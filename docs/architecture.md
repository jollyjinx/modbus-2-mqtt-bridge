---
title: "Architecture"
description: "Package layout, runtime flow, and core types for the modbus2mqtt bridge."
audience:
  - agents
  - maintainers
status: "active"
related:
  - "../DOCUMENTATION.md"
  - "../Sources/modbus2mqtt/modbus2mqtt.swift"
  - "../Sources/SwiftLibModbus2MQTT/ModbusDefinition.swift"
  - "../Sources/SwiftLibModbus2MQTT/MQTTServer.swift"
---

# Architecture

`modbus2mqtt` is split into an executable target and a reusable library target.

## Targets

- `modbus2mqtt` executable: parses command-line options, sets up logging, loads the selected device definition file, configures MQTT and Modbus endpoints, and keeps the bridge running.
- `SwiftLibModbus2MQTT` library: contains the bridge models and helper logic used by the executable.

## Runtime Flow

1. The executable starts with command-line options for MQTT, Modbus, topic prefix, and device definition file.
2. The device definition JSON is decoded into `ModbusDefinition` values.
3. The bridge connects to the MQTT broker and Modbus device.
4. Readable definitions are polled according to their `interval`.
5. Modbus values are converted into MQTT payloads and published under the configured topic prefix.
6. Writable definitions can be changed through MQTT request messages.
7. The bridge publishes MQTT response messages for accepted write requests.

## MQTT Client Lifecycle

The executable tracks the `main` branch of the `jollyjinx/mqtt-nio` fork and uses its mqtt-nio 3.x API. Each serving attempt opens an `MQTTConnection` with `withConnection(...)`, subscribes to the configured request topics, and runs the subscription consumer alongside the Modbus pollers in one throwing task group.

mqtt-nio 3 delivers publish payloads as NIO `ByteBuffer` values. The bridge decodes request buffers as UTF-8 JSON and creates UTF-8 buffers for value and response publications. Topic shapes and JSON payload contracts remain owned by modbus2mqtt rather than the MQTT client library.

If the broker closes the connection, the subscription's async sequence throws. That error cancels the pollers, exits the scoped connection, and reaches the executable's outer restart loop. The loop then observes the configured restart delay before opening a new connection and subscriptions.

## Key Types

- `ModbusDefinition`: one register or coil definition from a JSON device map, including Modbus address, access mode, value type, topic, interval, scaling, mappings, and bit mappings.
- `ModbusValue`: a value read from a Modbus device, including converted and raw forms where applicable.
- `MQTTRequest`: decoded MQTT write command containing a target topic, value, timestamp, and request id.
- `MQTTResponse`: MQTT write result containing the matching request id, success flag, timestamp, and optional error.
- `MQTTServer`: MQTT connection configuration.
- `MQTTDevice`: Modbus endpoint configuration.
- `BitMapValues`: bit and bit-range mapping support for integer register values.

## Recovery Behavior

The executable is designed as a long-running bridge. Modbus communication failures are counted, repeated failures can trigger `--device-reset-url`, and the bridge resumes attempts after delays rather than treating transient failures as a reason to stop the process. MQTT connection and subscription failures end the current serving attempt so the outer service loop can establish a fresh scoped connection.

## Runtime Log Level

`SIGUSR1` cycles the log level through `debug`, `trace`, and `info`; other starting levels switch to `debug`. The executable ignores the default POSIX action and retains a `DispatchSourceSignal` on a dedicated serial queue for the lifetime of `run()`. Logging and level changes happen in that dispatch callback.

JLog evaluates message autoclosures while holding its nonrecursive logger mutex. Read `JLog.loglevel` into a local value before interpolating it into any JLog message. Reading it inside the message attempts to acquire the same mutex again, which traps on Linux and can trap or deadlock on macOS. Moving the callback to another queue alone cannot fix that recursive acquisition.

After `swift build`, run `python3 scripts/test_sigusr1.py .build/debug/modbus2mqtt` to exercise real signal delivery, logging, and repeated level transitions in child processes. The check uses reserved loopback ports without listeners and runs during the bridge's retry delay; it needs neither Modbus hardware nor an MQTT broker. It also accepts a release executable path and runs on macOS or Linux.
