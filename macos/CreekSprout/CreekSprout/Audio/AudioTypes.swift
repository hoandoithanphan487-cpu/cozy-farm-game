import Foundation

enum AmbientMapLayer: String, Equatable, CaseIterable, Sendable {
    case farm
    case creek
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
