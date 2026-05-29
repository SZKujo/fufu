import Foundation

enum SpriteSheetPromptReference {
    static let fileName = "how to create a spritesheet.md"

    static func loadText() throws -> String {
        guard let url = DesktopPetResourceLocator.resourceURL(forResource: "how to create a spritesheet", withExtension: "md") else {
            throw ReferencePromptError.missingResource
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    enum ReferencePromptError: LocalizedError {
        case missingResource

        var errorDescription: String? {
            switch self {
            case .missingResource:
                "没有找到生图提示词参考。"
            }
        }
    }
}
