# N-015 运行时消费者与 HUD 字段合同

状态：基础合同 v2；B1 首个实现切片已落地，表中“待接”仍不得当作运行时完成。

## 1. 131 张正式像素资产的消费者计划

| 家族 | 数量 | 文件规则 | 唯一计划消费者 | 触发状态 / 说明 | 当前状态 |
|---|---:|---|---|---|---|
| 角色静态像 | 8 | `char_<actor>.png` | `CharacterVisualCatalog` / `PixelAssetStore` | 玩家 + 7 NPC 的静止/安全回退 | 8/8 已建立正式静态图映射 |
| 角色行走表 | 8 | `char_<actor>_walk.png` | `SpriteSheetAnimator` | 4 方向 × 4 帧；角色移动时播放 | 待接 |
| 玩家动作表 | 3 | `char_player_action_<tool>.png` | `PlayerActionPresenter` | 锄地、浇水、收获；动作完成回 idle | 待接 |
| 作物物品图 | 5 | `crop_<crop>.png` | `InventoryItemIconPresenter` / `CompactFarmHudView` | 背包、出售箱、配方材料、种子/作物摘要 | 5/5 已映射；播种 HUD 实际复用当前种子图 |
| 作物世界阶段 | 20 | `crop_<crop>_stage_0..3.png` | `FarmScene.makeCropNode` | 领域成长阶段映射到 0..3；不从天数直接猜图 | 20/20 已按 crop ID + stage 动态解析；五种均可种 |
| 草地 | 4 | `tile_grass(.png/_a/_b/_c)` | `PixelAssetStore.tileKind` | 基础回退 + 由 mapID/x/y 稳定散列选择 3 变体 | 4/4 已建立确定性解析 |
| 耕地 | 2 | `tile_tilled(.png/_watered)` | `PixelAssetStore.tileKind` | 已翻土干燥 / 已翻土浇水 | 2/2 已接 |
| 水体 | 13 | `tile_water_edge.png`、`tile_water_f00..03`、四边、四角 | `WaterVisualResolver` | 4 帧循环；邻接掩码选择边/角；legacy edge 仅作安全回退 | 待地图语义/邻接合同 |
| 石路 | 1 | `tile_stone_path.png` | `TerrainVisualResolver` | 地图显式 path cell；不随机铺设 | 待地图语义合同 |
| 水渠地块 | 2 | `tile_canal_ns/ew.png` | `CanalVisualPresenter` | 由既有 facing/连接方向选择，不改存档 schema | 待接 |
| 五建筑六层 | 30 | `building_<building>_<layer>.png` | `BuildingVisualPresenter` | base→structure→roof→detail→interaction→state_fx | [布局冲突审计](n-015-building-layout-audit.md) 已证明现地图不可直接落完整 footprint；B4 等待拓扑决策 |
| 摆放道具 | 7 | `prop_*.png` | `FarmScene.makePlacedObjectGlyph` | 按 placed object kind/facing；stone path 仍是摆放物语义 | 六个基线道具 + DEC-033 木蜜灶台已有解析；方向变体仍待 B3 |
| 采集物 | 3 | `gather_*.png` | `GatherableVisualPresenter` | 可采集时显示；耗尽/冷却时隐藏或显示状态，不删除领域记录 | 待接 |
| 工具图标 | 3 | `tool_*.png` | `CompactFarmHudView` | 锄头、浇水壶、收获手套；播种使用当前种子物品图 | 3/3 已接；G5 已由 DEC-033 解除 |
| 目标 FX | 4 | `fx_target_valid/invalid_f00..01` | `TargetFeedbackPresenter` | 目标格有效/无效两帧轻动画 | 待接 |
| 浇水 FX | 4 | `fx_water_splash_f00..03` | `WorldEffectPresenter` | 浇水命令成功后一次播放 | 待接 |
| 收获 FX | 4 | `fx_harvest_f00..03` | `WorldEffectPresenter` | 收获命令成功后一次播放 | 待接 |
| 水渠流动 FX | 4 | `fx_canal_flow_f00..03` | `CanalVisualPresenter` | 水渠状态允许流动时循环 | 待接 |
| HUD/UI | 7 | `ui_interact_badge`、`ui_slot(_selected)`、`ui_time/weather/stamina/currency` | `CompactFarmHudView` | 交互提示、工具栏、四项状态 | 四项状态图已接；交互徽章与槽位图待后续工具栏 |
| **总计** | **132** |  |  |  | 完整性 132/132；机器审计已解析 53/132，余 79 张待 B2–B5 |

消费者覆盖的验收口径：必须能从每个文件反查到表中唯一 presenter，并能从 presenter 的状态分支反查到玩家可触发路径或 PO 批准的技术回退用途。仅存在于 App Bundle 不算消费。

## 2. 统一资产描述符字段

```swift
struct RuntimeArtDescriptor {
    let key: RuntimeArtKey
    let filename: String
    let nativeSize: PixelSize
    let frameLayout: FrameLayout
    let anchor: SpriteAnchor
    let layer: RenderLayer
    let filtering: TextureFiltering // pixel layer 固定 nearest
    let fallback: RuntimeArtKey?
    let provenance: ArtProvenance
}
```

约束：

- `filename` 只允许集中出现在 catalog/manifest adapter，场景不得再次硬编码。
- `FrameLayout` 必须验证图片尺寸可以整除；越界帧记录诊断并使用 fallback。
- `provenance` 必须区分 N-006 base 与 N-003 approved override。
- `RuntimeArtKey` 不写入存档；存档继续保存领域 ID、状态和朝向。

## 3. HUD 类型化字段

```swift
struct HudPresentationState {
    let calendar: CalendarStatus       // day, phase, clockText
    let weather: WeatherStatus         // iconKey, label
    let resources: ResourceStatus      // stamina, staminaMax, currency
    let toolbelt: [ToolbeltSlot]        // iconKey, count, selected, enabled
    let focus: FocusStatus?             // targetCell, action, valid, reason
    let quest: QuestSummary?            // title, objective, progress
    let toast: HudToast?                // success / warning / error, expiresAt
    let contextualPrompt: InputPrompt?  // 当前输入上下文的单一主操作
    let debug: DebugHudState?            // 仅 H 显式开启时非 nil
}
```

默认信息层级：

1. 左上：日期/时段/天气；
2. 右上：体力/溪票；
3. 底部中央：5 个紧凑工具槽；
4. 目标格附近：有效/无效 FX，不用大段文字遮挡地图；
5. 屏幕下缘：短时反馈与一个上下文操作提示；
6. 任务摘要默认单行，可展开；
7. 坐标、地图 ID、存档诊断、完整命令帮助只进入 H 调试层。

禁止：从 `HudCopy.assemble()` 输出文本反向解析 HUD 状态。过渡期允许它继续给调试层供值，成品组件必须直接读 `HudPresentationState`。

## 4. 地图视觉数据合同

领域地图保持当前可通行、阻挡、出口和 NPC 位置。新增的只读呈现数据必须独立存在：

```text
mapID
  terrain cells: grass | stonePath | water | canalNS | canalEW
  water adjacency: N/E/S/W bit mask
  landmark visual: asset family, anchor cell, pixel offset,
                   visual footprint, entrance cell, occlusion split
```

- `visual footprint` 可以覆盖多格，但绝不自动加入 `blockedCells`。
- `entrance cell` 必须沿用现有可达交互位置；若冲突，先调整视觉锚点，不改领域地图。
- 草地变体使用确定性散列，不写入存档也不会每次启动变化。
- 建筑 roof/foreground occluder 只遮挡人物上半身；人物脚点与交互提示保持可读。

## 5. B1 最小文件边界

B1 只允许建立 catalog/presenter、农场视觉数据、紧凑 HUD、DEC-033 最小增量与对应测试；不得：

- 超出 DEC-033 的四种既有作物耕种/初始种子合同；
- 修改经济数值、配方、任务条件或存档 schema；
- 移动 NPC、出口、领域 blocked cells；
- 接入 N-014 猫店/三猫候选；
- 删除程序化回退；
- 同时改造集市、五建筑、全部 FX，导致无法独立审查。
