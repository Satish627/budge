// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Budge",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "BudgeCore"),
        .executableTarget(name: "Budge", dependencies: ["BudgeCore"]),
        .testTarget(name: "BudgeCoreTests", dependencies: ["BudgeCore"]),
    ]
)
