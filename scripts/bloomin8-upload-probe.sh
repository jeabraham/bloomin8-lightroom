#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
    cat <<EOF
Usage:
  ${SCRIPT_NAME} --host HOST --image PATH [options]
  ${SCRIPT_NAME} --host HOST --probe-only

Validate the Bloomin8 local API outside Lightroom by:
  1. Calling GET /deviceInfo
  2. Uploading a JPEG with POST /upload

Options:
  --host HOST                        Device host or base URL (example: 192.168.1.25 or http://192.168.1.25)
  --image PATH                       Local JPEG file to upload
  --gallery NAME                     Destination gallery (default: default)
  --filename NAME                    Remote filename override
  --show-now                         Ask the frame to display the uploaded image immediately
  --probe-only                       Stop after GET /deviceInfo
  --frame-orientation portrait|landscape
                                     Physical orientation of the frame (default: auto-detect from deviceInfo)
  --pad-color COLOR                  Background fill colour used when letterboxing (default: black)
  --connect-timeout N                Curl connect timeout in seconds (default: 5)
  --max-time N                       Curl total timeout in seconds (default: 60)
  --preview                          Open the processed image in Preview.app before uploading
                                     (macOS only; useful for verifying what will be sent to the frame)
  --help                             Show this message

Image processing:
  Requires ImageMagick (the 'magick' or 'convert'/'identify' commands).

  The script always produces a temporary JPEG that exactly matches the device
  canvas dimensions reported by /deviceInfo (e.g. 1200x1600 for portrait).

  Images are scaled to fit the canvas (portrait: 1200×1600, landscape:
  1600×1200) and padded with --pad-color.  No rotation is applied on the Mac.
  When the frame orientation is landscape a 90° CW rotation is applied only
  to the copy sent to the frame — the copy opened in --preview is always
  shown unrotated so it looks correct on your monitor.

  Use --frame-orientation to override the orientation inferred from the device
  (useful when the device API reports stale or unexpected dimensions).
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

sanitize_component() {
    local input="$1"
    local sanitized

    sanitized="$(printf '%s' "$input" | tr ' /' '__' | tr -cd '[:alnum:]._-')"
    [[ -n "$sanitized" ]] || die "Unable to derive a safe value from: $input"

    printf '%s' "$sanitized"
}

perform_request() {
    local response

    response="$(
        curl -sS \
            --connect-timeout "$CONNECT_TIMEOUT" \
            --max-time "$MAX_TIME" \
            -w $'\nHTTP_STATUS:%{http_code}\n' \
            "$@"
    )"

    LAST_STATUS="$(printf '%s\n' "$response" | sed -n 's/^HTTP_STATUS://p' | tail -n 1)"
    LAST_BODY="$(printf '%s\n' "$response" | sed '$d')"
}

# Extract a top-level numeric JSON field.  Uses jq when available, falls back
# to a grep-based approach that handles both compact and pretty-printed JSON.
extract_json_number() {
    local key="$1" body="$2"
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$body" | jq -r ".${key} // empty" 2>/dev/null
    else
        printf '%s' "$body" \
            | grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*[0-9]+" \
            | grep -oE '[0-9]+$' \
            | head -n1
    fi
}

require_command curl

# Detect ImageMagick — prefer the unified 'magick' binary (IM 7+), fall back
# to the classic 'convert' / 'identify' pair (IM 6 / distro packages).
if command -v magick >/dev/null 2>&1; then
    MAGICK_CONVERT=(magick)
    MAGICK_IDENTIFY=(magick identify)
elif command -v convert >/dev/null 2>&1 && command -v identify >/dev/null 2>&1; then
    MAGICK_CONVERT=(convert)
    MAGICK_IDENTIFY=(identify)
else
    die "ImageMagick is required for image processing.
  macOS : brew install imagemagick
  Debian: apt-get install imagemagick"
fi

TEMP_PROCESSED=""
TEMP_ROTATED=""

cleanup() {
    [[ -n "$TEMP_PROCESSED" ]] && rm -f "$TEMP_PROCESSED"
    [[ -n "$TEMP_ROTATED" ]] && rm -f "$TEMP_ROTATED"
}
trap cleanup EXIT

HOST=""
IMAGE_PATH=""
GALLERY="default"
REMOTE_FILENAME=""
SHOW_NOW=0
PROBE_ONLY=0
FRAME_ORIENTATION=""
PAD_COLOR="black"
CONNECT_TIMEOUT=5
MAX_TIME=60
OPEN_PREVIEW=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            HOST="${2:-}"
            shift 2
            ;;
        --image)
            IMAGE_PATH="${2:-}"
            shift 2
            ;;
        --gallery)
            GALLERY="${2:-}"
            shift 2
            ;;
        --filename)
            REMOTE_FILENAME="${2:-}"
            shift 2
            ;;
        --show-now)
            SHOW_NOW=1
            shift
            ;;
        --probe-only)
            PROBE_ONLY=1
            shift
            ;;
        --frame-orientation)
            FRAME_ORIENTATION="${2:-}"
            case "$FRAME_ORIENTATION" in
                portrait|landscape) ;;
                *) die "--frame-orientation must be 'portrait' or 'landscape'" ;;
            esac
            shift 2
            ;;
        --pad-color)
            PAD_COLOR="${2:-}"
            shift 2
            ;;
        --connect-timeout)
            CONNECT_TIMEOUT="${2:-}"
            shift 2
            ;;
        --max-time)
            MAX_TIME="${2:-}"
            shift 2
            ;;
        --preview)
            OPEN_PREVIEW=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

[[ -n "$HOST" ]] || {
    usage
    die "--host is required"
}

if [[ "$HOST" == http://* || "$HOST" == https://* ]]; then
    BASE_URL="${HOST%/}"
else
    BASE_URL="http://${HOST%/}"
fi

SAFE_GALLERY="$(sanitize_component "$GALLERY")"

if [[ "$PROBE_ONLY" -eq 0 ]]; then
    [[ -n "$IMAGE_PATH" ]] || {
        usage
        die "--image is required unless --probe-only is used"
    }

    [[ -f "$IMAGE_PATH" ]] || die "Image file not found: $IMAGE_PATH"

    if [[ -z "$REMOTE_FILENAME" ]]; then
        # Append a timestamp to the remote filename so every run uploads a
        # distinct file and the frame is guaranteed to render fresh content.
        local_stem="$(basename "$IMAGE_PATH")"
        local_ext="${local_stem##*.}"
        local_base="${local_stem%.*}"
        ts="$(date +%Y%m%dT%H%M%S)"
        REMOTE_FILENAME="${local_base}_${ts}.${local_ext}"
    fi

    SAFE_FILENAME="$(sanitize_component "$REMOTE_FILENAME")"

    case "$(printf '%s' "$IMAGE_PATH" | tr '[:upper:]' '[:lower:]')" in
        *.jpg|*.jpeg) ;;
        *)
            echo "Warning: upload endpoint is documented for JPEG input; continuing with: $IMAGE_PATH" >&2
            ;;
    esac
fi

echo "==> GET ${BASE_URL}/deviceInfo"
perform_request \
    -H 'Accept: application/json' \
    "${BASE_URL}/deviceInfo"

echo "HTTP ${LAST_STATUS}"
printf '%s\n' "$LAST_BODY"

[[ "$LAST_STATUS" == "200" ]] || die "deviceInfo request failed"

if ! grep -Eq '"fs_ready"[[:space:]]*:[[:space:]]*true' <<<"$LAST_BODY"; then
    echo "Warning: deviceInfo did not report fs_ready=true." >&2
fi

if ! grep -Eq '"network_type"[[:space:]]*:[[:space:]]*2' <<<"$LAST_BODY"; then
    echo "Warning: deviceInfo did not report network_type=2 (connected Wi-Fi)." >&2
fi

if [[ "$PROBE_ONLY" -eq 1 ]]; then
    exit 0
fi

UPLOAD_IMAGE="$IMAGE_PATH"

# ---------------------------------------------------------------------------
# Determine canvas dimensions.
# ---------------------------------------------------------------------------
CANVAS_W="$(extract_json_number "width"  "$LAST_BODY")"
CANVAS_H="$(extract_json_number "height" "$LAST_BODY")"

if [[ -z "$CANVAS_W" || -z "$CANVAS_H" || "$CANVAS_W" -eq 0 || "$CANVAS_H" -eq 0 ]]; then
    echo "Warning: could not read canvas dimensions from deviceInfo; defaulting to 1200x1600 (portrait)." >&2
    CANVAS_W=1200
    CANVAS_H=1600
fi

# Override canvas orientation if --frame-orientation was supplied.
if [[ "$FRAME_ORIENTATION" == "landscape" && "$CANVAS_H" -gt "$CANVAS_W" ]]; then
    _tmp="$CANVAS_W"; CANVAS_W="$CANVAS_H"; CANVAS_H="$_tmp"
elif [[ "$FRAME_ORIENTATION" == "portrait" && "$CANVAS_W" -gt "$CANVAS_H" ]]; then
    _tmp="$CANVAS_H"; CANVAS_H="$CANVAS_W"; CANVAS_W="$_tmp"
fi

# ---------------------------------------------------------------------------
# Determine visual image dimensions (respecting EXIF orientation tags).
# ---------------------------------------------------------------------------
# EXIF orientations 5-8 indicate a 90°/270° transpose, so width and height
# are visually swapped relative to the stored pixel dimensions.
EXIF_ORIENT="$("${MAGICK_IDENTIFY[@]}" -format "%[EXIF:Orientation]" "$IMAGE_PATH" 2>/dev/null | head -n1)"
IMG_W_RAW="$("${MAGICK_IDENTIFY[@]}" -format "%w" "$IMAGE_PATH" 2>/dev/null | head -n1)"
IMG_H_RAW="$("${MAGICK_IDENTIFY[@]}" -format "%h" "$IMAGE_PATH" 2>/dev/null | head -n1)"

if [[ -z "$IMG_W_RAW" || -z "$IMG_H_RAW" ]]; then
    die "Could not read image dimensions from: $IMAGE_PATH"
fi

if [[ "$EXIF_ORIENT" =~ ^[5-8]$ ]]; then
    IMG_W="$IMG_H_RAW"
    IMG_H="$IMG_W_RAW"
else
    IMG_W="$IMG_W_RAW"
    IMG_H="$IMG_H_RAW"
fi

echo "==> Image: ${IMG_W}x${IMG_H}  Canvas: ${CANVAS_W}x${CANVAS_H}"

# ---------------------------------------------------------------------------
# Determine whether the frame expects a rotated image for upload.
# A landscape frame (CANVAS_W > CANVAS_H) requires every image to be rotated
# 90° CW before upload so the firmware renders it correctly.  The canvas
# dimensions still drive the scale/pad step (1600×1200 for landscape).
# ---------------------------------------------------------------------------
FRAME_IS_LANDSCAPE=0
if [[ "$CANVAS_W" -gt "$CANVAS_H" ]]; then
    FRAME_IS_LANDSCAPE=1
fi

# ---------------------------------------------------------------------------
# Build the ImageMagick processing pipeline.
# Scale and pad to the canvas dimensions; no rotation here — the Mac display
# is not rotated.
# ---------------------------------------------------------------------------
echo "==> Scaling and padding to ${CANVAS_W}x${CANVAS_H} (pad colour: ${PAD_COLOR})"

MAGICK_ARGS=(
    -auto-orient
    -resize "${CANVAS_W}x${CANVAS_H}"
    -background "$PAD_COLOR"
    -gravity center
    -extent "${CANVAS_W}x${CANVAS_H}"
)

# mktemp on macOS requires Xs at the very end of the template, so we cannot
# embed a .jpg suffix.  Build a unique name from the process ID and $RANDOM.
TEMP_PROCESSED="/tmp/bloomin8-processed-$$.${RANDOM}.jpg"
"${MAGICK_CONVERT[@]}" "$IMAGE_PATH" "${MAGICK_ARGS[@]}" "$TEMP_PROCESSED"
UPLOAD_IMAGE="$TEMP_PROCESSED"

# For landscape frames the device firmware expects the image rotated 90° CW.
# Produce the rotated copy now (before potentially handing TEMP_PROCESSED off
# to Preview) so both files exist at the same time.
if [[ "$FRAME_IS_LANDSCAPE" -eq 1 ]]; then
    TEMP_ROTATED="/tmp/bloomin8-rotated-$$.${RANDOM}.jpg"
    echo "==> Rotating 90° CW for landscape frame upload"
    # +repage clears the virtual canvas geometry that -rotate leaves behind.
    "${MAGICK_CONVERT[@]}" "$TEMP_PROCESSED" -rotate 90 +repage "$TEMP_ROTATED"
    UPLOAD_IMAGE="$TEMP_ROTATED"
fi

# ---------------------------------------------------------------------------
# Open the unrotated processed image in Preview.app if requested (macOS only).
# The user's monitor is not rotated, so we always show TEMP_PROCESSED here.
# ---------------------------------------------------------------------------
if [[ "$OPEN_PREVIEW" -eq 1 ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "==> Opening processed image in Preview: ${TEMP_PROCESSED}"
        open -a Preview "$TEMP_PROCESSED"
        # Disable the EXIT cleanup for this file so Preview can load it;
        # macOS will remove stale /tmp files on restart.
        TEMP_PROCESSED=""
    else
        echo "Warning: --preview is only supported on macOS; skipping." >&2
    fi
fi

UPLOAD_URL="${BASE_URL}/upload?filename=${SAFE_FILENAME}&gallery=${SAFE_GALLERY}&show_now=${SHOW_NOW}"

# Delete any existing copy of the file so the device renders fresh from the
# new upload rather than serving a cached version of the old render.
DELETE_URL="${BASE_URL}/image/delete?image=${SAFE_FILENAME}&gallery=${SAFE_GALLERY}"
echo "==> POST ${DELETE_URL}"
perform_request \
    -H 'Accept: application/json' \
    -X POST \
    "$DELETE_URL"
echo "HTTP ${LAST_STATUS}"
if [[ "$LAST_STATUS" == "200" ]]; then
    echo "Existing file deleted."
else
    echo "(File did not exist on device or delete is not supported; continuing.)"
fi

echo
echo "==> POST ${UPLOAD_URL}"
perform_request \
    -H 'Accept: application/json' \
    -X POST \
    -F "image=@${UPLOAD_IMAGE};type=image/jpeg" \
    "$UPLOAD_URL"

echo "HTTP ${LAST_STATUS}"
printf '%s\n' "$LAST_BODY"

[[ "$LAST_STATUS" == "200" ]] || die "upload request failed"
grep -Eq '"status"[[:space:]]*:[[:space:]]*100' <<<"$LAST_BODY" || die "upload did not return firmware success status 100"

# ---------------------------------------------------------------------------
# If --show-now was requested, follow up with an explicit POST /show so the
# frame re-renders the freshly uploaded file.  The show_now=1 upload flag may
# not trigger a re-render when the same filename is already in the display
# queue; the /show endpoint with an explicit image path is more reliable.
# ---------------------------------------------------------------------------
if [[ "$SHOW_NOW" -eq 1 ]]; then
    SHOW_URL="${BASE_URL}/show"
    IMAGE_DEVICE_PATH="/gallerys/${SAFE_GALLERY}/${SAFE_FILENAME}"
    SHOW_BODY="{\"play_type\":0,\"image\":\"${IMAGE_DEVICE_PATH}\"}"
    echo
    echo "==> POST ${SHOW_URL}  (play_type=0, image=${IMAGE_DEVICE_PATH})"
    perform_request \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        -X POST \
        -d "$SHOW_BODY" \
        "$SHOW_URL"
    echo "HTTP ${LAST_STATUS}"
    printf '%s\n' "$LAST_BODY"
    [[ "$LAST_STATUS" == "200" ]] || echo "Warning: /show request returned HTTP ${LAST_STATUS}; frame may not refresh." >&2
fi

echo
echo "Upload probe succeeded."
