#!/bin/sh
# Builds the signed release AAB for Google Play into build/, using the Gradle
# build template and the upload key. The key's password comes from
# GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD, else the macOS Keychain item
# "city-bus-shift-upload", else a silent prompt. It is never written to disk.
cd "$(dirname "$0")/.." || exit 1
LIMIT=$((150 * 1024 * 1024))
OUT="$PWD/build/city-bus-shift-release.aab"
if grep -qE 'testing/cheats_in_release[[:space:]]*=[[:space:]]*true' project.godot; then
	echo "WARNING: buseta/testing/cheats_in_release is ON, so this release ships the hidden"
	echo "         cheats to testers. Set it to false in project.godot before a public release."
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$HOME/Keys/city-bus-shift-upload.jks}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-upload}"
if [ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]; then
	echo "RELEASE FAILED: no keystore at $GODOT_ANDROID_KEYSTORE_RELEASE_PATH (run tools/make_upload_key.sh)"
	exit 1
fi
if [ -z "$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" ]; then
	GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$(security find-generic-password -a "$USER" -s city-bus-shift-upload -w 2>/dev/null)
fi
if [ -z "$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" ]; then
	printf 'Upload keystore password: '
	stty -echo; read -r GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; stty echo; echo
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
. tools/android_env.sh
if [ ! -f android/build/build.gradle ]; then
	INSTALL="--install-android-build-template"
fi
rm -f "$OUT"
LOG="$PWD/build/release.log"
# The awk filter masks the password in case Godot or Gradle echo their command line.
"$GODOT" --headless $INSTALL --export-release "Android Release" "$OUT" 2>&1 \
	| awk 'BEGIN { p = ENVIRON["GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"] } { if (p != "") { while ((i = index($0, p)) > 0) $0 = substr($0, 1, i - 1) "****" substr($0, i + length(p)) } print }' > "$LOG"
unset GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
if [ ! -f "$OUT" ]; then
	grep -i -E "error|failed" "$LOG" | tail -20
	echo "RELEASE FAILED: no AAB (full log in build/release.log)"
	exit 1
fi
SIZE=$(wc -c < "$OUT" | tr -d ' ')
if [ "$SIZE" -ge "$LIMIT" ]; then
	echo "RELEASE FAILED: AAB is $SIZE bytes"
	exit 1
fi
if ! "$JAVA_HOME/bin/jarsigner" -verify "$OUT" >/dev/null 2>&1; then
	echo "RELEASE FAILED: AAB signature does not verify"
	exit 1
fi
echo "RELEASE BUILT: build/city-bus-shift-release.aab, $((SIZE / 1024 / 1024)) MB, signed"
