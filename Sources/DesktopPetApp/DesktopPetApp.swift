import AppKit
import SwiftUI

@main
struct DesktopPetApplication: App {
    @StateObject private var runtime = AppRuntime()
    @StateObject private var store = PetStore()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("桌面宠物", id: "main") {
            MainView()
                .environmentObject(runtime)
                .environmentObject(store)
                .task {
                    store.ensureSeedPetIfNeeded()
                    runtime.configure(store: store)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("桌宠", systemImage: "pawprint.fill") {
            MenuBarContentView()
                .environmentObject(runtime)
                .environmentObject(store)
                .task {
                    store.ensureSeedPetIfNeeded()
                    runtime.configure(store: store)
                }
        }
    }
}

private struct MenuBarContentView: View {
    @EnvironmentObject private var runtime: AppRuntime
    @EnvironmentObject private var store: PetStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开主界面") {
            openWindow(id: "main")
            runtime.activateMainWindow()
        }

        Button("显示当前宠物") {
            runtime.refreshFloatingPet()
        }

        Button("隐藏宠物") {
            runtime.floatingController.hide()
        }

        Button("取消展示当前宠物") {
            store.clearActivePet()
            runtime.refreshFloatingPet()
        }
        .disabled(store.activePet == nil)

        Divider()

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }
}
