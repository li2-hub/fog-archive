/**
 * 结局判定：纯函数，条件全部来自 state。
 * 结局 A「八分钟」：两条推论 + 至少五条线索 + 选择提交证据链
 * 结局 B「替罪者」：其余全部情况
 */
import { EndingDetail, EndingId, FinalChoice, GameState } from '../model/Types';
import { DEDUCE_GAP, DEDUCE_WHO, deductionName } from '../model/StoryGraph';

export const MIN_CLUES_FOR_TRUTH: number = 5;

export function resolveEnding(state: GameState, finalChoice: FinalChoice): EndingId {
  if (finalChoice !== FinalChoice.SUBMIT) {
    return EndingId.SCAPEGOAT;
  }
  if (!state.hasDeduction(DEDUCE_GAP) || !state.hasDeduction(DEDUCE_WHO)) {
    return EndingId.SCAPEGOAT;
  }
  if (state.collectedClues.length < MIN_CLUES_FOR_TRUTH) {
    return EndingId.SCAPEGOAT;
  }
  return EndingId.TRUTH;
}

/** 结局说明 + 未达成项，用于结局页复盘 */
export function endingDetail(id: EndingId, state: GameState, finalChoice: FinalChoice): EndingDetail {
  if (id === EndingId.TRUTH) {
    return new EndingDetail(
      EndingId.TRUTH,
      '结局 A · 八分钟',
      '你把两条推论并排放好：记录上的人和刷卡的人不是同一个，排班表上的"临时"是替别人签的退。八分钟的空档被重新调取，处分决定撤回，调查组进校。档案袋封口时，你在背面写下了日期。',
      []
    );
  }
  const missing: string[] = [];
  if (finalChoice !== FinalChoice.SUBMIT) {
    missing.push('你选择了只交人情，证据链没有交出去');
  }
  if (!state.hasDeduction(DEDUCE_GAP)) {
    missing.push(`缺少推论「${deductionName(DEDUCE_GAP)}」`);
  }
  if (!state.hasDeduction(DEDUCE_WHO)) {
    missing.push(`缺少推论「${deductionName(DEDUCE_WHO)}」`);
  }
  if (state.collectedClues.length < MIN_CLUES_FOR_TRUTH) {
    missing.push(`线索只有 ${state.collectedClues.length} 条，不足 ${MIN_CLUES_FOR_TRUTH} 条`);
  }
  return new EndingDetail(
    EndingId.SCAPEGOAT,
    '结局 B · 替罪者',
    '处分决定按原计划生效，理由栏写着"违规滞留，情节轻微"。记者站的稿子被压了下来，站长只说了句"再等等"。你知道那八分钟还在某个硬盘里，但没有人会再去调它。',
    missing
  );
}
