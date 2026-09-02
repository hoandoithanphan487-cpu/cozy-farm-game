# N-027 新窗口完整执行 Prompt

下面整段可直接粘贴到新的 Codex 窗口：

---

你正在本地仓库 `/Users/fengyifan/Documents/VibeCoding` 工作。请正式实施 **N-027：十段主剧情、保苗日报与毕业闭环运行时接入**，并在完成后构建、运行、验证真实 App。

这不是方案讨论，也不是只写计划。请直接修改工程、补齐测试与证据，持续推进到全部范围内功能完成并通过所需部门门禁。Q01 是架构纵向切片和中间门，不是本任务终点；不要在只接入第一段剧情后停止。

## 0. 工作纪律

1. 先完整读取并遵守：
   - `/Users/fengyifan/Documents/VibeCoding/AGENTS.md`
   - `/Users/fengyifan/Documents/VibeCoding/skills/cozy-farm-game-studio/SKILL.md`
   - `/Users/fengyifan/Documents/VibeCoding/skills/project-ledger/SKILL.md`
   - 上述 skill 要求的角色、流程与 genre references
   - `/Users/fengyifan/Documents/VibeCoding/docs/game/project-ledger.md` 全文
2. 把 Product Owner 本次指令视为 DEC-050 所登记的实现授权；不要再次询问本 Prompt 已经裁决的问题。
3. 使用 Cozy Farm Game Studio 工作流：
   - Department：🧱 Engineering & Pipeline
   - Specialist owner：🎮 gameplay
   - Department quality owner：🧱 tech
   - Consulted：🛠️ tools/data、🌱 design、🎭 content、🗺️ world、✨ ux、⚖️ economy
   - Downstream reviewer：🛡️ quality
   - 实现者不能自批；跨部门前必须取得相关负责人明确的 `APPROVED / REVISE / BLOCKED`。
4. 若当前运行时允许子代理，优先把“架构/存档审计、内容转录与校验、测试/运行时验收”分给互不重叠的子任务；主代理负责权威文档、集成、冲突裁决与最终证据。不要创建用户可见的新任务窗口。
5. 当前工作树很脏，已有改动都属于用户：
   - 禁止 `git reset`、`git checkout`、`git restore`、`git clean`；
   - 禁止删除、回滚或格式化无关文件；
   - 先记录 `git status --short`、目标文件基线和现有失败标识；
   - 只做 N-027 需要的定点修改；
   - 不提交 git commit，除非 Product Owner 另行要求。
6. 所有手工文件修改使用 `apply_patch`；可重复的纯机械内容生成可使用仓库脚本，但运行时不得解析 Markdown。
7. 不联网、不安装依赖、不接入大语言模型、不生成新美术或音频。遇到真正需要扩大地图拓扑、第三方依赖或新外部权限的情况才停止并向 Product Owner 报告。
8. 每个阶段都保持工程可构建。每隔不超过 60 秒给用户一条简短进度更新。

## 1. 权威输入与冲突优先级

依次完整读取：

1. `docs/game/n-027-main-story-runtime-brief.md`
2. `docs/game/game-rules.md`
3. `docs/game/story-bible.md`
4. `docs/game/main-story-dialogue-script.md`
5. `docs/game/character-dialogue-bible.md`
6. `docs/game/n-024-brief.md`
7. `docs/game/n-025-brief.md`
8. `docs/game/n-026-brief.md`
9. `docs/game/n-015-map-layout-contract.json`
10. 当前 Swift/SpriteKit 工程、现有测试与既有 accepted 合同。

发生冲突时，N-027 brief 与 DEC-050 优先；其次是规则、剧情设定、正式对白稿、角色声线、地图合同和当前已验收运行时。

先验证以下治理事实，不要重复登记：

- N-026 已因 Product Owner 本次“把这些内容正式接入游戏”完成创意终审，状态应为 `accepted / APPROVED`。
- N-027 已登记为 `active / PENDING`。
- N-027 依赖 M0-002、M0-003、M1-002、M2-001、M3-003、D0-002、N-015、N-022、N-024、N-025、N-026、DEC-050，全部就绪。
- N-016、N-017、N-018、N-019、N-012 不是本任务依赖，不得改变其状态。

若上述台账事实与文件不一致，先用 project-ledger 工作流做最小修正；若有任何真正未 accepted 的硬依赖，按 skill 规则登记 `BLOCKED` 并停止实现。不要把已有的 14 个全量测试失败误判成依赖失败。

## 2. 必须采用的产品裁决

### 2.1 节奏

- 完整通关 5–6 小时是硬目标。
- 正常确定性时间线目标约第 28 日，低声誉／偏差恢复线最迟第 32 日可毕业。
- 通用劳动历史可提前并行累计，前置未完成时只保存指标。凡条件写着“因为这次收益／订单而扩大投入”，必须在对应 `benefit`／`offer` 生效时保存基线，只计算之后成功提交的增量；更早的无关扩张不得抵扣。
- 所有爆发严格串行，同一时间最多一个前台主事件。
- Q02、Q07 保留两个完整、跨睡眠预警日和至少两日余韵：warning_1 当日后睡眠，warning_2 次日结束并完成相关操作后再睡眠，eruption 最早在随后一天触发。
- Q01、Q03–Q06、Q08 的 `warning_1` 与 `warning_2` 是两个独立节拍，中间至少完成一次与该事件有关、结果可观察的劳动或检查，或离开后重新进入该事件锚点；普通换图不能单独计数，也不强制跨两次睡眠。Q08 至少查验新车辙、烧焦纸或断铃铛中的一个证物节点后才可播放 warning_2。
- `warning_2` 结束后必须关闭当前 `StoryDialogueSession`、归还玩家控制。只有玩家随后完成至少一个与该事件有关、结果可观察的操作，或离开后重新进入事件锚点，`eruption` 才能进入待触发；两者禁止在同一会话连播。
- 普通余韵对白持续至少两天；善后交互完成后不再占全局前台锁。
- 不删获益、对白、爆发或终局来凑时长；用时间线模拟校准。

### 2.2 Q08 时长与场景

- 三个旅程检查点的可操作路程合计 15–20 分钟。
- 含托管、出发、对峙和返乡的 Q08 完整段落为 30–40 分钟。
- 做成三个独立的剧情专用模态小场景／检查点：旧水路、雾岭岔路、灰栅农场。
- 它们不能冒充现有农场／集市，也不能改变 N-015 两图拓扑。
- 不建设第三张完整开放地图，不开发通用 A* 或全村日程。

### 2.3 Q09–Q10 终局时长与离谷边界

- 从 Q09 首次显示账簿到 Q10 最终行动并进入毕业结算，必须形成 30–45 分钟主动体验，并计入总 5–6 小时。
- 通过证物检查、意图选择、熟悉岗位回扣、对质／沉默和最终行动形成时长；禁止用挂机、强制等待、重复翻页／对白、锁控制、故意降低文字速度或无意义走路灌时长。
- `leave` 固定使用现有 `brookseed.landmark.market_wharf` 的可达交互位，解析为 `brookseed.story.anchor.ending_departure`；确认后进入独立模态离谷短景并毕业，不新增谷外开放地图、不改 N-015 两图拓扑。
- `water` 必须回到现有农场完成一次真实、有效的最后浇水事务；两种最终行动都可在确认前取消并立即归还控制。

### 2.4 声誉

- 沿用 `CommunityState.standing` 0–100。
- Q01–Q07 每个负责任善后统一 +6；分支之间不分道德高低。
- 支援档：0–39、40–69、70–89、90–100。至少在 Q02、Q07、Q08 各实现一种可截图、可测试的到场批次、额外检查、捷径提示或庆典规格差异；每档都保留手工完成保底。
- Q07 后若低于 90，提供最多三个不重复的公开修复委托，每个 +6。
- 从现有可达低边界 31 也必须能在第 32 日前到 90。
- 普通剧情不以声誉硬锁；只有 Q08 要求 ≥90。
- 低声誉只能增加一步检查、减慢支援或减少捷径，不能扣物、毁田、伤动物、锁种子／水渠／主线。
- 固定 +6 是 Q01–Q07 每段唯一必得的剧情善后 standing 变化；分支、首项分工、完成度和支援档不再额外加减 standing。
- “31→90、至多三项委托”证明的前提必须写进测试：活动 M3 结清后、Q01 warning_1 进入时 standing≥31，七段善后各 +6，之后无新 standing 扣减。从 Q01 warning_1 到 Q10 毕业暂停生成新 M3 offer，因此 Q07 后最低为 73。standing<31 的合法旧档仍能完成普通剧情并走既有公开恢复路径，但不能虚称满足该 Day32 夹具保证。

### 2.5 水渠、动物与既有系统

- 保留 `brookseed.quest.restore_old_canal`、12+8 水脉、教程与稳定 ID；它作为 Q01 前置／获益来源，不复制第二条修渠线。
- 为水渠补充真实、确定性、可显示的自动灌溉收益，实际覆盖格日进入剧情指标；手动浇水始终是保底。
- Q07 的动物供货只读成功猫店收据，不强迫出售被保护或作为伙伴的起始动物。
- Q05 后增加透明“代养供货单”：唯一 `issuanceID`、同 campaign 同时最多一张 active；接受／取消／转伙伴不发钱；取消原子退还托管动物；转伙伴每 campaign 最多一次且该动物永久不可供货／不可换替代资格；旧 issuance 终结后才可签替代单。唯一收入来自最终成功的正常猫店唯一收据。

## 3. Phase 0 — 只读预检与基线

先完成并保存到 `artifacts/integration/n-027-main-story-runtime/preflight.md`：

1. 当前 git 状态和与 N-027 预计接触的文件。
2. Xcode、macOS、架构、project、scheme、targets。
3. 当前 SaveSchema 版本。
4. 现有 Story／Quest／Community／Dialogue／Map／CatShop／Livestock／Save 架构摘要。
5. 当前全量测试基线和失败标识集合。
6. 依赖预检结果。

当前已知基线，不要覆盖或美化：

- project：`macos/CreekSprout/CreekSprout.xcodeproj`
- scheme：`CreekSprout`
- targets：`CreekSprout`、`CreekSproutTests`
- schema：v9
- 2026-08-30 Debug/arm64 clean test：464 tests，450 passed，14 failed，2 个编译警告，exit 65
- 既有失败类别：
  - `N015PhaseCRuntimeTests` 1
  - `N015RuntimeConsumerMatrixTests` 7
  - `N015RuntimeArtAndHudTests` 1
  - `N015PerformanceEvidenceTests` 1
  - `PixelAssetStoreTests` 2
  - `M4PerformanceTests` 2
- fresh DerivedData 实测的扩展相邻域基线：225 tests，0 failed，2 个既有编译 warning。
- warning 稳定键：
  - `N015MapLayoutContractTests.swift|Variable 'farmNpcs' was never mutated; consider changing to 'let' constant`
  - `N015RuntimeConsumerMatrixTests.swift|Variable 'document' was never mutated; consider changing to 'let' constant`

本次内容冻结点：

- `main-story-dialogue-script.md`：`7986d4247e2ad2d23e0af3195788257a1c4d166582911f3e4ca280e6e80d3d52`
- `game-rules.md`：`203d1232590f2290fe4d45dff6788f2d874b8453f9322d1f975c8deb2bd4d6b9`
- `story-bible.md`：`87de9111df0154792c707e8ca79920278bc1c46e539677b5b5d69d756b59b8e3`
- `n-026-brief.md`：`a6d1d28d85a71560fdd79f0e0e997e1e109a426041f0ec37fadc88bcc037373b`

开工时复算哈希。若不一致，视为用户后续修改：保留修改并重新做内容审计，不得恢复旧文件或盲目沿用旧哈希。

重新跑基线时使用新的 `DerivedData` 和 `resultBundlePath`，不要覆盖旧证据。验收标准是 N-027 专项非零且 0 failed、相邻域 0 failed 且 warning 集合无新增、全量失败／warning 标识集合无新增；禁止宣称现有全量已经全绿。

推荐基线命令：

```bash
N027_BASELINE_ROOT="$(mktemp -d /private/tmp/creeksprout-n027-baseline.XXXXXX)"
N027_EVIDENCE_TESTS="$PWD/artifacts/integration/n-027-main-story-runtime/tests"
mkdir -p "$N027_EVIDENCE_TESTS"
printf '%s\n' "$N027_BASELINE_ROOT/Baseline.xcresult" > "$N027_EVIDENCE_TESTS/baseline-bundle-path.txt"
xcodebuild \
  -project macos/CreekSprout/CreekSprout.xcodeproj \
  -scheme CreekSprout \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$N027_BASELINE_ROOT/DerivedData" \
  -resultBundlePath "$N027_BASELINE_ROOT/Baseline.xcresult" \
  clean test
```

## 4. Phase A — 独立剧情内核、内容定义与 v10 存档

不要把十段剧情扩进 `GossipEventStatus`、`QuestLogState` 或现有单说话人 `DialogueDefinition`。新增独立、纯逻辑、可测试的剧情运行时。文件名可按现有目录风格微调，但职责必须分离。

建议结构：

```text
Content/
  StoryDefinitions.swift
  StoryCatalog.swift
  StoryAnchorCatalog.swift
Domain/
  StoryCampaignState.swift
  StoryMetricsState.swift
  StoryMaturityService.swift
  StoryDirector.swift
  FrontstageEventArbiter.swift
  StoryCommandService.swift
  StoryBlockingResolver.swift
  StoryDialogueInterpolator.swift
Persistence/
  CampaignSaveCoordinator.swift
Presentation/
  StoryPresentationSnapshot.swift
  StoryDialogueView.swift
  StoryJourneyView.swift
  StoryGalleryView.swift
```

### 4.1 定义与状态

Q01–Q08 使用以下成熟度阶段；不要把 Q09/Q10 套进这张图：

```text
locked
→ benefit
→ warningOne
→ warningTwo
→ eruption
→ aftermath
→ resolved
```

Q09/Q10 使用独立 `FinaleState`／beat：

```text
locked
→ preRevealSavePending
→ discovery
→ confrontation
→ finalActionPending
→ graduated
```

`preRevealSavePending` 只有在 campaign 专属保护槽原子写成、复读验证后才能进入 `discovery`。finale 逐句、意图、走位和安全恢复点单独持久化，不伪造 benefit／warning／aftermath。

实现统一、可持久化的 `FrontstageEventArbiter`，让教程／既有过场、M3 `GossipEventState`、剧情预警／爆发／对白、Q08 和 Q09/Q10 共享一个前台租约：

- 已显示会话不被新事件抢占；崩溃后先恢复已持久化会话。
- 空闲优先级：强制教程／恢复会话 → 已开始的 Q08 或 Q09/Q10 → 活动 M3 流言 → 待触发剧情预警／爆发 → 非阻塞提示。
- 任一未终结 `CommunityState.activeEvents` 存在时，不开启新的 story warning／eruption，通用指标可后台累计。
- 进入 Q01 warning_1 前结清活动 M3；从 Q01 warning_1 到 Q10 毕业暂停生成新的 M3 offer，不改其既有状态枚举与历史，毕业后恢复普通 offer 规则。
- 任一时刻只能有一个租约；取消／结束／失败确定性释放，SaveValidation 拒绝双活动状态。

`StoryCampaignState` 至少持久化：

- Q01–Q08 各自的成熟度阶段、进入日、余韵起止日、善后质量；
- 当前前台 event／scene／beat／line／blocking cue；
- 选择、分支、现场完成度、行动历史；
- 已发 effect／reward／receipt ID；
- Q06 关系结果；
- Q08 托管快照、任务时钟、路线、检查点和返乡状态；
- Q09 账簿意图；
- Q10 对质意图、最终行动、`graduated`、画廊；
- Q08 任务前与 Q09 揭露前保护存档标志。

`StoryMetricsState` 保存真实历史，不能从当前库存或当前动物反推：

- 翻土、播种、手动浇水、自动灌溉、收获、完整种植周期；
- 每种作物收获／交付／当前投入、最大同时生长面积；
- NPC 每日有效交谈、唯一帮助、协作、冲突日；
- 猫店成功收据、不同买家／来源、溢价日、庆典预付款；
- 动物照料、完整成长、供货、代养单；
- 平静日、余韵日、修复委托。
- 因果型成熟条件的 `offerID`、基线快照、快照日和提交后增量。

计数口径严格采用 N-027 brief。每一次指标写入必须来自已成功提交的领域事务：

- 农事只在 `FarmActionService` 成功后；
- 交谈每 NPC 每日最多一次；
- 帮助按唯一 action/quest ID；
- 猫店只在 `CatShopSupplyService` 成功产生唯一收据后；
- 动物成长史要在动物出售后仍留在 StoryMetrics；
- 连续日只由成功睡眠结算推进；
- 通用历史（完整种植周期、有效交谈、成功供货、动物成长等）可以预累计；因果型加码必须同时匹配来源 `offerID`、对应阶段基线与快照后的已提交增量，来源前的面积、动物、库存、预付款或溢价不得倒填；
- 重试、重复交谈、读档和重进不得重复累计。

源事务与指标必须同事务：农事、猫店、动物、交谈和剧情 action 都先构造一个候选 `GameState`，在源领域变更成功的同一候选中写 StoryMetrics，再一次性提交；禁止先提交源事务、再第二次补指标。

锁定 `SleepUseCase` 候选状态顺序：出售结算 → 当夜有效灌溉／天气覆盖 → 缺水判定与作物成长 → 畜牧日结 → 当日 StoryMetrics 记录 → 日期／时钟推进 → M3 日初推进 → 剧情成熟度／前台仲裁推进 → SaveValidation 与原子保存 → 内存提交。任何失败都恢复原 `GameState` 与 clock。

### 4.2 内容转录

- 把 Q01–Q10、所有阶段、全部分支、236 个稿件对白 ID 和 50 个 `Qxx_BLK_nn` 转成 Swift Catalog。
- 稿件 ID 保留为 `sourceID`；建立命名空间一致的 `brookseed.story.*` 稳定运行时 ID。
- 不在运行时读取或解析 Markdown。
- 不擅自润色、删减或重排已批准台词。
- 只允许两个插值 token：`{{reputation}}` 在该行展示时读取并格式化当前 0–100 standing；`{{q05_resolution}}` 读取已存 Q05 分支，并映射为 `public=公开限量单`、`coop=联合供货`、`delay=暂缓签约`。渲染后不得残留 `{{...}}`。
- 如果因为 UI 长度确实必须改字，先使用 `humanizer-zh` skill，记录 before/after 和原因，再由 🎭 content 复核；不得削弱明线人情味或终局恶意。
- 猫店角色使用：
  - `brookseed.npc.cat_shop_black`／黑猫店员
  - `brookseed.npc.cat_shop_calico`／三花店员
  - `brookseed.npc.cat_shop_ragdoll`／布偶猫店员
- 另建绒铃、灰栅代表、灰栅农场主三个不同稳定 ID。

扩展 `ContentValidator`，至少拒绝：

- 重复或缺失的剧情／scene／beat／line／choice／cue／anchor ID；
- 不存在的前置、speaker、branch、reward、anchor；
- 非法阶段跳转或循环依赖；
- 普通剧情错误声明 `minStanding`；
- 236／50 数量不符；
- Q09 前引用 `reveal_callback`；
- 终局共谋名册遗漏七名主要 NPC、三名猫店员、绒铃、灰栅代表或灰栅农场主中的任何一人，或把灰栅代表／农场主合成同一 ID；
- world-grid anchor 在 N-015 地图外、阻挡格，或违规占用出口／建筑交互位；journey-local anchor 越出局部场景、落在局部碰撞体或缺少成对入口／出口；
- 未知／缺值插值 token，或插值后仍残留 `{{...}}`；
- 分支没有可达完成路径；
- 奖励／effect 没有幂等 ID。

### 4.3 v9→v10

将 SaveSchema 升为 v10，并更新：

- `GameState`
- `SaveGameDTO`
- `SaveMigrator`
- `SaveValidation`
- `SaveStore` 相关测试

v10 至少增加稳定 `campaignID`、StoryCampaign、StoryMetrics、作物缺水／枯萎字段，以及必要的任务保护状态。要求：

- v9→v10 注入合法中性默认；不根据当前库存、关系或历史猜测并补发旧剧情指标；
- 旧作物迁移后 `dryStreak=0`，不得开档即濒死；
- v0…v9 链式迁移仍可到 v10；
- 社区、关系、经济、教程、水脉、任务、设置、配方、畜牧、猫店逐项不丢；
- Q01–Q08 每个阶段、Q08 检查点、Q09/Q10 finale beat 和毕业后均可存读；
- 编码采用稳定排序，二次保存字节／语义稳定；
- SaveValidation 拒绝非法阶段、悬空 ID、重复 receipt、越界指标与矛盾毕业状态。

保存所有权必须定死：

- 三个手动槽各拥有一个 campaign；campaign auto、`mission_current`、`pre_mist_ridge`、`pre_reveal` 均带相同 campaignID 并隔离，不能使用一个跨手动槽共享的全局 auto 语义。
- 新游戏先选目标手动槽并二次确认，只替换该槽及其原 campaign 所属伴随档；禁止清空 production 根、其他槽、其他 campaign 或 settings。
- Continue 枚举各 campaign 的有效 generation，默认最近保存的 campaign；若其 Q08 活动则优先有效 `mission_current`，否则比较 campaign auto／manual 的保存序号。保护档永不自动 Continue，只能从明确入口加载。
- v9 手动槽迁移时生成并持久化 campaignID；仅在来源元数据明确匹配时认领旧全局 auto，原文件保留到新 generation 写成并复读验证。
- 孤儿保护档只报告／忽略，不自动删除或跨 campaign 认领；活跃任务缺 `pre_mist_ridge` 时可从有效 `mission_current` 继续，但禁用“放弃并回滚”并显示诊断。
- `pre_reveal` 必须在第一次显示 `Q09_DIS_001`／账簿内容前原子写成并复读验证；失败则不进入 Q09。普通 auto 不得覆盖。

先完成纯逻辑测试并取得 🧱 tech 对 Phase A 的 `APPROVED` 或修订意见，再进入玩家呈现。

## 5. Phase B — 保苗、晨间报告、水渠收益与正式入口

### 5.1 作物压力

实现 `game-rules.md` 第 2 节：

- 第一次缺水日结：暂停成长；
- 第二次缺水日结：萎蔫，次日列为“必须”；
- 第三次缺水日结：枯萎，留下可清理残株；
- 浇水、雨水、有效水渠和 Q08 托管清零缺水；
- 成熟作物不因缺水枯萎；
- 不凭空增加当前库存／质量系统无法表达的品质层级。

睡眠前有当夜会枯萎的作物时：

- 显示数量、格位与后果；
- 需要二次确认；
- 取消后不改变时间或状态；
- 确认后才进入原子 `SleepUseCase`。

### 5.2 晨间保苗报告

每日第一次进入农场显示第一人称、可关闭、可再次打开的报告：

- 天气；
- “必须”作物；
- “建议”作物；
- 已成熟作物；
- 雨水／水渠／社区托管覆盖；
- 预计最低体力；
- 全部危险处理后明确显示“田里的作物都稳住了。”

报告必须读取真实田块，不制造剧情危机；文字速度、UI 缩放、键鼠和控制器输入继续生效。

### 5.3 灌溉收益

建立数据化 `IrrigationService`：

- 既有修渠完成后给出 Q01 临时收益；
- Q01 善后后升级为正式收益；
- 每日确定性选择真实生长、未浇水作物格；
- 显示覆盖数量与格位；
- 手工浇水可覆盖剩余格；
- 实际覆盖格日进入 StoryMetrics；
- 失败、重复日结和读档不重复覆盖或计数。

不要改 N-015 地图水格、渠格、出口或建筑拓扑。

### 5.4 正式游戏入口

把面向玩家的“开始演示”改为正式“新游戏”，并保留“继续游戏”：

- 新游戏使用 production 存档根；
- 先选择目标手动槽；覆盖前明确显示将被替换的 campaign 并确认，只触及该 campaign；
- 继续游戏按 Phase A 的 campaign generation 规则恢复，不跨槽混用 auto／保护档；
- `DemoSessionFixture` 只允许 DEBUG／测试；
- demo 目录不得成为正式 5–6 小时游戏的唯一存档位置；
- 旧测试所需 demo fixture 仍可通过测试入口使用。

## 6. Phase C — Q01 完整纵向切片

先用统一框架完成 Q01 全链，不写 Q01 专用巨型控制器：

```text
既有修渠前置
→ 临时水渠真实获益
→ 成熟度达标
→ warning_1
→ 相关检查/劳动
→ warning_2
→ 结束当前 StoryDialogueSession，归还玩家控制
→ 再完成一次可观察的相关操作，或离开后重新进入事件锚点
→ eruption 三分支
→ 善后
→ 两日余韵回响
→ +6 声誉
→ reveal_callback 仅登记、不可提前显示
```

必须接通：

- 成熟度指标；
- 日结／交互推进；
- 多说话人对白；
- 玩家意图按钮；
- 动线锚点、NPC override、短路径／切拍、退场；
- 玩家操作节点；
- 保存、完全退出、重启恢复；
- 幂等奖励；
- 取消／回头／暂缓无软锁；
- 现有 12+8 水渠主线、教程和 M3-003 不回归。

Q01 运行证据通过后由不同角色做 🧱 tech 中间审查。收到 `REVISE` 就定点返工；收到 `APPROVED` 后继续 Q02–Q10，不能在这里宣布完成。

## 7. Phase D — Q02–Q07 正式装填

使用同一状态机、对话和动线框架逐段装填，不复制十套控制器。

### 7.1 分支稳定枚举

| 剧情 | 枚举 |
|---|---|
| Q01 | `field_first / reed_first / inspect_first` |
| Q02 | `harvest / sandbag / patrol / livestock` |
| Q03 | `cut_test / trace_rumor / protect_inventory` |
| Q04 | `regroup / parallel_crop / publish_missing_page` |
| Q05 | `public / coop / delay` |
| Q06 | `talk / no_side / pause` + `love / tender / friend` |
| Q07 | `menu / inventory / harvest / livestock` |

所有分支可完成、可存读，无唯一正确项。

Q06 固定：

- Q06 benefit 期间提供两项可选环境行动：检查共同补过的水纹记录 `brookseed.story.q06.care.shared_log`，把茶／帮工表放回共同工作位 `brookseed.story.q06.care.tea_and_roster`。两项都成功提交才保存 `romance_tender=true`，少一项为 false；只用道具反馈承接批准对白，不加玩家人格台词，不读取 standing；
- 非暂停且已有 `romance_tender` → `love`；
- 非暂停且没有 `romance_tender` → `friend`；
- `pause` → 次日水痕余韵后 `tender`；
- 三结果都算负责任善后，不涉及婚姻。

### 7.2 成熟条件

把 `game-rules.md` `6.2` 的 Q01–Q08 门槛逐项数据化，禁止简化成天数触发。尤其验证：

- Q01 临时水渠收益出现后新增至少 6 个生长格，不能用此前已有面积抵扣；
- Q02 的正式灌溉 5 天、30 格次、3 次日结、面积 +30% 和两日内成熟高价作物；
- Q03 的铃花莓两轮、三个不同对象、连续溢价／称赞与当前 6 份；
- Q04 的两作物各两轮、三次种源便利、据此新增 8 格；
- Q05 的真实猫店供货、溢价、蜜穗瓜与扩张；
- Q06 的青砚／絮宁按日有效交谈、唯一帮助和协作；
- Q07 的真实作物／动物收据、完整动物成长、庆典扩张、三次预付／溢价、五个平静日。

其中 Q02 的 +30%、Q04 的种源后 8 格、Q05 的订单后 8 格／新增供货动物、Q07 的庆典扩张与三次庆典预付／溢价都必须使用各自 `benefit`／`offer` 时保存的独立基线。不能共享快照，也不能让旧历史使事件刚获益就立即成熟。

### 7.3 群像事件

Q02、Q07：

- 各保留两个完整跨睡眠预警日；必须经过 warning_1 日结、warning_2 日结，eruption 才可在第三天触发；
- 玩家只决定第一批调度；
- 未选工作由 NPC 在背景补位；
- 危机必能完成；
- 完成度只影响可表示的现场劳动量／庆典规格；每段固定 +6 是唯一剧情 standing 变化，不再按分支或完成度额外加减；不造成永久经济损失、作物全灭或动物伤害；
- NPC 分批到场，近景 2–3 人，不列队念词；
- 玩家每条分支至少完成一个短操作或路程；
- 主路、石阶、门、闸位、猫店访问位始终可走。

### 7.4 代养供货与声誉恢复

- 代养供货单写清动物将被转交；唯一 issuanceID、同 campaign 最多一张 active，接受／取消／转伙伴不发钱也不罚声誉。
- 取消时托管动物原子退还，不能留在圈舍；转伙伴每 campaign 最多一次，并把原动物永久标记为不可供货／不可换替代资格。
- 旧 issuance 终结后才开放新替代单；最终收入只通过成功猫店唯一收据产生，取消、失败、重读和重进不发钱。
- Q07 后按需出现至多三个不同、可观察、非重复刷取的声誉修复委托。
- 跑数值模拟证明：活动 M3 已结清、Q01 warning_1 进入时 standing=31，之后无新 M3 扣减、七段各 +6，因此 Q07 后为 73，至多三个 +6 委托可在第 32 日前达到 90。另测 standing<31 普通剧情不锁，但不要把它写成同一 Day32 保证。

四档支援必须有数据化、可截图的现场差异：0–39 至少多一步手工核验，40–69 至少有一名首批帮手，70–89 至少有一项可见补位／捷径，90–100 在 Q08 额外显示一条安全路线提示并使用完整庆典规格。具体文案可沿用稿件，但四档全部必须能完成 Q02、Q07，差异不得造成资源惩罚。

## 8. Phase E — 多人对白与人物动线

新增独立 `StoryDialogueSession`，不要破坏教程对话：

- 每行有 runtime ID、sourceID、speakerID、text、portrait、condition、cue；
- 支持多人轮换、1–3 句一组、玩家意图、分支、恢复 checkpoint；
- 对话、选择、过场用现有 pause reason；
- 设置中的文字速度四档实际控制推进；
- 键鼠、控制器、重绑定都能选择／确认／取消；
- 重要信息同时有文字，不只靠颜色或音效。

50 个 `Qxx_BLK_nn` 转成数据化 blocking cue，至少含：

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

实现要求：

- 锚点拆成 `WorldGridStoryAnchor` 与 `JourneyLocalAnchor`。前者解析到 N-015 map/grid/interaction cell 并做可走、阻挡、出口净空校验；后者只属于 Q08 模态小场景，使用场景内归一化坐标、局部碰撞和成对入口／出口校验，不能套 N-015 格点规则；
- 两类坐标都只放 `StoryAnchorCatalog`，不写进对白；Q10 `brookseed.story.anchor.ending_departure` 必须是 world-grid anchor，解析到现有 `brookseed.landmark.market_wharf` 可达交互位；
- 可走短路使用预制 waypoints + `SKAction`；
- 路线不安全时淡出／切拍，不开发 A*；
- 演出结束恢复 NPC 常驻位置和玩家控制；
- 同框正面主要说话者最多 2–3 人；
- 不占出口、落脚位、石阶、建筑门／交互位、农场主路、集市中央主轴；
- 玩家每段亲自走到、观察或操作至少一个节点；
- 分支先产生走位／动作，再播放回应；
- 初见不显示排练；Q09/Q10 才启用 reveal camera/prop。

Q09 猫店后间只通过现有猫店侧帘互动切拍呈现，不新建室内地图。

## 9. Phase F — Q08 无损远行

Q08 只在成功睡眠结算后检查：

- Q01–Q07 全部负责任善后；
- Q07 余韵至少 2 日；
- standing ≥90；
- 猫店开放；
- 无重大危机；
- 从未完成；
- 当前无前台主事件。

89 不触发，90 触发。触发后没有截止，玩家可准备或暂不出发。

### 9.1 原子托管

出发前展示并确认：

- 哪些作物会被浇水／保护；
- 成熟作物保持可收；
- 哪些动物由谁照料；
- 订单、剧情截止、猫店轮换冻结；
- 待售项价格快照；
- 不扣货币、物品、种子、体力或关系；
- 中途可保存和恢复。

确认时：

1. 建立有限 `MissionSnapshot`：只含 campaignID、任务实例／起始日、托管作物格 ID、动物 ID、冻结订单／截止／轮换、`EconomyState.shipping.pendingEntries` 的 entry ID／数量／出发时单价、检查点和 receipt ID；禁止内嵌完整 GameState／DTO，完整回滚只靠保护档。
2. 原子写成并复读验证 campaign 专属 `pre_mist_ridge`；失败或写成前崩溃时当前档／内存不变。
3. 从同一源状态构造任务候选，原子写成 campaign 专属 `mission_current`，再提交内存。任务档写失败时不进入旅程。
4. 保护档写成后、任务档写成前崩溃：保护档作为孤儿忽略；任务档写成后、内存提交前崩溃：Continue 恢复 `mission_current` 并进入已准备旅程。

### 9.2 三检查点

- 旧水路：观察／选择安全通过；
- 雾岭岔路：苔藓、水痕、爪印、香料粉、契约碎片；
- 灰栅农场：`evidence / trade_union / old_waterway` 三路线。

要求：

- 无战斗；
- 走错只绕回最近检查点或看到额外风景；
- 不扣资源或普通时钟；
- 每个检查点原子替换 `mission_current`；
- 强退从最近 checkpoint 恢复；
- 放弃或读取 `pre_mist_ridge` 不产生损失；
- 绒铃与灰栅农场主的首次呈现不泄露排演；
- 返乡结算、纪念物、成就均使用唯一 receipt/effect ID；在候选中写 receipt，先保存 campaign 当前档，再提交内存；保存前崩溃不结算，保存后崩溃由 receipt 阻止重发；
- 重复读取不重复结算、派奖或推进一天；
- 活跃任务缺失 `pre_mist_ridge` 时允许从有效 `mission_current` 继续，但禁用放弃回滚并显示诊断，不能拿有限 snapshot 伪造完整回滚。

完成返乡时安全推进一天；普通作物视为已安全浇水，成熟作物不变，动物安全。“待售项”只指 `EconomyState.shipping.pendingEntries`，按快照 entry／数量／单价 exactly-once 结算。

三个局部小场景可复用本项目现有原创资产和程序化构图；“不新增全量美术”不等于只能用空白界面，但不得引入外部受保护素材或建设第三张开放地图。

## 10. Phase G — Q09、Q10、毕业与画廊

顺序固定：

1. Q08 返乡到次日 06:30；
2. 玩家完成一个完整返乡日并睡眠；
3. 次日首次进入猫店或与主要 NPC 交谈触发 Q09；
4. Q09 意图后连续进入 Q10；
5. 最后浇水，或在现有 `brookseed.landmark.market_wharf` 交互位确认进入模态离谷短景时毕业。

### Q09

触发 Q09 时先进入 `preRevealSavePending`。在第一次显示 `Q09_DIS_001` 或任何账簿内容前，原子写成并复读验证 campaign 专属 `pre_reveal`；失败则保持揭露外状态、归还控制并允许稍后重试，不能先显示内容再补存档。

分支：

- `take_ledger`
- `keep_reading`
- `close_ledger`
- `return_titles`

玩家可以合页、回头或离开，三猫不封路。此时才允许展示 `reveal_callback`。Q09 前通过普通 UI、日志、画廊、调试关闭态或数据选择器均不可看到揭露文本。

### Q10

对质意图：

- `why_me`
- `any_truth`
- `silence`
- `break_titles`

最终行动：

- `water`
- `leave`

`leave` 只在 `brookseed.story.anchor.ending_departure` 可用，该 anchor 必须解析到现有集市码头可达交互位；确认后播放可安全恢复的模态离谷短景，再提交毕业事务。它不是新地图。`water` 只在成功提交真实浇水事务后结算，不能由点击对白代替。

Q09 首次显示账簿至 Q10 毕业目标为 30–45 分钟主动体验。记录证物检查、分支回扣、移动／互动和最终行动实测用时；不得以等待或重复内容补足。

NPC 不列队认罪，不堵路，不道歉，不悔悟，不把事情解释成考察、教育或善意实验。七名主要 NPC、三名猫店员、绒铃、灰栅代表、灰栅农场主全部知情；代表与农场主是两个不同 ID，除玩家外不得留下具名无辜者。只使用本项目的账簿、收据、闸痕、种袋、缺页、英雄牌、合照和对白；禁止摄影棚、导演、控制室、直播观众等现有影视标志性表达。

已在 Q09 首行显示前创建独立、campaign 专属 `pre_reveal`，普通自动存档不可覆盖。毕业后：

- 不清空农场、货币、动物、关系或 standing；
- UI 在揭露段短暂把“社会声誉”显示为“可操纵度”，底层值保留；
- 停止社区评价的后续游戏性作用；
- 解锁结局画廊；
- 画廊可查看已发现账页、分支批注、英雄牌、合照与结局；
- 可读取 `pre_reveal` 回看。

## 11. Phase H — 测试、时间线与真实 App

必须新增以下测试类；不要改名后留下 `-only-testing` 0-test 假绿：

- `N027StoryContentTests`
- `N027StoryStateMachineTests`
- `N027StoryMetricsTests`
- `N027StorySaveMigrationTests`
- `N027CropCareTests`
- `N027IrrigationTests`
- `N027StoryDialogueTests`
- `N027StoryBlockingTests`
- `N027JourneyTests`
- `N027EndingTests`
- `N027TimelineTests`
- `N027FormalSessionTests`

### 11.1 内容与状态

- 10 条剧情；
- 236 个 source dialogue ID 一一映射且唯一；
- 50 个 blocking cue 一一映射且唯一；
- 所有稳定分支枚举；
- 前置无环、引用完整；
- Q09 前 reveal 零泄露；
- 共谋名册完整包含七名主要 NPC、三名猫店员、绒铃、灰栅代表与灰栅农场主，且代表／农场主 ID 不同；
- Q01–Q08 阶段与 Q09/Q10 finale beat 不混用；
- 教程／过场、活动 M3、story、Q08、finale 的前台租约互斥、优先级、释放与恢复；活动 M3 阻止新 warning／eruption；
- 每条分支存在完成路径；
- 单前台爆发；
- `warning_2` 结束后当前 `StoryDialogueSession` 必须关闭；没有后续可观察的相关操作或事件锚点重进时，`eruption` 不得触发。普通换图不算节拍证据。
- Q08 warning_1 与 warning_2 也禁止同会话连播；新车辙／烧焦纸／断铃铛至少一个查验 action 成功提交后才允许 warning_2。
- `{{reputation}}`／`{{q05_resolution}}` 正确插值，未知／缺值 token 被拒，所有可显示文本不残留花括号 token。

### 11.2 指标与事务

- 每个成熟条件的正向、边界、差 1、重复提交与读档；
- 通用历史早期完成会保存但不提前触发；
- Q01、Q02、Q04、Q05、Q07 的因果型加码在 offer 前不计、offer 后差 1 不成熟、达到增量才成熟；各剧情基线彼此独立，存读后不漂移；
- 猫店只按成功收据计；
- 动物出售后成长史仍在；
- 失败操作与取消不计数；
- 声誉／奖励／receipt 幂等；
- 源领域事务与 StoryMetrics 同候选提交，任一步失败不留下半份指标；
- SleepUseCase 固定顺序可观察，任一注入失败都让状态与时钟全回滚；
- 四档声誉在 Q02／Q07／Q08 的现场快照不同但均可完成，31→73→90 的前提和算式通过；
- 代养单唯一 issuance／单 active／取消退还／伙伴一次／原动物不可换资格／收入仅凭正常猫店收据的不变量。

### 11.3 存档

- v9→v10；
- v0…v9 链式迁移；
- 迁移不追溯补发历史 StoryMetrics；
- 三手动槽与 campaign auto／mission_current／两个保护槽隔离，覆盖只触及目标 campaign；
- Continue 最近 campaign 与活动 mission 优先级；孤儿保护档、保护档缺失和损坏 generation；
- Q01–Q08 每阶段与 Q09/Q10 每个 finale beat 保存→完全退出→重启；
- Q08 保护档写成前、保护写成后但 mission 写成前、mission 写成后但内存提交前三个崩溃点；每 checkpoint 与返乡 exactly-once；
- `pre_mist_ridge`；`pre_reveal` 必须在 `Q09_DIS_001` 前写成，写失败不进入 Q09；
- 毕业后存读；
- 损坏主档备份回退；
- 重复结算不发生。

### 11.4 地图、输入与 UX

- world-grid 与 journey-local anchor 分别按各自规则可达；
- NPC 不堵出口、主轴、石阶、门或交互位；
- 每段玩家节点可达；
- 取消／暂缓恢复控制；
- 文本、颜色／声音替代信息；
- AX label、identifier、focus 顺序；UI scale、text speed、键鼠、控制器、重绑定；
- 960×640／1280×800 与 100%／125%／150% UI scale；
- `ending_departure` 解析到现有集市码头交互位，leave 进入模态短景而非新地图；
- 正式新游戏／继续游戏不混 demo 存档。

### 11.5 两条完整确定性路径

高声誉合作线：

```text
正常种田 → Q01 inspect_first → Q02 harvest
→ Q03 cut_test → Q04 publish_missing_page
→ Q05 coop → Q06 love → Q07 menu
→ standing≥90 → Q08 evidence
→ Q09 take_ledger → Q10 why_me → water 毕业
```

低声誉恢复线：

```text
活动 M3 已结清，Q01 warning_1 进入时 standing=31 → 普通剧情不锁
→ Q05 delay → Q06 friend 或 tender → Q07 livestock
→ 至多三个不同修复委托 → Day 32 前 standing≥90
→ Q08 old_waterway → Q09 close_ledger
→ Q10 silence → leave 毕业
```

输出 `timeline-normal.json`、`timeline-recovery.json`，逐日列出劳动、成熟指标、预警、爆发、余韵、声誉与预计现实分钟，并单列 Q08 与 Q09–Q10 的主动用时。正常线约第 28 日，31 边界恢复线不晚于第 32 日；Q09 首次显示账簿到 Q10 毕业应为 30–45 分钟主动体验。若模拟不符，调整数据化节奏，不删剧情，也不用等待或重复内容灌时长。

时间线模拟证明游戏日与节拍可达性，不冒充一次自然 5–6 小时真人通关。工程门提供可复核的分段主动时长；完整 5–6 小时由 Product Owner 最终自然计时试玩签核，不作为部门 1–6 代码门的阻塞前置。

### 11.6 测试命令

先跑 N-027 专项：

```bash
N027_RUN_ROOT="$(mktemp -d /private/tmp/creeksprout-n027-gate.XXXXXX)"
N027_EVIDENCE_TESTS="$PWD/artifacts/integration/n-027-main-story-runtime/tests"
mkdir -p "$N027_EVIDENCE_TESTS"

xcodebuild \
  -project macos/CreekSprout/CreekSprout.xcodeproj \
  -scheme CreekSprout \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$N027_RUN_ROOT/Focused-DD" \
  -resultBundlePath "$N027_RUN_ROOT/Focused.xcresult" \
  test \
  -only-testing:CreekSproutTests/N027StoryContentTests \
  -only-testing:CreekSproutTests/N027StoryStateMachineTests \
  -only-testing:CreekSproutTests/N027StoryMetricsTests \
  -only-testing:CreekSproutTests/N027StorySaveMigrationTests \
  -only-testing:CreekSproutTests/N027CropCareTests \
  -only-testing:CreekSproutTests/N027IrrigationTests \
  -only-testing:CreekSproutTests/N027StoryDialogueTests \
  -only-testing:CreekSproutTests/N027StoryBlockingTests \
  -only-testing:CreekSproutTests/N027JourneyTests \
  -only-testing:CreekSproutTests/N027EndingTests \
  -only-testing:CreekSproutTests/N027TimelineTests \
  -only-testing:CreekSproutTests/N027FormalSessionTests
```

再跑已实测为 225 项、0 failed 的扩展相邻域门：

```bash
xcodebuild \
  -project macos/CreekSprout/CreekSprout.xcodeproj \
  -scheme CreekSprout \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$N027_RUN_ROOT/Adjacent-DD" \
  -resultBundlePath "$N027_RUN_ROOT/Adjacent.xcresult" \
  test \
  -only-testing:CreekSproutTests/ContentCatalogTests \
  -only-testing:CreekSproutTests/CommunityContentTests \
  -only-testing:CreekSproutTests/CommunityEventTests \
  -only-testing:CreekSproutTests/CommunitySaveTests \
  -only-testing:CreekSproutTests/EconomyCatalogTests \
  -only-testing:CreekSproutTests/EconomySaveTests \
  -only-testing:CreekSproutTests/InventoryServiceTests \
  -only-testing:CreekSproutTests/FarmLoopTests \
  -only-testing:CreekSproutTests/SettlementTests \
  -only-testing:CreekSproutTests/SaveStoreTests \
  -only-testing:CreekSproutTests/M4SaveAndUxTests \
  -only-testing:CreekSproutTests/MapContentTests \
  -only-testing:CreekSproutTests/MapTravelTests \
  -only-testing:CreekSproutTests/GridMovementTests \
  -only-testing:CreekSproutTests/GatherAndQuestTests \
  -only-testing:CreekSproutTests/N022LivestockAndCatShopTests \
  -only-testing:CreekSproutTests/PlacementServiceTests \
  -only-testing:CreekSproutTests/SettingsTests \
  -only-testing:CreekSproutTests/TutorialServiceTests \
  -only-testing:CreekSproutTests/TutorialSaveTests \
  -only-testing:CreekSproutTests/WatershedProgressionTests \
  -only-testing:CreekSproutTests/WatershedSaveTests \
  -only-testing:CreekSproutTests/ShippingServiceTests \
  -only-testing:CreekSproutTests/WeatherServiceTests \
  -only-testing:CreekSproutTests/N017DemoSessionTests
```

最后用新的 DerivedData 跑全量：

```bash
xcodebuild \
  -project macos/CreekSprout/CreekSprout.xcodeproj \
  -scheme CreekSprout \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$N027_RUN_ROOT/Full-DD" \
  -resultBundlePath "$N027_RUN_ROOT/Full.xcresult" \
  clean test
```

三个命令必须在同一 shell 会话使用这个唯一 `N027_RUN_ROOT`；每次重跑都重新 `mktemp -d`，不得复用已有 `.xcresult`。全量当前预期可能因既有失败返回 65，仍需解析已经完成的 bundle。

对 Phase 0 baseline、focused、adjacent、full-after 均使用 legacy JSON 提取稳定指标：

```bash
extract_n027_xcresult() {
  N027_BUNDLE="$1"
  N027_LABEL="$2"
  xcrun xcresulttool get --legacy --path "$N027_BUNDLE" --format json > "$N027_EVIDENCE_TESTS/$N027_LABEL-root.json"
  jq '{tests:(.metrics.testsCount._value // "0" | tonumber), failed:(.metrics.testsFailedCount._value // "0" | tonumber), warnings:(.metrics.warningCount._value // "0" | tonumber)}' \
    "$N027_EVIDENCE_TESTS/$N027_LABEL-root.json" > "$N027_EVIDENCE_TESTS/$N027_LABEL-metrics.json"
  N027_TESTS_REF="$(jq -r '[.actions._values[] | select(.schemeCommandName._value == "Test") | .actionResult.testsRef.id._value][0] // empty' "$N027_EVIDENCE_TESTS/$N027_LABEL-root.json")"
  test -n "$N027_TESTS_REF"
  xcrun xcresulttool get --legacy --path "$N027_BUNDLE" --id "$N027_TESTS_REF" --format json > "$N027_EVIDENCE_TESTS/$N027_LABEL-tests.json"
  jq -r '.. | objects | select(has("testStatus")) | select(.testStatus._value == "Failure") | .identifier._value' \
    "$N027_EVIDENCE_TESTS/$N027_LABEL-tests.json" | sort -u > "$N027_EVIDENCE_TESTS/$N027_LABEL-failure-ids.txt"
  jq -r '(.issues.warningSummaries._values // [])[] | ((.documentLocationInCreatingWorkspace.url._value // "<unknown>") | split("#")[0] | split("/")[-1]) + "|" + (.message._value // "<no-message>")' \
    "$N027_EVIDENCE_TESTS/$N027_LABEL-root.json" | sort -u > "$N027_EVIDENCE_TESTS/$N027_LABEL-warning-ids.txt"
}

N027_BASELINE_BUNDLE="$(cat "$N027_EVIDENCE_TESTS/baseline-bundle-path.txt")"
extract_n027_xcresult "$N027_BASELINE_BUNDLE" baseline
extract_n027_xcresult "$N027_RUN_ROOT/Focused.xcresult" focused
extract_n027_xcresult "$N027_RUN_ROOT/Adjacent.xcresult" adjacent
extract_n027_xcresult "$N027_RUN_ROOT/Full.xcresult" full-after

jq -e '.tests > 0 and .failed == 0' "$N027_EVIDENCE_TESTS/focused-metrics.json"
jq -e '.tests >= 225 and .failed == 0' "$N027_EVIDENCE_TESTS/adjacent-metrics.json"
jq -e '.tests >= 464' "$N027_EVIDENCE_TESTS/full-after-metrics.json"

comm -13 "$N027_EVIDENCE_TESTS/baseline-failure-ids.txt" "$N027_EVIDENCE_TESTS/full-after-failure-ids.txt" > "$N027_EVIDENCE_TESTS/new-failure-ids.txt"
comm -13 "$N027_EVIDENCE_TESTS/baseline-warning-ids.txt" "$N027_EVIDENCE_TESTS/adjacent-warning-ids.txt" > "$N027_EVIDENCE_TESTS/new-adjacent-warning-ids.txt"
comm -13 "$N027_EVIDENCE_TESTS/baseline-warning-ids.txt" "$N027_EVIDENCE_TESTS/full-after-warning-ids.txt" > "$N027_EVIDENCE_TESTS/new-warning-ids.txt"
test ! -s "$N027_EVIDENCE_TESTS/new-failure-ids.txt"
test ! -s "$N027_EVIDENCE_TESTS/new-adjacent-warning-ids.txt"
test ! -s "$N027_EVIDENCE_TESTS/new-warning-ids.txt"
! rg -n '(^|/)N027' "$N027_EVIDENCE_TESTS/full-after-failure-ids.txt"
```

Focused 必须非零且 0 failed；fresh-DD adjacent 至少 225、0 failed，并且只允许 baseline 已有 warning；full-after 允许相同的既有 14 个失败，但失败与 warning 标识集合不得新增。若顺手修掉既有失败可以如实记录，但不要为追求全绿扩大任务。

### 11.7 真实 App

构建并启动真实 Debug App，不只跑单元测试。新增安全驱动 `scripts/drive-n027-story-app.py`，并提供仅 DEBUG 生效的 `--n027-evidence-root <absolute-path>` 注入，让存档、campaign 伴随档与 settings 全部写入 `$N027_RUN_ROOT/AppSupport/N027`；Release 必须忽略／拒绝该注入。自然 Q01 路径和加速夹具都使用这个隔离根。

运行前后分别对两个可能的 production 根生成稳定 SHA-256 manifest：普通用户 Application Support 下的 `CreekSprout`，以及 `com.fengyifan.CreekSprout` sandbox container 的 `Data/Library/Application Support/CreekSprout`。manifest 覆盖所有 `.json`、`.backup`、`.tmp`、settings 与 campaign 文件，并对不存在目录写 sentinel；before/after 必须字节全等。驱动禁止删除、迁移、覆盖或“先备份再恢复”production 文件。

通过自然 Q01 路径和 DEBUG-only 加速夹具分别验证：

- 正式标题页、新游戏确认、继续游戏；
- 晨间保苗报告、危险清零；
- Q01 完整自然路径；
- Q02 群像调度；
- Q07 群像调度与真实供货；
- Q08 托管、三个检查点、强退恢复、返乡；
- Q09 账簿；
- Q10 `water` 与 `leave` 两结局；
- 画廊与 `pre_reveal`；
- 四档声誉现场差异；
- 960×640、1280×800 以及 100%／125%／150% UI scale 的关键界面；
- AX label／identifier／focus 顺序和键鼠／控制器取消恢复。

DEBUG 加速夹具只能调用真实领域服务或安装合法的完整状态快照，不能存在于 Release UI。截图／视频必须来自真实 App，保存窗口尺寸、UI scale、运行配置、隔离存档和对应剧情状态。证据中同时保存 production before／after manifests 与 diff 为空的断言。

## 12. 证据目录

所有证据写入：

`artifacts/integration/n-027-main-story-runtime/`

最低结构：

```text
preflight.md
architecture.md
story-content-audit.json
path-clearance.json
timeline-normal.json
timeline-recovery.json
save-migration/
tests/
runtime/
runtime/production-before.sha256
runtime/production-after.sha256
runtime/production-diff.txt
gameplay-handoff.md
tech-review.md
design-review.md
content-review.md
ux-review.md
quality-review.md
file-boundary-audit.txt
```

证据必须能让另一名代理复核，不要只写“已测试”。记录命令、退出码、测试数量、失败标识、result bundle 路径、截图来源、存档前后差异和已知限制。

## 13. 部门门禁

按顺序完成：

1. 🎮 gameplay：`SUBMITTED`
2. 🧱 tech：状态机、原子事务、v10、Q08、文件边界 → `APPROVED / REVISE / BLOCKED`
3. 🌱 design + ⚖️ economy：Day 28/32、分段主动时长估算、声誉、压力、无软锁、代养单 → 明确结论
4. 🎭 content + 🗺️ world：236 对白、角色声线、全员恶人、原创边界、50 动线与地图净空 → 明确结论
5. ✨ ux：日报、睡眠确认、选择、输入、文字速度、托管清单、画廊 → 明确结论
6. 🛡️ quality：独立非零专项、相邻回归、全量失败／warning 集合 diff、两路径、production 指纹与真实 App → 明确结论

任一门禁 `REVISE` 就返工并复闸；不要跨着 REVISE 往下签。实现者不能给自己签 tech 或 quality。

1–6 全部通过后，把 N-027 保持为 `active / PENDING` 并提交 Product Owner 最终自然计时试玩；完整 5–6 小时判断由该门签核。没有 Product Owner 新的明确签字，不得标记 `accepted`。

## 14. 绝对禁止

- 不接入大语言模型或任何网络服务。
- 不写求婚、结婚、育儿。
- 不把结局改成考察、教育、实验、善意谎言或 NPC 悔悟。
- 不新增摄影棚、导演、控制室、直播观众等表达。
- 不用声誉直接扣基础产量、杀死作物或伤害动物。
- 不把 Q08 做成战斗、资源消耗或经济惩罚。
- 不通过复制奖励、重复收据、免费动物套利来凑成熟度。
- 不让 NPC 站住门、石阶、主路、出口或玩家必经格。
- 不把 236 句塞进一个线性字符串数组，也不在 `FarmScene` 堆十套专用 if/else。
- 不把稿件 Markdown 当运行时数据库。
- 不修改 N-015 地图拓扑。
- 不把现有 14 个全量失败说成 N-027 新回归，也不虚称全量全绿。
- 不把时间线分钟估算说成已完成 5–6 小时自然试玩。
- 不用真实 App 证据驱动读取、覆盖、删除或恢复 production 存档／设置。
- 不改变其他活跃／阻塞任务状态。

## 15. 最终回复格式

完成后用中文给 Product Owner 一份简洁但可核查的报告：

### 结果

- 玩家现在能做什么；
- Q01–Q10 是否全部接通；
- 正式新游戏、保苗、Q08、毕业是否可运行。

### 关键实现

- 状态机、指标、v10、灌溉、对话、动线、Q08、保护存档、画廊；
- 关键文件链接。

### 验证

- N-027 专项：通过／失败数；
- 相邻回归：通过／失败数；
- 全量：总数、通过、失败、失败集合与基线差异；
- 正常／恢复时间线；
- 真实 App 证据。

### 门禁

- gameplay、tech、design/economy、content/world、ux、quality 的明确结论与证据。

### 状态与下一步

- N-027 保持 `active / PENDING`；
- 唯一下一负责人是 Product Owner 最终试玩；
- 如仍有范围内缺口，不得写成完成，明确列出并继续修复。

现在开始执行。先给出一句简短的 skill／依赖预检更新，然后直接工作，不要把本 Prompt 重新解释给我。

---
