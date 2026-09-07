// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "S5",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "S5", targets: ["S5"]),
        .library(name: "S5Client", targets: ["S5Client"]),
        .library(name: "S5Vapor", targets: ["S5Vapor"]),
        .library(name: "S5Ignite", targets: ["S5Ignite"]),
        .library(name: "S5Scaffold", targets: ["S5Scaffold"]),
        .executable(name: "s5", targets: ["S5CLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", exact: "4.122.1"),
        .package(url: "https://github.com/twostraws/Ignite.git", exact: "0.6.9"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(name: "S5"),
        .target(name: "S5Client", dependencies: ["S5"]),
        .target(name: "S5Vapor", dependencies: ["S5", .product(name: "Vapor", package: "vapor")]),
        .target(name: "S5Ignite", dependencies: ["S5", .product(name: "Ignite", package: "Ignite")],
                resources: [.copy("Resources/runtime.mjs")]),
        .target(name: "S5Scaffold", resources: [.copy("Resources/Starter")]),
        .executableTarget(name: "S5CLI", dependencies: [
            "S5Scaffold", .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "S5ScaffoldTests", dependencies: ["S5Scaffold"]),
        .testTarget(name: "S5Tests", dependencies: ["S5", "S5Client"]),
        .testTarget(name: "S5VaporTests", dependencies: [
            "S5Vapor", .product(name: "VaporTesting", package: "vapor"),
        ]),
    ]
)
