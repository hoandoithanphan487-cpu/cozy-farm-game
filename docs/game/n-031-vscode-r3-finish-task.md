# N-031 R3：VS Code 完整收尾、真实验收与发布交接任务

下面整段可直接粘贴给 VS Code Agent：

---

你正在 `/Users/fengyifan/Documents/VibeCoding` 继续执行 **N-031 R3《溪谷新芽》完整浏览器移植**。

Product Owner 已说明上一轮执行结束，但仓库证据显示目前只完成了 **Canvas 视觉切片与部分预检**，还不是完整候选，也没有通过 N-031 的质量或视觉门禁。本任务不是重新开项目，而是在现有改动上继续收尾，直到形成可由 Product Owner 试玩的完整本地候选和可复现发布交接。

不要再次只写计划，不要停在“测试脚本显示数量存在”，不要把现有切片称为完整版。完成全部范围前，N-031 必须保持 `revise / REVISE`。

## 0. 先读取并遵守

完整读取：

1. `/Users/fengyifan/Documents/VibeCoding/AGENTS.md`
2. `/Users/fengyifan/Documents/VibeCoding/skills/cozy-farm-game-studio/SKILL.md`
3. `/Users/fengyifan/Documents/VibeCoding/skills/project-ledger/SKILL.md`
4. 上述 Skill 要求的角色和生产流程参考
5. `/Users/fengyifan/Documents/VibeCoding/docs/game/project-ledger.md` 全文
6. `/Users/fengyifan/Documents/VibeCoding/docs/game/n-031-vscode-full-web-port-r3-prompt.md` 全文
7. `/Users/fengyifan/Documents/VibeCoding/docs/game/n-031-full-web-port-brief.md`
8. `/Users/fengyifan/Documents/VibeCoding/docs/game/n-031-full-web-port-review.md`
9. `/Users/fengyifan/Documents/VibeCoding/artifacts/integration/n-031-web-r3/` 当前全部文件

前一份 R3 Prompt 的范围、唯一来源、零预算、固定网址、开屏排除、功能清单和发布门禁继续全部有效；本任务不缩减它们。

## 1. 角色与纪律

- Department：🧱 Engineering & Pipeline
- Specialist owner：🎮 gameplay
- Department quality owner：🧱 tech
- Consulted：🛠️ tools/data、✨ ux、🎨 art、🗺️ world、🎭 content、📖 narrative、⚖️ economy
- Cross-department reviewer：🛡️ quality
- Downstream owner：📦 release
- Final visual/release gate：Product Owner

当前不授权创建子代理或新的用户可见任务；顺序承担角色。实现者不能自签最终质量批准。

继续遵守：

- 不修改权威 macOS 工程 `/Users/fengyifan/Documents/VibeCoding/macos/CreekSprout`；只读并从中复制正式资产/数据。
- 不执行 `git reset`、`git restore`、`git checkout --`、`git clean` 或其他破坏性命令。
- 保留父仓库和 Web 子仓库所有既有用户改动。
- 只修改 `web/creek-sprout/`、`artifacts/integration/n-031-web-r3/` 和 N-031 必需文档。
- 手工编辑使用 `apply_patch`；机械生成和构建输出可以使用已有脚本。
- 每隔不超过 60 秒给 Product Owner 一条简短进度更新。
- 不部署、不覆盖公开网站，直到 Product Owner 看过完整本地候选并明确批准。

## 2. 当前事实基线

当前新增/修改：

- `web/creek-sprout/runtime/canvas-world.tsx`
- `web/creek-sprout/app/page.tsx`
- `web/creek-sprout/app/globals.css`
- `artifacts/integration/n-031-web-r3/{preflight.md,architecture.md,parity-matrix.md,source-manifest.json,visual-slice-review.md}`

当前已确认：

- `npm run test:full`：退出 0，但只是浅层数量/状态调用检查，不能证明真实玩家路径。
- `npx tsc --noEmit`：退出 0。
- `npm run build`：退出 0。
- `npx oxlint app/page.tsx runtime/canvas-world.tsx`：退出 1；`app/page.tsx:715` 的旧 `World` 函数未使用。
- `parity-matrix.md` 明确写着 `Full visual parity = missing`。
- `visual-slice-review.md` 明确写着完整 R22 拓扑和原生视觉等价均为 `REVISE`。
- 当前证据目录没有要求的浏览器截图、差异图、`asset-manifest.json`、`source-lock.json`、`web-handoff.md`、`quality-review.md` 或 `release-manifest.md`。
- 当前页面仍用 `localStorage` 单键存档；没有完成 R3 要求的 IndexedDB、三个手动槽、伴随档/保护点和原子备份语义。
- `runtime/canvas-world.tsx` 仍以硬编码道路、水面、水渠和通用草地近似地图，没有逐格消费 `n-015-map-layout-contract.json` 的完整 R22 拓扑与图层。
- 玩家仍使用静态 `char_player.png`，尚无四方向 walk/idle 和三种工具动作的完整帧驱动。
- Git 尚未形成新的验证提交；现有 HEAD 仍为旧 v2 `4793406`。

先重新记录两个工作区 `git status --short`，复跑以上四条命令，把结果追加到 `artifacts/integration/n-031-web-r3/preflight.md` 的“R3 finish baseline”小节。不要篡改或覆盖历史结果。

## 3. 必须关闭的 P0 缺口

以下任何一项未关闭，本任务不得提交为完成。

### P0-1：删除旧近似渲染路径

1. 删除或最小移除 `app/page.tsx` 中未使用的旧 `World` 实现。
2. 删除只服务旧 CSS 拼图地图且不再被引用的 `.world`、`.stone-road`、`.creek`、`.farm-canal`、`.world-object` 等样式；保留仍被真实 UI 使用的样式。
3. 加入静态检查，阻止旧 CSS 地图、emoji、文字方块或占位图重新成为世界渲染来源。
4. 修复定向 lint，使其退出 0；不得用全局禁用规则掩盖未使用代码。

### P0-2：完整 R22 地图与图层

1. 以以下权威输入构建确定性 Web 地图数据：
   - `docs/game/n-015-map-layout-contract.json`
   - `docs/game/n-019-approved-art-inventory.md`
   - `macos/CreekSprout/CreekSprout/Content/MapDefinition.swift`
   - `macos/CreekSprout/CreekSprout/Content/WorldCatalog.swift`
   - `macos/CreekSprout/CreekSprout/FarmScene.swift`
   - `macos/CreekSprout/CreekSprout/Presentation/DisplayR2/`
   - `macos/CreekSprout/CreekSprout/Presentation/WorldLife/`
2. 不再在 `canvas-world.tsx` 中手写“某行全是水”“某列全是水渠”“固定十字道路”作为近似。
3. 明确且可测试地绘制：地形底层、变化草地、路径、水体边/角/动画、水渠、耕地、建筑六层、遮挡层、装饰、采集物、动物、NPC、玩家、动作 FX、目标框和前景。
4. 两张地图的尺寸、格坐标、建筑 footprint、碰撞、遮挡、出口、NPC/动物/采集锚点必须与权威合同一致。
5. 修复缩放与坐标变换：屏幕绘制、指针命中、目标格和逻辑格使用同一变换；宽高比变化不能拉伸地图、错位点击或裁掉必要交互区。
6. 像素图使用 nearest-neighbor，优先整数缩放；必须记录非整数视口的 letterbox/相机策略。

### P0-3：正式角色、动画和反馈

1. 玩家使用四方向 idle/walk 帧，并根据逻辑方向切换。
2. 锄地、浇水、收获分别消费正式 action spritesheet/帧；完成动作后恢复 idle。
3. 7 名 NPC 使用各自正式静态/行走资源，不允许只画名字标签来表示角色。
4. 水体、水渠和关键 FX 使用正式动画帧且遵循 `reducedMotion`。
5. 建筑、角色、作物和道具的比例、锚点、阴影/遮挡以本地 App 为准，不能自行拉伸填满格子。

### P0-4：真实存档架构

1. 把正式游戏状态从单键 `localStorage` 迁移到版本化 IndexedDB。
2. 实现三个手动槽、自动/伴随档、Q08 任务前保护点、Q09 揭露前保护点、最近有效备份。
3. 设置可以继续使用小型 localStorage，但游戏进度不能只依赖 localStorage。
4. 保存流程必须：序列化 → 完整校验 → 临时写入 → 回读确认 → 原子替换 → 更新备份。
5. 覆盖：刷新恢复、关闭重开、升级迁移、损坏主档回退、非法导入拒绝、覆盖二次确认、导出/导入往返一致。
6. 不声称 Web 存档可直接读取 macOS 原生存档；只保证行为字段等价。

### P0-5：内容必须真实可玩

当前 `verify-full-game.ts` 直接调用函数和循环 `advanceStory()`，只能证明函数存在。必须增加由真实输入/世界锚点驱动的集成测试和浏览器端到端路径，证明：

- 两图移动、碰撞、换图和对象交互；
- 五作物完整农耕循环；
- 出售、制作、加工、放置、采集、水脉；
- 7 名 NPC 各自可达交谈；
- 三种动物照料与猫店作物/动物交易；
- Q01–Q07 由成熟度、预警、相关行动和前台互斥推进，不是任意点“下一阶段”；
- Q08 三检查点、中断恢复、放弃回滚和 exactly-once 返乡；
- Q09 保护点必须先成功写入，Q10 `water / leave` 均可从保护点走通；
- 结局画廊、设置、帮助、美术巡礼和存档管理均有入口。

若现有领域模型缺少上述原生语义，补齐纯 TypeScript 状态和事务，不要用 UI 状态或静态说明绕过。

## 4. 权威清单与漂移保护

1. 保留并校正 `source-manifest.json`。
2. 新增 `asset-manifest.json`：权威路径、Web 路径、大小、SHA-256、尺寸、用途、消费者、转换记录。
3. 新增 `source-lock.json`：本次移植依赖的 Swift、合同、内容稿和正式资产哈希。
4. 新增确定性审计命令，例如 `npm run audit:parity`：
   - 权威文件变化时明确失败；
   - Web 副本缺失/哈希漂移时失败；
   - 稳定 ID、内容引用、资源消费者或地图坐标不一致时失败；
   - 输出机器可读 JSON 和人类摘要。
5. `parity-matrix.md` 必须扩展到逐系统/逐屏幕/逐地图层/逐关键剧情路径，而不是当前 10 行摘要。
6. 除 Product Owner 主观视觉签字外，最终矩阵不得残留 `missing` 或未解释的 `implemented`；机器可验证项必须达到 `verified`。

## 5. 真实浏览器证据

本任务明确授权对本地候选做浏览器 UI 测试、点击、键盘、触摸模拟、截图和不同视口检查。不得用静态 HTML 或离屏合成代替。

至少执行：

1. 无存档打开 → 直接进入 Day 1 农场，无开屏。
2. 移动 → 翻土 → 播种 → 浇水 → 睡眠成长 → 收获。
3. 出售 → 睡眠结算 174 → 刷新/重开不重复到账。
4. 农场与集市双向换图、边界碰撞和指针命中。
5. 7 NPC 交谈、采集、制作、加工、放置、水脉 12+8。
6. 动物照料、猫店作物交易、动物取消保护和成功收据。
7. Q01–Q07 主路径和至少一个关键分支。
8. Q08 三检查点 → 中途刷新 → 继续 → 返乡；另测放弃。
9. Q09 保护点 → Q10 water；恢复保护点 → Q10 leave。
10. 结局画廊、设置、输入绑定、导出/导入、损坏回退和美术巡礼。
11. 1280×800、1280×900、960×640、390×844 四个视口。
12. 至少两个独立浏览器上下文证明存档互不串用。

保存到：

`artifacts/integration/n-031-web-r3/browser-evidence/`

每条路径必须有：步骤日志、关键截图、终态 JSON 摘要和 PASS/FAIL。任何 FAIL 都必须修复后重跑，保留首次失败记录。

## 6. 视觉对照门禁

对照以下原生证据：

- `artifacts/integration/n-019-demo-visual/visual-feedback-r22/real-app/screenshots/`
- `artifacts/integration/n-027-main-story-runtime/runtime/screenshots/`
- `artifacts/integration/n-019-demo-visual/` 中农场、集市、猫店和美术巡礼证据

至少制作以下成对截图与差异说明：

- 农场默认画面；
- 集市默认画面；
- 作物/农具动作；
- NPC 对话与立绘；
- 猫店/动物；
- Q08 旅程；
- Q09/Q10；
- 结局画廊；
- 暂停/设置。

更新 `visual-slice-review.md` 为完整 `visual-parity-review.md`，逐项检查：地图拓扑、构图、相机、比例、HUD、图层、遮挡、角色身份、动画、色彩、文字和平台合理差异。

自动化和内部复核不能代替 Product Owner。你只能把完整候选标为 `READY FOR PO VISUAL REVIEW`，不得自己写 `PO-approved`。

## 7. 测试与构建门禁

最终必须全部退出 0：

```bash
cd /Users/fengyifan/Documents/VibeCoding/web/creek-sprout
npm run audit:parity
npm run test:full
npx tsc --noEmit
npx oxlint app/page.tsx runtime lib persistence scripts
npm run build
git diff --check
```

目录名可按最终结构调整，但不得通过遗漏新增文件来获得 lint 通过。

额外要求：

- `test:full` 要输出断言数量和分组结果，不能只输出功能名计数。
- 浏览器 E2E 必须使用生产构建或等价候选，而不是只测开发热更新页面。
- 运行 20 个并发匿名请求，覆盖主页、入口脚本、地图、玩家资源、剧情 JSON 和两首音乐；保存状态码和失败数。
- 检查构建产物没有单文件超过 25 MiB，没有密钥、绝对本机路径或原生二进制。
- 确认 `.openai/hosting.json` 仍为既有项目且 `d1/r2` 为空。

## 8. 必须生成的交接物

完成后必须存在：

- `artifacts/integration/n-031-web-r3/preflight.md`
- `artifacts/integration/n-031-web-r3/architecture.md`
- `artifacts/integration/n-031-web-r3/source-manifest.json`
- `artifacts/integration/n-031-web-r3/asset-manifest.json`
- `artifacts/integration/n-031-web-r3/source-lock.json`
- `artifacts/integration/n-031-web-r3/parity-matrix.md`
- `artifacts/integration/n-031-web-r3/visual-parity-review.md`
- `artifacts/integration/n-031-web-r3/browser-evidence/`
- `artifacts/integration/n-031-web-r3/web-handoff.md`
- `artifacts/integration/n-031-web-r3/tech-review.md`
- `artifacts/integration/n-031-web-r3/quality-review.md`
- `artifacts/integration/n-031-web-r3/release-manifest.md`

`release-manifest.md` 必须包含：生产构建命令、构建文件数/大小、关键 SHA-256、精确 Web Git 提交、现有 Sites project_id、现有 v2 回滚提交/部署、匿名/并发探针计划和是否具备 Sites 发布工具。

## 9. Git 与发布边界

1. 完整测试通过后，只在 `web/creek-sprout` 子仓库创建一个精确候选提交。
2. 不提交父仓库无关脏文件。
3. 提交后再次确认候选 SHA 与构建来源一致；源码变更后必须重新构建和更新 SHA。
4. 此任务默认停在：`READY FOR PO VISUAL REVIEW`。
5. 把完整本地预览 URL、关键截图和验收清单交给 Product Owner。
6. 没有 Product Owner 明确说“视觉可以，并批准覆盖现有公开网站”，禁止部署。
7. 若 Product Owner 后续批准且当前环境具备 Sites 工具：复用 `appgprj_6a9d68fc11cc819193943a08181b0e37` 和原固定网址，不新建站点；按 Sites 流程保存版本、部署、轮询并验证。
8. 若没有 Sites 工具：保持 `READY FOR CODEX RELEASE`，给出精确提交和构建包，由 Codex 同址发布；不得改用其他平台。

## 10. 完成回复格式

只按以下结构回复：

1. `Status: READY FOR PO VISUAL REVIEW | REVISE | BLOCKED`
2. 本地候选 URL
3. 完成的玩家路径
4. 与原生 App 的一致项、合理平台差异和仍有差异项
5. 自动化、浏览器、存档、视口、并发和构建结果
6. 精确 Web Git 提交 SHA
7. 证据目录和关键截图
8. 各门禁精确状态
9. 是否已部署（本任务没有 PO 新批准时必须回答“未部署”）
10. 唯一下一负责人：Product Owner

没有上述全部证据时，不得再次回复“已完成”。

---
