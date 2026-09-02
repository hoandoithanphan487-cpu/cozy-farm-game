# Hermes r3 — N-012 desktop delivery re-gate

你是 N-012 的独立 🛡️ quality owner。Product Owner 已选择恢复桌面交付路径。请只读复核，不修改实现、主台账或 release payload。

目标入口：`/Users/fengyifan/Desktop/溪谷新芽.app`

该入口当前指向干净的 Release payload：`/private/tmp/creeksprout-n012-final/溪谷新芽.app`。先解析入口目标，再验证入口与目标均可通过：

```text
codesign --verify --deep --strict --verbose=2 /Users/fengyifan/Desktop/溪谷新芽.app
```

必须核对：

- 目标存在且不是 N-007 旧构建；
- universal `x86_64 arm64`、版本 `1.0 (1)`；
- 8 张 N-010 portrait PNG 存在；
- N-011 `building_farm_house_display_2048_v02.png` 存在，SHA-256 为 `c0a5b111d9686f283b1c2584b1fa662d0dd382f3948fa6392d1b79b0cda667a5`；
- 不包含 `CreekSproutTests.xctest`；
- strict codesign 通过；
- 冷启动后运行桌面包路径：收获→I 出售→农耕/加工→3 NPC 对话→Q/I/E 键→存读；
- GUI 驱动遇到 WeChat 或其他非游戏前台时，必须硬中止且不得注入按键；等待 Product Owner 将游戏窗口切回前台后再继续。

证据目录：`artifacts/integration/n-012-release/hermes-r3/`

返回 `APPROVED`、`REVISE` 或 `BLOCKED`，并说明所有剩余缺口。不要修改 `docs/game/project-ledger.md`。
