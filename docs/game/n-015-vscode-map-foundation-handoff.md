# N-015-VSCODE-MAP-01 地图重排基础门禁包交接（r6）

- 工作包：`N-015-VSCODE-MAP-01`
- 任务：N-015（台账 `active / PENDING`）
- 授权决策：DEC-035（Product Owner 批准“地图重排”，拒绝纯视觉缩小）
- 日期：2026-08-24（r6：响应 🧱 tech 门禁 `REVISE`，建立自动化全路径 coverage 审计；r5 关闭的 12 个 schema/value 反例不回退）
- 专项负责人：🛠️ tools / data
- 部门质量负责人：🧱 tech
- 下游交接：Codex `🧱 tech` 独立接收；未获 `APPROVED` 前 Codex 不得进入生产阶段 C

## 1. Outcome

`READY FOR CODEX REVIEW`

r1 被 🧱 tech 以 `REVISE` 退回（7 个假阳性），r2 关闭后又被复闸退回（再构造 7 个假阳性），r3 逐建筑/逐地图冻结后又被复闸退回（5 个顺序假阳性），r4 补齐排序后又被复闸退回（12 个字段完整性假阳性，r5 关闭）。r5 复闸再构造 7 个「required 与 frozen value/order coverage 不一致」假阳性，均因验证器只覆盖了手选突变、没有完整叶子冻结与完整顺序覆盖而错误 PASS。

r6 不再接受人工选择少量 mutation 后声明“完整覆盖”。本轮交付：

1. **深度冻结树逐路径比较**：候选合同与冻结合同做字段路径级结构化比较，缺失字段、额外（即便全局已知）字段、任一 scalar/string/bool/number 叶子值、任一列表顺序改变都会以精确 JSON path FAIL。补齐 `quest_targets[].purpose` 等所有 required-but-not-value-frozen 字段。
2. **deterministic_ordering.cells 全覆盖**：新增 building collision/interaction/occlusion、NPC approach、farm starting cells 的 x→y 顺序校验；boundary/path/water/canal 既有校验保留。
3. **immutable 列表冻结顺序**：`immutable_stable_ids` 全部列表与冻结合同逐项一致比较，移除 `sorted()` 后比较。
4. **按 map ID 精确 key set**：农场 terrain 拒绝 `plaza_semantic`、农场拒绝 `static_obstacle_cells`（即便显式空数组）；集市保持其冻结字段。
5. **自动化 coverage 审计**：验证器新增 `--coverage-audit` 常驻子命令，遍历全部 dict key 删除、全部叶子值突变、全部长度>1 且反转会改变值的数组反转，每例通过真实 validator subprocess，输出确定性 JSON evidence（含 JSON path、mutation、mutated value 摘要、exit/result/failures、matched failure path）。2562 例可执行突变全部 FAIL、0 gap、0 白名单；38 个对称列表（如 `[144,144]`）反转是 no-op、非突变，逐项显式记录理由，不静默忽略。
6. **r6 七类独立反例 XCTest**（篡改 quest purpose / 农场新增 static_obstacle_cells / 农场 terrain 新增 plaza_semantic / 反转 collision_cells / 反转 occlusion_cells / 反转 approach_cells / 反转 immutable buildings+npcs）+ 1 个 coverage 模式 XCTest；r1–r5 全部测试保留。

r4 关闭的 r3 复闸 5 个顺序假阳性现均 `exit 1 / result FAIL / failures>0`：

| 假阳性（r3 复闸） | r3 结果 | r4 结果 |
|---|---|---|
| 反转 creek_market 3 栋建筑数组 | PASS | FAIL |
| 反转 farm_homestead path_cells | PASS | FAIL |
| 反转 farm_homestead water_cells records | PASS | FAIL |
| 反转 creek_market npc_positions | PASS | FAIL |
| 反转 farm_homestead spawns | PASS | FAIL |

r2 复闸 7 个假阳性已在 r3 关闭，r4 未回退：

| 假阳性（r2 复闸，r3 已关闭） | r2 结果 | r3 结果 |
|---|---|---|
| 双向交换种源棚/巡护亭 base filename（同为 96×96，30 文件集合与 native_size 不变） | PASS | FAIL |
| 整体平移种源棚 footprint/collision/door/interaction/occlusion/anchor 一格 | PASS | FAIL |
| 清空木构农舍全部 collision_cells | PASS | FAIL |
| 删除两张地图全部 path_cells | PASS | FAIL |
| 农舍 render_anchor.normalized 改为 `[99,99]` | PASS | FAIL |
| 删除顶层 deterministic_ordering | PASS | FAIL |
| 反转两张地图数组顺序 | PASS | FAIL |

r4 复闸 12 个字段完整性假阳性已在 r5 关闭：

| 假阳性（r4 复闸，r5 已关闭） | r4 结果 | r5 结果 |
|---|---|---|
| 删除集市显式 `canal_cells: []` | PASS | FAIL |
| 删除集市显式 `farm_area: null` | PASS | FAIL |
| 删除 `terrain.path_semantic` | PASS | FAIL |
| 删除 `coordinate_system.screen_origin` | PASS | FAIL |
| 删除 `movement_semantics.walkable` | PASS | FAIL |
| 删除 `immutable_stable_ids.stable_id_families` | PASS | FAIL |
| `coordinate_system.x_axis` 改为 `west` | PASS | FAIL |
| 篡改 `movement_semantics.walkable` | PASS | FAIL |
| 篡改 `terrain.visual_variants` | PASS | FAIL |
| `world_safe_zone.visual_buffer_rows` 改为 999 | PASS | FAIL |
| 篡改教学 NPC 的 `scope` | PASS | FAIL |
| 篡改 gather target 的 `required_unlock_id` | PASS | FAIL |

r5 复闸 7 个假阳性已在 r6 关闭，且不再依赖手选突变：自动化 coverage 审计遍历全部 2600 个 mutation 位置逐一验证（2562 例可执行突变全部 FAIL，38 例对称列表反转 no-op 显式记录）：

| 假阳性（r5 复闸，r6 已关闭） | r5 结果 | r6 结果 |
|---|---|---|
| 篡改 `quest_targets[].purpose` | PASS | FAIL（路径 `maps[1].quest_targets[0].purpose`） |
| 给农场新增 `static_obstacle_cells: []` | PASS | FAIL（路径 `maps[0].static_obstacle_cells`） |
| 给农场 terrain 新增 `plaza_semantic` | PASS | FAIL（路径 `maps[0].terrain.plaza_semantic`） |
| 反转农舍 `collision_cells` | PASS | FAIL（路径 `…collision_cells`） |
| 反转农舍 `occlusion_cells` | PASS | FAIL（路径 `…occlusion_cells`） |
| 反转教学 NPC `approach_cells` | PASS | FAIL（路径 `…approach_cells`） |
| 反转 `immutable_stable_ids.buildings` / `.npcs` | PASS | FAIL（路径 `immutable_stable_ids.buildings[0]` 等） |

## 2. 前置合同 SHA-256

| 文件 | SHA-256 |
|---|---|
| `docs/game/n-015-map-layout-contract.json` | `328c1afd542464353058e47370373b19e5ca003ac6b49496b00ef2c2e723fd51` |
| `docs/game/n-015-map-rearrangement-spec.md` | `fd8a7dd2127178af7e7290e3bc9c91f0ae88ae92022a728865626e7b95f05997` |

两文件未修改（与 r1 一致），仍声明 `decision_id = "DEC-035"`、`task = "N-015"`、`schema_version = 1`。

## 3. 修改文件清单

仅以下路径（全部在 DEC-035 允许范围内）：

```text
scripts/validate-n015-map-layout-contract.py                  （交付物 A，r6 更新）
macos/CreekSprout/CreekSproutTests/N015MapLayoutContractTests.swift  （交付物 B，r6 扩到 67 项）
artifacts/integration/n-015-vscode-map-foundation/            （交付物 C，r6 证据，含可追踪生成脚本）
docs/game/n-015-vscode-map-foundation-handoff.md              （本交接文档，r6）
```

未修改任何冻结 spec/contract、消费者矩阵、生产 Swift、Assets、音频、Xcode 工程文件、既有验证器、项目台账或 Codex evidence。

新增可追踪证据脚本（保留在证据目录内，非运行后删除）：

```text
artifacts/integration/n-015-vscode-map-foundation/generate-negative-case-summary.py
    （镜像 Swift 全部负向突变，经同一 validator subprocess 生成 negative-case-summary.json）
```

## 4. R3-1～R3-5 返工完成情况（r3 完成，r4 保留）

### R3-1 冻结五建筑完整记录

- 建立 `BUILDING_RECORDS_FROZEN`，逐建筑冻结 footprint origin/width/height、collision_cells、door、interaction_cells、occlusion_cells、render_anchor（cell/normalized/pixel_offset）、state。
- `collision_cells` 必须精确等于冻结 footprint-minus-door 集合，空集或任意子集均 FAIL。
- render anchor 的 cell、normalized、pixel_offset 精确匹配；normalized 必须是 2 个 `[0,1]` 数值，越界（如 `[99,99]`）FAIL。
- 负向：整体平移种源棚、清空碰撞、非法 normalized → FAIL。

### R3-2 逐建筑逐语义 filename

- 建立 `BUILDING_LAYER_FILENAMES_FROZEN`，对每个 `(building_id, semantic)` 推导唯一 filename，如 `market_seed_shed/base` 只能对应 `building_market_seed_shed_base.png`。
- 同时验证 order、native size、matrix provenance 与全局唯一性；不再以 filename 集合 + 尺寸间接替代 exact mapping。
- 负向：真正双向交换种源棚/巡护亭同 semantic filename（30 文件集合与 native size 不变）→ FAIL。

### R3-3 冻结两图完整空间记录

- 建立 `PATH_CELLS_FROZEN`、`BOUNDARY_CELLS_FROZEN`、`FARM_AREA_FROZEN`，逐地图严格比较 path cells、environment boundary、farm area（primary_rectangles/starting_cells/legacy_farm_cells_remain_valid）。
- 静态障碍已在 r2 冻结；world safe zone、water、canal、spawns、exits、NPC、gather、quest、landmarks 亦逐项冻结。
- 负向：path 全删、boundary 漂移、farm-area 漂移 → FAIL。

### R3-4 完整 required fields 与稳定排序

- 为顶层及所有嵌套对象同时定义 `required` 与 `allowed` 字段；缺 `deterministic_ordering` 等必填项 FAIL。
- 按合同 `deterministic_ordering` 冻结 maps 数组稳定顺序；反转 maps 数组 FAIL。
- 负向：删除必填顶层字段、反转 maps → FAIL。

> 注：r3 的 R3-4 仅执行了 maps 与 layers 顺序，未执行 buildings/cells/named-records 顺序合同；该缺口由 r4 的 R4-1 关闭（见下）。

### R3-5 证据与复闸

- 本轮 7 个新反例全部加入同一 subprocess XCTest，继续通过同一 Python 权威实现。
- 修正 r2 handoff 中“所有 r2 语义已严格冻结”的过度陈述，明确 r3 关闭证据。
- 重新生成 negative summary，记录真正双向 filename swap（非单向覆盖）。
- 复跑冻结合同、确定性、定向、全量 XCTest、`git diff --check` 与文件边界。

## 4b. R4-1 完整执行 deterministic_ordering（本轮核心返工）

- 保留 `_compare_cells()` 的集合等价用途（order-insensitive、duplicate-sensitive），新增独立顺序校验 helper，不再以 `sorted(actual) == sorted(expected)` 代替顺序合同。
- `buildings` 按 footprint origin 的 `(y, x)` 升序，且与冻结显式顺序 `BUILDING_ORDER_FROZEN` 逐项一致；反转建筑数组 FAIL。
- 纯 cell 数组（`path_cells`、`environment_boundary_cells`）按 `(x, y)` 升序；反转 FAIL。
- 带 `cell` 字段的记录（`water_cells`、`canal_cells`）按其 cell `(x, y)` 升序；反转 FAIL。
- `layers` 继续按 order 升序；`maps` 保持冻结显式顺序（r3 已实现，r4 保留）。
- `spawns`、`exits`、`npc_positions`、`gather_targets`、`quest_targets`、`landmarks` 等 named records 按冻结合同中的实际显式顺序逐数组比较（`NAMED_RECORD_ORDER_FROZEN`），不再只比较 ID 集合；反转 FAIL。
- 负向：反转 buildings、path_cells、water_cells、npc_positions、spawns（5 项）→ 全部 FAIL。

## 4c. R5-1 完整 schema/value coverage（本轮核心返工）

r4 只补齐了排序，未完成 R3-3/R3-4 已要求的“完整 required fields + 逐字段冻结值”。r5 一次性建立可审计的完整 schema/value coverage，不再逐个补 key。

- 为每类对象建立 `required` + `allowed` 字段集合，并在对象进入语义逻辑前执行：coordinate system、movement semantics、immutable stable IDs、map（按 map ID 精确 key set）、dimensions、legacy bounds、world safe zone、terrain、building、footprint、render anchor、layer、spawn、exit、NPC、water、canal、gather、quest、landmark、farm area、HUD、behavior、safe zone、reachability、pair、save relocation、nearest-safe rule、coordinate records、deterministic ordering。
- 对非坐标语义对象逐字段比较冻结值：`COORDINATE_SYSTEM_FROZEN`（axes/origins/tile size）、`MOVEMENT_SEMANTICS_FROZEN`（全字段，含 `walkable`）、`IMMUTABLE_FROZEN`（含 `stable_id_families`）、`TERRAIN_FROZEN`（per-map：`default`/`path_semantic`/`plaza_semantic`/`visual_variants`）、`WORLD_SAFE_ZONE_FROZEN`（per-map：`playable_bounds` + `visual_buffer_rows`）。
- 对 record-specific 字段按稳定 ID 冻结精确 key set 与精确值：`NPC_SCOPE_FROZEN`（仅 farm `water_apprentice` 有 `scope: "teaching_spawn"`，其余 NPC 不得携带 `scope`）、`GATHER_REQUIRED_UNLOCK_FROZEN`（仅 `restored_brook_cache` 有 `required_unlock_id`，其余 gather 不得携带该字段）。
- 区分“字段缺失”“显式空数组”“显式 null”：`canal_cells` 与 `farm_area` 加入 `REQUIRED_MAP_FIELDS`，集市 `canal_cells: []` 与 `farm_area: null` 删除即 FAIL；`static_obstacle_cells` 按 map 区分（farm 冻结空集、market 冻结 `[[6,7]]`）。
- 不硬编码 candidate contract SHA 或比较整个文件哈希；每个负向测试由对应 schema/value 规则捕获，并在 `failures` 中给出字段路径。
- 负向：12 个 §11.1 反例（FP-r4-1 ~ FP-r4-12）+ 1 个表驱动测试（遍历 21 类嵌套对象各删除一个必填字段）→ 全部 FAIL。

## 4d. R6-1 自动化完备性（本轮核心返工）

r5 的“完整 schema/value coverage”仍只覆盖了新增测试选择的字段。r6 不再接受人工列出少量 mutation 后声明完整覆盖，改为自动化全路径 coverage 审计。

### R6-1a 深度冻结树逐路径比较

- 候选合同与冻结合同（`docs/game/n-015-map-layout-contract.json`，只读）做字段路径级结构化比较（`_deep_diff`），在任何语义规则之前执行。
- 三类差异都 FAIL：缺失字段、额外字段（即便全局 known、当前对象不允许，如农场 `static_obstacle_cells` / `plaza_semantic`）、任一叶子值或列表顺序改变；类型严格比较（bool≠int≠float）。
- 这不是哈希比较：每个分歧单独报告，failure 携带精确 JSON path（如 `maps[1].quest_targets[0].purpose`）。
- 补齐 `quest_targets[].purpose`：新增 `QUEST_PURPOSE_FROZEN` 按 (map_id, target_id) 冻结 purpose 文本（另有深度冻结树兜底）。

### R6-1b deterministic_ordering.cells 全覆盖

- `_check_cell_order`（x 升序，再 y 升序）扩展到 building `collision_cells` / `interaction_cells` / `occlusion_cells`、NPC `approach_cells`、`farm_area.starting_cells`。
- 既有覆盖保留：`environment_boundary_cells`、`path_cells`、water/canal cell-record 数组、buildings (y,x)、layers order、maps 数组、named records 显式顺序。

### R6-1c immutable 列表冻结顺序

- 新增 `IMMUTABLE_ORDER_FROZEN`：`buildings`/`exits`/`maps`/`npcs`/`spawns` 全部按冻结合同字面顺序逐项一致比较；移除 `sorted()` 后比较；`stable_id_families` 继续精确比较。

### R6-1d 按 map ID 精确 key set

- 农场 terrain 精确 key set = {default, path_semantic, visual_variants}；出现 `plaza_semantic`（集市专属）即 FAIL。
- 农场 map 不得出现 `static_obstacle_cells`（即便显式 `[]`）；集市 `[[6,7]]` 保留。
- NPC `scope`、gather `required_unlock_id` 按稳定 ID 精确约束保留（r5 不回退）。

### R6-1e 自动化 coverage 审计（常驻子命令）

- 验证器新增 `--coverage-audit <dir>` 常驻子命令，输出 `<dir>/coverage-audit.json`。
- A 删除遍历：冻结合同每个 dict key 删除一次 → 必须 FAIL（645 例）。
- B 叶子值突变：每个 scalar/string/bool/number 叶子做类型保持的不同值突变 → 必须 FAIL（1404 例）。
- C 数组顺序突变：每个长度>1 且反转会改变值的数组 reverse → 必须 FAIL（513 例）；38 个对称列表（如 `[144,144]`、`[7,7]`）反转是 no-op、非突变，在 `no_op_reversals` 中显式记录理由，不静默忽略。
- 全部 case 通过真实 validator subprocess（`--contract <tmp>`）执行；evidence 逐例记录 JSON path、mutation、mutated value 摘要、exit、result、failures、matched failure path、failure excerpt。
- 任何 PASS 必须进入 `COVERAGE_WHITELIST`（当前为空）；未白名单 PASS 记为 gap 并令审计 exit 1。
- 确定性：case 按 (phase, JSON path) 排序、临时候选路径固定、无时间戳/UUID；连续两次运行 stdout 与 evidence 逐字节一致（本包已实测 cmp 通过）。
- 结果：2562 例可执行突变全部 FAIL（matched failure path 100%），0 gap，0 passed，0 whitelist；38 例 no-op 反转逐项记录。

## 5. 定向 / 全量 XCTest 权威计数

| 指标 | r1 | r2 | r3 | r4 | r5 | r6 |
|---|---|---|---|---|---|---|
| 全量 XCTest | 316 | 334 | 341 | 346 | 359 | **367** |
| failures | 0 | 0 | 0 | 0 | 0 | **0** |
| skipped | 0 | 0 | 0 | 0 | 0 | **0** |
| 定向 `N015MapLayoutContractTests` | 16 | 34 | 41 | 46 | 59 | **67**（1 冻结合同 + 45 负向 + 12 FP-r4 + 1 表驱动 + 7 FP-r5 + 1 coverage） |

## 6. `git diff --check` 与文件边界

- `git diff --check`：exit 0。
- 文件边界：本包仅新增两条代码路径与隔离证据目录；未触碰任何禁止路径。

## 7. 声明

本包没有修改任何生产 Swift、美术、地图、台账、冻结 spec/contract、消费者矩阵或既有验证器。未宣称 N-015 完成，未宣称地图已接入，未自行给出 `APPROVED`，未启动或声称 Codex 阶段 C 已获授权。

## 8. 下一负责人

Codex `🧱 tech` 独立接收。未获 `APPROVED` 前 Codex 不得进入生产阶段 C。

## 9. 运行命令

```text
python3 scripts/validate-n015-map-layout-contract.py --contract-only
python3 scripts/validate-n015-map-layout-contract.py --coverage-audit artifacts/integration/n-015-vscode-map-foundation
python3 artifacts/integration/n-015-vscode-map-foundation/generate-negative-case-summary.py
python3 scripts/validate-n015-map-layout-contract.py --contract-only --write-evidence artifacts/integration/n-015-vscode-map-foundation
xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout \
  -destination 'platform=macOS' -parallel-testing-enabled NO \
  -only-testing:CreekSproutTests/N015MapLayoutContractTests test
xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout \
  -destination 'platform=macOS' -parallel-testing-enabled NO test
```

## 10. 决策与假设

1. 验证器是合同单一权威来源，只读冻结 spec、JSON 合同与消费者矩阵，不复制 `validate-n015-consumer-matrix.py` 或 `audit-runtime-art-integration.py` 的审计算法。
2. 水体语义命名采用「陆地侧」约定：corner 格恰有两个陆地侧、edge 格一个、base 格零个；推导与冻结合同逐格一致。
3. `water_apprentice` 是同一稳定 ID 在两图各出现一次，按 (map, id) 键分别校验，不误判为重复。
4. 计数字段实时推导；确定性：同一合同连续两次运行 stdout 逐字节一致，evidence 无时间戳；coverage audit 连续两次运行 stdout 与 evidence 均逐字节一致（已实测 cmp）。
5. 顺序合同逐项执行：buildings 按 footprint origin `(y, x)` 升序、纯 cell 数组与带 `cell` 的记录按 `(x, y)` 升序、layers 按 order 升序、maps 与 named records 按冻结合同显式顺序、immutable 列表按冻结合同字面顺序逐项一致（不得 `sorted()` 后比较）；`_compare_cells()` 仍保持集合等价（order-insensitive），顺序校验由独立 helper 完成，二者不混淆。
6. 深度冻结树是字段路径级结构化比较，不是候选文件哈希比较；每个分歧单独报告精确 JSON path。
7. coverage 审计对“反转后等于原值”的对称列表不视为突变：候选与冻结合同完全一致时 PASS 正确，此类路径在 `no_op_reversals` 显式记录理由，不进入白名单也不静默忽略。

## 11. 风险与后续

1. **工作树并行漂移**：Codex 阶段 C 未获授权前不得启动；验证器实时读取合同与矩阵，任何阶段 C 对合同的改动都会在重跑时以非零退出码暴露。
2. **解释器路径依赖**：测试依赖 Xcode Developer Tools 框架 Python 路径；若 CI 环境无 Xcode，`resolveInterpreter` 会显式失败（不伪造绿灯）。
