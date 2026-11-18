# 迷雾档案 · 开发计划（v1）

> 课程：《鸿蒙高级应用开发工程师认证》期末大作业
> 选题：主题一 迷雾档案——校园线索推理与多结局探索
> 形态：独立完成；在既有工程 `AdvancedStateLab` 内新增独立区域，原有实验代码零改动

---

## 1. 作品定位

一句话：**凌晨四点，图书馆闭馆清场时有人被反锁在 B1 书库，第二天校方给出的结论是"学生违规滞留"。你要在三个场景里找六条线索、做三次推理，决定这桩事是被掩盖、被误判，还是被说清。**

- 玩家身份：校学生记者站调查员
- 核心循环：**进入场景 → 触发事件节点 → 做选择（消耗"时间"） → 获得线索/改变标记 → 线索板上组合线索做推理 → 推理结果解锁新节点或结局条件 → 推进到最后判断**
- 失败不是"游戏结束"，而是**走进 B 结局**——这样"误判"也是作品的一部分，符合"2 个由不同条件触发的结局"

### 1.1 剧情骨架（12 个事件节点）

| # | 节点 ID | 场景 | 作用 | 关键产出 |
|---|---|---|---|---|
| 1 | `n_accept` | 记者站 | 接受调查，建立初始状态 | flag `accepted` |
| 2 | `n_gate` | 图书馆门厅 | 拿到闭馆记录，了解时间线 | clue `c_log`（值班表） |
| 3 | `n_b1_door` | B1 书库门 | 门禁记录异常，需先有 `c_log` 才可进入 | clue `c_door`（门禁刷卡记录） |
| 4 | `n_b1_shelf` | B1 书架 | 发现被抽走的借阅卡 | clue `c_card`（借阅卡） |
| 5 | `n_b1_tape` | B1 监控回放 | 监控缺 8 分钟，需 `c_door` + 推理 `d_gap` | clue `c_tape`（监控缺口） |
| 6 | `n_lab_corridor` | 实验楼走廊 | 遇到值班教师，对话分叉 | flag `teacher_trust` |
| 7 | `n_lab_room` | 实验楼 403 | 找到烧焦的排班表残页 | clue `c_burn`（残页） |
| 8 | `n_stadium_stand` | 体育场看台 | 目击者改口，第二次对话 | flag `witness_flip` |
| 9 | `n_stadium_locker` | 看台储物柜 | 需要 `witness_flip` + `c_card` 才可开 | clue `c_note`（纸条） |
| 10 | `n_confront` | 教务处 | 提交推理，进入最终判断 | flag `verdict_ready` |
| 11 | `n_final_choose` | 教务处 | 两条最终判断：「提交完整证据链」/「只交人情」 | 结局分流 |
| 12 | `n_epilogue` | 结局页 | 结局展示 + 复盘统计 | `endingId` |

阶段划分（`stage`）：0 接受调查 → 1 现场勘查 → 2 交叉验证 → 3 最终判断 → 4 结局。

### 1.2 六条线索

| 线索 | 名称 | 价值 |
|---|---|---|
| `c_log` | 值班表 | 证明当晚值班人并非登记人 |
| `c_door` | 门禁记录 | 卡片在 23:47 被刷开 |
| `c_card` | 借阅卡 | 持卡人不属于该时段 |
| `c_tape` | 监控缺口 | 8 分钟被裁剪 |
| `c_burn` | 残页 | 排班被临时替换 |
| `c_note` | 纸条 | 目击者被要求改口 |

### 1.3 两次推理（可组合验证）

- `d_gap` = `c_door` + `c_tape` → 监控缺口与刷卡时间吻合，证明"有人刻意删改"
- `d_who` = `c_card` + `c_burn` → 借阅卡与临时排班指向同一人

推理不是自动完成的：玩家在线索板上**选两条线索 → 点"验证推理"**，命中组合则生成推论，未命中给出"证据链不成立"的反向反馈。

### 1.4 两个结局的条件（互斥）

| 结局 | 触发条件 | 语义 |
|---|---|---|
| A 真相结局「八分钟」 | `d_gap` 且 `d_who` 均成立，且最终选择"提交完整证据链"，且线索数 ≥ 5 | 完整证据链，事件被重新调查 |
| B 误判结局「替罪者」 | 其余所有情况（线索 < 5、缺任一推理、或最终选择"只交人情"） | 结论被草率盖棺，记者站被约谈 |

结局页显示：结局名、达成条件回放、线索收集率、推理完成度、"再来一次"按钮。

---

## 2. 作业硬指标对照表

| 作业要求 | 本作实现 | 可验证证据 |
|---|---|---|
| 3 个可探索场景 | 图书馆 B1 / 实验楼 403 / 体育场看台 | 场景切换录屏 + `scenes` 配置 |
| 12 个有意义事件节点 | 见 1.1 表，节点带前置条件与效果 | `story/StoryGraph.ets` 数据表 |
| 6 条可查阅线索 | 见 1.2 表，线索板可翻看详情 | 线索板截图 |
| 2 个不同条件结局 | A/B 见 1.4，条件由引擎实时计算 | 两结局各一段录屏 + 单测 |
| 线索与选择真实改变后续 | 节点门槛读 `clues/flags`，选择写状态；同一节点在不同状态下文案与选项不同 | 单测 + 对照录屏 |
| 线索板 | 网格卡片 + 详情 + 推理验证面板 | 截图 |
| 关键状态提示 | 顶部 HUD：阶段、线索数、推论数、剩余时间 | 截图 |
| 阶段进度 | 5 阶段进度条，随 `stage` 变化有动画 | 录屏 |
| 存档与重开 | Preferences 自动存 + 手动存 + 重开清档 | 杀进程复现录屏 |
| 关进程后恢复 | `onBackground`/每次状态变更后落盘，冷启动读取快照 | 录屏 + 单测 |
| ArkUI 状态管理 | V1：`@State`/`@Observed`/`@ObjectLink`/`@StorageLink` + 单向数据流 | 代码 |
| 交互与动画 | 转场、线索入袋缩放高亮、推理成功/失败反馈、进度条动画 | 录屏 |
| 业务数据建模 | `StoryNode`/`Clue`/`Choice`/`GameState`/`SavePayload` | 需求说明书 + 代码 |
| Preferences/RDB | Preferences 单存档 + 版本号 + 损坏降级 | 代码 + 异常单测 |
| 单元测试 ≥ 6 | 9 条，见第 7 节 | ohosTest 报告截图 |
| README + 录屏 | 功能/环境/截图/运行方法 + 3 段录屏 | 仓库 |

---

## 3. 新区域与目录结构

新区域根：`F:/AdvancedStateLab/entry/src/main/ets/final/`
文档区：`F:/AdvancedStateLab/docs/final/`
**原 `ets/pages/Index.ets`、`ets/common/*`、卡片/媒体资源全部保留，不修改、不移动。**

```
entry/src/main/ets/final/
├─ pages/
│  ├─ FinalIndex.ets        总入口：开始/继续/重开 + 存档摘要
│  ├─ ScenePage.ets         场景探索页（节点渲染 + 选项）
│  ├─ ClueBoardPage.ets     线索板 + 推理验证
│  └─ EndingPage.ets        结局页 + 复盘统计
├─ view/
│  ├─ HudBar.ets            顶部状态条（阶段/线索/时间）
│  ├─ ClueCard.ets          线索卡片（@Observed/@ObjectLink 演示）
│  ├─ ChoiceButton.ets      选项按钮（受限选项置灰+原因）
│  └─ StageProgress.ets     阶段进度
├─ model/
│  ├─ Types.ets             枚举 + 接口（纯类型，无逻辑）
│  └─ StoryGraph.ets        12 节点 / 6 线索 / 场景配置（静态数据）
├─ engine/
│  ├─ GameEngine.ets        纯函数：进入判定/应用选择/时间推进/阶段推进
│  ├─ Deduction.ets         推理组合校验
│  └─ EndingResolver.ets    结局判定
├─ store/
│  ├─ SaveRepository.ets    Preferences 读写、版本迁移、损坏降级
│  └─ GameStore.ets         状态容器（@Observed）+ 自动存档节流
└─ util/
   └─ Log.ets               [FOG] 统一日志前缀
```

依赖方向严格单向：`pages/view → store → engine → model`，`model` 不依赖任何上层，保证引擎可脱离 UI 单测。

### 3.1 与现有工程的接入方式（最小侵入）

1. `resources/base/profile/main_pages.json` 的 `src` 数组**追加** `"final/pages/FinalIndex"`（只加一行，原 `"pages/Index"` 保留）。
2. `EntryAbility` 的启动页暂不改；验收时用 `router`/`Navigation` 从原首页进新区域，或在 `main_pages` 里临时把首个页面切到 FinalIndex（二选一，报告中说明）。
3. 新增字符串/颜色资源单独建 `resources/base/element/fog_strings.json`、`color.json` 里追加键，不覆盖已有键。

---

## 4. 数据模型（可直接落成 ArkTS 接口）

```ts
// model/Types.ets
export enum Stage { ACCEPT = 0, SURVEY = 1, VERIFY = 2, VERDICT = 3, ENDING = 4 }
export enum EndingId { NONE = 'none', TRUTH = 'A_8MIN', SCAPEGOAT = 'B_SCAPEGOAT' }

export interface ClueDef { id: string; name: string; summary: string; detail: string; sceneId: string; }
export interface ChoiceDef {
  id: string; label: string; nextNodeId: string;
  cost: number;                       // 消耗时间（分钟）
  requireClues?: string[];            // 前置线索
  requireFlags?: string[];            // 前置标记
  denyText?: string;                  // 不满足时的说明
  grantClues?: string[]; setFlags?: string[]; clearFlags?: string[];
}
export interface StoryNode {
  id: string; sceneId: string; title: string; text: string;
  stage: Stage;
  requireClues?: string[]; requireDeductions?: string[]; requireFlags?: string[];
  enterEffects?: { grantClues?: string[]; setFlags?: string[] };
  choices: ChoiceDef[];
  isEndingGate?: boolean;
}

export interface GameState {           // 唯一可变真相
  version: number;
  currentNodeId: string;
  stage: Stage;
  collectedClues: string[];            // 去重、保持获取顺序
  deductions: string[];                // d_gap / d_who
  flags: string[];
  visitedNodes: string[];
  timeLeft: number;                    // 起始 480 分钟，选项消耗
  turn: number;
  endingId: EndingId;
  startedAt: number; updatedAt: number;
}
```

**规则要点**
- 状态变更只走 `GameEngine.applyChoice(state, choice): GameState`（返回新对象，不原地改），UI 只负责展示与派发意图。
- `timeLeft <= 0` 不允许再做消耗型选择，只能进入最终判断（边界用例）。
- 线索获取幂等：重复授予不重复计数，不重复弹动画。
- 存档 `SavePayload = { schemaVersion, state, checksum }`，读取时校验 `schemaVersion` 与字段完整性，失败降级为新游戏并提示"存档损坏，已重新开始"。

---

## 5. 状态管理与交互设计

- `GameStore` 用 `@Observed` 包装 `GameState`，页面用 `@ObjectLink` 订阅；跨页共享用 `AppStorage` 存 `store` 引用 + `@StorageLink` 版本号 `storeRevision`，避免大对象深拷贝。
- 单向流：`UI 事件 → store.dispatch(choiceId) → engine 计算 → 新 state → revision++ → UI 重渲染`。
- 交互与动画清单：
  1. 场景切换：`pageTransition` + 背景模糊渐入（400ms）
  2. 线索入袋：卡片从 0.8 缩放至 1，边框高亮 + Toast，250ms
  3. 推理成功：线索两条连线绘制 + 结论卡展开；失败：面板轻微横向抖动（`keyframeAnimateTo`）
  4. 阶段推进：进度条 `animateTo` 填充 + 阶段名淡入
  5. 结局页：证据链逐条浮现（`animateTo` 延迟序列）
- 受限选项：保留在列表里但置灰，点击弹"还缺 XX 线索"，让玩家知道"选择被状态影响"，而不是凭空少一个按钮。

---

## 6. 持久化方案

| 项 | 方案 |
|---|---|
| 存储 | `@kit.ArkData` 的 `preferences`，文件名 `fog_archive`，key `save_v1` |
| 时机 | 每次 `dispatch` 成功后写；`EntryAbility.onBackground()` 再兜底写一次 |
| 内容 | `SavePayload` JSON 字符串（含 schemaVersion） |
| 恢复 | `FinalIndex.aboutToAppear()` 读档 → 校验 → 恢复到 `currentNodeId` 对应页面 |
| 重开 | 清 key + 重建初始 state，二次确认弹窗 |
| 异常 | JSON 解析失败/字段缺失/版本不认识 → 备份原始串到 `save_corrupt` 并开新档 |

不引入 RDB：单存档场景 Preferences 足够，报告中说明"为何不选 RDB"（写入频率、数据规模、无需查询）。

---

## 7. 测试计划（独立完成，9 条全由本人编写）

测试位置：`entry/src/ohosTest/ets/test/`，hypium；引擎为纯函数，多数用例不需要 UI 能力。

| # | 用例 | 类型 | 断言要点 |
|---|---|---|---|
| T1 | 初始状态构造 | 正常 | stage=ACCEPT、timeLeft=480、clues 空、currentNode=`n_accept` |
| T2 | 应用选择推进节点并授予线索 | 正常 | `n_gate` 选"翻闭馆记录"→ 得 `c_log`，node 变 `n_b1_door`，时间 -30 |
| T3 | 前置线索不满足时不可进入 | 边界 | 无 `c_log` 走 `n_b1_door` → `canEnter=false`，state 不变 |
| T4 | 重复获取线索幂等 | 边界 | 二次授予 `c_log` → 数组长度不变、顺序不变 |
| T5 | 时间耗尽后拒绝消耗型选择 | 边界 | timeLeft=0 再选 cost>0 → 返回拒绝原因 |
| T6 | 推理组合正确生成推论 | 正常 | `c_door`+`c_tape` → `d_gap` |
| T7 | 推理组合错误不生成结论 | 异常 | `c_log`+`c_note` → 结果为空 + 失败原因非空 |
| T8 | 结局判定双分支 | 分支 | 全条件满足→A；缺 `d_who`→B；"只交人情"→B |
| T9 | 存档序列化往返与损坏降级 | 异常/恢复 | roundtrip 字段全等；截断 JSON → 返回新档且不抛异常 |

另做手工验证清单（进《演示与测试清单.md》）：杀进程恢复、旋转/分屏、深色模式、快速连点防重复提交。

---

## 8. 里程碑

| 里程碑 | 交付物 | 验收标准 |
|---|---|---|
| M0 骨架（当前） | 目录、计划、需求说明书、README | 工程可编译，原实验功能不受影响 |
| M1 数据与引擎 | `Types/StoryGraph/GameEngine/Deduction/EndingResolver` | T1/T2/T3/T4/T5/T6/T7/T8 全绿，无 UI 参与 |
| M2 存档 | `SaveRepository/GameStore` | T9 绿；杀进程冷启能回到原节点 |
| M3 页面 | 4 个页面 + 4 个组件 | 可从入口走完整条主线到 A 结局 |
| M4 表现 | 动画、HUD、线索板视觉、空态/异常态 | 录屏无明显跳变，受限选项有解释 |
| M5 测试与打磨 | ohosTest 汇总、边界修复、性能（首屏 < 1s） | 9/9 通过，无 lint 报错 |
| M6 交付 | README、报告、3 段录屏、tag v1.0 | 报告与代码一致，验收项逐条可指认 |

**进度（2026-11-18）**

| 里程碑 | 状态 | 备注 |
|---|---|---|
| M0 骨架 | 完成 | 新区域、计划、需求说明书、README |
| M1 数据与引擎 | 完成 | T1–T8 + T10/T11 全绿 |
| M2 存档 | 完成 | T9/T12 绿；杀进程冷启回到原节点 |
| M3 页面 | 完成 | 三个页面（标题 / 场景+线索板 / 结局复盘）；组件改为页面内 `@Builder`，未拆 `view/` |
| M4 表现 | 完成 | 线索入袋浮层、结论卡、失败抖动、进度平滑、页面淡入；受限选项均有原因 |
| M5 测试与打磨 | 完成 | 15/15 通过；A/B 结局各走一遍并留证据 |
| M6 交付 | 进行中 | 报告与 README 已写，tag v1.0 随本次提交打；3 段录屏待录（分镜见《演示与测试清单》） |

---

## 9. Git 与提交规范

```
main                 仅接受可运行提交
feat/engine          引擎 + 单测
feat/pages           页面与组件
feat/save            持久化
docs/final           需求说明书、报告
```

- 提交粒度：一个可说明的行为一次提交，如 `feat(engine): 选择应用与线索幂等授予`。
- 消息格式：`type(scope): 中文描述`，type 取 feat/fix/test/docs/chore。
- 仓库根 `.gitignore` 需含 `.hvigor/`、`build/`、`oh_modules/`、`.idea/`、`local.properties`、`*.har`。
- 每个里程碑末尾打 tag（`m1-engine`…`v1.0`），作为报告里的进度证据。

---

## 10. 报告与录屏

**报告结构**：封面 → 摘要与关键词 → 需求分析（用户故事、功能清单、非功能）→ 系统设计（分层架构图、节点状态机图、数据模型 ER、存档时序）→ 关键实现（状态管理、引擎纯函数、动画、Preferences）→ 测试（用例表、执行结果、覆盖率、异常场景）→ 不足与改进 → 参考文献 → 附录（目录树、关键代码、录屏链接）

**三段录屏（每段 60–120s）**
1. 主线通关：接受调查 → 三场景 → 6 线索 → 2 推理 → A 结局
2. 存档恢复：中途强杀进程 → 冷启动 → 恢复原节点与 HUD → 继续通关
3. 分支与异常：走 B 结局（线索不足/只交人情）+ 存档损坏降级提示

**截图清单**：入口页、三场景、线索板、推理成功/失败、HUD 阶段变化、两结局、单测报告、Profiler 首屏。

---

## 11. 风险与规避

| 风险 | 影响 | 规避 |
|---|---|---|
| 剧情写完才发现条件链不闭合 | A 结局不可达 | 先把 12 节点写成表，用 T8 单测反向验证可达性 |
| 状态大对象跨页拷贝导致 HUD 不同步 | 演示翻车 | 统一 `GameStore` 单例 + revision 计数，禁止页面自持副本 |
| Preferences 写入过频 | 掉帧 | 节流 500ms，`onBackground` 兜底 |
| 新增页面注册影响原实验 | 编译失败 | 只追加 main_pages 一行，先编译再提交 |
| 动画过度影响可读性 | 观感差 | 统一 200–400ms，可关（设置项留 `reduceMotion`） |

---

## 12. 下一步（按顺序执行）

1. 建 `final/` 各目录占位文件，`main_pages.json` 追加一行，`hvigor` 编译验证。
2. 写 `Types.ets` + `StoryGraph.ets`（剧情表先定稿）。
3. 写 `GameEngine/Deduction/EndingResolver` + ohosTest T1–T8。
4. 写 `SaveRepository` + T9，接 `onBackground`。
5. 页面与组件，最后接动画。
6. README / 报告 / 录屏 / tag。
