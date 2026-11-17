/**
 * 存档 IO 层：只负责把 SaveCodec 产出的字符串塞进 Preferences，
 * 以及读回来。业务规则一律不在这里，方便单测绕开 Context。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { GameState } from '../model/Types';
import { DecodeResult, decodeState, encodeState, SAVE_KEY } from './SaveCodec';

const STORE_NAME: string = 'fog_archive';

export class LoadOutcome {
  ok: boolean = false;
  reason: string = '';
  state: GameState = new GameState();

  constructor(ok: boolean, reason: string, state: GameState) {
    this.ok = ok;
    this.reason = reason;
    this.state = state;
  }
}

async function openStore(context: common.Context): Promise<preferences.Preferences> {
  const options: preferences.Options = { name: STORE_NAME };
  return await preferences.getPreferences(context, options);
}

/** 写入失败不抛异常，只返回 false —— 存档失败不该让玩家点不动按钮 */
export async function saveState(context: common.Context, state: GameState): Promise<boolean> {
  try {
    const store: preferences.Preferences = await openStore(context);
    await store.put(SAVE_KEY, encodeState(state));
    await store.flush();
    return true;
  } catch (error) {
    const err = error as BusinessError;
    console.error(`[FOG] SAVE_FAILED code=${err.code} msg=${err.message}`);
    return false;
  }
}

export async function loadState(context: common.Context): Promise<LoadOutcome> {
  try {
    const store: preferences.Preferences = await openStore(context);
    const value: preferences.ValueType = await store.get(SAVE_KEY, '');
    let raw: string = '';
    if (typeof value === 'string') {
      raw = value;
    }
    const decoded: DecodeResult = decodeState(raw);
    return new LoadOutcome(decoded.ok, decoded.reason, decoded.state);
  } catch (error) {
    const err = error as BusinessError;
    console.error(`[FOG] LOAD_FAILED code=${err.code} msg=${err.message}`);
    return new LoadOutcome(false, '读取存档失败，已重置为新调查', new GameState());
  }
}

export async function clearState(context: common.Context): Promise<boolean> {
  try {
    const store: preferences.Preferences = await openStore(context);
    await store.delete(SAVE_KEY);
    await store.flush();
    return true;
  } catch (error) {
    const err = error as BusinessError;
    console.error(`[FOG] CLEAR_FAILED code=${err.code} msg=${err.message}`);
    return false;
  }
}
