public struct MQTTRequestRoute: Sendable, Equatable
{
    public let device: ModbusDeviceConfiguration
    public let responseTopic: String

    public init(device: ModbusDeviceConfiguration, responseTopic: String)
    {
        self.device = device
        self.responseTopic = responseTopic
    }
}

public struct MQTTRequestRouter: Sendable
{
    public let requestSubscriptions: [String]

    private let routes: [DeviceRoute]

    public init(configuration: ModbusDevicesConfiguration)
    {
        self.init(devices: configuration.devices)
    }

    public init(devices: [ModbusDeviceConfiguration])
    {
        let deviceRoutes = devices.map(DeviceRoute.init(device:))
        routes = deviceRoutes
            .sorted { $0.requestPrefix.count > $1.requestPrefix.count }
        requestSubscriptions = deviceRoutes.map(\.requestSubscription)
    }

    public func route(for topic: String) -> MQTTRequestRoute?
    {
        guard let route = routes.first(where: { $0.matches(topic) })
        else
        {
            return nil
        }

        let suffix = topic.dropFirst(route.requestPrefix.count)
        return MQTTRequestRoute(device: route.device,
                                responseTopic: route.responsePrefix + suffix)
    }
}

private struct DeviceRoute: Sendable
{
    let device: ModbusDeviceConfiguration
    let requestPrefix: String
    let responsePrefix: String
    let requestSubscription: String

    init(device: ModbusDeviceConfiguration)
    {
        self.device = device
        requestPrefix = "\(device.topic)/request"
        responsePrefix = "\(device.topic)/response"
        requestSubscription = "\(requestPrefix)/#"
    }

    func matches(_ topic: String) -> Bool
    {
        topic == requestPrefix || topic.hasPrefix(requestPrefix + "/")
    }
}
