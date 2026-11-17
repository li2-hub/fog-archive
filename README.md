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
- **存档**：Preferences 自动存档，杀进程冷启动恢复，损坏存档降级不崩溃
- **重开**：清档二次确认

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
│  ├─ pages/        入口 / 场景 / 线索板 / 结局
│  ├─ view/         HUD、线索卡、选项按钮、阶段进度
│  ├─ model/        类型定义 + 剧情数据表
│  ├─ engine/       纯函数引擎（选择、推理、结局判定）
│  ├─ store/        Preferences 存档 + 状态容器
│  └─ util/         日志
docs/final/         计划、需求说明书、演示与测试清单
```

## 运行方法

1. DevEco Studio 打开工程根目录（含 `build-profile.json5`），等待 Sync 完成。
2. 首次运行需在 `File → Project Structure → Signing Configs` 勾选自动签名。
3. 选择 `entry` 模块 + 手机模拟器/真机，点击运行。
4. 应用首页为原实验首页，从"迷雾档案"入口进入大作业区域（或在 `main_pages.json` 中把首屏切到 `final/pages/FinalIndex`）。

### 构建与测试

```bash
# 构建
hvigorw --mode module -p module=entry@default -p product=default assembleHap

# 单元测试（设备已连接）
hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap
hdc shell aa test -b com.example.campuscardlab -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 60000
```

## 测试

9 条自动化用例（正常 / 边界 / 异常 / 分支），覆盖初始状态、选择推进、条件门槛、线索幂等、时间耗尽、推理成功与失败、双结局判定、存档往返与损坏降级。详见 `docs/final/演示与测试清单.md`。

## 文档

- [开发计划](docs/final/PLAN.md)
- [软件需求说明书](docs/final/软件需求说明书.md)
- [演示与测试清单](docs/final/演示与测试清单.md)

## 截图与录屏

- 截图：待补（入口、三场景、线索板、推理成功/失败、双结局、测试报告）
- 录屏：待补（主线通关 / 杀进程恢复 / 分支与异常）

## 进度

- [x] M0 新区域与文档基线
- [x] M1 数据模型与引擎编译通过，T1–T8 用例已就绪（待设备执行）
- [ ] M2 存档 + T9
- [ ] M3 四个页面可通关
- [ ] M4 动画与视觉打磨
- [ ] M5 测试与性能
- [ ] M6 报告 / 录屏 / tag v1.0
