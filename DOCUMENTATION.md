---
title: "modbus2mqtt Documentation"
description: "Agent-oriented documentation index for the modbus2mqtt Swift package."
audience:
  - agents
  - maintainers
status: "active"
entry_point: true
front_matter_required: true
related:
  - "README.md"
  - "docs/architecture.md"
  - "docs/device-definitions.md"
  - "docs/mqtt-request-response.md"
  - "docs/documentation-style.md"
---

# modbus2mqtt Documentation

This file is the agent-oriented documentation entry point for **modbus2mqtt**. The project README remains plain Markdown for GitHub users, while this file and the topic files under `docs/` use YAML front matter so agents can classify, route, and search documentation consistently.

## Front Matter Convention

All agent-oriented documentation files should start with YAML front matter:

```yaml
---
title: "Short Human Title"
description: "One sentence describing the file's purpose."
audience:
  - agents
  - maintainers
status: "active"
related:
  - "README.md"
---
```

Use the front matter to describe the file before the Markdown body begins. Keep `README.md` as plain Markdown unless the project intentionally changes how it is presented on GitHub.

## Documentation Map

- [Architecture](docs/architecture.md): package layout, runtime flow, and important types.
- [Device Definitions](docs/device-definitions.md): JSON device definition format and bundled device files.
- [MQTT Request/Response](docs/mqtt-request-response.md): write flow for Modbus values through MQTT.
- [Documentation Style](docs/documentation-style.md): rules for adding or changing documentation files.

## Project Summary

`modbus2mqtt` is a bidirectional bridge that connects Modbus devices to an MQTT broker. It monitors Modbus registers, publishes values to MQTT topics, and accepts MQTT write requests that are translated back into Modbus writes.

The project is written in Swift and runs on macOS and Linux. It is configured through command-line options and JSON device definition files.

## Main Components

- `Sources/modbus2mqtt`: executable entry point, command-line parsing, and long-running bridge loop.
- `Sources/SwiftLibModbus2MQTT`: shared parsing, Modbus value modelling, MQTT request/response helpers, and runtime bridge support.
- `DeviceDefinitions`: bundled JSON maps for supported devices.
- `Tests/modbus2mqttTests`: package tests for decoding and bridge-level behavior.

## Command-Line Options

Run the executable with `--help` for the current command-line options:

```bash
swift run modbus2mqtt --help
```

