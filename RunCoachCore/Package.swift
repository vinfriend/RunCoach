// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RunCoachCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "RunCoachCore",
            targets: ["RunCoachCore"]
        )
    ],
    targets: [
        .target(
            name: "RunCoachCore",
            dependencies: []
        ),
        .testTarget(
            name: "RunCoachCoreTests",
            dependencies: ["RunCoachCore"]
        )
    ]
)
