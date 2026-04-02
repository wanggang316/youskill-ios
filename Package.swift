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
    targets: [
        .target(
            name: "YouSkill",
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
