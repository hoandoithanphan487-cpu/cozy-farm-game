# N-015-VSCODE-MAP-01 独立技术审查

- 日期：2026-08-24
- 审查轮次：r1 + r2 + r3 + r4 + r5 + r6
- 被审包：`N-015-VSCODE-MAP-01`
- 专项交付状态：`READY FOR CODEX REVIEW`
- 🧱 tech 独立门禁：`APPROVED`
- N-015：继续 `active / PENDING`
- Codex 阶段 C：已授权启动

## 1. 结论

验证器可以运行，Swift 测试确实通过 subprocess 调用同一 Python 权威实现，冻结合同、16/16 定向测试及交接所报的 316/316 全量结果没有显示编译或现有回归问题。然而，现有 16 个负向测试只证明了被选中的 15 种突变会失败，没有证明 prompt 要求的完整语义会被拒绝。

独立审查构造了 7 种应当失败的合同突变，验证器全部返回 `exit 0 / result PASS / failures 0`。这些是假阳性，会允许 Codex 阶段 C 在错误图层、缺 NPC、缺可达性、错误水体和越界 HUD 合同上继续，因此本包不能接收。

## 2. 已确认通过的部分

- 冻结合同 SHA-256 仍为 `328c1afd542464353058e47370373b19e5ca003ac6b49496b00ef2c2e723fd51`。
- `python3 scripts/validate-n015-map-layout-contract.py --contract-only` 对冻结合同返回 PASS，汇总为 2 maps、5 buildings、30 layers、23 required pairs、1 save relocation rule。
- 独立复跑 `N015MapLayoutContractTests`：16/16、0 failed、0 skipped，`TEST SUCCEEDED`。
- XCTest 的确以 `Process` 调用同一个 Python 文件；没有进程内复制验证算法、`XCTSkip` 或 subprocess 失败成功 fallback。
- `git diff --check` 通过；没有发现本包修改生产 Swift、Assets、地图合同或台账。

这些结果保留为 r1 基线，但不覆盖以下语义阻断。

## 3. 独立复现的假阳性

所有突变均只写入临时目录，未修改冻结合同或仓库文件。

| 应拒绝的突变 | 实际结果 | 暴露缺口 |
|---|---|---|
| 交换农舍与水工坊的 `base` filename，30 文件集合保持不变 | `PASS` | 只比较 B4 filename 集合，没有逐建筑、逐层 exact mapping / provenance |
| 删除农场教学 NPC 的 `npc_positions` 记录 | `PASS` | 没有验证 NPC 位置集合与冻结稳定 ID 的完整一一对应 |
| 将 NPC `approach_cells` 改为非相邻但可走的远端格 | `PASS` | 只检查可走，不检查与 NPC 曼哈顿距离必须为 1 |
| 将 23 条 `required_pairs` 删除到只剩 1 条 | `PASS` | 只检查列表非空，没有验证完整目标集合 |
| 将 960×640 `world_safe_rect_default` 改为 `[-999,-999,1,1]` | `PASS` | 只检查 HUD key 存在，不检查矩形类型、边界、面积或互斥 |
| 将建筑层 `native_size` 改为 `[1,1]` | `PASS` | 只检查数组长度，不与矩阵/manifest 的权威尺寸逐文件比较 |
| 把两图所有水格 semantic 全改为 `base` | `PASS` | 没有根据邻接关系验证 edge/corner/base，也没有验证水体连通性 |

## 4. 代码层根因

1. Rule 5 使用 `set(filename)` 与矩阵集合比较。只要文件集合相同，跨建筑或跨语义交换就不会失败；当前负向测试只是用重复文件覆盖一个文件，因此偶然制造了 missing filename，并未测试真正的交换。
2. NPC 校验仅拒绝不在 immutable 集合中的 fabricated ID；没有要求所有既有 ID 恰好出现一次，也没有要求地图归属正确。
3. `approach_cells` 只检查 bounds 和 blocked，没有验证相邻关系、唯一性及与玩家路径的连通性。
4. `required_pairs` 仅要求非空并逐条 BFS；删除应有目标不会失败。
5. 水体验证只拒绝同格重复/非法枚举；所谓 topology continuity 实际只检查 canal 是否混用 `ns/ew`。
6. HUD safe zone 只检查两个 viewport 和字段名；所有 rect 内容均可为越界、负数、错误类型或互相覆盖。
7. `native_size` 只检查为长度 2 的数组，没有检查正整数或权威尺寸。
8. Rule 14 的“spec/JSON coordinate consistency”只搜索五个中文建筑名称是否出现在 spec，没有比较任何地图尺寸、origin、door、interaction、NPC、spawn、exit、水体或 HUD 坐标。
9. 未对 spawn、exit、NPC、water、canal、HUD safe-zone 等嵌套对象执行完整 unknown-field/type/unique-ID 校验；handoff 中“各嵌套对象均拒绝未知字段”的表述不成立。

## 5. r2 必须关闭的返工项

VSCode 仍只能修改原四类授权文件，不得修改冻结 spec/contract、生产 Swift、Assets、消费者矩阵、既有验证器、台账或 Codex evidence。

### R2-1 逐建筑逐层严格映射

- 从 B4 消费者矩阵及权威 manifest 推导每个 filename 的建筑 ID、semantic、native size、batch、provenance。
- 对合同每个 building/layer 逐字段比较，不得只比较集合。
- 检查 filename 全局唯一且恰好一次。
- 增加真正的双向交换测试：交换两栋建筑相同 semantic 的 filename，保持 30 文件集合不变，必须 FAIL。
- 增加正确 filename 但错误 native size、semantic、batch/provenance 语义的负向测试。

### R2-2 稳定实体完整性

- maps、buildings、spawns、exits、NPC 必须与 immutable stable IDs 一一对应、无缺失、无重复、无额外项，且地图归属正确。
- destination map/spawn 必须互相引用有效。
- NPC approach cell 必须在 bounds、非 blocked、唯一、与 NPC 正交相邻，并至少一个从对应 spawn 可达。
- 增加删除 NPC、重复 NPC、错误地图归属、远端 approach 的负向测试。

### R2-3 必要可达性集合

- 从合同的 spawns、exits、building interaction、NPC approach、farm/gather/quest targets 推导必需 reachability 目标，而不是只相信 `required_pairs` 自报。
- 要求冻结的 23 条 pair 名称、map、from/to 与推导集合逐项一致；缺任意一条、重复或伪造一条均 FAIL。
- 起点和终点必须先验证 bounds、非 blocked，再执行 BFS。

### R2-4 水体与水渠拓扑

- 验证每个水体连通分量符合冻结布局。
- 根据正交邻接推导每格应为 `base`、单一 edge 或单一 corner；全部改成 base、错误方向或孤立水格必须 FAIL。
- canal 必须连续，`ns/ew` 必须与相邻方向匹配，而不是只要求全局 semantic 单一。
- 增加全 base、错误 corner、断裂水体、方向不符四类负向测试。

### R2-5 HUD 与存档合同

- 每个 HUD rect 必须为 4 个非负整数，宽高大于 0，完整落在 viewport 内；固定区之间按 spec 的规则不重叠。
- behavior 必填值、建筑卡默认隐藏/可关闭、toast 优先级和消退时间必须严格验证。
- save relocation 必须验证 apply timing、candidate、writeback、coordinate_records 的精确值，不只检查 key 存在。
- 增加负坐标、越界、零面积、互相覆盖、错误 tie-break/candidate/writeback 负向测试。

### R2-6 完整 schema 与 spec 一致性

- 为所有嵌套对象定义 allowed/required fields、精确类型、唯一性与稳定排序；未知字段必须 FAIL。
- Rule 14 至少逐项比较两图 dimensions、五建筑 origin/door/interaction、spawn/exit、8 个 NPC positions、HUD viewports 和关键水体范围；仅搜索中文标签不算一致性验证。
- 可记录并验证冻结 spec SHA-256，但不能用硬编码 contract SHA 让所有负向合同无条件失败；负向测试必须仍能证明具体语义规则工作。

### R2-7 负向测试与证据

- 把本审查的 7 个假阳性全部加入 XCTest，并继续通过同一 subprocess validator。
- 每项断言 exit 1、parseable FAIL JSON、failures 非空、无 traceback。
- 更新 handoff 与 evidence，明确 r1 假阳性已关闭。
- 复跑定向、全量 XCTest、确定性、`git diff --check` 与文件边界。

## 6. 门禁状态

```text
Outcome: REVISE
Frozen contract baseline: PASS
Focused tests: 16/16 PASS
Independent false-positive mutations: 7/7 incorrectly PASS
File boundary: PASS
VSCode package accepted: NO
Codex phase C authorized: NO
Next owner: VSCode / 🛠️ tools r2
```

本轮不要求修改 Codex 冻结的设计合同。问题在于验证器没有完整执行已经冻结的语义，不是地图方案本身需要重做。

## 7. r2 复闸结论

- 日期：2026-08-24
- r2 交付：`READY FOR CODEX REVIEW`
- 🧱 tech 独立门禁：`REVISE`
- Codex 阶段 C：继续禁止启动

r2 确实关闭了 r1 记录的 7 个具体反例：删除 NPC、非相邻 approach、缺 required pairs、越界 HUD、错误 native size 和错误水体现在均会 FAIL；独立复跑新增测试为 34/34、0 failed、0 skipped，subprocess 架构与文件边界仍然合规。

但 r2 把大量冻结值写进 Python 后，仍没有把完整合同逐项冻结。独立复闸再次构造 7 个合同突变，全部错误返回 `exit 0 / result PASS / failures 0`。

### 7.1 r2 新复现的假阳性

| 应拒绝的突变 | 实际结果 | 暴露缺口 |
|---|---|---|
| 双向交换种源棚与巡护亭的 `base` filename；两者同为 96×96，30 文件集合保持不变 | `PASS` | 仍未比较 building ID + semantic + exact filename；r2 所谓 swap 测试实际仍是单向覆盖 |
| 将种源棚 footprint、collision、door、interaction、occlusion、render anchor 全体向北平移一格 | `PASS` | 没有冻结五建筑的 origin/door/interaction/occlusion/anchor 精确坐标；Rule 14 仍只搜索中文名称 |
| 清空木构农舍全部 `collision_cells` | `PASS` | 只检查 collision 为合法子集，没有要求等于冻结 footprint-minus-door 集合 |
| 删除两张地图全部 `path_cells` | `PASS` | 没有验证 spec/JSON 的道路坐标一致性 |
| 将农舍 `render_anchor.normalized` 改为 `[99,99]` | `PASS` | render anchor 只检查字段存在，没有类型、范围或冻结值比较 |
| 删除顶层 `deterministic_ordering` | `PASS` | unknown-field 检查存在，但 required-field 检查不完整 |
| 反转两张地图数组顺序 | `PASS` | 声明了稳定排序，但验证器没有执行 map/list ordering 合同 |

### 7.2 r2 “filename swap”测试没有实现其注释

`testFalsePositiveSwapBaseFilenameFails` 的注释声称“双向交换并保持 30 文件集合不变”，实际代码只把农舍 base 改成水工坊 base，没有把水工坊 base 改成农舍 base。它会产生一个重复 filename 和一个 missing filename，因此仍是 r1 的集合差异案例。r2 验证器又利用两栋建筑尺寸不同捕获该单向覆盖；当交换两个同尺寸建筑时，仍会假阳性 PASS。

## 8. r3 必须关闭的返工项

仍保持原四类 VSCode 文件边界，不修改 spec、contract、生产 Swift、Assets、消费者矩阵、台账或 Codex evidence。

### R3-1 冻结五建筑完整记录

- 建立由冻结合同/spec 推导的每栋建筑权威记录，逐项比较：map、footprint origin/width/height、collision cells、door、interaction cells、occlusion cells、render anchor、state。
- `collision_cells` 必须精确等于冻结集合，不得接受空集或任意子集。
- render anchor 的 cell、normalized、pixel_offset 必须精确匹配，并验证 normalized 有效范围和数值类型。
- 新增“整体平移种源棚”“清空碰撞”“非法 normalized”三个 subprocess 负向测试。

### R3-2 逐建筑逐语义 filename

- 对每个 `(building_id, semantic)` 推导唯一 filename，例如 `market_seed_shed/base` 只能对应 `building_market_seed_shed_base.png`。
- 同时验证 order、native size、matrix provenance 和全局唯一性；不能以 filename 集合 + 尺寸间接替代 exact mapping。
- 新增真正双向交换种源棚/巡护亭同 semantic filename 的测试，必须保持 30 文件集合与 native size 不变并返回 FAIL。

### R3-3 冻结两图完整空间记录

- 逐地图严格比较 path cells、environment boundary、static obstacle、farm area、world safe zone、water、canal、spawns、exits、NPC、gather、quest、landmarks 及 buildings 的精确冻结值。
- 至少为 path 删除、boundary 漂移、farm-area 漂移各增加独立负向测试。
- Rule 14 不得继续只搜索五个中文标签；应验证冻结 spec SHA-256，并对 spec 中关键尺寸/坐标锚点做可复核比较。spec hash 只能保护 spec，不得用硬编码 contract hash 代替所有语义规则。

### R3-4 完整 required fields 与稳定排序

- 为顶层及所有嵌套对象同时定义 `required` 和 `allowed` 字段；缺 `deterministic_ordering` 等必填项必须 FAIL。
- 按合同自身的 `deterministic_ordering` 验证 maps、buildings、layers、cells 与 named records 的顺序；反转 map 数组必须 FAIL。
- 增加删除必填顶层字段、反转 maps、反转任一稳定 cell list 三类负向测试。

### R3-5 证据与复闸

- 将本轮 7 个新反例全部加入同一 subprocess XCTest。
- 修正 handoff 中“所有 r2 语义已严格冻结”的过度陈述，明确 r3 关闭证据。
- 重新生成 negative summary，确保真正双向 filename swap 被记录，而非单向覆盖。
- 复跑冻结合同、确定性、定向、全量 XCTest、`git diff --check` 和文件边界。

```text
Outcome: REVISE
r1 false positives closed: 7/7
r2 independent false positives: 7/7 incorrectly PASS
Focused tests: 34/34 PASS
VSCode package accepted: NO
Codex phase C authorized: NO
Next owner: VSCode / 🛠️ tools r3
```

## 9. r3 复闸结论

- 日期：2026-08-24
- r3 交付：`READY FOR CODEX REVIEW`
- 🧱 tech 独立门禁：`REVISE`
- Codex 阶段 C：继续禁止启动

r3 已实质关闭 r2 发现的 7 个具体假阳性：双向同尺寸 filename 交换、整栋建筑平移、清空碰撞、删除道路、非法 render anchor、删除 `deterministic_ordering` 与反转 maps 现在均返回可解析 `FAIL`。独立复跑冻结合同为 PASS；定向 XCTest 为 41/41、0 failed、0 skipped；`git diff --check` 通过。

但 R3-4 没有完整实现。冻结合同明确声明：

- `buildings`: footprint origin 的 y 升序，再 x 升序；
- `cells`: x 升序，再 y 升序；
- `layers`: order 升序；
- `named_records`: 本文档冻结的显式语义顺序。

当前验证器只执行了 maps 与 layers 顺序。`_compare_cells()` 会先 `sorted()` 再比较，主动抹掉 cell 数组顺序；building、NPC、spawn 等数组只比较内容/集合，没有执行稳定顺序合同。独立临时突变结果如下：

| 应拒绝的突变 | 实际结果 | 阻断原因 |
|---|---|---|
| 反转集市 3 栋建筑数组 | `exit 0 / PASS / failures 0` | 未执行 buildings 的 origin y→x 排序 |
| 反转农场 `path_cells` | `exit 0 / PASS / failures 0` | `_compare_cells()` 排序后比较，未执行 cells x→y 顺序 |
| 反转集市 `npc_positions` | `exit 0 / PASS / failures 0` | 未执行 named-record 稳定顺序 |
| 反转农场 `spawns` | `exit 0 / PASS / failures 0` | 未执行 named-record 稳定顺序 |
| 反转农场 `water_cells` | `exit 0 / PASS / failures 0` | 未执行 cell-record 稳定顺序 |

这与上轮 R3-4 的“验证 maps、buildings、layers、cells 与 named records 的顺序”以及“反转任一稳定 cell list 必须 FAIL”直接冲突。因此 41 个现有测试虽然全绿，却缺少要求过的 cell-order 负向测试，handoff 中“稳定排序验证已补齐”的表述不成立。

## 10. r4 最小返工项

保持原四类 VSCode 文件边界；不修改冻结 spec/contract、生产 Swift、Assets、消费者矩阵、台账或 Codex evidence。

1. 不得改变 `_compare_cells()` 现有集合等价用途；新增独立的顺序校验 helper，按合同执行：纯 cell 数组严格 x→y，带 `cell` 的记录按其 cell x→y；重复项仍须拒绝。
2. buildings 必须按 footprint origin 的 `(y, x)` 升序；layers 保持现有 order 升序；maps 保持现有冻结顺序。
3. 对 spawns、exits、NPC、gather、quest、landmarks 等 named records 使用冻结合同中的实际显式顺序逐数组比较；不要只比较 ID 集合。
4. 新增至少 5 个 subprocess XCTest：反转 buildings、path cells、water cell records、NPC records、spawn records。每个必须断言 exit 1、parseable `FAIL`、failures 非空、无 traceback。
5. 把本节五个独立突变写入 negative summary；修正 handoff 的排序覆盖表述；复跑定向、全量、确定性、`git diff --check` 与文件边界。

```text
Outcome: REVISE
r2 independent false positives closed by r3: 7/7
Focused tests: 41/41 PASS
r3 independent ordering false positives: 5/5 incorrectly PASS
VSCode package accepted: NO
Codex phase C authorized: NO
Next owner: VSCode / 🛠️ tools r4
```

## 11. r4 复闸结论

- 日期：2026-08-24
- r4 交付：`READY FOR CODEX REVIEW`
- 🧱 tech 独立门禁：`REVISE`
- Codex 阶段 C：继续禁止启动

r4 的排序修复有效：上一轮 5 个顺序反例，以及独立扩展的 boundary、canal、gather、quest、landmark、相邻 cell 交换变体，均返回可解析 `FAIL` 且无 traceback。独立定向结果为 46/46；独立全量 xcresult 权威摘要为 346/346、0 failed、0 skipped；冻结合同 PASS，SHA-256 未变化。

但 r4 只补齐了排序，仍未完成 R3-3/R3-4 已要求的“完整 required fields + 逐字段冻结值”。当前 `REQUIRED_MAP_FIELDS` 及各嵌套对象的 required/value 检查不完整，导致显式空值、可选记录字段和多个冻结语义字段被删除或篡改后仍错误 PASS。

### 11.1 独立复现的字段完整性假阳性

| 应拒绝的合同突变 | 实际结果 | 缺口 |
|---|---|---|
| 删除集市显式 `canal_cells: []` | `exit 0 / PASS / failures 0` | `get(..., [])` 把字段缺失与冻结空数组混为一谈 |
| 删除集市显式 `farm_area: null` | `exit 0 / PASS / failures 0` | `get()` 把字段缺失与冻结 null 混为一谈 |
| 删除 `terrain.path_semantic` | `exit 0 / PASS / failures 0` | terrain 没有 required-field 校验 |
| 删除 `coordinate_system.screen_origin` | `exit 0 / PASS / failures 0` | coordinate system 只验证 cell_origin/tile_size |
| 删除 `movement_semantics.walkable` | `exit 0 / PASS / failures 0` | movement semantics 只验证 blocked_union |
| 删除 `immutable_stable_ids.stable_id_families` | `exit 0 / PASS / failures 0` | immutable 对象 required/value 覆盖不完整 |
| 将 `coordinate_system.x_axis` 改为 `west` | `exit 0 / PASS / failures 0` | 冻结轴向未比较 |
| 篡改 `movement_semantics.walkable` | `exit 0 / PASS / failures 0` | 冻结移动语义未比较 |
| 篡改 `terrain.visual_variants` | `exit 0 / PASS / failures 0` | 地形视觉语义未冻结 |
| 将 `world_safe_zone.visual_buffer_rows` 改为 999 | `exit 0 / PASS / failures 0` | safe-zone 只比较 playable_bounds |
| 篡改教学 NPC 的 `scope` | `exit 0 / PASS / failures 0` | record-specific 可选字段未冻结 |
| 篡改 gather target 的 `required_unlock_id` | `exit 0 / PASS / failures 0` | record-specific 可选字段未冻结 |

现有 46 个测试和 346 个全量测试均没有覆盖这些突变，因此绿灯不能替代合同语义完整性。

## 12. r5 一次性收敛要求

保持原四类 VSCode 文件边界。不要继续只补上表的具体 key；应建立可审计的完整 schema/value coverage，防止下一轮出现同类漏项。

1. 对每类对象建立 required/allowed 字段集合，并在对象进入语义逻辑前执行：coordinate system、movement semantics、immutable stable IDs、map（允许按 map ID 使用精确 key set）、dimensions、legacy bounds、world safe zone、terrain、building、footprint、render anchor、layer、spawn、exit、NPC、water、canal、gather、quest、landmark、farm area、HUD、behavior、safe zone、reachability、pair、save relocation、nearest-safe rule、coordinate records、deterministic ordering。
2. 对 record-specific 字段使用按稳定 ID 冻结的精确 key set 与精确值；例如 farm NPC 的 `scope`、特定 gather target 的 `required_unlock_id`，不得用全局“可选”绕过。
3. 区分“字段缺失”“显式空数组”“显式 null”。集市 `canal_cells: []` 与 `farm_area: null` 都必须存在；删除必须 FAIL。
4. 对非坐标语义对象逐字段比较冻结值，而不只检查类型或少数字段：coordinate axes/origins、movement semantics 全字段、immutable `stable_id_families`、terrain semantics/variants、world-safe visual buffer 等。
5. 不得通过硬编码 candidate contract SHA 让所有临时合同失败；每个负向测试必须由对应 schema/value failure 捕获，并在 failures 中给出字段路径。
6. 新增至少 12 个 subprocess XCTest，逐项覆盖 §11.1；再增加一个表驱动测试，遍历每种对象至少删除一个必填字段，全部必须 exit 1、parseable `FAIL`、failures 非空、无 traceback。
7. negative summary 必须由实际 validator subprocess 结果生成或可复算，不能只手工声明；修正 handoff 中“完整 required fields 已完成”的表述。
8. 复跑冻结合同、确定性、全部负向测试、定向、全量、`git diff --check` 与文件边界。

```text
Outcome: REVISE
r3 ordering false positives closed by r4: 5/5
Focused tests: 46/46 PASS
Full tests: 346/346 PASS
r4 independent schema/value false positives: 12/12 incorrectly PASS
VSCode package accepted: NO
Codex phase C authorized: NO
Next owner: VSCode / 🛠️ tools r5
```

## 13. r5 复闸结论

- 日期：2026-08-24
- r5 交付：`READY FOR CODEX REVIEW`
- 🧱 tech 独立门禁：`REVISE`
- Codex 阶段 C：继续禁止启动

r5 已关闭 §11.1 的 12 个已知字段缺口；实现中没有使用候选合同 SHA 统一拒绝临时合同，已有字段路径规则是真实工作的。冻结合同基线继续 PASS，哈希未变化。

但“完整 schema/value coverage”仍只覆盖了新增测试选择的字段。独立泛化攻击再次发现以下合同突变错误返回 `exit 0 / PASS / failures 0`：

| 应拒绝的突变 | 暴露缺口 |
|---|---|
| 将 `quest_targets[].purpose` 改为 fabricated 文本 | purpose 只检查存在，不比较按稳定 ID 冻结值 |
| 给农场 map 新增 `static_obstacle_cells: []` | 没有执行按 map ID 的精确 key set；缺席与额外空字段被视为等价 |
| 给农场 terrain 新增仅集市允许的 `plaza_semantic` | terrain 只要求 expected keys 存在，没有拒绝该 map 不允许的 known key |
| 反转农舍 `collision_cells` | `deterministic_ordering.cells` 没有覆盖建筑内部 cell 数组 |
| 反转农舍 `occlusion_cells` | 同上 |
| 反转教学 NPC `approach_cells` | `deterministic_ordering.cells` 没有覆盖 NPC cell 数组 |
| 反转 `immutable_stable_ids.buildings` 或 `.npcs` | immutable 列表先排序后比较，未执行冻结列表顺序 |

相对地，删除 `quest_targets[].purpose` 会 FAIL；这证明问题不是 required-field 缺失，而是 required 与 frozen value/order coverage 仍不一致。r5 的 21 项表驱动测试只做“删除一个字段”，不能证明剩余字段值或所有数组顺序已被冻结。

## 14. r6 自动化完备性门禁

保持原四类文件边界。r6 不再接受人工列出少量 mutation 后声明“完整覆盖”；必须加入自动化覆盖审计。

1. 为每个 map ID、record stable ID 建立精确 key set；同时拒绝缺失与额外 known key。农场不得出现 `static_obstacle_cells`、`terrain.plaza_semantic`；集市必须保留其冻结字段。
2. 对合同中每个非容器叶子值建立字段路径级冻结比较。补齐 `quest_targets[].purpose`，并自动审计其他 required-but-not-value-frozen 字段。
3. `deterministic_ordering.cells` 必须覆盖所有稳定 cell 数组：boundary、path、building collision/interaction/occlusion、NPC approach、farm starting cells，以及所有带 `cell` 的 record arrays。顺序规则为 x→y；单元素数组自然通过。
4. immutable stable-ID/family 列表必须与冻结顺序逐项一致，不得 `sorted()` 后比较。
5. 新增一个可追踪、可复算的 validator coverage 模式或授权 evidence 内脚本：
   - 遍历冻结合同每个 dict key，删除后均应 FAIL；
   - 遍历每个 scalar/string/bool/number 叶子，做类型保持的值突变后均应 FAIL；
   - 对长度大于 1 的稳定数组反转后均应 FAIL；
   - 允许例外必须以字段路径白名单显式记录理由，不得静默 PASS；
   - 输出每个 JSON path、mutation、exit/result/failure path 的确定性 JSON evidence。
6. coverage 审计必须通过实际 validator subprocess，且脚本/生成逻辑必须保留在授权 evidence 目录或 validator 自身模式中；不得使用运行后删除的一次性脚本。
7. 增加本节 7 类独立反例的 subprocess XCTest，并保留 r1–r5 全部测试。
8. 复跑 validator、coverage 审计、确定性、定向、全量、diff check、文件边界与两个冻结 SHA。

```text
Outcome: REVISE
r4 schema/value false positives closed by r5: 12/12
r5 independent generalized false-positive categories: 7
VSCode package accepted: NO
Codex phase C authorized: NO
Next owner: VSCode / 🛠️ tools r6
```

## 15. r6 最终复闸与接收

- 日期：2026-08-24
- r6 交付：`READY FOR CODEX REVIEW`
- 🧱 tech 独立门禁：`APPROVED`
- VSCode 基础包：已接收
- Codex 阶段 C：已授权启动
- N-015：继续 `active / PENDING`

r6 关闭了 r5 的全部 7 类泛化缺口，并把验证方式从“人工挑选反例”升级为全路径自动 coverage：逐一删除全部 dict key、类型保持地突变全部叶子值、反转全部非对称列表，每一例均通过真实 validator subprocess。实现没有使用 candidate SHA 或整文件哈希统一拒绝；差异以 JSON path 粒度报告。

### 15.1 独立复核结果

| 检查项 | 独立结果 |
|---|---|
| 冻结合同 validator | PASS；2 maps / 5 buildings / 30 layers / 23 pairs / 1 relocation rule |
| r5 七类反例 + 额外 HUD/building 抽样 | 全部 exit 1、parseable FAIL、failure 命中准确 JSON path、无 traceback |
| coverage audit | 2562/2562 正确 FAIL；0 gap、0 pass、0 whitelist；matched path 2562/2562 |
| coverage evidence 确定性 | 独立输出与交付 evidence SHA-256 同为 `e33afdafabbb1744e95eca61c12a1b690a7ce59a7bf2e9a2e770e816b34a512e`，逐字节一致 |
| 全量 XCTest | 独立 xcresult：367/367 passed，0 failed，0 skipped，result Passed |
| `git diff --check` | exit 0 |
| contract SHA-256 | `328c1afd542464353058e47370373b19e5ca003ac6b49496b00ef2c2e723fd51` |
| spec SHA-256 | `fd8a7dd2127178af7e7290e3bc9c91f0ae88ae92022a728865626e7b95f05997` |

### 15.2 接收范围

本次 `APPROVED` 仅批准 `N-015-VSCODE-MAP-01` 的地图重排合同验证器、负向 XCTest、coverage 审计与隔离 evidence，确认 Codex 可以依据 DEC-035 冻结合同进入生产阶段 C。

它不代表：

- N-015 已完成或可改为 `accepted`；
- 当前 32×48 低清人物、24×24 地块或建筑像素层已通过 Product Owner 视觉验收；
- 5 栋建筑 30 层已经在真实地图接入；
- HUD、真实 App 截图、存档迁移、性能或最终消费者矩阵已经完成；
- N-016 音乐可以跳过 N-015 最终门禁提前结项。

Codex 阶段 C 必须优先解决玩家已明确指出的视觉问题：旧低清运行时像素资源不得因“有消费者”被误称为视觉合格；现有 8 张 2048 立绘和 5 张 2048 建筑原画必须进入自然玩家路径，同时以它们为视觉母版重做/提升地图运行层，而不是把高清原画直接缩成地图碰撞贴图。

### 15.3 非阻断观察项

`main()` 当前连续调用 `validate_contract(...)` 两次，结果随后被第二次覆盖。它不影响正确性或本次门禁，但使 coverage/XCTest 成本近似翻倍；可在不改变语义的后续维护中删除重复调用，不要求为此重开 VSCode 门禁。

```text
Outcome: APPROVED
VSCode package accepted: YES
Codex phase C authorized: YES
N-015 complete: NO (active / PENDING)
Current low-resolution art visually accepted: NO
Next owner: Codex / 🎮 gameplay + 🎨 art
```
