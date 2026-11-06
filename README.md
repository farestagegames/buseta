# City Bus Shift

A low-poly bus driving simulator for Android, built with Godot 4. "City Bus
Shift" is a working title.

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the code is organised and
[CREDITS.md](CREDITS.md) for licences.

## Setup

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/), standard version.
2. Open `project.godot` in Godot.
3. Press F5 to run the test scene on your computer.

Desktop keys:

| Action | Keys |
| --- | --- |
| Drive and steer | WASD or arrow keys |
| Brake | S, Down or Space |
| Drive or reverse | R |
| Doors | F |
| Indicators | Q and E |
| Horn | H |
| Camera view | C |
| Reset bus | Backspace |

The mouse also works on the on-screen controls.

## Tests

```bash
tools/test.sh
```

The script uses `$GODOT` if set, then `.tools/`, then `godot` on your PATH. It
exits non-zero if a test fails or the run hangs.

## Android build

Requirements:

- JDK 17
- Android SDK with platform-tools, build-tools 36.1.0 and platform android-36
- Godot 4.7.2 export templates

Set the SDK and JDK paths in Editor Settings under Export > Android, then use
Project > Export > Android. The preset builds an arm64 APK to `build/`.

This repository's helper builds a debug APK using the local `.tools` folder:

```bash
tools/build_apk.sh
```

## Installing on a phone

Copy `build/city-bus-shift-debug.apk` to the phone and open it, allowing
installs from that source when asked. Or connect with USB debugging on:

```bash
adb install -r build/city-bus-shift-debug.apk
```

Release builds for the Play Store need your own signing key, which must never be
committed.
