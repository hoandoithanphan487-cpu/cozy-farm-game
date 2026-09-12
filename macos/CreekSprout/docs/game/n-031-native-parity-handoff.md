# N-031 R3 本地一致性对齐 · 交接与续作提示

日期:2026-09-12 · 候选提交:`862d379`(web 仓库 `VibeCoding/web/creek-sprout`)

## 1. 本轮修复的 6 个「画面不一致」根因

| # | 问题 | 根因 | 修复 |
|---|---|---|---|
| 1 | **所有建筑从未渲染** | `content/r22-world.ts` 把 `render_anchor` 当数组读(`b.render_anchor[0]`),实际是记录 `{ cell:[x,y], normalized:[0.5,0.0], pixel_offset:[dx,dy] }` → 锚点变 `NaN` | 兼容两种形态并按 `pixel_offset` 取偏移(即原生 `renderOffsetX/Y`) |
| 2 | **世界上下颠倒** | 数据行号与 SpriteKit 一致(南→北),但 Web 把行 `y` 直接铺在屏幕自上而下 | 相机取景 `(rows - y - 0.5)`、`sy(y)=originY+(rows-1-y)*cell`、指针反算同步翻转 |
| 3 | **装饰整体错位** | 原生锚点是「图底边 = 格底边」,Web 用"底=格中心上方半格" | 逐类复刻 `rebuildWorldLife`:默认底=格底;gardenBed/scenicTilled/pasture/fence/shoreInset 中心锚;diningSet 顶锚;greenhouse 退半格;shoreInset 冷暖色融合 |
| 4 | **北地平线错** | Web 把 backdrop 拉伸到地图宽、从北界向下画 | 用原生整数像素缩放 + 底部中心锚(地图中心 x,锚行 y),超出地图两侧进入相机外延 |
| 5 | **遮挡关系全错** | 建筑不入 z 队列,玩家/NPC 画在最上层 | 统一 painter z:`建筑 5+order*0.1 / 屋顶 12 / 地面装饰 5.75-6.9 / 餐桌 7.7 / 温室 9.4 / NPC 9.5 / 玩家 10 / 树·动物 13.6-14.4 / FX 20 / 提示 30` |
| 6 | **地图外是纯色** | 缺原生 `bleedRoot` | 地图四边外 3 格铺基础草地,`alpha 0.88`(左右边缘现与原生素差 ≤2) |

附带:角色/动物的站位从"格顶"改回"格底";水渠深浅覆盖层按 `makeNorthSouthCanalDepthOverlay` 几何(中心 ±5 原生像素、2/1 像素宽、渠口阴影 10×2)重建。

## 2. 权威对照工具链(务必复用)

### 2.1 生成原生权威画面(唯一权威源)
原生仓库已加入临时对照测试 `CreekSproutTests/ZZWebParitySnapshotTests.swift`:
- 用 `PresentationSnapshot.pngData(from: scene, size: 1280×800)` 无头渲染 `FarmScene`(Metal,不含 SwiftUI HUD)
- 新游戏初始状态 = 玩家 `(7,6)` / day 1 / 晴
- 输出到沙盒临时目录(测试进程不能写 `/tmp`):
  `/Users/fengyifan/Library/Containers/com.fengyifan.CreekSprout/Data/tmp/native-parity/`

```bash
cd /Users/fengyifan/Documents/VibeCoding/macos/CreekSprout
xcodebuild test -project CreekSprout.xcodeproj -scheme CreekSprout \
  -destination 'platform=macOS' -only-testing:CreekSproutTests/ZZWebParitySnapshotTests
cp /Users/fengyifan/Library/Containers/com.fengyifan.CreekSprout/Data/tmp/native-parity/native-farm-1280.png /tmp/shots/
```

### 2.2 Web 侧截图
```bash
for p in $(lsof -ti tcp:4180); do kill $p; done
cd /Users/fengyifan/Documents/VibeCoding/web/creek-sprout
npm run build
(nohup node node_modules/vinext/dist/cli.js start --port 4180 >/tmp/v4180.log 2>&1 &)
curl -s --retry 15 --retry-connrefused --retry-delay 1 -o /dev/null -w 'srv:%{http_code}\n' http://127.0.0.1:4180/
'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --headless=new \
  --disable-gpu --hide-scrollbars --virtual-time-budget=7000 --window-size=1280,800 \
  --screenshot=/tmp/shots/web.png 'http://127.0.0.1:4180/'
```
> headless 使用全新 profile(无存档)= 初始站位 `(7,6)`,与原生快照同状态。
> 嵌入浏览器里的页面有本机存档,站位不同,**不能**直接用来做像素比对。

### 2.3 量化对比(PIL + numpy 片段)
- 格坐标映射:`格x = (屏幕x - 64)/72`,`格y = (793 - 屏幕y)/72`(1280×800、zoom 3)
- 逐格平均色差、最差行/列、砖红/黄色质心、`alpha` 过滤后的资产主色
- 关键校正:**原生快照不含 SwiftUI HUD**,`y<52` 与 `y>742` 行必然差异大(Web 有 DOM HUD),比对世界内容时排除这些行
- 色类字符画(每 8-16px 一个字符,最近邻调色板)是排查布局的利器

## 3. 当前差异状态(1280×800,初始站位)

| 区域 | 平均色差 | 说明 |
|---|---|---|
| 地图外左右边缘 | **≤2** | 已一致(bleed 修复后) |
| 中心区(y 133-666) | 8-30 | 主体接近 |
| 水渠列 x998-1072 | 40-60 | tile/depth 仍有差 |
| HUD 行 y33-43 | 58-65 | 原生快照无 HUD = 测量假象;真实 app 需对齐 SwiftUI HUD 样式 |
| 整幅均值 | 29.8 | 修复前约 100+ |

## 4. 剩余待办(按价值排序)

1. **HUD 样式对齐**:web 的 DOM HUD(顶部时钟/目标卡、底部工具带)与原生 SwiftUI 的材质、几何、字号逐项对齐;注意原生快照不含 HUD,需用真机截图或原生 HUD 源码对照。
2. **水渠细节**:`WorldVisualCatalog.canalKeys` 的多 tile 叠加、`canalAnimationKeys` 帧序、(市场)渠口与 apron 的差异。
3. **建筑 ±30px 微调**:砖红质心 sluice web(951.8,136.6) vs native(953.8,121.3);house web(501.7,172.9) vs native(487.7,141.4),需逐层核对 `BuildingVisualPresenter` 的层 anchor/尺寸。
4. **gather 节点 / 作物 display 锚点**:原生 `sprite.position.y = (spriteHeight - cellSize)/2`,Web 目前用底=格底,可能仍差。
5. **天气 wash / 雨滴**、`WorldEffectPresenter` 的 FX 帧。
6. 市场地图(`creek-market`)同法复核:18 列 14 行,相机与 bleed 逻辑相同但 `mapWidth > viewport` 时无水平 bleed。

## 5. 纪律

- 不部署、不置 PO-approved;候选提交保持可回退。
- 每次改完必跑:`npx tsc --noEmit`、`npm run build`、`npm run test:full`(20 断言)、`npm run audit:parity`(318 资产)。
- 对照后**用像素证据**判断是否收敛(不要凭观感)。
- 原生仓库的 `ZZWebParitySnapshotTests.swift` 只用于生成对照图,不参与发布。
