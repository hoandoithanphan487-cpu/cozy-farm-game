# Studio task: N-018 演示版美术完整接入与视觉成品化

Player outcome:
- 在 1280×800（主）和 960×640（兼容）窗口里，默认农场/集市画面是可公开展示的成品构图：正式像素资源铺满主要视觉区域，HUD 紧凑，立绘与建筑卡自然出现，没有程序化占位或开发态空白。

Current context:
- N-015、N-009、N-010、N-013、D0-002 均为 `accepted / APPROVED`。
- N-017 演示壳已提交但仍 `active / PENDING`；本任务不依赖其验收。
- 当前默认画面把整张地图装进窗口后格尺寸落到 24px，四周留下大面积深绿；HUD 为连续米色胶囊。

Assumptions:
- 正式 PNG 已经正确；缺陷在运行时取景、构图、HUD 和占位形状，不在重绘素材。
- 欢迎页只作入口，不能掩盖主画面问题。

Department:
- 🎭 World & Content（视觉成品）与 🧱 Engineering（运行时呈现）交叉；专项实现归 🎮 gameplay

Department quality owner:
- 🎭 `content`（构图、风格、区域身份、资源使用）

Specialist owner:
- 🎮 `gameplay`

Consulted:
- ✨ `ux`：HUD、可读性、窗口适配
- 🎨 `art`：像素缩放与风格统一

Downstream reviewer:
- 🧱 `tech` 与 🛡️ `quality`：仅在美术/内容与 UX 明确 `APPROVED` 后
- Product Owner：真实 App 画面最终批准，不得自动批准

In scope:
- 摄像机取景、默认整数缩放、玩家跟随与窗口适配。
- 正式地形/水体/道路填充场景边缘；天气/区域氛围色。
- HUD 排版、层级、正式图标；调试层默认隐藏。
- 立绘、建筑卡、事件反馈的展示位置。
- 132/132 玩家路径消费审计与真实 App 截图证据。

Out of scope:
- 修改地图拓扑、碰撞、玩法、经济、对白、存档 schema、稳定内容 ID。
- 重新生成或修改 N-009 立绘、N-015 地图角色及其他生产 PNG。
- N-014 猫店接入、N-016 音频验收、N-012 打包。

Inputs and dependencies:
- N-015、N-009、N-010、N-013、D0-002、DEC-037。

Deliverables:
- 摄像机/构图/HUD/氛围运行时改动。
- `artifacts/integration/n-018-visual/` 真实 App 截图、contact sheet、132/132 矩阵。
- 聚焦测试与完整 XCTest。

Acceptance criteria:
1. Given 正式 132 PNG，When 走默认演示路径，Then 132/132 均在玩家可见状态被消费，不得只存在于探针。
2. Given 1280×800，When 打开农场晴/雨与集市晴/雨，Then 游戏世界占据主要区域，无大面积无意义深绿空白，区域身份可辨。
3. Given 960×640，When 打开农场与集市默认画面，Then 角色、建筑、作物和互动目标一眼可读，像素为最近邻整数缩放。
4. Given 默认 HUD，When 不按 H，Then 无调试坐标、资源 ID、程序化占位或开发文字；HUD 紧凑且有层级。
5. Given 对话与建筑检查，When 触发，Then 8/8 立绘与 5/5 高清建筑图自然出现且不遮挡关键操作。
6. Given 耕种/浇水/播种/收获/出售/制作与设置音量，When 真实游玩，Then 事件反馈与设置页为成品画面。
7. Given 完整 XCTest，When 跑完，Then 至少维持当前 385 passed、0 failed、0 skipped，并覆盖新的构图契约。

Required evidence:
- 真实运行 App 截图（非静态探针）：1280 农场晴/雨、集市晴/雨；960 农场/集市；对话立绘；建筑展示；农耕事件；设置音量；contact sheet；132/132 矩阵。
- XCTest 原始日志。

Required gates:
- 🎭 content 审查真实截图 → ✨ ux 审查 HUD/适配 → 🧱 tech / 🛡️ quality → Product Owner 画面批准

Originality check:
- 只调整已批准原创资产的展示，不引入受保护构图或新素材。

Risks or open choices:
- N-015 地图合同冻结了 HUD 几何数字；本任务保持该合同数值，用摄像机与视觉样式解决空白，而不是改地图 JSON。
- 若必须改生产 PNG 才能消除占位，停止并升级 Product Owner。
