import { describe, it, expect } from '@ohos/hypium';
import {
  ApplyResult, ChoiceAvailability, ChoiceDef, DeduceResult, EndingId, EnterResult, FinalChoice, GameState, Stage,
  StoryNode
} from '../../../main/ets/final/model/Types';
import { applyChoiceById, canEnter, createInitialState, isChoiceAvailable } from '../../../main/ets/final/engine/GameEngine';
import { tryDeduce } from '../../../main/ets/final/engine/Deduction';
import { resolveEnding } from '../../../main/ets/final/engine/EndingResolver';
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

    it('T3_entrance_blocked_without_clue', 0, () => {
      const initial: GameState = createInitialState(NOW);
      const enter: EnterResult = canEnter(mustNode('n_b1_tape'), initial);
      expect(enter.ok).assertFalse();
      expect(enter.reason.length > 0).assertTrue();

      const doorState: GameState = initial.clone();
      doorState.currentNodeId = 'n_b1_door';
      const rejected: ApplyResult = applyChoiceById(doorState, 'ch_door_force', NOW + 1000);
      expect(rejected.ok).assertFalse();
      expect(rejected.reason.length > 0).assertTrue();
      expect(rejected.state.currentNodeId).assertEqual('n_b1_door');
      expect(rejected.state.hasClue(CLUE_DOOR)).assertFalse();
    });

    it('T4_clue_grant_is_idempotent', 0, () => {
      const state: GameState = createInitialState(NOW);
      state.currentNodeId = 'n_b1_shelf';
      const first: ApplyResult = applyChoiceById(state, 'ch_shelf_search', NOW + 1000);
      expect(first.state.collectedClues.length).assertEqual(1);
      expect(first.state.collectedClues[0]).assertEqual(CLUE_CARD);

      const again: GameState = first.state.clone();
      again.currentNodeId = 'n_b1_shelf';
      const second: ApplyResult = applyChoiceById(again, 'ch_shelf_search', NOW + 2000);
      expect(second.state.collectedClues.length).assertEqual(1);
      expect(second.state.collectedClues[0]).assertEqual(CLUE_CARD);
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

  });
}
