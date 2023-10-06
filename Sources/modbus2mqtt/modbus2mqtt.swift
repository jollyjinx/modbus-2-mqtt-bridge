//
//  modbus2mqtt.swift
//

import Dispatch
import Foundation

import ArgumentParser
import MQTTNIO
import NIO

import JLog
import SwiftLibModbus

struct JNXServer
{
    let hostname: String
    let port: UInt16
    let username: String?
    let password: String?

    init(hostname: String, port: UInt16, username: String? = nil, password: String? = nil)
    {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
    }
}

struct JNXMQTTServer
{
    let server: JNXServer
    let emitInterval: Double
    let topic: String
}

#if !NSEC_PER_SEC
    let NSEC_PER_SEC = 1_000_000_000
#endif

extension JLog.Level: ExpressibleByArgument {}
#if DEBUG
    let defaultLoglevel: JLog.Level = .debug
#else
    let defaultLoglevel: JLog.Level = .notice
#endif

@main
struct modbus2mqtt: AsyncParsableCommand
{
    @Option(help: "Set the log level.") var logLevel: JLog.Level = defaultLoglevel

    @Option(name: .shortAndLong, help: "optional debug output")
    var debug: Int = 0

    @Option(name: .long, help: "MQTT Server hostname")
    var mqttServername: String = "mqtt"

    @Option(name: .long, help: "MQTT Server port")
    var mqttPort: UInt16 = 1883

    @Option(name: .long, help: "MQTT Server username")
    var mqttUsername: String = ""

    @Option(name: .long, help: "MQTT Server password")
    var mqttPassword: String = ""

    @Option(name: .long, help: "Minimum interval to send updates to mqtt Server.")
    var emitInterval: Double = 0.1

    @Option(name: .shortAndLong, help: "MQTT Server topic.")
    var topic: String = "modbus/sunnyboy"

    #if DEBUG
        @Option(name: .long, help: "Maximum time a mqttRequest can lie in the future/past to be accepted.")
        var mqttRequestTTL: Double = 1000.0
    #else
        @Option(name: .long, help: "Maximum time a mqttRequest can lie in the future/past to be accepted.")
        var mqttRequestTTL: Double = 10.0
    #endif

    @Option(name: .long, help: "If mqttTopic has a refreshtime larger than this value it will be ratained.")
    var mqttAutoRetainTime: Double = 10.0

    @Option(name: .long, help: "Serial Modbus Device path")
    var modbusDevicePath: String = ""

    @Option(name: .long, help: "Serial Modbus Speed")
    var modbusSerialSpeed: Int = 9600

    @Option(name: .shortAndLong, help: "Modbus Device Servername.")
    var modbusServer: String = "modbus.example.com"

    @Option(name: .long, help: "Modbus Device Port number.")
    var modbusPort: UInt16 = 502

    @Option(name: .long, help: "Modbus Device Address.")
    var modbusAddress: UInt16 = 3

    @Option(name: .long, help: "Modbus Device Description file (JSON).")
    var deviceDescriptionFile = "sma.sunnyboy.json"

    mutating func run() async throws
    {
        JLog.loglevel = logLevel
        signal(SIGUSR1, SIG_IGN)
        signal(SIGUSR1, handleSIGUSR1)

        do
        {
            let mqttServer = JNXMQTTServer(server: JNXServer(hostname: mqttServername, port: mqttPort, username: mqttUsername, password: mqttPassword), emitInterval: emitInterval, topic: topic)

            let modbusDevice: ModbusDevice

            if modbusDevicePath.isEmpty
            {
                modbusDevice = try ModbusDevice(networkAddress: modbusServer, port: modbusPort, deviceAddress: modbusAddress)
            }
            else
            {
                modbusDevice = try ModbusDevice(device: modbusDevicePath, baudRate: modbusSerialSpeed)
            }

            try await startServing(modbusDevice: modbusDevice, mqttServer: mqttServer, options: self)
        }
        catch
        {
            JLog.error("Got error:\(error)")
        }
    }
}

func handleSIGUSR1(signal: Int32)
{
    DispatchQueue.main.async
    {
        JLog.notice("Received \(signal) signal.")
        JLog.notice("Switching Log level from \(JLog.loglevel)")
        switch JLog.loglevel
        {
            case .trace: JLog.loglevel = .info
            case .debug: JLog.loglevel = .trace
            case .info: JLog.loglevel = .debug
            default: JLog.loglevel = .debug
        }

        JLog.notice("to \(JLog.loglevel)")
    }
}

func startServing(modbusDevice: ModbusDevice, mqttServer: JNXMQTTServer, options: modbus2mqtt) async throws
{
    let deviceDescriptionURL = try fileURLFromPath(path: options.deviceDescriptionFile)
    var modbusDefinitions = try ModbusDefinition.read(from: deviceDescriptionURL)

    JLog.debug("modbusdefinitions:\(modbusDefinitions)")

    let credentials: MQTTConfiguration.Credentials?

    if let username = mqttServer.server.username,
       let password = mqttServer.server.password
    {
        credentials = MQTTConfiguration.Credentials(username: username, password: password)
    }
    else
    {
        credentials = nil
    }
    let mqttClient = MQTTClient(configuration: .init(target: .host(mqttServer.server.hostname, port: Int(mqttServer.server.port)),
                                                     credentials: credentials),
                                eventLoopGroupProvider: .createNew)
    try await mqttClient.connect()

    guard mqttClient.isConnected
    else
    {
        fatalError("Could not connect to mqtt server")
    }
    for modbusDefinition in modbusDefinitions.values
    {
        switch modbusDefinition.modbusaccess
        {
            case .read: break

            case .write: fallthrough
            case .readwrite: let topic = "\(mqttServer.topic)/request/+"
                try await mqttClient.subscribe(to: topic)
        }
    }

    let staticDefinitions = modbusDefinitions.values
    Task
    {
        var knownRequests = Set<MQTTRequest>()
        let requestTTL = options.mqttRequestTTL

        for await message in mqttClient.messages
        {
            JLog.debug("Received: \(message) contentType:\(message.payload)")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let data = message.payload.string?.data(using: .utf8),
               let request = try? decoder.decode(MQTTRequest.self, from: data)
            {
                JLog.debug("Got Request:\(request)")
                let response: MQTTResponse

                enum RequestError: Error
                {
                    case noTopicFound
                    case attributeNotWriteable
                    case attributeTypeCurrentlyNotSupported
                    case valueTypeConversionError
                    case requestDateOutdated
                    case requestDateInFuture
                    case requestAnswered
                }

                do
                {
                    let outdated = Date(timeIntervalSinceNow: -requestTTL)
                    let tofarinfuture = Date(timeIntervalSinceNow: requestTTL)
                    JLog.debug("Request from:\(request.date) Allowed range:\(outdated) - \(tofarinfuture)")

                    guard request.date > outdated else { throw RequestError.requestDateOutdated }
                    guard request.date < tofarinfuture else { throw RequestError.requestDateInFuture }
                    guard !knownRequests.contains(request) else { throw RequestError.requestAnswered }

                    guard let mbd = staticDefinitions.first(where: { $0.topic == request.topic }) else { throw RequestError.noTopicFound }

                    if mbd.modbusaccess == .read
                    {
                        throw RequestError.attributeNotWriteable
                    }
                    switch (mbd.valuetype, request.value)
                    {
                        case let (.bool, .bool(value)): JLog.debug("bool:\(value)")
                            guard mbd.modbustype == .coil else { throw RequestError.attributeTypeCurrentlyNotSupported }
                            try await modbusDevice.writeInputCoil(startAddress: mbd.address, value: value)

                        case let (.string, .string(value)): JLog.debug("string:\(value)")
                            try await modbusDevice.writeASCIIString(start: mbd.address, count: mbd.length!, string: value)

                        case let (.uint16, .decimal(value)): JLog.debug("decimal:\(value)")
                            let factored = mbd.hasFactor ? value * mbd.factor! : value
                            JLog.debug("factored:\(factored)")
                            guard let intValue = UInt16(factored.description) else { throw RequestError.valueTypeConversionError }
                            JLog.debug("Intvalue:\(intValue)")

                            try await modbusDevice.writeRegisters(to: mbd.address, arrayToWrite: [intValue], endianness: mbd.endianness ?? .bigEndian)

                        default: throw RequestError.attributeTypeCurrentlyNotSupported
                    }
                    response = MQTTResponse(date: Date(), id: request.id, success: true, error: nil)
                }
                catch
                {
                    JLog.error("Could not work on request: \(request) due to:\(error)")
                    response = MQTTResponse(date: Date(), id: request.id, success: false, error: "\(error)")
                }

                let outdated = Date(timeIntervalSinceNow: -requestTTL)

                knownRequests = knownRequests.filter { $0.date < outdated }
                knownRequests.insert(request)

                let topic = "\(mqttServer.topic)/response/\(request.id)"

                let jsonEncoder = JSONEncoder()
                jsonEncoder.dateEncodingStrategy = .iso8601
                if let jsonData = try? jsonEncoder.encode(response),
                   let jsonString = String(data: jsonData, encoding: .utf8)
                {
                    try await mqttClient.publish(MQTTMessage(topic: topic,
                                                             payload: jsonString,
                                                             retain: false)
                    )
                }
            }
            else
            {
                JLog.error("Could not decode request: \(message)")
            }
        }
        // only when error
    }

    var errorCounter = 0

    var retainedMessageCache = [String: ModbusType]()

    while true
    {
        let now = Date()

        let mbd = modbusDefinitions.values.min(by: {
            if $0.nextReadDate < now,
               $1.nextReadDate < now, // both of them are ready
               $0.interval != $1.interval // then interval is like priority
            {
                return $0.interval < $1.interval
            }
            return $0.nextReadDate < $1.nextReadDate
        })! as ModbusDefinition

        while mbd.nextReadDate > Date()
        {
            let timeToWait: TimeInterval = max(options.emitInterval, mbd.nextReadDate.timeIntervalSinceNow)
            JLog.debug("nextLoopDate:\(String(describing: mbd.nextReadDate)) mininterval:\(options.emitInterval) timetowait:\(timeToWait)")
            try? await Task.sleep(nanoseconds: UInt64(timeToWait * Double(NSEC_PER_SEC)))
            JLog.debug("waited.")
        }

        let payload: ModbusValue

        do
        {
            JLog.debug("reading:\(mbd)")

            switch mbd.valuetype
            {
                case .bool: let value = try await modbusDevice.readInputBitsFrom(startAddress: mbd.address, count: 1, type: mbd.modbustype).first!
                    payload = ModbusValue(address: mbd.address, value: .bool(value))

                case .uint8: let value = await try (modbusDevice.readRegisters(from: mbd.address, count: 1, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian) as [UInt8]).first!
                    payload = ModbusValue(address: mbd.address, value: .uint8(value))

                case .int8: let value = await try (modbusDevice.readRegisters(from: mbd.address, count: 1, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian) as [Int8]).first!
                    payload = ModbusValue(address: mbd.address, value: .int8(value))

                case .uint16: let value = await try (modbusDevice.readRegisters(from: mbd.address, count: 1, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian) as [UInt16]).first!
                    payload = ModbusValue(address: mbd.address, value: .uint16(value))

                case .int16: let value = await try (modbusDevice.readRegisters(from: mbd.address, count: 1, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian) as [Int16]).first!
                    payload = ModbusValue(address: mbd.address, value: .int16(value))

                case .uint32: let value = await try (modbusDevice.readRegisters(from: mbd.address, count: 1, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian) as [UInt32]).first!
                    payload = ModbusValue(address: mbd.address, value: .uint32(value))

                case .int32: let value = await try (modbusDevice.readRegisters(from: mbd.address, count: 1, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian) as [Int32]).first!
                    payload = ModbusValue(address: mbd.address, value: .int32(value))

                case .uint64: let value = await try (modbusDevice.readRegisters(from: mbd.address, count: 1, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian) as [UInt64]).first!
                    payload = ModbusValue(address: mbd.address, value: .uint64(value))

                case .int64: let value = await try (modbusDevice.readRegisters(from: mbd.address, count: 1, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian) as [Int64]).first!
                    payload = ModbusValue(address: mbd.address, value: .int64(value))

                case .string: let value = try await modbusDevice.readASCIIString(from: mbd.address, count: mbd.length!, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian)
                    payload = ModbusValue(address: mbd.address, value: .string(value))

                case .ipv4address: let array = try await modbusDevice.readRegisters(from: mbd.address, count: 4, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian) as [UInt16]
                    let value = array.map { String($0) }.joined(separator: ".")
                    payload = ModbusValue(address: mbd.address, value: .string(value))

                case .macaddress: let array = try await modbusDevice.readRegisters(from: mbd.address, count: mbd.length!, type: mbd.modbustype, endianness: mbd.endianness ?? .bigEndian) as [UInt8]
                    let value = array.map { String(format: "%02X", $0) }.joined(separator: ":")
                    payload = ModbusValue(address: mbd.address, value: .string(value))
            }
            errorCounter = 0

            JLog.debug("read:\(payload)")

            if !mqttClient.isConnected
            {
                JLog.error("No longer connected to mqtt server - reconnecting")

                retainedMessageCache.removeAll()
                modbusDefinitions.keys.forEach { address in modbusDefinitions[address]!.nextReadDate = .distantPast }

                try await mqttClient.reconnect()

                guard mqttClient.isConnected
                else
                {
                    fatalError("Could not connect to mqtt server")
                }
            }

            let retained = (mbd.mqtt == .retained) || (mbd.interval == 0) || mbd.interval > options.mqttAutoRetainTime
            let publish = mbd.publishalways ?? false

            if !publish, retained,
               let lastValue = retainedMessageCache[mbd.topic], lastValue == payload.value
            {
                JLog.debug("Value did not change")
            }
            else
            {
                retainedMessageCache[mbd.topic] = payload.value

                let topic = "\(mqttServer.topic)/\(mbd.topic)"
                try await mqttClient.publish(MQTTMessage(topic: topic,
                                                         payload: payload.json,
                                                         retain: retained)
                )
            }
            let nextReadDate = mbd.interval == 0 ? .distantFuture : Date(timeIntervalSinceNow: mbd.interval)
            modbusDefinitions[mbd.address]!.nextReadDate = nextReadDate
            JLog.debug("nextReadDate:\(nextReadDate)")
        }
        catch
        {
            errorCounter += 1
            if errorCounter > 10
            {
                throw error
            }
            JLog.error("got error:\(error) - ignoring errorcounter:\(errorCounter)")

            let waittime = 30.0 * Double(errorCounter)
            JLog.error("Waiting \(waittime) seconds")
            try? await Task.sleep(nanoseconds: UInt64(waittime * Double(NSEC_PER_SEC)))
        }
    }
}

func fileURLFromPath(path: String) throws -> URL
{
    let fileURL = URL(fileURLWithPath: path)

    if FileManager.default.fileExists(atPath: fileURL.path)
    {
        return fileURL
    }

    let filename = fileURL.deletingPathExtension().lastPathComponent
    let `extension` = fileURL.pathExtension
    JLog.debug("filename:\(filename) extension:\(`extension`)")

    if let bundleURL = Bundle.module.url(forResource: "Resources/" + filename, withExtension: `extension`)
    {
        return bundleURL
    }
    enum ValidationError: Error { case fileNotFound(String) }
    throw ValidationError.fileNotFound("\(path)")
}
