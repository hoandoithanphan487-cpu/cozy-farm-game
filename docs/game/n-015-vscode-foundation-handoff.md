# N-015-VSCODE-FDN-01 基础建造包交接

- 工作包：`N-015-VSCODE-FDN-01`
- 任务：N-015（台账 `active / PENDING`）
- 授权决策：DEC-034（Product Owner 指定 VSCode 承担基础建造，Codex 承担核心与美术）
- 日期：2026-08-23（r4：响应 🧱 tech 门禁 `REVISE` 审计单一权威来源收尾）
- 专项负责人：🛠️ tools / data
- 部门质量负责人：🧱 tech
- 跨部门审查：🛡️ quality
- 下游交接：Codex / 🎮 gameplay + 🎨 art

## Outcome

为 Codex 后续 B2–B5 的核心与美术接入建立了可审计地基：

1. 生成 132 项逐文件运行时消费者矩阵（`docs/game/n-015-runtime-consumer-matrix.json`）。
2. 建立独立标准库验证器（`scripts/validate-n015-consumer-matrix.py`），证明矩阵、磁盘资产、批准清单与当前消费者审计一致。验证器内置 `--refresh-matrix` 确定性刷新模式，不再依赖 gitignore 的 `generate-matrix.py`。
3. 增加只验证合同、不改运行时行为的 XCTest 套件（15 项测试，含 5 项负向契约测试，`N015RuntimeConsumerMatrixTests.swift`）。
4. 导出可重复生成的机器证据与交接文档。

未实现任何玩家画面、运行时消费者、动画、HUD、美术、音频或地图布局（这些全部归 Codex）。

## Changed artifacts

仅以下路径（全部在 DEC-034 允许范围内）：

```text
docs/game/n-015-runtime-consumer-matrix.json                  （交付物 A，新增）
scripts/validate-n015-consumer-matrix.py                      （交付物 B，新增，含 --refresh-matrix）
macos/CreekSprout/CreekSproutTests/N015RuntimeConsumerMatrixTests.swift  （交付物 C，新增，15 项含负向测试）
artifacts/integration/n-015-vscode-foundation/validation-report.json     （验证报告）
artifacts/integration/n-015-vscode-foundation/matrix-summary.json        （矩阵摘要）
artifacts/integration/n-015-vscode-foundation/SHA256SUMS.txt             （132 项 SHA-256）
docs/game/n-015-vscode-foundation-handoff.md                  （本交接文档）
```

未修改任何 PNG、核心运行时代码、HUD、音频、领域规则、存档、经济、地图拓扑、Xcode 工程文件或项目台账。

## Validation evidence

### 依赖预检（只读）

- N-015 状态：`active / PENDING`（台账确认，未修改）。
- 依赖 N-006、N-009、N-010、N-013、D0-002：均为 `accepted / APPROVED`。
- DEC-031、DEC-032、DEC-033、DEC-034：均已记录。
- 权威审计 `scripts/audit-runtime-art-integration.py`：`overall_pass: true`，资产 132 张。

### 交付物 B 验证器输出

```text
python3 scripts/validate-n015-consumer-matrix.py --write-evidence artifacts/integration/n-015-vscode-foundation
```

结果：`PASS`，`failures=0`。

- 磁盘 Assets（132）= 批准集合（132）= 矩阵集合（132），三者文件集合完全相等。
- **逐文件 provenance 严格比较**（非仅汇总）：从 N-003/N-006 manifests 与木蜜灶台记录精确推导每个 filename 的 provenance，逐行比对；`n006_base=119`、`n003_approved_override=12`、`dec033_approved_addition=1`。
- **逐字段严格比较**：category、planned_consumer、trigger_state、fallback、batch、provenance 全部按权威映射规则逐行比对；任何虚构消费者、错误批次、来源互换或错误分类均返回非零退出码。
- 分类计数：building 30 / char 19 / crop 25 / fx 16 / gather 3 / prop 7 / tile 22 / tool 3 / ui 7。
- 矩阵 `integrated`（53）严格等于权威审计 `resolved_referenced`（53）。
- B4 建筑 30 层全部 `blocked` 且 blocker 非空。
- PNG IHDR（RGBA color_type 6）、尺寸、SHA-256 全部独立复验通过。
- 确定性：`--refresh-matrix` 幂等（刷新后矩阵逐字节一致）；重复运行 stdout 逐位一致（`diff` 为空）。

### 负向契约验证（REVISE 第 3/4 项）

验证器对以下篡改均返回非零退出码 + 可解析 FAIL JSON（result=FAIL、failures>0、errors 含具体 filename/字段、无 traceback）：

- 两个资源互换 provenance（汇总 119/12/1 不变）→ `FAIL`（逐文件比较捕获）。
- `planned_consumer` 改为 `DefinitelyNotARealConsumer` → `FAIL`。
- 建筑 batch 改为 `B1` → `FAIL`。
- crop 的 category 改为 `building` → `FAIL`。
- **删除 provenance 必填字段** → `FAIL`（`assets[0]: missing or empty field 'provenance'`），不 KeyError 崩溃、stdout 始终可解析、stderr 无 traceback。

### 验证器健壮性（REVISE 第 1/2 项）

- `summary` 构建改用 `.get()` 安全取值，删除必填字段不再触发 KeyError。
- `main()` 外层 try/except 兜底，任何未预期异常都输出可解析 FAIL JSON 而非 traceback。
- 对「JSON 可解析但合同无效」的矩阵：stdout 始终可解析 JSON、result=FAIL、failures>0、errors 含具体 filename/字段、进程退出非零。

### 审计单一权威来源（REVISE 第 1–4 项）

- `run_audit()` 保持单一权威来源 `scripts/audit-runtime-art-integration.py`，已删除 `audit_in_process()` 及其复制的消费者扫描算法。
- 以下任一情况都抛异常（不 fallback 为成功）：subprocess 无法启动、returncode != 0、stdout 非合法 JSON、`overall_pass != true`。
- 异常由 `main()` 顶层保护输出可解析 FAIL JSON 并退出非零，不输出 traceback、不合成 `overall_pass=True`。
- 实测：模拟权威审计 `exit 1` 时，validator 输出 `result=FAIL`、`failures=1`、error 含 `authoritative audit exited 1`、exit=1、stderr 无 traceback。

### 定向 XCTest

```text
xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout \
  -destination 'platform=macOS' -parallel-testing-enabled NO \
  -only-testing:CreekSproutTests/N015RuntimeConsumerMatrixTests test
```

结果：15 tests、0 failures、`TEST SUCCEEDED`（含 5 项负向契约测试）。

说明：XCTest host 运行在 CreekSprout App Sandbox（`ENABLE_APP_SANDBOX = YES`）内，macOS 的 python3 均为 xcrun shim，沙箱禁止 xcrun（`xcrun: error: cannot be used within an App Sandbox`），因此 XCTest 无法通过 `Process` 运行 Python 验证器脚本。这 5 项负向测试是**等价合同测试**（Swift 进程内复现验证器的逐记录合同检查：必填字段、枚举合法性、逐文件 provenance/category/consumer/batch 推导），不是 Python CLI 自动化。Python CLI 的健壮性（无 KeyError 崩溃、审计失败必 FAIL、始终输出可解析 FAIL JSON）由沙箱外终端负向夹具证明（见「审计单一权威来源」与「负向契约验证」两节）。

### 全量 XCTest

```text
xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout \
  -destination 'platform=macOS' -parallel-testing-enabled NO test
```

结果：**289 tests、0 failures、0 skipped**（xcresult 权威计数 `total=289 passed=289 failed=0 skipped=0`）。

xcresult 路径：

```text
/Users/fengyifan/Library/Developer/Xcode/DerivedData/CreekSprout-gbsayxwynrkqivcpwgdarulvxunt/Logs/Test/Test-CreekSprout-2026.08.23_23-16-08--0700.xcresult
```

### 格式与边界审计

- `git diff --check`：exit 0。
- `git status --short`：仅新增允许路径（见 Changed artifacts），无越界。

## Baseline versus final test counts

| 指标 | 基线 | 最终 |
|---|---|---|
| 全量 XCTest | 274 | 289 |
| failures | 0 | 0 |
| skipped | 0 | 0 |
| 定向 N015 测试 | — | 15（10 合同 + 5 负向） |
| 资产总数 | 132 | 132 |
| 机器可解析消费者 | 53 | 53（矩阵 integrated 严格对齐） |

## File-boundary audit

- 新增/修改文件全部落在 DEC-034 允许的四个路径族内。
- 未触碰：`docs/game/project-ledger.md`、`docs/game/n-015-*.md`（除本 handoff 与 matrix）、`scripts/audit-runtime-art-integration.py`、`scripts/generate-*.py`、`macos/CreekSprout/CreekSprout/**`（生产代码、Assets、FarmScene、ContentView、Presentation、Audio、Content、Domain、Persistence）、`macos/CreekSprout/CreekSprout.xcodeproj/**`、任何既有 XCTest 文件。
- 新增测试文件 `N015RuntimeConsumerMatrixTests.swift` 被 `PBXFileSystemSynchronizedRootGroup` 自动纳入测试 target，未修改 `project.pbxproj`（全量 289 tests 已证明其被纳入并执行）。

## Decisions and assumptions

1. `integrated` 严格来自 `scripts/audit-runtime-art-integration.py` 实时 `resolved_referenced`（53 项），不凭感觉标绿，也不把 App Bundle 存在算作消费。
2. 未解析资产默认 `planned`（49 项）；B4 五建筑六层（30 项）按 `docs/game/n-015-building-layout-audit.md` 的 topology decision 设为 `blocked`，blocker 文案与该审计一致。
3. `provenance` 按 119/12/1 精确区分：12 张 N-003 approved overrides 与 1 张 DEC-033 addition 以权威清单判定，其余为 N-006 base。
4. 播种合同遵循 DEC-033 既定事实：不新增 `tool_seed`，播种使用当前种子物品图（矩阵中 5 张 crop 物品图的 `planned_consumer` 指向 `InventoryItemIconPresenter`）。
5. 验证器实时运行审计脚本（`scripts/audit-runtime-art-integration.py`）作为单一权威来源，避免与 Codex 并行推进的工作树产生漂移；审计失败（无法启动/非零退出/非 JSON/overall_pass 非 true）一律 FAIL，不 fallback、不合成成功。
6. 验证器是矩阵的单一权威来源：内置 `--refresh-matrix` 确定性刷新模式，不再依赖 gitignore 的 `generate-matrix.py`。
7. 验证器与矩阵生成逻辑均使用 Python 3 标准库，零第三方依赖。
8. XCTest 负向测试因 App Sandbox 禁止 xcrun 而无法运行 Python，改为在测试进程内以 Swift 复现同一合同检查（等价合同测试）；Python CLI 健壮性由沙箱外终端负向夹具覆盖。

## Risks and follow-ups

1. **工作树并行漂移**：Codex 正在并行推进核心/美术线，`resolved_referenced` 数量可能随其提交变化。验证器已设计为实时读取审计脚本，任何后续漂移都会在重跑时以非零退出码暴露。Codex 接入新消费者后，应重跑 `python3 scripts/validate-n015-consumer-matrix.py --refresh-matrix` 以同步矩阵。
2. **B4 建筑阻断未解除**：30 张建筑层仍 `blocked`，等待 Product Owner 在「地图重排」与「纯视觉缩小」之间选择（见 `n-015-building-layout-audit.md`）。
3. **矩阵为计划快照**：`planned` 的 49 项代表「计划消费者」，不等于运行时已接入；Codex 完成 B2–B5 后需将此矩阵的 `runtime_status` 从 `planned` 更新为 `integrated`（并保持与审计一致）。
4. `artifacts/` 被 gitignore（项目既有约定），证据文件不进入版本控制，但已落盘可审计。

## Requested department gate

`PENDING` —— 请求 🧱 tech 审查本基础建造包。本专项（🛠️ tools）不自签 `APPROVED`。

## Downstream handoff

Codex / 🎮 gameplay + 🎨 art —— 接收矩阵与验证器后，继续 B2–B5 的核心运行时、美术、HUD、建筑视觉与音频接入，并最终由 Codex 完成 N-015 台账门禁。
