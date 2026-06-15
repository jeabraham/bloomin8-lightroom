# Set Device to Sleep

Commands the device to enter sleep mode to conserve power.

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
    "/sleep": {
      "post": {
        "summary": "Set Device to Sleep",
        "description": "Commands the device to enter sleep mode to conserve power.",
        "tags": [
          "System APIs"
        ],
        "responses": {
          "200": {
            "description": "Device entering sleep mode."
          }
        }
      }
    }
  }
}
```