import Foundation

public protocol ChatProvider: Sendable {
    func reply(to input: String, pet: PetProfile, history: [ChatTurn]) async -> String
    func replyStream(to input: String, pet: PetProfile, history: [ChatTurn]) -> AsyncThrowingStream<String, Error>
}

public struct LocalMockChatProvider: ChatProvider {
    public init() {}

    public func replyStream(to input: String, pet: PetProfile, history: [ChatTurn]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let reply = await reply(to: input, pet: pet, history: history)
                for chunk in reply.chunkedForStreaming(maxCharacters: 4) {
                    continuation.yield(chunk)
                    try? await Task.sleep(nanoseconds: 80_000_000)
                }
                continuation.finish(throwing: nil)
            }
        }
    }

    public func reply(to input: String, pet: PetProfile, history: [ChatTurn]) async -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return "\(pet.name)歪头看着你：我在。"
        }

        let lowercased = text.lowercased()
        let reply: String
        if text.contains("累") || text.contains("烦") || text.contains("难") {
            reply = "\(pet.name)蹭蹭你：先喘口气，我陪你拆小一点。"
        } else if text.contains("你好") || lowercased.contains("hello") || lowercased.contains("hi") {
            reply = "\(pet.name)摇摇尾巴：今天也一起待会儿。"
        } else if text.contains("代码") || lowercased.contains("code") {
            reply = "\(pet.name)眨眨眼：代码慢慢写，我负责看住你的耐心。"
        } else if text.contains("吃") || text.contains("饿") {
            reply = "\(pet.name)认真点头：先补能量，脑袋才会亮起来。"
        } else if history.count > 6 {
            reply = "\(pet.name)贴过来：我们聊了好久，但我还在认真听。"
        } else {
            reply = fallbackReply(for: pet, seed: text.count + history.count)
        }

        return String(reply.prefix(50))
    }

    private func fallbackReply(for pet: PetProfile, seed: Int) -> String {
        let options = [
            "\(pet.name)歪头：这听起来有点意思。",
            "\(pet.name)趴在旁边：我记住啦，继续说给我听。",
            "\(pet.name)轻轻点头：嗯嗯，我站你这边。",
            "\(pet.name)甩甩尾巴：那我们先做最小的一步。",
            "\(pet.name)眨眼：设定模式启动。"
        ]
        return options[abs(seed) % options.count]
    }
}

private extension String {
    func chunkedForStreaming(maxCharacters: Int) -> [String] {
        guard !isEmpty else { return [] }
        var chunks: [String] = []
        var current = ""

        for character in self {
            current.append(character)
            if current.count >= maxCharacters || "，。：！？,.!?".contains(character) {
                chunks.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }
}
