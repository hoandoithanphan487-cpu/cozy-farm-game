# P0-007 独立 QA 复核报告（🛡️ quality / Hermes 独立执行）

- 任务：P0-007 — Xcode + SpriteKit 运行端迁移尖峰
- 复核角色：独立 QA（只读验证，未修改任何代码 / 配置 / 签名 / 测试 / 文档）
- 复核时间：2026-08-13（本机）
- 结论：**APPROVED**

## 环境

| 项 | 值 |
|---|---|
| Xcode | 26.6 (Build 17F113) |
| macOS | 26.5.2 (Build 25F84) |
| 架构 | arm64 |
| SDK | macosx26.5 |
| 工程 | `macos/CreekSprout/CreekSprout.xcodeproj`，scheme `CreekSprout`，configuration `Debug` |

## 1. Build

命令：
```
xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout \
  -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/creeksprout-dd build
```
- 退出码：**0**
- 结果：**BUILD SUCCEEDED**
- 原始日志：`artifacts/qa/p0-007-independent/build.log`

## 2. Test

命令：
```
xcodebuild ... test
```
- 退出码：**0**
- 结果：**TEST SUCCEEDED**
- 通过用例：**6 / 6（0 failed）**
  1. `GridMovementTests.testMovedPositionIsNilOutsideFarm` — pass
  2. `GridMovementTests.testPlayerCannotLeaveTenBySixBounds` — pass
  3. `SaveStoreTests.testCorruptPrimaryIsNotOverwritten` — pass
  4. `SaveStoreTests.testMissingSaveFailsSafely` — pass
  5. `SaveStoreTests.testPositionClockAndInventoryRoundTrip` — pass
  6. `SaveStoreTests.testValidBackupIsLoadedWhenPrimaryIsCorrupt` — pass
- 原始日志：`artifacts/qa/p0-007-independent/test.log`

## 3. 运行时验证（独立启动 App + 注入键盘）

验证方式：`open` 启动构建产物 `.app`；通过 macOS 辅助功能 API（AX）读取窗口内 SwiftUI 坐标标签文本，通过 CGEventPost 注入键盘事件；用 `screencapture` 抓取窗口截图并用像素分析验证网格与角色。未采纳 Cursor / Godot 任何历史证据。

### 3.1 可见性

| 检查项 | 结果 | 证据 |
|---|---|---|
| 10×6 网格 | ✅ 通过 | 窗口截图像素分析：横向 10 个绿色格 run（各 ~112px），纵向 6 个 run。`window-initial.png` |
| 黄色占位角色 | ✅ 通过 | 截图检测到黄色团块（4076 像素），质心落在网格 (4,2) 格内，与初始标签一致 |
| 顶部“逻辑坐标 (x, y)”标签 | ✅ 通过 | AX 读出标签文本 `逻辑坐标 (4, 2)`；窗口内坐标 y=48/450、水平居中（x≈383.5），位于顶部 |
| 移动可见 | ✅ 通过 | 按 D 后角色黄色质心从 (844.0, 546.1) → (943.4, 546.1)（右移一格，y 不变）。`window-after-D.png` |

### 3.2 WASD 单步移动（按键前后实际坐标）

| 按键 | 前 | 后 | 期望 | 结果 |
|---|---|---|---|---|
| D（右） | (4, 2) | (5, 2) | 向右一格 | ✅ |
| W（上） | (5, 2) | (5, 3) | 向上一格 | ✅ |
| A（左） | (5, 3) | (4, 3) | 向左一格 | ✅ |
| S（下） | (4, 3) | (4, 2) | 向下一格 | ✅ |

方向键（附带回退）同样逐格移动：RightArrow (4,2)→(5,2)、UpArrow (5,2)→(5,3)、LeftArrow (5,3)→(4,3)、DownArrow (4,3)→(4,2)。

### 3.3 边界约束（角色不能离开网格）

| 位置 | 越界按键 | 前 | 后 | 结果 |
|---|---|---|---|---|
| (9, 5) 右上角 | D（右） | (9, 5) | (9, 5) | ✅ 未离开 |
| (9, 5) 右上角 | W（上） | (9, 5) | (9, 5) | ✅ 未离开 |
| (0, 0) 左下角 | A（左） | (0, 0) | (0, 0) | ✅ 未离开 |
| (0, 0) 左下角 | S（下） | (0, 0) | (0, 0) | ✅ 未离开 |

完整按键序列与坐标记录：`artifacts/qa/p0-007-independent/movement-verification.txt`

## 4. 原始证据清单

| 文件 | 内容 |
|---|---|
| `build.log` | xcodebuild 构建完整输出（BUILD SUCCEEDED，退出 0） |
| `test.log` | xcodebuild 测试完整输出（TEST SUCCEEDED，6/6，退出 0） |
| `window-initial.png` | 启动后窗口截图（网格 + 黄色角色 + 顶部标签，初始 (4,2)） |
| `window-after-D.png` | 按 D 一次后窗口截图（角色右移一格） |
| `fullscreen-initial.png` | 全屏截图（含窗口位置佐证） |
| `movement-verification.txt` | 完整按键→坐标验证记录 |

## 5. 结论

全部检查项在本机独立通过，无阻塞、无缺陷。签发 **APPROVED**。
