import XCTest
@testable import CreekSprout

final class SynthesizedAudioServiceTests: XCTestCase {
    func testProductOwnerSelectedLicensedTracksMapToFarmAndCreek() {
        let farm = LicensedMusicCatalog.track(for: .farm)
        XCTAssertEqual(farm.title, "今日もいい日 / Today Is a Good Day")
        XCTAssertEqual(farm.filename, "music_farm_today_is_a_good_day_v01.mp3")
        XCTAssertEqual(farm.creator, "HALTO")

        let creek = LicensedMusicCatalog.track(for: .creek)
        XCTAssertEqual(creek.title, "はずむ足どり / Bouncy Steps")
        XCTAssertEqual(creek.filename, "music_creek_bouncy_steps_v01.mp3")
        XCTAssertEqual(creek.creator, "HALTO")
    }

    func testSelectedLicensedTracksResolveAndDecodeFromAppBundle() {
        let audio = SynthesizedAudioService()
        for track in LicensedMusicCatalog.all {
            XCTAssertEqual(
                audio.musicPlaybackSource(for: track.mapLayer),
                .licensedFile(cueID: track.cueID, filename: track.filename),
                "resource events: \(audio.events)"
            )
            XCTAssertTrue(audio.events.contains {
                $0.kind == "resource"
                    && $0.name == track.cueID
                    && $0.detail.contains("licensed file ready")
            })
        }
    }

    func testLicensedMusicManifestMatchesRuntimeCatalog() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "licensed_music_manifest", withExtension: "json")
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])
        let manifestFiles = Set(tracks.compactMap { $0["runtime_file"] as? String })
        XCTAssertEqual(manifestFiles, Set(LicensedMusicCatalog.all.map(\.filename)))
        let manifestHashes = Set(tracks.compactMap { $0["sha256"] as? String })
        XCTAssertEqual(manifestHashes, Set(LicensedMusicCatalog.all.map(\.expectedSHA256)))
    }

    func testMissingLicensedTracksArmProceduralFallback() throws {
        let temporaryBundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-audio-\(UUID().uuidString).bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryBundleURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryBundleURL) }
        let infoData = try PropertyListSerialization.data(
            fromPropertyList: [
                "CFBundleIdentifier": "com.creeksprout.tests.empty-audio",
                "CFBundleName": "EmptyAudio",
            ],
            format: .xml,
            options: 0
        )
        try infoData.write(to: temporaryBundleURL.appendingPathComponent("Info.plist"))
        let emptyBundle = try XCTUnwrap(Bundle(url: temporaryBundleURL))
        let audio = SynthesizedAudioService(resourceBundle: emptyBundle)

        XCTAssertEqual(audio.musicPlaybackSource(for: .farm), .proceduralFallback)
        XCTAssertEqual(audio.musicPlaybackSource(for: .creek), .proceduralFallback)
        XCTAssertEqual(
            audio.events.filter { $0.kind == "resource" && $0.detail.contains("fallback armed") }.count,
            2
        )
    }

    func testMasterVolumeZeroMutesAllBuses() {
        let audio = SynthesizedAudioService()
        var volumes = VolumeSettings.defaults
        audio.start(volumes: volumes)
        XCTAssertGreaterThan(audio.gain(for: .music), 0)
        volumes.master = 0
        audio.applyVolumes(volumes)
        XCTAssertEqual(audio.gain(for: .master), 0)
        XCTAssertEqual(audio.gain(for: .music), 0)
        XCTAssertEqual(audio.gain(for: .ambience), 0)
        XCTAssertEqual(audio.gain(for: .sfx), 0)
        XCTAssertEqual(audio.gain(for: .ui), 0)
        XCTAssertTrue(audio.isSilent(bus: .sfx))
        audio.play(.harvest)
        XCTAssertEqual(audio.events.last?.name, "harvest")
        XCTAssertEqual(audio.events.last?.gain, 0)
        audio.stop()
    }

    func testMapAndWeatherChangesKeepProceduralAmbienceSuppressed() {
        let audio = SynthesizedAudioService()
        audio.start(volumes: .defaults)
        XCTAssertFalse(audio.isProceduralAmbienceEnabled)
        XCTAssertEqual(audio.gain(for: .ambience), 0)

        audio.setMapLayer(.farm)
        audio.setMapLayer(.farm)
        let farmEvents = audio.events.filter { $0.kind == "ambient" && $0.name == "farm" }
        XCTAssertTrue(farmEvents.allSatisfy { $0.gain == 0 && $0.detail.contains("suppressed") })
        XCTAssertTrue(farmEvents.contains { $0.detail.contains("idempotent") })

        audio.setMapLayer(.creek)
        XCTAssertEqual(audio.mapLayer, .creek)
        XCTAssertTrue(audio.events.contains {
            $0.kind == "bgm-transition"
                && $0.name.contains("music.farm.today_is_a_good_day.v01")
                && $0.name.contains("music.creek.bouncy_steps.v01")
        })
        let creekEvent = audio.events.last { $0.kind == "ambient" && $0.name == "creek" }
        XCTAssertEqual(creekEvent?.gain, 0)
        XCTAssertTrue(creekEvent?.detail.contains("clean BGM mode") == true)

        audio.setWeatherLayer(.rain)
        audio.setWeatherLayer(.rain)
        XCTAssertEqual(audio.weatherLayer, .rain)
        XCTAssertTrue(audio.events.contains {
            $0.kind == "weather"
                && $0.name == "rain"
                && $0.gain == 0
                && $0.detail.contains("suppressed")
                && $0.detail.contains("idempotent")
        })
        XCTAssertFalse(audio.isProceduralAmbiencePlaying)
        audio.stop()
    }

    func testBGMToggleAndCategoryMute() {
        let audio = SynthesizedAudioService()
        audio.start(volumes: .defaults)
        XCTAssertTrue(audio.isBGMEnabled)
        audio.setBGMEnabled(false)
        XCTAssertFalse(audio.isBGMEnabled)
        XCTAssertEqual(audio.events.last { $0.kind == "bgm" }?.name, "off")
        audio.setBGMEnabled(true)
        XCTAssertEqual(audio.events.last { $0.kind == "bgm" }?.name, "on")
        var volumes = VolumeSettings.defaults
        volumes.music = 0
        audio.applyVolumes(volumes)
        XCTAssertEqual(audio.gain(for: .music), 0)
        audio.setBGMEnabled(true)
        XCTAssertTrue(audio.events.last { $0.kind == "bgm" }?.detail.contains("silent") == true)
        audio.stop()
    }

    func testUICuesLogFourLaborClasses() {
        let audio = SynthesizedAudioService()
        audio.start(volumes: .defaults)
        for cue in UISoundCue.allCases {
            audio.play(cue)
        }
        let names = Set(audio.events.filter { $0.kind == "sfx" }.map(\.name))
        XCTAssertTrue(names.isSuperset(of: ["harvest", "deposit", "settle", "talk", "craft"]))
        audio.stop()
    }
}
