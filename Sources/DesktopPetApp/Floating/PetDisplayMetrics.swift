import AppKit
import DesktopPetCore
import Foundation

@MainActor
enum PetDisplayMetrics {
    static let bubbleWidth: CGFloat = 270
    static let horizontalSpacing: CGFloat = 10
    static let padding: CGFloat = 24
    static let desktopAvatarScale: CGFloat = 2.0 / 3.0
    static let minimumAvatarSide: CGFloat = 64

    static func avatarSize(for pet: PetRecord) -> CGSize {
        let baseSize: CGSize
        switch pet.assetKind {
        case .spriteSheet:
            let spec = spriteSheetSpec(for: pet)
            baseSize = CGSize(width: spec.maxFrameWidth, height: spec.maxFrameHeight)
        case .stillImage:
            baseSize = stillImageSize(for: pet)
        }

        return CGSize(
            width: max(minimumAvatarSide, baseSize.width * pet.scale * desktopAvatarScale),
            height: max(minimumAvatarSide, baseSize.height * pet.scale * desktopAvatarScale)
        )
    }

    private static func spriteSheetSpec(for pet: PetRecord) -> SpriteSheetSpec {
        guard let assetURL = try? PetAssetManager.assetURL(for: pet.assetFileName) else {
            return SpriteSheetSpec.codexMainey
        }
        return SpriteFrameRenderer.shared.spec(for: assetURL)
    }

    static func panelSize(for pet: PetRecord, showsBubble: Bool) -> CGSize {
        let avatarSize = avatarSize(for: pet)
        let width = avatarSize.width
            + padding
            + (showsBubble ? bubbleWidth + horizontalSpacing : 0)
        let height = max(avatarSize.height + padding, showsBubble ? 172 : 0)
        return CGSize(width: width, height: height)
    }

    private static func stillImageSize(for pet: PetRecord) -> CGSize {
        guard
            let assetURL = try? PetAssetManager.assetURL(for: pet.assetFileName),
            let image = NSImage(contentsOf: assetURL)
        else {
            return CGSize(width: 160, height: 180)
        }

        let maxSide: CGFloat = 240
        let scale = min(maxSide / max(image.size.width, 1), maxSide / max(image.size.height, 1), 1)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }
}
