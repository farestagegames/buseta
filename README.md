# Buseta Simulator: Colombia

A low-poly bus driving simulator for Android, built with Godot 4. "City Bus
Shift" is a working title. Traffic drives on the right.

## Status

- Phase 1, setup, drivable bus, controls and cameras: done.
- Phase 2, city, route, stops, doors and passengers: done, including hills,
  suspension, knockable obstacles and sound.
- Phase 3, schedule, scoring, end of shift report, AI traffic and traffic lights:
  done.
- Phase 4, coins, unlocks, second bus and route, liveries, saves, daily challenge,
  levels, achievements and menus: done.
- Phase 5, UI and audio polish, graphics quality, languages, opening scene and
  tutorial: built. Profiling on a low-end phone is still to do.
- Launch content: four routes, a boarding view from the driver's seat and hidden
  test cheats.
- After Phase 5: an arcade bonus level with boosts, kept separate from shifts.

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the code is organised and
[CREDITS.md](CREDITS.md) for licences.

## Setup

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/), standard version.
2. Open `project.godot` in Godot.
3. Press F5 to run a shift on your computer. The flat proving ground is
   `scenes/test/test_drive.tscn`.

Desktop keys:

| Action | Keys |
| --- | --- |
| Drive and steer | WASD or arrow keys |
| Brake | S, Down or Space |
| Drive or reverse | R |
| Doors | F |
| Indicators | Q and E |
| Horn | H |
| Radio: next station or off | N |
| Camera view | C |
| Recover bus to the route | Backspace |

The mouse also works on the on-screen controls.

## Tests

```bash
tools/test.sh
```

The script uses `$GODOT` if set, then `.tools/`, then `godot` on your PATH. It
exits non-zero if a test fails or the run hangs.

`tools/gate.sh` is the check before committing: every test, then an Android export
and the APK size limit.

To drive a complete shift automatically and get a report on collisions, jolts
and missed stops, which checks that a route can be completed:

```bash
tools/autopilot.sh
```

Set `AUTOPILOT_ROUTE` and `AUTOPILOT_BUS` to a catalog id to test a specific pair,
`AUTOPILOT_TIME` to a time of day such as `noche`, and `AUTOPILOT_RAIN=1` to force a
downpour (`0` keeps it dry; unset follows the seed and the time's chance):

```bash
AUTOPILOT_ROUTE=route_01 AUTOPILOT_TIME=noche AUTOPILOT_RAIN=1 tools/autopilot.sh
```

The autopilot steers by the rear axle and pulls out of bays without looking, so an
odd car contact in its report is not always a problem with the route.

## Hidden cheats

The cheats are on in debug builds, and in release builds while the project setting
`buseta/testing/cheats_in_release` is `true` (the default for now, so Play testers
can try every setting and unlock without grinding). Before a public release, set it
to `false` in `project.godot` — `tools/build_release.sh` warns while it is still on.

- Main menu: tap the "Buseta Simulator: Colombia" title seven times, each within about a second
  of the last, for coins, driver levels, "Max level" (every time of day, Alto Cafeto
  and the arcade) and unlocking everything.
- During a shift: open MENU and tap the "Paused" title seven times for "Skip to next
  stop", "Finish shift" and "Downpour now". A finished shift pays out like a normal one.

## Adding content

Everything below lives in a country pack, such as `data/packs/colombia`. See
[ARCHITECTURE.md](ARCHITECTURE.md) for what a pack holds.

- A map is a JSON file in `maps`: nodes, roads, hills, bumps, potholes, parked cars
  and knockable props.
- A route is a JSON file in `routes`: the roads it follows, its stops and
  when each stop is due, in seconds from the start of the shift. Set the times
  from the arrivals `tools/autopilot.sh` prints. Going round a roundabout to an exit
  on the left takes about 20 seconds longer than going straight on.
- Each road can set `speed_limit` in km/h, and `traffic: false` to keep cars off it.
- A bus is a `BusSpec` resource in `buses`.
- `catalog.json` lists what can be unlocked and its cost. Add a route, bus,
  livery or driver there and it appears in the menus. `achievements.json` and
  `daily_challenges.json` work the same way.
- `passengers.json` lists the people who wait at stops, ride and walk the
  pavements, and the vendors. Each look sets colours, hair, clothes, a hat and
  anything carried. `size` makes children smaller and `pace` makes older people
  walk more slowly. `CountryPack.validate()` names any style it does not know.

Times of day and weather are in `pack.json`:

- `times_of_day` lists the times a shift can run at, in menu order: an id, a name,
  `level` to unlock it, `default: true` on one open from level 1, the sun
  (`sun_from` compass degrees, 90 is east; `sun_elevation`; `sun_colour`;
  `sun_energy`; `shadows`), `sky_top`, `sky_horizon`, `fog`, `fog_scale`, `ambient`,
  `ambient_energy`, `lights` (street lamps, 0 to 1), `windows` (share lit), `traffic`
  and `pedestrians` (times the usual), `rain_chance`, and optionally `stat`, a
  profile stat counted for each shift at that time. Leave it out and the map's theme
  gives one plain day.
- `weather.rain` sets the downpours: `build_seconds`, `rain_seconds`,
  `clear_seconds`, `start_share` (of the timetable) and `strength` as `[low, high]`;
  `wet_grip`, `dry_seconds`, `traffic_speed`, `traffic_gap`, `pedestrians`,
  `umbrellas`, `fog_density`, `storm_sky`, `darken`, `sun_dim`, `lights` and
  `schedule_slack`. `CountryPack.validate()` checks both.

Sound is in `pack.json` too:

- `horns` lists the horns: an id, a name, a file, and optionally `cost`, `level`,
  `volume_db` (added to the horn's level) and `finish: true` for a tune that plays
  to its end. A bus names its own horn with `horn` in the catalog. The player can
  fit another in the Garage. At least one horn must be free.
- `ambience` lists the street sound layers, mixed by `AmbienceMixer`. Each has an
  id, a file and a `rule`:
  - `always`; `calm` (louder while the bus stands); `rain` (follows the weather);
  - `sea`, `stalls` (market stalls) or `vendors` (stalls and bus stops), which
    need `near` and `far` in metres: full inside `near`, silent beyond `far`.
  - Optional: `volume_db`; `every` as `[shortest, longest]` seconds for a sound
    played now and then instead of a loop; `muffled: true` to play it through the
    muffled distant bus; `dry: true` to fade it out in rain; `radio_ducks: true` to
    silence it while the radio plays; `radio_ducks_db` (0 or less) to lower it by
    that much while the radio plays in the cockpit.
- `radio` lists the stations: an id, a fictional name, a frequency, a genre and its
  tracks. Leave it empty and the radio button is hidden. Each track plays once and
  the station moves on, so a track should start and end in silence. Use only
  original or CC0 music, never a real song, station name or jingle.

Sounds, horns, street sounds and radio music are generated by `tools/make_sounds.py`
(it needs numpy), and `python3 tools/check_sounds.py` checks their levels. Textures
are drawn by `tools/make_textures.py`.

The game is in Colombian Spanish first and English second. Each language other
than English has a file in the pack's `lang` folder, such as
`data/packs/colombia/lang/es_CO.json`, keyed by the English text in the code.
`pack.json` lists the languages in the order the settings show them. On first
launch the game uses English only if the phone is in English, and otherwise the
pack's `default_language`. `tools/test.sh` fails if any text in the code or data
files has no translation, if a translation loses a `%d` or `%s`, or if it uses a
word from Spain rather than Colombia, such as "autobús" or "pulsa".

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
