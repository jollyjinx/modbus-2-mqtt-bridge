import Foundation

public struct MQTTPublicationGate: Sendable
{
    private struct Publication: Sendable
    {
        let value: ModbusType
        let date: Date
    }

    private var publications = [String: Publication]()

    public init() {}

    public func shouldPublish(topic: String,
                              value: ModbusType,
                              retained: Bool,
                              publishAlways: Bool,
                              at date: Date,
                              unchangedPublishInterval: TimeInterval) -> Bool
    {
        if publishAlways
        {
            return true
        }

        guard let publication = publications[topic]
        else
        {
            return true
        }

        if publication.value != value
        {
            return true
        }

        if retained
        {
            return false
        }

        if unchangedPublishInterval <= 0
        {
            return true
        }

        return date.timeIntervalSince(publication.date) >= unchangedPublishInterval
    }

    public mutating func recordSuccessfulPublication(topic: String,
                                                     value: ModbusType,
                                                     at date: Date)
    {
        publications[topic] = Publication(value: value, date: date)
    }

    public mutating func reset()
    {
        publications.removeAll(keepingCapacity: true)
    }
}
