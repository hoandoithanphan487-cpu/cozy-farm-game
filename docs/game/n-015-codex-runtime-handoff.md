# N-015 Codex 运行时接入阶段交接

- 日期：2026-08-24
- 专项执行：🎮 gameplay（Codex）
- 部门质量负责人：🛡️ quality（待独立复核）
- 当前结论：`READY FOR DEPARTMENT REVIEW`
- 台账状态：`active / PENDING`

## 结论

VSCode 基础包 r4 已独立复闸 `APPROVED`。Codex 本轮完成 B2、B3、成品紧凑 HUD 和五栋高清建筑的非碰撞展示路径；运行时矩阵由 53 integrated / 49 planned / 30 blocked 推进到 **102 integrated / 0 planned / 30 blocked**。30 项均为 B4 五建筑六层像素图，仍由唯一未决拓扑选择阻断。

本结果是合格的阶段性交付，不是 N-015 完成。Codex 没有对自己的生产实现签发部门 `APPROVED`。

## 批次状态

| 批次 | 状态 | 结果 |
|---|---|---|
| B0 基础合同 | 完成 | 132 项合同、来源与 fail-closed validator 已通过独立门禁 |
| B1 农场首切片 | 完成 | 既有 53 项正式消费者保持有效 |
| B2 地图与行走 | READY | 两张地图、8 角色四向四帧、地形、水体、路径、水渠、采集物已接入 |
| B3 动作与 FX | READY | 锄地、浇水、收获动作及 16 张 FX 均由成功/失败路径驱动并显式清理 |
| HUD | READY | 默认成品 HUD、五槽工具栏、键鼠/手柄提示、单一上下文提示；H 保留调试层 |
| 五栋高清建筑 | READY | 五栋 2048 展示图均有可达、非碰撞展示卡；不改地图拓扑 |
| B4 建筑像素层 | BLOCKED | 30 张六层像素图等待 PO 拓扑决策 |
| B5 全路径验收 | 部分完成 | 自动回归、视觉、缺失资源、输入状态、存读与性能证据已齐；B4、独立部门复核与 PO 视觉验收未完成 |

## 生产实现

- `RuntimeArtCatalog` 为本轮 49 项建立唯一类型化描述、来源、原生尺寸、帧网格、锚点与层级。
- `PixelAssetStore` 校验尺寸并 fail closed；缺失或畸形资源安全返回 fallback，不把错误纹理当成正式接入。
- `SpriteSheetAnimator` 固定 4×4 布局、down/left/right/up 行、脚底锚点、nearest 与 reduced-motion 静帧。
- `FarmScene` 在真实移动、成功动作、地形、水体、水渠、采集、作物和 FX 路径中消费正式资源；失败动作不播放成功动画，短时 FX 显式移除。
- `HudPresentationState` 与 `ContentView` 形成默认成品 HUD；长调试文本只在 H 显式开启。
- `BuildingPresentationCatalog` 覆盖五栋高清展示；展示卡不参与碰撞或存档。

## 运行时消费者

| 指标 | 数量 |
|---|---:|
| official assets | 132 |
| integrated | 102 |
| blocked | 30 |
| planned | 0 |
| missing | 0 |
| extra | 0 |
| dimension/hash/PNG errors | 0 |

唯一未引用集合就是 30 张 B4 建筑层；没有把文件存在、测试引用或高清展示卡虚报为这些像素层的消费者。

## 测试与证据

- validator：`PASS`，132 项、来源 119/12/1、102 integrated、30 blocked。
- 运行时审计：`overall_pass=true`；资源完整性全绿；resolved 102；unreferenced 30 且全部为 B4。
- 定向实现测试：13/13，0 failed，0 skipped。
- VSCode 矩阵门禁：15/15，0 failed，0 skipped。
- 视觉证据测试：1/1；性能证据测试：1/1。
- 最终全量：权威 `xcresulttool` 统计 300/300，0 failed，0 skipped；高于 289 基线。
- `git diff --check`：exit 0。
- 性能：1920×1080，899 个测量帧，P95 2.93 ms，P99 8.36 ms；地图切换 P95 8.85 ms / 10 次；RSS 116.98→98.61 MB，峰值 116.98 MB。全部低于现有门槛。

主证据索引：`artifacts/integration/n-015-codex-runtime/handoff.md`。

## 文件边界

本轮生产改动限定为 `FarmScene`、`ContentView`、`Presentation` 的运行时消费者/动画/HUD/建筑展示文件、对应 XCTest，以及四张已批准 N-013 高清建筑图进入 App 展示目录。VSCode 独占的 validator、契约 XCTest 与 handoff 哈希保持不变；矩阵仅在 r4 获批后按 handoff 确定性刷新。

未修改：经济数值、配方、任务、NPC ID/对白、存档 schema、地图 blocked cells、出生点、出口、NPC 位置、N-014、正式音频服务。详细边界见 `artifacts/integration/n-015-codex-runtime/file-boundary/report.md`。

## 唯一产品阻断

1. 地图重排：显式重做两图布局、出生点、NPC 站位和 blocked cells，再放完整 footprint。
2. 纯视觉缩小：把建筑压到现有 blocked cells 内，仅作装饰，不承载真实 footprint。

推荐 **地图重排**。N-015 的目标是“真正接入”；纯视觉缩小会破坏比例、入口与碰撞可信度，难以诚实满足五建筑六层的最终验收。地图重排成本更高，且必须另立 PO 批准的拓扑/存档兼容合同，但能得到可行走、可遮挡、可交互且不穿模的长期结果。

## 下一门禁

🛡️ quality 独立复核本交接并返回 `APPROVED`、`REVISE` 或 `BLOCKED`；若 B2/B3/HUD/高清展示获批，N-015 仍保持 `active / PENDING`，直到 PO 解决 B4、完成 B4/B5 和最终视觉验收。N-016 依赖 N-015 `accepted / APPROVED`，因此现在不能正式启动。
