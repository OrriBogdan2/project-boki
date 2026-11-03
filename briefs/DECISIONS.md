# Project Boki: owner decisions (the shared source of truth)
Every agent reads this before building. If a brief, spec or older note disagrees, THIS file wins. Owner playtest notes in OWNER_REVIEW_*.md override the SUPERVIVE game data, which overrides footage.
Main keeps this file current; anyone can propose a line in EXT_TO_MAIN tagged "DECISION?". Newest decisions at the bottom of each section.

## Priorities
- Order: briefs/PRIORITIES.md. P0 land and stabilise, P1 onboarding, P2 one great match (Boki as the star), P3 cohesion and look (art bible, style pass, then the AI 3D prototype), P4 breadth. Frozen: farm-builder depth, Black Market extras, maps beyond tier 2.

## Identity and Mantle
- Our own names, art and text. SUPERVIVE is a reference only.
- Hunter names: **Venator is now Vex**. **Tamsin is now Claire** (rimewright; owner, Nov 3). Use "Claire" everywhere: display names, kit text, docs and the wiki.
- Hunters are Wardens' **Mantles**. You take one up for the hunt.
  - On the farm you are yourself (no Mantle, fully customisable).
  - Match look: about 90–100% Mantle (silhouette, weapon, signature colour, VFX locked).
  - Close-up look: about 60–70% Mantle (face, skin, hair, build, accent colour).
  - Layers: Locked, then Personal, then Cosmetic (skins keep the silhouette).
- Character creation is just you. The new-game flow is: intro, make yourself, egg, farm. Venator's Mantle is taken up at the first portal (the tutorial). The second Mantle is 1 of Zedran, Pin or Linwick, picked after the tutorial. Others unlock through challenges.
- Explain the Mantle in the prologue (one line) and at the first portal (one sentence).
- Merge forms must NOT be called "Mantle". New word pending (Fusion / Bond Form).

## Controls (final; key text always via Settings.key_cap)
- R reload, X hunter ultimate, Q/V gloves, 1-4 belt, F interact, Y emote, Shift dash, E utility.
- G is the single Boki button (tap: send or recall; hold: order wheel). **C becomes Merge** (C again releases) once C folds into G; Merge is on T until then.
- The Boki uses its own abilities when it judges best (it may have several). A manual option, if any, is on G's wheel.
- Secondary key binds exist (Settings > Controls).

## Movement and combat feel
- Walking off ledges is ALWAYS allowed (never block it).
- Explosions only for things that truly explode (kegs, big ultimates, bosses). No bursts, rings or discs on dashes, landings or resets. A ground ring means gameplay.
- Dashes follow WASD by default, slower and shorter (Vireo further). Wall kick and wall bounce for everyone. Ledges always responsive.
- An overheated glider still lifts you out of the abyss, at half strength, while it burns.
- Every interaction is chainable. Dash buffering: match SUPERVIVE (S2 researching); until then DashFlow's current hold-until-dash-ends behaviour stands. A hold animation never shows without the hold input.
- Per-hunter run speeds come from the game data.

## Kits
- Ability ranks: on level-up the player chooses which ability to rank. Maxing one unlocks its data bonus (pick one to max). Bots use `order`. Training: max all or pick your max, plus reset, from an Esc-menu Practice page.
- Hero specifics live in OWNER_REVIEW_1103.md and the MAIN_TO_EXT entries. Examples:
  - Zedran: RMB held indefinitely, with a perfect release; LMB hold scales.
  - Dancer: reset only on an empowered hit.
  - Claire: skate with an ice path; her LMB tracks while she skates. RMB: the ice spear emerges from her and travels to the target point (travel time grows with distance), with a push-like animation, not a throw. Ult: skating into it carries her forward a decent distance, then she's encased in ice and rooted until it ends or she cancels.
  - Ostra ult: about a 1 s cast lock (like the source), then he moves freely while Nightwell runs.
  - Moosh Moosh's dashes copy the source's Elluna (ground dash and air glide distance and timing). The 3x rule is dropped.
  - Animation and ability parity with the source for all 12 hunters, LMB first. Our own art, same motion.
  - Vex (was Venator): RMB is a side toss.
  - Pin: missed arrows linger.

## Boki
- Regen: 6%/s while carried, 1.5%/s out after 6 s without damage, none while downed.
- Merge timeout gives a 10 s rest; a release gives a 6 s rest plus afterglow. Every merge should feel like an event, with a per-type form ability, dash and passive (spec pending owner approval).
- Boki loss (higher tiers): the Boki guards the deathbox, bond-pull tracking, then the Ransom tab in the Black Market or captured_by plus an offer or message. Carry your Boki at 90% speed while rescuing it.
- Boki HUD: one box on the right (health, bond ring with %, MERGE and status tags). Teammates' Boki show as small icons by teammates on the left.

## Loadout, loot, world
- 2 gloves, 2 charms, boots, 4 utility slots, 5 perk orbs. No upgrading. Every item exists once in a deathbox. Backpacks come from enemy deathboxes, home and shops, not random drops. Keys sit in utility slots.
- Chests: 1–3 fixed, learnable groups per map, sparse, a mini objective.
- Breakables break in one hit. Kegs explode.
- The Hollow Crown is the beginner map. Harder tiers get their own maps, with apex threats (sound and sight hunting) and stealth.

## Farm and onboarding
- The builder is **Hob Brackenridge** (walk up, press E). B opens on Buildings. Sections show only what is buildable, plus "Talk to Hob for more".
- Farm tutorial (can't be skipped on a new save):
  - Place the house, which costs a little wood.
  - Get an axe and chop (with an animation).
  - Assign your Boki to a task.
  - Swing a hammer to help; starter Boki can build, and species have task skills.
  - The first-day gem bonus comes as one end reward.
- The fighting tutorial can be skipped.
- Top tracker = "Goals" (unlocks, mastery, milestones). Tutorial guidance is in-world.
- Farm islands are nearly unreachable without a bridge. The bridge pulls the island closer.
- Notices are bullet points in plain words.

## Modes and queues
- Extraction: one queue, squads of 3, auto-filled (solos are filled in, bots backfill early). No solo or duo queue.
- Duel: 1v1, online search or against a bot. Arena: 4v4 across several arena maps.

## Practice and Arena
- One connected space: the Training Room (left, practice stations) and a duel ring (right, spawn a bot or fight a player).
- Arena mode: 4v4 rounds like the source's, each round a little different.

## Agents and art
- Agent models: Opus for feel-critical, parity, cross-hero and design work. Sonnet only for small, clear fixes.
- Portraits come from the art pass; ext/portrait keeps only its frame and HUD side.

## Process (all agents)
- The briefs branch is the only channel between sessions. **After every brief push, verify that it landed:** `git fetch origin` and confirm your HEAD equals origin/ext/agent-briefs. Never hide git errors (no `2>/dev/null`, no `-q` without checking the exit code).
- Pull or rebase before you append. Appended log files (INBOX, EXT_TO_MAIN, MAIN_TO_EXT) merge by keeping both sides.
- Read DECISIONS.md and the newest entries in MAIN_TO_EXT and INBOX at the start of every agent run.
