import AppKit
import SwiftUI

struct DesktopChatInputField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusToken: Int
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.submit)
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit

        if context.coordinator.focusToken != focusToken {
            context.coordinator.focusToken = focusToken
            DispatchQueue.main.async {
                DesktopTextInputFocusCoordinator.focus(nsView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onSubmit: () -> Void
        var focusToken = 0

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        @objc func submit() {
            text.wrappedValue = (NSApp.keyWindow?.firstResponder as? NSTextField)?.stringValue ?? text.wrappedValue
            onSubmit()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                text.wrappedValue = textView.string
                onSubmit()
                return true
            }
            return false
        }
    }
}

enum DesktopInputFocusRetryPolicy {
    static func shouldRetry(
        isApplicationActive: Bool,
        isWindowKey: Bool,
        didAcceptFirstResponder: Bool,
        allowsNonActiveApplication: Bool = false
    ) -> Bool {
        (!allowsNonActiveApplication && !isApplicationActive) || !isWindowKey || !didAcceptFirstResponder
    }
}

@MainActor
private enum DesktopTextInputFocusCoordinator {
    private static let retryDelays: [TimeInterval] = [0.05, 0.15, 0.3]

    static func focus(_ textField: NSTextField) {
        focus(textField, remainingDelays: retryDelays)
    }

    private static func focus(_ textField: NSTextField, remainingDelays: [TimeInterval]) {
        guard let window = textField.window else {
            scheduleNextFocus(for: textField, remainingDelays: remainingDelays)
            return
        }

        let allowsNonActiveApplication = window.styleMask.contains(.nonactivatingPanel)
        if !allowsNonActiveApplication {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }

        if let panel = window as? FloatingPetPanel {
            panel.allowsKeyInput = true
        }

        window.makeKeyAndOrderFront(nil)
        let didAcceptFirstResponder = window.makeFirstResponder(textField)

        if DesktopInputFocusRetryPolicy.shouldRetry(
            isApplicationActive: NSApp.isActive,
            isWindowKey: window.isKeyWindow,
            didAcceptFirstResponder: didAcceptFirstResponder,
            allowsNonActiveApplication: allowsNonActiveApplication
        ) {
            scheduleNextFocus(for: textField, remainingDelays: remainingDelays)
        }
    }

    private static func scheduleNextFocus(
        for textField: NSTextField,
        remainingDelays: [TimeInterval]
    ) {
        guard let delay = remainingDelays.first else { return }
        let nextDelays = Array(remainingDelays.dropFirst())
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            focus(textField, remainingDelays: nextDelays)
        }
    }
}
