import Foundation

public struct PetAnimationPolicy: Sendable {
    public var idleHoldTicks: Int
    public var idleMotionTicks: Int

    public init(idleHoldTicks: Int = 72, idleMotionTicks: Int = 8) {
        self.idleHoldTicks = idleHoldTicks
        self.idleMotionTicks = idleMotionTicks
    }

    public func frameIndex(for action: PetAction, tick: Int, spec: SpriteSheetSpec) -> Int {
        switch action {
        case .idle:
            return idleFrameIndex(tick: tick, spec: spec)
        case .hover:
            return slowerFrameIndex(for: .hover, tick: tick, spec: spec, divisor: 2)
        case .dragRight, .dragLeft:
            return slowerFrameIndex(for: action, tick: tick, spec: spec, divisor: 3)
        case .thinking, .replying:
            return slowerFrameIndex(for: action, tick: tick, spec: spec, divisor: 4)
        case .replyError, .replyDone:
            return slowerFrameIndex(for: action, tick: tick, spec: spec, divisor: 5)
        case .wake:
            return spec.frameIndex(for: action, tick: tick)
        }
    }

    private func idleFrameIndex(tick: Int, spec: SpriteSheetSpec) -> Int {
        let idleFrames = spec.actions[.idle] ?? [0]
        guard let firstFrame = idleFrames.first else { return 0 }

        let cycle = max(1, idleHoldTicks + idleMotionTicks)
        let position = abs(tick) % cycle
        guard position >= idleHoldTicks else {
            return firstFrame
        }

        let motionTick = position - idleHoldTicks
        return spec.frameIndex(for: .idle, tick: motionTick)
    }

    private func slowerFrameIndex(
        for action: PetAction,
        tick: Int,
        spec: SpriteSheetSpec,
        divisor: Int
    ) -> Int {
        spec.frameIndex(for: action, tick: abs(tick) / max(1, divisor))
    }
}
