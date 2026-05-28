import DesktopPetCore
import Foundation

struct OpenAICompatibleChatConfiguration: Sendable, Equatable {
    var baseURL: URL
    var apiKey: String
    var model: String

    init(baseURL: URL, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }
}

enum OpenAICompatibleChatError: LocalizedError {
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

struct OpenAICompatibleChatProvider: ChatProvider {
    let configuration: OpenAICompatibleChatConfiguration
    var session: URLSession = .shared
    private let apiKeyProvider: @Sendable () throws -> String

    init(
        configuration: OpenAICompatibleChatConfiguration,
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
                        throw OpenAICompatibleChatError.missingAPIKey
                    }

                    var configuration = configuration
                    configuration.apiKey = apiKey
                    let request = try OpenAICompatibleRequestBuilder.request(
                        input: input,
                        pet: pet,
                        history: history,
                        configuration: configuration
                    )
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw OpenAICompatibleChatError.invalidResponse
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        throw OpenAICompatibleChatError.httpStatus(httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                    }

                    var parser = OpenAICompatibleStreamParser()
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

enum OpenAICompatibleRequestBuilder {
    static func request(
        input: String,
        pet: PetProfile,
        history: [ChatTurn],
        configuration: OpenAICompatibleChatConfiguration
    ) throws -> URLRequest {
        var endpoint = configuration.baseURL
        if !endpoint.path.hasSuffix("/chat/completions") {
            endpoint.append(path: "chat/completions")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(OpenAICompatibleChatRequest(
            model: configuration.model,
            messages: messages(input: input, pet: pet, history: history),
            stream: true,
            reasoningSplit: true,
            temperature: 0.8,
            maxCompletionTokens: 160
        ))
        return request
    }

    private static func messages(input: String, pet: PetProfile, history: [ChatTurn]) -> [OpenAICompatibleMessage] {
        let persona = pet.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let setting = persona.isEmpty ? "保持温暖、简短、像陪伴型桌宠一样回应用户。" : persona
        let system = """
        你是用户的桌面宠物 \(pet.name)。
        人设设定：
        \(setting)
        用中文回复，桌面气泡最多展示 50 个字，所以优先控制在 50 个中文字以内。
        """
        var messages = [OpenAICompatibleMessage(role: "system", content: system)]
        messages += history.suffix(12).map { turn in
            OpenAICompatibleMessage(
                role: turn.role == .user ? "user" : "assistant",
                content: turn.text
            )
        }
        messages.append(OpenAICompatibleMessage(role: "user", content: input))
        return messages
    }
}

struct OpenAICompatibleStreamParser {
    private var contentBuffer = ""

    mutating func contentChunk(fromSSELine line: String) throws -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }

        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard payload != "[DONE]" else { return nil }
        guard let data = payload.data(using: .utf8) else {
            throw OpenAICompatibleChatError.invalidStreamData
        }

        let chunk = try JSONDecoder().decode(OpenAICompatibleStreamChunk.self, from: data)
        guard let content = chunk.choices.first?.delta.content, !content.isEmpty else {
            return nil
        }

        if content.hasPrefix(contentBuffer) {
            let start = content.index(content.startIndex, offsetBy: contentBuffer.count)
            let delta = String(content[start...])
            contentBuffer = content
            return delta.isEmpty ? nil : delta
        }

        contentBuffer += content
        return content
    }
}

private struct OpenAICompatibleChatRequest: Encodable {
    var model: String
    var messages: [OpenAICompatibleMessage]
    var stream: Bool
    var reasoningSplit: Bool
    var temperature: Double
    var maxCompletionTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case reasoningSplit = "reasoning_split"
        case temperature
        case maxCompletionTokens = "max_completion_tokens"
    }
}

private struct OpenAICompatibleMessage: Codable {
    var role: String
    var content: String
}

private struct OpenAICompatibleStreamChunk: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var delta: Delta
    }

    struct Delta: Decodable {
        var content: String?
    }
}
