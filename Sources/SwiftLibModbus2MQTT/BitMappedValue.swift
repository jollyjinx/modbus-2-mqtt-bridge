//
//  BitMappedValue.swift
//

import Foundation
import JLog
import RegexBuilder

public struct BitMapKey: Sendable, Hashable
{
    public let lowestBit: UInt8
    public let highestBit: UInt8

    public let bits: UInt64
}

extension BitMapKey: Decodable
{
    public enum BitMapKeyError: Error
    {
        case readKey(String)
    }

    public init(from decoder: any Decoder) throws
    {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        try self.init(text)
    }

    public init(_ text: String) throws
    {
        let bitMapKeyPattern = Regex
        {
            TryCapture
            {
                OneOrMore(.digit)
            } transform: { match in
                UInt8(match)
            }

            Optionally
            {
                "-"
                TryCapture
                {
                    OneOrMore(.digit)
                } transform: { match in
                    UInt8(match)
                }
            }
        }

        guard let match = text.firstMatch(of: bitMapKeyPattern)
        else
        {
            JLog.error("could not read BitMapKey from string:\(text)")
            throw BitMapKeyError.readKey("could not read BitMapKey from string:\(text)")
        }

        lowestBit = match.1
        highestBit = match.2 ?? lowestBit

        guard lowestBit <= highestBit, highestBit < 65
        else
        {
            JLog.error("Invalid BitMapKey Values: \(text)")
            throw BitMapKeyError.readKey("Invalid BitMapKey Values: \(text)")
        }

        var bitmap: UInt64 = 0

        for bit in lowestBit ... highestBit
        {
            bitmap = bitmap | (1 << bit)
        }
        bits = bitmap
    }
}

extension BitMapKey: Encodable
{
    public func encode(to encoder: any Encoder) throws
    {
        var container = encoder.singleValueContainer()

        let string = lowestBit == highestBit ? String(lowestBit) : "\(lowestBit)-\(highestBit)"
        try container.encode(string)
    }

    public var description: String
    {
        return lowestBit == highestBit ? String(lowestBit) : "\(lowestBit)-\(highestBit)"
    }
}

public struct BitMapInfo: Codable, Sendable
{
    public let name: String
}

public struct BitMapValues: Sendable
{
    public typealias BitMapValues = [BitMapKey: BitMapInfo]

    public var values: BitMapValues

    public enum BitMapValue: Encodable
    {
        case bool(Bool)
        case uint64(UInt64)

        public func encode(to encoder: any Encoder) throws
        {
            var container = encoder.singleValueContainer()
            switch self
            {
                case let .bool(value): try container.encode(value)
                case let .uint64(value): try container.encode(value)
            }
        }
    }

    public func dictionary(for withValue: UInt64) -> [String: BitMapValue]
    {
        var bitmapDictionary = [String: BitMapValue]()

        for value in values
        {
            let key = value.key
            let info = value.value

            let maskedValue = key.bits & withValue
            let rightShift = UInt64(key.lowestBit)
            let value = maskedValue >> rightShift

            bitmapDictionary[info.name] = key.lowestBit == key.highestBit ? .bool(value != 0) : .uint64(value)
        }
        return bitmapDictionary
    }
}

extension BitMapValues: Codable
{
    typealias SimpleDictonary = [String: BitMapInfo]

    public init(from decoder: any Decoder) throws
    {
        let container = try decoder.singleValueContainer()

        let dictionary = try container.decode(SimpleDictonary.self)
        let tuples = try dictionary.map
        { (key: String, value: BitMapInfo) in
            JLog.trace("key:\(key) value:\(value)")

            return try (BitMapKey(key), value)
        }
        values = Dictionary(uniqueKeysWithValues: tuples)
    }

    public func encode(to encoder: any Encoder) throws
    {
        let tuples = values.map
        { (key: BitMapKey, value: BitMapInfo) in
            return (key.description, value)
        }
        let simpleDictionary = Dictionary(uniqueKeysWithValues: tuples)

        try simpleDictionary.encode(to: encoder)
    }
}
