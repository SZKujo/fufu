import Foundation

public struct SpriteFrameRect: Equatable, Sendable {
    public var minX: Int
    public var minY: Int
    public var width: Int
    public var height: Int

    public var maxX: Int { minX + width }
    public var maxY: Int { minY + height }

    public init(minX: Int, minY: Int, width: Int, height: Int) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
    }
}

public struct SpriteSheetSpec: Equatable, Sendable {
    public var id: String
    public var imageWidth: Int
    public var imageHeight: Int
    public var columns: Int
    public var rows: Int
    public var framesPerSecond: Double
    public var frameRects: [SpriteFrameRect]
    public var actions: [PetAction: [Int]]

    public var frameWidth: Int { imageWidth / columns }
    public var frameHeight: Int { imageHeight / rows }
    public var frameCount: Int { frameRects.isEmpty ? columns * rows : frameRects.count }
    public var maxFrameWidth: Int {
        frameRects.map(\.width).max() ?? frameWidth
    }
    public var maxFrameHeight: Int {
        frameRects.map(\.height).max() ?? frameHeight
    }

    public init(
        id: String,
        imageWidth: Int,
        imageHeight: Int,
        columns: Int,
        rows: Int,
        framesPerSecond: Double,
        frameRects: [SpriteFrameRect] = [],
        actions: [PetAction: [Int]]
    ) {
        self.id = id
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.columns = columns
        self.rows = rows
        self.framesPerSecond = framesPerSecond
        self.frameRects = frameRects
        self.actions = actions
    }

    public func frameRect(for frameIndex: Int) -> SpriteFrameRect {
        let safeIndex = max(0, min(frameIndex, frameCount - 1))
        if !frameRects.isEmpty {
            return frameRects[safeIndex]
        }
        let column = safeIndex % columns
        let row = safeIndex / columns
        return SpriteFrameRect(
            minX: column * frameWidth,
            minY: row * frameHeight,
            width: frameWidth,
            height: frameHeight
        )
    }

    public func frameIndex(for action: PetAction, tick: Int) -> Int {
        let frames = actions[action] ?? actions[.idle] ?? [0]
        guard !frames.isEmpty else { return 0 }
        return frames[abs(tick) % frames.count]
    }
}

public extension SpriteSheetSpec {
    static let codexMainey = SpriteSheetSpec(
        id: "codex-mainey",
        imageWidth: 1536,
        imageHeight: 1872,
        columns: 1,
        rows: 1,
        framesPerSecond: 9,
        frameRects: [
            SpriteFrameRect(minX: 7, minY: 5, width: 178, height: 198),
            SpriteFrameRect(minX: 198, minY: 5, width: 179, height: 198),
            SpriteFrameRect(minX: 390, minY: 5, width: 179, height: 198),
            SpriteFrameRect(minX: 581, minY: 5, width: 182, height: 197),
            SpriteFrameRect(minX: 774, minY: 5, width: 180, height: 198),
            SpriteFrameRect(minX: 969, minY: 5, width: 174, height: 198),
            SpriteFrameRect(minX: 198, minY: 213, width: 179, height: 198),
            SpriteFrameRect(minX: 1351, minY: 213, width: 177, height: 198),
            SpriteFrameRect(minX: 773, minY: 214, width: 182, height: 195),
            SpriteFrameRect(minX: 389, minY: 216, width: 182, height: 192),
            SpriteFrameRect(minX: 581, minY: 217, width: 182, height: 189),
            SpriteFrameRect(minX: 965, minY: 218, width: 182, height: 187),
            SpriteFrameRect(minX: 1157, minY: 220, width: 182, height: 183),
            SpriteFrameRect(minX: 5, minY: 226, width: 182, height: 172),
            SpriteFrameRect(minX: 7, minY: 421, width: 177, height: 198),
            SpriteFrameRect(minX: 1158, minY: 421, width: 179, height: 198),
            SpriteFrameRect(minX: 581, minY: 422, width: 182, height: 195),
            SpriteFrameRect(minX: 965, minY: 424, width: 182, height: 192),
            SpriteFrameRect(minX: 773, minY: 425, width: 182, height: 189),
            SpriteFrameRect(minX: 389, minY: 426, width: 182, height: 187),
            SpriteFrameRect(minX: 197, minY: 428, width: 182, height: 183),
            SpriteFrameRect(minX: 1349, minY: 434, width: 182, height: 172),
            SpriteFrameRect(minX: 5, minY: 629, width: 182, height: 198),
            SpriteFrameRect(minX: 198, minY: 629, width: 180, height: 198),
            SpriteFrameRect(minX: 581, minY: 630, width: 182, height: 196),
            SpriteFrameRect(minX: 389, minY: 631, width: 182, height: 193),
            SpriteFrameRect(minX: 396, minY: 837, width: 167, height: 198),
            SpriteFrameRect(minX: 197, minY: 838, width: 182, height: 196),
            SpriteFrameRect(minX: 581, minY: 840, width: 182, height: 192),
            SpriteFrameRect(minX: 773, minY: 848, width: 182, height: 175),
            SpriteFrameRect(minX: 5, minY: 854, width: 182, height: 163),
            SpriteFrameRect(minX: 965, minY: 1047, width: 182, height: 193),
            SpriteFrameRect(minX: 1157, minY: 1051, width: 182, height: 186),
            SpriteFrameRect(minX: 197, minY: 1055, width: 182, height: 178),
            SpriteFrameRect(minX: 773, minY: 1056, width: 182, height: 175),
            SpriteFrameRect(minX: 1349, minY: 1056, width: 182, height: 175),
            SpriteFrameRect(minX: 5, minY: 1057, width: 182, height: 173),
            SpriteFrameRect(minX: 581, minY: 1062, width: 182, height: 163),
            SpriteFrameRect(minX: 389, minY: 1096, width: 182, height: 95),
            SpriteFrameRect(minX: 8, minY: 1253, width: 175, height: 198),
            SpriteFrameRect(minX: 207, minY: 1253, width: 161, height: 198),
            SpriteFrameRect(minX: 585, minY: 1253, width: 173, height: 198),
            SpriteFrameRect(minX: 970, minY: 1253, width: 171, height: 198),
            SpriteFrameRect(minX: 773, minY: 1257, width: 182, height: 189),
            SpriteFrameRect(minX: 389, minY: 1273, width: 182, height: 157),
            SpriteFrameRect(minX: 16, minY: 1461, width: 159, height: 198),
            SpriteFrameRect(minX: 401, minY: 1461, width: 158, height: 198),
            SpriteFrameRect(minX: 777, minY: 1461, width: 173, height: 198),
            SpriteFrameRect(minX: 977, minY: 1461, width: 158, height: 198),
            SpriteFrameRect(minX: 197, minY: 1465, width: 182, height: 189),
            SpriteFrameRect(minX: 581, minY: 1473, width: 182, height: 173),
            SpriteFrameRect(minX: 7, minY: 1669, width: 178, height: 198),
            SpriteFrameRect(minX: 399, minY: 1669, width: 162, height: 198),
            SpriteFrameRect(minX: 975, minY: 1669, width: 162, height: 198),
            SpriteFrameRect(minX: 773, minY: 1678, width: 182, height: 179),
            SpriteFrameRect(minX: 197, minY: 1681, width: 182, height: 174),
            SpriteFrameRect(minX: 581, minY: 1684, width: 182, height: 167)
        ],
        actions: [
            .idle: [0, 1, 2, 3, 4, 5],
            .dragRight: [6, 7, 8, 9, 10, 11, 12, 13],
            .dragLeft: [14, 15, 16, 17, 18, 19, 20, 21],
            .wake: [22, 23, 24, 25],
            .hover: [26, 27, 28, 29, 30],
            .replyError: [31, 32, 33, 34, 35, 36, 37, 38],
            .replyDone: [39, 40, 41, 42, 43, 44],
            .thinking: [45, 46, 47, 48, 49, 50],
            .replying: [51, 52, 53, 54, 55, 56]
        ]
    )
}
