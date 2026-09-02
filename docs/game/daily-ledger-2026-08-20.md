# 《溪谷新芽》每日台账 — 2026-08-20

> Product Owner：用户
> 项目根目录：`/Users/fengyifan/Documents/VibeCoding`
> 状态来源：`docs/game/project-ledger.md`（只读核对）

## 1. 今日总览

- 任务总数：30
- 排除 deferred 后：29
- 已验收：27
- 活跃：2（N-003、N-006）
- 进度：`[█████████░] 93%`（27/29，四舍五入）
- 当前阶段：N1 下一轮·表现层（active）
- 今日目标：完成 N-003 / N-006 的资产线独立交接与 Product Owner 目检准备；不新增玩法范围。

## 2. 当前门禁与阻塞

| 任务 | 当前状态 | 今日动作 | 通过条件 | 下一负责人 |
|---|---|---|---|---|
| N-003 | `active / PENDING` | PO 确认场景锚点与首轮生产顺序；随后由 Cursor 做受限实现/接入 | PO 视觉决策 → 🎭 content `APPROVED` → 🧱 tech / 🛡️ quality 终验 | Product Owner → Cursor |
| N-006 | `active / PENDING` | PO 对 131 张正式 PNG + 18 张候选 PNG 做整包目检；Hermes 可独立复核技术证据 | PO 视觉整包确认 + 技术证据无阻断 → 🎬 director 登记验收 | Product Owner → Codex |
| RSK-007 | `open` | 暂不插入今日资产线；保留发布前必补 | 正式发布前断网安装、启动、输入、存读、VS-0 烟雾全绿 | release / quality |

## 3. 三方执行分工

### Cursor — N-003 资产线受限执行

职责：在 Product Owner 已确认首轮顺序后，负责 N-003 的像素资产生产/接入；未确认时只做预检，不得擅自开始。

```text
你是《溪谷新芽》的 🎨 art / 🧱 tech 执行专员，任务是 N-003 像素资产管线试点。

先读取：
- AGENTS.md
- skills/cozy-farm-game-studio/SKILL.md
- skills/cozy-farm-game-studio/references/roles.md
- skills/cozy-farm-game-studio/references/production-workflow.md
- skills/building-art-style-generation/SKILL.md
- docs/game/project-ledger.md
- docs/game/n-003-brief.md
- docs/game/art-style-master-doc.md
- docs/game/n-003-character-roster.md

开工前硬门禁：
1. 检查 Product Owner 是否已明确批准 N-003 的场景锚点与首轮顺序。若没有，返回 BLOCKED，说明缺少的 PO 决策并停止，不生成、不接入、不改台账。
2. 依赖 N-001、DEC-021、DEC-020、N-003 管线部分的既有 APPROVED 证据必须保持有效。
3. 专员不得自我批准；你的输出只能请求 🎭 content 或 🧱 tech 的门禁。

若门禁通过，仅处理 PO 指定的首轮资产，严格遵守：
- 角色 32×48、作物 32×32、地块 24×24 及 Master Doc §9 的命名/锚点/状态约束；
- 原生尺寸逐像素重绘，不把 C0 概念图直接缩放为运行时资产；
- 不改玩法、内容 ID、经济、存档 schema、PRD/TDD、Audio 或 N-004；
- 不触碰与本任务无关的 Assets；所有生成记录、尺寸、Alpha、色票、1×/4×验证证据落盘到 N-003 约定目录；
- 运行时接入前必须保留原程序化兜底，并验证最近邻/整数缩放/NFR-007。

执行验证：git diff --check；资产尺寸/Alpha/色票检查；N-003 专用测试；必要的轻量运行时截图。

最终只按以下格式返回：
Outcome:
Changed artifacts:
Validation evidence:
Decisions and assumptions:
Risks and follow-ups:
Requested department gate: APPROVED | REVISE | BLOCKED
不得把自己的执行结果写成 APPROVED；只提出门禁请求。
```

### Hermes — N-006 独立质量/技术复核

职责：只读独立复核 N-006 已交付资产包，不改源码、资产、台账，不把技术通过冒充 Product Owner 的视觉终验。

```text
你是《溪谷新芽》的 🛡️ quality 独立复核员，复核任务 N-006 全量运行时像素资产生产。

只读读取：
- AGENTS.md
- skills/cozy-farm-game-studio/SKILL.md
- skills/cozy-farm-game-studio/references/roles.md
- docs/game/project-ledger.md
- docs/game/n-006-runtime-art-batch-brief.md
- docs/game/art-style-master-doc.md §9.2–§9.7
- artifacts/integration/n-006-runtime-art/hermes-review.md
- artifacts/integration/n-006-runtime-art/test-output.txt
- artifacts/integration/n-006-runtime-art/file-boundary-audit.txt
- artifacts/art-style/runtime-batch-r0/

禁止：修改任何文件；修改台账状态；生成或替换 PNG；替 Product Owner 签署整包视觉目检。

独立复核以下证据：
1. 正式运行时包 131 张、世界生机候选包 18 张是否分目录且无混入；
2. 文件名/尺寸/状态/方向、RGBA、透明像素 RGB 清零、色票、无抗锯齿/软边/渐变；
3. 角色 32×48 / R1 128×192、作物 32×32、地块 3×3、水体连续帧、五栋建筑六层结构；
4. manifest SHA-256、1×/4×联系表、生成记录和原创性记录是否可追溯；
5. clean test、像素审计、应用包资源清单、文件边界和 git diff --check；
6. 明确区分“技术 APPROVED”与“PO 视觉 APPROVED”；不要把后者推断出来。

逐项给出 PASS/FAIL/NOT RUN 和证据路径；若发现缺口，给出最小返工项。

最终返回：
Gate status: APPROVED | REVISE | BLOCKED
Scope reviewed:
Evidence inspected:
Acceptance gaps:
Conditions or required revisions:
PO visual decision still required: YES | NO
Next gate or escalation:
```

### Codex — 导演整合、每日台账与门禁登记

职责：读取真实仓库证据，执行依赖预检、整合 Cursor/Hermes 交接，并在所有必要门禁齐备后更新正式台账。

```text
你是《溪谷新芽》的 🎬 director，同时承担跨部门整合；用户是 Product Owner。

先完整读取：
- AGENTS.md
- skills/project-ledger/SKILL.md
- skills/cozy-farm-game-studio/SKILL.md 及其 roles.md、production-workflow.md、genre-blueprint.md
- docs/game/project-ledger.md
- docs/game/daily-ledger-2026-08-20.md
- 本轮 Cursor handoff 与 Hermes 独立报告（若不存在，明确记为缺失）

执行顺序：
1. 只以仓库现状做依赖预检；不要根据聊天内容猜测完成状态。
2. 核对 N-003、N-006 的 changed artifacts、原始命令、退出码、截图/报告、哈希和边界证据。
3. N-003 必须有 🎭 content 或 🧱 tech 的明确 APPROVED；N-006 必须同时具备技术门禁 APPROVED 与 Product Owner 整包视觉确认。缺一项就保持 active / PENDING 或改为 REVISE/BLOCKED，不得 accepted。
4. Hermes 的 APPROVED 只能作为独立质量/技术证据；不能替代 PO 视觉决定，也不能由执行专员自我批准。
5. 只有在门禁和验收证据齐全后，使用 apply_patch 更新 docs/game/project-ledger.md：仅更新对应任务行和一条变更日志；保留历史事实，不重写旧记录。
6. 不修改 Swift/Godot/Assets/Audio/PRD/TDD，除非本轮已有明确授权且任务合同允许。
7. 复核 git diff --check，并重新读取被修改的任务行与变更日志。

最终返回：
- 每日状态：任务计数、进度、当前阶段、开放风险
- N-003：status / gate / evidence / next owner
- N-006：status / gate / evidence / next owner
- 台账是否更新及具体章节
- 未满足门禁与 Product Owner 需要决定的事项
- 下一工作日唯一推荐任务
```

## 4. Product Owner 今日确认项

1. N-003 场景锚点：候选 A「木蜜溪谷」70% + B「典雅水工镇」30% 是否升格为正式美术锚点。
2. N-003 首轮顺序：是否从 `char_player` C0 开始，随后按角色、作物、地块推进。
3. N-006：131 张正式 PNG 与 18 张候选 PNG 是否整包视觉验收通过；候选包不进入正式 `Assets/`。
4. RSK-007：继续按 DEC-018 延后到正式发布前，还是安排本日补跑离线烟雾。

## 5. 今日完成定义

- Cursor：只在 PO 决策存在时生产；否则明确 BLOCKED。
- Hermes：产出独立、可复核的 N-006 门禁报告，不修改任何文件。
- Codex：只有在证据与门禁齐全时更新正式台账；否则保留 active / PENDING 并记录阻塞原因。
- 不得把“概念图已生成”“技术测试通过”或“在线预演通过”写成完整视觉验收或离线发布通过。
