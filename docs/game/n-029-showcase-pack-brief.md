# Studio task: N-029《溪谷新芽》项目展示包

Player/audience outcome:
- 外部观看者能在数分钟内理解《溪谷新芽》的角色阵容、建筑语言、环境身份、核心玩法与生活系统，并能区分概念展示和真实运行画面。

Current context:
- Product Owner 要求分别生成人物、建筑、环境设计展示图，并授权补充对外展示所需内容。
- N-028 已有竖版群像海报，可作为封面候选，但本任务不依赖其最终验收。

Assumptions:
- 展示包采用五张独立 3:2 横版视觉板，适合发送、网站图集、提案和幻灯片。
- 新生成图片属于概念/设计展示，不冒充实机截图；实机证据单独索引既有验收截图。

Department:
- 🎭 World & Content

Department quality owner:
- 🎭 `content`

Specialist owner:
- 🎨 `art`

Consulted:
- 🗺️ `world`、🌱 `design`、✨ `ux`

Downstream reviewer:
- 🛡️ `quality`（跨部门，防止自我批准）

In scope:
- 01 人物设计：8 名主要人物全部出现、玩家居中、身份色与道具可辨、人物尺度接近。
- 02 建筑设计：木构农舍、铜闸水工坊、种源棚、巡护亭、苔石埠头、溪火猫食铺完整展示。
- 03 环境设计：农场、溪岸集市、梯田溪谷/水工生态三种区域气质形成连贯世界。
- 04 核心玩法：翻土、播种、浇水、收获、制作/建造、交谈/协作形成可读的生活循环。
- 05 物产与生活：五种原创作物、牛羊山羊、采集物、工具、灶台、猫店供货与溪谷日常。
- 建立 README，列出概念板与真实 App 证据，明确二者性质。

Out of scope:
- 不修改 Swift、正式 Assets、玩法、经济、剧情、存档或地图拓扑。
- 不把生成图描述为实际游戏画面，不生成虚构平台评分、奖项、发行日期或功能承诺。
- 不复制其他游戏的角色、建筑、地图、UI、Logo、文案或可识别表达。

Inputs and dependencies:
- N-003、N-006、N-009、N-013、N-014、N-015、N-022 均须为 `accepted / APPROVED`。
- 项目权威参考：N-009 角色总览、N-013 建筑总览、N-014 猫店总览、N-006 运行时资产总览、N-015 已验收地图/角色证据、N-022 畜牧/供货垂直切片。

Deliverables:
- `artifacts/marketing/n-029-showcase/01-character-design.png`
- `artifacts/marketing/n-029-showcase/02-building-design.png`
- `artifacts/marketing/n-029-showcase/03-environment-design.png`
- `artifacts/marketing/n-029-showcase/04-core-gameplay.png`
- `artifacts/marketing/n-029-showcase/05-life-and-produce.png`
- `artifacts/marketing/n-029-showcase/README.md`
- `artifacts/marketing/n-029-showcase/generation-record.md`
- `artifacts/marketing/n-029-showcase/review.md`

Acceptance criteria:
- 五张图采用统一的暖米色展示板、深苔绿边框、木蜜/雾蓝/湿土褐/铜橙色系与绘本式立体渲染。
- 每张图只出现一个准确中文分类标题，不含伪造小字、Logo、评分、水印或无关文字。
- 人物板为 8 人且各一次，玩家居中；建筑板六处设计互不混淆；环境板至少三处区域可辨。
- 核心玩法板覆盖农耕→收获→制作/建造→交谈/协作；生活板覆盖作物、畜牧、采集、工具、加工与猫店供货。
- README 明确“概念展示图”和“真实 App 截图”，真实截图只引用既有文件，不经生成模型改写。

Required evidence:
- 每张 PNG 的尺寸、格式、哈希与图像完整性检查。
- 🎭 content：身份、世界一致性、原创性与展示叙事。
- 🛡️ quality：数量、文字、禁项、缺陷、文件和 README 真实性边界。

Required gates:
- 🎭 content department gate。
- 🛡️ quality downstream gate。
- Product Owner 最终视觉终审；此前任务保持 `active / PENDING`。

Originality check:
- 可复用展示板、角色设定板、建筑图鉴、环境概念图等通用传播形式。
- 所有角色、建筑、生态、作物、道具与交互采用《溪谷新芽》既有原创身份重新构图。

Risks or open choices:
- 五图文字只保留分类标题，降低中文生成错误；若标题错误则定点重生成该图。
- 生成图不用于证明运行时实现；README 必须把概念与实机分栏。
