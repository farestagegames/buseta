# Overnight progress

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
| Store prep | Done | | Listing text es-419 and en-US, feature graphic, 8 Spanish screenshots, privacy policy draft (placeholders to fill, not published), Play Console form answers. All in `store/`. Owner to check: target age 13+, a skim of in-game slang, hosting the privacy page |

Dropped by the pivot: the boost/arcade level and the old map expansion. See DECISIONS.md.
