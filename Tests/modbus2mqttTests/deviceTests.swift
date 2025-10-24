//
//  deviceTests.swift
//

import Foundation
import JLog
import SwiftLibModbus
import SwiftLibModbus2MQTT
import Testing

@Suite("Device Tests")
struct deviceTests
{
    @Test(.disabled("Only works when attached"))
    func reverseEngineerHM310T() async throws
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

//    @Test(.disabled("Only works when attached"))
    func float32PhoenixController() async throws
    {
        // Prints out modbus address ranges and compares them to the last time

        let modbusDevice = try ModbusDevice(networkAddress: "10.98.16.12", port: 502, deviceAddress: 180)

        let startAddress: Float32 = 352
        let endAddress: Float32 = 358
        let stridesize: Int = MemoryLayout<Float32>.size / MemoryLayout<UInt16>.size
        let count = Int(endAddress - startAddress) / stridesize

        var store = [Int: [Float32]]()
        let emptyline = [Float32](repeating: 0, count: count)

        func readData(from address: Float32) async throws
        {
            let data: [Float32] = try await modbusDevice.readRegisters(from: startAddress, count: count, type: .holding)

            let previous: [Float32] = store[address] ?? emptyline

            if data != previous
            {
                print("\(String(format: "%04x", address)): \(data.map { $0 == 0 ? "  -   " : String(format: "%04x  ", $0) }.joined(separator: " ")) ")
                print("\(String(format: "%04x", address)): \(data.map { $0 == 0 ? "      " : String(format: "%05d ", $0) }.joined(separator: " ")) ")
                print("")
                store[address] = data
            }
        }

        for address in stride(from: 352, to: 358, by: stripesize)
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
}
