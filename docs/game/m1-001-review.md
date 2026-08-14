# M1-001 农耕闭环：专项提交与门禁记录

## 🎮 Gameplay Engineering 提交

Outcome:

- 提供数据化雾萝卜占位内容、会话级时钟/暂停原因、原子背包操作、农田动作与日结成长服务；
- 提供原创几何占位农场场景，支持八方向移动、工具切换、目标格反馈、翻土、播种、浇水、收获与小屋睡眠；
- 将 M1 农田字段、天气和背包容量加入向后兼容的存档映射；
- 新增 M1 农耕、缺水、体力回滚、满背包、存档往返和组合暂停测试。

Changed artifacts:

- `src/domain/`、`src/presentation/farm_slice.gd`、`scenes/farm/farm_slice.tscn`；
- `content/items/`、`content/crops/`；
- `src/core/game_session.gd`、`src/core/save_codec.gd`、`project.godot`；
- `tests/test_runner.gd`、`tests/unit/test_m1_farm_loop.gd`。

Validation evidence:

- `git diff --check`：退出 0；稳定 ID 与项目引擎/场景设置已静态复核；
- 官方 Godot 4.7.1 临时二进制 `--version`：输出 `4.7.1.stable.official.a13da4feb`；
- 以下四条测试启动命令均在执行 GDScript 前崩溃，退出信号为 `SIGSEGV (11)`，无测试通过/失败结果可用：
  - `Godot --headless --path . --script res://tests/test_runner.gd`
  - `Godot --headless --rendering-driver opengl3 --path . --script res://tests/test_runner.gd`
  - `Godot --headless --rendering-method gl_compatibility --path . --script res://tests/test_runner.gd`
  - `Godot --headless --display-driver headless --rendering-method gl_compatibility --path . --script res://tests/test_runner.gd`
- 崩溃回溯均在 Godot/MoltenVK 的 `mvk::SPIRVToMSLConverter`，未到项目脚本解析或测试运行阶段。
- 2026-08-10：以运行所需工程、场景、脚本和内容资源生成的临时 ZIP 通过完整性校验，并已在 Godot 4.7.1 Web Editor 的 `Preload project ZIP` 控件中选择；点击 `Start Godot Editor` 后，当前可控浏览器在进入 Godot 项目管理器前报告“HTML5 canvas appears to be unsupported”。外接 Chrome 控制连接不可用，因此未取得解包、GDScript、农耕路径或存读的运行证据。

Decisions and assumptions:

- M1 只使用最小原创占位数据与几何呈现；出售、制作、放置、水渠和 NPC 保持 M2/M3 范围；
- 存档新字段在读取旧存档时提供默认值，未提升 schema version。

Risks and follow-ups:

- 必须在能稳定启动 Godot 4.7.1 且支持 HTML5 Canvas 的环境重跑测试、无头启动和手动农耕烟雾路径；
- 在获得运行时证据前，不可将 M1-001 设为 `accepted`。

Requested department gate: 🌱 design / 🧱 tech / 🛡️ quality。

## 🌱 Design & Player Experience 交叉审阅

Gate status: APPROVED

Scope reviewed: 工具目标格、操作成功/失败反馈、移动、体力限制、睡眠日结、HUD 信息层级和原创占位表现。

Evidence inspected: M1 领域服务、场景脚本、任务简报、PRD 6.1–6.5 与静态差异检查。

Acceptance gaps: 运行时烟雾路径尚未执行；此项由技术与质量门禁阻断，非设计范围变更。

Conditions or required revisions: 保持 HUD 不遮挡农田，并在可运行环境中验证键鼠与手柄基础操作。

Next gate or escalation: 🧱 tech 需在可运行 Godot 环境中审查解析、测试、存档与服务边界。

## 🧱 Engineering & Pipeline 审阅

Gate status: BLOCKED

Scope reviewed: 领域/表现分层、事务边界、存档映射、测试接入与 Godot 4.7.1 启动证据。

Evidence inspected: 专项提交、`git diff --check`、四次 Godot 运行时崩溃回溯，以及 2026-08-10 的 Web Editor 启动前 Canvas 不支持结果。

Acceptance gaps: 当前环境中原生 Godot 在项目脚本执行前发生 `SIGSEGV`，网页编辑器又在项目管理器前因 Canvas 不支持停止；不能确认 GDScript 解析、测试或启动成功。

Conditions or required revisions: 在一个可稳定启动 Godot 4.7.1 的 macOS 环境复跑测试与启动；若出现项目解析/测试失败，按原始输出修复后重新提交。

Next gate or escalation: 🛡️ quality 在技术运行证据可用后执行独立复跑。

## 🛡️ Quality & Delivery 审阅

Gate status: BLOCKED

Scope reviewed: 自动测试、启动烟雾、保存读取和可玩闭环的独立证据。

Evidence inspected: 运行时命令与 `SIGSEGV` 回溯、Web Editor 的 Canvas 不支持结果；无项目测试输出。

Acceptance gaps: 无可复现的项目运行结果、无手动农耕烟雾记录；网页编辑器尚未进入项目管理器或游戏场景。

Conditions or required revisions: 取得成功的无头测试输出与一次手动路径证据：翻土 → 播种 → 浇水 → 两次睡眠 → 收获 → 保存/读取。

Next gate or escalation: 由 🧱 tech 解决/更换运行环境后重新交付质量门禁。
