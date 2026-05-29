import CoreGraphics
import Foundation
import ImageIO
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
        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "浮浮")
        XCTAssertEqual(plist["CFBundleName"] as? String, "浮浮")
        XCTAssertEqual(plist["CFBundlePackageType"] as? String, "APPL")
    }

    func testSourceICNSExistsForAppBundlePackaging() {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let iconURL = packageRoot.appendingPathComponent("Sources/DesktopPetApp/Resources/DesktopPetIcon.icns")

        XCTAssertTrue(FileManager.default.fileExists(atPath: iconURL.path))
    }

    func testSourcePNGUsesTransparentCanvasForDockRendering() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let iconURL = packageRoot.appendingPathComponent("Sources/DesktopPetApp/Resources/DesktopPetIcon.png")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(iconURL as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))

        XCTAssertTrue(image.alphaInfo.hasAlphaChannel)
        XCTAssertEqual(try alphaValue(in: image, x: 0, y: 0), 0)
        XCTAssertEqual(try alphaValue(in: image, x: image.width - 1, y: 0), 0)
        XCTAssertEqual(try alphaValue(in: image, x: 0, y: image.height - 1), 0)
        XCTAssertEqual(try alphaValue(in: image, x: image.width - 1, y: image.height - 1), 0)
    }

    func testSourcePNGDoesNotKeepOpaqueOuterShadowPixels() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let iconURL = packageRoot.appendingPathComponent("Sources/DesktopPetApp/Resources/DesktopPetIcon.png")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(iconURL as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))

        XCTAssertEqual(try alphaValue(in: image, x: 95, y: image.height / 2), 0)
        XCTAssertEqual(try alphaValue(in: image, x: image.width - 84, y: image.height / 2), 0)
        XCTAssertEqual(try alphaValue(in: image, x: image.width / 2, y: 75), 0)
        XCTAssertEqual(try alphaValue(in: image, x: image.width / 2, y: image.height - 64), 0)
    }

    func testSourcePNGSmoothsOuterCornerContour() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let iconURL = packageRoot.appendingPathComponent("Sources/DesktopPetApp/Resources/DesktopPetIcon.png")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(iconURL as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))

        XCTAssertEqual(try alphaValue(in: image, x: 180, y: 900), 0)
        XCTAssertEqual(try alphaValue(in: image, x: image.width - 189, y: 900), 0)
        XCTAssertEqual(try alphaValue(in: image, x: 200, y: 110), 0)
        XCTAssertEqual(try alphaValue(in: image, x: image.width - 201, y: 110), 0)

        let topCenterAlpha = try alphaValue(in: image, x: image.width / 2, y: 120)
        XCTAssertGreaterThan(topCenterAlpha, 0)
        XCTAssertLessThan(topCenterAlpha, 255)
    }

    private func alphaValue(in image: CGImage, x: Int, y: Int) throws -> UInt8 {
        let crop = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try XCTUnwrap(
            CGContext(
                data: &pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            )
        )

        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel[3]
    }
}

private extension CGImageAlphaInfo {
    var hasAlphaChannel: Bool {
        switch self {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        case .none, .noneSkipFirst, .noneSkipLast, .alphaOnly:
            return false
        @unknown default:
            return false
        }
    }
}
