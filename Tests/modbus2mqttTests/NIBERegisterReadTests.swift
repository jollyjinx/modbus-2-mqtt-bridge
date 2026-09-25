import Foundation
import SwiftLibModbus
import SwiftLibModbus2MQTT
import Testing

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

struct NIBERegisterReadTests
{
    private static let writeCases: [(Int, MQTTCommandValue, [UInt16])] = [
        (11, .decimal(Decimal(string: "-12.3")!), [0xFF85, 0xFFFF]),
        (26, .decimal(7), [7]),
        (30, .decimal(-5), [0xFFFB]),
        (34, .decimal(Decimal(string: "21.5")!), [215]),
        (56, .string("LARGE"), [2]),
        (92, .decimal(Decimal(string: "1.5")!), [15]),
        (183, .decimal(Decimal(string: "18.5")!), [185]),
        (216, .string("DEFROST"), [15]),
        (237, .string("MANUAL"), [1]),
        (783, .string("AUTO"), [0]),
        (5009, .decimal(Decimal(string: "32.5")!), [325]),
    ]

    @Test(arguments: writeCases)
    func writesDocumentedHoldingSettings(address: Int, command: MQTTCommandValue, words: [UInt16]) async throws
    {
        let definitions = try ModbusDefinition.readByRegister(from: URL(fileURLWithPath: "DeviceDefinitions/nibe.S2125-SMO-S40.json"))
        let definition = try #require(definitions[ModbusRegisterKey(type: .holding, address: address)])
        #expect(definition.modbusaccess == .readwrite)
        let server = try RegisterServer()
        defer { server.closeSocket() }
        async let response: Void = server.reply(address: address, words: words, function: 16)
        let device = try ModbusDevice(networkAddress: "127.0.0.1", port: server.port, deviceAddress: 1)
        try await device.write(command, definition: definition, deviceAddress: 1)
        try await response

        // The same R/W definition must decode its corresponding FC03 response.
        let payload = try await readPayload(definition: definition, words: words)
        switch command
        {
            case let .decimal(value):
                #expect(payload["value"] as? Double == NSDecimalNumber(decimal: value).doubleValue)
            case let .string(value):
                #expect(payload["value"] as? String == value)
            default:
                Issue.record("Unexpected fixture command")
        }
    }

    @Test
    func overlappingAreasLoadAndScheduleIndependently() throws
    {
        let url = URL(fileURLWithPath: "DeviceDefinitions/nibe.S2125-SMO-S40.json")
        var definitions = try ModbusDefinition.readByRegister(from: url)
        let input = ModbusRegisterKey(type: .input, address: 26)
        let holding = ModbusRegisterKey(type: .holding, address: 26)
        #expect(definitions[input]?.topic == "system/roomtemperature")
        #expect(definitions[holding]?.topic == "settings/heatingcurve")
        definitions[holding]?.nextReadDate = .distantFuture
        #expect(definitions[input]?.nextReadDate == .distantPast)
        #expect(definitions[holding]?.nextReadDate == .distantFuture)
        // Existing address-only callers get an explicit error rather than silent data loss.
        #expect(throws: (any Error).self) { try ModbusDefinition.read(from: url) }
        let writable = definitions.values.filter { $0.modbusaccess == .readwrite }
        #expect(writable.count == 36)
        for definition in writable
        {
            #expect(definition.modbustype == .holding)
            _ = try definition.writeValue(from: .decimal(0))
        }
    }

    private static let registerCases: [(Int, [UInt16], Double)] = [
        (1489, [UInt16(1_234), 0], 1_234.0),
        (1489, [UInt16(0x5678), 0x1234], 305_419_896.0),
        (1491, [UInt16(6), 0], 0.6),
        (1493, [UInt16(15), 0], 1.5),
        (1583, [UInt16(1), 0], 0.1),
        (1585, [UInt16(324), 0], 32.4),
        (1805, [UInt16(1)], 1.0),
        (400, [UInt16(42)], 42.0),
        (1975, [UInt16(40_000)], 40_000.0),
        (1478, [UInt16(bitPattern: -125)], -12.5),
        (26, [UInt16(215)], 21.5),
        (39, [UInt16(350)], 35.0),
        (88, [UInt16(285)], 28.5),
        (401, [UInt16(850)], 850.0),
        (551, [UInt16(423)], 42.3),
        (552, [UInt16(215)], 21.5),
        (555, [UInt16(bitPattern: -25)], -2.5),
        (1066, [UInt16(1)], 1.0),
        (1475, [UInt16(300)], 30.0),
        (1636, [UInt16(75)], 75.0),
        (2196, [UInt16(1)], 1.0),
    ]

    @Test(arguments: registerCases)
    func readsNIBERegistersThroughDefinition(address: Int, words: [UInt16], expected: Double) async throws
    {
        let definitions = try ModbusDefinition.readByRegister(from: URL(fileURLWithPath: "DeviceDefinitions/nibe.S2125-SMO-S40.json"))
        let definition = try #require(definitions[ModbusRegisterKey(type: .input, address: address)])
        let payload = try await readPayload(definition: definition, words: words)
        let expectedStates = [1805: "ACTIVE", 1066: "ON", 2196: "HOT_WATER"]
        if let expectedState = expectedStates[address]
        {
            #expect(payload["value"] as? String == expectedState)
            #expect(payload["rawValue"] as? Double == expected)
        }
        else
        {
            #expect(payload["value"] as? Double == expected)
        }
    }

    @Test(arguments: ["bigEndian", "littleEndian"])
    func unsignedByteUsesLowRegisterByte(endianness: String) async throws
    {
        let json = """
        {"address":1,"modbustype":"input","modbusaccess":"read","valuetype":"uint8",
         "endianness":"\(endianness)","mqtt":"visible","interval":10,"topic":"test","title":"test"}
        """
        let definition = try JSONDecoder().decode(ModbusDefinition.self, from: Data(json.utf8))
        let payload = try await readPayload(definition: definition, words: [0x00FE])
        #expect(payload["value"] as? Double == 254)
    }

    @Test(arguments: ["bigEndian", "littleEndian"])
    func signedByteUsesLowRegisterByte(endianness: String) async throws
    {
        let json = """
        {"address":1,"modbustype":"input","modbusaccess":"read","valuetype":"int8",
         "endianness":"\(endianness)","mqtt":"visible","interval":10,"topic":"test","title":"test"}
        """
        let definition = try JSONDecoder().decode(ModbusDefinition.self, from: Data(json.utf8))
        let payload = try await readPayload(definition: definition, words: [0x00FB])
        #expect(payload["value"] as? Double == -5)
    }

    private func readPayload(definition: ModbusDefinition, words: [UInt16]) async throws -> [String: Any]
    {
        let server = try RegisterServer()
        defer { server.closeSocket() }
        async let response: Void = server.reply(address: definition.address, words: words, function: definition.modbustype == .holding ? 3 : 4)
        let device = try ModbusDevice(networkAddress: "127.0.0.1", port: server.port, deviceAddress: 1)
        let value = try await device.read(definition: definition, deviceAddress: 1)
        try await response
        return try #require(JSONSerialization.jsonObject(with: Data(value.json(using: definition).utf8)) as? [String: Any])
    }
}

/// One FC03/FC04/FC16 exchange exercises real Modbus requests and wire values.
private struct RegisterServer: Sendable
{
    let descriptor: Int32
    let port: UInt16

    init() throws
    {
#if canImport(Darwin)
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
#else
        let descriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
#endif
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        do
        {
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            let bound = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bound == 0, listen(descriptor, 1) == 0 else { throw POSIXError(.EIO) }
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let named = withUnsafeMutablePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    getsockname(descriptor, $0, &length)
                }
            }
            guard named == 0 else { throw POSIXError(.EIO) }
            self.descriptor = descriptor
            port = UInt16(bigEndian: address.sin_port)
        }
        catch
        {
            _ = close(descriptor)
            throw error
        }
    }

    func closeSocket() { _ = close(descriptor) }

    func reply(address: Int, words: [UInt16], function: UInt8 = 4) async throws
    {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global().async
            {
                do
                {
                    var pending = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
                    guard poll(&pending, 1, 5_000) > 0 else { throw POSIXError(.ETIMEDOUT) }
                    let client = accept(descriptor, nil, nil)
                    guard client >= 0 else { throw POSIXError(.EIO) }
                    defer { _ = close(client) }
                    var timeout = timeval(tv_sec: 5, tv_usec: 0)
                    _ = setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
                    _ = setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
                    var request = [UInt8](repeating: 0, count: 12)
                    var received = 0
                    while received < request.count
                    {
                        let count = request.withUnsafeMutableBytes {
                            recv(client, $0.baseAddress!.advanced(by: received), $0.count - received, 0)
                        }
                        guard count > 0 else { throw POSIXError(.EIO) }
                        received += count
                        if received == 12, request.count == 12
                        {
                            let totalLength = 6 + (Int(request[4]) << 8 | Int(request[5]))
                            guard totalLength >= 12, totalLength <= 260 else { throw POSIXError(.EINVAL) }
                            request.append(contentsOf: repeatElement(0, count: totalLength - 12))
                        }
                    }
                    #expect(request[7] == function)
                    #expect(Int(request[8]) << 8 | Int(request[9]) == address)
                    #expect(Int(request[10]) << 8 | Int(request[11]) == words.count)
                    let data = words.flatMap { [UInt8($0 >> 8), UInt8(truncatingIfNeeded: $0)] }
                    let response: [UInt8]
                    if function == 16
                    {
                        #expect(request[12] == data.count)
                        #expect(Array(request.dropFirst(13)) == data)
                        response = [request[0], request[1], 0, 0, 0, 6, request[6], 16] + Array(request[8...11])
                    }
                    else
                    {
                        response = [request[0], request[1], 0, 0, 0, UInt8(data.count + 3), request[6], function, UInt8(data.count)] + data
                    }
                    var sent = 0
                    while sent < response.count
                    {
                        let count = response.withUnsafeBytes {
                            send(client, $0.baseAddress!.advanced(by: sent), $0.count - sent, 0)
                        }
                        guard count > 0 else { throw POSIXError(.EIO) }
                        sent += count
                    }
                    continuation.resume()
                }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
