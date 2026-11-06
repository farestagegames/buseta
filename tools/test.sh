#!/bin/sh
# Runs every GUT test headless and fails the run if it hangs.
# Set GODOT to the Godot binary if it is not on PATH.
GODOT="${GODOT:-godot}"
LIMIT="${TEST_TIMEOUT:-90}"
cd "$(dirname "$0")/.." || exit 1
"$GODOT" --headless --import >/dev/null 2>&1
"$GODOT" --headless -d -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json &
PID=$!
( sleep "$LIMIT"; kill "$PID" 2>/dev/null ) &
GUARD=$!
wait "$PID"; CODE=$?
kill "$GUARD" 2>/dev/null
exit $CODE
