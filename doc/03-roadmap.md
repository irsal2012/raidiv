# 03 — Step-by-Step Roadmap

Timeline assumes a team of 1–3. Solo developer: add ~50%. Each phase has **exit criteria**; don't move on until they're met.

---

## Phase 0 — Setup (Week 1)

- [ ] Create Roblox group (owns the experience; easier to add collaborators and receive revenue)
- [ ] Create experience with TEST and PRODUCTION places
- [ ] Set up toolchain and repo (see `02-tech-stack.md` §2)
- [ ] Set up CI (lint + format)
- [ ] Create task board with every item from this roadmap
- [ ] Create Discord server (closed for now, for testers)

**Exit:** code change in VS Code appears in Studio via Rojo; CI passes.

---

## Phase 1 — Prototype the fun (Weeks 2–3)

Goal: prove the core tension is fun with grey boxes and no art.

- [ ] Underwater swimming controller (3D movement, sprint, buoyancy feel)
- [ ] Oxygen system with UI gauge
- [ ] One grey-box zone with 5 rooms
- [ ] Relics: pickup, weight slows you, noise radius
- [ ] One creature (Drifter) with patrol/chase
- [ ] Extraction point; death drops loot
- [ ] Simple sell counter giving Coins

**Playtest:** 5–10 people (friends, Discord). Watch them play; don't explain.

**Exit:** testers voluntarily start a second and third dive, and describe a "one more relic" moment. If not, iterate here — no art until this is true.

---

## Phase 2 — Core systems (Weeks 4–6)

- [ ] ProfileStore data layer with versioned template
- [ ] Zone generator from room modules (build 10 grey-box modules)
- [ ] All 3 creatures with state machines
- [ ] Gear upgrade system (6 tracks × 5 levels), all numbers in `Config/`
- [ ] Squad system: party invites, shared dive, revive, pings
- [ ] Relic rarity + mutation system; collection book
- [ ] Personal base with display pedestals, visitable by others
- [ ] Daily currents modifier
- [ ] Analytics events from `02-tech-stack.md` §4.8
- [ ] Unit tests for loot tables, economy math, receipt handling

**Exit:** a full loop (dive → extract → sell → upgrade → dive deeper) works end to end with saved progress; no data loss on rejoin.

---

## Phase 3 — Art, audio, polish (Weeks 6–8, overlaps Phase 2)

- [ ] Visual style guide (color palette, lighting, fog density)
- [ ] Final room modules (20+) with ruins, kelp, lighting
- [ ] 30 relic models (reuse bases + material/mutation variants)
- [ ] 3 creature models + animations
- [ ] Surface hub: boat, market, base area
- [ ] Audio: ambience layers, breathing, creature cues, stingers
- [ ] UI pass: mobile-first buttons, readable at small sizes
- [ ] FTUE flow (see `01-game-design.md` §4)
- [ ] Monetization: 1 cosmetic suit set, 3–4 game passes (see `04-monetization-liveops.md`)
- [ ] Experience icon + 3–5 thumbnails (A/B-test later)

**Exit:** a stranger can play the first 5 minutes with no help and understand what to do.

---

## Phase 4 — Closed beta (Week 9)

- [ ] Invite 50–200 testers via Discord
- [ ] Performance testing on low-end phone
- [ ] Exploit testing (speed hacks, remote spam, pickup at distance)
- [ ] Complete content maturity questionnaire
- [ ] Bug bash; fix all data-loss and crash bugs
- [ ] Balance pass using analytics (dive duration, death rate, coin flow)

**Exit:** zero known data-loss bugs; mobile at acceptable FPS; median first session ≥ 10 min.

---

## Phase 5 — Soft launch (Weeks 10–11)

- [ ] Publish publicly with no big promotion
- [ ] Small sponsored-ad spend to bring ~5,000–10,000 players
- [ ] Monitor daily: D1 retention, session length, FTUE funnel, crashes
- [ ] Ship fixes every 2–3 days
- [ ] Test 2–3 thumbnail/icon variants

**Exit (targets):** D1 retention ≥ 25%, D7 ≥ 8%, average session ≥ 15 min. If under target, fix FTUE and core loop before Phase 6. Don't buy traffic into a leaky game.

---

## Phase 6 — Growth launch (Weeks 12–15)

- [ ] Launch update with a named event (e.g., "The First Tide")
- [ ] Scale sponsored ads
- [ ] Creator campaign (see `05-marketing-launch.md`)
- [ ] TikTok/Shorts content daily
- [ ] Open Discord publicly; codes for like/favorite milestones

**Exit:** stable or growing CCU week over week.

---

## Phase 7 — Live operations (ongoing)

| Cadence | Content |
|---|---|
| Weekly | New relic set or limited event, bug fixes, balance |
| Every 2 weeks | New cosmetic drop |
| Monthly | New zone or major feature (trading, Warden hunts, leaderboards) |
| Seasonal (~8–10 weeks) | Expedition Pass season + lore chapter |

Post-launch feature backlog (priority order):
1. Zone 2: Old Market
2. Leaderboards (deepest dive, richest base)
3. Trading with anti-dupe checks
4. Ranked "Deep Run" mode (no-death challenge runs)
5. Clans/crews with shared base

---

## Weekly rhythm once live

- **Monday:** review last week's analytics, pick fixes
- **Tue–Thu:** build update
- **Friday:** publish to TEST place, team plays it
- **Saturday morning:** release (weekends have peak players)
- **Sunday:** monitor, hotfix if needed
