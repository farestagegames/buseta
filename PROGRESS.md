# Overnight progress (game now "Buseta Simulator: Colombia")

Restore points: tag `milestone-pre-overnight` on `main`, and `milestone-pre-colombia-pivot`
on `overnight`, taken just before the game was refocused on Colombia. All work is on
`overnight`.

## Done before the pivot

| Item | State | Tag | Notes |
| --- | --- | --- | --- |
| Driver selection | Done | `milestone-drivers` | 8 drivers, cockpit hands and mirror. Reworked for Colombia in item 5 below |

## Revised backlog after the pivot

| # | Item | State | Tag | Notes |
| --- | --- | --- | --- | --- |
| 1 | Country packs | Done | `milestone-country-packs` | Colombia pack, left-hand Testland fixture, autopilot drove a full left-hand shift |
| 2 | Colombian city | Done | `milestone-colombian-city` | Puerto Marisol: coast, palms, colour, stalls, bunting, pedestrians, motorbikes, taxis, more bumps and potholes |
| 3 | Colombian buses and liveries | Done | `milestone-colombian-buses` | Buseta starter, B10, busetón, chiva, articulated with real joint physics, 11 patterned liveries, garage try-on. The articulated drives in item 4 |
| 4 | Colombian gameplay | Done | `milestone-colombian-gameplay` | Hail-anywhere routes, La Ola rapid-transit line, vendors, peso fares, stop requests |
| 5 | Drivers and passengers | Done | `milestone-colombian-people` | 10 Colombian drivers (coastal, Afro-Colombian, Andean, Wayuu), 20 passenger looks plus 2 vendors, all in data. Reviewed for respect; fixes made: a driver renamed after a name clash with a real crime figure, one portrait redrawn |
| 6 | Language | Done | `milestone-colombian-language` | Colombian Spanish is the default (English phones get English), every string reworded in coastal Colombian Spanish and reviewed, all visible text checked by a test, text fits at 1280, 1560 and 1600 wide |
| 7 | Audio | Done | `milestone-colombian-audio` | 5 original horns (choose in the Garage), 8 street-sound layers mixed by place, RADIO with 3 fictional stations of original generated music, radio volume slider, rain hook. Not yet listened to on a phone |
| 8a | Day/night and rain | Done | `milestone-day-night-rain` | Five times of day (unlock by level, picked on the Routes tab), seeded aguaceros with wet road, grip, wipers, traffic gaps, umbrellas, bonus and achievements. Night lit without real city lights. Arroyos not done. Independent review skipped (usage limit); checked by the gate and screenshots only |
| 8b | Daily challenges and achievements | Done | `milestone-challenges` | 17 daily challenges (route, bus, time-of-day and count conditions, only offered once unlocked), daily streak bonus, 18 achievements with coin rewards and progress in Career, per-route and per-bus stats. Menu not checked by screenshot (display asleep); covered by the menu tests |
| 8c | iOS readiness | Done | `milestone-ios-ready` | iOS export preset (Xcode project, team id left blank), no Android-only calls (tested), safe area for notch and home indicator (tested), IOS_PORT.md with what is left and how to build and sign. Never built for or run on an iPhone |
| 8d | Multiplayer research | Done | `milestone-multiplayer-research` | MULTIPLAYER.md compares Wi-Fi play, pass-and-play and share-code leaderboards; recommends pass-and-play then share codes. Prototype on branch `multiplayer-spike`, not merged |

## Requested during the day (7 Nov)

| Item | State | Notes |
| --- | --- | --- |
| Brake as a button | Done | Hold to brake: gentle at first, firmer the longer it is held |
| Clearer drive/reverse | Done | D and R switch with the gear in use lit, plus a tip when you try to change gear while moving |
| Menu scrolling | Done | Lists scroll from a drag anywhere, a drag never presses or buys, sliders only move sideways, scroll position kept after buying, notch-safe menu |
| Traffic awareness | Done | Cars and motos see the bus and its trailer, brake smoothly for obstacles, wait or pass a stopped bus only when the other side is clear, yield at junctions, stop for a reversing bus |
| Batch of 9 Nov | Done | Cars recover after hits and honk; door camera clear of walls; hail prompt says how far; radio louder than the street; salsa station plus more vallenato and champeta; Easy/Normal/Hard with transit police and fare dodgers; Ruta Libre endless route; rear exit door; arcade mode Carrera Express |

## Google Play release (11 Nov)

| Item | State | Tag | Notes |
| --- | --- | --- | --- |
| Release build | Done | `milestone-release-build` | Signed AAB from `sh tools/build_release.sh` (Gradle template, upload key in `~/Keys`, password from env/Keychain/prompt). RELEASE.md covers key backup, version bumps and the Play Console steps. Nothing uploaded yet. Next: back up the key, internal then closed testing (12 testers, 14 days) |
| Launcher icons | Done | | Original buseta icon from `tools/make_icons.py`: adaptive layers, monochrome themed icon, legacy 192 px, `store/icon_512.png` for the listing. Not yet seen on a phone's home screen |
| Store prep | Done | | Renamed "Buseta Simulator: Colombia" (privacy page must be re-uploaded to GitHub). Listing text es-419 and en-US, feature graphic, 8 Spanish screenshots, privacy policy (filled in, not yet hosted), Play Console form answers. All in `store/`. Target age 13+ confirmed. Owner to do: skim in-game slang, paste the privacy URL into Play Console (https://callenomad.github.io/city-bus-shift-privacy/) |
| Play testing | In progress | | 0.1.0 (code 1) uploaded to Internal testing (11 Nov). Owner steps in `store/testing-plan.md`: add tester list, roll out, install from the opt-in link, check icon, menu title and a short drive; then a closed track via a Google Group for 12+ testers for 14 days, with es/en invite drafts. Still to do: re-upload the privacy page (old name), back up the upload key off this Mac |
| Turn cheats off before public release | Todo | | Task 14 leaves `buseta/testing/cheats_in_release` true so Play testers get the hidden cheats; set it to false in `project.godot` before the public release (the release build warns while it is on) |

## Engagement batch and feedback fixes (12 Nov, in progress)

Prompts in `delegation/opencode-prompts.md`, run in order by the owner with opencode.

| # | Item | State | Notes |
| --- | --- | --- | --- |
| 1 | Tutorial ring offset on phone | Done | Ring uses global-to-local coords, refreshes on resize after layout settles; phone-size HUD ring test added. Not checked on a phone |
| 2 | Birds near trees only (3D sound plus flocks) | Done | `00bb2f6`. Not checked on a phone |
| 3 | Two short starter routes | Done | `e28780b`. 2 new routes, unlock chain, fresh profile and save tests, autopilot A 238 s and B 356 s |
| 4 | 3 route goals = 3 stars | Done | Goals on all routes, 3-star goal scoring, HUD/menu/results goal UI, 0-5→0-3 save migration, challenges/achievements updated |
| 5 | Feedback at every stop | Done | Fare pop/clink, perfect-stop stamp/chime/bounce, StopQuality rule and perfect-stop counts in reports |
| 6 | Payout screen | Done | Coin breakdown (fares/tips/clean/on-time/fines) counts up, stars pop with goal names, XP bar + level burst, next-unlock bar, next-route/retry + menu buttons, tap to skip under 6 s |
| 7 | Unlock every 1 to 2 shifts, cab decorations | Done | `overnight` | Liveries and horns re-cost/gated from autopilot averages (~438 coins/shift on starters and Route 1); 7 cheap cab decorations (one free) shown in cockpit and garage try-on; "Próximo desbloqueo" on the menu and exposed for the results screen. Existing saves keep purchases and coins. Not checked on a phone |
| 8 | First-time banners tied to achievements | Done | `firsts.json`, confetti celebration banner, profile-saved firsts, live achievement/first unlocks, and celebration tests |

| 9 | Owner feedback: arcade access and motorbikes | Done | `6af4597` Carrera Express button on Home (level 2, New! badge, best checkpoints) and a more forgiving arcade; then the moto fix (hits slow the bus and shove the rider aside, on every route). Regression test at boost speed. Not checked on a phone |
| 10 | Owner feedback: motos through boarding passengers, slow stops | Done | Traffic keeps out of a strip beside an open-door bus; boarding runs alongside alighting. Not checked on a phone |
| 11 | Owner feedback: Carrera Express tighter time scramble | Done | Arcade clock now tightens (62 s start, arch bonus 20 s shrinking 1 s per arch to a 9 s floor, crash −4 s, arches every 150 m) and cone/barrier sets appear every few arches, clear of pads and arches and always leaving a clear way; every number in `arcade.json`. Not checked on a phone |

**Resume here:** all eight engagement tasks are done. On the phone still to check: the Carrera Express Home button and the arcade's feel, hitting a motorbike (bus should jolt and slow, rider thrown aside), motos waiting while people board, boarding during alighting, the tutorial ring, the birds, Starter A as the first route, the 3-goal checklist, stop feedback placement/feel, cab decorations in cockpit, the next-unlock line, the payout sequence, and first-time/achievement celebration banners. Play: internal testing installed on the owner's phone (12 Nov); closed track, privacy page re-upload and key backup still to do (`store/testing-plan.md`).

## Next: second map, Alto Cafeto (planned 12 Nov)

Fictional coffee-region town, small district (2 to 3 routes incl. a ~3 min starter), unlocks at driver level 6. Design doc by agy (Gemini) in `design/alto-cafeto.md`, concept art in `design/alto-cafeto/` (`.gdignore`, not in the game). Owner approved the doc as written (12 Nov). Main risk: slopes over ~14% stall the starter buseta.

| # | Task | State | Notes |
| --- | --- | --- | --- |
| 1 | Playable slice: map, starter route C0, level 6 unlock, menu | Done | `maps/alto_cafeto.json` (doc layout ×1.4, retuned hills, max grade 11.1%), `routes/cafeto_c0.json` "Vuelta al Pueblo" (out and back, U-turn at the Plaza roundabout, 3 goals), catalog level 6, Routes tab grouped under town headings. Autopilot 4:11, no stall, 1 slow moto bump at the El Cafetal bay exit. Plain houses and normal traffic for now. Not checked on a phone or by menu screenshot |
| 2 | Church and mirador landmarks | Done | Map `landmarks` list (kind, x, z, face node). Church south of the Plaza roundabout facing it: whitewashed nave, clay-tile gable, bell tower with open arched belfry and bell, tiled spire, no cross. Mirador 34 m north of node `e`: octagonal plank deck on posts, rails, 3 benches, coin telescope, steps towards the road. Both in the scenery batch (draw calls unchanged), clear of roads/bays/pavement, houses keep clear. 4 GUT tests. Screenshots looked at |
| 3 | Willys jeep traffic | Done | | Doc task 4. `vehicle_mix: {"jeep": 0.4}` on the map, jeeps in one extra MultiMesh, seeded; Puerto Marisol unchanged. Screenshot captured, not seen on a phone |
| 4 | Routes C1 Mirador and C2 Las Lomas | | Doc task 5. Doc's stop "along" values need re-placing for the ×1.4 scale and 52 m bays |
| 5 | District switcher on the Routes tab | | Doc task 6, once there are 3 routes |
| 6 | Fog and mountain ambience | | Doc task 7 |

Dropped by the pivot: the boost/arcade level and the old map expansion. See DECISIONS.md.
