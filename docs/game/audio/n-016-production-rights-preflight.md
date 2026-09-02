# N-016 阶段 A：生产工具与权利链预检

结论：`PASS`，允许在隔离目录进入阶段 B 资产生产；不代表 🎭 content、🧱 tech、🛡️ quality 或 Product Owner 批准。

## 1. 选定生产方法

所有音乐、环境音和音效都使用项目专用、确定性、文件化合成流程原创生成：

1. 以项目自写的 score/patch 数据记录音符、节奏、包络、滤波、噪声种子和模态参数。
2. 以项目自写 Python 标准库 renderer 离线生成 48 kHz / 24-bit PCM WAV master。
3. 以 Apple `afconvert` 生成 48 kHz / 16-bit PCM CAF runtime candidate。
4. 以项目自写分析脚本计算帧数、峰值、DC、循环拼接和响度；以 `afinfo` 交叉检查格式，以 `shasum -a 256` 生成哈希。
5. 候选始终停留在 `artifacts/integration/n-016-audio/`，直到 🎭 content 明确 `APPROVED`。

这条链不需要录音、采样库、音乐生成模型、DAW 乐器库、循环包、SoundFont、MIDI 包或第三方素材。

## 2. 本机工具预检

| 工具 | 实测位置 / 版本 | 用途 | 权利与分发判断 | 结论 |
|---|---|---|---|---|
| Python | `/Applications/Xcode.app/Contents/Developer/usr/bin/python3`，3.9.6 | 自写 renderer、分析、manifest | Python 以 PSF License v2 提供；本项目不分发解释器，只分发项目自产 PCM/CAF 与项目源文件 | PASS |
| Python stdlib | `wave`、`struct`、`math`、`json`、`hashlib` 等 | PCM 写入、确定性 DSP、清单 | 不引入 pip 包；本机许可证在 `.../lib/python3.9/LICENSE.txt`，明确 royalty-free 使用与分发许可 | PASS |
| `afconvert` | `/usr/bin/afconvert`，Audio File Convert 2.0 | PCM WAV → PCM CAF | Apple 系统工具只在构建机执行，不随游戏分发；不引入声音内容 | PASS |
| `afinfo` | `/usr/bin/afinfo`，Audio File Info 2.0 | 容器/格式/帧数复核 | 只读检查工具，不随游戏分发、不引入内容 | PASS |
| `shasum` | `/usr/bin/shasum` | SHA-256 | 只读哈希工具，不引入内容 | PASS |
| GarageBand | `/Applications/GarageBand.app` 已检测 | 不使用 | 为避免 Apple Loops、乐器库或预设内容的授权与来源混入，本批明确排除 | EXCLUDED |
| FFmpeg / SoX | 当前命令不可用 | 不使用 | 不安装、不作为阶段 B 依赖 | EXCLUDED |

任何新增工具、pip 包、插件、音频模型或素材库都使本预检失效；必须先补充名称、版本、来源、许可证全文/链接、商业分发依据和归属，再决定 `PASS` 或 `BLOCKED`。

## 3. 作者与模型使用记录

- 阶段 A 文档：由 OpenAI Codex 辅助起草，Product Owner 作为项目方审阅与决定范围。
- 阶段 B：Codex 可辅助生成项目专用 renderer 源码与 score/patch 数据；不调用音乐生成模型，不生成模型音频，不使用第三方模型权重。
- 每个 score 和 renderer 都必须进入 SHA-256 manifest；任何人工修改都产生新版本和新哈希。
- OpenAI 2026-01-01 生效的官方 Terms of Use 说明：在适用法律允许范围内，用户保留 Input 权利并拥有 Output；同时说明 Output 可能不唯一，用户必须评估准确性与适用性。因此，权利链把 Codex 使用如实登记，并额外要求人工旋律/节奏/来源复核，不能只依赖服务条款推断原创性。
- 官方条款：<https://openai.com/policies/row-terms-of-use/>（本预检读取日期：2026-08-25；Content §54–67）。若 Product Owner 账号适用不同企业或地区条款，以实际账号条款为准，并在阶段 B rights record 中替换或补充。

## 4. 素材与许可矩阵

| 内容来源 | 本批是否使用 | 许可依据 | 分发结论 |
|---|---:|---|---|
| 项目自写音符、节奏、音色与 DSP 参数 | 是 | 项目自产；Codex 辅助使用如上记录 | 可进入候选；仍须原创性听审 |
| 确定性数学波形与噪声 | 是 | 不包含第三方录音或作品 | 可进入候选 |
| 现场录音 | 否 | 无 | 禁止混入 |
| 商业歌曲 / 游戏原声 / 可识别旋律 | 否 | 无 | 禁止 |
| 第三方采样、loop、MIDI、SoundFont、预设音频 | 否 | 无 | 禁止 |
| AI 音乐/音效模型生成音频 | 否 | 无模型或权重进入生产链 | 禁止 |
| 歌词、配音、人物语音 | 否 | N-016 明确 out of scope | 禁止 |
| N-001 程序化 buffer | 只作故障回退 | 已验收的项目源代码；不作为正式 master 来源 | 保留，不导出冒充正式资产 |

## 5. 原创过程证据要求

阶段 B 每个 cue 必须能从以下材料重建：

- score/patch 原始数据；
- renderer 源码与版本；
- 固定随机种子；
- 一条确定性渲染命令；
- master 与 runtime candidate；
- 音频分析 JSON；
- SHA-256 manifest；
- cue 级 generation record，列出构思、音程集合、节奏单元、音色参数和返工历史；
- 禁止项自检与人工听审记录。

若同一输入无法逐字节复现同一 master，或无法解释任一声音成分来自哪里，返回 `BLOCKED`。

## 6. 原创性复核规则

- 不输入、不保存、不分析任何商业参考曲音频；不做“像某游戏/某作曲家”的 prompt。
- 每首主题提交自己的核心动机表（音程、节奏、出现位置），由 🎭 content 检查是否像可识别既有旋律。
- 两首主题不能只换音色或移调；必须在节奏密度、句长、音域重心和伴奏结构上独立。
- 所有环境和 SFX 必须从项目 patch 参数产生；不得从 N-001 buffer 直接 bounce 后冒充正式文件。
- 发现疑似相似、来源不明或记录断裂时，对应 cue 返回 `REVISE`；若无法取得合法来源证明则 `BLOCKED`。

## 7. 阻断条件

以下任一情况立即停止阶段 B，不得提交 🎭 content：

1. 引入未登记的模型、插件、采样、loop、SoundFont、MIDI 或录音。
2. 工具或素材条款不允许商业使用、修改、再分发，或适用条款无法确定。
3. 无法保留 score/renderer/seed/命令/哈希的可复现链。
4. 响度分析器无法验证，或循环点只能凭手填而不能从 frame count 证明。
5. 候选文件误入 App 正式资源目录。
6. 需要修改 Swift、Xcode 工程、存档 schema、稳定 ID、地图、HUD 或玩法才能完成阶段 B。

## 8. 阶段 B 生产目录边界

```text
artifacts/integration/n-016-audio/
├── production/
│   ├── score/
│   ├── renderer/
│   └── records/
├── masters/
├── runtime-candidates/
├── analysis/
├── manifests/
├── rights/
├── listening/
└── content-gate/
```

- `docs/game/audio/`：长期合同、cue sheet、权利记录、混音基线和最终门禁摘要。
- `artifacts/integration/n-016-audio/`：候选、生产源、分析、试听和原始证据。
- `macos/CreekSprout/CreekSprout/Audio/Resources/`：只在 🎭 content `APPROVED` 后由 🧱 tech 创建/写入；阶段 A/B 禁止使用。
- 阶段 A 不修改项目台账；N-016 继续 `active / PENDING`，N-012 继续 `blocked / BLOCKED`。
