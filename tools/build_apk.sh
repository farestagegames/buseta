#!/bin/sh
# Builds a debug APK using the toolchain in .tools. Creates a debug keystore on
# first use. The keystore holds Android's standard public debug password.
cd "$(dirname "$0")/.." || exit 1
KEYSTORE="$PWD/.tools/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
	"$PWD/.tools/jdk/Contents/Home/bin/keytool" -genkeypair -v -keystore "$KEYSTORE" -alias androiddebugkey \
		-storepass android -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
		-dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
. tools/android_env.sh
exec "$GODOT" --headless --export-debug Android "$PWD/build/city-bus-shift-debug.apk"
