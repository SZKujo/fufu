import AppKit
import SwiftUI

struct FloatingPetDragSurface: NSViewRepresentable {
    var onHover: (Bool) -> Void
    var onClick: () -> Void
    var onDragChanged: (NSPoint, NSPoint, NSPoint) -> Void
    var onDragEnded: () -> Void

    func makeNSView(context: Context) -> DragSurfaceView {
        let view = DragSurfaceView()
        view.onHover = onHover
        view.onClick = onClick
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ nsView: DragSurfaceView, context: Context) {
        nsView.onHover = onHover
        nsView.onClick = onClick
        nsView.onDragChanged = onDragChanged
        nsView.onDragEnded = onDragEnded
    }
}

final class DragSurfaceView: NSView {
    var onHover: (Bool) -> Void = { _ in }
    var onClick: () -> Void = {}
    var onDragChanged: (NSPoint, NSPoint, NSPoint) -> Void = { _, _, _ in }
    var onDragEnded: () -> Void = {}

    private var startPanelOrigin: NSPoint?
    private var startMouseLocation: NSPoint?
    private var hasDragged = false

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        onHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover(false)
    }

    override func mouseDown(with event: NSEvent) {
        startPanelOrigin = window?.frame.origin
        startMouseLocation = screenLocation(for: event)
        hasDragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPanelOrigin, let startMouseLocation else { return }
        let currentMouseLocation = screenLocation(for: event)

        if !hasDragged {
            let distance = hypot(
                currentMouseLocation.x - startMouseLocation.x,
                currentMouseLocation.y - startMouseLocation.y
            )
            hasDragged = distance > 2
        }

        guard hasDragged else { return }
        onDragChanged(startPanelOrigin, startMouseLocation, currentMouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        if hasDragged {
            onDragEnded()
        } else {
            onClick()
        }

        startPanelOrigin = nil
        startMouseLocation = nil
        hasDragged = false
    }

    private func screenLocation(for event: NSEvent) -> NSPoint {
        guard let window else {
            return NSEvent.mouseLocation
        }
        return window.convertPoint(toScreen: event.locationInWindow)
    }
}
