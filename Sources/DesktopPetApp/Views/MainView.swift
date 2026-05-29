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
    @State private var editingPet: PetRecord?

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
                            PetListRow(pet: pet) {
                                editingPet = pet
                            }
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
        .sheet(item: $editingPet) { pet in
            PetSettingsEditorView(
                pet: pet,
                store: store,
                onSave: {
                    runtime.refreshFloatingPet()
                    if selectedPetID == pet.id {
                        selectedPetID = pet.id
                    }
                }
            )
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
    let edit: () -> Void

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

            Button(action: edit) {
                Label("修改设定", systemImage: "pencil")
            }
            .help("修改名字和人设提示词")

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

private struct PetSettingsEditorView: View {
    let pet: PetRecord
    @ObservedObject var store: PetStore
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var prompt: String
    @State private var errorMessage: String?

    private var isPromptTooLong: Bool {
        prompt.count > PetPromptText.maximumLength
    }

    init(pet: PetRecord, store: PetStore, onSave: @escaping () -> Void) {
        self.pet = pet
        self.store = store
        self.onSave = onSave
        _name = State(initialValue: pet.name)
        _prompt = State(initialValue: pet.prompt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("修改设定")
                    .font(.title2.weight(.semibold))
                Text("只修改名字和人设提示词，素材保持不变。")
                    .foregroundStyle(.secondary)
            }

            Form {
                TextField("名字", text: $name)
                VStack(alignment: .leading, spacing: 6) {
                    Text("设定")
                        .font(.callout.weight(.medium))
                    TextEditor(text: $prompt)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Text("\(prompt.count)/\(PetPromptText.maximumLength)")
                            .foregroundStyle(isPromptTooLong ? .red : .secondary)
                        Spacer()
                        Text("素材：\(pet.assetFileName)")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.caption)
                }
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isPromptTooLong)
            }
        }
        .padding(22)
        .frame(width: 560)
        .frame(minHeight: 460)
    }

    private func save() {
        do {
            try store.updatePetSettings(pet.id, name: name, prompt: prompt)
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
