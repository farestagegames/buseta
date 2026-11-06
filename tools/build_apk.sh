#!/bin/sh
# Builds a debug APK using the toolchain in .tools. Creates a debug keystore on
# first use. The keystore holds Android's standard public debug password.
cd "$(dirname "$0")/.." || exit 1
ROOT="$PWD/.tools"
GODOT="$ROOT/Godot.app/Contents/MacOS/Godot"
export JAVA_HOME="$ROOT/jdk/Contents/Home"
KEYSTORE="$ROOT/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
	"$JAVA_HOME/bin/keytool" -genkeypair -v -keystore "$KEYSTORE" -alias androiddebugkey \
		-storepass android -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
		-dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
"$GODOT" --headless --editor --quit >/dev/null 2>&1
SETTINGS=$(ls "$ROOT"/editor_data/editor_settings-*.tres | head -1)
grep -v -E '^export/android/(android_sdk_path|java_sdk_path) ' "$SETTINGS" > "$SETTINGS.new"
printf 'export/android/android_sdk_path = "%s"\nexport/android/java_sdk_path = "%s"\n' "$ROOT/android-sdk" "$JAVA_HOME" >> "$SETTINGS.new"
mv "$SETTINGS.new" "$SETTINGS"
mkdir -p build
exec "$GODOT" --headless --export-debug Android "$PWD/build/city-bus-shift-debug.apk"
