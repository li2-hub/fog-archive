/**
 * 结局页：把存档里这一次调查的结果摊开复盘。
 * 状态来源只有存档（场景页在结局时已落盘），所以这里不接收跨页参数，冷启动直接进来也不会空。
 */
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ClueDef, DeductionDef, EndingDetail, EndingId, FinalChoice, GameState } from '../model/Types';
import { CLUES, DEDUCTIONS, deductionName } from '../model/StoryGraph';
import { endingDetail } from '../engine/EndingResolver';
import { ReviewItem, ReviewStats, reviewStats } from '../engine/Review';
import { clearState, LoadOutcome, loadState } from '../store/SaveRepository';

const C_BG: string = '#0B0C0F';
const C_CARD: string = '#14161A';
const C_LINE: string = '#2A2D33';
const C_TEXT: string = '#E9E6E0';
const C_MUTED: string = '#868C96';
const C_ACCENT: string = '#D8A657';
const C_WARN: string = '#C2685C';
const C_OK: string = '#7FA37A';

@Entry
@Component
struct EndingPage {
  @State private ready: boolean = false;
  @State private ended: boolean = false;
  @State private endingTitle: string = '';
  @State private endingSummary: string = '';
  @State private endingMissing: string[] = [];
  @State private stats: ReviewStats = new ReviewStats();
  @State private finalChoice: FinalChoice = FinalChoice.NONE;
  /** 存档里的线索与推论清单，用于把"6 条线索"逐条标成已归档 / 未归档 */
  @State private collected: string[] = [];
  @State private deductions: string[] = [];
  /** 逐条浮现的进度：条件与线索按顺序淡入，避免一屏文字同时砸下来 */
  @State private reveal: number = 0;

  aboutToAppear(): void {
    this.load().catch((error: Error) => {
      console.error(`[FOG] ENDING_LOAD_FAILED ${error.message}`);
      this.ready = true;
    });
  }

  private async load(): Promise<void> {
    const context: common.Context = getContext(this) as common.Context;
    const outcome: LoadOutcome = await loadState(context);
    if (outcome.ok && outcome.state.endingId !== EndingId.NONE) {
      const state: GameState = outcome.state;
      const detail: EndingDetail = endingDetail(state.endingId, state, state.finalChoice);
      this.endingTitle = detail.title;
      this.endingSummary = detail.summary;
      this.endingMissing = detail.missing;
      this.finalChoice = state.finalChoice;
      this.collected = state.collectedClues.slice();
      this.deductions = state.deductions.slice();
      this.stats = reviewStats(state, state.finalChoice);
      this.ended = true;
      this.startReveal(0, this.stats.items.length + CLUES.length);
    }
    this.ready = true;
  }

  /** 用递归的定时器逐格推进，避免循环里闭包捕获同一个计数变量 */
  private startReveal(index: number, total: number): void {
    if (index >= total) {
      return;
    }
    setTimeout(() => {
      this.reveal = index + 1;
      this.startReveal(index + 1, total);
    }, 90);
  }

  private async again(): Promise<void> {
    const context: common.Context = getContext(this) as common.Context;
    await clearState(context);
    router.replaceUrl({ url: 'final/pages/FogScene' });
  }

  private visible(index: number): number {
    return this.reveal > index ? 1 : 0;
  }

  // ---------------- 视图 ----------------

  @Builder
  header() {
    Column({ space: 12 }) {
      Row() {
        Text('‹ 回到现场')
          .fontSize(14)
          .fontColor(C_MUTED)
          .onClick(() => {
            router.back();
          })
        Blank()
        Text('FILE 05 / 已归档')
          .fontSize(11)
          .fontColor(C_MUTED)
          .letterSpacing(2)
      }
      .width('100%')

      Text(this.ended ? '档案封存' : '档案还没有封存')
        .fontSize(11)
        .fontColor(C_ACCENT)
        .letterSpacing(3)
        .width('100%')
    }
    .width('100%')
    .padding({ top: 14, bottom: 16 })
  }

  @Builder
  endingCard() {
    Column({ space: 12 }) {
      Text(this.endingTitle)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(C_TEXT)
        .width('100%')

      Row({ space: 10 }) {
        Text(this.finalChoice === FinalChoice.SUBMIT ? '提交完整证据链' : '只交人情')
          .fontSize(11)
          .fontColor(this.stats.missCount === 0 ? C_OK : C_WARN)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.stats.missCount === 0 ? '#131A12' : '#1A1512')
          .borderRadius(3)
        Text(this.stats.missCount === 0 ? '证据链闭合' : `还差 ${this.stats.missCount} 项条件`)
          .fontSize(11)
          .fontColor(C_MUTED)
      }
      .width('100%')

      Text(this.endingSummary)
        .fontSize(14)
        .fontColor('#B9BDC4')
        .lineHeight(24)
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(C_CARD)
    .borderRadius(6)
    .border({ width: 1, color: C_LINE })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  statCell(value: string, label: string, percent: number, showBar: boolean) {
    Column({ space: 6 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(C_TEXT)
        .width('100%')
      Text(label)
        .fontSize(11)
        .fontColor(C_MUTED)
        .width('100%')
      if (showBar) {
        Progress({ value: percent, total: 100, type: ProgressType.Linear })
          .color(C_ACCENT)
          .backgroundColor(C_LINE)
          .height(2)
          .width('100%')
      }
    }
    .layoutWeight(1)
    .padding(12)
    .backgroundColor(C_CARD)
    .borderRadius(6)
    .border({ width: 1, color: C_LINE })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  statGrid() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        this.statCell(`${this.stats.clueCount} / ${this.stats.clueTotal}`, '线索收集', this.stats.cluePercent, true)
        this.statCell(`${this.stats.deductionCount} / ${this.stats.deductionTotal}`, '推论成立',
          this.stats.deductionPercent, true)
      }
      .width('100%')

      Row({ space: 8 }) {
        this.statCell(`${this.stats.timeUsed} 分`, '调查用时', 0, false)
        this.statCell(`${this.stats.timeLeft} 分`, '剩余时限', 0, false)
        this.statCell(`${this.stats.turn} 步`, '决策次数', 0, false)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  conditionList() {
    Column({ space: 8 }) {
      Text('结局条件回放')
        .fontSize(11)
        .fontColor(C_ACCENT)
        .letterSpacing(2)
        .width('100%')

      ForEach(this.stats.items, (item: ReviewItem, index: number) => {
        Row({ space: 10 }) {
          Text(item.ok ? '✓' : '✗')
            .fontSize(13)
            .fontColor(item.ok ? C_OK : C_WARN)
          Column({ space: 3 }) {
            Text(item.label)
              .fontSize(13)
              .fontColor(item.ok ? C_TEXT : '#8E929A')
              .width('100%')
            Text(item.note)
              .fontSize(11)
              .fontColor(C_MUTED)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(C_CARD)
        .borderRadius(6)
        .border({ width: 1, color: item.ok ? C_LINE : '#241A18' })
        .opacity(this.visible(index))
        .translate({ y: this.visible(index) === 1 ? 0 : 10 })
      }, (item: ReviewItem) => item.label)
    }
    .width('100%')
  }

  @Builder
  clueList(baseIndex: number) {
    Column({ space: 6 }) {
      Text('全部线索')
        .fontSize(11)
        .fontColor(C_ACCENT)
        .letterSpacing(2)
        .width('100%')

      ForEach(CLUES, (clue: ClueDef, index: number) => {
        Row({ space: 10 }) {
          Text(this.hasClueText(clue.id))
            .fontSize(12)
            .fontColor(this.stats.clueCount > 0 && this.isCollected(clue.id) ? C_OK : '#3C4048')
          Column({ space: 3 }) {
            Text(clue.name)
              .fontSize(13)
              .fontColor(this.isCollected(clue.id) ? C_TEXT : '#4E535B')
              .width('100%')
            Text(this.isCollected(clue.id) ? clue.summary : '没有归档')
              .fontSize(11)
              .fontColor(this.isCollected(clue.id) ? C_MUTED : '#3C4048')
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.isCollected(clue.id) ? C_CARD : '#0F1013')
        .borderRadius(6)
        .border({ width: 1, color: this.isCollected(clue.id) ? C_LINE : '#1B1D22' })
        .opacity(this.visible(baseIndex + index))
        .translate({ y: this.visible(baseIndex + index) === 1 ? 0 : 10 })
      }, (clue: ClueDef) => clue.id)
    }
    .width('100%')
  }

  private isCollected(id: string): boolean {
    return this.collected.includes(id);
  }

  private isDeduced(id: string): boolean {
    return this.deductions.includes(id);
  }

  private hasClueText(id: string): string {
    return this.isCollected(id) ? '✓' : '·';
  }

  @Builder
  deductionList() {
    Column({ space: 6 }) {
      Text('推论')
        .fontSize(11)
        .fontColor(C_ACCENT)
        .letterSpacing(2)
        .width('100%')
      ForEach(DEDUCTIONS, (item: DeductionDef) => {
        Row({ space: 10 }) {
          Text(this.isDeduced(item.id) ? '✓' : '✗')
            .fontSize(12)
            .fontColor(this.isDeduced(item.id) ? C_OK : '#3C4048')
          Text(deductionName(item.id))
            .fontSize(13)
            .fontColor(this.isDeduced(item.id) ? C_TEXT : '#4E535B')
        }
        .width('100%')
        .padding(12)
        .backgroundColor(C_CARD)
        .borderRadius(6)
        .border({ width: 1, color: C_LINE })
      }, (item: DeductionDef) => item.id)
    }
    .width('100%')
  }

  @Builder
  missingBlock() {
    Column({ space: 6 }) {
      Text('档案里没写完的部分')
        .fontSize(11)
        .fontColor(C_WARN)
        .width('100%')
      ForEach(this.endingMissing, (item: string) => {
        Text(`· ${item}`)
          .fontSize(12)
          .fontColor(C_MUTED)
          .lineHeight(20)
          .width('100%')
      }, (item: string) => item)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#1A1512')
    .borderRadius(6)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  emptyBlock() {
    Column({ space: 12 }) {
      Text('这份档案还没有结局')
        .fontSize(15)
        .fontColor(C_TEXT)
      Text('把调查推进到最终判断，档案才会封存。点下面的按钮回到现场。')
        .fontSize(12)
        .fontColor(C_MUTED)
        .lineHeight(20)
      Button('回到现场')
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor('#141414')
        .backgroundColor(C_ACCENT)
        .borderRadius(4)
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(C_CARD)
    .borderRadius(6)
    .border({ width: 1, color: C_LINE })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  footer() {
    Column({ space: 10 }) {
      Button('再 来 一 次')
        .width('100%')
        .height(48)
        .fontSize(15)
        .fontColor('#141414')
        .backgroundColor(C_ACCENT)
        .borderRadius(4)
        .onClick(() => {
          this.again();
        })
      Button('回到标题')
        .width('100%')
        .height(44)
        .fontSize(13)
        .fontColor(C_MUTED)
        .backgroundColor(C_CARD)
        .borderRadius(4)
        .onClick(() => {
          router.replaceUrl({ url: 'final/pages/FinalIndex' });
        })
    }
    .width('100%')
    .padding({ top: 12, bottom: 24 })
  }

  build() {
    Column() {
      if (!this.ready) {
        Column({ space: 12 }) {
          Text('正在调阅档案')
            .fontSize(13)
            .fontColor(C_MUTED)
            .letterSpacing(3)
          Text('· · ·')
            .fontSize(13)
            .fontColor(C_LINE)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        this.header()
        Scroll() {
          Column({ space: 16 }) {
            if (this.ended) {
              this.endingCard()
              this.statGrid()
              this.conditionList()
              if (this.endingMissing.length > 0) {
                this.missingBlock()
              }
              this.clueList(this.stats.items.length)
              this.deductionList()
            } else {
              this.emptyBlock()
            }
            this.footer()
          }
          .width('100%')
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
    .backgroundColor(C_BG)
  }
}
