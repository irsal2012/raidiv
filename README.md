# Deep Salvage

A co-op underwater extraction game for Roblox (13+). Squads of 1–4 dive into a flooded, sealed-off city, grab valuable relics, and try to get back to the surface before their oxygen runs out or something down there finds them.

**Status:** Grey-box game with Phase 1–3 systems in code: a seeded zone generator, 3 creatures, squads with revive and pings, saving, a collection book, player bases, daily currents, a tutorial, sonar, a shop with safe Robux handling, anti-cheat flags, and audio plumbing. Lint, format, 35 unit tests and strict type checks pass in CI. Most of it has **not yet been playtested** in Studio, and the art is still grey boxes. See [doc/06-build-plan.md](doc/06-build-plan.md).

## Quick start

Requirements: [Roblox Studio](https://create.roblox.com), [VS Code](https://code.visualstudio.com), and [Rokit](https://github.com/rojo-rbx/rokit).

```bash
# Install Rokit (macOS/Linux), then open a new terminal
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash

git clone https://github.com/irsal2012/raidiv.git
cd raidiv
rokit install        # Rojo, Wally, Selene, StyLua, luau-lsp, Lune (versions pinned in rokit.toml)
wally install        # Luau packages into Packages/
```

Then run the game in one of two ways:

- **Live sync (for development):** run `rojo serve`, open an empty Baseplate place in Studio, and connect with the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/). Saving a file in VS Code updates Studio.
- **One-off build:** run `rojo build -o build/DeepSalvage.rbxl` and open the file in Studio.

Press **Play**. For co-op, use **Test → Clients and Servers** with 2–4 players.

### Controls

| Action | Keyboard | Gamepad | Mobile |
|---|---|---|---|
| Dive | DIVE button | DIVE button | DIVE button |
| Swim | WASD + camera | Left stick | Thumbstick |
| Swim up / down | Space / C or Ctrl | A / L2 | Up / Down buttons |
| Take relic / use counter, locker, pedestal | Hold E | Hold X | Tap prompt |
| Sprint (hold) | Shift | L3 | Sprint button |
| Toggle lamp | F | Y | Lamp button |
| Ping for squad | G | R1 | Ping button |
| Drop heaviest relic | X | B | Drop button |
| Hide UI (clip mode) | H | | |
| **Studio only:** +5000 Coins, +500 Pearls | P | | |
| **Studio only:** summon the Warden in your room (while diving) | K | | |

Climb the yellow ladder out of the shaft to extract. Sell at the gold counter, upgrade at the blue locker, and use the SQUAD, BOOK and SHOP buttons at the top left. To replay the new-player tutorial in Studio, add a boolean attribute `ForceTutorial` to Workspace. To reproduce a zone layout, add a number attribute `ZoneSeed`.

## Development

| Command | What it does |
|---|---|
| `lune run tests/run` | Unit tests for pure game logic (loot, oxygen, swim speed, config invariants) |
| `selene src` | Lint |
| `stylua src tests` | Format (`--check` to verify only) |
| `rojo sourcemap default.project.json -o sourcemap.json` | Sourcemap for luau-lsp in VS Code |
| `python tools/make_sounds.py` | Regenerate the game sounds into `assets/audio/` (needs numpy, scipy, ffmpeg); upload them and paste the ids into `Config/Audio.luau` |

CI (`.github/workflows/ci.yml`) runs the format check, lint, tests and a strict `luau-lsp analyze` on every push and pull request.

Recommended VS Code extensions: **Luau Language Server** (JohnnyMorganz.luau-lsp), **StyLua** (JohnnyMorganz.stylua), and **Rojo** (evaera.vscode-rojo).

## Project layout

```
src/
├── shared/      → ReplicatedStorage.Shared
│   ├── Config/    All tuning numbers and content: relics, gear, creatures, zone, currents, shop, audio ids
│   ├── Logic/     Pure game math, no Roblox APIs, so it's unit-testable
│   ├── Net/       RemoteEvent registry
│   └── Types.luau Profile and dive state types
├── server/      → ServerScriptService.Server
│   ├── Services/  One module per system (Dive, Creature, Squad, Base, Tutorial, Monetization, ...)
│   ├── Util/      Rate limiter, grey-box geometry
│   └── Vendor/    ProfileStore (official source, pinned)
└── client/      → StarterPlayerScripts.Client
    └── Controllers/ HUD and panels, input, audio, tutorial, UI scaling
tests/           Lune test runner
doc/             Design docs and build plan
```

### Conventions

- **Server authority:** the server decides pickups, prices, oxygen, deaths and extraction. Clients only send input, and every remote is rate-limited and type-checked.
- **Services and controllers:** each module in `Services/` or `Controllers/` may export `init(modules)` and `start()`. All `init`s run first to wire up dependencies, without yielding. Then all `start`s run.
- **Config is data:** balance changes go in `src/shared/Config/`, not in service code.
- **Testable logic:** modules in `Config/` and `Logic/` use no Roblox APIs and no instance requires. Logic takes config and an RNG as arguments, so the same code runs in Studio and under Lune.
- Every file starts with `--!strict`.

## Design docs

| Doc | Covers |
|---|---|
| [01 Game design](doc/01-game-design.md) | Concept, core loop, systems, launch scope |
| [02 Tech stack](doc/02-tech-stack.md) | Tools, architecture, data, security |
| [03 Roadmap](doc/03-roadmap.md) | Phases with exit criteria |
| [04 Monetization & live ops](doc/04-monetization-liveops.md) | Revenue, pricing, economy, event calendar |
| [05 Marketing & launch](doc/05-marketing-launch.md) | Soft launch, creators, KPIs |
| [06 Build plan](doc/06-build-plan.md) | Current status, decisions, open questions |
| [07 Style guide](doc/07-style-guide.md) | Mood, colour, room-module builder spec, UI rules |
| [08 Store page](doc/08-store-page.md) | Store description, thumbnails brief, pre-launch checklist |
