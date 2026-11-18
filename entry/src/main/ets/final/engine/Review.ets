/**
 * 结案复盘：把一次调查的"结果"翻译成可读的统计与条件清单。
 * 纯函数，只读 state，不碰 UI / Context，方便单测（T14 / T15）。
 */
import { FinalChoice, GameState, START_MINUTES, StoryNode } from '../model/Types';
import { CLUES, DEDUCTIONS, DEDUCE_GAP, DEDUCE_WHO, SCENES, deductionName, nodeById } from '../model/StoryGraph';
import { MIN_CLUES_FOR_TRUTH } from './EndingResolver';

/** 一条"结局达成条件"的回放记录：达成与否都要展示，让玩家知道差在哪 */
export class ReviewItem {
  label: string = '';
  ok: boolean = false;
  note: string = '';

  constructor(label: string, ok: boolean, note: string) {
    this.label = label;
    this.ok = ok;
    this.note = note;
  }
}

export class ReviewStats {
  clueCount: number = 0;
  clueTotal: number = 0;
  cluePercent: number = 0;
  deductionCount: number = 0;
  deductionTotal: number = 0;
  deductionPercent: number = 0;
  timeUsed: number = 0;
  timeLeft: number = 0;
  turn: number = 0;
  sceneCount: number = 0;
  sceneTotal: number = 0;
  items: ReviewItem[] = [];
  /** 未达成的条件数，0 表示证据链闭合 */
  missCount: number = 0;
}

function percent(part: number, total: number): number {
  if (total <= 0) {
    return 0;
  }
  const value: number = Math.round((part / total) * 100);
  return value < 0 ? 0 : (value > 100 ? 100 : value);
}

/** 去重统计"实际走进过几个现场"，比数 visitedNodes 更能说明探索广度 */
function countScenes(state: GameState): number {
  const seen: string[] = [];
  for (const id of state.visitedNodes) {
    const node: StoryNode | undefined = nodeById(id);
    if (node === undefined) {
      continue;
    }
    if (!seen.includes(node.sceneId)) {
      seen.push(node.sceneId);
    }
  }
  return seen.length;
}

export function reviewStats(state: GameState, finalChoice: FinalChoice): ReviewStats {
  const stats: ReviewStats = new ReviewStats();
  stats.clueCount = state.collectedClues.length;
  stats.clueTotal = CLUES.length;
  stats.cluePercent = percent(stats.clueCount, stats.clueTotal);
  stats.deductionCount = state.deductions.length;
  stats.deductionTotal = DEDUCTIONS.length;
  stats.deductionPercent = percent(stats.deductionCount, stats.deductionTotal);
  stats.timeUsed = START_MINUTES - state.timeLeft;
  stats.timeLeft = state.timeLeft;
  stats.turn = state.turn;
  stats.sceneCount = countScenes(state);
  stats.sceneTotal = SCENES.length;

  const submitted: boolean = finalChoice === FinalChoice.SUBMIT;
  stats.items.push(new ReviewItem(
    '在最终判断里提交完整证据链',
    submitted,
    submitted ? '你选择了「提交完整证据链」' : '你选择了「只交人情」，证据没有交出去'
  ));

  const hasGap: boolean = state.hasDeduction(DEDUCE_GAP);
  stats.items.push(new ReviewItem(
    `推论「${deductionName(DEDUCE_GAP)}」成立`,
    hasGap,
    hasGap ? '时间矛盾已经被你拼出来了' : '这条推论没有在线索板上验证过'
  ));

  const hasWho: boolean = state.hasDeduction(DEDUCE_WHO);
  stats.items.push(new ReviewItem(
    `推论「${deductionName(DEDUCE_WHO)}」成立`,
    hasWho,
    hasWho ? '替签的人已经指向具体某一位' : '这条推论没有在线索板上验证过'
  ));

  const enough: boolean = stats.clueCount >= MIN_CLUES_FOR_TRUTH;
  stats.items.push(new ReviewItem(
    `归档线索不少于 ${MIN_CLUES_FOR_TRUTH} 条`,
    enough,
    `已归档 ${stats.clueCount} / ${stats.clueTotal} 条`
  ));

  let miss: number = 0;
  for (const item of stats.items) {
    if (!item.ok) {
      miss = miss + 1;
    }
  }
  stats.missCount = miss;
  return stats;
}
