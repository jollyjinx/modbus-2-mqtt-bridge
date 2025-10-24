
# modbus2mqtt Documentation

## Introduction

modbus2mqtt is a bidirectional bridge that connects Modbus devices to an MQTT broker. It allows you to monitor and control Modbus devices using MQTT, a lightweight messaging protocol ideal for IoT applications.

The project is written in Swift and can be run on macOS and Linux. It is highly configurable and can be adapted to work with a wide range of Modbus devices by creating custom JSON device definition files.

## Architecture

The project is divided into two main components:

*   **`modbus2mqtt` executable:** This is the main application that you run from the command line. It handles command-line argument parsing, sets up the Modbus and MQTT connections, and manages the main application loop.
*   **`SwiftLibModbus2MQTT` library:** This library contains the core logic for the Modbus-to-MQTT bridge. It is responsible for:
    *   Reading and parsing JSON device definition files.
    *   Connecting to the Modbus device and the MQTT broker.
    *   Reading data from Modbus registers and publishing it to MQTT topics.
    *   Subscribing to MQTT topics for write requests and writing data to Modbus registers.
    *   Handling data type conversions and value mapping.

### Key Data Structures

The following are the key data structures used in the `SwiftLibModbus2MQTT` library:

*   **`ModbusDefinition`**: This struct represents a single Modbus register definition from a JSON device description file. It contains all the information needed to interact with that register, such as its address, data type, and MQTT topic.
*   **`ModbusValue`**: This struct represents a value read from a Modbus device. It includes the raw value as well as information about how to format it for publishing to MQTT.
*   **`MQTTRequest` and `MQTTResponse`**: These structs are used for the request/response pattern that allows writing data to Modbus devices via MQTT.
*   **`MQTTServer` and `MQTTDevice`**: These structs store the configuration for the MQTT broker and the Modbus device.
*   **`BitMapValues`**: This struct provides functionality for handling bit-mapped values, where individual bits or ranges of bits within a larger integer value have specific meanings.

## How it Works

1.  **Initialization:**
    *   The `modbus2mqtt` executable is launched with command-line arguments that specify the MQTT broker, the Modbus device, and the JSON device definition file to use.
    *   The application reads the device definition file and creates a dictionary of `ModbusDefinition` objects, using the Modbus address as the key.
    *   It establishes a connection to the MQTT broker and the Modbus device.

2.  **Reading Data:**
    *   The application enters a loop that continuously reads data from the Modbus device.
    *   In each iteration, it determines which Modbus register to read next based on the `interval` specified in the `ModbusDefinition` for each register.
    *   It reads the value from the Modbus register and creates a `ModbusValue` object.
    *   The `ModbusValue` is then encoded into a JSON string and published to the appropriate MQTT topic.

3.  **Writing Data:**
    *   The application subscribes to a specific MQTT topic for write requests.
    *   When a message is received on this topic, it decodes the JSON payload into an `MQTTRequest` object.
    *   The `MQTTRequest` contains the topic of the value to be written and the new value.
    *   The application looks up the corresponding `ModbusDefinition` to determine the Modbus address and data type.
    *   It then writes the new value to the Modbus register.
    *   Finally, it publishes an `MQTTResponse` message to a response topic to indicate whether the write operation was successful.

## Device Definition Files

The behavior of `modbus2mqtt` is primarily controlled by the JSON device definition files. These files specify which Modbus registers to read, how often to read them, and how to map them to MQTT topics.

For a detailed explanation of the format of the device definition files, please refer to the [JSON Definition Files](#json-definition-files) section in the `README.md` file.

## Command-Line Options

The `modbus2mqtt` executable supports a number of command-line options for configuring its behavior. For a complete list of the available options, please run the application with the `--help` flag.
