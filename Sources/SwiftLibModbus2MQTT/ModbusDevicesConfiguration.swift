import Foundation

public struct ModbusDevicesConfiguration: Decodable, Sendable
{
    public let devices: [ModbusDeviceConfiguration]

    public init(devices: [ModbusDeviceConfiguration]) throws
    {
        self.devices = devices
        try validate()
    }

    public init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = try container.decode([ModbusDeviceConfiguration].self, forKey: .devices)
        try validate()
    }

    private enum CodingKeys: String, CodingKey
    {
        case devices
    }

    private func validate() throws
    {
        guard devices.isEmpty == false
        else
        {
            throw ModbusDevicesConfigurationError.emptyDeviceList
        }

        var topics = Set<String>()
        var logicalDevices = Set<LogicalModbusDeviceKey>()

        for device in devices
        {
            guard topics.insert(device.topic).inserted
            else
            {
                throw ModbusDevicesConfigurationError.duplicateTopic(device.topic)
            }

            let logicalDevice = LogicalModbusDeviceKey(endpoint: device.endpoint, modbusAddress: device.modbusAddress)
            guard logicalDevices.insert(logicalDevice).inserted
            else
            {
                throw ModbusDevicesConfigurationError.duplicateLogicalDevice(endpoint: device.endpoint, modbusAddress: device.modbusAddress)
            }
        }
    }
}

public struct ModbusDeviceConfiguration: Decodable, Sendable, Equatable
{
    public let networkAddress: String
    public let port: UInt16
    public let modbusAddress: UInt8
    public let topic: String
    public let deviceDescriptionFile: String
    public let deviceResetURL: String?

    public var endpoint: ModbusEndpointKey
    {
        ModbusEndpointKey(networkAddress: networkAddress, port: port)
    }

    public init(networkAddress: String,
                port: UInt16 = 502,
                modbusAddress: UInt8,
                topic: String,
                deviceDescriptionFile: String,
                deviceResetURL: String? = nil) throws
    {
        let networkAddress = networkAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let topic = topic.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let deviceDescriptionFile = deviceDescriptionFile.trimmingCharacters(in: .whitespacesAndNewlines)

        guard networkAddress.isEmpty == false
        else
        {
            throw ModbusDevicesConfigurationError.emptyNetworkAddress
        }
        guard topic.isEmpty == false
        else
        {
            throw ModbusDevicesConfigurationError.emptyTopic
        }
        guard topic.contains("#") == false, topic.contains("+") == false
        else
        {
            throw ModbusDevicesConfigurationError.wildcardTopic(topic)
        }
        guard deviceDescriptionFile.isEmpty == false
        else
        {
            throw ModbusDevicesConfigurationError.emptyDeviceDescriptionFile
        }

        self.networkAddress = networkAddress
        self.port = port
        self.modbusAddress = modbusAddress
        self.topic = topic
        self.deviceDescriptionFile = deviceDescriptionFile
        self.deviceResetURL = deviceResetURL
    }

    public init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(networkAddress: container.decode(String.self, forKey: .networkAddress),
                      port: container.decodeIfPresent(UInt16.self, forKey: .port) ?? 502,
                      modbusAddress: container.decode(UInt8.self, forKey: .modbusAddress),
                      topic: container.decode(String.self, forKey: .topic),
                      deviceDescriptionFile: container.decode(String.self, forKey: .deviceDescriptionFile),
                      deviceResetURL: container.decodeIfPresent(String.self, forKey: .deviceResetURL))
    }

    private enum CodingKeys: String, CodingKey
    {
        case networkAddress, port, modbusAddress, topic, deviceDescriptionFile, deviceResetURL
    }
}

public struct ModbusEndpointKey: Hashable, Sendable, Equatable, CustomStringConvertible
{
    public let networkAddress: String
    public let port: UInt16

    public init(networkAddress: String, port: UInt16)
    {
        self.networkAddress = networkAddress
        self.port = port
    }

    public var description: String
    {
        "\(networkAddress):\(port)"
    }
}

public enum ModbusDevicesConfigurationError: Error, Equatable
{
    case emptyDeviceList
    case emptyNetworkAddress
    case emptyTopic
    case wildcardTopic(String)
    case emptyDeviceDescriptionFile
    case duplicateTopic(String)
    case duplicateLogicalDevice(endpoint: ModbusEndpointKey, modbusAddress: UInt8)
}

private struct LogicalModbusDeviceKey: Hashable
{
    let endpoint: ModbusEndpointKey
    let modbusAddress: UInt8
}
