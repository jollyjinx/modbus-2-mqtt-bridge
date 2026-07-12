import Foundation
import JLog
import MQTTNIO
import NIO
import SwiftLibModbus
import SwiftLibModbus2MQTT

private struct RuntimeModbusDevice: Sendable
{
    let configuration: ModbusDeviceConfiguration
    let endpoint: ModbusDevice
    let recovery: EndpointRecoveryCoordinator
    let definitions: [Int: ModbusDefinition]
}

private actor MQTTConnectionGeneration
{
    private var generation = 0

    func advance()
    {
        generation += 1
    }

    func current() -> Int
    {
        generation
    }
}

private actor EndpointRecoveryCoordinator
{
    private let endpoint: ModbusEndpointKey
    private let resetURL: URL?
    private var resetInProgress = false
    private var lastResetDate: Date?

    init(endpoint: ModbusEndpointKey, resetURL: URL?)
    {
        self.endpoint = endpoint
        self.resetURL = resetURL
    }

    func attemptResetIfNeeded() async
    {
        guard let resetURL, resetInProgress == false
        else { return }

        if let lastResetDate, Date().timeIntervalSince(lastResetDate) < 300
        {
            JLog.warning("Skipping reset for \(endpoint); reset cooldown is active")
            return
        }

        resetInProgress = true
        defer { resetInProgress = false }

        do
        {
            JLog.warning("Resetting Modbus endpoint \(endpoint)")
            try await callResetURL(resetURL)
            lastResetDate = Date()
            try await Task.sleep(nanoseconds: UInt64(60 * NSEC_PER_SEC))
        }
        catch is CancellationError
        {
            return
        }
        catch
        {
            JLog.error("Failed to reset Modbus endpoint \(endpoint): \(error)")
        }
    }
}

private enum MultiDeviceServingError: Error
{
    case emptyDefinitionFile(String)
    case missingRuntimeDevice(String)
}

private enum MQTTRequestHandlingError: Error
{
    case noTopicFound
    case attributeNotWriteable
    case requestDateOutdated
    case requestDateInFuture
    case requestAnswered
}

func startServing(configurations: [ModbusDeviceConfiguration],
                  mqttServer: MQTTDevice,
                  options: modbus2mqtt) async throws
{
    var endpoints = [ModbusEndpointKey: ModbusDevice]()
    var recoveries = [ModbusEndpointKey: EndpointRecoveryCoordinator]()
    var runtimeDevices = [RuntimeModbusDevice]()

    for configuration in configurations
    {
        let endpoint: ModbusDevice
        if let existingEndpoint = endpoints[configuration.endpoint]
        {
            endpoint = existingEndpoint
        }
        else
        {
            endpoint = try ModbusDevice(networkAddress: configuration.networkAddress,
                                        port: configuration.port,
                                        deviceAddress: UInt16(configuration.modbusAddress))
            endpoints[configuration.endpoint] = endpoint
        }

        let recovery: EndpointRecoveryCoordinator
        if let existingRecovery = recoveries[configuration.endpoint]
        {
            recovery = existingRecovery
        }
        else
        {
            let resetURL = configuration.deviceResetURL.flatMap(URL.init(string:))
            recovery = EndpointRecoveryCoordinator(endpoint: configuration.endpoint, resetURL: resetURL)
            recoveries[configuration.endpoint] = recovery
        }

        let definitionURL = try fileURLFromPath(path: configuration.deviceDescriptionFile)
        let definitions = try ModbusDefinition.read(from: definitionURL)
        guard definitions.isEmpty == false
        else { throw MultiDeviceServingError.emptyDefinitionFile(configuration.deviceDescriptionFile) }

        runtimeDevices.append(RuntimeModbusDevice(configuration: configuration,
                                                  endpoint: endpoint,
                                                  recovery: recovery,
                                                  definitions: definitions))
    }

    let credentials: MQTTConfiguration.Credentials? = if let username = mqttServer.server.username,
                                                         let password = mqttServer.server.password
    {
        MQTTConfiguration.Credentials(username: username, password: password)
    }
    else
    {
        nil
    }

    let mqttClient = MQTTClient(configuration: .init(target: .host(mqttServer.server.hostname,
                                                                    port: Int(mqttServer.server.port)),
                                                     credentials: credentials),
                                eventLoopGroup: MultiThreadedEventLoopGroup.singleton)
    let router = MQTTRequestRouter(devices: configurations)
    let generation = MQTTConnectionGeneration()
    let devices = runtimeDevices
    let requestTTL = options.mqttRequestTTL
    let emitInterval = options.emitInterval
    let mqttAutoRetainTime = options.mqttAutoRetainTime

    do
    {
        try await mqttClient.connect()
        try await mqttClient.subscribe(to: router.requestSubscriptions)
        await generation.advance()
    }
    catch
    {
        try? await mqttClient.disconnect()
        for endpoint in endpoints.values
        {
            await endpoint.disconnect()
        }
        throw error
    }

    let reconnectObserver = mqttClient.whenConnected { _ in
        Task
        {
            await restoreSubscriptions(client: mqttClient,
                                       subscriptions: router.requestSubscriptions,
                                       generation: generation)
        }
    }

    await withTaskGroup(of: Void.self)
    { group in
        group.addTask
        {
            await serveMQTTRequests(client: mqttClient,
                                    router: router,
                                    runtimeDevices: devices,
                                    requestTTL: requestTTL)
        }

        for device in devices
        {
            group.addTask
            {
                await poll(device: device,
                           mqttClient: mqttClient,
                           generation: generation,
                           emitInterval: emitInterval,
                           mqttAutoRetainTime: mqttAutoRetainTime)
            }
        }

        await group.waitForAll()
    }

    reconnectObserver.cancel()
    for endpoint in endpoints.values
    {
        await endpoint.disconnect()
    }
    try? await mqttClient.disconnect()
}

private func poll(device: RuntimeModbusDevice,
                  mqttClient: MQTTClient,
                  generation: MQTTConnectionGeneration,
                  emitInterval: Double,
                  mqttAutoRetainTime: Double) async
{
    var definitions = device.definitions
    var retainedMessageCache = [String: ModbusType]()
    var errorCounter = 0
    var observedMQTTGeneration = await generation.current()
    let context = "[\(device.configuration.endpoint) unit=\(device.configuration.modbusAddress) topic=\(device.configuration.topic)]"

    while Task.isCancelled == false
    {
        do
        {
            let currentGeneration = await generation.current()
            if currentGeneration != observedMQTTGeneration
            {
                observedMQTTGeneration = currentGeneration
                retainedMessageCache.removeAll()
                definitions.keys.forEach { definitions[$0]!.nextReadDate = .distantPast }
            }

            try Task.checkCancellation()
            let now = Date()
            guard let definition = definitions.values.min(by: {
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
                try Task.checkCancellation()
                let timeToWait = max(emitInterval, definition.nextReadDate.timeIntervalSinceNow)
                try await Task.sleep(nanoseconds: UInt64(timeToWait * Double(NSEC_PER_SEC)))
            }

            let payload = try await device.endpoint.read(definition: definition,
                                                         deviceAddress: UInt16(device.configuration.modbusAddress))
            errorCounter = 0

            let retained = definition.mqtt == .retained || definition.interval == 0 || definition.interval > mqttAutoRetainTime
            let publishAlways = definition.publishalways ?? false

            if publishAlways || retained == false || retainedMessageCache[definition.topic] != payload.value
            {
                try await mqttClient.publish(MQTTMessage(topic: "\(device.configuration.topic)/\(definition.topic)",
                                                         payload: try payload.json(using: definition),
                                                         retain: retained))
                retainedMessageCache[definition.topic] = payload.value
            }

            definitions[definition.address]!.nextReadDate = definition.interval == 0
                ? .distantFuture
                : Date(timeIntervalSinceNow: definition.interval)
        }
        catch is CancellationError
        {
            return
        }
        catch
        {
            errorCounter = min(errorCounter + 1, 10)
            JLog.error("\(context) polling failed: \(error); consecutive errors: \(errorCounter)")

            if error is ModbusError
            {
                await device.endpoint.disconnect()
            }
            if errorCounter == 7
            {
                await device.recovery.attemptResetIfNeeded()
            }

            do
            {
                try await Task.sleep(nanoseconds: UInt64(Double(30 * errorCounter) * Double(NSEC_PER_SEC)))
            }
            catch
            {
                return
            }
        }
    }
}

private func serveMQTTRequests(client: MQTTClient,
                               router: MQTTRequestRouter,
                               runtimeDevices: [RuntimeModbusDevice],
                               requestTTL: Double) async
{
    let runtimeDevicesByTopic = Dictionary(uniqueKeysWithValues: runtimeDevices.map { ($0.configuration.topic, $0) })
    var knownRequests = [String: Set<MQTTRequest>]()

    for await message in client.messages
    {
        if Task.isCancelled { return }

        guard let route = router.route(for: message.topic),
              let runtimeDevice = runtimeDevicesByTopic[route.device.topic]
        else
        {
            JLog.warning("Received MQTT message without a configured route: \(message.topic)")
            continue
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = message.payload.string?.data(using: .utf8),
              let request = try? decoder.decode(MQTTRequest.self, from: data)
        else
        {
            JLog.error("Could not decode MQTT request on \(message.topic)")
            continue
        }

        let response: MQTTResponse
        do
        {
            let outdated = Date(timeIntervalSinceNow: -requestTTL)
            let tooFarInFuture = Date(timeIntervalSinceNow: requestTTL)
            let deviceRequests = knownRequests[route.device.topic, default: []]

            guard request.date > outdated else { throw MQTTRequestHandlingError.requestDateOutdated }
            guard request.date < tooFarInFuture else { throw MQTTRequestHandlingError.requestDateInFuture }
            guard deviceRequests.contains(request) == false else { throw MQTTRequestHandlingError.requestAnswered }
            guard let definition = runtimeDevice.definitions.values.first(where: { $0.topic == request.topic })
            else { throw MQTTRequestHandlingError.noTopicFound }
            guard definition.modbusaccess != .read
            else { throw MQTTRequestHandlingError.attributeNotWriteable }

            try await runtimeDevice.endpoint.write(request.value,
                                                   definition: definition,
                                                   deviceAddress: UInt16(route.device.modbusAddress))

            response = MQTTResponse(request: request, success: true)
        }
        catch
        {
            if error is ModbusError
            {
                await runtimeDevice.endpoint.disconnect()
            }
            JLog.error("Could not handle request for \(route.device.topic): \(error)")
            response = MQTTResponse(request: request, success: false, error: "\(error)")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        if let responseData = try? encoder.encode(response),
           let responseString = String(data: responseData, encoding: .utf8)
        {
            do
            {
                try await client.publish(MQTTMessage(topic: route.responseTopic,
                                                     payload: responseString,
                                                     retain: false))
                let outdated = Date(timeIntervalSinceNow: -requestTTL)
                var deviceRequests = knownRequests[route.device.topic, default: []]
                deviceRequests = deviceRequests.filter { $0.date >= outdated }
                deviceRequests.insert(request)
                knownRequests[route.device.topic] = deviceRequests
            }
            catch
            {
                JLog.error("Could not publish MQTT response on \(route.responseTopic): \(error)")
            }
        }
    }
}

private func restoreSubscriptions(client: MQTTClient,
                                  subscriptions: [String],
                                  generation: MQTTConnectionGeneration) async
{
    var retryDelay: UInt64 = 1

    while Task.isCancelled == false, client.isConnected
    {
        do
        {
            try await client.subscribe(to: subscriptions)
            await generation.advance()
            JLog.notice("Restored MQTT subscriptions after reconnect")
            return
        }
        catch is CancellationError
        {
            return
        }
        catch
        {
            JLog.error("Could not restore MQTT subscriptions; retrying in \(retryDelay) seconds: \(error)")
            do
            {
                try await Task.sleep(nanoseconds: retryDelay * UInt64(NSEC_PER_SEC))
            }
            catch
            {
                return
            }
            retryDelay = min(retryDelay * 2, 30)
        }
    }
}
