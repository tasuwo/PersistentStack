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
        .package(url: "https://github.com/tasuwo/swift", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "PersistentStack",
            dependencies: [],
            plugins: [
                .plugin(name: "LintSwift", package: "swift")
            ]
        ),
    ]
)
