# 《溪谷新芽》项目台账

> 版本：1.0  
> 建立日期：2026-07-27  
> 计划基线：[PRD.md](PRD.md) 0.4、[TDD.md](TDD.md) 0.4、12 周项目周期计划  
> 更新规则：使用 `project-ledger` skill；仅在验收证据与所需门禁齐备后将任务标记为 `accepted`。

## 状态与门禁

- 任务状态：`planned`、`active`、`revise`、`blocked`、`accepted`、`deferred`
- 门禁：`PENDING`、`APPROVED`、`REVISE`、`BLOCKED`、`N/A`
- 阶段完成条件：该阶段所有任务为 `accepted` 或经 Product Owner 明确批准为 `deferred`。

## 开发前依赖门禁

1. 开发前必须检查目标任务“依赖”列中的每个任务 ID，以及列出的外部决策或条件。
2. 所有任务依赖必须为 `accepted`；外部决策必须在决策记录中明确解决。缺失、`planned`、`active`、`revise`、`blocked` 或未获 PO 豁免的 `deferred` 均为未就绪。
3. 任一依赖未就绪时，不得开始实现、内容生产、配置、集成或下游交付；将目标任务标为 `blocked`、门禁设为 `BLOCKED`，并记录阻塞项、下一负责人和变更日志。
4. 只有 Product Owner 的明确豁免可允许有限的并行工作。豁免必须在决策记录中写明目标任务、阻塞依赖、允许范围和复核条件，再链接到任务证据列。

## 阶段总览

| 阶段 ID | 阶段 | 计划窗口 | 状态 | 退出门禁 | 依赖 |
|---|---|---|---|---|---|
| P0 | 预研 / 立项 | W1 | accepted | G0 技术锁定 | Product Owner 决策 |
| M0 | 技术骨架 | W2 | accepted | G1 空会话存读与离线启动 | P0 |
| M1–M2 | MVP / VS-0 | W3–W4 | planned | G2 首次出售 174 溪票 | M0 |
| M3 | 增量期 | W5–W7 | planned | G3 VS-1 Demo 路径可达 | M1–M2 |
| D0 | 内部 Demo / VS-1 | W8 | planned | Demo 评审 | M3 |
| M4 | 优化 / 稳定化 | W9–W10 | planned | G4 发行候选与性能达标 | D0 |
| A0 | 验收期 | W11 | planned | G5 验收签核 | M4 |
| R0 | 复盘 / 下轮规划 | W12 | planned | Product Owner 下轮方向确认 | A0 |

## 任务登记

| Task ID | 阶段 | 任务与交付物 | 专项负责人 / 质量负责人 | 依赖 | 验收要点 | 状态 | 门禁 | 证据 / 下一步 |
|---|---|---|---|---|---|---|---|---|
| P0-001 | P0 | 锁定 Godot 4.x 具体小版本；写入工程与构建说明 | 🎬 director / 🧱 tech | PO 引擎决策 | 版本、兼容渲染器与升级策略明确 | accepted | APPROVED | DEC-005；`project.godot`、`docs/game/build.md` 与 TDD 均锁定 4.7.1 / Compatibility；Godot 4.7.1 无头解析最小配置退出码 0；下一项 P0-002 |
| P0-002 | P0 | 确认 Windows x86-64、macOS arm64 参考设备与验收夹具策略 | 🎬 director / 🛡️ quality | P0-001 | 可执行的双平台性能与离线验收计划；两平台完整设备/可用方式，或经审计的获批替代基准 | accepted | APPROVED | DEC-010；Windows ThinkPad T480 与 macOS M4 MacBook Air 均为当前基线，设备/可用方式已确认；`platform-acceptance-plan.md`、`build.md`、PRD、TDD 与 `P0-002-prompt.md` 一致；文档合同检查与 `git diff --check` 通过；无运行结果；下一负责人 M0-001 的 🎮 gameplay / 🧱 tech |
| P0-003 | P0 | 建立项目台账技能与基线台账 | 🎬 director / 🛡️ quality | PRD、TDD、周期计划 | 技能强制在工作前读取、验收后以证据更新台账 | accepted | APPROVED | `quick_validate.py` 输出 `Skill is valid!`；已复查技能、台账与工作室调用点 |
| P0-004 | P0 | 为项目台账加入依赖未就绪的开发硬拦截 | 🎬 director / 🛡️ quality | P0-003、Product Owner 确认 | 依赖未 `accepted` 时停止开发并记录 `BLOCKED`；仅 PO 豁免可继续 | accepted | APPROVED | `quick_validate.py` 通过；M0-001 的 P0-001/P0-002 预检反例已复查 |
| P0-005 | P0 | 为项目台账加入“每日简报”：进度、下一项与阶段状态图 | 🎬 director / 🛡️ quality | P0-003、P0-004、Product Owner 确认 | 简报基于台账事实计算；不推荐未就绪任务；输出 Mermaid 阶段状态图 | accepted | APPROVED | `quick_validate.py` 通过；只读演练得出 2/19、11%、无可启动开发任务 |
| P0-006 | P0 | 将发行、性能与验收范围改为仅 macOS arm64，撤销未来 Windows x86-64 导出与测试要求 | 🎬 director / 🛡️ quality | P0-003、P0-004、DEC-012 | 活跃 PRD、TDD、构建说明、平台计划、验收脚本和导出预设仅要求 macOS arm64；历史记录保留但不构成未来 Windows 义务 | accepted | APPROVED | DEC-012；PRD/TDD 0.4、`build.md`、平台计划、归档 P0-002 Prompt、验证脚本和 `export_presets.cfg` 已同步。`sh docs/game/validate-platform-acceptance-plan.sh`、`git diff --check` 通过；macOS 导出退出 0（SHA-256 `cea8b91460fbcbb23a5fbfd5bb1d9200115a12b3cf340e8baab3f3bd67b59037`）；无头测试 19 run、0 failed。🎬 director、🧱 tech 与 🛡️ quality 均 `APPROVED`；下一负责人 M0-002 / M0-003。 |
| P0-007 | P0 | 锁定 Xcode + SpriteKit 替代运行端；完成迁移合同与最小 macOS 验证尖峰 | 🎬 director / 🧱 tech（🛡️ quality 独立复核） | P0-003、P0-004、DEC-013 | 原有玩法、数据 ID 与 macOS arm64 范围被保留；迁移边界、回归行为表和 Xcode 尖峰的构建/启动/输入/存读证据齐备；原 Godot 文件未被删除 | accepted | APPROVED | 🧱 tech `APPROVED`；🛡️ quality `APPROVED`。独立 QA 在 Xcode 26.6 / macOS 26.5.2 / arm64 重跑 Build 与 6 项 XCTest 均退出 0，并验证 10×6 网格、角色、顶部坐标、WASD/方向键逐格移动与边界约束。证据：`artifacts/qa/p0-007-independent/`。后续迁移任务 M1-002 已登记并重连直接下游依赖。 |
| M0-001 | M0 | 建立 Godot 工程、目录、Bootstrap、日志和双平台导出预设 | 🎮 gameplay / 🧱 tech | P0-001、P0-002 | 空工程按获批设备合同运行；DEC-007 下 Windows 实测在 M4-002 前恢复，未恢复不得发布 | accepted | APPROVED | Godot 4.7.1 已导出 macOS 包并在 M4 MacBook Air 的断网 `en0` 关闭状态启动；Bootstrap 日志、构建身份、SHA-256 与网络恢复记录已保存。macOS 包含 arm64（universal 模板同时含 x86_64，Info.plist 优先 arm64）；Windows 未执行，按 DEC-007 暂缓且不由 macOS 结果替代。🧱 tech 与 🛡️ quality 均 `APPROVED`；证据：`artifacts/acceptance/m0-001-bootstrap/macos-arm64/20260805T060126Z/`。下一负责人 M0-002 / M0-003。 |
| M0-002 | M0 | 实现内容定义、稳定 ID、ContentRegistry 与启动验证器 | 🛠️ tools / 🧱 tech | M0-001 | 错误引用阻止开发构建进入游戏 | accepted | APPROVED | 2026-08-06 依赖预检、任务级实现/夹具复核和无头验证通过：稳定 ID、只读注册表、全量校验、缺失引用/重复 ID/非法内容阻断均由 19 项无头测试覆盖。既有 🧱 tech 与 🛡️ quality `APPROVED` 见变更日志 2026-08-05；本次复跑仍通过。 |
| M0-003 | M0 | 实现 SaveCodec、一致快照、随机流、设置/输入与基础测试运行器 | 🎮 gameplay / 🧱 tech | M0-001 | 空会话新建、保存、读取通过；输入与设置安全回退 | accepted | APPROVED | 2026-08-06 依赖预检、任务级实现/夹具复核和无头验证通过：空会话存读、无效代拒绝、备份回退、稳定点排队、随机流续跑、输入保护与损坏设置回退均由 19 项无头测试覆盖。既有 🧱 tech 与 🛡️ quality `APPROVED` 见变更日志 2026-08-05；本次复跑仍通过。 |
| M0-004 | M0 | 建立独立候选想法 Backlog：记录、评估和受控采纳流程 | 🎬 director / 🛡️ quality | P0-003、P0-004、DEC-011 | 候选想法可追溯但不改变已批准路线图；只有完成影响评估并获 Product Owner 批准的条目才可派生任务或基线变更 | accepted | APPROVED | `docs/game/backlog.md`；预检通过；候选状态、跨部门评估与 Product Owner 采纳门禁检查通过；`git diff --check` 通过。下一负责人：🎬 director 在捕获想法时维护，R0-001 复盘时统筹评估。 |
| M1-001 | M1–M2 | 实现移动、交互、时间、体力、农田、作物、背包与 HUD（Godot 行为参考） | 🎮 gameplay / 🌱 design | M0-001、M0-002、M0-003 | 占位资源可完成翻土→播种→浇水→成长→收获 | blocked | BLOCKED | 🎮 实现已提交；🌱 design `APPROVED`。原生 Godot 与 Web Editor 均未产生运行时证据。DEC-013 后该实现冻结为行为参考，不再以 Godot 复跑作为解除条件，也不再作为 M2/M3 的下游依赖；Swift 替代任务为 M1-002。详见 `docs/game/m1-001-review.md`。 |
| M1-002 | M1–M2 | 在 Xcode + Swift + SpriteKit 中实现移动、目标格、时间、体力、农田、作物、背包、HUD 与扩展 JSON 存读 | 🎮 gameplay / 🧱 tech（🌱 design 咨询；🛡️ quality 独立复核） | P0-007、DEC-014 | 原创占位资源可完成翻土→播种→浇水→两次有效日结→收获→保存/读取；失败事务原子回滚；Swift Build/XCTest 与独立烟雾证据齐备 | active | REVISE | 2026-08-14 🧱 tech 独立复跑 19/19 XCTest 通过，但存档合同存在三项修订：合法的同物品多堆会被校验拒绝；农田坐标未限制到 10×6；扩展 JSON 缺少 `schema_version` 与迁移入口。修复并补回归测试前不得移交 Xcode。下一负责人：🎮 gameplay / Cursor。 |
| M2-001 | M1–M2 | 实现出售箱、日结、货币明细、制作、放置与经济调试报表 | 🎮 gameplay / 🧱 tech | M1-002、M0-003 | 无复制/重复结算/负货币/失败扣料；可收到 174 溪票 | planned | PENDING | — |
| M2-002 | M1–M2 | 制作 VS-0 场景、教学内容与 10–15 分钟烟雾路径 | ✨ ux / 🌱 design | M1-002、M2-001 | 新游戏→首次出售→存读→睡眠路径完整 | planned | PENDING | — |
| M3-001 | M3 | 制作两张原创地图、3 名职能角色、4 名邻居与基础对话内容 | 🗺️ world / 🎭 content | M1-002、M0-002 | 内容可达、原创、数据化且满足资产技术约束 | planned | PENDING | — |
| M3-002 | M3 | 实现主任务、采集、制作水渠接片、水脉 12+8 路径与地图/音频变体 | 🎮 gameplay / 🧱 tech | M2-001、M3-001 | 不依赖社交达到 20 点；重复执行幂等 | planned | PENDING | — |
| M3-003 | M3 | 实现社区事件五行动状态机、风评、信任定点计算与存档回放 | 🎮 gameplay / 🧱 tech | M3-001、M0-003 | 三条互斥夹具、边界恢复路径和主线不软锁 | planned | PENDING | — |
| D0-001 | D0 | 集成 VS-1 完整切片、替换关键占位表现并运行内部 Demo | 🧱 tech / 🛡️ quality | M3-001、M3-002、M3-003 | 45–60 分钟路径可玩；问题清单与试玩反馈已记录 | planned | PENDING | — |
| M4-001 | M4 | 完成性能、加载、内存、存档/设置失败恢复及无障碍优化 | 🎮 gameplay / 🧱 tech | D0-001 | 达到帧时间、加载、自动存档和内存预算 | planned | PENDING | — |
| M4-002 | M4 | 生成 macOS arm64 候选包，执行回归与离线烟雾 | 📦 release / 🛡️ quality | M4-001、P0-006 | macOS 安装、启动、输入、存读与 VS-0 路径有证据 | planned | PENDING | DEC-012；仅 macOS arm64 为当前发行与验收范围。 |
| A0-001 | A0 | 执行 PRD 第 10、11、14 节完整验收及签核建议 | 🧪 qa / 🛡️ quality | M4-002 | FR/NFR 追踪全绿，缺陷风险与已知问题明确 | planned | PENDING | — |
| R0-001 | R0 | 复盘试玩、经济模拟、缺陷与流程；形成下一增量 backlog | 🎬 director / 🛡️ quality（跨部门审阅） | A0-001 | 决策、度量、风险与下一优先级已记录 | planned | PENDING | — |

## 风险与依赖

| ID | 风险 / 依赖 | 影响任务 | 当前状态 | 缓解或下一步 | 负责人 |
|---|---|---|---|---|---|
| RSK-005 | 当前环境的原生 Godot 4.7.1 在无头启动时于 MoltenVK 初始化阶段 `SIGSEGV`；可控 Web Editor 浏览器又不支持 HTML5 Canvas，二者均早于项目 GDScript 解析与测试执行 | M1-001 验证 | open | 在可稳定启动 Godot 4.7.1 的 macOS 环境重新运行无头测试、启动检查和手动农耕烟雾；或在支持 SharedArrayBuffer 与 HTML5 Canvas 的桌面浏览器导入 ZIP 后完成同一路径。保留原始输出，勿将环境崩溃归因于项目代码 | 🧱 tech |
| RSK-006 | Xcode/SpriteKit 尖峰可能因本机工具链、项目模板或 macOS 权限而无法构建、启动、接收输入或完成本地存读 | P0-007 及后续 Swift 迁移 | resolved | P0-007 的独立 QA 已在 Xcode 26.6 / macOS 26.5.2 / arm64 取得 Build、6/6 XCTest、启动、网格、键盘移动、边界与 JSON 存读证据；后续功能仍须按任务验证，不将本尖峰结论外推为完整游戏通过 | 🧱 tech |
| DEP-001 | Godot 具体小版本未锁定 | P0–M4 | resolved | Product Owner 已锁定 Godot 4.7.1 标准版；升级遵循 `docs/game/build.md` | 🎬 director |
| DEP-002 | macOS arm64 参考设备与验收计划 | M4-001、M4-002、A0-001 | resolved | P0-006 已将活跃基线、导出预设与验收合同收敛到 M4 MacBook Air；历史 Windows 记录不再构成测试义务 | 🛡️ quality |
| RSK-001 | 存档、出售和跨服务事务的一致性 | M0-003、M2-001、M3-003 | open | 原子事务、回读验证、备份、幂等测试 | 🧱 tech |
| RSK-002 | 像素美术和邻居内容量失控 | M3-001、D0-001 | open | 先用占位资源；遵守角色与对白上限 | 🎭 content |
| RSK-003 | 社交状态影响主线可达性 | M3-003、A0-001 | open | 内容验证禁止主线 `min_standing`；执行边界夹具 | 🌱 design |
| RSK-004 | 本机 macOS 代码签名信任子系统无法完成本地 App 完整性评估 | 本机安装完整性复核 | open | 先恢复或诊断 macOS 的信任服务；当前 `codesign`/`spctl` 不能作为 Godot 篡改证据。Godot 仍锁定为官方标准版 4.7.1；不得通过移除隔离属性、临时重签名或升级版本掩盖主机诊断问题。 | 🧱 tech |

## 决策记录

| ID | 日期 | 决策 | 原因 / 影响 | 决策人 |
|---|---|---|---|---|
| DEC-001 | 2026-07-27 | 以 12 周小团队节奏为计划基线；单人开发需重新估期 | 当前周期计划按 W1–W12 组织；不改变 PRD/TDD 范围 | 🎬 director |
| DEC-002 | 2026-07-27 | 台账在 `docs/game/project-ledger.md` 维护，使用 Markdown 与稳定任务 ID | 可与 PRD/TDD 同库评审、版本控制和审计 | 🎬 director |
| DEC-003 | 2026-07-27 | 未就绪依赖默认阻止开发；并行或豁免仅限 Product Owner 明确批准 | 防止在不可验证的前提下提前实现并增加返工 | Product Owner |
| DEC-004 | 2026-07-27 | “每日简报”只读取台账；进度按非 `deferred` 任务中的 `accepted` 数计算 | 使日报可复现，且不因查询改变任务状态 | Product Owner |
| DEC-005 | 2026-07-30 | 锁定 Godot 4.7.1 标准版（非 .NET） | Product Owner 已安装并确认该版本；使用 2D Compatibility 渲染器，未经明确决策不得升级 | Product Owner |
| DEC-006 | 2026-07-30 | 将 2018 年以后 Windows 电脑列为补充兼容性覆盖范围，不替代既有性能基线 | Product Owner 已确认该兼容范围；PRD-NFR-001 的 i5-8250U / UHD 620 / 8 GB 低配性能门槛保持不变，仍须有原始或经审计等效设备 | Product Owner |
| DEC-007 | 2026-07-30 | 当前阶段暂不执行 Windows 实测 | 仅暂缓执行，不修订 Windows x86-64 发行目标或 NFR；Windows 设备/性能/离线验收必须在 M4-002 发行候选前完成。P0-002 与 M0-001 依赖关系不因此解除 | Product Owner |
| DEC-008 | 2026-07-30 | 批准 M0-001 仅在 macOS 上实施的有界例外 | 阻塞依赖：P0-002（双平台设备/验收未完成）。允许范围：M0-001 的 macOS 空工程、Bootstrap、输入、日志、场景和 macOS 导出/离线启动证据。到期/复核：M4-002 前恢复 Windows 验收；若 Windows 目标未恢复，禁止发布。不得将例外用于 P0-002 accepted 或 Windows 验收结论 | Product Owner |
| DEC-009 | 2026-08-04 | 确认 Windows 参考实机及补全 macOS 候选设备档案 | Windows：ThinkPad T480（Type 20L5）/ i5-8250U / UHD 620 / 8 GB / Windows 10 Pro 22H2 / 256 GB NVMe SSD / 60 Hz / 实验室实机；macOS：13 英寸 M4 MacBook Air / 16 GB / macOS 26.5.2 / 256 GB SSD / 60 Hz / 本机。Windows 与基线匹配；M4 仍不替代 M1/8 GB 性能基线 | Product Owner |
| DEC-010 | 2026-08-04 | 更新双平台性能基线并批准 P0-002 设备/夹具计划 | PRD/TDD 将 Windows T480 与 macOS M4 MacBook Air 设为当前基线；M1/8 GB/macOS 13 不再是验收前提。P0-002 的 `APPROVED` 仅覆盖设备与计划，不覆盖任何运行、性能、离线或烟雾结果；DEC-008 例外结束，DEC-007 的 Windows 实测恢复期限保持有效 | Product Owner |
| DEC-011 | 2026-08-05 | 建立独立候选想法 Backlog，不将记录行为视为路线图承诺 | Product Owner 要求可随时收集想法；候选不得改变范围、顺序、依赖或已批准交付。仅在正式影响评估与 Product Owner 明确批准后，才创建任务或修改 PRD/TDD/台账计划 | Product Owner |
| DEC-012 | 2026-08-05 | 发行范围改为仅 macOS arm64；撤销未来 Windows x86-64 导出、性能、离线与发布烟雾测试 | Product Owner 明确决定。P0-006 负责同步活跃 PRD、TDD、构建/平台验收文档、验证脚本与导出预设；既有双平台决策、设备档案与证据保留为历史记录，不构成未来交付或质量门禁 | Product Owner |
| DEC-013 | 2026-08-13 | 运行端由 Godot 4.7.1 切换为 Xcode + Swift + SpriteKit；Cursor 为主编码工具，Hermes 为任务整理与独立 QA 工具 | Product Owner 明确确认。DEC-005 的 Godot 锁定降为历史参考，不再是未来运行或验收前提；保留现有 Godot 项目、文档与测试作为行为迁移输入，不删除、不宣称已被 SpriteKit 验证。先完成 P0-007 尖峰与迁移合同，再重排 M0/M1 及下游依赖；macOS arm64 范围继续有效 | Product Owner |
| DEC-014 | 2026-08-13 | 将既有 M1 行为参考正式落账：M1 农耕四动作成功时各消耗 2 点体力，时钟为每现实秒 1.3 游戏分钟；M1-002 直接拥有所需 Swift 领域层与存档 schema 增量 | 这是对既有冻结行为的合同化，不新增玩法或扩大范围。PRD 的 2–5 点仍适用于后续砍伐、采掘等数据驱动劳动；M1-002 不依赖不存在的 Swift M0 等价任务，依赖 P0-007 后即可单独预检 | 🎬 director / 🌱 design |

## 变更日志

| 日期 | Task ID / 阶段 | 变更 | 证据 |
|---|---|---|---|
| 2026-08-14 | M1-002 / M1–M2 | Cursor 完成纯 Swift 领域、内容、持久化与 XCTest 交接；🧱 tech 对实际源码、事务、数据验证和存档安全独立复核为 `REVISE`，任务保持 `active`，暂停向 Xcode 跨部门交接。 | 沙箱外独立 `xcodebuild ... test` 退出 0，19/19 XCTest 通过，结果为 `/tmp/creeksprout-m1-002-tech-review-escalated/Logs/Test/Test-CreekSprout-2026.08.14_01-58-02--0700.xcresult`。需修复：`InventoryService.tryAdd` 可产生同 ID 多堆而 `SaveValidation` 拒绝；农田坐标只按 ±10000 校验而非 10×6；直接 Codable `GameState` 无 `schema_version`/迁移入口。下一负责人：🎮 gameplay / Cursor。 |
| 2026-08-13 | M1-002 / M1–M2 | Product Owner 明确授权启动；🎬 director 完成开发前依赖预检，任务由 `planned / PENDING` 改为 `active / PENDING`。M2/M3 任务、M1-001 历史状态和阶段总览均未改变，尚无实现或测试结论。 | P0-007 为 `accepted / APPROVED`；DEC-014 已记录；开工合同为 `docs/game/m1-002-brief.md`。下一负责人：🎮 gameplay / Cursor；随后须经 🧱 tech 和 🛡️ quality 明确门禁。 |
| 2026-08-13 | M1-002 / M1–M2 | 根据 Hermes 登记前 `REVISE` 完成合同修订：既有 M1 固定数值写入 PRD/TDD，M1-002 登记为 `planned / PENDING`，明确直接拥有 Swift 领域层与存档 schema 增量；M2-001、M2-002、M3-001 的直接依赖由 M1-001 重连至 M1-002。M1-001 保持历史 `blocked / BLOCKED`，M1–M2 阶段保持 `planned`。 | DEC-014；`docs/game/m1-002-brief.md`；`docs/game/PRD.md` 6.2/6.3；`docs/game/TDD.md` 7.1/7.2；`docs/game/xcode-spritekit-migration-brief.md` 状态修正。🎬 director 合同审查与 🌱 design 跨部门规则审查为 `APPROVED`；未开始功能开发、未运行或宣称 M1-002 测试通过。 |
| 2026-08-13 | P0-007 / P0 | 🛡️ quality 完成独立本机复核并签发 `APPROVED`；🧱 tech 既有 `APPROVED` 有效，任务改为 `accepted / APPROVED`。P0 的全部任务均已验收，阶段恢复 `accepted`。 | `artifacts/qa/p0-007-independent/QA-REPORT.md`、`build.log`、`test.log`、`window-initial.png`、`window-after-D.png`、`movement-verification.txt`。QA 独立执行 Build/Test 均退出 0，6/6 XCTest 通过；运行时验证网格、角色、坐标、WASD/方向键与边界通过；未改动代码或配置。 |
| 2026-08-13 | P0-007 / P0 | Cursor 完成领域层、持久化与 XCTest 修订；🧱 tech 对实际文件、工程 target 和用户提供的原始 Build/Test 记录审查为 `APPROVED`。任务改为 `active / PENDING`，等待 🛡️ quality 独立复核。 | 新增 `Domain/`、`Persistence/`、`CreekSproutTests/` 和共享 Scheme；`FarmScene` 读取 `GameState`，坐标标签移至 SwiftUI 顶部。Cursor 的 `xcodebuild` Build/Test 均退出 0，6 项 XCTest 通过；代码复查确认 App bundle ID 与 macOS 部署版本未改，且没有 Godot 文件改动。 |
| 2026-08-13 | P0-007 / P0 | Product Owner 在本机 Xcode 对 Cursor 的可视化尖峰完成部分烟雾：应用启动、10×6 网格可见，`D` 与 `A` 均使角色逐格移动。此为部分手工证据，不构成 🛡️ quality 的独立门禁。 | Product Owner 提供运行截图并确认“能够移动”。截图未显示坐标标签；无 XCTest、JSON 存读、损坏存档或 Hermes 独立复核证据，故保持 `active / REVISE`。 |
| 2026-08-13 | P0-007 / P0 | Cursor 提交最小 SpriteKit 呈现尖峰；🧱 tech 静态范围/架构审查为 `REVISE`，任务保持 `active / REVISE`，不得移交为质量通过。 | Product Owner 提供的 Cursor 运行记录报告 `xcodebuild` 退出 0、`BUILD SUCCEEDED`，并列明 `ContentView.swift`、`FarmScene.swift` 与 Xcode 工程；代码复查确认 10×6 网格、占位角色、WASD/方向键和坐标标签都只在 `macos/CreekSprout/`。无 XCTest Target 或 JSON 存读实现。Codex 隔离复建在 `#Preview` 宏的 `sandbox-exec: Operation not permitted` 停止，不能作为项目构建失败结论。 |
| 2026-08-13 | P0-007 / P0 | Hermes 完成第一轮只读行为追踪交接；未改动文件，未签发 `APPROVED`。任务保持 `active / PENDING`，Xcode 尖峰与独立 QA 仍是未满足门禁。 | Product Owner 转交 Hermes 报告：Cursor 必须对 12 行迁移矩阵逐项验收并保持参考数值（2 体力、1.3 分钟/秒、16 格、99 堆叠、`[1,1,1]` 成长）；🛡️ quality 只能采纳 Swift 自己生成的 XCTest 输出与截图，不得将 Godot 历史记录作为 SpriteKit 运行证据。 |
| 2026-08-13 | P0-007 / P0 | Product Owner 确认切换至 Xcode + Swift + SpriteKit；🎬 director 完成依赖预检并启动迁移合同与最小验证尖峰任务。P0 因运行端技术锁定重新开启；未删除 Godot 文件，未开始大规模源码迁移。 | P0-003、P0-004 均为 `accepted / APPROVED`；DEC-013；`docs/game/xcode-spritekit-migration-brief.md`。后续须取得 🧱 tech 的尖峰构建/启动/输入/存读证据及 🛡️ quality 独立复核。 |
| 2026-08-10 | M1-001 / M1–M2 | 🧪 qa 尝试以 Godot 4.7.1 Web Editor 运行当前项目；🧱 tech 作跨部门证据审阅，门禁维持 `BLOCKED`，未宣称项目运行。 | 运行所需工程/场景/脚本/内容资源的临时 ZIP 完整性校验通过；在 `Preload project ZIP` 控件选择后点击 `Start Godot Editor`，当前可控浏览器在项目管理器前提示不支持 HTML5 Canvas。外接 Chrome 控制连接不可用；无解包、GDScript、农耕或存读输出。 |
| 2026-08-09 | M1-001 / M1–M2 | 🎮 gameplay 提交 M1 农耕闭环；🌱 design 交叉审阅为 `APPROVED`。🧱 tech 与 🛡️ quality 均为 `BLOCKED`，任务改为 `blocked / BLOCKED`，未宣称验收完成。 | 新增领域服务、原创占位农场、数据资源、存档映射、M1 单元测试与 `m1-001-brief.md`/`m1-001-review.md`；`git diff --check` 退出 0。官方 4.7.1 二进制版本正常，但四种无头参数均在 `mvk::SPIRVToMSLConverter` 附近 `SIGSEGV`，无 GDScript 解析或测试结果。 |
| 2026-08-09 | M1-001 / M1–M2 | Product Owner 授权启动；🎮 gameplay 完成开工前依赖预检，任务由 `planned / PENDING` 改为 `active / PENDING`。 | M0-001、M0-002、M0-003 均为 `accepted / APPROVED`；范围：移动、交互、时钟、体力、农田/作物、背包、HUD、存档映射与自动化测试；明确不进入 M2 出售、制作与放置。 |
| 2026-08-06 | M0-002 / M0-003 / M0 | 🎬 director 完成台账一致性核对；引用既有 🧱 tech `APPROVED` 与 🛡️ quality `APPROVED`，并以任务级复跑证据将 M0-002、M0-003 改为 `accepted / APPROVED`。M0-001 至 M0-004 现均为 `accepted`，M0 阶段改为 `accepted`。 | 依赖 M0-001 为 `accepted / APPROVED`；`/Users/fengyifan/Downloads/Godot.app/Contents/MacOS/Godot --version` 为 `4.7.1.stable.official.a13da4feb`；无头测试输出 `19 run, 0 failed`（涵盖内容校验、SaveCodec、设置、备份回退与随机流）；`--headless --path . --quit-after 10` 输出 Bootstrap startup/ready；`git diff --check` 通过。既有独立门禁见 2026-08-05 M0-002/M0-003 日志。 |
| 2026-08-05 | M0-002 / M0-003 | Product Owner 确认 Godot 来自官网下载后，🛠️ tools 重新检测并修正 RSK-004：当前主机的代码签名信任子系统异常，不能将先前 Godot 的 `codesign` 失败解释为 App 被修改。项目运行/测试结论不变。 | Godot 仍报告 `4.7.1.stable.official.a13da4feb`、Universal x86_64/arm64，且包含 stapled notarization ticket；其 Safari quarantine 来源属性存在。`codesign` 对 Godot 的 arm64 报失效，但同一命令对 `/System/Applications/Calculator.app` 的 arm64e 报 `CSSMERR_TP_NOT_TRUSTED`，`spctl --assess` 对两者均报 `internal error in Code Signing subsystem`。故本机签名检查为 `BLOCKED`，不是 Godot 完整性失败结论；未改动 App。 |
| 2026-08-05 | M0-002 / M0-003 | 🛠️ tools 使用完整 Godot 路径复核测试与 Bootstrap；两任务维持 `active / PENDING`，未标记为 `accepted`。🧱 tech 对项目测试阻断的审查为 `APPROVED`；🛡️ quality 的独立运行复核为 `APPROVED`。当时记录的 Godot 签名失败为初步观察，已由其后的同主机对照检测修正为 RSK-004 的本机信任服务阻断。 | `/Users/fengyifan/Downloads/Godot.app/Contents/MacOS/Godot --version` 输出 `4.7.1.stable.official.a13da4feb`；指定无头测试命令退出 0，`19 run, 0 failed`；`--headless --path . --quit-after 10` 输出 Bootstrap startup/ready、`git diff --check` 退出 0。初次 `codesign --verify --deep --strict --verbose=4` 对 Godot 退出 1；后续对 Apple Calculator.app 的同类失败证明其不能单独推导 Godot App 被修改；未对 App 的隔离属性、签名或版本做修改。 |
| 2026-08-05 | P0-006 / P0 | 🎬 director、🧱 tech 与 🛡️ quality 复核均为 `APPROVED`；macOS-only 平台范围变更已验收，P0 恢复 `accepted`。 | PRD/TDD 0.4、构建/平台验收合同、归档提示、macOS 唯一导出预设与验证脚本一致；合同脚本和 `git diff --check` 通过；Godot macOS 导出退出 0（SHA-256 `cea8b91460fbcbb23a5fbfd5bb1d9200115a12b3cf340e8baab3f3bd67b59037`）；无头测试 19 run、0 failed。 |
| 2026-08-05 | P0-006 / P0 | Product Owner 将发行范围改为仅 macOS arm64；🎬 director 启动文档与导出预设收敛任务。 | 依赖预检：P0-003、P0-004 均为 `accepted / APPROVED`；DEC-012 记录明确的范围变更；待 🧱 tech 配置审查与 🛡️ quality 独立复核。 |
| 2026-08-05 | M0-002 / M0-003 | 修复 Godot 项目测试入口的类型推断错误，并使 SaveCodec 将 JSON 解析出的整值安全还原为 `int`；两任务保持 `active / PENDING`，不自行批准。 | `/Users/fengyifan/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`：19 run、0 failed、退出 0；`--headless --path . --quit-after 10`：Bootstrap 启动/ready、退出 0；`git diff --check` 退出 0。 |
| 2026-08-05 | M0-002 | 🛠️ tools 已向 🧱 tech 提交实现与验证材料，请求技术审查；不自行批准，任务保持 `active / PENDING`。 | 审查范围：`src/content/` 的结构/索引/验证边界、`src/core/bootstrap.gd` 的故障分流、`.tres` 夹具及 `tests/test_runner.gd` 接入。实际无头命令仍因本机无 `godot` 退出 127；🛡️ quality 独立复核须在可运行的测试证据后进行。 |
| 2026-08-05 | M0-002 | 🛠️ tools 已提交内容 Resource 定义、稳定 ID、只读 ContentRegistry、聚合 ContentValidator、Bootstrap 故障状态与 `.tres` 无头夹具；任务保持 `active / PENDING`，等待 🧱 tech 审查。 | 新增 `src/content/`、`tests/unit/test_content_registry.gd`、`tests/fixtures/content_*`、`docs/game/content-authoring.md`；更新 `src/core/bootstrap.gd`、`tests/test_runner.gd`。`git diff --check` 退出 0；`godot --headless --path . --script res://tests/test_runner.gd` 退出 127，原始输出 `command not found: godot`，无运行时解析/测试结论。 |
| 2026-08-05 | M0-002 | 🛠️ tools 开工前依赖预检通过，任务由 `planned / PENDING` 更新为 `active / PENDING`。 | M0-001 已为 `accepted / APPROVED`；范围为 Godot Resource 内容定义、稳定 ID、ContentRegistry、启动验证器、Bootstrap 接入及无头测试；后续须经 🧱 tech 审查与 🛡️ quality 独立复核。 |
| 2026-08-05 | M0-001 | Product Owner 已解决 Godot 4.7.1 macOS 导出模板；🎮 导出 macOS 包并在 Wi-Fi 关闭时启动通过。🧱 tech 与 🛡️ quality 复核均为 `APPROVED`，任务改为 `accepted`；M0 阶段仍因 M0-002/M0-003 未完成保持 `active`。 | `artifacts/acceptance/m0-001-bootstrap/macos-arm64/20260805T060126Z/`；macOS release export 与离线 Bootstrap 均退出 0；`git diff --check` 退出 0；Windows 仍按 DEC-007 暂缓。 |
| 2026-08-05 | M0-003 | 🎮 gameplay 开工前依赖预检通过，任务由 `planned / PENDING` 更新为 `active / PENDING`。 | M0-001 已为 `accepted / APPROVED`；范围为存档、设置、输入绑定、随机流与基础无头测试；后续须经 🧱 tech 与 🛡️ quality 门禁。 |
| 2026-08-05 | M0-003 | 🎮 gameplay 完成存档/设置/随机流与基础测试实现，任务保持 `active / PENDING`。 | 新增 `src/core/` 的领域、DTO、Codec、协调器、随机流及设置脚本；新增 `tests/test_runner.gd`、`tests/unit/`、`tests/integration/`。无头命令 `godot --headless --path . --script res://tests/test_runner.gd` 退出 127：`command not found`；常规 `git diff --check` 退出 0。因无 Godot 4.7.1 可执行文件，未声称解析、测试、🧱 tech 或 🛡️ quality 门禁通过。 |
| 2026-08-05 | M0-001 | 复核发现本机 Godot 4.7.1；🎮 重跑无头与 macOS 实机断网 Bootstrap 均通过，修正 arm64 所需 ETC2/ASTC 导入配置。🧱 tech 与 🛡️ quality 复核保持 `BLOCKED`，唯一 macOS 导出缺口为 `macos.zip` 模板；Windows 仍按 DEC-007 暂缓。 | `logs/godot-headless-20260805T053821Z.txt`、`logs/godot-offline-start-20260805T054700Z.txt`、`logs/godot-export-macos-arm64-20260805T054803Z.txt`、`offline/network-disabled.txt`、`git diff --check` 退出 0 |
| 2026-08-05 | M0-001 | 🎮 提交空工程骨架；🧱 tech 审阅为 `BLOCKED`，🛡️ quality 独立证据复核为 `BLOCKED`。任务保持 `active`，不宣称运行、导出、Windows、VS-0、存读或性能通过。 | `project.godot`、`export_presets.cfg`、`scenes/bootstrap/bootstrap.tscn`、`src/core/`、`artifacts/acceptance/m0-001-bootstrap/macos-arm64/20260805T045336Z/`；`godot --headless ...` 退出 127；网络状态无法确认；`git diff --check` 退出 0 |
| 2026-07-27 | P0-003 | 建立项目台账基线；状态设为 `active` | 本台账、`skills/project-ledger/`、`skills/cozy-farm-game-studio/SKILL.md` |
| 2026-07-27 | P0-003 | 🎬 实施提交、🛡️ 质量审阅均为 `APPROVED`；任务改为 `accepted` | `quick_validate.py` 通过；`git diff --check` 通过；工作流与任务登记已逐项复查 |
| 2026-07-27 | P0-004 | 建立依赖硬拦截规则；状态设为 `active` | Product Owner 确认；待修改、校验与质量审阅 |
| 2026-07-27 | P0-004 | 🎬 实施提交、🛡️ 质量审阅均为 `APPROVED`；任务改为 `accepted` | `quick_validate.py` 通过；依赖失败与许可路径均已审查 |
| 2026-07-27 | P0-005 | 建立每日简报能力；状态设为 `active` | Product Owner 确认；待修改、校验与质量审阅 |
| 2026-07-27 | P0-005 | 🎬 实施提交、🛡️ 质量审阅均为 `APPROVED`；任务改为 `accepted` | `quick_validate.py` 通过；进度、无就绪任务与阶段状态图路径已只读演练 |
| 2026-07-30 | P0-001 | Product Owner 确认 Godot 4.7.1 标准版；任务改为 `active` | DEC-005；待最小工程配置、构建说明与 🧱 tech 门禁 |
| 2026-07-30 | P0-001 | 🎬 director 提交、🧱 tech 审阅均为 `APPROVED`；任务改为 `accepted` | `project.godot`、`docs/game/build.md`、TDD 版本/渲染器一致；Godot 4.7.1 无头解析最小配置退出码 0；`git diff --check` 通过 |
| 2026-07-30 | P0-002 | 🎬 director 建立双平台验收计划；🛡️ quality 独立审阅为 `BLOCKED`，任务改为 `blocked` | P0-001 为 `accepted / APPROVED`；计划覆盖设备档案、替代基准、指标、断网、证据和 M0/VS-0/M4 分层；未提供任一平台完整设备档案、可用方式或获审计替代基准，故无质量 `APPROVED`、不得 accepted |
| 2026-07-30 | P0-002 | Product Owner 补充 macOS 测试候选的部分档案；维持 `blocked / BLOCKED` | MacBook Air / Apple M4 / 16 GB / macOS 26.5.2；其性能高于 M1/8 GB 基线，不能替代低配性能验收；仍待其存储、刷新率、可用方式与等效证据，且 Windows 档案尚未提供 |
| 2026-07-30 | P0-002 | Product Owner 确认 Windows 2018 年后设备兼容范围；维持 `blocked / BLOCKED` | 已作为补充功能兼容覆盖记录；年份不能替代 CPU/GPU/内存/系统/刷新率档案或低配性能等效证据，Windows 实际测试机仍待确认 |
| 2026-07-30 | P0-002 | 从当前本机采集 macOS 候选的非敏感硬件档案；维持 `blocked / BLOCKED` | 13 英寸 MacBook Air（M4，10 核 CPU/8 核 GPU，16 GB，macOS 26.5.2，内置 SSD）；未采集内屏刷新率，且高于 M1/8 GB 基线，仍缺低配等效性能证据和 Windows 实机档案 |
| 2026-07-30 | P0-002 | Product Owner 暂缓 Windows 实测；维持 `blocked / BLOCKED` | DEC-007；Windows 仍为发行目标且无实测结果，P0-002 不得 accepted，M0-001 依赖未解除；若需 macOS-only 例外，须另行记录限定范围与复核条件 |
| 2026-07-30 | M0-001 / M0 | Product Owner 批准 DEC-008 有界 macOS 例外；M0-001 改为 `active`，M0 改为 `active` | 仅允许 M0-001 的 macOS 实施与证据；P0-002 保持 `blocked / BLOCKED`。Windows 验收必须在 M4-002 前恢复，否则不得发布；下一负责人 🎮 gameplay / 🧱 tech |
| 2026-07-30 | P0-002 | 🎬 director 复核计划与构建入口，🛡️ quality 独立复审维持 `BLOCKED` | `validate-platform-acceptance-plan.sh` 通过、`git diff --check` 通过；已纠正 DEC-008 与 P0-002 正常门禁的说明一致性。Windows 完整参考设备/可用方式/等效证据缺失；macOS M4/16 GB 候选缺显示刷新率且不等效 M1/8 GB 基线；未创建或验证任何 M0/VS-0/发行夹具 |
| 2026-07-30 | P0-002 | 🛡️ quality 独立审阅维持 `BLOCKED`；任务保持 `blocked / BLOCKED` | P0-001 为 `accepted / APPROVED`；`sh docs/game/validate-platform-acceptance-plan.sh` 与 `git diff --check` 通过。Windows 仍缺完整设备、可用方式及低配等效证据；macOS M4/16 GB 候选仍缺刷新率和可审计的 M1/8 GB 等效证据；未将任何未实现夹具或运行结果误记为通过 |
| 2026-08-04 | P0-002 | Product Owner 确认 Windows 参考实机并补全 macOS 候选 SSD/刷新率；🛡️ quality 复审维持 `BLOCKED` | DEC-009；Windows T480 档案匹配基线，但尚未测试。macOS M4/16 GB/macOS 26.5.2 是高性能替代候选，仍缺 M1/8 GB/macOS 13 等效性能证据；无安装、离线、性能或烟雾结果，故不得 accepted |
| 2026-08-04 | P0-002 / P0 | Product Owner 更新性能基线；🎬 director 提交、🛡️ quality 独立审阅均为 `APPROVED`，P0-002 改为 `accepted`，P0 改为 `accepted` | DEC-010；PRD、TDD、构建入口、双平台验收计划和再执行 Prompt 一致。`sh docs/game/validate-platform-acceptance-plan.sh` 与 `git diff --check` 通过；本次仅批准设备/计划，未声称任何运行夹具通过 |
| 2026-08-05 | P0-002 | 按再执行 Prompt 复核已批准设备与验收夹具合同；🎬 director 提交、🛡️ quality 独立复核均为 `APPROVED`，任务保持 `accepted` | `sh docs/game/validate-platform-acceptance-plan.sh` 输出 PASS；`git diff --check` 通过。ThinkPad T480 与 M4 MacBook Air 仍为基线；M0、VS-0、M4 夹具均未实现、未运行，未创建候选构建或运行证据。DEC-007 仍要求 Windows 实测在 M4-002 前恢复，未恢复不得发布 |
| 2026-08-05 | M0-004 | 🎬 director 启动独立候选想法 Backlog 治理任务 | 预检通过：P0-003、P0-004 均为 `accepted / APPROVED`，DEC-011 记录了 Product Owner 的范围约束；待建立文档、执行质量复核。 |
| 2026-08-05 | M0-004 | 🎬 director 提交、🛡️ quality 独立复核均为 `APPROVED`；任务改为 `accepted` | 新增 `docs/game/backlog.md`，包含稳定想法 ID、捕获字段、候选状态、跨部门评估、Product Owner 采纳门禁与正反例；候选条目不改变路线图。文档结构检查和 `git diff --check` 通过。 |
