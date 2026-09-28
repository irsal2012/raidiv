# 02 — Technology Stack (All Free)

> Tools in the Roblox ecosystem move fast. Check each project's GitHub page for its current status before adopting it.

## 1. Stack at a glance

| Area | Tool | Why |
|---|---|---|
| Engine / IDE | **Roblox Studio** | Required; free |
| Language | **Luau** with `--!strict` type checking | Catches bugs early; Roblox's native language |
| Code editor | **VS Code** + **Luau Language Server** (luau-lsp) extension | Autocomplete, types, go-to-definition |
| File sync | **Rojo** | Edit code as files in VS Code, sync into Studio, use Git |
| Toolchain manager | **Rokit** (or Aftman) | Pins versions of Rojo, Wally, Selene, StyLua per project |
| Packages | **Wally** | Package manager for Roblox libraries |
| Linter | **Selene** | Catches common Luau mistakes |
| Formatter | **StyLua** | Consistent formatting |
| Tests | **Jest-Lua** (Roblox's open-source port of Jest) or **TestEZ** | Unit tests for economy, loot tables, trade logic |
| Version control | **Git + GitHub** (free private repos) | History, branches, reviews |
| CI | **GitHub Actions** (free minutes) | Lint + format + tests on every push |
| Deployment | **Roblox Open Cloud** API (place publishing) or **Mantle** (infrastructure-as-code) | One-command publishing to test and production places |
| Player data | **ProfileStore** (by loleris) on top of DataStoreService | Session locking prevents item duplication |
| Networking | **Zap** or **ByteNet** (typed, compact remotes), or plain RemoteEvents to start | Less bandwidth, typed payloads |
| UI | **Fusion** or **React-Lua** | Declarative, reactive UI |
| NPC pathfinding | **PathfindingService** + **SimplePath** module | Creature movement |
| Analytics | **Roblox AnalyticsService** + Creator Dashboard | Funnels, economy, custom events — built in and free |
| 3D modeling | **Blender** | Relics, creatures, ruins |
| Textures / 2D | **Krita** or **GIMP**; **Inkscape** for icons | UI and textures |
| Audio | **Audacity** + Roblox Creator Store free audio | Ambience, SFX, creature sounds |
| Animation | Roblox **Animation Editor** (built into Studio) | Creature and emote animations |
| AI helper | **Roblox Studio Assistant** (built in) | Boilerplate, quick asset placement |
| Project mgmt | **GitHub Projects** or **Trello** free tier | Task board |
| Community | **Discord** | Player community, feedback, update leaks |

## 2. Project setup (step by step)

1. Install Roblox Studio, VS Code, Git.
2. Install Rokit, then in an empty folder:
   ```bash
   rokit init
   rokit add rojo-rbx/rojo
   rokit add UpliftGames/wally
   rokit add Kampfkarren/selene
   rokit add JohnnyMorganz/StyLua
   rojo init
   wally init
   ```
3. Add dependencies to `wally.toml` (ProfileStore, Fusion or React, Zap/ByteNet, Jest-Lua), then `wally install`.
4. Install the Rojo plugin in Studio and the Rojo + Luau LSP extensions in VS Code.
5. Run `rojo serve`, connect from Studio. Code now lives in Git.
6. Create **two places** in one experience: `Deep Salvage [TEST]` (private) and `Deep Salvage` (public).
7. Add a GitHub Actions workflow running `selene src`, `stylua --check src`, and tests.

## 3. Folder structure

```
deep-salvage/
├── default.project.json        # Rojo mapping
├── wally.toml
├── rokit.toml
├── selene.toml
├── .github/workflows/ci.yml
└── src/
    ├── shared/                  # ReplicatedStorage
    │   ├── Config/              # Relics, gear, zones, prices (pure data tables)
    │   ├── Types.luau
    │   └── Net/                 # Remote definitions
    ├── server/                  # ServerScriptService
    │   ├── Services/
    │   │   ├── DataService.luau       # ProfileStore wrapper
    │   │   ├── DiveService.luau       # Instances, oxygen, extraction
    │   │   ├── ZoneGenerator.luau     # Room-module assembly
    │   │   ├── RelicService.luau      # Spawns, pickup, loot tables
    │   │   ├── CreatureService.luau   # AI state machines
    │   │   ├── EconomyService.luau    # Sell, buy, upgrades
    │   │   ├── MonetizationService.luau # MarketplaceService receipts
    │   │   └── AnalyticsService.luau  # Event wrapper
    │   └── init.server.luau
    └── client/                  # StarterPlayerScripts
        ├── Controllers/
        │   ├── SwimController.luau
        │   ├── LampController.luau
        │   ├── AudioController.luau
        │   └── CameraController.luau
        └── UI/                  # Fusion/React components
```

**Pattern:** simple Service (server) / Controller (client) modules with explicit `init()` and `start()` phases. No heavy framework needed.

## 4. Key technical designs

### 4.1 Dive instances
- Option A (simplest): each squad's dive runs in a **separate region of the same server** (zones spaced far apart, streamed in with `StreamingEnabled`).
- Option B (scales better): **TeleportService reserved servers** per squad dive. Carry the squad's state via teleport data + DataStore.
- Start with A for the MVG; move to B if server performance suffers.

### 4.2 Zone generation
- Build 20–30 hand-made **room modules** with tagged door attachments.
- Server assembles a graph from a seed: start room → branching rooms → dead ends with loot → extraction points.
- Seed is stored per dive for debugging and "seed of the day" events.

### 4.3 Creature AI
- Finite state machine on the server: `Patrol → Investigate(noise/light) → Chase → Search → Return`.
- Perception: noise radius events from players (sprint, heavy load, dropping relics) + raycast line of sight to lamp.
- Keep AI count low (3–6 per dive); use `Heartbeat` throttling (update every 0.2 s, not every frame).

### 4.4 Data (ProfileStore)
```lua
-- Profile template
{
    version = 1,
    coins = 0,
    pearls = 0,
    level = 1,
    xp = 0,
    gear = { tank = 1, fins = 1, lamp = 1, bag = 1, sonar = 0, suit = 1 },
    inventory = {},        -- relic instances {id, relicKey, mutation, obtainedAt}
    base = { displays = {} },
    collection = {},       -- discovered relicKeys
    cosmetics = { owned = {}, equipped = {} },
    purchases = {},        -- processed receipt IDs (idempotency)
    stats = { dives = 0, extractions = 0, deaths = 0 },
}
```
- Always include a `version` field and write migration functions.
- Give every relic a unique ID (use `HttpService:GenerateGUID()`) for trade auditing later.

### 4.5 Monetization plumbing
- `MarketplaceService.ProcessReceipt`: grant the item, save, and only then return `PurchaseGranted`. Store the receipt ID to prevent double-granting.
- Game passes checked with `UserOwnsGamePassAsync` on join, cached.

### 4.6 Security / anti-exploit
- **Never trust the client** for: relic pickup, sell price, currency, extraction success, oxygen death.
- Server validates distance on every pickup (`player is within N studs of relic`).
- Server-side sanity checks on movement speed (flag teleporting/speed hacks, don't auto-ban on first flag).
- Rate-limit every RemoteEvent.
- Log economy anomalies (e.g., coins gained per minute > threshold) to analytics.

### 4.7 Performance targets
- Mobile first: over half of Roblox players are on phones. Test on a low-end Android device weekly.
- Enable `StreamingEnabled`. Keep part count per room module low; use MeshParts.
- Target: 60 FPS on mid phones, < 700 MB client memory, server heartbeat stable at 60.

### 4.8 Analytics events (minimum set)
| Event | Why |
|---|---|
| FTUE funnel steps (join, first dive, first relic, first extraction, first upgrade) | Find where new players quit |
| Dive start / end (result, duration, loot value, depth) | Balance difficulty |
| Economy source/sink (coins earned/spent by reason) | Detect inflation |
| Shop view / purchase | Conversion rate |
| Squad size per dive | Is co-op working? |

Use `AnalyticsService:LogFunnelStepEvent`, `LogEconomyEvent`, and `LogCustomEvent`.

## 5. CI example (`.github/workflows/ci.yml`)

```yaml
name: CI
on: [push, pull_request]
jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: CompeyDev/setup-rokit@v0.1.2
      - run: stylua --check src
      - run: selene src
```
Add a test step and an Open Cloud publish step (to the TEST place only) once the basics work. Store the Open Cloud API key in GitHub Secrets.
