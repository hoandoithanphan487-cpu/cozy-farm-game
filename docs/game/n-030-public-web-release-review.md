# N-030 公开网页版发布复核

日期：2026-09-06

## 发布结果

- 生产网址：`https://creek-sprout-game.hoandoithanphan487.chatgpt.site/`
- 访问策略：`public`，任何获得网址的人均可访问，无需项目登录。
- Sites 项目：`appgprj_6a9d68fc11cc819193943a08181b0e37`
- 已保存版本：v1（`appgprj_6a9d68fc11cc819193943a08181b0e37~appgver_e25d9ddc6dd08191bed9318b50ebba1f`）
- 源码提交：`21c366491dcd2c74e9cd109dd462271b931f6691`
- 生产部署：`appgdep_6a9d699026f48191b9c975de903462d3`，状态 `succeeded`
- 公网探针：匿名 `GET /` 返回 HTTP `200`。

## 交付证据

- 📦 `release`：`SUBMITTED`
  - 独立站点工程位于 `web/creek-sprout/`。
  - `npm run build` 成功；发布包含 `dist/server/index.js`、`dist/.openai/hosting.json` 与游戏静态资源。
  - Sites 打包产物 SHA-256：`90d6aba5d2dd0c44fd924f0d58eb4c1816e523b9123737b08eb8c5f14ffb39ef`，77 个文件，1,720,320 bytes。

- 🧱 `tech`（跨部门复核）：`APPROVED`
  - Web 运行层与 Swift/SpriteKit 原生端隔离，未冒充完整 macOS 移植。
  - 核心规则集中于 `lib/game.ts`，界面层只调用领域动作；边界、出售箱碰撞、存档解析与损坏存档回退均有自动化验证。
  - `npm run test:game`：`PASS core-loop=1 save-roundtrip=1 corrupt-save-fallback=1 bounds=1`。
  - 发布源码提交与 Sites v1 的 `commit_sha` 完全一致。

- 🛡️ `quality`：`APPROVED`
  - 生产浏览器实走：翻土 → 播种 → 浇水 → 三日成长 → 收获 → 移动至木箱旁 → 出售。
  - 里程碑进度从 0% 到 100%；溪票从 120 增至 178；出售按钮仅在满足相邻位置与持有收成时启用。
  - 默认窄屏和 1280×900 桌面视口均显示农场、状态、工具与移动控件；桌面复核后已恢复默认视口。
  - 页面标题为“溪谷新芽｜公开浏览器试玩”，生产网址与 Sites 部署记录一致。

- 🎬 `director`（下游发布复核）：`APPROVED`
  - N-030 合同的公开访问、可玩闭环、键盘/触摸入口、本机存档、响应式、构建与生产发布证据均已满足。
  - 未越界宣称 N-027 十段主剧情、5–6 小时完整流程、猫店/畜牧全量移植或跨设备存档。

## 发布边界

- 这是独立浏览器垂直切片；与 macOS 存档不互通。
- 存档保存在当前浏览器的本地存储中，清除浏览器数据或更换设备不会自动同步。
- 网址由 Sites 托管并保持固定；自定义品牌域名和跨设备账号体系不在 N-030 范围内。

