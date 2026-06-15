# Get Log Configuration

Retrieve the current logging configuration.

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
      "name": "Log APIs",
      "description": "APIs for managing device logs, including configuration, listing, downloading, and deletion."
    }
  ],
  "paths": {
    "/log/config": {
      "get": {
        "summary": "Get Log Configuration",
        "description": "Retrieve the current logging configuration.",
        "tags": [
          "Log APIs"
        ],
        "responses": {
          "200": {
            "description": "Success",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "log_on": {
                      "type": "boolean",
                      "description": "Whether logging is enabled."
                    },
                    "log_keep_days": {
                      "type": "integer",
                      "minimum": 0,
                      "description": "Number of days to retain logs (0 = keep forever)."
                    }
                  }
                },
                "example": {
                  "log_on": true,
                  "log_keep_days": 7
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