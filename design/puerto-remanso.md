# Map 3 Design Document: Puerto Remanso (Magdalena River Port)

A third town for **Buseta Simulator: Colombia** (Godot 4.7.2 / GDScript), introducing a tropical river port on the lower Magdalena River with an elevated river bridge, a sloping ferry ramp, a riverside levee promenade, and flat riverbank cruising.

---

## 1. Town Name Options

1. **Puerto Remanso**: Evokes a peaceful expanse of deep, calm river water ("remanso") where riverboats moor and river trade thrives, while remaining completely fictional and respectful.
2. **Barranca Dorada**: Evokes golden silt bluffs and warm river sunsets characteristic of the Magdalena river basin (e.g. Barrancabermeja / Magangué), without naming real municipalities.
3. **Puerto Ceiba**: Highlights the majestic, shade-giving ceiba trees lining the riverfront plazas and canoe landings.

**Selected Pick**: **Puerto Remanso**. It communicates the river port setting instantly, sounds authentically Colombian, fits cleanly on UI buttons (`TownPuertoRemanso`), and provides an engaging contrast to coastal Puerto Marisol and mountain Alto Cafeto.

---

## 2. Feel & Gameplay vs. Existing Towns

| Dimension | Puerto Marisol (Coast) | Alto Cafeto (Coffee Andes) | Puerto Remanso (Magdalena River Port) |
| :--- | :--- | :--- | :--- |
| **Setting** | Caribbean coastal town with ocean beach and malecón. | High mountain ridge (+16m) with coffee groves, fog, and tight switchbacks. | Steamy tropical river port on the Magdalena with levee, bridge, and ferry ramp. |
| **Topography** | Flat coastal grid with gentle rolling swells (grades < 8%). | Extreme vertical terrain (8% to 11.1% grades), winding hairpins. | Elevated river levee (+3m) and arching bridge (+7m) spanning riverbanks; grades 4% to 8.8%. |
| **New Driving Elements** | Broad boulevards and tight 90° urban street turns. | Hill climbing, engine drag on steep descents, hairpin clipping. | High-speed cruise across long elevated bridge (50 km/h), gentle levee curves, and precision braking on the sloping ferry ramp. |
| **River & Water** | Wide Atlantic ocean with sandy surf. | Completely inland mountain terrain (`NO_COAST`). | Broad tropical river along the eastern edge with silt banks, river ferries, and riparian palms. |
| **Local Traffic** | Sedans, taxis, and urban motorbikes. | Willys jeeps ("Yipaos") and motorbikes. | Light river-port trucks, pickups, sedans, and motorbikes with relaxed traffic density (`traffic_share: 0.6`). |

---

## 3. Map Layout & Specifications

Puerto Remanso occupies approximately **440m x 300m** along the western bank of the river.

```
       [ h: Cruce Norte (+2m) ]====================[ g: Cabecera Norte (+3m) ]
                   |                                           /
                   |                                          /  Puente Fluvial (50 km/h)
                   | Avenida del Norte                       /   (Arches over water to +7m)
                   |                                        /
       [ i: Cruce Central (+3m) ]------------[ f: Cabecera Sur (+3m) ]
          /        |         \                            |
         /         |          \                           | Paseo de la Ribera
  [ j: Talleres ]  |           \ Calle Comercio           |
        |          |            \                         |
        |          |             \                        |
  [ b: Bodegas ]---|----[ c: Glorieta Central (+3m) ]---[ d: Cruce Ferry (+3m) ]
        |          |           (Roundabout)               |          \
        |          |                                      |           \ Rampa del Ferry
  [ a: Cruce ]     +--------------------------------------+            \
        |                                                               [ e: Embarcadero (-1m) ]
  [ depot: Patio Fluvial (0m) ]                                          (Roundabout at Water)
                                                          ~~~~~~~~~~~~~~~~ (Magdalena River)
```

### 3.1 Nodes
- `depot`: `{"x": -200, "z": 80, "kind": "terminal", "radius": 17}` — Patio Fluvial bus depot.
- `a`: `{"x": -130, "z": 80, "radius": 14}` — Cruce del Patio.
- `b`: `{"x": -40,  "z": 80, "radius": 14}` — Cruce Bodegas.
- `c`: `{"x": 60,   "z": 80, "kind": "roundabout", "radius": 20, "island": 8}` — Glorieta Central.
- `d`: `{"x": 160,  "z": 80, "radius": 14}` — Cruce Ribera (Top of Ferry Ramp).
- `e`: `{"x": 230,  "z": 80, "kind": "roundabout", "radius": 18, "island": 6}` — Glorieta del Embarcadero (Ferry slip at river water).
- `f`: `{"x": 160,  "z": -40,"radius": 14}` — Cabecera Sur del Puente.
- `g`: `{"x": 160,  "z": -180,"radius": 16}` — Cabecera Norte del Puente.
- `h`: `{"x": 60,   "z": -180,"radius": 14}` — Cruce Norte (Camino de las Garzas).
- `i`: `{"x": 60,   "z": -40,"radius": 14}` — Cruce Comercial Norte.
- `j`: `{"x": -40,  "z": -40,"radius": 14}` — Sector Talleres.

### 3.2 Roads
- `depot_road`: `depot` -> `a`, 30 km/h, traffic: false, `"Carrera del Patio"` (70m).
- `calle_bodegas`: `a` -> `b`, 30 km/h, `"Calle de las Bodegas"` (90m).
- `carrera_muelle`: `b` -> `j`, 30 km/h, `"Carrera del Muelle"` (120m).
- `calle_talleres`: `j` -> `i`, 30 km/h, `"Calle de los Talleres"` (100m).
- `avenida_fluvial`: `b` -> `c`, 40 km/h, `"Avenida Fluvial"` (100m).
- `carrera_central`: `c` -> `i`, 40 km/h, `"Carrera Central"` (120m).
- `carrera_mercado`: `c` -> `d`, 30 km/h, `"Carrera del Mercado"` (100m).
- `rampa_ferry`: `d` -> `e`, 30 km/h, `"Rampa del Ferry"` (70m, descending to water).
- `paseo_ribera`: `d` -> `f`, 40 km/h, `"Paseo de la Ribera"` (120m, alongside river).
- `calle_puerto`: `i` -> `f`, 30 km/h, `"Calle del Comercio"` (100m).
- `puente_fluvial`: `f` -> `g`, 50 km/h, via: `[[175, -110]]`, `"Puente Fluvial"` (143m elevated causeway).
- `camino_garzas`: `g` -> `h`, 40 km/h, `"Camino de las Garzas"` (100m).
- `avenida_norte`: `h` -> `i`, 40 km/h, `"Avenida del Norte"` (140m).

### 3.3 Hills & Coast
- **Puente Fluvial Bridge Hill**: `{ "x": 175, "z": -110, "radius": 170, "height": 6.5 }` (elevates bridge causeway to +6.5m above water).
- **Levee Promenade Hill**: `{ "x": 140, "z": 20, "radius": 180, "height": 3.0 }` (protects riverside road above water table).
- **Plaza Plateau**: `{ "x": 60, "z": 80, "radius": 160, "height": 2.5 }` (central town square elevation).
- **Ferry Slip Basin**: `{ "x": 230, "z": 80, "radius": 120, "height": -2.0 }` (slopes ramp down to river water level).
- **Coast**: `{ "x": 200, "beach": 30 }` (Magdalena River water extends east of x=200).

Max road grade across the entire map is **~8.8%** on the ferry ramp and **~7.9%** on the bridge approaches, strictly below the **12.5%** stall threshold.

### 3.4 Theme & Ambient Parameters
- `walls`: Riverside colonial/republican palette (whitewash, ochre, river turquoise, coral, warm mango).
- `roofs`: Weathered terracotta tiles and shaded corrugated canopies.
- `leaves`: Riverbank riparian green and lush broadleaf foilage.
- `palm_share`: 0.35 (palms along the river levee and plaza).
- `traffic_share`: 0.60 (slightly quieter than Puerto Marisol's 1.0, livelier than Alto Cafeto's 0.55).
- `sea` (river water): `Color(0.14, 0.46, 0.44)`, `sand`: `Color(0.78, 0.72, 0.58)`.

---

## 4. Starter Route: Route R0 (Paseo Fluvial)

A scenic introductory shift connecting the logistics depot, the riverfront market, the levee, and the elevated river bridge:
- **Type**: `service: "bays"`, Length: ~1,180m, Target Time: 150s (~2.5 min).
- **Stops**:
  1. *Mercado Fluvial* (`carrera_mercado`, along: 52, dir: 1, waiting: 3)
  2. *Puente Fluvial* (`puente_fluvial`, along: 70, dir: 1, waiting: 0)
  3. *Patio Fluvial* (`depot_road`, along: 35, dir: -1, waiting: 0, final: true)
- **Goals**:
  1. `finish_under`: 260 (4:20 limit)
  2. `no_collisions`
  3. `no_fines`

---

## 5. Progression & Menu Integration

- **Driver Level 8 Unlock**: Requires 2,625 XP (after Level 6 Alto Cafeto).
- Routes tab segmented town switcher displays:
  `[ Puerto Marisol ]   [ Alto Cafeto (Nivel 6) ]   [ Puerto Remanso (Nivel 8) ]`
- If player is below Level 8: shows `"🔒 Nivel 8"` lock badge; routes viewable but locked from play.

---

## 6. Key Engineering Risks & Mitigations

1. **Water Clipping / Ground Height at Ferry Slip**:
   - *Risk*: A road going too far below the water plane (SEA_LEVEL = -0.6) could immerse the bus wheels in water.
   - *Mitigation*: The ferry ramp node `e` sits at elevation -0.5m, right above the waterline, so wheels ride dry asphalt while facing the river expanse.
2. **Bridge Ascent Grade**:
   - *Risk*: Steep slopes on bridge approaches causing starter buseta to stall.
   - *Mitigation*: Hill radius (170m) and height (+6.5m) keep grade to ~5.8–7.9%, well below 12.5%.
3. **Parked Car & Bay Clearance**:
   - *Risk*: Parked cars or props overlapping bus bays.
   - *Mitigation*: Bays are isolated on `carrera_mercado` (along 52) and `puente_fluvial` (along 70) with 0 parked cars within 21m.
