# Studio task: N-017 明日内部演示稳定化

Player outcome:
- 明天现场观众可以从正式欢迎页进入一局隔离演示，在 8–10 分钟内看完农场、农耕、对话立绘、建筑卡、溪岸集市、加工入口、设置和存读，而不碰到调试 HUD 或误覆盖正常存档。

Current context:
- N-015、N-001、D0-002 均为 `accepted / APPROVED`。
- N-016 为 `active / PENDING`，MUSIC_SELECTION 仍为 `PENDING_PRODUCT_OWNER_LISTEN`。
- N-012 为 `blocked / BLOCKED`，本任务不是复闸或桌面正式交付。
- 当前游戏启动后直接进入农场会话，ESC 打开设置，存档写入 `Application Support/CreekSprout` 的三个手动槽和自动槽。

Assumptions:
- 这是内部演示稳定化，不是正式发布。
- 继续使用现有 `SynthesizedAudioService` 程序化安全音频。
- 演示夹具可以是确定性的独立初始状态，但不得进入正式存档。

Department:
- 🧱 Engineering & Pipeline

Department quality owner:
- 🧱 `tech`

Specialist owner:
- 🎮 `gameplay`

Consulted:
- ✨ `ux`：欢迎页、暂停层、960×640 / 1280×800 可读性
- 🎧 `audio`：本轮不接入文件化音乐

Downstream reviewer:
- 🛡️ `quality`（Codex 独立只读复核）
- Product Owner：实机彩排，不得由执行者代签

In scope:
- 完整欢迎页、暂停层、操作说明与设置入口。
- 隔离演示会话：不覆盖三个手动槽或自动存档。
- 默认成品 HUD，调试层仅显式开启。
- 8–10 分钟可重复演示路线与 ≥12 分钟真实 App 连续运行证据。
- 960×640 可用、1280×800 推荐现场尺寸、窗口缩放与全屏后布局不变形。

Out of scope:
- 修改存档 schema、稳定 ID、地图拓扑、碰撞、NPC 站位、玩法、经济、配方、任务或对白。
- 修改生产 PNG / 高清立绘。
- 接入 N-014 猫店候选。
- 将 CC0 候选音乐接入正式资源或把 N-016 标为 accepted。
- 修改 `project.pbxproj`、覆盖现有桌面 App、生成正式发行包。
- 启动 N-012。

Inputs and dependencies:
- N-015、N-001、D0-002 必须为 `accepted / APPROVED`。
- DEC-036。
- 现有 `FarmScene` 公开玩法接口、`SaveSlotCatalog`、`SettingsState` 与 N-015 HUD。

Deliverables:
- 欢迎页 / 暂停层 / 演示会话 Swift 与聚焦测试。
- `artifacts/integration/n-017-demo/` 证据包与 `cursor-handoff.md`。
- 独立 DerivedData 演示构建，不覆盖既有桌面版本。

Acceptance criteria:
1. Given 启动 App，When 显示欢迎页，Then 可见《溪谷新芽》、农场/水渠/社区副标题、开始演示/继续游戏/设置/操作说明、本地单人说明，且键鼠均可操作。
2. Given 开始演示，When 写入或重置演示会话，Then 三个手动槽与自动槽内容不变，schema 与稳定 ID 不变。
3. Given 演示进行中，When 按 ESC，Then 打开暂停层：继续、设置、操作说明、重新开始演示、返回标题；重新开始前有确认。
4. Given 默认演示页面，When 不按 H，Then 不显示调试 HUD、内部 ID、坐标或「阻/石阶/采」占位。
5. Given 8–10 分钟路线，When 从欢迎页真实游玩，Then 可完成农场展示、收获三株、出售、翻土播种浇水、学徒立绘、建筑卡、集市交谈、集市建筑卡、木蜜灶台入口、设置、存读与返回标题或重开演示。
6. Given 960×640 与 1280×800，When 缩放或全屏后返回，Then 欢迎页与游戏页不严重裁切或重叠。
7. Given 完整 XCTest 与 ≥12 分钟真实 App，When 检查结果，Then 0 failed / 0 skipped，前后台恢复无崩溃。

Required evidence:
- 聚焦与完整 XCTest 原始日志 / xcresult。
- 真实窗口截图 10 类、drive-log、runtime-duration、存读前后 JSON 与比较。
- 构建清单、可执行文件 SHA-256、codesign 验证。
- 文件边界审计。

Required gates:
- 实现提交：🎮 gameplay，不得自签 🧱 / 🛡️
- 独立复核：Codex 🧱 tech 与 🛡️ quality
- 最终彩排：Product Owner

Originality check:
- 仅复用农场生活模拟的欢迎/暂停惯例。
- 标题、副标题、按钮与路线文案为本项目原创，不复制受保护的界面构图或文案。

Risks or open choices:
- `FarmScene` 将存档目录与时钟暂停封装为私有实现。若无法用现有公开接口隔离演示会话并遵守暂停规则，允许最小公开 API：可注入存档目录、替换会话状态、菜单暂停。不得改变领域规则。
- 完整地图突变 XCTest 耗时较长，同一最终代码只跑一次完整测试。

Intake gate:
- Gate status: `APPROVED` by Product Owner bounded authorization (DEC-036)
- Next gate: 🎮 gameplay implementation → Codex independent `APPROVED | REVISE | BLOCKED`
