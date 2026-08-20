# D0-002 Cursor 开工 Prompt（合并版：执行版 + 合同）

> 本文件由 `docs/game/d0-002-prompt.md`（执行版）与 `docs/game/d0-002-brief.md`（合同）合并去重而成，供直接粘贴给 Cursor / Codex。两份原件保留，未改写。Cursor 是唯一实现负责人；完成后经 🧱 tech 交付门禁与 🛡️ quality 独立验收，任何人不得自行 APPROVED。

## 1. 任务一句话

在现有 Xcode + Swift + SpriteKit 工程（CreekSprout）上实现 PRD 6.13 设置功能：机器设置文件（安全写入/重启保持/损坏回退）、输入重绑定（键鼠/手柄、冲突阻止、默认恢复）、无障碍设置（UI 缩放/震动/闪烁/音量/文字速度）与存档集成（schema v6→v7 携带设置状态）。不做玩法改动、不做 M4 性能/美术。

**合同来源：** 任务登记表 D0-002 行（DEC-017 承接 D0-001 AC8 缺口）+ PRD 6.12/6.13、PRD-FR-010、PRD-NFR-010 + DEC-015（精简流程）。**角色契约：** 专项负责人 🎮 gameplay；部门质量负责人 🧱 tech；合同跨部门复核 🌱 design（无障碍/UX 规则）与 🛡️ quality（交付可行性）；下游独立验收 🛡️ quality。

## 2. 当前状态（独立核实过的事实，证据路径见括号）

- 工程在 `macos/CreekSprout/CreekSprout.xcodeproj`，scheme `CreekSprout`，macOS arm64 / Xcode 26.6 / macOS 26.5.2。
- **设置功能当前完全不存在**：全仓无 `UserDefaults`/机器设置文件/输入重绑定/无障碍设置代码（D0-001 AC8 已确认，`artifacts/integration/d0-001-xcode/hermes-review.md` 第三部分）。PRD 6.13、FR-010、NFR-010 自 Swift 迁移（M1-002）起未实现。
- 测试基线 **198/198 passed、0 failed、0 skipped、0 警告**（权威计数：`artifacts/integration/d0-001-xcode/TestResults-D0-001.xcresult`；M3-003 基线 180、D0-001 新增 18）。
- 存档 schema 当前 v6（`Persistence/SaveMigrator.swift`、`SaveGameDTO.swift`、`SaveValidation.swift`）；本任务升级 v7 携带设置状态并做 v6→v7 迁移。
- 输入处理现状：`ContentView.swift` 有 Y/B/V 等键绑定与 HUD；`FarmScene.swift` 处理移动/交互；手柄支持现状需先读代码确认（可能仅有按键子集）。
- 契约依据：PRD 6.12（存档至少包含…设置状态）、6.13（机器设置文件/重绑定/无障碍）、FR-010、NFR-010（见 `docs/game/PRD.md`）。
- 证据目录约定：`artifacts/integration/d0-002-xcode/`（不存在则创建）。

## 3. 实现边界

### 必须做（In scope）

1. **输入绑定系统**：键盘/鼠标/手柄绑定可分别修改；同一上下文冲突绑定阻止并说明原因；每个必要动作至少保留一个绑定（解绑最后一个绑定必须被拒）；恢复默认值；绑定表数据驱动、稳定 ID。
2. **机器设置文件**：所有输入与无障碍设置安全写入机器设置文件（安全替换 + 保留最近有效备份）；重启后保持；读取损坏设置回退默认值并保留错误日志（参照 PRD-NFR-003 存档安全精神）。
3. **无障碍设置**：UI 缩放 100/125/150%、屏幕震动开关、闪烁减弱、分类音量、慢/标准/快/立即四档文字速度；运行时立即生效。
4. **存档集成**：schema v6→v7，存档携带设置状态（PRD 6.12）；v6 存档迁移到合法默认设置；`SaveValidation` 覆盖 settings 字段；损坏 settings 拒绝或回退且不破坏最近有效存档。
5. **设置界面与可达性**：键鼠/手柄均可到达并完成全部设置操作（FR-010）；输入提示跟随最近使用设备。
6. **回归**：既有 198/198 保持全绿；新增测试覆盖重绑定冲突、最后绑定保护、默认恢复、重启持久化、损坏回退、迁移、运行时生效。

### 禁止做（红线，Do Not）

- ❌ 不改 PRD、TDD、`docs/game/project-ledger.md`、本 brief、既有 brief 与既有证据文件。
- ❌ 不自我 `APPROVED`，不修改任务状态，不宣称验收通过。
- ❌ 不改玩法/经济/社区事件/水渠/作物/物品/配方的事务语义与数值（Farm/Inventory/Shipping/Quest/Watershed/Gossip/Relationship/Crafting/Placement/Gather/Sleep 等既有 Domain 服务）。
- ❌ 不改 `ContentID.swift` 稳定 ID、`ContentValidator.swift` 校验规则。
- ❌ 不引入正式美术/精灵/动画/正式音频；音量分类只接现有状态行与占位表现。
- ❌ 不做性能/加载/内存预算（M4-001）、不做发行打包（M4-002）。
- ❌ 不删除/重写 M1–M3/D0-001 证据、不弱化既有测试断言。
- ❌ 不 `git commit`、不 `git reset`、不删除工作区未提交内容（直接增量工作）。
- ❌ 不复制任何受保护表达；所有文案原创。

## 4. 文件边界

### 可修改/新增

- 新增 `Domain/SettingsState.swift`（或等效，设置模型与默认值）、`Domain/InputBindingsService.swift`（重绑定/冲突/默认恢复）、`Persistence/SettingsStore.swift`（机器设置文件读写/备份/损坏回退）——文件名以实际实现为准，保持现有 Swift 分层。
- `Persistence/SaveGameDTO.swift`、`SaveMigrator.swift`（v6→v7）、`SaveValidation.swift`（settings 校验）。
- `ContentView.swift`（设置界面入口与布局）、`FarmScene.swift`（应用设置：缩放/文字速度/震动/闪烁/音量/绑定生效）。
- `Content/`（绑定默认表或设置相关数据定义，不改既有稳定 ID 语义）。
- `CreekSproutTests/`（新增聚焦测试；既有断言不得弱化）。
- 仅因新文件 target membership 所需：`project.pbxproj`。

### 禁止修改

- `Domain/` 既有事务核心语义（Farm/Inventory/Shipping/Quest/Watershed/Gossip/Relationship/Crafting/Placement/Gather/Sleep 等）、`ContentID.swift` 稳定 ID、`ContentValidator.swift` 规则。
- Godot 文件、PRD、TDD、台账、本 brief、既有证据。

## 5. 可观察验收（全部需证据）

1. clean Build/Test **≥198/198 passed、0 failed、0 skipped、0 编译警告**（xcresult 权威计数，含新增测试）。
2. 设置界面可由键盘、鼠标与手柄到达并完成全部操作（键鼠路径截图/转储证明）。
3. 重绑定冲突被阻止并说明原因；每个必要动作至少保留一个绑定（最后绑定解绑被拒）。
4. 恢复默认值一键还原全部绑定与设置。
5. 修改绑定与设置 → 完全退出 → 重启 → 一致（机器设置文件 + 存档 settings 双载体核验）。
6. 损坏设置文件 → 启动回退默认值 + 错误日志 + 游戏可正常进行；损坏存档 settings → 拒绝或回退且不破坏最近有效存档。
7. UI 缩放 100/125/150%、文字速度四档、震动开关、闪烁减弱、分类音量运行时生效（截图/转储证明）。
8. schema v7 携带 settings；v6 存档迁移后 settings 为合法默认；存读往返一致。
9. 既有路径不回归：新游戏→174 溪票→雨天→社区事件→水渠 20 主路径在设置生效下仍可走通（至少测试层）。
10. 未改动玩法/经济/事务语义；`git diff --check` exit 0；声明未修改文件清单。

## 6. 一条烟雾路径

启动游戏 → 打开设置（键鼠）→ 将「移动-上」改为冲突键 → 确认被阻止并显示说明 → 改为合法键 → UI 缩放 125%、文字速度「快」→ 恢复默认 → 重新设置（125%/「快」）→ 保存 → 完全退出 → 重启 → 设置保持 → 手动损坏设置文件 → 重启 → 默认值启动 + 错误日志存在 → 读旧 v6 存档 → 自动迁移 settings 为默认、游戏正常 → 新游戏（收获 3 株→174 溪票）在设置生效下完成。

## 7. 交付格式（全部放入 `artifacts/integration/d0-002-xcode/`）

1. `cursor-handoff.md`：outcome、变更文件清单（每文件一句）、验收映射表（10 条逐条 → 实现位置 + 证据）、已知问题与风险、下一负责人。
2. Build/Test 原始证据：
   ```text
   xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout \
     -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath /tmp/creeksprout-d0-002 \
     -resultBundlePath artifacts/integration/d0-002-xcode/TestResults-D0-002.xcresult \
     clean test
   ```
   原始日志 + `test-summary.json` + 编译警告计数（新旧计数对照）。
3. 运行时证据：设置界面截图（键鼠）、重绑定冲突反馈、重启前后设置文件/存档 JSON 对照、损坏回退错误日志、缩放/文字速度生效截图、v6→v7 迁移存档样本、设置生效下的 174 溪票路径证据。
4. `git diff --check` exit 0 输出；未修改文件清单（PRD/TDD/台账/brief/证据）。

## 8. 回复格式（必须逐项确认，缺项视为未完成）

```
A. 范围确认：in scope 与红线逐条「确认 / 不确认」；不确认项说明原因。
B. 当前基线核验：198/198 基线是否已按第 2 节证据路径核实。
C. 交付清单：第 7 节各文件路径 + 状态（已生成/未生成）。
D. 测试结果：xcresult 权威计数（passed/failed/skipped/警告），与 5.1 条对比。
E. 验收映射：10 条验收逐条 → 证据文件；未达标条目明确声明 REVISE 待办。
F. 风险与红线声明：声明未触碰任何红线；如有既有领域缺陷修复，列出最小改动清单。
G. 下一负责人：🧱 tech 交付门禁 → 🛡️ quality（Hermes）独立验收。
```

## 9. 门禁链（交付后由 Hermes 执行，Cursor 不参与）

- 🧱 tech 交付门禁：对实际源码、事务、数据验证和存档安全独立复核，返回 `APPROVED | REVISE | BLOCKED`。
- 🛡️ quality（Hermes）独立只读验收：xcresult 独立查询、日志/截图/存档 JSON 核验、回归确认，返回 `APPROVED | REVISE | BLOCKED`；不采信摘要。
- 🎬 director：仅在 🛡️ quality `APPROVED` 后登记；D0-002 完成后即满足 DEC-017 的「D0 阶段关闭前有设置功能」，D0 阶段关闭为 `accepted`，随后启动 M4-001。
