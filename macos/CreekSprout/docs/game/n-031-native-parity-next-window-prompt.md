# 复制到新窗口的续作 Prompt（N-031 R3 本地一致性对齐 · 续）

> 用法:把下面「===」之间的全部内容复制到 VS Code 新会话的开头发送即可。

===

## 任务

继续《溪谷新芽 / creek-sprout》Web 移植(N-031 R3)的**「与本地原生画面完全一致」**专项。上一窗口已完成 6 项重大渲染修复并提交到候选提交 `862d379`,现在需要继续把剩余差异收敛。

## 仓库与权威源

- **Web 工程(要改的)**:`/Users/fengyifan/Documents/VibeCoding/web/creek-sprout`
  - 渲染核心:`runtime/canvas-world.tsx`(唯一世界渲染器,`paintWorld` + `cameraFor`)
  - 地图数据:`content/r22-world.ts`(加载器)、`content/r22-map-data.ts`(原始数据,从原生成)、`content/r22-world-life.ts`(装饰 placements)、`content/r22-assets.ts`(资产名/路径)
  - 存档/规则:`lib/full-game.ts`;持久化:`persistence/`;验证:`scripts/verify-full-game.ts`、`scripts/audit-parity.ts`
  - 生产构建:`npm run build`(vinext),预览:4180 端口
- **原生权威(只读参考,勿改业务代码)**:`/Users/fengyifan/Documents/VibeCoding/macos/CreekSprout`
  - `CreekSprout/FarmScene.swift`(世界渲染:地形/建筑/世界生命/角色/水渠/FX)
  - `CreekSprout/Presentation/WorldCamera.swift`(相机、取景 52/58、bleedCells=3、atmosphereColor、weatherWash)
  - `CreekSprout/Presentation/WorldLifeCatalog.swift`(装饰 placements、锚点、z、assetName)
  - `CreekSprout/Presentation/PixelAssetStore.swift`(`tileKind`:草地变体 = `abs(x*31+y*17)%4`)
  - `CreekSprout/Presentation/BuildingVisualPresenter.swift`(建筑层:底中心锚、z=5+order*0.1、屋顶 z=12、state_fx alpha 0.72/0.18、root 偏移=renderOffsetX/Y×scale)
  - `CreekSprout/Presentation/CharacterVisualNode.swift`(角色:图宽 1 格、高 1.5 格、底边在格底)
  - 农场关键数值:16×15 格、spawn `(7,6)`、出口 `(7,0)`、三处 placements 数据在此文件

## 本轮已完成(提交 862d379),不要回退

1. `content/r22-world.ts`:`render_anchor` 按记录解析(`{cell, normalized, pixel_offset}`),`pixel_offset` 作为建筑 root 偏移 → **修复了"所有建筑从未渲染"**(之前锚点 NaN)。
2. 世界 Y 轴与 SpriteKit 一致(南→北):相机 `playerWorld.y=(rows-y-0.5)*cell`、`sy(y)=originY+(rows-1-y)*cell`、指针命中反算同步。
3. 装饰锚点按 `rebuildWorldLife` 逐类复刻(默认底=格底;gardenBed/scenicTilled/pasture/fence/shoreInset 中心锚;diningSet 顶锚;greenhouse 退半格;shoreInset 冷暖融合)。
4. backdrop 用原生整数像素缩放 + 底部中心锚(地图中心 x、锚行 y、宽 528/576 原生像素)。
5. 统一 painter z:建筑 5+order*0.1、屋顶 12、地面装饰 5.75-6.9、餐桌 7.7、温室 9.4、NPC 9.5、玩家 10、树/动物 13.6-14.4、FX 20、提示 30。
6. 相机外延 bleed:地图四边外 3 格草地 alpha 0.88(左右边缘现与原生差 ≤2)。
7. 角色/动物锚点 = 格底;水渠 depth overlay 按 `makeNorthSouthCanalDepthOverlay` 重建。

## 对照工具链(必须用像素证据)

1. **原生权威画面**(无头 Metal 快照,不含 SwiftUI HUD,初始状态玩家 (7,6)):
   ```bash
   cd /Users/fengyifan/Documents/VibeCoding/macos/CreekSprout
   xcodebuild test -project CreekSprout.xcodeproj -scheme CreekSprout \
     -destination 'platform=macOS' -only-testing:CreekSproutTests/ZZWebParitySnapshotTests
   cp /Users/fengyifan/Library/Containers/com.fengyifan.CreekSprout/Data/tmp/native-parity/native-farm-1280.png /tmp/shots/
   ```
2. **Web 截图**(headless = 无存档 = 同站位):
   ```bash
   for p in $(lsof -ti tcp:4180); do kill $p; done
   cd /Users/fengyifan/Documents/VibeCoding/web/creek-sprout && npm run build
   (nohup node node_modules/vinext/dist/cli.js start --port 4180 >/tmp/v4180.log 2>&1 &)
   curl -s --retry 15 --retry-connrefused --retry-delay 1 -o /dev/null -w 'srv:%{http_code}\n' http://127.0.0.1:4180/
   '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --headless=new --disable-gpu \
     --hide-scrollbars --virtual-time-budget=7000 --window-size=1280,800 \
     --screenshot=/tmp/shots/web.png 'http://127.0.0.1:4180/'
   ```
3. **量化对比**(Python + PIL/numpy,注意机器无 ImageMagick):
   - 格映射:`格x=(屏幕x-64)/72`,`格y=(793-屏幕y)/72`
   - 逐格平均色差、最差行/列、砖红(196,94,59)与黄色质心、按 alpha 过滤的资产主色
   - 色类字符画(8-16px/字符 + 最近邻调色板)用于"看"布局
   - **比对世界内容时必须排除 y<52 与 y>742**:原生快照没有 SwiftUI HUD,Web 有 DOM HUD

## 当前差异(1280×800 初始站位,均值 29.8)

- 左右边缘 ≤2(已一致);中心区 8-30;水渠列 x998-1072 为 40-60;HUD 行 y33-43 为 58-65(测量假象,不算回归)
- 建筑砖红质心:sluice web(951.8,136.6) vs native(953.8,121.3);house web(501.7,172.9) vs native(487.7,141.4) → 仍有 15-31px 偏移待查

## 待办(按价值)

1. **HUD 对齐**:Web DOM HUD(`app/page.tsx` + `app/globals.css`)与原生 SwiftUI HUD 的材质/几何/字号对齐(原生快照不含 HUD,需用真机截图或原生 HUD 源码 `HudPresentationState.swift`/`ContentView.swift`)。
2. **水渠**:`WorldVisualCatalog.canalKeys`/`canalAnimationKeys` 多 tile 叠加与帧序;(市场)渠口/apron 差异。
3. **建筑 ±15-31px 微调**:逐层核对 `BuildingVisualPresenter`(层 anchor、`normalized`、`pixel_offset` 已用但可能还需 roof/occluder 的处理)。
4. **gather 节点与作物 display 锚点**:原生 `position.y=(spriteHeight-cellSize)/2`。
5. **天气 wash/雨滴 FX**、`WorldEffectPresenter` 帧。
6. **市场地图复核**:18 列 14 行;地图宽 1296>1280 时**没有**水平 bleed,相机 clamp 分支不同。
7. 对齐后:重跑门禁、提交候选、更新 `artifacts/…/release-manifest.md` 指纹与台账。

## 纪律

- 不部署、不置 PO-approved;每轮改动必须可回退。
- 每轮必跑:`npx tsc --noEmit`、`npm run build`、`npm run test:full`(20 断言)、`npm run audit:parity`(318 资产)。
- 只用像素证据判定"是否一致"(逐格差、质心、剖面对齐),不凭观感。
- 原生仓库里的 `CreekSproutTests/ZZWebParitySnapshotTests.swift` 仅用于生成对照图,不参与发布。
- 详细交接文档:`/Users/fengyifan/Documents/VibeCoding/macos/CreekSprout/docs/game/n-031-native-parity-handoff.md`

===
