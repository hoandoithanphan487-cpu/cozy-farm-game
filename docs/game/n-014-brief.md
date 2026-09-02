# N-014 — 猫猫烧烤组高清展示图生产

## Player outcome

玩家在未来的角色/店铺介绍与对话展示中，可以看到与 N-009 人物立绘、N-013 R2 建筑相同清晰等级的溪火猫食铺与三名猫店员；地图游玩仍使用原生像素候选，不发生清晰度与碰撞逻辑混用。

## Ownership

- Department: 🎭 World & Content
- Department quality owner: 🎭 content
- Specialist owner: 🎨 art
- Consulted: 🧱 tech（只读导出规格）
- Downstream reviewer: Product Owner → 🛡️ quality
- 防自我批准：🎨 art 只提交；🎭 content 执行跨角色内容/原创性门禁，最终 🛡️ quality 独立复核。

## Dependencies and preflight

- N-005: `accepted / APPROVED` — 店铺 B 轮廓与三猫身份已批准。
- N-006: `accepted / APPROVED` — 原生运行时像素候选已存在并保持隔离。
- N-009: `accepted / APPROVED` — 高清绘本清晰度基准。
- DEC-028: 双层美术合同已批准。
- DEC-029: Product Owner 已授权猫猫高清展示批次。
- Preflight result: PASS.

## In scope

- 溪火猫食铺：1 张完整 2048×2048 RGBA 高清展示图。
- 酷黑猫、漂亮三花、优雅白色布偶：各 1 张完整全身 2048×2048 RGBA 高清展示图。
- 自动背景移除、2048 导出、透明 RGB 清理、边界/Alpha/哈希验证、联系表和生成记录。

## Out of scope / do not touch

- Swift、Xcode 工程、正式 Assets、存档、经济、配方、玩法和地图拓扑。
- 不创建稳定 ID、NPC 逻辑、地图位置、对话、剧情或动画。
- 不替换 N-004 木蜜灶台，不把高清图当作地图碰撞或运行时小图。
- 不覆盖 N-005/N-006 历史图；新文件使用 N-014 隔离目录和版本化文件名。

## Locked visual invariants

- 店铺：B 轮廓、宽低单体、开放烤炉、低递餐窗、双短烟帽、铜橙串架、雾蓝防火石基。
- 酷黑猫：黑色毛发、缺口耳、铜橙领巾、深色围裙、长烤钳、放松站姿。
- 三花猫：大块三花毛色、苔绿围裙、托盘烤串、温和姿态。
- 白色布偶：白色长毛、雾蓝重点色、窄长围裙、调味磨、优雅姿态。
- 三名猫均完整显示耳尖、脸、身体、双脚爪、尾部和全部手持工具；不裁切、不合并成群像。

## Acceptance criteria

1. 四张最终图均为 2048×2048 RGBA PNG，透明背景且透明 RGB 清零。
2. 店铺及三猫主体均完整、不触边；不存在棋盘格、文字、Logo、水印、场景或第二主体。
3. 三猫身份不只靠换色区分，花色、围裙、工具、姿态和轮廓均保持 N-005 设定。
4. 与 N-009/N-013 R2 的线条清洁度、材质密度、暖左上光和暖木/冷青色彩关系一致；不是像素图放大。
5. 🎭 content 原创性/风格门禁、Product Owner 视觉门禁和 🛡️ quality 独立复核全部明确 `APPROVED` 后，N-014 才可 `accepted`。

## Required evidence

- 四张源图、四张处理图、逐图生成记录。
- `manifest.json`、验证报告、SHA-256、联系表。
- 🎭 content、Product Owner 与 🛡️ quality 门禁文件。
