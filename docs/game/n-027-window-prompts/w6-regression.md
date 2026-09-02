# 窗口 6 — 相邻回归 225/0 与全量基线对比（硬指标）

> 本文件是给新 Codex 窗口的完整执行 Prompt。直接整段粘贴到新窗口。

你正在本地仓库 `/Users/fengyifan/Documents/VibeCoding` 执行 N-027 的 **相邻回归与全量基线验收**。这是只读验证窗口：不改任何源码/测试/领域文件，只跑测试、对比基线、产出证据。

## 0. 工作纪律

1. 先读：`AGENTS.md`、`skills/cozy-farm-game-studio/SKILL.md`、`skills/project-ledger/SKILL.md`、`docs/game/project-ledger.md`（N-027 行）、`docs/game/n-027-main-story-runtime-prompt.md`（§11.6 测试命令与 extract_n027_xcresult）。
2. 禁止 git reset/restore/checkout/clean/commit；不联网、不装依赖；不 spawn 子代理；**不修改任何文件**，只写 `artifacts/integration/n-027-main-story-runtime/tests/` 下的证据文件。
3. 每次跑测试用全新 DerivedData 与全新 resultBundlePath，不复用旧 .xcresult；同一 shell 会话内使用唯一 `N027_RUN_ROOT`（`mktemp -d`）。
4. **多窗口并发**：本窗口只读源码；若发现文件正在被修改（mtime 持续变化），等待稳定后再跑基线，并在证据里记录。
5. 台账只由窗口 8 汇总更新，本窗口不改台账。

## 1. 前置

- 窗口 1–5 应已完成（Phase D/F/G/H 全绿、呈现层接线完成）。
- 基线文件已存在于 `artifacts/integration/n-027-main-story-runtime/tests/`：`baseline-failure-ids.txt`、`baseline-warning-ids.txt`、`baseline-metrics.json` 等（只读对比用，不覆盖）。

## 2. 执行（三组命令，全新 DD）

1. **N-027 专项**：全部 N027 测试类（N027PhaseATests、N027CropIrrigationTests、N027MorningCropReportTests、N027FormalSessionTests、N027StoryDialogueTests、N027StoryBlockingTests、N027Q01VerticalSliceTests、N027Q02Q07BranchTests、N027FosterSupplyTests、N027JourneyTests、N027EndingTests、N027TimelineTests）。验收：非零且 0 failed。
2. **相邻域 225 项**（类清单见 n-027 prompt §11.6 的 Adjacent 命令：ContentCatalogTests、CommunityContentTests、CommunityEventTests、CommunitySaveTests、EconomyCatalogTests、EconomySaveTests、InventoryServiceTests、FarmLoopTests、SettlementTests、SaveStoreTests、M4SaveAndUxTests、MapContentTests、MapTravelTests、GridMovementTests、GatherAndQuestTests、N022LivestockAndCatShopTests、PlacementServiceTests、SettingsTests、TutorialServiceTests、TutorialSaveTests、WatershedProgressionTests、WatershedSaveTests、ShippingServiceTests、WeatherServiceTests、N017DemoSessionTests）。验收：≥225、0 failed、warning 集合 == 2 条冻结键（无新增）。
3. **全量 clean test**：fresh DD。预期仍为 464 项 / 450 passed / 14 既有失败 / 2 警告（exit 65 属预期）。验收：失败标识集合与 warning 标识集合相对基线**无新增**；N027 相关类 0 失败。
   - 14 个既有失败类别：N015PhaseCRuntimeTests 1、N015RuntimeConsumerMatrixTests 7、N015RuntimeArtAndHudTests 1、N015PerformanceEvidenceTests 1、PixelAssetStoreTests 2、M4PerformanceTests 2。

## 3. 证据输出（tests/ 下）

- 三组各自：`*-metrics.json`（tests/failed/warnings 数）、`*-failure-ids.txt`、`*-warning-ids.txt`、result bundle 路径记录。
- 对比结论文件 `adjacent-full-regression.md`：命令、退出码、三组数字、失败/warning 集合 diff（`comm -13` 基线 vs 实测）、结论（无新增通过/失败）。
- 禁止宣称全量已绿；只写“失败/warning 标识集合无新增”。

## 4. 完成标准

- 专项非零 0 failed；相邻 ≥225/0；全量无新增失败/warning 标识。
- 证据文件全部落盘且可复核（含 bundle 路径）。

## 5. 交接输出

窗口结束时用中文给出一句结果 + `adjacent-full-regression.md` 路径。
