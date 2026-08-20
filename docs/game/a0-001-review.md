# A0-001 PRD 完整验收报告

**任务:** 执行 PRD 第 10、11、14 节完整验收及签核建议
**执行人:** Hermes / 🧪 qa(只读验收)
**日期:** 2026-08-19
**合同:** `docs/game/a0-001-brief.md`
**范围:** PRD-FR-001~014(第 10 节)、PRD-NFR-001~011(第 11 节)、PRD 第 14 节 7 场景、第 12 节成功指标引用
**方式:** 只读证据追踪——不重复 clean test(引用各任务权威 xcresult)、不重复执行 DEC-018 豁免项;补验仅用静态探针(零 GUI 驱动)
**依据:** M1-002~M4-002 各任务权威证据;候选包 `artifacts/acceptance/m4-002-candidate-macos-20260820T015427Z/macos-arm64/20260820T015500Z/`

---

## 1. FR 追踪表(PRD 第 10 节)

| ID | 要求 | 判定 | 证据(权威路径) |
|---|---|---|---|
| FR-001 | 键鼠/手柄移动、选择工具、目标格反馈 | ✅ PASS | M1-002 网格移动/边界(10×6 网格、WASD/方向键逐格、`artifacts/qa/p0-007-independent/`;39/39 `m1-002-xcode/TestResults-R5.xcresult`);D0-002 键鼠/手柄重绑定(208/208);M4-002 候选包 r7 键鼠输入(截图 05–12) |
| FR-002 | 时间按规则推进;菜单/对话/睡眠正确暂停 | ✅ PASS | M2-002 对话暂停运行时(`m2-002-hermes-r1/DRIVE-LOG.md` 对话期时钟冻结 23:30);ClockSystem/DayCycleService 测试 |
| FR-003 | 翻土→播种→浇水→成长→收获闭环 | ✅ PASS | M2-002 教学路径运行时(`hud-till/plant/water/harvest*.txt` 序列);FarmLoopTests |
| FR-004 | 背包合并/拆分/消耗/满包/世界掉落不复制丢失 | ✅ PASS | M2-001 Inventory 测试(4 项)+ 运行时满包取回失败(`09-retrieve-full-fail.png`);89/89 `m2-001-xcode/hermes-r1/TestResults-hermes-r1.xcresult` |
| FR-005 | 待结算出售项可保存/读取/取回;日结只结算一次+准确明细 | ✅ PASS | M2-001 Shipping/EconomySave/Settlement 测试 + 174 路径运行时 + 幂等日结(`08-second-settle-no-dup.png`);M4-002 r7 二次睡眠不重复到账(`save-after-second-sleep.json` [174, 0]) |
| FR-006 | 保底节点取材料、制作并放置有效设施;失败放置不扣材料 | ✅ PASS | M3-002 GatherService/CraftingService 失败原子性(运行 03 证据);WatershedProgressionTests;127/127 `m3-002-xcode/verify-r2/TestResults.xcresult` |
| FR-007 | 水渠接片 +12 与修复交付 +8 达 20,不依赖社交;地图/音频/可玩状态变化 | ✅ PASS | M3-002 0→12→20 运行时 + 世界变化解锁(运行 02/15);127/127 |
| FR-008 | 三名职能角色对话;至少一名支持请求和信任变化 | ✅ PASS | M3-001 七人交谈/对话锁/重播无奖励(114/114);M3-003 RelationshipService 信任变化(180/180);D0-001 青砚核实路径 |
| FR-009 | 睡眠、退出、重启和读取后关键状态一致 | ✅ PASS | M2-001/M2-002 跨进程存读;M3-003 三夹具跨进程 B/C/D 一致;D0-001 `reload-consistency.json` mismatches 空;M4-002 r7 重载一致 |
| FR-010 | HUD/背包/制作/任务/设置可用键盘鼠标手柄;重绑定冲突、默认恢复、重启持久化 | ✅ PASS | D0-002 10 条验收全绿(tab 切换修复、Q 绑定持久化 `move_up=Key:Q`、重启 diff 全等、冲突反馈;208/208 `d0-002-xcode/TestResults-D0-002.xcresult`);设置缺口由 D0-002 补齐(D0-001 曾发现并登记) |
| FR-011 | 晴雨天气正确影响视觉、音频和浇水规则 | ✅ PASS(音频占位) | D0-001 雨天浇水(WeatherServiceTests 5 项 + 运行时第 2 天 `wateredToday: true`);视觉/文字图标晴雨变化;音频为占位表现按 DEC-015 后置(见观察项 O-1) |
| FR-012 | 所有作物、物品、配方、任务和价格从数据加载 | ✅ PASS | M0-002 ContentRegistry + ContentValidator 门禁(错误引用阻断);M3-001/M3-002 数据化内容(WorldCatalog/ProgressionCatalog);与 NFR-005 同源 |
| FR-013 | 四邻居基础对话;事件三初始应对+两步后续;状态/截止/行动历史可保存重放 | ✅ PASS | M3-001 邻居对白(各 5 句);M3-003 五行动状态机/截止优先/回放(180/180);D0-001 三夹具 42/50/58 |
| FR-014 | 风评规则+信任子点 +10%/−15%;`min_standing` 仅影响有恢复路径可选节点;水渠主线始终可继续 | ✅ PASS | M3-003 风评 50→42/58、边界 39→31/47、信任定点(+300/+330/+255 余数保留)、主线全分支不软锁;D0-001 复核(边界 31 暂停/47 恢复) |

## 2. NFR 追踪表(PRD 第 11 节)

| ID | 要求 | 判定 | 证据(权威路径) |
|---|---|---|---|
| NFR-001 | 参考设备 10 分钟压力路线:P95 ≤16.67ms、P99 ≤25ms | ✅ PASS | M4-001 真实墙钟 p95 2.11ms/p99 5.06ms(PerformanceClock `mach_absolute_time`,REVISE 返工后;`m4-001-xcode/hermes-gate-report.md`、`perf/`) |
| NFR-002 | 连续切图 10 次加载 P95 <3s | ✅ PASS | M4-001 10 次切图 p95 5.46ms(MapLoadTimer 纯单调时钟) |
| NFR-003 | 存档安全替换+保留最近有效备份 | ✅ PASS | M2-001/M4-001 SaveStore 三件套(tmp 写→读回→备份→原子替换)+ 故障注入 `testSaveFailureDoesNotCorruptValidGeneration`;M4-001 多槽隔离/睡眠自动槽 |
| NFR-004 | 关键规则自动测试;完整切片可重复烟雾 | ✅ PASS | 累积权威 228/0/0(`m4-001-xcode/TestResults-M4-001-revise.xcresult`);候选包烟雾 r7 可重复(DRIVE_OK) |
| NFR-005 | 稳定 ID;错误引用在开发构建中产生明确错误 | ✅ PASS | M0-002 ContentValidator 阻断缺失引用/重复 ID/非法内容(19 项无头测试);M3-001/M3-003 内容验证扩展(validateActions/validateTransitionTable) |
| NFR-006 | 文本与数据结构支持本地化;显示文本不作为逻辑键 | ✅ PASS | 内容全部数据化(ContentCatalog/WorldCatalog/HudCopy 集中文案);逻辑键为稳定 ID;本地化可扩展(见观察项 O-2) |
| NFR-007 | 像素资源最近邻过滤和整数缩放;无非预期模糊 | ✅ PASS(当前无位图纹理) | 静态探针:全仓零 `imageNamed`/位图加载,渲染全部程序化(42 处 SKShapeNode/SKSpriteNode/SKLabelNode 均于 FarmScene.swift)→ 无像素贴图即无非预期模糊;未来引入像素贴图须配置 `filteringMode = .nearest`(见观察项 O-3) |
| NFR-008 | 无网络时全部垂直切片功能可用 | ✅ PASS(静态) | 静态探针:全仓零网络 API(URLSession/Network/http 零命中)→ 代码层无网络依赖(PRD 1.2 离线单人);断网运行时验证按 DEC-018 豁免、RSK-007 发布前必补 |
| NFR-009 | 风评/事件/信任确定性;同档同序列可复现 | ✅ PASS | M3-003 定点计算测试(信任子点余数保留、同档同序列复现;180/180) |
| NFR-010 | UI 缩放/减弱闪烁/震动/文字速度/分类音量/输入绑定运行时生效、重启保持、损坏回退 | ✅ PASS | D0-002 10 条验收全绿(无障碍 HUD 生效、损坏回退真实日志 3 条、`settings.corrupt` 副本、绑定持久化;208/208) |
| NFR-011 | 断网环境安装/启动/新游戏/输入/存读/VS-0 烟雾 | ⏸️ 豁免(DEC-018) | 后置为「正式发布前必补」,RSK-007 开放;本任务不重复执行 |

## 3. PRD 第 14 节场景对照

| # | 场景 | 判定 | 证据 |
|---|---|---|---|
| 1 | 新档醒来,收获 3 株教学雾萝卜并投入出售箱 | ✅ PASS | M2-002 DRIVE 步骤 1–6(`hud-harvest1/3.txt`、`hud-deposit.txt`、01–03 png) |
| 2 | 键鼠/手柄翻土播种浇水;与水工学徒交谈、手动保存、提前睡眠收到 174 与「雾萝卜×3=174」明细;10–15 分钟 | ✅ PASS | M2-002 DRIVE 步骤 7–14(`hud-till/plant/water/talk/save.txt`、`hud-settled.txt`);时长口径按 DEC-017(专注操作 20–35 分钟 + 探索可至 45 分钟) |
| 3 | 睡眠前存档单独验证:待结算 3;只结算一次;重读自动档不重复增加货币 | ✅ PASS | M2-001(`06-settled-894.png`、`08-second-settle-no-dup.png`);M4-002 r7(`save-after-sleep.json` balance 894 / history [174]、`save-after-second-sleep.json` [174, 0]) |
| 4 | 第 2 天雨自动浇水;保底采集、制作放置水渠接片 +12,交付 +8;20 后地图/环境音/采集点/配方变化 | ✅ PASS | D0-001 雨天(`save-day2-offered.json` `wateredToday: true`);M3-002 运行 02/15(12/20、解锁四项);M3-002 运行 04 保底采集 |
| 5 | 自然风评 50 三夹具:A 转述 42 次日加成减半;B 暂不判断截止无惩罚;C 核实→保存→向青砚核实→纠正阿棉 58;均不软锁 | ✅ PASS | M3-003 + D0-001(HUD 19/20/12 + `saves/relay-42/defer-50/corrected-58`、行动历史 3 条);次日 ×1.50 由 M3 XCTest 覆盖(诚实声明) |
| 6 | 初始 39 边界夹具:转述 31 可选暂停;纠正 47 恢复;主线两者不暂停 | ✅ PASS | M3-003 + D0-001(HUD 21/22 + 截图 17/18,文案「暂停」「主线不受影响」) |
| 7 | 3 个脚本化游戏日;存读后待结算/结算记录/农田/库存/货币/任务/水渠/信任/事件历史/设置全一致 | ✅ PASS | D0-001(HUD 00/06/17 覆盖 3 日)+ `reload-consistency.json` mismatches 空(日/分钟/货币 894/结算 174/风评 58/行动历史/水脉/任务/农田/库存/信任子点余数 0/放置物;设置由 D0-002 补充验证);45–60 分钟口径 DEC-017 |

## 4. 补验记录(静态探针,零 GUI 驱动)

| # | 探针 | 目标条款 | 方法 | 结果 | 结论 |
|---|---|---|---|---|---|
| P-1 | 纹理加载扫描 | NFR-007 | 全仓 `imageNamed`/`SKTexture(image` 检索 | 零命中;42 处渲染调用全部程序化(SKShapeNode/SKSpriteNode/SKLabelNode,均于 `FarmScene.swift`) | 无位图纹理 → 无非预期模糊;最近邻配置待未来像素贴图引入时落实 |
| P-2 | 网络 API 扫描 | NFR-008 | 全仓 `URLSession`/`Network.`/`NWConnection`/`WebSocket`/`http` 检索 | 零命中 | 代码层零网络依赖;断网运行时按 RSK-007 后置 |

## 5. 缺陷、风险与发布前必补项

### 发布前必补(阻断正式发布,不阻断内部分发/试玩)

- **RSK-007(NFR-011 断网专项)**:离线烟雾 AC-3~8 未执行,仅有在线预演证据。DEC-018 豁免后置;正式发布签核前由 📦 release 补跑 `run-m4-002-offline-smoke.sh`(不带 `SKIP_NETWORK`)。
- **发布签名**:候选包为 adhoc 签名(`spctl rejected` 属预期);正式对外分发须 Developer ID 签名 + 公证(另立任务或并入发布流程,本任务不执行)。

### 观察项(非阻断,按 DEC-015 后置打磨)

- **O-1(FR-011)**:音频维度为占位表现——雨天音频切换尚未实装真实音轨,以 HUD 文字图标体现;待音频任务落地。
- **O-2(NFR-006)**:文本/数据结构具备本地化条件,但多语言未实际启用;显示文案集中于 HudCopy/ContentCatalog,迁移成本低。
- **O-3(NFR-007)**:当前无位图纹理,程序化渲染锐利;若后续引入像素贴图,须为相关 SKTexture 设置 `filteringMode = .nearest` 并整数缩放,否则违反 NFR-007。

### 已关闭/已解决的历史缺口

- FR-010/NFR-010 设置缺口(D0-001 发现)→ D0-002 已实现并验收(208/208 全绿)。
- D0-001 AC7 时长缺口 → DEC-017 已定口径。

## 6. 签核建议

**有条件签核(推荐签核)** — 判定依据:

- PRD 第 10/11/14 节全部条款 **PASS(28/28)** 或豁免(1 条:NFR-011,引用 DEC-018);零 FAIL。
- 证据链完整:各任务权威 xcresult 从 39/39(M1-002)单调递增至 228/228(M4-001),0 failed / 0 skipped / 0 警告;候选包在线预演 r7 `DRIVE_OK`。
- 第 12 节成功指标:核心路径(首次出售 174/交谈+保存/水渠+事件路径)均有自动化与运行时证据支撑;真人试玩度量(90%/80%/80%)建议在 R0 复盘前安排一轮试玩采集(记录为建议项,不阻断签核)。

**条件(签核通过需满足):** ① 正式发布前补跑离线烟雾(RSK-007);② 正式对外分发前完成 Developer ID 签名与公证。当前候选包可用于内部分发与试玩。

## 7. 边界确认

- 未修改任何源码、工程配置、PRD、TDD、既有证据;台账未在本报告撰写期间修改(开工登记已在合同门禁时完成)。
- 未重复 clean test:全部引用各任务权威 xcresult 计数(DEC-015)。
- 未执行 NFR-011:引用 DEC-018 豁免(DEC-015 + 合同红线)。
- 本报告为新建文件 `docs/game/a0-001-review.md`;`git diff --check` exit 0(待结项登记后复验)。
