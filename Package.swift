// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PersistentStack",
    platforms: [.iOS(.v14), .macOS(.v14)],
    products: [
        .library(
            name: "PersistentStack",
            targets: ["PersistentStack"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "PersistentStack",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ]
        ),
    ]
)
