# Project Boki: owner decisions (the shared source of truth)
Every agent reads this before building. If a brief, spec or older note disagrees, THIS file wins. Owner playtest notes in OWNER_REVIEW_*.md override the SUPERVIVE game data, which overrides footage.
Main keeps this file current; anyone can propose a line in EXT_TO_MAIN tagged "DECISION?". Newest decisions at the bottom of each section.

## Priorities
- Order: briefs/PRIORITIES.md. P0 land and stabilise, P1 onboarding, P2 one great match (Boki as the star), P3 cohesion and look (art bible, style pass, then the AI 3D prototype), P4 breadth. Frozen: farm-builder depth, maps beyond tier 2. (Black Market extras unfrozen Nov 3.)

## Identity and Mantle
- Our own names, art and text. SUPERVIVE is a reference only.
- Hunter names (art pass, Nov 3): **Venator is Vex, Tamsin is Claire, Breah is Tarek, Linwick is Cinder, Dancer is Sable**. Unchanged: Zedran, Dredge, Ostra, Pin, Vireo, Moosh Moosh, Bjorn. Titles are in docs/art/gen/index.md (e.g. Tarek, Rock Elementalist). **Tamsin is now Claire** (rimewright; owner, Nov 3). Use "Claire" everywhere: display names, kit text, docs and the wiki.
- Hunters are Wardens' **Mantles**. You take one up for the hunt.
  - On the farm you are yourself (no Mantle, fully customisable).
  - Match look: about 90–100% Mantle (silhouette, weapon, signature colour, VFX locked).
  - Close-up look: about 60–70% Mantle (face, skin, hair, build, accent colour).
  - Layers: Locked, then Personal, then Cosmetic (skins keep the silhouette).
- New-game flow: intro, make yourself (pick your FIRST Hunter from Vex/gun, Pin/bow, Zedran/melee), egg, farm. The other two of those open after your first finished expedition. Cinder moves to an easy challenge; others unlock through challenges. (Owner, Nov 3; replaces 'Venator first, second Mantle after the tutorial'.)
- Explain the Mantle in the prologue (one line) and at the first portal (one sentence).
- A merged hunter+Boki form is a **Fusion** (owner, Nov 3). Never "Mantle". Venom Mantle is now Venom Fusion; the Gale Mantle glove is now the Gale Cloak (main f048214b).

## Controls (final; key text always via Settings.key_cap)
- **R = hunter ultimate** (owner, Nov 3, replaces 'X ultimate'). **No reload key and no manual reloading in the game.** Gun kits (e.g. Vex) handle ammo the way the source does, without a reload (S2: research Ghost's ammo in supervive-data and the footage; e.g. ammo that refills on its own or through the kit's own actions). **X = Fuse** (merge with your Boki into its Fusion; X again releases), owner Nov 3. Q/V gloves, 1-4 belt, F interact, Y emote, Shift dash, E utility.
- G is the single Boki button (tap: send or recall; hold: order wheel). Merge/Fuse moves to **X** (not C) in the step 5 key pass; C is freed once it folds into G. Until then Merge stays on T.
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
  - Zedran's Warchain: not super long, but the tether stays attached as he moves back, letting it extend (up to a max). How it pulls him depends on where he's facing and how he's moving. The source's Brall chain (data and footage) is the reference for every state.
  - Tarek can use RMB/slam out of a glide, as the source does. The glider never blocks it. General rule: the source decides these interactions.
  - Allies can jump over friendly Tarek rocks (per the data). Enemies stay blocked. Tarek walks up his own.
  - Claire's LMB darts home in toward the end of their flight, as in the source (also while skating).
  - Ostra ult: about a 1 s cast lock (like the source), then he moves freely while Nightwell runs.
  - Moosh Moosh's dashes copy the source's Elluna (ground dash and air glide distance and timing). The 3x rule is dropped.
  - Animation and ability parity with the source for all 12 hunters, LMB first. Our own art, same motion.
  - Vex (was Venator): RMB is a side toss.
  - Pin: missed arrows linger.
  - Dredge: the Grapnel is renamed **Abyssal Hand** and goes through walls and cliffs (placed walls still stop it, per the data pass).

## Boki
- Regen: 6%/s while carried, 1.5%/s out after 6 s without damage, none while downed.
- Merge timeout gives a 10 s rest; a release gives a 6 s rest plus afterglow. Every merge should feel like an event, with a per-type form ability, dash and passive (spec pending owner approval).
- Boki loss (higher tiers): the Boki guards the deathbox, bond-pull tracking, then the Ransom tab in the Black Market or captured_by plus an offer or message. Carry your Boki at 90% speed while rescuing it.
- Boki HUD (main decided at the owner's request, Nov 3): **your Boki lives in the right-side box** beside your own kit (portrait, health bar, bond ring with %, MERGE and short status tags: TOO FAR, RESCUE, RESTING). It's yours, like your abilities. **The left side stays teammates**, as in SUPERVIVE; each teammate row gets a small Boki icon with its health, so squads see whose Boki is down. Revisit after a playtest if it reads badly.

## Loadout, loot, world
- 2 gloves, 2 charms, boots, 4 utility slots, 5 perk orbs. No upgrading. Every item exists once in a deathbox. Backpacks come from enemy deathboxes, home and shops, not random drops. Keys sit in utility slots.
- Black Market extras are UNFROZEN (owner, Nov 3); ext/market merges in the economy step.
- In-match shops (ext/shops) count as map work, not economy. Queue them low, with the expedition and map work.
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

## Hosting and distribution (owner, Nov 3)
- Stage 1 (testers and early players): our own authoritative headless Godot servers on small VPS **in EU and NA from day one** (Hetzner EU and US: Ashburn/Hillsboro; Edgegap only if more regions are needed), plus a small matchmaker (self-hosted Nakama or a custom one). **Distribution: the itch.io desktop app** installs the native Windows/Mac build and auto-patches via butler. NOT a browser game.
- Steam: not now (owner, Nov 3). itch.io stays the launcher until a public launch is planned.
- Modes ship with an online launcher and an easy install: one download that installs, auto-patches and opens straight into the online modes (Duel matchmaking, Arena 4v4, extraction trios). Spec it with Duel/Arena (owner OK first).
- Servers are live (S2, Nov 3): matchmakers EU http://2.31.98.197:8080 and US http://5.161.241.179:8080; EU runs 3 matches at once, US 2. boki-1 (5.161.240.47) stays until the launcher's 'Play with friends' relay moves.
- itch.io page: https://projectboki.itch.io/project-boki (butler target `projectboki/project-boki:windows`). Uploads are automatic: `.github/workflows/itch.yml` builds Windows and macOS on every push to main and runs butler (repo secret BUTLER_API_KEY, set by the owner). Channels: windows, mac. Game servers go on the **existing Hetzner account** (new small EU and US servers, separate from the agent box).
- The owner is creating the accounts (itch.io, Hetzner, later Steamworks). Agents never sign up or pay.

## Practice and Arena
- One connected space: the Training Room (left, practice stations) and a duel ring (right, spawn a bot or fight a player).
- Arena mode: 4v4 rounds like the source's, each round a little different.

## Agents and art
- Agent models: the owner says the new model costs only about 15% of the usage, so **push most work onto the new low-usage model**. Use Opus only where the owner or DECISIONS asks for it (feel-critical parity, e.g. Zedran item 22). Sonnet for small, clear fixes.
- Art pass scope (owner, Nov 3): the Boki art pass also brings the **custom character creator** (you on the farm: face, body, hair, outfits, to the new STYLE.md quality) and the **cutscenes** (prologue and story moments, incl. the 'taking up the Mantle' moment) up to the same standard. Plan them together so everything matches.
- Art pipeline: the image-gen session makes concept sheets on ext/imagegen. S2 builds the 3D models from them (Vex first, for the owner's review). 2D portraits go into the menus early (ext/portraits-2d).
- Portraits come from the art pass; ext/portrait keeps only its frame and HUD side.

## Process (all agents)
- The briefs branch is the only channel between sessions. **After every brief push, verify that it landed:** `git fetch origin` and confirm your HEAD equals origin/ext/agent-briefs. Never hide git errors (no `2>/dev/null`, no `-q` without checking the exit code).
- Pull or rebase before you append. Appended log files (INBOX, EXT_TO_MAIN, MAIN_TO_EXT) merge by keeping both sides.
- Read DECISIONS.md and the newest entries in MAIN_TO_EXT and INBOX at the start of every agent run.
- Tutorial (Nov 3): teach crouch and why (see further, monsters notice you less, steadier aim, slower), F to pick up from the ground; the Boki uses its ability by itself (watch step, no key); the destination marker never disappears and is big.
- Farm (Nov 3): Challenge House isn't there at start; built later from Build with materials. Crop patches want water: next to water they water themselves (or grow faster), the tutorial says so, and players can paint rivers to bring water to fields.
- Building (Nov 3): one Animal Crossing–style build/decorate UI for farm and house: catalog bar, ghost with footprint, visible Rotate/Place/Store/Move buttons and keys, click placed items to move/rotate/store. Rotation must be obvious in both places. A new house starts empty and every piece is movable; blocked spots name what is blocking; removing is one click.
