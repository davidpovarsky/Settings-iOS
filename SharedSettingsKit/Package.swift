// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedSettingsKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SharedSettingsKit",
            targets: ["SharedSettingsKit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SharedSettingsKit",
            dependencies: [],
            path: "Sources/SharedSettingsKit"
        ),
        .testTarget(
            name: "SharedSettingsKitTests",
            dependencies: ["SharedSettingsKit"],
            path: "Tests/SharedSettingsKitTests"
        ),
    ]
)
