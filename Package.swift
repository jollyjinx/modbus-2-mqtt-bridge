// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "modbus2mqtt",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(name: "modbus2mqtt", targets: ["modbus2mqtt"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.2.2")),
        .package(url: "https://github.com/sroebert/mqtt-nio.git", from: "2.8.0"),
        .package(url: "https://github.com/jollyjinx/JLog", .upToNextMajor(from: "0.0.5")),
        .package(url: "https://github.com/jollyjinx/SwiftLibModbus", from:"2.0.2"),
    ],
    targets: [
        .executableTarget(
            name: "modbus2mqtt",
            dependencies: [
                                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                                .product(name: "MQTTNIO", package: "mqtt-nio"),
                                .product(name: "JLog", package: "JLog"),
                                .product(name: "SwiftLibModbus", package: "SwiftLibModbus")
                        ],
            resources: [
                .copy("DeviceDefinitions/")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "modbus2mqttTests",
            dependencies: ["modbus2mqtt"]),
    ]
)
