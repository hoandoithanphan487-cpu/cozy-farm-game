# Studio task: N-011 首个高清建筑/场景展示样板

Player outcome:
- 玩家在真实可玩页面中看到一栋清晰、原创、高清的建筑展示图或场景背景样板，同时仍能使用原入口、碰撞、交互与地图移动逻辑。展示图是 presentation 层，不是碰撞图、地图拓扑或新的可达区域。

Current context:
- N-013 R2 五栋高清建筑展示图已 `accepted / APPROVED`，可作为只读输入。
- N-010 立绘运行时渲染层已按 DEC-030 完成并为 `accepted / APPROVED`；N-011 仍须重新执行开工预检，历史 `blocked / BLOCKED` 不自动解除。
- 2026-08-21 🎨 art 开工硬依赖预检失败，形成历史 `blocked / BLOCKED`。2026-08-22 🧱 tech 重新核对 N-010/N-013 与边界后，仅将任务登记为 `active / PENDING`；本 brief 不授权超出 N-011 范围的接入。

Assumptions:
- 无 Product Owner 豁免允许 N-011 在 N-010 未验收时并行接入。
- 现有 `ConceptArtCatalog` 仅映射 N-007 概念角色图，不构成建筑展示层，也不构成 N-010 完成证据。

Department:
- 🎭 World & Content

Department quality owner:
- 🎭 `content`

Specialist owner:
- 🎨 `art`

Consulted:
- 🧱 `tech`（展示层文件边界与运行时接入）
- 🌱 `design`（入口/交互不被遮挡）

Downstream reviewer:
- 🛡️ `quality` / Hermes
- Product Owner（样板视觉验收）

In scope (only after N-010 = accepted / APPROVED):
- 从 N-013 已批准的五栋中只选一栋作为样板。
- N-011 专属 brief、展示资源清单、隔离 presentation 资源。
- 与样板显示直接相关的展示层文件，且须由 Codex 确认边界。
- `artifacts/integration/n-011-building-sample/` 证据、截图与 manifest。

Out of scope:
- Domain、存档、经济、ContentID、WorldCatalog、地图拓扑、碰撞、NPC 行为。
- N-013 已批准原图与历史证据。
- 其余四栋建筑的运行时接入。
- 把概念图放大冒充高清，或把建筑图直接用作碰撞/导航。
- 在 N-010 未验收前进行任何接入、复制或选型落地。

Inputs and dependencies:
- N-010 = `accepted / APPROVED`（硬依赖，当前已满足；仍需重新执行本任务预检）
- N-013 = `accepted / APPROVED`（已满足；R2 证据见 `artifacts/integration/n-013-buildings/r2-hd-presentation/`）
- `docs/game/art-style-master-doc.md` §1.4 / §2.1 双层美术合同
- DEC-027、DEC-028

Deliverables (deferred until preflight passes):
- 选型与一致性说明
- 透明源文件映射、资源 manifest、尺寸/Alpha/SHA-256 检查
- 运行时样板截图与截图说明
- `artifacts/integration/n-011-building-sample/art-handoff.md`
- 🎭 content 原创性与世界一致性审查请求

Acceptance criteria:
- Given N-010 未 `accepted / APPROVED`，When 🎨 art 执行开工预检，Then 任务必须 `BLOCKED`，不得接入建筑样板。
- Given N-010 已验收且选定一栋 N-013 建筑，When 玩家进入真实可玩页面，Then 高清展示图可见、不遮挡关键交互与 HUD、窗口缩放不变形。
- Given 展示层已接入，When 玩家使用既有入口，Then 进入/交互/碰撞边界与接入前一致。
- Given 源 PNG，When 检查，Then 沿用已批准轮廓/入口/屋顶/地基/功能锚点；透明背景、完整入画、不触边、无人物/文字/Logo/水印/棋盘格。

Required evidence:
- 依赖预检记录、文件边界审计。
- 预检通过后：透明源映射、运行时截图、manifest、哈希/Alpha/尺寸输出。

Required gates:
- 开工前依赖预检（2026-08-22 重开结果：`active / PENDING`；不等同于 `APPROVED`）
- 预检通过后：🎭 content → 🧱 tech 接入边界确认 → 🛡️ quality / Hermes → Product Owner 视觉验收

Originality check:
- 熟悉用途仅限“建筑介绍/场景锚点展示”。
- 表达必须复用 N-013 已批准内部设计，不得新增建筑设定或外部受保护表达。

Risks or open choices:
- 在 N-010 未提供可复用的 HD Presentation 运行时容器前，建筑样板没有合法接入点。
- 解阻后建议优先木构农舍（N-013 批次风格锚点、农场默认可玩页），但不得在本轮落地选型。

Intake gate:
- Historical gate status: `BLOCKED` (2026-08-21)
- Current preflight gate status: `PENDING` (2026-08-22; task ledger status `active`)
- Historical upstream blocker: N-010 was `planned / PENDING`; current ledger evidence is `accepted / APPROVED`
