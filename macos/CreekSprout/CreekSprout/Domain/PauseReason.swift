enum PauseReason: String, Hashable, Sendable {
    case menu = "MENU"
    case dialogue = "DIALOGUE"
    case cutscene = "CUTSCENE"
    case loading = "LOADING"
    case sleep = "SLEEP"
}
