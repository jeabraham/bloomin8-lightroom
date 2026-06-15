# Push Firmware Update (OTA)

Pushes a firmware image to the device over the local network to perform an
over-the-air update. The device verifies the package, flashes it, and reboots
automatically on success.

**Firmware package format depends on the device model.** The accepted
extension is one of `.bin`, `.tar`, or `.zip` — the caller is expected to
fetch the correct package for the target device (typically resolved from
`screen_model` / `board_model` returned by `/deviceInfo`) and upload it as-is.
Do not transcode or repack.

| Extension | Typical usage                                                |
|-----------|--------------------------------------------------------------|
| `.bin`    | Single-image firmware (legacy / smaller boards).             |
| `.tar`    | Multi-partition bundle (newer boards with separate assets).  |
| `.zip`    | Compressed bundle (boards that ship resources alongside fw). |

**Request:** `multipart/form-data` with a single part named `update`
containing the firmware bytes. The `filename` in the multipart part
should carry the correct extension (e.g. `firmware.bin`, `firmware.tar`,
`firmware.zip`) so the device can dispatch the right handler.

**Recommended client timeouts:** send ≥ 2 minutes (large packages over
Wi-Fi), receive ≥ 30 seconds (device responds after verification, before
reboot).

**Behavior:** the device returns `{"status": "ok"}` after the package is
accepted and staged. The actual flash + reboot happens immediately after
the response; the device will be unreachable for a short window during reboot.


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
      "name": "OTA APIs",
      "description": "APIs for over-the-air firmware updates."
    }
  ],
  "paths": {
    "/update": {
      "post": {
        "summary": "Push Firmware Update (OTA)",
        "description": "Pushes a firmware image to the device over the local network to perform an\nover-the-air update. The device verifies the package, flashes it, and reboots\nautomatically on success.\n\n**Firmware package format depends on the device model.** The accepted\nextension is one of `.bin`, `.tar`, or `.zip` — the caller is expected to\nfetch the correct package for the target device (typically resolved from\n`screen_model` / `board_model` returned by `/deviceInfo`) and upload it as-is.\nDo not transcode or repack.\n\n| Extension | Typical usage                                                |\n|-----------|--------------------------------------------------------------|\n| `.bin`    | Single-image firmware (legacy / smaller boards).             |\n| `.tar`    | Multi-partition bundle (newer boards with separate assets).  |\n| `.zip`    | Compressed bundle (boards that ship resources alongside fw). |\n\n**Request:** `multipart/form-data` with a single part named `update`\ncontaining the firmware bytes. The `filename` in the multipart part\nshould carry the correct extension (e.g. `firmware.bin`, `firmware.tar`,\n`firmware.zip`) so the device can dispatch the right handler.\n\n**Recommended client timeouts:** send ≥ 2 minutes (large packages over\nWi-Fi), receive ≥ 30 seconds (device responds after verification, before\nreboot).\n\n**Behavior:** the device returns `{\"status\": \"ok\"}` after the package is\naccepted and staged. The actual flash + reboot happens immediately after\nthe response; the device will be unreachable for a short window during reboot.\n",
        "tags": [
          "OTA APIs"
        ],
        "requestBody": {
          "required": true,
          "content": {
            "multipart/form-data": {
              "schema": {
                "type": "object",
                "required": [
                  "update"
                ],
                "properties": {
                  "update": {
                    "type": "string",
                    "format": "binary",
                    "description": "Firmware package binary. The multipart `filename` must end with `.bin`, `.tar`, or `.zip` matching the target device.\n"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Firmware accepted. Device will flash and reboot.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": {
                      "type": "string",
                      "example": "ok"
                    }
                  }
                }
              }
            }
          },
          "400": {
            "description": "Rejected — malformed package, unsupported extension, or signature/version mismatch."
          },
          "500": {
            "description": "Internal error while writing the package to flash."
          }
        }
      }
    }
  }
}
```