import { promptAction, router } from '@kit.ArkUI';
import {
  ApplyResult, ChoiceAvailability, ChoiceDef, ClueDef, DeduceResult, EndingDetail, EndingId, GameState, SceneDef,
  StoryNode
} from '../model/Types';
import { applyChoiceById, createInitialState, isChoiceAvailable, progressPercent, stageName } from '../engine/GameEngine';
import { CLUES, clueName, deductionName, nodeById, sceneById } from '../model/StoryGraph';
import { endingDetail } from '../engine/EndingResolver';
import { tryDeduce } from '../engine/Deduction';

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
  /** 现场 / 线索板 两个视图在同一页面内切换，状态天然共享，不需要跨页传参 */
  @State private boardOpen: boolean = false;
  @State private pickA: string = '';
  @State private pickB: string = '';

  aboutToAppear(): void {
    this.restart();
  }

  private restart(): void {
    this.state = createInitialState(Date.now());
    this.endingTitle = '';
    this.endingSummary = '';
    this.endingMissing = [];
    this.reachedEnding = false;
    this.boardOpen = false;
    this.pickA = '';
    this.pickB = '';
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

  /** 当前节点是否已经没有任何可推进的选择（防止再次出现走不下去的死路） */
  private allBlocked(): boolean {
    if (this.reachedEnding) {
      return false;
    }
    const node: StoryNode = this.node();
    if (node.isEnding) {
      return false;
    }
    for (const choice of node.choices) {
      if (this.available(choice).ok) {
        return false;
      }
    }
    return true;
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

  private toggleClue(id: string): void {
    if (!this.state.hasClue(id)) {
      return;
    }
    if (this.pickA === id) {
      this.pickA = this.pickB;
      this.pickB = '';
      return;
    }
    if (this.pickB === id) {
      this.pickB = '';
      return;
    }
    if (this.pickA === '') {
      this.pickA = id;
      return;
    }
    if (this.pickB === '') {
      this.pickB = id;
      return;
    }
    this.pickA = id;
    this.pickB = '';
  }

  private deduce(): void {
    if (this.pickA === '' || this.pickB === '') {
      return;
    }
    const result: DeduceResult = tryDeduce(this.state, this.pickA, this.pickB, Date.now());
    if (!result.ok) {
      promptAction.showToast({ message: result.reason, duration: 2000 });
      return;
    }
    this.state = result.state;
    this.pickA = '';
    this.pickB = '';
    promptAction.showToast({ message: `推论成立：${deductionName(result.deductionId)}`, duration: 2400 });
  }

  // ---------------- 现场视图 ----------------

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
        Row({ space: 4 }) {
          Text('线索板')
            .fontSize(12)
            .fontColor(C_ACCENT)
          Text(`${this.state.collectedClues.length}/${CLUES.length}`)
            .fontSize(12)
            .fontColor(C_MUTED)
          Text('›')
            .fontSize(12)
            .fontColor(C_ACCENT)
        }
        .onClick(() => {
          this.pickA = '';
          this.pickB = '';
          this.boardOpen = true;
        })
      }
      .width('100%')

      Row() {
        Text(stageName(this.state.stage))
          .fontSize(11)
          .fontColor(C_MUTED)
          .letterSpacing(1)
        Blank()
        Text(`剩 ${this.state.timeLeft} 分`)
          .fontSize(11)
          .fontColor(this.state.timeLeft < 60 ? C_WARN : C_MUTED)
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

  @Builder
  deadlockBlock() {
    Column({ space: 10 }) {
      Text('没有能推进的选项')
        .fontSize(14)
        .fontColor(C_WARN)
      Text('上面的灰色选项写明了还缺什么。回线索板把手上已有的线索先拼一拼，或者从头再来一次。')
        .fontSize(12)
        .fontColor(C_MUTED)
        .lineHeight(20)
      Row({ space: 10 }) {
        Button('打开线索板')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .fontColor(C_ACCENT)
          .backgroundColor('#1B1710')
          .borderRadius(4)
          .onClick(() => {
            this.boardOpen = true;
          })
        Button('重新调查')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .fontColor('#141414')
          .backgroundColor(C_ACCENT)
          .borderRadius(4)
          .onClick(() => {
            this.restart();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(C_CARD)
    .borderRadius(6)
    .border({ width: 1, color: C_WARN })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  clueChips() {
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

  @Builder
  sceneBody() {
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
        } else if (this.allBlocked()) {
          this.deadlockBlock()
        } else {
          ForEach(this.node().choices, (choice: ChoiceDef) => {
            this.choiceRow(choice)
          }, (choice: ChoiceDef) => choice.id)
        }

        this.clueChips()
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

  // ---------------- 线索板视图 ----------------

  @Builder
  boardTopBar() {
    Column({ space: 10 }) {
      Row() {
        Text('‹ 回到现场')
          .fontSize(14)
          .fontColor(C_ACCENT)
          .onClick(() => {
            this.boardOpen = false;
          })
        Blank()
        Text(`推论 ${this.state.deductions.length} 条`)
          .fontSize(12)
          .fontColor(C_MUTED)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
  }

  @Builder
  clueCard(clue: ClueDef) {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(clue.name)
          .fontSize(14)
          .fontColor(C_TEXT)
          .width('100%')
        Text(clue.summary)
          .fontSize(11)
          .fontColor(C_MUTED)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.pickA === clue.id || this.pickB === clue.id) {
        Text(this.pickA === clue.id ? '①' : '②')
          .fontSize(14)
          .fontColor(C_ACCENT)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.pickA === clue.id || this.pickB === clue.id ? '#1B1710' : C_CARD)
    .borderRadius(6)
    .border({
      width: 1,
      color: this.pickA === clue.id || this.pickB === clue.id ? C_ACCENT : C_LINE
    })
    .onClick(() => {
      this.toggleClue(clue.id);
    })
  }

  @Builder
  lockedClueCard(clue: ClueDef) {
    Row({ space: 12 }) {
      Text(clue.name)
        .fontSize(14)
        .fontColor('#4E535B')
        .layoutWeight(1)
      Text('未归档')
        .fontSize(11)
        .fontColor('#3C4048')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#0F1013')
    .borderRadius(6)
    .border({ width: 1, color: '#1B1D22' })
    .opacity(0.7)
  }

  @Builder
  boardBody() {
    Scroll() {
      Column({ space: 14 }) {
        Text('线索板')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(C_TEXT)
          .width('100%')

        Text('选出任意两条已经归档的线索，看看它们能不能拼出一条推论。推论会解锁现场里原本灰色不可选的操作。')
          .fontSize(13)
          .fontColor(C_MUTED)
          .lineHeight(21)
          .width('100%')

        Divider().color(C_LINE)

        Text('已归档')
          .fontSize(11)
          .fontColor(C_ACCENT)
          .letterSpacing(2)
          .width('100%')

        ForEach(CLUES.filter((item: ClueDef) => this.state.hasClue(item.id)), (clue: ClueDef) => {
          this.clueCard(clue)
        }, (clue: ClueDef) => clue.id)

        Text('未归档')
          .fontSize(11)
          .fontColor(C_MUTED)
          .letterSpacing(2)
          .width('100%')
          .margin({ top: 6 })

        ForEach(CLUES.filter((item: ClueDef) => !this.state.hasClue(item.id)), (clue: ClueDef) => {
          this.lockedClueCard(clue)
        }, (clue: ClueDef) => `locked_${clue.id}`)

        Divider().color(C_LINE).margin({ top: 6 })

        Text('成立的推论')
          .fontSize(11)
          .fontColor(C_ACCENT)
          .letterSpacing(2)
          .width('100%')

        if (this.state.deductions.length === 0) {
          Text('还没有。两条对得上的线索放在一起，才会出现结论。')
            .fontSize(12)
            .fontColor(C_MUTED)
            .width('100%')
        } else {
          ForEach(this.state.deductions, (id: string) => {
            Row({ space: 10 }) {
              Text('✓')
                .fontSize(13)
                .fontColor(C_ACCENT)
              Text(deductionName(id))
                .fontSize(14)
                .fontColor(C_TEXT)
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#1B1710')
            .borderRadius(6)
          }, (id: string) => id)
        }
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .layoutWeight(1)
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  @Builder
  boardAction() {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        Text(`「${clueName(this.pickA)}」`)
          .fontSize(12)
          .fontColor(C_ACCENT)
        Text('+')
          .fontSize(12)
          .fontColor(C_MUTED)
        Text(`「${clueName(this.pickB)}」`)
          .fontSize(12)
          .fontColor(C_ACCENT)
      }

      Row({ space: 10 }) {
        Button('验证这组线索')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor('#141414')
          .backgroundColor(C_ACCENT)
          .borderRadius(4)
          .onClick(() => {
            this.deduce();
          })
        Button('清空')
          .width(84)
          .height(44)
          .fontSize(13)
          .fontColor(C_MUTED)
          .backgroundColor(C_CARD)
          .borderRadius(4)
          .onClick(() => {
            this.pickA = '';
            this.pickB = '';
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 12, bottom: 18 })
    .border({ width: { top: 1 }, color: C_LINE })
  }

  build() {
    Column() {
      if (this.boardOpen) {
        this.boardTopBar()
        this.boardBody()
        if (this.pickA !== '' && this.pickB !== '') {
          this.boardAction()
        }
      } else {
        this.topBar()
        this.sceneBody()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
    .backgroundColor(C_BG)
  }
}
