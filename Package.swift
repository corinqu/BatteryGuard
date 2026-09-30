// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BatteryGuard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BatteryGuard",
            path: "Sources",
            linkerSettings: [
                .unsafeFlags(["-framework", "IOKit"]),
            ]
        ),
    ]
)
