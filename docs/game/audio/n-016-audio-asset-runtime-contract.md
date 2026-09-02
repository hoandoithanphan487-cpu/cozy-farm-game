# N-016 阶段 A：文件、循环、响度与运行时编码合同

状态：阶段 A 合同；尚未生成音频、尚未修改 Swift/Xcode、尚未批准正式资源导入。

## 1. 规范层级

1. `docs/game/n-016-original-audio-brief.md` 是完整验收合同。
2. 本文件把该合同落实为阶段 B 生产规格和阶段 C 集成输入，不缩减 brief。
3. `docs/game/audio/n-016-audio-direction-and-cue-sheet.md` 决定 cue 数量、身份与听感。
4. manifest 中的实测值必须来自最终文件，不得把本文件的目标值伪装成测量结果。

## 2. 文件命名

- 只用小写 ASCII、数字和下划线；扩展名小写。
- 基名格式：`<category>_<identity>_vNN`；变体用版本位表达，如 `sfx_till_soil_v01`。
- master 与 runtime 使用同一基名、不同目录和扩展名；不得以 `final2`、`new`、`good` 等不可审计命名。
- Cue ID 与文件基名一对一或一对多（明确变体）；运行时不得通过模糊前缀猜文件。

## 3. 母带与运行时编码

| 层 | 格式 | 采样率 / 位深 | 声道 | 用途 |
|---|---|---|---|---|
| Source master | PCM WAV（无损） | 48,000 Hz / 24-bit | 音乐、环境 2；事件 1 | 权威母带、分析与返工来源 |
| Runtime candidate | PCM CAF（无损） | 48,000 Hz / 16-bit little-endian | 同母带 | App 解码与精确帧循环 |
| Analysis preview | PCM WAV 或只读播放 master | 不二次转码 | 同母带 | 🎭 content 试听；不得进入正式 App 资源 |

- 不用 MP3。首轮不用 AAC/M4A，避免编码器延迟、尾部填充和循环边界不确定性。
- 24→16 bit 转换必须使用确定性 TPDF dither；禁止归一化两次。
- Runtime 文件必须由 master 单向生成，不能反向以 runtime 返工 master。
- 阶段 B 转码后以 `afinfo` 复核容器、采样率、声道、frame count，并以 SHA-256 锁定。

## 4. 循环点与接缝

- 所有循环首轮固定 `loop_start_frame = 0`；`loop_end_frame = frame_count`，右端为开区间。
- 不在文件头尾保留编码器静音、淡出尾巴或 reverb spill；空间尾音必须在循环内部完成闭合。
- 音乐循环点必须落在完整小节边界；环境循环点必须保持噪声相位/滤波状态连续。
- 自动门槛：拼接前后 5 ms 窗口的峰值跳变低于 -60 dBFS；拼接窗口不得新增 DC offset；左、右声道分别检查。
- 听感门槛：耳机和内置扬声器各听至少 3 个连续循环，无 click、抽吸、节奏抢拍、空间坍缩或明显重复标记。
- manifest 必须存 `frame_count`、`loop_start_frame`、`loop_end_frame` 和以帧数计算的时长；秒数只作显示。

## 5. 响度与动态

| 类别 | 目标 | 真峰值上限 | 额外规则 |
|---|---|---|---|
| Music | -20 LUFS-I ±1 | -2 dBTP | 两首相差 ≤1 LU；不用砖墙式限制器 |
| Region ambience | -30 / -29 LUFS-I ±2 | -6 dBTP | 与音乐叠加后不遮挡农耕 cue |
| Rain ambience | -31 LUFS-I ±2 | -7 dBTP | 雨 + 区域环境总和目标 ≤ -25 LUFS-I |
| Labor / sale SFX | -24 至 -17 LUFS-I，按 cue sheet | -3 dBTP | 连续 8 次触发无刺耳累积 |
| Dialogue / UI | -28 至 -23 LUFS-I | -6 dBTP | 错误声不做警报；确认声不抢音乐 |

- 测量以最终 master 和 runtime candidate 分别执行；两者响度差异 >0.3 LU 或峰值差异 >0.5 dB 时返工。
- 阶段 B 的自写分析器按 ITU-R BS.1770 K-weighting 与门限逻辑实现；报告必须记录算法版本和源文件 SHA-256。
- 在进入 🎭 content 前，至少以合成基准信号验证分析器的确定性；无法验证时返回 `BLOCKED`，不得手填 LUFS。

## 6. Manifest 最低字段

最终 `manifest.json` 每个文件必须包含：

```text
cue_id
category
event
variant_index
source_master
runtime_file
sample_rate_hz
bit_depth
channels
frame_count
loop_start_frame
loop_end_frame
duration_seconds
integrated_lufs
true_peak_dbtp
peak_dbfs
dc_offset
sha256_master
sha256_runtime
score_source
score_sha256
renderer_source
renderer_sha256
renderer_version
production_toolchain
author_or_operator
created_utc
source_materials
model_usage
license_basis
originality_statement
review_status
```

- 非循环文件的 `loop_start_frame` / `loop_end_frame` 为 `null`，不得填 0 假装循环。
- `source_materials` 必须是空数组；若非空，阶段 B 立即停止并重做权利预检。
- `model_usage` 必须明确为“Codex 辅助文本/源代码；没有模型生成音频”，不得留空。
- `review_status` 在阶段 B 初始为 `audio_ready_for_content`；只有 🎭 content 可改为内容门禁结论。

## 7. 运行时 mixer 与静音合同

- 保留 `VolumeSettings` 的 Master、Music、Ambience、SFX、UI 五类，不改存档 schema 或 key 名。
- 有效增益继续为 `master × category`；任一为 0 时该类无残留声音。
- Music：两首区域主题；Ambience：区域层 + 雨层；SFX：农耕、采集、制作、出售/结算；UI：对话、确认、错误。
- 静音不应销毁逻辑状态；恢复时只恢复一个对应 loop，不得从多个 player 重叠启动。
- 同 cue 的一次领域事务只消费一次；视觉刷新、状态发布或重复渲染不得重复触发声音。

## 8. 回退合同

- 必须保留 `SynthesizedAudioService.swift` 与 `ProceduralAudioBuffers.swift`，不得删除、改名或用空实现覆盖。
- 回退触发：资源不存在、manifest 不一致、SHA-256 不符、容器/采样率/声道不符、`AVAudioFile` 打开失败、读取 frame 数不足或解码异常。
- 回退必须按 cue 类映射到现有或补充的确定性程序化 buffer；单一正式 cue 失败不应迫使所有其他正式 cue 回退。
- 日志至少含 `cue_id`、`runtime_file`、错误类别、是否已使用 fallback、scene/weather、时间戳；不得记录用户隐私路径。
- 测试必须覆盖“缺失”“损坏但可打开失败”“格式可打开但解码/帧数失败”三类，不得只测 `FileManager` 不存在。

## 9. 阶段 C 最小文件边界（预告，不授权现在修改）

内容门禁 `APPROVED` 后，🧱 tech 必须先逐文件说明理由，默认只允许：

- `macos/CreekSprout/CreekSprout/Audio/**`
- 新增正式音频资源目录（建议 `macos/CreekSprout/CreekSprout/Audio/Resources/`）
- `macos/CreekSprout/CreekSproutTests/*Audio*Tests.swift`
- 连接既有事件所必需的最少运行时代码
- `docs/game/audio/**`
- `artifacts/integration/n-016-audio/**`

修改 Xcode 工程、存档 schema、稳定 ID、地图、HUD、玩法或其他边界外文件，必须停止并请求 Product Owner 授权。
