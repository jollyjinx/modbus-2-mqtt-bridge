//
//  Created by Patrick Stein on 18.03.22.
//

@preconcurrency import Foundation
import SwiftLibModbus
import JLog


public enum MQTTVisibilty:String,Encodable,Decodable,Sendable
{
    case invisible,visible,retained
}

struct ModbusDefinition:Encodable,Decodable,Sendable
{
    enum ModbusAccess:String,Encodable,Decodable
    {
        case read
        case readwrite
        case write
    }

    enum ModbusValueType:String,Encodable,Decodable
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

    let address:Int
    let length:Int?
    let modbustype:ModbusRegisterType
    let modbusaccess:ModbusAccess
    let endianness:ModbusDeviceEndianness?

    let valuetype:ModbusValueType
    let factor:Decimal?
    let unit:String?

    let mqtt:MQTTVisibilty
    let publishalways:Bool?
    let interval:Double
    let topic:String
    let title:String

    var nextReadDate:Date! = .distantPast
}


extension ModbusDefinition
{
    static func read(from url:URL) throws -> [Int:ModbusDefinition]
    {
        let jsonData = try Data(contentsOf: url)
        var modbusDefinitions = try JSONDecoder().decode([ModbusDefinition].self, from: jsonData)
        modbusDefinitions = modbusDefinitions.map{ var mbd = $0; mbd.nextReadDate = .distantPast; return mbd }

        let returnValue = Dictionary(uniqueKeysWithValues: modbusDefinitions.map { ($0.address, $0) })

        Self.modbusDefinitions = returnValue
        return returnValue
    }

    static var modbusDefinitions:[Int:ModbusDefinition]! = nil
}


extension ModbusDefinition
{
    var hasFactor:Bool { self.factor != nil && self.factor! != 0 && self.factor! != 1 }
}

