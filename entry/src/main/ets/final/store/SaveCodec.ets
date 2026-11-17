/**
 * 存档编解码：纯函数，不依赖 Context / 文件 / 系统 API。
 * 拆出来的目的是让"往返一致性"和"损坏降级"能进单元测试——
 * Preferences 那层需要 UIAbilityContext，hypium 里拿不到。
 *
 * 降级策略：任何一处不可信，都返回 ok=false 并给出原因，
 * 由调用方重置为新调查，绝不把半损坏的状态喂给引擎。
 */
import { EndingId, FinalChoice, GameState, SAVE_SCHEMA_VERSION, Stage, START_MINUTES } from '../model/Types';
import { CLUES, DEDUCTIONS, nodeById } from '../model/StoryGraph';

export const SAVE_KEY: string = 'save_v1';

/** 存档正文。所有字段可选，因为反序列化后必须逐项校验运行时类型 */
interface SavePayload {
  version?: number;
  currentNodeId?: string;
  collectedClues?: string[];
  deductions?: string[];
  flags?: string[];
  visitedNodes?: string[];
  timeLeft?: number;
  turn?: number;
  endingId?: string;
  finalChoice?: string;
  startedAt?: number;
  updatedAt?: number;
}

export class DecodeResult {
  ok: boolean = false;
  reason: string = '';
  state: GameState = new GameState();

  constructor(ok: boolean, reason: string, state: GameState) {
    this.ok = ok;
    this.reason = reason;
    this.state = state;
  }
}

export function encodeState(state: GameState): string {
  const payload: SavePayload = {
    version: SAVE_SCHEMA_VERSION,
    currentNodeId: state.currentNodeId,
    collectedClues: state.collectedClues,
    deductions: state.deductions,
    flags: state.flags,
    visitedNodes: state.visitedNodes,
    timeLeft: state.timeLeft,
    turn: state.turn,
    endingId: state.endingId,
    finalChoice: state.finalChoice,
    startedAt: state.startedAt,
    updatedAt: state.updatedAt
  };
  return JSON.stringify(payload);
}

function toStringList(value: string[] | undefined, known: string[]): string[] {
  const out: string[] = [];
  if (value === undefined || value === null) {
    return out;
  }
  if (!Array.isArray(value)) {
    return out;
  }
  for (const item of value) {
    if (typeof item !== 'string') {
      continue;
    }
    // 只保留当前数据表里还存在的 id：改了剧情表之后，旧存档不会带进幽灵线索
    if (known.length > 0 && !known.includes(item)) {
      continue;
    }
    if (!out.includes(item)) {
      out.push(item);
    }
  }
  return out;
}

function toNumber(value: number | undefined, fallback: number): number {
  if (value === undefined || typeof value !== 'number') {
    return fallback;
  }
  if (!Number.isFinite(value)) {
    return fallback;
  }
  return value;
}

function toEnding(value: string | undefined): EndingId {
  if (value === EndingId.TRUTH) {
    return EndingId.TRUTH;
  }
  if (value === EndingId.SCAPEGOAT) {
    return EndingId.SCAPEGOAT;
  }
  return EndingId.NONE;
}

function toFinalChoice(value: string | undefined): FinalChoice {
  if (value === FinalChoice.SUBMIT) {
    return FinalChoice.SUBMIT;
  }
  if (value === FinalChoice.KEEP_QUIET) {
    return FinalChoice.KEEP_QUIET;
  }
  return FinalChoice.NONE;
}

export function decodeState(raw: string): DecodeResult {
  if (raw === undefined || raw === null || raw === '') {
    return new DecodeResult(false, '没有可恢复的存档', new GameState());
  }

  let payload: SavePayload;
  try {
    payload = JSON.parse(raw) as SavePayload;
  } catch (error) {
    return new DecodeResult(false, '存档内容已损坏，已重置为新调查', new GameState());
  }
  if (payload === undefined || payload === null) {
    return new DecodeResult(false, '存档内容为空，已重置为新调查', new GameState());
  }

  const version: number = toNumber(payload.version, -1);
  if (version !== SAVE_SCHEMA_VERSION) {
    return new DecodeResult(false, '存档版本不兼容，已重置为新调查', new GameState());
  }

  const nodeId: string = typeof payload.currentNodeId === 'string' ? payload.currentNodeId : '';
  const node = nodeById(nodeId);
  if (node === undefined) {
    return new DecodeResult(false, '存档指向的场景已不存在，已重置为新调查', new GameState());
  }

  const clueIds: string[] = CLUES.map((item) => item.id);
  const deductionIds: string[] = DEDUCTIONS.map((item) => item.id);

  const state: GameState = new GameState();
  state.version = SAVE_SCHEMA_VERSION;
  state.currentNodeId = node.id;
  // 阶段以节点定义为准，避免存档里的 stage 与节点不一致导致进度条错位
  state.stage = node.stage;
  state.collectedClues = toStringList(payload.collectedClues, clueIds);
  state.deductions = toStringList(payload.deductions, deductionIds);
  state.flags = toStringList(payload.flags, []);
  state.visitedNodes = toStringList(payload.visitedNodes, []);

  let timeLeft: number = toNumber(payload.timeLeft, START_MINUTES);
  if (timeLeft < 0) {
    timeLeft = 0;
  }
  if (timeLeft > START_MINUTES) {
    timeLeft = START_MINUTES;
  }
  state.timeLeft = timeLeft;

  let turn: number = toNumber(payload.turn, 0);
  state.turn = turn < 0 ? 0 : turn;
  state.endingId = toEnding(payload.endingId);
  state.finalChoice = toFinalChoice(payload.finalChoice);
  state.startedAt = toNumber(payload.startedAt, 0);
  state.updatedAt = toNumber(payload.updatedAt, 0);

  // 结局节点必须带结局 id，否则是半截数据
  if (node.isEnding && state.endingId === EndingId.NONE) {
    return new DecodeResult(false, '结局存档不完整，已重置为新调查', new GameState());
  }

  return new DecodeResult(true, '', state);
}
