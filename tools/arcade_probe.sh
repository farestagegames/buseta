#!/bin/sh
# Drives the arcade course (Carrera Express) headless and prints how many arches
# a decent driver reaches under the current tuning. PROBE_CRUISE sets the cruise
# speed in m/s.
cd "$(dirname "$0")/.." || exit 1
LOCAL="$PWD/.tools/Godot.app/Contents/MacOS/Godot"
if [ -z "$GODOT" ]; then
  if [ -x "$LOCAL" ]; then GODOT="$LOCAL"; else GODOT=godot; fi
fi
"$GODOT" --headless --import >/dev/null 2>&1
"$GODOT" --headless res://tools/arcade_probe.tscn &
PID=$!
( sleep "${PROBE_TIMEOUT:-720}"; kill "$PID" 2>/dev/null ) &
GUARD=$!
wait "$PID"; CODE=$?
kill "$GUARD" 2>/dev/null
exit $CODE
