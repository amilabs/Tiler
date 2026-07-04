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
        // System layer (AppKit/AX/multitouch): TouchStream, GestureEngine, WindowActions.
        // A library (not the executable) so integration tests can import it.
        .target(
            name: "TilerSystem",
            dependencies: ["TilerCore", "CMultitouchSupport"]
        ),
        .executableTarget(
            name: "Tiler",
            dependencies: ["TilerCore", "TilerSystem"]
        ),
        .testTarget(
            name: "TilerCoreTests",
            dependencies: ["TilerCore"]
        ),
        // AX-dependent integration tests; auto-skip unless the test host is trusted.
        .testTarget(
            name: "TilerIntegrationTests",
            dependencies: ["TilerCore", "TilerSystem"]
        ),
    ]
)
