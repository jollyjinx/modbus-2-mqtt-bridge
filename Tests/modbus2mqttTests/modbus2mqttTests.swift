//
//  modbus2mqttTests.swift
//

import Foundation
import SwiftLibModbus2MQTT
import Testing

@Suite
struct Modbus2mqttTests
{
    @Test
    func brokenJSONDefinition() throws
    {
        let testJSON = """
        [
            {
                "address": 0,
                "modbustype": "holding",
                "modbusaccess": "read",
                "valuetype": "int16",
                "mqtt": "visible",
                "interval": 10,
                "topic": "ambient/errornumber",
                "title": "Ambient Error Number"
            },
            {
                "address": 0,
                "modbustype": "holding",
                "modbusaccess": "read",
                "valuetype": "int16",
                "mqtt": "visible",
                "interval": 10,
                "topic": "ambient/errornumber",
                "title": "Ambient Error Number"
            }
        ]
        """

        // write to a temporary file
        let url = URL(fileURLWithPath: "/tmp/ModbusDefinitions.json" + UUID().uuidString)
        try testJSON.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: (any Error).self)
        {
            try ModbusDefinition.read(from: url)
        }
    }

    @Test
    func bitMapValues() throws
    {
        let testJSON = """
        [
            {
                "address": 1,
                "modbustype": "holding",
                "modbusaccess": "read",
                "valuetype": "int16",
                "mqtt": "visible",
                "interval": 10,
                "topic": "ambient/errornumber",
                "title": "Ambient Error Number",
                "bits" : {
                    "0-1": { "name" : "foo", "mqttPath" : "pathfoo" },
                    "2-5": { "name" : "bar", "mqttPath" : "pathbar" },
                    "6" :  { "name" : "baz", "mqttPath" : "pathbaz" }
                }
            }
        ]
        """

        // write to a temporary file
        let url = URL(fileURLWithPath: "/tmp/ModbusDefinitions.json" + UUID().uuidString)
        try testJSON.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try ModbusDefinition.read(from: url)
    }

    @Test
    func decodingInt8() throws
    {
        let testJSON = """
        [
            {
                "address": 1,
                "modbustype": "holding",
                "modbusaccess": "read",
                "valuetype": "uint32",
                "mqtt": "visible",
                "interval": 10,
                "topic": "ambient/errornumber",
                "title": "Ambient Error Number",
                "bits" : {
                    "0-1": { "name" : "foo" },
                    "2-5": { "name" : "bar" },
                    "6" :  { "name" : "baz" }
                },
                "map" : {
                    "0" : "bla",
                    "127" : "foo"
                }
            }
        ]
        """

        // write to a temporary file
        let url = URL(fileURLWithPath: "/tmp/ModbusDefinitions.json" + UUID().uuidString)
        try testJSON.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try ModbusDefinition.read(from: url)
        #expect(ModbusValue(address: 1, value: .uint32(0b1111111)).stringValue == "127")
    }

    @Test
    func payloadEncodingUsesItsExplicitDefinition() throws
    {
        let firstURL = try temporaryDefinitionFile(title: "First meter",
                                                   topic: "meters/first",
                                                   unit: "A",
                                                   mappedValue: "running")
        let secondURL = try temporaryDefinitionFile(title: "Second meter",
                                                    topic: "meters/second",
                                                    unit: "W",
                                                    mappedValue: "active")
        defer
        {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        let firstDefinitions = try ModbusDefinition.read(from: firstURL)
        let secondDefinitions = try ModbusDefinition.read(from: secondURL)
        let firstDefinition = try #require(firstDefinitions[1])
        let secondDefinition = try #require(secondDefinitions[1])
        let value = ModbusValue(address: 1, value: .uint16(1))

        let firstJSON = try value.json(using: firstDefinition)
        let secondJSON = try value.json(using: secondDefinition)

        #expect(firstJSON == #"{"address":1,"rawValue":1,"title":"First meter","unit":"A","value":"running"}"#)
        #expect(secondJSON == #"{"address":1,"rawValue":1,"title":"Second meter","unit":"W","value":"active"}"#)
        #expect(value.topic(using: firstDefinition) == "meters/first")
        #expect(value.topic(using: secondDefinition) == "meters/second")
    }

    @Test
    func decodingEastronSDM72DMV2Definition() throws
    {
        let url = URL(fileURLWithPath: "DeviceDefinitions/eastron.sdm72dm-v2.json")

        let definitions = try ModbusDefinition.read(from: url)

        #expect(definitions[0x0000]?.valuetype == .float32)
        #expect(definitions[0x0000]?.topic == "immediate/p1/voltage")
        #expect(definitions[0x0156]?.topic == "counter/totalactiveenergy")
        #expect(definitions[0xFC00]?.topic == "static/serialnumber")
    }

    @Test
    func decodingNIBES2125Definition() throws
    {
        let url = URL(fileURLWithPath: "DeviceDefinitions/nibe.s2125.json")

        let definitions = try ModbusDefinition.read(from: url)

        #expect(definitions[1]?.topic == "system/outdoortemperature")
        #expect(definitions[1478]?.topic == "heatpump/supplyline")
        #expect(definitions[1805]?.map?["1"] == "ACTIVE")
    }

    private func temporaryDefinitionFile(title: String,
                                         topic: String,
                                         unit: String,
                                         mappedValue: String) throws -> URL
    {
        let json = """
        [
            {
                "address": 1,
                "modbustype": "holding",
                "modbusaccess": "read",
                "valuetype": "uint16",
                "unit": "\(unit)",
                "map": { "1": "\(mappedValue)" },
                "mqtt": "visible",
                "interval": 10,
                "topic": "\(topic)",
                "title": "\(title)"
            }
        ]
        """
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ModbusDefinitions-\(UUID().uuidString).json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
