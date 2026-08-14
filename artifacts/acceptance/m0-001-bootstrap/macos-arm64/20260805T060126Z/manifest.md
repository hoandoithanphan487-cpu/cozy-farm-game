# M0-001 macOS arm64 导出与断网启动夹具记录

| 字段 | 记录 |
|---|---|
| 夹具 ID | `m0-001-exported-bootstrap-offline-start` |
| 执行时间 | 2026-08-05T06:01:26Z（UTC） |
| 测试平台 | macOS arm64（本机 MacBook Air M4） |
| 构建 ID | `m0-001-bootstrap-macos-20260805T060126Z` |
| 构建类型 | Godot 4.7.1 release export |
| 目标 | macOS arm64；导出模板产生包含 arm64 与 x86_64 的 universal Mach-O，`Info.plist` 将 arm64 列为优先架构 |
| 渲染器 | 2D Compatibility（`gl_compatibility`） |
| 结果 | **PASS** |

## 步骤与结果

1. 使用 `macOS arm64` 预设导出 `.app` 到临时目录，退出码 0；见 `logs/export-macos-arm64.txt`。
2. 使用 `file` 验证可执行文件包含 arm64，记录校验值；见 `build/identity.txt`。
3. 关闭唯一活动 Wi-Fi 接口 `en0`，确认 `Wi-Fi Power (en0): Off`。
4. 在断网状态运行已导出的应用；Bootstrap 记录版本锁、21 个输入动作和四个后续服务边界，退出码 0；见 `logs/offline-exported-bootstrap.txt`。
5. 清理步骤恢复 Wi-Fi；后续查询确认 `Wi-Fi Power (en0): On`。

## 边界

- 这是空工程 Bootstrap 验证，不是 VS-0、保存读取、手柄、性能或发行候选验收。
- Windows x86-64 未执行，按 DEC-007 暂缓；macOS 结果不构成 Windows 证据。
- 导出包是 `/private/tmp` 的临时验证产物，包身份与 SHA-256 已在本证据包中保留；未将临时二进制纳入仓库。
