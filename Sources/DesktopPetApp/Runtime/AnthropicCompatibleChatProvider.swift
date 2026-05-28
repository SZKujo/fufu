import DesktopPetCore
import Foundation

struct AnthropicCompatibleChatConfiguration: Sendable, Equatable {
    var baseURL: URL
    var apiKey: String
    var model: String

    init(baseURL: URL, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }
}

enum AnthropicCompatibleChatError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpStatus(Int, String)
    case invalidStreamData

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "还没有配置 API Key。"
        case .invalidResponse:
            "接口没有返回有效响应。"
        case .httpStatus(let status, let message):
            "接口返回 \(status)：\(message)"
        case .invalidStreamData:
            "流式回复解析失败。"
        }
    }
}

struct AnthropicCompatibleChatProvider: ChatProvider {
    let configuration: AnthropicCompatibleChatConfiguration
    var session: URLSession = .shared
    private let apiKeyProvider: @Sendable () throws -> String

    init(
        configuration: AnthropicCompatibleChatConfiguration,
        session: URLSession = .shared,
        apiKeyProvider: (@Sendable () throws -> String)? = nil
    ) {
        self.configuration = configuration
        self.session = session
        self.apiKeyProvider = apiKeyProvider ?? { configuration.apiKey }
    }

    func reply(to input: String, pet: PetProfile, history: [ChatTurn]) async -> String {
        var reply = ""
        do {
            for try await chunk in replyStream(to: input, pet: pet, history: history) {
                reply += chunk
            }
            return reply
        } catch {
            return ""
        }
    }

    func replyStream(to input: String, pet: PetProfile, history: [ChatTurn]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = try apiKeyProvider().trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !apiKey.isEmpty else {
                        throw AnthropicCompatibleChatError.missingAPIKey
                    }

                    var configuration = configuration
                    configuration.apiKey = apiKey
                    let request = try AnthropicCompatibleRequestBuilder.request(
                        input: input,
                        pet: pet,
                        history: history,
                        configuration: configuration
                    )
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AnthropicCompatibleChatError.invalidResponse
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        throw AnthropicCompatibleChatError.httpStatus(
                            httpResponse.statusCode,
                            HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                        )
                    }

                    let parser = AnthropicCompatibleStreamParser()
                    for try await line in bytes.lines {
                        if let chunk = try parser.contentChunk(fromSSELine: line) {
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish(throwing: nil)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

enum AnthropicCompatibleRequestBuilder {
    static let defaultBaseURL = URL(string: "https://api.minimaxi.com/anthropic")!
    static let anthropicVersion = "2023-06-01"

    static func request(
        input: String,
        pet: PetProfile,
        history: [ChatTurn],
        configuration: AnthropicCompatibleChatConfiguration
    ) throws -> URLRequest {
        var request = URLRequest(url: endpoint(from: configuration.baseURL))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "Anthropic-Version")
        request.httpBody = try JSONEncoder().encode(AnthropicCompatibleChatRequest(
            model: configuration.model,
            maxTokens: 160,
            stream: true,
            temperature: 0.8,
            system: systemPrompt(for: pet),
            messages: messages(input: input, history: history)
        ))
        return request
    }

    private static func endpoint(from baseURL: URL) -> URL {
        var endpoint = baseURL
        if endpoint.path.hasSuffix("/v1/messages") {
            return endpoint
        }
        if endpoint.path.hasSuffix("/v1") {
            endpoint.append(path: "messages")
            return endpoint
        }
        endpoint.append(path: "v1/messages")
        return endpoint
    }

    private static func systemPrompt(for pet: PetProfile) -> String {
        let persona = pet.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let setting = persona.isEmpty ? "保持温暖、简短、像陪伴型桌宠一样回应用户。" : persona
        return """
        你是用户的桌面宠物 \(pet.name)。
        人设设定：
        \(setting)
        用中文回复，桌面气泡最多展示 50 个字，所以优先控制在 50 个中文字以内。
        """
    }

    private static func messages(input: String, history: [ChatTurn]) -> [AnthropicCompatibleMessage] {
        var messages = history.suffix(12).map { turn in
            AnthropicCompatibleMessage(
                role: turn.role == .user ? "user" : "assistant",
                content: turn.text
            )
        }
        messages.append(AnthropicCompatibleMessage(role: "user", content: input))
        return messages
    }
}

struct AnthropicCompatibleStreamParser {
    func contentChunk(fromSSELine line: String) throws -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }

        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard payload != "[DONE]" else { return nil }
        guard let data = payload.data(using: .utf8) else {
            throw AnthropicCompatibleChatError.invalidStreamData
        }

        let chunk = try JSONDecoder().decode(AnthropicCompatibleStreamChunk.self, from: data)
        guard chunk.type == "content_block_delta",
              chunk.delta?.type == "text_delta",
              let text = chunk.delta?.text,
              !text.isEmpty else {
            return nil
        }
        return text
    }
}

private struct AnthropicCompatibleChatRequest: Encodable {
    var model: String
    var maxTokens: Int
    var stream: Bool
    var temperature: Double
    var system: String
    var messages: [AnthropicCompatibleMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case stream
        case temperature
        case system
        case messages
    }
}

private struct AnthropicCompatibleMessage: Codable {
    var role: String
    var content: String
}

private struct AnthropicCompatibleStreamChunk: Decodable {
    var type: String
    var delta: Delta?

    struct Delta: Decodable {
        var type: String?
        var text: String?
    }
}
