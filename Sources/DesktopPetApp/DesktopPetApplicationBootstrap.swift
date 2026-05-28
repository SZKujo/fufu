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
