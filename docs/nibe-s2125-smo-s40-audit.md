---
title: "NIBE S2125 / SMO S40 register audit"
description: "Counter word order, numeric byte decoding, scaling, and unresolved model-specific registers checked against NIBE documentation and MQTT telemetry."
audience:
  - agents
  - maintainers
status: "active"
related:
  - "device-definitions.md"
  - "../DeviceDefinitions/nibe.S2125-SMO-S40.json"
  - "../Sources/SwiftLibModbus2MQTT/ModbusDefinitionIO.swift"
  - "../Tests/modbus2mqttTests/NIBERegisterReadTests.swift"
---

# S2125 / SMO S40 register audit

Reviewed on 2026-09-25. The filename is `nibe.S2125-SMO-S40.json`; the initial commit description called it S2150. This audit concerns S2125/F2120 slave 1 (EB101) behind SMO S40.

## Sources and confidence

- User-supplied **Technical information Modbus S-Series.pdf**: page 8 contains the SMO S40 and S2125/F2120 slave 1 tables; pages 7, 10, and 11-12 provide other-model and common-register comparisons. The local PDF is a re-export, so its creation timestamp does not establish the original document revision.
- [NIBE's official M12676EN, TIF EN 2608](https://professional.nibe.eu/document/Technical%20information%20(TIF)/M12676EN.pdf): page 6 explicitly describes reversed register order for 32-bit values; page 12 confirms the S2125/F2120 slave 1 counter addresses. This is useful information absent from the supplied PDF.
- The user confirmed that **Technical information Modbus S-Series.2026.pdf** is the same document as the official TIF EN 2608 download. The local file was inaccessible to the process, so the official copy was used; the SMO S40 and S2125 slave 1 tables on pages 10 and 12 were visually checked.
- Read-only MQTT observation of `nibe/#` on the user-provided broker. Counter samples below were retained messages; they establish what was published, not the controller's current display or register contents.
- A 310-second capture saw all 35 configured topics and fresh publications on 10 of them. Compressor frequency was freshly reported as zero; the counters were observed only as retained messages during that interval.
- Checked-out `SwiftLibModbus` typed-read implementation and loopback Modbus TCP regression tests.

The controller's own USB CSV export remains the best source for firmware- and installation-specific availability. Export all registers through menu 7.5.9 and compare operating values with menu 3.1. Do not substitute another model's addresses solely because its table includes a similar label.

## Confirmed defects and local corrections

1. **32-bit word order:** all five 32-bit values in this definition used the default high-word-first decoder. Set `endianness: littleEndian` for 1489, 1491, 1493, 1583, and 1585. With the checked-out dependency on supported little-endian macOS/Linux targets, that combines libmodbus's host-order UInt16 words low-word-first; it does not reverse each register's wire bytes.
2. **Runtime scaling:** 1491 and 1493 need multiplication by 0.1 to publish hours. NIBE's factor column is a divisor, whereas this project's `factor` is a multiplier. The S2125 table explicitly specifies signed 32-bit for 1491; that entry now uses `int32`. The hot-water counter 1493 is supported by the other-module table, so its availability on this installation still needs the CSV/display check.
3. **Numeric 8-bit reads:** the default dependency UInt8 read selected the high byte, so a register containing `0x0001` became zero. The package-local reader now reads one UInt16 register and narrows its low byte for both `uint8` and `int8`. String, hexadecimal, IP and MAC byte reads are unchanged. This correction also affects other device definitions using numeric 8-bit values.
4. **Alarm number 1975:** the common-register table specifies `u16`; changed from `int16` to `uint16` so large alarm identifiers are not negative.

MQTT topics and register addresses are preserved. These are source changes, not a deployment or a change to the heat pump.

## Observed counter values

| Register / topic suffix | Published value | Interpretation after word-order and scale corrections |
| --- | ---: | ---: |
| 1489 / `heatpump/compressorstarts` | 0 | 0 |
| 1491 / `heatpump/compressoroperatingtime` | 393216 h | 0.6 h |
| 1493 / `heatpump/compressoroperatingtimehotwater` | 0 h | 0 h |
| 1583 / `energy/hotwatercompressor` | 6553.6 kWh | 0.1 kWh |
| 1585 / `energy/heatingcompressor` | 2123366.4 kWh | 32.4 kWh |

These are deterministic reinterpretations of the captured payloads, not independently verified physical totals. For example, 393216 is `0x00060000`; reversing its words gives 6, then scaling gives 0.6 h. Zero remains zero under word swapping: the reported zero compressor-start count is not explained by this correction. Check the controller's display, firmware export, and fresh raw registers 1489-1490 before claiming that symptom is resolved.

## Coverage and remaining questions

The initial definition had 35 entries. The following audit describes those existing entries; the 2026 expansion below brings the total to 82 (46 input readings and 36 read/write settings):

- Addresses/types/scales agree with the supplied matching-model or common tables: 1, 8, 9, 40, 400, 550, 1478, 1479, 1480, 1481, 1621, 1622, 1803, 1805, 2195. Numeric `uint8` entries still need the reader correction described above.
- Corrected counters or types: 1489, 1491, 1493, 1583, 1585, 1975. Address 1493 remains subject to the model-availability caveat.
- **301 requested frequency:** the PDF says `u8`, Hz, factor 10; the definition uses factor 1. An unsigned byte divided by 10 tops out at 25.5 Hz, making this specification suspect. The observed zero cannot resolve the scale. Leave it unchanged pending a running-compressor sample and controller CSV; compare with 1803 and the separate 1854 requested-frequency value.
- **1802 pressure:** the PDF lists this under F2040, not in the S2125 table. The running map labels it BP8 and publishes 5.8 bar, but that does not establish the sensor identity or scale. Leave it unchanged pending the controller export. Address 550 is a pressure-derived temperature in degrees Celsius, so it must not be relabelled as bar.
- **1485 and 1495:** the supplied ground-source module table includes these timer/alarm addresses, but the S2125 shortlist does not. Preserve them pending the device export.
- Not established by the relevant tables: 37, 407, 408, 1108, 1109, 1453, 1556, 1854, 1976, 2158. Absence from this shortlist is not proof a register is invalid.

Register 407's MQTT `null` is the bridge's UInt16 `0xFFFF` sentinel handling, not evidence of a zero-minute countdown. A zero flow reading at 40 also does not establish whether the required flow sensor/accessory is fitted. No address-wide +1/-1 correction is justified: the documented compressor-start address is already 1489 and several temperatures are plausible.

## 2026 documentation expansion

Added the missing input-register telemetry from the SMO S40 and S2125/F2120 slave 1 tables:

| Register | New MQTT topic suffix | Published units / states |
| --- | --- | --- |
| 26 | `system/roomtemperature` | degrees Celsius |
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

All additions are read-only, use FC04, and poll every 30 seconds except room temperature (60 seconds). Temperature registers are signed 16-bit with factor 0.1. Fan speed is unsigned 16-bit; pump/valve registers are unsigned 8-bit. Existing topics, addresses, value types and polling intervals remain compatible with the preceding corrected definition. Labels now distinguish condenser supply and evaporator inlet, and identify 2195 as active alarm without changing its numeric payload.

Two documentation details require care: 551 is explicitly a temperature despite its pressure label; 1636 has percent units but also an off/on legend. The map retains its numeric percentage, consistent with the earlier manual, rather than mapping every nonzero speed to a status. Actual accessory/sensor availability still depends on the installation.

GSHP-only valves and other outdoor units are outside this definition. The unresolved entries above are preserved, including the existing requested-frequency scale. The 8-bit topics require a bridge build containing the package-local numeric-byte reader correction; replacing the JSON alone in an older image does not fix that decoder.

## Read/write settings

The SMO S40 settings on pages 10-11 and common R/W registers on pages 15-16 are included as FC03 holding registers with `modbusaccess: readwrite`, polled every 60 seconds. Their MQTT topic suffixes start with `settings/`. Documented R/W settings should be usable without editing the JSON to enable writes.

The 36 settings cover degree minutes, cooling degree minutes, alarm reset, heating curve/offset and seven custom curve points, minimum/maximum supply temperatures, hot-water demand and normal start/stop temperatures, heating/hot-water/cooling periods, compressor/additional-heat degree-minute thresholds, automatic-mode temperature thresholds, alarm actions, manual-mode heat/cooling permissions, operating mode, charge-pump mode, AUX10/AUX11 functions and calculated heating/cooling supply temperatures. Accessory-specific R/W settings for modules not represented by this SMO S40/S2125 definition are not included.

Write requests use the existing MQTT contract. For a base topic `nibe`, publish to `nibe/request/change` with a fresh ISO-8601 `date`, a new UUID `id`, `topic: "settings/operatingmode"` and `value: "AUTO"` (or numeric 0). The response arrives at `nibe/response/change`. Setpoints are supplied in published engineering units: e.g. supply temperature 21.5 is encoded as 215. Values outside the declared integer range or that cannot be represented exactly after scaling are rejected. The document does not provide full setting-specific ranges; the controller still determines which values and modes it accepts. A controller configured for reading only cannot accept writes even when the JSON allows them.

Input 26 (room temperature) and holding 26 (heating curve), as well as addresses 39 and 40, legitimately coexist. Loading and both polling loops now key definitions by register area plus address. The legacy address-only loader still explicitly rejects these collisions; use `readByRegister(from:)` for this definition.

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

The official SMO S40 table documents input 26, but actual availability depends on
the controller and installed/activated accessories. An absent or inactive BT50 is
a plausible explanation, not established by these probes; check menu 7.5.9's own
register export before changing the bundled definition globally.

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

The regression cases also cover every added input register, including percent pump speed, negative temperature and mapped pump/valve states. Physical counter totals remain unverified until a direct controller/display comparison is available.

Wire tests cover the original input readings and FC16 writes followed by FC03 reads for representative settings, including signed values, inverse scaling, enum names and two-register word order. Separate checks cover overlapping register areas, independent polling dates, supported writes for all 36 settings, and rejection of fractional/out-of-range integers.

Final validation: `swift build` succeeded and all 48 tests in 8 suites passed. JSON validation confirmed 82 unique register-area/address pairs and MQTT topics, all 36 expected R/W settings, unchanged input definitions and unambiguous mapped names. Documentation front matter, local links and `git diff --check` passed. Physical-device writes were not used for validation.
