//
//  modbus2mqttTests.swift
//

import Foundation
import JLog
import SwiftLibModbus
import Testing
import SwiftLibModbus2MQTT

@Suite("Modbus Tests")
struct modbus2mqttTests
{
    @Test
    func BrokenJSONDefinition() async throws
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

	#expect(throws: (any Error).self) {
            let definitions = try ModbusDefinition.read(from: url)
        }
    }

    @Test
    func BitMapValues() async throws
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

        
        let definitions = try ModbusDefinition.read(from: url)
    }

    @Test
    func DecodingInt8() async throws
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

        let definitions = try ModbusDefinition.read(from: url)

        let modbusValue = ModbusValue(address: 1, value: .uint32(0b1111111))

    }
}
