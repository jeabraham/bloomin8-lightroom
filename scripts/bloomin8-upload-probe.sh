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
  --host HOST          Device host or base URL (example: 192.168.1.25 or http://192.168.1.25)
  --image PATH         Local JPEG file to upload
  --gallery NAME       Destination gallery (default: default)
  --filename NAME      Remote filename override
  --show-now           Ask the frame to display the uploaded image immediately
  --probe-only         Stop after GET /deviceInfo
  --connect-timeout N  Curl connect timeout in seconds (default: 5)
  --max-time N         Curl total timeout in seconds (default: 60)
  --help               Show this message
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

require_command curl

HOST=""
IMAGE_PATH=""
GALLERY="default"
REMOTE_FILENAME=""
SHOW_NOW=0
PROBE_ONLY=0
CONNECT_TIMEOUT=5
MAX_TIME=60

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
        --connect-timeout)
            CONNECT_TIMEOUT="${2:-}"
            shift 2
            ;;
        --max-time)
            MAX_TIME="${2:-}"
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

    case "${IMAGE_PATH,,}" in
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

UPLOAD_URL="${BASE_URL}/upload?filename=${SAFE_FILENAME}&gallery=${SAFE_GALLERY}&show_now=${SHOW_NOW}"

echo
echo "==> POST ${UPLOAD_URL}"
perform_request \
    -H 'Accept: application/json' \
    -X POST \
    -F "image=@${IMAGE_PATH};type=image/jpeg" \
    "$UPLOAD_URL"

echo "HTTP ${LAST_STATUS}"
printf '%s\n' "$LAST_BODY"

[[ "$LAST_STATUS" == "200" ]] || die "upload request failed"
grep -Eq '"status"[[:space:]]*:[[:space:]]*100' <<<"$LAST_BODY" || die "upload did not return firmware success status 100"

echo
echo "Upload probe succeeded."
