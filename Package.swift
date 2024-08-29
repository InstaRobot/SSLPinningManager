// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SSLPinningManager",
    platforms: [
        .iOS(.v14), .macOS(.v11), .tvOS(.v14)
    ],
    products: [
        .library(
            name: "SSLPinningManager",
            targets: ["SSLPinningManager"]),
    ],
    targets: [
        .target(
            name: "SSLPinningManager"),
    ]
)
