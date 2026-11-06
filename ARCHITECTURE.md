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
| `scripts/passengers` | `PassengerLedger`, `StopSession`, `PassengerCrowd` visuals |
| `scripts/audio` | `AudioDirector`, driven only by events |

| `scripts/scoring` | `ShiftScore` category points, stars and coins, `DrivingMonitor`, `ScoreKeeper` |
| `scripts/traffic` | `TrafficLightPlan`, `LaneGraph`, `TrafficLane`, `TrafficAgent`, `TrafficSystem` |

| `scripts/progression` | `PlayerProfile`, `SaveStore`, `Catalog`, `ShiftRewards`, `DriverLevel`, `DailyChallenge`, `AchievementList`, `AdProvider`, `ProgressionSystem` |
| `scripts/core/profile.gd` | Autoload holding the live profile and saving it |
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
