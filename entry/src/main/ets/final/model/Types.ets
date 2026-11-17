/**
 * 迷雾档案 · 类型定义
 * 只放类型、枚举、常量与状态容器，不含业务规则。
 */

export const SAVE_SCHEMA_VERSION: number = 1;
export const START_MINUTES: number = 480;

/** 阶段：0 接受调查 → 1 现场勘查 → 2 交叉验证 → 3 最终判断 → 4 结局 */
export enum Stage {
  ACCEPT = 0,
  SURVEY = 1,
  VERIFY = 2,
  VERDICT = 3,
  ENDING = 4
}

export enum EndingId {
  NONE = 'none',
  TRUTH = 'truth_8min',
  SCAPEGOAT = 'scapegoat'
}

export enum FinalChoice {
  NONE = 'none',
  SUBMIT = 'submit',
  KEEP_QUIET = 'quiet'
}

export interface ClueDef {
  id: string;
  name: string;
  summary: string;
  detail: string;
  sceneId: string;
}

export interface DeductionDef {
  id: string;
  name: string;
  clueA: string;
  clueB: string;
  conclusion: string;
}

export interface ChoiceDef {
  id: string;
  label: string;
  hint: string;
  nextNodeId: string;
  /** 消耗的分钟数 */
  cost: number;
  requireClues: string[];
  requireDeductions: string[];
  requireFlags: string[];
  grantClues: string[];
  setFlags: string[];
  finalChoice: FinalChoice;
}

export interface StoryNode {
  id: string;
  sceneId: string;
  title: string;
  text: string;
  stage: Stage;
  requireClues: string[];
  requireDeductions: string[];
  requireFlags: string[];
  isEnding: boolean;
  choices: ChoiceDef[];
}

export interface SceneDef {
  id: string;
  name: string;
  subtitle: string;
}

/** 唯一可变真相；引擎不原地修改，clone 后返回新实例 */
export class GameState {
  version: number = SAVE_SCHEMA_VERSION;
  currentNodeId: string = 'n_accept';
  stage: Stage = Stage.ACCEPT;
  collectedClues: string[] = [];
  deductions: string[] = [];
  flags: string[] = [];
  visitedNodes: string[] = [];
  timeLeft: number = START_MINUTES;
  turn: number = 0;
  endingId: EndingId = EndingId.NONE;
  startedAt: number = 0;
  updatedAt: number = 0;

  clone(): GameState {
    const next: GameState = new GameState();
    next.version = this.version;
    next.currentNodeId = this.currentNodeId;
    next.stage = this.stage;
    next.collectedClues = this.collectedClues.slice();
    next.deductions = this.deductions.slice();
    next.flags = this.flags.slice();
    next.visitedNodes = this.visitedNodes.slice();
    next.timeLeft = this.timeLeft;
    next.turn = this.turn;
    next.endingId = this.endingId;
    next.startedAt = this.startedAt;
    next.updatedAt = this.updatedAt;
    return next;
  }

  hasClue(id: string): boolean {
    return this.collectedClues.includes(id);
  }

  hasDeduction(id: string): boolean {
    return this.deductions.includes(id);
  }

  hasFlag(id: string): boolean {
    return this.flags.includes(id);
  }
}

export class EnterResult {
  ok: boolean = false;
  reason: string = '';

  constructor(ok: boolean, reason: string) {
    this.ok = ok;
    this.reason = reason;
  }
}

export class ChoiceAvailability {
  ok: boolean = false;
  reason: string = '';

  constructor(ok: boolean, reason: string) {
    this.ok = ok;
    this.reason = reason;
  }
}

export class ApplyResult {
  ok: boolean = false;
  reason: string = '';
  state: GameState = new GameState();

  constructor(ok: boolean, reason: string, state: GameState) {
    this.ok = ok;
    this.reason = reason;
    this.state = state;
  }
}

export class DeduceResult {
  ok: boolean = false;
  deductionId: string = '';
  conclusion: string = '';
  reason: string = '';
  state: GameState = new GameState();

  constructor(ok: boolean, deductionId: string, conclusion: string, reason: string, state: GameState) {
    this.ok = ok;
    this.deductionId = deductionId;
    this.conclusion = conclusion;
    this.reason = reason;
    this.state = state;
  }
}

export class EndingDetail {
  id: EndingId = EndingId.NONE;
  title: string = '';
  summary: string = '';
  missing: string[] = [];

  constructor(id: EndingId, title: string, summary: string, missing: string[]) {
    this.id = id;
    this.title = title;
    this.summary = summary;
    this.missing = missing;
  }
}
