---
title: "NIBE S2125 / SMO S40 register audit"
description: "NIBE counter decoding, scaling, settings, and model-specific availability checked against documentation, live telemetry, REST metadata, and the controller USB export."
audience:
  - agents
  - maintainers
status: "active"
related:
  - "device-definitions.md"
  - "nibe-s2125-smo-s40-device-registers.csv"
  - "../DeviceDefinitions/nibe.S2125-SMO-S40.json"
  - "../Sources/SwiftLibModbus2MQTT/ModbusDefinitionIO.swift"
  - "../Tests/modbus2mqttTests/NIBERegisterReadTests.swift"
---

# S2125 / SMO S40 register audit

Reviewed on 2026-09-26. The filename is `nibe.S2125-SMO-S40.json`; the initial commit description called it S2150. This audit concerns S2125/F2120 slave 1 (EB101) behind SMO S40.

## Sources and confidence

- User-supplied **Technical information Modbus S-Series.pdf**: page 8 contains the SMO S40 and S2125/F2120 slave 1 tables; pages 7, 10, and 11-12 provide other-model and common-register comparisons. The local PDF is a re-export, so its creation timestamp does not establish the original document revision.
- [NIBE's official M12676EN, TIF EN 2608](https://professional.nibe.eu/document/Technical%20information%20(TIF)/M12676EN.pdf): page 6 explicitly describes reversed register order for 32-bit values; page 12 confirms the S2125/F2120 slave 1 counter addresses. This is useful information absent from the supplied PDF.
- The user confirmed that **Technical information Modbus S-Series.2026.pdf** is the same document as the official TIF EN 2608 download. The local file was inaccessible to the process, so the official copy was used; the SMO S40 and S2125 slave 1 tables on pages 10 and 12 were visually checked.
- Read-only MQTT observation of `nibe/#` on the user-provided broker. Counter samples below were retained messages; they establish what was published, not the controller's current display or register contents.
- A 310-second capture saw all 35 configured topics and fresh publications on 10 of them. Compressor frequency was freshly reported as zero; the counters were observed only as retained messages during that interval.
- The device REST API returned 1,165 point records containing English titles, Modbus metadata, writeability flags, descriptions and a live value snapshot.
- Two menu 7.5.9 USB exports from the controller were byte-identical. Each contains 1,164 German-language Modbus rows: 604 input registers and 560 holding registers. They match the REST address, area, divisor, unit, value type, limits and defaults, apart from localized units and omitted limits for date/time values. The REST-only `MODBUS_NO_REGISTER` point explains the one-row difference.
- [The generated English CSV catalogue](nibe-s2125-smo-s40-device-registers.csv) preserves the metadata, writeability flags and current MQTT-definition mapping without copying live values.
- Checked-out `SwiftLibModbus` typed-read implementation and loopback Modbus TCP regression tests.

The controller's own REST and USB exports are the best sources for this firmware and installation. Do not substitute another model's addresses solely because its table includes a similar label. Three exported rows use address zero and are not safe polling targets; one REST point has no Modbus register.

## Confirmed defects and local corrections

1. **32-bit word order:** all five 32-bit values in this definition used the default high-word-first decoder. Set `endianness: littleEndian` for 1489, 1491, 1493, 1583, and 1585. With the checked-out dependency on supported little-endian macOS/Linux targets, that combines libmodbus's host-order UInt16 words low-word-first; it does not reverse each register's wire bytes.
2. **Runtime scaling and type:** the device exports specify `u32`, divisor 1 and hours for 1491 and 1493. Both therefore use `uint32` without a factor. This supersedes the earlier interpretation of the abbreviated manual table. The exports confirm that 1493 is available on this installation. Exported signed minimum values for these unsigned counters are internally inconsistent and are not imported.
3. **Numeric 8-bit reads:** the default dependency UInt8 read selected the high byte, so a register containing `0x0001` became zero. The package-local reader now reads one UInt16 register and narrows its low byte for both `uint8` and `int8`. String, hexadecimal, IP and MAC byte reads are unchanged. This correction also affects other device definitions using numeric 8-bit values.
4. **Alarm number 1975:** the exact-device exports specify `s16`, conflicting with the common-register manual's `u16`. The device-specific definition follows the exports and uses `int16`.
5. **Settings metadata:** holding register 20 uses divisor 10; registers 92 and 93 use divisor 1 and represent hot-water and heating periods respectively. The previous definition had the period topics reversed and scaled both by 0.1. Custom heating-curve registers 39 through 45 are points P7 through P1, in descending order.
6. **Unavailable optional registers:** input 26 (BT50), holding 94 (cooling period) and holding 183 (cooling start temperature) are absent from both exact-device exports and are omitted. This avoids polling registers that this installation rejects or does not advertise.
7. **State maps:** REST descriptions provide named states for compressor request 1556 and last-defrost result 2158; those maps are now included.

These are source changes, not a deployment or a change to the heat pump. Correcting registers 39-45 and 92-93 changes which register supplies each existing MQTT topic so that the topic meaning matches the controller export.

## Observed counter values

| Register / topic suffix | Published value | Interpretation after word-order and scale corrections |
| --- | ---: | ---: |
| 1489 / `heatpump/compressorstarts` | 0 | 0 |
| 1491 / `heatpump/compressoroperatingtime` | 393216 h | 6 h |
| 1493 / `heatpump/compressoroperatingtimehotwater` | 0 h | 0 h |
| 1583 / `energy/hotwatercompressor` | 6553.6 kWh | 0.1 kWh |
| 1585 / `energy/heatingcompressor` | 2123366.4 kWh | 32.4 kWh |

These are deterministic reinterpretations of the captured payloads, corroborated by the REST snapshot: 393216 is `0x00060000`, and reversing its words gives the exported value of 6 hours. Zero remains zero under word swapping: the reported zero compressor-start count is not explained by this correction. A direct controller-display comparison remains useful for physical-total verification.

## Coverage established by the device exports

The initial definition had 35 entries. After the 2026 expansion and exact-device corrections, the curated definition has 79 entries: 45 input readings and 34 read/write holding settings.

- Addresses/types/scales agree with the supplied matching-model or common tables: 1, 8, 9, 40, 400, 550, 1478, 1479, 1480, 1481, 1621, 1622, 1803, 1805, 2195. Numeric `uint8` entries still need the reader correction described above.
- Corrected counters or types: 1489, 1491, 1493, 1583, 1585 and 1975.
- The exports confirm that requested frequency 301 is unscaled `u8` Hz.
- They confirm that 1802 is signed 16-bit low pressure in bar with divisor 10. Address 550 remains a pressure-derived temperature in degrees Celsius.
- They confirm 1485 and 1495 and every previously unresolved existing entry: 37, 407, 408, 1108, 1109, 1453, 1556, 1854, 1976 and 2158.

Register 407's MQTT `null` is the bridge's UInt16 `0xFFFF` sentinel handling, not evidence of a zero-minute countdown. A zero flow reading at 40 also does not establish whether the required flow sensor/accessory is fitted. No address-wide +1/-1 correction is justified: the documented compressor-start address is already 1489 and several temperatures are plausible.

## 2026 documentation expansion

Added the missing input-register telemetry from the SMO S40 and S2125/F2120 slave 1 tables:

| Register | New MQTT topic suffix | Published units / states |
| --- | --- | --- |
| 39 | `system/externalsupplyline` | degrees Celsius |
| 88 | `system/returnline` | degrees Celsius |
| 401 | `heatpump/fanspeed` | rpm |
| 551 | `heatpump/highpressuretemperature` | degrees Celsius |
| 552 | `heatpump/injection` | degrees Celsius |
| 555 | `heatpump/evaporatorout` | degrees Celsius |
| 1066 | `system/heatingmediumpump` | OFF / ON |
| 1475 | `heatpump/returnline` | degrees Celsius |
| 1636 | `heatpump/chargepumpspeed` | percent |
| 2196 | `system/divertervalve` | HEATING / HOT_WATER |

All retained additions are read-only and use FC04. Temperature registers are signed 16-bit with factor 0.1. Fan speed is unsigned 16-bit; pump/valve registers are unsigned 8-bit. Labels distinguish condenser supply and evaporator inlet, and identify 2195 as active alarm without changing its numeric payload. Input 26 was removed after both live rejection and absence from the exact-device exports.

Two documentation details require care: 551 is explicitly a temperature despite its pressure label; 1636 has percent units but also an off/on legend. The map retains its numeric percentage, consistent with the earlier manual, rather than mapping every nonzero speed to a status. Actual accessory/sensor availability still depends on the installation.

GSHP-only valves and other outdoor units are outside this definition. The 8-bit topics require a bridge build containing the package-local numeric-byte reader correction; replacing the JSON alone in an older image does not fix that decoder.

## Read/write settings

The SMO S40 settings on pages 10-11 and common R/W registers on pages 15-16 are included as FC03 holding registers with `modbusaccess: readwrite`, polled every 60 seconds. Their MQTT topic suffixes start with `settings/`. Documented R/W settings should be usable without editing the JSON to enable writes.

The 34 settings cover degree minutes, cooling degree minutes, alarm reset, heating curve/offset and seven custom curve points, minimum/maximum supply temperatures, hot-water demand and normal start/stop temperatures, heating/hot-water periods, compressor/additional-heat degree-minute thresholds, automatic-mode heating thresholds, alarm actions, manual-mode heat/cooling permissions, operating mode, charge-pump mode, AUX10/AUX11 functions and calculated heating/cooling supply temperatures. Cooling period 94 and cooling start temperature 183 are absent from this controller's exports and are not polled. The REST API marks reset alarm 22 and operating mode 237 non-writable, while the Modbus manual marks them R/W; the definition retains documented Modbus write access because REST and Modbus permissions may differ.

Write requests use the existing MQTT contract. For a base topic `nibe`, publish to `nibe/request/change` with a fresh ISO-8601 `date`, a new UUID `id`, `topic: "settings/operatingmode"` and `value: "AUTO"` (or numeric 0). The response arrives at `nibe/response/change`. Setpoints are supplied in published engineering units: e.g. supply temperature 21.5 is encoded as 215. Values outside the integer type or that cannot be represented exactly after scaling are rejected. The generated CSV records setting-specific raw limits, but the bridge does not yet enforce them; the controller determines which values and modes it accepts. A controller configured for reading only cannot accept writes even when the JSON allows them.

Input and holding registers 39 and 40 legitimately coexist. Loading and both polling loops key definitions by register area plus address. The legacy address-only loader explicitly rejects these collisions; use `readByRegister(from:)` for this definition.

The writer now supports signed/unsigned 8-bit settings as complete 16-bit registers and signed 32-bit writes using FC16. Register 11 uses factor 0.1 and low-word-first order. Numeric and mapped string requests use the same conversion path. A rebuilt bridge is required for these writer and loader changes; this work does not deploy the bridge or issue writes to the physical heat pump.

## Regression verification

### Live register rejection on bgbpi (2026-09-25)

With revision `73ac869` deployed, a passive Modbus TCP capture identified the recurring
`couldNotRead(error: "Illegal function")`: unit 1 at `172.16.100.2:502` rejects FC04
input register 26 (`system/roomtemperature`, BT50). The request PDU was
`04 00 1a 00 01`; its response was `84 01` (exception 01). Five subsequent read-only
requests spaced one second apart confirmed FC04 address 1 succeeds, FC04 address 26
fails twice, and FC03 holding address 26 succeeds with value 8. This is specific to
the input reading, not a general FC04 failure or an input/holding address collision.
No controller writes or deployment changes were made during diagnosis.

The official SMO S40 table documents input 26, but both the REST catalogue and
menu 7.5.9 USB export omit it on this controller. The device-specific bundled
definition therefore no longer polls it. An absent or inactive BT50 remains the
likely explanation.

At this revision, `MultiDeviceServing.poll` does not log individual register reads
at debug/trace level, and its catch log omits the selected definition. SIGUSR1 does
change the JLog level, but cannot reveal missing instrumentation. Every Modbus
exception disconnects the endpoint and pauses this logical device for
`30 * consecutiveErrors` seconds. Successful reads reset the counter, explaining
the repeated value 1. Failed definitions keep their old due date, so an unavailable
register can repeatedly delay polling and prevent other equally/slower-polled
definitions from being reached. Future recovery should back off rejected registers
individually and include register area/address/topic in error logs.

The subsequent logging fix adds register area, decimal address, full MQTT topic,
and definition filename/path to error-level polling messages in both serving
paths. Retry scheduling remains unchanged; the live findings above describe the
deployed revision before this fix.

`NIBERegisterReadTests` runs a local FC04 server and passes responses through the actual dependency reader, device definition and MQTT JSON encoder. It covers a nonzero compressor-start count, distinct high/low words, captured runtime/energy patterns, an active defrost status, a nonzero alarm, negative temperature and signed 8-bit decoding. The original implementation fails these counter/byte checks; the corrections pass. No live heat pump or MQTT broker is required for these tests.

The regression cases also cover every retained added input register, including percent pump speed, negative temperature and mapped pump/valve states. They cover the new compressor-request and last-defrost maps and the exact-device metadata corrections. Physical counter totals remain unverified until a direct controller/display comparison is available.

Wire tests cover the original input readings and FC16 writes followed by FC03 reads for representative settings, including signed values, inverse scaling, enum names and two-register word order. Separate checks cover overlapping register areas, independent polling dates, supported writes for all 34 settings, and rejection of fractional/out-of-range integers.

Final validation for the 2026-09-26 source update: `swift build` succeeded and all 49 tests in 8 suites passed. JSON validation confirmed 79 unique register-area/address pairs and MQTT topics, all 34 expected R/W settings, and no type or scaling mismatch against the exact-device exports. The generated CSV parses as 1,165 data rows, includes all 79 curated definitions, and omits live values. Documentation front matter, local links and `git diff --check` passed. Physical-device writes were not used for validation.
