# Studio task: N-013 五栋高分辨率完整建筑展示图

Player outcome:
- 在后续建筑展示页面看到清晰、完整、彼此可辨且同属《溪谷新芽》的五栋建筑，不再使用带棋盘格或分辨率不统一的旧概念图。

Current context:
- N-006 已 `accepted / APPROVED`，五栋建筑已有覆盖设计、三剪影、Product Owner 选型、配色概念、六层运行时像素资产及整包技术证据。
- N-009 的 8 名完整全身立绘已获 Product Owner 视觉 `APPROVED`，但内容与独立质量门禁仍待签发；N-010/N-011 因依赖尚未启动。
- 本任务把建筑图像生产与 N-011 运行时接入分开，允许先产出完整展示图而不绕过接入门禁。

Assumptions:
- Product Owner 的“也是”按与立绘同等级的清晰度理解为最终处理图 2048×2048 RGBA。
- “风格一致”指五栋之间统一使用 Master Doc 的暖色中世纪溪谷像素语言、轻微俯视三分之四视角、同一左上暖光、同一色票与材质规则。
- “画面完整”指屋脊、屋檐、地基、入口、台阶、轮/杆/网架/系缆桩/水口等所属附属件全部入画，Alpha bbox 不触画布边缘。

Department:
- 🎭 World & Content

Department quality owner:
- 🎭 `content`

Specialist owner:
- 🎨 `art`

Consulted:
- 🧱 `tech`（PNG/Alpha/尺寸/边界校验）
- 🎬 `director`（范围与依赖）

Downstream reviewer:
- 🛡️ `quality`
- Product Owner（逐栋视觉验收）

In scope:
- `brookseed.landmark.farm_house` / 木构农舍
- `brookseed.landmark.farm_sluice` / 铜闸水工坊
- `brookseed.landmark.market_seed_shed` / 种源棚
- `brookseed.landmark.market_warden_post` / 巡护亭
- `brookseed.landmark.market_wharf` / 苔石埠头
- 每栋一张独立高分辨率展示图、生成记录、清单、校验报告与五图联络表。

Out of scope:
- 不新增建筑、稳定 ID、状态、功能或地图布局。
- 不修改 Swift、Xcode 工程、正式 `Assets/`、存档 schema、玩法、经济、碰撞、入口、地图拓扑或主场景。
- 不启动 N-010/N-011 的运行时接入，不替换既有六层像素资产。

Inputs and dependencies:
- `docs/game/art-style-master-doc.md`
- `skills/building-art-style-generation/SKILL.md`
- `docs/game/building-art-style-spec-template.md`
- 五栋既有 `coverage-spec-v01.md`、`generation-record-v01.md` 及选中配色概念图，仅用于锁定已经批准的内部造型。
- N-006=`accepted / APPROVED`；DEC-027。

Deliverables:
- `artifacts/integration/n-013-buildings/source/`：ImageGen 输出。
- `artifacts/integration/n-013-buildings/processed/`：2048×2048 RGBA 最终处理图。
- `artifacts/integration/n-013-buildings/records/`：五份生成记录。
- `artifacts/integration/n-013-buildings/contact-sheet/n-013-buildings-contact-sheet-v01.png`。
- `manifest.json`、`evidence/validation-report.json`、`art-handoff.md`、`po-visual-checklist.md`。

Acceptance criteria:
- Given 五栋已批准内部建筑设计，When 生成展示图，Then 每栋保持选中方案的主体轮廓、入口和原创功能件，不擅自改型。
- Given 单栋最终 PNG，When 检查画布与 Alpha，Then 为 2048×2048 RGBA8，透明像素 RGB 清零，非透明 bbox 四边均有安全留白且不裁切任何建筑部件。
- Given 五张最终图，When 并排检查，Then 镜头、像素密度、左上暖光、深溪墨暗部、木蜜/麦秆金暖面和雾蓝/河岸青冷平衡一致。
- Given 单栋图，When 目检，Then 屋顶、地基、入口与功能件清晰；无人物、背景场景、文字、Logo、水印、签名、棋盘格、投影底板或额外建筑。
- Given 原创性审阅，When 与项目内其他四栋和外部受保护表达边界检查，Then 五栋不是通用换色，也不近似具体游戏或现实地标。

Required evidence:
- 源图与最终图 SHA-256、PNG IHDR、Alpha 范围、bbox/边距、非透明占比、透明 RGB 清零结果。
- 五栋并排联络表与逐栋生成记录。
- 🎭 content、Product Owner 与 🛡️ quality 的明确 `APPROVED | REVISE | BLOCKED`。

Required gates:
- 既有覆盖设计/三剪影/选型门禁：复用 N-006 及逐栋记录中的已批准结果，不重开造型。
- 本任务生产后：🎭 content → Product Owner → 🛡️ quality。

Originality check:
- 熟悉用途仅限农舍、水工坊、种源服务、巡护观察和水边装卸。
- 外轮廓、部件组合、色票、材质与空间关系来自项目 Master Doc 与既有批准记录；不使用外部作品名、画师名、外部色板或图生图外部素材。

Risks or open choices:
- ImageGen 可能输出伪透明棋盘格、软边或不一致视角；失败时仅做单点返工，不接受裁切或把背景烘焙进最终图。
- 2048 图为展示层资产，不代表 24×24 网格六层运行时资产；N-011 仍须单独接入和验收。
