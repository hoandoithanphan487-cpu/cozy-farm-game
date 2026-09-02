# N-015-VSCODE-CHAR-TRACE-01 交接文档

- Package：`N-015-VSCODE-CHAR-TRACE-01` — 立绘同源角色追踪与独立复核包
- Task：N-015（项目状态不变：`active / PENDING`）
- Specialist owner：🛠️ tools / data
- Department quality owner：🧱 tech
- Cross-department reviewer：🛡️ quality
- Downstream handoff：Codex 的 🧱 tech 独立接收
- 日期：2026-08-25

## 1. Outcome

`READY FOR CODEX REVIEW`

本包把 Codex 在 N-015 角色 R1 中接入的 19 个立绘同源运行时角色文件纳入权威消费者追踪链：132 项消费者矩阵、标准库验证器与契约 XCTest 已同步到新的可审计来源，并提供了独立负向突变与静态一致性证据。未自签 `APPROVED`，未更改 N-015 台账状态，未启动 N-016。

## 2. 依赖预检结果

PASS。

| 检查项 | 结果 |
|---|---|
| N-015 状态 | `active / PENDING` ✅ |
| N-006 / N-009 / N-010 / N-013 / D0-002 | 均 `accepted / APPROVED` ✅ |
| DEC-031～DEC-035 | 均存在 ✅ |
| `docs/game/n-015-character-overrides.json` | 存在，声明 19 个资产（8 idle / 8 walk / 3 action） ✅ |
| `artifacts/integration/n-015-character-r1/evidence/validation-runtime.json` | `PASS` ✅ |
| `artifacts/integration/n-015-character-r1/evidence/runtime-art-audit.json` | `overall_pass: true` ✅ |
| `artifacts/integration/n-015-character-r1/real-app/index.json` | 17 个 captures ✅ |
| `validate-n015-character-sheets.py`（processed ↔ runtime） | PASS: 19 processed assets，exit 0 ✅ |
| `audit-runtime-art-integration.py --require-all-consumers` | exit 0；132 manifest / 132 PNG / 132 resolved / 0 unreferenced / 0 missing / 0 extra ✅ |

**旧追踪缺口复现**：旧验证器精确返回 `FAIL`，且恰好是 19 个 `char_*.png` 的 SHA-256 mismatch（19/19，无一例外），与本包预期完全一致。

## 3. 修改文件清单

只写入了授权边界内的文件：

| 文件 | 变更 |
|---|---|
| `docs/game/n-015-runtime-consumer-matrix.json` | `generated_from` 加入 `docs/game/n-015-character-overrides.json`（确定性顺序：base → N-003 → N-015 character → DEC-033 → audit）；19 条 `char_*.png` 记录的 `provenance` 改为 `n015_portrait_derived_override`（4 条原 `n003_approved_override`、15 条原 `n006_base`）；其余 113 条记录零改动 |
| `scripts/validate-n015-consumer-matrix.py` | 新增第四个权威来源与覆盖顺序；`VALID_PROVENANCE` 加入 `n015_portrait_derived_override`；`provenance_of()` 从权威集合推导；新增 19 项角色 override 清单验证（集合 19、全属正式集合、全 char、8/8/3 尺寸、SHA/IHDR 与磁盘一致）；来源计数精确 104/8/1/19；132 全部 `integrated`；`generated_from` 精确校验；新增最小 `--character-overrides` 参数（默认仍为仓库权威路径，仅供只读验证与负向测试）；修复 `--refresh-matrix` 配合仓库外临时路径时的 `relative_to` 崩溃 |
| `macos/CreekSprout/CreekSproutTests/N015RuntimeConsumerMatrixTests.swift` | 保留既有测试并同步 provenance 期望（104/8/19/1）；新增 5 个同步断言（manifest 精确一致、全 char+integrated、8/8/3 尺寸、其余 113 条不误标、`generated_from` 含新 manifest）；新增权威 subprocess 正向测试 + 6 个负向测试（真实调用同一验证器，Xcode Developer Tools 框架 Python，文件重定向防死锁，仅写系统临时目录） |
| `docs/game/n-015-vscode-character-trace-handoff.md` | 本文档 |
| `artifacts/integration/n-015-vscode-character-trace/**` | 独立证据（见 §6、§8、§10） |

## 4. 旧 19 mismatch → 新 PASS 的原因与证据

旧验证器只把 base manifest、N-003 override、DEC-033 addition 作为权威来源。角色 R1 在磁盘 Assets 上以新哈希替换了 19 个角色文件，但 `docs/game/n-015-character-overrides.json` 不在旧验证器的权威集合里，因此旧验证器拿 base/N-003 的旧 SHA 与磁盘比较，精确报出 19 个 mismatch（`/tmp/n015-trace-matrix-preflight.json`，19/19 全为 `char_*.png`）。

新验证器把 `docs/game/n-015-character-overrides.json` 作为第四个权威来源，按 base → N-003 → N-015 character → DEC-033 的覆盖顺序解析最终 132 项集合；19 个角色文件的预期 SHA 来自 override manifest，与磁盘逐文件一致 → PASS（exit 0，failures 0）。角色 R1 之前 Codex 侧权威审计（132/132 runtime audit PASS）与本包结论互相印证。

## 5. 来源覆盖顺序与 104/8/1/19 计数

覆盖顺序：`runtime-batch-r0/manifest.json` → `n-003-first-round/pixel-check.json` → `n-015-character-overrides.json` → `n-015-runtime-additions.json`；消费者解析仍唯一依赖 `scripts/audit-runtime-art-integration.py`（实时 subprocess，任一失败即 FAIL，无成功 fallback）。

同步后的来源计数（验证器实测）：

| 来源 | 计数 |
|---|---:|
| `n006_base` | 104 |
| `n003_approved_override` | 8 |
| `n015_portrait_derived_override` | 19 |
| `dec033_approved_addition` | 1 |
| **合计** | **132** |

19 个新角色 override 覆盖了 15 个原 N-006 角色文件与 4 个原 N-003 静态角色文件（`char_player`、`char_water_apprentice`、`char_seed_steward`、`char_creek_warden`），不重复计数。`--refresh-matrix` 确定性重建的矩阵与当前矩阵逐字节一致。

## 6. 负向测试（每个均含真实 FAIL 证据）

六类负向突变全部通过 subprocess 调用同一权威验证器（`scripts/validate-n015-consumer-matrix.py`），在隔离临时副本上执行；每例 exit 1、可解析 FAIL JSON、`errors` 非空、stderr 无 Traceback。证据：`artifacts/integration/n-015-vscode-character-trace/negative-case-summary.json`。

| # | 突变 | 结果 | 代表性错误 |
|---|---|---|---|
| 1 | 删除一个 character override 记录 | FAIL | `provenance 'n015_portrait_derived_override' != expected ...`；`n015... set != character override manifest`；`declares 18 files, expected 19` |
| 2 | 篡改一个 character override SHA | FAIL | `char_player.png: sha256 mismatch` |
| 3 | 把一个角色矩阵 provenance 改回 `n006_base` | FAIL | `char_player.png: provenance 'n006_base' != expected 'n015_portrait_derived_override'` |
| 4 | 把一个非角色资产标成 `n015_portrait_derived_override` | FAIL | `crop_amber_bean.png: provenance ... != expected 'n003_approved_override'` |
| 5 | duplicate character override filename | FAIL | `character override manifest has duplicate filename(s)` |
| 6 | 缺少必填字段 | FAIL（可解析 JSON，无崩溃） | `assets[0]: missing or empty field 'provenance'` |

## 7. XCTest 权威计数

| 运行 | 结果 | xcresult |
|---|---|---|
| Focused（`-only-testing:CreekSproutTests/N015RuntimeConsumerMatrixTests`） | **27 passed / 0 failed / 0 skipped / 0 expected failures** | `/tmp/n015-vscode-character-trace-focused/Logs/Test/Run-CreekSprout-2026.08.25_01-01-51--0700.xcresult` |
| Full（`clean test`） | **385 passed / 0 failed / 0 skipped / 0 expected failures** | `/tmp/n015-vscode-character-trace-full/Logs/Test/Run-CreekSprout-2026.08.25_01-02-43--0700.xcresult` |

本包开始前全量基线为 373 passed。本次 385 = 373 + 12 新增（5 同步断言 + 1 权威正向 + 6 负向），满足"总数 ≥ 373 且 failed/skipped/expected failures 全为 0"。subprocess 测试在 App Sandbox 内通过 Xcode Developer Tools 框架 Python 真实执行验证器，未用历史 xcresult 冒充。

## 8. Runtime audit 与 real-App 证据静态审计

- 权威审计（`--require-all-consumers`）：`overall_pass: true`；manifest 132 / Assets PNG 132 / resolved 132 / unreferenced 0；missing/extra/dimension/hash/invalid 全 0。输出：`/tmp/n015-vscode-runtime-audit-final.json`，摘要：`artifacts/integration/n-015-vscode-character-trace/consumer-audit-summary.json`。
- Real-App 证据静态一致性：`index.json` capture_count = 17；17 个截图与 17 个 HUD 导出（.txt）全部存在且非空；无缺失、无空文件 → PASS（`real-app-evidence-check.json`）。
- 19 个角色 override 清单（filename / manifest size / manifest SHA-256 / 磁盘 SHA-256 / 字节数）：全部一致 → `character-override-inventory.json`。
- 8 张高清立绘保留不动：角色 R1 只替换 `macos/CreekSprout/CreekSprout/Assets` 下的地图像素资源；本包零 PNG 改动（见 §10）。

## 9. `git diff --check` 与文件边界

- `git diff --check -- <四个文件>`：exit 0，无输出（三个既有文件为未跟踪状态，`git diff` 对未跟踪文件不生效）。
- 补充 `git diff --no-index --check /dev/null <file>`（docs/ 与 artifacts/ 为未跟踪文件的既有情况）：四个文件均无 whitespace-error 行（exit 1 表示"存在差异"而非空白问题，输出为空即通过）。
- 文件边界报告：以包开始前捕获的 `git status` 为基线，本次新增/变化的 git status 条目全部落在授权边界内，越界 0 → PASS（`file-boundary-report.json`）。

## 10. 明确声明

- 生产 Swift、`macos/CreekSprout/CreekSprout/Assets/**`、`Presentation/Portraits/**`、`Presentation/**`、`FarmScene.swift`、`ContentView.swift`、`Audio/**`、`Content/**`、`Domain/**`、`Persistence/**`、`CreekSprout.xcodeproj/**`、其他既有 XCTest：**均未修改**（0 改动）。
- 高清立绘 8 张：**未修改**（0 改动）。
- 角色生成包 `artifacts/integration/n-015-character-r1/**`、`scripts/process-n015-character-sheets.py`、`scripts/validate-n015-character-sheets.py`、`scripts/audit-runtime-art-integration.py`：**未修改**。
- 项目台账 `docs/game/project-ledger.md`：**未修改**；N-015 保持 `active / PENDING`。
- 未生成或修改任何 PNG；未调整美术；未改运行时行为。

## 11. 风险、假设与下一负责人

- 风险：`artifacts/` 与部分 `docs/` 文件在 Git 中未跟踪，`git diff` 无法直接审计其内容差异；本包以 `git diff --no-index` 与逐字节确定性对比补足。
- 假设：角色 R1 的 19 个 override 是 N-015 字符追踪链的最终正式来源；若 Codex 后续重做角色美术，需更新 `n-015-character-overrides.json` 并重新运行本包验证。
- 下一负责人：**Codex 🧱 tech 独立接收**（独立审查本包证据后签发 `APPROVED` / `REVISE` / `BLOCKED`）。最终视觉验收仍归 Product Owner；不启动 N-016。

## 12. 复现命令

```bash
python3 scripts/validate-n015-consumer-matrix.py \
  --write-evidence artifacts/integration/n-015-vscode-character-trace
python3 artifacts/integration/n-015-vscode-character-trace/generate-evidence.py
xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/n015-vscode-character-trace-focused \
  -only-testing:CreekSproutTests/N015RuntimeConsumerMatrixTests clean test
```
