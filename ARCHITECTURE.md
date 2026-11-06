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
| `scripts/world` | `LowPolyBuilder` mesh batching, `TestGround` |

Planned for later phases: `route`, `passengers`, `scoring`, `traffic`,
`progression`, `save`, `audio`.

## Key decisions

**Custom handling instead of Godot's vehicle physics.** The bus is a kinematic
bicycle model pivoting on the rear axle, moved by a `CharacterBody3D`. It is
cheap on phones, gives the same result at any frame rate, and can be tuned and
tested without a scene. The body extending behind the pivot gives real rear
overhang swing. Weight comes from pedal lag, limited steering speed, grip
limits and spring-damped body movement.

**Custom multi-touch controls.** Standard Godot buttons follow one pointer. Each
`TouchZone` tracks its own finger, so pedals and steering work at the same time,
and held controls are released if the app loses focus.

**GL Compatibility renderer.** It reaches the widest range of phones and has the
lowest overhead on mid-range hardware.

**Batched geometry.** `LowPolyBuilder` merges boxes into one vertex-coloured mesh,
so the bus body and the test ground props each cost one draw call.

**Physics interpolation.** Physics runs at a fixed 60 Hz, and cameras read
interpolated transforms, so motion stays smooth at any frame rate.
