# bloomin8-lightroom

Adobe Photoshop Lightroom Classic plugin project for publishing photos to a Bloomin8 frame.

## Goal

Create a Lightroom **publish service** that:
1. Publishes selected photos to a local directory as JPEG files.
2. Resizes exports to a 1600px long edge (targeting 1200x1600 display usage).
3. Uploads those files to a Bloomin8 frame through the public API.

API reference: https://bloomin8.readme.io/reference/get_deviceinfo

---

## Prerequisites

- Adobe Photoshop Lightroom Classic
- **ImageMagick** (required by `bloomin8-gallery-slideshow.sh` for resize/pad/rotate processing)
  - macOS: `brew install imagemagick`
  - Debian/Ubuntu: `sudo apt-get install imagemagick`
- Optional (for shell-level API diagnostics): `jq`

If the helper works in Terminal but fails from Lightroom, Lightroom may be running
with a limited `PATH`. The helper now searches common ImageMagick install paths,
and you can set `BLOOMIN8_MAGICK_BIN` to an absolute executable path if needed.

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
- Gallery slideshow helper copied into the local publish directory on publish: `bloomin8-gallery-slideshow.sh`

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
The device reports `width:1200, height:1600` when in portrait orientation and
`width:1600, height:1200` when in landscape.  The probe script uses ImageMagick
to automatically rotate images whose orientation does not match the frame, then
scales and letter/pillarboxes them to exactly fill the canvas.  Use
`--frame-orientation portrait|landscape` to override what is inferred from the
device's `width`/`height` values.
The future Lightroom plugin upload step must apply the same rotation and
padding logic, comparing the image's rendered pixel dimensions to the device's
reported `width`/`height` values.

If this shell-level probe works against the real device, the next code change should be implementing the same request flow in Lua.

---

## Manual gallery slideshow testing

Each Lightroom publish now also copies `bloomin8-gallery-slideshow.sh` into the
local publish directory alongside the exported JPEGs.

Run it from that directory to upload every `*.jpg`/`*.jpeg` file into one frame
gallery and then ask the frame itself to run the slideshow:

```bash
bash ./bloomin8-gallery-slideshow.sh \
  --host 192.168.1.25
```

Optional flags:
- `--gallery NAME` to pick the device gallery name explicitly
- `--duration SECONDS` to control the slideshow interval sent to `POST /show`
- `--image-dir PATH` if you want to run the helper from somewhere other than the publish directory
- `--frame-orientation portrait|landscape` to override the orientation inferred from `/deviceInfo`
- `--random` to shuffle images into a random upload order (the device displays them in the order they were uploaded)

Current helper behavior:
- calls `GET /deviceInfo`
- deletes and recreates the target gallery so the slideshow contains exactly the current exported set
- uploads each JPEG into that gallery (in sorted order by default; shuffled when `--random` is passed)
- calls `POST /show` with `play_type: 1` so the frame iterates the gallery on-device

## Automated gallery slideshow from Lightroom

The plugin can upload photos and start the slideshow automatically after each
publish.  Configure the **Step 2: Device Upload & Slideshow** section in the
plugin settings:

| Setting | Description |
|---|---|
| **Device host** | IP address or hostname of the Bloomin8 frame (e.g. `192.168.1.25`). Leave blank to skip upload and use the shell script manually. |
| **Gallery name** | Name of the gallery on the device. Defaults to the local publish directory name if left blank. |
| **Duration (seconds)** | Seconds between pictures in the slideshow (default: 120). |
| **Playback order** | *Sequential* (default) or *Random*. Random shuffles the upload order so the device plays images in a random sequence. |
| **Frame orientation** | *Auto (from device)* reads width/height from `/deviceInfo`. Set to *Portrait* or *Landscape* to match how your frame is physically hung on the wall if the auto-detected value is wrong. |

When **Device host** is set, Lightroom will run `bloomin8-gallery-slideshow.sh`
automatically at the end of each publish, uploading all rendered photos and
starting playback on the frame.  If the script exits with an error a warning
dialog will appear.

Each publish also writes `bloomin8-run-slideshow.sh` into the publish directory.
It is a single-command wrapper that calls `bloomin8-gallery-slideshow.sh` with
the current Lightroom settings (host, gallery, duration, playback order,
orientation), and forwards any extra CLI arguments you append.

## Lightroom logs (for troubleshooting)

If slideshow upload fails, check the Lightroom log:

- macOS: `~/Library/Logs/Adobe/Lightroom/`
- Windows: `%AppData%\Adobe\Lightroom\Logs\`

---

## If API docs are inaccessible

If Bloomin8 API docs become unavailable, use the copied API documentation already present in this repository under `bloomin8-docs/reference/`.
