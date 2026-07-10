#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
FIRMWARE_UPLOAD_SUCCESS=100
RETRY_COUNT=2
RETRY_DELAY=1

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
  --debug                            Enable verbose request diagnostics
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

debug_log() {
    if [[ "$DEBUG" -eq 1 ]]; then
        echo "[debug] $*" >&2
    fi
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
    local response curl_exit=0
    local curl_args=(
        -sS
        --connect-timeout "$CONNECT_TIMEOUT"
        --max-time "$MAX_TIME"
        -w $'\nHTTP_STATUS:%{http_code}\n'
    )

    if [[ "$DEBUG" -eq 1 ]]; then
        curl_args+=(--verbose)
    fi
    debug_log "curl $(printf '%q ' "${curl_args[@]}" "$@")"

    if ! response="$(curl "${curl_args[@]}" "$@" 2>&1)"; then
        curl_exit=$?
    fi

    LAST_CURL_EXIT="$curl_exit"
    LAST_STATUS="$(printf '%s\n' "$response" | sed -n 's/^HTTP_STATUS://p' | tail -n 1)"
    LAST_BODY="$(printf '%s\n' "$response" | sed '$d')"

    if [[ -z "$LAST_STATUS" ]]; then
        LAST_STATUS="000"
    fi

    debug_log "curl_exit=${LAST_CURL_EXIT} http=${LAST_STATUS}"
}

should_retry_request() {
    if [[ "$LAST_CURL_EXIT" -ne 0 ]]; then
        return 0
    fi

    case "$LAST_STATUS" in
        000|408|425|429|500|502|503|504)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

perform_request_with_retry() {
    local action="$1"
    shift

    local attempt=1
    local max_attempts=$(( RETRY_COUNT + 1 ))

    while true; do
        perform_request "$@"

        if [[ "$LAST_CURL_EXIT" -eq 0 && "$LAST_STATUS" == "200" ]]; then
            return 0
        fi

        if [[ "$attempt" -ge "$max_attempts" ]] || ! should_retry_request; then
            return 0
        fi

        echo "Warning: ${action} attempt ${attempt}/${max_attempts} failed (curl=${LAST_CURL_EXIT}, http=${LAST_STATUS}); retrying in ${RETRY_DELAY}s..." >&2
        attempt=$(( attempt + 1 ))
        sleep "$RETRY_DELAY"
    done
}

upload_response_succeeded() {
    if command -v jq >/dev/null 2>&1; then
        [[ "$(printf '%s' "$LAST_BODY" | jq -r '.status // empty' 2>/dev/null)" == "${FIRMWARE_UPLOAD_SUCCESS}" ]]
    else
        grep -Eq "\"status\"[[:space:]]*:[[:space:]]*${FIRMWARE_UPLOAD_SUCCESS}" <<<"$LAST_BODY"
    fi
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
DEBUG=0

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
        --debug)
            DEBUG=1
            shift
            ;;
        --random)
            RANDOM_ORDER=1
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
collect_images

if [[ "$RANDOM_ORDER" -eq 1 ]]; then
    shuffle_images
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
perform_request_with_retry "deviceInfo request" \
    -H 'Accept: application/json' \
    "${BASE_URL}/deviceInfo"
echo "HTTP ${LAST_STATUS}"
printf '%s\n' "$LAST_BODY"
[[ "$LAST_CURL_EXIT" -eq 0 && "$LAST_STATUS" == "200" ]] || die "deviceInfo request failed (curl=${LAST_CURL_EXIT}, http=${LAST_STATUS})"

derive_canvas_dimensions

echo
echo "==> DELETE ${BASE_URL}/gallery?name=${SAFE_GALLERY}"
perform_request_with_retry "gallery delete" \
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
perform_request_with_retry "gallery create" \
    -H 'Accept: application/json' \
    -X PUT \
    "${BASE_URL}/gallery?name=${SAFE_GALLERY}"
echo "HTTP ${LAST_STATUS}"
printf '%s\n' "$LAST_BODY"
[[ "$LAST_CURL_EXIT" -eq 0 && "$LAST_STATUS" == "200" ]] || die "gallery creation failed (curl=${LAST_CURL_EXIT}, http=${LAST_STATUS})"

image_index=0
for image_path in "${IMAGE_FILES[@]}"; do
    image_index=$((image_index + 1))
    remote_filename="$(printf '%04d_%s' "$image_index" "$(basename "$image_path")")"
    remote_filename="$(sanitize_component "$remote_filename")"
    prepared_image="$(prepare_image "$image_path" "$(printf '%04d' "$image_index")")"
    [[ -f "$prepared_image" ]] || die "Image preparation failed (ImageMagick error?) for: $image_path"

    echo
    echo "==> Uploading processed file:"
    ls -la "$prepared_image"
    echo "==> POST ${BASE_URL}/image/delete?image=${remote_filename}&gallery=${SAFE_GALLERY}"
    perform_request_with_retry "image delete ${remote_filename}" \
        -H 'Accept: application/json' \
        -X POST \
        "${BASE_URL}/image/delete?image=${remote_filename}&gallery=${SAFE_GALLERY}"
    echo "HTTP ${LAST_STATUS}"
    if [[ "$LAST_CURL_EXIT" -eq 0 && "$LAST_STATUS" == "200" ]]; then
        printf '%s\n' "$LAST_BODY"
    else
        echo "(Image did not already exist on device or delete was not accepted; continuing.)"
    fi

    echo "==> POST ${BASE_URL}/upload?filename=${remote_filename}&gallery=${SAFE_GALLERY}&show_now=0"
    upload_attempt=1
    max_upload_attempts=$(( RETRY_COUNT + 1 ))
    while true; do
        perform_request \
            -H 'Accept: application/json' \
            -X POST \
            -F "image=@${prepared_image};type=image/jpeg" \
            "${BASE_URL}/upload?filename=${remote_filename}&gallery=${SAFE_GALLERY}&show_now=0"
        echo "HTTP ${LAST_STATUS}"
        printf '%s\n' "$LAST_BODY"

        if [[ "$LAST_CURL_EXIT" -eq 0 && "$LAST_STATUS" == "200" ]] && upload_response_succeeded; then
            break
        fi

        if [[ "$upload_attempt" -ge "$max_upload_attempts" ]]; then
            if [[ "$LAST_CURL_EXIT" -ne 0 || "$LAST_STATUS" != "200" ]]; then
                die "upload request failed for: $image_path (curl=${LAST_CURL_EXIT}, http=${LAST_STATUS})"
            fi
            die "upload did not return status ${FIRMWARE_UPLOAD_SUCCESS} for: $image_path (body: ${LAST_BODY})"
        fi

        echo "Warning: upload attempt ${upload_attempt}/${max_upload_attempts} failed for ${remote_filename}; deleting stale device file and retrying in ${RETRY_DELAY}s..." >&2
        upload_attempt=$(( upload_attempt + 1 ))
        perform_request \
            -H 'Accept: application/json' \
            -X POST \
            "${BASE_URL}/image/delete?image=${remote_filename}&gallery=${SAFE_GALLERY}"
        sleep "$RETRY_DELAY"
    done
done

SHOW_BODY="{\"play_type\":1,\"gallery\":\"${SAFE_GALLERY}\",\"duration\":${DURATION}}"

echo
echo "==> POST ${BASE_URL}/show"
perform_request_with_retry "show request" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -X POST \
    -d "$SHOW_BODY" \
    "${BASE_URL}/show"
echo "HTTP ${LAST_STATUS}"
printf '%s\n' "$LAST_BODY"
[[ "$LAST_CURL_EXIT" -eq 0 && "$LAST_STATUS" == "200" ]] || die "show request failed (curl=${LAST_CURL_EXIT}, http=${LAST_STATUS})"

echo
echo "Slideshow upload succeeded for gallery: ${SAFE_GALLERY}"
