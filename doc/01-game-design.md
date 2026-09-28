# 01 — Game Design Document

## 1. High concept

**Genre:** Co-op extraction + light horror + collection/base-building
**Audience:** 13+ (Roblox content maturity: expected "Moderate" due to fear/tension — confirm via the questionnaire)
**Session:** 10–15 minute dives; 30–60 minute play sessions
**Players per server:** 12–16 (squads of 1–4 share a hub; each dive is a squad instance)

**Fantasy:** "I'm a daring salvage diver, and one more relic could make me rich — or get me killed."

## 2. Core loop

```
Surface Hub ──► Gear up ──► Dive ──► Scavenge ──► Extract ──► Sell / Display ──► Upgrade ──┐
     ▲                                                                                      │
     └──────────────────────────────────────────────────────────────────────────────────────┘
```

1. **Gear up** at the surface base: suit, oxygen tank, lamp, tools.
2. **Dive** into a zone. Layout is shuffled from hand-built room modules each dive.
3. **Scavenge** relics. Every relic has **value**, **weight** (slows you down) and **noise** (attracts creatures).
4. **Extract** via the dive boat or an emergency buoy. Dying drops everything you were carrying; squadmates can recover it.
5. **Sell** relics for Coins or **display** rare ones in your base.
6. **Upgrade** gear and base → unlock deeper zones.

### The key tension
The greed-vs-survival decision: *"My oxygen is at 30%, and there's a gold relic two rooms deeper…"* Design every system to sharpen this choice.

## 3. Systems

### 3.1 Oxygen
- Main timer for every dive. Drains faster when sprinting or carrying heavy loads.
- Refill stations (rare) and air pockets create route decisions.
- UI: a large, readable gauge plus audio cues (breathing gets louder below 25%).

### 3.2 Relics
- **Rarity tiers:** Common, Uncommon, Rare, Epic, Legendary.
- **Mutations** (~1–3% chance): Glowing, Barnacled, Gilded, Cursed. Mutations multiply value and look distinct. They are the collectible status symbols.
- **Collection book:** track discovered relics per zone; completion rewards give cosmetics/titles.
- Target launch content: **~30 relics** in zone 1, **4 mutations**.

### 3.3 Creatures (the threat)
- React to **noise** and **light**. Turning your lamp off hides you but blinds you.
- Launch set: 3 types
  - **Drifter** — slow patrol, alerted by light.
  - **Lurker** — ambush from vents/debris, alerted by noise.
  - **Warden** — rare zone "boss" that hunts carriers of heavy loot.
- No gore. Fear comes from sound, darkness, and chase, not violence.

### 3.4 Co-op mechanics
- Proximity text chat always; proximity voice chat for age-verified players who opt in (Roblox rules).
- Revive downed teammates within a time window.
- Hand relics to teammates (strong swimmer carries heavy loot).
- Ping system (point at relic / danger) for players without voice.

### 3.5 Progression
| Layer | Examples |
|---|---|
| Gear | Oxygen tank size, swim speed, lamp range, carry capacity, sonar |
| Zones | Zone 1 Harbor → Zone 2 Old Market → Zone 3 Cathedral (post-launch) |
| Base | Display pedestals, aquarium walls, trophy room; visitable by others |
| Player level | XP from dives; unlocks titles, emotes |

### 3.6 Economy
- **Coins** (soft currency) from selling relics.
- **Pearls** (premium, bought with Robux, also earnable slowly in-game) for cosmetics only.
- Sinks: gear upgrades, repairs, base items, relic restoration.
- Trading (post-launch, v1.2+): relic-for-relic trading only with server-side validation and trade logs. Delay until anti-dupe systems are proven.

### 3.7 Mystery / lore layer
- Environmental clues (notes, murals, radio logs) hint at why the city sank.
- Server-wide "unlock" events every few weeks reveal new story beats and zones.
- Purpose: YouTube theory videos and Discord discussion (free marketing).

## 4. First-time user experience (FTUE)

| Time | What happens |
|---|---|
| 0–10 s | Spawn on dive boat. One button prompt: "DIVE". |
| 10–60 s | Guided first dive in a safe mini-zone. Grab 3 glowing relics. |
| 1–3 min | First creature sighting (scripted, can't kill you). Rush back to the boat. |
| 3–5 min | Sell relics, buy first upgrade, see your empty base with pedestals. |
| 5 min | Prompt to join a squad or invite a friend. |

Goal: every new player experiences **fear, reward, and progress** in the first 5 minutes.

## 5. Launch content scope (MVG)

- 1 surface hub + 1 dive zone (Harbor) with ~20 room modules
- 30 relics, 4 mutations, 3 creatures
- 6 gear upgrade tracks, 5 levels each
- Personal base with 10 display slots
- 1 cosmetic suit set (monetized) + 1 earnable set
- Daily "currents" modifier (e.g., 2x Rare spawn in east wing)

Everything else is post-launch.

## 6. Content rules for a 13+ audience

- No blood/gore; creatures are eerie, not graphic.
- All player text goes through `TextChatService` filtering (required).
- No real-world gambling themes. No paid random items at launch.
- Complete the Roblox **content maturity questionnaire** honestly.
