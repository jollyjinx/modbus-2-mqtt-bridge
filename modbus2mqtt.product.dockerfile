FROM swift:latest as builder
WORKDIR /swift
COPY . .
RUN swift build -c release
RUN chmod -R u+rwX,go+rX-w /swift/.build/release/

FROM swift:slim
WORKDIR /modbus2mqtt
ENV PATH "$PATH:/modbus2mqtt"
RUN chmod -R ugo+rwX /modbus2mqtt
COPY --from=builder /swift/.build/release/modbus2mqtt .
COPY --from=builder /swift/.build/release/modbus2mqtt_modbus2mqtt.resources ./modbus2mqtt_modbus2mqtt.resources
CMD ["modbus2mqtt"]

# create your own docker image:
#
# docker build . --file modbus2mqtt.product.dockerfile --tag modbus2mqtt
# docker run --name modbus2mqtt modbus2mqtt


# following lines are for publishing on docker hub
#
# version=2.2.0
# docker build . --file modbus2mqtt.product.dockerfile --tag jollyjinx/modbus2mqtt:development && docker push jollyjinx/modbus2mqtt:development
# docker tag jollyjinx/modbus2mqtt:development jollyjinx/modbus2mqtt:$version  && docker push jollyjinx/modbus2mqtt:$version
# docker tag jollyjinx/modbus2mqtt:$version jollyjinx/modbus2mqtt:latest  && docker push jollyjinx/modbus2mqtt:latest

