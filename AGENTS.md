---
name: spm-local-modbus2mqtt
description: Guidance for working on the local modbus2mqtt Swift package. Use when changing Package.swift, the Modbus/MQTT bridge runtime, device definition loading, reconnect/error handling, container build files, or package tests.
---

# modbus2mqtt

Use this skill when work touches `/Users/jolly/GitHub/modbus2mqtt`.

## Scope

- `Package.swift` defines the executable, library target, and external package dependencies.
- `Sources/modbus2mqtt` contains the CLI entry point, long-running bridge loop, and retry/restart behavior.
- `Sources/SwiftLibModbus2MQTT` contains shared device-definition parsing, MQTT helpers, and payload models.
- `DeviceDefinitions` contains bundled JSON device maps that must stay backward compatible unless a breaking change is intentional.
- `Tests/modbus2mqttTests` covers JSON decoding and bridge-level behavior.
- `modbus2mqtt.product.dockerfile` and `README.md` contain container/runtime examples; use Docker in workflows.

## Working Rules

- Assume Swift 6.2 with strict concurrency enabled.
- Favor small fixes that improve long-running bridge resilience under transient Modbus or MQTT failures.
- Preserve published MQTT topic shapes and request/response behavior unless explicitly asked to change the external contract.
- When diagnosing transport issues, inspect checked out dependency code under `.build/checkouts/SwiftLibModbus` and `.build/checkouts/mqtt-nio` before changing package-local logic.
- Prefer package-local recovery or instrumentation before forking dependency behavior.

## Validation

- Prefer `swift build` and targeted `swift test` from `/Users/jolly/GitHub/modbus2mqtt`.
- For reconnect or retry changes, verify the executable still compiles and review the relevant `run()` / `startServing(...)` log flow.
