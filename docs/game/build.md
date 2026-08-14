# 构建与引擎基线

## P0-001：引擎锁定

| 项目 | 锁定值 |
|---|---|
| 编辑器 | Godot Engine **4.7.1** 标准版（非 .NET） |
| 语言 | 强类型 GDScript |
| 渲染器 | Godot 2D Compatibility（`gl_compatibility`） |
| 当前开发机 | macOS arm64（Apple Silicon） |
| 发行目标 | macOS arm64 |
| 网络要求 | 垂直切片与发行烟雾路径必须支持断网运行 |

此锁定值同时写入根目录的 [`project.godot`](../../project.godot)。其中 `config/engine_version_lock` 保存精确补丁版本；`config/features` 使用 Godot 的 4.7 特性标签。不得以“最新 4.x”替代精确版本号。

## 当前范围

`project.godot` 仅保存 P0-001 所需的项目名称、引擎版本锁定和 Compatibility 渲染器。M0-001 负责 Bootstrap、输入映射、日志、目录结构、场景与 macOS arm64 导出预设；必须遵守 P0-006 的 macOS 参考设备与验收夹具合同。DEC-012 将当前发行范围限定为 macOS arm64。

## 平台验收入口

P0-006 的 macOS 参考设备、离线操作、证据目录、指标和分层夹具合同见[macOS 参考设备与验收夹具计划](platform-acceptance-plan.md)。参考设备为 13 英寸 M4 MacBook Air（16 GB / macOS 26.5.2 / 60 Hz）；M0-001 已有 macOS 空工程离线启动证据，后续 M4-002 按该合同完成发布候选验收。

发布候选阶段按该计划在 macOS 参考设备上保存 `artifacts/acceptance/<candidate-build-id>/macos-arm64/` 证据包；不得以开发机可运行编辑器或计划文本替代断网安装、启动、输入、保存读取和 VS-0 路径证据。

## 编辑器与构建检查

1. 使用 Godot 4.7.1 标准版打开仓库根目录。
2. 在 Project Settings 确认 Rendering Method 为 Compatibility。
3. 在编辑器的 Project Manager 或项目配置中确认项目使用 4.7 系列；以 `project.godot` 的 `config/engine_version_lock = "4.7.1"` 作为补丁版本权威记录。
4. M0-001 创建空工程后，在 macOS arm64 验证离线启动；M4-002 再执行 macOS arm64 完整发布导出、安装、保存读取和 VS-0 烟雾测试。

## 本机无头测试入口

当前 macOS 开发机的 Godot 4.7.1 App 位于 `/Users/fengyifan/Downloads/Godot.app`，未加入 shell `PATH`。在未配置 PATH 前，使用其完整二进制路径运行测试：

```zsh
/Users/fengyifan/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path /Users/fengyifan/Documents/VibeCoding \
  --script res://tests/test_runner.gd
```

这只是开发机命令入口，不改变本项目锁定的 Godot 4.7.1 标准版或发行验收要求。

## 升级策略

1. 任何 Godot 升级都必须先由 Product Owner 批准，并更新项目台账中的决策记录。
2. 在独立分支上升级 `config/features` 与 `config/engine_version_lock`，不得在开发分支静默更换编辑器版本。
3. 升级候选必须通过现有自动测试、存档兼容/迁移检查、macOS arm64 离线启动，以及相应阶段的性能与烟雾验证后，才可合并。
4. 未通过验证时，恢复到 4.7.1；不得用未验证的版本创建、迁移或发布存档。
