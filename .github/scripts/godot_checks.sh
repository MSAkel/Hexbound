#!/usr/bin/env bash
# Headless health checks for Flavour Pass. Used by CI and runnable locally:
#   GODOT=/path/to/godot .github/scripts/godot_checks.sh
# Fails if the project doesn't import or boot cleanly, or if a playtest/fuzz case fails.
set -uo pipefail

GODOT="${GODOT:-godot}"
RUNS="${PLAYTEST_RUNS:-1}"
FUZZ_RUNS="${FUZZ_RUNS:-20}"
LOG_DIR="${LOG_DIR:-ci-logs}"
mkdir -p "$LOG_DIR"
LOG_ABS="$(cd "$LOG_DIR" && pwd)"
failed=0

# Lines that mean something is broken. Godot often exits 0 even when scripts fail to compile.
ERROR_PATTERN='SCRIPT ERROR|Parse Error|Compile Error|ERROR:'

step() { echo; echo "::group::$1"; }
endstep() { echo "::endgroup::"; }

check_log() {  # $1 = step name, $2 = log file
  if grep -qE "$ERROR_PATTERN" "$2"; then
    echo "::error title=$1::Errors in $1 output"
    grep -E "$ERROR_PATTERN" "$2" | sort | uniq -c | sort -rn | head -40
    failed=1
  else
    echo "$1: clean"
  fi
}

step "Import (first pass, builds .godot cache)"
# The first import on a fresh checkout logs load-order errors for the theme and font
# before their textures exist, so its output isn't checked.
timeout 600 "$GODOT" --headless --path . --import > "$LOG_DIR/import-1.log" 2>&1
endstep

step "Import (second pass)"
timeout 600 "$GODOT" --headless --path . --import > "$LOG_DIR/import-2.log" 2>&1
check_log "Import" "$LOG_DIR/import-2.log"
endstep

step "Boot main scene for 600 frames"
timeout 120 "$GODOT" --headless --path . --quit-after 600 > "$LOG_DIR/boot.log" 2>&1
code=$?
cat "$LOG_DIR/boot.log"
[ $code -ne 0 ] && { echo "::error title=Boot::Godot exited with $code"; failed=1; }
check_log "Boot" "$LOG_DIR/boot.log"
endstep

run_playtest() {  # $1 = name, rest = runner flags
  local name="$1"; shift
  step "Playtest: $name"
  timeout 1800 "$GODOT" --headless --path . res://scenes/debug/playtest_runner.tscn -- \
    --out="$LOG_ABS/report-$name.json" "$@" > "$LOG_DIR/playtest-$name.log" 2>&1
  local code=$?
  grep -E '^\[playtest\]' "$LOG_DIR/playtest-$name.log"
  if [ $code -ne 0 ]; then
    echo "::error title=Playtest $name::Runner exited with $code (failed cases or crash)"
    grep -E 'FAIL|SCRIPT ERROR|ERROR:' "$LOG_DIR/playtest-$name.log" | head -40
    failed=1
  fi
  endstep
}

run_playtest bot --runs="$RUNS"
run_playtest fuzz --fuzz --runs="$FUZZ_RUNS"

echo
if [ $failed -ne 0 ]; then echo "Checks FAILED"; else echo "All checks passed"; fi
exit $failed
