# Multiplayer options

City Bus Shift is a single-player, offline game with no accounts and no
servers. The project rules also rule out paid services, new accounts and
analytics SDKs. This page compares three realistic ways to play with friends
within those limits, and recommends one.

## What the game already gives us

- **Seeded shifts.** A shift's hail stops and its weather (downpour or not, and
  when) come from one number, `CityShift.shift_seed`. Two players given the
  same seed, route, bus and time of day face the same stops and the same rain.
- **Traffic and passengers are already fixed.** Traffic (`TrafficFlow`, seed
  4242) and passenger destinations (`PassengerLedger`, `PASSENGER_SEED`) use
  fixed seeds, so they repeat too. Only street walkers and some sounds vary,
  which changes the look, not the shift.
- **A full score.** Every shift ends in a report: score out of 100, stars,
  punctuality, stopping accuracy, smoothness, traffic rules, passenger
  satisfaction and time. That is a fair thing to compare.

## Option 1: local Wi-Fi play

**The idea.** Two to four phones on the same Wi-Fi drive in the same city at
the same time. Each player drives their own bus on their own route and sees the
others as traffic. Variants: race the same route, or cooperate on a shared
timetable (one bus every five minutes, with a joint score for the line).

**Effort.** Large, about 4 to 6 weeks.
- Godot's high-level multiplayer (`ENetMultiplayerPeer` and
  `MultiplayerSynchronizer`) handles the connections. Finding each other on a
  local network needs a small broadcast on UDP, or the host shows an address
  and code to type in.
- Every other bus has to be synchronised and smoothed: position, heading, the
  trailer angle, doors and indicators, about 10 to 20 times a second.
- The city has to be the same on every phone: traffic, lights, passengers and
  weather. Either the host runs them and sends them out, which costs a lot of
  bandwidth for 30+ vehicles, or every phone runs them from the same seed and
  clock, which drifts unless it is fully deterministic.
- Collisions between players' buses, pausing (one player gets a phone call),
  someone leaving mid-shift, and timetable and score rules for two buses.

**Effect on the architecture.** Big. The bus, traffic and route systems assume
one local bus. `GameEvents` is a global signal bus for one player; it would
need to say whose bus each event is about. Physics runs at 60 Hz with
interpolation, which is fine locally but needs prediction and correction for
remote buses. The test suite and autopilot would need a two-player mode.

**Risks.** Older phones (which you plan to test on) running the city and the
networking together; Wi-Fi in a café or on a bus is often blocked between
devices; Android and iOS local network permissions (iOS asks the user, and
needs `NSLocalNetworkUsageDescription`).

## Option 2: pass-and-play challenges on one phone

**The idea.** "Who drives the route best?" Two to four friends take turns on
the same phone. Everyone drives the same shift: same route, bus, time of day,
and the same seed, so the same hails, traffic and downpour. After each turn
the phone is passed on; at the end there is a ranking with each player's score,
stars and best category, and a "rematch" button with a new seed. Optional
handicaps: a younger player gets the buseta and automatic recovery.

**Effort.** Small, about 2 to 4 days.
- A pure `PassAndPlay` session class: player names, the shared shift settings
  and seed, each player's result, whose turn it is, the ranking with tie breaks.
- A setup screen (names, route, bus, time), a "pass the phone to Ana" screen
  between turns, and a results screen.
- Rewards: give coins and XP to the phone's owner only, or none in this mode, so
  it cannot be used to farm coins.

**Effect on the architecture.** Small. A shift already starts from settings and
ends in a report. Pass-and-play just runs several shifts in a row with fixed
settings and collects the reports. No network, no new permissions, works
offline and on every phone.

**Risks.** It is only fun when friends are physically together, and a full
shift is 6 to 11 minutes per player, so a four-player round takes most of an
hour. Short "sprint" versions of the routes (two or three stops) would help.

## Option 3: friends' leaderboard of shift scores

**The idea.** See how your best scores compare with your friends'. The usual
way is an online leaderboard, but that needs a server and accounts (or Google
Play Games and Game Center, which are accounts too). Within the project rules,
the version that works is **share codes**: after a good shift the game makes a
short code such as `PM-T1-7F3K-92-A8Q4` holding the route, bus, time, seed,
score, stars and a checksum. You send it to friends through any chat app. When
a friend types or pastes it in, the game adds it to their "friends" board and
offers "drive this exact shift", which loads the same seed so they can try to
beat it.

**Effort.** Medium, about 1 to 2 weeks.
- Encoding and decoding the code, with a checksum against typos.
- A friends' board in the Career tab, stored in the save.
- "Drive this shift" reuses the seeded start from option 2.
- Sharing through the phone's share sheet needs a small native call on each
  system; copying to the clipboard works everywhere with `DisplayServer.clipboard_set`.

**Effect on the architecture.** Small to medium. The same seeding as option 2,
plus a stored list in `PlayerProfile` (with save-compatibility like the other
fields), plus a code format to keep stable across versions.

**Risks.** Codes can be faked. With no server, a checksum only catches typos,
not cheating; this suits friends, not a public ranking. If a real online board
is wanted later, it needs a server and accounts, which this project rules out
for now.

## Comparison

| | Wi-Fi play | Pass-and-play | Share-code board |
|---|---|---|---|
| Effort | 4–6 weeks | 3–5 days | 1–2 weeks |
| Architecture change | Large | Small | Small to medium |
| Needs network | Local Wi-Fi | No | No (codes go through any chat app) |
| Needs accounts or servers | No | No | No |
| Works on older phones | Doubtful | Yes | Yes |
| Fun alone | No | No | Yes, against friends' codes |
| Fun together | Very | Yes | Some |

## Recommendation

**Build pass-and-play first, then share codes.** Both rest on the same
foundation: a shift that can be replayed exactly from a seed. That foundation
also helps testing and the daily challenges (a shared "shift of the day" seed).
Pass-and-play is the cheapest real multiplayer and works on every phone; share
codes then let friends compete when they are apart, still with no servers.
Leave Wi-Fi play until the game has an audience asking for it; it costs about
ten times as much and changes the core architecture.

## Prototype

A small prototype of pass-and-play is on the branch `multiplayer-spike`. It is
not merged into `overnight`. See its `SPIKE.md` for what it does and what it
leaves out.
