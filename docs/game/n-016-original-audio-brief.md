# Studio task: N-016 原创正式音乐、环境音与音效接入

> 2026-08-25 Product Owner 决定覆盖：两首区域 BGM 改用已确认的现成授权曲目 C1 + C4，不再要求本项目自行合成；准确映射、来源、许可和集成状态以 `docs/game/audio/n-016-licensed-bgm-selection.md` 为准。环境音、事件音效与完整质量门禁仍按本 brief 执行。

> 2026-08-25 Product Owner 再次覆盖：去掉正常游戏中的背景杂音。农场风声、溪流水声与雨声环境层全部取消播放；事件 SFX/UI 音效继续保留。此决定以 DEC-040 为准。

Player outcome:
- 玩家在农场和溪岸集市听到与场景、天气和操作一致的原创音乐与声音反馈；音乐温暖、耐听、可无缝循环，不再以程序化测试音作为默认成品体验。

Current context:
- N-001 已接入 `AVAudioEngine`、分音量总线、区域/雨天环境层、操作 cue 和程序化 BGM，功能链可用。
- 当前仓库正式音频文件为 0；`SynthesizedAudioService` 明确使用实时生成 buffer，因此现有通过证据只代表音频系统工作，不代表成品音乐完成。

Assumptions:
- 首轮正式音乐范围为两首原创区域主题：农场、溪岸集市；雨天采用可叠加变体或独立层。
- 继续支持主音量、音乐、环境、音效、UI 五类设置；程序化音频仅作为文件缺失时的安全回退。

Department:
- 🎭 World & Content

Department quality owner:
- 🎭 `content`

Specialist owner:
- 🎧 `audio`

Consulted:
- 🧱 `tech`：文件格式、流式播放、生命周期、性能与打包
- 🌱 `design` / ✨ `ux`：反馈优先级、设置与无障碍

Downstream reviewer:
- 🧱 `tech`：运行时集成门禁
- 🛡️ `quality`：独立运行与长时听感门禁

In scope:
- 原创 cue sheet、音乐方向、乐器/节奏/情绪边界和原创性记录。
- 至少两首可无缝循环区域 BGM；农场与溪岸集市切换时平滑淡入淡出。
- 农场、流水、雨天环境层；翻土、播种、浇水、收获、采集、制作、出售/结算、交谈和 UI 确认/错误等关键反馈。
- 文件化音频加载、缓存/流式播放、生命周期、前后台恢复、分音量与静音。
- 正式音频缺失、解码失败时的程序化回退和可诊断日志。

Out of scope:
- 语音配音、歌词、外部商业曲目授权、新剧情或根据社交状态动态作曲。
- 模仿可识别的旋律、和声编排、音色签名或现有游戏原声。

Inputs and dependencies:
- N-015、N-001、D0-002 必须为 `accepted / APPROVED`。
- DEC-031。
- 当前 `Audio/` 服务、`SettingsState` 和音频 XCTest。

Deliverables:
- `docs/game/audio/` 下的 cue sheet、技术规格、原创性/权利记录和混音基线。
- 原始无损母带、运行时编码文件、循环点和 SHA-256 manifest。
- 文件化/混合音频服务、测试和真实运行交接。
- 音量、切图、雨天、前后台、缺失文件回退及至少 20 分钟连续运行证据。

Acceptance criteria:
1. Given 农场和溪岸集市，When 玩家切换地图，Then 播放对应原创主题并平滑过渡，无爆音、双重叠播或明显循环接缝。
2. Given 雨天和区域环境，When 天气/地图状态变化，Then 环境层正确开始、停止或交叉淡化，音乐与关键操作音仍清晰。
3. Given 关键操作，When 翻土、播种、浇水、收获、采集、制作、出售、结算、交谈和 UI 确认/错误发生，Then 正确 cue 只播放一次且不延迟干扰输入反馈。
4. Given 五类音量设置，When 单独调整或主音量归零，Then 对应 bus 生效、重启保持、静音时无残留声音。
5. Given App 进入后台、恢复或音频设备改变，When 返回游戏，Then 不崩溃、不重复启动多个 loop，恢复行为可预测。
6. Given 正式音频文件缺失或损坏，When 服务加载，Then 使用程序化安全回退并记录错误，不阻断游戏。
7. Given 音频资产，When 检查 manifest，Then 来源、作者/生成方式、授权、原创性声明、格式、采样率、声道、循环点、时长、峰值/响度和哈希齐备。
8. Given 20 分钟连续游玩，When 在两地图与晴雨间切换并重复操作，Then 无明显听觉疲劳、爆音、削波、泄漏 player node 或内存持续增长；🛡️ quality 提供独立记录。

Required evidence:
- 音频文件与 manifest 的集合/哈希一致性。
- 波形/响度/循环边界检查及实际听感记录。
- XCTest、构建、App 包资源、音频日志和运行路径证据。
- 分音量、静音、切图、天气、前后台、缺失文件与长时运行证据。

Required gates:
- 音乐/音效内容门禁：🎭 `content`
- 运行时集成门禁：🧱 `tech`
- 独立质量门禁：🛡️ `quality`
- 最终听感验收：Product Owner

Originality check:
- 音乐、音效与环境音必须为本项目原创或拥有可审计授权。
- 不得提示或要求模仿任何具体游戏、作曲家、歌曲或可识别录音；仅使用“温暖、溪谷、水工、手作、低压力”等本项目语义描述。

Risks or open choices:
- 正式音乐的创作/生成工具和授权条款尚未选定；开始资产生产前必须记录来源与可商用权利。
- 两首区域主题是首轮垂直切片假设；若 Product Owner 要求昼夜/季节/节庆更多曲目，应另行扩展范围和排期。

Intake gate:
- Gate status: `APPROVED`
- Scope reviewed: Product Owner 已明确要求加入音乐，并同意其位于最终交付之前。
- Evidence inspected: N-001 证据、当前 `SynthesizedAudioService`、`ProceduralAudioBuffers`、设置模型及仓库音频文件集合。
- Next gate: N-015 `accepted / APPROVED` 后由 🎧 audio 执行依赖预检；本合同批准不等于音乐或集成批准。
