import { promptAction, router } from '@kit.ArkUI';
import {
  ApplyResult, ChoiceAvailability, ChoiceDef, EndingDetail, EndingId, GameState, SceneDef, StoryNode
} from '../model/Types';
import { applyChoiceById, createInitialState, isChoiceAvailable, progressPercent, stageName } from '../engine/GameEngine';
import { CLUES, clueName, nodeById, sceneById } from '../model/StoryGraph';
import { endingDetail } from '../engine/EndingResolver';

const C_BG: string = '#0B0C0F';
const C_CARD: string = '#14161A';
const C_LINE: string = '#2A2D33';
const C_TEXT: string = '#E9E6E0';
const C_MUTED: string = '#868C96';
const C_ACCENT: string = '#D8A657';
const C_WARN: string = '#C2685C';

@Entry
@Component
struct FogScene {
  @State private state: GameState = new GameState();
  @State private endingTitle: string = '';
  @State private endingSummary: string = '';
  @State private endingMissing: string[] = [];
  @State private reachedEnding: boolean = false;

  aboutToAppear(): void {
    this.restart();
  }

  private restart(): void {
    this.state = createInitialState(Date.now());
    this.endingTitle = '';
    this.endingSummary = '';
    this.endingMissing = [];
    this.reachedEnding = false;
  }

  /** build 里不处理 undefined，统一在这里兜底 */
  private node(): StoryNode {
    const found: StoryNode | undefined = nodeById(this.state.currentNodeId);
    if (found !== undefined) {
      return found;
    }
    const first: StoryNode | undefined = nodeById('n_accept');
    return first as StoryNode;
  }

  private sceneName(): string {
    const node: StoryNode = this.node();
    const scene: SceneDef | undefined = sceneById(node.sceneId);
    return scene === undefined ? '未知现场' : `${scene.name} · ${scene.subtitle}`;
  }

  private available(choice: ChoiceDef): ChoiceAvailability {
    return isChoiceAvailable(choice, this.state);
  }

  private apply(choice: ChoiceDef): void {
    const result: ApplyResult = applyChoiceById(this.state, choice.id, Date.now());
    if (!result.ok) {
      promptAction.showToast({ message: result.reason, duration: 1800 });
      return;
    }
    this.state = result.state;
    if (result.state.endingId !== EndingId.NONE) {
      const detail: EndingDetail = endingDetail(result.state.endingId, result.state, choice.finalChoice);
      this.endingTitle = detail.title;
      this.endingSummary = detail.summary;
      this.endingMissing = detail.missing;
      this.reachedEnding = true;
    }
  }

  @Builder
  topBar() {
    Column({ space: 10 }) {
      Row() {
        Text('‹ 档案')
          .fontSize(14)
          .fontColor(C_MUTED)
          .onClick(() => {
            router.back();
          })
        Blank()
        Row({ space: 6 }) {
          Text(stageName(this.state.stage))
            .fontSize(11)
            .fontColor(C_ACCENT)
            .letterSpacing(1)
          Text('·').fontSize(11).fontColor(C_LINE)
          Text(`剩 ${this.state.timeLeft} 分`)
            .fontSize(11)
            .fontColor(this.state.timeLeft < 60 ? C_WARN : C_MUTED)
        }
      }
      .width('100%')

      Progress({ value: progressPercent(this.state), total: 100, type: ProgressType.Linear })
        .color(C_ACCENT)
        .backgroundColor(C_LINE)
        .height(2)
        .width('100%')
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
  }

  @Builder
  choiceRow(choice: ChoiceDef) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(choice.label)
          .fontSize(15)
          .fontColor(this.available(choice).ok ? C_TEXT : '#5A5F68')
          .width('100%')
        Text(this.available(choice).ok ? choice.hint : this.available(choice).reason)
          .fontSize(11)
          .fontColor(this.available(choice).ok ? C_MUTED : C_WARN)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${choice.cost}′`)
        .fontSize(12)
        .fontColor(this.available(choice).ok ? C_ACCENT : '#3C4048')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(C_CARD)
    .borderRadius(6)
    .border({ width: 1, color: this.available(choice).ok ? C_LINE : '#1B1D22' })
    .opacity(this.available(choice).ok ? 1 : 0.55)
    .onClick(() => {
      this.apply(choice);
    })
  }

  @Builder
  endingBlock() {
    Column({ space: 12 }) {
      Text('档案封存')
        .fontSize(11)
        .fontColor(C_ACCENT)
        .letterSpacing(3)
      Text(this.endingTitle)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(C_TEXT)
      Text(this.endingSummary)
        .fontSize(14)
        .fontColor('#B9BDC4')
        .lineHeight(24)

      if (this.endingMissing.length > 0) {
        Column({ space: 6 }) {
          Text('证据链未闭合的部分')
            .fontSize(11)
            .fontColor(C_WARN)
          ForEach(this.endingMissing, (item: string) => {
            Text(`· ${item}`).fontSize(12).fontColor(C_MUTED).width('100%')
          })
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#1A1512')
        .borderRadius(4)
        .alignItems(HorizontalAlign.Start)
      }

      Row({ space: 10 }) {
        Button('重新调查')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor('#141414')
          .backgroundColor(C_ACCENT)
          .borderRadius(4)
          .onClick(() => {
            this.restart();
          })
        Button('回到标题')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(C_MUTED)
          .backgroundColor(C_CARD)
          .borderRadius(4)
          .onClick(() => {
            router.back();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(C_CARD)
    .borderRadius(6)
    .border({ width: 1, color: C_LINE })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.topBar()

      Scroll() {
        Column({ space: 16 }) {
          Text(this.sceneName())
            .fontSize(11)
            .fontColor(C_MUTED)
            .letterSpacing(1)
            .width('100%')

          Text(this.node().title)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(C_TEXT)
            .width('100%')

          Text(this.node().text)
            .fontSize(15)
            .fontColor('#C3C7CD')
            .lineHeight(27)
            .width('100%')

          Divider().color(C_LINE).margin({ top: 2 })

          if (this.reachedEnding) {
            this.endingBlock()
          } else {
            ForEach(this.node().choices, (choice: ChoiceDef) => {
              this.choiceRow(choice)
            }, (choice: ChoiceDef) => choice.id)
          }

          if (this.state.collectedClues.length > 0) {
            Column({ space: 8 }) {
              Text(`已归档线索 ${this.state.collectedClues.length} / ${CLUES.length}`)
                .fontSize(11)
                .fontColor(C_MUTED)
                .width('100%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.state.collectedClues, (id: string) => {
                  Text(clueName(id))
                    .fontSize(11)
                    .fontColor(C_ACCENT)
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .margin({ right: 6, bottom: 6 })
                    .backgroundColor('#1B1710')
                    .borderRadius(3)
                }, (id: string) => id)
              }
              .width('100%')
            }
            .width('100%')
            .padding({ top: 6 })
          }
        }
        .width('100%')
        .padding({ bottom: 32 })
      }
      .layoutWeight(1)
      // Scroll 在内容短于视口时默认把内容竖直居中，标题会浮在页面中间，
      // 这里显式顶对齐，保证正文永远贴着顶部条开始。
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
    .backgroundColor(C_BG)
  }
}
