# VSCode 完整执行 Prompt：N-015 地图重排基础门禁包

你正在仓库 `/Users/fengyifan/Documents/VibeCoding` 工作。

你的工作包是 `N-015-VSCODE-MAP-01`。Product Owner 已通过 `DEC-035` 批准“地图重排”，但你只负责非美术、非生产代码的基础门禁；Codex 负责地图视觉方案、生产 Swift、全部美术、HUD、运行时接入和最终证据。

## 一、必须先读

开始前完整阅读：

1. `AGENTS.md`
2. `skills/cozy-farm-game-studio/SKILL.md`
3. 该 skill 要求的角色、流程与类型参考
4. `skills/project-ledger/SKILL.md`
5. `docs/game/project-ledger.md` 中 N-015、DEC-031～DEC-035
6. `docs/game/n-015-codex-runtime-review.md`
7. `docs/game/n-015-building-layout-audit.md`
8. `docs/game/n-015-runtime-consumer-contract.md`
9. `docs/game/n-015-runtime-consumer-matrix.json`
10. Codex 阶段 A 产出的：
   - `docs/game/n-015-map-rearrangement-spec.md`
   - `docs/game/n-015-map-layout-contract.json`

若最后两个文件任一不存在、为空、互相矛盾，或没有声明 `decision_id = DEC-035`，立即返回 `BLOCKED`；不得自行设计地图、补坐标或修改合同。

## 二、前置关系

本包必须在 Codex 阶段 A 完成后执行，并且必须在 Codex 生产实现阶段 C 之前获得独立技术接收。

```text
Codex A：美术构图与机器合同
              ↓ 强依赖
VSCode B：合同验证器与负向门禁（本工作包）
              ↓ 必须 APPROVED
Codex C：生产地图、美术、HUD、B4/B5 实现
```

不得与 Codex 阶段 C 并行运行。若发现 Codex 已在修改生产地图，而本包尚未交付，返回 `BLOCKED` 并报告并发风险。

## 三、角色与门禁

- 专项 owner：`🛠️ tools`
- 部门质量 owner：`🧱 tech`
- 你可以完成实现与自测，但不得给自己的包签发最终 `APPROVED`。
- 最终只能返回 `READY FOR CODEX REVIEW`、`REVISE` 或 `BLOCKED`。
- Codex 必须随后独立复核并签发接收结论。

## 四、唯一允许写入的范围

只允许新增或修改：

1. `scripts/validate-n015-map-layout-contract.py`
2. `macos/CreekSprout/CreekSproutTests/N015MapLayoutContractTests.swift`
3. `docs/game/n-015-vscode-map-foundation-handoff.md`
4. `artifacts/integration/n-015-vscode-map-foundation/**`

上面未列出的文件全部只读。尤其禁止修改：

- `docs/game/n-015-map-rearrangement-spec.md`
- `docs/game/n-015-map-layout-contract.json`
- `docs/game/project-ledger.md`
- `docs/game/n-015-runtime-consumer-matrix.json`
- `scripts/validate-n015-consumer-matrix.py`
- `scripts/audit-runtime-art-integration.py`
- 所有生产 Swift、Assets、音频、Xcode 工程文件和既有测试
- Codex 的 handoff、review 与 evidence 目录

不得生成或修改任何 PNG，不得改地图坐标，不得改 blocked cells、出生点、NPC 位置、出口、玩法、经济、任务、对白、稳定 ID 或存档 schema。

## 五、实现目标

### 5.1 权威验证器

实现 `scripts/validate-n015-map-layout-contract.py`：

- 只使用 Python 标准库。
- 权威输入只能是 Codex 冻结的 spec、JSON contract、现有消费者矩阵和只读资产清单。
- 不复制另一个脚本的审计算法；若调用权威审计 subprocess，任一非零、超时、空输出或非法 JSON 必须明确 `FAIL`，禁止成功 fallback。
- 正常与失败路径都输出可解析 JSON。
- 成功 exit 0，失败 exit 1。
- 支持：
  - `--contract-only`
  - `--write-evidence <directory>`
  - `--contract <path>`，仅用于隔离负向测试
- 不需要、也不得在本阶段声称生产 Swift 已匹配未来合同。

输出至少包含：

```json
{
  "schema_version": 1,
  "task": "N-015-VSCODE-MAP-01",
  "decision_id": "DEC-035",
  "result": "PASS",
  "failures": [],
  "summary": {
    "map_count": 2,
    "building_count": 5,
    "building_layer_count": 30,
    "reachable_required_target_count": 0,
    "save_relocation_rule_count": 0
  }
}
```

计数字段以实际合同推导，不得硬编码成只会通过一份文件的装饰性输出。

### 5.2 严格合同检查

验证器必须验证：

1. JSON schema、必填字段、类型、唯一 ID、稳定排序和未知字段策略。
2. 仅有两张既有地图 ID；不得虚构第三张地图或替换稳定 ID。
3. 五栋既有建筑完整出现且 footprint 固定为：
   - 木构农舍 5×4
   - 铜闸水工坊 5×4
   - 苔石埠头 5×2
   - 种源棚 3×2
   - 巡护亭 3×2
4. 每栋建筑必须有 `origin`、完整 footprint cells、入口、交互格、屋顶遮挡区域、所属地图、地标 ID 和六层正式 PNG。
5. 30 张建筑层必须与消费者矩阵中的 B4 文件逐文件一一对应；每栋严格六层：`base → structure → roof → detail → interaction → state_fx`。
6. footprint、不可通行水格、地图边界、出口、出生点、NPC、农田、采集节点与其他建筑之间无非法重叠。
7. 出生点、出口、NPC 脚点和建筑入口均位于地图内且非 blocked；NPC 至少有一个玩家可站立的相邻交谈格。
8. 以四方向 BFS 验证：每个出生点都能到出口、五栋建筑入口、任务关键 NPC、农田入口和合同列出的关键采集/交互目标。
9. 水体与水渠拓扑连续、方向一致；单格不能同时声明互斥的 tile 语义，不得用“叠齐所有边角资产”冒充正确布局。
10. 默认画面禁止项进入合同：`阻`、`石阶`、`采`、调试格文字和纯几何占位不能是正式视觉消费者。
11. 960×640 与 1280×800 的 HUD 安全区、世界可见区和建筑展示触发区均有明确合同，且不会永久吞掉玩家活动中心。
12. 旧存档兼容规则完整：不改变 schema；旧地图内任意可能玩家坐标若在新布局变为越界或 blocked，必须有确定性的最近安全格迁移策略和稳定 tie-break；合法坐标保持不动。
13. 地图重排不得改变经济、配方、任务、对白、NPC ID、建筑 ID、物品 ID、音频或 N-014 候选内容。
14. spec 中的人类可视坐标表、JSON 中的机器坐标与 footprint/layer 汇总逐项一致。

### 5.3 负向契约测试

`N015MapLayoutContractTests.swift` 必须通过 subprocess 调用同一个 Python 权威验证器，并至少覆盖这些独立突变：

- 删除一栋建筑
- footprint 越界
- 两栋建筑重叠
- 入口落入 blocked
- 出生点到出口不可达
- NPC 没有交谈相邻格
- 建筑缺一层或层序错误
- B4 provenance/filename 对调
- 同一水格声明互斥 tile
- 删除旧存档坐标迁移规则
- 虚构地图、建筑或 NPC 稳定 ID
- 删除必填字段时仍返回可解析 `FAIL` JSON，而不是崩溃

测试不得复制验证算法。它只负责制作临时突变合同、运行 CLI、断言 exit 1，并解析 `result=FAIL` 与非空 failures。

不得通过 `XCTSkip`、忽略退出码、捕获异常后改写成功或在 subprocess 失败时本地补算来制造绿灯。

### 5.4 确定性与可追踪性

- 对同一合同连续运行两次，JSON 结果与 evidence 文件逐字节一致，时间戳不得污染确定性文件。
- evidence 至少包含验证器 JSON、负向案例摘要、合同 SHA-256、文件边界报告和测试摘要。
- handoff 明确列出所有文件哈希和运行命令。

## 六、验证要求

依次运行：

1. `python3 scripts/validate-n015-map-layout-contract.py --contract-only`
2. `python3 scripts/validate-n015-map-layout-contract.py --contract-only --write-evidence artifacts/integration/n-015-vscode-map-foundation`
3. 新增 XCTest 定向测试
4. 全量 XCTest
5. `git diff --check`
6. 文件边界审计

全量测试基线不得少于当前权威 300 项；新增测试后要求 0 failed、0 skipped。若机器环境无法执行 Xcode 测试，必须返回 `BLOCKED`，不得用历史 xcresult 冒充本次结果。

## 七、交付格式

在 `docs/game/n-015-vscode-map-foundation-handoff.md` 写清：

1. Outcome：`READY FOR CODEX REVIEW` / `REVISE` / `BLOCKED`
2. 前置合同 SHA-256
3. 修改文件清单
4. 验证器覆盖的每条语义规则
5. 每个负向测试及其失败证据
6. 定向/全量 XCTest 权威计数
7. `git diff --check` 与文件边界
8. 明确声明没有修改任何生产 Swift、美术、地图、台账或既有基础包
9. 下一负责人：Codex `🧱 tech` 独立接收；未获 `APPROVED` 前 Codex 不得进入生产阶段 C

最终回复必须包含：

```text
Outcome: READY FOR CODEX REVIEW | REVISE | BLOCKED
Contract-only validator: PASS | FAIL
Focused tests: X/X
Full tests: X/X, failed 0, skipped 0
File boundary: PASS | FAIL
Production files changed: 0
Next gate: Codex independent 🧱 tech review
```

不要宣称 N-015 完成，不要宣称地图已经接入，不要自行给出 `APPROVED`。
