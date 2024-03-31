//
//  ModbusDefinition.swift
//

import Foundation
import JLog
import SwiftLibModbus

public enum MQTTVisibilty: String, Encodable, Decodable, Sendable
{
    case invisible, visible, retained
}

typealias ValueMap = [String: String]

struct ModbusDefinition: Encodable, Sendable
{
    enum ModbusAccess: String, Encodable, Decodable
    {
        case read
        case readwrite
        case write
    }

    enum ModbusValueType: String, Encodable, Decodable
    {
        case bool

        case uint8
        case int8
        case uint16
        case int16
        case uint32
        case int32
        case uint64
        case int64

        case string
        case ipv4address
        case macaddress
    }

    let address: Int
    let length: Int?
    let modbustype: ModbusRegisterType
    let modbusaccess: ModbusAccess
    let endianness: ModbusDeviceEndianness?

    let valuetype: ModbusValueType
    let factor: Decimal?
    let unit: String?

    let map: ValueMap?
    let bits: BitMapValues?

    let mqtt: MQTTVisibilty
    let publishalways: Bool?
    let interval: Double
    let topic: String
    let title: String

    var nextReadDate: Date! = .distantPast
}

extension ModbusDefinition: Decodable
{
    enum CodingKeys: String, CodingKey
    {
        case address, length, modbustype, modbusaccess, endianness, valuetype, factor, unit, map, bits, mqtt, publishalways, interval, topic, title, nextReadDate
    }

    public init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let address = try? container.decode(Int.self, forKey: .address)
        {
            self.address = address
        }
        else
        {
            let addressString: String = try container.decode(String.self, forKey: .address)
            JLog.debug("addressString: \(addressString)")

            guard let address = addressString.hasPrefix("0x") ? Int(addressString.dropFirst(2), radix: 16) : Int(addressString)
            else
            {
                throw DecodingError.dataCorruptedError(forKey: .address, in: container, debugDescription: "Could not decode string \(addressString) as Int")
            }
            self.address = address
        }
        JLog.debug("address: \(address)")

        length = try? container.decode(Int.self, forKey: .length)
        modbustype = try container.decode(ModbusRegisterType.self, forKey: .modbustype)
        modbusaccess = try container.decode(ModbusAccess.self, forKey: .modbusaccess)
        endianness = try? container.decode(ModbusDeviceEndianness.self, forKey: .endianness)

        valuetype = try container.decode(ModbusValueType.self, forKey: .valuetype)
        factor = try? container.decode(Decimal.self, forKey: .factor)
        unit = try? container.decode(String.self, forKey: .unit)
        map = try? container.decode(ValueMap.self, forKey: .map)

        bits = try? container.decode(BitMapValues.self, forKey: .bits)

        mqtt = try container.decode(MQTTVisibilty.self, forKey: .mqtt)
        publishalways = try? container.decode(Bool.self, forKey: .publishalways)
        interval = try container.decode(Double.self, forKey: .interval)
        topic = try container.decode(String.self, forKey: .topic)
        title = try container.decode(String.self, forKey: .title)

        nextReadDate = try? container.decode(Date.self, forKey: .nextReadDate)

        JLog.debug("decoded: \(self)")
    }
}

extension ModbusDefinition
{
    enum ModbusDefinitionError: Swift.Error
    {
        case duplicateModbusAddressDefined(ModbusDefinition, ModbusDefinition)
    }

    static func read(from url: URL) throws -> [Int: ModbusDefinition]
    {
        let jsonData = try Data(contentsOf: url)
        var modbusDefinitions = try JSONDecoder().decode([ModbusDefinition].self, from: jsonData)
        modbusDefinitions = modbusDefinitions.map { var mbd = $0; mbd.nextReadDate = .distantPast; return mbd }

        let returnValue = try Dictionary(modbusDefinitions.map { ($0.address, $0) }, uniquingKeysWith: { throw ModbusDefinitionError.duplicateModbusAddressDefined($0, $1) })

        Self.modbusDefinitions = returnValue
        return returnValue
    }

    private static let modbusDefinitionStore = ModbusDefinitionStore()

    static var modbusDefinitions: [Int: ModbusDefinition]
    {
        get { modbusDefinitionStore.definitions }
        set { modbusDefinitionStore.definitions = newValue }
    }
}

extension ModbusDefinition
{
    var hasFactor: Bool { factor != nil && factor! != 0 && factor! != 1 }
}

private final class ModbusDefinitionStore: @unchecked Sendable
{
    let userMutatingLock = DispatchQueue(label: "definitions.lock.queue." + UUID().uuidString)
    private var _modbusDefinitions: [Int: ModbusDefinition] = [:]

    var definitions: [Int: ModbusDefinition]
    {
        get { userMutatingLock.sync { _modbusDefinitions } }
        set { userMutatingLock.sync { _modbusDefinitions = newValue } }
    }

    init()
    {}
}
