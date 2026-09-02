# 窗口 4 — Phase H：N027TimelineTests 与确定性时间线/内容/净空证据

> 本文件是给新 Codex 窗口的完整执行 Prompt。直接整段粘贴到新窗口。

你正在本地仓库 `/Users/fengyifan/Documents/VibeCoding` 执行 N-027 的 **Phase H（时间线与机器证据）**：新增 `N027TimelineTests`（确定性模拟，禁止冒充真人试玩），并把四条证据落盘到证据根 `artifacts/integration/n-027-main-story-runtime/`。

## 0. 工作纪律

1. 先读：`AGENTS.md`、`skills/cozy-farm-game-studio/SKILL.md`、`skills/project-ledger/SKILL.md`、`docs/game/project-ledger.md`（N-027 行）、`docs/game/n-027-main-story-runtime-brief.md`、`docs/game/n-027-main-story-runtime-prompt.md`（尤其 §11.5 两条时间线）。
2. 禁止 git reset/restore/checkout/clean/commit；不联网、不装依赖、不接 LLM；不 spawn 子代理。
3. 工程 PBXFileSystemSynchronizedRootGroup（objectVersion 77），新增 .swift 自动入 target。
4. 测试命令（每次用全新 DerivedData）：
   `N027_EVIDENCE_ROOT=/Users/fengyifan/Documents/VibeCoding/artifacts/integration/n-027-main-story-runtime xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath <fresh DD> -only-testing:CreekSproutTests/N027TimelineTests test CODE_SIGNING_ALLOWED=NO`
   （`N027_EVIDENCE_ROOT` 是环境变量，测试内用 `ProcessInfo.processInfo.environment` 读取。）
5. **多窗口并发**：编辑前先 `ls -lt` 查 mtime 并重读；只新建/编辑本窗口文件；绝不覆盖他窗改动；不要 git add/commit。
6. 编译警告冻结：只允许 2 条既有警告键，不得引入新警告。
7. 已定案决策（不重新争论）：warning 夹具四要素 + `m3OffersPaused` 一致性；每段 completedActionIDs 配 actionReceipts；Q02/Q07 两完整跨睡眠预警日（warningTwoSleepEpoch>warningOneSleepEpoch 且进入日递增）；Q01/Q03–Q06 两独立预警节拍由可观察相关操作分隔；`warning_2` 结束会话归还控制、eruption 禁止同会话连播；四档支援（StorySupportTier 0_39/40_69/70_89/90_100）在 Q02/Q07/Q08 各有可观察快照差异且全档保留手工保底；Q07 后 <90 开放至多三项不同 +6 修复委托；从 Q01 warning_1 到 Q10 毕业暂停生成新 M3 offer。
8. 台账只由窗口 8 汇总更新，本窗口不改台账。

## 1. 现状与前置

- 前置：窗口 1/2/3 的 Phase D/F/G 应已绿（若尚未全绿，先只跑 TimelineTests 中不依赖它们的纯断言部分，等绿后再全量；时间线驱动需要合法夹具——参照 `N027JourneyTests.swift` 只读）。
- 证据发射设施：先读 `macos/CreekSprout/CreekSproutTests/N027EvidenceWriter.swift`（已存在）——用它把 JSON 写进 `N027_EVIDENCE_ROOT`，保持确定性（两次运行逐字节一致）。
- 现有可复用发射：`N027StoryBlockingTests.testPathClearanceEvidenceEmission` 已实现 path-clearance.json 发射，需要以 `N027_EVIDENCE_ROOT` 指向证据根重跑一次生成 `path-clearance.json`（50 cue × 全分支：双类锚点、可走、越界、碰撞、入口/出口配对、说话人、净空结论）。

## 2. 文件所有权

- 新建：`macos/CreekSprout/CreekSproutTests/N027TimelineTests.swift`。
- 可扩展（如需新发射函数）：`N027EvidenceWriter.swift`。
- 禁止编辑：窗口 1/2/3 的测试文件与领域文件、`ContentView.swift`、`FarmScene.swift`、`docs/game/project-ledger.md`。

## 3. 必须输出（证据根 artifacts/integration/n-027-main-story-runtime/）

1. `timeline-normal.json`：正常线，确定性模拟逐日驱动——通用劳动历史并行累计 + 因果型加码只认 benefit/offer 基线后增量；Q01 inspect_first → Q02 harvest → Q03 cut_test → Q04 publish_missing_page → Q05 coop → Q06 love → Q07 menu → standing≥90 → Q08 evidence → Q09 take_ledger → Q10 why_me → water 毕业；全程约第 28 日毕业。逐日列出劳动、成熟指标、预警、爆发、余韵、声誉、支援档与预计现实分钟；单列 Q08 与 Q09–Q10 主动用时。
2. `timeline-recovery.json`：恢复线——31 边界夹具（活动 M3 结清、Q01 warning_1 进入时 standing=31）→ Q01–Q07 七次 +6 → standing≥73 → 至多三项不同 +6 委托 ≤Day32 到 90 → Q08 old_waterway → Q09 close_ledger → Q10 silence → leave 毕业；Q01 warning_1 到 Q10 毕业期间不生成新 M3 offer。
3. `story-content-audit.json`：10 剧情 / 236 对白 sourceID 一一映射 / 50 cue / 全分支枚举 / 插值 token 白名单校验（{{reputation}}、{{q05_resolution}}，渲染后无 `{{...}}` 残留）。
4. `path-clearance.json`：见上（重跑 N027StoryBlockingTests.testPathClearanceEvidenceEmission，N027_EVIDENCE_ROOT 指证据根）。
- 两条时间线各阶段（benefit/warning_1/warning_2/eruption/aftermath 进入日、sleep epoch、standing、支援档）**逐项断言**在测试里；Q09 首次显示账簿到 Q10 毕业主动时长落在 30–45 分钟区间；时间线是确定性模拟，**声明不冒充一次自然 5–6 小时真人通关**（该判断留给 Product Owner）。
- 不得覆盖既有 `phase-a-tech-gate.md` / `phase-b-integration.md` / `tests/baseline-*.txt`。

## 4. 完成标准

1. `N027TimelineTests` 非零全绿（0 failed）；无新警告。
2. 四个 JSON 全部落盘且可被重跑复现（记录 fresh DD 路径与命令）。
3. 正常线约 Day28、恢复线 ≤Day32 的断言通过；若模拟不符，调整数据化节奏（在内容/指标参数内），不删剧情、不用等待灌时长，并把调整记录进交接文件。

## 5. 交接输出

写 `artifacts/integration/n-027-main-story-runtime/phase-h-integration.md`：模拟参数、Day28/Day32 结果、主动时长估算、证据文件清单与 DD 路径、剩余风险。窗口结束时用中文给出一句结果 + 该文件路径。
