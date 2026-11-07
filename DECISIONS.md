# Decisions made without you

One line each, with the reason. Newest at the bottom.

- Boost/arcade level goes after item 7 and before item 8: it was added after the list was written, and this keeps your order intact.
- Eight drivers, with two free and six costing 300 to 1,200 coins: enough variety without the price competing with routes.
- Drivers are cosmetic only: a perk would make a coin purchase affect the fairness of the score.
- In the cockpit the driver is shown by their hands on the wheel and their face in a new interior mirror: the body has to stay hidden or it blocks the view.
- Added a sixth menu tab, Drivers, and renamed Driver to Career: selection and career stats are different jobs.
- Added tools/gate.sh so every item is checked the same way before it is committed.
- Pivot to Colombia received mid-night. Stopped before starting liveries, tagged `milestone-pre-colombia-pivot`, and replaced the remaining backlog as you asked.
- Boost/arcade level is off tonight's plan: your revised backlog replaces the remaining items and does not list it. It is not rejected, so ask if you want it back.
- Old map expansion is off the plan: the Colombian city rework replaces it.
- The city is called Puerto Marisol, from "mar y sol": it sounds Caribbean and no real Colombian city has that name as far as I know.
- Money keeps its internal unit, and each pack sets how much one is worth. In Colombia one coin shows as $100, so a route at 500 reads $50.000 and a fare can be a real-looking $2.900.
- Packs live in `data/packs/<country>`, and the left-hand test pack lives in `test/fixtures` so it never ships.
- Colombia keeps all six languages until item 6, so the game stays playable in the meantime.
- Did the file part of the language item early: it saved translating every new string into four languages that were about to leave the game. French, Portuguese, Hindi and Arabic are kept in `data/lang/archive` and their fonts stay in the repo, but neither ships in the APK.
- Sea to the east, with the old river road becoming the Malecón: it was already the edge of town and gave the city a coast without moving a road.
- Speed bumps went from 2 to 4 for the Colombian feel, keeping the warnings you asked for. Potholes went from 4 to 14.
- Street stalls can be knocked over and cost points, but no vendor stands at them: a person flying through the air is not the warmth you asked for.
- A hit motorbike stays upright and the rider just stops. It counts as a collision, with nothing shown that could be read as an injury.
- Cars include many yellow taxis, as in Colombian cities.
