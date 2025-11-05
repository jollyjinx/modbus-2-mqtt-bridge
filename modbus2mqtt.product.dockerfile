FROM swift:latest AS modbus2mqttbuilder
WORKDIR /swift
ENV SWIFTPM_BUILD_TESTS=false
COPY Sources Sources
COPY DeviceDefinitions DeviceDefinitions
COPY Package.swift Package.swift
RUN swift build -v -c release --product modbus2mqtt 
RUN chmod -R u+rwX,go+rX-w /swift/.build/release/

FROM swift:slim
WORKDIR /modbus2mqtt
ENV PATH="$PATH:/modbus2mqtt"
COPY --from=modbus2mqttbuilder /swift/.build/release/modbus2mqtt .
COPY --from=modbus2mqttbuilder /swift/.build/release/modbus2mqtt_modbus2mqtt.resources ./modbus2mqtt_modbus2mqtt.resources
# Copy DeviceDefinitions to make them available for the bundled symlink
COPY --from=modbus2mqttbuilder /swift/DeviceDefinitions /DeviceDefinitions
CMD ["modbus2mqtt"]

# create your own docker image:
#
# docker build . --file modbus2mqtt.product.dockerfile --tag modbus2mqtt
# docker run --name modbus2mqtt modbus2mqtt


# multiarch build to docker.io:
#
# docker buildx create --use --name multiarch-builder
# docker buildx inspect --bootstrap
# docker buildx build --no-cache --platform linux/amd64,linux/arm64 --tag jollyjinx/modbus2mqtt:development --file modbus2mqtt.product.dockerfile --push .
# docker buildx build --no-cache --platform linux/amd64,linux/arm64 --tag jollyjinx/modbus2mqtt:latest --tag jollyjinx/modbus2mqtt:2.2.1 --file modbus2mqtt.product.dockerfile --push .
# docker buildx imagetools inspect jollyjinx/modbus2mqtt:latest
