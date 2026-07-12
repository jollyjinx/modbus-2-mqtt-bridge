import SwiftLibModbus2MQTT
import Testing

struct MQTTRequestRouterTests
{
    @Test
    func routesExactRequestPrefix() throws
    {
        let device = try makeDevice(topic: "counters/heatpump", modbusAddress: 1)
        let router = MQTTRequestRouter(devices: [device])

        let route = try #require(router.route(for: "counters/heatpump/request"))

        #expect(route.device == device)
        #expect(route.responseTopic == "counters/heatpump/response")
    }

    @Test
    func preservesRequestTopicSuffixExactly() throws
    {
        let device = try makeDevice(topic: "counters/heatpump", modbusAddress: 1)
        let router = MQTTRequestRouter(devices: [device])

        let route = try #require(router.route(for: "counters/heatpump/request/change/123"))

        #expect(route.responseTopic == "counters/heatpump/response/change/123")
    }

    @Test(arguments: [
        "unrelated/counters/heatpump/request/change",
        "counters/heatpump/requested",
        "counters/heatpump/request-change",
        "counters/heatpump",
    ])
    func rejectsTopicsOutsideRequestNamespace(topic: String) throws
    {
        let device = try makeDevice(topic: "counters/heatpump", modbusAddress: 1)
        let router = MQTTRequestRouter(devices: [device])

        #expect(router.route(for: topic) == nil)
    }

    @Test
    func choosesMostSpecificRequestPrefix() throws
    {
        let outerDevice = try makeDevice(topic: "meters", modbusAddress: 1)
        let nestedDevice = try makeDevice(topic: "meters/request/secondary", modbusAddress: 2)
        let router = MQTTRequestRouter(devices: [outerDevice, nestedDevice])

        let route = try #require(router.route(for: "meters/request/secondary/request/change"))

        #expect(route.device == nestedDevice)
        #expect(route.responseTopic == "meters/request/secondary/response/change")
    }

    @Test
    func precomputesRequestSubscriptions() throws
    {
        let heatpump = try makeDevice(topic: "counters/heatpump", modbusAddress: 1)
        let boiler = try makeDevice(topic: "counters/boiler", modbusAddress: 2)

        let router = MQTTRequestRouter(devices: [heatpump, boiler])

        #expect(router.requestSubscriptions == [
            "counters/heatpump/request/#",
            "counters/boiler/request/#",
        ])
    }

    private func makeDevice(topic: String, modbusAddress: UInt8) throws -> ModbusDeviceConfiguration
    {
        try ModbusDeviceConfiguration(networkAddress: "gateway",
                                      modbusAddress: modbusAddress,
                                      topic: topic,
                                      deviceDescriptionFile: "meter.json")
    }
}
