# N-010 Hermes r3 独立复闸 Prompt

你是《溪谷新芽》的 🛡️ quality / release 独立质量负责人 Hermes。请对 N-010 r3 修复候选执行一次独立复闸。你不能修改 Swift、不能替 Codex 修复问题、不能自行修改主台账，也不能提前验收 N-011 或 N-012。

## 1. 当前任务状态与授权

- N-010 当前状态：`revise / REVISE`。
- N-007 当前状态：`revise / REVISE`。
- N-011 当前状态：`blocked / BLOCKED`。
- N-012 当前状态：`planned / PENDING`。
- Product Owner 已批准 `DEC-030`，允许 N-010 在 N-007 保持 `REVISE` 时完成高清立绘运行时缺口。
- N-009 已为 `accepted / APPROVED`，8 张 processed 全身立绘是本任务的唯一高清角色输入。

本次 r3 只验证 Hermes r2 指出的单行缺陷是否关闭：

```swift
Text("[\(InputBindingDefinitions.characterInfoKeyboardLabel)]关闭")
```

目标显示必须是：

```text
[Q]关闭
```

不得出现：

```text
[(InputBindingDefinitions.characterInfoKeyboardLabel)]关闭
```

## 2. 必须读取的材料

请先读取并以仓库当前内容为准：

- `AGENTS.md`
- `skills/cozy-farm-game-studio/SKILL.md`
- `skills/cozy-farm-game-studio/references/roles.md`
- `skills/cozy-farm-game-studio/references/production-workflow.md`
- `skills/project-ledger/SKILL.md`
- `docs/game/project-ledger.md`
- `docs/game/n-010-brief.md`
- `docs/game/n-010-prompt.md`
- `docs/game/n-010-revise-prompt.md`
- `artifacts/integration/n-010-xcode/hermes-r3/handoff.md`
- `artifacts/integration/n-010-xcode/hermes-r3/xcodebuild-clean-test-authoritative.log`
- `artifacts/integration/n-010-xcode/hermes-r3/TestResults-N-010-r3.xcresult`
- `artifacts/integration/n-010-xcode/hermes-r3/file-boundary-audit.txt`
- `artifacts/integration/n-009-portraits/manifest.json`

不要以 Codex 的总结代替源码、xcresult、日志、候选构建和 GUI 证据检查。

## 3. 复闸前依赖核对

逐项记录实际结果：

1. N-009 是否仍为 `accepted / APPROVED`；
2. DEC-030 是否存在且授权范围未被扩大；
3. N-010 是否仍为 `revise / REVISE`；
4. N-011 是否仍为 `blocked / BLOCKED`；
5. N-012 是否仍为 `planned / PENDING`；
6. r3 候选构建、xcresult、日志、handoff 是否来自同一修复窗口；
7. 是否没有 N-011 建筑接入、N-012 打包交付或其他超范围改动。

如果依赖、候选构建或证据链不一致，返回 `BLOCKED`，停止后续验收。

## 4. 静态与构建证据

独立检查以下内容：

- `ContentView.swift` 关闭提示使用单反斜杠 Swift 插值；
- `InputBindingDefinitions.characterInfoKeyboardLabel` 解析为 `Q`；
- `Key:I` 仍映射 `actionDeposit`；
- `Key:Q` 不被任何既有 gameplay binding 占用；
- `I` 与 `Q` 路由不互相拦截；
- `SettingsTests.swift` 或等效测试包含 `[Q]关闭` 断言；
- 8 张 processed 立绘 SHA-256 与 N-009 manifest 及 N-010 presentation manifest 一致；
- `32×48` 地图 sprite 未被替换；
- Domain、Persistence、EconomyCatalog、WorldCatalog、ContentID、地图拓扑、碰撞、NPC 行为、存档 schema、N-009 源图/处理图、N-011、N-012 均未被本次修复修改；
- `git diff --check` 通过；
- 权威 clean test 的真实计数为 266 passed / 0 failed / 0 skipped；
- 2 条 AppIntents metadata 环境警告若仍存在，需如实记录，不能误报为 Swift 编译器警告；
- 不接受只看测试摘要，必须读取 xcresult 权威结果和原始日志。

## 5. r3 必须重新执行的 GUI 路径

必须使用 r3 候选构建重新驱动，不能只复用 r2 截图。

### A. Q 信息页路径

1. 启动 r3 候选构建。
2. 新游戏进入可操作状态。
3. 按 `Q`。
4. 确认角色信息页打开。
5. 通过 OCR、Accessibility 或可审计截图直接确认关闭提示显示为 `[Q]关闭`。
6. 确认界面不显示原始插值表达式、双反斜杠或其他占位文本。
7. 再按 `Q`。
8. 确认角色信息页关闭，且没有触发投入出售箱。

### B. I 投入出售箱路径

1. 在新游戏空背包状态按 `I`，确认不会打开角色信息页。
2. 使用受控方式准备至少一个可出售物品；如使用调试注入，必须在日志中明确标记为测试夹具，不得改写正式内容。
3. 按 `I`。
4. 确认出现“已投入出售箱”或等效成功反馈。
5. 确认待结算数量变化正确，且没有打开角色信息页。

### C. 基本 N-010 回归

在 r3 候选构建上重新验证，或证明候选构建与已验证 r2 代码路径完全一致并补足受影响证据：

- 至少 3 名不同职业 NPC 的对话卡显示正确高清完整全身立绘；
- 角色信息页显示同一稳定 ID 对应的高清立绘；
- 缺失一张立绘时安全回退，其他角色仍正常显示；
- 立绘不裁头、不裁脚、不拉伸；
- 窗口尺寸变化后仍等比显示；
- HUD 默认折叠，`H` 展开/收起；
- `K` 完全退出，重新启动后 `L` 读取成功；
- 读取后再次对话，位置、待结算、任务状态与对话状态一致；
- 键盘路径覆盖移动、交谈、Q 信息页、I 投入、保存、读取、H HUD；
- 手柄不可用时记录为观察项，不得虚构手柄通过；若此前手柄路径未被 N-010 修改，可如实记录为未实测观察项。

## 6. 必须保存的新证据

请将本次复闸证据保存到：

```text
artifacts/integration/n-010-xcode/hermes-r3/
```

至少包含：

- `QA-SUMMARY.md`
- `drive-log.txt`
- r3 候选构建标识与路径
- 权威 xcresult 路径和测试计数
- 原始 GUI 驱动日志
- `[Q]关闭` 的清晰截图
- Q 开/Q 关截图或连续证据
- I 投入出售箱成功截图
- 至少 3 名 NPC 对话卡截图，或对 r2 已通过截图的候选一致性说明
- 缺失资源回退截图，或对候选一致性的可审计说明
- 保存→退出→重启→读取→对话证据
- 文件边界审计
- `git diff --check` 原始输出

截图必须来自 r3 候选构建；不能只把 r2 截图复制到 r3 目录。

## 7. 门禁判定

只能返回一个结果：

### `APPROVED`

同时满足：

- `[Q]关闭` 在真实 GUI 中正确显示；
- Q 开关信息页正确；
- I 仍投入出售箱且不打开信息页；
- 266 tests 或最新真实测试全部通过；
- N-010 既有对话、立绘、回退、缩放、HUD、存读验收项有独立证据；
- 无越界改动；
- 无未披露阻断缺陷。

### `REVISE`

实现可以运行，但存在明确可修复缺口。必须写明：

- 复现步骤；
- 期望结果；
- 实际结果；
- 影响范围；
- 缺陷文件与行号；
- Codex 下一步修复条件。

### `BLOCKED`

依赖状态不一致、r3 候选不可用、GUI 无法驱动、证据不是同一候选构建、文件越界或需要新的 Product Owner 决策时返回 `BLOCKED`。

## 8. 最终交付格式

```text
Gate status: APPROVED | REVISE | BLOCKED

Scope reviewed:

Evidence inspected:

Acceptance gaps:

Conditions or required revisions:

Next gate or escalation:
```

Hermes 不得自行修改 `docs/game/project-ledger.md` 的任务状态。若返回 `APPROVED`，下一步由 Codex/Product Owner 依据 N-010 证据关闭 N-007；之后 Cursor 重新预检 N-011。
