import Foundation

enum AmbientMapLayer: String, Equatable, Hashable, CaseIterable, Sendable {
    case farm
    case creek
}

struct LicensedMusicTrack: Equatable, Sendable {
    let mapLayer: AmbientMapLayer
    let cueID: String
    let resourceName: String
    let fileExtension: String
    let title: String
    let creator: String
    let expectedSHA256: String

    var filename: String { "\(resourceName).\(fileExtension)" }
}

enum LicensedMusicCatalog {
    static let farm = LicensedMusicTrack(
        mapLayer: .farm,
        cueID: "music.farm.today_is_a_good_day.v01",
        resourceName: "music_farm_today_is_a_good_day_v01",
        fileExtension: "mp3",
        title: "今日もいい日 / Today Is a Good Day",
        creator: "HALTO",
        expectedSHA256: "7e8dc08731715ae8b22b9e399b1ce507e2279840324d7a87db4356bfe101c8e0"
    )

    static let creek = LicensedMusicTrack(
        mapLayer: .creek,
        cueID: "music.creek.bouncy_steps.v01",
        resourceName: "music_creek_bouncy_steps_v01",
        fileExtension: "mp3",
        title: "はずむ足どり / Bouncy Steps",
        creator: "HALTO",
        expectedSHA256: "7ed96174b5d6e074cdd6bb9a7de2b036f4051c2c452c375abbf4101ada87a2e7"
    )

    static let all = [farm, creek]

    static func track(for layer: AmbientMapLayer) -> LicensedMusicTrack {
        switch layer {
        case .farm: return farm
        case .creek: return creek
        }
    }
}

enum MusicPlaybackSource: Equatable, Sendable {
    case licensedFile(cueID: String, filename: String)
    case proceduralFallback
}

enum AmbientWeatherLayer: String, Equatable, CaseIterable, Sendable {
    case none
    case rain
}

enum UISoundCue: String, Equatable, CaseIterable, Sendable {
    case harvest
    case deposit
    case settle
    case talk
    case craft
}

enum AudioBus: String, Equatable, Sendable {
    case master
    case music
    case ambience
    case sfx
    case ui
}

struct AudioLogEvent: Equatable, Sendable, Codable {
    var timestamp: String
    var kind: String
    var name: String
    var gain: Double
    var detail: String

    enum CodingKeys: String, CodingKey {
        case timestamp
        case kind
        case name
        case gain
        case detail
    }
}
