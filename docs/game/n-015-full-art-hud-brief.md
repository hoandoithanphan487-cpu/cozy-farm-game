# Studio task: N-015 全量运行时美术接入与 HUD 重构

Player outcome:
- 玩家启动游戏后看到完整、统一、原创的溪谷农场世界，而不是蓝色调试网格、几何色块、单字标记和遮屏日志；现有正式原画在移动、耕作、探索、交谈和建筑浏览中真实可见。

Current context:
- N-006 已交付并验收 131 张正式运行时像素 PNG；N-009 已交付 8 张高清全身立绘；N-013 已交付 5 栋高清建筑。
- 当前包内资源基本齐备，但运行时代码只映射少量角色、成熟作物与地块，大量场景仍由 `SKShapeNode` / `SKLabelNode` 占位绘制。
- N-007/N-010 解决了立绘卡和默认收起调试 HUD，N-011 只接入一栋建筑展示样板，均不等于全量地图美术接入。

Assumptions:
- “全量”指 N-006 的 131 张正式运行时资产、N-009 的 8 张立绘和 N-013 的 5 栋建筑；每个文件必须有明确运行时消费者、可见状态或经 Product Owner 批准的技术用途。
- N-014 猫店与三猫仍是候选内容；本任务不静默新增角色、稳定 ID、地图位置、剧情或玩法。

Department:
- 🧱 Engineering & Pipeline

Department quality owner:
- 🧱 `tech`

Specialist owner:
- 🎮 `gameplay`

Consulted:
- ✨ `ux`：HUD、信息层级、输入与无障碍
- 🎨 `art` / 🎭 `content`：资产用途、视觉一致性与原创性

Downstream reviewer:
- 🌱 `design` 与 🎭 `content`：玩家可读性和风格复核
- 🛡️ `quality`：独立运行验收

In scope:
- 建立完整资产 manifest/catalog，将 131 张正式 PNG 映射到实际场景状态。
- 两张地图的地形、水体、水岸、水渠、道路、建筑、道具、采集物与互动标识正式化。
- 玩家、3 名职能 NPC、4 名邻居的静态、行走和适用动作帧；未知/缺失资源安全回退。
- 5 种作物的 4 个阶段、浇水/收获/目标合法性/水渠流动等 FX。
- 五栋既有建筑的像素运行层和高清展示层；保持原碰撞、入口和地图拓扑。
- 以 `ui_*` 资产重构 HUD、背包/选择态、时间、天气、体力、货币与交互提示；调试信息默认关闭且不得遮挡主画面。
- 固定分辨率、缩放、键鼠/手柄、存读、性能和玩法回归。

Out of scope:
- 新玩法、新地图、新剧情、新经济数值、新存档语义。
- N-014 猫店/三猫的稳定 ID、地图/NPC/配方接入。
- 重新生成已经通过视觉验收的美术，除非运行时证据证明技术规格不兼容并经 Product Owner 同意。
- 以高清展示图直接替代碰撞、导航或像素地图层。

Inputs and dependencies:
- N-006、N-009、N-010、N-013、D0-002 均须为 `accepted / APPROVED`。
- DEC-031。
- `docs/game/art-style-master-doc.md` 与 `artifacts/art-style/runtime-batch-r0/` manifest。

Deliverables:
- 131 项资产消费矩阵：文件、状态、消费者、场景、缩放/锚点、回退、测试与截图证据。
- 数据驱动的完整运行时资产 catalog 和必要的展示节点/动画控制器。
- 成品 HUD 组件与调试层隔离。
- 运行时前后对照、两张地图和核心动作路径的截图/录屏证据。
- 实现交接、文件边界审计、构建与测试原始结果。

Acceptance criteria:
1. Given 132 张正式运行时 PNG（含 DEC-033 木蜜灶台增量），When 执行资产消费审计，Then 132/132 均有可追踪消费者或经 Product Owner 明确批准的技术用途，不能只证明“文件在 App 包里”。
2. Given 新游戏和两张地图，When 玩家移动、耕作、浇水、收获、采集、制作、出售与交谈，Then 不再依赖蓝色调试网格、`阻/流水/石阶/采/空` 等单字标记或几何图形作为默认主视觉。
3. Given 5 种作物，When 经过四个阶段，Then 每阶段使用对应正式图像且状态变化清晰；缺图时安全回退并产生可诊断记录。
4. Given 8 名角色，When 静止、移动、交谈及适用动作发生，Then 使用正确资产、朝向/脚底锚点稳定、碰撞和移动规则不变。
5. Given 五栋建筑，When 玩家在相应地图浏览和交互，Then 像素运行层与高清展示层均正确，入口、碰撞和地图拓扑与改造前一致。
6. Given 默认 HUD，When 以 960×640 和至少一个更大窗口运行，Then 时间、天气、体力、货币、选中物品和交互提示清晰且不遮挡主要操作；调试 HUD 仅在显式开启后出现。
7. Given 现有存档和控制设置，When 完全退出、重启并读取，Then 状态、键鼠/手柄路径和视觉呈现一致，不修改存档 schema 或经济结果。
8. Given 全量接入构建，When 执行 XCTest、性能和真实运行烟雾，Then 既有 271 项基线不回归，新增映射/回退/动画/HUD 测试通过，目标帧时间与内存基线不恶化到既有门槛之外。

Required evidence:
- 资产消费矩阵及独立反查：磁盘文件集合 = catalog 集合 = App 包集合。
- 构建/XCTest 原始命令、xcresult、失败/跳过/警告计数。
- 农场、集市、全部角色、全部作物阶段、五栋建筑、HUD 与缺失资源回退的真实运行证据。
- 存读、输入、性能、文件边界和 `git diff --check`。

Required gates:
- 开工依赖预检：🎬 `director`
- 实现门禁：🧱 `tech` 返回 `APPROVED | REVISE | BLOCKED`
- 玩家表现门禁：🌱 `design` 与 🎭 `content`
- 独立质量门禁：🛡️ `quality`
- 最终视觉验收：Product Owner

Originality check:
- 仅复用农场生活模拟的通用可读性约定。
- 所有视觉表达必须来自本项目已批准的原创资产和内部风格规范，不复制受保护的角色、地图、UI 布局或动画表达。

Risks or open choices:
- 工作区存在大量未提交资产与源码变更；开工前必须记录基线并确保不覆盖用户工作。
- 131 项全量接入可能暴露资产规格或状态缺口；发现缺口时应登记并请求有限返工，不得退回大面积程序化占位后仍声称完成。

Intake gate:
- Gate status: `APPROVED`
- Scope reviewed: Product Owner 已明确将本任务前置为最高优先级。
- Evidence inspected: N-006/N-009/N-010/N-013 台账证据、当前 `PixelAssetStore`、`FarmScene`、`ContentView` 与 App 资源集合。
- Next gate: 🎮 gameplay 开工依赖预检；本合同批准不等于实现批准。
