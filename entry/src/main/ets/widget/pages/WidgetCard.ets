const cardStorage: LocalStorage = new LocalStorage();

@Entry(cardStorage)
@Component
struct WidgetCard {
  @LocalStorageProp('formId') private formId: string = '';
  @LocalStorageProp('dimension') private dimension: number = 2;
  @LocalStorageProp('eventIndex') private eventIndex: number = 0;
  @LocalStorageProp('title') private title: string = '活动准备中';
  @LocalStorageProp('time') private time: string = '--';
  @LocalStorageProp('place') private place: string = '--';
  @LocalStorageProp('summary') private summary: string = '';
  @LocalStorageProp('todoCount') private todoCount: number = 0;
  @LocalStorageProp('refreshedAt') private refreshedAt: string = '';

  // 卡片状态位置

  private cover(): Resource {
    return this.eventIndex === 0 ? $r('app.media.campus_photo') :
      (this.eventIndex === 1 ? $r('app.media.campus_lab') : $r('app.media.campus_run'));
  }

  @Builder
  footer() {
    Column({ space: 3 }) {
      Row() {
        Text(`待办 ${this.todoCount} 项`).fontSize(9).fontWeight(FontWeight.Medium).fontColor('#24695F')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 }).backgroundColor('#E4F1EB').borderRadius(7);
        Blank();
        Text(this.refreshedAt).fontSize(9).fontColor('#7F90A4');
      }.width('100%');
      Row({ space: 6 }) {
        Button('换活动').fontSize(10).fontWeight(FontWeight.Medium).height(22).borderRadius(8).padding(0).layoutWeight(1)
          .backgroundColor('#287D76').fontColor('#FFFFFF')
          .onClick(() => { postCardAction(this, { action: 'message', params: { operation: 'next' } }); });
        Button('详情').fontSize(10).fontWeight(FontWeight.Medium).height(22).borderRadius(8).padding(0).layoutWeight(1)
          .backgroundColor('#E6EEF7').fontColor('#294C74')
          .onClick(() => {
            postCardAction(this, { action: 'router', abilityName: 'EntryAbility',
              params: { target: 'detail', formId: this.formId } });
          });
      }.width('100%');
    }.width('100%').height(42);
  }

  @Builder
  information(wide: boolean) {
    Column({ space: 3 }) {
      Text(this.title).fontSize(wide ? 17 : 15).fontWeight(FontWeight.Bold).fontColor('#193853')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.time).fontSize(11).fontColor('#45637E')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.place).fontSize(11).fontColor('#6D8297')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
      if (wide) {
        Text(this.summary).fontSize(11).fontColor('#6D8297')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      // 活动摘要位置
      Blank();
      this.footer();
    }.alignItems(HorizontalAlign.Start).width('100%').height('100%')
    .padding(wide ? 12 : 8).backgroundColor('#F7FAFC');
  }

  @Builder
  compactCard() {
    Column() {
      Image(this.cover()).width('100%').height(36).objectFit(ImageFit.Cover);
      Column() { this.information(false); }.width('100%').layoutWeight(1);
    }.width('100%').height('100%');
  }

  @Builder
  wideCard() {
    Row() {
      Image(this.cover()).width('36%').height('100%').objectFit(ImageFit.Cover);
      Column() { this.information(true); }.layoutWeight(1).height('100%');
    }.width('100%').height('100%');
  }

  build() {
    Column() {
      if (this.dimension === 3) {
        this.wideCard();
      } else {
        this.compactCard();
      }
    }.width('100%').height('100%');
  }
}
