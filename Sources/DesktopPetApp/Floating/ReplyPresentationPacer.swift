import Foundation

enum ReplyPresentationPacer {
    static let minimumThinkingSeconds: TimeInterval = 0.6

    static func remainingThinkingDelay(startedAt: Date, now: Date = Date()) -> TimeInterval {
        max(0, minimumThinkingSeconds - now.timeIntervalSince(startedAt))
    }

    static func waitForMinimumThinkingIfNeeded(startedAt: Date) async {
        let seconds = remainingThinkingDelay(startedAt: startedAt)
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
