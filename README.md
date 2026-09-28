# Deep Salvage

A co-op underwater extraction game for Roblox (13+). Squads of 1–4 dive into a flooded, sealed-off city, grab valuable relics, and try to get back to the surface before their oxygen runs out or something down there finds them.

**Status:** Phase 1 prototype, which is a grey-box loop built in code. It builds, and lint, format, tests and strict type checks pass in CI. It has not been playtested in Studio yet. See [doc/06-build-plan.md](doc/06-build-plan.md).

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
| Swim | WASD + camera, Space to rise | Left stick | Thumbstick |
| Sprint (hold) | Shift | L3 | Sprint button |
| Toggle lamp | F | Y | Lamp button |

Climb out of the shaft to extract. Sell relics at the gold counter by the boat.

## Development

| Command | What it does |
|---|---|
| `lune run tests/run` | Unit tests for pure game logic (loot, oxygen, swim speed, config invariants) |
| `selene src` | Lint |
| `stylua src tests` | Format (`--check` to verify only) |
| `rojo sourcemap default.project.json -o sourcemap.json` | Sourcemap for luau-lsp in VS Code |

CI (`.github/workflows/ci.yml`) runs the format check, lint, tests and a strict `luau-lsp analyze` on every push and pull request.

Recommended VS Code extensions: **Luau Language Server** (JohnnyMorganz.luau-lsp), **StyLua** (JohnnyMorganz.stylua), and **Rojo** (evaera.vscode-rojo).

## Project layout

```
src/
├── shared/      → ReplicatedStorage.Shared
│   ├── Config/    All tuning numbers: relics, gear, oxygen, swim, creatures
│   ├── Logic/     Pure game math, no Roblox APIs, so it's unit-testable
│   ├── Net/       RemoteEvent registry
│   └── Types.luau Profile and dive state types
├── server/      → ServerScriptService.Server
│   ├── Services/  Greybox, Dive, Relic, Creature, Economy, PlayerData
│   └── Util/      Rate limiter
└── client/      → StarterPlayerScripts.Client
    └── Controllers/ HUD, sprint, lamp input
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
