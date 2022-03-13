// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "modbus2mqtt",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(name: "modbus2mqtt", targets: ["modbus2mqtt"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from:"1.1.0" ), // revision:"3cad8ef"), // : "1.0.3"),
        .package(url: "https://github.com/sroebert/mqtt-nio.git", from: "2.5.0"),
        .package(url: "https://github.com/jollyjinx/JLog", from:"0.0.4"),
        .package(url: "https://github.com/jollyjinx/SwiftLibModbus", from:"2.0.0-beta1"),
//        .package(path: "/Users/jolly/Documents/GitHub/SwiftLibModbus")
//        .package(path: "/home/swift/SwiftLibModbus")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "modbus2mqtt",
            dependencies: [
                                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                                .product(name: "MQTTNIO", package: "mqtt-nio"),
                                .product(name: "JLog", package: "JLog"),
                                .product(name: "SwiftLibModbus", package: "SwiftLibModbus")
                        ],
                        resources: [
                            .copy("Resources/phoenix.evcharger.json"),
                            .copy("Resources/sma.sunnyboy.json"),
                            .copy("Resources/sma.sunnystore.json")
                        ]
            ),
        .testTarget(
            name: "modbus2mqttTests",
            dependencies: ["modbus2mqtt"]),
    ]
)
