# 07: Style Guide and Builder Spec

For builders, artists and UI work in Phase 3. The grey-box game already runs. Art replaces grey boxes without changing the measurements below, because the code depends on them.

## 1. Mood

A drowned harbor city, eerie rather than gory (13+, doc/01 §6). Fear comes from **darkness, sound and chase**, not violence. The surface should feel safe and warm; the depths cold and quiet.

| Place | Feel | Current settings (`GreyboxService.init`) |
|---|---|---|
| Surface / hub | Bright afternoon, wooden docks, warm | `Lighting.ClockTime = 14`, `Brightness = 2`, `OutdoorAmbient = (120,130,140)` |
| Rooms underwater | Dim enough that the lamp matters, bright enough to navigate | `Lighting.Ambient = (70,80,90)` |
| Water | Murky teal | `Terrain.WaterColor = (30,95,105)`, `WaterTransparency = 0.5` |

Playtest rule: a player with the lamp **off** can find doorways but can't read relic colours from across a room. If rooms get darker, raise lamp range rather than ambient.

## 2. Colour

Rarity colours live in `src/shared/Config/Palette.luau`. Change them there only, and relics, pedestals, sonar dots and the collection book all follow.

| Rarity | RGB | Use |
|---|---|---|
| Common | 170, 170, 170 | |
| Uncommon | 85, 200, 110 | |
| Rare | 70, 140, 255 | |
| Epic | 170, 90, 255 | |
| Legendary | 255, 190, 40 | Reserve this gold for Legendary only; don't use it on scenery |

Signal colours players learn: **teal** = creature calm, **amber** = creature alerted, **red** = creature attacking / danger. Don't use red or amber lights as decoration underwater; they would read as threats.

Mutations must be recognisable at a glance: Glowing (emissive), Barnacled (encrusted texture), Gilded (gold metal), Cursed (dark, purple-black). They are currently rendered as Neon material on the rarity colour.

## 3. Room modules (builder spec)

The zone generator (`Logic/ZoneLayout.luau`) places rooms on a 50-stud grid and connects them with doors. A Studio-built room model must match these numbers, or creatures will swim through walls and players will get stuck.

| Rule | Value |
|---|---|
| Interior size | 48 × 24 × 48 studs (X × Y × Z); room center at Y = −40 |
| Walls, floor, ceiling | 2 studs thick; outer footprint 52 × 52 |
| Doorways | 12 × 12, **centered** on each wall, vertically centered in the room. Build all four; the generator seals unused ones. |
| Keep clear | A straight line from the room center to each doorway center. Creatures travel along these lines; no props there. |
| Relic spawns | Near the floor at offsets (−14,−10,−14), (14,−10,10), (−16,−10,14), (16,−10,−16), (4,−10,18) from center. Keep these spots open. |
| Hiding props | Pillars and crates on the diagonals, about 8 studs from center (see `decorate` in `GreyboxService`) |
| Vents (Lurker) | On a doorless wall, 3 studs in from the wall, 6 studs above the room's center height |
| Start room | Has a 16 × 16 hole in the ceiling for the shaft |
| Performance | Mobile first: MeshParts, a small part count per room, no per-room lights except creature and relic glows. Target 60 FPS on a mid phone, < 700 MB client memory (doc/02 §4.7). |

Room kinds today are `plain`, `pillars` and `crates` (`Config/Zone.luau` weights). New kinds are added the same way.

## 4. Creatures, relics and assets needed

| Asset | Now | Needed |
|---|---|---|
| Drifter | 6-stud dark ball with a state-coloured light | Slow, eerie floater; the silhouette readable in lamp light |
| Lurker | 4-stud ball, nearly invisible in its vent | Vent-dweller; the amber windup must be obvious (dodge cue) |
| Warden | 10-stud dark-red ball | Big, slow, relentless boss |
| Relics (30 for launch) | Cubes sized by weight | Models reusing a few bases with material variants (doc/03 Phase 3) |
| Room modules (20+) | Grey boxes | Ruins, kelp, harbor architecture per §3 |
| Surface hub | Grey plates, a wooden boat, blocks | Dock, market, base area |
| Audio | None | Ambience layers, breathing below 25% air, creature cues, stingers |
| Icon + 3–5 thumbnails | Roblox defaults | Doc/05 §3: one creature or diver face, high contrast |

## 5. UI rules

- **Mobile first.** Layouts are authored at 720 px tall and scaled by `UIScaleController` (0.7×–1.15×). Check every screen at 360 px tall (landscape phone).
- Touch targets at least 40 px at 1× (28 px after the minimum scale).
- Panels no larger than about 540 × 460 at 1×, so they fit a phone after scaling.
- Roblox chat owns the top left. The SQUAD / BOOK / SHOP buttons stack at the left middle, with the squad list under them; the top center holds oxygen, bag and the tutorial banner; the bottom right is Roblox's touch controls and our action buttons (Sprint, Lamp, Ping, Drop). Keep new UI out of those zones.
- Fonts: Gotham Black for buttons and headings, Gotham Bold for labels, Gotham for secondary text.
- New screens must be added to `OUR_GUIS` in `UIScaleController`, or they won't scale.
