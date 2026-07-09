---
title: "Device Definitions"
description: "JSON device definition format and bundled device maps for modbus2mqtt."
audience:
  - agents
  - maintainers
status: "active"
related:
  - "../README.md"
  - "../DeviceDefinitions"
  - "../Sources/SwiftLibModbus2MQTT/ModbusDefinition.swift"
---

# Device Definitions

Device definition files control which Modbus values are exposed over MQTT. Bundled definitions live in `DeviceDefinitions/` and custom definitions can be passed with `--device-description-file`.

## Bundled Definitions

- `b+ge-tech.sd100-00b.json`: B+G E-Tech SD100-00B energy meter.
- `daheimladen.json`: DaheimLader wallbox.
- `eastron.sdm72dm-v2.json`: Eastron SDM72DM-V2 energy meter.
- `goodwe-et15-30.json`: GoodWe ET 15-30 solar inverter.
- `hanmatek.hm310t.json`: Hanmatek HM310T laboratory power supply.
- `lambda.json`: Lambda Eureka heat pumps.
- `lambda.solartherm.json`: Lambda heat pump with solar thermal integration.
- `phoenix.evcharger.json`: Phoenix Contact electric vehicle charge controller.
- `sma.sunnyboy.json` and `sma.sunnyboy.all.json`: SMA Sunny Boy inverter definitions.
- `sma.sunnystore.json` and `sma.sunnystore.all.json`: SMA Sunny Boy Storage definitions.

The `.all.json` files contain extended register sets. For SMA devices, `sma2mqtt` can be a better fit when SMA-specific support is needed.

## Definition Fields

Common fields include:

- `address`: Modbus register or coil address.
- `modbustype`: Modbus area, such as `holding` or `coil`.
- `modbusaccess`: allowed access mode, such as `read`, `write`, or `readwrite`.
- `valuetype`: decoded value type, such as `string`, `uint16`, `int32`, `float`, `ipv4address`, or `macaddress`.
- `length`: length for value types that need it, especially strings.
- `interval`: polling interval in seconds. `0` means the value is requested at startup and then retained through MQTT.
- `factor`: optional multiplier applied to numeric values.
- `unit`: optional display unit.
- `mqtt`: MQTT visibility or retention behavior, such as `visible`, `invisible`, or `retained`.
- `topic`: MQTT topic suffix for the value.
- `title`: human-readable label.
- `map`: optional mapping from raw values to named values.
- `bits`: optional mapping from individual bits or bit ranges to named fields.

## Example

JSON does not allow comments; this example omits comments so it can be copied into a definition file.

```json
[
  {
    "address": 30581,
    "modbustype": "holding",
    "modbusaccess": "read",
    "valuetype": "uint32",
    "factor": 0.001,
    "unit": "kWh",
    "mqtt": "visible",
    "interval": 1000,
    "topic": "counter/totalusage",
    "title": "Total Yield"
  },
  {
    "address": 1,
    "modbustype": "holding",
    "modbusaccess": "read",
    "valuetype": "uint16",
    "mqtt": "visible",
    "interval": 5,
    "map": {
      "0": "OFF",
      "1": "AUTOMATIC",
      "2": "MANUAL",
      "3": "ERROR"
    },
    "topic": "ambient/operatingstate",
    "title": "Ambient Operating State"
  },
  {
    "address": 2,
    "modbustype": "holding",
    "modbusaccess": "read",
    "valuetype": "uint16",
    "mqtt": "visible",
    "interval": 5,
    "bits": {
      "0": { "name": "running" },
      "1-3": { "name": "mode" },
      "4-15": { "name": "reserved" }
    },
    "topic": "test/state",
    "title": "Test State"
  }
]
```

