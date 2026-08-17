#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/serve-sim-safe-test.XXXXXX")"
runner_pid=""

cleanup() {
  if [[ -n "$runner_pid" ]] && kill -0 "$runner_pid" 2>/dev/null; then
    kill "$runner_pid" 2>/dev/null || true
    wait "$runner_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$tmp_dir/bin"

cat >"$tmp_dir/bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$tmp_dir/bin/npx" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"--list -q"* ]]; then
  printf '{"running":false}\n'
  exit 0
fi

if [[ "$*" == *"serve-sim@broken"* ]]; then
  echo 'error encoding frame: encodingFailed'
  sleep 30
fi

if [[ "$*" == *"serve-sim@unknown"* ]]; then
  echo 'unrelated startup failure' >&2
  exit 7
fi

echo 'mock preview ready'
sleep 30
EOF

chmod +x "$tmp_dir/bin/curl" "$tmp_dir/bin/npx"

wait_for_pattern() {
  local pattern="$1"
  local file="$2"
  local attempt
  for attempt in {1..120}; do
    if grep -q "$pattern" "$file" 2>/dev/null; then
      return 0
    fi
    sleep 0.1
  done
  echo "Timed out waiting for '$pattern'." >&2
  cat "$file" >&2 || true
  return 1
}

fallback_log="$tmp_dir/fallback-test.log"
PATH="$tmp_dir/bin:$PATH" "$repo_root/scripts/serve-sim-safe.sh" \
  --probe-seconds 2 --latest-version broken --fallback-version good \
  test-device >"$fallback_log" 2>&1 &
runner_pid=$!
wait_for_pattern 'Using runtime-proven serve-sim@good' "$fallback_log"
kill "$runner_pid"
wait "$runner_pid" 2>/dev/null || true
runner_pid=""

healthy_log="$tmp_dir/healthy-test.log"
PATH="$tmp_dir/bin:$PATH" "$repo_root/scripts/serve-sim-safe.sh" \
  --probe-seconds 2 --latest-version healthy test-device \
  >"$healthy_log" 2>&1 &
runner_pid=$!
wait_for_pattern 'passed the 2s startup probe' "$healthy_log"
if grep -q 'Using runtime-proven' "$healthy_log"; then
  echo "A healthy latest version was incorrectly downgraded." >&2
  exit 1
fi
kill "$runner_pid"
wait "$runner_pid" 2>/dev/null || true
runner_pid=""

unknown_log="$tmp_dir/unknown-test.log"
set +e
PATH="$tmp_dir/bin:$PATH" "$repo_root/scripts/serve-sim-safe.sh" \
  --probe-seconds 2 --latest-version unknown test-device \
  >"$unknown_log" 2>&1
unknown_status=$?
set -e
if [[ "$unknown_status" -eq 0 ]] || grep -q 'Using runtime-proven' "$unknown_log"; then
  echo "An unrelated failure was incorrectly downgraded." >&2
  cat "$unknown_log" >&2
  exit 1
fi

existing_log="$tmp_dir/existing-test.log"
cat >"$tmp_dir/bin/npx" <<'EOF'
#!/usr/bin/env bash
printf '{"running":true,"device":"owned-device"}\n'
EOF
chmod +x "$tmp_dir/bin/npx"
set +e
PATH="$tmp_dir/bin:$PATH" "$repo_root/scripts/serve-sim-safe.sh" \
  test-device >"$existing_log" 2>&1
existing_status=$?
set -e
if [[ "$existing_status" -ne 75 ]]; then
  echo "An existing helper was not preserved." >&2
  cat "$existing_log" >&2
  exit 1
fi

echo "serve-sim-safe tests passed"
