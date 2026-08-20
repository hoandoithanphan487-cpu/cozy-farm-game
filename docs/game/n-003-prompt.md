# N-003 Cursor 开工 Prompt（粘贴给 Cursor / Codex）— 管线部分

> 本文件是 `docs/game/n-003-brief.md` 的执行版（管线范围）。Cursor 负责**位图渲染管线 + 渲染接入**；资产图片由资产生成器（`scripts/generate-pixel-assets.py`，程序化占位）与 Product Owner 概念图协作提供（PO 图就绪后仅换图，本任务不等待）。完成后经 🛡️ quality 独立验收（Hermes），不得自行 APPROVED。**本任务不改资产文件、不改领域/经济/存档语义。**

## 1. 任务一句话

在 CreekSprout（Xcode + Swift + SpriteKit）实现**位图渲染管线**：从 `macos/CreekSprout/CreekSprout/Assets/` 加载 PNG 贴图（`SKTexture` + `filteringMode = .nearest` + 整数缩放 + 缓存），把 N-001 的程序化角色/作物/地块呈现替换为贴图渲染（贴图缺失时回退程序化）；落实 NFR-007（最近邻过滤实测）。当前 `Assets/` 已有 11 个程序化 PNG 可直接用，Product Owner 概念图就绪后只换图不换代码。

## 2. 当前状态（独立核实过的事实，证据路径见括号）

- 工程 `macos/CreekSprout/CreekSprout.xcodeproj`，scheme `CreekSprout`，macOS arm64 / Xcode 26.6；参考设备 M4 MacBook Air / 16 GB / macOS 26.5.2。
- 单元回归权威基线 **228/228 passed、0 failed、0 skipped、0 警告**（`artifacts/integration/m4-001-xcode/TestResults-M4-001-revise.xcresult`）+ N-001 新增 8 项（`artifacts/integration/n-001-xcode/TestResults-N-001-new-tests.xcresult`，8 passed）。本任务**不重复 clean test**（DEC-015），引用两基线；以运行时烟雾为决定性回归证据。
- N-001 已 `accepted / APPROVED`：`Presentation/CharacterVisualCatalog.swift`（7 NPC + 玩家主题色/发型，`CharacterVisualDefinition`）、`Presentation/CharacterVisualNode.swift`（SKShapeNode 程序化角色 + 动效）、`Presentation/CharacterVisualDefinition.swift`、`Audio/`（3 文件）、`FarmScene.swift` 表现段接线。角色稳定 ID 在 `Content/NpcDefinition.swift`（`waterApprentice`/`seedSteward`/`creekWarden`/`neighborHearsay`/`neighborStoryteller`/`neighborEvidence`/`neighborConsensus`）。
- `Assets/` 已存在 11 个程序化 PNG + `generation-log.md`（由 `scripts/generate-pixel-assets.py` 生成，本任务**只读**）：`char_water_apprentice.png`/`char_seed_steward.png`/`char_creek_warden.png`（32×48 RGBA）、`crop_mist_radish.png`/`crop_stream_leaf.png`/`crop_amber_bean.png`/`crop_bell_berry.png`/`crop_honey_melon.png`（32×32）、`tile_grass.png`/`tile_tilled.png`/`tile_water_edge.png`（24×24）。
- PRD 7.1：地块 24×24、角色 32×48、16:9 内部分辨率整数缩放、最近邻；NFR-007：像素资源最近邻过滤 + 整数缩放，无非预期模糊。
- 合同 `docs/game/n-003-brief.md`（10 条 AC）；门禁 🧱 tech + 🌱 design 双 `APPROVED`；任务 `active / PENDING`（台账 N-003 行）。资产生成流程已调整：PO 概念图协作（`docs/game/n-003-character-roster.md`），本任务不等待资产，用现有 PNG 打通管线。
- 工作树含此前各任务历史未提交修改（正常）；本任务不得 `git commit`。

## 3. 实现边界

### 必须做（In scope）

1. **贴图管线**（`Presentation/` 新增，如 `PixelAssetStore.swift`）：
   - 从 `Assets/` 目录加载 PNG → `SKTexture`（`SKTexture(imageNamed:)` 需将 `Assets/` 加入资源 bundle，或 `SKTexture(image:)` 从文件加载；实现者选定并声明）。
   - **`filteringMode = .nearest`**（NFR-007 关键）；**整数缩放**（PRD 7.1：按 24/32/48 的整数倍放置，不出现半像素插值）。
   - 缓存：同一资产只建一次纹理（字典缓存），重复请求返回同一实例。
   - 缺失容错：贴图缺失/加载失败时返回 nil，调用方回退程序化呈现（不崩溃、有日志）。
2. **渲染接入**：
   - 角色：`CharacterVisualNode` 增加贴图模式——有 `Assets/char_<id>.png` 时用 `SKSpriteNode(texture:)`，无则回退现有 SKShapeNode 程序化绘制；NPC ID → 文件名映射表（`char_water_apprentice.png` 等，与 `generation-log.md` 命名一致）。
   - 作物：成熟态用 `crop_<id>.png`（生长阶段可暂用程序化/仅成熟态贴图，简化并声明）。
   - 地块：`tile_grass/tilled/water_edge.png` 用于对应地形渲染（可先行只替换草地/耕地底色块）。
   - 动效（行走摆幅/收获/对话）保留：贴图模式下的动效用 SKAction 位移/缩放实现（与程序化等价），不做帧动画（帧动画属全量扩量）。
3. **测试**（新增，随源码交付）：
   - 管线：`filteringMode == .nearest` 断言；缓存命中（同 ID 同实例）；缺失 ID 回退 nil。
   - 资产完整性：`Assets/` 11 个文件可加载为纹理、尺寸符合规范（32×48/32×32/24×24）。
   - NFR-007 实测断言：放大整数倍后无插值模糊（可对纹理进行放大采样断言像素锐利，或提供放大验证图）。
4. **证据**：渲染截图（贴图角色/作物/地块在场景中）+ NFR-007 放大验证图（原图 vs 放大 8×，像素块锐利）。

### 禁止做（红线，Do Not）

- ❌ 不改 `ContentID.swift`/`ContentValidator.swift` 稳定 ID 与校验；不改经济/存档 schema/领域逻辑（`Domain/`、`Persistence/`）。
- ❌ 不改 `Audio/`（N-001 已验收）；不改 `ContentView.swift` 输入逻辑。
- ❌ **不改 `Assets/` 任何 PNG 与 `generation-log.md`**（资产由生成器/PO 维护；本任务只读）。
- ❌ 不做帧动画、不做全量资产扩量（4 邻居贴图、集市地图、物品图标——全量扩量另立任务）。
- ❌ 不改 PRD/TDD/台账；不自我 `APPROVED`；不 `git commit`。
- ❌ 不复制任何受保护表达（本任务无资产生成，仅加载既有文件）。

## 4. 可观察验收（对应 brief AC 的管线部分）

1. **管线加载**：`Assets/` 全部 11 个 PNG 可加载为 `SKTexture`（测试断言）。
2. **NFR-007 实测**：`filteringMode == .nearest`；整数放大后像素锐利（放大验证图）。
3. **缓存**：同资产重复请求返回同一纹理实例（测试断言）。
4. **回退**：缺失贴图 ID 回退程序化渲染，不崩溃、有日志（测试 + 运行时）。
5. **角色接入**：场景中 3 职能角色显示贴图（运行时截图，NPC 名/「谈」角标不回归）。
6. **作物/地块接入**：成熟作物贴图 + 地块贴图生效（运行时截图）。
7. **动效保留**：贴图模式下行走/收获/对话动效可见（截图序列）。
8. **回归**：引用 228/0/0 + N-001 8/8 基线；运行时烟雾主路径（新游戏→收获→投入→日结→对话→切图→雨天）不回归。
9. **红线**：内容 ID/经济/schema/领域/Audio 零修改；`Assets/` 零修改；`git diff --check` exit 0。
10. **证据包**：截图 + NFR-007 放大验证 + 新增测试计数，落盘 `artifacts/integration/n-003-pixel/`。

## 5. 一条完整烟雾路径（锁定，逐项取证）

管线实现 → 资产加载测试（11 文件）→ 渲染接入（角色/作物/地块）→ 新游戏（贴图角色/地块截图）→ 收获 3 株（贴图作物 + 收获音效不回归）→ 对话（表情/角标不回归）→ 切图（集市）→ 放大验证（NFR-007 图）→ 证据包落盘。

## 6. 交付格式（放进 `artifacts/integration/n-003-pixel/`）

1. `cursor-handoff.md`：outcome、变更文件清单（每文件一句 + 理由）、验收映射（10 条逐条 → 证据）、已知限制、下一负责人。
2. 运行时截图（角色/作物/地块贴图）+ NFR-007 放大验证图。
3. 新增测试文件与计数（断言要点一句话/测试）。
4. `git diff --check` exit 0 输出；未修改文件清单（内容 ID/经济/schema/领域/Audio/Assets/PRD/TDD/台账）。
5. 决策与假设：纹理加载方式（imageNamed vs 文件加载）、Assets 资源 bundle 配置、地块替换范围、已知妥协。
6. 风险与遗留：全量扩量衔接建议、PO 概念图换图说明（只换 PNG 不换代码）。

**不要求**：重复 clean test、长报告、冗余截图、非阻断打磨。

## 7. 回复格式（必须逐项确认，缺项视为未完成）

```
A. 范围确认：in scope 与红线逐条「确认 / 不确认」；不确认项说明原因。
B. 基线核验：228/0/0 + N-001 8/8 已引用；确认不重复 clean test。
C. 交付清单：第 6 节各文件路径 + 状态。
D. 管线结果：加载/缓存/回退测试计数；NFR-007 断言与放大验证图路径。
E. 接入结果：角色/作物/地块贴图渲染截图；动效保留证据。
F. 验收映射：10 条逐条 → 证据文件；未达标项声明 REVISE。
G. 红线声明：内容 ID/经济/schema/领域/Audio/Assets 零修改；未改台账；`git diff --check` exit 0。
H. 下一负责人：🛡️ quality（Hermes）独立验收；资产生成由 PO 概念图协作（不等待）。
```

完成后将本文件与 `docs/game/n-003-brief.md` 一并交给 🛡️ quality 门禁。
