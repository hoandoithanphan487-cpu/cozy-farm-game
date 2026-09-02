# 窗口 5 — 呈现层接线（最小可玩，不改变领域）+ 真实 App 冒烟证据

> 本文件是给新 Codex 窗口的完整执行 Prompt。直接整段粘贴到新窗口。

你正在本地仓库 `/Users/fengyifan/Documents/VibeCoding` 执行 N-027 的 **呈现层接线**：把已 tech 门禁的剧情运行时接进 ContentView/FarmScene（多说话人对话、意图按钮、旅程模态小场景、结局画廊），并用真实 Debug App 冒烟取证。**不改变领域语义**，只做呈现与接线。

## 0. 工作纪律

1. 先读：`AGENTS.md`、`skills/cozy-farm-game-studio/SKILL.md`、`skills/project-ledger/SKILL.md`、`docs/game/project-ledger.md`（N-027 行）、`docs/game/n-027-main-story-runtime-brief.md`、`docs/game/n-027-main-story-runtime-prompt.md`（§11.7 真实 App 部分）。
2. 禁止 git reset/restore/checkout/clean/commit；不联网、不装依赖、不接 LLM；不 spawn 子代理。
3. 工程 PBXFileSystemSynchronizedRootGroup（objectVersion 77），新增 .swift 自动入 target；`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，跨隔离传函数值需 nonisolated。
4. 构建命令：`xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath <fresh DD> build CODE_SIGNING_ALLOWED=NO`；Release 配置同形状（`-configuration Release`）。每次用全新 DD。
5. **多窗口并发**：编辑前先 `ls -lt` 查 mtime 并重读目标区域；只编辑本窗口“文件所有权”文件；绝不覆盖他窗改动；不要 git add/commit。
6. 编译警告冻结：只允许 2 条既有警告键，不得引入新警告。
7. 已定案决策（不重新争论）：意图按钮是按钮含义（label 用 `dialogueIntentLabel`），不写玩家固定人格台词；一次展示 1–3 句同说话人；文字速度四档即时生效；`warning_2` 结束必须关闭会话归还控制；`ending_departure` 是 world-grid 锚点（creek_market (3,5) 交互位）；Q09 前任何普通界面不得暴露 reveal 内容；DEBUG fixture（DemoSessionFixture 等）不得进 Release；不开发 A*，短路径用预制路点 + SKAction，不安全时淡出/切拍。

## 1. 现状

- 领域只读可用：`StoryDialogueService.view(state:settings:catalog:)` 生成 `StoryDialogueView`；`StoryDialogueInputRouter` 走现有 `InputBindingsService` 重绑定 action（键鼠/手柄同路径）；`StoryDialogueSession` 已持久化；`StoryContentCatalog.visibleLines/visibleBlockingCue(finaleUnlocked:)` 做 Q09 前零泄露；`StoryAnchorCatalog.journeyScenes` 三个旅程模态小场景（旧水路/雾岭岔路/灰栅农场，journey-local 锚点 + 局部碰撞 + 成对入口/出口）；`FinaleService.recallPreReveal` 供画廊读取。
- 当前 ContentView/FarmScene 只有旧单说话人 DialoguePresentationLayer；需要新增独立 StoryDialoguePresentationLayer，不塞进旧对话路径。

## 2. 文件所有权

- 可编辑：`ContentView.swift`、`FarmScene.swift`、`CreekSproutApp.swift`、`Presentation/` 下新建文件（StoryDialoguePresentationLayer.swift、StoryJourneySceneView.swift、StoryGalleryView.swift 等，文件名自定但职责分离）。
- 禁止编辑：任何 Domain/Content/Persistence 领域文件、全部 N027 测试文件、`docs/game/project-ledger.md`。若发现领域缺口，只记录到交接文件，由对应窗口/后续审查处理，不在本窗口改领域。

## 3. 接线范围（最小可玩）

1. FarmScene 暴露 storyDialogue 状态：由 `StoryDialogueService.view` 生成 + `StoryDialogueInputRouter` 路由，走现有 InputBindingsService 重绑定 action，键鼠/手柄同路径；对话框可取消并归还控制（cancelSession）。
2. ContentView 增加 `StoryDialoguePresentationLayer`：分页 1–3 句同说话人；意图按钮 label 用 `dialogueIntentLabel`；AX label/identifier/focus 顺序；文字速度四档即时生效。
3. Q08 三个旅程模态小场景视图：journey-local 锚点、局部碰撞、检查点入口/出口配对、SKAction/淡出切拍；不开发 A*。
4. 结局画廊视图：账簿页（discoveredLedgerPageIDs）、分支批注（discoveredAnnotationIDs）、英雄牌与合照（keepsakeIDs）、毕业结果（endingID）、pre_reveal 读取（recallPreReveal）。
5. DEBUG 专用 fixture（DemoSessionFixture 等）不得进入 Release；Release 构建需实测确认（构建成功 + 产物中无 fixture 调用路径，记录检查方式）。
6. 真实 Debug App 冒烟（用隔离证据根，不碰生产存档）：启动→新游戏选槽→晨报→触发一段剧情对白→取消归还控制；960×640 与 1280×800、100%/125%/150% UI scale 各截关键界面证据入 `artifacts/integration/n-027-main-story-runtime/runtime/`（截图保存窗口尺寸、UI scale、运行配置、剧情状态；不得读取/覆盖/删除/恢复 production 存档或设置，前后生成 production 目录 SHA-256 manifest 且 diff 为空）。

## 4. 完成标准

1. Debug 构建成功且真实 App 冒烟路径可用（截图证据落盘 runtime/）。
2. Release 构建成功且不含 DEBUG fixture。
3. 无新警告（Debug 与 Release 各查一次 warning 集合 == 2 条冻结键）。
4. 领域行为零改动（交接文件列出 diff 说明）。

## 5. 交接输出

写 `artifacts/integration/n-027-main-story-runtime/presentation-handoff.md` + `runtime/` 证据。窗口结束时用中文给出一句结果 + 该文件路径。
