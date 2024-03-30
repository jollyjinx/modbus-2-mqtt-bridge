//
//  File.swift
//  
//
//  Created by Patrick Stein on 30.03.24.
//

import Foundation
import RegexBuilder


struct BitMapKey: Sendable, Hashable
{
    let lowestBit : UInt8
    let highestBit : UInt8

    let bits:UInt64
}

extension BitMapKey: Decodable
{
    enum BitMapKeyError:Error
    {
        case readKey(String)
    }

    public init(from decoder: any Decoder) throws
    {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        try self.init(text)
    }

    public init(_ text:String) throws
    {
        let bitMapKeyPattern = Regex {
            TryCapture {
                OneOrMore(.digit)
            }transform: { match in
                UInt8(match)
            }

            Optionally {
                        "-"
                        TryCapture {
                            OneOrMore(.digit)
                        }transform: { match in
                            UInt8(match)
                        }
            }
        }

        guard let match = text.firstMatch(of: bitMapKeyPattern)
        else
        {
            print("could not read BitMapKey from string:\(text)")
            throw BitMapKeyError.readKey("could not read BitMapKey from string:\(text)")
        }

        lowestBit = match.1
        highestBit = match.2 ?? lowestBit

        guard lowestBit <= highestBit , highestBit < 65 else
        {
            print("Invalid BitMapKey Values: \(text)")
            throw BitMapKeyError.readKey("Invalid BitMapKey Values: \(text)")
        }

        var bitmap:UInt64 = 0

        for bit in lowestBit...highestBit
        {
            bitmap = bitmap | (1 << bit)
        }
        bits =  bitmap
    }
}

extension BitMapKey : Encodable
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

struct BitMapInfo : Codable
{
    let name:String
    let mqttPath:String
}

struct BitMapValues
{
    typealias BitMapValues = [BitMapKey:BitMapInfo]

    var values:BitMapValues
}

extension BitMapValues: Codable
{
    typealias SimpleDictonary = Dictionary<String,BitMapInfo>

    init(from decoder: any Decoder) throws
    {
        let container = try decoder.singleValueContainer()

        let dictionary = try container.decode(SimpleDictonary.self)
        let tuples = try dictionary.map { (key: String, value: BitMapInfo) in
        print("key:\(key) value:\(value)")

            return ( try BitMapKey(key), value )
        }
        values = Dictionary(uniqueKeysWithValues:tuples)
    }

    func encode(to encoder: any Encoder) throws
    {
        let tuples = values.map { (key: BitMapKey, value: BitMapInfo) in
            return (key.description, value)
        }
        let simpleDictionary = Dictionary(uniqueKeysWithValues: tuples)

        try simpleDictionary.encode(to:encoder)
    }
}
