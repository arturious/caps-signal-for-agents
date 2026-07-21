// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "capsig",
    platforms: [.macOS(.v12)],
    targets: [
        .systemLibrary(name: "CIOHID"),
        .executableTarget(
            name: "capsig",
            dependencies: ["CIOHID"]
        ),
    ]
)
