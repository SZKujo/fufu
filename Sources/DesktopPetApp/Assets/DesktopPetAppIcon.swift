import AppKit
import Foundation

enum DesktopPetAppIcon {
    static let resourceName = "DesktopPetIcon"
    static let resourceExtension = "png"

    static func resourceURL(
        mainBundleURL: URL = Bundle.main.bundleURL,
        mainResourceURL: URL? = Bundle.main.resourceURL,
        moduleBundle: Bundle = .module
    ) -> URL? {
        DesktopPetResourceLocator.resourceURL(
            forResource: resourceName,
            withExtension: resourceExtension,
            mainBundleURL: mainBundleURL,
            mainResourceURL: mainResourceURL,
            moduleBundle: moduleBundle
        )
    }

    static func bundledIconImage() -> NSImage? {
        guard let url = resourceURL() else { return nil }
        return iconImage(resourceURL: url)
    }

    static func iconImage(resourceURL: URL) -> NSImage? {
        NSImage(contentsOf: resourceURL)
    }
}

enum DesktopPetResourceLocator {
    static func resourceURL(
        forResource name: String,
        withExtension resourceExtension: String,
        mainBundleURL: URL = Bundle.main.bundleURL,
        mainResourceURL: URL? = Bundle.main.resourceURL,
        moduleBundle: Bundle = .module
    ) -> URL? {
        let fileName = "\(name).\(resourceExtension)"
        let fileManager = FileManager.default
        let packagedResourceBundleName = "DesktopPetApp_DesktopPetApp.bundle"
        let directMainResourceURL = mainResourceURL?.appending(path: fileName, directoryHint: .notDirectory)
        let packagedMainResourceURL = mainResourceURL?
            .appending(path: packagedResourceBundleName, directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)
        let appContentsResourceURL = mainBundleURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "Resources", directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)
        let appContentsResourceBundleURL = mainBundleURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "Resources", directoryHint: .isDirectory)
            .appending(path: packagedResourceBundleName, directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)

        return [
            directMainResourceURL,
            packagedMainResourceURL,
            appContentsResourceURL,
            appContentsResourceBundleURL,
            moduleBundle.url(forResource: name, withExtension: resourceExtension)
        ]
        .compactMap { $0 }
        .first { fileManager.fileExists(atPath: $0.path) }
    }
}
