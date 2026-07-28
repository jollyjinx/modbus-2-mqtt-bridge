//
//  modbus2mqtt.swift
//

import ArgumentParser
import Dispatch
import Foundation
import JLog
import MQTTNIO
import SwiftLibModbus
import SwiftLibModbus2MQTT

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if !NSEC_PER_SEC
    let NSEC_PER_SEC = 1_000_000_000
#endif

private let serviceRestartDelay: TimeInterval = 30

private enum ConfigurationError: Error
{
    case multipleMultiDeviceConfigurationSources
    case multiDeviceConfigurationConflictsWithLegacyDeviceOptions
    case invalidMQTTUnchangedPublishInterval(Double)
}

extension JLog.Level: @retroactive ExpressibleByArgument
{
    public init?(argument: String)
    {
        self.init(argument)
    }
}
#if DEBUG
    let defaultLoglevel: JLog.Level = .debug
#else
    let defaultLoglevel: JLog.Level = .notice
#endif

@main
struct modbus2mqtt: AsyncParsableCommand
{
    @Option(help: "Set the log level.") var logLevel: JLog.Level = defaultLoglevel

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
    var topic: String = "example/modbus2mqttdevice"

    #if DEBUG
        @Option(name: .long, help: "Maximum time a mqttRequest can lie in the future/past to be accepted.")
        var mqttRequestTTL: Double = 1000.0
    #else
        @Option(name: .long, help: "Maximum time a mqttRequest can lie in the future/past to be accepted.")
        var mqttRequestTTL: Double = 10.0
    #endif

    @Option(name: .long, help: "If mqttTopic has a refreshtime larger than this value it will be ratained.")
    var mqttAutoRetainTime: Double = 10.0

    @Option(name: .long, help: "Maximum interval between unchanged non-retained MQTT updates; 0 restores publish-every-poll behavior.")
    var mqttUnchangedPublishInterval: Double = 15.0

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

    @Option(name: .long, help: "Device Reset URL (HTTP GET) - called when communication fails repeatedly.")
    var deviceResetURL: String?

    @Option(name: .long, help: "JSON file containing multiple logical Modbus devices.")
    var modbusDevicesFile: String?

    @Option(name: .long, help: "Inline JSON containing multiple logical Modbus devices.")
    var modbusDevicesString: String?

    func run() async throws
    {
        guard mqttUnchangedPublishInterval.isFinite, mqttUnchangedPublishInterval >= 0
        else
        {
            throw ConfigurationError.invalidMQTTUnchangedPublishInterval(mqttUnchangedPublishInterval)
        }

        JLog.loglevel = logLevel
        signal(SIGUSR1, SIG_IGN)
        signal(SIGUSR1, handleSIGUSR1)

        if logLevel != defaultLoglevel
        {
            JLog.info("Loglevel: \(logLevel)")
        }

        // Validate static configuration once so startup errors fail fast.
        let resetURL: URL?

        if let urlString = deviceResetURL,
           let url = URL(string: urlString), url.host != nil,
           let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
        {
            JLog.notice("Device reset URL configured: \(urlString)")
            resetURL = url
        }
        else
        {
            resetURL = nil
        }

        let multiDeviceConfigurationData: Data?
        let multiDeviceConfigurationDescription: String?

        switch (modbusDevicesFile, modbusDevicesString)
        {
            case (.some, .some):
                throw ConfigurationError.multipleMultiDeviceConfigurationSources

            case let (.some(path), .none):
                let configurationURL = URL(fileURLWithPath: path)
                multiDeviceConfigurationData = try Data(contentsOf: configurationURL)
                multiDeviceConfigurationDescription = configurationURL.path

            case let (.none, .some(json)):
                multiDeviceConfigurationData = Data(json.utf8)
                multiDeviceConfigurationDescription = "--modbus-devices-string"

            case (.none, .none):
                multiDeviceConfigurationData = nil
                multiDeviceConfigurationDescription = nil
        }

        let configuredDevices: [ModbusDeviceConfiguration]?
        if let multiDeviceConfigurationData
        {
            guard topic == "example/modbus2mqttdevice",
                  modbusDevicePath.isEmpty,
                  modbusSerialSpeed == 9600,
                  modbusServer == "modbus.example.com",
                  modbusPort == 502,
                  modbusAddress == 3,
                  deviceDescriptionFile == "sma.sunnyboy.json",
                  deviceResetURL == nil
            else
            {
                throw ConfigurationError.multiDeviceConfigurationConflictsWithLegacyDeviceOptions
            }

            let configuration = try JSONDecoder().decode(ModbusDevicesConfiguration.self, from: multiDeviceConfigurationData)
            for device in configuration.devices
            {
                _ = try fileURLFromPath(path: device.deviceDescriptionFile)
            }
            configuredDevices = configuration.devices
            JLog.notice("Loaded \(configuration.devices.count) Modbus devices from \(multiDeviceConfigurationDescription ?? "configuration")")
        }
        else
        {
            _ = try fileURLFromPath(path: deviceDescriptionFile)
            configuredDevices = nil
        }

        let mqttServer = MQTTDevice(server: MQTTServer(hostname: mqttServername, port: mqttPort, username: mqttUsername, password: mqttPassword), topic: topic)

        while !Task.isCancelled
        {
            do
            {
                if let configuredDevices
                {
                    try await startServing(configurations: configuredDevices, mqttServer: mqttServer, options: self)
                }
                else
                {
                    let modbusDevice: ModbusDevice = if modbusDevicePath.isEmpty
                    {
                        try ModbusDevice(networkAddress: modbusServer, port: modbusPort, deviceAddress: modbusAddress)
                    }
                    else
                    {
                        try ModbusDevice(device: modbusDevicePath, slaveid: Int(modbusAddress), baudRate: modbusSerialSpeed)
                    }

                    try await startServing(modbusDevice: modbusDevice, deviceAddress: modbusAddress, mqttServer: mqttServer, resetURL: resetURL, options: self)
                }
            }
            catch
            {
                JLog.error("Serving failed:\(error)")
            }

            guard !Task.isCancelled
            else
            {
                break
            }

            JLog.notice("Restarting service in \(serviceRestartDelay) seconds")
            try? await Task.sleep(nanoseconds: UInt64(serviceRestartDelay * Double(NSEC_PER_SEC)))
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

func callResetURL(_ url: URL) async throws
{
    JLog.notice("Calling device reset URL: \(url.absoluteString)")

    var request = URLRequest(url: url)
    request.timeoutInterval = 5 // shorter timeout since device will reboot quickly

    do
    {
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse
        {
            JLog.notice("Reset URL response: HTTP \(http.statusCode)")
            if http.statusCode == 303 || (200 ..< 400).contains(http.statusCode)
            {
                JLog.notice("Device reset triggered successfully (status \(http.statusCode))")
            }
            else
            {
                JLog.warning("Unexpected reset response: \(http.statusCode)")
            }
        }
    }
    catch
    {
        // Connection drop during reboot → expected
        if let urlError = error as? URLError, urlError.code == .timedOut || urlError.code == .networkConnectionLost
        {
            JLog.notice("Device likely rebooting (connection lost during reset)")
        }
        else
        {
            throw error
        }
    }
}

func startServing(modbusDevice: ModbusDevice, deviceAddress: UInt16, mqttServer: MQTTDevice, resetURL: URL?, options: modbus2mqtt) async throws
{
    let deviceDescriptionURL = try fileURLFromPath(path: options.deviceDescriptionFile)
    let modbusDefinitions = try ModbusDefinition.read(from: deviceDescriptionURL)

    JLog.debug("modbusdefinitions:\(modbusDefinitions)")

    let requestPath = "\(mqttServer.topic)/request"
    let responsePath = "\(mqttServer.topic)/response"

    try await MQTTConnection.withConnection(
        address: .hostname(mqttServer.server.hostname, port: Int(mqttServer.server.port)),
        configuration: mqttConnectionConfiguration(for: mqttServer.server)
    )
    { mqttConnection in
        try await mqttConnection.subscribe(to: [
            MQTTSubscribeInfo(topicFilter: requestPath + "/#", qos: .atMostOnce),
        ])
        { subscription in
            try await runMQTTServingSession(workers: [
                {
                    try await serveMQTTRequests(subscription: subscription,
                                                connection: mqttConnection,
                                                modbusDevice: modbusDevice,
                                                deviceAddress: deviceAddress,
                                                definitions: Array(modbusDefinitions.values),
                                                requestPath: requestPath,
                                                responsePath: responsePath,
                                                requestTTL: options.mqttRequestTTL)
                },
                {
                    try await poll(modbusDevice: modbusDevice,
                                   deviceAddress: deviceAddress,
                                   definitions: modbusDefinitions,
                                   mqttConnection: mqttConnection,
                                   topicPrefix: mqttServer.topic,
                                   resetURL: resetURL,
                                   options: options)
                },
            ])
        }
    }
}

private func serveMQTTRequests(subscription: MQTTSubscription,
                               connection: MQTTConnection,
                               modbusDevice: ModbusDevice,
                               deviceAddress: UInt16,
                               definitions: [ModbusDefinition],
                               requestPath: String,
                               responsePath: String,
                               requestTTL: Double) async throws
{
    var knownRequests = Set<MQTTRequest>()

    for try await message in subscription
    {
        JLog.debug("Received MQTT message on \(message.topicName)")

        var responseTopic = message.topicName

        if let range = responseTopic.range(of: requestPath)
        {
            responseTopic.replaceSubrange(range, with: responsePath)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let requestString = message.payload.getString(at: message.payload.readerIndex,
                                                            length: message.payload.readableBytes),
              let data = requestString.data(using: .utf8),
              let request = try? decoder.decode(MQTTRequest.self, from: data)
        else
        {
            JLog.error("Could not decode MQTT request on \(message.topicName)")
            continue
        }

        JLog.debug("Got Request:\(request)")
        let response: MQTTResponse

        do
        {
            let outdated = Date(timeIntervalSinceNow: -requestTTL)
            let tooFarInFuture = Date(timeIntervalSinceNow: requestTTL)
            JLog.debug("Request from:\(request.date) Allowed range:\(outdated) - \(tooFarInFuture)")

            guard request.date > outdated else { throw MQTTRequestHandlingError.requestDateOutdated }
            guard request.date < tooFarInFuture else { throw MQTTRequestHandlingError.requestDateInFuture }
            guard knownRequests.contains(request) == false else { throw MQTTRequestHandlingError.requestAnswered }
            guard let definition = definitions.first(where: { $0.topic == request.topic })
            else { throw MQTTRequestHandlingError.noTopicFound }
            guard definition.modbusaccess != .read
            else { throw MQTTRequestHandlingError.attributeNotWriteable }

            try await modbusDevice.write(request.value, definition: definition, deviceAddress: deviceAddress)
            response = MQTTResponse(request: request, success: true)
        }
        catch
        {
            JLog.error("Could not work on request: \(request) due to:\(error)")
            response = MQTTResponse(request: request, success: false, error: "\(error)")
        }

        let outdated = Date(timeIntervalSinceNow: -requestTTL)
        knownRequests = knownRequests.filter { $0.date < outdated }
        knownRequests.insert(request)

        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = .sortedKeys
        if let jsonData = try? jsonEncoder.encode(response),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            try await connection.publish(to: responseTopic,
                                         payload: .init(string: jsonString),
                                         qos: .atMostOnce)
        }
    }
}

private func poll(modbusDevice: ModbusDevice,
                  deviceAddress: UInt16,
                  definitions: [Int: ModbusDefinition],
                  mqttConnection: MQTTConnection,
                  topicPrefix: String,
                  resetURL: URL?,
                  options: modbus2mqtt) async throws
{
    var modbusDefinitions = definitions
    var errorCounter = 0
    var publicationGate = MQTTPublicationGate()

    while Task.isCancelled == false
    {
        try Task.checkCancellation()
        let now = Date()

        guard let definition = modbusDefinitions.values.min(by: {
            if $0.nextReadDate < now,
               $1.nextReadDate < now,
               $0.interval != $1.interval
            {
                return $0.interval < $1.interval
            }
            return $0.nextReadDate < $1.nextReadDate
        })
        else { return }

        while definition.nextReadDate > Date()
        {
            let timeToWait = max(options.emitInterval, definition.nextReadDate.timeIntervalSinceNow)
            JLog.debug("nextLoopDate:\(String(describing: definition.nextReadDate)) mininterval:\(options.emitInterval) timetowait:\(timeToWait)")
            try await Task.sleep(nanoseconds: UInt64(timeToWait * Double(NSEC_PER_SEC)))
            JLog.debug("waited.")
        }

        do
        {
            JLog.debug("reading:\(definition)")
            let payload = try await modbusDevice.read(definition: definition, deviceAddress: deviceAddress)
            errorCounter = 0

            JLog.debug("read:\(payload)")

            let publishedPayload = payload.applyingResolution(using: definition)
            let retained = definition.mqtt == .retained
                || definition.interval == 0
                || definition.interval > options.mqttAutoRetainTime
            let publishAlways = definition.publishalways ?? false
            let publicationDate = Date()

            if publicationGate.shouldPublish(topic: definition.topic,
                                               value: publishedPayload.value,
                                               retained: retained,
                                               publishAlways: publishAlways,
                                               at: publicationDate,
                                               unchangedPublishInterval: options.mqttUnchangedPublishInterval)
            {
                try await mqttConnection.publish(to: "\(topicPrefix)/\(definition.topic)",
                                                 payload: .init(string: try publishedPayload.json(using: definition)),
                                                 qos: .atMostOnce,
                                                 retain: retained)
                publicationGate.recordSuccessfulPublication(topic: definition.topic,
                                                             value: publishedPayload.value,
                                                             at: publicationDate)
            }
            else
            {
                JLog.debug("Value did not change")
            }
            let nextReadDate = definition.interval == 0 ? .distantFuture : Date(timeIntervalSinceNow: definition.interval)
            modbusDefinitions[definition.address]!.nextReadDate = nextReadDate
            JLog.debug("nextReadDate:\(nextReadDate)")
        }
        catch is CancellationError
        {
            return
        }
        catch
        {
            if error is MQTTError
            {
                throw error
            }

            errorCounter += 1

            if let modbusError = error as? ModbusError
            {
                JLog.warning("Resetting Modbus connection after error: \(modbusError)")
                await modbusDevice.disconnect()
            }

            if errorCounter == 7, let url = resetURL
            {
                JLog.warning("Error threshold reached (\(errorCounter) errors), attempting device reset")
                do
                {
                    try await callResetURL(url)
                    JLog.notice("Waiting 60 seconds for device to reboot...")
                    try? await Task.sleep(nanoseconds: UInt64(60 * NSEC_PER_SEC))
                    JLog.notice("Attempting to resume communication")
                }
                catch
                {
                    JLog.error("Failed to call reset URL: \(error)")
                }
            }

            if errorCounter > 10
            {
                throw error
            }
            JLog.error("got error:\(error) - ignoring errorcounter:\(errorCounter)")

            let waittime = 30.0 * Double(errorCounter)
            JLog.error("Waiting \(waittime) seconds")
            try await Task.sleep(nanoseconds: UInt64(waittime * Double(NSEC_PER_SEC)))
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

    JLog.debug("Bundle.module:\(String(describing: Bundle.module.resourceURL))")
    JLog.debug("filename:\(filename) extension:\(`extension`)")

    if let bundleURL = Bundle.module.url(forResource: filename, withExtension: `extension`, subdirectory: "DeviceDefinitions")
    {
        return bundleURL
    }
    JLog.error("file not found:\(path)")

    enum ValidationError: Error { case fileNotFound(String) }
    throw ValidationError.fileNotFound("\(path)")
}
