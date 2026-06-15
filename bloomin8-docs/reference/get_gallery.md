# List Images in Gallery

Retrieves a paginated list of all images within a specific gallery.

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
      "name": "Gallery APIs",
      "description": "APIs for managing collections of images (galleries)."
    }
  ],
  "paths": {
    "/gallery": {
      "get": {
        "summary": "List Images in Gallery",
        "description": "Retrieves a paginated list of all images within a specific gallery.",
        "tags": [
          "Gallery APIs"
        ],
        "parameters": [
          {
            "in": "query",
            "name": "gallery_name",
            "schema": {
              "type": "string"
            },
            "required": true,
            "description": "The name of the gallery to query."
          },
          {
            "in": "query",
            "name": "offset",
            "schema": {
              "type": "integer",
              "format": "int32"
            },
            "required": true,
            "description": "The starting index for pagination."
          },
          {
            "in": "query",
            "name": "limit",
            "schema": {
              "type": "integer",
              "format": "int32"
            },
            "required": true,
            "description": "The number of items per page."
          },
          {
            "in": "query",
            "name": "full",
            "schema": {
              "type": "string",
              "enum": [
                "0",
                "1"
              ],
              "default": "0"
            },
            "required": false,
            "description": "Pagination mode switch. Pass \"1\" to enumerate the entire gallery via cursor-based pagination — required to access more than the most recent 51 images. When omitted or \"0\", the device only returns the most recent 51 images (offset/limit pagination with `total`, no cursor).\n"
          },
          {
            "in": "query",
            "name": "show_full_path",
            "schema": {
              "type": "boolean",
              "default": false
            },
            "required": false,
            "description": "When true, the `name` field (and `cursor_next` under full=1) returns the full path (e.g. \"/gallerys/default/f1.jpg\") instead of just the filename (\"f1.jpg\").\n"
          }
        ],
        "responses": {
          "200": {
            "description": "Paginated list of images in the gallery. The response shape depends on `full`: without `full=1` the device returns `total` (capped at 51); with `full=1` the device returns cursor-based fields (`cursor_next`, `more`) and omits `total`.\n",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "name": {
                            "type": "string",
                            "description": "Image filename, or full path when `show_full_path=true`.",
                            "example": "MANUAL_COVER_3547193_1769594354623_P.jpg"
                          },
                          "size": {
                            "type": "integer",
                            "format": "int32",
                            "description": "File size in bytes.",
                            "example": 981744
                          },
                          "time": {
                            "type": "integer",
                            "format": "int64",
                            "description": "Unix timestamp (seconds) of the image.",
                            "example": 1769594358
                          }
                        }
                      }
                    },
                    "total": {
                      "type": "integer",
                      "description": "Only present when `full` is omitted or \"0\". Number of images returned in this legacy mode (capped at the most recent 51).\n",
                      "example": 51
                    },
                    "cursor_next": {
                      "type": "string",
                      "description": "Only present when `full=1`. Opaque cursor (image name, or full path when `show_full_path=true`) to pass back to fetch the next page.\n",
                      "example": "MANUAL_COVER_JPg8NVFyXpax0crE6quM_1769417246208_P.jpg"
                    },
                    "more": {
                      "type": "boolean",
                      "description": "Only present when `full=1`. True if more pages remain.",
                      "example": true
                    },
                    "offset": {
                      "type": "integer",
                      "example": 0
                    },
                    "limit": {
                      "type": "integer",
                      "example": 10
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