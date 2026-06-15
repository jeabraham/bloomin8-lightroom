# Upload Image

Uploads a single JPEG image to a specified gallery. The image can be displayed immediately upon upload.

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
      "name": "Image APIs",
      "description": "APIs for managing and displaying images."
    }
  ],
  "paths": {
    "/upload": {
      "post": {
        "summary": "Upload Image",
        "description": "Uploads a single JPEG image to a specified gallery. The image can be displayed immediately upon upload.",
        "tags": [
          "Image APIs"
        ],
        "parameters": [
          {
            "in": "query",
            "name": "filename",
            "schema": {
              "type": "string"
            },
            "required": true,
            "description": "The name to save the file as."
          },
          {
            "in": "query",
            "name": "gallery",
            "schema": {
              "type": "string"
            },
            "required": false,
            "description": "The gallery to store the image in. Defaults to default."
          },
          {
            "in": "query",
            "name": "show_now",
            "schema": {
              "type": "integer",
              "enum": [
                0,
                1
              ]
            },
            "required": false,
            "description": "1 to display the image immediately after upload."
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "multipart/form-data": {
              "schema": {
                "type": "object",
                "properties": {
                  "image": {
                    "type": "string",
                    "format": "binary",
                    "description": "The binary data of the JPEG image."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Image uploaded successfully.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "status",
                    "path"
                  ],
                  "properties": {
                    "status": {
                      "type": "integer",
                      "description": "Firmware status code. `100` indicates success."
                    },
                    "path": {
                      "type": "string",
                      "description": "Stored path on device, e.g. `/gallerys/{gallery}/{filename}`."
                    }
                  }
                },
                "example": {
                  "status": 100,
                  "path": "/gallerys/default/test_1778763207.jpg"
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