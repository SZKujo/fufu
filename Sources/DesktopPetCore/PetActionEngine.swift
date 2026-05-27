import Foundation

public enum PetActionEvent: Sendable {
    case hoverBegan
    case hoverEnded
    case dragChanged(DragDirection)
    case dragEnded
    case wake
    case thinkingBegan
    case replyingBegan
    case replySucceeded
    case replyFailed
    case idleTick
}

public enum DragDirection: Sendable {
    case left
    case right
}

public struct PetActionEngine: Sendable {
    public private(set) var currentAction: PetAction = .idle
    private var isHovering = false
    private var isDragging = false
    private var isThinking = false
    private var isReplying = false
    private var dragDirection: DragDirection = .right

    public init() {}

    @discardableResult
    public mutating func handle(_ event: PetActionEvent) -> PetAction {
        switch event {
        case .hoverBegan:
            isHovering = true
        case .hoverEnded:
            isHovering = false
        case .dragChanged(let direction):
            isDragging = true
            dragDirection = direction
        case .dragEnded:
            isDragging = false
        case .wake:
            currentAction = .wake
            return currentAction
        case .thinkingBegan:
            isThinking = true
            isReplying = false
        case .replyingBegan:
            isThinking = false
            isReplying = true
        case .replySucceeded:
            isThinking = false
            isReplying = false
            currentAction = .replyDone
            return currentAction
        case .replyFailed:
            isThinking = false
            isReplying = false
            currentAction = .replyError
            return currentAction
        case .idleTick:
            break
        }

        currentAction = resolvedAction()
        return currentAction
    }

    private func resolvedAction() -> PetAction {
        if isDragging {
            return dragDirection == .right ? .dragRight : .dragLeft
        }
        if isReplying { return .replying }
        if isThinking { return .thinking }
        if isHovering { return .hover }
        return .idle
    }
}
