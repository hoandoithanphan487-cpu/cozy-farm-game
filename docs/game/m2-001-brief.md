# Studio task: M2-001 出售箱、日结、货币明细、制作与放置

**Status:** active / PENDING（2026-08-17 开工登记）
**Decision:** 无新增决策记录；沿用 DEC-013、DEC-014 与既有 PRD/TDD 合同

## Player outcome

玩家在 VS-0 中可以把收获的雾萝卜投入出售箱、睡眠前取回，并在睡眠日结时收到唯一一次的货币结算与逐项明细（3 株普通雾萝卜 = 174 溪票）；货币始终不为负且每一笔来源/消耗可查；数据驱动的制作与放置事务在成功时才消耗材料，任何失败都不扣料。

## Current context and assumptions

- M1-002 已为 `accepted / APPROVED`：Swift 领域层、ContentCatalog、SaveStore（schema v1）、39/39 XCTest、跨进程存读证据齐备。
- M2-001 直接依赖 M1-002 与 M0-003（均已 `accepted / APPROVED`），预检通过。
- 现有架构约定：`GameState` 为值类型权威状态，领域服务为纯函数（preview/apply 模式），表现层（FarmScene/ContentView）只派生渲染，存档走 `SaveCodec` + `SaveMigrator` + `SaveStore`（tmp→回读→backup→替换）+ `SaveValidation`。
- 开工基线（2026-08-17，已逐字节核验）：8 个 Swift 文件 SHA-256 与 `artifacts/integration/m1-002-xcode/hermes-r5/file-boundary-sha256.txt` 一致；`docs/game/project-ledger.md` 的 diff 仅为 M1-002 验收登记；`artifacts/integration/` 为验收证据。**任何超出该清单的新修改均视为 M2 变更。**
- 不承诺导入 Godot 存档；Godot 文件与历史证据必须保留。
- 溪叶菜、琥珀豆、铃花莓、蜜穗瓜的作物/商店内容不在本任务（VS-0 仅需雾萝卜；其余作物数据验证属 M3/后续）。

## 开工基线清单（M2 变更起点）

| 类别 | 内容 |
|---|---|
| 基线文件（8 个，SHA-256 见 `hermes-r5/file-boundary-sha256.txt`） | ContentID.swift、SaveMigrator.swift、FarmLoopTests.swift、GridMovementTests.swift、InventoryServiceTests.swift、SaveStoreTests.swift、FarmScene.swift、ContentView.swift |
| 台账 | `docs/game/project-ledger.md`（含 2026-08-17 M1-002 验收登记，属基线） |
| 证据目录 | `artifacts/integration/m1-002-xcode/`（只读，不得改写） |
| 其余源码 | `Domain/`、`Persistence/`、`Content/`、`CreekSproutTests/` 全部已跟踪文件（当前哈希即基线） |

**基线风险：** ① 工作区相对 HEAD 有 9 个未提交改动，HEAD 未包含 M1-002 最终状态——M2 交付与验收必须以当前工作区（= 已验收基线）为基准，提交时机由 Product Owner 决定；② `schema_version` 1→2 的迁移必须覆盖既有 v1 存档，否则已验收存档将不可读。

## Assignment and approval contract

| Field | Contract |
|---|---|
| Department | 🧱 Engineering & Pipeline |
| Specialist owner | 🎮 gameplay：Swift 领域规则、内容数据、存档 v2、XCTest；Cursor 为主编码工具 |
| Department quality owner | 🧱 tech：事务原子性、存档安全、数据验证、架构与集成证据 |
| Consulted | 🌱 design：规则完整性、经济意图、反馈与验收；🛠️ tools：稳定 ID 与数据验证 |
| Cross-department reviewer | 🌱 design（合同阶段跨部门审阅）+ 🛡️ quality（交付后独立复核） |
| Downstream handoff | M2-002（教学流程与 VS-0 路径）；M3-002 依赖 M2-001 |

## Inputs and dependencies

- M1-002 `accepted / APPROVED`：领域层、ContentCatalog、SaveStore v1、39 XCTest、运行时烟雾证据。
- M0-003 `accepted / APPROVED`：存档/设置/随机流基线合同。
- `docs/game/PRD.md` 6.5、6.6、6.8、9、10（FR-005/006/009/012）、14。
- `docs/game/TDD.md` 6.2（ItemDefinition/NewGameScenarioDefinition/RecipeDefinition）、6.3（运行状态）、7.1（日结顺序）、7.3、7.4、7.5、10（存档 v2/迁移）、16（测试）、17（M2 门禁）、18（schema 变更规则）。

## In scope

1. **经济状态**：`GameState` 增加 `scenarioID`、经济（余额、待结算、结算历史、货币明细 ledger）与放置状态；货币只接受整数事务，余额不得为负；每笔货币变化记录 `reasonID`、`amount`、`sourceRef`、`dayIndex`。
2. **出售箱**：`ShippingService` 独占待结算状态；投入时从背包原子移除并生成价格快照条目；取回时先验证背包容量再原子返还；失败时两处状态均不变。
3. **日结结算**：`SettleShippingUseCase` 以 `scenarioID + game_day` 生成唯一结算 ID；先由服务生成待提交变更，再单事务一次增加余额、清空对应待结算项并写 `SettlementRecord`；已存在结算 ID 时返回幂等成功，不二次到账、不二次发布事件。
4. **174 溪票基线**：3 株普通雾萝卜（quality=normal，倍率 1.00）合并为一条 `quantity=3` 待结算条目，快照单价 58，日结明细显示「雾萝卜×3 = 174」。
5. **新游戏场景数据**：`NewGameScenarioDefinition` 最小实现（VS-0 子集）：`starting_currency=720`、起始雾萝卜种子×8、教学地块 3 株成熟雾萝卜（默认 (4,1)、(5,1)、(6,1)，数据可调）、`starting_recipe_ids`（木箱、小径、堆肥架、水渠接片）、默认 `scenario_id`。
6. **数据驱动配方**：`RecipeDefinition`（id、nameKey、inputs、outputs、placedObjectID?）进入 `ContentCatalog`；配方数据仅 PRD 6.6 的 4 个初始配方（雨水桶因解锁条件属 M3，不进目录）。
7. **制作事务**：`CraftingService` 验证材料充足后一次性原子移除材料并添加输出；材料不足、配方未知、输出背包容量不足时失败且背包不变。
8. **放置**：`PlacedObjectDefinition`（id、nameKey、footprint 相对坐标、category）进入目录；`PlacementService` 校验地图允许层（10×6）、占地、冲突（既有放置物/作物格）、可达性（放置原点与玩家相邻）；全部通过才消耗 1 个对应输出物品并创建 `PlacedObjectState`；预览为纯表现对象，不进存档。
9. **存档 v2**：`SaveGameDTO` 增加 `scenario_id`、`economy`（余额、按 entry_id 排序的待结算条目、结算历史、货币明细）、`placed_objects`；`schema_version` 提升至 2；`SaveValidation` 覆盖新字段（余额非负、结算 ID 唯一、条目/历史排序与唯一性、放置定义与占地合法）；`SaveMigrator` 增加 v1→v2 迁移。
10. **日结集成**：睡眠执行顺序对齐 TDD 7.1——冻结输入/时钟 → 结算当日出售 → 推进作物与日历 → 生成日结摘要 → 自动保存 → 进入新日；日结可重入保护。
11. **调试报表**：`EconomyDebugReport` 输出余额与全部来源/消耗明细（含迁移 grant）；开发构建提供触发入口。
12. **最小可运行反馈**：HUD 增加货币余额、待结算数量与结算结果；键盘路径覆盖投入/取回/日结/调试报表；DEBUG 构建提供材料注入命令以便手工验证制作→放置闭环（正式采集属 M3）。
13. **自动化测试**：XCTest 覆盖全部验收规则与 M1 回归（39 项既有用例不得回归）。

## Frozen rules（本任务锁定值，调参只改内容数据）

| 项 | 值 | 来源 |
|---|---|---|
| 雾萝卜基础售价 | 58 溪票 | PRD 6.8.3 |
| 3 株普通雾萝卜结算 | 174 溪票（58×3×1.00） | PRD 6.8.1、14 |
| 起始货币 | 720 溪票 | PRD 6.8.2 |
| 品质倍率（定点） | normal 100 / good 118 / excellent 142（基点） | PRD 6.8.3；VS-0 仅产生 normal，判定系统不在范围 |
| 默认 scenario_id | `brookseed.scenario.vs1`（与 TDD 10.1 存档示例一致） | TDD 10.1 |
| 结算 ID 格式 | `\(scenario_id).day\(game_day)` | TDD 6.3/7.4 |
| schema_version | 2（v1→v2 迁移） | TDD 10.4、18 |
| v1→v2 迁移默认 | 注入 scenario_id、balance=720 且 ledger 记一条 `migration.grant` 明细、空待结算/历史/放置 | 本任务决策（见风险节） |
| 待结算条目合并 | 同 item_id + quality + deposited_day 合并为一条，quantity 累加 | TDD 7.4 VS-0 |
| 空箱日结 | 仍生成总额 0 的结算记录并标记该日已结算（幂等一致） | 本任务决策 |
| 制作/放置体力消耗 | 0（PRD 未规定，本任务不引入） | 本任务假设 |

## Out of scope

- M2-002：教学流程、完整 10–15 分钟引导、场景叙事包装。
- NPC、对话、两张地图、正式美术与音频。
- M3：水脉 +12/+8 贡献、任务交付、世界变化、采集点、随机掉落、品质判定系统、雨水桶解锁、琥珀豆/溪叶菜商店。
- Godot 文件修改（源码、场景、资源、测试、导出预设、历史证据）。
- 平台、Bundle ID、签名、部署版本、发行配置变更；性能/发行验收。
- 不删除、不覆盖、不提交既有用户改动；不重写已验收的 M1 行为。

## Acceptance criteria（Given / When / Then）

- **AC-1 投入原子性**：Given 背包有 3 个雾萝卜且出售箱为空，When 玩家投入出售箱，Then 背包雾萝卜归零、待结算出现一条 `quantity=3` 条目（含 itemID、quality=normal、depositedDay、unitPriceSnapshot=58）；若任一校验失败，Then 背包与待结算均不变。
- **AC-2 取回原子性**：Given 待结算有雾萝卜×3 且背包容量充足，When 玩家取回，Then 条目消失且背包恢复雾萝卜×3；Given 背包容量不足，When 取回，Then 失败且条目与背包均不变。
- **AC-3 价格快照**：Given 投入时目录售价为 58，When 生成待结算条目，Then 快照单价为 58；之后目录调价不得改变已投入条目的结算价。
- **AC-4 唯一结算 ID**：Given 第 1 天睡眠，When 执行日结，Then 生成 `brookseed.scenario.vs1.day1` 结算记录、余额 +174、历史含逐项金额与总额。
- **AC-5 幂等结算**：Given 第 1 天已结算，When 再次日结或重复读取后再次结算，Then 不二次到账、不产生第二条记录，返回幂等成功。
- **AC-6 负货币拒绝**：Given 余额为 0，When 提交 −1 的货币事务，Then 拒绝且余额与明细均不变。
- **AC-7 货币明细**：Given 任意货币变化（结算、迁移 grant、调试注入），When 记账，Then ledger 包含 reasonID、amount、sourceRef、dayIndex，且调试报表可完整输出。
- **AC-8 174 结算**：Given 新游戏（720 起始货币、3 株成熟教学雾萝卜），When 收获 3 株→投入→睡眠结算，Then 收到 174、余额 894，明细显示「雾萝卜×3 = 174」。
- **AC-9 配方数据驱动**：Given 目录含 `recipe.wooden_crate`（溪木×12→木箱×1），When 材料充足时制作，Then 材料原子移除且输出入背包；Given 材料不足或配方未知，When 制作，Then 失败且背包不变。
- **AC-10 放置失败不扣料**：Given 已制作 1 个木箱输出物品，When 在合法格放置，Then 消耗 1 个输出物品并创建 `PlacedObjectState`；Given 越界、与既有放置物或作物格冲突、或原点与玩家不相邻，When 放置，Then 失败且不消耗任何物品、不产生状态。
- **AC-11 存档往返**：Given 含余额、待结算、结算历史、放置的 v2 状态，When 保存→退出→重启→读取，Then 全部字段完整往返且校验通过。
- **AC-12 v1 迁移**：Given 一份 v1 存档（无经济字段），When 读取，Then 迁移至 v2（注入 scenario_id、720 起始 + `migration.grant` 明细、空待结算/历史/放置）并可继续正常游戏。
- **AC-13 校验拒绝损坏**：Given 存档含负余额、重复结算 ID、非法放置或越界条目，When 读取，Then 该代存档无效、安全回退备份、不部分载入。
- **AC-14 自动化测试**：Given M2 实现完成，When 运行 XCTest，Then 新增用例覆盖 AC-1~13 且全部通过，既有 39 项用例 0 回归。
- **AC-15 调试报表**：Given 开发构建，When 触发报表命令，Then 输出余额与每笔来源/消耗明细，格式稳定可断言。
- **AC-16 最小可运行反馈**：Given 运行中的 App，When 玩家执行投入→日结，Then HUD 显示余额、待结算数量与结算结果反馈，174 路径可完整操作。

## File ownership

| 工具 | 可修改 | 不得触碰 |
|---|---|---|
| Cursor（🎮 gameplay） | `Domain/`（新增 Economy/Shipping/Crafting/Placement/Settle 服务与状态类型；GameState 扩展）、`Content/`（ItemDefinition 增 `baseSellPrice`、RecipeDefinition、PlacedObjectDefinition、NewGameScenarioDefinition、ContentCatalog/ContentID 扩展）、`Persistence/`（DTO v2、SaveMigrator v1→v2、SaveValidation）、`CreekSproutTests/`（新增测试文件与既有用例扩展） | `FarmScene.swift`、`ContentView.swift`、xcodeproj 工程配置、签名/发行设置、Godot 文件、台账 |
| Xcode（表现层集成） | `FarmScene.swift`（HUD/反馈/日结调用/预览渲染）、`ContentView.swift`（按键映射）、xcodeproj target membership（新文件入工程） | 领域规则与平衡值、Godot 文件、签名/发行范围、台账 |
| Hermes | 只读追踪、独立 Build/Test/烟雾、截图、日志与缺陷报告 | 源码、工程配置、台账状态、自行批准实现 |

**Xcode 必须提供的证据：** ① 工具链版本与完整 `xcodebuild ... clean test` 原始日志（退出码、TEST SUCCEEDED）；② 权威测试计数（总数/通过/失败/跳过，来自 xcresult）；③ 运行时烟雾截图与 HUD 文本：新游戏→收获 3 株→投入出售箱→保存→完全退出→重启→读取（待结算仍在）→睡眠结算 174→再次读取/重试日结不重复到账；④ 失败反馈截图（取回容量不足、放置冲突/越界/不可达不扣料）；⑤ `git diff --check` 通过、工程/Godot/台账门禁期间无 diff 的核对。

## Required gates

1. 🧱 tech：检查事务原子性、存档 v2 安全、迁移与校验、数据验证、表现/领域分层后返回 `APPROVED`、`REVISE` 或 `BLOCKED`。
2. 🌱 design：确认规则完整性、经济意图、反馈与验收可观察性（本任务合同阶段已完成跨部门审查，见下节）。
3. 🛡️ quality：依据独立证据返回最终质量门禁；未取得 🧱 tech 与 🛡️ quality 明确 `APPROVED` 前，M2-001 不得设为 `accepted`。

## Originality check

- 出售箱、睡眠日结、货币与制作/放置属于类型惯例；本任务全部使用《溪谷新芽》原创的稳定 ID、名称、占位几何、HUD 构图与反馈文案。
- 所有数值来自 PRD 6.8 原创基线，不复制任何既有游戏的数据或表达。

## Risks and open choices

- **决策（已定）**：v1→v2 迁移给旧存档注入 720 起始货币并记 `migration.grant` 明细——理由：M1 存档从未发放过起始资金，迁移后与同场景新游戏保持经济一致，且明细可审计；若 Product Owner 希望旧档从 0 开始，仅需改迁移函数与对应测试。
- **决策（已定）**：日结包含自动保存（复用 slot_0 安全替换机制）——PRD 14 第 3 步要求验证「再次读取自动存档不重复到账」，TDD 7.1 睡眠顺序第 7 步为写自动存档。
- **假设**：制作/放置不消耗体力（PRD 未规定）；待结算合并按 item+quality+day；空箱日结仍记录 0 金额结算。
- **风险**：M1-002 基线未提交（HEAD 落后工作区）——M2 期间任何人不得 commit 或改写历史，提交由 Product Owner 决定；「自动保存」与「手动保存」同槽位可能造成教学流程（M2-002）中覆盖困惑，届时由 M2-002 的 UX 决策处理。
- **风险**：若 Cursor 与 Xcode 并行编辑重叠文件，会造成交接冲突——按文件边界顺序作业：Cursor 先完成领域/内容/持久化/测试，Xcode 仅在交接后进行表现层集成。

---

## 🌱 design 跨部门审查记录（合同阶段）

- **审查人角色**：🌱 Design & Player Experience Lead（本环境无独立子代理，按 AGENTS.md「delegation 不可用时依序扮演角色」承接，审查独立于 🎬 director 起草过程执行）
- **审查对象**：本任务合同的规则完整性、经济意图、反馈与验收可观察性、原创性边界
- **审查要点**：
  1. 规则完整性：投入/取回/结算/放置的失败路径均有原子性与明确反馈；重复日结、重复读取、空箱日结、负货币均有可测试规则 ✅
  2. 经济意图：720 起始 + 首日 174 落在 PRD 6.8.1「第 1–3 天 90–180 每日可支配净收入」区间；快照定价避免调价回算 ✅
  3. 平衡与防利用：待结算按 item+quality+day 合并、唯一结算 ID、幂等结算杜绝重复发钱；品质倍率以定点基点数存储避免浮点漂移 ✅
  4. 可达性：教学地块 3 株成熟雾萝卜保证首日 174 路径不依赖种植周期；放置可达性=与玩家相邻，规则可断言 ✅
  5. 反馈与可用性：HUD 余额/待结算/结算明细、✅/❌ 反馈延续 M1 惯例、非纯颜色信号（形状+文字）✅
  6. 原创性：全部 ID/文案/数值原创或源自 PRD 基线，无受保护表达 ✅
  7. 验收可观察性：16 条 Given/When/Then 均可由 XCTest 或运行时烟雾独立断言 ✅
  8. 范围纪律：M2-002 教学、M3 水脉/任务/采集、NPC/地图/美术音频、Godot 与发行配置均明确排除 ✅

**Gate status: APPROVED**（无 REVISE 条件；两条既有决策——v1 迁移注入 720 与日结自动保存——已在合同记录并附理由，实现时须在交接说明中重申）
