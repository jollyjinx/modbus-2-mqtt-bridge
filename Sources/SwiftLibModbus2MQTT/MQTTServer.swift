//
//  MQTTServer.swift
//

public struct MQTTServer: Sendable
{
    public let hostname: String
    public let port: UInt16
    public let username: String?
    public let password: String?

    public init(hostname: String, port: UInt16 = 1883, username: String? = nil, password: String? = nil)
    {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
    }
}

public struct MQTTDevice: Sendable
{
    public let server: MQTTServer
    public let topic: String

    public init(server: MQTTServer, topic: String)
    {
        self.server = server
        self.topic = topic
    }
}
