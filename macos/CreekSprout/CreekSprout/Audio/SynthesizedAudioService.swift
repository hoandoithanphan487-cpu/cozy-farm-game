import AVFoundation
import CryptoKit
import Foundation

/// Mixes licensed file-backed music, one-shots, and a deterministic music
/// fallback through category buses. Procedural ambience stays hard-disabled
/// in the player build so wind, creek, and rain noise cannot mask the BGM.
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
    private let farmMusicPlayer = AVAudioPlayerNode()
    private let creekMusicPlayer = AVAudioPlayerNode()
    private let bgmPlayer = AVAudioPlayerNode()
    private let sfxPlayer = AVAudioPlayerNode()
    private let uiPlayer = AVAudioPlayerNode()

    private var volumes: VolumeSettings = .defaults
    private var currentMapLayer: AmbientMapLayer?
    private var currentWeatherLayer: AmbientWeatherLayer = .none
    private var bgmEnabled = true
    private let proceduralAmbienceEnabled = false
    private var engineStarted = false
    private var attached = false
    private let resourceBundle: Bundle
    private var musicBuffers: [AmbientMapLayer: AVAudioPCMBuffer] = [:]
    private var musicLoadFailures: [AmbientMapLayer: String] = [:]
    private var musicFadeTimer: DispatchSourceTimer?
    private(set) var events: [AudioLogEvent] = []
    private var logURL: URL?

    init(resourceBundle: Bundle = .main) {
        self.resourceBundle = resourceBundle
        loadLicensedMusic()
        attachGraph()
    }

    func setLogURL(_ url: URL?) {
        logURL = url
    }

    var mapLayer: AmbientMapLayer? { currentMapLayer }
    var weatherLayer: AmbientWeatherLayer { currentWeatherLayer }
    var isBGMEnabled: Bool { bgmEnabled }
    var isEngineRunning: Bool { engineStarted && engine.isRunning }
    var isProceduralAmbienceEnabled: Bool { proceduralAmbienceEnabled }
    var isProceduralAmbiencePlaying: Bool {
        farmPlayer.isPlaying || creekPlayer.isPlaying || rainPlayer.isPlaying
    }

    func musicPlaybackSource(for layer: AmbientMapLayer) -> MusicPlaybackSource {
        let track = LicensedMusicCatalog.track(for: layer)
        guard musicBuffers[layer] != nil else { return .proceduralFallback }
        return .licensedFile(cueID: track.cueID, filename: track.filename)
    }

    /// Keeps presentation state observable without touching AVAudioPlayerNode.
    /// The XCTest host uses this while SwiftUI is bootstrapping, before the
    /// test bundle is connected and it is safe to start Core Audio playback.
    func setEnvironmentWithoutPlayback(
        mapLayer: AmbientMapLayer,
        weatherLayer: AmbientWeatherLayer
    ) {
        currentMapLayer = mapLayer
        currentWeatherLayer = weatherLayer
        log(kind: "ambient", name: mapLayer.rawValue, gain: 0, detail: "logical state; playback suppressed")
        log(kind: "weather", name: weatherLayer.rawValue, gain: 0, detail: "logical state; playback suppressed")
    }

    func start(volumes: VolumeSettings) {
        self.volumes = volumes
        startEngineIfNeeded()
        applyGains()
        setBGMEnabled(true)
        log(kind: "engine", name: "start", gain: Double(masterGain), detail: "engine running=\(engine.isRunning)")
    }

    func stop() {
        cancelMusicFade()
        farmPlayer.stop()
        creekPlayer.stop()
        rainPlayer.stop()
        farmMusicPlayer.stop()
        creekMusicPlayer.stop()
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
        let previous = currentMapLayer
        currentMapLayer = layer
        stopProceduralAmbiencePlayers()
        ensureMusicPlayback(for: layer, crossfadeFrom: previous)
        applyGains()
        let detail = previous == layer
            ? "suppressed; clean BGM mode; idempotent"
            : "suppressed; clean BGM mode"
        log(kind: "ambient", name: layer.rawValue, gain: 0, detail: detail)
    }

    func setWeatherLayer(_ layer: AmbientWeatherLayer) {
        startEngineIfNeeded()
        let unchanged = currentWeatherLayer == layer
        currentWeatherLayer = layer
        stopProceduralAmbiencePlayers()
        applyGains()
        let detail = unchanged
            ? "suppressed; clean BGM mode; idempotent"
            : "suppressed; clean BGM mode"
        log(kind: "weather", name: layer.rawValue, gain: 0, detail: detail)
    }

    func setBGMEnabled(_ enabled: Bool) {
        startEngineIfNeeded()
        bgmEnabled = enabled
        if enabled, musicGain > 0 {
            if let currentMapLayer {
                ensureMusicPlayback(for: currentMapLayer, crossfadeFrom: nil)
            }
            let detail = currentMapLayer == nil ? "waiting for map layer" : "loop"
            log(kind: "bgm", name: "on", gain: Double(musicGain), detail: detail)
        } else {
            stopAllMusicPlayers()
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
            farmPlayer, creekPlayer, rainPlayer, farmMusicPlayer, creekMusicPlayer,
            bgmPlayer, sfxPlayer, uiPlayer,
        ]
        for node in nodes {
            engine.attach(node)
        }
        let monoFormat = AVAudioFormat(
            standardFormatWithSampleRate: ProceduralAudioBuffers.sampleRate,
            channels: 1
        )!
        let stereoFormat = musicBuffers.values.first?.format
            ?? AVAudioFormat(
                standardFormatWithSampleRate: ProceduralAudioBuffers.sampleRate,
                channels: 2
            )!
        engine.connect(farmPlayer, to: ambienceMixer, format: monoFormat)
        engine.connect(creekPlayer, to: ambienceMixer, format: monoFormat)
        engine.connect(rainPlayer, to: ambienceMixer, format: monoFormat)
        engine.connect(farmMusicPlayer, to: musicMixer, format: musicBuffers[.farm]?.format ?? stereoFormat)
        engine.connect(creekMusicPlayer, to: musicMixer, format: musicBuffers[.creek]?.format ?? stereoFormat)
        engine.connect(bgmPlayer, to: musicMixer, format: monoFormat)
        engine.connect(sfxPlayer, to: sfxMixer, format: monoFormat)
        engine.connect(uiPlayer, to: uiMixer, format: monoFormat)
        engine.connect(ambienceMixer, to: masterMixer, format: stereoFormat)
        engine.connect(musicMixer, to: masterMixer, format: stereoFormat)
        engine.connect(sfxMixer, to: masterMixer, format: stereoFormat)
        engine.connect(uiMixer, to: masterMixer, format: stereoFormat)
        engine.connect(masterMixer, to: engine.mainMixerNode, format: nil)
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
        ambienceMixer.outputVolume = 0
        sfxMixer.outputVolume = sfxGain <= 0 ? 0 : 1
        uiMixer.outputVolume = uiGain <= 0 ? 0 : 1
        farmPlayer.volume = 0
        creekPlayer.volume = 0
        rainPlayer.volume = 0
        stopProceduralAmbiencePlayers()
        if musicGain <= 0 || !bgmEnabled {
            stopAllMusicPlayers()
        } else if engine.isRunning, let currentMapLayer {
            ensureMusicPlayback(for: currentMapLayer, crossfadeFrom: nil)
        }
    }

    // MARK: - Licensed music

    private func loadLicensedMusic() {
        for track in LicensedMusicCatalog.all {
            do {
                let url = try licensedMusicURL(for: track)
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                guard digest == track.expectedSHA256 else {
                    throw MusicResourceError.hashMismatch(expected: track.expectedSHA256, actual: digest)
                }

                let file = try AVAudioFile(forReading: url)
                guard file.fileFormat.sampleRate == 44_100,
                      file.fileFormat.channelCount == 2,
                      file.length > 0,
                      file.length <= AVAudioFramePosition(UInt32.max)
                else {
                    throw MusicResourceError.unsupportedFormat(
                        sampleRate: file.fileFormat.sampleRate,
                        channels: file.fileFormat.channelCount,
                        frames: file.length
                    )
                }

                let capacity = AVAudioFrameCount(file.length)
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: capacity
                ) else {
                    throw MusicResourceError.bufferAllocationFailed
                }
                try file.read(into: buffer, frameCount: capacity)
                guard buffer.frameLength > 0 else {
                    throw MusicResourceError.shortRead(expected: capacity, actual: 0)
                }
                musicBuffers[track.mapLayer] = buffer
                log(
                    kind: "resource",
                    name: track.cueID,
                    gain: 0,
                    detail: "licensed file ready; filename=\(track.filename); frames=\(buffer.frameLength)"
                )
            } catch {
                let detail = String(describing: error)
                musicLoadFailures[track.mapLayer] = detail
                log(
                    kind: "resource",
                    name: track.cueID,
                    gain: 0,
                    detail: "fallback armed; filename=\(track.filename); error=\(detail)"
                )
            }
        }
    }

    private func licensedMusicURL(for track: LicensedMusicTrack) throws -> URL {
        if let url = resourceBundle.url(
            forResource: track.resourceName,
            withExtension: track.fileExtension
        ) {
            return url
        }
        if let url = resourceBundle.url(
            forResource: track.resourceName,
            withExtension: track.fileExtension,
            subdirectory: "Audio/Resources"
        ) {
            return url
        }
        throw MusicResourceError.missingFile(track.filename)
    }

    private func ensureMusicPlayback(
        for layer: AmbientMapLayer,
        crossfadeFrom previousLayer: AmbientMapLayer?
    ) {
        guard bgmEnabled, musicGain > 0, engine.isRunning else { return }
        let track = LicensedMusicCatalog.track(for: layer)

        guard let buffer = musicBuffers[layer] else {
            cancelMusicFade()
            farmMusicPlayer.stop()
            creekMusicPlayer.stop()
            if !bgmPlayer.isPlaying {
                bgmPlayer.stop()
                bgmPlayer.scheduleBuffer(ProceduralAudioBuffers.bgmLoop(), at: nil, options: .loops)
                bgmPlayer.volume = 1
                bgmPlayer.play()
                let reason = musicLoadFailures[layer] ?? "resource unavailable"
                log(
                    kind: "bgm",
                    name: track.cueID,
                    gain: Double(musicGain),
                    detail: "procedural fallback; reason=\(reason)"
                )
            }
            return
        }

        bgmPlayer.stop()
        let selectedPlayer = musicPlayer(for: layer)
        let otherLayer: AmbientMapLayer = layer == .farm ? .creek : .farm
        let otherPlayer = musicPlayer(for: otherLayer)

        if selectedPlayer.isPlaying {
            if musicFadeTimer == nil {
                selectedPlayer.volume = 1
                otherPlayer.stop()
            }
            return
        }

        let shouldCrossfade = previousLayer != nil
            && previousLayer != layer
            && previousLayer.map { musicPlayer(for: $0).isPlaying } == true

        selectedPlayer.stop()
        selectedPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        selectedPlayer.volume = shouldCrossfade ? 0 : 1
        selectedPlayer.play()

        if shouldCrossfade, let previousLayer {
            startMusicCrossfade(
                from: musicPlayer(for: previousLayer),
                to: selectedPlayer,
                fromTrack: LicensedMusicCatalog.track(for: previousLayer),
                toTrack: track
            )
        } else {
            cancelMusicFade()
            otherPlayer.stop()
        }
        log(
            kind: "bgm",
            name: track.cueID,
            gain: Double(musicGain),
            detail: "licensed loop; filename=\(track.filename)"
        )
    }

    private func startMusicCrossfade(
        from oldPlayer: AVAudioPlayerNode,
        to newPlayer: AVAudioPlayerNode,
        fromTrack: LicensedMusicTrack,
        toTrack: LicensedMusicTrack
    ) {
        cancelMusicFade()
        let steps = 20
        var step = 0
        let timer = DispatchSource.makeTimerSource(queue: .main)
        musicFadeTimer = timer
        timer.schedule(deadline: .now(), repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            step += 1
            let progress = min(1, Float(step) / Float(steps))
            oldPlayer.volume = 1 - progress
            newPlayer.volume = progress
            guard step >= steps else { return }
            oldPlayer.stop()
            newPlayer.volume = 1
            timer.cancel()
            self.musicFadeTimer = nil
        }
        timer.resume()
        log(
            kind: "bgm-transition",
            name: "\(fromTrack.cueID)->\(toTrack.cueID)",
            gain: Double(musicGain),
            detail: "crossfade 1.0s"
        )
    }

    private func cancelMusicFade() {
        musicFadeTimer?.cancel()
        musicFadeTimer = nil
    }

    private func stopAllMusicPlayers() {
        cancelMusicFade()
        farmMusicPlayer.stop()
        creekMusicPlayer.stop()
        bgmPlayer.stop()
    }

    private func musicPlayer(for layer: AmbientMapLayer) -> AVAudioPlayerNode {
        switch layer {
        case .farm: return farmMusicPlayer
        case .creek: return creekMusicPlayer
        }
    }

    private var masterGain: Float { clamped(volumes.master) }
    private var musicGain: Float { masterGain * clamped(volumes.music) }
    private var ambienceGain: Float {
        proceduralAmbienceEnabled ? masterGain * clamped(volumes.ambience) : 0
    }
    private var sfxGain: Float { masterGain * clamped(volumes.sfx) }
    private var uiGain: Float { masterGain * clamped(volumes.ui) }

    private func clamped(_ value: Double) -> Float {
        Float(max(0, min(1, value)))
    }

    private func stopProceduralAmbiencePlayers() {
        farmPlayer.stop()
        creekPlayer.stop()
        rainPlayer.stop()
    }

    private func log(kind: String, name: String, gain: Double, detail: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        events.append(
            AudioLogEvent(timestamp: stamp, kind: kind, name: name, gain: gain, detail: detail)
        )
        writeLogIfPossible()
    }
}

private enum MusicResourceError: Error, CustomStringConvertible {
    case missingFile(String)
    case hashMismatch(expected: String, actual: String)
    case unsupportedFormat(sampleRate: Double, channels: AVAudioChannelCount, frames: AVAudioFramePosition)
    case bufferAllocationFailed
    case shortRead(expected: AVAudioFrameCount, actual: AVAudioFrameCount)

    var description: String {
        switch self {
        case let .missingFile(filename):
            return "missing file: \(filename)"
        case let .hashMismatch(expected, actual):
            return "SHA-256 mismatch: expected \(expected), got \(actual)"
        case let .unsupportedFormat(sampleRate, channels, frames):
            return "unsupported format: \(sampleRate) Hz, \(channels) channels, \(frames) frames"
        case .bufferAllocationFailed:
            return "PCM buffer allocation failed"
        case let .shortRead(expected, actual):
            return "short decode: expected \(expected) frames, got \(actual)"
        }
    }
}
