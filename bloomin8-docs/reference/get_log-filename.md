# Download Log File

Download a specific log file by filename.

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
    "/log/{filename}": {
      "get": {
        "summary": "Download Log File",
        "description": "Download a specific log file by filename.",
        "tags": [
          "Log APIs"
        ],
        "parameters": [
          {
            "name": "filename",
            "in": "path",
            "required": true,
            "description": "Log filename (e.g. 2025-12-05.log)",
            "schema": {
              "type": "string",
              "pattern": "^\\d{4}-\\d{2}-\\d{2}\\.log$"
            },
            "example": "2025-12-05.log"
          }
        ],
        "responses": {
          "200": {
            "description": "Log file content",
            "content": {
              "text/plain": {
                "schema": {
                  "type": "string"
                },
                "example": "[2025-12-05 10:00:00] Device started\n[2025-12-05 10:00:01] WiFi connected\n"
              }
            }
          },
          "404": {
            "description": "Log file not found"
          }
        }
      }
    }
  }
}
```