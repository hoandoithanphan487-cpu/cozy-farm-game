# N-008 高分辨率立绘规格、资产清单与工具预检

> 版本：`r2`（2026-08-21）。`r1` 已由 🛡️ quality 签发 `APPROVED`，快照保存在 `artifacts/integration/n-008-brief/r1-archive/`，不删除、不改写。
> `r2` 由 Product Owner 明确 `REVISE` 后授权返工，只补齐三处缺口：逐人主题色/发型轮廓/表情方向、源图→处理图→运行时图的完整分层、工具预检的 SHA-256 与本机 PNG 校验能力。

## 任务合同

- Task ID：`N-008`
- 阶段：`N1`
- 专项负责人：🎬 `director`
- 部门质量负责人：🛡️ `quality`（Hermes，跨部门独立复核）
- 咨询：🎨 `art`、🎭 `content`、🧱 `tech`
- 依赖：`N-006 = accepted / APPROVED`；Product Owner 已明确“真正的高分辨率立绘”范围；`N-007 = revise / REVISE`
- 本文件不修改 `docs/game/project-ledger.md`；台账状态由 Product Owner 或 Codex 登记。

## 1. 玩家可见结果

玩家走到 NPC 面前触发对话时，对话卡与角色信息区显示一张清晰、原创、光照统一的高分辨率全身立绘；从头顶到鞋底、手部、服装下摆与职业道具全部可见，不再是被拉大的模糊像素方块或半身裁切。地图上的角色移动、碰撞与比例继续使用原生 `32×48` 运行时 sprite，两套资源互不替代。

N-008 本身不产出任何图像，只锁定合同与工具；玩家看到立绘发生在 N-009 生产、N-010 接入之后。

## 2. 角色清单与稳定 ID

范围固定为 8 名，不增不减；不含 `shopkeeper` 预留位，不含 N-005 猫店候选。

| # | 稳定 ID | slug | 显示名 | 来源校验 |
|---:|---|---|---|---|
| 1 | `brookseed.player.sprout` | `player` | 新芽农人 | `PlayerVisualID.sprout`（表现层 ID，非 Content ID，不入存档） |
| 2 | `brookseed.npc.water_apprentice` | `water_apprentice` | 水工学徒 | `ContentID.waterApprentice` |
| 3 | `brookseed.npc.seed_steward` | `seed_steward` | 种源管理员 | `ContentID.seedSteward` |
| 4 | `brookseed.npc.creek_warden` | `creek_warden` | 溪岸巡护员 | `ContentID.creekWarden` |
| 5 | `brookseed.npc.neighbor_hearsay` | `neighbor_hearsay` | 涧麦婶 | `ContentID.neighborHearsay` |
| 6 | `brookseed.npc.neighbor_storyteller` | `neighbor_storyteller` | 石灯 | `ContentID.neighborStoryteller` |
| 7 | `brookseed.npc.neighbor_evidence` | `neighbor_evidence` | 青砚 | `ContentID.neighborEvidence` |
| 8 | `brookseed.npc.neighbor_consensus` | `neighbor_consensus` | 絮宁 | `ContentID.neighborConsensus` |

稳定 ID 不随美术版本变化；文件名带 `_v01` 版本号，ID 不带。

## 3. 逐人视觉规格

主题色、描边色、发色取自 `macos/CreekSprout/CreekSprout/Presentation/CharacterVisualCatalog.swift` 的既有定义（0–1 浮点已换算为 8 位十六进制并四舍五入）；发型轮廓取自 `HairSilhouette` 枚举。立绘必须与运行时角色是同一个人，不得另立配色。

| slug | 职业识别 | 主题色 | 描边色 | 发色 | 发型/轮廓（`HairSilhouette`） | 表情方向 | 服装与道具重点 |
|---|---|---|---|---|---|---|---|
| `player` | 新芽农人；玩家化身 | `#EDC76B` 木蜜衣 | `#387361` 苔边 | `#6B4729` 湿土发 | `mossTuft` 苔簇短发，顶部有一撮不规则翘起 | 平静专注，微微上扬的嘴角；不夸张 | 木蜜色短打上衣、苔绿滚边、手边或肩上一把锄头 |
| `water_apprentice` | 水渠引导与铜闸维护 | `#479EAD` 雾蓝工衣 | `#1F5261` 深渠边 | `#383D47` 短发 | `copperClipCrop` 利落短发，鬓角带一枚铜夹 | 少年感、认真略拘谨，眼神向前 | 雾蓝工装、腰间青铜水闸扳手、随身小木铲 |
| `seed_steward` | 种子与作物保管 | `#578F52` 苔绿罩衫 | `#294D24` 叶荫边 | `#8C612E` 束髻 | `seedBun` 麦褐束髻，发髻插一根木签 | 温和微笑，眼角柔和 | 苔绿罩衫、胸前种子布袋、手捧浅种碟 |
| `creek_warden` | 溪岸巡护与采集生态 | `#7A6147` 湿石褐 | `#47331F` 铜闸边 | `#4D473D` 巡护帽 | `wardenCap` 宽檐巡护帽压住短发，帽侧有铜扣 | 沉稳平静，视线略微下压 | 湿石褐外套、肩背渔网、腰挂木桶 |
| `neighbor_hearsay` | 邻居·消息灵通 | `#C79447` 麦蜜围裙 | `#754D1A` 麦秆边 | `#61381F` 盘髻 | `coiledKnot` 低位盘髻，鬓边散出细碎发丝 | 热心健谈，眉眼舒展、嘴部微张似正说话 | 麦蜜色围裙、臂弯挎菜篮 |
| `neighbor_storyteller` | 邻居·爱讲夸张故事 | `#D16B38` 铜橙外袍 | `#7A2E14` 灯芯边 | `#2E241F` 灯穗发 | `lampSpike` 竖起的灯穗状发簇，轮廓有尖角节奏 | 表情夸张外放，眉毛高挑 | 铜橙外袍、随身小石灯、一只手抬起做讲述手势 |
| `neighbor_evidence` | 邻居·重证据 | `#526685` 砚青长衫 | `#242E47` 墨边 | `#29292E` 侧分 | `inkPart` 整齐侧分，额前一缕压平 | 严谨审视，眉头轻收，嘴角平直 | 砚青长衫、腋下或手中夹一卷纸/竹简 |
| `neighbor_consensus` | 邻居·随共识更新 | `#9E85AD` 柳絮衫 | `#5C4770` 暮紫边 | `#755C47` 垂发 | `willowFall` 柔顺垂发过肩，轮廓无硬角 | 柔和含蓄，视线略偏、不直视 | 柳絮色浅衫、一只手轻抚衣襟 |

三条硬约束：

1. **八人不得只靠换色区分。** 发型轮廓、肩线宽窄、道具和姿态必须各不相同；灰度化后仍能分辨是谁。
2. **表情方向是首轮唯一表情。** 每人首轮只产 1 张对话基线立绘，不做喜/怒/惊多表情组；多表情属未来任务，不在 N-009。
3. **主题色是识别锚点，不是唯一用色。** 立绘允许在同一色相内做明暗与材质过渡，但不得引入会改变角色识别的新色相，也不得让主题色被背光或滤镜吃掉。整体色彩关系服从 `docs/game/art-style-master-doc.md` 第 3 节的溪谷色票族与「暗部不用纯黑」规则。

## 4. 立绘类型

- 构图：正面或轻微三分之四的**完整全身像**；头顶到鞋底全部可见，双脚完整落在透明画布内，人物主体居中。禁止半身、头肩或膝上裁切。
- 背景：完全透明；不带场景、地板、投影底板或装饰边框。
- 禁止内容：文字、字幕、签名、水印、Logo、透明棋盘格烘焙、UI 框、边角标签、拼图式多角色同框。
- 不直接复用 C0：现有 `Assets/ConceptArt/concept_character_*_v01.png` 是**全身 C0 概念图**（实测 `1024×1536`，且主体整体半透明、透明像素 RGB 未清零），只能作为造型与配色参考。N-009 必须重新生成高分辨率全身构图，并做边缘清理，不得改名、裁剪或放大 C0 充数。另注：C0 只覆盖 7 名 NPC，`player` 没有 C0，必须原创新出。
- 原创：不得描摹、图生图改色或近似任何既有作品的角色、发型服装组合、构图与画师风格。

## 5. 源图 → 处理图 → 运行时图分层

| 层 | 用途 | 规格与位置 | 归属任务 |
|---|---|---|---|
| C0 概念图 | 造型方向与配色参考，不是成品立绘 | 既有 `macos/CreekSprout/CreekSprout/Assets/ConceptArt/`、`artifacts/art-style/`；全身、1024 级 | 已有，只读 |
| 立绘源图 | 生成器直出的原始产物，保留全部像素信息 | 生成器原生方形 RGBA PNG（当前路径实测 `1254×1254`），`artifacts/integration/n-009-portraits/source/` | N-009 生产 |
| 立绘处理图 | 源图经透明边缘清理/透明像素 RGB 清零后的交付件；N-010 只读取这一层 | 同尺寸同比例 RGBA PNG，`artifacts/integration/n-009-portraits/processed/` | N-009 生产 |
| 运行时像素角色 | 地图移动、碰撞、比例、行为 | 原生 `32×48`，`macos/CreekSprout/CreekSprout/Assets/char_*.png`，N-006 已验收 | 禁止在 N-008/N-009 改动 |
| N-010 展示资源 | 对话卡/角色信息展示实际加载的资源 | 由处理图派生，尺寸与目录由 N-010 决定；不回写源图与处理图 | N-010 生成并接入 |

处理图与源图必须是**两个文件**。即使某张图无需清理，也要产出处理图并在记录中写明 `cleanup=no-op` 与两者哈希关系，不允许用一个文件同时充当两层。

**红线：** 严禁把 `32×48` 运行时图插值放大、锐化或加滤镜冒充高分辨率立绘；严禁把 C0 概念图改名成源图或展示资源。

## 6. 推荐目标尺寸

| 层 | 尺寸 | 理由 |
|---|---|---|
| 源图 | 生成器原生方形 RGBA，当前路径 `1254×1254` | 保留生成器原始输出，不伪造原生分辨率；DEC-025 允许在处理层导出 2048 |
| 交付 PNG（处理图） | `2048×2048`，`1:1` 统一长宽比 | 八人长宽比必须一致，N-010 才能用同一套布局；不得逐人换比例 |
| 运行时显示 | 保持源图原始比例等比缩放 | 由 N-010 按对话卡可用区域等比适配，**不得强制缩放到 `32×48`**，不得非等比拉伸 |

人物在画布中的占比按「头顶到画布上沿留白约 6%–10%，鞋底到画布下沿留白约 5%–10%，全身高度占画布约 80%–88%」控制，避免八人大小不一。四边留白必须保留，不得裁到头发、道具、手部、衣摆、腿部或鞋底；双脚必须清晰可见。

## 7. 命名规则

| 产物 | 命名 |
|---|---|
| 源图 | `portrait_<slug>_source_v01.png` |
| 处理图 | `portrait_<slug>_clean_v01.png` |
| 生成记录 | `portrait_<slug>_generation-record-v01.md` |
| 联系表 | `n-009-contact-sheet-v01.png` |
| 清单 | `manifest.json` |

全小写 snake_case；`<slug>` 严格取第 2 节的 8 个值。版本升级新增文件，不覆盖已批准版本。

## 8. 目录规则

```
artifacts/integration/n-009-portraits/
├── source/          portrait_<slug>_source_v01.png            × 8
├── processed/       portrait_<slug>_clean_v01.png             × 8
├── records/         portrait_<slug>_generation-record-v01.md  × 8
├── evidence/        alpha/尺寸/bbox 检查输出、命令原始日志
├── contact-sheet/   n-009-contact-sheet-v01.png
└── manifest.json
```

N-009 只允许写这一棵子树。禁止写 `macos/`、`docs/game/project-ledger.md`、PRD/TDD 及其他任务文件。

## 9. Alpha、透明边缘、尺寸、色彩与文件格式要求

- 格式：PNG，8 位/通道，颜色类型 6（RGBA）。禁止 JPG、索引色、16 位、CMYK。
- 尺寸：处理图必须实测 `2048×2048`；八人一致。
- Alpha（可测阈值）：背景 `alpha == 0`；人物主体内部 `alpha == 255`，且完全不透明像素数必须大于 0。仅允许人物**轮廓过渡带**取 1–254 的中间值（这是高分辨率插画与像素资产的关键区别），但不得出现整体半透明蒙层、白边、黑边或成片脏 halo。
  > 实测依据：既有 C0 `concept_character_water_apprentice_v01.png` 的 alpha 最大值仅 `254`、`opaque=0`，即主体整体半透明；这是它不能直接复用为立绘的硬性原因之一。详见 `artifacts/integration/n-008-brief/tool-preflight.md` 第 3 节。
- 透明像素清零：所有 `alpha == 0` 的像素其 RGB 必须为 `(0,0,0)`，避免不同渲染器出现彩边。
- 边界框：由 alpha 计算非透明 bbox 并记录；bbox 不得触到画布任一边（证明留白未被裁切）。
- 色彩：主题色/描边色/发色锚定第 3 节表格；整体服从 Master Doc 第 3 节色票族与「暗部用环境综合色、不用纯黑」的规则。
- 禁止：棋盘格烘焙、外框、文字、水印、噪点滤镜、彩色描边光晕。

## 10. 每名角色的 generation record 要求

每人一份 `portrait_<slug>_generation-record-v01.md`，必须包含：

1. 稳定 ID、slug、显示名；
2. 完整生成 prompt 原文与 prompt 版本号；
3. 生成工具与版本、生成日期、迭代次数与最终选用理由；
4. 源图文件名 + SHA-256；处理图文件名 + SHA-256；
5. 处理步骤逐条（去背/边缘清理/透明 RGB 清零/无操作），含所用命令；`cleanup=no-op` 亦须显式声明；
6. 实测尺寸、颜色类型、位深、alpha 直方图摘要、非透明 bbox；
7. 与第 3 节的逐项比对：主题色、描边色、发色、发型轮廓、表情方向、服装道具是否命中；
8. 原创性自查结论与理由；
9. 状态字段：`planned → generated → alpha_checked → boundary_checked → content_reviewed → po_pending`。

八人共 8 份，不得用一张汇总表替代逐人记录。

## 11. 原创性审查要求

- 逐人书面结论，不接受整批一句话通过。
- 检查项：是否描摹或图生图改色既有作品；发型+服装+道具组合是否与任何既有农场/生活模拟游戏角色可识别近似；是否出现外部作品名、画师名、Logo、品牌标识；配色关系是否为本项目独立体系。
- 任一项存疑即退回重设计，不允许「改个颜色再交」。
- 审查人：🎭 `content`。生成者不得审查自己的原创性结论。

## 12. Product Owner 视觉验收要求

- 交付形式：8 张全身处理图的 1× 单图 + 一张八人联系表，供一次性目检。
- 验收口径：每人从头顶到鞋底完整可见、双脚未裁切、人物清晰不糊、八人可区分、职业一眼可辨、光照与色彩统一、无文字/水印/棋盘格、透明边缘干净。
- PO 可逐人给出通过或返工，不要求整批同进退。
- **任何技术门禁都不等于 PO 视觉批准。** 🛡️ quality 的 `APPROVED` 只覆盖文件、证据与合同符合性；🎭 content 的 `APPROVED` 只覆盖内容与原创性。

## 13. N-009 的输入、输出、禁止事项与完成定义

**输入：** 本文件；`docs/game/n-008-prompt.md`；`docs/game/art-style-master-doc.md`；`CharacterVisualCatalog.swift` 的既有主题色；`Assets/ConceptArt/` 的 7 张 C0（只读参考）；`artifacts/integration/n-008-brief/tool-preflight.md` 的工具结论。

**输出：** 8 张源图、8 张处理图、8 份 generation record、evidence 检查输出、1 张联系表、1 份 manifest.json。

**禁止：** 改 Swift 源码；写 `macos/CreekSprout/CreekSprout/Assets/`；改 Content ID、地图、存档 schema、经济参数、玩法；改 `docs/game/project-ledger.md`、PRD/TDD 与 N-007/N-010～N-012 文件；放大 `32×48` 冒充立绘；把 C0 改名交付；自行安装软件；自签 `APPROVED`。

**完成定义：** 上述输出齐备且逐项可复核 → 🎭 `content` 返回 `APPROVED` → Product Owner 视觉验收通过 → 🛡️ `quality` 独立复核文件与证据 `APPROVED`。三者缺一，N-009 不得视为完成，N-010 不得启动。

## 14. N-010 的接入前提

N-010 只有在以下条件全部成立后才能开始：

1. N-009 在台账中为 `accepted / APPROVED`；
2. 8 张处理图齐备、尺寸与长宽比一致、manifest 哈希可校验；
3. Product Owner 视觉验收已记录；
4. N-010 从 `processed/` 取图，另建独立 presentation 资源层，不回写 N-009 产物，不改动 `Assets/` 内的 `32×48` 运行时图；
5. 展示尺寸、裁切窗口、等比缩放算法与无立绘时的安全回退，均由 N-010 的 🧱 `tech` 合同定义，本文件不预先承诺。

## 15. 门禁与风险

- N-008：🎬 director 交付 → 🛡️ quality（Hermes）独立复核 → 由 Product Owner/Codex 登记台账。director 不自签 `APPROVED`。
- 风险 R-1：本机缺 Pillow/OpenCV/ImageMagick/pngcheck。已确认可用替代路径见 `artifacts/integration/n-008-brief/tool-preflight.md`；若 N-009 实际执行中替代路径不足，先提交缺口与安装理由，不擅自安装。
- 风险 R-2：高分辨率插画的边缘抗锯齿与像素资产的「无半透明」规则冲突。本文件第 9 节已明确对立绘放宽轮廓抗锯齿、但禁止整体半透明与脏 halo；该放宽仅适用于立绘层，不适用于 `Assets/` 内的运行时像素资产。
- 风险 R-3：`docs/game/daily-ledger-2026-08-21.md` 与 `docs/game/project-ledger.md` 对 N-008 的状态记载不一致。本文件不修改台账，冲突留待 Product Owner/Codex 裁决。
