// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "S5",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "S5", targets: ["S5"]),
        .library(name: "S5Client", targets: ["S5Client"]),
        .library(name: "S5Vapor", targets: ["S5Vapor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", exact: "4.122.1"),
    ],
    targets: [
        .target(name: "S5"),
        .target(name: "S5Client", dependencies: ["S5"]),
        .target(name: "S5Vapor", dependencies: ["S5", .product(name: "Vapor", package: "vapor")]),
        .testTarget(name: "S5Tests", dependencies: ["S5", "S5Client"]),
        .testTarget(name: "S5VaporTests", dependencies: [
            "S5Vapor", .product(name: "VaporTesting", package: "vapor"),
        ]),
    ]
)
