/**
 * 推理验证：两条线索组合 → 推论。
 * 顺序无关；重复验证同一条推论会被拒绝（幂等）。
 */
import { DeduceResult, DeductionDef, GameState } from '../model/Types';
import { DEDUCTIONS } from '../model/StoryGraph';

export function tryDeduce(state: GameState, clueA: string, clueB: string, now: number): DeduceResult {
  if (clueA === clueB) {
    return new DeduceResult(false, '', '', '要选两条不同的线索', state);
  }
  if (!state.hasClue(clueA) || !state.hasClue(clueB)) {
    return new DeduceResult(false, '', '', '选中的线索还没有到手', state);
  }
  const matched: DeductionDef | undefined = DEDUCTIONS.find((item: DeductionDef) => {
    const forward: boolean = item.clueA === clueA && item.clueB === clueB;
    const backward: boolean = item.clueA === clueB && item.clueB === clueA;
    return forward || backward;
  });
  if (matched === undefined) {
    return new DeduceResult(false, '', '', '这两条线索放在一起，还推不出结论', state);
  }
  if (state.hasDeduction(matched.id)) {
    return new DeduceResult(false, matched.id, matched.conclusion, '这条推论已经在档案里了', state);
  }
  const next: GameState = state.clone();
  next.deductions.push(matched.id);
  next.updatedAt = now;
  return new DeduceResult(true, matched.id, matched.conclusion, '', next);
}
