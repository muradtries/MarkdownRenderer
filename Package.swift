// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MarkdownRenderer",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "MarkdownRenderer",
            targets: ["MarkdownRenderer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3"),
    ],
    targets: [
        .target(
            name: "MarkdownRenderer",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .testTarget(
            name: "MarkdownRendererTests",
            dependencies: ["MarkdownRenderer"]
        ),
    ]
)
