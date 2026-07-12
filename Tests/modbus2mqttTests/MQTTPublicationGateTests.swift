import Foundation
import SwiftLibModbus2MQTT
import Testing

struct MQTTPublicationGateTests
{
    private let topic = "meters/power"
    private let initialDate = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test
    func initialValuePublishes()
    {
        let gate = MQTTPublicationGate()

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: false,
                                   publishAlways: false,
                                   at: initialDate,
                                   unchangedPublishInterval: 15))
    }

    @Test
    func changedValuePublishesImmediately()
    {
        let gate = recordedGate(value: .uint16(10))

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(11),
                                   retained: false,
                                   publishAlways: false,
                                   at: date(secondsAfterInitial: 1),
                                   unchangedPublishInterval: 15))
    }

    @Test
    func unchangedValueBeforeIntervalIsSkipped()
    {
        let gate = recordedGate(value: .uint16(10))

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: false,
                                   publishAlways: false,
                                   at: date(secondsAfterInitial: 14.999),
                                   unchangedPublishInterval: 15) == false)
    }

    @Test(arguments: [15.0, 16.0])
    func unchangedValueAtOrAfterIntervalPublishes(elapsed: TimeInterval)
    {
        let gate = recordedGate(value: .uint16(10))

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: false,
                                   publishAlways: false,
                                   at: date(secondsAfterInitial: elapsed),
                                   unchangedPublishInterval: 15))
    }

    @Test
    func successfulHeartbeatStartsNewInterval()
    {
        var gate = recordedGate(value: .uint16(10))
        gate.recordSuccessfulPublication(topic: topic,
                                         value: .uint16(10),
                                         at: date(secondsAfterInitial: 15))

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: false,
                                   publishAlways: false,
                                   at: date(secondsAfterInitial: 29),
                                   unchangedPublishInterval: 15) == false)
        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: false,
                                   publishAlways: false,
                                   at: date(secondsAfterInitial: 30),
                                   unchangedPublishInterval: 15))
    }

    @Test
    func unrecordedPublicationDoesNotStartNewInterval()
    {
        let gate = recordedGate(value: .uint16(10))

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: false,
                                   publishAlways: false,
                                   at: date(secondsAfterInitial: 15),
                                   unchangedPublishInterval: 15))
        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: false,
                                   publishAlways: false,
                                   at: date(secondsAfterInitial: 16),
                                   unchangedPublishInterval: 15))
    }

    @Test
    func retainedUnchangedValueIsSuppressed()
    {
        let gate = recordedGate(value: .uint16(10))

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: true,
                                   publishAlways: false,
                                   at: date(secondsAfterInitial: 60),
                                   unchangedPublishInterval: 15) == false)
    }

    @Test
    func publishAlwaysOverridesSuppression()
    {
        let gate = recordedGate(value: .uint16(10))

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: true,
                                   publishAlways: true,
                                   at: date(secondsAfterInitial: 1),
                                   unchangedPublishInterval: 15))
    }

    @Test
    func zeroIntervalPreservesNonRetainedPublishEveryPollBehavior()
    {
        let gate = recordedGate(value: .uint16(10))

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: false,
                                   publishAlways: false,
                                   at: initialDate,
                                   unchangedPublishInterval: 0))
    }

    @Test
    func resetForcesPublication()
    {
        var gate = recordedGate(value: .uint16(10))
        gate.reset()

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: true,
                                   publishAlways: false,
                                   at: date(secondsAfterInitial: 1),
                                   unchangedPublishInterval: 15))
    }

    @Test
    func slowPollAfterDeadlinePublishes()
    {
        let gate = recordedGate(value: .uint16(10))

        #expect(gate.shouldPublish(topic: topic,
                                   value: .uint16(10),
                                   retained: false,
                                   publishAlways: false,
                                   at: date(secondsAfterInitial: 45),
                                   unchangedPublishInterval: 15))
    }

    private func recordedGate(value: ModbusType) -> MQTTPublicationGate
    {
        var gate = MQTTPublicationGate()
        gate.recordSuccessfulPublication(topic: topic, value: value, at: initialDate)
        return gate
    }

    private func date(secondsAfterInitial seconds: TimeInterval) -> Date
    {
        initialDate.addingTimeInterval(seconds)
    }
}
