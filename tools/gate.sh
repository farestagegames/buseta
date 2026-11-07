#!/bin/sh
# The quality gate: every test passes, the Android export works and the APK stays
# under the size limit. Prints one line and exits non-zero on any failure.
cd "$(dirname "$0")/.." || exit 1
LIMIT=$((150 * 1024 * 1024))
RESULTS=$(TEST_TIMEOUT="${TEST_TIMEOUT:-280}" sh tools/test.sh 2>&1)
PASSED=$(printf '%s\n' "$RESULTS" | grep "Passing Tests" | tail -1 | awk '{print $NF}')
FAILED=$(printf '%s\n' "$RESULTS" | grep "Failing Tests" | tail -1 | awk '{print $NF}')
if [ -z "$PASSED" ] || [ -n "$FAILED" ]; then
	printf '%s\n' "$RESULTS" | grep -E "\[Failed\]|SCRIPT ERROR|Parse Error" | cut -c1-220 | sort -u | head -20
	echo "GATE FAILED: tests (${PASSED:-0} passed, ${FAILED:-unknown} failed)"
	exit 1
fi
rm -f build/city-bus-shift-debug.apk
sh tools/build_apk.sh >/dev/null 2>&1
if [ ! -f build/city-bus-shift-debug.apk ]; then
	echo "GATE FAILED: Android export produced no APK"
	exit 1
fi
SIZE=$(wc -c < build/city-bus-shift-debug.apk | tr -d ' ')
if [ "$SIZE" -ge "$LIMIT" ]; then
	echo "GATE FAILED: APK is $SIZE bytes"
	exit 1
fi
echo "GATE PASSED: $PASSED tests, APK $((SIZE / 1024 / 1024)) MB"
