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
  - **Bjorn's LMB:** per the footage, holding LMB charges one big forward swing (body tracks the cursor, a glint grows, a flare at full charge, a flaming crescent on release), and the 360 spin is on Shift. Build that unless the INBOX says the owner wants an LMB spin.
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
