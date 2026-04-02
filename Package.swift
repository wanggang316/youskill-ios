// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YouSkill",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "YouSkill", targets: ["YouSkill"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1")
    ],
    targets: [
        .target(
            name: "YouSkill",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources",
            exclude: ["App"],
            sources: ["Config", "Repo", "Runtime", "Service", "Types", "UI"]
        ),
        .testTarget(
            name: "YouSkillTests",
            dependencies: ["YouSkill"],
            path: "Tests",
            exclude: ["Info.plist"]
        )
    ]
)
