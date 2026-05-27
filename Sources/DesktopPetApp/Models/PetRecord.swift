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
        messages: [ChatRecord] = []
    ) {
        self.id = id
        self.name = name
        self.personality = personality
        self.catchphrase = catchphrase
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
        PetProfile(id: id, name: name, personality: personality, catchphrase: catchphrase)
    }

    var sortedMessages: [ChatRecord] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
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
        personality = try container.decode(String.self, forKey: .personality)
        catchphrase = try container.decode(String.self, forKey: .catchphrase)
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
            personality: entity.personality,
            catchphrase: entity.catchphrase,
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
