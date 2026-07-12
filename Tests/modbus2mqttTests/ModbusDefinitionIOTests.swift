import Foundation
import SwiftLibModbus2MQTT
import Testing

struct ModbusDefinitionIOTests
{
    @Test
    func convertsBooleanStringsToCoilValues() throws
    {
        let definition = try makeDefinition(valueType: "bool", modbusType: "coil")

        #expect(try definition.writeValue(from: .string("TRUE")) == .coil(true))
        #expect(try definition.writeValue(from: .string("false")) == .coil(false))
        #expect(throws: ModbusDefinitionIOError.valueTypeConversionError)
        {
            try definition.writeValue(from: .string("yes"))
        }
    }

    @Test
    func convertsMappedAndFactoredUInt16Values() throws
    {
        let definition = try makeDefinition(valueType: "uint16",
                                            factor: 0.1,
                                            map: ["10": "ACTIVE"])

        #expect(try definition.writeValue(from: .string("ACTIVE")) == .uint16(100))
    }

    @Test
    func convertsFactoredSignedValues() throws
    {
        let definition = try makeDefinition(valueType: "int16", factor: 0.1)

        #expect(try definition.writeValue(from: .decimal(-1.5)) == .int16(-15))
    }

    @Test
    func rejectsUnsupportedOrUnrepresentableWrites() throws
    {
        let unsignedDefinition = try makeDefinition(valueType: "uint16")
        let unsupportedDefinition = try makeDefinition(valueType: "uint32")

        #expect(throws: ModbusDefinitionIOError.valueTypeConversionError)
        {
            try unsignedDefinition.writeValue(from: .decimal(-1))
        }
        #expect(throws: ModbusDefinitionIOError.attributeTypeCurrentlyNotSupported)
        {
            try unsupportedDefinition.writeValue(from: .decimal(1))
        }
    }

    @Test
    func requiresLengthForStringWrites() throws
    {
        let missingLengthDefinition = try makeDefinition(valueType: "string")
        let definition = try makeDefinition(valueType: "string", length: 8)

        #expect(throws: ModbusDefinitionIOError.missingLength)
        {
            try missingLengthDefinition.writeValue(from: .string("value"))
        }
        #expect(try definition.writeValue(from: .string("value")) == .asciiString("value", count: 8))
    }

    private func makeDefinition(valueType: String,
                                modbusType: String = "holding",
                                factor: Decimal? = nil,
                                map: [String: String]? = nil,
                                length: Int? = nil) throws -> ModbusDefinition
    {
        var object: [String: Any] = [
            "address": 1,
            "modbustype": modbusType,
            "modbusaccess": "readwrite",
            "valuetype": valueType,
            "mqtt": "visible",
            "interval": 10,
            "topic": "test/value",
            "title": "Test value",
        ]
        if let factor
        {
            object["factor"] = NSDecimalNumber(decimal: factor)
        }
        if let map
        {
            object["map"] = map
        }
        if let length
        {
            object["length"] = length
        }

        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(ModbusDefinition.self, from: data)
    }
}
