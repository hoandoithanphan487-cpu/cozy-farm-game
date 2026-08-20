# N-001 Cursor 开工 Prompt（粘贴给 Cursor / Codex）

> 本文件是 `docs/game/n-001-brief.md` 的执行版。Cursor 是唯一实现负责人；完成后经 🛡️ quality 独立验收（Hermes），任何人不得自行 APPROVED。本任务**只做表现层**：程序化角色视觉 + 合成音频，零位图纹理、零外部资产，不改任何领域/经济/存档语义。

## 1. 任务一句话

在现有 Xcode + Swift + SpriteKit 工程（CreekSprout）上完成第一拍表现升级：① 7 名角色（3 职能 + 4 邻居）程序化视觉——主题色/发型轮廓/表情/微动效，视觉定义数据化；② 合成音频——农场/溪岸/雨天环境音层（随地图/天气切换）、收获/投入/结算/对话/制作 UI 音效、轻量 BGM loop，全部 AVAudioEngine 合成生成、零外部音频文件；③ 接入既有分类音量（SettingsState，静音/重启保持）。全程**不引入任何位图纹理或音频文件资产**。

## 2. 当前状态（独立核实过的事实，证据路径见括号）

- 工程在 `macos/CreekSprout/CreekSprout.xcodeproj`，scheme `CreekSprout`，macOS arm64 / Xcode 26.6 / macOS 26.5.2；参考设备 M4 MacBook Air / 16 GB。
- 单元回归权威基线 **228/228 passed、0 failed、0 skipped、0 编译警告**，证据 `artifacts/integration/m4-001-xcode/TestResults-M4-001-revise.xcresult`。本任务**不重复 clean test**（DEC-015），引用该基线；以运行时烟雾为决定性回归证据。
- 全仓**零位图纹理**：`imageNamed`/`SKTexture(image` 零命中；42 处渲染调用全部程序化（SKShapeNode/SKSpriteNode/SKLabelNode，集中于 `FarmScene.swift`）。AVAudioEngine/AVAudioPlayer 引用零命中（音频未实现）。`Presentation/`、`Audio/` 目录不存在（特性缺失探针通过）。
- 角色定义：`Content/NpcDefinition.swift`（`npcID`、`nameKey` 稳定文本 ID）；`Content/WorldCatalog.swift` 含 7 NPC 显示名与坐标（青砚/絮宁为最终名）。**本任务不改这些文件的既有语义**，只新增视觉定义。
- 设置：`Domain/SettingsState.swift` 分类音量（`SettingsState.defaults`）；音量 0 应静音；重启保持由 D0-002 已验收机制承载。
- 合同 `docs/game/n-001-brief.md`（9 条 AC + 锁定烟雾路径）；门禁已 🧱 tech + 🌱 design 双 `APPROVED`，任务 `active / PENDING`（台账 `docs/game/project-ledger.md` N-001 行）。
- 工作区现状：git 工作树含此前各任务未提交修改（历史累积，正常）；本任务不得 `git commit`，在其上增量工作。

## 3. 实现边界

### 必须做（In scope）

1. **程序化角色视觉**（`Presentation/` 或 `Visuals/` 新目录，`FarmScene.swift` 表现段接线）：
   - 新增 `CharacterVisualDefinition`（或等价）数据化：7 角色 ×（主题色、发型轮廓参数、表情状态集）；用稳定 ID 关联 `NpcDefinition`，不写死在场景代码。
   - 微动效：行走摆幅、收获动作反馈、对话表情切换（至少各一处可观察）。
   - 「谈/采」角标保留，可加状态动画；HUD 布局与无障碍（形状/图标/文字前缀，颜色不作唯一提示）不回归。
2. **合成音频**（`Audio/` 新目录）：
   - 环境音层：农场（微风/草）、溪岸（流水/鸟鸣）、雨天（雨声）；随地图/天气正确切换（暂停旧层、启动新层）。
   - UI 音效：收获/投入/结算/对话/制作至少 4 类，柔和短促（PRD 8 劳动音效要求）。
   - 轻量 BGM loop：木质打击+拨弦质感，原创、不模仿任何可识别旋律。
   - 全部 AVAudioEngine/AVAudioPlayer **程序化合成或生成**，零音频文件依赖。
3. **设置联动**：新音效/BGM 接入既有分类音量（音量 0 静音，重启保持）；不扩展存档 schema（设置文件为既有机制）。
4. **测试**：新增测试覆盖——视觉定义有效性（7 角色 ID 完整、配色/表情字段合法）、音频服务（音量 0 静音、音层切换幂等、BGM 开关）。测试文件随源码交付并计入交付清单。

### 禁止做（Out of scope / 红线，Do Not）

- ❌ 不引入任何位图纹理或音频文件资产（`imageNamed`/`SKTexture(image`/音频文件引用**零新增**）；位图管线属 IDEA-002 第二拍。
- ❌ 不改 `ContentID.swift`/`ContentValidator.swift` 稳定 ID 与校验规则；不改经济数值（174/894、作物定价）、存档 schema、社区/水渠/任务/关系领域逻辑。
- ❌ 不改 PRD、TDD、`docs/game/project-ledger.md`、既有 brief/prompt/证据文件。
- ❌ 不自我 `APPROVED`，不修改任务状态，不宣称验收通过。
- ❌ 不模仿/采样任何受保护旋律、音效或语音（PRD 8 原创边界）。
- ❌ 不 `git commit`、不 `git reset`、不删除工作区未提交内容。
- ❌ 不复制任何受保护的角色、地图、对白、视觉或音频表达。

## 4. 可观察验收（全部需证据，对应 brief AC-1~9）

1. **AC-1 角色辨识度**：7 角色各有主题色/轮廓，静止与移动可区分（全角色截图对照）。
2. **AC-2 微动效**：行走摆幅、收获反馈、对话表情至少各一处可观察（截图序列或录像）。
3. **AC-3 环境音层**：农场/溪岸/雨天音层可听且随地图/天气正确切换（音频触发日志 + 采样）。
4. **AC-4 UI 音效**：收获/投入/结算/对话/制作至少 4 类触发（日志）。
5. **AC-5 BGM**：loop 循环不刺耳；静音/分类音量生效并重启保持（设置文件 diff 全等）。
6. **AC-6 零位图**：`imageNamed`/`SKTexture(image`/音频文件引用在源码零命中。
7. **AC-7 回归**：引用 228/0/0 基线；运行时烟雾主路径（新游戏→收获→投入→日结→对话→切图→雨天）不回归。
8. **AC-8 红线**：内容 ID/经济/schema/领域逻辑零修改；`git diff --check` exit 0。
9. **AC-9 证据包**：截图 + 音频日志 + 新增测试计数，落盘 `artifacts/integration/n-001-*/`。

## 5. 一条烟雾路径（锁定，逐项取证）

新游戏（农场环境音 active，玩家+水工学徒主题色截图）→ 收获 3 株（harvest 音效 + 收获动效）→ 投入（deposit 音效）→ 对话水工学徒（talk 音效 + 表情切换）→ 睡眠结算（settle 音效，HUD 174/894 不回归）→ 切图至溪岸集市（音层切换：farm 停、market 起）→ 第 2 天雨天（rain 音层）→ 音量 0 全静音 → 恢复 → 证据包落盘。

## 6. 交付格式（全部放入 `artifacts/integration/n-001-*/`）

1. `cursor-handoff.md`：outcome、变更文件清单（每文件一句 + 理由）、验收映射表（9 条逐条 → 证据文件）、已知限制、下一负责人。
2. 7 角色对照截图 + 动效截图序列。
3. 音频触发日志（环境音/UI/BGM 切换点 + 音量 0 静音验证）+ 设置文件 diff 证明重启保持。
4. 新增测试文件与计数（断言要点一句话/测试）。
5. `git diff --check` 退出 0 输出；未修改文件清单（内容 ID/经济/schema/领域/PRD/TDD/台账）。
6. 决策与假设：视觉参数选择、音层实现方式、已知表现妥协。
7. 风险与遗留：非阻断项、后续（IDEA-002）衔接建议。

**不要求**：重复 clean test、长报告、冗余截图、非阻断打磨。

## 7. 回复格式（必须逐项确认，缺项视为未完成）

```
A. 范围确认：本任务 in scope 与红线逐条「确认 / 不确认」；不确认项说明原因。
B. 当前基线核验：228/228 权威基线已引用；确认不重复 clean test。
C. 交付清单：第 6 节各文件路径 + 状态（已生成/未生成）。
D. 视觉结果：7 角色辨识度对照 + 动效证据路径；零位图声明。
E. 音频结果：音层/音效/BGM 触发日志 + 音量联动验证路径；零音频文件声明。
F. 验收映射：9 条 AC 逐条 → 证据文件；未达标条目明确声明 REVISE 待办。
G. 红线声明：未触碰内容 ID/经济/schema/领域、未引入位图/音频资产、未修改台账；`git diff --check` exit 0。
H. 下一负责人：🛡️ quality（Hermes）独立验收。
```

完成后将本文件与 `docs/game/n-001-brief.md` 一并交给 🛡️ quality 门禁。
