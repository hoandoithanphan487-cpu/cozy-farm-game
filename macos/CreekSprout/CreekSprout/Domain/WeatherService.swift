//
//  WeatherService.swift
//  CreekSprout
//
//  Scripted VS-1 weather. Day 2 is rain; rain marks outdoor ordinary plots as
//  watered at day start. Indoor/shelter flags do not exist in the slice, so
//  every farm cell with a crop or prepared soil counts as outdoor.
//

enum WeatherService {
    /// Applies the day's scripted weather after the clock has rolled. Returns
    /// the number of outdoor plots marked watered. Idempotent within a day.
    @discardableResult
    static func applyDayStart(state: inout GameState, catalog: ContentCatalog) -> Int {
        guard catalog.scenario.weather(on: state.clock.day) == .rain else {
            return 0
        }
        var watered = 0
        for position in state.farmCells.keys.sorted(by: { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }) {
            var cell = state.farmCells[position] ?? FarmCell()
            guard cell.hasCrop || cell.prepared else {
                continue
            }
            if !cell.wateredToday {
                cell.wateredToday = true
            }
            state.farmCells[position] = cell
            watered += 1
        }
        return watered
    }
}
