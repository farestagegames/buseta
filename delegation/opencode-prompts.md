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
