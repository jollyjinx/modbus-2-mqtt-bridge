//
//  MQTTRequestResponse.swift
//

import Foundation

public enum MQTTCommandValue: Hashable, Equatable
{
    case string(String)
    case decimal(Decimal)
    case bool(Bool)

    public init(_ value: String) { self = .string(value) }
    public init(_ value: Decimal) { self = .decimal(value) }
    public init(_ value: Bool) { self = .bool(value) }
}

extension MQTTCommandValue: Codable
{
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()

        switch self
        {
            case let .string(value): try container.encode(value)
            case let .decimal(value): try container.encode(value)
            case let .bool(value): try container.encode(value)
        }
    }

    public init(from decoder: Decoder) throws
    {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else { let value = try container.decode(Decimal.self); self = .decimal(value) }
    }
}

public struct MQTTRequest
{
    public let date: Date
    public let id: UUID
    public let topic: String
    public let value: MQTTCommandValue

    public init(date: Date = Date(), id: UUID = UUID(), topic: String, value: MQTTCommandValue)
    {
        self.date = date
        self.id = id
        self.topic = topic
        self.value = value
    }
}

extension MQTTRequest: Codable {}

extension MQTTRequest: Equatable
{
    public static func == (lhs: Self, rhs: Self) -> Bool
    {
        lhs.id == rhs.id
    }
}

extension MQTTRequest: Hashable
{
    public func hash(into hasher: inout Hasher)
    {
        id.hash(into: &hasher)
    }
}

public struct MQTTResponse
{
    public let date: Date
    public let id: UUID
    public let success: Bool
    public let error: String?

    public init(date: Date = Date(), id: UUID, success: Bool, error: String?)
    {
        self.date = date
        self.id = id
        self.success = success
        self.error = error
    }

    public init(request: MQTTRequest, success: Bool, error: String? = nil)
    {
        self.init(date: request.date, id: request.id, success: success, error: error)
    }
}

extension MQTTResponse: Codable {}
