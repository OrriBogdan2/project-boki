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
- Lore framing: a Relic is the mask of a fallen Hero. Wearing one lets you fight as that Hunter. Only those with a Hero's Relic can save our souls.
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
