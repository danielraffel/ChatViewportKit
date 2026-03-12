// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ChatViewportKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Compatibility product — re-exports ChatViewportSwiftUI for existing consumers.
        // `import ChatViewportKit` continues to work. Remove after migration stabilizes.
        .library(
            name: "ChatViewportKit",
            targets: ["ChatViewportKit"]
        ),
        .library(
            name: "ChatViewportCore",
            targets: ["ChatViewportCore"]
        ),
        .library(
            name: "ChatViewportSwiftUI",
            targets: ["ChatViewportSwiftUI"]
        ),
        .library(
            name: "ChatViewportUIKit",
            targets: ["ChatViewportUIKit"]
        )
    ],
    targets: [
        .target(
            name: "ChatViewportCore",
            path: "Sources/ChatViewportCore"
        ),
        .target(
            name: "ChatViewportSwiftUI",
            dependencies: ["ChatViewportCore"],
            path: "Sources/ChatViewportSwiftUI"
        ),
        .target(
            name: "ChatViewportUIKit",
            dependencies: ["ChatViewportCore"],
            path: "Sources/ChatViewportUIKit"
        ),
        // Compatibility wrapper — just re-exports ChatViewportSwiftUI
        .target(
            name: "ChatViewportKit",
            dependencies: ["ChatViewportSwiftUI"],
            path: "Sources/ChatViewportKit"
        )
    ]
)
