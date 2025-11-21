// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlobalPhoneAreaCodeKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "GlobalPhoneAreaCodeKit",
            targets: ["GlobalPhoneAreaCodeKit"]),
    ],
    targets: [
        .target(
            name: "GlobalPhoneAreaCodeKit",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "GlobalPhoneAreaCodeKitTests",
            dependencies: ["GlobalPhoneAreaCodeKit"]
        )
    ]
)
