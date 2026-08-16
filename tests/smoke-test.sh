#!/usr/bin/env bash

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/proxmox-health-check.sh"
FAILURES=0
FIXTURE_OUTPUT="$(mktemp)"
trap 'rm -f "$FIXTURE_OUTPUT"' EXIT

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  (( FAILURES += 1 ))
}

if bash -n "$SCRIPT"; then
  pass "Bash syntax"
else
  fail "Bash syntax"
fi

if "$SCRIPT" --help | grep -q "Read-only health summary"; then
  pass "Help output"
else
  fail "Help output"
fi

if [[ "$("$SCRIPT" --version)" == "HORCRUX Proxmox Health Check 1.0.1" ]]; then
  pass "Version output"
else
  fail "Version output"
fi

set +e
"$SCRIPT" --root-warn 95 --root-crit 90 >/dev/null 2>&1
invalid_status=$?
set -e
if (( invalid_status == 64 )); then
  pass "Invalid threshold rejection"
else
  fail "Invalid threshold rejection (received exit $invalid_status)"
fi

if grep -Eq '\b(rm|reboot|shutdown|poweroff|apt(-get)?[[:space:]]+(remove|purge|upgrade|dist-upgrade)|qm[[:space:]]+(stop|destroy)|pct[[:space:]]+(stop|destroy))\b' "$SCRIPT"; then
  fail "Read-only command policy"
else
  pass "Read-only command policy"
fi

set +e
PATH="$REPO_ROOT/tests/mock-bin:$PATH" \
  "$SCRIPT" --no-color --mount /mnt/media >"$FIXTURE_OUTPUT" 2>&1
fixture_status=$?
set -e
if (( fixture_status == 0 )) && grep -q "Proxmox VE" "$FIXTURE_OUTPUT" && grep -q "1/2 running" "$FIXTURE_OUTPUT"; then
  pass "Simulated Proxmox host"
else
  fail "Simulated Proxmox host (received exit $fixture_status)"
  sed -n '1,160p' "$FIXTURE_OUTPUT" >&2
fi

if (( FAILURES > 0 )); then
  printf '\n%d smoke test(s) failed.\n' "$FAILURES" >&2
  exit 1
fi

printf '\nAll smoke tests passed.\n'
