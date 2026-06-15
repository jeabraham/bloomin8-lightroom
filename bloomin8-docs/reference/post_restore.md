# Factory Restore (Erase All Data)

Wipes all on-device user data and resets the device to factory state.
This deletes all galleries, playlists, dithered image data, logs, and
clears the upstream binding (token / URL / cron). The device will
reboot after the operation completes.

**Prerequisite:** battery level must be **> 30%**. The device refuses
the operation below that threshold to avoid bricking mid-erase.

**Caution:** this is irreversible. The caller is expected to confirm
with the user before invoking.


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
    "/restore": {
      "post": {
        "summary": "Factory Restore (Erase All Data)",
        "description": "Wipes all on-device user data and resets the device to factory state.\nThis deletes all galleries, playlists, dithered image data, logs, and\nclears the upstream binding (token / URL / cron). The device will\nreboot after the operation completes.\n\n**Prerequisite:** battery level must be **> 30%**. The device refuses\nthe operation below that threshold to avoid bricking mid-erase.\n\n**Caution:** this is irreversible. The caller is expected to confirm\nwith the user before invoking.\n",
        "tags": [
          "System APIs"
        ],
        "responses": {
          "200": {
            "description": "Erase initiated. The device begins wiping data and will reboot shortly."
          },
          "400": {
            "description": "Refused — typically because battery is at or below 30%."
          }
        }
      }
    }
  }
}
```