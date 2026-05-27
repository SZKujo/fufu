import AppKit
import DesktopPetCore
import SwiftUI

struct PetAvatarView: View {
    enum AnimationMode {
        case desktop
        case staticFrame
    }

    let pet: PetRecord
    let action: PetAction
    var animationMode: AnimationMode = .desktop

    var body: some View {
        Group {
            if let assetURL = try? PetAssetManager.assetURL(for: pet.assetFileName) {
                switch pet.assetKind {
                case .spriteSheet:
                    SpriteSheetAvatarView(assetURL: assetURL, action: action, animationMode: animationMode)
                case .stillImage:
                    StillAvatarView(assetURL: assetURL)
                }
            } else {
                MissingAvatarView()
            }
        }
        .scaleEffect(x: pet.scale, y: pet.scale, anchor: .center)
    }
}

private struct SpriteSheetAvatarView: View {
    let assetURL: URL
    let action: PetAction
    let animationMode: PetAvatarView.AnimationMode
    private let policy = PetAnimationPolicy()

    var body: some View {
        let spec = SpriteFrameRenderer.shared.spec(for: assetURL)

        switch animationMode {
        case .staticFrame:
            SpriteFrameImage(image: SpriteFrameRenderer.shared.image(assetURL: assetURL, spec: spec, frameIndex: spec.frameIndex(for: .idle, tick: 0)))
        case .desktop:
            TimelineView(.periodic(from: .now, by: 1 / spec.framesPerSecond)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate * spec.framesPerSecond)
                let frameIndex = policy.frameIndex(for: action, tick: tick, spec: spec)
                SpriteFrameImage(image: SpriteFrameRenderer.shared.image(assetURL: assetURL, spec: spec, frameIndex: frameIndex))
            }
        }
    }
}

private struct SpriteFrameImage: View {
    let image: NSImage?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .interpolation(.none)
                .antialiased(false)
                .resizable()
                .scaledToFit()
        } else {
            MissingAvatarView()
        }
    }
}

private struct StillAvatarView: View {
    let assetURL: URL

    var body: some View {
        if let image = NSImage(contentsOf: assetURL) {
            Image(nsImage: image)
                .interpolation(.none)
                .antialiased(false)
                .resizable()
                .scaledToFit()
        } else {
            MissingAvatarView()
        }
    }
}

private struct MissingAvatarView: View {
    var body: some View {
        Image(systemName: "pawprint.fill")
            .font(.system(size: 56, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .help("素材丢失")
    }
}
