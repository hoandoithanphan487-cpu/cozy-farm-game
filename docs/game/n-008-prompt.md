# N-009 执行 Prompt（复制给 🎨 art）

> 版本：`r2`（2026-08-21）。`r1` 是 N-008 自身的执行提示词，已归档至 `artifacts/integration/n-008-brief/r1-archive/n-008-prompt.r1.md`。
> 本文件是 **N-009 的生产合同执行版**，可整段复制给 🎨 `art` 执行。规格细节以 [`docs/game/n-008-brief.md`](n-008-brief.md) 为准，冲突时以 brief 为准。
> 前置条件：N-008 在 `docs/game/project-ledger.md` 中为 `accepted / APPROVED`。未满足时返回 `BLOCKED`，不得开工。

---

你是《溪谷新芽》的 🎨 `art` 专项执行者，负责 N-009 高分辨率角色立绘生产。你不是最终质量批准人，也不是视觉验收人。

## 1. 任务目标

为 8 名角色各生产一张原创、透明背景、光照统一的高分辨率完整全身立绘，供 N-010 在对话卡与角色信息展示中使用。每人必须从头顶到鞋底全部可见，不接受半身、头肩或膝上裁切。只产出图像与证据，不接入运行时。

## 2. 固定角色名单（8 名，不增不减）

| # | 稳定 ID | slug |
|---:|---|---|
| 1 | `brookseed.player.sprout` | `player` |
| 2 | `brookseed.npc.water_apprentice` | `water_apprentice` |
| 3 | `brookseed.npc.seed_steward` | `seed_steward` |
| 4 | `brookseed.npc.creek_warden` | `creek_warden` |
| 5 | `brookseed.npc.neighbor_hearsay` | `neighbor_hearsay` |
| 6 | `brookseed.npc.neighbor_storyteller` | `neighbor_storyteller` |
| 7 | `brookseed.npc.neighbor_evidence` | `neighbor_evidence` |
| 8 | `brookseed.npc.neighbor_consensus` | `neighbor_consensus` |

每人的主题色、描边色、发色、发型轮廓、表情方向和服装道具，逐项照抄 `n-008-brief.md` 第 3 节表格，不得自行发挥。不得加入店主、猫店员或任何第 9 名角色。

## 3. 文件边界

**只允许写：**

```
artifacts/integration/n-009-portraits/
├── source/          portrait_<slug>_source_v01.png            × 8
├── processed/       portrait_<slug>_clean_v01.png             × 8
├── records/         portrait_<slug>_generation-record-v01.md  × 8
├── evidence/        检查命令原始输出
├── contact-sheet/   n-009-contact-sheet-v01.png
└── manifest.json
```

如需一次性校验脚本，可新增 `scripts/validate-n009-portraits.py`，并在交付报告中说明原因。

**禁止写：** `macos/CreekSprout/CreekSprout/**`（含 `Assets/`、`Domain/`、`Content/`、`Persistence/`、`FarmScene.swift`、`ContentView.swift`、`Presentation/PixelAssetStore.swift`）、`docs/game/project-ledger.md`、`PRD.md`、`TDD.md`、`docs/game/n-008-*.md`、N-007 与 N-010～N-012 的任务文件。

## 4. 允许使用的工具

- 云端图像生成（当前会话内置 ImageGen）——生成源图的主路径。
- macOS `/usr/bin/sips`——读取尺寸、格式转换。
- `/usr/bin/shasum -a 256`——记录哈希。
- `python3` 标准库（`zlib` / `struct` / `hashlib`）——PNG 解码、alpha 统计、bbox、透明像素 RGB 清零校验。可参考仓库既有实现 `scripts/validate-runtime-art-batch.py` 的纯标准库 PNG 解码器。

详见 `artifacts/integration/n-008-brief/tool-preflight.md`。

## 5. 工具缺口处理方式

本机确认缺失：Pillow、OpenCV、numpy、ImageMagick、`pngcheck`。

- **不得自行安装任何软件。**
- 优先用第 4 节的现有能力覆盖需求。
- 若某项检查用现有工具确实无法可靠完成，把缺口写进交付报告：缺什么能力、卡在哪一步、建议装什么、为什么现有工具不够；由 🧱 `tech` 评估、Product Owner 决定，然后才可能新增工具。
- 不得因为某个工具方便就扩大 N-009 范围（例如顺手做动画、多表情、建筑或 UI）。

## 6. 生成与处理步骤

逐人串行执行，一次只做一个角色：

1. 依据 `n-008-brief.md` 第 3 节写该角色的生成 prompt，记录 prompt 原文与版本号。
2. 生成头顶到鞋底完整可见的全身像与透明背景源图；保留生成器原生方形 RGBA 文件，处理层按 DEC-025 独立导出 `2048×2048`；不满意可迭代，记录迭代次数与选用理由。
3. 存入 `source/portrait_<slug>_source_v01.png`。
4. 检查并清理：透明边缘去白边/黑边/脏 halo，`alpha == 0` 的像素 RGB 清零。无需清理时执行 no-op 并显式声明。
5. 存入 `processed/portrait_<slug>_clean_v01.png`（必须是独立文件，不能与源图同一个）。
6. 跑检查：尺寸、颜色类型与位深、alpha 直方图、非透明 bbox、透明像素 RGB 清零、SHA-256；原始输出存 `evidence/`。
7. 写 `records/portrait_<slug>_generation-record-v01.md`，字段照 `n-008-brief.md` 第 10 节的 9 项。
8. 八人全部完成后，生成 1× 联系表与 `manifest.json`。

## 7. 每名角色必须交付的文件

- `source/portrait_<slug>_source_v01.png`
- `processed/portrait_<slug>_clean_v01.png`
- `records/portrait_<slug>_generation-record-v01.md`
- `evidence/` 中该角色的检查命令原始输出

八人齐备后再加：`contact-sheet/n-009-contact-sheet-v01.png`、`manifest.json`。

## 8. 透明背景与 Alpha 检查

- 背景 `alpha == 0`；人物主体内部 `alpha == 255`，完全不透明像素数必须大于 0。
- 仅允许人物轮廓过渡带取 1–254 的中间值——这是插画层与像素层的关键区别，不按 `Assets/` 的「无半透明」规则处理。
- 注意：既有 C0 实测 `opaque=0`、alpha 上限 254、透明像素 RGB 未清零，属于**不合格样例**，不要照抄它的输出习惯。
- 禁止：整体半透明蒙层、白边、黑边、成片脏 halo、棋盘格烘焙、外框、彩色描边光晕。
- 所有 `alpha == 0` 的像素 RGB 必须为 `(0,0,0)`。
- 逐张记录 alpha 直方图摘要与检查命令原始输出。

## 9. 尺寸、裁切、命名、哈希与 manifest 要求

- 尺寸：源图与处理图均实测 `2048×2048`，八人长宽比一致（`1:1`）。
- 裁切：非透明 bbox 不得触到画布任一边；头顶留白约 6%–10%，鞋底留白约 5%–10%，全身高度约占画布 80%–88%；不得裁到头发、道具、手部、衣摆、腿部或鞋底，双脚必须完整可见。
- 命名：`portrait_<slug>_source_v01.png`、`portrait_<slug>_clean_v01.png`、`portrait_<slug>_generation-record-v01.md`，全小写 snake_case。
- 哈希：每个 PNG 记 SHA-256（`shasum -a 256`），写入 record 与 manifest。
- `manifest.json`：逐文件记录 slug、稳定 ID、路径、SHA-256、宽高、颜色类型、位深、alpha 统计、bbox、prompt 版本、状态；顶部记录生成日期、工具与版本、总文件数。

## 10. 不得进入正式 Assets

产物一律留在 `artifacts/integration/n-009-portraits/`。禁止复制、移动、软链或以任何方式写入 `macos/CreekSprout/CreekSprout/Assets/`（含 `ConceptArt/` 子目录），禁止加入 Xcode target，禁止打进应用包。接入是 N-010 的事。

## 11. 不得修改 Swift、存档、经济、地图和内容 ID

不改任何 `.swift`、`project.pbxproj`、存档 schema 或迁移、`EconomyCatalog`、`WorldCatalog`、地图布局与碰撞、`ContentID`。N-009 对运行时行为的 diff 必须为零。

## 12. 不得把 32×48 像素图放大冒充立绘

禁止对 `Assets/char_*.png` 做插值放大、锐化、AI 超分或加滤镜后当立绘交付。也禁止把 `Assets/ConceptArt/concept_character_*_v01.png` 改名或直接裁切充当源图——那是全身 C0 概念图，只能作为造型与配色参考，必须重新生成高分辨率完整全身像。

## 13. 内容原创性要求

- 完全原创：不描摹、不图生图改色、不拼接现成素材、不复用既有作品的角色轮廓。
- 不得近似任何既有农场/生活模拟游戏的角色、发型服装组合、构图或可识别画师风格。
- 画面内不得出现文字、签名、水印、Logo、品牌标识、外部作品名。
- 每人在 record 中写独立的原创性自查结论与理由；🎭 `content` 逐人复核，你不得审查自己的结论。

## 14. Product Owner 目检流程

1. 你交付 8 张处理图的 1× 单图 + 一张八人联系表。
2. Product Owner 逐人目检：清晰度、八人可区分、职业可辨、光照与色彩统一、无文字/水印/棋盘格、透明边缘干净。
3. PO 可逐人通过或逐人返工，不要求整批同进退。
4. PO 视觉批准只能由 Product Owner 本人给出，你和任何审查 agent 都不能代签。

## 15. 🎭 content 部门门禁

🎭 `content` 负责内容与原创性门禁，检查：八人身份与 `n-008-brief.md` 第 3 节是否逐项一致；职业识别锚点是否清晰；八人是否仅靠换色区分；光照与色彩是否统一；原创性是否成立；表情方向是否符合角色性格。返回 `APPROVED`、`REVISE` 或 `BLOCKED` 之一，`REVISE` 须列出逐人具体缺口。

## 16. 🛡️ quality 独立复核要求

🛡️ `quality` 做只读独立复核，不看你的结论只看证据：文件齐备性；尺寸/颜色类型/位深实测；alpha 与透明 RGB 清零；bbox 未触边；SHA-256 与 manifest 逐项一致；文件边界无越界（`macos/` 与台账零 diff）；`git diff --check` 结果；逐人 record 九项字段完整。返回 `APPROVED`、`REVISE` 或 `BLOCKED` 之一。

## 17. 失败时返回 REVISE 或 BLOCKED 的条件

返回 `BLOCKED`（不改文件、停止）：

- N-008 未处于 `accepted / APPROVED`；
- 图像生成能力不可用；
- 只能通过安装新软件才能完成必需检查，而安装未获批准；
- 合同本身缺项、自相矛盾或与既有已验收资产冲突。

返回 `REVISE`（说明缺口，不自批通过）：

- 任一角色的源图或处理图缺失、尺寸不符、长宽比不一致；
- alpha 脏、bbox 触边、透明像素 RGB 未清零；
- 画面出现文字、水印、棋盘格、UI 或多角色同框；
- 与第 3 节的主题色/发型轮廓/表情方向不符；
- record、evidence、manifest 或哈希缺失、对不上；
- 出现原创性风险。

任何情况下都不得自签 `APPROVED`。

## 18. 交付报告格式

严格使用以下格式，交付到 `artifacts/integration/n-009-portraits/art-handoff.md`：

```
Outcome:
Changed artifacts:
Validation evidence:
Decisions and assumptions:
Risks and follow-ups:
Requested department gate: 请 🎭 content 与 🛡️ quality 分别返回 APPROVED | REVISE | BLOCKED；🎨 art 不自签
```

其中 `Validation evidence` 必须给出命令原文与原始输出（尺寸、alpha、bbox、SHA-256、`git diff --check` 退出码），不接受只写结论的摘要。
