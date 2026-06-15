# Get Schedule Pull Configuration

Retrieves the device's current scheduled pull configuration.

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
      "name": "Upstream APIs",
      "description": "Configure the device's upstream server and wake schedule for automated image pulling."
    }
  ],
  "paths": {
    "/upstream/pull_settings": {
      "get": {
        "summary": "Get Schedule Pull Configuration",
        "description": "Retrieves the device's current scheduled pull configuration.",
        "tags": [
          "Upstream APIs"
        ],
        "responses": {
          "200": {
            "description": "Current pull configuration.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "upstream_on": {
                      "type": "boolean",
                      "description": "Whether scheduled pulling is enabled.",
                      "example": true
                    },
                    "upstream_url": {
                      "type": "string",
                      "description": "Upstream server address.",
                      "example": "https://your-upstream.com"
                    },
                    "token": {
                      "type": "string",
                      "description": "Access token sent to upstream server.",
                      "example": "eyJhbGci..."
                    },
                    "next_cron_time": {
                      "type": "integer",
                      "description": "Next wake time (Unix timestamp in seconds, 0 = not set).",
                      "example": 1766400360
                    },
                    "pre_image": {
                      "type": "string",
                      "description": "Last displayed image URL.",
                      "example": ""
                    },
                    "time": {
                      "type": "integer",
                      "description": "Device current time (Unix timestamp in seconds).",
                      "example": 1766400249
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