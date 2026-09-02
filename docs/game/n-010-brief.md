# N-010 完整全身立绘运行时渲染层

> 版本：`r1`（2026-08-22）  
> Product Owner 决策：`DEC-030`  
> 状态：`active / PENDING`  
> 主执行者：🧱 tech / Codex  
> 独立质量负责人：🛡️ quality / Hermes

## 玩家结果

玩家走到任一 NPC 面前触发对话时，对话卡或角色信息页显示对应的原创高清完整全身立绘：头顶、双脚、手部、服装下摆与职业道具完整可见，不再显示粗糙放大的像素角色。地图移动、碰撞、比例与原生 `32×48` sprite 不变。

## 决策与依赖

- N-009：`accepted / APPROVED`；从 `artifacts/integration/n-009-portraits/processed/` 读取 8 张处理图。
- N-007：保持 `revise / REVISE`；根据 `DEC-030`，仅将其高清立绘运行时缺口有界转由本任务承接。
- N-013、N-011：本任务不接入建筑；N-011 仍须等待本任务 accepted。
- 超出 DEC-030 范围时立即 `BLOCKED`，不得自行扩大授权。

## 范围

### 必须完成

- 独立 presentation 资源映射：稳定角色 ID → N-009 processed 立绘。
- 对话卡显示高清完整全身立绘。
- 角色信息页显示对应立绘。
- 等比缩放、完整构图、不裁头脚、不变形。
- 未知 ID、缺失文件或加载失败时安全回退，不阻断对话。
- 保留 HUD 默认收起与 `H` 展开/收起行为。
- 增加或更新 XCTest，覆盖 8 名角色映射、回退、展示路径、旧存档读取、键鼠与手柄相关路径。

### 禁止修改

- Domain、ContentID、WorldCatalog、EconomyCatalog、存档 schema/迁移、地图拓扑、碰撞、NPC 行为。
- 原生 `32×48` 地图角色 sprite、N-009 源图与处理图。
- N-011 建筑接入、N-012 打包交付。
- 不得以放大像素图替代高清立绘。

## 文件边界

允许修改：

- `macos/CreekSprout/CreekSprout/Presentation/`
- 明确的高清 presentation 资源目录或 target 资源引用
- `macos/CreekSprout/CreekSproutTests/` 中与本任务直接相关的测试
- `artifacts/integration/n-010-xcode/`
- `docs/game/n-010-brief.md`、`docs/game/n-010-prompt.md`

不得修改：

- `macos/CreekSprout/CreekSprout/Domain/`
- `macos/CreekSprout/CreekSprout/Persistence/`
- `macos/CreekSprout/CreekSprout/Content/ContentID.swift`
- `macos/CreekSprout/CreekSprout/Content/WorldCatalog.swift`
- `macos/CreekSprout/CreekSprout/Content/EconomyCatalog.swift`
- `macos/CreekSprout/CreekSprout/Assets/` 中既有运行时像素资产
- `docs/game/project-ledger.md`（状态由 Product Owner/Codex 按门禁登记）

## 验收标准

- Given 新游戏，When 走到至少 3 名不同职业 NPC 并触发对话，Then 对话卡显示对应高清完整全身立绘。
- Given 角色信息页，When 选择已知角色，Then 显示同一稳定 ID 对应立绘，比例正确且不裁头脚。
- Given 缺失文件、未知 ID 或加载失败，When 触发展示，Then 对话继续、出现安全回退且有可诊断日志。
- Given 窗口或容器尺寸变化，When 重新布局，Then 立绘保持等比、不拉伸、不越界。
- Given 保存、完全退出、重启、读取，When 再次走到 NPC，Then 存档内容与既有玩法状态不变，展示仍可用。
- Given 项目回归，When 执行 clean test，Then 既有测试与本任务测试均通过，0 failed、0 skipped、0 warnings。

## 必须提交的证据

- 原始 `xcodebuild clean test` 命令、scheme、destination、xcresult 与真实计数。
- 至少 3 名角色对话截图、1 张角色信息页截图、1 张缺失资源回退截图。
- presentation 资源映射清单、文件 SHA-256、边界审计、`git diff --check`。
- 农耕、出售、加工、存读回归证据。
- Codex 交付报告，请求 Hermes 返回 `APPROVED | REVISE | BLOCKED`；Codex 不自签。
