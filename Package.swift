// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "PersistentStack",
    platforms: [.iOS(.v14), .macOS(.v10_15)],
    products: [
        .library(
            name: "PersistentStack",
            targets: ["PersistentStack"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tasuwo/swift", from: "0.3.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", .upToNextMinor(from: "0.0.3"))
    ],
    targets: [
        .target(
            name: "PersistentStack",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            plugins: [
                .plugin(name: "LintSwift", package: "swift")
            ]
        ),
    ]
)
