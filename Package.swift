// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "agent-signal",
    platforms: [.macOS(.v12)],
    targets: [
        .systemLibrary(name: "CIOHID"),
        .executableTarget(
            name: "agent-signal",
            dependencies: ["CIOHID"]
        ),
    ]
)
