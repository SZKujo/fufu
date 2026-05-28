import DesktopPetCore
import Foundation
import SwiftData

enum PetAssetKind: String, CaseIterable, Identifiable, Codable {
    case spriteSheet
    case stillImage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spriteSheet:
            "Sprite 图"
        case .stillImage:
            "单张图片"
        }
    }
}

enum PetPromptText {
    static let maximumLength = 2_000

    static func legacyPrompt(name: String, personality: String, catchphrase: String) -> String {
        let personality = personality.trimmingCharacters(in: .whitespacesAndNewlines)
        let catchphrase = catchphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "这只桌面宠物" : name

        var parts = ["你是用户的桌面宠物 \(displayName)。"]
        if !personality.isEmpty {
            parts.append("性格与行为：\(personality)。")
        }
        if !catchphrase.isEmpty {
            parts.append("你可以自然地使用口头禅「\(catchphrase)」。")
        }
        parts.append("回复要温暖、简短、像陪伴型桌宠。")
        return parts.joined(separator: "\n")
    }
}

struct PetRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var personality: String
    var catchphrase: String
    var assetFileName: String
    var assetKind: PetAssetKind
    var spriteSpecID: String
    var isActive: Bool
    var windowX: Double
    var windowY: Double
    var scale: Double
    var isBundled: Bool = false
    var createdAt: Date
    var messages: [ChatRecord]

    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        assetFileName: String,
        assetKind: PetAssetKind,
        spriteSpecID: String = SpriteSheetSpec.codexMainey.id,
        isActive: Bool = false,
        windowX: Double = 1120,
        windowY: Double = 180,
        scale: Double = 1,
        isBundled: Bool = false,
        createdAt: Date = Date(),
        messages: [ChatRecord] = []
    ) {
        self.id = id
        self.name = name
        self.personality = prompt
        self.catchphrase = ""
        self.assetFileName = assetFileName
        self.assetKind = assetKind
        self.spriteSpecID = spriteSpecID
        self.isActive = isActive
        self.windowX = windowX
        self.windowY = windowY
        self.scale = scale
        self.isBundled = isBundled
        self.createdAt = createdAt
        self.messages = messages
    }

    var isProtectedDefault: Bool {
        isBundled || (name == "Mainey" && assetFileName == "mainey-spritesheet.webp" && spriteSpecID == SpriteSheetSpec.codexMainey.id)
    }

    var profile: PetProfile {
        PetProfile(id: id, name: name, prompt: prompt)
    }

    var prompt: String {
        get { personality }
        set { personality = newValue }
    }

    var sortedMessages: [ChatRecord] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case prompt
        case personality
        case catchphrase
        case assetFileName
        case assetKind
        case spriteSpecID
        case isActive
        case windowX
        case windowY
        case scale
        case isBundled
        case createdAt
        case messages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let prompt = try container.decodeIfPresent(String.self, forKey: .prompt) {
            personality = prompt
        } else {
            let legacyPersonality = try container.decodeIfPresent(String.self, forKey: .personality) ?? ""
            let legacyCatchphrase = try container.decodeIfPresent(String.self, forKey: .catchphrase) ?? ""
            personality = PetPromptText.legacyPrompt(
                name: name,
                personality: legacyPersonality,
                catchphrase: legacyCatchphrase
            )
        }
        catchphrase = ""
        assetFileName = try container.decode(String.self, forKey: .assetFileName)
        assetKind = try container.decode(PetAssetKind.self, forKey: .assetKind)
        spriteSpecID = try container.decode(String.self, forKey: .spriteSpecID)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        windowX = try container.decode(Double.self, forKey: .windowX)
        windowY = try container.decode(Double.self, forKey: .windowY)
        scale = try container.decode(Double.self, forKey: .scale)
        isBundled = try container.decodeIfPresent(Bool.self, forKey: .isBundled) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        messages = try container.decodeIfPresent([ChatRecord].self, forKey: .messages) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(assetFileName, forKey: .assetFileName)
        try container.encode(assetKind, forKey: .assetKind)
        try container.encode(spriteSpecID, forKey: .spriteSpecID)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(windowX, forKey: .windowX)
        try container.encode(windowY, forKey: .windowY)
        try container.encode(scale, forKey: .scale)
        try container.encode(isBundled, forKey: .isBundled)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(messages, forKey: .messages)
    }
}

struct ChatRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var role: ChatRole
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), role: ChatRole, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }

    var turn: ChatTurn {
        ChatTurn(id: id, role: role, text: text, createdAt: createdAt)
    }
}

@Model
final class PetEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var personality: String
    var catchphrase: String
    var assetFileName: String
    var assetKindRaw: String
    var spriteSpecID: String
    var isActive: Bool
    var windowX: Double
    var windowY: Double
    var scale: Double
    var isBundled: Bool = false
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ChatMessageEntity.pet) var messages: [ChatMessageEntity]

    init(
        id: UUID = UUID(),
        name: String,
        personality: String,
        catchphrase: String,
        assetFileName: String,
        assetKind: PetAssetKind,
        spriteSpecID: String = SpriteSheetSpec.codexMainey.id,
        isActive: Bool = false,
        windowX: Double = 1120,
        windowY: Double = 180,
        scale: Double = 1,
        isBundled: Bool = false,
        createdAt: Date = Date(),
        messages: [ChatMessageEntity] = []
    ) {
        self.id = id
        self.name = name
        self.personality = personality
        self.catchphrase = catchphrase
        self.assetFileName = assetFileName
        self.assetKindRaw = assetKind.rawValue
        self.spriteSpecID = spriteSpecID
        self.isActive = isActive
        self.windowX = windowX
        self.windowY = windowY
        self.scale = scale
        self.isBundled = isBundled
        self.createdAt = createdAt
        self.messages = messages
    }

    var assetKind: PetAssetKind {
        get { PetAssetKind(rawValue: assetKindRaw) ?? .spriteSheet }
        set { assetKindRaw = newValue.rawValue }
    }

    var prompt: String {
        get { personality }
        set {
            personality = newValue
            catchphrase = ""
        }
    }
}

@Model
final class ChatMessageEntity {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var text: String
    var createdAt: Date
    var pet: PetEntity?

    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        createdAt: Date = Date(),
        pet: PetEntity? = nil
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.text = text
        self.createdAt = createdAt
        self.pet = pet
    }

    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .pet }
        set { roleRaw = newValue.rawValue }
    }
}

extension PetRecord {
    init(entity: PetEntity) {
        self.init(
            id: entity.id,
            name: entity.name,
            prompt: entity.prompt,
            assetFileName: entity.assetFileName,
            assetKind: entity.assetKind,
            spriteSpecID: entity.spriteSpecID,
            isActive: entity.isActive,
            windowX: entity.windowX,
            windowY: entity.windowY,
            scale: entity.scale,
            isBundled: entity.isBundled,
            createdAt: entity.createdAt,
            messages: entity.messages
                .sorted { $0.createdAt < $1.createdAt }
                .map(ChatRecord.init(entity:))
        )
    }
}

extension ChatRecord {
    init(entity: ChatMessageEntity) {
        self.init(
            id: entity.id,
            role: entity.role,
            text: entity.text,
            createdAt: entity.createdAt
        )
    }
}
