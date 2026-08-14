# M0-001 补充部门门禁复核

## 🧱 tech — Engineering & Pipeline

Gate status: **APPROVED**

Scope reviewed:

- Godot 4.7.1 成功读取 `macOS arm64` 预设并生成 release `.app`。
- 导出包包含 arm64 架构；模板实际输出 universal Mach-O，且 Info.plist 将 arm64 设为优先架构。这满足 macOS arm64 运行目标，不声称生成 arm64-only 包。
- 已导出 Bootstrap 包在 `en0` 关闭状态下启动，版本锁、InputMap 和日志边界均可定位。
- Windows 预设仍在配置中；DEC-007 暂缓 Windows 实机执行，此门禁不将 macOS 结果扩展为 Windows 通过。

Evidence inspected:

- `build/identity.txt`
- `logs/export-macos-arm64.txt`
- `offline/network-disabled.txt`
- `logs/offline-exported-bootstrap.txt`

Acceptance gaps:

无 M0-001 范围内阻塞项。VS-0、保存读取、性能、手柄和 Windows 实机均为后续/延期验收项，不属于本次通过结论。

Next gate or escalation:

交 🛡️ quality 独立证据复核；M0-002 与 M0-003 可在 M0-001 获接受后解除依赖。

## 🛡️ quality — Independent evidence review

Gate status: **APPROVED**

Evidence inspected:

- 导出命令、退出码、包内容、架构说明和 SHA-256 均可追溯。
- 断网前后 `en0` 状态、已导出应用启动命令及三条 Bootstrap 日志均已保存。
- 证据明确将 macOS 结果与 Windows、VS-0、存档和性能验收区分开。

Conditions:

Windows 必须按 DEC-007 在 M4-002 前使用 ThinkPad T480 独立验证；本次批准不替代该义务。
