---
title: "MQTT Request Response"
description: "MQTT write request and response flow for changing Modbus values."
audience:
  - agents
  - maintainers
status: "active"
related:
  - "../README.md"
  - "../Sources/SwiftLibModbus2MQTT/MQTTRequestResponse.swift"
  - "../Sources/SwiftLibModbus2MQTT/MQTTServer.swift"
---

# MQTT Request Response

`modbus2mqtt` can write values back to a Modbus device through MQTT. Writes use a request/response pattern so callers can correlate a command with its result.

## Topic Shape

For a bridge topic prefix such as `hm310`, write requests are sent under:

```text
hm310/request/<request-name>
```

The response is published under the matching response path:

```text
hm310/response/<request-name>
```

## Request Payload

The request contains a timestamp, request id, target value topic, and new value:

```json
{
  "value": 14.04,
  "date": "2022-10-21T08:43:22Z",
  "topic": "set/voltage",
  "id": "D2129DBF-9F94-46D7-86BC-4A07152FF1D8"
}
```

The target topic is matched against writable device definitions. The value is converted to the Modbus type defined for that address before being written.

## Swift Models

The request and response models are defined in `MQTTRequestResponse.swift`.

```swift
struct MQTTRequest: Encodable, Decodable, Hashable, Equatable {
    let date: Date
    let id: UUID
    let topic: String
    let value: MQTTCommandValue
}

struct MQTTResponse: Encodable, Decodable {
    let date: Date
    let id: UUID
    let success: Bool
    let error: String?
}
```

The response uses the same `id` as the request. Request timestamps must be within the configured MQTT request TTL.

