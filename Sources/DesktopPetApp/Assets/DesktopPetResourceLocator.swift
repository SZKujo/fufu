import Foundation

enum DesktopPetResourceLocator {
    static let resourceBundleName = "DesktopPet_DesktopPetApp.bundle"

    static func resourceURL(
        forResource name: String,
        withExtension fileExtension: String,
        mainBundleURL: URL = Bundle.main.bundleURL,
        mainResourceURL: URL? = Bundle.main.resourceURL,
        moduleBundle: Bundle = .module
    ) -> URL? {
        let fileName = "\(name).\(fileExtension)"
        let packagedURLs = [
            mainResourceURL?.appending(path: resourceBundleName, directoryHint: .isDirectory),
            mainBundleURL.appending(path: resourceBundleName, directoryHint: .isDirectory)
        ]
            .compactMap { $0?.appending(path: fileName, directoryHint: .notDirectory) }

        for url in packagedURLs where FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        return moduleBundle.url(forResource: name, withExtension: fileExtension)
    }
}
