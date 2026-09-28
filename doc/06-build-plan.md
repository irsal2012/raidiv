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

## 5. Next after Phase 1

Phase 2 starts with the data layer (ProfileStore + versioned template + migrations), then the zone generator from room modules. Extend `tests/run.luau` with economy and receipt-idempotency tests before `MonetizationService` exists.
