# N-024 — 主剧情成熟度门槛与全员恶人终局收敛

## Player outcome

玩家在每场危机前有足够时间重复获益、建立依赖并主动扩大投入；两次群像大团圆将玩家逐步推成溪谷英雄，最终再由《溪谷消遣簿》和《已经玩够》揭露全员串谋。

## Ownership

- Department: 🎭 World & Content
- Department quality owner: 🎭 `content`
- Specialist owner: 📖 `narrative`
- Consulted: ⚖️ `economy`
- Cross-department reviewer: 🌱 `design`

## Dependencies and preflight

- N-020: `accepted / APPROVED`
- N-021: `accepted / APPROVED`
- N-022: `accepted / APPROVED`
- N-023: `accepted / APPROVED`
- DEC-045: Product Owner 已批准方向
- Preflight: `PASS`

## In scope

- 将普通剧情触发由“做过一次”改为“最低平静期＋重复受益＋主动加码＋形成牵挂＋两日预警”。
- 为每条主剧情定义进入预警前的可观察成熟标准。
- 插入《春潮护田夜》和《溪火百桌宴》两次NPC故意制造的群像危机。
- 将猫猫公主营救改为全员共同排演的最终英雄戏。
- 建立《溪谷消遣簿》和《已经玩够》的揭露与毕业规则。

## Out of scope

- 不修改 Swift、Xcode、运行时任务状态机、存档 schema、经济数值或美术资产。
- 不宣称上述剧情已经接入当前构建。
- 不复制现有影视或游戏的摄影棚、控制室、导演、直播观众或标志性台词。

## Acceptance criteria

1. 每条主剧情都具有明确的前置剧情、劳动成熟度、平静期和无并发主事件条件。
2. 每次爆发前至少有三次真实获益、一次主动加码和连续两日预警。
3. 两次群像危机均由NPC制造、由全员帮助解决，并让玩家获得公开英雄身份。
4. 普通剧情不以声誉硬锁；声誉只调整支援质量，猫猫公主隐藏任务仍要求≥90。
5. 终局明确是玩弄而非考察，全部主要NPC知情且不以悔悟洗白。
6. 危机保持低生存惩罚，不导致清档、永久破产、农作全灭或动物伤害。

## Handoff and gates

### 📖 narrative

- Outcome: `game-rules.md` 与 `story-bible.md` 已统一为成熟度触发和全员恶人终局。
- Changed artifacts: `docs/game/game-rules.md`、`docs/game/story-bible.md`、`docs/game/n-024-brief.md`。
- Assumption: 游戏仍是有限篇幅体验；延长的是游戏内关系发酵，不引入每日登录或离线惩罚。

### 🎭 content gate

- Gate status: `APPROVED`
- Scope reviewed: 剧情顺序、角色共谋、两次群像高潮、终局狠度和原创表达。
- Evidence inspected: `story-bible.md` 第1、4–11节。
- Acceptance gaps: 无。

### 🌱 design cross-department gate

- Gate status: `APPROVED`
- Scope reviewed: 触发状态机、成熟度计数、预警、余韵、声誉门槛和失败保底。
- Evidence inspected: `game-rules.md` 第6–12节。
- Acceptance gaps: 无；数值为后续实现基线，仍须在运行时任务中数据化并试玩调优。
