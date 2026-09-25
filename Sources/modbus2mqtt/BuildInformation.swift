import Foundation

struct Modbus2MQTTBuildInformation: Sendable
{
    let version: String
    let revision: String?

    init(environment: [String: String] = ProcessInfo.processInfo.environment)
    {
        version = Self.nonempty(environment["MODBUS2MQTT_VERSION"]) ?? "development"
        revision = Self.nonempty(environment["MODBUS2MQTT_REVISION"])
    }

    private static func nonempty(_ value: String?) -> String?
    {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
