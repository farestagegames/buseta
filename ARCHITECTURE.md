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

## Modules

| Folder | Contents |
| --- | --- |
| `scripts/core` | `GameEvents` signal bus, `GameSettings` player settings |
| `scripts/vehicle` | `BusSpec` data, `BusPhysicsModel` handling, `AutomaticGearbox`, `BusDoors`, `BusIndicators`, `BusController` scene wrapper, `BusVisual` |
| `scripts/input` | `SteeringMapper` for all three steering modes, `WheelTracker`, `DriverInputRouter` |
| `scripts/camera` | `CameraRig` with cockpit, close and far views |
| `scripts/ui` | Multi-touch controls, HUD and settings panel |
| `scripts/world` | `RoadNetwork`, `GroundSurface`, `MapLoader`, `CityBuilder`, `ObstacleField`, `KnockableProp`, `LowPolyBuilder`, `CityShift` level root, `TestGround` |
| `scripts/route` | `RouteRunner` progress and turn hints, `RouteStop` alignment, `RouteSystem` shift flow |
| `scripts/passengers` | `PassengerLedger`, `StopSession`, `PassengerCrowd` visuals, `CabinLayout` walking paths inside the bus |
| `scripts/drivers` | `DriverLook` data read from the catalog, `DriverFigure` box models |
| `scripts/audio` | `AudioDirector`, driven only by events |

| `scripts/scoring` | `ShiftScore` category points, stars and coins, `DrivingMonitor`, `ScoreKeeper` |
| `scripts/traffic` | `TrafficLightPlan`, `LaneGraph`, `TrafficLane`, `TrafficAgent`, `TrafficSystem` |

| `scripts/progression` | `PlayerProfile`, `SaveStore`, `Catalog`, `ShiftRewards`, `DriverLevel`, `DailyChallenge`, `AchievementList`, `AdProvider`, `ProgressionSystem`, `Cheats` |
| `scripts/core/profile.gd` | Autoload holding the live profile and saving it |
| `scripts/core/lang.gd` | Autoload for languages and fonts |
| `scripts/core/graphics_quality.gd` | Low, medium and high as data, and matching a phone to a level |
| `scripts/tutorial` | `CameraShots`, `IntroCutscene`, `TutorialScript`, `TutorialDirector`, `TutorialPanel` |
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
locked left to right, so Arabic mirrors the menus, the pause panel and the shift
report but never moves the wheel or pedals.

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
a new driver needs no code. Drivers change nothing about how the bus handles.

**Cheats in test builds only.** `Cheats.available()` is `OS.is_debug_build()`, so
the gesture and panels do not exist in a release export. The panels are English
only, and each cheat is a small function on `PlayerProfile` or `RouteSystem`.

**Autopilot check.** `tools/autopilot.sh` drives a whole shift through the real
controls. Run it after changing a map, because a route that passes its data tests
can still be impossible for a 12 m bus.

**Custom multi-touch controls.** Standard Godot buttons follow one pointer. Each
`TouchZone` tracks its own finger, so pedals and steering work at the same time,
and held controls are released if the app loses focus.

**GL Compatibility renderer.** It reaches the widest range of phones and has the
lowest overhead on mid-range hardware.

**Batched geometry.** `LowPolyBuilder` merges boxes into one vertex-coloured mesh,
so the bus body and the test ground props each cost one draw call.

**Physics interpolation.** Physics runs at a fixed 60 Hz, and cameras read
interpolated transforms, so motion stays smooth at any frame rate.
