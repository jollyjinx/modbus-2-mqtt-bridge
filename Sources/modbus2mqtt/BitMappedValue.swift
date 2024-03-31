//
//  BitMappedValue.swift
//

import Foundation
import JLog
import RegexBuilder

struct BitMapKey: Sendable, Hashable
{
    let lowestBit: UInt8
    let highestBit: UInt8

    let bits: UInt64
}

extension BitMapKey: Decodable
{
    enum BitMapKeyError: Error
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
    func encode(to encoder: any Encoder) throws
    {
        var container = encoder.singleValueContainer()

        let string = lowestBit == highestBit ? String(lowestBit) : "\(lowestBit)-\(highestBit)"
        try container.encode(string)
    }

    var description: String
    {
        return lowestBit == highestBit ? String(lowestBit) : "\(lowestBit)-\(highestBit)"
    }
}

struct BitMapInfo: Codable
{
    let name: String
}

struct BitMapValues
{
    typealias BitMapValues = [BitMapKey: BitMapInfo]

    var values: BitMapValues

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

    func dictionary(for withValue: UInt64) -> [String: BitMapValue]
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

    init(from decoder: any Decoder) throws
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

    func encode(to encoder: any Encoder) throws
    {
        let tuples = values.map
        { (key: BitMapKey, value: BitMapInfo) in
            return (key.description, value)
        }
        let simpleDictionary = Dictionary(uniqueKeysWithValues: tuples)

        try simpleDictionary.encode(to: encoder)
    }
}
