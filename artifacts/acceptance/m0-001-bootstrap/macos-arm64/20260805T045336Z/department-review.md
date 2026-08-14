# M0-001 部门门禁复核

## 🧱 tech — Engineering & Pipeline

Gate status: **BLOCKED**

Scope reviewed:

- `project.godot` 保留 `config/engine_version_lock = "4.7.1"` 和 Compatibility 渲染器，并将启动场景指向 Bootstrap。
- `scenes/bootstrap/bootstrap.tscn`、`src/core/bootstrap.gd` 和 `src/core/game_log.gd` 仅提供空工程启动、InputMap 检查和分类日志；没有实现 ContentRegistry、SaveCodec、SaveService、SettingsService、SceneRouter 或任何农耕、库存、HUD、角色、任务、经济、VS-0 内容。
- `export_presets.cfg` 声明 Windows Desktop x86-64 和 macOS arm64 两个目标。

Evidence inspected:

- `logs/static-validation.txt`：21 个基础动作、9 个日志分类、双平台导出目标和 `git diff --check` 退出 0。
- `logs/godot-headless-20260805T053821Z.txt`：Godot 4.7.1 无头启动成功，Bootstrap 记录 `engine_lock=4.7.1`。
- `logs/godot-offline-start-20260805T054700Z.txt` 与 `offline/network-disabled.txt`：关闭 `en0` 后启动成功，清理步骤确认 Wi-Fi 已恢复开启。
- `logs/godot-export-macos-arm64-20260805T054803Z.txt`：预设已被 Godot 读取；修正 ETC2/ASTC 配置后，仅因模板缺失而导出失败。

Acceptance gaps:

1. macOS 4.7.1 导出模板 `macos.zip` 不存在，因此无法生成可安装 arm64 `.app` 以验证导出产物。
2. Windows 实机未执行；这符合 DEC-007 的暂缓范围，但仍是发布前必须恢复的独立证据。

Conditions or required revisions:

安装 Godot 4.7.1 标准版对应的 macOS 导出模板，重跑 macOS arm64 导出与导出包的离线启动，保存包校验值后重新提交 tech 门禁。

Next gate or escalation:

保持 M0-001 `active / BLOCKED`；完成上述运行证据后由 🧱 tech 复审，再交 🛡️ quality 独立验收。

## 🛡️ quality — Independent evidence review

Gate status: **BLOCKED**

Scope reviewed:

- 证据包按平台、运行 ID、身份、设备、网络与日志分开保存；未将 macOS 结果写成 Windows 或 VS-0 通过。
- 清单明确区分成功的源码工程断网启动与未生成的导出包，并保留 Windows、存档、性能和 VS-0 缺口。

Evidence inspected:

- `manifest.md`、`device-profile.json`、`build/identity.txt`、`offline/` 和 `logs/` 中的每项引用均存在。
- `manifest.md`、`offline/` 与新的 Godot 日志互相一致：源码工程断网启动成功，macOS 导出仅因模板缺失失败。

Acceptance gaps:

缺少 macOS arm64 安装包及其离线启动证据；Windows 仍按 DEC-007 暂缓。未收集存档、性能或 VS-0 证据，这些均不在 M0-001 已验证范围内。

Conditions or required revisions:

在重新执行时保留成功或失败的完整命令输出、导出包身份/校验值、离线前后接口状态、实际 Bootstrap 日志与启动截图。Windows 结果必须在指定 ThinkPad T480 独立记录，不能由 macOS 结果替代。

Next gate or escalation:

M0-001 不得标为 `accepted`；在 tech 复审通过后执行新的独立质量复核。
