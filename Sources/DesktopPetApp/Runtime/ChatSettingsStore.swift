import DesktopPetCore
import Foundation
import Security

enum ChatProviderMode: String, CaseIterable, Identifiable {
    case localMock
    case anthropicCompatible
    case openAICompatible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localMock:
            "本地假智能"
        case .anthropicCompatible:
            "MiniMax Anthropic（推荐）"
        case .openAICompatible:
            "OpenAI 兼容"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .localMock, .anthropicCompatible:
            AnthropicCompatibleRequestBuilder.defaultBaseURL.absoluteString
        case .openAICompatible:
            "https://api.minimax.io/v1"
        }
    }

    var defaultModel: String { "MiniMax-M2.7" }
}

@MainActor
final class ChatSettingsStore: ObservableObject {
    @Published var mode: ChatProviderMode {
        didSet {
            applyProviderDefaultsAfterModeChange(from: oldValue)
            save()
        }
    }
    @Published var baseURL: String {
        didSet { save() }
    }
    @Published var model: String {
        didSet { save() }
    }
    @Published private(set) var hasAPIKey: Bool

    private let defaults: UserDefaults
    private let apiKeyCache: APIKeyCache
    static let hasAPIKeyDefaultsKey = "chat.hasAPIKey.com.kujo.DesktopPet"

    init(
        defaults: UserDefaults = .standard,
        keychain: APIKeychain = .live
    ) {
        self.defaults = defaults
        apiKeyCache = APIKeyCache(keychain: keychain)
        let storedMode = ChatProviderMode(rawValue: defaults.string(forKey: "chat.mode") ?? "") ?? .localMock
        mode = storedMode
        baseURL = defaults.string(forKey: "chat.baseURL") ?? storedMode.defaultBaseURL
        model = defaults.string(forKey: "chat.model") ?? storedMode.defaultModel
        hasAPIKey = defaults.bool(forKey: Self.hasAPIKeyDefaultsKey)
    }

    func makeProvider() -> any ChatProvider {
        let cachedAPIKeyProvider: @Sendable () throws -> String = { [apiKeyCache] in
            try apiKeyCache.readAPIKey()
        }
        switch mode {
        case .localMock:
            return LocalMockChatProvider()
        case .anthropicCompatible:
            return AnthropicCompatibleChatProvider(configuration: AnthropicCompatibleChatConfiguration(
                baseURL: URL(string: baseURL) ?? AnthropicCompatibleRequestBuilder.defaultBaseURL,
                apiKey: "",
                model: normalizedModel
            ), apiKeyProvider: cachedAPIKeyProvider)
        case .openAICompatible:
            return OpenAICompatibleChatProvider(configuration: OpenAICompatibleChatConfiguration(
                baseURL: URL(string: baseURL) ?? URL(string: "https://api.minimax.io/v1")!,
                apiKey: "",
                model: normalizedModel
            ), apiKeyProvider: cachedAPIKeyProvider)
        }
    }

    func saveAPIKey(_ apiKey: String) throws {
        try apiKeyCache.saveAPIKey(apiKey)
        hasAPIKey = !apiKey.isEmpty
        defaults.set(hasAPIKey, forKey: Self.hasAPIKeyDefaultsKey)
    }

    func clearAPIKey() throws {
        try apiKeyCache.clearAPIKey()
        hasAPIKey = false
        defaults.set(false, forKey: Self.hasAPIKeyDefaultsKey)
        defaults.set(false, forKey: "chat.hasAPIKey.keychain")
        defaults.set(false, forKey: "chat.hasAPIKey")
    }

    private func save() {
        defaults.set(mode.rawValue, forKey: "chat.mode")
        defaults.set(baseURL, forKey: "chat.baseURL")
        defaults.set(model, forKey: "chat.model")
    }

    private var normalizedModel: String {
        let value = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? mode.defaultModel : value
    }

    private func applyProviderDefaultsAfterModeChange(from oldMode: ChatProviderMode) {
        guard mode != .localMock else { return }
        let currentBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentBaseURL.isEmpty || currentBaseURL == oldMode.defaultBaseURL {
            baseURL = mode.defaultBaseURL
        }

        let currentModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentModel.isEmpty || currentModel == oldMode.defaultModel {
            model = mode.defaultModel
        }
    }

}

final class APIKeyCache: @unchecked Sendable {
    private let keychain: APIKeychain
    private let lock = NSLock()
    private var cachedAPIKey: String?

    init(keychain: APIKeychain) {
        self.keychain = keychain
    }

    func readAPIKey() throws -> String {
        try lock.withLock {
            if let cachedAPIKey {
                return cachedAPIKey
            }
            let apiKey = try keychain.readAPIKey()
            cachedAPIKey = apiKey
            return apiKey
        }
    }

    func saveAPIKey(_ apiKey: String) throws {
        try keychain.saveAPIKey(apiKey)
        lock.withLock {
            cachedAPIKey = apiKey
        }
    }

    func clearAPIKey() throws {
        try keychain.deleteAPIKey()
        lock.withLock {
            cachedAPIKey = ""
        }
    }
}

struct APIKeychain: Sendable {
    var readAPIKey: @Sendable () throws -> String
    var saveAPIKey: @Sendable (String) throws -> Void
    var deleteAPIKey: @Sendable () throws -> Void

    static let live = APIKeychain(
        readAPIKey: {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status != errSecItemNotFound else { return "" }
            guard status != errSecUserCanceled else {
                throw KeychainError.userCanceled
            }
            guard status == errSecSuccess, let data = result as? Data else {
                throw KeychainError.unhandled(status)
            }
            return String(decoding: data, as: UTF8.self)
        },
        saveAPIKey: { value in
            guard !value.isEmpty else {
                try deleteStoredAPIKey(service: service)
                return
            }
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: Data(value.utf8)
            ]
            let status = SecItemAdd(query as CFDictionary, nil)
            switch status {
            case errSecSuccess:
                return
            case errSecDuplicateItem:
                try updateStoredAPIKey(value, service: service)
            case errSecUserCanceled:
                throw KeychainError.userCanceled
            default:
                throw KeychainError.unhandled(status)
            }
        },
        deleteAPIKey: {
            try deleteStoredAPIKey(service: service)
            try? deleteStoredAPIKey(service: legacyService)
        }
    )

    static let service = "com.kujo.DesktopPet.ChatProvider"
    static let legacyService = "DesktopPet.ChatProvider"
    static let account = "OpenAICompatibleAPIKey"

    private static func updateStoredAPIKey(_ value: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8)
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecUserCanceled:
            throw KeychainError.userCanceled
        default:
            throw KeychainError.unhandled(status)
        }
    }

    private static func deleteStoredAPIKey(service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    enum KeychainError: LocalizedError {
        case userCanceled
        case unhandled(OSStatus)

        var errorDescription: String? {
            switch self {
            case .userCanceled:
                "钥匙串访问被拒绝。需要允许桌面宠物读取 API Key，或重新保存 Key。"
            case .unhandled(let status):
                if status == OSStatus(-25244) {
                    "钥匙串操作失败：\(status)。这通常是旧版本或调试版留下的钥匙串项目和当前 App 签名冲突，请用新版 App 重新保存 Key。"
                } else {
                    "钥匙串操作失败：\(status)"
                }
            }
        }
    }
}
