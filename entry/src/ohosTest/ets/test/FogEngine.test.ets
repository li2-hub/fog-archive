import { describe, it, expect } from '@ohos/hypium';
import {
  ApplyResult, ChoiceAvailability, ChoiceDef, DeduceResult, EndingId, EnterResult, FinalChoice, GameState,
  START_MINUTES, Stage, StoryNode
} from '../../../main/ets/final/model/Types';
import { applyChoiceById, canEnter, createInitialState, isChoiceAvailable } from '../../../main/ets/final/engine/GameEngine';
import { tryDeduce } from '../../../main/ets/final/engine/Deduction';
import { resolveEnding } from '../../../main/ets/final/engine/EndingResolver';
import { reviewStats, ReviewStats } from '../../../main/ets/final/engine/Review';
import { DecodeResult, decodeState, encodeState } from '../../../main/ets/final/store/SaveCodec';
import {
  CLUE_BURN, CLUE_CARD, CLUE_DOOR, CLUE_LOG, CLUE_NOTE, CLUE_TAPE, DEDUCE_GAP, DEDUCE_WHO, nodeById
} from '../../../main/ets/final/model/StoryGraph';

const NOW: number = 1731800000000;

function mustNode(id: string): StoryNode {
  const node: StoryNode | undefined = nodeById(id);
  if (node === undefined) {
    throw new Error(`节点缺失: ${id}`);
  }
  return node;
}

/** 用真实选项把状态推到"有值班记录"的节点 */
function stateAtDoor(): GameState {
  const step1: ApplyResult = applyChoiceById(createInitialState(NOW), 'ch_accept', NOW + 1000);
  return applyChoiceById(step1.state, 'ch_gate_log', NOW + 2000).state;
}

function stateWith(clues: string[], deductions: string[]): GameState {
  const state: GameState = createInitialState(NOW);
  state.collectedClues = clues.slice();
  state.deductions = deductions.slice();
  state.updatedAt = NOW;
  return state;
}

export default function fogEngineTest() {
  describe('FogEngine', () => {

    it('T1_initial_state', 0, () => {
      const state: GameState = createInitialState(NOW);
      expect(state.currentNodeId).assertEqual('n_accept');
      expect(state.stage).assertEqual(Stage.ACCEPT);
      expect(state.timeLeft).assertEqual(480);
      expect(state.collectedClues.length).assertEqual(0);
      expect(state.deductions.length).assertEqual(0);
      expect(state.endingId).assertEqual(EndingId.NONE);
      expect(state.startedAt).assertEqual(NOW);
    });

    it('T2_choice_moves_and_grants_clue', 0, () => {
      const first: ApplyResult = applyChoiceById(createInitialState(NOW), 'ch_accept', NOW + 1000);
      expect(first.ok).assertTrue();
      expect(first.state.currentNodeId).assertEqual('n_gate');
      expect(first.state.timeLeft).assertEqual(470);
      expect(first.state.turn).assertEqual(1);

      const second: ApplyResult = applyChoiceById(first.state, 'ch_gate_log', NOW + 2000);
      expect(second.ok).assertTrue();
      expect(second.state.currentNodeId).assertEqual('n_b1_door');
      expect(second.state.timeLeft).assertEqual(440);
      expect(second.state.hasClue(CLUE_LOG)).assertTrue();
      expect(second.state.stage).assertEqual(Stage.SURVEY);
      expect(second.state.visitedNodes.includes('n_b1_door')).assertTrue();
    });

    it('T3_guard_blocks_without_prerequisite', 0, () => {
      // 节点级守卫仍然生效：调查结束后任何节点都不再可进入
      const finished: GameState = createInitialState(NOW);
      finished.endingId = EndingId.TRUTH;
      const enter: EnterResult = canEnter(mustNode('n_b1_tape'), finished);
      expect(enter.ok).assertFalse();

      // 选项级守卫：缺值班记录时，调门禁后台被拒
      const doorState: GameState = createInitialState(NOW);
      doorState.currentNodeId = 'n_b1_door';
      const rejected: ApplyResult = applyChoiceById(doorState, 'ch_door_force', NOW + 1000);
      expect(rejected.ok).assertFalse();
      expect(rejected.reason.length > 0).assertTrue();
      expect(rejected.state.currentNodeId).assertEqual('n_b1_door');
      expect(rejected.state.hasClue(CLUE_DOOR)).assertFalse();

      // 选项级守卫：有门禁记录但没有推论时，完整回放仍被拒
      const tapeState: GameState = stateWith([CLUE_DOOR], []);
      tapeState.currentNodeId = 'n_b1_tape';
      const tapeRejected: ApplyResult = applyChoiceById(tapeState, 'ch_tape_full', NOW + 2000);
      expect(tapeRejected.ok).assertFalse();
      expect(tapeRejected.state.hasClue(CLUE_TAPE)).assertFalse();
    });

    it('T4_clue_grant_is_idempotent', 0, () => {
      // 目标节点 n_b1_tape 不再要求门禁线索，这里只验证"同一条线索重复领取不会重复记账"
      const state: GameState = createInitialState(NOW);
      state.currentNodeId = 'n_b1_shelf';

      const first: ApplyResult = applyChoiceById(state, 'ch_shelf_search', NOW + 1000);
      expect(first.ok).assertTrue();
      expect(first.state.countClue(CLUE_CARD)).assertEqual(1);
      expect(first.state.collectedClues.length).assertEqual(1);

      const again: GameState = first.state.clone();
      again.currentNodeId = 'n_b1_shelf';
      const second: ApplyResult = applyChoiceById(again, 'ch_shelf_search', NOW + 2000);
      expect(second.ok).assertTrue();
      expect(second.state.countClue(CLUE_CARD)).assertEqual(1);
      expect(second.state.collectedClues.length).assertEqual(1);
    });

    it('T5_time_exhausted_rejects_choice', 0, () => {
      const state: GameState = createInitialState(NOW);
      state.timeLeft = 0;
      const node: StoryNode = mustNode('n_accept');
      const choice: ChoiceDef = node.choices[0];
      const availability: ChoiceAvailability = isChoiceAvailable(choice, state);
      expect(availability.ok).assertFalse();
      expect(availability.reason.length > 0).assertTrue();

      const result: ApplyResult = applyChoiceById(state, 'ch_accept', NOW + 1000);
      expect(result.ok).assertFalse();
      expect(result.state.timeLeft).assertEqual(0);
      expect(result.state.turn).assertEqual(0);
    });

    it('T6_deduction_matches_regardless_of_order', 0, () => {
      const ready: GameState = stateAtDoor();
      expect(ready.hasClue(CLUE_LOG)).assertTrue();
      expect(ready.hasClue(CLUE_DOOR)).assertFalse();

      ready.collectedClues.push(CLUE_DOOR);
      const result: DeduceResult = tryDeduce(ready, CLUE_DOOR, CLUE_LOG, NOW + 3000);
      expect(result.ok).assertTrue();
      expect(result.deductionId).assertEqual(DEDUCE_GAP);
      expect(result.state.hasDeduction(DEDUCE_GAP)).assertTrue();
      expect(result.conclusion.length > 0).assertTrue();
    });

    it('T7_wrong_pair_has_no_conclusion', 0, () => {
      const state: GameState = stateWith([CLUE_LOG, CLUE_NOTE], []);
      const result: DeduceResult = tryDeduce(state, CLUE_LOG, CLUE_NOTE, NOW + 1000);
      expect(result.ok).assertFalse();
      expect(result.reason.length > 0).assertTrue();
      expect(result.state.deductions.length).assertEqual(0);
      expect(state.deductions.length).assertEqual(0);
    });

    it('T8_ending_branches', 0, () => {
      const full: GameState = stateWith(
        [CLUE_LOG, CLUE_DOOR, CLUE_CARD, CLUE_TAPE, CLUE_BURN, CLUE_NOTE],
        [DEDUCE_GAP, DEDUCE_WHO]
      );
      expect(resolveEnding(full, FinalChoice.SUBMIT)).assertEqual(EndingId.TRUTH);
      expect(resolveEnding(full, FinalChoice.KEEP_QUIET)).assertEqual(EndingId.SCAPEGOAT);

      const noWho: GameState = stateWith(
        [CLUE_LOG, CLUE_DOOR, CLUE_CARD, CLUE_TAPE, CLUE_BURN],
        [DEDUCE_GAP]
      );
      expect(resolveEnding(noWho, FinalChoice.SUBMIT)).assertEqual(EndingId.SCAPEGOAT);

      const fewClues: GameState = stateWith(
        [CLUE_LOG, CLUE_DOOR, CLUE_CARD, CLUE_TAPE],
        [DEDUCE_GAP, DEDUCE_WHO]
      );
      expect(resolveEnding(fewClues, FinalChoice.SUBMIT)).assertEqual(EndingId.SCAPEGOAT);
    });

    it('T10_shortcut_route_can_finish', 0, () => {
      // 回归用例：先选「直接问值班保安」再选「按保安口述记下时间」，
      // 曾经因为 n_b1_tape 的节点门槛而永久卡死。这条用例逐步断言每一步都推进成功。
      const steps: string[] = [
        'ch_accept', 'ch_gate_guard', 'ch_door_guess', 'ch_shelf_search', 'ch_tape_skip',
        'ch_teacher_ask', 'ch_burn_photo', 'ch_witness_calm', 'ch_locker_open',
        'ch_confront_enter', 'ch_final_quiet'
      ];
      let state: GameState = createInitialState(NOW);
      for (const id of steps) {
        const step: ApplyResult = applyChoiceById(state, id, NOW + 1000);
        expect(step.ok).assertTrue();
        state = step.state;
      }
      expect(state.endingId).assertEqual(EndingId.SCAPEGOAT);
      expect(state.visitedNodes.includes('n_epilogue')).assertTrue();

      // 能走完，但门禁记录与完整录像这两条证据确实拿不到
      expect(state.hasClue(CLUE_DOOR)).assertFalse();
      expect(state.hasClue(CLUE_TAPE)).assertFalse();
    });

    it('T11_guard_route_can_recover_door_clue', 0, () => {
      // 问保安之后回头补记录：总耗时与"直接调记录"路线持平，但证据能补齐
      const first: ApplyResult = applyChoiceById(createInitialState(NOW), 'ch_accept', NOW + 1000);
      const talk: ApplyResult = applyChoiceById(first.state, 'ch_gate_guard', NOW + 2000);
      expect(talk.ok).assertTrue();
      expect(talk.state.hasFlag('guard_talk')).assertTrue();
      expect(talk.state.hasClue(CLUE_LOG)).assertFalse();

      const back: ApplyResult = applyChoiceById(talk.state, 'ch_door_back', NOW + 3000);
      expect(back.ok).assertTrue();
      expect(back.state.hasClue(CLUE_LOG)).assertTrue();
      expect(back.state.hasClue(CLUE_DOOR)).assertTrue();
      expect(back.state.timeLeft).assertEqual(420);

      const deduced: DeduceResult = tryDeduce(back.state, CLUE_LOG, CLUE_DOOR, NOW + 4000);
      expect(deduced.ok).assertTrue();
      expect(deduced.deductionId).assertEqual(DEDUCE_GAP);
    });

    it('T13_review_stats_for_truth', 0, () => {
      // 结局页的统计必须以存档为准：条件清单全绿、百分比取整、用时按起始时限反推
      const full: GameState = stateWith(
        [CLUE_LOG, CLUE_DOOR, CLUE_CARD, CLUE_TAPE, CLUE_BURN, CLUE_NOTE],
        [DEDUCE_GAP, DEDUCE_WHO]
      );
      full.timeLeft = 100;
      full.turn = 12;
      full.visitedNodes = ['n_accept', 'n_gate', 'n_b1_door', 'n_b1_shelf', 'n_b1_tape', 'n_lab_corridor',
        'n_lab_room', 'n_stadium_stand', 'n_stadium_locker', 'n_confront', 'n_final_choose', 'n_epilogue'];

      const stats: ReviewStats = reviewStats(full, FinalChoice.SUBMIT);
      expect(stats.clueCount).assertEqual(6);
      expect(stats.cluePercent).assertEqual(100);
      expect(stats.deductionCount).assertEqual(2);
      expect(stats.deductionPercent).assertEqual(100);
      expect(stats.timeUsed).assertEqual(START_MINUTES - 100);
      expect(stats.sceneCount).assertEqual(4);
      expect(stats.missCount).assertEqual(0);
      expect(stats.items.length).assertEqual(4);
      for (const item of stats.items) {
        expect(item.ok).assertTrue();
      }
    });

    it('T14_review_stats_lists_missing_conditions', 0, () => {
      // 走"只交人情"的 B 结局：四条条件都该标成未达成，且逐项能说清原因
      const thin: GameState = stateWith([CLUE_LOG, CLUE_CARD], []);
      thin.turn = 4;
      thin.timeLeft = 300;

      const stats: ReviewStats = reviewStats(thin, FinalChoice.KEEP_QUIET);
      expect(stats.missCount).assertEqual(4);
      expect(stats.cluePercent).assertEqual(33);
      expect(stats.deductionPercent).assertEqual(0);
      for (const item of stats.items) {
        expect(item.ok).assertFalse();
        expect(item.note.length > 0).assertTrue();
      }

      // 只缺线索数时，前三条应当通过
      const almost: GameState = stateWith([CLUE_LOG, CLUE_DOOR, CLUE_CARD], [DEDUCE_GAP, DEDUCE_WHO]);
      const partial: ReviewStats = reviewStats(almost, FinalChoice.SUBMIT);
      expect(partial.missCount).assertEqual(1);
      expect(partial.items[0].ok).assertTrue();
      expect(partial.items[1].ok).assertTrue();
      expect(partial.items[2].ok).assertTrue();
      expect(partial.items[3].ok).assertFalse();
    });

    it('T9_save_roundtrip', 0, () => {
      // 存档往返：所有会影响玩法判断的字段都必须原样回来
      const original: GameState = createInitialState(NOW);
      original.currentNodeId = 'n_b1_tape';
      original.stage = Stage.SURVEY;
      original.collectedClues = [CLUE_LOG, CLUE_DOOR, CLUE_CARD];
      original.deductions = [DEDUCE_GAP];
      original.flags = ['guard_talk'];
      original.visitedNodes = ['n_accept', 'n_gate', 'n_b1_door'];
      original.timeLeft = 300;
      original.turn = 5;
      original.finalChoice = FinalChoice.SUBMIT;
      original.startedAt = NOW;
      original.updatedAt = NOW + 5000;

      const raw: string = encodeState(original);
      expect(raw.length > 0).assertTrue();

      const decoded: DecodeResult = decodeState(raw);
      expect(decoded.ok).assertTrue();
      const back: GameState = decoded.state;
      expect(back.currentNodeId).assertEqual('n_b1_tape');
      expect(back.stage).assertEqual(Stage.SURVEY);
      expect(back.collectedClues.length).assertEqual(3);
      expect(back.hasClue(CLUE_LOG)).assertTrue();
      expect(back.hasClue(CLUE_DOOR)).assertTrue();
      expect(back.hasDeduction(DEDUCE_GAP)).assertTrue();
      expect(back.hasFlag('guard_talk')).assertTrue();
      expect(back.visitedNodes.length).assertEqual(3);
      expect(back.timeLeft).assertEqual(300);
      expect(back.turn).assertEqual(5);
      expect(back.finalChoice).assertEqual(FinalChoice.SUBMIT);
      expect(back.startedAt).assertEqual(NOW);
      expect(back.updatedAt).assertEqual(NOW + 5000);

      // 恢复后引擎能继续用这份状态推进
      const next: ApplyResult = applyChoiceById(back, 'ch_tape_skip', NOW + 6000);
      expect(next.ok).assertTrue();
      expect(next.state.currentNodeId).assertEqual('n_lab_corridor');
    });

    it('T12_save_corruption_degrades', 0, () => {
      // 空存档
      expect(decodeState('').ok).assertFalse();

      // 截断的 JSON：不能让异常穿透到 UI
      const broken: DecodeResult = decodeState('{"version":1,');
      expect(broken.ok).assertFalse();
      expect(broken.reason.length > 0).assertTrue();

      // 版本不兼容（旧包写的档）
      expect(decodeState('{"version":0,"currentNodeId":"n_gate"}').ok).assertFalse();

      // 指向已被删除的节点
      expect(decodeState('{"version":1,"currentNodeId":"n_removed_scene"}').ok).assertFalse();

      // 结局节点缺少 endingId：半截数据也算损坏
      expect(decodeState('{"version":1,"currentNodeId":"n_epilogue","endingId":"none"}').ok).assertFalse();

      // 局部脏数据不整档丢弃：未知线索过滤、重复去重、越界数值夹紧
      const partial: DecodeResult = decodeState(
        '{"version":1,"currentNodeId":"n_gate","collectedClues":["c_log","c_ghost","c_log"],"timeLeft":9999,"turn":-3}'
      );
      expect(partial.ok).assertTrue();
      expect(partial.state.collectedClues.length).assertEqual(1);
      expect(partial.state.hasClue(CLUE_LOG)).assertTrue();
      expect(partial.state.timeLeft).assertEqual(START_MINUTES);
      expect(partial.state.turn).assertEqual(0);
      // 阶段以节点定义为准，不信任存档里可能错位的值
      expect(partial.state.stage).assertEqual(Stage.SURVEY);
    });

  });
}
