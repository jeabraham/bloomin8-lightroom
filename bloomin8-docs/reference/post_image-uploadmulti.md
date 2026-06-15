# Upload Multiple Images

Uploads multiple images in a single request.

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
    "/image/uploadMulti": {
      "post": {
        "summary": "Upload Multiple Images",
        "description": "Uploads multiple images in a single request.",
        "tags": [
          "Image APIs"
        ],
        "parameters": [
          {
            "in": "query",
            "name": "gallery",
            "schema": {
              "type": "string"
            },
            "required": false,
            "description": "The destination gallery."
          },
          {
            "in": "query",
            "name": "override",
            "schema": {
              "type": "integer",
              "enum": [
                0,
                1
              ]
            },
            "required": false,
            "description": "1 to overwrite existing files with the same name."
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "multipart/form-data": {
              "schema": {
                "type": "object",
                "properties": {
                  "images": {
                    "type": "array",
                    "items": {
                      "type": "string",
                      "format": "binary"
                    },
                    "description": "Multiple parts, each containing image binary data."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Images uploaded successfully.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "required": [
                    "status",
                    "files"
                  ],
                  "properties": {
                    "status": {
                      "type": "integer",
                      "description": "Overall firmware status code. `100` indicates success."
                    },
                    "files": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "required": [
                          "path",
                          "size",
                          "status"
                        ],
                        "properties": {
                          "path": {
                            "type": "string",
                            "description": "Stored path on device, e.g. `/gallerys/{gallery}/{filename}`."
                          },
                          "size": {
                            "type": "integer",
                            "description": "File size in bytes."
                          },
                          "status": {
                            "type": "string",
                            "description": "Per-file result, e.g. `uploaded`."
                          }
                        }
                      }
                    }
                  }
                },
                "example": {
                  "status": 100,
                  "files": [
                    {
                      "path": "/gallerys/default/multi_a_1778763474.jpg",
                      "size": 241614,
                      "status": "uploaded"
                    },
                    {
                      "path": "/gallerys/default/multi_b_1778763474.jpg",
                      "size": 241614,
                      "status": "uploaded"
                    }
                  ]
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