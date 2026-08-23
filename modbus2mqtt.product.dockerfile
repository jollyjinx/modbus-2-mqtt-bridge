# syntax=docker/dockerfile:1.7

FROM swift:6.3 AS modbus2mqttbuilder

WORKDIR /swift
ENV SWIFTPM_BUILD_TESTS=false
ARG TARGETARCH

COPY Package.swift Package.swift
RUN --mount=type=cache,id=modbus2mqtt-swift-build-${TARGETARCH},target=/swift/.build,sharing=locked \
    --mount=type=cache,id=modbus2mqtt-swiftpm-${TARGETARCH},target=/root/.cache,sharing=locked \
    --mount=type=cache,id=modbus2mqtt-swiftpm-config-${TARGETARCH},target=/root/.swiftpm,sharing=locked \
    swift package resolve

COPY Sources Sources
COPY Tests Tests
COPY DeviceDefinitions DeviceDefinitions
RUN --mount=type=cache,id=modbus2mqtt-swift-build-${TARGETARCH},target=/swift/.build,sharing=locked \
    --mount=type=cache,id=modbus2mqtt-swiftpm-${TARGETARCH},target=/root/.cache,sharing=locked \
    --mount=type=cache,id=modbus2mqtt-swiftpm-config-${TARGETARCH},target=/root/.swiftpm,sharing=locked \
    swift build -c release --jobs 1 --product modbus2mqtt \
        -Xswiftc -num-threads -Xswiftc 1 \
    && binary_path="$(find /swift/.build -path '*/release/modbus2mqtt' -type f | head -n 1)" \
    && resource_path="$(find /swift/.build -type d -name 'modbus2mqtt_modbus2mqtt.resources' | head -n 1)" \
    && test -n "${binary_path}" \
    && test -n "${resource_path}" \
    && install -Dm755 "${binary_path}" /out/modbus2mqtt \
    && cp -R "${resource_path}" /out/modbus2mqtt_modbus2mqtt.resources

FROM swift:6.3-slim

ARG VCS_REF=unknown
ARG MODBUS2MQTT_VERSION=development

LABEL org.opencontainers.image.title="modbus2mqtt" \
    org.opencontainers.image.version="${MODBUS2MQTT_VERSION}" \
    org.opencontainers.image.revision="${VCS_REF}"

ENV PATH="${PATH}:/modbus2mqtt" \
    MODBUS2MQTT_VERSION="${MODBUS2MQTT_VERSION}" \
    MODBUS2MQTT_REVISION="${VCS_REF}"

WORKDIR /modbus2mqtt

COPY --from=modbus2mqttbuilder /out/modbus2mqtt /modbus2mqtt/modbus2mqtt
COPY --from=modbus2mqttbuilder /out/modbus2mqtt_modbus2mqtt.resources /modbus2mqtt/modbus2mqtt_modbus2mqtt.resources
COPY --from=modbus2mqttbuilder /swift/DeviceDefinitions /DeviceDefinitions

CMD ["modbus2mqtt"]
