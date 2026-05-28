import DesktopPetCore
import Foundation
import SwiftData

@MainActor
final class PetStore: ObservableObject {
    @Published private(set) var pets: [PetRecord] = []
    @Published private(set) var lastError: String?

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let legacyJSONURL: URL?

    convenience init() {
        do {
            let schema = Schema([PetEntity.self, ChatMessageEntity.self])
            let container = try ModelContainer(for: schema)
            self.init(modelContainer: container, legacyJSONURL: Self.defaultLegacyJSONURL())
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    init(modelContainer: ModelContainer, legacyJSONURL: URL?) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        self.legacyJSONURL = legacyJSONURL
        migrateLegacyJSONIfNeeded()
        normalizeLegacySettingsIfNeeded()
        reload()
    }

    var activePet: PetRecord? {
        pets.first(where: \.isActive)
    }

    func ensureSeedPetIfNeeded() {
        guard pets.isEmpty else { return }

        do {
            let assetFileName = try PetAssetManager.installBundledMaineyIfNeeded()
            let pet = PetEntity(
                name: "Mainey",
                personality: Self.defaultMaineyPrompt,
                catchphrase: "",
                assetFileName: assetFileName,
                assetKind: .spriteSheet,
                isActive: true,
                isBundled: true
            )
            appendMessageEntity(.pet, text: "Mainey跳到桌面上：喵呜，我已经就位啦。", to: pet)
            modelContext.insert(pet)
            try saveAndReload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func createPet(
        name: String,
        prompt: String,
        sourceURL: URL?
    ) throws -> PetRecord {
        let assetFileName: String
        if let sourceURL {
            assetFileName = try PetAssetManager.copyAsset(from: sourceURL)
        } else {
            assetFileName = try PetAssetManager.installBundledMaineyIfNeeded()
        }

        let pet = PetEntity(
            name: cleaned(name, fallback: "新宠物"),
            personality: try cleanedPrompt(prompt),
            catchphrase: "",
            assetFileName: assetFileName,
            assetKind: .spriteSheet,
            isActive: pets.isEmpty
        )
        appendMessageEntity(.pet, text: "\(pet.name)探出头：以后请多关照。", to: pet)
        modelContext.insert(pet)
        try saveAndReload()
        return PetRecord(entity: pet)
    }

    func updatePetSettings(_ petID: UUID, name: String, prompt: String) throws {
        guard let pet = try fetchPetEntity(id: petID) else { return }
        pet.name = cleaned(name, fallback: "新宠物")
        pet.prompt = try cleanedPrompt(prompt)
        try saveAndReload()
    }

    func setActive(_ petID: UUID) {
        do {
            for pet in try fetchPetEntities() {
                pet.isActive = pet.id == petID
            }
            try saveAndReload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearActivePet() {
        do {
            for pet in try fetchPetEntities() {
                pet.isActive = false
            }
            try saveAndReload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func delete(_ petID: UUID) -> Bool {
        do {
            let entities = try fetchPetEntities()
            guard let pet = entities.first(where: { $0.id == petID }) else { return false }
            guard !pet.isProtectedDefault else { return false }
            modelContext.delete(pet)
            try saveAndReload()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func updatePosition(for petID: UUID, x: Double, y: Double) {
        do {
            guard let pet = try fetchPetEntity(id: petID) else { return }
            pet.windowX = x
            pet.windowY = y
            try saveAndReload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func appendMessage(_ role: ChatRole, text: String, to petID: UUID) -> ChatRecord? {
        do {
            guard let pet = try fetchPetEntity(id: petID) else { return nil }
            let message = appendMessageEntity(role, text: text, to: pet)
            try saveAndReload()
            return ChatRecord(entity: message)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func pet(with id: UUID) -> PetRecord? {
        pets.first { $0.id == id }
    }

    private func reload() {
        do {
            pets = try fetchPetEntities().map(PetRecord.init(entity:))
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            pets = []
        }
    }

    private func saveAndReload() throws {
        try modelContext.save()
        reload()
    }

    private func fetchPetEntities() throws -> [PetEntity] {
        let descriptor = FetchDescriptor<PetEntity>(sortBy: [SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor)
    }

    private func fetchPetEntity(id: UUID) throws -> PetEntity? {
        let descriptor = FetchDescriptor<PetEntity>(
            predicate: #Predicate { $0.id == id },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    private func appendMessageEntity(_ role: ChatRole, text: String, to pet: PetEntity) -> ChatMessageEntity {
        let message = ChatMessageEntity(role: role, text: text, pet: pet)
        modelContext.insert(message)
        pet.messages.append(message)
        return message
    }

    private func migrateLegacyJSONIfNeeded() {
        do {
            guard let legacyJSONURL else { return }
            guard FileManager.default.fileExists(atPath: legacyJSONURL.path) else { return }
            guard try fetchPetEntities().isEmpty else { return }

            let data = try Data(contentsOf: legacyJSONURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacyPets = try decoder.decode([PetRecord].self, from: data)

            for legacyPet in legacyPets {
                let pet = PetEntity(record: legacyPet)
                modelContext.insert(pet)
                for legacyMessage in legacyPet.messages {
                    appendMessageEntity(legacyMessage.role, text: legacyMessage.text, to: pet).createdAt = legacyMessage.createdAt
                }
            }
            try modelContext.save()

            let migratedURL = legacyJSONURL.appendingPathExtension("migrated")
            if FileManager.default.fileExists(atPath: migratedURL.path) {
                try FileManager.default.removeItem(at: migratedURL)
            }
            try FileManager.default.moveItem(at: legacyJSONURL, to: migratedURL)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func normalizeLegacySettingsIfNeeded() {
        do {
            var didChange = false
            for pet in try fetchPetEntities() where !pet.catchphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pet.prompt = PetPromptText.legacyPrompt(
                    name: pet.name,
                    personality: pet.personality,
                    catchphrase: pet.catchphrase
                )
                didChange = true
            }
            if didChange {
                try modelContext.save()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func cleaned(_ value: String, fallback: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? fallback : text
    }

    private func cleanedPrompt(_ value: String) throws -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count <= PetPromptText.maximumLength else {
            throw PetValidationError.promptTooLong
        }
        return text
    }

    private static func defaultLegacyJSONURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appending(path: "DesktopPet/pets.json", directoryHint: .notDirectory)
    }

    private static let defaultMaineyPrompt = """
    你是 Mainey，一只像 Codex 桌宠一样陪在用户屏幕上的小猫。
    你黏人、好奇、会在用户写代码或工作时安静陪伴。
    回复要温暖、简短、有一点猫咪感，但不要过度卖萌。
    当用户焦虑或卡住时，帮用户把事情拆小一点，像可靠的小伙伴一样鼓励 TA。
    """
}

enum PetValidationError: LocalizedError {
    case promptTooLong

    var errorDescription: String? {
        switch self {
        case .promptTooLong:
            "设定最多 2000 字。"
        }
    }
}

private extension PetEntity {
    convenience init(record: PetRecord) {
        self.init(
            id: record.id,
            name: record.name,
            personality: record.prompt,
            catchphrase: "",
            assetFileName: record.assetFileName,
            assetKind: record.assetKind,
            spriteSpecID: record.spriteSpecID,
            isActive: record.isActive,
            windowX: record.windowX,
            windowY: record.windowY,
            scale: record.scale,
            isBundled: record.isBundled,
            createdAt: record.createdAt
        )
    }
}

private extension PetEntity {
    var isProtectedDefault: Bool {
        isBundled || (name == "Mainey" && assetFileName == "mainey-spritesheet.webp" && spriteSpecID == SpriteSheetSpec.codexMainey.id)
    }
}
