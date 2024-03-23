//
//  modbus2mqttTests.swift
//

import SwiftLibModbus
import XCTest

@testable import modbus2mqtt

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
        {

        }
    }
}
