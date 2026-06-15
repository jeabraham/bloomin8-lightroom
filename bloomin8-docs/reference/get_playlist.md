# Get Playlist Content

Retrieves the detailed content of a specific playlist.

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
    "/playlist": {
      "get": {
        "summary": "Get Playlist Content",
        "description": "Retrieves the detailed content of a specific playlist.",
        "tags": [
          "Playlist APIs"
        ],
        "parameters": [
          {
            "in": "query",
            "name": "name",
            "schema": {
              "type": "string"
            },
            "required": true,
            "description": "The name of the playlist to query."
          }
        ],
        "responses": {
          "200": {
            "description": "The detailed content of the playlist.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "name",
                    "type",
                    "list"
                  ],
                  "properties": {
                    "name": {
                      "type": "string",
                      "example": "daily_show"
                    },
                    "type": {
                      "type": "string",
                      "enum": [
                        "duration",
                        "time"
                      ],
                      "example": "duration"
                    },
                    "time_offset": {
                      "type": "integer",
                      "format": "int32",
                      "description": "In seconds, for 'time' type.",
                      "example": 0
                    },
                    "list": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "name": {
                            "type": "string",
                            "example": "/gallerys/default/f1.jpg"
                          },
                          "duration": {
                            "type": "integer",
                            "format": "int32",
                            "example": 40
                          },
                          "time": {
                            "type": "string",
                            "example": ""
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
  }
}
```