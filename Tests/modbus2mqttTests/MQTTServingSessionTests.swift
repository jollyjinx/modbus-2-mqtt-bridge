import SwiftLibModbus2MQTT
import Testing

struct MQTTServingSessionTests
{
    private enum WorkerEvent: Equatable, Sendable
    {
        case started
        case stopped
    }

    private enum TestError: Error, Equatable, Sendable
    {
        case disconnected(String)
    }

    @Test
    func disconnectCancelsWorkersAndEndsSession() async
    {
        let (disconnectEvents, disconnectContinuation) = AsyncStream.makeStream(of: TestError.self)
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
                workers: [
                    {
                        for await event in disconnectEvents
                        {
                            throw event
                        }
                        try Task.checkCancellation()
                    },
                    {
                        workerEventsContinuation.yield(.started)
                        for await _ in workerBlocker {}
                        workerEventsContinuation.yield(.stopped)
                    },
                ]
            )
        }

        #expect(await workerEventIterator.next() == .started)

        let expectedError = TestError.disconnected("broker restart")
        disconnectContinuation.yield(expectedError)
        disconnectContinuation.finish()

        do
        {
            try await sessionTask.value
            Issue.record("Expected the serving session to end after MQTT disconnected")
        }
        catch let error as TestError
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
    func workerFailurePropagates() async
    {
        let expectedError = TestError.disconnected("connection closed during setup")

        do
        {
            try await runMQTTServingSession(workers: [
                {
                    throw expectedError
                },
            ])
            Issue.record("Expected the buffered MQTT disconnect to end the serving session")
        }
        catch let error as TestError
        {
            #expect(error == expectedError)
        }
        catch
        {
            Issue.record("Unexpected serving-session error: \(error)")
        }
    }
}
