#!/bin/sh
# Runs every GUT test headless and fails the run if it hangs.
# Uses GODOT if set, then the local .tools copy, then godot on PATH.
cd "$(dirname "$0")/.." || exit 1
LOCAL="$PWD/.tools/Godot.app/Contents/MacOS/Godot"
if [ -z "$GODOT" ]; then
	if [ -x "$LOCAL" ]; then GODOT="$LOCAL"; else GODOT=godot; fi
fi
LIMIT="${TEST_TIMEOUT:-300}"
"$GODOT" --headless --import >/dev/null 2>&1
"$GODOT" --headless -d -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json &
PID=$!
( sleep "$LIMIT"; kill "$PID" 2>/dev/null ) &
GUARD=$!
wait "$PID"; CODE=$?
kill "$GUARD" 2>/dev/null
exit $CODE
