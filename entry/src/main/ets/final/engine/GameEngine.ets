/**
 * 游戏引擎：所有状态变更的唯一入口。
 * 约定：不修改入参，返回新 GameState；失败用 ApplyResult/EnterResult 携带原因返回，不抛异常。
 * 不依赖 UI 与 Context，时间通过 now 参数注入，便于单元测试。
 */
import {
  ApplyResult, ChoiceAvailability, ChoiceDef, EndingId, EnterResult, FinalChoice, GameState, START_MINUTES,
  Stage, StoryNode
} from '../model/Types';
import { clueName, deductionName, nodeById } from '../model/StoryGraph';
import { resolveEnding } from './EndingResolver';

export function createInitialState(now: number): GameState {
  const state: GameState = new GameState();
  state.version = 1;
  state.currentNodeId = 'n_accept';
  state.stage = Stage.ACCEPT;
  state.timeLeft = START_MINUTES;
  state.turn = 0;
  state.endingId = EndingId.NONE;
  state.startedAt = now;
  state.updatedAt = now;
  return state;
}

export function currentNode(state: GameState): StoryNode | undefined {
  return nodeById(state.currentNodeId);
}

/** 节点是否可进入：线索 / 推论 / 标记三类前置条件 */
export function canEnter(node: StoryNode, state: GameState): EnterResult {
  if (state.endingId !== EndingId.NONE) {
    return new EnterResult(false, '调查已经结束');
  }
  const missing: string[] = [];
  for (const id of node.requireClues) {
    if (!state.hasClue(id)) {
      missing.push(`线索「${clueName(id)}」`);
    }
  }
  for (const id of node.requireDeductions) {
    if (!state.hasDeduction(id)) {
      missing.push(`推论「${deductionName(id)}」`);
    }
  }
  for (const id of node.requireFlags) {
    if (!state.hasFlag(id)) {
      missing.push('必要的前置对话');
    }
  }
  if (missing.length > 0) {
    return new EnterResult(false, `还缺 ${missing.join('、')}`);
  }
  return new EnterResult(true, '');
}

/** 选项是否可用：前置条件 + 剩余时间 */
export function isChoiceAvailable(choice: ChoiceDef, state: GameState): ChoiceAvailability {
  if (state.endingId !== EndingId.NONE) {
    return new ChoiceAvailability(false, '调查已经结束');
  }
  const missing: string[] = [];
  for (const id of choice.requireClues) {
    if (!state.hasClue(id)) {
      missing.push(`线索「${clueName(id)}」`);
    }
  }
  for (const id of choice.requireDeductions) {
    if (!state.hasDeduction(id)) {
      missing.push(`推论「${deductionName(id)}」`);
    }
  }
  for (const id of choice.requireFlags) {
    if (!state.hasFlag(id)) {
      missing.push('前置对话没有完成');
    }
  }
  if (missing.length > 0) {
    return new ChoiceAvailability(false, `还缺 ${missing.join('、')}`);
  }
  if (choice.cost > state.timeLeft) {
    const short: number = choice.cost - state.timeLeft;
    return new ChoiceAvailability(false, `时间不够，还差 ${short} 分钟`);
  }
  return new ChoiceAvailability(true, '');
}

export function applyChoice(state: GameState, node: StoryNode, choice: ChoiceDef, now: number): ApplyResult {
  if (node.id !== state.currentNodeId) {
    return new ApplyResult(false, '当前不在该节点', state);
  }
  const availability: ChoiceAvailability = isChoiceAvailable(choice, state);
  if (!availability.ok) {
    return new ApplyResult(false, availability.reason, state);
  }
  const target: StoryNode | undefined = nodeById(choice.nextNodeId);
  if (target === undefined) {
    return new ApplyResult(false, '剧情节点缺失，请检查数据表', state);
  }
  const enter: EnterResult = canEnter(target, state);
  if (!enter.ok) {
    return new ApplyResult(false, enter.reason, state);
  }

  const next: GameState = state.clone();
  next.timeLeft = state.timeLeft - choice.cost;
  next.turn = state.turn + 1;
  for (const id of choice.grantClues) {
    if (!next.hasClue(id)) {
      next.collectedClues.push(id);
    }
  }
  for (const id of choice.setFlags) {
    if (!next.hasFlag(id)) {
      next.flags.push(id);
    }
  }
  next.currentNodeId = target.id;
  next.visitedNodes.push(target.id);
  next.stage = target.stage;
  next.updatedAt = now;

  if (choice.finalChoice !== FinalChoice.NONE) {
    next.finalChoice = choice.finalChoice;
    next.endingId = resolveEnding(next, choice.finalChoice);
  } else if (target.isEnding) {
    next.endingId = resolveEnding(next, FinalChoice.NONE);
  }
  return new ApplyResult(true, '', next);
}

export function applyChoiceById(state: GameState, choiceId: string, now: number): ApplyResult {
  const node: StoryNode | undefined = currentNode(state);
  if (node === undefined) {
    return new ApplyResult(false, '剧情节点缺失，请检查数据表', state);
  }
  const choice: ChoiceDef | undefined = node.choices.find((item: ChoiceDef) => item.id === choiceId);
  if (choice === undefined) {
    return new ApplyResult(false, '当前节点没有这个选项', state);
  }
  return applyChoice(state, node, choice, now);
}

/** 剩余时间是否还够做任何消耗型选择 */
export function hasAffordableChoice(state: GameState): boolean {
  const node: StoryNode | undefined = currentNode(state);
  if (node === undefined) {
    return false;
  }
  for (const choice of node.choices) {
    if (choice.cost <= state.timeLeft && isChoiceAvailable(choice, state).ok) {
      return true;
    }
  }
  return false;
}

export function stageName(stage: Stage): string {
  if (stage === Stage.ACCEPT) {
    return '接受调查';
  }
  if (stage === Stage.SURVEY) {
    return '现场勘查';
  }
  if (stage === Stage.VERIFY) {
    return '交叉验证';
  }
  if (stage === Stage.VERDICT) {
    return '最终判断';
  }
  return '档案封存';
}

export function progressPercent(state: GameState): number {
  const ratio: number = (state.stage as number) / (Stage.ENDING as number);
  const clamped: number = ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
  return Math.round(clamped * 100);
}
