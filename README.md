# modbus2mqtt Bridge

*modbus2mqtt* allows you to have modbus capable devices (Ethernet/USB/Serial) being available in MQTT.
 
It works on standard swift platforms. I works on macOS and Linux computers (e.g raspberry pi), but should work on swift for windows as well.

## Have any Modbus device brigded to MQTT 

It comes with json definition files for:
    - SMA sunnyboy inverters
    - SMA sunnystore inverters
    - Phoenix Contact electric vehicle chargecontroller
    - Hanmatek HM310T laboratory power supply

It's easy to setup your own modbus2mqtt definition file. A json definition file looks like this:

```
{
  {
    "address": 40631,                   // modbus address
    "modbustype": "holding",            // holding,coil,
    "modbusaccess": "readwrite",        // read/write/readwrite
    "valuetype": "string",              // string, ipv4address, macaddress, uint8, int8, uint16,...
    "length": 24,                       // strings need a length
    "interval": 1000,                   // interval being updated in seconds (decimal value like 0.2 possible)
                                        // interval of 0 means it will be requested only at start and then 
                                        // using mqtt retain to retain it.
    "mqtt": "visible",                  // if shown in mqtt visible/invisible/retained
    "topic": "settings/name",           // topic to post values
    "title": "Name"                     // description for gui (like node-red)
  },
  {
    "address": 30581,
    "modbustype": "holding",
    "modbusaccess": "read",
    "valuetype": "uint32",  
    "factor": 1000,                     // factor to divide by
    "unit": "kWh",                      // unit for gui
    "mqtt": "visible",
    "interval": 1000,
    "topic": "counter/totalusage",
    "title": "Total Yield"
  },

}
```

Remark: Be aware that json does not support comments like in this example.


## Bridge goes both ways

*modbus2mqtt* is a bridge it does not only allow modbus devices show up in mqtt, it also allows writing values to the modbus devices from mqtt.
It uses a Request/Response pattern. You send a mqtt request to the mqtt request topic and are give the result of the request in the response topic path.

To set the output voltage of the HM310T to 14.04 Volt you can send the following json 

```
{
  "value": 14.04,
  "date": "2022-10-20T16:07:46+00",
  "topic": "set/voltage",
  "id": "D2129DBF-9F94-56D7-86BC-7A07152FF1D8"
}
```

to the topic *hm310/request/jollysrequest* of the MQTT server. The bridge will pickup the request and return the response to the response topic *hm310/response/D2129DBF-9F94-56D7-86BC-7A07152FF1D8* .

In swift Request/Responses are defined as follows.

```
struct MQTTRequest:Encodable,Decodable,Hashable,Equatable
{
    let date:Date       // needs to be within request ttl time 
    let id:UUID
    let topic:String
    let value:MQTTCommandValue
}

struct MQTTResponse:Encodable,Decodable
{
    let date:Date
    let id:UUID         // same uuid of request
    let success:Bool
    let error:String?
}
```


## Status

I'm using it 24/7 on my own modbus devices (the devices I created JSON definitions for).

Starting the application

```
> modbus2mqtt --topic=sma/sunnystore \
              --modbus-server=sunnyboy.local \
              --mqtt-server=mqtt.local \
              --device-description-file=sma.sunnystore.json
```

It supports command line help:

```
> ./.build/debug/modbus2mqtt --help 
USAGE: modbus2mqtt <options>

OPTIONS:
  -d, --debug <debug>     optional debug output (default: 0)
  --mqtt-server <mqtt-server>
                          MQTT Server hostname (default: mqtt)
  --mqtt-port <mqtt-port> MQTT Server port (default: 1883)
  --mqtt-username <mqtt-username>
                          MQTT Server username
  --mqtt-password <mqtt-password>
                          MQTT Server password
  --interval <interval>   Minimum interval to send updates to mqtt Server. (default: 0.1)
  -t, --topic <topic>     MQTT Server topic. (default: modbus/sunnyboy)
  --mqtt-request-ttl <mqtt-request-ttl>
                          Maximum time a mqttRequest can lie in the future/past to be accepted. (default: 1000.0)
  --mqtt-auto-retain-time <mqtt-auto-retain-time>
                          If mqttTopic has a refreshtime larger than this value it will be ratained. (default: 10.0)
  --modbus-device-path <modbus-device-path>
                          Serial Modbus Device path
  --modbus-serial-speed <modbus-serial-speed>
                          Serial Modbus Speed (default: 9600)
  -m, --modbus-server <modbus-server>
                          Modbus Device Servername. (default: modbus.example.com)
  --modbus-port <modbus-port>
                          Modbus Device Port number. (default: 502)
  --modbus-address <modbus-address>
                          Modbus Device Address. (default: 3)
  --device-description-file <device-description-file>
                          Modbus Device Description file (JSON). (default: sma.sunnyboy.json)
  -h, --help              Show help information.

```

## Feedback welcome

In case you add json definitions for your own devices, create pull requests. 
