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
