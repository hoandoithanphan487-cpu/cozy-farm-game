# 内容定义与稳定 ID

`content/` 下的 `.tres` 是权威设计数据；`src/content/` 的 Resource 脚本只定义结构与验证规则。运行时会话、背包、任务进度、风评和随机状态不得写入这些资源或 `ContentRegistry`。

稳定 ID 必须为小写 `namespace.category.name`，例如 `brookseed.crop.mist_radish`。显示名称、资源文件名和节点路径都不是业务键。已发布 ID 不可静默重命名或复用；未来存档迁移必须显式映射旧 ID。

目录按定义职责划分：

- `content/items`、`crops`、`recipes`、`shops`：经济与制作定义。
- `content/scenarios`：可重复的新游戏初始状态。
- `content/characters`、`dialogue`、`schedules`：角色与出现场景。
- `content/events`、`quests`：社区与主线内容。
- `content/weather`、`world/gather_nodes`：世界规则与保底采集。
- `content/world/locations`：地图 ID 与出生点目录，供启动验证器做可达性检查。

启动时 `ContentRegistry` 递归读取所有 `.tres`，按稳定 ID 建立只读索引，并让 `ContentValidator` 汇总错误。每条错误采用 `资源路径 | 字段或引用链 | 原因` 格式。开发构建会停止启动；发布构建显示可恢复的失败状态。
