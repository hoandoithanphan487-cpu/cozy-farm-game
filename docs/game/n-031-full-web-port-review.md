# N-031 完整 Web 迁移发布复核

日期：2026-09-06

## 生产结果

- 固定公开网址：`https://creek-sprout-game.hoandoithanphan487.chatgpt.site/`
- Sites 项目：`appgprj_6a9d68fc11cc819193943a08181b0e37`
- 保存版本：v2（`appgprj_6a9d68fc11cc819193943a08181b0e37~appgver_25e5f5be01c481919f4c13abb4ec2daf`）
- 源码提交：`4793406c6a8f5e2c5ea5e91c877c33a5fb7a3832`
- 生产部署：`appgdep_6a9d78cf1de08191b71a326aa7513ed4`，`succeeded`
- 访问策略：`public`
- 页面标题：`溪谷新芽｜正式网页版`
- 开屏边界：无欢迎页、标题页或开屏动画；无有效存档时直接建立第 1 天农场，有有效浏览器存档时直接恢复。

## 实施交付

- 🎮 `gameplay`：`SUBMITTED`
  - 新增 `lib/full-game.ts`，统一承载两图、五作物、天气/时间/体力、背包、制作/加工/放置、采集、水脉、任务、关系、畜牧、猫店、剧情与存档状态。
  - `app/page.tsx` 使用正式全屏游戏壳；R22 像素资源、顶部 HUD、底部工具栏、剧情手册与暂停面板共享同一会话。
  - 从冻结 N-027 权威手稿确定性导出 10 段、59 stage、236 条正式对白和 20 条内联回应到 `public/full-assets/story.json`；源手稿 SHA-256 保持 `7986d424…`。
  - Q08 三检查点、Q09 揭露保护标记、Q10 `water / leave` 双结局写入同一浏览器存档。

- 🧱 `tech` 部门质量门：`APPROVED`
  - 领域层与 React 呈现分离；关键动作只通过纯状态转换进入存档。
  - `npx tsc --noEmit` 退出 0；本次新增文件定向 `oxlint` 退出 0；`git diff --check` 退出 0。
  - `npm run test:full`：`PASS full-web farm=5-crops maps=2 crafting=1 processing=1 watershed=20 livestock=1 cat-shop=1 story=10/236 journey=3 save=roundtrip corrupt=fallback npcs=7`。
  - `npm run build` 成功；本地生产探针 `GET /`、`GET /full-assets/story.json`、`GET /full-assets/assets/char_player.png` 均 HTTP 200。

- 🛡️ `quality` 跨部门复核：`APPROVED（自动化与发布范围）`
  - 完整内容目录、五作物循环、水渠 12+8、加工、畜牧保护、猫店交接、10 段剧情、三旅程点、双结局和损坏存档回退均有非零自动化断言。
  - 生产匿名探针：主页 200 / 27,762 bytes；剧情 200 / 70,380 bytes；玩家资源 200；农场 BGM 200 / 936,999 bytes。
  - 未使用静态说明冒充剧情目录：生产 JSON 实际含 10 stories、59 stages、236 manuscript lines。
  - 本轮未代替 Product Owner 进行主观视觉同等性和自然长流程验收；该项保留为 N-031 唯一后续签核。

- 📦 `release` 下游门：`APPROVED`
  - 286 个源码/资产文件进入提交；专用 Sites 源码仓库 `main` 已从 `21c3664…` 推进至 `4793406…`。
  - 部署包 379 条 tar 清单、压缩包 SHA-256 `bbf0f64a…`，Sites 接收 356 files / 7,270,400 bytes。
  - v2 与推送提交 SHA 完全一致；生产部署 `succeeded`，固定网址和 `public` 访问策略保持不变。

## 已知边界

- Web 是 TypeScript/React 行为等价迁移，不是 SpriteKit 二进制在浏览器中运行。
- 浏览器存档与 macOS 原生存档不直接互通；可在网页暂停页导出/导入 Web JSON 备份。
- 浏览器会拦截未交互页面的自动播放；玩家首次点击/按键后，纯净 BGM 才开始。
- N-016、N-019、N-027 的原生端状态没有因本次发布改变；N-031 仍等待 Product Owner 对网页与本地 App 的主观同等性签核后再改为 `accepted`。

