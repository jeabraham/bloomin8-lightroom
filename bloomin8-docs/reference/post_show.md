# Start Playback

Initiates the display of a single image, a gallery slideshow, or a playlist.

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
    "/show": {
      "post": {
        "summary": "Start Playback",
        "description": "Initiates the display of a single image, a gallery slideshow, or a playlist.",
        "tags": [
          "System APIs"
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "play_type"
                ],
                "properties": {
                  "play_type": {
                    "type": "integer",
                    "description": "0 for single image, 1 for gallery slideshow, 2 for playlist.",
                    "enum": [
                      0,
                      1,
                      2
                    ],
                    "example": 1
                  },
                  "gallery": {
                    "type": "string",
                    "description": "Required when play_type is 1.",
                    "example": "default"
                  },
                  "duration": {
                    "type": "integer",
                    "description": "Required when play_type is 1. Interval in seconds.",
                    "example": 120
                  },
                  "playlist": {
                    "type": "string",
                    "description": "Required when play_type is 2.",
                    "example": "my_playlist"
                  },
                  "image": {
                    "type": "string",
                    "description": "Optional. Path to an image to display immediately.",
                    "example": "/gallerys/default/f1.jpg"
                  },
                  "dither": {
                    "type": "integer",
                    "description": "Optional. Dithering algorithm (e.g., 0 for Floyd-Steinberg, 1 for JJN).",
                    "enum": [
                      0,
                      1
                    ],
                    "example": 1
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Playback initiated successfully."
          }
        }
      }
    }
  }
}
```