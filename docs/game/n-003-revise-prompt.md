# N-003 REVISE 返工 Prompt — AC-1 / AC-5 / O-1

> 触发：Hermes 独立验收 `REVISE`
> 目标：补齐合同证据，不扩大 N-003 运行时资产范围
> 执行者：Cursor / 🎨 art
> 技术复核：🧱 tech；独立质量复核：Hermes / 🛡️ quality

将以下全文复制给 Cursor：

```text
你是《溪谷新芽》的 🎨 art 执行专员。请对 N-003 首轮资产执行一次最小范围 REVISE 返工。

A. 任务与输入

任务：N-003 首轮 R0（4 名角色 idle、5 种成熟作物、3 张农场地块）的合同证据补齐。

先读取：
- AGENTS.md
- skills/cozy-farm-game-studio/SKILL.md
- skills/cozy-farm-game-studio/references/roles.md
- skills/cozy-farm-game-studio/references/production-workflow.md
- docs/game/n-003-brief.md
- docs/game/art-style-master-doc.md
- artifacts/integration/n-003-pixel/cursor-handoff-first-round.md
- Hermes 的 N-003 REVISE 反馈
- artifacts/art-style/n-003-first-round/pixel-check.json

B. 硬门禁

1. 只修复 AC-1、AC-5 和 O-1；不得生产新的运行时资产，不得改玩法。
2. 不修改 Content、Domain、经济、存档 schema、Audio、PRD、TDD、N-004、台账或既有 PNG。
3. 不修改 `PixelAssetStore.swift`、测试或 Xcode 工程；本轮只补证据文档和必要的联系表展示裁切。
4. 不自行签发 APPROVED；完成后请求 🎭 content / 🧱 tech / 🛡️ quality 门禁。
5. 先确认 Hermes 所说的 `assets/` 合同路径。证据包使用：
   `artifacts/art-style/n-003-first-round/assets/`
   若仓库已有明确的合同解析路径，按该路径落盘，并在 handoff 中写明映射；不要把审核文档混入运行时 `macos/.../Assets/`，除非合同解析明确要求。

C. 修复 AC-1：风格规范

创建 `assets/style-spec.md`（按 B 节确认后的合同路径）。内容必须是本轮实际使用的可审计规范，而不是只链接 Master Doc。至少包含：

- 任务 ID、版本、日期、Product Owner 已确认的正式视觉锚点；
- 4 名角色、5 种作物、3 张地块的实际清单与运行时文件名；
- 原生尺寸：角色 32×48、作物 32×32、地块 24×24；
- bottom-center / center 锚点与 idle-front / mature / default 状态；
- Master Doc §3 的 10 个锁定色票及“不得越界”；
- Alpha 规则：独立元素 RGBA、Alpha 仅 0/255、透明像素 RGB 清零；地块可不透明；
- 最近邻、整数缩放、无抗锯齿、无软边/渐变/全局纯黑粗描边；
- C0 只作 silhouette / costume / tool 参考，R0 必须原生尺寸逐像素重绘；
- 程序化回退规则、`char_player` 映射规则、缺失贴图安全回退；
- NFR-007 验证方式与本轮证据路径；
- 本轮 out of scope：行走图、生长阶段、建筑六层、邻居运行时贴图、FX/UI 扩量。

D. 修复 AC-5：逐件原创性审核

创建 `assets/originality-review.md`（同一合同路径），逐件列出以下 12 项：

- char_player.png
- char_water_apprentice.png
- char_seed_steward.png
- char_creek_warden.png
- crop_mist_radish.png
- crop_stream_leaf.png
- crop_amber_bean.png
- crop_bell_berry.png
- crop_honey_melon.png
- tile_grass.png
- tile_tilled.png
- tile_water_edge.png

每项必须包含：

- stable_id 与运行时文件路径；
- 对应 C0 概念源或“无独立 C0、依据 Master Doc 角色/作物/地块规格”的说明；
- silhouette / 构图检查；
- 角色服装、工具或作物形态的原创性说明；
- 与既有游戏/公开 sprite 的近似风险检查，明确“未发现可识别近似”或列出返工项；
- 色票与线条规则检查；
- 是否存在文字、logo、水印、场景背景、底板或外部素材；
- 结论：PASS 或 REVISE；
- 审核者：🎨 art 自检，不得写成部门批准。

文档末尾增加总表：12/12 是否 PASS、剩余风险、请求的 🎭 content 门禁。

E. 修复 O-1：联系表裁切

只修复证据展示图，不修改运行时 PNG：

- 重新生成 `characters-contact-4x.png`，确保 4 名角色的头顶、脚底、左右透明边界均完整可见；
- 重新生成对应 1× / 4× 预览或联系表时，保留完整画布，不裁掉透明留白；
- 如果生成测试会覆盖同名证据图，保持证据目录路径不变；
- 在 handoff 中说明运行时 PNG SHA-256 未改变。

F. 观察项处理

- O-2（水边地块 3×3 接缝约 2.75）：记录为非阻断观察项，不改运行时 tile，除非能证明是纯证据错误；
- O-3（manifest 元数据矛盾）：修正 manifest/证据文档中的元数据，不改 PNG；若无法安全判定，记录为 REVISE follow-up；
- O-4（NFR-007 图色偏）：记录为证据展示问题；优先重新导出/校正展示图，不改运行时 PNG。若展示图无法可靠校正，保留为非阻断观察项并引用独立测试断言。

G. 验证与交付

执行并保存原始结果：

- 证据文档路径存在性检查；
- 12 项逐件原创性记录计数为 12；
- style-spec 的尺寸/色票/过滤规则与 Master Doc 一致；
- 联系表完整性检查；
- `git diff --check` exit 0；
- 证明 12 个运行时 PNG 的 SHA-256 与返工前一致；
- 不重复 clean test，不改测试，不声称新的 XCTest 结果。

H. 返回格式

Outcome:
Changed artifacts:
AC-1 evidence:
AC-5 evidence:
O-1 evidence:
O-2/O-3/O-4 status:
Runtime PNG hashes changed: YES | NO
Boundary audit:
Validation evidence:
Decisions and assumptions:
Risks and follow-ups:
Requested department gate: APPROVED | REVISE | BLOCKED

不得把执行结果写成 APPROVED；只请求门禁。
```
