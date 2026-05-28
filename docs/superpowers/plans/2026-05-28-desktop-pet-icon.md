# Desktop Pet Icon Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
**Goal:** Generate the approved macOS-style Mainey cat icon and wire it into the Swift desktop pet app as the runtime Dock/application icon.
**Architecture:** Keep visual assets in `Sources/DesktopPetApp/Resources`, matching the package's existing resource processing. Add a focused icon loader in `Sources/DesktopPetApp/Assets` and a tiny bootstrap unit that applies the launch policy and icon during app startup.
**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Swift Package Manager resources, `sips`, `iconutil`, XCTest.
---
## File Structure
- Create `Sources/DesktopPetApp/Resources/DesktopPetIcon.png`: 1024x1024 master icon generated from the approved design.
- Create `Sources/DesktopPetApp/Resources/DesktopPetIcon.icns`: macOS multi-size icon container generated from the PNG master.
- Create `Sources/DesktopPetApp/Assets/DesktopPetAppIcon.swift`: resource metadata and `NSImage` loading helpers for the app icon.
- Create `Sources/DesktopPetApp/DesktopPetApplicationBootstrap.swift`: startup configuration for activation policy and app icon application.
- Modify `Sources/DesktopPetApp/DesktopPetApp.swift`: call the bootstrap unit from `DesktopPetApplication.init()`.
- Modify `Tests/DesktopPetTests/PetStoreTests.swift`: add focused tests for icon resource loading and bootstrap behavior.
### Task 1: Generate Icon Assets
**Files:**
- Create: `Sources/DesktopPetApp/Resources/DesktopPetIcon.png`
- Create: `Sources/DesktopPetApp/Resources/DesktopPetIcon.icns`
- Temporary: `tmp/DesktopPetIcon.iconset/`
- [ ] **Step 1: Generate the 1024px PNG master**
Use the image generation tool with this prompt, saving the final image to `Sources/DesktopPetApp/Resources/DesktopPetIcon.png`:
```text
1024x1024 macOS application icon, refined white and misty blue-gray cat head centered on a soft rounded-square macOS-style base. The base uses a subtle white-to-gray-blue gradient, delicate inner highlight, and soft drop shadow. The cat is white-gray with gentle gray-blue shading, clear ears, rounded face, black round eyes with tiny white highlights, pale pink nose, simple horizontal whiskers. Add a memorable forehead marking: three thin curved gray-blue fur strokes forming a natural soft M shape, like cat fur flow, not a hard letter. Clean, polished, premium, calm, friendly desktop pet companion, no mint green, no warm cream palette, no star, no wink, no text, no background scene, icon-safe margins.
```
- [ ] **Step 2: Verify master dimensions**
Run:
```bash
sips -g pixelWidth -g pixelHeight Sources/DesktopPetApp/Resources/DesktopPetIcon.png
```
Expected: `pixelWidth: 1024` and `pixelHeight: 1024`.
- [ ] **Step 3: Build the iconset and ICNS**
Run:
```bash
mkdir -p tmp/DesktopPetIcon.iconset
sips -z 16 16 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon.iconset/icon_16x16.png
sips -z 32 32 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon.iconset/icon_16x16@2x.png
sips -z 32 32 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon.iconset/icon_32x32.png
sips -z 64 64 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon.iconset/icon_32x32@2x.png
sips -z 128 128 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon.iconset/icon_128x128.png
sips -z 256 256 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon.iconset/icon_128x128@2x.png
sips -z 256 256 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon.iconset/icon_256x256.png
sips -z 512 512 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon.iconset/icon_256x256@2x.png
sips -z 512 512 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon.iconset/icon_512x512.png
cp Sources/DesktopPetApp/Resources/DesktopPetIcon.png tmp/DesktopPetIcon.iconset/icon_512x512@2x.png
iconutil -c icns tmp/DesktopPetIcon.iconset -o Sources/DesktopPetApp/Resources/DesktopPetIcon.icns
```
Expected: `Sources/DesktopPetApp/Resources/DesktopPetIcon.icns` exists.
- [ ] **Step 4: Check small-size recognizability**
Run:
```bash
sips -z 128 128 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon-128.png
sips -z 32 32 Sources/DesktopPetApp/Resources/DesktopPetIcon.png --out tmp/DesktopPetIcon-32.png
file tmp/DesktopPetIcon-128.png tmp/DesktopPetIcon-32.png Sources/DesktopPetApp/Resources/DesktopPetIcon.icns
```
Expected: the PNG files report `PNG image data`; the ICNS file reports `Mac OS X icon`.
- [ ] **Step 4a: Visually inspect the 128px and 32px previews**
Open or view `tmp/DesktopPetIcon-128.png` and `tmp/DesktopPetIcon-32.png`.
Expected: 128px shows the cat face and fine curved M forehead fur; 32px still reads as a white-gray cat head instead of an abstract gray blob.
- [ ] **Step 5: Commit generated assets**
Run:
```bash
git add Sources/DesktopPetApp/Resources/DesktopPetIcon.png Sources/DesktopPetApp/Resources/DesktopPetIcon.icns
git commit -m "Add desktop pet app icon assets"
```
Expected: commit succeeds and only the two icon asset files are included.
### Task 2: Add Icon Resource Loader
**Files:**
- Create: `Sources/DesktopPetApp/Assets/DesktopPetAppIcon.swift`
- Modify: `Tests/DesktopPetTests/PetStoreTests.swift`
- [ ] **Step 1: Write failing icon loader tests**
Add these tests after `testResourceLocatorPrefersPackagedAppResourcesBundle()` in `Tests/DesktopPetTests/PetStoreTests.swift`:
```swift
func testDesktopPetAppIconUsesBundledPNGResource() throws {
    let url = try XCTUnwrap(DesktopPetAppIcon.resourceURL())
    XCTAssertEqual(url.lastPathComponent, "DesktopPetIcon.png")
    XCTAssertNotNil(DesktopPetAppIcon.iconImage(resourceURL: url))
}
func testDesktopPetAppIconLoadsImageFromURL() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appending(path: "test-icon.png", directoryHint: .notDirectory)
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: 2, height: 2).fill()
    image.unlockFocus()
    let tiffData = try XCTUnwrap(image.tiffRepresentation)
    let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
    let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: url)
    let loadedImage = try XCTUnwrap(DesktopPetAppIcon.iconImage(resourceURL: url))
    XCTAssertEqual(Int(loadedImage.size.width), 2)
    XCTAssertEqual(Int(loadedImage.size.height), 2)
}
```
- [ ] **Step 2: Run tests to verify they fail**
Run:
```bash
swift test --filter DesktopPetTests/testDesktopPetAppIcon
```
Expected: FAIL because `DesktopPetAppIcon` does not exist.
- [ ] **Step 3: Implement the icon loader**
Create `Sources/DesktopPetApp/Assets/DesktopPetAppIcon.swift`:
```swift
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
```
- [ ] **Step 4: Run icon loader tests**
Run:
```bash
swift test --filter DesktopPetTests/testDesktopPetAppIcon
```
Expected: PASS.
- [ ] **Step 5: Commit icon loader**
Run:
```bash
git add Sources/DesktopPetApp/Assets/DesktopPetAppIcon.swift Tests/DesktopPetTests/PetStoreTests.swift
git commit -m "Add app icon resource loader"
```
Expected: commit succeeds with the loader and tests only.
### Task 3: Apply the Icon During App Startup
**Files:**
- Create: `Sources/DesktopPetApp/DesktopPetApplicationBootstrap.swift`
- Modify: `Sources/DesktopPetApp/DesktopPetApp.swift`
- Modify: `Tests/DesktopPetTests/PetStoreTests.swift`
- [ ] **Step 1: Write failing bootstrap tests**
Add these tests near `testDesktopPetLaunchPolicyKeepsDockEntryAvailable()` in `Tests/DesktopPetTests/PetStoreTests.swift`:
```swift
func testApplicationBootstrapAppliesLaunchPolicyAndIcon() {
    var appliedPolicy: NSApplication.ActivationPolicy?
    var appliedIcon: NSImage?
    let icon = NSImage(size: NSSize(width: 4, height: 4))
    DesktopPetApplicationBootstrap.configure(
        setActivationPolicy: { appliedPolicy = $0 },
        setApplicationIconImage: { appliedIcon = $0 },
        iconImage: { icon }
    )
    XCTAssertEqual(appliedPolicy, .regular)
    XCTAssertTrue(appliedIcon === icon)
}
func testApplicationBootstrapKeepsLaunchPolicyWhenIconIsMissing() {
    var appliedPolicy: NSApplication.ActivationPolicy?
    var didApplyIcon = false
    DesktopPetApplicationBootstrap.configure(
        setActivationPolicy: { appliedPolicy = $0 },
        setApplicationIconImage: { _ in didApplyIcon = true },
        iconImage: { nil }
    )
    XCTAssertEqual(appliedPolicy, .regular)
    XCTAssertFalse(didApplyIcon)
}
```
- [ ] **Step 2: Run bootstrap tests to verify they fail**
Run:
```bash
swift test --filter DesktopPetTests/testApplicationBootstrap
```
Expected: FAIL because `DesktopPetApplicationBootstrap` does not exist.
- [ ] **Step 3: Implement the bootstrap unit**
Create `Sources/DesktopPetApp/DesktopPetApplicationBootstrap.swift`:
```swift
import AppKit
enum DesktopPetApplicationBootstrap {
    static func configure(
        setActivationPolicy: (NSApplication.ActivationPolicy) -> Void = { NSApplication.shared.setActivationPolicy($0) },
        setApplicationIconImage: (NSImage) -> Void = { NSApplication.shared.applicationIconImage = $0 },
        iconImage: () -> NSImage? = DesktopPetAppIcon.bundledIconImage
    ) {
        setActivationPolicy(DesktopPetActivationPolicy.launchPolicy)
        if let icon = iconImage() {
            setApplicationIconImage(icon)
        }
    }
}
```
- [ ] **Step 4: Call bootstrap from app initialization**
In `Sources/DesktopPetApp/DesktopPetApp.swift`, replace:
```swift
init() {
    NSApplication.shared.setActivationPolicy(DesktopPetActivationPolicy.launchPolicy)
}
```
with:
```swift
init() {
    DesktopPetApplicationBootstrap.configure()
}
```
- [ ] **Step 5: Run bootstrap and launch policy tests**
Run:
```bash
swift test --filter DesktopPetTests/testApplicationBootstrap
swift test --filter DesktopPetTests/testDesktopPetLaunchPolicyKeepsDockEntryAvailable
```
Expected: PASS.
- [ ] **Step 6: Commit startup wiring**
Run:
```bash
git add Sources/DesktopPetApp/DesktopPetApplicationBootstrap.swift Sources/DesktopPetApp/DesktopPetApp.swift Tests/DesktopPetTests/PetStoreTests.swift
git commit -m "Apply app icon at startup"
```
Expected: commit succeeds with startup wiring and tests only.
### Task 4: Final Verification
**Files:**
- Verify: `Sources/DesktopPetApp/Resources/DesktopPetIcon.png`
- Verify: `Sources/DesktopPetApp/Resources/DesktopPetIcon.icns`
- Verify: `Sources/DesktopPetApp/Assets/DesktopPetAppIcon.swift`
- Verify: `Sources/DesktopPetApp/DesktopPetApplicationBootstrap.swift`
- [ ] **Step 1: Run the full test suite**
Run:
```bash
swift test
```
Expected: all tests pass.
- [ ] **Step 2: Build the executable**
Run:
```bash
swift build
```
Expected: build succeeds.
- [ ] **Step 3: Verify resource dimensions and ICNS type**
Run:
```bash
sips -g pixelWidth -g pixelHeight Sources/DesktopPetApp/Resources/DesktopPetIcon.png
file Sources/DesktopPetApp/Resources/DesktopPetIcon.icns
```
Expected: PNG is 1024x1024 and ICNS reports `Mac OS X icon`.
- [ ] **Step 4: Inspect final diff scope**
Run:
```bash
git status --short
git log --oneline -4
```
Expected: only pre-existing unrelated dirty files remain unstaged; the latest icon-related commits are visible.
