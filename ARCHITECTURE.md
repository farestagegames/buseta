# Architecture

## Rules

- Each module has one job and lives in its own folder under `scripts/`.
- Modules talk through the `GameEvents` signal bus, not through direct references.
- Game logic is plain `RefCounted` classes with no scene dependencies, so it can
  be unit tested headless. Nodes are thin wrappers around that logic.
- Content is data. A new bus is a new `BusSpec` file in `data/buses/`.

## Data flow

```
Touch controls (scripts/ui)  --ui_* signals-->  DriverInputRouter (scripts/input)
Tilt sensor, keyboard  ---------------------->        |
                                                drive_input_changed
                                                      v
                                              BusController (scripts/vehicle)
                                                      |
                                                 runs BusPhysicsModel
                                                      |
                                              bus_telemetry_updated
                                                      v
                                 BusVisual, CameraRig, HudGauge, later scoring
```

## Country packs

A country is a folder in `data/packs`, with `pack.json` at its root. It sets the
driving side, road rules, signage, currency, languages, sounds and radio, and points
to the catalog of routes, buses, liveries and drivers, plus passenger designs,
achievements and daily challenges. `Country.pack` is the live pack and
`CountryPack.validate()` lists anything wrong with one. Paths in a pack are relative
to its folder unless they start with `res://`.

Left-hand driving needs no special code. `RoadNetwork.sample` takes a `dir` for
anything placed relative to traffic, and then `lateral` means "towards the kerb
traffic keeps to", so lanes, bays, parked cars and cones all swap sides together.
`BusSpec.keep_to_side` mirrors the door and driver, and `LaneGraph` turns the
roundabouts the other way. `test/fixtures/packs/testland` is a small left-hand pack
that proves this. Its tests run a real stop, and the autopilot can drive it:

```bash
AUTOPILOT_PACK=res://test/fixtures/packs/testland/pack.json AUTOPILOT_ROUTE=test_loop AUTOPILOT_BUS=test_bus tools/autopilot.sh
```

## Modules

| Folder | Contents |
| --- | --- |
| `scripts/core` | `GameEvents` signal bus, `GameSettings` player settings, `CountryPack` and the `Country` autoload |
| `scripts/vehicle` | `BusSpec` data, `BusPhysicsModel` handling, `AutomaticGearbox`, `BusDoors`, `BusIndicators`, `BusController` scene wrapper, `BusVisual` |
| `scripts/input` | `SteeringMapper` for all three steering modes, `WheelTracker`, `DriverInputRouter` |
| `scripts/camera` | `CameraRig` with cockpit, close and far views |
| `scripts/ui` | Multi-touch controls, HUD and settings panel |
| `scripts/world` | `RoadNetwork`, `GroundSurface`, `MapLoader`, `CityBuilder`, `ObstacleField`, `KnockableProp`, `LowPolyBuilder`, `HeadParts` faces, hair and hats, `CityShift` level root, `TestGround` |
| `scripts/route` | `RouteRunner` progress and turn hints, `RouteStop` alignment, `RouteSystem` shift flow |
| `scripts/passengers` | `PassengerLedger`, `StopSession`, `PassengerCrowd` visuals, `CabinLayout` walking paths inside the bus, `PassengerLooks` and `PassengerLook` data read from the pack, `PassengerFigure` meshes |
| `scripts/drivers` | `DriverLook` data read from the catalog, `DriverFigure` box models |
| `scripts/audio` | `AudioDirector`, driven only by events; `HornVoice`, `AmbienceMixer` and `RadioTuner` logic; `SoundBuses` |

| `scripts/scoring` | `ShiftScore` category points, stars and coins, `DrivingMonitor`, `ScoreKeeper` |
| `scripts/traffic` | `TrafficLightPlan`, `LaneGraph`, `TrafficLane`, `TrafficAgent`, `TrafficFlow` driving logic, `TrafficSense` geometry and choices, `TrafficBox`, `TrafficSystem` drawing |

| `scripts/progression` | `PlayerProfile`, `SaveStore`, `Catalog`, `ShiftRewards`, `DriverLevel`, `DailyChallenge`, `AchievementList`, `AdProvider`, `ProgressionSystem`, `Cheats` |
| `scripts/core/profile.gd` | Autoload holding the live profile and saving it |
| `scripts/core/lang.gd` | Autoload for languages and fonts |
| `scripts/core/graphics_quality.gd` | Low, medium and high as data, and matching a phone to a level |
| `scripts/tutorial` | `CameraShots`, `IntroCutscene`, `TutorialScript`, `TutorialDirector`, `TutorialPanel` |
| `scripts/weather` | `TimeOfDay` and `RainSettings` pack data, `WeatherPlan` seeded downpours, `WeatherClock` rain and road wetness through a shift, `Atmosphere` sky and light, `WeatherDirector` scene wrapper, `RainSheet` |
`CityShift` is the only script that knows every module. It wires them together
at load time.

## Key decisions

**Right-hand traffic.** Vehicles drive on the right, as in mainland Europe. The
bus has its driver on the left and its doors on the right, set in `BusSpec`.

**Custom handling instead of Godot's vehicle physics.** The bus is a kinematic
bicycle model pivoting on the rear axle, moved by a `CharacterBody3D`. It is
cheap on phones, gives the same result at any frame rate, and can be tuned and
tested without a scene. The body extending behind the pivot gives real rear
overhang swing. Weight comes from pedal lag, limited steering speed, grip
limits and spring-damped body movement.

**Ground as a height function.** `GroundSurface` answers "how high is the ground
here?" for each wheel. Terrain gives slope, which feeds gravity into the handling
model. Kerbs, bumps and potholes are extra detail felt by the wheels. `BusSuspension`
springs the body on the four wheel heights, so hills tilt it smoothly and bumps
make it rock. No ground collision mesh is needed. Only detail counts as a jolt, so
smooth hills never penalise passenger comfort.

**Ballistic obstacles.** `KnockableProp` is simple maths tested against the bus
outline, drawn with one `MultiMesh` per kind. Hundreds cost almost nothing, whereas
a rigid body each would be heavy on a phone.

**Pushable cars.** Parked cars are heavy `KnockableProp`s, not solid walls. A bus
outweighs a car about nine to one, so a hit shoves the car and costs some speed
depending on how direct and how fast it was. Buildings, trees and lamp posts stay
solid.

**Textures from a script.** `tools/make_textures.py` draws tiling textures that
the meshes tint with vertex colour, so one wall texture covers every building.
`LowPolyBuilder` writes UVs in metres, which keeps brick and windows at real size.

**Scoring through events.** `ScoreKeeper` only listens to `GameEvents` and only
speaks through them. All point values are named constants in `ShiftScore`, so the
game's balance can be tuned in one file. A shift ends with `shift_report_ready`.

**Traffic without physics bodies.** Cars follow lanes built from the road data and
use the Intelligent Driver Model for smooth queues. It is cheap, and cars are drawn
as one instanced batch. They react to the bus through its telemetry.

**Traffic that sees the bus.** `TrafficFlow` is plain logic, and `TrafficSystem` only
feeds it the bus and draws the result. Each tick a vehicle traces the strip it is
about to drive, at its own width, and checks it against the bus body and trailer,
each stretched to where the bus will be in a moment. Props in the road are kept as
spans along and across each lane, so checking them is a few sums. Other vehicles
come from per-lane lists, never a loop over everyone. A vehicle waits at a junction
while the bus is in the part it would cross. It goes round a bus at a stop, or
something standing in the lane, by moving sideways (`TrafficAgent.shift`), and only
moves back once its usual line is clear. Speed limits ahead are met by easing off
in time, and only something in the way brakes hard. The rules themselves are pure
functions in `TrafficSense`.

**Safe saves.** `SaveStore` writes to a temporary file and swaps it in only when
complete, keeping the last good save as a backup. `PlayerProfile.from_dict`
validates every field, so damaged data cannot stop the game from starting. Progress
saves after every change and whenever the app goes to the background.

**Ads behind an interface.** `AdProvider` is a stub that is never available, so no
ad button shows. A real provider extends it and is assigned to `Profile.ads`.

**Scoring fairness.** `test_an_imperfect_learner_shift_earns_three_or_four_stars`
defines what a realistic imperfect drive should score. Change the balance
freely, but keep that test passing. Losses in a category level off, running early
is never penalised, and any valid stop scores at least 60% for accuracy.

**Chunked city.** `LowPolyBuilder` can split geometry into 170 m cells, so the
phone only draws what the camera can see. This halved triangles per frame. The cost
is more draw calls, which is the number to watch on low-end GPUs.

**Languages.** Anything drawn by hand calls `tr()`, and the driving controls are
locked left to right, so a right-to-left language would mirror the menus, the pause
panel and the shift report but never move the wheel or pedals. Colombian Spanish is
the main language and English the second. Text drawn on a button or gauge shrinks
to fit with `UiStyle.fit_font_size`, so a longer word in Spanish never spills out.
`test_languages` scans the code for text a player could see and fails if it has no
Spanish entry.

**People on the bus.** `StopSession` still decides who boards and when, one person
at a time, and knows nothing of walking. `PassengerCrowd` then shows it: a boarder
is reparented to the bus body, follows the `CabinLayout` path past the ticket
machine, and stops being a walker on reaching their row. `BusVisual` holds that seat
empty in the rider batch until then, so nobody appears sitting before they arrive.
`passenger_paid` comes from the crowd, because the sound has to match the moment on
screen rather than the moment the ledger changed. In the cockpit view `CameraRig`
turns the driver's head to the doorway while the doors are open.

**Reports that always fit.** The shift report keeps its buttons in a column of
fixed height, and everything that can grow scrolls. `test_report_fits` renders the
longest possible report in every language at a 16:9 phone's height.

**Stop lines behind the zebra.** Cars wait 5.4 m back from a junction, painted and
driven from one constant, `LaneGraph.STOP_LINE_GAP`. A 12 m bus turning right
sweeps its nose across the opposite lane, so the gap is what makes tight corners
fair.

**Drivers are data.** A driver is a catalog entry of colours and styles. `DriverLook`
reads it, `DriverFigure` builds the 3D figure and `DriverBadge` draws the portrait, so
a new driver needs no code. Drivers change nothing about how the bus handles. The
interior mirror trims the head to its glass with `LowPolyBuilder.clip` and squashes it
flat, so a tall hat or long braids stop at the frame from any seat in any bus.
`CountryPack.validate()` names a driver's misspelt style or bad colour.

**Passengers are data.** The pack's `passengers.json` lists looks: a person's colours,
hair, clothes, hat and whatever they carry, with `size` for children and `pace` for
older people. `PassengerLooks` reads it and never fails, falling back to one default
person, while `CountryPack.validate()` reports anything wrong. `PassengerCrowd` builds
each look once as a body, an arm and a leg mesh, and dresses walkers from a shuffled
deck as they step out. Seated riders and pavement walkers take their colours from the
same looks, and a rider keeps the look of whoever walked to that seat. Drivers and
passengers share `HeadParts`, so a vueltiao or braids look the same on both.

**Cities are themed by data.** The `theme` block of a map sets the colours, building
mix, palms and sky, read by `CityTheme`, and the `coast` block adds a beach and sea.
`StreetLife` walks people along the pavements as one instanced batch. Motorbikes are
`TrafficAgent`s that keep to the kerb side of a lane and pass cars that do not
overlap them, a little faster than the car, so they filter past queues without any
lane-changing logic.

**Bus bodies and paint are data.** `BusSpec.body_style` picks the shell, and a livery
sets colours and a pattern drawn by `BusVisual._paint_livery` as flat shapes in the
merged body mesh. The rear section of an articulated bus is a trailer: `BusPhysicsModel`
drags its axle behind the joint, so it cuts in on bends, and it has its own collision
shape and footprint.

**Three kinds of stop.** `RouteStop.Kind` is a bay, a hail or a station, set by a
route's `service`. On an informal route `HailPlan` adds people flagging the bus down
between the named stops, seeded per shift, and only the final stop is really timed:
each hail gets a share of it. `RouteRunner.update_position` also takes the bus's
facing, because a line that runs out and back on one road passes each point twice.

**Sound is data.** The pack lists its horns, its street sound layers and its radio
stations, and `CountryPack.validate()` checks them. `AudioDirector` only plays what
three pure classes decide. `HornVoice` loops a held horn, fades a steady one out on
release and lets a tune horn finish its pass. `AmbienceMixer` sets each street
layer's level from the distance to the sea, the nearest stall or stop, the bus's
speed, the radio and a rain input (`GameEvents.rain_changed`, for the weather to
come), and times the one-off sounds such as a passing motorbike. `RadioTuner` steps
off, through each station and back to off, and moves to the next track when one
ends. Each bus names its horn in the catalog, and the player can fit another in
the Garage, saved in the profile. The station is a setting, so it carries over to
the next shift. The radio has its own bus and volume, made by `SoundBuses`, and is
quieter and muffled from the follow cameras. It keeps playing in the pause menu, so
its volume slider can be heard. Loops carry their loop points inside
the WAV file, which Godot reads on import, and every file is compressed with QOA.

**Cheats in test builds only.** `Cheats.available()` is `OS.is_debug_build()`, so
the gesture and panels do not exist in a release export. The panels are English
only, and each cheat is a small function on `PlayerProfile` or `RouteSystem`.

**Time of day and weather are data.** The pack's `times_of_day` list sets the sun,
sky, fog, ambient light, lamps, windows, traffic and pedestrians for each time, and
its unlock level. `weather.rain` sets how an aguacero builds, lasts and clears and
what a wet road does. `WeatherPlan` decides from the shift seed whether and when it
rains, and `WeatherClock` follows it, keeping a road wetness that soaks quickly and
dries slowly. `WeatherDirector` is the only node that runs it: it sets the sky, sun
and fog itself and sends `rain_changed`, `weather_updated` and `lighting_changed`.
The bus reads its grip, traffic its speed and gap, `RouteSystem` its timetable
slack, `StreetLife` its walkers and umbrellas, and `ScoreKeeper` the downpour bonus,
all from those events.

**Night without real lights.** Lit windows are worked out in the facade shader from
the window's place and each building's vertex alpha. Lamps, stalls and shelters
glow through unshaded materials and throw additive discs on the ground. The only
real lights are on the bus: a headlight beam on MEDIUM and HIGH and a cabin light on
HIGH that only lights the bus's own render layer. Sun shadows are off at night and
fade out under storm clouds, so a night or a downpour costs less than a sunny day.

**Rain round the camera.** `RainSheet` draws falling streaks with a shader on one
or two open cylinders that follow the camera. Raindrops on the windscreen are a
shader too: it knows when a wiper blade last crossed each spot from the blade's
sweep, so drops grow back behind the blades without any extra render pass.

**Autopilot check.** `tools/autopilot.sh` drives a whole shift through the real
controls. Run it after changing a map, because a route that passes its data tests
can still be impossible for a 12 m bus.

**Touch lists.** Every scrolling list is a `TouchScroll`, which lets a drag start
on anything inside it, cancels a button press once the finger scrolls, and treats
a tap on a coasting list as a stop. Sliders inside are `TouchSlider`s, which move
only for a sideways drag. Rows that react to a tap use `TouchScroll.on_tap`.

**Custom multi-touch controls.** Standard Godot buttons follow one pointer. Each
`TouchZone` tracks its own finger, so pedals and steering work at the same time,
and held controls are released if the app loses focus.

**GL Compatibility renderer.** It reaches the widest range of phones and has the
lowest overhead on mid-range hardware.

**Batched geometry.** `LowPolyBuilder` merges boxes into one vertex-coloured mesh,
so the bus body and the test ground props each cost one draw call.

**Physics interpolation.** Physics runs at a fixed 60 Hz, and cameras read
interpolated transforms, so motion stays smooth at any frame rate.
