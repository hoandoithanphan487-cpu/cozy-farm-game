# Studio task: 《溪谷新芽》完整 Web 迁移（直入游戏）

Player outcome:
- 玩家打开既有公开网址后直接进入《溪谷新芽》正式游戏，不经过欢迎页或开屏页；当前本地 macOS App 中可见、可玩的正式内容在浏览器中有等价入口和持久化结果。

Current context:
- 权威本地运行端为 Swift + SpriteKit；浏览器不能直接运行 SpriteKit，因此本任务以独立 TypeScript/React 运行层重建玩家可见行为。
- N-030 已交付公开 Web 垂直切片和固定 Sites 网址，但它只覆盖农耕首轮闭环。
- 当前本地 App 已接入 R22 两张地图视觉、五作物、加工/制作/放置、水脉主线、社区关系、畜牧与猫店收购、正式 Q01–Q10 剧情和本地多槽/保护档语义；N-016、N-019、N-027 仍有各自原生端长时或 Product Owner 最终签核缺口。

Product Owner decision:
- 2026-09-06 要求“本地 App 里是什么样，云端就是什么样”，并明确本轮省掉开屏部分，后续另议。
- 该决定授权 N-031 在不改变 N-016、N-019、N-027 原状态的前提下，使用它们当前已集成的实现和证据作为 Web 等价迁移输入。

Department:
- 🧱 Engineering & Pipeline

Specialist owner:
- 🎮 `gameplay`

Department quality owner:
- 🧱 `tech`

Cross-department quality owner:
- 🛡️ `quality`

Downstream reviewer:
- 📦 `release`

In scope:
- 继续使用 `web/creek-sprout/` 与现有公开 Sites 项目和网址。
- 首次访问直入新游戏；存在有效浏览器存档时直入继续游戏。暂停层保留存档、设置、帮助与重开能力，但没有标题/开屏页。
- 迁移当前本地 App 的两张正式地图、R22 视觉语言、移动/碰撞/换图、五作物农耕、天气/时间/体力、背包、出售、制作、加工、放置、采集、水脉、任务、社区关系、七名 NPC、Q01–Q10 正式剧情、Q08 旅程、Q09/Q10 双结局、畜牧照料与猫店收购。
- 浏览器本地自动存档、手动导出/导入 JSON、损坏存档安全回退；不声称与 macOS 原生存档文件直接互通。
- 键盘、鼠标和触摸输入；桌面优先且窄屏可操作；纯净 BGM 模式，默认遵循浏览器自动播放限制。

Out of scope:
- 欢迎页、开屏动画、标题页和相关视觉讨论。
- macOS SpriteKit 二进制直接运行于网页、原生存档文件无损导入、账号/跨设备云同步、多人、付费或自定义域名/DNS。
- 借本任务关闭 N-016、N-019、N-027 的原生端待签核项。

Inputs and dependencies:
- 已验收基线：M0-002、M0-003、M1-002、M2-001、M3-001、M3-002、M3-003、D0-002、N-004、N-006、N-009、N-010、N-013、N-014、N-015、N-022、N-024、N-025、N-026、N-030。
- 有界例外：N-016、N-019、N-027 保持 `active / PENDING`；DEC-052 只允许读取其当前集成实现作为 Web 迁移输入，不能据此宣称原生端验收完成。

Acceptance criteria:
- Given 新浏览器且无有效存档，When 打开公开网址，Then 直接进入第 1 天农场可操作状态，不出现开屏、标题或欢迎页。
- Given 有有效浏览器存档，When 刷新或再次访问，Then 直接恢复地图、日期、背包、田地、任务、关系、畜牧、剧情和结局状态。
- Given 玩家使用键盘/触摸，When 进行完整游玩，Then 两张地图、五作物、采集、制作/加工/放置、出售、畜牧、猫店、水脉、社区和 Q01–Q10 均有可达入口，不以静态说明冒充实现。
- Given Q08/Q09/Q10，When 玩家进入对应剧情，Then 旅程检查点、揭露保护点和 water/leave 双结局可完成且可存读。
- Given 用户打开暂停/设置，When 调整音量或文字速度、导出/导入存档或重开，Then 操作明确、失败安全且不会无确认覆盖有效进度。
- Given 生产构建和自动化验证，When 执行发布候选，Then 内容目录、主要状态转换、存档往返、损坏回退、两图可达和生产构建全部通过。
- Given 最终 Sites 部署，When 匿名访客访问既有网址，Then 公开 HTTP 200、部署 `succeeded`、URL 保持不变。

Required gates:
- 🎮 gameplay 实施提交。
- 🧱 tech 部门质量门：领域/呈现边界、状态转换、资源路径、存档安全与构建。
- 🛡️ quality 跨部门复核：内容可达性、输入、响应式、长流程抽样和不夸大边界。
- 📦 release 下游发布门：版本、公开策略、固定 URL 与回滚信息。

Originality check:
- 只使用本项目已有原创素材、获准音乐和项目自身内容；不复制其他农场游戏的角色、对白、地图、界面、音频或代码。

Known limitation:
- Web 是行为等价迁移而非 Swift 源码同构编译；浏览器存档与 macOS 原生存档不直接互通。
