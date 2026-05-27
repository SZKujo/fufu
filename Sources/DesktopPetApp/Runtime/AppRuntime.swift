import AppKit
import DesktopPetCore
import Foundation

@MainActor
final class AppRuntime: ObservableObject {
    let chatSettings = ChatSettingsStore()
    let floatingController = FloatingPetController()

    private var didConfigure = false
    private weak var store: PetStore?

    func configure(store: PetStore) {
        guard !didConfigure else { return }
        didConfigure = true
        self.store = store
        refreshFloatingPet()
    }

    func refreshFloatingPet() {
        guard let store else { return }
        if let pet = store.activePet {
            floatingController.show(pet: pet, store: store, chatProvider: makeChatProvider())
        } else {
            floatingController.hide()
        }
    }

    func makeChatProvider() -> any ChatProvider {
        chatSettings.makeProvider()
    }

    func activateMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
