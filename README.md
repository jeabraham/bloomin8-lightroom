# bloomin8-lightroom

Adobe Photoshop Lightroom Classic plugin for publishing photos to a Bloomin8 frame.

## What it does

A Lightroom **publish service** that:
1. Renders selected photos to a local directory as JPEG files (fit within 1600×1200px).
2. Resizes and letterboxes each image to match the frame's canvas using ImageMagick.
3. Uploads photos to a Bloomin8 frame gallery through the device's local API.
4. Starts gallery slideshow playback on the frame after each publish.
5. Tracks publish state per-photo — only changed photos are re-uploaded on subsequent publishes.
6. Deletes photos from the local directory and from the device when removed from a collection.

API reference: https://bloomin8.readme.io/reference/get_deviceinfo

---

## Prerequisites

- Adobe Photoshop Lightroom Classic
- **ImageMagick** (required by `bloomin8-gallery-slideshow.sh` for resize/pad/rotate processing)
  - macOS: `brew install imagemagick`
  - Debian/Ubuntu: `sudo apt-get install imagemagick`
- Optional (for shell-level API diagnostics): `jq`

If the helper works in Terminal but fails from Lightroom, Lightroom may be running
with a limited `PATH`. The helper searches common ImageMagick install paths,
and you can set `BLOOMIN8_MAGICK_BIN` to an absolute executable path if needed.

---

## Installation

1. Open Lightroom Classic.
2. **File → Plug-in Manager → Add** and select `<repository-root>/Bloomin8.lrplugin`.
3. In the **Publish Services** panel (left sidebar), click **Set Up…** next to **Bloomin8 Publish Service**.
4. Set **Local publish directory** to where exported JPEGs should be stored.
5. Set **Device host** to the IP address or hostname of your Bloomin8 frame (e.g. `192.168.1.25`).  Leave blank to skip device upload and use the shell scripts manually.
6. Right-click a collection and choose **Edit Collection Settings** to configure per-collection options (gallery name, duration, playback order, frame orientation).

---

## API probe (validate device connectivity outside Lightroom)

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
`width:1600, height:1200` when in landscape.  The helper script uses ImageMagick
to rotate images whose orientation does not match the frame, then
scales and letter/pillarboxes them to exactly fill the canvas.  Pass
`--frame-orientation portrait|landscape` to match how your frame is physically hung.

---

## Manual gallery slideshow

Each Lightroom publish copies `bloomin8-gallery-slideshow.sh` into the
local publish directory alongside the exported JPEGs.

Run it from that directory to upload every `*.jpg`/`*.jpeg` file into one frame
gallery and then ask the frame itself to run the slideshow:

```bash
bash ./bloomin8-gallery-slideshow.sh \
  --host 192.168.1.25 \
  --frame-orientation portrait
```

Optional flags:
- `--gallery NAME` to pick the device gallery name explicitly
- `--duration SECONDS` to control the slideshow interval sent to `POST /show`
- `--image-dir PATH` if you want to run the helper from somewhere other than the publish directory
- `--frame-orientation portrait|landscape` (required) set to match how your frame is hung
- `--random` to shuffle images into a random upload order (the device displays them in the order they were uploaded)

Current helper behavior:
- calls `GET /deviceInfo`
- deletes and recreates the target gallery so the slideshow contains exactly the current exported set
- uploads each JPEG into that gallery (in sorted order by default; shuffled when `--random` is passed)
- calls `POST /show` with `play_type: 1` so the frame iterates the gallery on-device

## Automated gallery slideshow from Lightroom

When **Device host** is configured, Lightroom uploads photos and starts slideshow
playback automatically after each publish.  Configure the **Device Upload &
Slideshow** section in the plugin settings:

| Setting | Description |
|---|---|
| **Device host** | IP address or hostname of the Bloomin8 frame (e.g. `192.168.1.25`). Leave blank to skip upload and use the shell script manually. |

Gallery name, duration, playback order, and frame orientation are set
**per-collection** rather than globally, so each collection can target a
different gallery on the frame with its own slideshow settings.  To edit them,
right-click a collection in the Publish panel and choose **Edit Collection
Settings**.

| Collection Setting | Description |
|---|---|
| **Gallery name** | Name of the gallery on the device and the export subdirectory under the local publish directory. Leave blank to use the collection name automatically. |
| **Duration (seconds)** | Seconds between pictures in the slideshow (default: 120). |
| **Playback order** | *Sequential* (default) or *Random*. Random shuffles the upload order so the device plays images in a random sequence. |
| **Frame orientation** | *Portrait* or *Landscape* — set to match how your frame is physically hung on the wall. |

Each collection's files are exported to a subdirectory named after its gallery
(e.g. `<Local publish directory>/<Gallery name>/`).  This keeps images from
different collections isolated so that sending one collection's slideshow to the
frame does not mix in images from other collections.

When **Device host** is set, Lightroom will run `bloomin8-gallery-slideshow.sh`
automatically at the end of each publish, uploading all rendered photos and
starting playback on the frame.  If the script exits with an error a warning
dialog will appear.

Each publish also writes `bloomin8-run-slideshow.sh` into the collection's
export subdirectory.  It is a single-command wrapper that calls
`bloomin8-gallery-slideshow.sh` with the current settings (host, gallery,
duration, playback order, orientation), and forwards any extra CLI arguments you
append.

## Bloomin8 plugin log (for troubleshooting)

If slideshow upload fails, the plugin writes diagnostic output (including the
full shell script output) to its own log file:

- macOS: `~/Library/Logs/Adobe/Lightroom/LrClassicLogs/bloomin8.log`
- Windows: `%AppData%\Adobe\Lightroom\Logs\bloomin8.log`

The failure dialog also shows the last several lines of the script's output
directly, so you can usually see the reason without opening the log file.

---

## If API docs are inaccessible

If Bloomin8 API docs become unavailable, use the copied API documentation already present in this repository under `bloomin8-docs/reference/`.
