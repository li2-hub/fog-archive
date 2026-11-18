# 迷雾档案 FogArchive

> 《鸿蒙高级应用开发工程师认证》期末大作业 · 主题一：校园线索推理与多结局探索 App
> 独立完成 / ArkTS + ArkUI / HarmonyOS API 17

一名学生记者在校园里调查"违规滞留被处分"的真相：三个场景、十二个事件节点、六条线索、两次推理、两个结局。线索与选择会真实改变后续可进入的节点与最终判定；进程被杀后冷启动可完整恢复进度。

## 功能

- **三场景探索**：图书馆 B1 书库 / 实验楼 403 / 体育场看台
- **12 个事件节点**：带前置线索、推论、标记的条件门槛，选项消耗时间
- **线索板**：6 条线索查阅 + 选两条做推理验证，命中生成推论并解锁后续
- **状态 HUD**：阶段进度、线索收集数、推论数、剩余时间常驻显示
- **双结局**：A「八分钟」（完整证据链）/ B「替罪者」（证据不足或选择沉默）
- **结局复盘页**：结局名、线索与推论完成度、用时与决策次数、四条达成条件逐条 ✓/✗、未闭合项说明
- **存档**：Preferences 自动存档，杀进程冷启动恢复，损坏存档降级不崩溃
- **重开**：清档二次确认
- **过渡动画**：线索入袋浮层、推论结论卡展开、推理失败抖动、HUD 进度条平滑推进、页面淡入

## 开发环境

| 项 | 版本 |
|---|---|
| DevEco Studio | 5.0.5 及以上 |
| HarmonyOS SDK | 5.0.5(17)（`compatibleSdkVersion` 同） |
| 语言 / 框架 | ArkTS / ArkUI 声明式（Stage 模型） |
| 测试框架 | @ohos/hypium 1.0.21 |
| 设备 | 手机（主）、平板、2in1 |

## 目录说明

```
entry/src/main/ets/
├─ pages/           原有课程实验页面（Index.ets 等，保持不变）
├─ common/          原有实验数据与卡片存储
├─ final/           ★ 期末大作业新区域
│  ├─ BootConfig.ets 启动页开关（切回课程实验入口只需改这里）
│  ├─ pages/        标题页 FinalIndex / 场景页 FogScene / 结局复盘页 EndingPage
│  ├─ view/         HUD、线索卡、选项按钮、阶段进度
│  ├─ model/        类型定义 + 剧情数据表
│  ├─ engine/       纯函数引擎（选择、推理、结局判定、复盘统计）
│  ├─ store/        Preferences 存档 + 状态容器
│  └─ util/         日志
docs/final/         计划、需求说明书、演示与测试清单、测试执行记录、结课报告
```

## 运行方法

1. DevEco Studio 打开工程根目录（含 `build-profile.json5`），等待 Sync 完成。
2. 选择 `entry` 模块 + 模拟器/真机，点击运行。**打开即是本作品**（标题页）。
3. 本机 log 版模拟器不校验签名，未签名包也能安装运行；装到真机时才需要在 `File → Project Structure → Signing Configs` 勾选自动签名。

### 启动页开关（做课程实验时看这里）

打开 App 看到哪个页面，只由 `entry/src/main/ets/final/BootConfig.ets` 一个常量决定：

```ts
export const START_PAGE: string = 'final/pages/FinalIndex'; // 大作业入口
// 要做实验十一、十二等课程实验时，改成：
// export const START_PAGE: string = 'pages/Index';         // 课程实验入口
```

改完直接运行即可。`pages/Index.ets`、`common/`、卡片与媒体资源、`module.json5` 全程未被修改，
切回后实验页面与改造前完全一致（状态栏也会恢复系统默认外观，不会被本作品的深色主题影响）。

### 构建与测试

```bash
# 构建
hvigorw --mode module -p module=entry@default -p product=default assembleHap

# 单元测试（设备已连接）
hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap
hdc shell aa test -b com.example.campuscardlab -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 60000
```

## 存档

- 位置：Preferences，库名 `fog_archive`，键 `save_v1`；写入内容为 `store/SaveCodec.ets` 产出的单行 JSON。
- 时机：每次推进、每次推理成功、重新开档、退到后台（`onPageHide`）各写一次。操作频率是"一次点击一次写入"，不做节流——节流反而有丢最后一次写入的风险。
- 恢复：进入场景页时自动读取；标题页检测到进度后按钮变为「继续调查」并显示已记录步数。
- 降级：JSON 截断、版本不符、节点已从数据表删除、结局存档缺少结局 id —— 一律丢弃并开新档，同时用 toast 说明原因，不把半损坏状态喂给引擎。
- 分层：`store/SaveCodec.ets` 是纯函数（无 Context），负责编码与逐字段校验；`store/SaveRepository.ets` 只做 Preferences 读写。这样存档逻辑能进单元测试。

## 测试

13 → 15 条自动化用例（正常 / 边界 / 异常 / 分支 / 回归 / 存档 / 复盘），覆盖初始状态、选择推进、条件门槛、线索幂等、时间耗尽、推理成功与失败、双结局判定、捷径路线不卡关、问保安路线的证据补救、存档往返、存档损坏降级、结局复盘统计。

其中 **15 条已在模拟器上全部实跑通过**（2026-11-18，`Tests run: 15, Failure: 0, Error: 0`）。另有端到端验证：① 推进到监控回放后 `force-stop` 杀进程，重启仍恢复同一节点、同一剩余时间、同三条线索；② 走完 A 结局进复盘页，四条条件全绿、线索 6/6、用时 209 分；③ 捷径路线落到 B 结局，复盘页显示"还差 4 项条件"并逐条给出未达成原因。

原始输出见 `docs/final/evidence/`，两轮真实缺陷复盘与杀进程验证步骤见 `docs/final/测试执行记录.md`。

## 文档

- [开发计划](docs/final/PLAN.md)
- [软件需求说明书](docs/final/软件需求说明书.md)
- [结课报告](docs/final/结课报告.md)
- [演示与测试清单](docs/final/演示与测试清单.md)
- [测试执行记录](docs/final/测试执行记录.md)
- [签名与模拟器操作步骤](docs/final/签名与模拟器操作步骤.md)

## 截图与录屏

- 截图：`docs/final/screenshots/01–20`（标题页、案件概要、场景页、线索归档、B1 铁门三条路线、线索板、推论成立、选项解锁、杀进程前、重启后继续调查、重启后现场恢复、线索入袋提示、推论结论卡、结局封存、A 结局复盘、复盘线索清单、B 结局复盘、推理失败反馈、切回实验入口验证）
- 录屏：待补（主线通关 / 杀进程恢复 / 分支与异常），分镜脚本见《演示与测试清单》第四节

## 进度

- [x] M0 新区域与文档基线
- [x] M1 数据模型与引擎，用例在模拟器上全部通过
- [x] 启动入口切换（`BootConfig.ets`）与标题页、场景页跑通
- [x] 修复 B1 监控回放的死路，补"问保安"路线的证据补救选项
- [x] 线索板：两两验证推论、解锁现场灰色选项
- [x] M2 存档：Preferences 落盘 / 启动恢复 / 损坏降级 / 标题页"继续调查" / 页面内「↻ 重开」
- [x] M2 验证：T9、T12 实跑通过，并实机验证杀进程恢复
- [x] M3 结局页：独立复盘页（条件回放、完成度、未闭合项、再来一次），场景页保留封存卡入口
- [x] M4 动画与视觉打磨：线索入袋浮层、结论卡展开、失败抖动、进度条平滑、页面淡入
- [x] M5 测试：15/15 实跑通过，A/B 两条结局各走一遍并归档截图
- [ ] M6 报告已写完，录屏与 tag v1.0 待补
