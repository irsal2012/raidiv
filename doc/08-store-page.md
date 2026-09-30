# 08: Store Page Copy

Ready to paste into Studio → File → Experience Settings → Basic Info → Description (paste the text between the ``` lines, max 1,000 characters). Follows doc/05 §3: hook first, then what's new, then how to play. Keep it accurate: don't promise content that isn't in the game yet.

## Title

`Deep Salvage`

During events, add a short tag: `Deep Salvage 🌊 FIRST TIDE`. Keep it under 50 characters.

## Description

```
Dive, loot, survive: can you make it back up?

Plunge into a flooded harbor city, grab glowing relics, and get out before your air runs dry... or something down there finds you.

🌊 NEW LAYOUT EVERY DAY: the Harbor rearranges itself daily, with a new current (rarer loot, glowing tides, calm waters...)
👀 3 CREATURES: the Drifter hunts your lamp, the Lurker strikes at noise, the Warden hunts heavy loot
🤝 SQUAD UP: dive with up to 4 friends, revive each other, ping relics and danger
📖 30 RELICS + rare mutations to collect
🏛️ YOUR OWN BASE: show off your best finds to everyone

HOW TO PLAY
• Press DIVE, swim down, hold E on relics
• Watch your oxygen, and climb the yellow ladder out to keep your loot
• Sell at the gold counter, upgrade at the blue locker, dive deeper

CONTROLS
Space / C: swim up / down · Shift: sprint · F: lamp · G: ping · X: drop relic · H: hide UI for clips
(Mobile: on-screen buttons)
```

## Update notes template

Put the latest update above the "HOW TO PLAY" block, and keep only the last one or two there.

```
🆕 UPDATE: <name> (<date>)
• <headline change>
• <second change>
• <fix players asked for>
```

## Icon and thumbnail briefs (for the artist)

Upload both on the start place: Creator Hub → Deep Salvage → Configure → Places → the starred place → **Icon** / **Thumbnails** (icon 512×512, thumbnails 1920×1080 under 3 MB). Current icon drafts are in `assets/marketing/`, drawn by `tools/make_icons.py`.

- **Icon:** one face, either the Warden looming out of the dark or a diver's helmet lit by a lamp. High contrast, readable at 50 px. Make 2–3 variants for testing (doc/05 §3).
- **Thumbnails (3–5):** action moments. A diver escaping with a glowing Legendary as the Warden closes in; a squad reviving a downed friend; a base full of rare relics; a Lurker lunging from a vent. Keep text off the image, or down to two words.

## Before going public

- Content maturity questionnaire answered for the **current** content (Creator Hub → Audience)
- Max Players = 16 (so every player gets a base plot)
- Robux item IDs pasted into `src/shared/Config/Monetization.luau`, or those items stay hidden
- The Phase 5 soft-launch targets in doc/03 are what decide when to go wider
