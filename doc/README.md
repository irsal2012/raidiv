# Deep Salvage — Roblox Game Plan

A co-op underwater extraction game for players 13+. Squads of 1–4 dive into a flooded, sealed-off city, grab valuable relics, and try to get back to the surface before their oxygen runs out or something down there finds them.

## Files in this plan

| File | What it covers |
|---|---|
| `01-game-design.md` | Concept, core loop, progression, systems, content scope for launch |
| `02-tech-stack.md` | Free tools, project architecture, data, networking, security, CI/CD |
| `03-roadmap.md` | Step-by-step build plan, week by week, with exit criteria |
| `04-monetization-liveops.md` | Revenue design, pricing, economy, update cadence |
| `05-marketing-launch.md` | Soft launch, growth, creators, community, KPIs |
| `06-build-plan.md` | Repo scaffold status, decisions, Phase 1 task breakdown, open questions |
| `07-style-guide.md` | Mood, colour, room-module builder spec, asset list, UI rules |
| `08-store-page.md` | Store description, update-notes template, icon/thumbnail briefs, pre-launch checklist |

## Guiding principles

1. **Retention beats everything.** Roblox's discovery system rewards playtime and returning players far more than raw visits. Every feature must answer: *does this make players stay longer or come back tomorrow?*
2. **Launch small, iterate fast.** Ship a tight Minimum Viable Game (MVG), measure, fix, then scale marketing.
3. **Fun in the first 60 seconds.** No tutorial walls. The player should be underwater within one minute of joining.
4. **Fair monetization.** Cosmetics and convenience, never pay-to-win.
5. **Server authority.** Anything valuable (relics, currency, trades) is decided on the server only.

## Assumptions

- Team: 1–3 people (programmer, builder/artist, optional marketer). Timelines in `03-roadmap.md` assume this; a solo developer should add ~50%.
- Budget: $0 for tools (everything listed is free). Marketing needs some Robux for ads and creator deals, estimated in `05-marketing-launch.md`.
- Platform rules and tools change often. Re-check Roblox's Creator Hub documentation for policies (content maturity, paid random items, voice chat, age checks) before launch.
