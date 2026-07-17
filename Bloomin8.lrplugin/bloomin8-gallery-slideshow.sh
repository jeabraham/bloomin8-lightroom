#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
FIRMWARE_UPLOAD_SUCCESS=100

usage() {
    cat <<EOF
Usage:
  bash ${SCRIPT_NAME} --host HOST [options]

Upload every JPG/JPEG in the current directory into one Bloomin8 gallery and
start the frame's gallery slideshow playback.

Options:
  --host HOST                        Device host or base URL
  --image-dir PATH                   Directory containing JPG/JPEG files (default: current directory)
  --gallery NAME                     Destination gallery (default: derived from directory name)
  --duration SECONDS                 Slideshow interval passed to POST /show (default: 120)
  --frame-orientation portrait|landscape
                                     Orientation of the frame (required)
  --pad-color COLOR                  Background fill color used when padding (default: black)
  --random                           Shuffle images into a random upload order
  --connect-timeout N                Curl connect timeout in seconds (default: 5)
  --max-time N                       Curl total timeout in seconds (default: 60)
  --file PATH                        Add a specific file to upload (repeatable). When one or more
                                     --file options are given the script runs in incremental mode:
                                     the gallery is not deleted/recreated and only the specified
                                     files are processed and uploaded.
  --help                             Show this message

Environment:
  BLOOMIN8_MAGICK_BIN                Absolute path to ImageMagick binary to use
                                     (for Lightroom-launched shells with limited PATH)
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

find_command_path() {
    local cmd="$1"
    local path_candidate

    if path_candidate="$(command -v "$cmd" 2>/dev/null)"; then
        printf '%s' "$path_candidate"
        return 0
    fi

    for path_candidate in \
        "/opt/homebrew/bin/${cmd}" \
        "/usr/local/bin/${cmd}" \
        "/opt/local/bin/${cmd}" \
        "/usr/bin/${cmd}" \
        "/bin/${cmd}"
    do
        if [[ -x "$path_candidate" ]]; then
            printf '%s' "$path_candidate"
            return 0
        fi
    done

    return 1
}

sanitize_component() {
    local input="$1"
    local sanitized

    sanitized="$(printf '%s' "$input" | tr ' /' '__' | tr -cd '[:alnum:]._-' | tr -s '_')"
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

derive_canvas_dimensions() {
    CANVAS_W="$(extract_json_number "width" "$LAST_BODY")"
    CANVAS_H="$(extract_json_number "height" "$LAST_BODY")"

    if [[ -z "$CANVAS_W" || -z "$CANVAS_H" || "$CANVAS_W" -eq 0 || "$CANVAS_H" -eq 0 ]]; then
        echo "Warning: could not read canvas dimensions from deviceInfo; defaulting to 1200x1600 before applying orientation." >&2
        CANVAS_W=1200
        CANVAS_H=1600
    fi

    if [[ "$FRAME_ORIENTATION" == "landscape" && "$CANVAS_H" -gt "$CANVAS_W" ]]; then
        _tmp="$CANVAS_W"; CANVAS_W="$CANVAS_H"; CANVAS_H="$_tmp"
    elif [[ "$FRAME_ORIENTATION" == "portrait" && "$CANVAS_W" -gt "$CANVAS_H" ]]; then
        _tmp="$CANVAS_H"; CANVAS_H="$CANVAS_W"; CANVAS_W="$_tmp"
    fi

    FRAME_IS_LANDSCAPE=0
    if [[ "$CANVAS_W" -gt "$CANVAS_H" ]]; then
        FRAME_IS_LANDSCAPE=1
    fi
}

collect_images() {
    local file
    IMAGE_FILES=()

    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        IMAGE_FILES+=("$file")
    done < <(
        find "$IMAGE_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -print | LC_ALL=C sort
    )

    [[ "${#IMAGE_FILES[@]}" -gt 0 ]] || die "No JPG/JPEG files found in: $IMAGE_DIR"
}

shuffle_images() {
    local i j tmp n="${#IMAGE_FILES[@]}"
    for (( i = n - 1; i > 0; i-- )); do
        j=$(( RANDOM % (i + 1) ))
        tmp="${IMAGE_FILES[$i]}"
        IMAGE_FILES[$i]="${IMAGE_FILES[$j]}"
        IMAGE_FILES[$j]="$tmp"
    done
}

prepare_image() {
    local source_path="$1"
    local output_stem="$2"
    local processed_path="${PROCESSED_DIR}/${output_stem}.jpg"
    local rotated_path="${PROCESSED_DIR}/${output_stem}-rotated.jpg"

    echo "==> Preparing $(basename "$source_path") for ${CANVAS_W}x${CANVAS_H}" >&2
    "${MAGICK_CONVERT[@]}" \
        "$source_path" \
        -auto-orient \
        -resize "${CANVAS_W}x${CANVAS_H}" \
        -background "$PAD_COLOR" \
        -gravity center \
        -extent "${CANVAS_W}x${CANVAS_H}" \
        "$processed_path"

    if [[ "$FRAME_IS_LANDSCAPE" -eq 1 ]]; then
        "${MAGICK_CONVERT[@]}" "$processed_path" -rotate 90 +repage "$rotated_path"
        printf '%s' "$rotated_path"
    else
        printf '%s' "$processed_path"
    fi
}

HOST=""
IMAGE_DIR="."
GALLERY=""
DURATION=120
FRAME_ORIENTATION=""
PAD_COLOR="black"
CONNECT_TIMEOUT=5
MAX_TIME=60
RANDOM_ORDER=0
NEW_FILES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            HOST="${2:-}"
            shift 2
            ;;
        --image-dir)
            IMAGE_DIR="${2:-}"
            shift 2
            ;;
        --gallery)
            GALLERY="${2:-}"
            shift 2
            ;;
        --duration)
            DURATION="${2:-}"
            shift 2
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
        --random)
            RANDOM_ORDER=1
            shift
            ;;
        --file)
            [[ -n "${2:-}" ]] || die "--file requires a non-empty path argument"
            NEW_FILES+=("$2")
            shift 2
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

[[ -n "$FRAME_ORIENTATION" ]] || {
    usage
    die "--frame-orientation is required (portrait or landscape)"
}

[[ -d "$IMAGE_DIR" ]] || die "Image directory not found: $IMAGE_DIR"

require_command curl

if [[ -n "${BLOOMIN8_MAGICK_BIN:-}" ]]; then
    [[ -x "${BLOOMIN8_MAGICK_BIN}" ]] || die "BLOOMIN8_MAGICK_BIN is not executable: ${BLOOMIN8_MAGICK_BIN}"
    MAGICK_CONVERT=("${BLOOMIN8_MAGICK_BIN}")
elif MAGICK_PATH="$(find_command_path magick)"; then
    MAGICK_CONVERT=("${MAGICK_PATH}")
elif MAGICK_PATH="$(find_command_path convert)"; then
    MAGICK_CONVERT=("${MAGICK_PATH}")
else
    die $'ImageMagick is required for image processing.\n  macOS : brew install imagemagick\n  Debian: apt-get install imagemagick\nIf Lightroom cannot find it, set BLOOMIN8_MAGICK_BIN to the full executable path.'
fi

if [[ "$HOST" == http://* || "$HOST" == https://* ]]; then
    BASE_URL="${HOST%/}"
else
    BASE_URL="http://${HOST%/}"
fi

IMAGE_DIR="$(cd "$IMAGE_DIR" && pwd)"

if [[ "${#NEW_FILES[@]}" -gt 0 ]]; then
    # Incremental mode: only the explicitly specified files are processed and uploaded.
    IMAGE_FILES=("${NEW_FILES[@]}")
else
    collect_images

    if [[ "$RANDOM_ORDER" -eq 1 ]]; then
        shuffle_images
    fi
fi

if [[ -z "$GALLERY" ]]; then
    GALLERY="$(basename "$IMAGE_DIR")"
fi

SAFE_GALLERY="$(sanitize_component "$GALLERY")"

case "$DURATION" in
    ''|*[!0-9]*)
        die "--duration must be a positive integer"
        ;;
esac
[[ "$DURATION" -gt 0 ]] || die "--duration must be a positive integer"

PROCESSED_DIR="${IMAGE_DIR}/processed"
mkdir -p "$PROCESSED_DIR"

echo "==> GET ${BASE_URL}/deviceInfo"
perform_request \
    -H 'Accept: application/json' \
    "${BASE_URL}/deviceInfo"
echo "HTTP ${LAST_STATUS}"
printf '%s\n' "$LAST_BODY"
[[ "$LAST_STATUS" == "200" ]] || die "deviceInfo request failed"

derive_canvas_dimensions

echo
if [[ "${#NEW_FILES[@]}" -eq 0 ]]; then
    echo "==> DELETE ${BASE_URL}/gallery?name=${SAFE_GALLERY}"
    perform_request \
        -H 'Accept: application/json' \
        -X DELETE \
        "${BASE_URL}/gallery?name=${SAFE_GALLERY}"
    echo "HTTP ${LAST_STATUS}"
    if [[ "$LAST_STATUS" == "200" ]]; then
        printf '%s\n' "$LAST_BODY"
    else
        echo "(Gallery did not already exist or delete was not accepted; continuing.)"
    fi

    echo
    echo "==> PUT ${BASE_URL}/gallery?name=${SAFE_GALLERY}"
    perform_request \
        -H 'Accept: application/json' \
        -X PUT \
        "${BASE_URL}/gallery?name=${SAFE_GALLERY}"
    echo "HTTP ${LAST_STATUS}"
    printf '%s\n' "$LAST_BODY"
    [[ "$LAST_STATUS" == "200" ]] || die "gallery creation failed"
else
    # Incremental mode: ensure the gallery exists; ignore failure if it already exists.
    echo "==> PUT ${BASE_URL}/gallery?name=${SAFE_GALLERY} (ensure exists)"
    perform_request \
        -H 'Accept: application/json' \
        -X PUT \
        "${BASE_URL}/gallery?name=${SAFE_GALLERY}" || true
    if [[ "$LAST_STATUS" == "200" ]]; then
        echo "HTTP ${LAST_STATUS} (gallery created)"
    else
        echo "HTTP ${LAST_STATUS:-unknown} (gallery may already exist; continuing)"
    fi

    # Stop any active slideshow before uploading.  The firmware returns status 3
    # (not 100) when POST /upload is called while a gallery slideshow is playing,
    # preventing the upload from being accepted.  POST /stop pauses playback so
    # the uploads succeed; POST /show at the end of this script restarts it.
    echo
    echo "==> POST ${BASE_URL}/stop"
    perform_request \
        -H 'Accept: application/json' \
        -X POST \
        "${BASE_URL}/stop" || true
    echo "HTTP ${LAST_STATUS:-unknown}"
fi

# Indexed array of remote filenames already claimed in this run.
# Using an indexed array (bash 3.2-compatible) instead of an associative
# array (which requires bash 4+, unavailable on stock macOS).
used_remote_names=()

name_in_use() {
    local name="$1" n
    for n in "${used_remote_names[@]+"${used_remote_names[@]}"}"; do
        [[ "$n" == "$name" ]] && return 0
    done
    return 1
}

image_index=0
for image_path in "${IMAGE_FILES[@]}"; do
    image_index=$((image_index + 1))

    # Derive the remote filename from the plain basename (no sequence prefix).
    # On collision, append _2, _3, … before the extension.
    base_remote="$(sanitize_component "$(basename "$image_path")")"
    if [[ "$base_remote" == *.* ]]; then
        stem="${base_remote%.*}"
        ext=".${base_remote##*.}"
    else
        stem="$base_remote"
        ext=""
    fi
    remote_filename="$base_remote"
    suffix=2
    while name_in_use "$remote_filename"; do
        remote_filename="${stem}_${suffix}${ext}"
        suffix=$(( suffix + 1 ))
    done
    used_remote_names+=("$remote_filename")

    prepared_image="$(prepare_image "$image_path" "$(printf '%04d' "$image_index")")"
    [[ -f "$prepared_image" ]] || die "Image preparation failed (ImageMagick error?) for: $image_path"

    if [[ "${#NEW_FILES[@]}" -gt 0 ]]; then
        # Incremental: delete any existing copy from the device first (ignore failure –
        # the file may not exist yet for a brand-new photo).
        echo
        echo "==> POST ${BASE_URL}/image/delete?image=${remote_filename}&gallery=${SAFE_GALLERY} (pre-delete)"
        perform_request \
            -H 'Accept: application/json' \
            -X POST \
            "${BASE_URL}/image/delete?image=${remote_filename}&gallery=${SAFE_GALLERY}" || true
        echo "HTTP ${LAST_STATUS:-skipped}"
    fi

    echo
    echo "==> Uploading processed file:"
    ls -la "$prepared_image"
    echo "==> POST ${BASE_URL}/upload?filename=${remote_filename}&gallery=${SAFE_GALLERY}"
    perform_request \
        -H 'Accept: application/json' \
        -X POST \
        -F "image=@${prepared_image};type=image/jpeg" \
        "${BASE_URL}/upload?filename=${remote_filename}&gallery=${SAFE_GALLERY}"
    echo "HTTP ${LAST_STATUS}"
    printf '%s\n' "$LAST_BODY"
    [[ "$LAST_STATUS" == "200" ]] || die "upload request failed for: $image_path"
    grep -Eq "\"status\"[[:space:]]*:[[:space:]]*${FIRMWARE_UPLOAD_SUCCESS}" <<<"$LAST_BODY" || {
        echo "Upload failed for: $image_path" >&2
        echo "Response body:" >&2
        echo "$LAST_BODY" >&2
        die "upload did not return status ${FIRMWARE_UPLOAD_SUCCESS}"
    }
done

SHOW_BODY="{\"play_type\":1,\"gallery\":\"${SAFE_GALLERY}\",\"duration\":${DURATION}}"

echo
echo "==> POST ${BASE_URL}/show"
perform_request \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -X POST \
    -d "$SHOW_BODY" \
    "${BASE_URL}/show"
echo "HTTP ${LAST_STATUS}"
printf '%s\n' "$LAST_BODY"
[[ "$LAST_STATUS" == "200" ]] || die "show request failed"

echo
echo "Slideshow upload succeeded for gallery: ${SAFE_GALLERY}"
