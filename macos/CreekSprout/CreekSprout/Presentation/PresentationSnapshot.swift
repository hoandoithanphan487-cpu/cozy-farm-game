import AppKit
import Metal
import SpriteKit

enum PresentationSnapshot {
    static func pngData(from scene: SKScene, size: CGSize) -> Data? {
        if let metal = metalPNG(from: scene, size: size) {
            return metal
        }
        return viewPNG(from: scene, size: size)
    }

    static func pngData(from node: SKNode, canvas: CGSize, background: SKColor) -> Data? {
        node.removeFromParent()
        let scene = SKScene(size: canvas)
        scene.backgroundColor = background
        scene.anchorPoint = .zero
        node.position = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        scene.addChild(node)
        return pngData(from: scene, size: canvas)
    }

    static func writePNG(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    private static func metalPNG(from scene: SKScene, size: CGSize) -> Data? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            return nil
        }
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0.16, 0.22, 0.18, 1)

        let renderer = SKRenderer(device: device)
        renderer.scene = scene
        guard let buffer = queue.makeCommandBuffer() else {
            return nil
        }
        renderer.render(
            withViewport: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)),
            commandBuffer: buffer,
            renderPassDescriptor: pass
        )
        buffer.commit()
        buffer.waitUntilCompleted()

        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(
            &bytes,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ), let image = context.makeImage() else {
            return nil
        }
        return pngData(from: image)
    }

    private static func viewPNG(from scene: SKScene, size: CGSize) -> Data? {
        if let existing = scene.view {
            existing.layoutSubtreeIfNeeded()
            if let texture = existing.texture(from: scene) {
                return pngData(from: texture.cgImage())
            }
        }
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.allowsTransparency = false
        let window = NSWindow(
            contentRect: view.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderBack(nil)
        defer { window.close() }
        if scene.view == nil {
            view.presentScene(scene)
        }
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.08))
        if let texture = (scene.view ?? view).texture(from: scene) {
            return pngData(from: texture.cgImage())
        }
        return nil
    }

    private static func pngData(from image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }
}
