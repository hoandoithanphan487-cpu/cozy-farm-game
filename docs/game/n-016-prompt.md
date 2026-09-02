# N-016 可直接执行 Prompt：原创正式音乐、环境音与音效接入

你现在接手 Cozy Farm Game Studio 的 N-016。工作目录：

`/Users/fengyifan/Documents/VibeCoding`

## 权威状态

- N-016 = `active / PENDING`，只代表依赖已就绪，不代表任何资产或实现已获批。
- N-015、N-001、D0-002 = `accepted / APPROVED`；DEC-031 已登记。
- N1 阶段保持 `active`；N-012 仍为 `blocked / BLOCKED`，不得提前复闸、打包或宣称完成。
- 专项负责人：🎧 audio；部门质量负责人：🎭 content；后续门禁：🧱 tech → 🛡️ quality → Product Owner。
- 禁止自我批准；跨部门前必须取得上一门禁的明确 `APPROVED`、`REVISE` 或 `BLOCKED`。

## 开始前必须依次读取

1. `AGENTS.md`
2. `skills/cozy-farm-game-studio/SKILL.md`
3. 该 skill 要求的 roles、production-workflow、genre-blueprint
4. `skills/project-ledger/SKILL.md`
5. 完整的 `docs/game/project-ledger.md`
6. `docs/game/n-016-original-audio-brief.md`
7. `docs/game/n-001-brief.md` 及 N-001 的音频实现/验收证据
8. `macos/CreekSprout/CreekSprout/Audio/AudioTypes.swift`
9. `macos/CreekSprout/CreekSprout/Audio/SynthesizedAudioService.swift`
10. `macos/CreekSprout/CreekSprout/Audio/ProceduralAudioBuffers.swift`
11. `macos/CreekSprout/CreekSproutTests/SynthesizedAudioServiceTests.swift`
12. `macos/CreekSprout/CreekSprout/Domain/SettingsState.swift`

读取后再次执行台账硬依赖预检；若权威状态与上述内容冲突，停止并返回 `BLOCKED`，不得用本 Prompt 覆盖台账。

## 目标

用可审计的原创文件化音频替换程序化 BGM 主体验，同时保留 `SynthesizedAudioService` / `ProceduralAudioBuffers` 作为缺文件或解码失败时的安全回退。至少交付：

- 农场与溪岸集市各一首原创、可无缝循环的主题音乐；
- 农场/溪岸区域环境层与雨天环境层；
- 农耕、收获、出售、制作、对话及 UI 反馈音效；
- 切图淡入淡出、前后台恢复、主/音乐/环境/音效/UI 五类音量与静音；
- 来源、原创过程、工具/模型/素材许可、循环点、响度、编码与 SHA-256 清单；
- 无文件、文件损坏或解码失败时不崩溃并确定性回退；
- 真实 App 至少 20 分钟连续运行、场景切换、雨天、事件音效、静音/恢复及前后台证据。

完整验收条件以 `docs/game/n-016-original-audio-brief.md` 为唯一合同，不得缩减。

## 强制分阶段门禁

### A. 🎧 audio：方向、cue sheet 与权利预检

先只产出音频方向、cue sheet、命名/循环/响度/编码合同，以及生产工具与权利链说明。必须明确哪些声音由何种工具原创生成、是否使用第三方模型或素材、相应许可和可分发依据；无法审计时返回 `BLOCKED`。本阶段不得改 Swift，不得把候选音频放入正式 App 资源目录。

建议文档位于 `docs/game/audio/`，候选与证据位于 `artifacts/integration/n-016-audio/`。

### B. 🎧 audio → 🎭 content：原创资产生产与听感门禁

只在 A 的工具/权利预检通过后生产无损 master、运行时编码、循环点、响度数据和 SHA-256 manifest。候选资产必须留在隔离证据目录；🎭 content 需针对原创性、世界观适配、区域身份、重复疲劳、层次清晰度、循环接缝及禁项返回明确门禁结论。

只有 🎭 content 返回 `APPROVED`，才允许进入生产资源目录和技术集成。若为 `REVISE`，只返工被点名的 cue；若为 `BLOCKED`，停止。

### C. 🧱 tech：文件化接入与回退

在 content `APPROVED` 后，先列出最小文件边界，再实现文件加载、缓存、循环、场景淡入淡出、生命周期恢复、五类 mixer bus 与错误回退。保留并测试现有程序化回退，不得直接删除或覆盖 `SynthesizedAudioService` / `ProceduralAudioBuffers`。

允许的默认边界：

- `macos/CreekSprout/CreekSprout/Audio/**`
- 新增的正式音频资源目录（按现有 Xcode 工程目录同步规则确定）
- `macos/CreekSprout/CreekSproutTests/*Audio*Tests.swift`
- 为连接既有事件所必需的最少运行时代码；编辑前必须逐文件列出理由
- `docs/game/audio/**`
- `artifacts/integration/n-016-audio/**`

若需要修改 Xcode 工程文件、存档 schema、稳定 ID、地图、HUD、玩法或其他边界外文件，先停止并请求新的授权。

### D. 🛡️ quality → Product Owner：独立回归与最终听感

🛡️ quality 必须独立验证：清单/哈希/包内消费、缺失与损坏文件回退、循环接缝、切图淡入淡出、雨天叠层、五类音量和全静音、前后台恢复、事件 cue、一轮 full XCTest，以及至少 20 分钟真实 App 连续运行。记录 0 failed / 0 skipped 或如实列出失败，不得用静态探针替代真实听感证据。

质量门禁通过后，只能提交 Product Owner 最终试听，不能替 Product Owner 自动批准。N-016 只有收到 Product Owner 明确批准后才可更新为 `accepted / APPROVED`，随后才可重新预检 N-012。

## 禁止事项

- 不得修改或重新生成 N-009 高清人物立绘、N-015 地图角色、其他生产 PNG、建筑、地图拓扑或 HUD。
- 不得修改玩法、经济、任务、对白、存档 schema、稳定内容 ID 或输入合同。
- 不得把商业歌曲、受保护旋律、特定作品仿作、歌词、配音或权利不明素材带入仓库。
- 不得触碰 N-014 猫猫烧烤候选范围。
- 不得启动 N-012、生成发行包或改变 N1 阶段状态。
- 不得以“测试通过”替代 🎭 content 听感门禁或 Product Owner 最终试听。

## 交接输出格式

每个阶段结束必须报告：

1. `Outcome`：`APPROVED`、`REVISE` 或 `BLOCKED`（仅对应当前部门门禁）
2. `Changed artifacts`：逐文件列出新增/修改及理由
3. `Evidence`：命令、测试计数、真实 App 时长、音频清单、循环/响度/哈希与试听材料
4. `Rights and originality`：工具、来源、许可、禁止项检查
5. `Risks / open decisions`：未决项及影响
6. `Next owner`：严格按 🎧 audio → 🎭 content → 🧱 tech → 🛡️ quality → Product Owner 顺序

现在只从阶段 A 开始；不得跳过门禁直接生成或接入正式音频。
