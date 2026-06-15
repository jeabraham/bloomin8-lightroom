# Delete Image

Deletes a specific image from a gallery.

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
    "/image/delete": {
      "post": {
        "summary": "Delete Image",
        "description": "Deletes a specific image from a gallery.",
        "tags": [
          "Image APIs"
        ],
        "parameters": [
          {
            "in": "query",
            "name": "image",
            "schema": {
              "type": "string"
            },
            "required": true,
            "description": "The filename of the image to delete."
          },
          {
            "in": "query",
            "name": "gallery",
            "schema": {
              "type": "string"
            },
            "required": false,
            "description": "The gallery containing the image. Defaults to default."
          }
        ],
        "responses": {
          "200": {
            "description": "Image deleted successfully."
          }
        }
      }
    }
  }
}
```