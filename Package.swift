// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YouSkill",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "YouSkill", targets: ["YouSkill"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1"),
        .package(url: "https://github.com/appstefan/highlightswift.git", from: "1.1.0"),
        .package(url: "https://github.com/exyte/SVGView.git", from: "1.0.6")
    ],
    targets: [
        .target(
            name: "YouSkill",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "HighlightSwift", package: "highlightswift"),
                .product(name: "SVGView", package: "SVGView")
            ],
            path: "Sources",
            exclude: ["App"],
            sources: ["Config", "Repo", "Runtime", "Service", "Types", "UI"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "YouSkillTests",
            dependencies: ["YouSkill"],
            path: "Tests",
            exclude: ["Info.plist"]
        )
    ]
)
