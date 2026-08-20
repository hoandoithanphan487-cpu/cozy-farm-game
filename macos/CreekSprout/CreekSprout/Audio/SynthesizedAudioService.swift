import AVFoundation
import Foundation

/// Mixes procedurally generated loops and one-shots through category buses.
/// Zero audio files. Volume 0 on master or a category silences that bus.
final class SynthesizedAudioService {
    private let engine = AVAudioEngine()
    private let masterMixer = AVAudioMixerNode()
    private let musicMixer = AVAudioMixerNode()
    private let ambienceMixer = AVAudioMixerNode()
    private let sfxMixer = AVAudioMixerNode()
    private let uiMixer = AVAudioMixerNode()

    private let farmPlayer = AVAudioPlayerNode()
    private let creekPlayer = AVAudioPlayerNode()
    private let rainPlayer = AVAudioPlayerNode()
    private let bgmPlayer = AVAudioPlayerNode()
    private let sfxPlayer = AVAudioPlayerNode()
    private let uiPlayer = AVAudioPlayerNode()

    private var volumes: VolumeSettings = .defaults
    private var currentMapLayer: AmbientMapLayer?
    private var currentWeatherLayer: AmbientWeatherLayer = .none
    private var bgmEnabled = true
    private var engineStarted = false
    private var attached = false
    private(set) var events: [AudioLogEvent] = []
    private var logURL: URL?

    init() {
        attachGraph()
    }

    func setLogURL(_ url: URL?) {
        logURL = url
    }

    var mapLayer: AmbientMapLayer? { currentMapLayer }
    var weatherLayer: AmbientWeatherLayer { currentWeatherLayer }
    var isBGMEnabled: Bool { bgmEnabled }
    var isEngineRunning: Bool { engineStarted && engine.isRunning }

    func start(volumes: VolumeSettings) {
        self.volumes = volumes
        startEngineIfNeeded()
        applyGains()
        setBGMEnabled(true)
        log(kind: "engine", name: "start", gain: Double(masterGain), detail: "engine running=\(engine.isRunning)")
    }

    func stop() {
        farmPlayer.stop()
        creekPlayer.stop()
        rainPlayer.stop()
        bgmPlayer.stop()
        sfxPlayer.stop()
        uiPlayer.stop()
        currentMapLayer = nil
        currentWeatherLayer = .none
        if engineStarted {
            engine.stop()
            engineStarted = false
        }
        log(kind: "engine", name: "stop", gain: 0, detail: "stopped")
    }

    func applyVolumes(_ volumes: VolumeSettings) {
        self.volumes = volumes
        applyGains()
        log(
            kind: "volume",
            name: "apply",
            gain: Double(masterGain),
            detail: "master=\(volumes.master) music=\(volumes.music) ambience=\(volumes.ambience) sfx=\(volumes.sfx) ui=\(volumes.ui)"
        )
        if masterGain == 0 {
            log(kind: "volume", name: "mute-all", gain: 0, detail: "master or product is silent")
        }
    }

    func setMapLayer(_ layer: AmbientMapLayer) {
        startEngineIfNeeded()
        if currentMapLayer == layer, player(for: layer).isPlaying {
            log(kind: "ambient", name: layer.rawValue, gain: Double(ambienceGain), detail: "idempotent skip")
            return
        }
        if let previous = currentMapLayer, previous != layer {
            stopMapPlayer(previous)
            log(kind: "ambient", name: previous.rawValue, gain: 0, detail: "stop")
        }
        currentMapLayer = layer
        let node = player(for: layer)
        if !node.isPlaying {
            node.stop()
            node.scheduleBuffer(buffer(for: layer), at: nil, options: .loops)
            node.play()
        }
        applyGains()
        log(kind: "ambient", name: layer.rawValue, gain: Double(ambienceGain), detail: "start")
    }

    func setWeatherLayer(_ layer: AmbientWeatherLayer) {
        startEngineIfNeeded()
        if currentWeatherLayer == layer {
            let playing = layer == .rain ? rainPlayer.isPlaying : true
            if playing {
                log(kind: "weather", name: layer.rawValue, gain: Double(ambienceGain), detail: "idempotent skip")
                return
            }
        }
        if currentWeatherLayer == .rain, layer != .rain {
            rainPlayer.stop()
            log(kind: "weather", name: "rain", gain: 0, detail: "stop")
        }
        currentWeatherLayer = layer
        if layer == .rain {
            rainPlayer.stop()
            rainPlayer.scheduleBuffer(ProceduralAudioBuffers.rainLoop(), at: nil, options: .loops)
            rainPlayer.play()
            applyGains()
            log(kind: "weather", name: "rain", gain: Double(ambienceGain), detail: "start")
        } else {
            applyGains()
            log(kind: "weather", name: "none", gain: Double(ambienceGain), detail: "clear")
        }
    }

    func setBGMEnabled(_ enabled: Bool) {
        startEngineIfNeeded()
        bgmEnabled = enabled
        if enabled, musicGain > 0 {
            if !bgmPlayer.isPlaying {
                bgmPlayer.stop()
                bgmPlayer.scheduleBuffer(ProceduralAudioBuffers.bgmLoop(), at: nil, options: .loops)
                bgmPlayer.play()
            }
            log(kind: "bgm", name: "on", gain: Double(musicGain), detail: "loop")
        } else {
            bgmPlayer.stop()
            log(kind: "bgm", name: "off", gain: Double(musicGain), detail: enabled ? "silent via volume" : "disabled")
        }
    }

    func play(_ cue: UISoundCue) {
        startEngineIfNeeded()
        let buffer = ProceduralAudioBuffers.cue(cue)
        let useUI = cue == .talk
        let node = useUI ? uiPlayer : sfxPlayer
        let gain = useUI ? uiGain : sfxGain
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [])
        if gain > 0 {
            node.play()
        }
        log(kind: "sfx", name: cue.rawValue, gain: Double(gain), detail: gain == 0 ? "muted" : "play")
    }

    func gain(for bus: AudioBus) -> Float {
        switch bus {
        case .master: return masterGain
        case .music: return musicGain
        case .ambience: return ambienceGain
        case .sfx: return sfxGain
        case .ui: return uiGain
        }
    }

    func isSilent(bus: AudioBus) -> Bool {
        gain(for: bus) <= 0
    }

    func exportLogJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(events)
    }

    func writeLogIfPossible() {
        guard let logURL else { return }
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? exportLogJSON().write(to: logURL, options: .atomic)
    }

    // MARK: - Graph

    private func attachGraph() {
        guard !attached else { return }
        attached = true
        let nodes: [AVAudioNode] = [
            masterMixer, musicMixer, ambienceMixer, sfxMixer, uiMixer,
            farmPlayer, creekPlayer, rainPlayer, bgmPlayer, sfxPlayer, uiPlayer,
        ]
        for node in nodes {
            engine.attach(node)
        }
        let format = AVAudioFormat(standardFormatWithSampleRate: ProceduralAudioBuffers.sampleRate, channels: 1)
        engine.connect(farmPlayer, to: ambienceMixer, format: format)
        engine.connect(creekPlayer, to: ambienceMixer, format: format)
        engine.connect(rainPlayer, to: ambienceMixer, format: format)
        engine.connect(bgmPlayer, to: musicMixer, format: format)
        engine.connect(sfxPlayer, to: sfxMixer, format: format)
        engine.connect(uiPlayer, to: uiMixer, format: format)
        engine.connect(ambienceMixer, to: masterMixer, format: format)
        engine.connect(musicMixer, to: masterMixer, format: format)
        engine.connect(sfxMixer, to: masterMixer, format: format)
        engine.connect(uiMixer, to: masterMixer, format: format)
        engine.connect(masterMixer, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }

    private func startEngineIfNeeded() {
        attachGraph()
        guard !engine.isRunning else {
            engineStarted = true
            return
        }
        do {
            try engine.start()
            engineStarted = true
        } catch {
            log(kind: "engine", name: "error", gain: 0, detail: String(describing: error))
        }
    }

    private func applyGains() {
        masterMixer.outputVolume = masterGain
        musicMixer.outputVolume = musicGain <= 0 ? 0 : 1
        ambienceMixer.outputVolume = ambienceGain <= 0 ? 0 : 1
        sfxMixer.outputVolume = sfxGain <= 0 ? 0 : 1
        uiMixer.outputVolume = uiGain <= 0 ? 0 : 1
        farmPlayer.volume = currentMapLayer == .farm ? 1 : 0
        creekPlayer.volume = currentMapLayer == .creek ? 1 : 0
        rainPlayer.volume = currentWeatherLayer == .rain ? 1 : 0
        bgmPlayer.volume = bgmEnabled && musicGain > 0 ? 1 : 0
        if musicGain <= 0, bgmPlayer.isPlaying {
            bgmPlayer.stop()
        } else if bgmEnabled, musicGain > 0, engine.isRunning, !bgmPlayer.isPlaying {
            bgmPlayer.scheduleBuffer(ProceduralAudioBuffers.bgmLoop(), at: nil, options: .loops)
            bgmPlayer.play()
        }
    }

    private var masterGain: Float { clamped(volumes.master) }
    private var musicGain: Float { masterGain * clamped(volumes.music) }
    private var ambienceGain: Float { masterGain * clamped(volumes.ambience) }
    private var sfxGain: Float { masterGain * clamped(volumes.sfx) }
    private var uiGain: Float { masterGain * clamped(volumes.ui) }

    private func clamped(_ value: Double) -> Float {
        Float(max(0, min(1, value)))
    }

    private func player(for layer: AmbientMapLayer) -> AVAudioPlayerNode {
        switch layer {
        case .farm: return farmPlayer
        case .creek: return creekPlayer
        }
    }

    private func buffer(for layer: AmbientMapLayer) -> AVAudioPCMBuffer {
        switch layer {
        case .farm: return ProceduralAudioBuffers.farmLoop()
        case .creek: return ProceduralAudioBuffers.creekLoop()
        }
    }

    private func stopMapPlayer(_ layer: AmbientMapLayer) {
        player(for: layer).stop()
    }

    private func log(kind: String, name: String, gain: Double, detail: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        events.append(
            AudioLogEvent(timestamp: stamp, kind: kind, name: name, gain: gain, detail: detail)
        )
        writeLogIfPossible()
    }
}
