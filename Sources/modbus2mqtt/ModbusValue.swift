//
//  Created by Patrick Stein on 18.03.22.
//

import Foundation
import JLog


public enum ModbusType:Equatable
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
extension ModbusType:Decodable {}


public struct ModbusValue:Equatable
{
    let address:Int
    let value:ModbusType
}

extension ModbusValue
{
    public var topic:String                 { ModbusDefinition.modbusDefinitions[address]?.topic   ?? "address/\(address)" }
    public var mqttVisibility:MQTTVisibilty { ModbusDefinition.modbusDefinitions[address]?.mqtt ?? .invisible }
}


extension ModbusValue:Encodable
{
    public var json:String
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
            topic
        }
        var container = encoder.container(keyedBy:CodingKeys.self)

        try container.encode(mbd.address ,forKey:.address)
        
        if mbd.unit != nil
        {
            try container.encode(mbd.unit    ,forKey:.unit)
        }
        try container.encode(mbd.title   ,forKey:.title)

        switch value
        {
            case .bool(let value):      try container.encode(value,forKey:.value)

            case .uint8(let value):    try container.encode( mbd.hasFactor ? Decimal(value) / mbd.factor! : Decimal(value),forKey:.value)
            case .int8(let value):     try container.encode( mbd.hasFactor ? Decimal(value) / mbd.factor! : Decimal(value),forKey:.value)
            
            case .uint16(let value):    try container.encode( mbd.hasFactor ? Decimal(value) / mbd.factor! : Decimal(value),forKey:.value)
            case .int16(let value):     try container.encode( mbd.hasFactor ? Decimal(value) / mbd.factor! : Decimal(value),forKey:.value)

            case .uint32(let value):    if value == UInt32.max
                                        {
                                            let string:String? = nil
                                            try container.encode(string ,forKey:.value)
                                        }
                                        else
                                        {
                                            try container.encode( mbd.hasFactor ? Decimal(value) / mbd.factor! : Decimal(value),forKey:.value)
                                        }
            case .int32(let value):     if value == Int32.min
                                        {
                                            let string:String? = nil
                                            try container.encode(string ,forKey:.value)
                                        }
                                        else
                                        {
                                            try container.encode( mbd.hasFactor ? Decimal(value) / mbd.factor! : Decimal(value),forKey:.value)
                                        }


            case .uint64(let value):    if value == UInt64.max
                                        {
                                            let string:String? = nil
                                            try container.encode(string ,forKey:.value)
                                        }
                                        else
                                        {
                                            try container.encode( mbd.hasFactor ? Decimal(value) / mbd.factor! : Decimal(value),forKey:.value)
                                        }
            case .int64(let value):     if value == Int64.min
                                        {
                                            let string:String? = nil
                                            try container.encode(string ,forKey:.value)
                                        }
                                        else
                                        {
                                            try container.encode( mbd.hasFactor ? Decimal(value) / mbd.factor! : Decimal(value),forKey:.value)
                                        }
            case .string(let value):    try container.encode(value,forKey:.value)
        }
    }
}
