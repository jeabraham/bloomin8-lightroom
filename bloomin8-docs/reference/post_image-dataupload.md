# Upload Dithered Image Data

Uploads pre-processed, dithered raw image data for fast, direct-to-screen rendering. This is an advanced feature.

The data is stored in a dedicated directory (not in galleries). The device parses and refreshes the screen immediately upon upload. If uploaded during slideshow mode, the next slideshow cycle is postponed by 5 minutes (300s).

**Resolution must match the screen's current physical resolution exactly**, or the device will error.
- e.g. EL073TF1 portrait (rotation 1 or 3): 480 x 800
- e.g. EL073TF1 landscape (rotation 0 or 2): 800 x 480

**Color palette (6 colors):**

| Color  | Index | Binary (3-bit) |
|--------|-------|----------------|
| Black  | 0     | 000            |
| White  | 1     | 001            |
| Red    | 2     | 010            |
| Green  | 3     | 011            |
| Blue   | 4     | 100            |
| Yellow | 5     | 101            |

**3-bit packing format:** Each pixel is represented by 3 bits. Every 3 bytes (24 bits) encode 8 pixels. Pixels are scanned left-to-right, top-to-bottom. Their 3-bit values are concatenated into a continuous bit stream, then split into bytes.

**Example:** 9 pixels with colors [Red, Yellow, Green, White, Red, Black, White, White, ...]:
- Bit stream: `010 101 011 001 010 000 001 001 ...`
- Byte 1: `01010101` = `0x55`
- Byte 2: `10010100` = `0x94`
- Byte 3: `00001001` = `0x09`

**Data size comparison (e.g. 13.3" screen 1200x1600):**
- Uncompressed (1 byte/pixel): 1,920,000 bytes (~1.92 MB)
- 3-bit packed: (1200 × 1600 × 3) / 8 = 720,000 bytes (~703 KB)


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
    "/image/dataUpload": {
      "post": {
        "summary": "Upload Dithered Image Data",
        "description": "Uploads pre-processed, dithered raw image data for fast, direct-to-screen rendering. This is an advanced feature.\n\nThe data is stored in a dedicated directory (not in galleries). The device parses and refreshes the screen immediately upon upload. If uploaded during slideshow mode, the next slideshow cycle is postponed by 5 minutes (300s).\n\n**Resolution must match the screen's current physical resolution exactly**, or the device will error.\n- e.g. EL073TF1 portrait (rotation 1 or 3): 480 x 800\n- e.g. EL073TF1 landscape (rotation 0 or 2): 800 x 480\n\n**Color palette (6 colors):**\n\n| Color  | Index | Binary (3-bit) |\n|--------|-------|----------------|\n| Black  | 0     | 000            |\n| White  | 1     | 001            |\n| Red    | 2     | 010            |\n| Green  | 3     | 011            |\n| Blue   | 4     | 100            |\n| Yellow | 5     | 101            |\n\n**3-bit packing format:** Each pixel is represented by 3 bits. Every 3 bytes (24 bits) encode 8 pixels. Pixels are scanned left-to-right, top-to-bottom. Their 3-bit values are concatenated into a continuous bit stream, then split into bytes.\n\n**Example:** 9 pixels with colors [Red, Yellow, Green, White, Red, Black, White, White, ...]:\n- Bit stream: `010 101 011 001 010 000 001 001 ...`\n- Byte 1: `01010101` = `0x55`\n- Byte 2: `10010100` = `0x94`\n- Byte 3: `00001001` = `0x09`\n\n**Data size comparison (e.g. 13.3\" screen 1200x1600):**\n- Uncompressed (1 byte/pixel): 1,920,000 bytes (~1.92 MB)\n- 3-bit packed: (1200 × 1600 × 3) / 8 = 720,000 bytes (~703 KB)\n",
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
            "description": "A unique name for the data file."
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "multipart/form-data": {
              "schema": {
                "type": "object",
                "properties": {
                  "dithered_image": {
                    "type": "string",
                    "format": "binary",
                    "description": "The binary data of the dithered image."
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Dithered image data uploaded successfully."
          }
        }
      }
    }
  }
}
```