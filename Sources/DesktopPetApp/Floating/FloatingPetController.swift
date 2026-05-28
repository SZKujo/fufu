import AppKit
import DesktopPetCore
import QuartzCore
import SwiftUI

@MainActor
final class FloatingPetController: ObservableObject {
    @Published var action: PetAction = .idle
    @Published var isBubbleOpen = false
    @Published var latestReply = ""

    private var panel: FloatingPetPanel?
    private var actionEngine = PetActionEngine()

    func show(pet: PetRecord, store: PetStore, chatProvider: any ChatProvider) {
        isBubbleOpen = false
        let size = PetDisplayMetrics.panelSize(for: pet, showsBubble: false)
        let origin = FloatingPetWindowPlacement.visibleOrigin(
            preferredOrigin: CGPoint(x: pet.windowX, y: pet.windowY),
            size: size,
            visibleFrames: NSScreen.screens.map(\.visibleFrame)
        )
        let frame = NSRect(
            x: origin.x,
            y: origin.y,
            width: size.width,
            height: size.height
        )

        let panel = panel ?? FloatingPetPanel(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel = panel

        panel.configureForDesktopPet()
        panel.allowsKeyInput = false
        panel.setFrame(frame, display: true)
        preloadFrames(for: pet)
        let hostingView = NSHostingView(
            rootView: FloatingPetHostView(
                pet: pet,
                store: store,
                chatProvider: chatProvider,
                controller: self
            )
        )
        hostingView.wantsLayer = true
        hostingView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        hostingView.layer?.magnificationFilter = .nearest
        hostingView.layer?.minificationFilter = .nearest
        hostingView.layer?.isOpaque = false
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.bringDesktopPetToFront()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func handle(_ event: PetActionEvent) {
        let nextAction = actionEngine.handle(event)
        guard nextAction != action else { return }
        action = nextAction
    }

    func reactToClick() {
        handle(.wake)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.handle(.idleTick)
        }
    }

    func openBubbleForTyping(for pet: PetRecord) {
        isBubbleOpen = true
        resizePanel(for: pet, showsBubble: true)
        focusForTyping()
    }

    func closeBubble(for pet: PetRecord) {
        isBubbleOpen = false
        resizePanel(for: pet, showsBubble: false)
        panel?.allowsKeyInput = false
    }

    func focusForTyping() {
        panel?.allowsKeyInput = true
        panel?.makeKeyAndOrderFront(nil)
    }

    func movePanel(start: NSPoint, translation: CGSize) {
        guard let panel else { return }
        if translation.width > 1 {
            handle(.dragChanged(.right))
        } else if translation.width < -1 {
            handle(.dragChanged(.left))
        }
        let next = NSPoint(
            x: (start.x + translation.width).rounded(),
            y: (start.y - translation.height).rounded()
        )
        guard panel.frame.origin != next else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrameOrigin(next)
        CATransaction.commit()
        panel.bringDesktopPetToFront()
    }

    func movePanel(
        startPanelOrigin: NSPoint,
        startMouseLocation: NSPoint,
        currentMouseLocation: NSPoint
    ) {
        guard let panel else { return }
        if let direction = FloatingDragGeometry.direction(
            startMouseLocation: startMouseLocation,
            currentMouseLocation: currentMouseLocation
        ) {
            handle(.dragChanged(direction))
        }

        let next = FloatingDragGeometry.panelOrigin(
            startPanelOrigin: startPanelOrigin,
            startMouseLocation: startMouseLocation,
            currentMouseLocation: currentMouseLocation
        )
        guard panel.frame.origin != next else { return }
        panel.setFrameOrigin(next)
        panel.bringDesktopPetToFront()
    }

    func currentOrigin() -> NSPoint {
        panel?.frame.origin ?? .zero
    }

    func persistPosition(for pet: PetRecord, in store: PetStore) {
        guard let panel else { return }
        let closedSize = PetDisplayMetrics.panelSize(for: pet, showsBubble: false)
        let storedX = panel.frame.maxX - closedSize.width
        store.updatePosition(for: pet.id, x: storedX.rounded(), y: panel.frame.minY.rounded())
    }

    private func resizePanel(for pet: PetRecord, showsBubble: Bool) {
        guard let panel else { return }
        let size = PetDisplayMetrics.panelSize(for: pet, showsBubble: showsBubble)
        let frame = panel.frame
        let nextFrame = NSRect(
            x: frame.maxX - size.width,
            y: frame.minY,
            width: size.width,
            height: size.height
        )
        let origin = FloatingPetWindowPlacement.visibleOrigin(
            preferredOrigin: nextFrame.origin,
            size: nextFrame.size,
            visibleFrames: NSScreen.screens.map(\.visibleFrame)
        )
        panel.setFrame(NSRect(origin: origin, size: nextFrame.size), display: true, animate: false)
        panel.bringDesktopPetToFront()
    }

    private func preloadFrames(for pet: PetRecord) {
        guard
            pet.assetKind == .spriteSheet,
            let assetURL = try? PetAssetManager.assetURL(for: pet.assetFileName)
        else {
            return
        }
        SpriteFrameRenderer.shared.preloadFrames(for: assetURL)
    }
}

final class FloatingPetPanel: NSPanel {
    var allowsKeyInput = false

    override var canBecomeKey: Bool { allowsKeyInput }
    override var canBecomeMain: Bool { allowsKeyInput }

    func configureForDesktopPet() {
        styleMask.insert(.nonactivatingPanel)
        allowsKeyInput = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none
        hidesOnDeactivate = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
    }

    func bringDesktopPetToFront() {
        level = .screenSaver
        orderFrontRegardless()
    }
}
