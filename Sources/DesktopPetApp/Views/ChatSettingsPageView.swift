import DesktopPetCore
import SwiftUI

struct ChatSettingsPageView: View {
    @EnvironmentObject private var runtime: AppRuntime

    var body: some View {
        ChatSettingsForm(settings: runtime.chatSettings) {
            runtime.refreshFloatingPet()
        }
    }
}

private struct ChatSettingsForm: View {
    @ObservedObject var settings: ChatSettingsStore
    let refreshFloatingPet: () -> Void

    @State private var apiKey = ""
    @State private var statusMessage: String?
    @State private var isTesting = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case baseURL
        case model
        case apiKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("模型配置")
                    .font(.title2.weight(.semibold))
                Text("推荐使用 MiniMax Anthropic 兼容接口；OpenAI 兼容保留给其他同格式服务。")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                SettingRow(title: "回复模式") {
                    Picker("回复模式", selection: $settings.mode) {
                        ForEach(ChatProviderMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .onChange(of: settings.mode) {
                        refreshFloatingPet()
                    }
                }

                SettingRow(title: "Base URL") {
                    TextField(settings.mode.defaultBaseURL, text: $settings.baseURL)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .baseURL)
                        .disabled(settings.mode == .localMock)
                }

                SettingRow(title: "模型") {
                    TextField("MiniMax-M2.7", text: $settings.model)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .model)
                        .disabled(settings.mode == .localMock)
                }

                SettingRow(title: "API Key") {
                    SecureField(settings.hasAPIKey ? "已保存 API Key，输入新值可覆盖" : "API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .apiKey)
                        .disabled(settings.mode == .localMock)
                        .onTapGesture {
                            focusedField = .apiKey
                        }
                }

                HStack(spacing: 10) {
                    Button {
                        focusedField = nil
                        saveAPIKey()
                    } label: {
                        Label("保存 Key", systemImage: "key.fill")
                    }
                    .disabled(settings.mode == .localMock)

                    Button {
                        focusedField = nil
                        clearAPIKey()
                    } label: {
                        Label("清除 Key", systemImage: "xmark.circle")
                    }
                    .disabled(settings.mode == .localMock || !settings.hasAPIKey)

                    Button {
                        focusedField = nil
                        testConnection()
                    } label: {
                        Label(isTesting ? "测试中" : "测试连接", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .disabled(settings.mode == .localMock || isTesting)

                    Button {
                        focusedField = nil
                        refreshFloatingPet()
                        statusMessage = "配置已应用。"
                    } label: {
                        Label("应用配置", systemImage: "checkmark.circle")
                    }
                    .disabled(settings.mode == .localMock)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(statusMessage.hasPrefix("连接成功") || statusMessage.hasPrefix("已保存") || statusMessage.hasPrefix("配置已应用") ? .green : .red)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .padding(24)
    }

    private func saveAPIKey() {
        do {
            try settings.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            apiKey = ""
            statusMessage = "已保存 API Key。"
            refreshFloatingPet()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func clearAPIKey() {
        do {
            try settings.clearAPIKey()
            apiKey = ""
            statusMessage = "已清除 API Key。"
            refreshFloatingPet()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func testConnection() {
        isTesting = true
        statusMessage = nil
        let provider = settings.makeProvider()
        let pet = PetProfile(name: "Mainey", personality: "黏人、好奇", catchphrase: "喵呜")

        Task {
            do {
                var reply = ""
                for try await chunk in provider.replyStream(to: "你好，简单回复一下。", pet: pet, history: []) {
                    reply += chunk
                    if reply.count >= 8 {
                        break
                    }
                }
                await MainActor.run {
                    isTesting = false
                    statusMessage = reply.isEmpty ? "连接失败：没有收到回复。" : "连接成功：\(String(reply.prefix(20)))"
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    statusMessage = "连接失败：\(error.localizedDescription)"
                }
            }
        }
    }
}

private struct SettingRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 86, alignment: .trailing)

            content
                .frame(maxWidth: 520, alignment: .leading)

            Spacer()
        }
    }
}
