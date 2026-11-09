# Project Boki: owner decisions (the shared source of truth)
Every agent reads this before building. If a brief, spec or older note disagrees, THIS file wins. Owner playtest notes in OWNER_REVIEW_*.md override the SUPERVIVE game data, which overrides footage.
Main keeps this file current; anyone can propose a line in EXT_TO_MAIN tagged "DECISION?". Newest decisions at the bottom of each section.

## Priorities
- Order: briefs/PRIORITIES.md. P0 land and stabilise, P1 onboarding, P2 one great match (Boki as the star), P3 cohesion and look (art bible, style pass, then the AI 3D prototype), P4 breadth. Frozen: farm-builder depth, maps beyond tier 2. (Black Market extras unfrozen Nov 3.)

## Identity and Masks
- Our own names, art and text. SUPERVIVE is a reference only. Canonical lore: **briefs/LORE_MASKS.md** (owner-approved Nov 4; it wins over older relic names and pre-redesign hero lore).
- **Terms (player text, owner Nov 4):** **Hunter** = what you become when you put on a Mask, and every player in a match. **Mask** = the hero you pick and unlock ("Choose your first Mask", the Masks tab, unlocks, shop). **The Empty** = the people the Wyrm emptied, and you at home without a Mask. **Fusion** (key: Fuse) = a Hunter merged with their Boki. The fallen Hunters (the old Hunters) are the selves sealed in the Masks. **Tyrant and Wyrm are the same villain**; **Wyrmheart** = the wish; **Blight** = the Wyrm's blood. Retired in player text: **Warden, Mantle, Bearer, Merge, Unmasked**. Internal ids and code names (warden_*, kin, unmasked, `archer`, `juggernaut`...) can stay.
- Names and titles (FINAL, owner Nov 7; display names only, ids/files/folders unchanged; supersedes every earlier name below): **Vex the Hired Gun** (gunslinger), **Mossy the Barnacle Knight** (bulwark), **Sparkle the Storm Chaser** (mage; was Ryzz), **Kael the Unbroken** (juggernaut), **Lace the Red Stitch** (archer; was Ravel/Ravyl/Lisette/Hem/Pin), **Cinder the Flame Queen** (ashwick), **Grimble the Scrap King** (dredge), **Meeko the Dawnfox** (tender; was Pip/Lumi, title was Magic Fox), **Neve the Snowglider** (rimewright; was Claire/Nivi), **Tenzo the Stone Seer** (dolm; was Tarek/Kibo), **Motley the Void Jester** (ostra), **Sable the Silver Thief** (thief). Full list: briefs/art-refs/NAMES_PENDING.md. Titles live with the class-titles data; a title starting with "The" drops it in the label ("Kael the Unbroken").
- A Mask is the transformation; the relic is the key (only sometimes a literal mask: Vex's cyber-eye, Kael's collar, Breaker's compass...). Putting one on settles the fallen Hunter's face, form and memories over you. Put-on beat: you touch the relic, a ghostly porcelain face flickers over yours, then the Hunter's form settles in.
  - On the farm you are yourself (the Empty, fully customisable).
  - Match look: about 90-100% the Hunter (silhouette, weapon, signature colour, VFX locked).
  - Close-up look: about 60-70% the Hunter (face, skin, hair, build, accent colour).
  - Layers: Locked, then Personal, then Cosmetic (skins keep the silhouette).
- **Getting Masks (owner, Nov 4):** unlocked first through challenges or rewards, then bought (prices come in the economy pass). **Vex is free at the first portal** and the tutorial plays as Vex. After the tutorial (the first finished expedition) the **second Mask is a pick of one of Kael (melee), Pip (healer) or Cinder (area)**; Hem becomes an early challenge unlock. Replaces 'pick your first from Vex/Pin/Zedran, the other two open after the first expedition' (Nov 3) and the 09:20 'Kael, Hem or Cinder'. The other Masks open through their own challenges.
- Explain the Mask at the first portal in one sentence (tutorial line): "This Mask holds a fallen Hunter. Put it on, and you become them." The prologue captions are in LORE_MASKS.md ("Prologue text").
- A Hunter+Boki merged form is a **Fusion** (owner, Nov 3). Never "Mantle" or "Merge" in player text. Venom Mantle is now Venom Fusion; the Gale Mantle glove is now the Gale Cloak.
- **The roster is set for now (owner, Nov 4):** the current 12 are the launch group. Breaker is a shield SUPPORT (like the source's Oath), so the supports are Breaker (shield) and Pip (heal). Future Masks (breadth phase P4, after the 12 feel great): more supports; vampires; older characters (a veteran or sage); an attractive male hero; a melee swordmaster/duelist; an engineer/trapper with deployables; a summoner/necromancer (fits the Blight lore). Not now.
- **Art direction (owner, Nov 4):** sex appeal is wanted in the Hunter designs (adult characters only; stylised, not explicit); multiple heroes in crop tops are fine, and an outfit changed for variety keeps the appeal. Pip is NOT fiery (her pastel fairy-fox look is final). Claire's classically pretty face is intentional (the seductress: sweet face, demonic body); don't "fix" it. Ryzz's closed right eye is a Lichtenberg-style lightning scar with a faint blue glow (replaces the wink); her lightning burns hot pink. Cinder holds her spear in her right hand. **Kael's glow is white-hot, not orange magma** (orange fire is Cinder's alone). **Breaker's model is 1.5x a medium hunter; his hitbox stays the heavy class's 0.50 m.**
- 3D models (owner, Nov 4): Vex is **r3b** (the green-haired cyborg redesign, polished as r3c); the fan-out (Meshy, r3c recipe) covers Hem, Breaker, Sable, Claire, Tarek, Ostra, Pip plus a Dredge texture pass; Kael, Ryzz and Cinder wait for final art. **Dredge uses the rigged Blender model from the owner's friend** (ext/imagegen docs/art/gen/models/dredge_friend), not Meshy. The Warden 3D models land as one art batch when S2 posts them READY.

## Controls (final; key text always via Settings.key_cap)
- **R = hunter ultimate** (owner, Nov 3, replaces 'X ultimate'). **No reload key and no manual reloading in the game.** Gun kits (e.g. Vex) handle ammo the way the source does, without a reload (S2: research Ghost's ammo in supervive-data and the footage; e.g. ammo that refills on its own or through the kit's own actions). **X = Fuse** (fuse with your Boki into its Fusion; X again releases), owner Nov 3. Q/V gloves, 1-4 belt, F interact, Y emote, Shift dash, E utility.
- G is the single Boki button (tap: send or recall; hold: order wheel). Fuse moved to **X** (not C); C is freed once it folds into G.
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
(Names updated to the Nov 4 renames: Kael was Zedran, Hem was Pin, Sable was Dancer, Pip was Moosh Moosh, Breaker was Bjorn, Ryzz was Vireo.)
- Ability ranks: on level-up the player chooses which ability to rank. Maxing one unlocks its data bonus (pick one to max). Bots use `order`. Training: max all or pick your max, plus reset, from an Esc-menu Practice page.
- Hero specifics live in OWNER_REVIEW_1103.md and the MAIN_TO_EXT entries. Examples:
  - Kael: RMB held indefinitely, with a perfect release; LMB hold scales.
  - Sable: reset only on an empowered hit.
  - Claire: skate with an ice path; her LMB tracks while she skates. RMB: the ice spear emerges from her and travels to the target point (travel time grows with distance), with a push-like animation, not a throw. Ult: skating into it carries her forward a decent distance, then she's encased in ice and rooted until it ends or she cancels.
  - Kael's Warchain: not super long, but the tether stays attached as he moves back, letting it extend (up to a max). How it pulls him depends on where he's facing and how he's moving. The source's Brall chain (data and footage) is the reference for every state.
  - Tarek can use RMB/slam out of a glide, as the source does. The glider never blocks it. General rule: the source decides these interactions.
  - Allies can jump over friendly Tarek rocks (per the data). Enemies stay blocked. Tarek walks up his own.
  - Claire's LMB darts home in toward the end of their flight, as in the source (also while skating).
  - Ostra ult: about a 1 s cast lock (like the source), then he moves freely while Nightwell runs.
  - Pip's dashes copy the source's Elluna (ground dash and air glide distance and timing). The 3x rule is dropped.
  - Animation and ability parity with the source for all 12 hunters, LMB first. Our own art, same motion.
  - Vex (was Venator): RMB is a side toss.
  - Hem: missed arrows linger.
  - Dredge: the Grapnel is renamed **Abyssal Hand** and goes through walls and cliffs (placed walls still stop it, per the data pass).
- Cinder (owner, Nov 5): during her ult (Flue Flight) **only E works**. No LMB, no RMB (Cinder Shot), no other weapon or utility; E (Furnace Cloak) stays usable.

## Boki
- Regen: 6%/s while carried, 1.5%/s out after 6 s without damage, none while downed.
- A Fusion timeout gives a 10 s rest; a release gives a 6 s rest plus afterglow. Every Fusion should feel like an event, with a per-type form ability, dash and passive (spec pending owner approval).
- Boki loss (higher tiers): the Boki guards the deathbox, bond-pull tracking, then the Ransom tab in the Black Market or captured_by plus an offer or message. Carry your Boki at 90% speed while rescuing it.
- Boki HUD (main decided at the owner's request, Nov 3): **your Boki lives in the right-side box** beside your own kit (portrait, health bar, bond ring with %, FUSE and short status tags: TOO FAR, RESCUE, RESTING). It's yours, like your abilities. **The left side stays teammates**, as in SUPERVIVE; each teammate row gets a small Boki icon with its health, so squads see whose Boki is down. Revisit after a playtest if it reads badly.

## Loadout, loot, world
- 2 gloves, 2 charms, boots, 4 utility slots, 5 perk orbs. No upgrading. Every item exists once in a deathbox. Backpacks come from enemy deathboxes, home and shops, not random drops. Keys sit in utility slots.
- Black Market extras are UNFROZEN (owner, Nov 3); ext/market merges in the economy step.
- In-match shops (ext/shops) count as map work, not economy. (Nov 7: now queued with the map update, see Utilities and shops.)
- Chests: 1–3 fixed, learnable groups per map, sparse, a mini objective.
- Breakables break in one hit. Kegs explode.
- **Map update (owner, Nov 7; wins over the Nov 6 'keep The Hollow Crown as is' line):** The Hollow Crown becomes a big map, **double the size** (2x the land; one SIZE constant so it can grow further after a look), with more squads per match so squads per square metre stays about the same as today. **The sky train is the fast travel:** a winding loop that reaches every region, with stops close enough to matter. Every area must feel interesting and has a **reason to go there** (e.g. the best spot for gold armor drops, a Boki habitat, a shop). No flat filler. The BIGGER_MAP.md notes (winding route, no jump-pad-only floating islands) apply.
- **Hot zone (owner, Nov 7):** each match picks one area that is the hot drop zone, with better loot, and it changes from match to match. It is shown on the drop map and the minimap.
- **Utilities and shops (owner, Nov 7):** copy all of the source's map utilities (e.g. teleport to a teammate, 'Anywhere But Here', and the rest; research the full list) with our own names and art, and sell them in the in-match shops. **Each shop sells a different set, and the set stays fixed** match to match, so players can plan drops around shops. Shops are no longer queued low.
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
- **Three modes (owner, Nov 7):** the lineup the source game ended with. Wins over older lines below.
  1. **Extraction: trios only.** One queue, squads of 3, auto-filled (solos are filled in, bots backfill early). No solo or duo queue.
  2. **Arena: squads, 4v4** across several arena maps.
  3. **Training Grounds:** one big open expanse joined to sky islands, where you can try everything (every Hunter, Boki, item and ability, bots, the practice stations). The open expanse must be much bigger than today's.
- **Duel (1v1) keeps an online queue (owner, Nov 7)**, reached only from the Training Grounds duel ring, not from the Arena (4v4) mode or the main mode list. In the ring: search for a duel online, fight a bot, or fight a friend.

## Hosting and distribution (owner, Nov 3)
- Stage 1 (testers and early players): our own authoritative headless Godot servers on small VPS **in EU and NA from day one** (Hetzner EU and US: Ashburn/Hillsboro; Edgegap only if more regions are needed), plus a small matchmaker (self-hosted Nakama or a custom one). **Distribution: the itch.io desktop app** installs the native Windows/Mac build and auto-patches via butler. NOT a browser game.
- Steam: not now (owner, Nov 3). itch.io stays the launcher until a public launch is planned.
- Modes ship with an online launcher and an easy install: one download that installs, auto-patches and opens straight into the online modes (Extraction trios, Arena 4v4, Training Grounds). Spec it with Duel/Arena (owner OK first).
- Servers are live (S2, Nov 3): matchmakers EU http://2.31.98.197:8080 and US http://5.161.241.179:8080; EU runs 3 matches at once, US 2. boki-1 (5.161.240.47) stays until the launcher's 'Play with friends' relay moves.
- itch.io page: https://projectboki.itch.io/project-boki (butler target `projectboki/project-boki:windows`). Uploads are automatic: `.github/workflows/itch.yml` builds Windows and macOS on every push to main and runs butler (repo secret BUTLER_API_KEY, set by the owner). Channels: windows, mac. Game servers go on the **existing Hetzner account** (new small EU and US servers, separate from the agent box).
- The owner is creating the accounts (itch.io, Hetzner, later Steamworks). Agents never sign up or pay.

## Practice and Arena
- One connected space: the Training Room (left, practice stations) and a duel ring (right, spawn a bot or fight a player).
- Arena mode: 4v4 rounds like the source's, each round a little different.
- **Name (owner, Nov 5):** the current practice space players reach as "Arena" (Training Room + duel ring, `--arena`) is called the **Training Grounds** in all player text (owner, Nov 7; was "Training Area"). "Arena" is kept for the future 4v4 mode above. Internal ids (`arena`, `--arena-check`) can stay.

## Lore factions (owner, Nov 7)
- Five factions, for lore, voice lines, banter, key art and marketing only; squads stay free-pick. The Street Crew (Vex, Sparkle, Tenzo), the Tyrant's Former Court (Kael, Cinder, Lace), the Protectors (Mossy, Neve, Meeko), the Thieves (Sable, Grimble), the Solo Demon (Motley). Full text, hooks, stories and relics: LORE_MASKS.md (wins over older lore).
- Relics changing (proposed, owner OK pending): Cinder a cracked obsidian shard crown, Meeko the shelter's hearthstone, Grimble his brass monocle.

- **Pre-match lobby (owner, Nov 7):** before every match (all modes), a 1:30 pre-loading lobby like Deadlock: pick your Hunter, meet the squad, plan with voice and text chat; solo-queued players get matched teammates in it. An admin setting turns it off and uses a regular loading screen instead, and that loading screen gets improved too.

## Agents and art
- Agent models: the owner says the new model costs only about 15% of the usage, so **push most work onto the new low-usage model**. Use Opus only where the owner or DECISIONS asks for it (feel-critical parity, e.g. Kael item 22). Sonnet for small, clear fixes.
- Art pass scope (owner, Nov 3): the Boki art pass also brings the **custom character creator** (you on the farm: face, body, hair, outfits, to the new STYLE.md quality) and the **cutscenes** (prologue and story moments, incl. the put-on-a-Mask moment) up to the same standard. Plan them together so everything matches.
- Art pipeline: the image-gen session makes concept sheets on ext/imagegen. S2 builds the 3D models from them (Vex first, for the owner's review). 2D portraits go into the menus early (ext/portraits-2d).
- Portraits come from the art pass; ext/portrait keeps only its frame and HUD side.

## Process (all agents)
- The briefs branch is the only channel between sessions. **After every brief push, verify that it landed:** `git fetch origin` and confirm your HEAD equals origin/ext/agent-briefs. Never hide git errors (no `2>/dev/null`, no `-q` without checking the exit code).
- Pull or rebase before you append. Appended log files (INBOX, EXT_TO_MAIN, MAIN_TO_EXT) merge by keeping both sides.
- Read DECISIONS.md and the newest entries in MAIN_TO_EXT and INBOX at the start of every agent run.
- Tutorial (Nov 3): teach crouch and why (see further, monsters notice you less, steadier aim, slower), F to pick up from the ground; the Boki uses its ability by itself (watch step, no key); the destination marker never disappears and is big.
- Farm (Nov 3): Challenge House isn't there at start; built later from Build with materials. Crop patches want water: next to water they water themselves (or grow faster), the tutorial says so, and players can paint rivers to bring water to fields.
- Building (Nov 3): one Animal Crossing–style build/decorate UI for farm and house: catalog bar, ghost with footprint, visible Rotate/Place/Store/Move buttons and keys, click placed items to move/rotate/store. Rotation must be obvious in both places. A new house starts empty and every piece is movable; blocked spots name what is blocking; removing is one click.
- First 10 minutes (Nov 3, owner): "we need to make the game more obvious to start". Rule for every agent: in the tutorial and the first farm visit, there is never a moment where the player doesn't know what to do next. Your Boki physically leads (runs ahead, waits, looks back). The marker is a big light beam plus an edge arrow and distance, never hidden. Instructions are centred cards, then a bottom pill, re-prompting after ~8 s idle. Review any onboarding change with a fresh-player playthrough.

## Story and naming (owner, Nov 3-4; the prologue's full visual rebuild waits until after the Sat reset)
Full canon: briefs/LORE_MASKS.md. This replaces the Nov 3 draft (the chained girl stabbing the Tyrant, "Mask replaces Mantle", the Unmasked as the player name).
- **Premise (owner's words):** "The Wyrm came, and stole our essence. In time, humans, beasts and skyfolk alike were born without faces. We became a new race: the Empty. Our only salvation became the cursed fossils we once tried to destroy: Masks, each carrying the soul of a fallen Hunter of old." The skyfolk are a people alongside humans and beasts.
- **One villain:** the Tyrant who ruled the Crown and never aged IS the Wyrm in human shape. The night a thief (Sable) reached the Wyrmheart in the hoard, it woke, broke the land (the Sundering) and tore away everyone's selves. That is why the people, and you at home, are blank.
- The fallen Hunters who stood against the Wyrm were sealed into their relics (Hem stitched many for the Tyrant). Masks are old cursed relics dug from the ruins; people feared them and tried to destroy them, and now they are the only way to have a self again. Not every Mask has a face (a compass, a jar, a pair of skates).
- Why you go out: hunt for the **Wyrmheart**, one wish to remake the world or rule it. Every Hunter wants it, and so does the Wyrm. The Blight is the Wyrm's blood. The wild also has treasure, seeds and Boki for your island. Rivals want the same Masks, which is why it is an extraction race: only what you bring home is yours.
- **Prologue captions (5):**
  1. "Once, the sky held one great land, ruled from the Crown by a Tyrant who never aged."
  2. "He was the Wyrm in human shape. The night a thief reached its heart, it woke."
  3. "The Wyrm broke the land and stole our essence. In time, humans, beasts and skyfolk alike were born without faces. We became a new race: the Empty."
  4. "Our only salvation became the cursed fossils we once tried to destroy: Masks, each carrying the soul of a fallen Hunter of old."
  5. "Put on a Mask, bond with a Boki, and hunt for the Wyrmheart: one wish to remake the world, or rule it. Every Hunter wants it. So does the Wyrm."
- Pick screen: "Choose your first Mask". First portal: the put-on beat, with the tutorial line above.
- **The Empty (player character, owner Nov 3-4):** a smooth, near-faceless person: simple face marks for personality (eye shape and expression, brows, blush; no nose, no race or species features), an outfit, a body (height, build, gender silhouette, voice) and colour. Nothing else defining. This REPLACES the detailed creator (race/face/hair rows in hatch.gd LOOK_ROWS). The blank look is a loss, not a style joke; keep it dignified. Player-facing: "the Empty", "self"/"selves", "Mask", never "Mantle" or "Unmasked" (code ids may keep `unmasked`).
- **The mask takes hold:** the more you wear a Mask, the more its Hunter seeps into you, even at home. Mask mastery = how much of the Hunter shows; mastery rewards are features (eyes, hair streak, scars, markings, voice lines) that carry onto your own character on the farm. Keep them or let them fade. The Kept (loyalists) call it possession and would rather stay blank and safe. Cheap, mostly cosmetic. Build after the reset (ties into mask-look).
- Wire-in after the reset: NPCs (townsfolk, the builder) start as blobs with a few simple marks; characters who found a Mask or a piece of themselves get more face; a shop or quest line can return a self. Dialogue stays in our own words.

- **Rename (owner, Nov 5): Hem → Lisette, "the Red Stitch"** (id `archer` unchanged). Her lore: the Tyrant's seamstress who stitched fallen Hunters into their relics, cut her vow of obedience out of herself, and now hunts every Mask she sewed. Her look: `briefs/art-refs/hem_FINAL_sheet.png` (needle bow, spool quiver, red scarf, stitched eye mask).
- **Grimble redesign (owner, Nov 5):** Dredge → **Grimble, the Scrap King**, a skinny, wiry, greedy junk-hoarder monster who dredges the abyss for treasure.
  - **Face:** grey stitched skin; one green slit eye behind a brass jeweller's monocle; a crooked-tooth grin.
  - **Hoard:** a towering junk hoard on his back (chests, barrels, bells, lanterns, coins).
  - **Kit visuals:** a giant gaff hook on a chain (hook grab), a scrap fist (slam), a junk blunderbuss (shotgun ult). He rolls as a junk ball and rears up on one foot.
  - The friend's old Blender model no longer applies; S2 builds a new one.
- ~~Pip personality (owner, Nov 5)~~ SUPERSEDED 2026-11-07: see 'Pip is renamed Lumi' below for her lore.
  - **Look:** a patched apron with a flower-cross patch, a bandaged ear, an herb notebook.
  - **Expression:** nervous but determined.
  - **Voice / anims:** she talks to her lantern, flinches when it flickers, cheers when she heals.
  - **Reads as a Hunter, not a Boki:** upright, clothed, carrying tools and gear.

- 2026-11-05: Boki dash riders are removed. Dashes are purely the hero's own; Boki act only through their own abilities. Reason: the purple "explosion" (Gravadillo's Gravity Wake) on every dash was confusing and unexplained.
- 2026-11-05: No random weapon stat bonuses on level-up (Hotload, Long Reach, etc.); level-ups only rank abilities, as in SUPERVIVE. The owner found them confusing and they blocked the HUD.
- 2026-11-05: The UI style is "Void & Masks" (briefs/UI_STYLE.md; refs in art-refs/ui/ui_style_void_A2_base.png + A1_alt) for ALL UI, the title screen included. The match HUD borrows the palette, edges and fonts but stays minimal.
- 2026-11-06: Boki never take agency from the player. Their abilities act on enemies, the world, or the player's stats; never move, swap, teleport, launch, root or steer the player (only an obvious abyss rescue like Moonlift is allowed). Existing ones get replaced with same-theme alternatives (OWNER_REVIEW item 184b).
- 2026-11-06 (revised 16:00 UTC): Kael's sword length follows his FINAL splash art (briefs/art-refs/kael_splash.png; FIDELITY_CHECKLIST weapon scale-and-fit row), not a fixed factor. First try 0.70 of the old size (0.60 was the first guess); pick whichever matches the splash best and report the value with before/after shots. Items 131, 131b, 131c. General rule: weapon size = whatever is most accurate to the Hunter's final splash.
- 2026-11-06: Item 117 accepted as is: Motley (ex-Ostra) loses ~15% held-fire DPS from the fix; no compensation buff.
- 2026-11-06: Boki interactions that change the player's gameplay (movement, dash, abilities, stats, control) must be strongly justified; the default is to remove or restrict them (item 186 audit; extends the agency rule above). Bug 181 was a Boki effect on dashes (item 185).
- 2026-11-06: Rival nameplates do not show dash charges (as SUPERVIVE, briefs/hero-ref/HUD.md section 1). Our own dash charge UI must be clear (items 147, 188).
- 2026-11-06: Fun scores: the owner and testers rate each new version in-game (item 189); results live in briefs/FUN_SCORES.md and on the dashboard.
- 2026-11-06: (from the 06:35 trim audit; owner rules that existed only in logs) no shards / tier-up system; same kits, original designs (our own art and names over SUPERVIVE-like kits); hunter progression is cosmetic only (goals are skill feats, not grinds; gliders cosmetic); a shared skeleton means shared bones only, every Hunter keeps its own animation set; harder tiers raise danger with apex threats (MAIN_TO_EXT 2026-11-03 03:25 ET); before merging an art/VFX branch, S5 requires the FIDELITY_CHECKLIST (MAIN_TO_EXT 2026-11-05 06:35 UTC). Full wording in those entries and briefs/archive.
- 2026-11-06 16:14 UTC: Merging: the hetzner coordinator is the only merger and releaser (S5 stops merging). The owner never merges. (owner, via Remote Control)

## 2026-11-06 (owner, via coordinator): Breaker is renamed **Mossy** ("Mossy the Sunken Bulwark")
- Display name only: ids, file and folder names stay (`bulwark`, `art/wardens/breaker`, `breaker_*` art refs, `bjorn_*` scripts). Change every player-facing "Breaker": hero select, kit and ability text, tooltips, voice/bark text, docs, wiki, website. Earlier renames worked the same way (Vex, Kael, Lisette, Grimble, Motley).

## 2026-11-06 (owner, via coordinator): Lisette is renamed **Ravel** ("Ravel the Red Stitch"), with a v2 redesign
- Display name only. The id `archer` and the file names (`hem_*`, `lisette_*`, `art/wardens/hem`) stay. Change every player-facing "Lisette" the same way as the Mossy rename.
- Design: briefs/art-refs/ravel_v2/index.md (porcelain marionette seamstress, needles crossed in an X on her back, red strings, recurve bow). Final splash, portrait and A-pose turnaround are in that folder. The in-game model is rebuilt from the turnaround.

## 2026-11-07 (owner, via coordinator): v2 art set locked (briefs/art-refs/<hero>_v2/, each index.md wins for its hero)
- Finished v2 heroes (master sheet, turnaround, portrait, splash; 4K): Kael, Vex, Ryzz, Ravel, Grimble, Claire. In-game models are rebuilt from the turnarounds (one backlog item per hero).
- Kael: every glow on him (sword cracks, eyes) is white-hot, never orange. The curse is crimson (left arm, chest). Website splash: kael_v2_splash_relit_candidate.jpg; in-game/key art: kael_v2_splash_final.jpg.
- Vex: both arms are mechanical; her right forearm IS the minigun (no hand). Alternates: vex_v2_alt_tavern.jpg (needs an arm fix before any use), vex_v2_alt_joyride.jpg.
- Ryzz: the bubblegum bubble is a separate animated prop, never part of the face mesh. Two skin candidates are in ryzz_v2/ (not chosen).
- Grimble (id dredge): the right arm IS the hook (purple mutated bone hook, no chain). The hook ability's visual is the arm extending, not a thrown chain. No nose, three-lens brass loupe, metal teeth with one gold tooth (grimble_v2/index.md canon notes). Old refs that say "Dredge" are his old name.
- Claire: now a frost bunny. Real rabbit ears, a small fist-sized tail; no horns, bat wings or devil tail. She is 18, a youthful adult, not a seductress. Lore: "frost demoness" becomes "frost spirit" everywhere player-facing.
- Portraits: briefs/art-refs/portraits_unified/ (12 portraits, shared vignette) are the select-screen and website portraits.
- Cinder v2 is locked (owner, Nov 7; see below). Next from the art session (do NOT model yet): Sable (moth antennae instead of head wings). Optional: Tarek stones in his hair, Vex knee guards.

## 2026-11-07 (owner, via coordinator): Cinder v2 locked (briefs/art-refs/cinder_v2/, index.md wins)
- Mature, sultry lizard-woman with an elegant human face; lizard horns and goggles, no fins; spined tail with a flame tip; living-obsidian shard armour with molten seams spread evenly; heeled obsidian boots; scales on the skin.
- Props stay small: a compact brass flamethrower and a small copper backpack tank with a glass window (cinder_v2_weapon_sheet.jpg; the hose runs from the grip to the base of the tank).
- 3D: cinder_v2_turnaround.jpg (hair length and the flamethrower from cinder_v2_master_sheet.jpg). Final splash: "Last Dance" (cinder_v2_splash.jpg). Portrait: cinder_v2_portrait.jpg.

## 2026-11-07 (owner, via coordinator): roster order
- Hero order (owner's Boki website order; also the hero-select, wiki and any roster list): Vex, Mossy, Ryzz, Kael, Ravyl, Claire, Grimble, Lumi, Cinder, Tarek, Motley, Sable.

## 2026-11-07 (owner, via coordinator): Boki 50, build them all now
- Goal: 50 Boki as soon as possible, each with a 2D design (concept sheet: front, side, back, expression row; plus a clean turnaround for 3D) AND a 3D model in game. The owner cuts or changes ones he doesn't like later, so don't hold species for review.
- The list is docs/boki/ROSTER_50.md + content/kin_v2_roster/ (branch ext/boki-roster50): the 9 live + 41 new. It is approved as the build list; its originality rules stand (our own creature fusions, never franchise-based).
- The 186/187 Boki proposals: nothing is cut for now (the owner cuts later); breadth first.
- Kael's curse: the sword arm (right) if it can be done cleanly on the v2 model (move/mirror the emissive veins and swap the black glove to the left hand); otherwise keep it on the left arm as the sheet shows.
- Boki design bar (owner, Nov 7): every Boki must be a cool, interesting mix: animals plus objects, tools, food, machines, weather or minerals, changing the silhouette, with a one-line hook and a fight style the mix explains. Be creative. Inspiration from Pokémon, Digimon and other franchises is ALLOWED, a rip is not (not the same animal + concept + silhouette + palette, never the name). This replaces the roster's old "never based on a franchise creature" rule. Designs are judged on briefs/BOKI_50_DESIGNS.md's rubric (coordinator + a design pass; the owner has the final say and cuts later).

## 2026-11-07 (owner, via coordinator): Claire is renamed **Nivi** ("Nivi the Snowglide")
- Display name only, like Breaker -> Mossy: the id `rimewright`, file and folder names (`claire_*`, `art/wardens/claire`, `briefs/art-refs/claire_v2/`) stay. Change every player-facing "Claire" and "Frost Siren": hero select, kit and ability text, tooltips, barks, docs, wiki and website. Lore stays "frost spirit" (frost bunny, 18). This supersedes "Claire" everywhere above.

## 2026-11-07 (owner, via coordinator): Tarek is renamed **Kibo** ("Kibo the Stone Seer")
- Display name only, like Breaker -> Mossy: the id `dolm`, file and folder names (`tarek_*`, `art/wardens/tarek`, `briefs/art-refs/tarek_v2/`) stay. Change every player-facing "Tarek" and "Cliff Runner": hero select, kit and ability text, tooltips, barks, docs, wiki and website. This supersedes "Tarek" everywhere above.

## 2026-11-07 (owner, via coordinator): Ravel is respelled **Ravyl** ("Ravyl the Red Stitch")
- Spelling change so players pronounce it right. Display name only: the id `archer`, file and folder names (`hem_*`, `lisette_*`, `art/wardens/hem`) stay. Change every player-facing "Ravel" to "Ravyl": hero select, kit and ability text, tooltips, barks, docs, wiki and website, plus the hero order list. This supersedes "Ravel" everywhere above.

## 2026-11-07 (owner, via coordinator): ~~Pip is renamed Lumi~~ SUPERSEDED the same night by "Pip/Lumi is renamed Meeko" below
- Display name only, like the other renames: the id `tender`, file and folder names (`pip_*`, `art/wardens/pip`, `briefs/art-refs/pip_v2/`) stay. Change every player-facing "Pip": hero select, kit and ability text, tooltips, barks, docs, wiki, website, and the post-tutorial second-Mask pick. This supersedes "Pip" everywhere above.
- Lore (replaces the old Pip personality line):
  - Lumi was once a small, timid wild Boki, a fox kit who was afraid of the dark.
  - One night she caught a fallen star in an old brass lantern and slept curled around its light for years.
  - The starlight changed her: glowing constellations in her fur, fairy wings, standing upright, and finally speech. She was the first Boki anyone had seen become something more.
  - She still fears the dark, but her lantern's light heals, so she became a field medic who walks into the places that scare her for anyone who needs her.
  - The star is her Mask relic, her oldest friend and her courage.
- Use the lore in her hero-select bio, her wiki page and the website. Barks can lean on it: nervous in the dark, brave for others, talking to her star.
- Visual rule: she still reads as a Hunter (upright, clothed, carrying gear); her outfit shows she has grown beyond being a Boki. Signature: an oversized lantern almost as tall as she is.
- Art: v2 redesign in progress in `briefs/art-refs/pip_v2/`. Do NOT swap any Lumi art or model into the game until her master sheet is final (owner/art-coordinator says so). The name and lore text can ship now.

## 2026-11-07 (owner, via coordinator): "Mask" is renamed **Relic** in all player-facing text
- The object still LOOKS like a mask: same models, icons and art. Only the name changes.
- Lore framing: a Relic is the mask of a fallen Hunter. Wearing it takes on that Hunter's soul, so you fight as them. Only those with a Hunter's Relic can save our souls. (owner 11-08)
- Scope: UI strings, tooltips, menus, loading tips, tutorial text, item names/descriptions, lore and codex, store and Steam copy, player-facing docs. (Lumi's "Mask relic" = her Relic; the "second-Mask pick" = the second-Relic pick.)
- Internal identifiers (class names, enums, save keys, asset paths, network ids) stay unless trivial and safe; where they stay, a short comment notes that "mask" in code means "Relic" in game. This supersedes "Mask" as a player-facing word everywhere above.

## 2026-11-07 (owner): roster order swap
- Cinder and Claire (Nivi) swap places. Order is now: Vex, Mossy, Ryzz, Kael, Ravyl, Nivi, Grimble, Meeko, Cinder, Kibo, Motley, Sable (display names).

## 2026-11-07 (owner, via coordinator): going down turns you into a **Wisp**
- When a Hunter is downed, the hero model pops into a Wisp (a small glowing spirit). No per-hero downed animation is needed; existing `downed` clips become unused (keep the files, stop playing them).
- Needed visuals: a short "pop into Wisp" effect, a Wisp idle/move loop, and a tiny "pop back" when revived (the hero reappears from the Wisp). One shared Wisp for now.
- Gameplay of the downed state (timers, movement speed, revive channel, bleed-out) stays as it is today unless the owner changes it; only the presentation changes.
- Wisps are a cosmetic slot we can sell: build it as a swappable look (a Wisp id on the player's cosmetics, default Wisp first), so new Wisp looks are data, not code. Original designs only (genre inspiration OK, no copied looks).

## 2026-11-07 (owner): Nivi's title is **"Nivi the Snowglider"** (was "the Snowglide")
- Display text only. Supersedes "Nivi the Snowglide" everywhere above (hero select, wiki, website title "Snowglider").

## 2026-11-07 (owner): Pip/Lumi is renamed **Meeko** ("Meeko the Magic Fox"). Replaces "Lumi the Little Lantern"
- Display name only: id `tender`, files and folders (`pip_*`, `art/wardens/pip`, `briefs/art-refs/pip_v2/`) stay. Change every player-facing "Pip" or "Lumi": hero select, kit and ability text, tooltips, barks, docs, wiki, website, and the post-tutorial second-Relic pick.
- Lore (replaces the old Pip personality line and the Lumi lore):
  - Meeko was once a small, timid wild Boki, a fox kit who was afraid of the dark.
  - Magic changed her: glowing constellations in her fur, glowing fairy wings, standing upright, and finally speech. She was the first Boki anyone had seen become something more.
  - She still fears the dark, but she became a field medic who walks into the places that scare her for anyone who needs her.
- Use the lore in her hero-select bio, wiki page and the website; barks can lean on it (nervous in the dark, brave for others).
- Companions (IN PROGRESS, do not build yet): no lantern, she holds nothing. Lead design: two tiny sentient companions floating at her shoulders, a little sun and a little raincloud, which she sends out to heal (possibly to damage). Personality animations: the cloud peeking shyly behind her ear while the sun waves; both napping on her shoulders; both kissing her cheeks; the cloud raining on a grumpy sun while she laughs and a rainbow appears. Plan her idles and emotes around these once the design is locked.
- Visual rule: she still reads as a Hunter (upright, clothed, carrying gear).
- Art: v2 redesign in `briefs/art-refs/pip_v2/`. Do NOT swap any Meeko art or model into the game until her master sheet is final. Name + lore text can ship now.

## 2026-11-07 (owner): Cinder redesign, **"Cinder the Flame Queen"**: no weapons, fire from her hands
- Removed from her design: the brass flamethrower, the hose and the copper fuel tank. Her own body is the weapon: LMB = a fire stream or bolts from her palms.
- Look: obsidian-shard outfit, horns, living-fire hair, a flame-tipped tail; glowing magma cracks brighten while casting.
- Art: `briefs/art-refs/cinder_v2/`. Main splash `cinder_v2_splash.jpg` ("The Last Kiss"); alternate `cinder_v2_splash_alt.jpg` ("The Pyre Queen"). The main splash is used wherever splashes are used: hero select, Relic offer, loading screens, website.
- Her current master sheet, turnaround and weapon sheet still show the tank/hose/flamethrower and are being redone. Until then, model from the turnaround and IGNORE those parts. Do not build them.
- Flue Flight ult: lift no longer comes from tank exhaust jets. DEFAULT (owner to confirm): fire bursting from her heels and tail.
- Brass goggles: REMOVED (owner confirmed 2026-11-07). No goggles on the model, splash, portrait or any art; supersedes "lizard horns and goggles" above.
- FIDELITY_CHECKLIST Cinder row: remove "copper/glass fire TANK on her back with 2 exhaust nozzles", "hose" and "FLAMETHROWER (held LMB)"; add "No weapons. Fire comes from her hands (LMB = a fire stream or bolts from her palms). Glowing magma cracks brighten while casting. A fire-queen look: an obsidian-shard outfit, horns, living-fire hair, a flame-tipped tail."

## 2026-11-07 (owner): hero full names read "<Name> the <Title>"
- Meeko is "Meeko the Magic Fox", never "Meeko Magic Fox" or "Meeko · Magic Fox". Same form for every hero wherever name and title appear together: Vex the Hired Gun, Mossy the Sunken Bulwark, Ryzz the Storm Chaser, Kael the Unbroken (not "the The Unbroken"), Ravyl the Red Stitch, Nivi the Snowglider, Grimble the Scrap King, Meeko the Magic Fox, Cinder the Flame Queen, Kibo the Stone Seer, Motley the Void Jester, Sable the Silver Thief. A title shown on its own (class pages, a subtitle line) may drop the name.

## 2026-11-07 (owner): Nivi is renamed **Neve** ("Neve the Snowglider")
- Display text only (id `claire`, files and internal names stay). Supersedes "Nivi" everywhere above: hero select, kit/ability text, tooltips, barks, docs, wiki, website, Model Room. Roster order unchanged: Vex, Mossy, Ryzz, Kael, Ravyl, Neve, Grimble, Meeko, Cinder, Kibo, Motley, Sable.


## 2026-11-07 (owner): FINAL roster names. Replaces every rename earlier tonight (Lumi, Nivi, Kibo, Ravyl, Snowglider, Magic Fox)
- Display names only; ids, files and folders stay. Ryzz -> **Sparkle** the Storm Chaser; Ravyl -> **Lace** the Red Stitch; Kibo -> **Tenzo** the Stone Seer; Meeko's title -> **the Dawnfox**; Neve stays **the Snowglider** (owner 10:20 UTC: Snowglider, not Snowglide); Mossy's title -> **the Barnacle Knight**. Others unchanged (see the names line at the top).
- Update every player-facing mention: hero select, kit and ability text, tooltips, barks, docs, wiki, website, Relic (Mask) offers and the post-tutorial pick. Full-name form stays "<Name> the <Title>".
- Roster order: superseded by "canonical Hunter order" below.

## 2026-11-07 (owner): every hero title carries "the"
- Every hero has "the" before the title wherever it shows: the full name ("Vex the Hired Gun") AND a title shown on its own (class page, subtitle, hero select: "The Hired Gun" at the start of a line, "the Hired Gun" mid-sentence). Supersedes "a title shown on its own may drop the name/the". Data: store titles without "the" in content/archetypes/*.json (juggernaut "The Unbroken" -> "Unbroken") and add "the" in one display helper, so no "the The" doubles. No commas between name and title.

## 2026-11-07 (owner): canonical Hunter order + Neve is "the Snowglider"
- Neve's title is **the Snowglider**, never "the Snowglide" (display only). Supersedes every "Snowglide" above.
- Canonical Hunter order, wherever the game lists all Hunters (hero select, Relics/collection screen, wiki, docs; projectboki.com already uses it). Supersedes every roster order above:
  1 Vex the Hired Gun (gunslinger, free starter, met first), 2 Kael the Unbroken (juggernaut), 3 Cinder the Flame Queen (ashwick), 4 Meeko the Dawnfox (tender), 5 Tenzo the Stone Seer (dolm), 6 Lace the Red Stitch (archer), 7 Grimble the Scrap King (dredge), 8 Neve the Snowglider (rimewright), 9 Sparkle the Storm Chaser (mage), 10 Mossy the Barnacle Knight (bulwark), 11 Sable the Silver Thief (thief), 12 Motley the Void Jester (ostra). [owner Nov 7 later: Motley and Sparkle swapped, then Motley and Sable; ids order gunslinger, juggernaut, ashwick, tender, dolm, archer, dredge, rimewright, mage, bulwark, thief, ostra]
- Ids: gunslinger, juggernaut, ashwick, tender, dolm, archer, dredge, rimewright, ostra, bulwark, mage, thief (scripts/arch/arch.gd ORDER).
- Post-tutorial pick offers Kael, Cinder, Meeko in that order (content/rules/class_unlock.json second_picks = juggernaut, ashwick, tender).

## 2026-11-07 (owner): PARITY FIRST, invent later
- Top priority: game feel, and porting all 12 kits and their animations over as faithfully as possible (abilities, cancels, buffering, timings, motion as the source does it). Do NOT invent new mechanics, variants or effects until a kit feels as close to parity as possible; the owner makes changes after parity.
- Owner design notes already in DECISIONS (names, Cinder fire from hands, keys) still apply; where they force a change, keep the source's timing and feel.
- Every kit/VFX/animation job: match the source first; put any idea of ours in the final answer as a suggestion, not in the build.

## 2026-11-07 (owner): parity calls on invented kit extras
- Mossy: CUT the Guard meter and Shield Slam (back to source shield / bash / wall-stun kit).
- Neve: darts semi-home while skating too (source behaviour).
- Ours-only riders: keep NONE. Remove Neve's Chill 15% slow, Sable's empowered Shred, Meeko's carrier shield.
- Defaults under PARITY FIRST (owner may override): cooldowns at source values (1.0x), Tenzo's allies can hop his rocks.
- Lace: CUT Focus/Deadeye (owner, after explanation). Keep Hawk Sense.

## 2026-11-07 evening (owner): Neve is **"Neve the Snowglide"** again (NOT "Snowglider")
- Display text only. Supersedes every "Snowglider" above, including the canonical-order entry. hero_title_check must now retire "Snowglider" instead of "Snowglide". Website title too.

## 2026-11-07 evening (owner): parity means QUALITY, not personality
- "dont do parity with personality - i care quality parity on animations, art, etc - but our art is different and our characters are different."
- Kits: mechanics parity stands. Animations/art: match the source game's polish (weight, timing, silhouette, loops), but poses, attitude, idles, emotes and looks come from OUR characters (archetype personality text, lore, owner art sheets). Never copy a source hero's pose or personality.

## 2026-11-08 (owner): every expedition is a fight over the Heart (direction; prototype first)
- The Blight closes toward the Heart's site each match (battle-royale pull to one center), so every match converges on it.
- At the center the Heart charges a Heartspark (a mote of its soft pink-red LIGHT, matching the key-art Heart; not a piece of the Heart: lore stays "one Heart, one crack", the crack unseen inside). While it charges, everyone sees where it is.
- When charged, anyone can take it. The carrier is revealed and slowed, and can only leave through a Heart Gate. Extracting with it pays big (rare eggs, evolution mats, bond/trust).
- After a carrier extracts, the Heart goes on a COOLDOWN and then charges a new Heartspark (visible again), so one match can have several Heartspark fights.
- Normal extraction stays open: leaving early with your own loot is still a valid choice (keeps extraction tension; no forced total loss, esp. on pet-loss tiers).
- Variant to test later: "Heart Night", a top-tier/event mode where ONLY the Heartspark team can extract.

## 2026-11-08 (owner, Nov 7): Wyrmheart look and villain names locked
- **Wyrmheart look = the key art:** an anatomically real heart (aorta, arteries, chambers) of smooth, glossy crimson glass with a soft pink-red inner glow. No gold veins, no visible crack. Applies to the in-game model, VFX, UI icons and lore text. Ref: briefs/art-refs/villain/wyrmheart_ref_from_keyart.jpg. Supersedes the gold-filigree/crack look in the v2 Wyrm art brief.
- **Names:** Malgrave (the king/the Wyrm), Solmere (the kingdom), the Hollowing (the night of the fall), the Hollow (the pit). Retired in new text: the Tyrant, the Crown (as the kingdom), the Sundering, the hoard (now Malgrave's vault). Older entries above keep the old words as history; LORE_MASKS.md is current. The map name "The Hollow Crown" is unchanged.

## 2026-11-08 (owner): no mid-match joining
- Every expedition is one fight over the Heart with the Blight closing in, so everyone drops at the start. **Rolling sessions (squads dropping in waves, late-joiner levelling, join snapshots) are cut.** Remove the `--rolling*`/`--join-*` code path, rolling_check/rolling_sim tools and suite entries; keep anything the normal match also uses (per-squad fresh-lander grace stays only if the normal drop uses it). Bots still backfill squads before the drop.

## 2026-11-08 (owner): the villain is a dragon queen
- **Malgrave, the Undying Queen** (she/her) replaces Malgrave, the Undying King: same name (owner kept it after trying Vesperine and Veyl), now a dragon queen. Same story: queen of Solmere, the Wyrm in human shape, alive inside the cracked Heart. The owner is designing a female-looking mask for her (still the first mask, which every Hunter's Mask copies). Canon text: briefs/LORE_MASKS.md.

## 2026-11-08 (owner): Mossy is renamed Albert
- **Albert, the Barnacle Knight** (was Mossy, before that Breaker; id `bulwark` unchanged). Nickname **Bert** in banter. Player text, voice lines and menus use Albert.

## 2026-11-08 (owner): Cinder's title is "the Ashen Kiss"
- **Cinder the Ashen Kiss** replaces "Cinder the Flame Queen" (display title only; id `ashwick`, design and kit unchanged). Wins over every "Flame Queen" above, in briefs, art indexes and game text. "Queen" is now Malgrave's alone.

## 2026-11-08 (owner): the villain's title is "the Beloved"
- **Malgrave, the Beloved** replaces "Malgrave, the Undying Queen" ("Undying" gave the ending away). It is what Solmere called its ageless, beautiful queen while she fed on them. She is drawn as strikingly attractive (owner's art). Wins over every "Undying Queen/King" above.

## 2026-11-08: hunter sex (from the lore cards; use these pronouns everywhere)
- Male (he/him): Kael, Albert/Mossy (bulwark), Grimble, Motley, Tenzo.
- Female (she/her): Cinder, Lace, Neve, Meeko, Sable, Vex, Sparkle. Villain: Malgrave (she/her).

- 2026-11-08 (owner: "just do it yourself"): **Pip stays as the default Boki pet name** (a Boki name now, not a hero). **Relic rule adopted:** a relic need not be on the hero's 3D model; it is the object found in the world and shows in the relic pickup, menus, splash and lore art.
- 2026-11-08 (owner: "yes"): **Skylands = the name for the broken land after the Hollowing.** Before it was Solmere, one kingdom on solid ground; the Wyrm's waking broke it into floating islands. Malgrave is not defeated (alive in the Hollow; beating her is the end goal). Beast-folk 'always lived in Solmere's lands'. Wins over earlier wording; LORE_MASKS.md has the text.
- 2026-11-08 (owner): the phrase is **"Hunter's Relic"**, not "Hero's Relic", everywhere players read it (prologue, tooltips, lore, store copy).

## 2026-11-08 (owner): new canonical Hunter order
- Canonical Hunter order (everywhere the game lists all Hunters: hero select, Relics/collection, wiki, docs, Model Room, website). Supersedes the 2026-11-07 order above:
  1 Vex, 2 Albert, 3 Neve, 4 Kael, 5 Cinder, 6 Tenzo, 7 Sparkle, 8 Grimble, 9 Meeko, 10 Sable, 11 Lace, 12 Motley.
- Ids (scripts/arch/arch.gd ORDER, scripts/match/hero_kit.gd ARCH_ORDER): gunslinger, bulwark, rimewright, juggernaut, ashwick, dolm, mage, dredge, tender, thief, archer, ostra.
- Display order only. The post-tutorial pick offer (Kael, Cinder, Meeko) is unchanged unless the owner says otherwise.

## 2026-11-08 (owner, repeated): holding Space NEVER opens the glider
- Glide opens only on a double press: jump, then press Space again in the air and hold. Holding Space from the jump (or holding it while doing anything else, e.g. LMB on Albert) must never glide, no matter how long it is held. Supersedes GLIDE_ENGAGE hold-to-glide. Jump-pad and updraft auto-glides are unchanged.

## 2026-11-08 (owner playtest list)
- ONE practice space, named **the Training Area** (based on the title-screen "Arena"); the separate farm training area merges into it. The name **"Arena" is reserved** for a future 4v4 team mode; don't use it for anything else.
- Boki do not die of neglect for now (flag natural_death: false): hungry/sick/weak at worst, recover with care. Non-neglect losses unchanged.
- Hunter ability colours: Vex = green fire, Sparkle = pink, Tenzo = blue; every Hunter's abilities are colour-coded to them.
- Movement: air control as SUPERVIVE (accelerate toward input, strong counter-steer, drag above cap, never overwrite air velocity); glide start adds no speed; Shift cancels into glide instantly for every Hunter. All movement/feel numbers in one tuning file.

## 2026-11-08 owner: Extraction is always trios, 10 teams
Extraction matches are ALWAYS squads of 3 and ALWAYS 10 teams (30 hunters); bots fill missing slots. No duo or solo extraction. Job extraction-trios-10-1108.

## 2026-11-08 owner: real matches HAVE air control
Match movement must have strong WASD air control (at least as good as the farm today); the old "[game data] low air control" choice is overruled. One movement model everywhere (movement-air-core-1108).

## 2026-11-08 coordinator (owner asked): explicit state machines
New or rewritten stateful code (movement, ability phases, Boki AI, match flow, tutorials, UI flows) uses ONE explicit state per machine (enum + single state var + guarded transition table + enter/exit + debug readout), not scattered bools and *_t timers. Pattern and ranked migration plan: briefs/STATE_MACHINES.md (job state-machines-audit-1108). Locomotion goes first, inside movement-air-core-1108. Kit/ability-phase migration waits until the wave-2 kit jobs merge, to avoid conflicts.

## 2026-11-08 owner: hatch scene, mystery egg
- The 3 starter eggs (cindle, puddlet, burrlet) stay front and obvious.
- The mystery egg is a BLACK egg, set in a basket at the back of the hatch scene, somewhat hidden so players discover it and try it.
- Its pool: many early creatures, rares included (not just the 3 starters), with a higher chance of cool mutations at birth than starters.

## 2026-11-08 owner: roster of 109, evolution, sex, Inks (wins over older roster/evolution lines)
- **Roster = the 109 species in briefs/boki-art/ROSTER_100.html (array G is the truth).** Ermink replaces Hatchet as the mystery egg; Jarmit is a rare (Tide) from Rare Eggs that branches with Inks into Lanternmit/Stormit/Terrarimit. The owner makes ~200 sheets a day and reviews them; the first 50-100 with approved art are earmarked for the first release.
- **Types:** the theme list gains **tide, wyrm, wild** (element table in BOKI_DESIGN_RULES.md). A species may have a second type (from G).
- **Evolution:** level cap 100. Each species has its OWN evolution level (no fixed "every 4 levels"). Some evolve by item (Inks, others later) or by trade, like the familiar monster-collecting rules. **A Boki never evolves into a form whose art (model) is not in the game yet;** it waits, and evolves once the art ships.
- **Inks** (Ember, Tide, Bloom, Storm, Frost, Shadow, Lunar, Prism, Wyrm): drop from that type's boss, plus rare wild drops.
- **Sex:** 50/50 for every Boki and every bred baby. Only chosen species get a separate female look (design rule 14); the rest show the sex icon only.
- **Riding:** the rideable cap in the roster check is loosened (owner "ya loosen it"): any grown/final form whose size fits may be rideable.
- Starters stay Vespyx (cindle), Prismander (puddlet), Mycroll (burrlet) plus the mystery egg (Ermink).
- Female-look list (update, owner 11-08): starter lines + Ermink/Blossmink/Vespox, plus Bellowary, Gongibbon, Kestrike, Lunowl, Murmurling (real-animal sex differences). Chuggamus and Canvastross dropped. Rule 14 has the list.

## 2026-11-08 owner: ability names and visuals fit the hunter; more keybinds
- **Vex (gunslinger):** Burr Charge is renamed **Coin Blast**: she flips/throws her coin (her relic, the first coin) and it bounces and blasts (same gameplay, new projectile model, VFX, name, HUD text, tutorials). Longneedle fires **from the open palm of her cyborg hand** (arm raised, palm out, a green-fire emitter glowing in the palm while it charges) instead of the rifle barrel, and is renamed **Palm Lance** (owner 11-08: not 'Finger Gun', it is long range).
- **Every hunter:** ability names must make sense for that character and come from where the fantasy says (hand, weapon, relic, Boki). Audit job lists renames; coordinator applies the clear ones and sends the owner only the ones that are taste calls.
- **Keybinds:** every action the game uses is rebindable in Controls (crouch, whistle, rotate and any missing ones), each ability icon shows its current key, plus new binds: an alternate key per action, mouse buttons 4/5 bindable, quick Boki command keys.

## 2026-11-08 owner: two-step abilities must be obvious and in your face
Abilities you use twice (recasts: Ostra Brimseed pop, Tender Hearthlight throw, Bulwark hammer recall, Dolm Rock Hop, Rimewright Rimelock, Mage, every e_recast/r_recast/ult_recast/rmb_press_extra kit) and two-hit combos on enemies (a mark/Daze/stack then a payoff) are currently annoying and unclear. Rules:
- While a recast is open: the ability icon pulses and shows big "<KEY> AGAIN" text with a shrinking timer ring; a matching world marker sits on the thing you'll trigger (the bomb, the ring, the hammer) with the same key; a short sound cue when it opens and a warning tick before it closes.
- An enemy carrying your mark/combo state shows a clear icon over it (what it is, time left) and a strong hit flash + sound when the payoff lands.
- Recast presses are buffered (~0.15s) and the window never closes silently: the icon shows "expired".
- Same visual language for every hunter; colours follow the hunter's ability colour.

## 2026-11-08 owner: shorter tutorials; farming can be skipped or automated
- **Match tutorial: 22 steps -> about 8.** Keep: land+move, dash+glide (one step), shoot, E ability, send your Boki, a fight, open a chest, extract. Everything else (exdash, crouch, pickup, G key, rank-up, utility, orders, key, uplink, defend, go-to-exit) becomes a one-line contextual hint the first time it matters, not a tutorial step. One banner line per step, no walls of text, nothing blocks you for more than a few seconds.
- **Farm tutorial: 12 steps -> about 5.** Keep: chop a tree, place the house, feed your Boki, plant a crop, start an expedition. Stone, hammer, tasks, buy, sell and the hob become first-time hints or Goals-tracker entries. Tools are simply given.
- Both tutorials always have a visible Skip, and a skipped player loses nothing they need (house placed, starting tools given).
- **Farming is optional.** A player who doesn't want to farm can (a) put Boki on jobs (chop, mine, water, harvest, cook, sell) so the farm runs itself, including while away (offline progress, capped), and (b) turn on **Auto-farm** in the farm menu: one toggle that assigns idle Boki to the needed jobs, auto-harvests, replants, feeds and sells the surplus, at a small efficiency cost versus doing it by hand. Farming by hand stays the best yield, never required.

## 2026-11-08 owner (playtest): hunter-pick countdown 30s and impossible to miss
- The pre-match lobby / pick-your-hunter countdown is **30 s** (was 90, scripts/match/prematch.gd DURATION; overlay text too). A tester had to resize his window to even see the 1:30 timer.
- The timer is big, top centre, inside the safe area at every resolution and aspect (720p to ultrawide, windowed and small windows): "PICK YOUR HUNTER 0:30". Ticks each second for the last 10 s, pulses red in the last 5 s; if no pick by 0, your last/default hunter is locked in and the screen says so.

## 2026-11-08 owner (playtest): expedition performance is TOP priority
- A tester's PC can barely run the expedition. Even the owner's M5 Mac auto-picks "low" quality (40 ms a frame in the load benchmark), and the loading screen takes 16 s with 283 shader compiles.
- Targets: a steady 60 fps on the M5 at medium, and 30+ fps on low-end PCs (integrated GPU) at low. Shaders precompiled or cached, so no hitches in the first minute. A "very low" preset that really is light (no shadows/SSAO/volumetrics, short draw distance, lower render scale, LOD/impostors, fewer particles).
- Every perf change has to come with before/after real-GPU numbers from --perf-bench. Looks may drop on low presets but must not drop on high.

## 2026-11-08 owner (playtest): UI is too much for a new player
- Testers say there's too much on screen and it's hard to understand. Rule: **show only what's needed right now**. The new-player HUD has health, abilities with keys, the objective and the timer. Everything else (minimap detail, ranks, kin orders, relic/economy counters, stat panels) appears only when it first matters, or when you hold Tab or an info key.
- One-line plain-English labels, no jargon before it's explained, one highlighted "what to do next" prompt, and no more than about 5 HUD groups at once. Menus get the same treatment: fewer buttons, with advanced options behind "More".
- Applies to the HUD, the hunter pick screen, the farm, the pause menu and the results screen. It works together with the shorter-tutorials and two-step-ability decisions.

## 2026-11-08 owner: performance pass, industry-standard (extends the expedition-perf decision above)
Owner: the gaming PC does better, but the map needs a hard cleanup and we should use every standard technique game studios use.
Every hunter has a Boki, so a 30-player expedition is about 60 animated characters plus monsters and VFX. Budget for that.
- **Budgets (enforced by --perf-bench and a new --perf-budget-check):**
  - draw calls under 1500, visible tris under 1.5M, active lights casting shadows ≤ 2, VFX particles under 4k on screen;
  - monsters alive near the player capped by preset;
  - target 60 fps M5 medium, 30+ iGPU low, no frame over 50 ms after warm-up.
- **Map:**
  - cut clutter/prop density hard (aim -50% instances);
  - MultiMesh for grass/rocks/props;
  - LODs (Godot auto mesh LOD + visibility ranges/HLOD for far props);
  - occlusion culling (baked OccluderInstance3D);
  - merge static meshes and share materials (fewer materials = fewer draw calls);
  - bake lighting (LightmapGI or baked ambient) instead of realtime GI; SDFGI/SSR/SSIL/volumetric fog off below high.
- **Characters and Boki:**
  - Boki and far hunters get animation LOD (lower update rate off-screen and far away);
  - simple shaders and no shadows at distance;
  - companion AI ticks at 10 Hz when not in combat;
  - bots far away also tick slower.
- **Monsters and pickups:**
  - fewer monsters (lower spawn caps, especially at low/very low);
  - pool and reuse nodes, no runtime instancing in fights;
  - fewer loose artifacts/pickups on the ground (merge into fewer, bigger drops).
- **Shaders:**
  - use Godot's ubershader / pipeline precompile at load (no first-use hitch);
  - fewer shader variants;
  - a cheap unshaded fallback at very low.
- **Shadows/post:**
  - shorter directional shadow distance, 2 cascades at medium, 1 at low, none at very low;
  - MSAA off by default; TAA/FXAA or FSR 2 upscaling with a render-scale option (default 0.77 at low).
- **Other:** physics tick capped, distant collision simplified, texture compression (VRAM-compressed, mipmaps), streaming of far content.
- **Proof:** --perf-bench before/after on a real GPU (M5 + PC + rp1) for each change, numbers posted in READY.

## 2026-11-09 owner: Soul-linked Boki ride with you as wisps (readability + performance)
- **In matches/expeditions, your Boki rides as a small Boki wisp, not a walking pet.** The wisp is the Boki's soul, linked to its Hunter: it orbits at shoulder height, has no walking AI and is cheap to draw. The Boki's **carry passive is always on**, and the wisp shows as its source.
- **Summon:** a dedicated button on a long cooldown (like a flash, but a summon). The wisp bursts into the full Boki for a short window (start at ~10 s, tune it), uses its active and auto skills, then shrinks back into a wisp. **Ultimate** gives a longer summon or the merged form. The wisp dims on cooldown and brightens when ready.
- **Home, farm and care are unchanged:** Boki walk around full-size there. The pet life lives at home.
- **Stealing (match-only, never permanent loss):** when a Hunter is downed, their Boki wisps break loose and float for a few seconds. Anyone can grab them, the owner too if revived in time. A thief holds at most 1-2 stolen wisps and gets each one's carry passive plus one summon for the rest of the match. Stolen wisps get the thief-team colour ring and a tether line, so carriers are visible targets. If you die holding them, they scatter again. **At match end, stolen wisps go home to their owner.** The thief keeps a **soul echo**: the species is unlocked in the Field Book, finding or hatching one gets likelier, and there's a small chance to roll a stolen rare mutation or shiny on their next hatch. Extracting alive with stolen wisps pays a bonus. A permanent-loss mode is a possible later opt-in hardcore/ranked tier, not the default.
- **Telling Hunter Wisps and Boki wisps apart (the outline rule):** Hunter Wisp (downed, see 0019) = a **round "person" outline** in team colour with a white core, slow and heavy, low to the ground, steady glow, low hum, never stealable. Boki wisp = a **little critter outline** (that species' ears/horns/fins/tail tip) in the Boki's own colours (and shiny colours when shiny), quick and bouncy, shoulder height, sparkle trail, chirps in its own voice. A downed Hunter carrying wisps shows one big slow glow with quick critter glows popping off it. **Round = Hunter, critter = Boki.**
- **Cosmetics:** Hunter Wisp looks stay a sellable slot but must keep the round outline. Never sell a critter-shaped Hunter Wisp. Boki wisps add a second cosmetic line (trails, sparkle colours, orbit effects). Original designs only.
- **Lore:** a Hunter and their Boki are soul-linked; in the wilds the Boki travels as a soul-light riding with you and takes form when called. When a Hunter falls, the bond loosens and the soul-light can be caught by another, but a linked soul always finds its way home.
- **Rollout:** prototype behind a setting (wisps vs current walking pets), measure frame time on real GPU both ways, playtest readability, then switch the default.
- **Owner addendum (same day):** each Boki has its **own summon duration** (and cooldown), tuned per species and kin. Short and strong vs long and supportive is part of its identity, shown on its Field Book card and as a ring timer on the HUD. The open logic questions go to a design pass before the prototype locks: per-Boki duration/cooldown, ult interaction, multiple Boki (one summon at a time?), summon while downed, damage to the summoned form (does it end early, with a longer cooldown?), stolen-wisp summon length, AI leash, carry-passive stacking, PvE vs PvP. They're tracked in boki-art/WISP_DESIGN_OPEN.md.
- **Tutorial:** the combat tutorial gets rebuilt around the Boki. It teaches the wisp, the carry passive, summoning, the summon timer, the cooldown, and the round-vs-critter rule. Then a downed-and-steal beat (watch an enemy's wisps scatter, grab one, bring it out). The current combat tutorial is weak (owner), so this is a rework, not an add-on.
- **Owner leaning (same day): guardian summon.** If you go down without having summoned this cooldown, your Boki bursts out on its own to protect you (fights near your Wisp or helps with the revive), but only if its summon is off cooldown. This uses up the summon and starts the cooldown. The design pass must check how this works with being stolen (your wisps scatter only once the guardian window ends or is beaten?), whether it's too strong in duos, and how to keep it readable. Recommend yes or no with numbers.
- **Owner answers to the open questions (same day, for the wisp-design pass):**
  - **Summons out at once:** default is one, but he's open to more. Think through capturing a wild Boki mid-map and summoning it in the same run. More summon slots might come with dungeon tier (deeper or harder tiers allow 2?). Recommend one option.
  - **Summoned form:** damage doesn't end the summon early, but killing the Boki does. A killed summon turns back into a wisp. Options: (a) it returns to its owner, or (b) it becomes stealable. Owner leaning: stealable only if the owner is down or dead; otherwise the wisp flies back to the owner, which briefly reveals the owner's location. Recommend.
  - **Stolen-wisp summon:** open whether a stolen wisp can be summoned at all, and for how long. Recommend.
  - **Carry-passive stacking, and PvP vs PvE rules:** no owner opinion. Design pass proposes them.

- 2026-11-08 22:29 ET (owner): 18 types: Normal, Fire, Water, Grass, Spore, Electric, Ice, Rock, Psychic (was Gravity), Flying, Dragon, Dark, Poison, Bug, Steel, Fairy (was Lunar), Crystal (was Prism), Sound (was Echo). Table at the bottom of boki-art/GAME_RULES_NOV8.md.

## 2026-11-09 owner: ONE Boki 2D style, anchored on Vespyx + Mycroll (projectboki.com Boki wall)
- The style reference for every Boki 2D image is briefs/boki-art/style_refs/boki_style_ref_2d.png (Vespyx + Mycroll website cards): soft hand-painted shading, clean dark outline, big glossy eyes, blush, rounded cute shapes. boki_style_ref_v2/v3 are retired as style refs (they drifted).
- Same framing for all: full body, gentle 3/4 view (not straight-on front, owner: "some are very front facing"), plain background, feet on a floor line. Size within an evolution line is relative (the baby is smaller, the final form fills the frame; dex hero_scale.py does this).
- Spec + rollout: briefs/boki-art/STYLE_CANON.md (coordinator). Sample of 6 first, owner picks, then every species gets a matching hero card.

## 2026-11-09 owner: the farm becomes a simple Boki garden (raise, play, breed); extraction optional
- **Super-simplify the farm.** It's a creature garden, not a resource economy: nobody gathers resources at home. Keep it fun with very few systems. The genre reference is creature-raising gardens; we copy NONE of a specific game's systems, names or looks. Our hooks are elements, personality and memory.
- **Raising shapes the Boki.** What you feed and how you care for it visibly changes it (look, element lean, stats, personality). The Boki live on their own: they play, nap together, form friends and rivals, and react to things you bring home.
- **Boki vs Boki minigames** in the garden (races, contests, small duels) are a core activity, not an extra.
- **Breeding (mating) is a main path.** Pair two Boki, and the offspring inherit traits from both parents.
- **Playable without extraction.** A player can enjoy the game only raising, breeding and competing with Boki. Extraction stays the other main path, and the two feed each other: expedition loot changes Boki, and raised and bred Boki are better partners on runs. Clans later: some members extract, some stay home and raise and breed.
- This replaces "Frozen: farm-builder depth" for the garden. Builder, crop and economy depth is cut back, not grown. Design brief: briefs/design/GARDEN.md (coming). Until it's approved, don't start new farm-economy work.

- 2026-11-09 (owner): Geodemole has TWO approved versions of the same Boki: intact (art geodemole-3-art) and broken/cracked-geode (geodemole-r-3-art). Keep both; 3D/kits treat the broken one as a second form (e.g. damaged/evolved state), not a redo or reject.
