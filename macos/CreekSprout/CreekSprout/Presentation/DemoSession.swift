import CoreGraphics
import Foundation

enum DemoCopy {
    static let title = "溪谷新芽"
    static let subtitle = "照料新芽农场，修复溪谷水渠，和邻居一起过安稳的社区日子。"
    static let localSinglePlayer = "本地单人游戏 · 不需要联网"
    static let startDemo = "开始演示"
    static let continueGame = "继续游戏"
    static let settings = "设置"
    static let controls = "操作说明"
    static let resume = "继续"
    static let restartDemo = "重新开始演示"
    static let returnToTitle = "返回标题"
    static let confirmRestartTitle = "重新开始演示？"
    static let confirmRestartBody = "当前演示进度会丢失。三个手动存档和自动存档不会被改写。"
    static let confirmRestart = "确认重新开始"
    static let cancelRestart = "取消"
    static let continueUnavailable = "还没有可继续的存档"
    static let pauseTitle = "暂停"
    static let keyboardHint = "↑↓ 选择  ·  回车开始  ·  鼠标也可点击  ·  Esc 打开或关闭暂停"
    static let controlsBody = [
        "移动：WASD 或方向键",
        "动作 / 采集 / 进出地图：空格或回车",
        "交谈：走到角色旁按 T",
        "工具：1 锄头  2 种子  3 水壶  4 收获手套",
        "投入出售箱：I    角色信息：Q    建筑详情：E",
        "靠近溪火猫食铺：点击提示卡或按 J 打开美术巡礼",
        "保存：K    读取：L    设置或暂停：Esc",
        "成功提示以「成功：」标明，失败提示以「失败：」标明，不只靠颜色。",
    ].joined(separator: "\n")

    static let welcomeItems = [startDemo, continueGame, settings, controls]
    static let pauseItems = [resume, settings, controls, restartDemo, returnToTitle]
}

enum DemoShellRoute: Equatable, Sendable {
    case welcome
    case playing
}

enum DemoOverlay: Equatable, Sendable {
    case none
    case pause
    case settings
    case controls
    case restartConfirm
}

enum DemoSessionKind: Equatable, Sendable {
    case none
    case demo
    case formalCampaign
    case continuePlay
}

enum DemoShellCommand: Equatable, Sendable {
    case none
    case startDemo
    case continueGame
    case openSettings
    case openControls
    case closeOverlay
    case resume
    case requestRestartDemo
    case confirmRestartDemo
    case cancelRestart
    case returnToTitle
}

struct DemoShellState: Equatable, Sendable {
    var route: DemoShellRoute = .welcome
    var overlay: DemoOverlay = .none
    var sessionKind: DemoSessionKind = .none
    var selectedWelcomeIndex = 0
    var selectedPauseIndex = 0
    var continueAvailable = false
    var settingsReturnOverlay: DemoOverlay = .none

    var welcomeItemCount: Int { DemoCopy.welcomeItems.count }
    var pauseItemCount: Int { DemoCopy.pauseItems.count }

    var isClockPaused: Bool {
        overlay == .pause
            || overlay == .settings
            || overlay == .controls
            || overlay == .restartConfirm
            || route == .welcome
    }

    mutating func moveWelcomeSelection(_ delta: Int) {
        let count = max(welcomeItemCount, 1)
        selectedWelcomeIndex = (selectedWelcomeIndex + delta + count) % count
    }

    mutating func movePauseSelection(_ delta: Int) {
        let count = max(pauseItemCount, 1)
        selectedPauseIndex = (selectedPauseIndex + delta + count) % count
    }

    mutating func activateWelcomeSelection() -> DemoShellCommand {
        switch selectedWelcomeIndex {
        case 0: return .startDemo
        case 1: return continueAvailable ? .continueGame : .none
        case 2: return .openSettings
        case 3: return .openControls
        default: return .none
        }
    }

    mutating func activatePauseSelection() -> DemoShellCommand {
        switch selectedPauseIndex {
        case 0: return .resume
        case 1: return .openSettings
        case 2: return .openControls
        case 3: return .requestRestartDemo
        case 4: return .returnToTitle
        default: return .none
        }
    }

    mutating func apply(_ command: DemoShellCommand) {
        switch command {
        case .none:
            break
        case .startDemo:
            route = .playing
            sessionKind = .demo
            overlay = .none
            selectedPauseIndex = 0
        case .continueGame:
            guard continueAvailable else { return }
            route = .playing
            sessionKind = .continuePlay
            overlay = .none
            selectedPauseIndex = 0
        case .openSettings:
            settingsReturnOverlay = route == .playing && overlay != .settings ? (overlay == .none ? .pause : overlay) : .none
            overlay = .settings
        case .openControls:
            if route == .playing && overlay == .none {
                overlay = .pause
            }
            overlay = .controls
        case .closeOverlay:
            if overlay == .settings {
                overlay = settingsReturnOverlay
                settingsReturnOverlay = .none
            } else if overlay == .controls {
                overlay = route == .playing ? .pause : .none
            } else {
                overlay = .none
            }
        case .resume:
            overlay = .none
        case .requestRestartDemo:
            overlay = .restartConfirm
        case .confirmRestartDemo:
            route = .playing
            sessionKind = .demo
            overlay = .none
            selectedPauseIndex = 0
        case .cancelRestart:
            overlay = .pause
        case .returnToTitle:
            route = .welcome
            sessionKind = .none
            overlay = .none
            selectedWelcomeIndex = 0
            selectedPauseIndex = 0
        }
    }

    mutating func handleEscape() -> DemoShellCommand {
        switch overlay {
        case .none where route == .playing:
            overlay = .pause
            selectedPauseIndex = 0
            return .none
        case .pause:
            overlay = .none
            return .resume
        case .restartConfirm:
            overlay = .pause
            return .cancelRestart
        case .settings, .controls:
            apply(.closeOverlay)
            return .closeOverlay
        case .none:
            return .none
        }
    }
}

enum DemoSessionStore {
    static let demoFolderName = "n017-demo-session"

    static var productionDirectory: URL {
        FarmScene.productionSaveDirectory
    }

    static func demoDirectory(root: URL? = nil) -> URL {
        (root ?? productionDirectory).appendingPathComponent(demoFolderName, isDirectory: true)
    }

    static func slotFileNames() -> [String] {
        SaveSlotCatalog.allKnownSlotNamesIncludingLegacy().map { "\($0).json" }
    }

    static func slotURLs(in directory: URL) -> [URL] {
        slotFileNames().map { directory.appendingPathComponent($0) }
    }

    static func hasContinuableSave(in directory: URL) -> Bool {
        slotURLs(in: directory).contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func fingerprint(of directory: URL) -> [String: Data] {
        var result: [String: Data] = [:]
        for url in slotURLs(in: directory) {
            result[url.lastPathComponent] = try? Data(contentsOf: url)
        }
        return result
    }

    static func loadBestSave(
        in directory: URL,
        catalog: ContentCatalog = .vs0
    ) -> (state: GameState, slotIndex: Int)? {
        let names = SaveSlotCatalog.manualSlotNames + [SaveSlotCatalog.autoSlotName, SaveSlotCatalog.legacyDefaultSlot]
        for (index, name) in names.enumerated() {
            let store = SaveStore(directory: directory, slotName: name, catalog: catalog)
            guard FileManager.default.fileExists(atPath: store.primaryURL.path) else { continue }
            guard let state = try? store.load() else { continue }
            let slotIndex = min(index, SaveSlotCatalog.manualSlotNames.count - 1)
            return (state, slotIndex)
        }
        return nil
    }

    static func resetDemoDirectory(_ directory: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

#if DEBUG
enum DemoSessionFixture {
    static let hearthOrigin = GridPosition(x: 9, y: 4)

    static func makeInitialState(catalog: ContentCatalog = .vs0) -> GameState {
        var state = GameState.vs0NewGame(catalog: catalog)
        for record in catalog.scenario.startingFarmCells {
            state.farmCells.removeValue(forKey: record.position)
        }
        for (position, cell) in visualGardenCells() {
            // The isolated demo owns its opening composition. Clear the
            // production teaching strip first so no old crop remains beside
            // the road after the whole field moves west.
            state.farmCells[position] = cell
        }
        // The opened rear plot is authoritative farmland, not a decorative
        // soil sticker. Start these four cells prepared and empty so the PO
        // can immediately seed and water them during the visual demo.
        for position in FarmCultivationCatalog.rearCultivableCells {
            state.farmCells[position] = FarmCell(prepared: true)
        }
        // Keep the in-memory fixture in the same canonical order used by
        // SaveGameDTO so the temporary round-trip verification compares the
        // exact same state on the very first demo save.
        state.placedObjects = visualProps().sorted { $0.instanceID < $1.instanceID }
        return state
    }

    static func matureTeachingCropCount(_ state: GameState) -> Int {
        state.farmCells.values.filter { cell in
            cell.cropID == ContentID.mistRadishCrop && cell.readyToHarvest
        }.count
    }

    static func visualGardenCells() -> [GridPosition: FarmCell] {
        var cells: [GridPosition: FarmCell] = [:]
        // One compact 5 × 4 field replaces the former split beds. Each column
        // has one crop identity, which keeps all five silhouettes readable
        // while leaving x=6 as a fence-and-gate buffer before the x=7 road.
        let cropColumns: [(Int, String)] = [
            (1, ContentID.mistRadishCrop),
            (2, ContentID.streamLeafCrop),
            (3, ContentID.amberBeanCrop),
            (4, ContentID.bellBerryCrop),
            (5, ContentID.honeyMelonCrop),
        ]
        for (x, cropID) in cropColumns {
            for y in 2...5 {
                let isLastTeachingRadish = cropID == ContentID.mistRadishCrop && y == 5
                cells[GridPosition(x: x, y: y)] = staged(
                    cropID,
                    stage: isLastTeachingRadish ? 2 : 3,
                    watered: (x + y).isMultiple(of: 2)
                )
            }
        }
        return cells
    }

    static func visualProps() -> [PlacedObjectState] {
        [
            PlacedObjectState(
                instanceID: "brookseed.placed.woodhoney_hearth#9,4#down#n019-r8",
                definitionID: ContentID.woodhoneyHearthObject,
                origin: hearthOrigin,
                facing: .down
            ),
            PlacedObjectState(
                instanceID: "brookseed.placed.compost_rack#8,5#up#n019-r8",
                definitionID: ContentID.compostRackObject,
                origin: GridPosition(x: 8, y: 5),
                facing: .up
            ),
            PlacedObjectState(
                instanceID: "brookseed.placed.wooden_crate#7,4#down#n019-r8",
                definitionID: ContentID.woodenCrateObject,
                origin: GridPosition(x: 7, y: 4),
                facing: .down
            ),
            PlacedObjectState(
                instanceID: "brookseed.placed.rain_barrel#8,4#down#n019-r8",
                definitionID: ContentID.rainBarrelObject,
                origin: GridPosition(x: 8, y: 4),
                facing: .down
            ),
        ]
    }

    private static func staged(_ cropID: String, stage: Int, watered: Bool = false) -> FarmCell {
        FarmCell(
            prepared: true,
            wateredToday: watered,
            fertility: 0,
            cropID: cropID,
            cropStage: stage >= 3 ? 2 : stage,
            stageProgressDays: max(stage, 0),
            plantedDay: 1,
            readyToHarvest: stage >= 3
        )
    }
}
#endif

struct DemoChromeLayout: Equatable, Sendable {
    var title: CGRect
    var subtitle: CGRect
    var localBadge: CGRect
    var buttons: [CGRect]
    var footer: CGRect

    var allRects: [CGRect] {
        [title, subtitle, localBadge] + buttons + [footer]
    }

    static func welcome(in size: CGSize) -> DemoChromeLayout {
        let padding: CGFloat = size.width >= 1_200 ? 48 : 32
        let buttonWidth = min(360, size.width - padding * 2)
        let buttonHeight: CGFloat = size.height >= 760 ? 48 : 44
        let gap: CGFloat = 12
        let titleHeight: CGFloat = size.height >= 760 ? 54 : 44
        let subtitleHeight: CGFloat = 48
        let badgeHeight: CGFloat = 28
        let footerHeight: CGFloat = 36
        let buttonCount = DemoCopy.welcomeItems.count
        let stackHeight = CGFloat(buttonCount) * buttonHeight + CGFloat(buttonCount - 1) * gap
        let contentHeight = titleHeight + 12 + subtitleHeight + 10 + badgeHeight + 24 + stackHeight + 18 + footerHeight
        let startY = max(padding, (size.height - contentHeight) / 2)
        let centerX = size.width / 2
        let title = CGRect(x: padding, y: startY, width: size.width - padding * 2, height: titleHeight)
        let subtitle = CGRect(x: padding, y: title.maxY + 12, width: size.width - padding * 2, height: subtitleHeight)
        let localBadge = CGRect(x: padding, y: subtitle.maxY + 10, width: size.width - padding * 2, height: badgeHeight)
        var buttons: [CGRect] = []
        var buttonY = localBadge.maxY + 24
        for _ in 0..<buttonCount {
            buttons.append(
                CGRect(x: centerX - buttonWidth / 2, y: buttonY, width: buttonWidth, height: buttonHeight)
            )
            buttonY += buttonHeight + gap
        }
        let footer = CGRect(
            x: padding,
            y: max(buttonY + 6, size.height - padding - footerHeight),
            width: size.width - padding * 2,
            height: footerHeight
        )
        return DemoChromeLayout(
            title: title,
            subtitle: subtitle,
            localBadge: localBadge,
            buttons: buttons,
            footer: footer
        )
    }

    func fitsWithoutOverlapOrClipping(in size: CGSize) -> Bool {
        let bounds = CGRect(origin: .zero, size: size)
        guard allRects.allSatisfy({ bounds.contains($0) }) else { return false }
        let rects = allRects
        for index in rects.indices {
            for other in (index + 1)..<rects.count {
                if rects[index].insetBy(dx: 1, dy: 1).intersects(rects[other].insetBy(dx: 1, dy: 1)) {
                    return false
                }
            }
        }
        return true
    }
}

struct DemoPauseLayout: Equatable, Sendable {
    var panel: CGRect
    var buttons: [CGRect]

    static func pause(in size: CGSize) -> DemoPauseLayout {
        let width = min(420, size.width - 48)
        let buttonHeight: CGFloat = 40
        let gap: CGFloat = 10
        let header: CGFloat = 64
        let count = DemoCopy.pauseItems.count
        let height = header + CGFloat(count) * buttonHeight + CGFloat(count + 1) * gap + 16
        let panel = CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
        var buttons: [CGRect] = []
        var y = panel.minY + header
        for _ in 0..<count {
            buttons.append(CGRect(x: panel.minX + 24, y: y, width: width - 48, height: buttonHeight))
            y += buttonHeight + gap
        }
        return DemoPauseLayout(panel: panel, buttons: buttons)
    }

    func fitsWithoutOverlapOrClipping(in size: CGSize) -> Bool {
        let bounds = CGRect(origin: .zero, size: size)
        guard bounds.contains(panel) else { return false }
        return buttons.allSatisfy { panel.insetBy(dx: 8, dy: 8).contains($0) }
    }
}
