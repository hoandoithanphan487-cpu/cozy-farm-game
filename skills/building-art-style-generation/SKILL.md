---
name: building-art-style-generation
description: Generate original cozy medieval valley building art under the CreekSprout master style, including silhouette review, layered pixel production, import, runtime validation, and acceptance evidence.
---

# 建筑美术风格生成 Skill

这是《溪谷新芽》建筑素材的唯一执行流程。开始前必须完整读取：

1. [美术风格 Master Doc](../../docs/game/art-style-master-doc.md)
2. [建筑规范模板](../../docs/game/building-art-style-spec-template.md)

后续 prompt 只能引用这三份文件；不能引用《星露谷物语》或其他作品的具体像素、调色板、建筑、角色、UI、地图或动画作为风格条件。外部资料最多用于确认技术格式，不得改变视觉结论。

## 角色与门禁

- 专项负责人：🎨 `art`，负责概念、silhouette、分层资产与生成记录。
- 部门质量负责人：🎭 `content`，负责一致性、原创性、内容可达性和视觉身份。
- 工程质量负责人：🧱 `tech`，负责导入、渲染层、碰撞/交互映射、性能和运行时证据。
- 独立最终验收：🛡️ `quality`，负责逐条验收、回归、无障碍与证据完整性。
- 禁止专项负责人自我批准；同一人兼任时，必须由跨部门负责人签发 `APPROVED`、`REVISE` 或 `BLOCKED`。

## 输入与输出

输入只能来自 Master Doc 和建筑规范模板：建筑功能、占地网格、升级状态、交互点、环境位置、目标层数和必要的原创识别件。

输出至少包括：

- 三剪影评审页与选定记录；
- `base/structure/roof/detail/interaction/state_fx` 六层资产；
- 生成参数、迭代记录、原创性检查记录；
- 像素检查报告、导入配置、运行时截图和验收矩阵。

## 工作流

### 1. 覆盖设计（coverage design）

先填写模板，不得先画图。确认建筑在以下覆盖面都有证据：

- 功能覆盖：玩家一眼知道它做什么；
- 空间覆盖：footprint、入口、门前站位、碰撞和遮挡明确；
- 状态覆盖：正常、使用中/打开、升级后、受损或不可用（按需求选用）；
- 视觉覆盖：远景 silhouette、中景材质、近景识别件；
- 生产覆盖：六层拆分、颜色预算、目标像素尺寸、文件命名和运行时 ID。

覆盖设计输出后，由 `content` 返回 `APPROVED | REVISE | BLOCKED`。未 `APPROVED` 不进入剪影。

### 2. 三剪影评审

为同一建筑制作三个互不只是换色的方案：

- **A 功能优先**：入口、操作面、工作装置最清楚；
- **B 轮廓优先**：远距离识别最强，屋顶/基础形成独特外形；
- **C 叙事/环境优先**：把溪谷水工、木石层叠或地形关系融入外轮廓。

每个方案仅用 1–3 个明度块，不放纹理、文字、角色或复杂装饰。分别检查 1×、2×、灰度和纯色缩略图。评审表必须记录：功能可读性、独特性、网格可生产性、遮挡风险、与既有建筑的相似风险。`content` 选择方案并返回 `APPROVED | REVISE | BLOCKED`；若全部近似或不可读，`BLOCKED` 并退回重新构思。

### 3. 分层生产

按以下顺序生产，所有层使用同一画布、原点、基线和调色板：

1. `base`：地基、阴影、不可移动的接地关系；
2. `structure`：墙体、木梁、石基、门洞主体；
3. `roof`：屋顶、屋脊、檐口和遮挡层；
4. `detail`：原创功能件、窗、旗帜、工具、木牌；
5. `interaction`：入口高亮、工作面、可点击锚点，不烘焙到静态底图；
6. `state_fx`：开门、蒸汽、水流、升级闪光、损坏提示等短时状态。

层文件必须能独立隐藏/显示。碰撞、交互和遮挡数据使用稳定 ID，不从像素颜色推断。升级资产复用不变层，替换或叠加变化层，并保留可回退的旧状态。

### 4. 像素检查

提交前执行以下检查并记录结果：

- 尺寸符合模板，宽高是 24 px 网格的整数关系；
- 所有缩放倍率为整数，1× 查看边缘无抗锯齿；
- 调色板只来自 Master Doc，逐层色数不超模板预算；
- 轮廓无全局纯黑粗边，暗部使用深溪墨/湿石褐/栗木影的分工；
- 无半透明软边、渐变、照片纹理、隐藏文字或未声明的 sprite；
- silhouette、入口、基础和屋顶层级在灰度/纯色缩略图仍可读；
- 动画帧基线、锚点、轮廓和色票一致；
- 透明边界、命名、层顺序和版本号正确。

失败项必须标注为 `REVISE`，不得以截图“看起来差不多”代替检查。

### 5. 运行时导入

🧱 `tech` 按项目当前运行端执行导入：Xcode + Swift + SpriteKit。资产进入约定的 `Assets/` 路径后：

1. 使用 `SKTexture` 或项目等价纹理入口加载；
2. 强制 `filteringMode = .nearest`，禁止线性插值和自动抗锯齿；
3. 使用整数缩放与稳定锚点；
4. 按 `base → structure → roof → detail → interaction → state_fx` 叠加；
5. 绑定建筑稳定 ID、footprint、碰撞、入口和交互点；
6. 保留加载失败时的可读占位/回退，不阻断存档与核心路径；
7. 检查纹理缓存与 draw/内存预算，避免每帧重新加载或生成图像。

技术导入门禁需提供：配置 diff、资产存在性/尺寸检查、nearest 断言、稳定 ID 映射、运行时加载日志或等价证据。工程负责人返回 `APPROVED | REVISE | BLOCKED`。

### 6. 运行时验收

在目标运行端至少验证：

- 新游戏加载建筑，远景/近景轮廓均清晰；
- 玩家可从约定入口接近、交互、离开，碰撞不穿透；
- 打开/使用/升级/受损状态的层切换正确，反馈不只依赖颜色；
- 角色遮挡关系、屋顶前后层级和门前站位正确；
- 退出、重启、存档/读档后建筑状态与稳定 ID 一致；
- 2× 或更高整数放大保持锐利，无线性模糊；
- 键鼠/手柄、UI 缩放、闪烁减少和文字/图标辅助反馈不回归；
- 既有核心测试基线通过，且没有改动经济、领域、存档 schema 或无关音频。

### 7. 原创性与质量验收

`content` 逐项确认：没有复制或近似具体游戏的建筑、角色、地图、UI 或动画；三剪影有真正不同的设计意图；材质、色票、身份与溪谷世界一致。

`quality` 独立按模板验收并只返回一个门禁状态：

- `APPROVED`：所有证据齐全，允许进入下游集成；
- `REVISE`：列出具体失败项并退回专项负责人；
- `BLOCKED`：指出外部依赖或未决产品选择，交由 `director`/Product Owner 处理。

## 交付记录格式

```markdown
Outcome:
Changed artifacts:
Silhouette decision:
Pixel-check evidence:
Import/runtime evidence:
Originality review:
Risks and follow-ups:
Requested gates: content / tech / quality
```

## Prompt 生成规则

生成 prompt 时只把模板中的变量替换为建筑事实；必须带上 Master Doc 的暖色中世纪溪谷像素语言、24×24 网格、清晰 silhouette、六层生产、nearest/整数缩放和原创性红线。禁止加入外部作品名、画师名、“像某某游戏”、外部色板、写实材质、3D 渲染或未经批准的新颜色。
