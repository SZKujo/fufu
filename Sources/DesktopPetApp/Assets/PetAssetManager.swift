import Foundation

enum PetAssetManager {
    static var supportDirectory: URL {
        get throws {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let directory = root.appending(path: "DesktopPet/Assets", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }
    }

    static func assetURL(for fileName: String) throws -> URL {
        try supportDirectory.appending(path: fileName, directoryHint: .notDirectory)
    }

    static func copyAsset(from sourceURL: URL) throws -> String {
        let directory = try supportDirectory
        let ext = sourceURL.pathExtension.isEmpty ? "asset" : sourceURL.pathExtension
        let fileName = "\(UUID().uuidString).\(ext)"
        let destination = directory.appending(path: fileName, directoryHint: .notDirectory)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return fileName
    }

    static func installBundledMaineyIfNeeded() throws -> String {
        let fileName = "mainey-spritesheet.webp"
        let destination = try assetURL(for: fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            return fileName
        }

        guard let source = Bundle.module.url(forResource: "MaineySpritesheet", withExtension: "webp") else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return fileName
    }
}
