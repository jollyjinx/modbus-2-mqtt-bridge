---
title: modbus2mqtt agent documentation
description: Routing index for architecture, device-definition, MQTT-contract, and documentation-maintenance guidance.
audience:
  - agents
  - maintainers
status: active
entry_point: true
last_updated: 2026-07-22
related:
  - ../README.md
  - ../DOCUMENTATION.md
---

# Agent documentation

Use [DOCUMENTATION.md](../DOCUMENTATION.md) as the authoritative documentation index. This `AI/` entry point exists so repository-wide tooling can discover the established front-matter documentation set without duplicating its content.

## Routing

- Consumer setup, containers, common CLI modes, and supported devices: [README.md](../README.md)
- Package targets and runtime flow: [docs/architecture.md](../docs/architecture.md)
- Container build and publication workflow: [docs/container-builds.md](../docs/container-builds.md)
- Multi-device ownership, routing, recovery, and validation: [docs/MULTI_DEVICE_ARCHITECTURE.md](../docs/MULTI_DEVICE_ARCHITECTURE.md)
- Device-definition fields and examples: [docs/device-definitions.md](../docs/device-definitions.md)
- MQTT write request/response contract: [docs/mqtt-request-response.md](../docs/mqtt-request-response.md)
- Unchanged-value publication design and implementation record: [docs/mqtt-unchanged-publish-interval-plan.md](../docs/mqtt-unchanged-publish-interval-plan.md)
- Documentation conventions: [docs/documentation-style.md](../docs/documentation-style.md)

## Validation baseline

Run `swift build` and `swift test` from the repository root. For documentation-only changes, also parse the YAML front matter, resolve local links, and validate any edited JSON examples. Do not require attached Modbus hardware or an external MQTT broker for the default test suite.

Preserve the external contracts unless a deliberate breaking change is requested: device-definition decoding, MQTT topic shapes, request/response payloads, and CLI configuration compatibility.
