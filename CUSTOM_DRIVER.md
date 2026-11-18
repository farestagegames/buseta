# Custom driver: design (owner interview, 18 Nov)

Looks only. A custom driver has no effect on driving, score or XP.

## Slots
- Custom drivers open at level 10, with one slot. A second slot opens at level 20 and a third at level 30. Keep these levels in config, because they may change.
- The 10 hired drivers stay. The CHOFER tray shows custom slots first, then hired drivers. An empty open slot shows a "Crear chofer" card, and a locked slot shows a padlock and its level.
- When the player creates a driver they type its name once. Renaming needs a **name tag** (Placa de nombre), which is used up on use. Name tags come from the coin shop (around 500 coins) and as a level-up reward every 5 levels from level 15.

## Parts
The parts reuse `DriverLook`, `DriverFigure` and `HeadParts`.
- **Cara / Pelo:** skin tone, hair style, hair colour, beard, greying.
- **Camisa:** polo or guayabera, shirt colour, trim colour.
- **Sombrero:** none, cap, vueltiao, headwrap, hard hat or sun hat, plus an accent colour.
- **Extras:** glasses, earrings, towel, plus the new special items below.

## Unlocking
- **Free at level 10:** every skin tone, a few hair styles (short, fade, bob, curly and a few more), basic hair and shirt colours, the polo, and no hat.
- **Everything else** is earned. Ordinary parts come from levels and the coin shop: more hair styles, beards, the guayabera, the hats, glasses, earrings, the towel and more colours. Once unlocked, an ordinary part is free for every custom driver.
- **Special items** are new, themed, one per route. Each route's item is given the first time that route is finished at level 10 or above. Routes the player already finished pay out when the editor first opens. A 3-star finish gives a bonus colour or a second item. Ideas: a Junior FC-style shirt (an original design), a gold chain, aviator sunglasses, a rosary, a vueltiao with a tricolour band, a coffee grower's poncho for the Alto Cafeto routes, and so on.
- **Inventory:** only special items count. Each copy can be worn by one custom driver at a time; wearing it on another driver takes it off the first. Extra copies can be bought with coins in the editor's shop. Ordinary parts are not limited.
- Unlocks show as cards on the existing "¡Desbloqueado!" queue (`UnlockNews`).

## Editor
- A full cartoon page (`MenuCartoon`) with the driver's bust large on the roundabout stage. Tabs: Cara / Pelo / Camisa / Sombrero / Extras.
- Locked parts show a padlock and how to get them: "Nivel N", "Termina <ruta>" or the coin price.
- A small shop holds the extra copies of special items and name tags.

## Build notes
- Put the logic in pure, GUT-tested classes: slots by level, part unlocks, the inventory with its one-copy-per-driver rule, route payouts (including the back-pay), name tags, and save/load. Old saves must load.
- The save keeps custom drivers (name and look), owned parts, special item counts and name tags.
- The custom driver must work everywhere a hired driver does: the portrait, the cockpit hands, the 3D figure and the tray side card.
