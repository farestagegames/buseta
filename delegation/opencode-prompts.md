# opencode prompts: engagement batch and feedback fixes (12 Nov)

Run them **one at a time, in this order**, in `~/Claude/Games/Buseta` on branch
`overnight`. They share files (results screen, stars, catalog) and only one Godot
process may run at a time. Paste the shared rules plus one task into opencode.
Check each commit before you start the next.

## Shared rules (paste at the top of every prompt)

```
Project: "Buseta Simulator: Colombia", a Godot 4.7.2 / GDScript bus driving game for
Android, in ~/Claude/Games/Buseta on branch `overnight`. Read PROGRESS.md and
DECISIONS.md first; don't re-explore the whole repo.

Rules:
- Work on `overnight` only. Never touch `main`, never force-push, never rewrite history.
- Only one Godot process at a time.
- Commit only after `sh tools/gate.sh` passes (all GUT tests plus an APK under 150 MB).
  Add or update GUT tests in `test/` for every behaviour you change.
- No ad, analytics or Play Games SDKs, no network code, no paid services. The game
  collects no data; keep it that way.
- Content lives in data (`data/packs/colombia/*.json`, `.tres`), not hard-coded.
- Every new visible string goes in both languages via the lang files
  (`data/packs/colombia/lang/es_CO.json` and the English source), worded in coastal
  Colombian Spanish, and must fit at 1280, 1560 and 1600 px wide (an existing test
  checks visible text).
- Keep it respectful: no crime or poverty stereotypes.
- Record each design decision in one line in DECISIONS.md and update the table in
  PROGRESS.md. Commit message: one plain sentence saying what changed.
- Finish with a short report: what changed, test count, APK size, commit hash,
  anything not verified on a phone.

Agents and models (OpenCode Go): pick the most efficient agent for each step, not
the biggest model for everything.
- Start in the `plan` agent: read only what the task names, then write a short
  plan (files to touch, tests to add) before editing.
- Hand file searches and reading to the `explore` subagent (or `general` if
  explore isn't available), on the fastest/cheapest model available in OpenCode Go.
- Switch to the `build` agent for the edits. Use the strongest coding model you have
  for logic, physics, save migration and UI layout; use a lighter model for data
  edits (JSON/lang strings), docs and commit messages.
- If a gate run fails twice on the same error, stop and report rather than looping.
- Say in your final report which agent/model you used for each step.

Difficulty for this task: see the line under its heading.
```

## 1. Tutorial highlight ring is offset on the phone

Difficulty: Small: lighter model is fine, strong model only if the coordinate bug is subtle. Paste this line too.

```
Bug: the tutorial's pulsing yellow highlight ring is shifted and/or the wrong size on
an Android phone (it lines up in the Mac editor). The ring is drawn by
`scripts/tutorial/tutorial_panel.gd` (`show_step(text, ring)`, `_draw()`), and its rect
comes from `_hud.control_rect(step["focus"])` in
`scripts/tutorial/tutorial_director.gd` (`_show_step()`), defined in
`scripts/ui/drive_hud.gd`.

Likely causes to check: the rect is in a different coordinate space from the panel's
canvas (global vs local, viewport stretch/aspect on a tall phone screen, safe-area
insets for the notch), or it is read before the HUD layout settles after a resize.

Fix it so the ring wraps the focused control exactly at any aspect ratio and with
safe-area insets. Recompute it when the viewport size changes. Add a GUT test that
runs the HUD at a phone-like size (e.g. 2400x1080 and 1600x720) with a fake safe area
and checks that for every tutorial step the ring rect contains the focused control's
on-screen rect, with no more than 4 px of offset.
```

## 2. Birds: heard and seen near trees only

Difficulty: Medium: strong model for audio and flock code, light model for map data. Paste this line too.

```
Change: the birds are currently one map-wide ambience layer
(`assets/audio/ambience/birds.wav`, mixed in `scripts/audio/ambience_mixer.gd`; rain
fades it out, see `scripts/core/game_events.gd`). The owner wants birds only near
some trees.

1. Remove birds from the map-wide street ambience.
2. Pick a handful of tree clusters (palms and trees placed by
   `scripts/world/city_builder.gd` / `street_life.gd`; choose spots in parks, the
   seafront and quieter streets, not the busway) and put positional 3D bird sound
   there (AudioStreamPlayer3D, short range ~25 to 35 m, random start offset so they
   don't loop in sync). Keep the rain fade: birds go quiet in a downpour and at night.
3. At some of those clusters, add a small flock (3 to 6 simple low-poly birds) that
   perch in the tree and fly off in a short arc when the bus passes within ~15 m,
   then return after a while. Keep it cheap: no physics, pooled meshes, nothing on
   low graphics quality beyond the sound.
4. Put the cluster positions in map data (`data/packs/colombia/maps/puerto_marisol.json`)
   so they can be tuned without code.

Tests: no bird sound in the global ambience; players exist only at the listed
clusters; a flock takes off when a fake bus comes within range and not otherwise;
birds are silent in full rain. Check the frame time on the existing performance test
(if there is one) does not get worse.
```

## 3. Two short starter routes

Difficulty: Medium: light model for route JSON and strings, strong model for unlock logic and tests. Paste this line too.

```
Feature: new players should finish their first shifts in 3 to 5 minutes before the
longer routes. Add two NEW starter routes; leave all existing routes unchanged.

- Routes are JSON in `data/packs/colombia/routes/` (see `route_01.json` for the format:
  map, start, legs, stops, service, hail) and are listed in
  `data/packs/colombia/catalog.json` under "routes" (id, name, file, cost,
  description).
- Starter A: 3 stops, about 3 minutes at normal driving, simple streets, one gentle
  turn type, no busway. Starter B: 5 stops, about 5 minutes, adds a roundabout or the
  seafront.
- Order them first in the route list. Starter A is free and selected for a new
  profile. Starter B unlocks after finishing A. Route 1 unlocks after finishing B.
  Existing saves keep everything they already own.
- Fit the tutorial: it should run on Starter A if it currently runs on Route 1.
- Daily challenges and achievements that name routes must still be offered only
  once playable (`scripts/progression/daily_challenge.gd`).
- Names and descriptions in both languages, in the game's style (e.g. "Ruta 0:
  Vuelta corta").

Tests: a fresh profile starts on Starter A; unlock order A, B, Route 1; use the
autopilot (`tools/autopilot.sh`) to finish both starter routes and assert duration
limits (A under 4 min, B under 6 min of game time).
```

## 4. Three route goals = three stars

Difficulty: Hard: strong model (touches scoring, saves, challenges, achievements). Paste this line too.

```
Change: replace the current 5-star rating with 3 stars, one per route goal.

- Today stars are 0 to 5 (`report["stars"]`, shown in `scripts/ui/shift_end_panel.gd`,
  used by `scripts/progression/shift_rewards.gd`,
  `scripts/progression/driver_level.gd` `xp_from_shift`, daily challenges and
  achievements). Find every use.
- Each route JSON gets a "goals" array of exactly 3 goals from a small data-driven
  set, e.g. finish under a time, no fines, no collisions, pick up N vendors, every
  stop "perfect", satisfaction at least N. Write goals for all routes, including the
  starter routes if task 3 is done; the endless and arcade routes keep their own
  scoring.
- Show the 3 goals on the route panel before the shift, as a small checklist in the
  HUD during it (ticks when met, crossed when failed), and on the results screen.
- Stars = goals met. Best stars per route are kept; migrate old saves (convert
  0-5 best stars to 0-3 by rounding down 5->3, 4->2, 3->2, 2->1, 1->1, 0->0, then
  record it in DECISIONS.md) and keep XP rewards roughly the same.
- Update daily challenges and achievements that test star counts so they still make
  sense with 3 stars.

Tests: goals evaluate correctly from a fake shift report; stars equal goals met;
save migration; HUD checklist updates; challenges with star conditions still offered.
```

## 5. Instant feedback at every stop

Difficulty: Medium: strong model. Paste this line too.

```
Feature: make every stop feel rewarding (scripts around `scripts/passengers/stop_session.gd`,
`scripts/route/route_runner.gd`, HUD in `scripts/ui/drive_hud.gd`,
`scripts/ui/penalty_toast.gd` for the existing toast style, sounds in
`scripts/audio/` and `tools/make_sounds.py` (sounds are generated in code, CC0)).

- When fares are paid, show a floating "+$2.400" (peso format already used in the
  game) rising from the fare area, with a fare-box clink.
- A "¡Parada perfecta!" stamp plus a short chime when the bus stops cleanly inside
  the stop box (define "perfect" in one place: inside the box, low speed at the
  stop, no harsh braking). Count perfect stops in the shift report so task 4's goals
  can use it.
- One happy reaction from boarding passengers (a small emoji-style bubble or a
  bounce) when the stop is perfect.
- Keep it short (under 1.2 s), never covering the controls or the tutorial ring,
  and with a setting to reduce effects if one exists.

Tests: the perfect-stop rule; toast and stamp fire once per stop; perfect stops are
in the shift report.
```

## 6. Big payout screen at the end of a shift

Difficulty: Hard: strong model (animation sequence and UI layout). Paste this line too.

```
Feature: rework the end-of-shift results (`scripts/ui/shift_end_panel.gd`,
`scripts/progression/shift_rewards.gd`) into a celebratory payout.

- Coins count up one category at a time: fares, tips, clean driving, on-time bonus,
  fines (in red, counting down), then the total. Each line lands with a tick sound;
  the total lands with a bigger sound.
- Then the 3 stars pop in one by one (scale bounce plus sound), each with its goal's
  name underneath (uses task 4's goals).
- Then the XP bar fills; on a level-up, a short burst.
- Then a "Próximo desbloqueo" bar (task 7 adds the data; for now show the next
  affordable shop item and how many coins are missing).
- Main button "Siguiente ruta" (or "Reintentar por ★★★" when not all stars are won),
  secondary "Menú".
- Tap anywhere to skip the animation to the final state. The whole sequence is
  under 6 seconds.
- The categories must add up exactly to the coins awarded.

Tests: categories sum to the reward; the skip shows the final state; the button
label depends on the stars; the sequence finishes under 6 s of game time.
```

## 7. Unlock something every 1 to 2 shifts

Difficulty: Medium: light model for catalog data and balancing notes, strong model for the cockpit decorations. Paste this line too.

```
Feature: early players should unlock something every 1 or 2 shifts. Shop items are in
`data/packs/colombia/catalog.json` (liveries, buses, drivers) plus horns, bought with
coins and gated by driver level (`scripts/progression/player_profile.gd`,
`scripts/progression/catalog.gd`).

- Reorder the costs and level gates of liveries and horns so cheap ones arrive during
  the first 10 shifts, using the average coins per shift from the starter routes
  and Route 1 (measure it with the autopilot, write the numbers in DECISIONS.md).
- Add a new kind of small cosmetic: cab decorations (seat covers, a dashboard toy, a
  mirror charm, a football pennant without real club names or crests; nothing
  religious or political), 6 to 8 items, cheap, shown in the cockpit view and in
  the garage try-on. Original designs only, no real brands.
- Add a "Próximo desbloqueo" helper that returns the next item the player can reach
  and the coins/level missing; show it on the main menu and give it to the results
  screen (task 6).
- Existing saves keep their purchases and coins.

Tests: new items load and can be bought; cockpit shows the equipped decoration;
"next unlock" picks the cheapest reachable item; a simulated run of 10 starter-level
shifts unlocks at least 5 items.
```

## 8. Celebrate first times

Difficulty: Medium: strong model for the save and achievement links, light model for the list of firsts. Paste this line too.

```
Feature: one-off celebrations for a player's firsts, kept in-game only (no Play Games
achievements; decided 12 Nov, see DECISIONS.md).

- Firsts: first passenger picked up, first perfect stop, first full bus, first
  3-star route, first shift with no fines, first night shift, first rain shift,
  first chiva drive, first La Ola line shift, first vendor on board. Put the list in
  data.
- Each shows a banner with confetti and a small coin reward the first time only
  (saved in the profile), mid-shift where it happens, short and never over the
  controls.
- Connect them to the existing achievements (`scripts/progression/achievement_list.gd`,
  `data/packs/colombia/achievements.json`): when a first matches an achievement,
  unlock that achievement at the same time and show one banner, not two. Also show
  achievements unlocked during a shift as the same mid-shift banner instead of only
  in Career.
- Give every achievement and first a stable id in `snake_case` that could later be
  mapped to Play Games achievements without changes.

Tests: each first fires once ever and survives a save/load; a matching achievement
unlocks with one banner; the coins are added once.
```

## Owner feedback (12 Nov, evening)

Run 9 to 11 one at a time, like the others. 10 and 11 both touch the Drivers tab
and `scripts/ui/driver_preview.gd`, so run 10 then 11.

## 9. Vendor carts are never left unattended

Difficulty: Easy to Medium. Light model is fine.

```
Bug: the street vendor carts/stalls (knockable kind "stall" in the map JSON,
`data/packs/colombia/maps/*.json`; built in `scripts/world/obstacle_field.gd`, walkers
in `scripts/world/street_life.gd`) often stand on the street with nobody at them.

- Every stall always has a vendor standing beside it (behind the cart, facing the
  street), on every map and every graphics level, day and night and in rain (rain may
  give them an umbrella; they never walk away).
- Reuse the existing pedestrian/passenger looks and instanced batches: no new draw
  call per vendor, no per-frame allocations. The vendor is not a walker and is not
  counted in the walker budget.
- A knocked stall: its vendor steps back out of the way and stays near it, never
  inside the bus or the cart.

Tests: every stall in every map gets exactly one vendor, placed on the pavement
within 2 m of the stall; still one after a rain toggle and at LOW quality; a knocked
stall's vendor is not inside the stall or the road.
```

## 10. Try drivers on before buying, like the buses

Difficulty: Medium. Strong model.

```
Feature: on the Drivers tab (`scripts/ui/main_menu.gd`, `_drivers_tab()`,
`DriverPreview` in `scripts/ui/driver_preview.gd`), tapping any driver row, owned or
not, shows that driver in the turning preview, the same way the Garage lets you try
a bus or livery before buying (`_garage_row`, which uses `TouchScroll.on_tap`).

- Tapping the row previews; only the Buy/Select button buys or selects. A drag to
  scroll never previews or buys (follow the Garage pattern).
- The preview names the driver shown and, when it is not owned, its price or level.
- Leaving the tab or selecting goes back to showing the selected driver.

Tests: tapping a locked driver's row changes the preview without spending coins or
changing the selection; the Buy button still buys; a drag does neither.
```

## 11. Forehead shows through the hair when the menu driver spins

Difficulty: Medium. Strong model (mesh/depth issue).

```
Bug: on the Drivers tab the preview head turns slowly, and at some angles the skin of
the forehead shows through the hair (z-fighting or the hair shell being too close
to / inside the head). Driver meshes come from `scripts/world/head_parts.gd` and
`DriverLook` (see `scripts/ui/driver_preview.gd`, `driver_badge.gd`).

- Find the cause (hair shell offset, winding/culling, transparency sort, or depth
  precision at the preview camera's near plane) and fix it at the source so every
  hair style on every driver is solid from all angles, in the menu and in the cab.
- Don't just shrink the head or hide the forehead.

Tests: for every driver look and hair style, sample points on the hair's front edge
from 16 angles around the head and assert the hair surface sits at least a few
millimetres outside the skull surface; include a regression case for the style that
showed the glitch. Take a screenshot of the Drivers tab at three angles and look at it.
```

## Owner feedback (12 Nov, night)

Run 12 to 16 one at a time, in order, like the others. 12 and 16 both touch
`scripts/traffic/`, so never run them together.

## 12. Willys jeeps in Alto Cafeto traffic

Difficulty: Medium. Strong model for the mesh and batch code, light model for map data.

```
Feature (Alto Cafeto doc task 4, `design/alto-cafeto.md` section 6 "Task 4"): the
mountain town's traffic should include Willys-style utility jeeps ("yipaos") in
place of some sedans.

- Add a low-poly jeep in `scripts/world/obstacle_field.gd` next to the car mesh
  (`_mesh_for("car")`): flat bonnet, round headlights, rear spare tyre, roll bar,
  colourful rear canopy, maybe a few plantain bunches or coffee sacks in the back.
  Same footprint class as a car (fits `TrafficAgent` CAR_HALF_LENGTH/WIDTH or adds
  its own half extents if longer). Original design, no brand badges or names.
- Traffic (`scripts/traffic/traffic_system.gd`, the car batch, around
  `_build_car_batch()`) reads an optional map field, e.g. `"vehicle_mix": {"jeep": 0.4}`,
  and turns that share of cars into jeeps, seeded so a run is repeatable. Set it
  in `data/packs/colombia/maps/alto_cafeto.json` only. Jeeps use one extra
  MultiMesh at most (one draw call), no per-frame allocations, and keep working
  with the patrol car, hits, honks, lights and LOW quality.
- Puerto Marisol must not change at all: no `vehicle_mix`, same cars, same random
  sequence (don't draw extra random numbers when the field is missing).

Tests (GUT, `test/unit/test_traffic.gd` or a new file): Alto Cafeto spawns some jeeps
and roughly the configured share; Puerto Marisol spawns none and its car layout is
identical to before; the jeep mesh builds with sane extents (within the car footprint
or its declared one). Take a screenshot of Alto Cafeto traffic and look at it.
```

## 13. Carrera Express: a tighter time scramble

Difficulty: Medium. Strong model for the rules, light model for data and strings.

```
Owner feedback: the arcade mode, Carrera Express, is now too easy. Owner's choice:
make it a tighter time scramble, not difficulty settings. Its rules are in
`scripts/arcade/arcade_run.gd` / `arcade_system.gd` and
`data/packs/colombia/routes/arcade.json`; its last tuning is in DECISIONS.md (75 s
start, +22 s per arch, -2 s per crash, 3.4 m boost pads, handling 1.3).

- The clock tightens over the run: each arch adds less time than the last (e.g.
  start around +20 s and drop by about 1 s per arch to a floor near +9 s), and
  crashes cost more (about -4 s). Start time around 60 to 65 s. Keep the wider pads
  and handling help so it stays fair, not punishing.
- A few more obstacles appear as the run goes on (cones/barrier sets from the
  existing knockable kinds on the course ahead, more of them every few arches),
  placed in the lane but always leaving a clear way through, never on a pad or
  under an arch.
- Put every number in data (arcade.json) so it can be tuned without code. Show the
  arch bonus in the existing "+N s" pop so the player sees it shrinking. Scoring
  stays checkpoints; existing best scores are kept.
- Aim: a decent driver reaches about 10 to 14 arches; the run should feel frantic by
  arch 8. Use the autopilot or a scripted run to check the numbers and report them.

Tests: arch bonus shrinks per arch and stops at the floor; crash penalty applied;
obstacle count grows with arches and none sits on a pad, an arch or blocks the
whole road; normal shifts unchanged. Record the new tuning in DECISIONS.md.
```

## 14. Cheats back on for testers (temporary)

Difficulty: Small. Light model is fine.

```
The hidden cheats still exist (`scripts/progression/cheats.gd`, `scripts/ui/cheat_panel.gd`,
seven taps on the menu title; seven taps on the pause title for skip stop / finish
shift in `scripts/ui/settings_panel.gd`), but `Cheats.available()` is
`OS.is_debug_build()`, so Play testers on the release build never get them. The owner
wants testers to try every setting and unlock without grinding, for now.

- Add ONE switch that turns cheats on in release builds too, e.g. a project setting
  `buseta/testing/cheats_in_release` (default true for now) read by
  `Cheats.available()` (still always on in debug builds). One line to flip back.
- Make sure the panel reaches everything: add "Max level" (unlocks every time of day,
  Alto Cafeto's level 6, the arcade's level 2) and check "Unlock all" covers every
  catalog kind including decorations, horns, drivers and routes with `requires`.
- `tools/build_release.sh` prints a clear warning when the switch is on.
- README "Hidden cheats" section: say how to turn them off before release.
- Record it in DECISIONS.md and add a row "Turn cheats off before public release"
  to PROGRESS.md.

Tests: with the switch on, `Cheats.available()` is true in a non-debug check (make the
release check injectable); off, it is false outside debug; "Max level" and "Unlock
all" leave nothing locked by level or ownership.
```

## 15. A recurring ambient noise is too frequent

Difficulty: Small. Light model is fine.

```
Owner feedback: a recurring background noise plays too often; it is hard to tell
whether it is a plane or a vehicle. Diagnosis (done): it is the "motorbike" one-shot
ambience layer in `data/packs/colombia/pack.json` (`motorbike_pass.wav`, made by
`tools/sound_kit/ambience.py`): a 3.2 s buzz with a falling Doppler note, rule
"always", not positional, played every 6 to 16 s. With no bike in sight it reads as
a passing plane or an unseen vehicle, and it also plays in Alto Cafeto.

- Make it rarer: `every` about [35, 80] s, and a little quieter (about -15 dB).
- Don't play it within ~10 s of a real traffic moto passing near the bus if that is
  easy to know; otherwise skip this point.
- Leave the other layers alone. Don't regenerate the wav (no `tools/sound_kit` run
  needed); never commit `tools/sound_kit/__pycache__`.

Tests: the pack's motorbike layer gap is at least 30 s; the mixer's one-shot
scheduler never plays it twice within its minimum gap over a simulated 10 minutes.
```

## 16. Smarter traffic: find and fix the dumbest stuck behaviour

Difficulty: Medium to Hard. Strong model.

```
Owner feedback: make traffic cars smarter. The traffic AI is in `scripts/traffic/`
(`traffic_flow.gd` rules: junction and roundabout yielding, passing a stopped bus,
waiting; `traffic_agent.gd` driving; `traffic_sense.gd`). Agents are spawned once and
never recycled, and there is no deadlock breaker, so a mutual yield at a junction or
a jam on a roundabout can leave cars stopped for good.

1. Measure first: write a headless soak test (GUT, no rendering) that runs the
   traffic system on Puerto Marisol and Alto Cafeto at the highest traffic count for
   5+ simulated minutes, with the bus parked in a few awkward spots (in a junction, at
   a roundabout entry, in a stop bay), and logs every agent stopped for over 20 s
   while not at a red light and not queued behind the bus. Report what you find.
2. Fix the one or two worst causes, for example:
   - a tie-breaker so two or more cars yielding to each other never wait forever
     (e.g. after a few seconds with nobody moving, the one with priority by lane or
     index goes);
   - a car stuck over ~30 s that is out of the camera's view and over ~60 m from the
     bus is quietly moved to a free spot on another lane.
   Keep the existing behaviour tests passing (`test/unit/test_traffic*.gd`). Seeded,
   no per-frame allocations.

Tests: the soak test asserts no agent is stuck over 30 s (outside red lights and
queues behind the bus); a unit test builds the deadlock case and shows it clears.
State in DECISIONS.md what was found and changed.
```
