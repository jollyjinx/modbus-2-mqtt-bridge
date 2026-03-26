// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("StrictConcurrency"),
]

let package = Package(name: "modbus2mqtt",
                      platforms: [
                          .iOS(.v18),
                          .macOS(.v15),
                      ],
                      products: [
                          // Products define the executables and libraries a package produces, and make them visible to other packages.
                          .executable(name: "modbus2mqtt", targets: ["modbus2mqtt"]),
                          .library(name: "SwiftLibModbus2MQTT", targets: ["SwiftLibModbus2MQTT"]),
                      ],
                      dependencies: [
                          .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.6.2")),
                          .package(url: "https://github.com/sroebert/mqtt-nio.git", from: "2.8.0"),
                          .package(url: "https://github.com/jollyjinx/JLog", .upToNextMajor(from: "0.0.9")),
                          .package(url: "https://github.com/jollyjinx/SwiftLibModbus", from: "2.1.0"),
                      ],
                      targets: [
                          .executableTarget(name: "modbus2mqtt",
                                            dependencies: [
                                                "SwiftLibModbus2MQTT",
                                                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                                                .product(name: "JLog", package: "JLog"),
                                            ],
                                            resources: [
                                                .copy("DeviceDefinitions/"),
                                            ],
                                            swiftSettings: strictSwiftSettings),
                          .target(name: "SwiftLibModbus2MQTT",
                                  dependencies: [
                                      .product(name: "MQTTNIO", package: "mqtt-nio"),
                                      .product(name: "JLog", package: "JLog"),
                                      .product(name: "SwiftLibModbus", package: "SwiftLibModbus"),
                                  ],
                                  swiftSettings: strictSwiftSettings),
                          .testTarget(name: "modbus2mqttTests",
                                      dependencies: [
                                          "SwiftLibModbus2MQTT",
                                          .product(name: "SwiftLibModbus", package: "SwiftLibModbus"),
                                      ],
                                      swiftSettings: strictSwiftSettings),
                      ],
                      swiftLanguageModes: [.v6])
