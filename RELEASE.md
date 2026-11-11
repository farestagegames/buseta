# Google Play release

Package id: `com.citybusshift.game`. It can never change after the first upload.

## The upload key

- Keystore: `~/Keys/city-bus-shift-upload.jks` (PKCS12, alias `upload`, RSA 4096,
  valid about 27 years). It lives outside the repository on purpose.
- Upload certificate SHA-256 (public, for matching in Play Console):
  `6A:3A:78:EB:F1:85:54:A7:B8:E9:C3:AA:82:0A:BE:0D:A2:27:82:92:9F:0D:AA:C7:44:53:E8:33:D6:BF:47:C2`
- Password: chosen by you, one password for both the keystore and the key (PKCS12 and
  Godot both need them to match). It is in your password manager and, if you said yes
  when creating the key, in the macOS login Keychain as `city-bus-shift-upload`.
- Nothing secret is in git: `*.jks`, `*.keystore`, `*.p12`, `*.pepk`, `.env*`,
  `export_credentials.cfg` and `release_credentials*` are ignored, and
  `export_presets.cfg` holds no keystore path or password.

To create it again on a new machine (only if the old one is truly gone, see below):

```bash
sh tools/make_upload_key.sh
```

### Back it up now

With Play App Signing, Google holds the key that signs what players install. Yours is
only the *upload* key. Losing it does not lose the app, but you cannot publish an
update until Google's support resets the upload key, which takes days and needs a new
key and certificate from you. Leaking it lets someone else upload as you until it is
reset. So:

1. Copy `~/Keys/city-bus-shift-upload.jks` to at least two places that are not this
   Mac: an encrypted USB stick and an encrypted cloud store (e.g. an encrypted disk
   image in iCloud Drive, or your password manager's file attachment).
2. Keep the password in the password manager, never next to the file in plain text.
3. Check a backup once: copy it back to a temp folder and run
   `.tools/jdk/Contents/Home/bin/keytool -list -keystore <copy>` (asks for the password).

If the key is ever lost or leaked: Play Console, Test and release, App integrity,
App signing, "Request upload key reset", then follow its steps with a new keystore.

## Building

```bash
sh tools/build_release.sh
```

It builds `build/city-bus-shift-release.aab` with the Gradle build template (installed
into `android/` on the first run, which is git-ignored and regenerated when missing),
signs it with the upload key, checks it is under 150 MB and that the signature
verifies. The password comes from `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` if set,
else the Keychain, else a hidden prompt. The first build downloads Gradle and its
dependencies, so it needs internet and takes a few minutes. The log is
`build/release.log`, with the password masked.

Other keystore locations: set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` and
`GODOT_ANDROID_KEYSTORE_RELEASE_USER` (alias).

To check a build is signed with the upload key, compare its certificate fingerprint
with the keystore's:

```bash
.tools/jdk/Contents/Home/bin/keytool -printcert -jarfile build/city-bus-shift-release.aab
```

The debug APK is unchanged: `sh tools/build_apk.sh`, and `sh tools/gate.sh` still
gates every commit. The release export leaves out the hidden cheat rows, as every
release export does.

## Bumping the version

In `export_presets.cfg`, preset `[preset.2.options]` ("Android Release"):

- `version/code`: a whole number that must go up by at least 1 for every upload to
  Play, on any track. Play rejects a code it has seen before, even from a deleted
  release.
- `version/name`: what players see, e.g. `0.1.0` then `0.1.1` or `0.2.0`.

Bump the debug preset (`[preset.0.options]`) the same way if you want them to match,
and the iOS preset's `application/version` and `application/short_version` when that
ships.

## Next steps in Play Console (by hand)

1. Create the app: name, default language (Spanish, Latin America `es-419`), game,
   free. Declarations: no ads.
2. Play App Signing: on the first upload, accept "Let Google manage and protect your
   app signing key". Your keystore becomes the upload key.
3. Testing. New personal developer accounts must run a closed test with at least 12
   testers opted in for 14 days in a row before they can apply for production.
   Start with Internal testing (up to 100 testers, available in minutes) to check the
   AAB installs, then a Closed testing track for the 12-tester rule.
4. Store listing: short and full description (Spanish and English), 512×512 icon
   (`store/icon_512.png`), 1024×500 feature graphic, at least 2 phone screenshots
   (`tools/screens/` has gameplay shots to start from). The launcher icons come from
   `python3 tools/make_icons.py`; rerun it after changing the drawing.
5. Content rating: fill in the IARC questionnaire (driving, minor collisions with
   no injuries, no gambling, no user chat).
6. Target audience and content: pick the age groups; choosing under 13 brings the
   Families policy into play.
7. Data safety: the game collects and shares no data, has no ads or analytics SDKs
   and asks for no internet permission. Saves stay on the phone.
8. Privacy policy: https://callenomad.github.io/city-bus-shift-privacy/ (GitHub Pages, repository `callenomad/city-bus-shift-privacy`,
   source `store/privacy/index.html`; re-upload it there after any change).
9. App access (no login needed), Ads (none), Government app (no), Financial
   features (none), Health (none).
10. Countries: Colombia first, more later.
