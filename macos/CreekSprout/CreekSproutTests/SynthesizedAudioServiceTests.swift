import XCTest
@testable import CreekSprout

final class SynthesizedAudioServiceTests: XCTestCase {
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

    func testAmbientLayerSwitchIsIdempotent() {
        let audio = SynthesizedAudioService()
        audio.start(volumes: .defaults)
        audio.setMapLayer(.farm)
        audio.setMapLayer(.farm)
        let farmEvents = audio.events.filter { $0.kind == "ambient" && $0.name == "farm" }
        XCTAssertGreaterThanOrEqual(farmEvents.filter { $0.detail == "start" }.count, 1)
        XCTAssertGreaterThanOrEqual(farmEvents.filter { $0.detail == "idempotent skip" }.count, 1)
        audio.setMapLayer(.creek)
        XCTAssertEqual(audio.mapLayer, .creek)
        let creekStart = audio.events.last { $0.kind == "ambient" && $0.name == "creek" }
        XCTAssertEqual(creekStart?.detail, "start")
        let farmStop = audio.events.last { $0.kind == "ambient" && $0.name == "farm" && $0.detail == "stop" }
        XCTAssertNotNil(farmStop)
        audio.setWeatherLayer(.rain)
        audio.setWeatherLayer(.rain)
        XCTAssertEqual(audio.weatherLayer, .rain)
        XCTAssertTrue(audio.events.contains { $0.kind == "weather" && $0.detail == "idempotent skip" })
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
