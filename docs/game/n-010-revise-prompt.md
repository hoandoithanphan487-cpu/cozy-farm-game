# N-010 REVISE 修复 Prompt（复制给 Codex）

Hermes 已对 N-010 返回 `REVISE`。请只修复以下回归，不扩大 DEC-030 范围：

## 缺陷

N-010 在 `ContentView.swift:213-216` 新增 `i` 键处理，先于既有绑定分发执行，导致原有 `I=投入出售箱` 键盘路径不可达。HUD 仍显示 `[I]投入出售箱`，因此这是明确的玩家路径回归。

## 修复要求

1. 保留既有 `I=投入出售箱` 语义与 HUD 帮助文案，不得破坏 `actionDeposit` 的默认键盘绑定。
2. 将角色信息页改为一个不与现有绑定冲突的键；先读取 `InputBindingDefinitions` 确认候选键未被移动、交互、交谈、制作、存读、HUD 或设置占用。
3. 同步角色信息页提示文案和任何输入绑定显示；不得静默保留错误的 `[I]` 信息页说明。
4. 若选择改变任何既有公开绑定，必须在交付报告中明确说明旧键、新键、影响与理由；优先采用仅移动“角色信息页”到未占用键的最小修复。
5. 增加按键路由测试（若 SwiftUI 事件层无法直接单测，至少增加可测试的路由 helper）：
   - `I` → `actionDeposit`；
   - 新的信息页按键 → `showCharacterInfo`；
   - 两者互不拦截。
6. 保持 N-010 既有行为：8 张高清立绘映射、对话卡、角色信息卡、等比缩放、缺失回退、HUD、存读、32×48 地图 sprite 与 DEC-030 文件边界不变。

## 禁止修改

- Domain、Persistence、EconomyCatalog、WorldCatalog、ContentID、地图、碰撞、NPC 行为；
- 存档 schema；
- N-009 原图/处理图；
- N-011 建筑样板与 N-012 交付；
- 不得用删除角色信息页来规避缺陷。

## 必须重新验证

- `xcodebuild clean test`：真实结果、0 failed、0 skipped、0 warnings；
- 新游戏 → 按 `I` → 确认成功投入出售箱；
- 新的信息页按键 → 打开/关闭角色信息页；
- 3 名 NPC 对话卡、角色信息卡、缺失资源回退；
- HUD `H`、键鼠、手柄、保存→完全退出→重启→读取→对话；
- 重新生成 handoff、原始日志、xcresult、截图、文件边界审计与 `git diff --check`。

## 交付格式

Outcome:
Changed artifacts:
Validation evidence:
Decisions and assumptions:
Risks and follow-ups:
Requested department gate: 请 Hermes 返回 `APPROVED | REVISE | BLOCKED`；Codex 不自签。

## Hermes r2 追加修复（2026-08-22）

Hermes r2 已确认 I/Q 路由与原有运行路径通过，但发现一个新的类 1 文案缺陷：`ContentView.swift:530` 将插值写成双反斜杠，导致界面显示原始 `[(InputBindingDefinitions.characterInfoKeyboardLabel)]关闭`。

只做以下最小修复：

```swift
Text("[\(InputBindingDefinitions.characterInfoKeyboardLabel)]关闭")
```

要求：

- 使用单反斜杠，让 `Key:Q` 显示为 `[Q]关闭`；
- 不改 I→投入出售箱、Q→角色信息页的路由；
- 新 DerivedData 重新执行权威 clean test；
- 增加或补充关闭提示可测字符串断言（如不扩大 SwiftUI 驱动范围）；
- 重新驱动 Q 开 → 确认 `[Q]关闭` → Q 关 → I 仍能投入出售箱；
- 重新提交 handoff、原始日志、xcresult、截图和边界审计；
- 交 Hermes 复闸，Codex 不自签。
