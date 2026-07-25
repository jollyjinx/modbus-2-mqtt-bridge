import SwiftLibModbus2MQTT
import Testing

struct MQTTServingSessionTests
{
    private enum WorkerEvent: Equatable, Sendable
    {
        case started
        case stopped
    }

    @Test
    func disconnectCancelsWorkersAndEndsSession() async
    {
        let (disconnectEvents, disconnectContinuation) = AsyncStream.makeStream(
            of: MQTTServingSessionError.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let (workerBlocker, workerBlockerContinuation) = AsyncStream.makeStream(of: Void.self)
        let (workerEvents, workerEventsContinuation) = AsyncStream.makeStream(
            of: WorkerEvent.self,
            bufferingPolicy: .bufferingNewest(2)
        )
        defer
        {
            disconnectContinuation.finish()
            workerBlockerContinuation.finish()
            workerEventsContinuation.finish()
        }

        var workerEventIterator = workerEvents.makeAsyncIterator()
        let sessionTask = Task
        {
            try await runMQTTServingSession(
                until: disconnectEvents,
                workers: [
                    {
                        workerEventsContinuation.yield(.started)
                        for await _ in workerBlocker {}
                        workerEventsContinuation.yield(.stopped)
                    },
                ]
            )
        }

        #expect(await workerEventIterator.next() == .started)

        let expectedError = MQTTServingSessionError.disconnected("broker restart")
        disconnectContinuation.yield(expectedError)
        disconnectContinuation.finish()

        do
        {
            try await sessionTask.value
            Issue.record("Expected the serving session to end after MQTT disconnected")
        }
        catch let error as MQTTServingSessionError
        {
            #expect(error == expectedError)
        }
        catch
        {
            Issue.record("Unexpected serving-session error: \(error)")
        }

        #expect(await workerEventIterator.next() == .stopped)
    }

    @Test
    func bufferedDisconnectEndsSessionBeforeWorkersStart() async
    {
        let (disconnectEvents, disconnectContinuation) = AsyncStream.makeStream(
            of: MQTTServingSessionError.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let expectedError = MQTTServingSessionError.disconnected("connection closed during setup")
        disconnectContinuation.yield(expectedError)
        disconnectContinuation.finish()

        do
        {
            try await runMQTTServingSession(until: disconnectEvents, workers: [])
            Issue.record("Expected the buffered MQTT disconnect to end the serving session")
        }
        catch let error as MQTTServingSessionError
        {
            #expect(error == expectedError)
        }
        catch
        {
            Issue.record("Unexpected serving-session error: \(error)")
        }
    }
}
