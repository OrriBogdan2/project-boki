# Server update 5: hero kits to match their sources (owner priority)

The owner says our hero kits are "a bit off" from their SUPERVIVE sources and wants them as close to the originals as possible, clean room: the same mechanics, timing, aiming, telegraphs and animation feel, with every model, texture, shader, effect and sound made by us. He wants this done well.

**Use Opus 5.5 at medium effort for every agent in this update** (Agent tool: model "opus", effort "medium"), not Sonnet.

## Inputs
- `briefs/hero-ref/<name>.md`: one reference sheet per hero, written from gameplay footage. Each has a source summary table, per-ability notes (input, aiming, reticle, animation, VFX, numbers), a ranked gap list against our code with file and function pointers, a rename list, and open questions. The sheets reference key frames by file name. Those frames stay on the local machine (video screenshots never go into the public repo), so work from the text.
- Scale: about 1 body height = 1.8 m in our game.
- Names. The owner renamed these heroes; ids and file names stay the same:

| id | New display name | Was |
|---|---|---|
| thief | **Dancer** | Thief |
| archer | **Pin** | Archer |
| bulwark | **Bjorn** | Bulwark |
| gunslinger | **Venator** | Marlowe |
| ashwick | **Linwick** | Ashwick |
| tender | **Moosh Moosh** | Linnet |
| dolm | **Breah** | Dolm |

  Unchanged: Vireo (mage), Tamsin (rimewright), Dredge, Ostra, Juggernaut.
  - Rename every player-facing place: content JSON, hero_kit.gd, kit cards, HUD text, gen_wiki output and hand-written wiki pages, sfx labels.
  - Also rename the minigun ability currently called "Bulwark" (content/abilities/bulwark.json) so it doesn't clash.

## Order
### 1. ext/aimkit (one agent, start now)
Shared aiming and telegraph helpers that the kits will call. New files only, plus thin wiring.
- **Aim modes:** "at cursor, clamped to max range" vs "always max range in the aim direction", as a per-shot option (today `Hunter._emit_shot` only clamps for `boom` weapons).
- **Ground telegraphs:**
  - a lane with a fixed or growing length, which can narrow while charging
  - a V of two lines that close into one as a draw charges
  - a cone
  - a landing circle, and a circle with a growing inner sweet-spot ring
  - a curved arc wall
  - a dotted lane
  - a two-end marker (for swaps)
- **Reticle states on the cursor:** charge ring, full-charge flare, and a one-frame perfect-window star flash.
- Driven per ability from kit code, styled per hero colour, readable but not loud. Use MultiMesh or immediate geometry, not per-frame node spam.
- A `--aimkit-check` registered in tools/check_registry.gd, with a screenshot of each telegraph.
- When it's pushed, start the six kit agents from it.

### 2. Six kit agents, one per pair, each on its own branch from ext/aimkit
| Branch | Heroes | Note |
|---|---|---|
| ext/kitfix-pin-bjorn | archer, bulwark | |
| ext/kitfix-vireo-venator | mage, gunslinger | Venator's sheet uses Ghost's real section |
| ext/kitfix-linwick-dredge | ashwick, dredge | |
| ext/kitfix-moosh-tamsin | tender, rimewright | |
| ext/kitfix-breah-ostra | dolm, ostra | |
| ext/kitfix-dancer-juggernaut | thief, juggernaut | Dancer's LMB becomes a ranged alternating-hand bolt that lands at the cursor: the biggest single change |

## Rules for every kit agent
- **Work through the gap list top-down.** Fix every `mechanic`, `aim`, `reticle`, `anim` and `vfx` gap. Fix `numbers` to match the source's ratios (damage relative to the basic attack, cooldown ratios); don't copy raw numbers. Our health and damage scale is different.
- **Animations:** rebuild them in hunter_anim.gd KMOVES as procedural moves, timed to the sheet's frame counts: wind-up, release, follow-through, recovery. The body faces the cursor where the source does.
- **Sounds:** each ability gets its own sound authored by us. Synthesize it (like tools/gen_care_sfx.py) or use a CC0 library. Match the character the sheet describes. Never use audio from any game or video.
- **VFX:** our own shaders and particles. Anything a sheet marks `distinctive` keeps its function but gets a look of our own.
- **R is the Boki Merge.**
  - Source ultimates stay folded into other slots as the docs say, unless the sheet shows the fold breaks the kit.
  - Juggernaut's Doomfall payoffs do nothing because class_ults is off. Fold them into something that works, and say what.
  - Thief's leftover Jackpot R definition goes.
- **Where the video is silent** (the sheet's open questions), pick the most likely behaviour and record it under "Assumptions" in docs/heroes/<id>.md, so the owner can correct it.
- **Owner notes:**
  - **Bjorn's LMB:** the owner wants him **spinning the hammer while LMB is held**, then on release a strong slam that also carries him forward (owner playtest note 2). This overrides the footage reading of a static charge. Keep the footage's cursor-facing, growing glint, full-charge flare and flaming crescent on the slam. Shift stays the dash-into-360 spin.
  - **Dredge's grab** stops at walls on purpose in our doc. Keep that unless the owner says otherwise.
  - **Pin's Shift** is Spirit Walk in the newer source. Build Spirit Walk (dodge roll, then 2.8 s through walls) and drop the grapple.
- **Hold state:**
  - New holds and channels must clear on `KinMerge.active(h)`, like the existing fixes.
  - List any new hold fields for MergeKit.drop_class_holds.
- **Standing rules:**
  - Reserved Boki files are off limits. Keys G, C, R and F stay reserved.
  - Big files are wiring-only. Don't raise any health.py budget; split code instead.
  - New checks go in tools/check_registry.gd.
  - Net: bump only if sync changes, and say so.
- **Checks:**
  - Update each hero's combo check so it asserts the new behaviour: cursor landing, telegraph shown while aiming or holding, charge timings, the payoff.
  - Run the full suite once at the end, with 0 failures and no SCRIPT ERROR.
- **Screenshots** for the owner, into ext/hero-shots under `<newname>/v2/`, for each ability:
  - the telegraph or reticle while aiming
  - the key animation frame
  - the impact
  - a before/after pair for the top 3 gaps

## Report
- In STATUS.md, per branch: commit, Net, checks, gaps fixed and gaps left with reasons, assumptions made.
- Tell the local machine in STATUS.md when each pair is ready. The local machine reviews the screenshots before anything goes to main.

## OWNER PLAYTEST NOTES: these override the footage where they differ
Read `MAIN_TO_EXT.md` entries "11:55 ET: OWNER PLAYTEST (sync61), hero fidelity pass" and "12:00 ET: add to ext/fidelity: Vireo (Joule)" in full. This update IS that ext/fidelity pass, split into ext/aimkit plus six ext/kitfix-* branches; report ready per pair.

Per hero:
- **Juggernaut:** RMB hold reads clearly:
  - a big wind-up pose, a rising sound, a fill, a "full" flash
  - you can jump while holding
  - release flings you far forward
- **Bjorn:**
  - the throw lands at the cursor
  - LMB hold spins the hammer, and release is a slam with forward momentum
  - his shield looks unique to him
- **Pin:**
  - a visible draw wind-up and a clear flash at the perfect moment
  - shots go to the cursor
- **Breah:**
  - raised rocks give verticality: she can stand on and climb them
  - punching rocks sends them flying
  - LMB is a hold
- **Ostra:**
  - spamming Shift must never dash in random directions
  - Shift keeps his height
  - RMB has 1 charge, not 3, and must visibly stun, including on the training dummy
- **Venator:** the grenade explodes in a visible cone when it hits a wall or the ground, never on hitting a person.
- **Tamsin:**
  - her shots look like ice shards, come out slowly and home onto targets
  - her ice wall looks unique to her
- **Dredge:** E in the air smashes straight down, the anchor lands with him, a ring shows at the landing, and height adds damage.
- **Vireo:**
  - a stack marker over the target's head, with sparks that grow per stack
  - the dash does double damage and resets ONLY when it hits a target at full stacks
  - E: place the area, then flick the drag direction to pull foes toward you or throw them away; the area is a circle with its own look
  - her dash locks her own control and holds her height, but keeps her momentum
  - she fires electricity from a finger gun: no gun model, arm extended, a snap or recoil, a crackle at the fingertip, a jagged bolt, a spark impact

Across all heroes:
- every projectile looks distinct: its own shape, colour, trail and impact
- every wall or barrier looks unique to its owner
- every ability gets its own shape language, a wind-up tell, an impact and a KMOVES pose
- upgrade the signature weapon model, firing animation, muzzle and impact effects, using the GAMEDEV_CHECKLIST game-feel items (hit stop, trauma shake, squash and stretch)
- pool every effect
- **L loadout picker:** rewrite every hero's card in one format: a role line, then one plain line each for LMB, RMB, E, Shift and passive.
- **ArchKit._drop_holds()** (on main since sync61) is the single hook every kit implements for merge-start cleanup. Use it, not ad-hoc `KinMerge.active` checks.
- Re-merge main (sync62 or newer) before reporting a pair ready. Sync62 slowed base movement and dashes, so re-check any dash speeds a kit hard-codes.

## OWNER, 13:46 ET: custom, noticeable animations for every ability and every dash
- **Every ability needs its own clearly visible animation**, timed to the reference sheet's beats: LMB, every LMB variant (tap, hold, perfect, overdraw), RMB, Shift, E, the passive procs, and the payoff moments. "A pose change" is not enough. Use exaggerated, readable key poses, anticipation before release, overshoot and settle, squash and stretch, weapon trails, and secondary motion (cloak, hair, weapon swing). The footage is the reference for what each move should communicate.
- **Dashes count too:**
  - each hero's Shift ability gets its own animation
  - the shared base dash gets a per-hero variant: posture, lean, a trail in the hero's colour, a landing settle. A heavy hero lumbers and shoves; a light one flicks or tumbles.
- **Screenshots:** for each hero, add a strip of 4–6 frames for every animation (anticipation, release, follow-through, recovery) under `ext/hero-shots:<newname>/v2/anim/`. The owner reviews these.
- Animations are procedural (hunter_anim.gd KMOVES plus kit-driven offsets). If a move needs bone or rig motion the procedural system can't express, add the smallest general capability to the animation system (a new curve type, a limb IK target, a weapon pivot) and say what you added.

## OWNER, 14:07 ET: the small mechanics must transfer too
The owner's example: Brall's tether pull can be **steered to the side** while you're being pulled in. Details like this make the original feel right, and the footage only catches some of them. For every ability:
- **Research the fine print** with WebSearch/WebFetch: the game's wiki ability pages, patch notes, guides, Reddit or Discord tech threads, and pro-play breakdowns. Look for:
  - steering or drift during movement abilities, and air control
  - cancel windows and animation cancels
  - buffering
  - what happens on hitting a wall, a rock or the abyss edge
  - interactions with other abilities (dash during X, X in the air)
  - momentum carried in and out
  - recast and redirect windows
  - hidden bonuses (backstab, edge, sweet spot)
  - what interrupts it
  - how it treats allies, wisps or Boki
- Add a **"Small mechanics"** list to the hero's reference sheet: one line per item, with a source link, and note where the footage confirms it. Build every one that fits our game, and assert each in the combo check, for example "tether pull: sideways input shifts the arrival point by at least 1.5 m".
- If a mechanic can't be confirmed, build the most likely version and list it under Assumptions in docs/heroes/<id>.md.
