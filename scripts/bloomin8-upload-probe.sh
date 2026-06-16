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

  If the image orientation (portrait vs landscape) differs from the frame
  orientation, the image is first rotated 90° clockwise.  It is then scaled
  to fit within the canvas while preserving aspect ratio, and any remaining
  canvas area is filled with --pad-color (letterboxing / pillarboxing).

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

cleanup() {
    if [[ -n "$TEMP_PROCESSED" ]]; then
        rm -f "$TEMP_PROCESSED"
    fi
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
        REMOTE_FILENAME="$(basename "$IMAGE_PATH")"
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
# Build the ImageMagick processing pipeline.
# ---------------------------------------------------------------------------
# Rotate 90° CW when the image and frame orientations differ:
#   landscape image on a portrait frame, or portrait image on a landscape frame.
ROTATE=0
if [[ "$IMG_W" -gt "$IMG_H" && "$CANVAS_H" -gt "$CANVAS_W" ]]; then
    echo "==> Rotating landscape image 90° CW to fit portrait frame"
    ROTATE=90
elif [[ "$IMG_H" -gt "$IMG_W" && "$CANVAS_W" -gt "$CANVAS_H" ]]; then
    echo "==> Rotating portrait image 90° CW to fit landscape frame"
    ROTATE=90
fi

echo "==> Scaling and padding to ${CANVAS_W}x${CANVAS_H} (pad colour: ${PAD_COLOR})"

MAGICK_ARGS=(-auto-orient)
if [[ "$ROTATE" -ne 0 ]]; then
    # +repage clears the virtual canvas geometry that -rotate leaves behind,
    # ensuring -resize and -extent operate on the actual pixel dimensions.
    MAGICK_ARGS+=(-rotate "$ROTATE" +repage)
fi
MAGICK_ARGS+=(
    -resize "${CANVAS_W}x${CANVAS_H}"
    -background "$PAD_COLOR"
    -gravity center
    -extent "${CANVAS_W}x${CANVAS_H}"
)

TEMP_PROCESSED="$(mktemp /tmp/bloomin8-processed-XXXXXX.jpg)"
"${MAGICK_CONVERT[@]}" "$IMAGE_PATH" "${MAGICK_ARGS[@]}" "$TEMP_PROCESSED"
UPLOAD_IMAGE="$TEMP_PROCESSED"

# ---------------------------------------------------------------------------
# Open processed image in Preview.app if requested (macOS only).
# ---------------------------------------------------------------------------
if [[ "$OPEN_PREVIEW" -eq 1 ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
        PREVIEW_COPY="/tmp/bloomin8-preview.jpg"
        cp "$TEMP_PROCESSED" "$PREVIEW_COPY"
        echo "==> Opening processed image in Preview: ${PREVIEW_COPY}"
        open -a Preview "$PREVIEW_COPY"
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

echo
echo "Upload probe succeeded."
