# agy (Antigravity) prompts: more maps (12 Nov, night)

Owner's choice: finish Alto Cafeto (doc tasks 5 to 7), then design and build a
third town's playable slice without waiting for doc approval. Run them one at a
time on `overnight`, after opencode tasks 12 to 16, never alongside another agent
(one checkout, one Godot process). Paste the shared rules from
`opencode-prompts.md` at the top of each prompt, with the "Agents and models"
paragraph left out.

## A1. Alto Cafeto routes C1 Mirador and C2 Las Lomas

```
Alto Cafeto doc task 5 (`design/alto-cafeto.md`, sections on Route C1 "Ruta del
Mirador" and Route C2 "Circuito Las Lomas"; C0 is already `routes/cafeto_c0.json`).

- Add `data/packs/colombia/routes/cafeto_c1.json` and `cafeto_c2.json` following
  `cafeto_c0.json`. The map was scaled x1.4 from the doc (see DECISIONS.md), so
  re-place every stop's "along" value on the real roads and keep each 52 m bay clear
  of junctions, landmarks (church, mirador) and other bays.
- Catalog: level 6 like C0; C1 requires C0; C2 costs 1,200 coins (doc). Three goals
  each, time goals about 25% over the autopilot's time.
- Run `tools/autopilot.sh` on both and report time, collisions and any stall on
  grades (max grade is 11.1%). Fix stops or the route, not the hills.

Tests: both routes load, every stop sits on its road with a clear bay, unlock chain
works, goals score.
```

## A2. District switcher on the Routes tab

```
Alto Cafeto doc task 6. Alto Cafeto now has 3 routes. In `scripts/ui/main_menu.gd`
`_routes_tab()`, replace the town headings with a segmented row (Puerto Marisol /
Alto Cafeto) that filters the list. A locked town (driver level under 6) shows a
lock and "Nivel 6", and can be viewed but not played. Remember the chosen town in
the profile. Follow the existing TouchScroll tap/drag rules; buttons at least 48 px.
New strings in both lang files.

Tests: filtering, lock badge below level 6, choice persists, a drag never switches.
```

## A3. Fog and mountain ambience in Alto Cafeto

```
Alto Cafeto doc task 7. Morning and dawn fog x1.35 on Alto Cafeto only (map or
theme data, via `CityTheme.fog` / `TimeOfDay.fog_scale`), no change to Puerto
Marisol. Bird clusters near the coffee groves using the existing positional bird
system. No sea layer there; a quieter street bed; keep the one-shot "motorbike"
ambience rare (see task 15). Frame time must not get worse on the performance test.

Tests: Alto Cafeto fog is 1.35x at dawn/morning and unchanged elsewhere; no sea
layer on the map; bird clusters valid. Screenshot dawn on both maps and look.
```

## A4. A third town: design note and playable slice

```
Design and build a third fictional Colombian town as a playable slice, like Alto
Cafeto task 1. Pick a region that adds something new to drive (e.g. a Magdalena
river port with a ferry ramp and a long bridge, or a Llanos plains town with long
straights and cattle trucks). Fictional names only, no real businesses, nothing
religious or political as a set piece, no crime or poverty stereotypes.

1. Write `design/<town>.md` (short: pitch, layout, what's new for the player,
   starter route, unlock level, risks) like `design/alto-cafeto.md`.
2. Build `data/packs/colombia/maps/<town>.json` and one starter route (about 3 min,
   3 goals), unlocked at a driver level after 6, grouped under its own town on the
   Routes tab / district switcher. Plain houses and normal traffic are fine.
3. Run the autopilot and report time and bumps.

Tests: map integrity (connected roads, grades under 12.5%), the route loads and
scores, the town's lock level works. Puerto Marisol and Alto Cafeto unchanged.
```
