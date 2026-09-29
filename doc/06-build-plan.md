# 06 — Build Plan (Phase 0 → Phase 1)

Turns `03-roadmap.md` Phases 0–1 into concrete tasks against the repo scaffold. Updated 2026-09-28.

## 1. Where we are

Phase 0 scaffold is in the repo:

| File | Purpose |
|---|---|
| `default.project.json` | Rojo map: `src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client, `Packages` → ReplicatedStorage.Packages. StreamingEnabled on. |
| `rokit.toml` | Pinned Rojo, Wally, Selene, StyLua, luau-lsp, Lune |
| `wally.toml` | Fusion 0.3 (UI) |
| `selene.toml`, `stylua.toml`, `.gitignore` | Lint, format, ignores |
| `.github/workflows/ci.yml` | StyLua check, Selene, Lune tests |
| `src/server/init.server.luau`, `src/client/init.client.luau` | Loaders: every module in `Services/` or `Controllers/` gets `init()` then `start()` |
| `src/shared/Config/{Oxygen,Gear,Relics}.luau` | All tuning numbers (placeholders) |
| `src/shared/Logic/{Loot,OxygenMath}.luau` | Pure, testable game math |
| `src/shared/Types.luau` | Profile + relic instance types (matches `02` §4.4) |
| `tests/run.luau` | Lune test runner for pure logic |

### Remaining Phase 0 steps (manual, need your accounts)

1. `rokit install` → `wally install` → `stylua src tests` (normalize formatting once) → `lune run tests/run`
2. `git init`, create a private GitHub repo, push. CI should go green.
3. Create the Roblox **group**, then the experience with `Deep Salvage [TEST]` and `Deep Salvage` places.
4. Install the Rojo Studio plugin, `rojo serve`, connect. You should see `[Server] Deep Salvage booted` in Output.
5. Task board + closed Discord.

**Phase 0 exit:** edit a file in VS Code → change shows in Studio; CI passes.

## 2. Decisions made (change any you disagree with)

| Decision | Choice | Reason |
|---|---|---|
| Unit tests | **Lune** for pure logic in CI; Jest-Lua later for in-engine tests | Jest-Lua/TestEZ need a Roblox runtime, which GitHub Actions doesn't have. Lune runs Luau directly. |
| Testability rule | `Config/` and `Logic/` modules use no Roblox APIs and no requires; logic takes config + rng as arguments | Same code runs in Studio and in Lune |
| UI | **Fusion** | Lighter than React-Lua for a small team |
| Networking | Plain RemoteEvents in Phase 1, **Zap** in Phase 2 | Doc suggests starting simple; Zap once payloads settle |
| Dive instancing | Option A (regions in one server) | Per doc; revisit if server perf fails (see §4) |
| Framework | None; two-phase loader only | Per doc |

## 3. Phase 1 — Prototype the fun (weeks 2–3)

Goal: grey-box proof that the "one more relic" tension works. No art, no saving.

| # | Task | Files | Done when |
|---|---|---|---|
| 1 | Swim controller: 3D movement, sprint, buoyancy; PC + mobile + gamepad input | `client/Controllers/SwimController.luau` | Feels smooth on a phone |
| 2 | Dive session on server: start dive, per-player oxygen tick (0.2 s) using `OxygenMath`, death at 0 | `server/Services/DiveService.luau` | Oxygen drains faster when sprinting/loaded; player dies at 0 |
| 3 | Oxygen gauge UI + low-air breathing cue | `client/UI/OxygenGauge.luau`, `client/Controllers/AudioController.luau` | Readable at phone size |
| 4 | Grey-box zone, 5 rooms, hand placed | Studio place file (not generated yet) | Walkable loop with a dead end |
| 5 | Relic spawns via `Loot.rollRelic`; server-validated pickup (distance check); weight slows swim; noise event on pickup | `server/Services/RelicService.luau` | Pickup >N studs away is rejected |
| 6 | Drifter creature: `Patrol → Investigate → Chase → Return`, reacts to lamp + noise | `server/Services/CreatureService.luau`, `client/Controllers/LampController.luau` | Turning the lamp off can lose it |
| 7 | Extraction at the boat; death drops carried loot as a pickup | `DiveService`, `RelicService` | Squadmate can recover dropped loot |
| 8 | Sell counter → Coins (in memory only) | `server/Services/EconomyService.luau` | Price comes from `Loot.sellValue` on server |
| 9 | Remotes with per-player rate limiting | `shared/Net/Remotes.luau` | Spamming a remote does nothing |

### Status (2026-09-28): code written for all 9 tasks, not yet run in Studio

| Task | Implemented as | Differs from the table above |
|---|---|---|
| 1 | `client/Controllers/SwimController.luau` (sprint input) | Uses Roblox's native Terrain-water swimming, not a custom controller. Server sets `WalkSpeed` from fins, load and sprint (`Logic/SwimMath.luau`). Replace only if playtesters say swimming feels bad. |
| 2 | `server/Services/DiveService.luau` | A dive starts when a player sinks below the shaft entry, and ends as an **extraction when they climb out of the shaft**, not at a boat prompt. |
| 3 | `client/Controllers/HudController.luau` | Plain Instances, not Fusion. Low air = red bar + blinking "LOW AIR"; **no breathing audio yet** (needs sound asset IDs). |
| 4 | `server/Services/GreyboxService.luau` | **Built in code**, not by hand in Studio: 6 flooded rooms (loop B-C-E-D, dead end F with 5 relic spawns), shaft, boat, sell counter. It deletes the template `Baseplate`/`SpawnLocation`. |
| 5 | `server/Services/RelicService.luau` | Pickup is a ProximityPrompt with a server distance check. Empty spawns refill every 60 s while nobody is diving. |
| 6 | `server/Services/CreatureService.luau`, `client/Controllers/LampController.luau` | Drifter is an anchored ball moving room to room through door centers (no pathfinding). Its light shows its state: teal patrol, amber investigate/search, red chase. It has no view cone yet. |
| 7 | `DiveService` + `RelicService.dropAt` | Loot also drops if a player disconnects mid-dive. |
| 8 | `server/Services/EconomyService.luau`, `PlayerDataService.luau` | Coins show on the leaderboard. **Nothing saves** (Phase 2). |
| 9 | `shared/Net/Remotes.luau`, `server/Util/RateLimiter.luau` | Token bucket per player per remote; payloads type-checked. |

**Added after the first Studio run (2026-09-28):** lighting brightened (dusk was unreadable), and a **Gear Locker** upgrade station (blue block left of the boat; `UpgradeService`, `UpgradeController`, `Logic/Upgrade.luau`) so Coins buy tank, fins, bag and lamp levels. This gives the playtest its "sell → upgrade → dive again" pull. Sonar and suit are hidden until they do something.

**Saving (pulled forward from Phase 2):** `PlayerDataService` now uses **ProfileStore**, vendored from the official MadStudioRoblox repo at commit `45c9847` into `src/server/Vendor/` (license in `licenses/`). Wally only had third-party forks. Profiles are session-locked, versioned (`MIGRATIONS` table), GDPR-tagged with `AddUserId`, and reconciled against the template on load. The place is published (private) with Studio API access on.

**Analytics (pulled forward from Phase 2, for the playtest):** `AnalyticsService` wraps Roblox's AnalyticsService (pcall-guarded). It logs an onboarding funnel (Joined → FirstDive → FirstRelic → FirstExtraction → FirstSale → FirstUpgrade), each step once per player ever via `profile.onboarding`. Per dive it logs `DiveEnded` (seconds), `DiveLoot` (Coins carried) and `DiveDeath` (cause: oxygen / creature / other). Coin sources (selling) and sinks (upgrades) are economy events. Roblox ignores Studio sessions, so data comes only from the published game; view it in Creator Hub → Analytics. Not yet logged: squad size per dive (no squads yet) and shop views.

Tuning lives in `Config/Oxygen`, `Config/Swim`, `Config/Creatures`, `Config/Gear`, `Config/Relics`. A test locks in the core chase rule: an unloaded starter diver outruns the Drifter only by sprinting.

**To playtest:** `rojo serve`, connect Studio to an empty Baseplate place, press Play. Controls: DIVE button, Shift = sprint, F = lamp (touch buttons on mobile). For the squad test, use Test → Clients and Servers with 2–4 players.

**Known Phase 1 limits:** one shared zone for all players; the Drifter can clip wall corners while investigating from odd angles; no revive or pings (Phase 2 squad system).

**Playtest:** 5–10 people, don't explain anything. **Exit:** testers start a 2nd and 3rd dive on their own and describe a "one more relic" moment.

## 4. Gaps and conflicts found in the docs

1. **Suit upgrade is undefined.** `01` lists 6 gear tracks including suit but doesn't say what it improves. I assumed a depth rating that gates deeper zones (`Config/Gear.luau`). Confirm.
2. **"Restore relic" needs a damage system** (`04` §2.2), but `01` never says relics get damaged. Either design it (e.g. dropped/bumped relics lose value) or cut the product.
3. **Extra Bag Pocket pass vs "never sell power."** In an extraction game, carry capacity is loot per dive. Consider making it cosmetic storage, or small enough that max-level free bags beat it.
4. **Live-ops calendar dates don't work for 2026.** `04` puts Halloween at week 7 after launch. Today is 2026-09-28 and launch is ~week 12, around late December, so Halloween 2026 is gone. Retarget "The First Tide" to the **winter holidays / New Year**, or plan Ghost Tide for Halloween 2027.
5. **Server load, Option A.** 12–16 players can mean 4 simultaneous squad dives, each with its own copy of the zone and 3–6 creatures on one server. Measure in Phase 2; move to reserved servers early if heartbeat drops.
6. **ProfileStore on Wally** needs checking; it may need to be vendored into `src/server`.
7. **Proximity voice** needs age-verified players who opt in. Pings (`01` §3.4) must work well enough that nobody needs voice.

## 5. Phase 2 progress

| Item | Status |
|---|---|
| ProfileStore data layer, versioned template | Done (pulled forward) |
| Analytics events | Done (pulled forward); squad size and revives added with squads |
| **Squad system: invites, shared dive, revive, pings** | **Code written 2026-09-29, not yet run in Studio.** `Logic/Squads.luau` holds the unit-tested rules (invite, accept, leave, cap of 4, 60 s invite expiry). `SquadService` handles membership and remotes. In `DiveService`, a diver with a diving squadmate goes *downed* for 20 s (frozen, oxygen paused, ignored by creatures) instead of dying, and a squadmate holds E for 2 s to revive them with at least 30% air. Solo divers still die outright. `PingService` labels pings from world state (RELIC name / DANGER / LOOK) and relays them to the squad only. Client: `SquadController` (SQUAD button, invite popup, member list) and `PingController` (G / R1 / touch). "Shared dive" comes free while there's one zone; per-squad instances wait for the zone generator. |
| Zone generator from room modules | **Code written 2026-09-29, not yet run in Studio.** `Logic/ZoneLayout.luau` (unit-tested over 200 seeds) grows 10 rooms from the start cell as a random tree, adds 2 loop doors, and marks depth and dead ends. `GreyboxService` builds it with grey-box modules (plain / pillars / crates); dead ends get 5 relic spawns, and the Drifter starts in the deepest room. The seed is the day number ("seed of the day"); set a `ZoneSeed` number attribute on Workspace to reproduce a layout. The seed in use is printed and stored as `ActiveZoneSeed`. Still one shared zone per server: per-squad instances (reserved servers or spaced regions) come when server performance calls for it. Tuning is in `Config/Zone.luau`. |
| All 3 creatures | **Code written 2026-09-29, not yet run in Studio.** **Lurker** (2 per zone, in seeded wall vents away from the start): hidden and ignores light; noise in its room triggers a 0.7 s amber windup, then a lunge to the noise point (not the diver, so it's dodgeable), retreat and cooldown. Pings don't reveal hidden Lurkers. **Warden** (rare boss): while anyone is heavy (bag ≥ 70% or ≥ 400 Coins carried), a 35% chance every 10 s to spawn in the deepest room with a warning to all divers. It hunts the heaviest carrier room to room and chases in sight at 14 speed: an unloaded diver escapes, a full bag can't even when sprinting (unit-tested). It leaves after 20 s with nobody heavy. Added **Drop** (X / B / touch) to drop the heaviest relic, which makes noise; this is the escape valve the Warden and Drifter designs assumed. Death causes are now per creature. |
| Gear upgrades (6 tracks) | 4 of 6 done; sonar and suit need gameplay first |
| Rarity/mutation + collection book | **Code written 2026-09-29, not yet run in Studio.** Extractions record base and mutated finds (`Logic/Collection.luau`, unit-tested), announce new discoveries, and pay one-time milestones from `Config/Collection.luau`: first mutation 200, half the book 250, full book 1000 + title "Harbor Historian" (stored in `profile.titles`; displayed once cosmetics exist). The BOOK panel shows relics by rarity, ??? until found, with mutation badges. |
| Personal base with pedestals | **Code written 2026-09-29, not yet run in Studio.** 16 surface plots behind the shaft (`Config/Base.luau`), assigned when a profile loads, each with a name sign and 10 pedestals. Owners hold E to display an unsold relic (picker) or take it back. Displays save in `profile.base.displays` and are outside the inventory, so selling never takes them. Visitors see the relics; other players' prompts are hidden client-side. **Set Max Players to 16** in Game Settings so everyone gets a plot. |
| Daily currents modifier | **Code written 2026-09-29, not yet run in Studio.** Five currents in `Config/Currents.luau` (rarer loot, more mutations, longer oxygen, sharper creature hearing, better sell prices), rotating with the zone seed. Pure helpers in `Logic/Currents.luau` return modified config copies. Shown on a sign behind the boat and announced on join. |

**Testing squads in Studio:** Test tab → Clients and Servers → 2 players → Start. Use the SQUAD button in one window to invite the other.

## 6. Phase 3 progress (started 2026-09-29, ahead of the Phase 1 playtest, at the owner's request)

| Item | Status |
|---|---|
| **FTUE flow** (doc/01 §4) | **Code written, not yet run in Studio.** New players spawn at a separate, creature-free **tutorial cove** (`TutorialService`, 300 studs south of the harbor) and grab 3 Glowing relics only they can take (230 Coins, enough for a first upgrade). A client-only scripted creature rushes them after relic 3, then they climb out, are teleported to the harbor, and are guided to sell → upgrade → visit their base → squad tip. Step rules are pure and unit-tested (`Logic/Tutorial.luau`); the step saves in `profile.tutorial`. There's an objective banner with **Skip**, and targets get highlights. Players with any extraction skip it. In Studio, set a boolean attribute `ForceTutorial` on Workspace to replay it. Shared geometry helpers moved to `server/Util/Geometry.luau`. |
| Monetization, UI pass, style guide | Not started |
| Art and audio (models, room modules, sounds, icon) | Needs a builder/artist |

## 7. Next after Phase 1

Phase 2 starts with the data layer (ProfileStore + versioned template + migrations), then the zone generator from room modules. Extend `tests/run.luau` with economy and receipt-idempotency tests before `MonetizationService` exists.
