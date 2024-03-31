//
//  modbus2mqttTests.swift
//

import Foundation
import JLog
import SwiftLibModbus
import XCTest

@testable import modbus2mqtt

public extension Encodable
{
    var json: String
    {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.sortedKeys]
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.prettyPrinted]
        let jsonData = try? jsonEncoder.encode(self)
        return jsonData != nil ? String(data: jsonData!, encoding: .utf8) ?? "" : ""
    }
}

public extension Decodable
{
    init(json: String) throws
    {
        print("Decodable:\(json)")
        print("Self:\(Self.self)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = json.data(using: .utf8)!
        self = try decoder.decode(Self.self, from: data)
    }
}

final class modbus2mqttTests: XCTestCase
{
    func testReverseEngineerHM310T() async throws
    {
        // Prints out modbus address ranges and compares them to the last time

        let modbusDevice = try ModbusDevice(device: "/dev/tty.usbserial-42340", baudRate: 9600)
        let stripesize = 0x10

        var store = [Int: [UInt16]]()
        let emptyline = [UInt16](repeating: 0, count: stripesize)

        func readData(from address: Int) async throws
        {
            let data: [UInt16] = try await modbusDevice.readRegisters(from: address, count: stripesize, type: .holding)

            let previous: [UInt16] = store[address] ?? emptyline

            if data != previous
            {
                print("\(String(format: "%04x", address)): \(data.map { $0 == 0 ? "  -   " : String(format: "%04x  ", $0) }.joined(separator: " ")) ")
                print("\(String(format: "%04x", address)): \(data.map { $0 == 0 ? "      " : String(format: "%05d ", $0) }.joined(separator: " ")) ")
                print("")
                store[address] = data
            }
        }

        for address in stride(from: 0x000, to: 0xFFFF, by: stripesize)
        {
            try await readData(from: address)
        }

        for _ in 0 ... 20
        {
            print("WRAPAROUND")

            for address in store.keys
            {
                try await readData(from: address)
            }
        }
    }

    func testBrokenJSONDefinition() async throws
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

        do
        {
            let definitions = try ModbusDefinition.read(from: url)
            XCTFail("Expected duplicateModbusAddressDefined error, got \(definitions)")
        }
        catch
        {}
    }

    func testBitMapValues() async throws
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

        do
        {
            let definitions = try ModbusDefinition.read(from: url)
            print("definitions:\(definitions.json)")
        }
        catch
        {
            XCTFail("Expected decoding working got error:\(error)")
        }
    }

    func testDecodingInt8() async throws
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

        do
        {
            let definitions = try ModbusDefinition.read(from: url)
            print("definitions:\(definitions.json)")
        }
        catch
        {
            XCTFail("Expected decoding working got error:\(error)")
        }

        let modbusValue = ModbusValue(address: 1, value: .uint32(0b1111111))

        JLog.debug("modbusValue:\(modbusValue.json)")
    }
}
