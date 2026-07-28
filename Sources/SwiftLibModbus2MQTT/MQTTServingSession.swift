package typealias MQTTServingWorker = @Sendable () async throws -> Void

package func runMQTTServingSession(workers: [MQTTServingWorker]) async throws
{
    try await withThrowingTaskGroup(of: Void.self)
    { group in
        for worker in workers
        {
            group.addTask(operation: worker)
        }

        for try await _ in group {}
    }
}
