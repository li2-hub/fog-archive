import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import {
  ApplyResult, ChoiceAvailability, ChoiceDef, ClueDef, DeduceResult, EndingDetail, EndingId, GameState, SceneDef,
  StoryNode
} from '../model/Types';
import { applyChoiceById, createInitialState, isChoiceAvailable, progressPercent, stageName } from '../engine/GameEngine';
import { CLUES, clueName, deductionName, nodeById, sceneById } from '../model/StoryGraph';
import { endingDetail } from '../engine/EndingResolver';
import { tryDeduce } from '../engine/Deduction';
import { LoadOutcome, loadState, saveState } from '../store/SaveRepository';

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
  /** 存档读取是异步的，读完前不要渲染场景，否则会闪一下"记者站·傍晚"的假初始节点 */
  @State private ready: boolean = false;
  /** 线索入袋的浮层提示：新线索出现时短暂亮一下，让"选择真的改变了状态"看得见 */
  @State private flashText: string = '';
  @State private flashOn: boolean = false;
  /** 推理成功后的结论卡；推理失败时整块面板横向抖一下 */
  @State private conclusion: string = '';
  @State private shakeX: number = 0;
  @State private appear: number = 0;

  aboutToAppear(): void {
    this.restoreOrStart().catch((error: Error) => {
      console.error(`[FOG] RESTORE_FAILED ${error.message}`);
      this.restart();
      this.ready = true;
    });
    animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
      this.appear = 1;
    });
  }

  /** 优先恢复存档；没有或不可信时开新档，并把降级原因告诉玩家 */
  private async restoreOrStart(): Promise<void> {
    const context: common.Context = getContext(this) as common.Context;
    const outcome: LoadOutcome = await loadState(context);
    if (outcome.ok) {
      this.state = outcome.state;
      this.applyEndingView(outcome.state);
      this.ready = true;
      return;
    }
    this.restart();
    this.ready = true;
    if (outcome.reason !== '' && outcome.reason !== '没有可恢复的存档') {
      promptAction.showToast({ message: outcome.reason, duration: 2600 });
    }
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
    this.flashOn = false;
    this.flashText = '';
    this.conclusion = '';
    this.shakeX = 0;
    this.persist();
  }

  /**
   * 每次状态变更后立即落盘。这里的操作频率是"一次点击一次写入"，
   * 不需要节流；节流反而有丢掉最后一次写入的风险。
   */
  private persist(): void {
    const context: common.Context = getContext(this) as common.Context;
    saveState(context, this.state)
      .then((ok: boolean) => {
        if (!ok) {
          console.warn('[FOG] 存档写入失败，本次进度可能不会被恢复');
        }
      })
      .catch((error: Error) => {
        console.error(`[FOG] PERSIST_FAILED ${error.message}`);
      });
  }

  private applyEndingView(state: GameState): void {
    if (state.endingId === EndingId.NONE) {
      return;
    }
    const detail: EndingDetail = endingDetail(state.endingId, state, state.finalChoice);
    this.endingTitle = detail.title;
    this.endingSummary = detail.summary;
    this.endingMissing = detail.missing;
    this.reachedEnding = true;
  }

  private confirmRestart(): void {
    AlertDialog.show({
      title: '重新调查',
      message: '当前进度会被清空，从案件开头重新开始。这条存档不会保留。',
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '重新开始',
        fontColor: C_WARN,
        action: () => {
          this.restart();
        }
      }
    });
  }

  /** 退到后台或被系统回收前再写一次，兜住最后一次可能没落盘的状态 */
  onPageHide(): void {
    this.persist();
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
    const before: string[] = this.state.collectedClues.slice();
    const result: ApplyResult = applyChoiceById(this.state, choice.id, Date.now());
    if (!result.ok) {
      promptAction.showToast({ message: result.reason, duration: 1800 });
      return;
    }
    const fresh: string[] = result.state.collectedClues.filter((id: string) => !before.includes(id));
    // 包在 animateTo 里，HUD 的进度条与线索计数会平滑过渡，而不是一步跳到位
    animateTo({ duration: 280, curve: Curve.EaseOut }, () => {
      this.state = result.state;
    });
    this.applyEndingView(result.state);
    this.persist();
    if (fresh.length > 0) {
      this.showFlash(fresh);
    }
  }

  /** 线索入袋的浮层：淡入 → 停 2 秒 → 淡出，纯提示，不拦截任何点击 */
  private showFlash(ids: string[]): void {
    let names: string = '';
    for (const id of ids) {
      names = names === '' ? `「${clueName(id)}」` : `${names}、「${clueName(id)}」`;
    }
    this.flashText = `已归档 ${names}`;
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.flashOn = true;
    });
    setTimeout(() => {
      animateTo({ duration: 320, curve: Curve.EaseInOut }, () => {
        this.flashOn = false;
      });
    }, 2000);
  }

  /** 推理不成立时让面板横向抖一下，比只弹一个 toast 更容易被注意到 */
  private shake(): void {
    animateTo({ duration: 60, curve: Curve.Linear }, () => {
      this.shakeX = -6;
    });
    setTimeout(() => {
      animateTo({ duration: 60, curve: Curve.Linear }, () => {
        this.shakeX = 6;
      });
      setTimeout(() => {
        animateTo({ duration: 90, curve: Curve.Linear }, () => {
          this.shakeX = 0;
        });
      }, 70);
    }, 70);
  }

  /** 结局页的状态源是存档，跳转前确保这一笔已经落盘 */
  private openReview(): void {
    const context: common.Context = getContext(this) as common.Context;
    saveState(context, this.state)
      .catch((error: Error) => {
        console.error(`[FOG] PERSIST_BEFORE_REVIEW_FAILED ${error.message}`);
      })
      .finally(() => {
        router.pushUrl({ url: 'final/pages/EndingPage' });
      });
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
      this.shake();
      promptAction.showToast({ message: result.reason, duration: 2000 });
      return;
    }
    animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.state = result.state;
      // 结论直接留在板上，玩家回到现场后还能翻回来看
      this.conclusion = result.conclusion;
    });
    this.pickA = '';
    this.pickB = '';
    this.persist();
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
        Text('↻ 重开')
          .fontSize(12)
          .fontColor(C_MUTED)
          .margin({ left: 16 })
          .onClick(() => {
            this.confirmRestart();
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
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.endingMissing.length > 0) {
        Text(`还有 ${this.endingMissing.length} 项条件没有闭合，完整复盘里能看到差在哪`)
          .fontSize(11)
          .fontColor(C_WARN)
          .width('100%')
      }

      Button('查看完整复盘 ›')
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor('#141414')
        .backgroundColor(C_ACCENT)
        .borderRadius(4)
        .onClick(() => {
          this.openReview();
        })
      Text('重新调查')
        .fontSize(13)
        .fontColor(C_MUTED)
        .onClick(() => {
          this.restart();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(C_CARD)
    .borderRadius(6)
    .border({ width: 1, color: C_LINE })
    .alignItems(HorizontalAlign.Start)
  }

  /** 新线索入袋时的浮层；用绝对定位钉在顶部条下方，不参与正文排版 */
  @Builder
  clueFlash() {
    Row({ space: 8 }) {
      Text('✓')
        .fontSize(12)
        .fontColor(C_ACCENT)
      Text(this.flashText)
        .fontSize(12)
        .fontColor(C_TEXT)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor('#1B1710')
    .borderRadius(4)
    .border({ width: 1, color: C_ACCENT })
    .opacity(this.flashOn ? 1 : 0)
    .translate({ y: this.flashOn ? 0 : -8 })
    // 没有提示时保留占位（避免正文上下跳动），但整块隐藏，不要让 ✓ 单独留在页面上
    .visibility(this.flashText === '' ? Visibility.Hidden : Visibility.Visible)
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

        if (this.conclusion !== '') {
          Column({ space: 6 }) {
            Row() {
              Text('推论成立')
                .fontSize(11)
                .fontColor(C_ACCENT)
                .letterSpacing(2)
              Blank()
              Text('收起')
                .fontSize(11)
                .fontColor(C_MUTED)
                .onClick(() => {
                  animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
                    this.conclusion = '';
                  });
                })
            }
            .width('100%')
            Text(this.conclusion)
              .fontSize(13)
              .fontColor('#C3C7CD')
              .lineHeight(22)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#1B1710')
          .borderRadius(6)
          .border({ width: 1, color: C_ACCENT })
          .alignItems(HorizontalAlign.Start)
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -8 })))
        }

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
    // 推理不成立时的抖动作用在整块面板上，正文不重排
    .translate({ x: this.shakeX })
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
      if (!this.ready) {
        Column({ space: 12 }) {
          Text('正在读取档案')
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
      } else if (this.boardOpen) {
        this.boardTopBar()
        this.boardBody()
        if (this.pickA !== '' && this.pickB !== '') {
          this.boardAction()
        }
      } else {
        this.topBar()
        this.clueFlash()
        this.sceneBody()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20 })
    .backgroundColor(C_BG)
    .opacity(this.appear)
    .translate({ y: this.appear === 1 ? 0 : 12 })
  }
}
