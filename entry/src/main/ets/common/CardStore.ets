/**
 * 实验十一 任务1：卡片实例记录
 *
 * 每张桌面卡片在 CardEvent 表里占一行，formId 是主键。
 * eventIndex 记住这张卡片当前显示哪条活动，todoCount 记住它的待办数量，
 * revision 从 0 开始，每次保存后加一，用来核对是哪一次修改。
 *
 * 数据库由页面与卡片提供方共用：都通过应用级 Context 打开同名库，
 * 因此卡片上保存的内容，编辑页读得到；编辑页写入的结果，卡片也收得到。
 */
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { CardPayload, eventData } from './CampusData';

export interface CardRecord {
  formId: string;
  eventIndex: number;
  todoCount: number;
  revision: number;
}

async function openDb(context: common.Context): Promise<relationalStore.RdbStore> {
  const config: relationalStore.StoreConfig = {
    name: 'campus_cards.db', securityLevel: relationalStore.SecurityLevel.S1
  };
  const db = await relationalStore.getRdbStore(context.getApplicationContext(), config);
  try {
    await db.executeSql('CREATE TABLE IF NOT EXISTS CardEvent (' +
      'formId TEXT PRIMARY KEY NOT NULL, eventIndex INTEGER NOT NULL, ' +
      'todoCount INTEGER NOT NULL, revision INTEGER NOT NULL)');
    return db;
  } catch (error) { await db.close(); throw new Error((error as Error).message); }
}

function recordFrom(rows: relationalStore.ResultSet): CardRecord {
  return { formId: rows.getString(0), eventIndex: rows.getLong(1),
    todoCount: rows.getLong(2), revision: rows.getLong(3) };
}
export async function readCard(context: common.Context, id: string): Promise<CardRecord | undefined> {
  const db = await openDb(context);
  try {
    const rows = await db.querySql('SELECT formId, eventIndex, todoCount, revision FROM CardEvent WHERE formId = ?', [id]);
    try { return rows.goToFirstRow() ? recordFrom(rows) : undefined; }
    finally { rows.close(); }
  } finally { await db.close(); }
}

export async function ensureCard(context: common.Context, id: string): Promise<CardRecord> {
  if (id.length === 0) { throw new Error('卡片ID为空'); }
  const db = await openDb(context);
  try {
    await db.executeSql('INSERT OR IGNORE INTO CardEvent VALUES (?, 0, 3, 0)', [id]);
  } finally { await db.close(); }
  const record = await readCard(context, id);
  if (record === undefined) { throw new Error('卡片记录读取失败'); }
  return record;
}
export async function listCards(context: common.Context): Promise<CardRecord[]> {
  const db = await openDb(context);
  const items: CardRecord[] = [];
  try {
    const rows = await db.querySql('SELECT formId, eventIndex, todoCount, revision FROM CardEvent ORDER BY formId');
    try { while (rows.goToNextRow()) { items.push(recordFrom(rows)); } }
    finally { rows.close(); }
  } finally { await db.close(); }
  return items;
}

export async function removeCard(context: common.Context, id: string): Promise<void> {
  const db = await openDb(context);
  try {
    const count = await db.delete(new relationalStore.RdbPredicates('CardEvent').equalTo('formId', id));
    console.info(`[CARDLAB] REMOVE id=${id} rows=${count}`);
  } finally { await db.close(); }
}

export function clockText(): string {
  const now = new Date();
  return `${now.getHours().toString().padStart(2, '0')}:` +
    `${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}`;
}

export function cardData(record: CardRecord, source: string): CardPayload {
  const data: CardPayload = eventData(record.eventIndex, record.todoCount);
  data.formId = record.formId;
  data.revision = record.revision;
  data.refreshedAt = clockText();
  data.refreshSource = source;
  return data;
}
export async function saveCard(context: common.Context, id: string, index: number, count: number): Promise<CardRecord> {
  if (!Number.isInteger(index) || index < 0 || index > 2 ||
    !Number.isInteger(count) || count < 0 || count > 9) {
    throw new Error('活动编号或待办数量无效');
  }
  const db = await openDb(context);
  try {
    await db.executeSql('UPDATE CardEvent SET eventIndex = ?, todoCount = ?, revision = revision + 1 WHERE formId = ?',
      [index, count, id]);
    const rows = await db.querySql('SELECT formId, eventIndex, todoCount, revision FROM CardEvent WHERE formId = ?', [id]);
    try {
      if (!rows.goToFirstRow()) { throw new Error('卡片已移除，请从桌面重新进入'); }
      return recordFrom(rows);
    } finally { rows.close(); }
  } finally { await db.close(); }
}
