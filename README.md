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
- Lightroom plugin bundle scaffold: `<repository-root>/Bloomin8.lrplugin`
- Plugin metadata (`Info.lua`)
- Export/publish provider (`PublishServiceProvider.lua`)
- Local directory setting in plugin UI
- JPEG render defaults with long-edge resize constrained to **1600px**
- Copy of rendered files into the configured local publish directory
- Bash probe script for validating the frame API outside Lightroom: `<repository-root>/scripts/bloomin8-upload-probe.sh`

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

### Step 2 (current prototype path)
Validate the Bloomin8 API outside Lightroom first:
- Confirm `GET /deviceInfo` connectivity against the real frame.
- Confirm whether `POST /upload` works without extra auth/session setup.
- Use one exported JPEG as the test artifact.
- Capture success/failure responses before writing Lua upload code.

### Step 3
Add Bloomin8 API client module:
- Configurable API base URL and credentials/token storage.
- Request helper with robust error handling and response parsing.

### Step 4
Add frame/device handshake:
- Call device info endpoint.
- Validate connectivity and selected frame target.

### Step 5
Add upload pipeline:
- Iterate rendered local files.
- Upload each image using Bloomin8 API endpoints.
- Capture per-file success/failure details.

### Step 6
Add publish-state management:
- Track published IDs/metadata from Lightroom side.
- Handle re-publish, removal, and updates.

### Step 7
Add resilience + diagnostics:
- Retry policy for transient failures.
- User-facing status/errors in Lightroom dialogs/logs.

### Step 8
Hardening and release:
- Final manual QA in Lightroom Publish Manager.
- Packaging/versioning and release notes.

---

## Step 1 test instructions (manual)

There is no automated Lua test harness in this repository yet. Validate in Lightroom Classic:

1. Open Lightroom Classic.
2. File → Plug-in Manager → Add and select:
   - `<repository-root>/Bloomin8.lrplugin`
3. Create/use an export publish action with this plugin.
4. Set **Local publish directory** in plugin settings.
5. Export/publish a small set of photos.
6. Confirm output files are present in that directory and are JPEG with long edge constrained to 1600px.

---

## Step 2 API probe instructions (manual)

The repository now includes a bash helper for proving the upload flow outside Lightroom first:

- Script: `<repository-root>/scripts/bloomin8-upload-probe.sh`
- Local API docs copy: `<repository-root>/bloomin8-docs/reference`

Recommended flow:

1. Use a JPEG already exported by the Lightroom plugin.
2. Probe the frame without uploading anything:

   ```bash
   ./scripts/bloomin8-upload-probe.sh \
     --host 192.168.1.25 \
     --probe-only
   ```

3. Upload a single exported JPEG and ask the frame to display it immediately:

   ```bash
   ./scripts/bloomin8-upload-probe.sh \
     --host 192.168.1.25 \
     --image /absolute/path/to/exported-photo.jpg \
     --gallery default \
     --show-now
   ```

What this validates:
- whether `/deviceInfo` is reachable on the local network
- whether the device filesystem reports ready state
- whether the documented single-image upload endpoint accepts a multipart JPEG
- what the success/failure payload looks like on the real frame

Current docs indicate:
- `GET /deviceInfo` does not require documented auth parameters
- `POST /upload` accepts `multipart/form-data` with a single `image` part
- `POST /upload` uses query parameters `filename`, optional `gallery`, and optional `show_now`
- a successful upload returns HTTP 200 with JSON containing `status: 100` and a stored `path`
- `status: 0` from the upload endpoint indicates an on-device render failure (not an HTTP error)

**Orientation note (confirmed with real device):**
The device reports `width:1200, height:1600` regardless of its physical mounting
orientation.  When the frame is physically in landscape, a landscape photo
(wider than tall) must be rotated 90° before upload so the device renders it
correctly.  The probe script handles this automatically via `sips` on macOS.
The future Lightroom plugin upload step must apply the same rotation logic,
comparing the image's rendered pixel dimensions to the device's reported
`width`/`height` values.

If this shell-level probe works against the real device, the next code change should be implementing the same request flow in Lua.

---

## If API docs are inaccessible

If Bloomin8 API docs become unavailable, use the copied API documentation already present in this repository under `bloomin8-docs/reference/`.
