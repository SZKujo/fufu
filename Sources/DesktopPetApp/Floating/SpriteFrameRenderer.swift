import AppKit
import DesktopPetCore
import Foundation

@MainActor
final class SpriteFrameRenderer {
    static let shared = SpriteFrameRenderer()

    private var sheetCache: [URL: CGImage] = [:]
    private var specCache: [URL: SpriteSheetSpec] = [:]
    private var frameCache: [String: NSImage] = [:]

    func spec(for assetURL: URL) -> SpriteSheetSpec {
        if let cached = specCache[assetURL] {
            return cached
        }

        guard let sheet = sheetImage(for: assetURL) else {
            return SpriteSheetSpec.codexMainey
        }

        let spec = NineRowSpriteSheetAnalyzer.spec(for: sheet)
        specCache[assetURL] = spec
        return spec
    }

    func image(assetURL: URL, spec: SpriteSheetSpec, action: PetAction, tick: Int) -> NSImage? {
        image(assetURL: assetURL, spec: spec, frameIndex: spec.frameIndex(for: action, tick: tick))
    }

    func preloadFrames(for assetURL: URL) {
        let spec = spec(for: assetURL)
        for frameIndex in 0..<spec.frameCount {
            _ = image(assetURL: assetURL, spec: spec, frameIndex: frameIndex)
        }
    }

    func image(assetURL: URL, spec: SpriteSheetSpec, frameIndex: Int) -> NSImage? {
        let key = "\(assetURL.path)-\(spec.id)-\(frameIndex)"
        if let cached = frameCache[key] {
            return cached
        }

        guard let sheet = sheetImage(for: assetURL) else { return nil }
        let rect = spec.frameRect(for: frameIndex)
        let cropRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height
        )
        guard let cropped = sheet.cropping(to: cropRect) else { return nil }

        let image = normalizedImage(cropped, rect: rect, spec: spec)
        frameCache[key] = image
        return image
    }

    private func normalizedImage(_ frame: CGImage, rect: SpriteFrameRect, spec: SpriteSheetSpec) -> NSImage {
        let canvasWidth = max(rect.width, spec.maxFrameWidth)
        let canvasHeight = max(rect.height, spec.maxFrameHeight)
        let bytesPerPixel = 4
        let bytesPerRow = canvasWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: canvasHeight * bytesPerRow)

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: &pixels,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return NSImage(cgImage: frame, size: NSSize(width: rect.width, height: rect.height))
        }

        context.interpolationQuality = .none
        let drawRect = CGRect(
            x: (canvasWidth - rect.width) / 2,
            y: canvasHeight - rect.height,
            width: rect.width,
            height: rect.height
        )
        context.draw(frame, in: drawRect)

        guard let normalizedFrame = context.makeImage() else {
            return NSImage(cgImage: frame, size: NSSize(width: rect.width, height: rect.height))
        }
        return NSImage(
            cgImage: normalizedFrame,
            size: NSSize(width: canvasWidth, height: canvasHeight)
        )
    }

    private func sheetImage(for url: URL) -> CGImage? {
        if let cached = sheetCache[url] {
            return cached
        }

        guard let nsImage = NSImage(contentsOf: url) else { return nil }
        var proposedRect = NSRect(origin: .zero, size: nsImage.size)
        guard let cgImage = nsImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }
        sheetCache[url] = cgImage
        return cgImage
    }
}
