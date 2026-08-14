# Studio task: M1-001 农耕闭环

Player outcome: 玩家可在原创占位农场中移动、选择工具、翻土、播种、浇水、睡眠推进作物并收获；所有关键状态可保存。

Current context: M0-001、M0-002、M0-003 已验收。当前项目仅有启动、内容验证、存档与设置基础设施，尚无农耕运行时。

Assumptions: M1 使用雾萝卜最小占位数据和原创几何表现验证循环；出售、制作、放置和水渠留给 M2/M3。

Department: 🧱 Engineering & Pipeline
Department quality owner: 🌱 Design & Player Experience（台账指定）
Specialist owner: 🎮 Gameplay Engineering
Consulted: 🧱 tech、🛡️ quality
Downstream reviewer: 🧱 tech 集成审阅，🛡️ quality 独立验证

In scope:

- 移动、工具目标格、互动式睡眠、时钟、暂停原因、体力、农田、作物、背包、HUD；
- M1 状态的存档映射、单元与集成层级的自动化测试；
- 原创且明确标注为占位的图形与内容资源。

Out of scope:

- 出售与货币结算、制作、放置、水渠、NPC/任务、社交事件、发行包与性能验收。

Inputs and dependencies:

- `M0-001`、`M0-002`、`M0-003`，均为 `accepted / APPROVED`；
- [PRD.md](PRD.md) 6.1–6.5、6.13、10；[TDD.md](TDD.md) 7.1–7.3、11、16、17。

Deliverables:

- 会话级领域服务、最小可玩农场场景、数据化雾萝卜占位内容、存档映射、M1 测试与验证记录。

Acceptance criteria:

- Given 一包种子与可达目标格，When 玩家依次翻土、播种、浇水并经过两次日结，Then 作物成熟且可收获到背包。
- Given 作物未浇水或体力不足，When 玩家日结或尝试劳动，Then 状态不产生违规成长或部分提交。
- Given 保存后读取，When 比较时间、体力、背包与农田，Then 状态保持一致。

Required evidence:

- 无头测试原始输出与退出码；启动检查；`git diff --check`；设计、技术和质量门禁结论。

Required gates:

- 🌱 design 玩家体验与可观察反馈审阅；
- 🧱 tech 架构、测试与存档安全审阅；
- 🛡️ quality 独立运行证据审阅。

Originality check:

- 使用网格农耕与日结这一类型功能；
- 所有名称、色彩、HUD 构图、占位画面和内容 ID 为《溪谷新芽》原创实现，不复刻任何现有游戏表达。

Risks or open choices:

- 已下载并验证官方 Godot 4.7.1 临时二进制的版本，但四种无头启动参数均在项目脚本解析前以 `SIGSEGV` 崩溃；运行时测试需在可稳定启动的环境复跑，不得把无运行证据当作通过。
