# bloomin8-lightroom

Adobe Photoshop Lightroom Classic plugin project for publishing photos to a Bloomin8 frame.

## Goal

Create a Lightroom **publish service** that:
1. Publishes selected photos to a local directory as JPEG files.
2. Resizes exports to a 1600px long edge (targeting 1200x1600 display usage).
3. Uploads those files to a Bloomin8 frame through the public API.

API reference: https://bloomin8.readme.io/reference/get_deviceinfo

---

## Current implementation status

This repository now implements **Step 1** (foundation + local publish pipeline).

Implemented:
- Lightroom plugin bundle scaffold: `/home/runner/work/bloomin8-lightroom/bloomin8-lightroom/jeabraham/bloomin8-lightroom/Bloomin8.lrplugin`
- Plugin metadata (`Info.lua`)
- Export/publish provider (`PublishServiceProvider.lua`)
- Local directory setting in plugin UI
- JPEG render defaults with long-edge resize constrained to **1600px**
- Copy of rendered files into the configured local publish directory

Not implemented yet:
- Bloomin8 authentication/session handling
- Device discovery and selection
- Upload API call flow
- Publish state sync and retry queue

---

## Functional implementation plan (incremental)

### Step 1 (implemented)
Create plugin skeleton and local publish behavior:
- Add Lightroom plugin files.
- Add a configurable local output directory setting.
- Force JPEG export with 1600 long-edge constraint.
- Copy each rendered file to the local directory.

### Step 2
Add Bloomin8 API client module:
- Configurable API base URL and credentials/token storage.
- Request helper with robust error handling and response parsing.

### Step 3
Add frame/device handshake:
- Call device info endpoint.
- Validate connectivity and selected frame target.

### Step 4
Add upload pipeline:
- Iterate rendered local files.
- Upload each image using Bloomin8 API endpoints.
- Capture per-file success/failure details.

### Step 5
Add publish-state management:
- Track published IDs/metadata from Lightroom side.
- Handle re-publish, removal, and updates.

### Step 6
Add resilience + diagnostics:
- Retry policy for transient failures.
- User-facing status/errors in Lightroom dialogs/logs.

### Step 7
Hardening and release:
- Final manual QA in Lightroom Publish Manager.
- Packaging/versioning and release notes.

---

## Step 1 test instructions (manual)

There is no automated Lua test harness in this repository yet. Validate in Lightroom Classic:

1. Open Lightroom Classic.
2. File → Plug-in Manager → Add and select:
   - `/home/runner/work/bloomin8-lightroom/bloomin8-lightroom/jeabraham/bloomin8-lightroom/Bloomin8.lrplugin`
3. Create/use an export publish action with this plugin.
4. Set **Local publish directory** in plugin settings.
5. Export/publish a small set of photos.
6. Confirm output files are present in that directory and are JPEG with long edge constrained to 1600px.

---

## If API docs are inaccessible

If Bloomin8 API docs become unavailable, add the copied API documentation into this repository (for example under `docs/bloomin8-api/`) and reference that copy in future implementation steps.
