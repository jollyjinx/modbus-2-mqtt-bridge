//
//  Created by Patrick Stein on 18.03.22.
//

import Foundation


enum MQTTCommandValue:Encodable,Decodable,Hashable,Equatable
{
    case string(String)
    case decimal(Decimal)
    case bool(Bool)

    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()

        switch self
        {
            case .string(let value):    try container.encode(value)
            case .decimal(let value):   try container.encode(value)
            case .bool(let value):      try container.encode(value)
        }
    }

    public init(from decoder: Decoder) throws
    {
        let container = try decoder.singleValueContainer()
                if let value = try? container.decode(Bool.self)     { self = .bool(value)       }
        else    if let value = try? container.decode(String.self)   { self = .string(value)     }
        else    { let value = try container.decode(Decimal.self)    ; self = .decimal(value)    }
    }
}
struct MQTTRequest:Encodable,Decodable,Hashable,Equatable
{
    let date:Date
    let id:UUID
    let topic:String
    let value:MQTTCommandValue

    static func ==(lhs:Self,rhs:Self) -> Bool
    {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher)
    {
        return id.hash(into: &hasher)
    }
}

struct MQTTResponse:Encodable,Decodable
{
    let date:Date
    let id:UUID
    let success:Bool
    let error:String?
}
