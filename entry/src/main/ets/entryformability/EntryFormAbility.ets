/**
 * 实验十一 任务1：卡片提供方（首次绑定数据 + 实例登记）
 *
 * 系统在桌面添加卡片时调用 onAddForm()，这里是卡片生命周期的起点。
 * 首次图文仍然同步返回第一项活动（校园摄影采风）的字段，卡片页面按下发
 * 字段名逐个接收；同时把 formId 登记进 CardEvent 表，供后续刷新与编辑读取。
 *
 * IDENTITY_KEY 是系统分配的卡片实例标识（formId），DIMENSION_KEY 是
 * 系统选定的尺寸编号：2 表示 2*2，3 表示 2*4。
 *
 * formId 与 dimension 是本实验自定义的下发字段名，值取自 Want；
 * 其余字段都来自 eventData(0)。createFormBindingData() 把它们交给
 * 新建的卡片实例，页面里的 @LocalStorageProp 按同名接收。
 */
import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { CardPayload, EVENTS, eventData } from '../common/CampusData';
import { CardRecord, cardData, ensureCard, removeCard, saveCard } from '../common/CardStore';

export default class EntryFormAbility extends FormExtensionAbility {
  private working: Set<string> = new Set<string>();
  onAddForm(want: Want): formBindingData.FormBindingData {
    const id: string = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string ?? '';
    const dimension: number = want.parameters?.[formInfo.FormParam.DIMENSION_KEY] as number ?? 2;
    const data: CardPayload = eventData(0);
    data.formId = id;
    data.dimension = dimension;
    // 首次图文同步返回，数据库登记在异步里完成：新 ID 写入 0 号活动、3 项待办
    ensureCard(this.context, id).then(() => {
      console.info(`[CARDLAB] READY id=${id}`);
    }).catch((error: Error) => { console.error(`[CARDLAB] STORE_ERROR ${error.message}`); });
    console.info(`[CARDLAB] ADD id=${id} dimension=${dimension} title=${data.title}`);
    return formBindingData.createFormBindingData(data);
  }

  // 把一条记录转换成卡片字段，提交给指定 formId，只有这张卡片会刷新
  private async push(id: string, record: CardRecord, source: string): Promise<void> {
    const data: CardPayload = cardData(record, source);
    await formProvider.updateForm(id, formBindingData.createFormBindingData(data));
    console.info(`[CARDLAB] PUSH id=${id} index=${record.eventIndex} count=${record.todoCount} source=${source} at=${data.refreshedAt}`);
  }

  // 切到下一项活动：读当前记录 → 算下一项 → 保存 → 提交。working 防止同一张卡片重复点击交叉执行
  private async nextEvent(id: string): Promise<void> {
    if (this.working.has(id)) { return; }
    this.working.add(id);
    try {
      const current = await ensureCard(this.context, id);
      const next: number = (current.eventIndex + 1) % EVENTS.length;
      const saved = await saveCard(this.context, id, next, EVENTS[next].todoCount);
      await this.push(id, saved, '手动换活动');
    } catch (error) {
      console.error(`[CARDLAB] UPDATE_ERROR id=${id} ${(error as Error).message}`);
    } finally { this.working.delete(id); }
  }

  // 卡片上 postCardAction(action:'message') 会走到这里，operation 决定业务动作
  onFormEvent(formId: string, message: string): void {
    try {
      const params: Record<string, string> = JSON.parse(message) as Record<string, string>;
      console.info(`[CARDLAB] MESSAGE id=${formId} operation=${params.operation} raw=${message}`);
      if (params.operation === 'next') { this.nextEvent(formId); }
    } catch (error) {
      console.error(`[CARDLAB] MESSAGE_ERROR ${(error as Error).message}`);
    }
  }

  // 系统请求刷新时，读取这张卡片已经保存的活动并重新提交（活动不变，只换刷新时间）
  private async refreshSaved(id: string): Promise<void> {
    try {
      const saved = await ensureCard(this.context, id);
      await this.push(id, saved, '系统刷新');
    } catch (error) { console.error(`[CARDLAB] SYSTEM_ERROR id=${id} ${(error as Error).message}`); }
  }

  // 周期刷新、每日时刻刷新和 setFormNextRefreshTime 申请到期后，系统都通过这里回调
  onUpdateForm(formId: string): void {
    console.info(`[CARDLAB] UPDATE id=${formId} source=system`);
    this.refreshSaved(formId);
  }

  // 卡片从桌面移除时，同步删掉这条实例记录，避免数据库留下取不到卡片的孤儿行
  onRemoveForm(formId: string): void {
    removeCard(this.context, formId).catch((error: Error) => {
      console.error(`[CARDLAB] REMOVE_ERROR ${error.message}`);
    });
  }
}
