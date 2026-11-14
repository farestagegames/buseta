# Town Features Plan: Alto Cafeto and Puerto Remanso

## Alto Cafeto

### 1. Plaza Market Day
- Player experience: The player navigates around vibrant fruit crates, canvas awnings, and active street vendors crowding the kerb of Plaza Principal.
- Implementation: Add 6-8 stall and crate entries to map knockables in alto_cafeto.json; existing StreetLife vendor logic automatically places animated vendors behind stalls.
- Cost: S
- Render impact: Zero new draw calls; instances reuse the existing ObstacleField and StreetLife MultiMesh batches with negligible vertex overhead on mid-range phones.

### 2. Coffee Pickers along Mountain Roads
- Player experience: Roadside farm workers wearing straw hats and waist baskets walk along the gravel shoulders of Subida del Cafetal and Bajada de los Guayacanes.
- Implementation: Spawn a custom rural passenger look via existing StreetLife MultiMesh pedestrian batches (clothes, skin, hair) with a simple low-poly basket primitive in the hair/hat batch.
- Cost: S
- Render impact: Zero new draw calls; merged into existing pedestrian batches, costing under 60 extra triangles per visible character.

### 3. Chiva Rural Bus Traffic
- Player experience: Wooden ladder-backed chiva buses packed with roof cargo share the narrow switchbacks, honking at tight curves.
- Implementation: Add "chiva": 0.15 to map vehicle_mix; TrafficSystem instantiates one extra MultiMesh batch using a simplified low-poly version of the existing BusVisual chiva model.
- Cost: M
- Render impact: Exactly 1 new draw call for the chiva batch; around 400 triangles per vehicle for 2-3 concurrent traffic instances.

### 4. Valley Mist and Fog Banks
- Player experience: Soft white fog blankets the lower depot valley and hairpin ascents at dawn, thinning out as the bus climbs toward the sunny Mirador.
- Implementation: Add a static low-poly horizontal fog ribbon mesh in CityBuilder static scenery chunks near node a and curva_cafe, combined with the existing map fog_scale multiplier.
- Cost: S
- Render impact: Zero new draw calls when baked into the static scenery LowPolyBuilder batch; uses unshaded vertex-alpha geometry to prevent mobile fill-rate drops.

Build first (Alto Cafeto): Plaza Market Day. It makes the central plaza immediately feel alive and provides fresh driving obstacles using existing knockable and vendor systems with zero code changes and zero new draw calls.

## Puerto Remanso

### 1. Ferry Slipway and Barge
- Player experience: At the foot of Rampa del Ferry, the player stops facing a wide flat-bottomed river barge docked at the slipway with wooden ramps and moored trucks.
- Implementation: Add a landmark entry {"kind": "ferry_barge", "x": 235, "z": 80, "face": "e"} in puerto_remanso.json; CityBuilder builds the static hull and ramp in procedural scenery.
- Cost: S
- Render impact: Zero new draw calls; geometry is baked directly into static scenery LowPolyBuilder chunks with zero CPU overhead.

### 2. Riverside Stilt Market
- Player experience: An open-air fish and plantain market with wooden boardwalks and corrugated tin awnings lines Carrera del Mercado and Paseo de la Ribera.
- Implementation: Add a "river_market" landmark in CityBuilder for the timber pavilion, populated with knockable stalls and StreetLife fish vendors along the kerb.
- Cost: M
- Render impact: Zero new draw calls; the pavilion is baked into static scenery while market stalls and vendors reuse existing MultiMesh batches.

### 3. River Boats and Canoes
- Player experience: Long wooden motorized canoes and cargo skiffs bob along the silt shoreline east of the levee and beneath the elevated bridge.
- Implementation: Add landmark entries or static scenery instances along the water line (x=205 to 220) using a single low-poly canoe mesh generated in CityBuilder scenery.
- Cost: S
- Render impact: Zero new draw calls when combined with the static scenery batch; minimal triangle count well within budget mobile limits.

### 4. Riverbank Fishermen
- Player experience: Fishermen sit along the muddy silt bank beside Paseo de la Ribera with wooden stools, cane rods, and fish buckets.
- Implementation: Place static pedestrian looks from StreetLife standing or seated along the riverbank edge, anchored to crate knockables or landmark markers.
- Cost: S
- Render impact: Zero new draw calls; shares the existing pedestrian and knockable MultiMesh batches.

### 5. River Audio Ambience Layer
- Player experience: Gentle muddy water laps, distant outboard two-stroke putts, and riparian cicadas replace ocean surf along the levee and bridge.
- Implementation: Override the map ambience in puerto_remanso.json by ducking the ocean layer to -80 dB and adding a looping river bed sound using the existing "sea" proximity rule.
- Cost: S
- Render impact: Zero render or GPU cost; purely audio-thread logic processed by AmbienceMixer and AudioDirector.

Build first (Puerto Remanso): Ferry Slipway and Barge. It turns the dead-end ferry ramp into a purposeful, iconic waterfront destination with zero draw call overhead.
