---
title: "MQTT Unchanged Publish Interval Implementation Plan"
description: "Plan for suppressing unchanged non-retained MQTT values while preserving periodic heartbeat publications."
audience:
  - agents
  - maintainers
status: "draft"
related:
  - "../README.md"
  - "../Sources/modbus2mqtt/modbus2mqtt.swift"
  - "../Sources/modbus2mqtt/MultiDeviceServing.swift"
  - "../Sources/SwiftLibModbus2MQTT/ModbusValue.swift"
---

# MQTT Unchanged Publish Interval Implementation Plan

## Goal

Reduce steady-state CPU consumption and MQTT traffic by suppressing unchanged
non-retained values while still publishing a periodic heartbeat. Changed values
must continue to be published at the first Modbus poll that observes the change.

## User-Visible Behavior

Add a process-wide command-line option:

```text
--mqtt-unchanged-publish-interval 15
```

The option is measured in seconds and defaults to `15`. Setting it to `0`
restores the existing behavior for non-retained topics, where every successful
poll is published.

Publication rules:

1. Publish the initial value immediately.
2. Publish a changed value immediately after the poll that observes it.
3. For a non-retained topic whose value is unchanged, publish on the first poll
   at or after the configured unchanged-publish interval.
4. Preserve the existing change-only behavior for retained topics.
5. Preserve `publishalways: true` as an override that publishes every poll.
6. Clear publication state after MQTT reconnect so all current values are
   republished.
7. Do not add Modbus reads solely to meet the MQTT heartbeat interval. A topic
   polled less frequently than the configured interval publishes on its next
   scheduled poll.

## Design

### Shared Publication Gate

Add a small value type to `SwiftLibModbus2MQTT` that owns per-topic publication
state:

- the last successfully published `ModbusType` value;
- the time of the last successful publication.

The gate receives the current value, retention state, `publishalways` flag,
current time, and unchanged-publish interval. Keep the publication decision and
successful-publication recording as separate operations so a failed MQTT
publish never advances the heartbeat deadline.

Time is supplied by the caller. This keeps the policy deterministic and allows
unit tests to use fixed dates without sleeping.

### Runtime Integration

Replace the existing retained-value dictionaries in both serving paths with the
shared gate:

- legacy single-device polling in `Sources/modbus2mqtt/modbus2mqtt.swift`;
- multi-device polling in `Sources/modbus2mqtt/MultiDeviceServing.swift`.

Both paths must use identical policy rules. They should record state only after
`MQTTClient.publish` succeeds and reset state when MQTT reconnects.

The change must preserve MQTT topic names, payload JSON, retain flags, QoS,
Modbus polling intervals, and request/response behavior.

## Test Plan

Add deterministic Swift Testing coverage for the publication gate:

- an initial value publishes;
- a changed value publishes immediately;
- an unchanged value before the interval is skipped;
- an unchanged value at and after the interval publishes;
- a successful heartbeat starts a new interval;
- a failed or unrecorded publication does not start a new interval;
- retained unchanged values remain suppressed;
- `publishalways` overrides suppression;
- interval `0` preserves legacy non-retained behavior;
- resetting state forces a new publication;
- a caller-provided later poll time correctly models slow Modbus polling.

Tests must not use wall-clock delays or networking.

## Documentation

Update `README.md` with:

- the new CLI option and default;
- an example using a 15-second heartbeat;
- `0` as the legacy behavior;
- interaction with `--mqtt-auto-retain-time`, explicit `mqtt: retained`, and
  `publishalways`;
- clarification that this option changes MQTT publication frequency, not Modbus
  polling frequency.

## Validation

1. Run the targeted publication-policy tests.
2. Run the complete Swift test suite.
3. Build the release executable.
4. Run the mock Modbus/MQTT workload used during diagnosis and compare CPU time
   and publish counts before and after the change.
5. Review cancellation, reconnect, and actor-isolation behavior under Swift 6.2
   strict concurrency.
6. Confirm the working tree contains no temporary profiling artifacts.

## Acceptance Criteria

- Stable non-retained values publish no more frequently than the configured
  unchanged-publish interval.
- Changed values publish at the first poll that observes the change.
- Initial connection and reconnection force current values to be published.
- Retained topics and `publishalways` preserve their established behavior.
- Both legacy and multi-device serving modes use the same tested policy.
- All tests and the release build pass.
- A repeatable stress run shows materially lower CPU use for stable values.
