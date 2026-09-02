# N-016 现成 BGM 选择与集成交接

状态：BGM 垂直切片已由 Product Owner 选曲并完成技术接入；随后按 DEC-040 进入“纯净 BGM”模式，农场风声、溪流水声和雨声不再播放。N-016 的事件音效、生命周期、长时听感和完整质量门禁仍保持 `active / PENDING`。

## Product Owner 决定

2026-08-25，Product Owner 对试听清单明确回复“第一个和第四个。选择确认”。本决定覆盖原合同中“两首音乐必须项目自制原创”的假设，改为使用来源与许可可审计的现成曲目；不授权抓取付费或受限资源。

| 场景 | 采用曲目 | 作者 | 运行时文件 |
|---|---|---|---|
| 农场 | 《今日もいい日 / Today Is a Good Day》 | HALTO | `music_farm_today_is_a_good_day_v01.mp3` |
| 溪岸集市 | 《はずむ足どり / Bouncy Steps》 | HALTO | `music_creek_bouncy_steps_v01.mp3` |

两首均采用作者公开提供的 loop 版本。文件保持原 44.1 kHz、双声道、128 kbps MP3，不冒充无损母带。运行时先完整解码为 PCM buffer，再由 `AVAudioPlayerNode.scheduleBuffer(..., .loops)` 循环，因此 MP3 的 priming/remainder 不会作为循环内静音重复播放。

## 来源与权利

- 农场曲来源：<https://halto-freesounds.com/today-is-a-good-day/>
- 集市曲来源：<https://halto-freesounds.com/bouncy-steps/>
- 使用条款：<https://halto-freesounds.com/terms/>
- 条款检查日期：2026-08-25。
- 允许：免费商用/非商用项目使用、为项目编辑、署名可选。
- 禁止：把音频作为独立素材再分发、虚假声称作者身份、发布到音乐流媒体、用于 AI 训练、注册 Content ID。

本项目只把音频作为游戏的一部分分发；不把两首文件作为素材包或独立下载交付。

## 运行时合同

- `farm` 映射农场曲，`creek` 映射集市曲。
- 切图时两个文件播放器做 1.0 秒交叉淡化；结束后旧播放器停止。
- Master 与 Music 继续使用既有 `master × music` 增益；静音停止音乐节点，恢复时只启动当前地图的一首。
- 启动时逐文件检查：存在性、SHA-256、44.1 kHz、双声道、可解码、非零有效帧。
- 任一检查失败，只对音乐启用 `ProceduralAudioBuffers.bgmLoop()` 回退，不影响 SFX、UI 或游戏运行。
- 正常游戏中的 Ambience 总线固定为 0；地图与天气变化只更新逻辑状态，农场、溪流和雨声播放器始终停止。该规则不影响两首 BGM 的地图映射和切换。
- 运行清单：`Audio/Resources/licensed_music_manifest.json`；Swift 中的哈希和场景映射必须与清单一致。

## 顺序门禁

- 🎧 audio 专项：`APPROVED`——PO 所选两首原始 loop 文件、标题、作者、场景映射和哈希一致。
- 🎭 content 部门质量：`APPROVED`——农场更舒缓、集市更有步行律动，均满足轻松愉快且场景可区分；权利边界已记录。
- 🧱 tech 集成：`APPROVED`——包内解析/解码、哈希校验、地图切换、分音量和程序回退已接入。
- 🛡️ quality：`REVISE`——BGM 与环境杂音抑制专项自动化可通过，但完整 N-016 仍缺真实设备长时听感、前后台/设备切换及全事件 SFX，所以不得把 N-016 或 N-012 标为完成。

## 自动化证据

- `SynthesizedAudioServiceTests`：8/8 通过，包括选择映射、App bundle 解码、manifest 一致性、切图淡化事件和空资源包回退。
- App bundle 中两首文件哈希与源文件、清单、Swift catalog 一致。
- 程序化农场、溪流和雨声被强制停止并硬静音；事件音效继续保留。
- `testMapAndWeatherChangesKeepProceduralAmbienceSuppressed` 验证默认环境增益为 0，地图/雨天切换后三个环境播放器均未运行。
