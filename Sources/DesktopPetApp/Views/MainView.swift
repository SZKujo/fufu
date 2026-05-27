import DesktopPetCore
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var runtime: AppRuntime
    @EnvironmentObject private var store: PetStore
    @State private var selectedTab = "pets"

    var body: some View {
        TabView(selection: $selectedTab) {
            PetsPageView()
                .tabItem {
                    Label("宠物", systemImage: "pawprint.fill")
                }
                .tag("pets")

            ChatPageView()
                .tabItem {
                    Label("聊天", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag("chat")

            ChatSettingsPageView()
                .tabItem {
                    Label("配置", systemImage: "slider.horizontal.3")
                }
                .tag("settings")
        }
        .frame(minWidth: 1080, minHeight: 620)
        .task {
            runtime.refreshFloatingPet()
        }
    }
}

private struct PetsPageView: View {
    @EnvironmentObject private var runtime: AppRuntime
    @EnvironmentObject private var store: PetStore
    @State private var selectedPetID: UUID?
    @State private var isAssetPreviewExpanded = false

    private var selectedPet: PetRecord? {
        if let selectedPetID, let pet = store.pet(with: selectedPetID) {
            return pet
        }
        return store.activePet ?? store.pets.first
    }

    var body: some View {
        HStack(spacing: 0) {
            PetCreationView()
                .frame(width: 330)
                .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("宠物列表")
                            .font(.title2.weight(.semibold))
                        Text("选择一只宠物展示在桌面上。")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        store.clearActivePet()
                        runtime.refreshFloatingPet()
                    } label: {
                        Label("取消展示", systemImage: "eye.slash")
                    }
                    .disabled(store.activePet == nil)

                    Button {
                        runtime.refreshFloatingPet()
                    } label: {
                        Label("刷新桌宠", systemImage: "arrow.clockwise")
                    }
                }

                if store.pets.isEmpty {
                    ContentUnavailableView("还没有宠物", systemImage: "pawprint", description: Text("从左侧创建一只宠物后，它会出现在这里。"))
                } else {
                    List {
                        ForEach(store.pets) { pet in
                            PetListRow(pet: pet)
                                .deleteDisabled(pet.isProtectedDefault)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPetID = pet.id
                                }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                store.delete(store.pets[index].id)
                            }
                            runtime.refreshFloatingPet()
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .padding(20)

            Divider()

            if isAssetPreviewExpanded {
                PetAssetPreviewPanel(
                    pet: selectedPet,
                    isExpanded: $isAssetPreviewExpanded
                )
                .frame(width: 260)
            } else {
                CollapsedAssetPreviewButton {
                    isAssetPreviewExpanded = true
                }
            }
        }
    }
}

private struct CollapsedAssetPreviewButton: View {
    let expand: () -> Void

    var body: some View {
        Button(action: expand) {
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                Text("素材")
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxHeight: .infinity)
            .frame(width: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("展开素材预览")
    }
}

private struct PetListRow: View {
    @EnvironmentObject private var runtime: AppRuntime
    @EnvironmentObject private var store: PetStore
    let pet: PetRecord

    var body: some View {
        HStack(spacing: 14) {
            PetAvatarView(pet: pet, action: .idle, animationMode: .staticFrame)
                .frame(width: 64, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pet.name)
                        .font(.headline)
                    if pet.isActive {
                        Text("展示中")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.green.opacity(0.16), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
                Text(pet.personality)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("口头禅：\(pet.catchphrase)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if pet.isActive {
                Button {
                    store.clearActivePet()
                    runtime.refreshFloatingPet()
                } label: {
                    Label("取消展示", systemImage: "eye.slash")
                }
            } else {
                Button {
                    store.setActive(pet.id)
                    runtime.refreshFloatingPet()
                } label: {
                    Label("展示", systemImage: "display")
                }
            }

            Button {
                store.delete(pet.id)
                runtime.refreshFloatingPet()
            } label: {
                Label("移除", systemImage: "trash")
            }
            .disabled(pet.isProtectedDefault)
            .help(pet.isProtectedDefault ? "默认桌宠不可删除" : "移除这只宠物")
        }
        .padding(.vertical, 8)
    }
}
