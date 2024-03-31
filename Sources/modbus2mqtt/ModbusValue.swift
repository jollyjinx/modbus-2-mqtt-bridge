//
//  ModbusValue.swift
//

import Foundation
import JLog

public enum ModbusType: Equatable
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

    case string(String)
}

extension ModbusType: Decodable {}

public struct ModbusValue: Equatable
{
    let address: Int
    let value: ModbusType
}

public extension ModbusValue
{
    var topic: String { ModbusDefinition.modbusDefinitions[address]?.topic ?? "address/\(address)" }
    var mqttVisibility: MQTTVisibilty { ModbusDefinition.modbusDefinitions[address]?.mqtt ?? .invisible }
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
            case let .string(value): return String(value)
        }
    }
}

extension ModbusValue: Encodable
{
    public var json: String
    {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .sortedKeys
        let jsonData = try! jsonEncoder.encode(self)
        return String(data: jsonData, encoding: .utf8)!
    }

    public func encode(to encoder: Encoder) throws
    {
        let mbd = ModbusDefinition.modbusDefinitions[address]!

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
            let string = map[stringValue] ?? stringValue
            try container.encode(string, forKey: .value)

            switch value
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
                case let .string(value): try container.encode(value, forKey: .rawValue)
            }
        }
        else
        {
            switch value
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
                case let .string(value): try container.encode(value, forKey: .value)
            }
        }
    }
}
