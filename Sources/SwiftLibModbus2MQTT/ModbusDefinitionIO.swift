import Foundation
import SwiftLibModbus

public enum ModbusDefinitionIOError: Error, Equatable, Sendable
{
    case attributeTypeCurrentlyNotSupported
    case valueTypeConversionError
    case missingLength
    case emptyReadResult
}

public enum ModbusWriteValue: Equatable, Sendable
{
    case coil(Bool)
    case asciiString(String, count: Int)
    case uint16(UInt16)
    case int16(Int16)
}

public extension ModbusDefinition
{
    func writeValue(from commandValue: MQTTCommandValue) throws -> ModbusWriteValue
    {
        let convertedValue = try convertedCommandValue(from: commandValue)

        switch (valuetype, convertedValue)
        {
            case let (.bool, .bool(value)):
                guard modbustype == .coil
                else { throw ModbusDefinitionIOError.attributeTypeCurrentlyNotSupported }
                return .coil(value)

            case let (.string, .string(value)):
                guard let length
                else { throw ModbusDefinitionIOError.missingLength }
                return .asciiString(value, count: length)

            case let (.uint16, .decimal(value)):
                let factored = hasFactor ? value / factor! : value
                guard let integerValue = UInt16(factored.description)
                else { throw ModbusDefinitionIOError.valueTypeConversionError }
                return .uint16(integerValue)

            case let (.int16, .decimal(value)):
                let factored = hasFactor ? value / factor! : value
                guard let integerValue = Int16(factored.description)
                else { throw ModbusDefinitionIOError.valueTypeConversionError }
                return .int16(integerValue)

            default:
                throw ModbusDefinitionIOError.attributeTypeCurrentlyNotSupported
        }
    }

    private func convertedCommandValue(from commandValue: MQTTCommandValue) throws -> MQTTCommandValue
    {
        switch (valuetype, commandValue)
        {
            case let (.bool, .string(value)):
                switch value.lowercased()
                {
                    case "true": return .bool(true)
                    case "false": return .bool(false)
                    default: throw ModbusDefinitionIOError.valueTypeConversionError
                }

            case let (.uint16, .string(value)),
                 let (.int16, .string(value)):
                guard let map,
                      let mappedValue = map.first(where: { $0.value == value })?.key
                else
                {
                    throw ModbusDefinitionIOError.attributeTypeCurrentlyNotSupported
                }
                guard let decimalValue = Decimal(string: mappedValue)
                else { throw ModbusDefinitionIOError.valueTypeConversionError }
                return .decimal(decimalValue)

            default:
                return commandValue
        }
    }
}

public extension ModbusDevice
{
    func read(definition: ModbusDefinition, deviceAddress: UInt16) async throws -> ModbusValue
    {
        let value: ModbusType
        let endianness = definition.endianness ?? .bigEndian

        switch definition.valuetype
        {
            case .bool:
                let values = try await readInputBitsFrom(startAddress: definition.address,
                                                         count: 1,
                                                         type: definition.modbustype,
                                                         deviceAddress: deviceAddress)
                value = .bool(try first(values))

            case .uint8:
                let values: [UInt8] = try await readRegisters(from: definition.address, count: 1, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .uint8(try first(values))

            case .int8:
                let values: [Int8] = try await readRegisters(from: definition.address, count: 1, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .int8(try first(values))

            case .uint16:
                let values: [UInt16] = try await readRegisters(from: definition.address, count: 1, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .uint16(try first(values))

            case .int16:
                let values: [Int16] = try await readRegisters(from: definition.address, count: 1, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .int16(try first(values))

            case .uint32:
                let values: [UInt32] = try await readRegisters(from: definition.address, count: 1, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .uint32(try first(values))

            case .int32:
                let values: [Int32] = try await readRegisters(from: definition.address, count: 1, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .int32(try first(values))

            case .uint64:
                let values: [UInt64] = try await readRegisters(from: definition.address, count: 1, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .uint64(try first(values))

            case .int64:
                let values: [Int64] = try await readRegisters(from: definition.address, count: 1, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .int64(try first(values))

            case .float32:
                let values: [Float32] = try await readRegisters(from: definition.address, count: 1, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .float32(try first(values))

            case .string:
                guard let length = definition.length
                else { throw ModbusDefinitionIOError.missingLength }
                value = .string(try await readASCIIString(from: definition.address, count: length, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress))

            case .ipv4address:
                let values: [UInt8] = try await readRegisters(from: definition.address, count: 4, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .string(values.map(String.init).joined(separator: "."))

            case .ipv4address16:
                let values: [UInt16] = try await readRegisters(from: definition.address, count: 4, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .string(values.map(String.init).joined(separator: "."))

            case .macaddress:
                guard let length = definition.length
                else { throw ModbusDefinitionIOError.missingLength }
                let values: [UInt8] = try await readRegisters(from: definition.address, count: length, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .string(values.map { String(format: "%02X", $0) }.joined(separator: ":"))

            case .hexstring:
                guard let length = definition.length
                else { throw ModbusDefinitionIOError.missingLength }
                let values: [UInt8] = try await readRegisters(from: definition.address, count: length, type: definition.modbustype, endianness: endianness, deviceAddress: deviceAddress)
                value = .string(values.map { String(format: "%02X", $0) }.joined())
        }

        return ModbusValue(address: definition.address, value: value)
    }

    func write(_ commandValue: MQTTCommandValue,
               definition: ModbusDefinition,
               deviceAddress: UInt16) async throws
    {
        switch try definition.writeValue(from: commandValue)
        {
            case let .coil(value):
                try await writeInputCoil(startAddress: definition.address, value: value, deviceAddress: deviceAddress)

            case let .asciiString(value, count):
                try await writeASCIIString(start: definition.address, count: count, string: value, deviceAddress: deviceAddress)

            case let .uint16(value):
                try await writeRegisters(to: definition.address, arrayToWrite: [value], endianness: definition.endianness ?? .bigEndian, deviceAddress: deviceAddress)

            case let .int16(value):
                try await writeRegisters(to: definition.address, arrayToWrite: [value], endianness: definition.endianness ?? .bigEndian, deviceAddress: deviceAddress)
        }
    }

    private func first<T>(_ values: [T]) throws -> T
    {
        guard let value = values.first
        else { throw ModbusDefinitionIOError.emptyReadResult }
        return value
    }
}
