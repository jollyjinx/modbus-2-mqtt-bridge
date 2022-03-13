# modbus2mqtt Bridge

modbus2mqtt bridge allows you to have modbus capable devices beeing available in mqtt. 
It works on Macs and Linux computers (e.g raspberry pi)

Setup which modbus values are shown and how often are defined in a json file. SMA sunnyboys, SMA sunnystore and Phoenix Contact chargecontroller json definition files are included.
The json in there is defined like this:

```
{
  {
    "address": 40631,                   // modbus address
    "length": 24,                       // strings need a length
    "modbustype": "holding",            // holding,coil,
    "modbusaccess": "readwrite",        // read/write/readwrite
    "valuetype": "string",              // string, ipv4address, macaddress, uint8, int8, uint16,...
    "mqtt": "visible",                  // if shown in mqtt visible/invisible/retained
    "interval": 1000,                   // interval being updated in seconds (decimal value like 0.2 possible)
                                        // interval of 0 means it will be requested only at start and then 
                                        // using mqtt retain to retain it.
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

## Bridge

As it's a bridge it does not only allow modbus devices show up in mqtt, it also allows writing values to the modbus devices from mqtt.
It uses a Request/Response pattern with messages like this:

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

in topic named topic/reqeust and topic/response


## Status

Right now it's a proof of concept. It's a quick hack, it works though. 



```
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
  -m, --modbus-server <modbus-server>
                          Modbus Device Servername. (default: modbus.example.com)
  --modbus-port <modbus-port>
                          Modbus Device Port number. (default: 502)
  --modbus-address <modbus-address>
                          Modbus Device Address. (default: 3)
  --device-description-file <device-description-file>
                          Modbus Device Description file (JSON). (default: sma.sunnyboy)
  -h, --help              Show help information.
```





