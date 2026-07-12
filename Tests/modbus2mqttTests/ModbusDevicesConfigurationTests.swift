import Foundation
import SwiftLibModbus2MQTT
import Testing

struct ModbusDevicesConfigurationTests
{
    @Test
    func decodesDevicesAndAppliesDefaults() throws
    {
        let data = Data(#"""
        {
          "devices": [
            {
              "networkAddress": "10.112.1.2",
              "modbusAddress": 1,
              "topic": "/counters/heatpump/",
              "deviceDescriptionFile": "meter.json"
            },
            {
              "networkAddress": "10.112.1.2",
              "port": 1502,
              "modbusAddress": 2,
              "topic": "counters/boiler",
              "deviceDescriptionFile": "meter.json"
            }
          ]
        }
        """#.utf8)

        let configuration = try JSONDecoder().decode(ModbusDevicesConfiguration.self, from: data)

        #expect(configuration.devices.count == 2)
        #expect(configuration.devices[0].port == 502)
        #expect(configuration.devices[0].topic == "counters/heatpump")
        #expect(configuration.devices[1].port == 1502)
        #expect(configuration.devices.map(\.endpoint).allSatisfy { $0.networkAddress == "10.112.1.2" })
    }

    @Test
    func rejectsEmptyDeviceList()
    {
        #expect(throws: ModbusDevicesConfigurationError.emptyDeviceList)
        {
            try JSONDecoder().decode(ModbusDevicesConfiguration.self, from: Data(#"{"devices":[]}"#.utf8))
        }
    }

    @Test
    func rejectsDuplicateTopics() throws
    {
        let first = try device(address: 1, topic: "counter")
        let second = try device(address: 2, topic: "counter")

        #expect(throws: ModbusDevicesConfigurationError.duplicateTopic("counter"))
        {
            try ModbusDevicesConfiguration(devices: [first, second])
        }
    }

    @Test
    func rejectsDuplicateEndpointAndUnit() throws
    {
        let first = try device(address: 1, topic: "first")
        let second = try device(address: 1, topic: "second")
        let endpoint = ModbusEndpointKey(networkAddress: "gateway", port: 502)

        #expect(throws: ModbusDevicesConfigurationError.duplicateLogicalDevice(endpoint: endpoint, modbusAddress: 1))
        {
            try ModbusDevicesConfiguration(devices: [first, second])
        }
    }

    @Test(arguments: ["bad/#", "bad/+", "#", "+"])
    func rejectsMQTTWildcards(topic: String)
    {
        #expect(throws: ModbusDevicesConfigurationError.wildcardTopic(topic))
        {
            try device(address: 1, topic: topic)
        }
    }

    private func device(address: UInt8, topic: String) throws -> ModbusDeviceConfiguration
    {
        try ModbusDeviceConfiguration(networkAddress: "gateway",
                                      modbusAddress: address,
                                      topic: topic,
                                      deviceDescriptionFile: "meter.json")
    }
}
