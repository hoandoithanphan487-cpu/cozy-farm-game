# Studio task: 《溪谷新芽》公开网页版垂直切片与稳定网址

Player outcome:
- 玩家无需安装 macOS 应用或登录，打开公开网址即可进入《溪谷新芽》的浏览器可玩切片。

Current context:
- 当前权威运行端为 Swift + SpriteKit macOS 应用，不能直接在浏览器运行。
- N-015 已验收正式美术/HUD，N-022 已验收农耕、出售与猫店/畜牧相邻能力；N-027 的 5–6 小时完整主剧情仍等待 Product Owner 自然计时试玩签核。
- 本任务使用独立 Web 运行层复用项目原创视觉资产与已验收规则，不声称移植完整 macOS 内容。

Assumptions:
- “布置到线上的网站”解释为公开、无需登录、可直接游玩的 Web 垂直切片，而不是仅提供 macOS 安装包下载页。
- 稳定网址由 OpenAI Sites 提供；自定义域名不在本任务内。
- 浏览器存档使用 `localStorage`，只在当前设备/浏览器内保存。

Department:
- 🛡️ Quality & Delivery

Department quality owner:
- 🛡️ `quality`

Specialist owner:
- 📦 `release`

Consulted:
- 🧱 `tech`、🎮 `gameplay`、✨ `ux`、🎭 `content`

Downstream reviewer:
- 🎬 `director`

In scope:
- 在独立 `web/creek-sprout/` Site 工程实现单页浏览器垂直切片。
- 复用已批准的原创像素资源，提供移动、翻土、播种、浇水、成长、收获、出售与本机存档。
- 键盘与触摸控制、响应式布局、明确的操作提示和安全的浏览器存档回退。
- 成功构建、独立质量复核、公开 Sites 生产部署与稳定网址。

Out of scope:
- Swift/SpriteKit 代码直接编译到浏览器。
- N-027 十段主剧情、完整 5–6 小时流程、猫店畜牧全量移植、跨设备云存档、账号系统、多人功能。
- 自定义域名购买或 DNS 配置。

Inputs and dependencies:
- N-003 `accepted / APPROVED`：原创像素资产与浏览器可复用素材基线。
- N-015 `accepted / APPROVED`：玩家可见美术与 HUD 基线。
- N-022 `accepted / APPROVED`：农耕、出售及相邻玩法规则基线。
- DEC-051：Product Owner 授权公开 Web 垂直切片与公开访问。

Deliverables:
- `web/creek-sprout/` 可独立构建的 Site 工程。
- 浏览器可玩农耕闭环、设备本地存档、键盘/触摸控制与响应式界面。
- 公开生产网址与部署状态证据。

Acceptance criteria:
- Given 新访客打开公开网址，When 页面加载完成，Then 无需登录且可在首屏开始游戏。
- Given 键盘或触摸输入，When 玩家移动并选择工具，Then 可完成翻土→播种→浇水→成长→收获→出售闭环。
- Given 页面刷新，When 浏览器本地存档有效，Then 关键状态恢复；损坏存档回退为安全新游戏。
- Given 960×640 桌面和窄屏手机视口，When 使用主要路径，Then 主要按钮、状态和游戏画面可见且不互相遮挡。
- Given 发布候选，When 运行生产构建，Then 构建成功且静态资源路径有效。
- Given 最终 Sites 部署，When 匿名访客打开网址，Then 公开访问且部署状态为 `succeeded`。

Required evidence:
- 生产构建退出码 0。
- 自动化状态/存档/核心闭环检查通过。
- 🧱 `tech` 对架构与资源边界明确 `APPROVED`。
- 🛡️ `quality` 对构建、主要路径、输入与公开部署明确 `APPROVED`。
- Sites 生产部署状态 `succeeded` 与公开访问策略。

Required gates:
- 🧱 Engineering & Pipeline gate。
- 🛡️ Quality & Delivery gate。
- 🎬 Direction & Production release review。

Originality check:
- 复用本项目已有原创素材、名称与规则表达。
- 不复制其他农场游戏的角色、对白、地图、界面、音频或代码。

Risks or open choices:
- Web 版本是独立实现，首版只保证本合同垂直切片与设备本地存档；与 macOS 存档不互通。
- Sites 生成网址为稳定生产网址；若后续需要品牌自定义域名，应另建 DNS/域名任务。

