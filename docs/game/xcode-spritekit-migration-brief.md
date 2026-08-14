# Studio task: Xcode + SpriteKit 运行端迁移尖峰

**Task ID:** P0-007  
**Status:** accepted / APPROVED  
**Decision:** DEC-013 (2026-08-13)

## Player outcome

玩家仍可在 macOS arm64 上玩《溪谷新芽》的原始农耕核心循环；首先得到一个能稳定启动、可见、可输入、可存读的 SpriteKit 最小客户端。迁移不得改变玩法目标，也不得把未验证的 Godot 实现描述为已完成的可玩内容。

## Current context and assumptions

- Godot 4.7.1 的 M1 行为实现与静态测试存在，但本机原生运行在项目 GDScript 解析前崩溃，Web Editor 也无法使用 HTML5 Canvas；因此 M1-001 仍是 `blocked / BLOCKED`。
- 产品当前发行范围仍是 macOS arm64；原有 Godot 文件、资源、文档和测试保留为行为与数据迁移输入。
- 目标技术路线为 Swift、SpriteKit、Xcode；SpriteKit 只承担 2D 呈现与输入适配，业务规则保持在可测试的 Swift 领域层。
- 本次不承诺导入任何未发布的 Godot 本地存档。现有样本存档与原文件必须保留，正式存档兼容策略要在首个可运行尖峰后单独决定。

## Assignment and approval contract

| Field | Contract |
|---|---|
| Department | 🎬 Direction & Production；交付跨入 🧱 Engineering & Pipeline 与 🛡️ Quality & Delivery |
| Specialist owner | 🎬 director：迁移合同、范围、任务路由；随后 🧱 tech：Xcode 尖峰 |
| Department quality owner | 🧱 tech 审查架构与尖峰证据 |
| Cross-department reviewer | 🛡️ quality：独立启动、输入、存读烟雾复核，防止自审 |
| Consulted | 🌱 design：确认农耕行为表未被改写；🎮 gameplay：迁移规则；🛠️ tools：内容和存档数据合同 |
| Downstream handoff | M1-002 已登记为 Swift 农耕闭环任务；M2-001、M2-002 与 M3-001 的直接依赖已由 M1-001 重连至 M1-002，M1-001 保留为 Godot 行为参考 |

## In scope

1. 明确 macOS 客户端目标架构、文件边界和验证顺序。
2. 用现有项目提取“输入 → 规则 → 状态 → 反馈 → 存档 → 测试”的农耕行为对照表。
3. 在 Xcode 中验证一个最小 macOS SpriteKit 尖峰：能构建、启动、呈现网格、接收键盘移动、执行 JSON 存读往返。
4. 规定 Cursor、Hermes 和 Xcode 的不重叠职责及交接证据。

## Out of scope

- 删除、重命名、批量转换或修改任何 Godot 源文件、场景、资源、导出预设或历史验收证据。
- 直接复制 GDScript、`.tscn` 或 `.tres` 文件到 Xcode，或声称它们可以直接运行。
- 改变作物数值、经济平衡、世界内容、角色、文案、视觉风格、发布平台或商店发行方案。
- 在尖峰未通过前开始大批量 Swift 迁移、制作正式美术，或修改 M2 及后续任务的依赖关系。

## Target architecture

```text
macOS app entry (SwiftUI)
  └─ SpriteKit scene and HUD adapters
       └─ GameDomain (pure Swift rules and state)
            ├─ ContentRepository (Codable data, stable IDs)
            └─ SaveStore (Codable JSON, temp write, read-back, backup)
```

| Existing input | Target | Migration rule |
|---|---|---|
| `src/core/` and `src/domain/` GDScript rules | Pure Swift `GameDomain` types and services | Port behavior and tests, never copy syntax verbatim. |
| `content/*.tres` | Versioned Codable JSON data | Preserve stable IDs and validation intent; convert only after schema review. |
| `scenes/*.tscn` and presentation scripts | `SKScene` plus SwiftUI shell/HUD | Recreate visible behavior and layout with original placeholder presentation. |
| `user://` save/settings | App Support JSON store | Keep temp-write, read-back, backup and failure-recovery guarantees from the TDD. |
| Godot tests | XCTest unit/integration tests plus manual smoke | Rewrite tests against the Swift domain; no test is considered ported until it runs. |

## First executable slice: Xcode technical spike

### File ownership

| Tool | Owns | Must not touch |
|---|---|---|
| Xcode | macOS target, SpriteKit scene/view, build settings, debugger and local build/test evidence | Gameplay balance, broad domain rewrite, release/signing decisions |
| Cursor | Swift domain modules, Codable DTOs, XCTest and focused refactors | Xcode signing/release configuration; files Hermes is currently operating |
| Hermes | Read-only traceability checklist, independent smoke execution, screenshots/logs/defect reports | Direct edits to active Cursor files; accepting its own implementation |

### Acceptance criteria

- Given a fresh Xcode checkout, when the macOS target is built, then the build succeeds and a local app launches.
- Given the app is open, when a player presses the configured direction keys, then an on-screen placeholder moves one logical grid step and the movement is visible.
- Given a new in-memory game state, when it is saved and reloaded, then its selected player position, clock value and one inventory quantity round-trip through JSON.
- Given a malformed or missing save, when loading, then the app keeps the original file and falls back safely without a crash.
- Given the spike evidence, when 🛡️ quality repeats the four checks independently, then it can reproduce them from raw commands, screenshots or logs.

### Required evidence

1. Xcode build/test output and target/toolchain version.
2. One launch screenshot or recording showing the grid and movement.
3. XCTest output for the save round-trip and malformed-save path.
4. Hermes QA checklist with observed result, timestamp, expected/actual and any reproducible defect.
5. `git diff --check` after implementation; no Godot file deletion.

## First-round work order

1. **Hermes — read-only.** Map M1-001's actions, preconditions, state changes and feedback into a behavior checklist. Report gaps; do not edit source.
2. **Xcode — bounded spike.** Create only the macOS SwiftUI + SpriteKit shell needed to meet the five acceptance criteria. Submit build/test logs to 🧱 tech.
3. **Cursor — domain-first implementation.** After Xcode establishes the target, implement the minimal `GameState`, movement intent and `Codable` save DTO with XCTest. Do not import Godot APIs or alter the Xcode release settings.
4. **Hermes — independent QA.** Repeat launch, movement, valid save/reload and malformed-save checks. Submit evidence to 🛡️ quality.
5. **Director — dependency remap.** 2026-08-13 在 🧱 tech 与 🛡️ quality 对 P0-007 签发 `APPROVED` 后，登记 M1-002 并重连其下游直接依赖；M1-002 仍为 `planned / PENDING`，尚未开始功能开发。

## Risks and open choices

- P0-007 已在 Xcode 26.6 / macOS 26.5.2 / arm64 通过构建、6 项 XCTest、启动、输入与 JSON 存读独立复核；RSK-006 已解除，但结论不得外推为 M1-002 功能通过。
- A future decision is required for migration of any real player save, but no released save compatibility is promised by this spike.
- SpriteKit is sufficient for the current 2D macOS scope; any later iOS, 3D, multiplayer or editor requirement needs a new Product Owner decision.

## Gate requirements

- 🎬 Direction & Production: task contract is bounded and traceable to DEC-013.
- 🧱 Engineering & Pipeline: `APPROVED` only after the Xcode spike has build, launch, input and XCTest save evidence.
- 🛡️ Quality & Delivery: `APPROVED` only after independent reproduction. A failed or absent check is `REVISE` or `BLOCKED`, not acceptance.
