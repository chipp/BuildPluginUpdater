// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BuildPluginUpdater",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-package-manager", branch: "swift-6.0-RELEASE"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.2.2"))
    ],
    targets: [
        .executableTarget(name: "BuildPluginUpdater", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "SwiftPMDataModel-auto", package: "swift-package-manager")
        ]),
    ]
)
