# CLI Playback Controls for Bloomin8

This guide provides command-line examples using `curl` and the device REST API to:
1. Inspect current playback status (active gallery or playlist, playing image, interval).
2. List all available galleries and playlists stored on the device.
3. Change the slideshow timing interval on the currently playing gallery without re-uploading images.

## Prerequisites

- `curl` (standard on macOS and Linux)
- Optional: `jq` (recommended for parsing and formatting JSON output)

Set an environment variable for your frame's IP address or hostname:
```bash
FRAME_IP="192.168.1.25"
```

---

## 1. Inspect Current Playback

The `/deviceInfo` endpoint provides live status of the frame's playback state, including:
- `play_type`: `0` for single image, `1` for gallery slideshow, `2` for playlist
- `gallery`: currently active gallery name
- `playlist`: currently active playlist name (empty when not in playlist mode)
- `play_duration`: per-image playback interval in seconds
- `image`: path of the currently displayed image

### Formatted summary (with jq)
```bash
curl -s "http://${FRAME_IP}/deviceInfo" | jq '{
  play_type: (if .play_type == 1 then "gallery" elif .play_type == 2 then "playlist" else "single_image" end),
  active_gallery: .gallery,
  active_playlist: .playlist,
  interval_seconds: .play_duration,
  current_image: .image
}'
```

### Raw JSON (without jq)
```bash
curl -s "http://${FRAME_IP}/deviceInfo"
```

---

## 2. List All Galleries and Playlists

### List all galleries
```bash
curl -s "http://${FRAME_IP}/gallery/list" | jq -r '.[].name'
```

### List all playlists
```bash
curl -s "http://${FRAME_IP}/playlist/list" | jq -r '.[].name'
```

### All-in-one status check
```bash
bash -c '
FRAME_IP="192.168.1.25"
echo "=== CURRENT PLAYBACK ==="
curl -s "http://${FRAME_IP}/deviceInfo" | jq "{play_type, gallery, playlist, play_duration_sec: .play_duration, current_image: .image}"
echo -e "\n=== GALLERIES ==="
curl -s "http://${FRAME_IP}/gallery/list" | jq -r ".[].name"
echo -e "\n=== PLAYLISTS ==="
curl -s "http://${FRAME_IP}/playlist/list" | jq -r ".[].name"
'
```

---

## 3. Change Slideshow Timing Interval on Active Gallery

The `POST /show` endpoint initiates playback or updates the playback duration for a gallery slideshow (`play_type: 1`).

### Option A: Automatically detect the active gallery and update interval
This queries `/deviceInfo` to find the currently active gallery and sends `POST /show` with the new interval (in seconds):

```bash
FRAME_IP="192.168.1.25"
NEW_DURATION=300   # interval in seconds (e.g. 300 = 5 minutes)

ACTIVE_GALLERY=$(curl -s "http://${FRAME_IP}/deviceInfo" | jq -r '.gallery')

curl -s -X POST "http://${FRAME_IP}/show" \
  -H "Content-Type: application/json" \
  -d "{\"play_type\": 1, \"gallery\": \"${ACTIVE_GALLERY}\", \"duration\": ${NEW_DURATION}}"
```

### Option B: Set the interval directly for a specific gallery
If you already know the gallery name (e.g. `default`):

```bash
curl -s -X POST "http://${FRAME_IP}/show" \
  -H "Content-Type: application/json" \
  -d '{"play_type": 1, "gallery": "default", "duration": 300}'
```

### Option C: Using the plugin helper script
You can also use `bloomin8-gallery-slideshow.sh` with `--mode finish` to send the `POST /show` command without re-processing or re-uploading images:

```bash
bash Bloomin8.lrplugin/bloomin8-gallery-slideshow.sh \
  --host 192.168.1.25 \
  --mode finish \
  --gallery default \
  --duration 300
```
