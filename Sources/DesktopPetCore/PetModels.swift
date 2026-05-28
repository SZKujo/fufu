import Foundation

public struct PetProfile: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var prompt: String

    public init(
        id: UUID = UUID(),
        name: String,
        prompt: String
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
    }
}

public enum ChatRole: String, Codable, Sendable {
    case user
    case pet
}

public struct ChatTurn: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var role: ChatRole
    public var text: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

public enum PetAction: String, CaseIterable, Codable, Sendable {
    case idle
    case dragRight
    case dragLeft
    case wake
    case hover
    case replyError
    case replyDone
    case thinking
    case replying
}
