import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { promptAction } from '@kit.ArkUI';
import { CampusEvent, EVENTS } from '../common/CampusData';
import { CardRecord, cardData, clockText, listCards, readCard, saveCard } from '../common/CardStore';

class ClockPatch {
  refreshedAt: string = clockText();
  refreshSource: string = '局部更新时间';
}

@Entry
@Component
struct Index {
  @StorageLink('activeFormId') private formId: string = '';
  @StorageLink('entrySource') private entrySource: string = 'app';
  @StorageLink('routeSerial') @Watch('routeArrived') private routeSerial: number = 0;
  @State private records: CardRecord[] = [];
  @State private draftIndex: number = 0;
  @State private draftCount: number = 3;
  @State private revision: number = 0;
  @State private ready: boolean = false;
  @State private saving: boolean = false;
  @State private retryAvailable: boolean = false;
  @State private showRecords: boolean = false;
  @State private logs: string = '';

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  aboutToAppear(): void { this.reload(); }
  private routeArrived(): void { this.reload(); }

  private async exitApp(): Promise<void> {
    try {
      this.record('EXIT');
      await this.context().terminateSelf();
    } catch (error) {
      this.notify('暂时无法退出，请重试');
      this.record(`EXIT_ERROR ${(error as Error).message}`);
    }
  }

  private notify(message: string): void { promptAction.showToast({ message: message }); }

  private record(value: string): void {
    console.info(`[CARDLAB] PAGE ${value}`);
    this.logs = (this.logs + value + '\n').slice(-4000);
  }

  private cover(index: number): Resource {
    return index === 0 ? $r('app.media.campus_photo') :
      (index === 1 ? $r('app.media.campus_lab') : $r('app.media.campus_run'));
  }

  private async reload(): Promise<void> {
    const id: string = this.formId;
    this.ready = false;
    this.retryAvailable = false;
    try {
      if (id.length === 0) {
        const list = await listCards(this.context());
        if (this.formId.length > 0) { return; }
        this.records = list;
        this.record(`LIST rows=${list.length}`);
      } else {
        const saved = await readCard(this.context(), id);
        if (id !== this.formId) { return; }
        if (saved === undefined) { this.notify('这张卡片已移除'); return; }
        this.draftIndex = saved.eventIndex;
        this.draftCount = saved.todoCount;
        this.revision = saved.revision;
        this.ready = true;
        this.record(`READ id=${id} index=${saved.eventIndex} count=${saved.todoCount} revision=${saved.revision}`);
      }
    } catch (error) {
      this.notify('暂时无法读取，请重试');
      this.record(`READ_ERROR ${(error as Error).message}`);
    }
  }

  private async saveDraft(): Promise<void> {
    const id: string = this.formId;
    this.saving = true;
    try {
      const saved = await saveCard(this.context(), id, this.draftIndex, this.draftCount);
      this.revision = saved.revision;
      this.record(`SAVE id=${id} index=${saved.eventIndex} count=${saved.todoCount} revision=${saved.revision}`);
      try {
        await formProvider.updateForm(id, formBindingData.createFormBindingData(cardData(saved, '页面保存')));
        this.notify('已保存');
        this.retryAvailable = false;
        this.record(`PUSH id=${id} source=页面保存`);
      } catch (error) {
        this.notify('已保存，暂未同步');
        this.retryAvailable = true;
        this.record(`PUSH_ERROR ${(error as Error).message}`);
      }
    } catch (error) {
      this.notify('保存失败，请重试');
      this.record(`SAVE_ERROR ${(error as Error).message}`);
    } finally { this.saving = false; }
  }

  private async retryPush(): Promise<void> {
    const id: string = this.formId;
    this.saving = true;
    try {
      const saved = await readCard(this.context(), id);
      if (saved === undefined) { throw new Error('卡片记录已移除'); }
      await formProvider.updateForm(id, formBindingData.createFormBindingData(cardData(saved, '重新提交')));
      this.notify('已同步');
      this.retryAvailable = false;
      this.record(`RETRY id=${id}`);
    } catch (error) {
      this.notify('同步失败，请稍后重试');
      this.record(`RETRY_ERROR ${(error as Error).message}`);
    }
    finally { this.saving = false; }
  }

  private async updateClock(): Promise<void> {
    try {
      const data = new ClockPatch();
      await formProvider.updateForm(this.formId, formBindingData.createFormBindingData(data));
      this.notify('时间已更新');
      this.record(`CLOCK id=${this.formId} at=${data.refreshedAt}`);
    } catch (error) {
      this.notify('刷新失败，请重试');
      this.record(`CLOCK_ERROR ${(error as Error).message}`);
    }
  }

  private async scheduleNext(): Promise<void> {
    try {
      await formProvider.setFormNextRefreshTime(this.formId, 5);
      this.notify('已预约刷新');
      this.record(`NEXT id=${this.formId} minute=5 requestedAt=${clockText()}`);
    } catch (error) {
      this.notify('预约失败，请重试');
      this.record(`NEXT_ERROR ${(error as Error).message}`);
    }
  }

  // 保存方法位置
  @Builder
  recordsSheet() {
    Column({ space: 14 }) {
      Row() {
        Text('更多').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#193853');
        Blank();
        Button('完成').fontSize(13).height(32).backgroundColor(Color.Transparent).fontColor('#287D76')
          .onClick(() => { this.showRecords = false; });
      }.width('100%');
      if (this.formId.length > 0) {
        Text(`编号 ${this.formId}`).fontSize(12).fontColor('#6D8297');
        Text(`来源：${this.entrySource === 'card' ? '桌面卡片' : '应用列表'} · 版本 ${this.revision}`)
          .fontSize(12).fontColor('#6D8297');
        Row({ space: 10 }) {
          Button('刷新时间').fontSize(12).height(38).layoutWeight(1).enabled(this.ready && !this.saving)
            .onClick(() => { this.updateClock(); });
          Button('5分钟后刷新').fontSize(12).height(38).layoutWeight(1).enabled(this.ready && !this.saving)
            .onClick(() => { this.scheduleNext(); });
        }.width('100%');

        // 系统刷新按钮位置
      }
      Divider().color('#E1E8EF');
      Text('操作记录').fontSize(14).fontColor('#45637E');
      Scroll() { Text(this.logs).fontSize(12).width('100%').fontColor('#415F7A'); }
        .width('100%').layoutWeight(1).align(Alignment.TopStart);
    }.width('100%').height('100%').padding(20);
  }

  @Builder
  cardList() {
    Column({ space: 12 }) {
      Row() {
        Text(`${this.records.length} 张卡片`).fontSize(14).fontColor('#6D8297');
        Blank();
        Button('刷新').fontSize(12).height(30).backgroundColor(Color.Transparent).fontColor('#287D76')
          .onClick(() => { this.reload(); });
      }.width('100%');
      ForEach(this.records, (item: CardRecord) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 14 }) {
            Image(this.cover(item.eventIndex)).width(78).height(70).objectFit(ImageFit.Cover).borderRadius(12);
            Column({ space: 7 }) {
              Text(EVENTS[item.eventIndex].title).fontSize(17).fontColor('#193853');
              Text(`${EVENTS[item.eventIndex].time} · ${item.todoCount}项待办`)
                .fontSize(12).fontColor('#6D8297');
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
          }.width('100%');
        }.width('100%').padding(12).borderRadius(18).backgroundColor('#FFFFFF')
        .onClick(() => { this.formId = item.formId; this.entrySource = 'app'; this.reload(); });
      }, (item: CardRecord) => `${item.formId}-${item.revision}-${item.eventIndex}-${item.todoCount}`);
      if (this.records.length === 0) {
        Text('暂无卡片').fontSize(18).fontColor('#45637E');
        Text('长按应用图标添加卡片').fontSize(13).fontColor('#6D8297');
      }
    }.width('100%').alignItems(HorizontalAlign.Start);
  }

  @Builder
  editor() {
    Column({ space: 16 }) {
      if (this.ready) {
        Column({ space: 10 }) {
          Image(this.cover(this.draftIndex)).width('100%').height(140).objectFit(ImageFit.Cover).borderRadius(16);
          Text(EVENTS[this.draftIndex].title).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#193853');
          Text(`${EVENTS[this.draftIndex].time} · ${EVENTS[this.draftIndex].place}`)
            .fontSize(14).fontColor('#45637E');
        }.width('100%').padding(16).alignItems(HorizontalAlign.Start)
        .backgroundColor('#FFFFFF').borderRadius(20);
        Text('活动').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#193853');
        Row({ space: 8 }) {
          ForEach(EVENTS, (item: CampusEvent, index: number) => {
            Button(item.title).fontSize(11).padding(6).height(44).layoutWeight(1)
              .backgroundColor(this.draftIndex === index ? '#287D76' : '#DCE7F2')
              .fontColor(this.draftIndex === index ? '#FFFFFF' : '#294C74').enabled(!this.saving)
              .onClick(() => { this.draftIndex = index; this.draftCount = item.todoCount; });
          }, (item: CampusEvent) => item.title);
        }.width('100%');
        Row({ space: 16 }) {
          Text('待办数量').fontSize(16).fontColor('#193853').layoutWeight(1);
          Button('－').width(38).height(38).padding(0).fontSize(20).enabled(!this.saving)
            .backgroundColor('#E8F1F0').fontColor('#287D76')
            .onClick(() => { this.draftCount = Math.max(0, this.draftCount - 1); });
          Text(this.draftCount.toString()).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#287D76');
          Button('＋').width(38).height(38).padding(0).fontSize(20).enabled(!this.saving)
            .backgroundColor('#E8F1F0').fontColor('#287D76')
            .onClick(() => { this.draftCount = Math.min(9, this.draftCount + 1); });
        }.width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(16);
        Button(this.saving ? '保存中…' : '保存').width('100%').height(46)
          .backgroundColor('#287D76').enabled(!this.saving).onClick(() => { this.saveDraft(); });
        if (this.retryAvailable) {
          Button('重试同步').width('100%').enabled(!this.saving).onClick(() => { this.retryPush(); });
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Start);
  }

  // 页面Builder位置

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row({ space: 10 }) {
          if (this.formId.length > 0) {
            Button('返回').fontSize(12).height(32).enabled(!this.saving)
              .backgroundColor(Color.Transparent).fontColor('#45637E').padding({ left: 0, right: 8 })
              .onClick(() => { this.formId = ''; this.entrySource = 'app'; this.reload(); });
          }
          Text(this.formId.length > 0 ? '编辑卡片' : '校园日程')
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#193853').layoutWeight(1);
          Button(this.formId.length > 0 ? '更多' : '退出').fontSize(12).height(32).enabled(!this.saving)
            .backgroundColor('#E1EBEF').fontColor('#45637E').padding({ left: 12, right: 12 })
            .onClick(() => {
              if (this.formId.length > 0) { this.showRecords = true; }
              else { this.exitApp(); }
            })
            .bindSheet($$this.showRecords, this.recordsSheet(), { height: '75%', showClose: false });
        }.width('100%');

        // 页头位置
        if (this.formId.length === 0) { this.cardList(); }
        else { this.editor(); }

        // 编辑页面调用位置
      }.width('100%').padding(20).alignItems(HorizontalAlign.Start);

    }.width('100%').height('100%').align(Alignment.TopStart).backgroundColor('#EEF3F9');
  }
}
