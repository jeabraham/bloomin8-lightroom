# List Log Files

Get a list of all available log files on the device.

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
    "/log/list": {
      "get": {
        "summary": "List Log Files",
        "description": "Get a list of all available log files on the device.",
        "tags": [
          "Log APIs"
        ],
        "responses": {
          "200": {
            "description": "Success",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "type": "string"
                  }
                },
                "example": [
                  "2025-12-01.log",
                  "2025-12-02.log",
                  "2025-12-03.log"
                ]
              }
            }
          }
        }
      }
    }
  }
}
```