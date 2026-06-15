# List All Playlists

Retrieves a list of all playlists on the device.

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
      "name": "Playlist APIs",
      "description": "APIs for managing playlists, which are ordered lists of images with specific playback timing."
    }
  ],
  "paths": {
    "/playlist/list": {
      "get": {
        "summary": "List All Playlists",
        "description": "Retrieves a list of all playlists on the device.",
        "tags": [
          "Playlist APIs"
        ],
        "responses": {
          "200": {
            "description": "A list of all playlists.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "name": {
                        "type": "string",
                        "example": "daily_show"
                      },
                      "time": {
                        "type": "integer",
                        "format": "int64",
                        "example": 1739095496
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
}
```