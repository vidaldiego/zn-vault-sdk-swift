// swift-tools-version:5.9
// Path: zn-vault-sdk-swift/Package.swift

import PackageDescription

let package = Package(
    name: "ZnVault",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "ZnVault",
            targets: ["ZnVault"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ZnVault",
            dependencies: [],
            path: "Sources/ZnVault"
        ),
        .testTarget(
            name: "ZnVaultTests",
            dependencies: ["ZnVault"],
            path: "Tests/ZnVaultTests"
        ),
        // Integration tests are run via test-integration.sh shell script
        // which tests API compatibility against a running ZnVault server
    ]
)
