#!/usr/bin/env bash
set -euo pipefail

readonly DEFAULT_FALLBACK_VERSION="0.1.39"
readonly ENCODER_FAILURE_PATTERN='encodingFailed|error encoding frame'

preview_port="3200"
probe_seconds="8"
latest_version="latest"
fallback_version="$DEFAULT_FALLBACK_VERSION"
device=""

usage() {
  cat <<'EOF'
Usage: scripts/serve-sim-safe.sh [options] <simulator-udid-or-name>

Starts the latest serve-sim browser preview, monitors its encoder logs, and
falls back to the last runtime-proven version only for the known failure.

Options:
  -p, --port PORT              Preview port (default: 3200)
      --probe-seconds SECONDS  Latest-version observation window (default: 8)
      --latest-version VALUE   Version to probe first (default: latest)
      --fallback-version VALUE Known-good fallback (default: 0.1.39)
  -h, --help                   Show this help
EOF
}

while (($#)); do
  case "$1" in
    -p|--port)
      preview_port="${2:?missing port}"
      shift 2
      ;;
    --probe-seconds)
      probe_seconds="${2:?missing probe duration}"
      shift 2
      ;;
    --latest-version)
      latest_version="${2:?missing latest version}"
      shift 2
      ;;
    --fallback-version)
      fallback_version="${2:?missing fallback version}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      device="${1:-}"
      shift || true
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
    *)
      if [[ -n "$device" ]]; then
        echo "Only one Simulator target is supported." >&2
        exit 64
      fi
      device="$1"
      shift
      ;;
  esac
done

if [[ -z "$device" ]]; then
  echo "A Simulator UDID or device name is required." >&2
  usage >&2
  exit 64
fi

if ! [[ "$preview_port" =~ ^[0-9]+$ ]] || ((preview_port < 1 || preview_port > 65535)); then
  echo "Invalid preview port: $preview_port" >&2
  exit 64
fi

if ! [[ "$probe_seconds" =~ ^[0-9]+$ ]] || ((probe_seconds < 2)); then
  echo "Probe duration must be an integer of at least 2 seconds." >&2
  exit 64
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/serve-sim-safe.XXXXXX")"
active_pid=""
tail_pid=""

terminate_active() {
  if [[ -n "$tail_pid" ]] && kill -0 "$tail_pid" 2>/dev/null; then
    kill "$tail_pid" 2>/dev/null || true
    wait "$tail_pid" 2>/dev/null || true
  fi
  tail_pid=""

  if [[ -n "$active_pid" ]] && kill -0 "$active_pid" 2>/dev/null; then
    pkill -TERM -P "$active_pid" 2>/dev/null || true
    kill "$active_pid" 2>/dev/null || true
    wait "$active_pid" 2>/dev/null || true
  fi
  active_pid=""
}

cleanup() {
  terminate_active
  rm -rf "$tmp_dir"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

existing_inventory="$(npx --yes "serve-sim@${latest_version}" --list -q 2>/dev/null || true)"
if grep -Eq '"running"[[:space:]]*:[[:space:]]*true' <<<"$existing_inventory"; then
  echo "An existing serve-sim helper is already running; refusing to replace a user-owned stream." >&2
  echo "$existing_inventory" >&2
  exit 75
fi

start_version() {
  local version="$1"
  local log_file="$2"

  echo "Starting serve-sim@${version} for ${device} on http://127.0.0.1:${preview_port}"
  npx --yes "serve-sim@${version}" -p "$preview_port" "$device" >"$log_file" 2>&1 &
  active_pid=$!
}

probe_latest() {
  local log_file="$1"
  local preview_ready="false"
  local second

  for ((second = 1; second <= probe_seconds; second++)); do
    sleep 1

    if grep -Eiq "$ENCODER_FAILURE_PATTERN" "$log_file"; then
      return 20
    fi

    if ! kill -0 "$active_pid" 2>/dev/null; then
      wait "$active_pid" || true
      return 21
    fi

    if curl --max-time 2 --fail --silent --output /dev/null \
      "http://127.0.0.1:${preview_port}/"; then
      preview_ready="true"
    fi
  done

  [[ "$preview_ready" == "true" ]]
}

monitor_active() {
  local log_file="$1"
  cat "$log_file"
  tail -n 0 -f "$log_file" &
  tail_pid=$!

  while kill -0 "$active_pid" 2>/dev/null; do
    if grep -Eiq "$ENCODER_FAILURE_PATTERN" "$log_file"; then
      return 20
    fi
    sleep 1
  done

  wait "$active_pid"
}

run_fallback() {
  local fallback_log="$tmp_dir/fallback.log"
  local ready="false"
  local attempt

  terminate_active
  start_version "$fallback_version" "$fallback_log"

  for attempt in {1..15}; do
    sleep 1
    if grep -Eiq "$ENCODER_FAILURE_PATTERN" "$fallback_log" || \
      ! kill -0 "$active_pid" 2>/dev/null; then
      break
    fi
    if curl --max-time 2 --fail --silent --output /dev/null \
      "http://127.0.0.1:${preview_port}/"; then
      ready="true"
      break
    fi
  done

  if [[ "$ready" != "true" ]]; then
    cat "$fallback_log" >&2
    echo "The runtime-proven fallback did not become ready." >&2
    return 1
  fi
  echo "Using runtime-proven serve-sim@${fallback_version}."
  monitor_active "$fallback_log"
}

latest_log="$tmp_dir/latest.log"
start_version "$latest_version" "$latest_log"

set +e
probe_latest "$latest_log"
probe_status=$?
set -e

case "$probe_status" in
  0)
    echo "serve-sim@${latest_version} passed the ${probe_seconds}s startup probe; browser-visible frame verification is still required."
    set +e
    monitor_active "$latest_log"
    monitor_status=$?
    set -e
    if [[ "$monitor_status" -ne 20 ]]; then
      exit "$monitor_status"
    fi
    echo "Detected the known serve-sim encoder failure after startup; falling back to ${fallback_version}." >&2
    run_fallback
    ;;
  20)
    echo "Detected the known serve-sim encoder failure; falling back to ${fallback_version}." >&2
    cat "$latest_log" >&2
    run_fallback
    ;;
  *)
    cat "$latest_log" >&2
    echo "Latest serve-sim failed for an unknown reason; refusing to mask it with a fallback." >&2
    exit 1
    ;;
esac
