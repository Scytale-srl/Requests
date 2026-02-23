// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Requests",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "Requests",
            targets: ["Requests"]),
        .library(
            name: "RequestsBinary",
            targets: ["RequestsBinary"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Requests",
            dependencies: [],
            path: "Requests"),
        .testTarget(
            name: "RequestsTests",
            dependencies: ["Requests"],
            path: "RequestsTests"),
        .binaryTarget(
            name: "RequestsBinary",
            url: "https://github.com/Scytale-srl/Requests/releases/download/0.0.0/Requests.xcframework.zip",
            checksum: "PLACEHOLDER"
        ),
    ]
)
