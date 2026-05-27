// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DesktopPet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DesktopPetCore", targets: ["DesktopPetCore"]),
        .executable(name: "DesktopPet", targets: ["DesktopPetApp"])
    ],
    targets: [
        .target(name: "DesktopPetCore"),
        .executableTarget(
            name: "DesktopPetApp",
            dependencies: ["DesktopPetCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DesktopPetTests",
            dependencies: ["DesktopPetApp"]
        )
    ]
)
