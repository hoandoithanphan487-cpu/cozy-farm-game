# Codex 完整执行 Prompt：N-015 地图重排、全量美术接入与 HUD 返工

你正在仓库 `/Users/fengyifan/Documents/VibeCoding` 工作。

Product Owner 已接受独立审查建议，并通过 `DEC-035` 批准“地图重排”，拒绝“纯视觉缩小”。你的任务是完成 N-015 的 R5+B4+B5：先冻结视觉/拓扑合同，等待并接收 VSCode 基础门禁，再实施两图重排、五建筑六层接入、比例/HUD/水体返工及真实 App 证据。

## 一、必须先读

完整阅读：

1. `AGENTS.md`
2. `skills/cozy-farm-game-studio/SKILL.md`
3. skill 指定的全部角色、流程与类型参考
4. `skills/project-ledger/SKILL.md`
5. `docs/game/project-ledger.md` 中 N-015、DEC-031～DEC-035
6. `docs/game/n-015-full-art-hud-brief.md`
7. `docs/game/n-015-runtime-consumer-contract.md`
8. `docs/game/n-015-runtime-consumer-matrix.json`
9. `docs/game/n-015-building-layout-audit.md`
10. `docs/game/n-015-codex-runtime-handoff.md`
11. `docs/game/n-015-codex-runtime-review.md`
12. `docs/game/art-style-master-doc.md`
13. 五栋建筑六层资产的生成记录、manifest、尺寸和 provenance

保护用户已有脏工作树，不覆盖无关修改，不使用破坏性 Git 命令。

## 二、强制三阶段顺序

```text
阶段 A：Codex 视觉构图与拓扑合同
                ↓ 输出冻结合同后停止
阶段 B：VSCode 建验证器/负向门禁
                ↓ Codex 独立复核必须 APPROVED
阶段 C：Codex 生产实现与真实视觉证据
```

阶段 A 完成后必须停止并返回 `READY FOR VSCODE FOUNDATION`。在用户把 VSCode handoff 送回本任务前，不得提前修改生产地图、blocked cells、出生点、NPC 站位、出口或 B4 运行时消费者。

VSCode 未获独立 `APPROVED` 时，阶段 C 不得开始。

## 三、角色和防自签

- 阶段 A specialist：`🎨 art / 🌱 design`
- 阶段 B 接收 owner：`🧱 tech`
- 阶段 C specialist：`🎮 gameplay / 🎨 art`
- 阶段 C 部门质量：`🧱 tech`
- 最终跨部门门禁：`✨ ux / 🎭 content / 🛡️ quality`

同一执行者不能为自己的阶段 C 生产实现签发最终 `APPROVED`。实现完成后只能返回 `READY FOR DEPARTMENT REVIEW`；N-015 保持 `active / PENDING`，直到独立复核与 Product Owner 最终视觉验收完成。

## 四、文件所有权与冲突红线

Codex 独占：

- `docs/game/n-015-map-rearrangement-spec.md`
- `docs/game/n-015-map-layout-contract.json`
- 所有生产 Swift
- 所有 PNG、美术 catalog、运行时渲染、HUD、动画、地图、碰撞、存档兼容实现
- Codex 新增的生产实现测试、运行截图/录屏、性能和 handoff
- 消费者矩阵的最终确定性刷新
- 项目台账的阶段记录（不得自签 accepted）

VSCode 独占，Codex 不得修改：

- `scripts/validate-n015-map-layout-contract.py`
- `macos/CreekSprout/CreekSproutTests/N015MapLayoutContractTests.swift`
- `docs/game/n-015-vscode-map-foundation-handoff.md`
- `artifacts/integration/n-015-vscode-map-foundation/**`

若 VSCode 文件需要返工，把结论退回 VSCode；不得由 Codex 直接代改。

## 五、阶段 A：视觉构图和机器合同

### 5.1 先做只读审计

在任何生产改动前：

- 盘点两张地图现有尺寸、农田、出口、出生点、7 NPC、任务关键交互、采集节点、放置物与旧存档坐标。
- 盘点五建筑真实 footprint：5×4、5×4、5×2、3×2、3×2，以及各自 6 层 PNG。
- 检查 102 个现有消费者与 30 个 B4 blocked 资产。
- 复核独立 review 的 R1～R6：默认占位、角色倍率、水体堆叠、空旷构图、HUD 遮挡、合成证据。

### 5.2 设计目标

重排方案必须做到：

1. 两图在不看文字标签时即可区分“农场与农舍”和“溪岸集市”。
2. 木构农舍、铜闸水工坊完整落在农场；苔石埠头、种源棚、巡护亭完整落在集市。
3. 建筑 footprint、入口、交互格、屋顶遮挡和碰撞语义可信；玩家不能穿墙，也不能被入口阻挡。
4. 农田保持足够可玩空间；道路从出生点清晰连接农田、建筑和出口。
5. 集市 7 NPC 不堆叠、不堵主路，每人至少有一个可用交谈邻格。
6. 水体/水渠形成连续拓扑；每格选择正确语义，不把互斥 edge/corner 叠在同一格。
7. 默认画面完全移除“阻”“石阶”“采”等占位和调试地标文字；碰撞由真实环境表达。
8. 角色建立独立于 24 px 地砖的缩放合同；脚点、前后遮挡和世界比例可信。
9. HUD 在 960×640 与 1280×800 都有安全区；建筑卡仅临近/交互时出现并可收起。
10. 不改经济、配方、任务、对白、NPC/建筑/物品稳定 ID，不接入 N-014，不制作正式音乐。

地图可以扩展行列数，以容纳真实 footprint；不要为了保留 10×6 / 10×8 而再次挤压建筑。选择尺寸时以最小但完整、可读、可行走的垂直切片为准。

### 5.3 必须产出的两个冻结文件

`docs/game/n-015-map-rearrangement-spec.md` 必须包含：

- 两图 ASCII/表格坐标图和视觉层级图
- 地图尺寸、世界安全区、道路、水体、水渠、农田、建筑和前景区
- 五建筑 footprint、入口、交互格、屋顶遮挡格、地标锚点
- 出生点、出口、7 NPC、关键采集/任务目标位置
- 每个关键目标的可达性说明
- 两视口 HUD 安全区
- 旧存档迁移策略与不改 schema 声明
- 30 张 B4 文件的逐建筑六层映射
- 原创性与不复用受保护表达声明

`docs/game/n-015-map-layout-contract.json` 必须是同一方案的机器可读版本，至少包含：

- `schema_version`、`task`、`decision_id=DEC-035`
- maps、dimensions、terrain/water/path/canal cells
- buildings、footprints、doors、interaction cells、occlusion cells、layers
- blocked/walkable semantics
- spawns、exits、NPC positions、NPC approach cells
- farm area、gather/quest targets
- required reachability pairs
- HUD safe zones for 960×640 and 1280×800
- legacy bounds and deterministic save relocation rules
- immutable stable IDs and forbidden scope

两文件必须确定性排序、互相一致。完成后运行格式检查，只提交合同与设计证据，不改生产代码，然后返回：

```text
Outcome: READY FOR VSCODE FOUNDATION
Decision: DEC-035 map rearrangement
Production files changed in phase A: 0
Frozen contract SHA-256: ...
Next: run N-015-VSCODE-MAP-01 prompt
```

## 六、阶段 B：接收 VSCode 基础门禁

只有在用户提供 `docs/game/n-015-vscode-map-foundation-handoff.md` 后执行：

1. 复跑 Python contract-only validator。
2. 检查验证器是否只依赖冻结合同和权威输入。
3. 独立做至少四个临时负向突变：建筑重叠、入口 blocked、不可达、缺层。
4. 确认每次都 exit 1 且 stdout 是可解析 `FAIL` JSON。
5. 复跑定向和全量 XCTest。
6. 检查 VSCode 只修改其四类授权文件。
7. 检查没有 fallback 成功、算法复制、XCTSkip 或 ignored failure。

门禁只能返回：

- `APPROVED`：才可进入阶段 C。
- `REVISE`：停止，给 VSCode 精确返工项。
- `BLOCKED`：停止，说明外部阻断。

将结果追加到既有 VSCode review 或新建有界 review；不要修改 VSCode handoff。

## 七、阶段 C：生产实现

### 7.1 地图与存档兼容

- 按冻结合同修改 `WorldCatalog` 及必要内容 catalog。
- 更新地图尺寸、blocked cells、地标、出生点、出口、NPC 和任务关键位置。
- stable ID 不变，存档 schema 不变。
- 为旧存档位置实现确定性安全迁移：合法格保持不动；越界/新 blocked 格迁到合同规定的最近安全格，稳定 tie-break；不得清档。
- ContentValidator 必须验证建筑、门、NPC 交谈格和关键路径可达。

### 7.2 五建筑六层真实接入

- 把 30 张 B4 PNG 全部接入生产运行时，不只是测试、catalog 或展示卡。
- 每栋建筑使用 `base → structure → roof → detail → interaction → state_fx` 六层。
- base/structure/detail、roof 遮挡、interaction/state_fx 按合同分层；roof 可做前景遮挡，但不得错误影响碰撞。
- 高清 2048 图继续只用于展示卡；不能替代地图像素建筑。
- 玩家可从正常路径走到每栋入口并触发对应展示/交互反馈。

### 7.3 修复独立复核 R1～R6

- 删除默认“阻”“石阶”“采”、调试格文字与几何主视觉；仅 H 调试层可显示诊断信息。
- 修正角色独立缩放、NPC 站位、脚点与遮挡。
- 重写水体语义 resolver，不把多个互斥边角叠在同一格；旧“uses all assets”测试必须改为验证拓扑正确性。
- 完成两图连续地形、道路、水岸、农田、建筑、环境边界和前景构图。
- 重构 HUD 安全区、toast 优先级、建筑卡触发/收起和 960×640 适配。
- 保留现有合成快照作为回归，但新增真实 App 启动与连续交互证据。

### 7.4 消费者矩阵

- 实现完成后运行现有确定性 refresh，把 30 B4 从 `blocked` 更新为有真实生产消费者的 `integrated`。
- 最终目标为 132 integrated、0 blocked、0 planned、0 missing、0 extra。
- 逐文件 provenance、哈希、尺寸和 PNG 完整性保持通过。

### 7.5 测试

除已有回归外，新增生产实现测试覆盖：

- live `WorldCatalog` 与冻结 JSON 合同逐字段一致
- 五 footprint 无重叠/越界，入口和交互格合法
- 所有 required reachability pairs BFS 可达
- 7 NPC 有交谈格且不堵出口/门
- 旧存档合法坐标保持、不合法坐标确定迁移、重复加载稳定
- 30 建筑层真实生产节点存在、层序和 zPosition 正确
- 屋顶前后遮挡与碰撞分离
- 水体单格不包含互斥语义
- 默认场景节点/可访问文本中不存在禁止占位符
- 角色在两个视口的目标高度与覆盖范围合格
- HUD 安全区与建筑卡行为
- reduced motion、FX 清理、输入、存读、切图、农耕、出售、加工不回归

不得删除、放宽或跳过既有测试来换取通过。

## 八、真实视觉与性能证据

必须从同一候选构建取得：

1. 960×640 农场默认 HUD
2. 1280×800 农场全景
3. 1280×800 集市全景
4. 五栋建筑各自入口/遮挡/展示触发
5. 7 NPC 不堆叠的集市场景
6. H 层关闭与开启对照
7. 一段真实 App 连续录屏或逐帧序列：启动新档 → 四向移动 → 耕地 → 浇水 → 收获/FX → 进入建筑触发区 → 切到集市 → 与 NPC 交谈 → H 开关

证据不能只靠 DEBUG 注入、离屏 SKView 或把静态 SpriteKit 与 SwiftUI 图片后期合成。自动快照可以保留，但必须明确标为补充证据。

性能继续要求帧工作、地图切换、RSS、FX 清理和 reduced motion 不回归。

## 九、最终验证

至少运行：

1. `python3 scripts/validate-n015-map-layout-contract.py --contract-only`
2. live contract implementation tests
3. `python3 scripts/validate-n015-consumer-matrix.py`
4. `python3 scripts/audit-runtime-art-integration.py`
5. N-015 定向 XCTest
6. 全量 XCTest，权威 xcresult 计数，0 failed、0 skipped
7. `git diff --check`
8. 文件边界与禁止范围审计
9. 两视口截图像素尺寸、非空和实际 App 来源核验

若任何一项失败，不得宣称完成。

## 十、交付

产出新的 Codex handoff 与隔离 evidence，包含：

- 阶段 A 合同 SHA-256
- VSCode 基础包独立接收结论
- 132 项最终消费者汇总
- 地图前后坐标与存档迁移说明
- 五建筑 30 层逐项运行时消费者
- 测试和性能权威结果
- 真实 App 截图/录屏清单
- 文件边界
- 未改经济、配方、任务、对白、稳定 ID、schema、N-014 和正式音频的声明

最终只能返回：

```text
Outcome: READY FOR DEPARTMENT REVIEW | REVISE | BLOCKED
Runtime assets: X integrated / X blocked
Map contract: PASS | FAIL
VSCode foundation gate: APPROVED | REVISE | BLOCKED
Focused tests: X/X
Full tests: X/X, failed 0, skipped 0
Real app evidence: PASS | FAIL
File boundary: PASS | FAIL
N-015 ledger: active / PENDING
```

不要自签 `APPROVED`，不要把自动测试全绿等同于视觉验收，不要提前启动 N-016 正式音乐。
