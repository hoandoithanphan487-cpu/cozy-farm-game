# Studio task: M1-002 Swift/SpriteKit 农耕闭环

**Status:** active / REVISE  
**Decision:** DEC-013、DEC-014

## Player outcome

玩家可在 macOS arm64 的 SpriteKit 客户端中移动、确定目标格、翻土、播种、浇水、睡眠推进作物、收获，并在保存、退出和读取后保持时间、体力、背包与农田状态一致。

## Current context and assumptions

- P0-007 已为 `accepted / APPROVED`，当前 Swift 尖峰具备 10×6 网格移动、边界约束和最小 JSON 存读。
- M1-001 保持 `blocked / BLOCKED`，其 Godot 实现、数据和测试仅作为行为参考，不再作为下游开发依赖或 Swift 运行证据。
- M1-002 直接拥有所需的 Swift 领域层、Codable 内容模型、存档 schema 增量、XCTest 与 SpriteKit/SwiftUI 适配；不依赖尚不存在的“Swift M0 等价任务”。
- 不承诺导入未发布的 Godot 本地存档；既有 Godot 文件和证据必须保留。

## Assignment and approval contract

| Field | Contract |
|---|---|
| Department | 🧱 Engineering & Pipeline |
| Specialist owner | 🎮 gameplay：Swift 领域规则、内容模型、存档与 XCTest；Xcode 负责表现适配和工程集成 |
| Department quality owner | 🧱 tech：架构、事务、数据/存档安全、测试与集成证据 |
| Consulted | 🌱 design：规则、反馈与可用性；🛠️ tools：稳定 ID 与数据验证 |
| Cross-department reviewer | 🛡️ quality：独立构建、测试、运行、存读与烟雾复核 |
| Downstream handoff | M2-001、M2-002、M3-001；只有 M1-002 `accepted / APPROVED` 后才满足依赖 |

## Inputs and dependencies

- P0-007：`accepted / APPROVED`；提供 SwiftUI + SpriteKit 壳、移动、XCTest 与 SaveStore 尖峰。
- DEC-013：运行端切换至 Xcode + Swift + SpriteKit。
- DEC-014：冻结 M1 数值并确认 M1-002 直接拥有 Swift 领域层和存档 schema 增量。
- `docs/game/PRD.md` 6.1–6.5、6.13、10、14；`docs/game/TDD.md` 7.1–7.3、10、11、16、17。
- M1-001 的 Godot 文件、数据和测试仅作行为参考。

## In scope

1. 保持 10×6 占位农场的移动与边界约束，加入面向方向和目标格。
2. 实现累计时间、组合暂停原因、06:30–23:30 时钟与睡眠日结。
3. 实现体力、固定槽位背包、堆叠限制和原子增删事务。
4. 实现翻土、播种、浇水、成长、成熟和收获的纯 Swift 领域规则。
5. 使用 Codable 数据与稳定 ID 定义最小雾萝卜占位内容。
6. 扩展 JSON 存档以覆盖玩家、时钟、体力、背包容量、物品和农田状态，并保留临时写入、回读验证、备份与安全失败。
7. 用 SpriteKit/SwiftUI 呈现目标格、农田阶段、HUD 和成功/失败反馈，不让表现层成为权威状态源。
8. 提供 XCTest、Xcode Build/Test 原始输出、手工烟雾截图和 Hermes 独立 QA 报告。

## Frozen M1 baselines

| Item | Baseline |
|---|---|
| Initial stamina | 100 |
| M1 labour cost | `hoe`、`seed`、`water`、`harvest` 成功时各 2；失败为 0 |
| Clock rate | 每现实秒 1.3 游戏分钟；与渲染帧率无关 |
| Day bounds | 06:30–23:30 |
| Inventory capacity | 16 格 |
| Common stack limit | 99 |
| Crop ID | `brookseed.crop.mist_radish` |
| Seed / harvest IDs | `brookseed.item.mist_radish_seed` / `brookseed.item.mist_radish` |
| Growth | `stage_days = [1,1,1]`、`mature_stage_index = 2`、单次产量 1 |
| Missing water | 当日不成长，不立即死亡 |

## Out of scope

- 出售箱、174 溪票、货币结算、制作、放置、水渠、NPC、任务与社交事件。
- 正式美术、音频、发行包、性能验收、iOS、Windows、3D 或多人游戏。
- 删除、重命名、批量转换或修改 Godot 源码、场景、资源、测试、导出预设与历史证据。
- 直接复制 GDScript、`.tscn` 或 `.tres`，或把 Godot 历史测试当成 Swift 证据。
- 修改 bundle ID、签名、部署目标、发行平台或其他产品范围。

## Acceptance criteria

- Given 一包雾萝卜种子和可达目标格，When 玩家依次翻土、播种、浇水并完成两次有效浇水日结，Then 作物成熟且可收获 1 个雾萝卜到背包。
- Given 作物当天未浇水，When 执行日结，Then 作物阶段不推进且不会死亡。
- Given 玩家仅有 1 点体力，When 尝试任一 M1 劳动，Then 动作失败且体力、库存和地块全部不变。
- Given 背包已满，When 尝试收获，Then 动作失败且成熟作物仍留在原地。
- Given 同时存在两个暂停原因，When 只移除其中一个，Then 时钟仍保持暂停。
- Given 已修改时间、体力、背包和多个农田格，When 保存、退出并读取，Then 所有状态完整往返。
- Given 主存档损坏且备份有效，When 读取，Then 加载备份且保留损坏主档；若两代均无效则安全失败而不覆盖文件。
- Given Cursor 与 Xcode 完成交接，When Hermes 独立重跑 Build、XCTest 与手工路径，Then 原始证据可复现且未使用 Godot 结果替代。

## File ownership

| Tool | Owns | Must not touch |
|---|---|---|
| Cursor | `Domain/`、`Persistence/`、新增 Codable 内容、`CreekSproutTests/` | `FarmScene.swift`、`ContentView.swift`、签名/发行设置、Godot 文件 |
| Xcode | `FarmScene.swift`、`ContentView.swift`、target membership、工程集成与本机证据 | 领域规则与平衡值、Godot 文件、签名/发行范围 |
| Hermes | 只读追踪、独立 Build/Test/烟雾、截图、日志与缺陷报告 | 源码、工程配置、台账状态、自行批准实现 |

## Required evidence and gates

1. Cursor：变更文件、XCTest 或等待集成的真实结果、`git diff --check`、风险与交接。
2. Xcode：工具链、Build/Test 命令与退出码、实际测试数、启动和完整农耕烟雾截图。
3. 🧱 tech：检查领域/表现分层、事务原子性、数据验证、存档安全和工程集成后返回 `APPROVED`、`REVISE` 或 `BLOCKED`。
4. Hermes：独立生成 `PASS`、`FAIL` 或 `BLOCKED` 建议与原始证据。
5. 🛡️ quality：依据独立证据返回最终质量门禁。未取得 🧱 tech 与 🛡️ quality 的明确 `APPROVED` 前，M1-002 不得设为 `accepted`。

## Originality check

- 网格农耕、体力、日结和作物成长属于类型惯例。
- 名称、稳定 ID、占位几何、色彩、HUD 构图、反馈文案和代码必须为《溪谷新芽》的原创表达，不复制任何既有游戏资产或受保护表达。

## Risks and follow-ups

- PRD/TDD 的其余 Godot 专属章节尚未全量迁移；M1-002 以 DEC-013、本任务合同和明确引用的跨引擎行为规则为准。
- P0-007 的 6 项 XCTest 只证明技术尖峰，不证明 M1-002 的农耕、事务或扩展存档已经通过。
- 2026-08-13 Product Owner 已授权启动，依赖预检通过，任务为 `active / PENDING`。Cursor 可开始领域层与 XCTest；Xcode 仅在 Cursor 交接后进行工程和表现集成，二者不得同时编辑重叠文件。
- 2026-08-14 🧱 tech 独立复核返回 `REVISE`：修复多堆背包与存档校验冲突、将农田坐标限制到 10×6，并为扩展 JSON 增加 `schema_version` 与迁移入口及相应 XCTest 后，方可移交 Xcode。
