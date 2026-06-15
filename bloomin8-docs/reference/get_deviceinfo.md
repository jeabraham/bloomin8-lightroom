# Get Device Information

Retrieves comprehensive information about the device's status and configuration.

# OpenAPI definition

```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "Arpobot Bloomin8 E-Ink Canvas Public API Documentation",
    "description": "Welcome to the official API documentation for the Bloomin8 E-Ink Canvas. This document provides developers with all the necessary information to interact with and control the device programmatically. The API is designed to be straightforward and follows RESTful principles, allowing for easy integration into various platforms and applications, such as Home Assistant, custom scripts, or third-party services. All API requests and responses use the application/json content type unless otherwise specified.",
    "version": "1.1.0",
    "contact": {
      "name": "ArpoBot Company"
    }
  },
  "servers": [
    {
      "url": "http://192.168.10.128"
    }
  ],
  "tags": [
    {
      "name": "System APIs",
      "description": "APIs for general device control, status monitoring, and system-level settings."
    }
  ],
  "paths": {
    "/deviceInfo": {
      "get": {
        "summary": "Get Device Information",
        "description": "Retrieves comprehensive information about the device's status and configuration.",
        "tags": [
          "System APIs"
        ],
        "responses": {
          "200": {
            "description": "A JSON object containing detailed device attributes.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "name": {
                      "type": "string",
                      "description": "User-assigned device name.",
                      "example": "Study Room"
                    },
                    "version": {
                      "type": "string",
                      "description": "Firmware version.",
                      "example": "1.8.35"
                    },
                    "type": {
                      "type": "string",
                      "description": "Device product type identifier.",
                      "example": "warptrek"
                    },
                    "sn": {
                      "type": "string",
                      "description": "Device serial number.",
                      "example": "FC4778AFC936AE984B0B891DCABBF337"
                    },
                    "bt_mac": {
                      "type": "string",
                      "description": "Bluetooth MAC address (uppercase, no separators).",
                      "example": "E149121B1360"
                    },
                    "board_model": {
                      "type": "string",
                      "description": "Hardware board model identifier.",
                      "example": "sps_s3_v6_n16r8_el133uf1"
                    },
                    "screen_model": {
                      "type": "string",
                      "description": "E-ink screen panel model.",
                      "example": "EL133UF1"
                    },
                    "ms_code": {
                      "type": "string",
                      "description": "Manufacturer/brand short code.",
                      "example": "ARPO"
                    },
                    "battery": {
                      "type": "integer",
                      "format": "int32",
                      "description": "Battery percentage (0-100).",
                      "example": 49
                    },
                    "fs_ready": {
                      "type": "boolean",
                      "description": "Whether the on-device filesystem is mounted and ready.",
                      "example": true
                    },
                    "total_size": {
                      "type": "integer",
                      "format": "int64",
                      "description": "Total storage capacity in bytes.",
                      "example": 31902400512
                    },
                    "free_size": {
                      "type": "integer",
                      "format": "int64",
                      "description": "Free storage in bytes.",
                      "example": 28456976384
                    },
                    "sleep_duration": {
                      "type": "integer",
                      "format": "int32",
                      "description": "Deep sleep duration in seconds between scheduled wake-ups.",
                      "example": 259200
                    },
                    "max_idle": {
                      "type": "integer",
                      "format": "int32",
                      "description": "Max idle seconds before the device auto-sleeps.",
                      "example": 120
                    },
                    "idx_wake_sens": {
                      "type": "integer",
                      "format": "int32",
                      "description": "Wake sensitivity level index.",
                      "example": 4
                    },
                    "network_type": {
                      "type": "integer",
                      "format": "int32",
                      "description": "Network connection status. 0 = not connected, 2 = connected (Wi-Fi).",
                      "example": 2
                    },
                    "width": {
                      "type": "integer",
                      "format": "int32",
                      "description": "Screen width in pixels.",
                      "example": 1200
                    },
                    "height": {
                      "type": "integer",
                      "format": "int32",
                      "description": "Screen height in pixels.",
                      "example": 1600
                    },
                    "sta_rssi": {
                      "type": "integer",
                      "format": "int32",
                      "description": "Wi-Fi signal strength in dBm (negative).",
                      "example": -59
                    },
                    "sta_ssid": {
                      "type": "string",
                      "description": "Connected Wi-Fi SSID.",
                      "example": "ITCC"
                    },
                    "sta_ip": {
                      "type": "string",
                      "description": "Device LAN IP address.",
                      "example": "172.18.195.132"
                    },
                    "image": {
                      "type": "string",
                      "description": "Path of the currently displayed image.",
                      "example": "/gallerys/default/AGENT_COVER_cpoZh9qPnPyATWXzUCbL_1777547321799_P.jpg"
                    },
                    "next_time": {
                      "type": "integer",
                      "format": "int64",
                      "description": "Unix timestamp (seconds) of the next scheduled wake-up.",
                      "example": 1778307459
                    },
                    "gallery": {
                      "type": "string",
                      "description": "Currently active gallery name.",
                      "example": "default"
                    },
                    "playlist": {
                      "type": "string",
                      "description": "Currently active playlist name (empty when not in playlist mode).",
                      "example": ""
                    },
                    "play_type": {
                      "type": "integer",
                      "format": "int32",
                      "description": "0 for single image, 1 for gallery slideshow, 2 for playlist.",
                      "example": 0
                    },
                    "play_duration": {
                      "type": "integer",
                      "format": "int32",
                      "description": "Per-image playback interval in seconds (gallery / playlist mode).",
                      "example": 300
                    },
                    "beep_on": {
                      "type": "boolean",
                      "description": "Whether the buzzer / sound effects are enabled.",
                      "example": true
                    },
                    "restored": {
                      "type": "boolean",
                      "description": "True if the device just restored from deep sleep on this boot cycle.",
                      "example": false
                    },
                    "gamma": {
                      "type": "number",
                      "description": "Gamma correction factor applied during rendering.",
                      "example": 1
                    },
                    "dither": {
                      "type": "integer",
                      "format": "int32",
                      "description": "Active dithering algorithm (0 = Floyd-Steinberg, 1 = JJN).",
                      "example": 0
                    },
                    "saturation": {
                      "type": "number",
                      "description": "Saturation multiplier applied during rendering.",
                      "example": 1
                    },
                    "time": {
                      "type": "integer",
                      "format": "int64",
                      "description": "Current device Unix timestamp in seconds.",
                      "example": 1778048295
                    },
                    "silence_on": {
                      "type": "boolean",
                      "description": "Whether silent mode is enabled (suppresses beeps and notifications).",
                      "example": false
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```