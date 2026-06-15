# Configure Schedule Pull

Configure the device's scheduled pull settings.

**Workflow:**
1. Configure `upstream_url` and `cron_time`
2. Device sleeps until `cron_time`
3. Device calls `{upstream_url}/eink_pull` to get image
4. Displays image, then sleeps until `next_cron_time` from response
5. Loop continues


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
      "put": {
        "summary": "Configure Schedule Pull",
        "description": "Configure the device's scheduled pull settings.\n\n**Workflow:**\n1. Configure `upstream_url` and `cron_time`\n2. Device sleeps until `cron_time`\n3. Device calls `{upstream_url}/eink_pull` to get image\n4. Displays image, then sleeps until `next_cron_time` from response\n5. Loop continues\n",
        "tags": [
          "Upstream APIs"
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "upstream_on": {
                    "type": "boolean",
                    "description": "Enable/disable scheduled pulling. Set `false` to stop.",
                    "example": true
                  },
                  "upstream_url": {
                    "type": "string",
                    "description": "Upstream server address. Device will call `{upstream_url}/eink_pull`.",
                    "example": "http://192.168.1.50:8080"
                  },
                  "token": {
                    "type": "string",
                    "description": "Custom token. Device sends this in `X-Access-Token` header when calling upstream.",
                    "example": "my-secret-token"
                  },
                  "cron_time": {
                    "type": "string",
                    "description": "Next pull time in UTC ISO 8601 format.",
                    "example": "2025-11-01T08:30:00Z"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Configuration updated successfully."
          }
        }
      }
    }
  }
}
```