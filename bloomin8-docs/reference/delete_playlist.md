# Delete Playlist

Deletes a specific playlist.

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
      "delete": {
        "summary": "Delete Playlist",
        "description": "Deletes a specific playlist.",
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
            "description": "The name of the playlist to delete."
          }
        ],
        "responses": {
          "200": {
            "description": "Playlist deleted successfully."
          }
        }
      }
    }
  }
}
```