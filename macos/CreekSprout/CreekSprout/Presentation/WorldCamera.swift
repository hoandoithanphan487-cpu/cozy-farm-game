import CoreGraphics
import SpriteKit

/// Presentation-only camera: integer pixel zoom and player-centered framing.
/// It never changes collision, topology, or save data.
enum WorldCamera {
    static let bleedCells = 3
    static let framingTop: CGFloat = 52
    static let framingBottom: CGFloat = 58

    static func integerZoom(for viewport: CGSize) -> CGFloat {
        viewport.width >= 1_200 || viewport.height >= 760 ? 3 : 2
    }

    static func cellSize(for viewport: CGSize) -> CGFloat {
        integerZoom(for: viewport) * PixelMetrics.tileNative
    }

    static func framingRect(in viewport: CGSize) -> CGRect {
        let height = max(viewport.height - framingTop - framingBottom, 1)
        return CGRect(x: 0, y: framingBottom, width: viewport.width, height: height)
    }

    /// Converts SwiftUI's top-left HUD coordinate space into SpriteKit's
    /// bottom-left scene coordinate space.
    static func sceneSafeRect(fromHudSafeRect hudRect: CGRect, viewport: CGSize) -> CGRect {
        CGRect(
            x: hudRect.minX,
            y: viewport.height - hudRect.maxY,
            width: hudRect.width,
            height: hudRect.height
        )
    }

    static func worldOrigin(
        viewport: CGSize,
        mapColumns: Int,
        mapRows: Int,
        cellSize: CGFloat,
        player: GridPosition,
        safeRect: CGRect? = nil
    ) -> CGPoint {
        let safe = safeRect ?? framingRect(in: viewport)
        let mapWidth = CGFloat(mapColumns) * cellSize
        let mapHeight = CGFloat(mapRows) * cellSize
        let playerWorld = CGPoint(
            x: (CGFloat(player.x) + 0.5) * cellSize,
            y: (CGFloat(player.y) + 0.5) * cellSize
        )
        var origin = CGPoint(x: safe.midX - playerWorld.x, y: safe.midY - playerWorld.y)
        if mapWidth >= safe.width {
            origin.x = min(safe.minX, origin.x)
            origin.x = max(safe.maxX - mapWidth, origin.x)
        } else {
            origin.x = safe.midX - mapWidth / 2
        }
        if mapHeight >= safe.height {
            origin.y = min(safe.minY, origin.y)
            origin.y = max(safe.maxY - mapHeight, origin.y)
        } else {
            origin.y = safe.midY - mapHeight / 2
        }
        return PixelMetrics.snap(origin)
    }

    static func atmosphereColor(mapID: String, isRain: Bool, restored: Bool) -> SKColor {
        let isMarket = mapID == ContentID.creekMarket
        if isRain {
            return isMarket
                ? SKColor(red: 0.10, green: 0.16, blue: 0.24, alpha: 1)
                : SKColor(red: 0.12, green: 0.18, blue: 0.16, alpha: 1)
        }
        if isMarket {
            return restored
                ? SKColor(red: 0.20, green: 0.36, blue: 0.40, alpha: 1)
                : SKColor(red: 0.18, green: 0.30, blue: 0.34, alpha: 1)
        }
        return restored
            ? SKColor(red: 0.32, green: 0.46, blue: 0.24, alpha: 1)
            : SKColor(red: 0.28, green: 0.40, blue: 0.22, alpha: 1)
    }

    static func weatherWash(isRain: Bool, isMarket: Bool) -> SKColor {
        if isRain {
            return SKColor(red: 0.12, green: 0.20, blue: 0.32, alpha: isMarket ? 0.18 : 0.15)
        }
        return isMarket
            ? SKColor(red: 0.18, green: 0.42, blue: 0.48, alpha: 0.025)
            : SKColor(red: 0.62, green: 0.52, blue: 0.22, alpha: 0.025)
    }
}
