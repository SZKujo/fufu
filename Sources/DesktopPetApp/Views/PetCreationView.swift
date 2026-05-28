import SwiftUI
import UniformTypeIdentifiers

struct PetCreationView: View {
    @EnvironmentObject private var runtime: AppRuntime
    @EnvironmentObject private var store: PetStore

    @State private var name = ""
    @State private var prompt = ""
    @State private var selectedAssetURL: URL?
    @State private var isImporterPresented = false
    @State private var errorMessage: String?

    private var isPromptTooLong: Bool {
        prompt.count > PetPromptText.maximumLength
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("创建宠物")
                    .font(.title2.weight(.semibold))
                Text("上传 Codex 风格 9 行 spritesheet，动作会按预设规则读取。")
                    .foregroundStyle(.secondary)
            }

            Form {
                TextField("名字", text: $name)
                VStack(alignment: .leading, spacing: 6) {
                    Text("设定")
                        .font(.callout.weight(.medium))
                    TextEditor(text: $prompt)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                    Text("\(prompt.count)/\(PetPromptText.maximumLength)")
                        .font(.caption)
                        .foregroundStyle(isPromptTooLong ? .red : .secondary)
                }

                Button {
                    isImporterPresented = true
                } label: {
                    Label(selectedAssetURL == nil ? "选择 Sprite 图" : "已选择 Sprite 图", systemImage: "photo.on.rectangle.angled")
                }

                Text(selectedAssetURL?.lastPathComponent ?? "未选择素材")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                AssetRequirementHintView()
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button {
                createPet()
            } label: {
                Label("创建宠物", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isPromptTooLong)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedAssetURL = urls.first
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func createPet() {
        do {
            guard !isPromptTooLong else {
                throw PetValidationError.promptTooLong
            }
            guard let selectedAssetURL else {
                errorMessage = "请选择 Sprite 图。"
                return
            }

            let needsAccess = selectedAssetURL.startAccessingSecurityScopedResource()
            defer {
                if needsAccess {
                    selectedAssetURL.stopAccessingSecurityScopedResource()
                }
            }

            try store.createPet(
                name: name,
                prompt: prompt,
                sourceURL: selectedAssetURL
            )
            name = ""
            prompt = ""
            self.selectedAssetURL = nil
            errorMessage = nil
            runtime.refreshFloatingPet()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AssetRequirementHintView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("素材建议", systemImage: "list.bullet.rectangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(spriteSheetText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(8)
        }
        .padding(.vertical, 4)
    }

    private var spriteSheetText: String {
        "WebP sprite 图按 9 行读取：1 待机，2 向右拖动，3 向左拖动，4 唤醒打招呼，5 鼠标悬停，6 回复出错，7 回复完成，8 思考中，9 回复中。每行可放多帧，透明背景效果最好。"
    }
}
