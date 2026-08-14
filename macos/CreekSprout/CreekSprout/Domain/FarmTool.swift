enum FarmTool: String, Equatable, Sendable {
    case hoe
    case seed
    case water
    case harvest

    var staminaCost: Int { 2 }
}
