import CoreGraphics

enum FloatingPetWindowPlacement {
    private static let margin: CGFloat = 12

    static func visibleOrigin(
        preferredOrigin: CGPoint,
        size: CGSize,
        visibleFrames: [CGRect]
    ) -> CGPoint {
        guard let visibleFrame = bestVisibleFrame(
            for: CGRect(origin: preferredOrigin, size: size),
            visibleFrames: visibleFrames
        ) else {
            return preferredOrigin
        }

        return CGPoint(
            x: clamped(
                preferredOrigin.x,
                minimum: visibleFrame.minX + margin,
                maximum: visibleFrame.maxX - size.width - margin
            ),
            y: clamped(
                preferredOrigin.y,
                minimum: visibleFrame.minY + margin,
                maximum: visibleFrame.maxY - size.height - margin
            )
        )
    }

    private static func bestVisibleFrame(
        for windowFrame: CGRect,
        visibleFrames: [CGRect]
    ) -> CGRect? {
        guard !visibleFrames.isEmpty else { return nil }
        if let intersectingFrame = visibleFrames.max(by: {
            $0.intersection(windowFrame).area < $1.intersection(windowFrame).area
        }), intersectingFrame.intersection(windowFrame).area > 0 {
            return intersectingFrame
        }

        return visibleFrames.min {
            $0.center.distance(to: windowFrame.center) < $1.center.distance(to: windowFrame.center)
        }
    }

    private static func clamped(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard minimum <= maximum else { return minimum }
        return min(max(value, minimum), maximum)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }

    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
