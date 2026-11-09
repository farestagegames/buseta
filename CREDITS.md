# Credits

## Art and audio

The bus, city, passengers and obstacles are generated in code, all sounds are
synthesised by `tools/make_sounds.py`, and all textures are drawn by
`tools/make_textures.py`. Latin text uses Godot's built-in font.

### Horns, street sounds and radio music

Every file below is original, made by `tools/make_sounds.py` and the helpers in
`tools/sound_kit`, from sine waves and filtered noise. No recordings, samples or
speech are used. The music is composed by the code: rhythms inspired by cumbia,
vallenato and champeta, with every melody written by a seeded process that walks
each section's chords, so none is a known tune. The radio stations and track
titles are fictional. All of these files are dedicated to the public domain under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

| File in `assets/audio` | What it is | How it was made | Licence |
| --- | --- | --- | --- |
| `horn_loop.wav` | City bus horn | Two close tones with overtones, softly saturated; `horn_loop()` in `make_sounds.py`, fade in and loop by `horns.py` | CC0 |
| `horn_two_tone.wav` | Buseta's bright two-tone horn | Two tones a major third apart, saturated; `horns.two_tone()` | CC0 |
| `horn_air.wav` | Articulated bus's deep air horn | Three low reeds in a chord with a little air noise; `horns.air_horn()` | CC0 |
| `horn_double_tap.wav` | Short friendly "beep beep" | Two short two-note beeps; `horns.double_tap()` | CC0 |
| `horn_chiva.wav` | Chiva's playful musical horn | A short tune composed for this game on an electric trumpet-like voice; `horns.chiva_tune()` | CC0 |
| `ambience/city_bed.wav` | Traffic murmur, a 24 s loop | Filtered noise with slow swells; `ambience.city_bed()` | CC0 |
| `ambience/sea_waves.wav` | Waves below the Malecón | Filtered noise shaped into swells, breaks and fizz; `ambience.sea_waves()` | CC0 |
| `ambience/birds.wav` | Great-tailed grackles and parrots, a 40 s loop | Rising whistles, dry clacks and rough squawks from sine sweeps and noise, at seeded random times; `ambience.birds()` | CC0 |
| `ambience/shop_music.wav` | Music from a shop doorway, a 16-bar loop | Sixteen bars of "Ventana al mar" rendered as a seamless loop with loop points; `music.shop_music()` | CC0 |
| `ambience/rain.wav` | Rain, for the weather to come | Filtered noise with tiny drop clicks; `ambience.rain()` | CC0 |
| `ambience/motorbike_pass.wav` | A small motorbike going past | Buzzing harmonics with a Doppler drop and distance filtering; `ambience.motorbike_pass()` | CC0 |
| `ambience/vendor_bell.wav` | A paletero's hand bell | Inharmonic bell partials, rung three times; `ambience.vendor_bell()` | CC0 |
| `ambience/sharpener_whistle.wav` | A knife sharpener's pan pipe | A quick breathy scale up and down; `ambience.sharpener_whistle()` | CC0 |
| `siren_whoop.wav` | A patrol car's whoop when the police fine the driver | Two rising sine sweeps with two harmonics; `make_sounds.py siren_whoop()` | CC0 |
| `radio/onda_marisol_1.wav` | "Brisa de las cinco", Onda Marisol 95.3 FM | Cumbia-inspired 2/4: tambora-style drum, scraper, bass, keys, gaita-like lead; `music.cumbia()` | CC0 |
| `radio/onda_marisol_2.wav` | "Ventana al mar", Onda Marisol 95.3 FM | Cumbia-inspired, minor key, clarinet-like lead | CC0 |
| `radio/acordeon_puerto_1.wav` | "Paseo de la ciénaga", Acordeón del Puerto 93.3 FM | Vallenato-inspired paseo: caja-like drum, scraper, bass, accordion-like voice in thirds; `music.vallenato()` | CC0 |
| `radio/acordeon_puerto_2.wav` | "Camino a Los Almendros", Acordeón del Puerto 93.3 FM | Vallenato-inspired, faster, major key | CC0 |
| `radio/pico_marisol_1.wav` | "Terraza Caliente", Picó Marisol 106.1 FM | Champeta-inspired 4/4: syncopated kick and snare, bouncing bass, bright guitar runs, synth answer; `music.champeta()` | CC0 |
| `radio/pico_marisol_2.wav` | "Baile en el Barrio", Picó Marisol 106.1 FM | Champeta-inspired, minor key | CC0 |
| `radio/pico_marisol_3.wav` | "Arena y Picó", Picó Marisol 106.1 FM | Champeta-inspired, quicker, answering melody | CC0 |
| `radio/pico_marisol_4.wav` | "La Esquina del Parlante", Picó Marisol 106.1 FM | Champeta-inspired, slower, minor key | CC0 |
| `radio/acordeon_puerto_3.wav` | "Puya del Arroyo", Acordeón del Puerto 93.3 FM | Vallenato-inspired, fast puya feel | CC0 |
| `radio/acordeon_puerto_4.wav` | "Son de la Ciénaga Grande", Acordeón del Puerto 93.3 FM | Vallenato-inspired, slow son feel, minor key | CC0 |
| `radio/son_malecon_1.wav` | "Clave del Malecón", Son del Malecón 102.9 FM | Salsa-inspired 4/4: son clave, cowbell, conga tumbao, piano montuno, tumbao bass, brass in harmony; `music.salsa()` | CC0 |
| `radio/son_malecon_2.wav` | "Noche de Terraza", Son del Malecón 102.9 FM | Salsa-inspired, minor key, 3-2 clave | CC0 |
| `radio/son_malecon_3.wav` | "Pregón del Mercado", Son del Malecón 102.9 FM | Salsa-inspired, quick | CC0 |
| `radio/son_malecon_4.wav` | "Brisa de Diciembre", Son del Malecón 102.9 FM | Salsa-inspired, slower, minor key | CC0 |

The radio tracks are songs: each starts from silence, ends on a held closing chord
that fades out, and has no loop points. `python3 tools/check_sounds.py` checks their
levels: no clipping, peaks below -1 dBFS, smooth loop points, songs that start and
end in silence, and horns and tracks matched in loudness.

### Fonts

| Asset | Author | Source | Licence |
| --- | --- | --- | --- |
| Noto Sans Devanagari Regular | The Noto Project Authors | [notofonts/devanagari](https://github.com/notofonts/devanagari) | SIL Open Font License 1.1, see `assets/fonts/OFL.txt` |
| Noto Sans Arabic Regular | The Noto Project Authors | [notofonts/arabic](https://github.com/notofonts/arabic) | SIL Open Font License 1.1, see `assets/fonts/OFL.txt` |

## Software

| Software | Use | Licence |
| --- | --- | --- |
| [Godot Engine 4.7.2](https://godotengine.org) | Game engine | MIT |
| [GUT 9.7.1](https://github.com/bitwes/Gut) | Unit testing, development only | MIT |
