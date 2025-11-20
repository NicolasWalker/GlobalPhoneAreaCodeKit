// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AreaCodeKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "AreaCodeKit",
            targets: ["AreaCodeKit"]),
    ],
    targets: [
        .target(
            name: "AreaCodeKit",
            dependencies: [],
            resources: [
                .process("Resources/area_codes.json")
            ]
        )
    ]
)
