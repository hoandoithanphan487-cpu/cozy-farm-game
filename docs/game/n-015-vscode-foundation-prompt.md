# VSCode 执行 Prompt：N-015 非美术基础建造包

把下面从“开始”到“结束”的全部内容原样交给 VSCode 中的 coding agent。

---

## 开始

你正在 `/Users/fengyifan/Documents/VibeCoding` 仓库工作。

你的工作包是：`N-015-VSCODE-FDN-01`。它是台账任务 `N-015` 内部的、由 Product Owner 通过 `DEC-034` 授权的独立基础建造包，不是新的产品任务。

### 一、必须先遵守的项目规则

1. 完整阅读根目录 `AGENTS.md`。
2. 完整阅读并遵守：
   - `skills/cozy-farm-game-studio/SKILL.md`
   - `skills/cozy-farm-game-studio/references/roles.md`
   - `skills/cozy-farm-game-studio/references/production-workflow.md`
   - `skills/cozy-farm-game-studio/references/genre-blueprint.md`
   - `skills/project-ledger/SKILL.md`
3. 完整阅读：
   - `docs/game/project-ledger.md`
   - `docs/game/n-015-full-art-hud-brief.md`
   - `docs/game/n-015-foundation-plan.md`
   - `docs/game/n-015-runtime-consumer-contract.md`
   - `docs/game/n-015-foundation-review.md`
   - `docs/game/n-015-building-layout-audit.md`
   - `docs/game/n-015-runtime-additions.json`
4. 把用户视为 Product Owner。不得自行扩大玩法、美术、音频、地图或经济范围。
5. 当前工作树很脏，现有修改全部属于用户或 Codex。禁止清理、还原、覆盖、重排或顺手格式化无关文件。
6. 禁止执行 `git reset`、`git checkout --`、`git clean`、递归删除或任何破坏性清理。
7. 不要提交、不要 push、不要创建 PR、不要修改台账状态。最终只交付工作树改动与证据。

### 二、依赖预检与当前事实

开始实现前，执行只读预检：

- 在 `docs/game/project-ledger.md` 中确认 N-015 仍为 `active / PENDING`。
- 确认 N-015 的依赖 N-006、N-009、N-010、N-013、D0-002 均为 `accepted / APPROVED`。
- 确认 `DEC-031`、`DEC-032`、`DEC-033`、`DEC-034` 已记录。
- 若上述任一项不成立，停止开发并返回 `BLOCKED`，不得自行修台账。

当前权威基线：

- 正式运行时 PNG：132 张。
- 组合来源：119 张 N-006 base + 12 张 N-003 approved overrides + 1 张 DEC-033 木蜜灶台 addition。
- 当前机器审计：完整性通过；可解析消费者 53/132；未解析 79/132。
- 当前 XCTest 基线：274 tests、0 failures。
- N-015 仍为 `active / PENDING`；不得宣称全量接入完成。

先运行并保存只读基线：

```bash
git status --short
python3 scripts/audit-runtime-art-integration.py
```

如果审计不是 `overall_pass: true`，或资产数量不是 132，停止并返回 `BLOCKED`，不要尝试修改资产或核心代码。

### 三、角色与门禁

- Department：🧱 Engineering & Pipeline
- Specialist owner：🛠️ tools / data
- Department quality owner：🧱 tech
- Cross-department reviewer：🛡️ quality
- Downstream handoff：Codex 的 🎮 gameplay + 🎨 art

你是基础工具专项，不得给自己签 `APPROVED`。完成后只能请求 🧱 tech 审查，并返回 `PENDING`、`REVISE` 或 `BLOCKED` 事实。

### 四、本工作包的唯一目标

为 Codex 后续 B2–B5 的核心与美术接入建立可审计地基：

1. 生成 132 项逐文件运行时消费者矩阵。
2. 建立独立验证器，证明矩阵、磁盘资产、批准清单与当前消费者审计一致。
3. 增加一个只验证合同、不改运行时行为的 XCTest 套件。
4. 导出可重复生成的机器证据和清晰交接文档。

玩家画面、运行时消费者、动画、HUD、美术、音频和地图布局全部由 Codex 负责；你不得实现这些内容。

### 五、严格文件所有权

你只允许创建或修改以下文件：

```text
docs/game/n-015-runtime-consumer-matrix.json
docs/game/n-015-vscode-foundation-handoff.md
scripts/validate-n015-consumer-matrix.py
macos/CreekSprout/CreekSproutTests/N015RuntimeConsumerMatrixTests.swift
artifacts/integration/n-015-vscode-foundation/**
```

除上述路径外，任何文件都不得修改。

特别禁止修改：

```text
docs/game/project-ledger.md
docs/game/n-015-*.md（上面唯一允许的新 handoff 和 matrix 除外）
scripts/audit-runtime-art-integration.py
scripts/generate-*.py
macos/CreekSprout/CreekSprout/Assets/**
macos/CreekSprout/CreekSprout/FarmScene.swift
macos/CreekSprout/CreekSprout/ContentView.swift
macos/CreekSprout/CreekSprout/Presentation/**
macos/CreekSprout/CreekSprout/Audio/**
macos/CreekSprout/CreekSprout/Content/**
macos/CreekSprout/CreekSprout/Domain/**
macos/CreekSprout/CreekSprout/Persistence/**
macos/CreekSprout/CreekSprout.xcodeproj/**
任何既有 XCTest 文件
```

该 Xcode 工程使用 `PBXFileSystemSynchronizedRootGroup`，新增测试文件不需要修改 `project.pbxproj`。如果你的环境显示必须改工程文件，停止并返回 `BLOCKED`，不要越界。

### 六、交付物 A：132 项消费者矩阵

创建：

`docs/game/n-015-runtime-consumer-matrix.json`

矩阵必须覆盖 Assets 根目录中的全部 132 张正式 PNG，恰好一文件一记录，无重复、无遗漏。每条记录至少包含：

```json
{
  "asset_key": "稳定且唯一的 key",
  "filename": "example.png",
  "category": "char|crop|tile|building|prop|gather|tool|fx|ui",
  "native_width": 32,
  "native_height": 32,
  "provenance": "n006_base|n003_approved_override|dec033_approved_addition",
  "planned_consumer": "唯一计划消费者名称",
  "trigger_state": "由什么运行时状态触发",
  "fallback": "缺失或非法时的明确回退",
  "batch": "B1|B2|B3|B4|B5",
  "runtime_status": "integrated|planned|blocked",
  "blocker": null
}
```

矩阵顶层至少包含：

```json
{
  "schema_version": 1,
  "task": "N-015",
  "decision": "DEC-034",
  "generated_from": [],
  "expected_asset_count": 132,
  "assets": []
}
```

规则：

- `integrated` 只能来自 `scripts/audit-runtime-art-integration.py` 当前 `resolved_referenced` 的事实，禁止凭感觉手工标绿。
- 当前未解析资产默认 `planned`。
- 五建筑六层在 B4，因 `docs/game/n-015-building-layout-audit.md` 的 topology decision 设为 `blocked`，并填写一致 blocker。
- `provenance` 必须准确区分 119/12/1 三类来源。
- `planned_consumer` 必须与 `docs/game/n-015-runtime-consumer-contract.md` 的唯一消费者家族一致。
- 不得把 App Bundle 中存在等同于 `integrated`。
- 不得新增、改名或重导出任何 PNG。
- 不得为播种创建 `tool_seed`；播种使用当前种子物品图是 DEC-033 的既定事实。

### 七、交付物 B：独立验证器

创建：

`scripts/validate-n015-consumer-matrix.py`

要求：

- 只用 Python 3 标准库，不安装依赖。
- 默认只读；只有显式 `--write-evidence <directory>` 才写证据。
- 从以下权威来源组合批准集合：
  - `artifacts/art-style/runtime-batch-r0/manifest.json`
  - `artifacts/art-style/n-003-first-round/pixel-check.json`
  - `docs/game/n-015-runtime-additions.json`
- 独立解析 PNG IHDR，验证格式、宽高；计算 SHA-256。
- 验证磁盘 Assets、批准集合、矩阵三者文件集合完全相等且都为 132。
- 验证 asset_key 唯一、filename 唯一、枚举值合法、字段完整。
- 验证 provenance 计数恰好为 119/12/1。
- 调用或读取现有审计结果，验证矩阵 `integrated` 集合恰好等于当前 `resolved_referenced` 集合；不得复制一份容易漂移的手工算法。
- 验证 B4 全部建筑层为 `blocked` 且 blocker 非空。
- 验证其他 `planned` 项 blocker 可以为空，但禁止空字符串。
- 输出简洁 JSON 到 stdout，失败退出非 0，并逐项列出错误。
- `--write-evidence` 至少写：
  - `validation-report.json`
  - `matrix-summary.json`
  - `SHA256SUMS.txt`
- 输出必须确定性排序；同一工作树重复运行不得产生内容漂移。

### 八、交付物 C：XCTest 合同测试

创建：

`macos/CreekSprout/CreekSproutTests/N015RuntimeConsumerMatrixTests.swift`

测试只验证合同与仓库数据，不得修改任何生产代码。至少覆盖：

1. 矩阵可解码，schema_version 为 1，task 为 N-015，expected_asset_count 为 132。
2. assets 恰好 132，asset_key/filename 无重复。
3. 分类计数与当前正式集合一致。
4. provenance 计数为 119/12/1。
5. 5 种作物 × 4 阶段共 20 张均存在且字段完整。
6. 8 名角色静态图均存在；行走表是独立记录，不能误算为静态图。
7. 木蜜灶台存在、来源为 DEC-033 addition、尺寸为 48×48。
8. 不存在 `tool_seed.png`；三个正式工具图存在；播种合同在矩阵中指向当前种子物品图策略。
9. 30 个建筑六层记录全部属于 B4、状态 blocked、blocker 非空。
10. 测试只读，不创建或改写仓库文件。

测试可通过 `#filePath` 向上定位仓库，不得硬编码个人 DerivedData 路径。错误信息必须能指出具体 filename 或字段。

### 九、交付物 D：证据与交接

证据目录：

`artifacts/integration/n-015-vscode-foundation/`

运行：

```bash
python3 scripts/validate-n015-consumer-matrix.py \
  --write-evidence artifacts/integration/n-015-vscode-foundation

xcodebuild \
  -project macos/CreekSprout/CreekSprout.xcodeproj \
  -scheme CreekSprout \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:CreekSproutTests/N015RuntimeConsumerMatrixTests \
  test

xcodebuild \
  -project macos/CreekSprout/CreekSprout.xcodeproj \
  -scheme CreekSprout \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  test

git diff --check
git status --short
```

将原始命令、退出码、测试总数、失败数、xcresult 路径和边界审计写入：

`docs/game/n-015-vscode-foundation-handoff.md`

handoff 必须包含：

- Outcome
- Changed artifacts
- Validation evidence
- Baseline versus final test counts
- File-boundary audit
- Decisions and assumptions
- Risks and follow-ups
- Requested department gate
- Downstream handoff to Codex

### 十、验收标准

只有全部满足才算专项交付完成：

- 132/132 矩阵无缺失、无重复。
- 磁盘 Assets = 批准集合 = 矩阵集合。
- PNG、尺寸、哈希与 provenance 校验全部通过。
- `integrated` 集合严格等于权威审计的 resolved 集合。
- B4 建筑阻断被如实编码，不伪造完成。
- 定向 XCTest 通过。
- 全量 XCTest 不少于当前 274 条基线且 0 failures。
- `git diff --check` 通过。
- 最终 `git status --short` 证明只改了允许路径。
- 未修改任何 PNG、核心运行时代码、HUD、音频、领域规则、存档、经济、地图拓扑、项目文件或台账。

### 十一、失败与停止条件

遇到以下任一情况，立即停止并返回 `BLOCKED`：

- 依赖预检或 DEC-034 不成立。
- 权威审计不是 overall_pass=true 或不是 132 张。
- 完成任务必须修改禁止路径。
- 当前矩阵事实与批准 manifest 无法无歧义对齐。
- 新增测试文件无法被同步组自动纳入测试 target。
- 全量测试出现无法在允许路径内修复的回归。

不得通过修改生产代码、资产、旧测试或放宽断言来绕过失败。

### 十二、最终回复格式

完成后只按以下格式回复 Product Owner：

```markdown
Outcome:

Changed artifacts:

Validation evidence:

File-boundary audit:

Decisions and assumptions:

Risks and follow-ups:

Requested department gate: PENDING | REVISE | BLOCKED

Downstream handoff: Codex / 🎮 gameplay + 🎨 art
```

不要声称 N-015 已完成，不要自行给出 `APPROVED`，不要修改项目台账。

## 结束

