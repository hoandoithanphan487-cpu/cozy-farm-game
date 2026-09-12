# 部署 Prompt：《溪谷新芽》Web 版 → Vercel

> 用途：把下面代码块内的整段文本复制给执行部署的 AI（PI / 其他终端代理），它即可独立完成部署。
> 工程路径：`/Users/fengyifan/Documents/VibeCoding/web/creek-sprout`
> GitHub 仓库：`hoandoithanphan487-cpu/cozy-farm-game`（main，工程位于 `web/creek-sprout` 子目录，HEAD `ef77b12`）
> 发布产物：纯静态站点（`dist/client`）

---

```text
[任务]
把本地工程 /Users/fengyifan/Documents/VibeCoding/web/creek-sprout 部署到 Vercel，产出一个公开可访问的线上地址。只做部署，不改任何游戏功能、画面与资产。

[工程事实（已核实，不要凭直觉假设）]
1. 这是 Vite 8 + React 19 的客户端渲染游戏（《溪谷新芽》Web 版），页面只有一个路由 "/"，游戏状态全部在浏览器内存/存档里，没有后端 API、没有数据库。
2. 构建命令是 npm run build，构建工具是 vinext（不是 Next.js）。产物分两部分：
   - dist/client/：前端静态资源（_next/、full-assets/、game-assets/、favicon.svg），构建后原本【没有 index.html】。
   - dist/server/：Cloudflare Workers 形态的服务端 bundle（index.js 导出 default.fetch）+ wrangler.json。这是 Workers 产物，Vercel 不能直接运行，也不需要运行。
3. 我已经把静态化所需的两个文件做好并提交：
   - scripts/export-static-index.mjs：调用 dist/server/index.js 的 fetch handler，把 SSR 出来的 HTML 外壳写进 dist/client/index.html。
   - vercel.json：framework=null、buildCommand="npm run build && node scripts/export-static-index.mjs"、outputDirectory="dist/client"、SPA rewrites 到 /index.html、_next 与资产目录的 Cache-Control。
4. 我已在本机用静态服务器验证过这套产物：/ 返回 200、CSS 200、/full-assets/story.json 200、/full-assets/assets/tile_canal_ns.png 200，浏览器打开后游戏正常运行（按 E 弹出水工学徒剧情，无 JS 报错）。所以这是已验证的部署形态，不要改成 Next.js、不要引入 SSR 平台、不要把这些静态文件搬去做 Worker/Edge Function。

[执行步骤（Vercel CLI 路线，推荐）]
cd "/Users/fengyifan/Documents/VibeCoding/web/creek-sprout"
npm install
npm run build
node scripts/export-static-index.mjs        # 必须输出“已写入 dist/client/index.html”
test -f dist/client/index.html || { echo "静态导出失败，停止部署"; exit 1; }
npx vercel@latest login                      # 若已登录会直接跳过
npx vercel@latest link                       # 关联或新建项目，项目名建议 creek-sprout
npx vercel@latest deploy --prod              # 云端会重新跑 buildCommand
部署完成后立刻把线上 URL 打印出来。

[如果走 Vercel 控制台（Git 集成）路线，推荐]
代码已在 GitHub 仓库 hoandoithanphan487-cpu/cozy-farm-game 的 main 分支（工程位于 web/creek-sprout 子目录）。
Vercel → Add New → Project → Import 该仓库，然后设置：
  Root Directory    = web/creek-sprout      ← 必须设置，否则会在仓库根目录构建 macOS 工程而失败
  Framework Preset  = Other
  Build Command     = npm run build && node scripts/export-static-index.mjs
  Output Directory  = dist/client
  Install Command   = npm install
环境变量不需要任何密钥。绑定后每次 push 到 main 会自动重新部署。

[构建环境]
Node 20 或更高（建议 22）。若 Vercel 构建报 Node 版本相关错误，在该项目 Settings → Environment Variables 增加 NODE_VERSION=22 后重新部署。

[部署后验收清单（逐条执行并贴出结果）]
1. curl -sI "<线上URL>" 应返回 200 且 content-type 为 text/html。
2. curl -s -o /dev/null -w "%{http_code}\n" 依次检查：
   <线上URL>/full-assets/story.json
   <线上URL>/full-assets/assets/tile_canal_ns.png
   <线上URL>/full-assets/world/wl_backdrop_farm_north_horizon_r6.png
   <线上URL>/full-assets/music/music_farm_today_is_a_good_day_v01.mp3
   <线上URL>/full-assets/music/music_creek_bouncy_steps_v01.mp3
   全部应为 200。
3. 用无痕窗口打开 <线上URL>：应看到农场画面、左上「农场与农舍」、右上「第1天 06:30 晴」、底部消息条「欢迎来到新芽农场……」。
4. 打开 <线上URL>/?fresh=1：底部提示应变成「校对模式：未读写存档，画面与本地初始状态一致。」且玩家位于农场 (7,6)。
5. 键盘验收：按 E 应弹出「Q01 · 获益 / 水工学徒」对话卡；按 F 应弹出主线指引；按 J 应打开手册；WASD 可移动。
6. 用 20 个并发请求压一次首页，应全部 200（可用 xargs/ab，简单验证即可）。
7. 如有任何一条不通过，先贴原始输出再排查，不要自行修改游戏源码。

[纪律]
- 只在 main 上追加部署用文件；不要改写 Git 历史、不要 force push、不要提交 dist/ 目录。
- 不要改动 app/、runtime/、content/、lib/、public/ 下的任何游戏逻辑、画面参数与资产文件。
- 不要替换成别的框架或托管方式；不要删除 scripts/export-static-index.mjs 与 vercel.json。
- 不要覆盖用户已有的其他线上站点/域名；如需自定义域名，先回来询问，不要自行绑定。
- 失败时保留现场（原始命令 + 原始报错），不要反复尝试破坏性操作。

[交付]
把线上 URL、部署时间、构建日志末尾 20 行、以及上面 7 条验收的结果一并回报。
```

---

## 本地已验证的记录（供参考，不必执行）

| 检查项 | 结果 |
| --- | --- |
| `node scripts/export-static-index.mjs` | 写入 `dist/client/index.html`（15695 字符） |
| 静态服务器 `/` | 200 |
| `/_next/static/.../index.*.css` | 200 |
| `/full-assets/story.json` | 200 |
| `/full-assets/assets/tile_canal_ns.png` | 200 |
| 浏览器实测（静态形态） | 探针正常、玩家 (7,6)、按 E 弹出水工学徒剧情、无 JS 报错 |

## 备注

- 代码已推送到 `git@github.com:hoandoithanphan487-cpu/cozy-farm-game.git`（main，提交 `ef77b12`）；web 工程位于该仓库的 `web/creek-sprout` 子目录，因此 Vercel 导入时**必须**把 Root Directory 设为 `web/creek-sprout`。
- `dist/client` 中的 `_headers` 是 Cloudflare 专用格式，Vercel 会忽略；缓存策略由 `vercel.json` 的 `headers` 提供，两者不冲突。
- 由于是 SPA rewrite，任意未知路径都会返回首页 HTML（而非 404），这是预期行为。
- 若后续需要正式域名，在 Vercel 项目 Settings → Domains 绑定，并与 PO 确认后再动旧站。
