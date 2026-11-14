# Graphics refresh: a chunky low-poly toy look (13 Nov)

## Current look

- Buildings are single boxes with a tiling photo-ish wall texture (flats, office,
  shops) tinted by vertex colour, a flat parapet slab and a few roof boxes. No
  edges, ledges or frames, so blocks read as flat cards.
- Lighting is linear tonemap, grey-blue ambient (0.72, 0.74, 0.78 at 0.62) and a
  pale sun, so colours wash out and shade sides look grey rather than coloured.
- Kerbs are a flat light strip 0.09 m up; road markings are thin.
- Trees are two wobbly blobs on a stick; palms are thin two-segment posts.
- Traffic cars and pedestrians are a handful of plain boxes (MultiMesh batches).
- No contact darkening anywhere: buildings, trees and props sit on the ground
  without any grounding, and LOW graphics has no shadows at all.

## Target look

Clean, bright, chunky toy-town: saturated flat colours, warm sun and cool
coloured shade, every object with a few chunky bevels and trims (plinths,
ledges, frames, rims), darker bases that ground things, and fat readable road
furniture. Original shapes and palettes only.

## Changes, ranked (impact vs. phone cost)

All of these add vertices to the existing merged meshes or MultiMeshes, or a few
shader instructions; none adds a draw call. Layout random numbers are untouched
(any new variety uses a separate seeded generator) so every town keeps its
layout and tests.

| # | Change | Impact | Frame cost |
| --- | --- | --- | --- |
| 1 | Light and colour: filmic-style tonemap, warmer sun, cooler and stronger coloured ambient, a touch more saturation per time of day | High, whole screen | None (tonemap is already a pass) |
| 2 | Chunky buildings: street-level plinth, storey ledge and cornice lip, corner pilasters on blocks, a deeper parapet; window frames and sills drawn in the facade shader | High | ~10 boxes per building (a few thousand vertices town-wide), a few ALU per wall pixel |
| 3 | Baked "AO": bottom vertices of walls, trunks, posts and props darkened, plus a dark skirt on the ground round each building | Medium-high, grounds everything, also on LOW | None |
| 4 | Raised chunky kerbs (lit top, darker face) and fatter lane dashes, yellow kerb paint at bus bays | Medium | Vertices only |
| 5 | Nicer trees and palms: stacked two-tone faceted crowns, ringed thicker palm trunks with coconuts | Medium | Vertices only |
| 6 | Chunkier traffic cars and pedestrians: bevelled roofs, bumpers, wheel arches, window bands; bigger heads and shoes | Medium | Vertices per instance only |
| 7 | Gentle rim light on the vertex-colour scenery (cheap fresnel in a small custom shader) | Low-medium | A few ALU per pixel; dropped if it shows on the frame time |

Rejected: inverted-hull outlines (doubles vertices and draw calls), SSAO and
screen-space outlines (not in the Compatibility renderer or too costly on a phone).

## Order and checks

Build 1, 2, 3, 4 first (biggest look change for least cost), then 5 and 6 if
time allows, 7 last. Each change: before/after shots with `tools/store_shots.tscn`
(copied out of the repo), full gate, its own commit and a DECISIONS.md line.

Noticed in passing, not in this plan: the follow camera passes through palm
fronds at a stop (02_pasajeros shot), which a camera-occlusion fade could fix.
