# Sourced by build_apk.sh and build_release.sh: points Godot's editor settings at
# the Android SDK and JDK in .tools. Expects to run from the repository root.
ROOT="$PWD/.tools"
GODOT="$ROOT/Godot.app/Contents/MacOS/Godot"
export JAVA_HOME="$ROOT/jdk/Contents/Home"
"$GODOT" --headless --editor --quit >/dev/null 2>&1
SETTINGS=$(ls "$ROOT"/editor_data/editor_settings-*.tres | head -1)
grep -v -E '^export/android/(android_sdk_path|java_sdk_path) ' "$SETTINGS" > "$SETTINGS.new"
printf 'export/android/android_sdk_path = "%s"\nexport/android/java_sdk_path = "%s"\n' "$ROOT/android-sdk" "$JAVA_HOME" >> "$SETTINGS.new"
mv "$SETTINGS.new" "$SETTINGS"
mkdir -p build
