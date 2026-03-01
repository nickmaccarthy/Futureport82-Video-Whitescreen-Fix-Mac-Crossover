// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FP82Fixer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "FP82Fixer",
            path: "FP82Fixer",
            resources: [
                .copy("FixResources"),
                .copy("Images")
            ]
        )
    ]
)
