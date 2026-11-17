import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { CLUES, DEDUCTIONS, NODES, SCENES } from '../model/StoryGraph';
import { START_MINUTES } from '../model/Types';
import { LoadOutcome, loadState } from '../store/SaveRepository';

/** 深色档案 + 琥珀强调 */
const C_BG: string = '#0B0C0F';
const C_CARD: string = '#14161A';
const C_LINE: string = '#2A2D33';
const C_TEXT: string = '#E9E6E0';
const C_MUTED: string = '#868C96';
const C_ACCENT: string = '#D8A657';

@Entry
@Component
struct FinalIndex {
  @State private shown: boolean = false;
  @State private glow: number = 0.25;
  @State private showCaseFile: boolean = false;
  /** 有存档时把按钮改成"继续调查"，并提示已记录到第几步 */
  @State private resumeTurn: number = 0;

  aboutToAppear(): void {
    animateTo({ duration: 650, curve: Curve.EaseOut }, () => {
      this.shown = true;
    });
    animateTo({ duration: 1600, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate }, () => {
      this.glow = 0.85;
    });
    this.checkSave();
  }

  /** 只读一次存档用于改文案，真正的恢复在场景页做，避免两处各写一份逻辑 */
  private async checkSave(): Promise<void> {
    try {
      const context: common.Context = getContext(this) as common.Context;
      const outcome: LoadOutcome = await loadState(context);
      if (outcome.ok && outcome.state.turn > 0) {
        this.resumeTurn = outcome.state.turn;
      }
    } catch (error) {
      const err = error as Error;
      console.error(`[FOG] CHECK_SAVE_FAILED ${err.message}`);
    }
  }

  @Builder
  caseFile() {
    Column({ space: 10 }) {
      Row() {
        Text('案件编号').fontSize(12).fontColor(C_MUTED).width(84)
        Text('AR-1105').fontSize(12).fontColor(C_TEXT)
      }.width('100%')

      Row() {
        Text('地点').fontSize(12).fontColor(C_MUTED).width(84)
        Text('图书馆 B1 闭架书库').fontSize(12).fontColor(C_TEXT)
      }.width('100%')

      Row() {
        Text('时限').fontSize(12).fontColor(C_MUTED).width(84)
        Text(`调查开始后 ${START_MINUTES} 分钟`).fontSize(12).fontColor(C_TEXT)
      }.width('100%')

      Row() {
        Text('可勘查点').fontSize(12).fontColor(C_MUTED).width(84)
        Text(`${SCENES.length} 处现场 / ${NODES.length} 个事件节点`).fontSize(12).fontColor(C_TEXT)
      }.width('100%')

      Row() {
        Text('可归档').fontSize(12).fontColor(C_MUTED).width(84)
        Text(`${CLUES.length} 条线索 / ${DEDUCTIONS.length} 条推论`).fontSize(12).fontColor(C_TEXT)
      }.width('100%')

      Divider().color(C_LINE).margin({ top: 4, bottom: 4 })

      Text('闭馆二十分钟后，B1 的灯还亮着一盏。值班表上写着"临时替班"，门禁记录里却只有一个人的名字。校方已经按"违规滞留"定了性，你有八分钟的时间差可以推翻它。')
        .fontSize(13)
        .fontColor(C_MUTED)
        .lineHeight(22)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(C_CARD)
    .borderRadius(6)
    .border({ width: 1, color: C_LINE })
  }

  build() {
    Column() {
      // 顶部编号
      Row({ space: 8 }) {
        Circle({ width: 6, height: 6 }).fill(C_ACCENT).opacity(this.glow)
        Text('FILE 05 / 未归档').fontSize(11).fontColor(C_MUTED).letterSpacing(2)
      }
      .width('100%')
      .padding({ top: 28 })

      Blank()

      Column({ space: 18 }) {
        Text('迷雾档案')
          .fontSize(46)
          .fontWeight(FontWeight.Bold)
          .fontColor(C_TEXT)
          .letterSpacing(10)

        Row({ space: 12 }) {
          Divider().color(C_LINE).layoutWeight(1)
          Text('八 分 钟').fontSize(13).fontColor(C_ACCENT).letterSpacing(3)
          Divider().color(C_LINE).layoutWeight(1)
        }
        .width('86%')

        Text('校园线索推理 · 多结局调查')
          .fontSize(13)
          .fontColor(C_MUTED)
          .letterSpacing(1)
      }
      .opacity(this.shown ? 1 : 0)
      .translate({ y: this.shown ? 0 : 18 })

      Blank()

      if (this.showCaseFile) {
        this.caseFile()
      }

      Column({ space: 12 }) {
        Button(this.resumeTurn > 0 ? '继 续 调 查' : '开 始 调 查')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontColor('#141414')
          .fontWeight(FontWeight.Medium)
          .backgroundColor(C_ACCENT)
          .borderRadius(4)
          .onClick(() => {
            router.pushUrl({ url: 'final/pages/FogScene' });
          })

        if (this.resumeTurn > 0) {
          Text(`上次记录停在第 ${this.resumeTurn} 步，进度已保存`)
            .fontSize(11)
            .fontColor(C_MUTED)
        }

        Text(this.showCaseFile ? '收起案件概要' : '先看案件概要')
          .fontSize(13)
          .fontColor(C_MUTED)
          .decoration({ type: TextDecorationType.Underline, color: C_LINE })
          .onClick(() => {
            animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
              this.showCaseFile = !this.showCaseFile;
            });
          })
      }
      .width('100%')

      Text(`${NODES.length} 个节点 · ${CLUES.length} 条线索 · 2 种结局`)
        .fontSize(11)
        .fontColor('#5A5F68')
        .margin({ top: 22, bottom: 26 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
    .backgroundColor(C_BG)
  }
}
