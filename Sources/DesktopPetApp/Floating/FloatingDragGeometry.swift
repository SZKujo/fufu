import AppKit
import DesktopPetCore

enum FloatingDragGeometry {
    static let directionThreshold: CGFloat = 1

    static func panelOrigin(
        startPanelOrigin: NSPoint,
        startMouseLocation: NSPoint,
        currentMouseLocation: NSPoint
    ) -> NSPoint {
        NSPoint(
            x: (startPanelOrigin.x + currentMouseLocation.x - startMouseLocation.x).rounded(),
            y: (startPanelOrigin.y + currentMouseLocation.y - startMouseLocation.y).rounded()
        )
    }

    static func direction(
        startMouseLocation: NSPoint,
        currentMouseLocation: NSPoint,
        threshold: CGFloat = directionThreshold
    ) -> DragDirection? {
        let deltaX = currentMouseLocation.x - startMouseLocation.x
        if deltaX > threshold {
            return .right
        }
        if deltaX < -threshold {
            return .left
        }
        return nil
    }
}
