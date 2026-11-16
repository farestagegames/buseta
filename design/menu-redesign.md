# Main menu redesign (16 Nov, owner's Gemini prototype)

Draft by agy (Gemini), from the owner's prototype at https://gemini.google.com/share/d70dc5268266. Owner's ask: copy the layout, iconography, animations and how the menus are managed, keep the game's look with better colours.

## 1. Prototype to existing features
- **Full-screen bus on a turntable**: `BusPreview`/`PreviewStage` grows into a full-screen `TurntableStage` behind the Home UI: the chosen bus on a low-poly street with a yellow ring base.
- **"360°" chip**: badge on the bus saying it can be dragged round.
- **Yellow side arrows**: cycle the owned buses in `Profile.catalog.items(Catalog.BUSES)` (skipping `route_only`) with `Profile.select(Catalog.BUSES, id)`.
- **Top-left pills**: level and XP bar (`DriverLevel`), money (`Country.pack.money`), driver chip (`DriverBadge` + short name; tap opens CHOFER).
- **Bus card**: category tag, bus name, livery dots, 4 stat bars (speed, steering, seats, brakes from `BusSpec`).
- **Top-right icon buttons (52x52)**: horn (preview horn), gear (Configuración), camera (turntable angle), sound (mute), fullscreen (desktop only).
- **Route chip**: chosen route, time of day, expected pay; tap opens RUTAS.
- **Bottom tab bar** (`MenuTabBar`): INICIO, RUTAS, GARAJE, CHOFER (was Conductores), LOGROS (was Progreso). Configuración moves to the gear.
- **TURNO ▶**: the big orange call to action, `_start_shift()`.
- **Kept on Home**: the per-town Carrera Express button (node `ArcadeButton` with `NewBadge`), the daily challenge and next unlock, in a small tray or drawer.

## 2. Colours and type
- Cards and pills `#FEFDFB`, outline/ink `#22242D` (3 px), shadow `#00000033` offset (0, 4) size 6.
- Accent, active tab, turntable ring `#FFC733`; TURNO `#FF7A1A` (pressed `#E0650A`).
- Stats: red `#FF5C5C`, blue `#4D96FF`, green `#6BCB77`, yellow `#FFD93D`.
- Text `#22242D`, muted `#7A8090`, tag fill `#F4EEDC`.
- Sizes: TURNO 32, titles 26, pills and numbers 20, tab labels 18 upper case, body 16, stat labels 14.

## 3. Components
- `scripts/ui/menu_icons.gd` (`MenuIcon`): code-drawn icons. **Written** (opencode, free model).
- `scripts/ui/menu_tab_bar.gd` (`MenuTabBar`): bottom bar, yellow active pill, press bounce. **Written** (opencode via OpenRouter, free model).
- `scripts/ui/turntable_stage.gd` (`TurntableStage`): full-screen 3D stage, drag to turn, side arrows.
- `scripts/ui/menu_top_bar.gd` (`MenuTopBar`): pills and the icon row.
- `scripts/ui/menu_bus_card.gd` (`MenuBusCard`), `scripts/ui/menu_route_chip.gd` (`MenuRouteChip`), `scripts/ui/menu_shift_button.gd` (`MenuShiftButton`, pulsing).
- `scripts/ui/menu_home_drawer.gd` (`MenuHomeDrawer`): Carrera Express, daily challenge, next unlock.

## 4. Animations
- Tab press bounce 0.18 s (scale 0.92 and back, sine).
- Card slide-in on tab change 0.25 s (24 px up, fade in, cubic out).
- Turntable idle spin 0.35 rad/s; drag pauses it, release eases out over 0.8 s.
- TURNO breathing pulse, 1.6 s loop, scale 1.0 to 1.04.
- Bus change 0.22 s slide or spin.

## 5. Layout
- Safe-area insets from `UiStyle.screen_insets` on the root margin.
- Touch targets: tabs 110x64, top icons 52x52, side arrows 56x80, TURNO 170x68, pills and chip at least 48 tall.
- 1280x720: pills left (~380 px), icons right (~290 px), bus card under the pills, tab bar centred at the bottom with the route chip above, TURNO bottom right.
- 1560x720: the extra width goes to the side margins; arrows pin to the edges.
- 1600x900: the extra height separates the bus card from the bottom row.

## 6. Build steps (commit each)
1. Icons, tab bar, card and pill styles in `UiStyle`; their unit tests.
2. Turntable stage; keep `BusPreview` contracts for the garage try-on.
3. Top bar with pills and icons; gear opens Configuración (settings tests).
4. Bus card, route chip, TURNO.
5. Home tray with Carrera Express, daily challenge, next unlock (arcade button tests).
6. Assemble in `main_menu.gd`; keep `_content` and `show_tab(0..5)` so every existing tab test still opens its tab.
7. Animations and polish, full gate.

## 7. Risks
- Frame rate: a full-screen 3D stage behind the cards on a Mali-G52 / Adreno 610 class phone. Keep it low poly, no shadows, MSAA 2x at most, and stop rendering it when another tab covers it.
- Spanish text length: short tab names (CHOFER, LOGROS), `UiStyle.fit_font_size` on variable text, fit tests at 1280 and 1560.
