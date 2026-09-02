# N-027 — 十段主剧情、保苗日报与毕业闭环运行时接入

> 文档状态：Product Owner 已授权开工；本文件是 N-027 的运行时合同，不代表功能已经实现或通过验收。  
> 实施入口：[n-027-main-story-runtime-prompt.md](n-027-main-story-runtime-prompt.md)

## Player outcome

玩家从正式的“新游戏／继续游戏”入口开始一段可分 2–3 次完成的单次旅程。每天醒来先看到第一人称保苗报告，知道哪些作物必须处理、哪些只会暂停成长、哪些已被雨水、水渠或社区照料覆盖；随后通过真实种植、供货、畜牧、交谈和协作积累剧情成熟度。

Q01–Q07 依次经历获益、两次预警、爆发与余韵。两场群像危机让玩家切实调度众人并成为公开英雄。达到全部负责任善后与社会声誉 90 后，Q08《雾岭失踪的猫猫公主》以无损、可中断的三段旅程触发；Q09–Q10 再用同一批劳动记录、人物站位和道具完成“全员知情、只有玩家不知情”的揭露与毕业。毕业后劳动成果保留，可进入结局画廊或读取揭露前保护存档。

## Ownership

- Department：🧱 Engineering & Pipeline
- Specialist owner：🎮 `gameplay`
- Department quality owner：🧱 `tech`
- Consulted：🛠️ `tools`／数据、🌱 `design`、🎭 `content`、🗺️ `world`、✨ `ux`、⚖️ `economy`
- Downstream reviewer：🛡️ `quality`
- Product Owner：最终试玩、节奏、反转强度与毕业体验
- 防自我批准：实现者不得签发 🧱 tech 门禁；若同一代理承担多角色，必须另请不同部门代理做只读复核。

## Dependencies and preflight

- M0-002：`accepted / APPROVED`
- M0-003：`accepted / APPROVED`
- M1-002：`accepted / APPROVED`
- M2-001：`accepted / APPROVED`
- M3-003：`accepted / APPROVED`
- D0-002：`accepted / APPROVED`
- N-015：`accepted / APPROVED`
- N-022：`accepted / APPROVED`
- N-024：`accepted / APPROVED`
- N-025：`accepted / APPROVED`
- N-026：Product Owner 已在 2026-08-30 以“把这些内容正式接入游戏”完成 v3 创意终审，应登记为 `accepted / APPROVED`
- DEC-050：Product Owner 授权 N-027，并接受本合同对节奏与 Q08 时长矛盾的运行时裁决
- Preflight：`PASS`

N-016、N-017、N-018、N-019 与 N-012 不是本任务依赖，不得因为 N-027 开工或完成而改变其状态。

## Authority order

出现冲突时按以下顺序执行：

1. 本 brief 与 DEC-050 的运行时裁决；
2. [game-rules.md](game-rules.md) 的系统规则与成熟门槛；
3. [story-bible.md](story-bible.md) 的世界真相、顺序与原创边界；
4. [main-story-dialogue-script.md](main-story-dialogue-script.md) 的 236 个稿件对白 ID、分支和 50 个动线定位符；
5. [character-dialogue-bible.md](character-dialogue-bible.md) 的七人声线；
6. [n-015-map-layout-contract.json](n-015-map-layout-contract.json) 与当前已验收运行时；
7. PRD/TDD 的既有稳定系统合同。

禁止在运行时解析 Markdown。对白、剧情、成熟条件、分支、锚点和奖励必须转成可校验的 Swift 内容定义；稿件 ID 作为 `sourceID` 保留，另建 `brookseed.story.*` 稳定运行时 ID。

## Product Owner runtime rulings

### 节奏冲突

- 硬目标是完整通关 **5–6 小时**；正常时间线目标约第 28 日，偏差与低声誉恢复线最迟第 32 日可毕业。
- 通用劳动历史可提前、并行累计；前置未完成时只存指标，不提前播放预警或爆发。带有“因为这次收益／订单而加码”因果要求的指标不得用更早的无关投入抵扣，必须从对应 `benefit`／`offer` 生效时的基线快照之后计算增量。
- 所有 `eruption` 严格串行，同一时间只能有一个前台主事件。
- Q02、Q07 两场群像事件保留两个完整、跨睡眠的预警日和至少两日余韵：`warning_1` 当日结束后睡眠，`warning_2` 次日结束并完成相关操作后再睡眠，`eruption` 最早在随后一天触发。
- Q01、Q03–Q06、Q08 仍各有 `warning_1` 与 `warning_2` 两个独立节拍；二者之间必须发生一次与该事件有关、结果可观察的劳动或检查，或离开后重新进入该事件锚点。普通换图不能单独计数，也不强制再睡一次。Q08 至少要求玩家查验新车辙、烧焦纸或断铃铛中的一个证物节点后才可播放 `warning_2`。
- `warning_2` 播放完必须结束当前 `StoryDialogueSession` 并归还玩家控制；只有玩家随后完成至少一个与该事件有关、结果可观察的操作，或离开后重新进入事件锚点，`eruption` 才可进入待触发。`warning_2` 与 `eruption` 禁止在同一会话连播。
- 普通剧情余韵对白持续至少两个游戏日；完成善后交互后不再占用全局前台事件锁，可与下一条获益积累并行。
- 不得删对白、跳过获益、合并爆发或用纯等待来强行凑 28 日。必须用确定性时间线模拟验证正常线与恢复线。

### Q08 时长与场景

- 三个可操作旅程检查点本身目标 15–20 分钟。
- 从托管确认、出发、三检查点、对峙到返乡的 Q08 完整段落目标 30–40 分钟。
- N-027 使用三个独立的剧情专用模态小场景／检查点呈现旧水路、雾岭岔路与灰栅农场；它们不是现有农场或集市地图，也不改 N-015 的两图拓扑。
- 不在本任务内建设第三张完整开放地图、A* 寻路或全村居民日程。

### 终局时长与离谷边界

- 从 Q09 首次显示账簿到 Q10 最终行动并进入毕业结算，保留 **30–45 分钟**主动终局体验；它计入完整 5–6 小时目标。
- 时长来自证物检查、意图选择、熟悉岗位的回扣、质问／沉默和最终行动。禁止用挂机、强制等待、重复翻页／对白、锁控制、故意降低文字速度或无意义走路灌时长。
- Q10 `leave` 固定在现有 `brookseed.landmark.market_wharf` 可达交互位解锁 `brookseed.story.anchor.ending_departure`；确认后进入独立模态离谷短景并毕业，不新增谷外开放地图，不改变 N-015 两图拓扑。
- Q10 `water` 要求玩家回到现有农场并成功提交一次真实的最后浇水事务。两个入口在确认前都可取消并立即归还控制。

### 既有水渠适配

- 保留 `brookseed.quest.restore_old_canal`、12+8 水脉、既有教程和稳定 ID。
- 既有“让旧水渠再次流动”作为 Q01 的前置／获益来源，不复制第二条同义修渠主线。
- 新增可见、可验证的数据化灌溉收益：临时收益与 Q01 善后后的正式收益分别覆盖确定性的生长作物格，实际覆盖格日进入成熟度指标；玩家始终保留手动浇水保底。

### 声誉可达性

- 沿用 `CommunityState.standing` 的 0–100 数值。
- Q01–Q07 每个负责任善后统一给予 `+6`，同一剧情的分支不分“高尚／低劣”档。
- 支援展示档位为 `0–39`、`40–69`、`70–89`、`90–100`。至少在 Q02、Q07、Q08 各给出一种可截图、可测试的到场批次、额外检查、捷径提示或庆典规格差异；所有档位都保留可完成的手工保底。
- Q07 后仍低于 90 时开放最多 3 个不重复的公开修复委托，每个 `+6`；从既有可达低边界 31 出发也必须在第 32 日前到 90。
- 低声誉工具差异只能增加一步检查或减少协作加成，不得扣物、毁田、伤害动物、锁种子、水渠或普通主线。
- 只有 Q08 使用声誉 90 硬门槛；未达成时继续经营即可恢复，不需重开。
- 固定 `+6` 是 Q01–Q07 唯一必得的剧情善后声誉奖。完成度、首项分工和支援档不再额外加减 standing，只改变现场呈现或可选劳动量。
- “31 可在三项委托内到 90”的证明前提是：活动 M3 结清后、Q01 `warning_1` 进入时 standing≥31；Q01–Q07 七次善后均完成；之后没有新的 standing 扣减。从 Q01 `warning_1` 到 Q10 毕业期间暂停生成新的 M3 流言 offer，于是 Q07 后最低为 73。低于 31 的合法旧档仍可走普通剧情，并使用既有公开恢复路径先回到 31，但不虚称该极端档满足 Day32 三委托证明。

### 动物供货保底

- Q07 的“动物供货 ≥1”只读取成功的猫店收据。
- 不得强迫玩家解除伙伴／保护标记或出售起始动物。
- Q05 后提供透明的“代养供货单”：玩家明确接受一只以转交为目的的新动物，完成照料成长后可供货；玩家可随时取消或转为伙伴，系统之后仍提供不造成套利的替代单。
- 每张代养单有唯一 `issuanceID`，同一 campaign 同时最多一张 active；接受、取消与转伙伴均不发钱。取消会把托管动物原子退还，不能留在玩家圈舍；转伙伴每 campaign 最多一次，并把该动物永久标记为不可供货／不可换替代单。
- 旧 `issuanceID` 终结后才可签新替代单；原动物 ID 不得再次兑换替代资格。代养动物带来的唯一收入必须来自其最终成功的正常猫店唯一收据，失败、取消、转伙伴、重读或重进都不发钱；不扩展到繁殖、疾病或动物产品。

## Runtime state contract

新增独立剧情运行时；不得把十段剧情塞进 `GossipEventStatus`、`QuestLogState` 或现有单说话人 `DialogueDefinition`。

Q01–Q08 使用以下成熟度阶段；Q09、Q10 不得套用这张图：

```text
locked
→ benefit
→ warning_1
→ warning_2
→ eruption
→ aftermath
→ resolved
```

Q09、Q10 使用独立 `FinaleState`／beat 状态：

```text
locked
→ pre_reveal_save_pending
→ discovery(Q09)
→ confrontation(Q10)
→ final_action_pending
→ graduated
```

`pre_reveal_save_pending` 只有在 campaign 专属保护槽原子写成后才能进入 `discovery`；Q09/Q10 的逐句、意图、走位和安全恢复点保存在 finale beat 中，不伪造 benefit、warning 或 aftermath。

新增统一 `FrontstageEventArbiter`，让教程／既有过场、M3 `GossipEventState`、剧情预警／爆发／对白、Q08 旅程和 Q09/Q10 终局共享一个可持久化的前台租约：

- 已经显示的前台会话不被新事件抢占；崩溃恢复时先恢复已持久化会话。
- 空闲时优先级为：尚未完成的强制教程／恢复会话 → 已开始的 Q08 或 Q09/Q10 → 已活动的 M3 流言 → 待触发的剧情预警／爆发 → 非阻塞提示。
- 任一 `CommunityState.activeEvents` 中存在未终结 M3 流言时，不得开启新的剧情 `warning_1`、`warning_2` 或 `eruption`；通用劳动指标仍可后台累计。
- 进入 Q01 `warning_1` 前必须先结清活动流言；从 Q01 `warning_1` 到 Q10 毕业期间不生成新的 M3 流言 offer，既有 M3 状态枚举与历史不被改写，毕业后恢复普通 offer 规则。
- 任何时刻只能有一个前台租约；取消、结束或失败必须确定性释放，SaveValidation 拒绝互相矛盾的双活动状态。

`StoryCampaignState` 至少持久化：

- Q01–Q08 各自的成熟度阶段、进入日、善后质量与余韵起止日；
- 当前前台事件、当前 scene／beat／line／blocking cue；
- 玩家意图、分支、现场完成度、行动历史与已授予 effect ID；
- Q06 关系结果；
- Q08 托管快照、独立任务时钟、路线、检查点、返乡与一次性奖励收据；
- Q09 账簿意图；
- Q10 对质意图、最终行动、`graduated` 与画廊解锁；
- 揭露前保护存档是否已创建。

`StoryMetricsState` 至少持久化：

- 翻土、播种、手动浇水、自动灌溉、收获与完整种植周期；
- 按作物分类的收获、交付、当前投入与最大生长面积；
- NPC 每日有效交谈、唯一帮助、协作与关系冲突日；
- 猫店成功收据、不同买家／订单来源、溢价日与庆典预付款；
- 动物每日照料、完整成长、供货与代养单历史；
- 无公开冲突的平静日、剧情余韵日与补足委托。
- 因果型成熟条件的来源 `offerID`、基线快照、快照日和提交后的增量；至少覆盖 Q01 临时水渠后新增 6 格、Q02 正式水渠后面积 +30%、Q04 种源便利后新增 8 格、Q05 订单后扩种 8 格／新增供货动物，以及 Q07 庆典订单后的扩张与 3 次庆典预付／溢价。

计数统一口径：

- 对话每 NPC 每游戏日最多计 1 次；重复短回应不计。
- 帮助按唯一任务／行动 ID 计；读取、重进与重试不得重复。
- 供货只在 `CatShopSupplyService` 成功生成唯一收据后计数。
- 连续日按成功睡眠结算计算；断档重置对应连续计数。
- 种植面积是同时处于生长状态的最大格数；30% 扩张相对成熟度开始快照向上取整。
- 自动灌溉格次是睡眠时真正被覆盖的生长格累计。
- 平静日必须整日没有公开冲突和前台爆发。
- 节庆扩张满足任一：快照后新增 8 个生长格、新增 1 只动物，或锁定 12 件合格库存。
- 通用历史（例如完整种植周期、有效交谈、成功供货、动物成长）可预累计；因果型加码必须同时具备有效来源、对应阶段基线和快照后的已提交增量。来源出现前的面积、动物、库存、预付款或溢价一律不能倒填。

所有变更都应先构造 `GameState` 候选，再整体提交。重复触发、存读、强退或请求重试不得重复加指标、声誉、奖励、收据或日结。

`SleepUseCase` 必须在一个候选 `GameState` 中按固定顺序完成：出售结算 → 当夜有效灌溉／天气覆盖 → 缺水判定与作物成长 → 畜牧日结 → 当日 StoryMetrics 记录 → 日期／时钟推进 → M3 日初推进 → 剧情成熟度／前台仲裁推进 → SaveValidation 与原子保存 → 内存提交。任一步失败都恢复原状态与时钟。

农事、猫店、动物、交谈和剧情 action 的指标必须随源领域事务写入同一个候选 `GameState` 并一起提交；禁止先提交源事务、再用第二次写入补 StoryMetrics。v9→v10 不追溯猜测历史指标，只注入安全中性值。

## Farming pressure and morning report

在现有温和种植循环上补齐 [game-rules.md](game-rules.md) 第 2 节：

- `FarmCell` 增加可迁移、可校验的连续缺水与枯萎状态。
- 第 1 个缺水日只暂停成长；第 2 个缺水日进入“当日必须”；第 3 次缺水日结才枯萎。
- 浇水、雨水、有效水渠或 Q08 社区托管清除缺水计数。
- 成熟作物不因缺水枯萎；本任务不强造现有库存系统无法表达的品质层级。
- 睡眠前若仍有当夜会枯萎的作物，显示数量、位置和后果并二次确认。
- 每天第一次进入农场显示第一人称报告：天气、必须、建议、成熟、已覆盖、预计体力；危险清零后明确显示“田里的作物都稳住了。”
- 剧情或坏风评不得无因直接扣基础产量；任何协作暂停都必须显示受影响地块与手工保底。

## Story content contract

### Maturity thresholds

Q01–Q08 的成熟门槛必须逐项按 [game-rules.md](game-rules.md) `6.2` 数据化，不得以“到某天自动触发”替代。Q09、Q10 按以下顺序：

1. Q08 返乡到次日 06:30；
2. 玩家完成一个返乡日并睡眠；
3. 下一日首次进入猫店或与任一主要 NPC 交谈时触发 Q09；
4. Q09 意图完成后连续进入 Q10；
5. 最后浇水，或在现有 `brookseed.landmark.market_wharf` 交互位确认进入模态离谷短景时毕业。

### Stable branches

| 剧情 | 运行时枚举 |
|---|---|
| Q01 | `field_first / reed_first / inspect_first` |
| Q02 | `harvest / sandbag / patrol / livestock` |
| Q03 | `cut_test / trace_rumor / protect_inventory` |
| Q04 | `regroup / parallel_crop / publish_missing_page` |
| Q05 | `public / coop / delay` |
| Q06 | `talk / no_side / pause` + `love / tender / friend` |
| Q07 | `menu / inventory / harvest / livestock` |
| Q08 | `evidence / trade_union / old_waterway` |
| Q09 | `take_ledger / keep_reading / close_ledger / return_titles` |
| Q10 | `why_me / any_truth / silence / break_titles` + `water / leave` |

全部分支可完成，不设唯一道德答案。Q02、Q07 只决定第一批调度，其余工作由 NPC 补位。Q05 三线均可负责任善后。Q08 三线无战斗、无资源损失。

Q06 规则：

- 在 Q06 `benefit` 期间提供两项可选、可观察、可存档且不带道德评分的环境行动：检查共同补过的水纹记录 `brookseed.story.q06.care.shared_log`，以及把茶／帮工表放回二人共同工作位 `brookseed.story.q06.care.tea_and_roster`。两项都成功提交时设置 `romance_tender=true`；少一项则为 false。行动只用道具反馈承接已批准对白，不新增玩家人格台词，也不读取 standing。
- 未暂停且已有 `romance_tender` → `love`；
- 未暂停且没有 `romance_tender` → `friend`；
- `pause` → 次日水痕余韵后进入 `tender`；
- 三个结果都算负责任善后，不涉及婚姻，不阻断 Q07。

### Dialogue and blocking

- 转录 236 个唯一稿件对白 ID；每条保留 `sourceID`，不能只导入标题或摘要。
- 建立多说话人 `StoryDialogueSession`，支持每行 speaker、portrait、文字、玩家意图、分支条件、动作 cue 与安全恢复点。
- 一次展示 1–3 句；走位、检查或劳动穿插其间，文字速度沿用设置四档。
- 玩家意图是按钮含义，不替玩家写固定人格台词。
- 运行时对白插值只允许白名单 token：`{{reputation}}` 在该行展示时读取并格式化当前 0–100 standing；`{{q05_resolution}}` 读取已存 Q05 分支，并映射为 `public=公开限量单`、`coop=联合供货`、`delay=暂缓签约`。Validator 拒绝未知 token、缺失状态与输出后仍含 `{{...}}` 的文本。
- Q09 之前任何普通界面、回放、调试关闭态都不得暴露 `reveal_callback`。
- 不接入大语言模型；运行时完全离线、确定性、可测试。

50 个 `Qxx_BLK_nn` 转成 `StoryBlockingCueDefinition`，至少包含：

```text
sceneID
sourceBlockingID
entryAnchor
npcStartAnchors
playerWaypoints
interactionAnchor
crossingOrInterrupt
branchMovement
npcExitAnchors
temporarilyBlockedCells
revealCameraOrProp
```

约束：

- 锚点分两类：`WorldGridStoryAnchor` 解析到 N-015 现有地图、格点和 interaction cell，按可走／阻挡／出口净空校验；`JourneyLocalAnchor` 只属于 Q08 模态小场景，使用场景内归一化坐标、局部碰撞和入口／出口配对校验，不拿 N-015 格点规则误判。
- 两类坐标都集中在 `StoryAnchorCatalog`，对白文件不写坐标；Q10 `ending_departure` 必须是 world-grid anchor，并解析到 `brookseed.landmark.market_wharf` 的现有可达交互位。
- 同一近景主要说话者最多 2–3 人。
- 建筑门、交互位、石阶、农场主路、集市中央主轴和地图出口始终可走。
- 玩家每段至少检查或操作一个节点；选择后先走位，再播回应。
- 短路径可用预制路点与 `SKAction`；不能安全走时使用淡出／切拍，不开发完整 A*。
- 演出结束立即恢复控制；取消、回头与暂缓不得软锁。
- 初见不显示排练后台；Q09/Q10 才允许替代机位与旧动作回看。
- 关键事实同时有文字或可检查道具，不只靠颜色、声音或远景。
- Q09 不新建猫店室内地图，只在现有猫店侧帘使用互动切拍。

猫店三名未命名角色先使用稳定 ID：

- `brookseed.npc.cat_shop_black` → 黑猫店员
- `brookseed.npc.cat_shop_calico` → 三花店员
- `brookseed.npc.cat_shop_ragdoll` → 布偶猫店员

另建绒铃、灰栅代表、灰栅农场主稳定 ID；代表与农场主不得混成同一角色。

## Q08 transaction boundary

出发前必须显示并确认托管清单。`MissionSnapshot` 只能保存有限的托管／结算信息：`campaignID`、任务实例与起始日、被承诺覆盖的作物格 ID、动物 ID、冻结订单／截止／收购板轮换、`EconomyState.shipping.pendingEntries` 的 entry ID／数量／出发时单价、检查点和一次性 receipt ID。不得在 `GameState` 内嵌完整 `GameState` 或完整 DTO；完整回滚只依靠 campaign 专属 `pre_mist_ridge` 保护槽。

出发采用两阶段提交：

1. 原子写成并复读验证 `pre_mist_ridge`；失败或写成前崩溃时，当前档与内存不变，不进入 Q08。
2. 基于同一源状态构造带有限 `MissionSnapshot` 的任务候选，原子写成 campaign 专属 `mission_current`；失败时不提交内存。若保护槽写成后、任务当前档写成前崩溃，保护文件视为孤儿并忽略；若任务当前档写成后、内存提交前崩溃，Continue 必须恢复 `mission_current` 并进入已准备的 Q08。

Q08 使用独立任务时钟：

- 作物安全推进一天，成熟作物保持可收获；
- 动物保持安全照料；
- 普通订单、剧情截止和收购板轮换冻结；
- “待售物”专指 `EconomyState.shipping.pendingEntries`；按快照中的 entry ID／数量／单价只结算一次；
- 不扣货币、背包、种子、普通体力或关系；
- 每个检查点原子替换 `mission_current`；强退后从最近写成的检查点恢复；
- 放弃任务或读取任务前存档不产生状态损失；
- 返乡在候选状态中写入唯一结算／纪念 receipt，先保存 campaign 当前档，再提交内存；保存前崩溃不结算，保存后崩溃由 receipt 阻止重发，达到 exactly-once。
- 活跃任务若因外部删除缺失 `pre_mist_ridge`，仍可从有效 `mission_current` 继续，但必须禁用“放弃并回滚”并给出明确诊断；不得凭有限快照伪造完整回滚。

## Formal game shell and ending

- `GameState`／DTO 增加稳定 `campaignID`。三个手动槽各自拥有一个 campaign；其自动档、`mission_current`、`pre_mist_ridge`、`pre_reveal` 都按 campaign 隔离，禁止继续使用一个跨槽共享的全局自动档语义。
- 把玩家入口从“开始演示”升级为正式“新游戏／继续游戏”；新游戏必须先选目标手动槽并确认，只替换该槽及其原 campaign 所属伴随档，禁止清空 production 根、其他手动槽、其他 campaign 或设置。
- `DemoSessionFixture` 只能留在 DEBUG／测试证据路径，不能成为正式 5–6 小时存档根。
- 正式 Continue 枚举每个 campaign 的有效 generation，默认选择最近保存的 campaign；若该 campaign 有活动 Q08，则优先恢复有效 `mission_current`，否则选择较新的 campaign auto／manual。两个保护槽永不参与自动 Continue，只能由明确的“任务前／揭露前”读取入口打开。
- v9 手动槽迁移时生成并持久化 campaignID；只在来源元数据明确匹配时认领旧全局 auto，保留原文件直到迁移写成验证成功。孤儿保护档只报告并忽略，不自动删除或跨 campaign 认领。
- `pre_reveal` 必须在第一次显示 `Q09_DIS_001`／账簿内容之前原子创建并复读验证；保存失败则停留在揭露外、不进入 Q09。普通自动存档不得覆盖。
- 毕业不清空农场、货币、动物、关系或声誉数值；只停止社区评价的游戏性作用，并把 UI 标签在揭露段短暂改为“可操纵度”。
- 结局画廊至少能查看已发现的账簿页、分支批注、英雄牌、合照和毕业结果，并可读取 `pre_reveal`。
- 终局共谋名册必须明确包含七名主要 NPC、三名猫店员、绒铃、灰栅代表、灰栅农场主；灰栅代表与农场主是两个不同 ID。除玩家外，所有具名主线参与者都知情，不得留下一个“其实无辜”的代表来削弱全员恶人。
- 终局不得加入道歉、考察、教育、悔悟或洗白；不得使用摄影棚、导演、直播观众或任何现有影视作品标志性表达。

## Scope boundaries

### In scope

- 正式新游戏／继续游戏与保护存档。
- 保苗状态、晨间报告、睡眠风险确认和真实水渠灌溉收益。
- 独立剧情定义、Catalog、状态机、指标、日结推进、内容验证。
- schema v9→v10 迁移、存档验证与每阶段恢复。
- Q01–Q10 全部对白、意图、分支、人物动线与可玩交互。
- Q08 三个剧情小场景、无损托管、检查点与幂等奖励。
- Q09 账簿、Q10 对质、最后行动、毕业与画廊。
- 声誉支援档、可达性修复委托、代养供货单。
- 自动化、真实 App 运行证据、部门门禁与台账维护。

### Out of scope

- 大语言模型或联网对话。
- 求婚、结婚、育儿或多代系统。
- 完整第三张开放地图、完整 NPC 日程、A*／通用寻路。
- 新的全量美术、配音、BGM 或环境音生产。
- 繁殖、疾病、死亡、动物产品与多圈舍管理。
- 重做 N-015 地图拓扑、已验收经济基线或 M3-003 状态枚举。
- 修复与 N-027 无关的既有 N-015 资源／像素／性能失败，除非 N-027 引入了新的回归。

## Delivery increments

1. **A — 核心与存档**：定义、Catalog、指标、状态机、v10 迁移、验证和纯逻辑测试。
2. **B — 农务与正式入口**：保苗、日报、灌溉、正式新游戏／继续游戏。
3. **C — Q01 纵向切片**：成熟度→获益→两预警→爆发→余韵→对白→动线→存读完整跑通，取得 🧱 tech 中间门禁。
4. **D — Q02–Q07 装填**：群像事件、铃花莓、种源、独家单、关系结果、声誉恢复与代养单。
5. **E — 多人对白与人物动线**：236 行、50 cue、插值、跨场景恢复、净空与输入。
6. **F — Q08 无损远行**：两阶段提交、三段局部场景、检查点与 exactly-once 返乡。
7. **G — Q09–Q10**：账簿、全员恶人对质、30–45 分钟主动终局、最后农务／离开、画廊与揭露前保护档。
8. **H — 独立验收**：专项、相邻回归、全量基线比较、两条时间线、真实 App 烟雾、部门复核。

每个增量必须保持可构建、可测试。Q01 是架构门而不是最终交付；任务不得在只完成 Q01 时停止。

## Acceptance criteria

1. 正式新游戏不误用 demo 目录；选择并确认后只替换目标手动槽所属 campaign。三手动槽、campaign auto、任务当前档与两个保护档完全隔离，Continue 优先级、孤儿／缺失保护档和崩溃恢复均有测试。
2. v9 存档迁移后既有农作不立即危险，畜牧、猫店、社区、经济和设置逐项保持；v10 再存读全等，不追溯补发无法证明的历史剧情指标。
3. 晨间报告与睡眠确认准确反映每块田；连续缺水行为符合 1/2/3 日规则，成熟作物不枯萎。
4. 临时／正式水渠真实覆盖作物且可观察，手动保底一直存在，覆盖计数不重复；SleepUseCase 顺序与全事务失败回滚符合合同。
5. 十条剧情和 236 个稿件对白 ID 一一映射；50 个动线定位符均有运行时 cue；两个白名单插值正确解析，成品文本不残留 `{{...}}`。
6. Q01–Q08 每项成熟条件有明确指标来源；通用历史提前完成不丢，因果型加码只读取对应 `benefit`／`offer` 基线后的增量，读档不重复，不能只靠日期触发。
7. Q01–Q08 使用成熟度阶段，Q09/Q10 使用独立 finale beat；统一前台仲裁保证教程、活动 M3、剧情、旅程和终局互斥。活动 M3 阻止新剧情预警／爆发。
8. 任一段的 `warning_2` 与 `eruption` 不得在同一 `StoryDialogueSession` 连播；中间必须归还控制，并发生一次可观察的相关玩家操作或事件锚点重进。Q08 的 `warning_1`／`warning_2` 也不得同会话连播，二者之间必须完成至少一个证物查验节点。
9. 两套确定性模拟证明正常线约第 28 日、31 边界恢复线不晚于第 32 日毕业；工程证据给出预计主动时长，完整 5–6 小时由 Product Owner 最终自然计时试玩签核，不作为 1–6 部门代码门的阻塞前置。
10. Q09 首次显示账簿至 Q10 毕业为 30–45 分钟主动体验，不以等待或重复内容填充。
11. 普通剧情在声誉 0–89 均可完成；89 不触发 Q08，90 触发。31 边界夹具在 Q01 七次 +6 后 Q07 standing≥73，再由最多三项不同 +6 委托到 90；该证明不冒充 standing<31 极端旧档的 Day32 保证。
12. 四个声誉支援档在 Q02、Q07、Q08 有可观察快照／测试差异，所有档都能保底完成；固定 +6 是每段唯一剧情善后声誉变化，分支与完成度不额外加减。
13. Q02、Q07 所有首项分工均能完成，NPC 补位不扣永久资源，不软锁。
14. Q06 两项可观察行动确定 `romance_tender`；true→love、false→friend、pause→tender，三结果互斥、可存读、均可继续且无婚姻内容。
15. 猫店里程碑只读取成功收据；代养单满足唯一 issuance、单 active、取消退还、伙伴例外最多一次、原动物不可换新资格和只凭猫店收据产生收入等防套利不变量。
16. World-grid 与 journey-local 锚点分别校验；50 cue 的全部分支净空、入口／出口、取消恢复和玩家节点都有机器可读证据。
17. Q08 三路线均可完成、无战斗、无经济／物品／作物／动物损失；保护档→任务当前档两阶段崩溃点、检查点和返乡 exactly-once 均通过测试。
18. `pre_reveal` 在首次显示 `Q09_DIS_001` 前写成，失败不进入 Q09；Q09 前无 `reveal_callback` 泄露，Q09 四意图与 Q10 四对质意图均可到达。
19. Q10 最后浇水和离开两种毕业均保留劳动成果、解锁画廊和 `pre_reveal` 读取；`leave` 从现有集市码头交互位进入模态短景，不新增开放地图。
20. 终局明确是玩弄；七名主要 NPC、三名猫店员、绒铃、灰栅代表、灰栅农场主全部在共谋名册中，除玩家外没有具名无辜者，也不出现考察、教育、道歉或洗白。
21. 文字、选择、托管清单和关键线索不只靠颜色／声音；文字速度、AX label／identifier／focus 顺序、输入重绑定和目标分辨率／缩放继续生效。
22. M3-003、N-022、农场循环、出售箱、地图、设置与存档相邻回归 225 项无失败；只允许已知两条编译 warning，warning 集合无新增。
23. 当前全量基线为 464 项、450 passed、14 个既有失败、2 个编译警告；N-027 专项必须非零且全绿，全量失败与 warning 标识集合无新增，不得虚称当前全量已绿。

## Required evidence

证据根：`artifacts/integration/n-027-main-story-runtime/`

- `preflight.md`：依赖、工作树、工具链、基线失败标识；
- `architecture.md`：状态、事务、指标来源、ID、文件边界；
- `story-content-audit.json`：10 剧情／236 对白／50 cue／分支枚举；
- `timeline-normal.json` 与 `timeline-recovery.json`；
- `path-clearance.json`：50 cue × 全分支的两类锚点、可达性与净空结果；
- `save-migration/`：v9→v10、campaign 隔离、Continue 选择、各阶段存读、Q08 崩溃点／checkpoint、Q09 前 pre_reveal；
- `tests/`：专项、相邻回归、全量 xcresult 摘要和失败集合 diff；
- `runtime/`：晨报、四档声誉差异、Q01、Q02、Q07、Q08 三检查点、Q09、Q10 两结局及 960×640／1280×800、100%／125%／150% UI 证据；
- `file-boundary-audit.txt`；
- `gameplay-handoff.md`；
- `tech-review.md`；
- `design-review.md`；
- `content-review.md`；
- `quality-review.md`。

## Gates and completion

1. 🎮 gameplay：`SUBMITTED`，附实现、测试、运行证据与已知限制。
2. 🧱 tech：`APPROVED / REVISE / BLOCKED`，审查状态机、原子性、v10、性能和文件边界。
3. 🌱 design + ⚖️ economy：审查节奏、压力、声誉可达、代养单和无软锁。
4. 🎭 content + 🗺️ world：审查 236 对白、反转、原创边界、动线与语义锚点。
5. ✨ ux：审查输入、文字速度、日报、选择、托管清单和画廊。
6. 🛡️ quality：独立运行非零专项、相邻回归、全量失败／warning 集合 diff 和两条完整路径。
7. Product Owner：最终自然计时试玩（含完整 5–6 小时判断）与创意终审。

只有 1–6 全部 `APPROVED`、所有范围内 AC 有证据后，才能把 N-027 提交给 Product Owner；Product Owner 未签字前保持 `active / PENDING`，不得自行标记 `accepted`。

## Baseline known state

- 工程：`macos/CreekSprout/CreekSprout.xcodeproj`
- scheme：`CreekSprout`
- targets：`CreekSprout`、`CreekSproutTests`
- 当前存档 schema：v9
- 2026-08-30 只读 QA 基线：Debug/arm64 clean test 共 464 项，450 passed、14 failed、2 个编译警告，退出 65。
- 14 个失败限于既有 N-015 资源／像素／性能类别：`N015PhaseCRuntimeTests` 1、`N015RuntimeConsumerMatrixTests` 7、`N015RuntimeArtAndHudTests` 1、`N015PerformanceEvidenceTests` 1、`PixelAssetStoreTests` 2、`M4PerformanceTests` 2。
- 扩展相邻域使用 fresh DerivedData 独立实测为 225 tests、0 failed、2 个既有编译 warning；N-027 交付必须维持 0 failed 且 warning 集合无新增。
- 两条既有 warning 稳定键为：`N015MapLayoutContractTests.swift|Variable 'farmNpcs' was never mutated; consider changing to 'let' constant`；`N015RuntimeConsumerMatrixTests.swift|Variable 'document' was never mutated; consider changing to 'let' constant`。
- 此基线只用于识别新增回归，不视为发布级通过。
