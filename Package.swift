// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CoreDataPublisher",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "CoreDataPublisher",
            targets: ["CoreDataPublisher"]
        ),
    ],
    targets: [
        .target(
            name: "CoreDataPublisher"
        ),
        .testTarget(
            name: "CoreDataPublisherTests",
            dependencies: ["CoreDataPublisher"],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
