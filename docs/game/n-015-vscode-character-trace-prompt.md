# VSCode 完整执行 Prompt：N-015 立绘同源角色追踪与独立复核包

把下面从“开始”到“结束”的全部内容原样交给 VSCode 中的 coding agent。

---

## 开始

你正在仓库 `/Users/fengyifan/Documents/VibeCoding` 工作。

你的工作包是 `N-015-VSCODE-CHAR-TRACE-01`。这是 Product Owner 在 N-015 内授权的独立工程追踪与质量复核包，不是新产品任务，也不是角色美术返工。Codex 已根据 8 张保留的高清立绘生成并接入 19 个地图角色运行时 PNG；你负责把原由 VSCode 维护的 132 项消费者矩阵、验证器和合同测试同步到新的可审计来源，并提供独立证据。

### 一、必须先读并遵守

开始前完整阅读：

1. `AGENTS.md`
2. `skills/cozy-farm-game-studio/SKILL.md`
3. `skills/cozy-farm-game-studio/references/roles.md`
4. `skills/cozy-farm-game-studio/references/production-workflow.md`
5. `skills/cozy-farm-game-studio/references/genre-blueprint.md`
6. `skills/project-ledger/SKILL.md`
7. `docs/game/project-ledger.md` 中 N-015、N-016、N-012、DEC-031～DEC-035
8. `docs/game/n-015-runtime-consumer-contract.md`
9. `docs/game/n-015-runtime-consumer-matrix.json`
10. `docs/game/n-015-character-overrides.json`
11. `docs/game/n-015-codex-phase-c-handoff.md`
12. `artifacts/integration/n-015-character-r1/HANDOFF.md`
13. `scripts/audit-runtime-art-integration.py`
14. `scripts/validate-n015-character-sheets.py`
15. `scripts/validate-n015-consumer-matrix.py`
16. `macos/CreekSprout/CreekSproutTests/N015RuntimeConsumerMatrixTests.swift`

把用户视为 Product Owner。当前工作树很脏，所有既有修改都属于用户或 Codex。禁止清理、还原、覆盖、重排或顺手格式化无关文件；禁止 `git reset`、`git checkout --`、`git clean`、递归删除、commit、push 或创建 PR。

### 二、依赖预检和已知基线

只读确认：

- N-015 为 `active / PENDING`。
- N-006、N-009、N-010、N-013、D0-002 均为 `accepted / APPROVED`。
- DEC-031～DEC-035 均存在。
- `docs/game/n-015-character-overrides.json` 存在且声明 19 个资产。
- `artifacts/integration/n-015-character-r1/evidence/validation-runtime.json` 为 `PASS`。
- `artifacts/integration/n-015-character-r1/evidence/runtime-art-audit.json` 为 `overall_pass: true`。
- 真实 App 证据 `artifacts/integration/n-015-character-r1/real-app/index.json` 声明 17 个 captures。

先运行并记录：

```bash
git status --short
python3 scripts/validate-n015-character-sheets.py \
  --processed-dir artifacts/integration/n-015-character-r1/processed \
  --runtime-dir macos/CreekSprout/CreekSprout/Assets \
  --report /tmp/n015-vscode-character-validation.json
python3 scripts/audit-runtime-art-integration.py --require-all-consumers
python3 scripts/validate-n015-consumer-matrix.py
```

预期旧矩阵验证器在第三条命令准确返回 `FAIL`，且恰好是 19 个 `char_*.png` 的 SHA-256 mismatch；这正是本包要关闭的追踪缺口。若前两条命令失败、失败集合不止这 19 个角色、资产总数不是 132、消费者不是 132/132，立即返回 `BLOCKED`，不要扩权修生产文件。

### 三、角色与门禁

- Department：🧱 Engineering & Pipeline
- Specialist owner：🛠️ tools / data
- Department quality owner：🧱 tech
- Cross-department reviewer：🛡️ quality
- Downstream handoff：Codex 的 🧱 tech 独立接收

你可以实现并自测，但不得给自己的包签发最终 `APPROVED`。最终只能返回 `READY FOR CODEX REVIEW`、`REVISE` 或 `BLOCKED`。

### 四、唯一允许写入的文件边界

只允许新增或修改：

```text
docs/game/n-015-runtime-consumer-matrix.json
scripts/validate-n015-consumer-matrix.py
macos/CreekSprout/CreekSproutTests/N015RuntimeConsumerMatrixTests.swift
docs/game/n-015-vscode-character-trace-handoff.md
artifacts/integration/n-015-vscode-character-trace/**
```

除此之外全部只读。尤其禁止修改：

```text
docs/game/project-ledger.md
docs/game/n-015-character-overrides.json
docs/game/n-015-codex-phase-c-handoff.md
artifacts/integration/n-015-character-r1/**
scripts/audit-runtime-art-integration.py
scripts/validate-n015-character-sheets.py
scripts/process-n015-character-sheets.py
macos/CreekSprout/CreekSprout/Assets/**
macos/CreekSprout/CreekSprout/Presentation/Portraits/**
macos/CreekSprout/CreekSprout/Presentation/**
macos/CreekSprout/CreekSprout/FarmScene.swift
macos/CreekSprout/CreekSprout/ContentView.swift
macos/CreekSprout/CreekSprout/Audio/**
macos/CreekSprout/CreekSprout/Content/**
macos/CreekSprout/CreekSprout/Domain/**
macos/CreekSprout/CreekSprout/Persistence/**
macos/CreekSprout/CreekSprout.xcodeproj/**
任何其他既有 XCTest
```

若完成任务必须越界，返回 `BLOCKED`；不得自行扩大范围。

### 五、唯一目标

将 N-015 角色 R1 的 19 个正式 override 纳入权威消费者追踪链，同时证明：

1. 19 个新角色文件与 `n-015-character-overrides.json`、磁盘 Assets、运行时消费者矩阵逐文件一致。
2. 其余 113 个正式资产的来源和消费者记录完全不漂移。
3. 132/132 资产仍为 `integrated`，0 missing、0 extra、0 unreferenced。
4. 8 张高清立绘展示资源仍存在，角色 R1 只替换地图像素资源。
5. 验证器能用负向突变拒绝错误来源、错误哈希、漏项和越界 override。

不要生成或修改任何 PNG，不要调整美术，不要改运行时行为。

### 六、交付物 A：消费者矩阵来源同步

修改 `docs/game/n-015-runtime-consumer-matrix.json`：

- 在顶层 `generated_from` 加入 `docs/game/n-015-character-overrides.json`，保持确定性顺序。
- 新增合法 provenance：`n015_portrait_derived_override`。
- 仅把 `docs/game/n-015-character-overrides.json` 中列出的 19 个 `char_*.png` 记录改为该 provenance。
- 不得修改这 19 条记录的 `asset_key`、filename、category、native size、consumer、trigger、fallback、batch、runtime_status 或 blocker。
- 不得修改其余 113 条记录的任何字段。

同步后的来源计数必须精确为：

```text
n006_base                       104
n003_approved_override            8
dec033_approved_addition           1
n015_portrait_derived_override    19
total                            132
```

解释：19 个新角色 override 覆盖了 15 个原 N-006 角色文件和 4 个原 N-003 静态角色文件；不能重复计数。

### 七、交付物 B：权威验证器同步

修改 `scripts/validate-n015-consumer-matrix.py`：

1. 继续只用 Python 3 标准库。
2. 将 `docs/game/n-015-character-overrides.json` 作为第四个权威来源，并在 base → N-003 override → N-015 character override → DEC-033 addition 的明确覆盖顺序中解析最终 132 项集合。
3. `VALID_PROVENANCE` 加入 `n015_portrait_derived_override`。
4. `provenance_of()` 必须从权威集合推导，不能按文件名前缀猜测。
5. 验证 19 个 character override：
   - 文件集合恰好 19；
   - 全部属于最终 132 项正式集合；
   - 全部 category 为 `char`；
   - 8 个 32×48 idle；
   - 8 个 128×192 walk；
   - 3 个 128×192 player action；
   - SHA-256、IHDR 尺寸与磁盘 Assets 一致。
6. 验证来源集合互斥后的计数精确为 104/8/1/19。
7. 继续调用权威 `audit-runtime-art-integration.py --require-all-consumers`；任一非零、超时、空输出或非法 JSON 必须明确 `FAIL`，禁止成功 fallback 或复制审计算法。
8. 验证 matrix 的 132 个 `runtime_status` 全部为 `integrated`，resolved consumer 集合恰好 132。
9. 正常与失败路径都输出可解析 JSON；成功 exit 0，失败 exit 1，错误包含具体 filename/field。
10. `--write-evidence` 输出保持确定性，至少更新：
    - `validation-report.json`
    - `matrix-summary.json`
    - `SHA256SUMS.txt`
11. 不得修改 `docs/game/n-015-character-overrides.json` 来迁就验证器。

### 八、交付物 C：合同和负向 XCTest

修改 `N015RuntimeConsumerMatrixTests.swift`，保留既有测试并同步 provenance 期望。至少新增/更新这些断言：

1. 来源计数精确为 104/8/1/19，总数 132。
2. 19 个 `n015_portrait_derived_override` 文件集合与 JSON override manifest 完全一致。
3. 19 条全部 category=char、runtime_status=integrated。
4. 静态/行走/玩家动作数量与尺寸分别为 8/8/3。
5. 其余 113 条不得误标为 N-015 character override。
6. `generated_from` 包含新的 override manifest。
7. 通过 subprocess 对隔离临时副本执行负向测试，至少覆盖：
   - 删除一个 character override 记录 → FAIL；
   - 篡改一个 character override SHA → FAIL；
   - 把一个 character matrix provenance 改回 n006_base → FAIL；
   - 把一个非角色资产标成 n015_portrait_derived_override → FAIL；
   - duplicate character override filename → FAIL；
   - 缺少必填字段时返回可解析 FAIL JSON，不得崩溃。
8. 负向测试必须调用同一权威验证器，不得复制验证算法、忽略退出码、XCTSkip 或在 subprocess 失败时本地补算成功。
9. 测试只可写系统临时目录，不得改仓库文件。

如果现有 CLI 缺少隔离输入参数，可在允许修改的验证器中增加最小的 `--matrix`、`--character-overrides` 参数，仅供只读验证和负向测试；默认仍指向仓库权威路径。

### 九、交付物 D：独立证据与交接

证据目录：

`artifacts/integration/n-015-vscode-character-trace/`

至少产出：

- validator 正常 PASS JSON；
- provenance summary；
- 六类负向突变摘要；
- 19 个角色 override 的 filename/size/SHA-256 清单；
- 132 项集合与消费者审计摘要；
- 真实 App evidence index 的静态一致性检查：capture_count=17，17 个截图与 17 个 HUD 文件存在且非空；
- 文件边界报告；
- focused/full XCTest 摘要和 xcresult 路径。

创建 `docs/game/n-015-vscode-character-trace-handoff.md`，必须包含：

1. Outcome：`READY FOR CODEX REVIEW` / `REVISE` / `BLOCKED`
2. 依赖预检结果
3. 修改文件清单
4. 旧 19 mismatch → 新 PASS 的原因与证据
5. 来源覆盖顺序和 104/8/1/19 计数
6. 每个负向测试及其真实 FAIL 证据
7. focused/full XCTest 权威计数
8. runtime audit 与 real-App evidence 静态审计
9. `git diff --check` 和文件边界
10. 明确声明生产 Swift、Assets、高清立绘、角色生成包、审计脚本和台账均未修改
11. 风险、假设和下一负责人：Codex 🧱 tech 独立接收

### 十、必须执行的验证

依次运行：

```bash
python3 scripts/validate-n015-consumer-matrix.py \
  --write-evidence artifacts/integration/n-015-vscode-character-trace

python3 scripts/validate-n015-character-sheets.py \
  --processed-dir artifacts/integration/n-015-character-r1/processed \
  --runtime-dir macos/CreekSprout/CreekSprout/Assets \
  --report /tmp/n015-vscode-character-validation-final.json

python3 scripts/audit-runtime-art-integration.py \
  --require-all-consumers \
  --output /tmp/n015-vscode-runtime-audit-final.json

xcodebuild \
  -project macos/CreekSprout/CreekSprout.xcodeproj \
  -scheme CreekSprout \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/n015-vscode-character-trace-focused \
  -only-testing:CreekSproutTests/N015RuntimeConsumerMatrixTests \
  clean test

xcodebuild \
  -project macos/CreekSprout/CreekSprout.xcodeproj \
  -scheme CreekSprout \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/n015-vscode-character-trace-full \
  clean test

git diff --check -- \
  docs/game/n-015-runtime-consumer-matrix.json \
  scripts/validate-n015-consumer-matrix.py \
  macos/CreekSprout/CreekSproutTests/N015RuntimeConsumerMatrixTests.swift \
  docs/game/n-015-vscode-character-trace-handoff.md

git status --short
```

本包开始前全量权威基线为 373 passed、0 failed、0 skipped、0 expected failures。修改测试后总数应大于或等于 373，且 failed/skipped/expected failures 全为 0。不得用历史 xcresult 冒充本次结果；若环境不能运行 Xcode，返回 `BLOCKED`。

### 十一、最终回复格式

最终回复必须精确包含：

```text
Outcome: READY FOR CODEX REVIEW | REVISE | BLOCKED
Dependency preflight: PASS | FAIL
Old trace gap reproduced: 19/19 character SHA mismatches | FAIL
Updated validator: PASS | FAIL
Character assets: 19/19
Runtime consumers: 132/132, unreferenced 0
Provenance: n006=104, n003=8, dec033=1, n015_character=19
Negative mutations: X/X rejected
Focused tests: X passed, 0 failed, 0 skipped
Full tests: X passed, 0 failed, 0 skipped
Real-App evidence static audit: 17/17
File boundary: PASS | FAIL
Production Swift changed: 0
Runtime/HD PNG changed: 0
Ledger changed: 0
Next gate: Codex independent 🧱 tech review
```

不要宣称 Product Owner 已视觉批准，不要把 N-015 改成 accepted，不要启动 N-016，不要自行签发 `APPROVED`。

## 结束

