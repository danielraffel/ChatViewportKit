// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ChatViewportKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ChatViewportKit",
            targets: ["ChatViewportKit"]
        )
    ],
    targets: [
        .target(
            name: "ChatViewportKit",
            path: "Sources/ChatViewportKit"
        )
    ]
)
