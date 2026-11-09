# Morning report

Everything is on the `overnight` branch; `main` is untouched. The restore point
before any of this is the tag `milestone-pre-overnight`, and
`milestone-pre-colombia-pivot` is the state just before the Colombia refocus.
There is no Git remote, so nothing was pushed. Every item below passed the
quality gate (all tests plus an Android APK under 150 MB) before it was
committed. Final state: 711 tests, APK 33 MB.

## Completed, with tags

| Item | Tag |
|---|---|
| Driver selection (before the pivot) | `milestone-drivers` |
| 1. Country packs (Colombia pack, left-hand Testland test pack) | `milestone-country-packs` |
| 2. Puerto Marisol, a Caribbean coastal city | `milestone-colombian-city` |
| 3. Colombian buses and decorated liveries | `milestone-colombian-buses` |
| 4. Hail-anywhere routes, La Ola busway, vendors, pesos | `milestone-colombian-gameplay` |
| 5. Colombian drivers and passengers | `milestone-colombian-people` |
| Your requests: hold-to-brake button, D / R switch | (commit after `milestone-colombian-people`) |
| 6. Colombian Spanish first, English second | `milestone-colombian-language` |
| Your requests: menu scrolling, smarter traffic | `milestone-menus-and-traffic` |
| 7. Horns, street ambience, radio with original music | `milestone-colombian-audio` |
| 8a. Times of day, night, tropical downpours | `milestone-day-night-rain` |
| 8b. Conditional daily challenges, streaks, rewarding achievements | `milestone-challenges` |
| 8c. iOS readiness (preset, tests, IOS_PORT.md) | `milestone-ios-ready` |
| 8d. Multiplayer research (MULTIPLAYER.md) | `milestone-multiplayer-research` |
| 8d. Pass-and-play prototype | branch `multiplayer-spike`, not merged |

## How to test on your phone

Install `build/city-bus-shift-debug.apk`. The hidden cheats still work: tap the
"City Bus Shift" title seven times on the main menu for money and levels, or
the "Pausa" title in the pause menu to skip a stop or finish the shift.

- **Language:** starts in Colombian Spanish unless the phone is in English.
  Switch under Configuración > Idioma.
- **Controls:** hold FRENO (brakes harder the longer you hold); tap D or R on
  the gear switch; try R while moving to see the tip.
- **Menus:** drag lists starting on a button or slider; a drag should never buy
  or select anything.
- **Traffic:** stop at the kerb on Route 1 and watch cars wait, then pass when
  the other side is clear; motorbikes squeeze by.
- **Drivers tab:** ten Colombian drivers with short bios.
- **Garage:** Pito section with ▶ previews; La Chiva unlocks at level 5.
- **Radio:** RADIO button cycles three fictional stations. Please listen with
  sound on; I could only measure the audio, never hear it.
- **Times of day:** Routes tab. Sunset unlocks at level 2, dawn at 3, night at
  4 (use the cheat). In the pause menu cheat row, "Downpour now" starts an
  aguacero: wipers in the cockpit view, longer braking, slower traffic.
- **Challenges:** Home shows today's challenge and your streak; Career shows
  each achievement's progress and coin reward.
- **Pass-and-play** (spike APK `build/city-bus-shift-spike.apk`): Home > Pass
  and play > 2 players, then hand the phone over between shifts.

## Broken, skipped or unfinished

- **Not checked on a real phone:** frame rates, night and rain cost, audio mix,
  notch handling. All numbers come from a desktop M2.
- **Day/night and rain skipped its independent review** (usage limit). It was
  checked by the gate, the autopilot and my look at the screenshots only.
- **Challenges screen** was not checked by screenshot (the Mac display was
  asleep); the menu tests build every tab.
- **Not built:** arroyos (flooding streets), puddles and splashes, passengers
  sheltering in rain; typed player names in pass-and-play.
- **iOS** has never been built: no iOS export templates here, and signing needs
  your Apple account. IOS_PORT.md lists every remaining step.
- **Known small issues:** at 1280 wide the garage preview cuts off the end of
  long buses; the tutorial box can cover a penalty toast; the intro line says
  "seven stops" on longer routes; `PlayerProfile.from_dict` errors on a
  non-true/false `intro_done` in a hand-edited save.
- **No app icon** yet on Android or iOS.

## Decisions made without you

All are in DECISIONS.md, one line each with the reason. The bigger ones:

- City name Puerto Marisol; fictional bus brands Caimán and Alcatraz; La Ola as
  the fictional busway.
- Money shown as Colombian pesos ($2.900 fare), 100 pesos per coin.
- Two drivers renamed after name searches found real people in crime news.
- Game title stays "City Bus Shift" in Spanish too; Career tab is "Progreso".
- Brake is hold-to-firm-up (gentle first, full after 1.5 s).
- Five horns and three fictional radio stations, all generated in code (CC0).
- Times of day unlock at levels 1 to 4; rain chance is highest at sunset.
- Rain cuts grip by 30% and gives 20% more timetable slack and a coin bonus.
- Daily challenges only offer what you own; streaks add up to 200 coins.
- iOS preset exports an Xcode project with no account details.
- Recommended multiplayer: pass-and-play, then share codes; Wi-Fi play later.

## Recommended next steps

1. Play the latest APK on your phones, old and new: frame rate at night and in
   rain, sound balance, and the controls.
2. Decide on the multiplayer spike: merge it, change it, or drop it.
3. Make an original app icon and pick the final game name.
4. Arroyos as a rain feature, then puddles and shelters.
5. If iOS matters soon: install the iOS templates and follow IOS_PORT.md on a
   Mac with Xcode.
6. When happy, merge `overnight` into `main`.
