# iOS port

The game is ready to be exported to iOS, but it has never been built for or run
on an iPhone. This page lists what is already done, what is left, and the exact
steps to build, sign and test it.

## Already done

- **No Android-only code.** Game code never calls Java, Android singletons or
  Android permissions. A test (`test_game_code_has_no_android_only_calls`)
  keeps it that way. Phone-only behaviour checks the general `mobile` feature,
  which is true on iOS too.
- **Notches and the home indicator.** The menu and the driving controls stay
  inside the screen's safe area, padded equally on both sides because the game
  turns with the phone (`UiStyle.screen_insets`). A test covers an iPhone-shaped
  notch and the home indicator.
- **Touch.** All controls are multi-touch zones or lists that work from touches
  turned into mouse events, the same on both systems. Tilt steering uses
  Godot's gravity and accelerometer, which iOS provides.
- **Pausing.** The shift pauses when the app goes to the background
  (`NOTIFICATION_APPLICATION_PAUSED`), and progress is saved then. The Android
  back button has no iOS equivalent; the on-screen MENU button does the same job.
- **Graphics.** The Compatibility renderer runs on iOS through OpenGL ES on
  Metal. Textures are already imported with ETC2/ASTC compression, which iOS
  supports.
- **Ads.** Rewarded ads sit behind `AdProvider` with no SDK, so there is nothing
  to port. If an ad SDK is added later, it needs an iOS plugin of its own.
- **Export preset.** `export_presets.cfg` has an `iOS` preset with the same
  content filters as Android, bundle id `com.citybusshift.game`, iPhone and iPad,
  arm64, iOS 14 minimum, and "export project only" on, so Godot writes an Xcode
  project for you to sign. A test checks the preset stays in step with Android.

## What is left

1. **A Mac with Xcode** (16 or later) and an **Apple Developer account**
   (paid, needed to install on a device for more than a few days and for the
   App Store). Neither can be set up from here, and no account details are in
   the repository.
2. **iOS export templates** for Godot 4.7.2. In the editor: Editor > Manage
   Export Templates > Download and Install. The Android build uses the same
   templates package.
3. **Team id and bundle id.** In Project > Export > iOS, set
   `application/app_store_team_id` to your team id (Apple Developer website,
   Membership). Change `application/bundle_identifier` if you want another id;
   it must be unique on the App Store.
4. **App icons.** iOS needs at least the 1024x1024 App Store icon. Neither
   preset has icons yet (the Android one also uses the default). Make one
   original icon, then fill the `icons/*` fields in the iOS preset.
5. **Launch screen.** The preset uses Godot's storyboard launch screen with the
   game's dark background colour. Add a splash image if wanted.
6. **Privacy and export compliance.** The game collects no data, uses no
   network and no encryption beyond the system's. In App Store Connect answer
   "no data collected", and set "uses non-exempt encryption" to No (or add
   `ITSAppUsesNonExemptEncryption = NO` to the Info.plist in Xcode). Check that
   Godot's generated privacy manifest (`PrivacyInfo.xcprivacy`) lists the
   file-timestamp and user-defaults reasons Apple asks engines to declare;
   Godot fills these in its iOS export options under `privacy/`.
7. **Audio session.** Godot's default iOS session is "Ambient": the game's
   sounds follow the silent switch and mix with music from other apps. If you
   would rather the radio play with the switch on silent, change
   `audio/general/ios/session_category` in Project Settings to "Playback".
8. **Testing on devices** (see below).

## Build and sign

1. Open the project in Godot 4.7.2 on a Mac.
2. Project > Export > iOS. Fill in the team id. Leave "Export Project Only" on.
3. Export to `build/ios/`. Godot writes `CityBusShift.xcodeproj` and its files.
4. Open the Xcode project. Under Signing & Capabilities pick your team and let
   Xcode manage signing.
5. Plug in an iPhone, pick it as the run target and press Run. The first time,
   trust the developer profile on the phone (Settings > General > VPN & Device
   Management).
6. For TestFlight or the App Store: Product > Archive, then Distribute App >
   App Store Connect.

From the command line, once templates and the team id are set:

```bash
.tools/Godot.app/Contents/MacOS/Godot --headless --export-debug iOS build/ios/CityBusShift.ipa
```

## Check on a device

- Frame rate: aim for a steady 60 fps on an iPhone XR or newer (A12). Turn on
  Settings > Show performance in the game. Try High and Low quality, by day,
  at night and in a downpour.
- Safe area: the notch or Dynamic Island must never cover the wheel, pedals,
  VISTA/MENÚ/RADIO or the minimap, with the phone turned either way. The home
  indicator must not sit on the pedals.
- Touch: hold GO and steer at the same time; drag menu lists starting on a
  button; tap buttons in lists.
- Tilt steering: check the direction with the phone turned each way, and the
  Invert tilt setting.
- Pausing: lock the phone and swipe to another app mid-shift; the shift must be
  paused and nothing lost when you come back.
- Sound: horn, street sounds, rain and the radio, with the silent switch on and
  off.
- iPad: the layout uses the same landscape view, wider. Check the menus fit.

## Not planned

- iCloud saves, Game Center and in-app purchases are not part of this port.
  Saves stay on the device, as on Android.
