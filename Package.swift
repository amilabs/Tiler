// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tiler",
    platforms: [.macOS("26.0")],
    targets: [
        // Pure decision logic: gesture recognizer, tunables, models. No system imports.
        .target(name: "TilerCore"),
        // C-layout structs for the private MultitouchSupport framework.
        .target(name: "CMultitouchSupport"),
        .executableTarget(
            name: "Tiler",
            dependencies: ["TilerCore", "CMultitouchSupport"]
        ),
        .testTarget(
            name: "TilerCoreTests",
            dependencies: ["TilerCore"]
        ),
    ]
)
