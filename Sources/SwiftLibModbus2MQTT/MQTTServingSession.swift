package enum MQTTServingSessionError: Error, Equatable, Sendable, CustomStringConvertible
{
    case disconnected(String)

    package var description: String
    {
        switch self
        {
            case let .disconnected(reason):
                "MQTT disconnected: \(reason)"
        }
    }
}

package typealias MQTTServingWorker = @Sendable () async throws -> Void

package func runMQTTServingSession(until disconnectEvents: AsyncStream<MQTTServingSessionError>,
                                   workers: [MQTTServingWorker]) async throws
{
    try await withThrowingTaskGroup(of: Void.self)
    { group in
        group.addTask
        {
            for await event in disconnectEvents
            {
                throw event
            }

            try Task.checkCancellation()
        }

        for worker in workers
        {
            group.addTask(operation: worker)
        }

        for try await _ in group {}
    }
}
