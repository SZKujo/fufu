import AppKit
import DesktopPetCore
import Foundation

enum NineRowSpriteSheetAnalyzer {
    private static let rowActions: [PetAction] = [
        .idle,
        .dragRight,
        .dragLeft,
        .wake,
        .hover,
        .replyError,
        .replyDone,
        .thinking,
        .replying
    ]

    private static let alphaThreshold: UInt8 = 16

    static func spec(for url: URL, framesPerSecond: Double = 9) -> SpriteSheetSpec? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }
        return spec(for: cgImage, framesPerSecond: framesPerSecond)
    }

    static func spec(for image: CGImage, framesPerSecond: Double = 9) -> SpriteSheetSpec {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return fallbackSpec(imageWidth: width, imageHeight: height, framesPerSecond: framesPerSecond)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return spec(
            imageWidth: width,
            imageHeight: height,
            framesPerSecond: framesPerSecond
        ) { x, y in
            let alphaIndex = y * bytesPerRow + x * bytesPerPixel + 3
            return data[alphaIndex] > alphaThreshold
        }
    }

    static func spec(
        imageWidth: Int,
        imageHeight: Int,
        framesPerSecond: Double,
        isVisible: (Int, Int) -> Bool
    ) -> SpriteSheetSpec {
        guard imageWidth > 0, imageHeight > 0 else {
            return fallbackSpec(imageWidth: max(1, imageWidth), imageHeight: max(1, imageHeight), framesPerSecond: framesPerSecond)
        }

        var frameRects: [SpriteFrameRect] = []
        var actions: [PetAction: [Int]] = [:]
        let minimumFrameWidth = max(3, imageWidth / 256)
        let minimumFrameHeight = max(3, imageHeight / 256)
        let maximumMergeGap = max(2, imageWidth / 256)

        for (rowIndex, action) in rowActions.enumerated() {
            let rowMinY = rowIndex * imageHeight / rowActions.count
            let rowMaxY = (rowIndex + 1) * imageHeight / rowActions.count
            let rowRuns = mergedColumnRuns(
                imageWidth: imageWidth,
                yRange: rowMinY..<rowMaxY,
                maximumGap: maximumMergeGap,
                isVisible: isVisible
            )

            for run in rowRuns {
                guard run.count >= minimumFrameWidth else { continue }
                guard let rect = frameRect(
                    xRange: run,
                    yRange: rowMinY..<rowMaxY,
                    minimumFrameHeight: minimumFrameHeight,
                    isVisible: isVisible
                ) else {
                    continue
                }
                actions[action, default: []].append(frameRects.count)
                frameRects.append(rect)
            }
        }

        if frameRects.isEmpty {
            return fallbackSpec(imageWidth: imageWidth, imageHeight: imageHeight, framesPerSecond: framesPerSecond)
        }

        let idleFrames = actions[.idle] ?? [0]
        for action in rowActions where actions[action] == nil {
            actions[action] = idleFrames
        }

        return SpriteSheetSpec(
            id: "nine-row-alpha-\(imageWidth)x\(imageHeight)-\(frameRects.count)",
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            columns: frameRects.count,
            rows: rowActions.count,
            framesPerSecond: framesPerSecond,
            frameRects: frameRects,
            actions: actions
        )
    }

    private static func mergedColumnRuns(
        imageWidth: Int,
        yRange: Range<Int>,
        maximumGap: Int,
        isVisible: (Int, Int) -> Bool
    ) -> [Range<Int>] {
        var rawRuns: [Range<Int>] = []
        var start: Int?
        var lastVisibleX = 0

        for x in 0..<imageWidth {
            let hasVisiblePixel = yRange.contains { y in
                isVisible(x, y)
            }

            if hasVisiblePixel {
                if start == nil {
                    start = x
                }
                lastVisibleX = x
            } else if let runStart = start {
                rawRuns.append(runStart..<(lastVisibleX + 1))
                start = nil
            }
        }

        if let runStart = start {
            rawRuns.append(runStart..<(lastVisibleX + 1))
        }

        return rawRuns.reduce(into: []) { mergedRuns, run in
            guard let previous = mergedRuns.last else {
                mergedRuns.append(run)
                return
            }

            let gap = run.lowerBound - previous.upperBound
            if gap <= maximumGap {
                mergedRuns[mergedRuns.count - 1] = previous.lowerBound..<run.upperBound
            } else {
                mergedRuns.append(run)
            }
        }
    }

    private static func frameRect(
        xRange: Range<Int>,
        yRange: Range<Int>,
        minimumFrameHeight: Int,
        isVisible: (Int, Int) -> Bool
    ) -> SpriteFrameRect? {
        var minY = yRange.upperBound
        var maxY = yRange.lowerBound

        for y in yRange {
            for x in xRange where isVisible(x, y) {
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }

        guard minY <= maxY else { return nil }
        let height = maxY - minY + 1
        guard height >= minimumFrameHeight else { return nil }

        return SpriteFrameRect(
            minX: xRange.lowerBound,
            minY: minY,
            width: xRange.count,
            height: height
        )
    }

    private static func fallbackSpec(
        imageWidth: Int,
        imageHeight: Int,
        framesPerSecond: Double
    ) -> SpriteSheetSpec {
        let rect = SpriteFrameRect(minX: 0, minY: 0, width: max(1, imageWidth), height: max(1, imageHeight))
        return SpriteSheetSpec(
            id: "nine-row-fallback-\(imageWidth)x\(imageHeight)",
            imageWidth: max(1, imageWidth),
            imageHeight: max(1, imageHeight),
            columns: 1,
            rows: 1,
            framesPerSecond: framesPerSecond,
            frameRects: [rect],
            actions: [.idle: [0]]
        )
    }
}
