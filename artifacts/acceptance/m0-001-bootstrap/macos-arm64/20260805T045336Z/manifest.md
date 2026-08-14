# M0-001 空工程启动夹具记录

| 字段 | 记录 |
|---|---|
| 夹具 ID | `m0-001-empty-bootstrap-offline-start` |
| 首次执行时间 | 2026-08-05T04:53:36Z（UTC） |
| 补充执行时间 | 2026-08-05T05:38:21Z、2026-08-05T05:47:00Z（UTC） |
| 测试平台 | macOS arm64（本机 MacBook Air M4） |
| 构建 ID | `m0-001-bootstrap-source-20260805T045336Z` |
| 构建类型 | 源码工程；macOS arm64 导出预检未生成安装包 |
| 引擎要求 | Godot Engine 4.7.1 标准版、2D Compatibility |
| 结果 | Bootstrap 启动 **PASS**；macOS arm64 导出 **BLOCKED**（导出模板缺失） |

## 已执行步骤

1. 采集架构、系统和硬件档案，见 `device-profile.json`。
2. 确认 Godot 可执行文件 `/Users/fengyifan/Downloads/Godot.app/Contents/MacOS/Godot` 的版本为 `4.7.1.stable.official.a13da4feb`。
3. 无头启动项目并得到 Bootstrap 三条 `[PERF]` 日志，见 `logs/godot-headless-20260805T053821Z.txt`。
4. 关闭唯一报告为可达的网络接口 `en0`，无头启动项目并恢复 Wi-Fi，见 `offline/network-disabled.txt` 与 `logs/godot-offline-start-20260805T054700Z.txt`。
5. 执行 macOS arm64 临时导出预检，见 `logs/godot-export-macos-arm64-20260805T054803Z.txt`。
6. 执行静态结构、目标平台和空白检查，见 `logs/static-validation.txt`。

## 当前阻塞原因

- Godot 4.7.1 标准版已找到，普通与断网 Bootstrap 启动均已执行成功；首次“未找到 Godot”的诊断保留在 `logs/godot-headless.txt` 作为已替代的历史记录。
- macOS arm64 导出失败的唯一剩余配置错误是缺少导出模板：`/Users/fengyifan/Library/Application Support/Godot/export_templates/4.7.1.stable/macos.zip`。因此没有可安装的 macOS `.app` 包，也不能进行已导出包的离线启动。

## 平台边界

Windows x86-64 未执行，按 DEC-007 暂缓至 Windows 实测恢复时，最迟 M4-002。此 macOS 记录不构成 Windows 通过证据，也不构成 VS-0、保存读取、性能或完整离线烟雾通过证据。

## 可用证据

- `build/identity.txt`
- `device-profile.json`
- `offline/network-before.txt`
- `offline/network-disabled.txt`
- `logs/godot-headless.txt`（已替代的历史诊断）
- `logs/godot-headless-20260805T053821Z.txt`
- `logs/godot-offline-start-20260805T054700Z.txt`
- `logs/godot-export-macos-arm64-20260805T054803Z.txt`
- `logs/static-validation.txt`
