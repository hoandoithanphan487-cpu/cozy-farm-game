# N-006 全量运行时像素资产生产合同

## 玩家结果

在不改变玩法、地图、存档或经济规则的前提下，把既有 C0 造型参考重绘为可由 SpriteKit 最近邻显示的原生像素资产，并形成可一次性目检的联系表。Product Owner 的“全部开始生成”是本批生产授权，不自动替代未完成的逐项视觉终验。

## 范围

- 正式运行时包：Master Doc §9.2–§9.7 已定义的角色、作物、地块/水体、五栋建筑六层、放置物、采集物、工具、FX 与 UI。
- 世界生机候选包：猫猫烧烤店、三名猫店员、环境动物、灌木和花丛只制作 R0 候选，不写入正式 `Assets/`；稳定 ID、footprint 与交互语义后续另立合同。
- 现有 C0 仅作造型与配色参考；运行时图在目标尺寸逐像素重绘，不直接缩放概念图。

## 文件边界

- 可写：`macos/CreekSprout/CreekSprout/Assets/`、`artifacts/art-style/runtime-batch-r0/`、`artifacts/art-style/candidates/runtime-r0/`、本合同、台账和专用生成脚本。
- 禁止改动：Swift 玩法源码、内容 ID、地图、存档 schema、经济参数、PRD/TDD。

## 验收条件

1. 文件名、尺寸、状态和方向与 Master Doc §9 一致。
2. 独立元素为 RGBA，透明像素 RGB 清零；铺满地块允许不透明。
3. 仅使用锁定色票，禁止半透明软边、渐变和抗锯齿。
4. 角色 R0 为 32×48；R1 为 128×192、4×4 帧且脚底基线稳定。
5. 作物 R0/R1 为 32×32；四阶段轮廓有可读变化。
6. 地块通过 3×3 平铺检查；水循环静帧和连续帧均可读。
7. 五栋建筑各有 `base/structure/roof/detail/interaction/state_fx` 六层，母画布尺寸正确，图层可独立隐藏。
8. 放置物、资源、工具、FX、UI 尺寸及透明度正确。
9. 生成清单、哈希、尺寸/色票/Alpha 检查和 1×/4×联系表齐备。
10. 🎨 art 完成后由 🧱 tech 返回 `APPROVED/REVISE/BLOCKED`；Product Owner 目检前任务保持 `active / PENDING`。

## 门禁分工

- 专项负责人：🎨 art。
- 部门质量负责人：🧱 tech。
- 整包视觉验收：Product Owner。
- 防自我批准：生成者不得签署技术或 Product Owner 终验。
