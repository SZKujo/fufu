import Foundation
import XCTest

final class DesktopPetPackagingTests: XCTestCase {
    func testAppBundleInfoPlistRegistersDesktopPetIcon() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let plistURL = packageRoot.appendingPathComponent("Packaging/DesktopPet-Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "DesktopPetIcon")
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "DesktopPet")
        XCTAssertEqual(plist["CFBundlePackageType"] as? String, "APPL")
    }

    func testSourceICNSExistsForAppBundlePackaging() {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let iconURL = packageRoot.appendingPathComponent("Sources/DesktopPetApp/Resources/DesktopPetIcon.icns")

        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.path))
    }
}
