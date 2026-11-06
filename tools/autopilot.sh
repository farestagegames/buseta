#!/bin/sh
# Drives a full shift headless at high speed and prints a report.
cd "$(dirname "$0")/.." || exit 1
LOCAL="$PWD/.tools/Godot.app/Contents/MacOS/Godot"
if [ -z "$GODOT" ]; then
	if [ -x "$LOCAL" ]; then GODOT="$LOCAL"; else GODOT=godot; fi
fi
"$GODOT" --headless --import >/dev/null 2>&1
"$GODOT" --headless res://tools/autopilot.tscn &
PID=$!
( sleep "${AUTOPILOT_TIMEOUT:-200}"; kill "$PID" 2>/dev/null ) &
GUARD=$!
wait "$PID"; CODE=$?
kill "$GUARD" 2>/dev/null
exit $CODE
