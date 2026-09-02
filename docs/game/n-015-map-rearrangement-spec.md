# N-015 地图重排冻结规范

- 任务：`N-015`
- 决策：`DEC-035` 地图重排；拒绝纯视觉缩小
- 合同版本：`schema_version = 1`
- 坐标：`(0,0)` 在地图西南角，`x` 向东，`y` 向北；地砖为 `24×24 px`
- 状态：阶段 A 冻结候选；生产地图、碰撞和运行时消费者尚未修改

## 1. 任务合同与边界

玩家结果：农场能直接读成“农舍 + 农田 + 水工渠系”，集市能直接读成“临溪埠头 + 集市建筑 + 邻里活动区”；五栋建筑使用真实 footprint、入口、碰撞和遮挡语义，默认画面不再依赖文字占位。

| 项目 | 责任 |
|---|---|
| 专项 owner | 🎨 `art` / 🌱 `design`（本阶段仅合同） |
| 部门质量 owner | 🎭 `content`（视觉身份、原创性、空间连贯） |
| 跨部门 reviewer | 🧱 `tech`（机器一致性、存档与可达性） |
| 下游 | VSCode 阶段 B：只读验证器、负向门禁与 XCTest |

本阶段只新增本规范、机器合同与台账阶段记录。没有修改生产 Swift、Assets、blocked cells、出生点、出口、NPC 位置或 B4 消费者。

禁止范围：经济、价格、配方、任务规则、对白、稳定 ID、存档 schema、N-014 候选内容、N-016 正式音频。高清 2048 建筑图继续只用于展示卡，不能替代地图像素层。

## 2. 图例与视觉层级

| 标记 | 含义 |
|---|---|
| `#` | 环境边界/视觉缓冲，不可走 |
| `H` / `S` | 木构农舍 / 铜闸水工坊 footprint |
| `E` / `R` / `W` | 种源棚 / 巡护亭 / 苔石埠头 footprint |
| `D` / `I` | 建筑门 / 门外交互格 |
| `~` / `|` | 连续水体 / 南北水渠 |
| `=` | 主路径或湿石路 |
| `f` | 主要农田 |
| `X` / `@` | 出口 / 出生点 |
| `A` | 农场教学水工学徒 |
| `a,s,w,h,t,e,c` | 集市七 NPC：水工、种源、巡护、涧麦婶、石灯、青砚、絮宁 |
| `T` | 邻里石桌 |
| `g` | 采集/任务目标；精确 ID 见表格 |

渲染层固定为：

```text
terrain → path/water/canal → building base → structure → roof → detail
        → placed/gather/crop → actor feet/body → roof foreground occlusion
        → interaction → state_fx → world prompt → HUD → H debug
```

`roof` 可拆为后景与前景遮挡通道，但不参与碰撞；碰撞只取机器合同中的 `collision_cells`。默认画面不得出现“阻”“石阶”“采”或地标名称等诊断文字。

## 3. 农场与农舍：16×15

视觉结构：北侧两栋主建筑形成明确天际线；中部东西两片农田由纵向主路分开；东南小水池通过直线水渠接到水工坊；南端出口与两栋建筑入口由同一条清晰道路连接。`y=12...14` 主要是建筑原生画布的视觉缓冲；仅 `x=7...8,y=12...13` 四格按 N-019 开放为真实后田，`y=14` 仍完整阻挡。

```text
y14  # # # # # # # # # # # # # # # #
y13  # # # # # # # f f # # # # # # #
y12  # # # # # # # f f # # # # # # #
y11  . H H H H H . . . . S S S S S .
y10  . H H H H H . . . . S S S S S .
y09  . H H H H H . . . . S S S S S .
y08  . H H D H H . . . . S S D S S .
y07  . . . I = = = = = = = = I . . .
y06  . g . . . . . @ A . . . g . . .
y05  . . f f f f f = f f f f . | . .
y04  . . f f f f f = f f f f . | . .
y03  . . f f f f f = f f f f . | . .
y02  . . f f f f f = f f f f . | . .
y01  . . . . . . . @ . . . g ~ ~ ~ .
y00  . . . . . . . X . . . . ~ ~ ~ .
      0 1 2 3 4 5 6 7 8 9 A B C D E F
```

### 农场坐标

| 对象 | 坐标/范围 | 可达性与语义 |
|---|---|---|
| 木构农舍 | footprint `x=1...5,y=8...11`；门 `(3,8)`；交互 `(3,7)` | 门与交互格可走；其余 footprint 阻挡；从 `(7,6)` 经 `y=7` 横路可达 |
| 铜闸水工坊 | footprint `x=10...14,y=8...11`；门 `(12,8)`；交互 `(12,7)` | 门与交互格可走；其余 footprint 阻挡；东侧水工视觉连接直渠 |
| 主要农田 | `x=2...6,y=2...5` 与 `x=8...11,y=2...5` | 共 36 格主耕作面；旧 10×6 合法农田格仍保留，不清除旧作物 |
| 后侧农田 | `(7,12),(7,13),(8,12),(8,13)` | 四格真实可耕、可播种/浇水/成长/收获并写入现有存档；仍禁止玩家家具摆放 |
| 水池 | `x=12...14,y=0...1` | 不可走；六格分别使用单一 corner/edge 语义 |
| 水渠 | `x=13,y=2...7` | 不可走；全为 `ns`，不使用缺失的转角素材 |
| 主路 | `x=7,y=0...7`；`x=3...12,y=7` | 连接出口、两片农田、两栋建筑和出生点 |
| 后田引路 | `x=7,y=8...11` | 与现有石路同表现的展示层通路；`(7,11)` 打开围栏，接到后田，不写入权威 `path_cells` |
| 新档出生点 | `brookseed.spawn.farm_wake=(7,6)` | 不与 NPC、门或碰撞重叠 |
| 集市返回点 | `brookseed.spawn.farm_from_market=(7,1)` | 出口旁安全落点 |
| 农场出口 | `brookseed.exit.farm_to_market=(7,0)` | 到集市 `market_from_farm` |
| 教学水工学徒 | `(8,6)`；邻格 `(7,6),(8,5),(8,7),(9,6)` | 至少三条非出生邻格可交谈；不堵主路的纵向通行 |
| 溪木/芦纤维/苔石 | `(1,6)` / `(11,1)` / `(12,6)` | 均能从 wake spawn 以四向移动到达相邻/目标格；水渠东侧不放任务目标 |
| 湿土苗床地标 | `(5,3)` | 位于主农田，不靠文字才可辨 |

### 农场建筑遮挡

- 农舍屋檐遮挡格：`(1...5,8)`。
- 水工坊屋檐遮挡格：`(10...14,8)`。
- 水工坊 192 px 宽画布相对门中心向西偏移 12 px，使完整画布落在地图 `x=8...16` 世界边界内，不裁切侧水轮或闸管。
- 角色脚点进入门格时，只遮挡上半身；脚、门槛和交互徽章保持可见。
- 两栋建筑画布分别为 144×144 与 192×168；除后田四格外，`y=12...14` 的环境缓冲防止原生画布被裁切；`y=14` 始终不可走。

## 4. 溪岸集市：18×14

视觉结构：南侧三格深连续溪面形成强区域身份；苔石埠头完整落在水岸上方；中部双列主路保持南北贯通；种源棚与巡护亭分居北侧两翼，七 NPC 分散在临水、邻里、种源和巡护活动区，绝不占用 `x=8...9` 主路。

```text
y13  # # # # # # # # # # # # # # # # # #
y12  # . . . . . . . = X . . . . . . . #
y11  # . . . . . . . = @ . . . . . . . #
y10  # E E E . . . . = = . . . . R R R #
y09  # D E E s . . . = = . . . w R R D #
y08  # I = = = = = = = = = = = = = = I #
y07  # . = . = h T = = = = = = c . = . #
y06  # . = a . = . t = = . e . c . = . #
y05  # . = I = = = = = = = = = = = = . #
y04  # W W D W W g . = = . . g . . g . #
y03  # W W W W W . . = = . . . . . . g #
y02  ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
y01  ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
y00  ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
      0 1 2 3 4 5 6 7 8 9 A B C D E F G H
```

图中的 `W` 是苔石埠头 5×2 footprint，精确范围为 `x=1...5,y=3...4`；门 `(3,4)`、交互 `(3,5)`。ASCII 的水岸/footprint 交界只表达构图，机器合同是唯一精确来源。

### 集市坐标

| 对象 | 坐标/范围 | 可达性与语义 |
|---|---|---|
| 苔石埠头 | footprint `x=1...5,y=3...4`；门 `(3,4)`；交互 `(3,5)` | 与水岸相邻但不把水体烘焙进建筑；门可走，其余 footprint 阻挡 |
| 种源棚 | footprint `x=1...3,y=9...10`；门 `(1,9)`；交互 `(1,8)` | 从北市场横路可达；窗口/门不占 NPC 格 |
| 巡护亭 | footprint `x=14...16,y=9...10`；门 `(16,9)`；交互 `(16,8)` | 从北市场横路可达；网架不得侵入交互格 |
| 连续溪面 | `x=0...17,y=0...2` | 不可走；四角、四边和内部 base 各格只有一个 shoreline semantic |
| 主路 | `x=8...9,y=3...12` | 任何 NPC、建筑碰撞和石桌都不得占用 |
| 北市场横路 | `x=1...16,y=8` | 连接两栋小建筑与主路 |
| 临水横路 | `x=2...15,y=5` | 连接埠头、采集区与主路 |
| 集市出生点 | `brookseed.spawn.market_from_farm=(9,11)` | 与出口相隔一格，避免切图循环 |
| 集市出口 | `brookseed.exit.market_to_farm=(9,12)` | 返回农场 `(7,1)` |
| 邻里石桌 | `(6,7)` | 静态阻挡；位于广场侧，不堵主路 |
| 阻塞/复流水口 | `(16,2)` | 水体地标；恢复态由环境与 FX 表达，不显示文字 |
| 漂木/芦纤维/苔石/回水浅滩 | `(6,4)` / `(12,4)` / `(15,4)` / `(16,3)` | 均从主路可达；回水浅滩继续受既有 unlock ID 控制 |

### 七 NPC 与交谈邻格

| NPC 稳定 ID | 位置 | 可用交谈邻格 |
|---|---:|---|
| `brookseed.npc.water_apprentice` | `(3,6)` | `(2,6),(3,5),(3,7),(4,6)` |
| `brookseed.npc.seed_steward` | `(4,9)` | `(4,8),(4,10),(5,9)` |
| `brookseed.npc.creek_warden` | `(13,9)` | `(12,9),(13,8),(13,10)` |
| `brookseed.npc.neighbor_hearsay` | `(5,7)` | `(4,7),(5,6),(5,8)` |
| `brookseed.npc.neighbor_storyteller` | `(7,6)` | `(6,6),(7,5),(7,7)` |
| `brookseed.npc.neighbor_evidence` | `(11,6)` | `(10,6),(11,5),(11,7),(12,6)` |
| `brookseed.npc.neighbor_consensus` | `(7,11)` | `(6,11),(7,10),(7,12),(8,11)` |

七人坐标互不相同，不占出口、门、建筑交互格或 `x=8...9` 主路。每人至少一个交谈邻格可从 spawn 以四向移动到达。

### 集市建筑遮挡

- 埠头前景遮挡格：`(1...5,4)`。
- 种源棚屋檐遮挡格：`(1...3,9)`。
- 巡护亭屋檐遮挡格：`(14...16,9)`。
- 遮挡只影响角色上半身的渲染顺序，不改变 footprint、门或存档。

## 5. 水体与道路语义

每个水格始终渲染一个循环 base frame，并且最多选择一个 shoreline semantic：`base | edge_n | edge_e | edge_s | edge_w | corner_ne | corner_se | corner_sw | corner_nw`。corner 格不得再叠 edge；直边格不得叠另一个方向的 edge。`tile_water_edge.png` 只作为缺资源诊断回退，不得作为正常拓扑的第二层。

集市 18×3 矩形溪面确保四角、四边和内部 base 都有真实拓扑消费者。农场 3×2 水池与 `x=13` 直渠形成小型水工焦点。水渠只用 `tile_canal_ns`；本冻结方案不伪造不存在的拐角素材，也不把 `ns/ew` 叠在同一格。

道路是显式 `path_cells`，草地变体继续使用稳定散列；道路、水体和环境边界不从 PNG 透明度推断碰撞。

## 6. 五建筑六层映射（30/30）

所有文件 provenance 均为 `n006_base`，过滤为 nearest，运行时按原生像素画布与 24 px 网格整数缩放。层序固定为 `base → structure → roof → detail → interaction → state_fx`；六层本身都不贡献碰撞。

| 建筑 | footprint / 画布 | base | structure | roof | detail | interaction | state_fx |
|---|---|---|---|---|---|---|---|
| 木构农舍 | 5×4 / 144×144 | `building_farm_house_base.png` | `building_farm_house_structure.png` | `building_farm_house_roof.png` | `building_farm_house_detail.png` | `building_farm_house_interaction.png` | `building_farm_house_state_fx.png` |
| 铜闸水工坊 | 5×4 / 192×168 | `building_farm_sluice_base.png` | `building_farm_sluice_structure.png` | `building_farm_sluice_roof.png` | `building_farm_sluice_detail.png` | `building_farm_sluice_interaction.png` | `building_farm_sluice_state_fx.png` |
| 苔石埠头 | 5×2 / 144×96 | `building_market_wharf_base.png` | `building_market_wharf_structure.png` | `building_market_wharf_roof.png` | `building_market_wharf_detail.png` | `building_market_wharf_interaction.png` | `building_market_wharf_state_fx.png` |
| 种源棚 | 3×2 / 96×96 | `building_market_seed_shed_base.png` | `building_market_seed_shed_structure.png` | `building_market_seed_shed_roof.png` | `building_market_seed_shed_detail.png` | `building_market_seed_shed_interaction.png` | `building_market_seed_shed_state_fx.png` |
| 巡护亭 | 3×2 / 96×96 | `building_market_warden_post_base.png` | `building_market_warden_post_structure.png` | `building_market_warden_post_roof.png` | `building_market_warden_post_detail.png` | `building_market_warden_post_interaction.png` | `building_market_warden_post_state_fx.png` |

完整 SHA-256 与尺寸继续以 `artifacts/art-style/runtime-batch-r0/manifest.json` 和消费者矩阵为权威输入；机器合同冻结 filename、native size、层序和地图消费者，不复制 provenance 算法。

## 7. 角色比例合同

- 地砖逻辑尺寸保持 24 px；角色原生帧保持 32×48 px，不能复用 `cellSize / 24` 作为角色倍率。
- 角色以 bottom-center 脚点对齐所占格中心，目标世界高度为 `1.50 tile`，允许范围 `1.40...1.65 tile`；宽度不得超过 `1.15 tile`。
- 960×640 与 1280×800 使用同一角色世界高度合同，仅镜头/letterbox 变化，不按窗口尺寸单独拉伸角色。
- NPC 碰撞仍是一格；屋檐前后排序使用脚点 `y`，而不是 sprite 画布中心。
- reduced motion 使用对应方向的稳定静帧，脚点、碰撞和交谈邻格不变。

## 8. HUD 安全区

屏幕坐标原点在左上。矩形格式均为 `[x,y,width,height]`。

| 视口 | 默认世界安全区 | 左/右状态栏 | 工具栏 | toast / prompt | 建筑卡 |
|---|---|---|---|---|---|
| 960×640 | `[16,72,928,376]` | `[16,16,272,44]` / `[688,16,256,44]` | `[300,568,360,56]` | `[240,504,480,48]` / `[240,456,480,40]` | 临近 `[696,80,248,120]`；显式展开 `[568,80,376,400]` |
| 1280×800 | `[16,72,1248,528]` | `[16,16,304,44]` / `[960,16,304,44]` | `[456,728,368,56]` | `[360,656,560,48]` / `[360,608,560,40]` | 临近 `[976,80,288,128]`；显式展开 `[872,80,392,480]` |

建筑卡默认隐藏；临近时只显示紧凑卡，交互后才展开，并支持关闭。展开卡允许暂时缩小世界安全区，但不能与状态栏、toast、prompt 或工具栏重叠。toast 同时只显示最高优先级一条，优先级为 `error > warning > success`，默认 2.5 秒消退。H 调试层不参与默认布局。

## 9. 旧存档兼容与确定性迁移

存档 schema 保持 `v8`，不新增字段、不清档。规范化发生在 decode 后、SaveValidation 前。

旧边界：农场 `10×6`，集市 `10×8`。坐标策略：

1. 玩家位置若在新地图内且为可走格，保持不动。
2. 越界或落入新建筑碰撞、环境边界、静态障碍、水体、水渠或 NPC 占位时，枚举该地图所有安全格。
3. 候选按 `(曼哈顿距离升序, y 升序, x 升序)` 排序，选择第一格；算法无随机数且重复执行幂等。
4. 未知地图 ID 继续按损坏存档拒绝，不猜测目标地图。
5. 正常下一次保存将新坐标写回既有 `position` 字段，不写迁移标记。

农场的新建筑和环境边界全部位于旧 10×6 合法区之外；因此既有合法 `farmCells` 与 `placedObjects` footprint 原位保留，视觉道路不会让已合法的放置物失效。旧农场出口、被旧建筑占用的非法格本来就不是合法玩家位置。集市南侧新水体会使少数旧坐标成为新 blocked，按同一规则迁移玩家；NPC 坐标不在存档中，不需要 schema 迁移。

## 10. 可达性硬门禁

四向 BFS 必须使用机器合同中的精确 blocked union，至少验证：

- 两个出生点到对应出口；
- 农场 wake spawn 到主要农田、两栋建筑交互格、三个采集点和教学 NPC 交谈格；
- 集市 spawn 到三栋建筑交互格、七 NPC 各一个交谈格、四个采集/任务目标；
- 门、交互格、spawn、exit 和 NPC approach 不得在 blocked union 内；
- 五个 footprint 互不重叠且不越界；NPC 不占门、出口或 `x=8...9` 主路。

机器合同的 `reachability.required_pairs` 是最小权威集合；VSCode 阶段 B 必须加入建筑重叠、入口 blocked、不可达和缺层四类负向突变。

## 11. 原创性声明

本布局只复用农场生活模拟的通用约定：网格耕作、建筑入口、道路、水岸、集市活动区和四向移动。两图尺寸、建筑组合、道路/渠系、NPC 分布、视觉层级、HUD 组成及坐标均为本项目基于“中世纪溪谷水工社区”重新设计，不复用或描摹任何现有游戏的地图、角色、建筑立面、UI 排版、对白、图标或动画表达。

## 12. 阶段 A 门禁

- 🎨 art / 🌱 design specialist：合同已覆盖两图构图、五建筑、角色尺度、水体、HUD 与迁移。
- 🎭 content 跨角色审阅：`APPROVED`；两图无文字仍能区分，五建筑身份、原创边界与功能锚点一致。
- 🧱 tech 下游状态：`READY FOR VSCODE FOUNDATION`；该状态只允许阶段 B 建验证器，不批准任何生产实现。
- N-015 台账保持 `active / PENDING`；最终实现不得由本执行者自签 `APPROVED`。
