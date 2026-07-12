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

    @Test(arguments: [
        (Float32(1_234.3344), Decimal(100), Decimal(1_200)),
        (Float32(1_251), Decimal(100), Decimal(1_300)),
        (Float32(12.345), Decimal(string: "0.01")!, Decimal(string: "12.35")!),
        (Float32(-1_250), Decimal(100), Decimal(-1_300)),
    ])
    func roundsFloatValuesToConfiguredResolution(input: Float32,
                                                  resolution: Decimal,
                                                  expected: Decimal) throws
    {
        let definition = try makeDefinition(valueType: "float32", resolution: resolution)
        let value = ModbusValue(address: 1, value: .float32(input))

        #expect(value.applyingResolution(using: definition).value == .decimal(expected))
    }

    @Test
    func JSONUsesConfiguredFloatResolution() throws
    {
        let definition = try makeDefinition(valueType: "float32", resolution: 100)
        let value = ModbusValue(address: 1, value: .float32(1_234.3344))
        let json = try value.json(using: definition)
        let data = try #require(json.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["value"] as? Double == 1_200)
    }

    @Test
    func valuesInSameResolutionBucketAreEqualForPublication() throws
    {
        let definition = try makeDefinition(valueType: "float32", resolution: 100)
        let first = ModbusValue(address: 1, value: .float32(1_234.3344)).applyingResolution(using: definition)
        let second = ModbusValue(address: 1, value: .float32(1_249.9)).applyingResolution(using: definition)
        let changed = ModbusValue(address: 1, value: .float32(1_251)).applyingResolution(using: definition)
        let publicationDate = Date(timeIntervalSinceReferenceDate: 1_000)
        var gate = MQTTPublicationGate()
        gate.recordSuccessfulPublication(topic: definition.topic,
                                         value: first.value,
                                         at: publicationDate)

        #expect(first.value == .decimal(1_200))
        #expect(gate.shouldPublish(topic: definition.topic,
                                   value: second.value,
                                   retained: false,
                                   publishAlways: false,
                                   at: publicationDate.addingTimeInterval(1),
                                   unchangedPublishInterval: 15) == false)
        #expect(gate.shouldPublish(topic: definition.topic,
                                   value: changed.value,
                                   retained: false,
                                   publishAlways: false,
                                   at: publicationDate.addingTimeInterval(1),
                                   unchangedPublishInterval: 15))
    }

    private func makeDefinition(valueType: String,
                                modbusType: String = "holding",
                                factor: Decimal? = nil,
                                resolution: Decimal? = nil,
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
        if let resolution
        {
            object["resolution"] = NSDecimalNumber(decimal: resolution)
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
