//
//  ModbusValue.swift
//

import Foundation
import JLog

public enum ModbusType: Equatable, Sendable
{
    case bool(Bool)

    case uint8(UInt8)
    case uint16(UInt16)
    case uint32(UInt32)
    case uint64(UInt64)
    case int8(Int8)
    case int16(Int16)
    case int32(Int32)
    case int64(Int64)
    case float32(Float32)
    case decimal(Decimal)

    case string(String)
}

extension ModbusType: Decodable {}

public struct ModbusValue: Equatable, Sendable
{
    public let address: Int
    public let value: ModbusType

    public init(address: Int, value: ModbusType)
    {
        self.address = address
        self.value = value
    }
}

public extension ModbusValue
{
    func applyingResolution(using definition: ModbusDefinition) -> ModbusValue
    {
        guard case let .float32(value) = value,
              let resolution = definition.floatResolution,
              let decimalValue = Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX"))
        else
        {
            return self
        }

        var quotient = decimalValue / resolution
        var roundedQuotient = Decimal()
        NSDecimalRound(&roundedQuotient, &quotient, 0, .plain)

        return ModbusValue(address: address, value: .decimal(roundedQuotient * resolution))
    }

    func topic(using definition: ModbusDefinition) -> String
    {
        definition.topic
    }

    func mqttVisibility(using definition: ModbusDefinition) -> MQTTVisibilty
    {
        definition.mqtt
    }

    var stringValue: String
    {
        switch value
        {
            case let .bool(value): return String(value)

            case let .uint8(value): return String(value)

            case let .int8(value): return String(value)

            case let .uint16(value): return String(value)

            case let .int16(value): return String(value)

            case let .uint32(value): return String(value)

            case let .int32(value): return String(value)

            case let .uint64(value): return String(value)

            case let .int64(value): return String(value)

            case let .float32(value): return String(value)

            case let .decimal(value): return String(describing: value)

            case let .string(value): return String(value)
        }
    }
}

public extension ModbusValue
{
    func json(using definition: ModbusDefinition) throws -> String
    {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .sortedKeys
        let jsonData = try jsonEncoder.encode(ModbusValuePayload(value: applyingResolution(using: definition), definition: definition))
        guard let json = String(data: jsonData, encoding: .utf8)
        else
        {
            throw EncodingError.invalidValue(jsonData, .init(codingPath: [], debugDescription: "Encoded Modbus payload is not valid UTF-8"))
        }
        return json
    }
}

private struct ModbusValuePayload: Encodable
{
    let value: ModbusValue
    let definition: ModbusDefinition

    func encode(to encoder: Encoder) throws
    {
        let mbd = definition

        enum CodingKeys: String, CodingKey
        {
            case address,
                 unit,
                 title,
                 value,
                 rawValue,
                 topic,
                 bits
        }
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(mbd.address, forKey: .address)

        if mbd.unit != nil
        {
            try container.encode(mbd.unit, forKey: .unit)
        }
        try container.encode(mbd.title, forKey: .title)

        if let map = mbd.map
        {
            let string = map[value.stringValue] ?? value.stringValue
            try container.encode(string, forKey: .value)

            switch value.value
            {
                case let .bool(value): try container.encode(value, forKey: .rawValue)

                case let .uint8(value): try container.encode(value, forKey: .rawValue)

                case let .int8(value): try container.encode(value, forKey: .rawValue)

                case let .uint16(value): try container.encode(value, forKey: .rawValue)

                case let .int16(value): try container.encode(value, forKey: .rawValue)

                case let .uint32(value): try container.encode(value, forKey: .rawValue)

                case let .int32(value): try container.encode(value, forKey: .rawValue)

                case let .uint64(value): try container.encode(value, forKey: .rawValue)

                case let .int64(value): try container.encode(value, forKey: .rawValue)

                case let .float32(value): try container.encode(value, forKey: .rawValue)

                case let .decimal(value): try container.encode(value, forKey: .rawValue)

                case let .string(value): try container.encode(value, forKey: .rawValue)
            }
        }
        else
        {
            switch value.value
            {
                case let .bool(value): try container.encode(value, forKey: .value)

                case let .uint8(value): try container.encode(mbd.hasFactor ? Decimal(value) * mbd.factor! : Decimal(value), forKey: .value)
                    if let dictionary = mbd.bits?.dictionary(for: UInt64(value))
                    {
                        try container.encode(dictionary, forKey: .bits)
                    }

                case let .int8(value): try container.encode(mbd.hasFactor ? Decimal(value) * mbd.factor! : Decimal(value), forKey: .value)

                case let .uint16(value):
                    if value == UInt16.max
                    {
                        let string: String? = nil
                        try container.encode(string, forKey: .value)
                    }
                    else
                    {
                        try container.encode(mbd.hasFactor ? Decimal(value) * mbd.factor! : Decimal(value), forKey: .value)
                    }
                    if let dictionary = mbd.bits?.dictionary(for: UInt64(value))
                    {
                        try container.encode(dictionary, forKey: .bits)
                    }

                case let .int16(value):
                    if value == Int16.min
                    {
                        let string: String? = nil
                        try container.encode(string, forKey: .value)
                    }
                    else
                    {
                        try container.encode(mbd.hasFactor ? Decimal(value) * mbd.factor! : Decimal(value), forKey: .value)
                    }

                case let .uint32(value):
                    if value == UInt32.max
                    {
                        let string: String? = nil
                        try container.encode(string, forKey: .value)
                    }
                    else
                    {
                        try container.encode(mbd.hasFactor ? Decimal(value) * mbd.factor! : Decimal(value), forKey: .value)
                    }
                    if let dictionary = mbd.bits?.dictionary(for: UInt64(value))
                    {
                        try container.encode(dictionary, forKey: .bits)
                    }

                case let .int32(value):
                    if value == Int32.min
                    {
                        let string: String? = nil
                        try container.encode(string, forKey: .value)
                    }
                    else
                    {
                        try container.encode(mbd.hasFactor ? Decimal(value) * mbd.factor! : Decimal(value), forKey: .value)
                    }

                case let .uint64(value):
                    if value == UInt64.max
                    {
                        let string: String? = nil
                        try container.encode(string, forKey: .value)
                    }
                    else
                    {
                        try container.encode(mbd.hasFactor ? Decimal(value) * mbd.factor! : Decimal(value), forKey: .value)
                    }
                    if let dictionary = mbd.bits?.dictionary(for: UInt64(value))
                    {
                        try container.encode(dictionary, forKey: .bits)
                    }

                case let .int64(value):
                    if value == Int64.min
                    {
                        let string: String? = nil
                        try container.encode(string, forKey: .value)
                    }
                    else
                    {
                        try container.encode(mbd.hasFactor ? Decimal(value) * mbd.factor! : Decimal(value), forKey: .value)
                    }

                case let .float32(value): try container.encode(value, forKey: .value)

                case let .decimal(value): try container.encode(value, forKey: .value)

                case let .string(value): try container.encode(value, forKey: .value)
            }
        }
    }
}
