# modbus2mqtt — bidirectional Modbus-to-MQTT bridge

`modbus2mqtt` exposes Modbus TCP and RTU devices through MQTT. It polls configured registers and coils, publishes typed JSON values, and translates validated MQTT request messages into Modbus writes.

The bridge supports one device or multiple logical devices in a single process. Multi-device mode shares one MQTT connection and one Modbus TCP connection per physical endpoint while keeping unit addresses, polling schedules, topics, and recovery state separate.

## Highlights

- Modbus TCP and serial RTU transports
- Read and write support through MQTT request/response topics
- Multi-device and multi-unit configurations
- Typed integers, floating-point values, strings, addresses, mappings, and bit fields
- Configurable scaling, floating-point resolution, polling, retention, and unchanged-value heartbeat
- Long-running retry behavior and optional HTTP device reset
- Linux container images for `amd64` and `arm64`
- Bundled device definitions plus support for custom JSON definitions

## Run the container

The stable image is published as `ghcr.io/jollyjinx/modbus-2-mqtt-bridge:latest`:

```sh
container run --name modbus2mqtt \
  ghcr.io/jollyjinx/modbus-2-mqtt-bridge:latest \
  modbus2mqtt \
  --modbus-server lambda.local \
  --mqtt-servername mqtt.local \
  --topic lambda \
  --device-description-file lambda.json
```

The default MQTT host is `mqtt`, the default port is `1883`, and the default Modbus TCP port is `502`. Use a pinned release tag instead of `latest` when reproducible deployment is important. The `development` image tag tracks the development branch.

To build locally:

```sh
container build . \
  --file modbus2mqtt.product.dockerfile \
  --tag modbus2mqtt

container run --name modbus2mqtt \
  modbus2mqtt \
  --modbus-server lambda.local \
  --device-description-file lambda.json \
  --topic lambda
```

## Build from source

Source builds require Swift 6.3 or newer. The package is developed for macOS and Linux.

```sh
swift build -c release --product modbus2mqtt
.build/release/modbus2mqtt --help
```

## Single-device configuration

Use `--modbus-server`, `--modbus-port`, and `--modbus-address` for Modbus TCP. For RTU, provide `--modbus-device-path` and optionally `--modbus-serial-speed`.

```sh
modbus2mqtt \
  --modbus-server meter.local \
  --modbus-address 1 \
  --mqtt-servername mqtt.local \
  --topic meters/main \
  --device-description-file b+ge-tech.sd100-00b.json
```

Broker credentials are available through `--mqtt-username` and `--mqtt-password`. Run `modbus2mqtt --help` for the complete, version-matched option list.

## Multiple devices

Use `--modbus-devices-file` for a JSON configuration file or `--modbus-devices-string` for inline JSON. These options are mutually exclusive and cannot be mixed with the legacy single-device endpoint, topic, definition, or reset options.

The checked-in [example configuration](Examples/config/modbus-devices.json) demonstrates two unit addresses behind one gateway and another device on a separate endpoint:

```sh
container run --name modbus2mqtt \
  --volume "$PWD/Examples/config:/config:ro" \
  ghcr.io/jollyjinx/modbus-2-mqtt-bridge:latest \
  modbus2mqtt \
  --mqtt-servername mqtt.local \
  --modbus-devices-file /config/modbus-devices.json
```

Each device entry provides `networkAddress`, optional `port` (default `502`), optional `modbusAddress` (default `3`), unique MQTT `topic`, `deviceDescriptionFile`, and optional `deviceResetURL`. Entries with the same host and port share a connection. They must use different host/unit combinations and MQTT topics; a shared endpoint must also use one consistent reset URL.

See [the multi-device architecture](docs/MULTI_DEVICE_ARCHITECTURE.md) for validation rules, topic routing, resource ownership, and recovery behavior.

## Bundled device definitions

| Definition | Device |
| --- | --- |
| `b+ge-tech.sd100-00b.json` / `.minimal.json` | B+G E-Tech SD100-00B energy meter |
| `daheimladen.json` | DaheimLader wallbox |
| `eastron.sdm72dm-v2.json` / `.minimal.json` | Eastron SDM72DM-V2 energy meter |
| `goodwe-et15-30.json` | GoodWe ET 15–30 solar inverter |
| `hanmatek.hm310t.json` | Hanmatek HM310T laboratory power supply |
| `lambda.json` | Lambda Eureka heat pumps |
| `lambda.solartherm.json` | Lambda heat pump with solar thermal integration |
| `nibe.s2125.json` | NIBE S2125 air/water heat pump |
| `phoenix.evcharger.json` | Phoenix Contact EV charge controller |
| `sma.sunnyboy.json` / `.all.json` | SMA Sunny Boy inverter |
| `sma.sunnystore.json` / `.all.json` | SMA Sunny Boy Storage |

Definitions bundled into the executable may be selected by filename. A readable filesystem path can be used for a custom definition. The `.minimal.json` files reduce the published register set; the SMA `.all.json` files expand it. For SMA-specific integrations, [sma2mqtt](https://github.com/jollyjinx/sma2mqtt) may be a better fit.

The format, supported fields, and copyable examples are documented in [docs/device-definitions.md](docs/device-definitions.md).

## MQTT topics and writes

Values are published below the configured base topic. A writable definition can be changed by publishing a request to:

```text
<base-topic>/request/<request-name>
```

The bridge replies on the corresponding response path:

```text
<base-topic>/response/<request-name>
```

Example request:

```json
{
  "value": 14.04,
  "date": "2026-07-22T08:43:22Z",
  "topic": "set/voltage",
  "id": "D2129DBF-9F94-46D7-86BC-4A07152FF1D8"
}
```

Requests outside `--mqtt-request-ttl` are rejected. The response uses the same UUID so clients can correlate the result. See [docs/mqtt-request-response.md](docs/mqtt-request-response.md) for the contract.

## Publication behavior

Changed values publish on their next configured poll. By default, unchanged non-retained values publish at most once every 15 seconds. Set `--mqtt-unchanged-publish-interval 0` to publish them on every poll.

This heartbeat does not add Modbus reads; a slowly polled value publishes on its next scheduled poll. Explicitly retained definitions keep their retained behavior, while `"publishalways": true` bypasses unchanged-value suppression. `--mqtt-auto-retain-time` controls automatic retention separately.

## Device reset

`--device-reset-url` can issue an HTTP GET after repeated communication failures, wait for the device to recover, and resume bridge attempts. Treat this URL as an operational control: restrict access to the bridge host, avoid embedding credentials in committed configuration, and verify that repeated calls are safe for the target device.

In multi-device mode the reset URL belongs to the physical host/port endpoint. A reset can affect every unit behind that endpoint.

## Development and documentation

```sh
swift build
swift test
```

Maintainers can publish branch-tagged AMD64/ARM64 images to Gitmaster or GHCR with
`scripts/build_and_push_image.sh`; see [the container build guide](docs/container-builds.md).

The test suite includes JSON decoding, device configuration, publication policy, request routing, and bridge-level behavior. Tests and builds should not require live Modbus devices or an external MQTT broker unless a test explicitly documents that dependency.

Start with [DOCUMENTATION.md](DOCUMENTATION.md) for the maintained documentation map. Agent-oriented routing is available in [AI/README.md](AI/README.md).

## License

`modbus2mqtt` is available under the [MIT License](LICENSE). Its dependencies retain their respective licenses.
