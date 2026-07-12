# Multi-device Modbus architecture

## Goal

Run several logical Modbus devices in one `modbus2mqtt` process while sharing resources at their natural boundaries:

- one MQTT connection for the process;
- one Modbus connection for each unique physical endpoint;
- one independently scheduled logical device for each Modbus unit address and MQTT topic.

For example, two meters connected through one Waveshare gateway and one separate Lambda host should use this topology:

```text
modbus2mqtt process
├── MQTT connection
├── 10.112.1.2:502 connection
│   ├── unit 1 → counters/heatpump
│   └── unit 2 → counters/boiler
└── 10.112.1.3:502 connection
    └── unit 1 → lambda
```

## Configuration

The preferred interface is a JSON configuration file passed with `--modbus-devices-file`:

```json
{
  "devices": [
    {
      "networkAddress": "10.112.1.2",
      "port": 502,
      "modbusAddress": 1,
      "topic": "counters/heatpump",
      "deviceDescriptionFile": "/waveshare/b+ge-tech.sd100-00b.json"
    },
    {
      "networkAddress": "10.112.1.2",
      "port": 502,
      "modbusAddress": 2,
      "topic": "counters/boiler",
      "deviceDescriptionFile": "/waveshare/b+ge-tech.sd100-00b.json"
    },
    {
      "networkAddress": "10.112.1.3",
      "port": 502,
      "modbusAddress": 1,
      "topic": "lambda",
      "deviceDescriptionFile": "lambda.json"
    }
  ]
}
```

The existing single-device command-line options remain supported. When no devices file is supplied, they are converted internally into a one-element device configuration. Supplying a devices file together with explicitly supplied legacy device options is a configuration error.

Startup validation rejects empty device lists, duplicate MQTT base topics, MQTT wildcard characters, invalid ports or unit identifiers, and missing device-description files. Topic paths are normalized by removing leading and trailing slashes.

## Runtime model

### Physical endpoints

A physical endpoint is identified by network address and port. Configurations with an identical endpoint key share one `ModbusDevice` actor and therefore one TCP connection.

The endpoint actor serializes all I/O. Every operation includes the target unit address, and selecting the unit plus performing the libmodbus operation is atomic within actor isolation:

```text
connect if necessary → select unit → perform I/O → return
```

Exposing `setDeviceAddress()` separately from reads and writes is explicitly avoided because another polling or MQTT request task could interleave between the calls.

### Logical devices

Each configuration entry creates a logical device containing:

- its physical endpoint reference;
- Modbus unit address;
- MQTT base topic;
- local register definitions;
- polling schedule;
- retained-value cache;
- request duplicate cache;
- retry and error state.

Logical devices never own MQTT connections or physical Modbus connections.

### MQTT

One MQTT client connects before logical-device workers start. It subscribes to every configured request namespace and has exactly one message-consumer loop. That loop routes messages by configured base topic, executes the write against the selected logical device, and publishes on the corresponding response path.

Polling workers publish through the same MQTT owner. MQTT reconnection and resubscription are centralized so multiple workers cannot initiate competing reconnect attempts. After a reconnect, retained caches are invalidated so current retained values are republished.

### Supervision and cancellation

Each logical device has an independently supervised polling worker. Operational failure in one worker is handled locally and does not cancel other workers. Process shutdown cancels the MQTT router and all polling workers, then disconnects every unique Modbus endpoint and the MQTT client.

Structured concurrency owns worker lifetimes. Long-running loops check cancellation at natural suspension points.

## Definition isolation

Register definitions must not use process-global mutable state. Each logical device loads and owns its definition map. MQTT payload encoding receives the relevant `ModbusDefinition` explicitly, preventing values from concurrently loaded device types from using the wrong title, unit, map, bits, or topic.

## Failure isolation

Error state is scoped according to the failing resource:

- register or unit failures update only the logical device;
- TCP failures disconnect and recover only the affected physical endpoint;
- MQTT failures are recovered once by the shared MQTT owner;
- configuration and definition failures prevent startup.

An endpoint reset URL, when configured, belongs to the physical endpoint because resetting a gateway affects every logical device behind it. Reset attempts require endpoint-wide coordination and cooldown.

Logs include endpoint, unit, and topic context, for example:

```text
[10.112.1.2:502 unit=2 topic=counters/boiler]
```

## Delivery sequence

1. Remove global definition state and make payload encoding explicit.
2. Add atomic unit-address-aware operations to `SwiftLibModbus` while preserving existing APIs.
3. Add configuration decoding, validation, and legacy-option conversion.
4. Pool physical endpoints by network address and port.
5. Extract address-aware register read and write operations.
6. Introduce the single MQTT owner and request router.
7. Add independently supervised logical-device polling workers.
8. Add endpoint-, device-, and MQTT-scoped recovery.
9. Complete unit, concurrency, routing, recovery, compatibility, and integration tests.
10. Update deployment documentation and examples.

## Acceptance criteria

For the example configuration, the completed implementation must demonstrate:

- one `modbus2mqtt` process;
- one MQTT broker connection;
- one TCP connection to `10.112.1.2:502`;
- one TCP connection to `10.112.1.3:502`;
- safe multiplexing of units 1 and 2 over the Waveshare connection;
- independent MQTT topics and request/response paths;
- device-local definitions and retained caches;
- continued Lambda polling during a Waveshare or meter failure;
- unchanged behavior for existing single-device commands.
