# Breah (`dolm`): reference sheet from the Tetra guide video

## Source and method

- **Footage:** `/home/claude/svvid/hero/breah/frames`, taken from a commentated guide (300 s, 4 fps). Frame N is
  second (N-1)/4, so each frame is 0.25 s and every timing below is ±0.12 s.
- **No commentary transcript:** neither whisper nor vosk is installed, so `audio.wav` was skipped. The guide's
  on-screen tip titles were used instead: "Rocksweeping", "Crush the Rocks", "Wall Stacking", "Punch to Extend
  Dash/RMB" and "Dash -> RMB Dunk Combo".
- **Ability cards:** the player's own key labels are on the HUD (L SHIFT, SPACE, E, R). The cards themselves use the
  default keys.
- **Key frames:** `/home/claude/hero-ref/breah/`.
- **Our code:** origin/main 4f82978, worktree `/home/claude/ref-vireo`. In our code the hero's id is still `dolm` and
  its display name is still "Dolm". See section 6.
- **Scale:** Tetra is about 40 px tall in the training-room shots. Ranges below are in body heights (bh); about 1 bh
  is 1 unit.

## 1. Source summary

| Slot | Ability | Input | Aim type | Cooldown / cost | Effect |
|---|---|---|---|---|---|
| Passive | Stonesight | hold Sneak | cone in front, follows the cursor direction | none | Reveals enemies in a cone through walls. The cone grows the longer Sneak is held. |
| LMB | Quake Punch | **tap** | skillshot toward the cursor | 0.6 s | Throws a boulder (169 on the dummy) with a small explosion on hit. |
| LMB | Quake Punch | **hold and release** | short melee lane toward the cursor | 0.6 s | Punches forward. Enemies are launched about 3 bh, and an enemy punched into a wall is **Stunned**. Rocks (from Q or R) in the lane are launched as flaming boulders that explode and shred Armor (244 each). |
| RMB | Volcano Crusher | hold to charge, release to slam | ground AoE centred a short hop ahead, toward the cursor | 9 s, 20 mana | Slam (188 outer, 225 to 413 with a Stun at the centre). Enemies over the Abyss are Dunked. **Jump while charging to leap forward.** Holding longer gives more damage, a longer stun and a bigger sweet spot. Resets on a knock or kill. Launches Q/R rocks on impact. Upgrade: a 250 HP shield per slam (max 4 stacks). |
| Shift | Landslide | tap | dash in the aim direction | 9 s, 15 mana | Makes a rock in front of her and dashes forward with it. At the end of the dash the rock is launched forward (160 and **SLOWED**). Upgrade IV: the dash lasts 33% longer. |
| Q | Rockwave | tap | placed a fixed distance in front, perpendicular to the aim | 10 s, 15 mana | Raises a wall of 3 rocks. Ground only. Allies can hop over friendly walls by jumping against them. Upgrade IV: an extra rock wall. |
| R | Tetraform | **tap**, or **hold and drag** to set the angle | wall centred at the press point; dragging rotates it | 35 s, 25 mana | A giant wall of rocks (about 12 bh long). The rocks spawn after a short delay from the centre outward and **slow** nearby enemies. Over the Abyss it makes temporary terrain. Punched rocks launch. |

## 2. Per-ability detail

### Passive: Stonesight (card `0685`; in use at `0013`–`0017` and `0693`–`0725`)

**Input:** hold Sneak.

**Aiming:** the cone points at the cursor and turns with it.

**Reticle and telegraph** (`0697`):
- The cone is a pale cream, translucent wedge. Its opening is about 35–40°, and it is long: about 10–14 bh, running
  off-screen.
- A thin white line runs from Tetra to the cursor dot inside the cone.
- An enemy found behind a wall is marked with an **orange-red ring**, about 2 bh across, drawn through the wall
  (`0013`). The ring fades and refreshes.
- Per the card, the cone widens and lengthens the longer Sneak is held. Over `0693`–`0725` the wedge grows a little,
  but the change is hard to measure.

**Animation:** she sneaks in a crouched walk.

### LMB tap: boulder (`0104`–`0117`; card `0099`)

**Input:** tap. The cadence is 1 throw per 2–3 frames, about 0.6–0.7 s, which matches the 0.6 s on the card.

**Aiming:**
- The boulder flies straight toward the cursor and hits the first enemy.
- The dummy stood in line with the cursor in every throw, so the footage does not settle whether it stops at the
  cursor or flies to max range (see open questions).
- A **red laser aim line** runs from her hand to the cursor or the first obstacle. It is the global aim line, always
  on.
- The cursor is a small white ring with a centre dot.

**Animation:** an underarm or side hurl from the right gauntlet, with no long wind-up (`0108`).

**VFX:**
- The boulder is a glowing molten orange rock, about 0.4 bh across, with a short ember trail.
- It is fairly slow: about 0.5 s to cross about 5 bh (`0108`→`0110`), so roughly 10–12 bh/s.
- On impact it bursts into an orange-yellow fireball about 1.5 bh across with a **red circle on the ground**
  (`0110`, `0117`). That reads as a small AoE.

**Numbers:** 169 damage.

### LMB hold: punch (`0117`–`0124`, `0128`–`0150`)

**Input:**
- Hold to wind up. A white outlined **rectangular lane with chevron arrows** appears in front of her, about 2.5 bh long
  and 1 bh wide (`0118`, `0119`).
- Release to punch. The hold-to-release time was about 0.75 s (`0118`→`0121`).
- Afterwards she can walk while her fist recovers.

**Aiming:** the lane points at the cursor and does not move with cursor distance.

**Animation:**
- Wind-up: the right gauntlet is drawn back (`0118`).
- Release: a straight lunge punch that steps her forward about 0.5 bh (`0121`). Her gauntlets are huge, so the fists
  dominate the silhouette. Mark this as `distinctive`: our Rubble Fists already cover the role.

**Effect:**
- The dummy is launched about 3 bh into a pillar. It flashes white and purple on the wall hit (`0122`), then shows
  stun sparkle stars (`0123`).
- 199 damage, then about 113 more on the wall.

**Punching rocks** (`0128`–`0150`, "Rocksweeping" `0761`–`0821`):
- One punch launches **every rock in the lane** as a flaming boulder along the aim (`0128`→`0130`).
- Each rock explodes on the target with a large fireball and shrapnel, for 244 (`0140`, `0149`). That is far more
  than the plain boulder.
- "Rocksweeping": a punch aimed along a Tetraform wall launches a whole stream of rocks one after another
  (`0161`–`0165`, `0797`, `0813`). The 544 numbers are multiple rocks landing on the same target.

### RMB: Volcano Crusher (`0249`–`0337`, `0825`–`0861`, `0938`–`0958`; card `0240`)

**Input:** hold to charge, release to slam.

**Timing of the 3 dummy casts** (as she charges, the outer circle's rim fills in a brighter orange, from the edges
inward):

| Cast | Circle appears | Slam | Charge time |
|---|---|---|---|
| 1 | `0253` | `0259` | about 1.5 s |
| 2 | `0265` | `0269` | about 1.0 s |
| 3 | `0315` | `0321` | about 1.5 s |

**Aiming and placement:**
- The AoE is a **large red circle, radius about 2.5 bh**, centred a short way ahead of her toward the cursor. Its
  near edge reaches her (`0253`, `0256`, `0274`).
- When she jumps while charging, she leaps forward and the circle comes with her. "Punch to Extend": a held punch
  during the charge carries her and the circle further (`0938`–`0958`).
- She hops into the circle's centre for the slam (`0258`→`0259`). So the slam lands where she lands, about 1–1.5 bh
  ahead. It is **not** cursor-placed at range.

**Reticle and telegraph:**
- The outer circle is red-orange, semi-transparent, with a bright rim.
- An **inner sweet-spot ring** (yellow-orange) sits at the centre and grows with the charge, from about 0.5 bh to
  about 1 bh radius (`0253`→`0258`).
- Her gauntlets glow brighter as the charge builds (`0256`–`0258`).

**Animation:**
- Charge: a crouch with the fists gathered and glowing.
- Release: a short hop forward, then a two-fist downward smash.
- Impact (`0259`): a big orange and yellow starburst explosion about 4–5 bh across, with rock shards.
- Afterwards (`0260`–`0264`): a dark red scorched crater with gold rune flecks stays about 1 s.

**On hit:**
- The target shows 188 (the outer ring), then **225 with a stun-swirl icon** (the sweet spot).
- The target is stunned with sparkles for about 1 s.
- The 413 at `0335` was a full charge with rocks in the area.

**After the slam:**
- A **yellow shield ring** surrounds her afterwards (`0260`–`0264`, `0314`). This is the shield upgrade.
- Rocks in the circle are launched outward ("Crush the Rocks", `0327`–`0337`, `0841`–`0861`).

**Dunk** ("Dash -> RMB Dunk Combo", `0965`–`1010`):
- Landslide shoves the enemy out over the Abyss.
- She leap-slams onto them. A **green-and-white vertical beam** and the text **KNOCK** show the dunk (`0989`,
  `0990`).

### Shift: Landslide (`0513`–`0548`; card `0505`)

**Input:** tap.

**Sequence:**
1. On press, a rock spike bursts up just in front of her, with a puff behind (`0516`, `0517`).
2. She dashes forward with it, about 2–3 bh in about 0.25–0.5 s.
3. At the end of the dash the rock flies on as a **rolling molten boulder** about 1 bh across (`0518`, `0519`). It
   travels about 5–6 bh more and explodes (`0520`).
4. On the dummy it dealt 160 and applied **SLOWED** (`0539`, `0540`).

**Aiming:** the dash goes in the cursor direction. The red aim line stays on throughout.

**Dash look:** a white ring at her feet (`0537`).

### Q: Rockwave (`0394`–`0470`; card `0391`)

**Input:** tap.

**Placement:** three tall jagged rock spikes rise in a slightly curved row, perpendicular to the aim. They stand
about 2 bh in front of her and span about 3 bh (`0398`, `0408`).

**Rise:**
- A red-orange ground flash comes first (`0397`, `0407`).
- The rocks are up within 1 frame (0.25 s).
- They are dark basalt with glowing orange cracks at the base.

**Duration:** they stood for at least about 5 s in the footage.

**Interactions:**
- Rocks block bodies and shots.
- A punch launches them (`0425`–`0432`).
- They can be raised next to a cliff to "stack" a wall ("Wall Stacking", `0869`–`0917`).

### R: Tetraform (`0576`–`0677`; card `0571`)

**Input:** tap, or hold and drag. Over `0576`–`0582` the placement preview rotates as the cursor moves: "HOLD and drag
to position the wall at your desired angle".

**Reticle:**
- A thin white line about 12 bh long, with **inward-pointing chevron arrows** along it.
- A small circle marks the centre (`0579`).
- The line is placed ahead of her toward the cursor, then pivots on its centre as she drags.

**Spawn:**
- From release (about `0582`), the rocks erupt **from the centre outward** over about 1 s (`0583`→`0587`), with fire
  bursts and red crack lines on the ground.
- The finished wall is a long ridge of about 12 rock spikes (`0587`–`0590`).
- Enemies caught near it are SLOWED.

**Over the Abyss** (`0649`–`0677`): it lays a sand-coloured walkway with spikes along it, so it makes temporary
terrain.

**For us:** R is the Boki Merge. Our doc folds this into E rank 3 (a second row and a bridge).

## 3. The combo the kit is built around

1. **Make rocks** with Q, R or the dash.
2. **Throw them:** a held punch launches every rock in the lane (244 each), or a slam launches every rock in the circle
   outward.
3. **Slam:** set up with Landslide or a punch into a wall (stun), then leap-slam the sweet spot for a centre stun.
   Over the abyss that is a Dunk (KNOCK).
4. **Reset:** a knock or kill resets Volcano Crusher, so she chains straight into the next target.

## 4. Key frames (`/home/claude/hero-ref/breah/`)

| File | Caption |
|---|---|
| 0099.jpg | Quake Punch card: tap = boulder, hold = punch, wall = Stun, punched rocks explode and shred Armor; 0.6 s |
| 0110.jpg | Tap boulder impact: fireball with a red ground ring, 169; red laser aim line to the cursor |
| 0118.jpg | Hold punch: white rectangular lane with chevrons (about 2.5 bh), gauntlet cocked |
| 0122.jpg | Punch into a pillar: wall-hit flash (then stun stars on the next frame) |
| 0128.jpg | Punching a Rockwave rock: the rock leaves as a flaming boulder along the aim |
| 0240.jpg | Volcano Crusher card: hold to charge, centre Stun, Abyss Dunk, jump-while-charging leap, reset on knock/kill, launches rocks; 9 s / 20 |
| 0256.jpg | RMB charging: big red AoE circle ahead of her, inner sweet-spot ring growing, fists glowing |
| 0259.jpg | RMB slam: starburst, 188 outer and 225 with a stun icon on the dummy |
| 0391.jpg | Rockwave card: 3 rocks, ground only, allies hop friendly walls; 10 s / 15 |
| 0398.jpg | Rockwave up: 3 spikes in a curved row about 2 bh ahead, perpendicular to the aim |
| 0408.jpg | Rockwave cast side-on: the row perpendicular to a leftward aim |
| 0505.jpg | Landslide card: rock in front, dash, launch the rock at the end; 9 s / 15 |
| 0516.jpg | Landslide start: the rock bursts up in front, puff behind |
| 0519.jpg | Landslide end: the rock rolling on as a molten boulder |
| 0571.jpg | Tetraform card: tap or hold-drag to angle, spawns centre-out, slows, makes terrain over the Abyss; 35 s / 25 |
| 0579.jpg | Tetraform placement reticle: long line with inward chevrons and a centre circle |
| 0587.jpg | Tetraform wall fully raised (about 12 spikes) |
| 0685.jpg | Stonesight card: sneak to reveal in a cone, grows with hold time |
| 0697.jpg | Stonesight cone while sneaking: pale wedge, aim line, orange ring on a hidden enemy |
| 0986.jpg | Dash then RMB dunk: slam over the abyss, beam, KNOCK |

## 5. Gaps against ours, ranked by how much they change the feel

**Files:**
- Kit: `scripts/arch/kits/dolm_kit.gd`
- Data: `content/archetypes/dolm.json`
- Weapon: `content/weapons/rubble_fists.json`
- Animation: `scripts/match/hunter_anim.gd`, KMOVES `dolm_*`
- Placement: `scripts/arch/hero_zones.gd`

1. **[mechanic] [numbers] A punched rock is the big hit, and it should feel that way.**
   - Source: a launched rock deals about 1.45× the tap boulder (244 vs 169), and a single punch along a wall sends a
     whole stream of rocks.
   - Ours: a rock deals 14, the boulder 9 and the punch 12–24 (`rock.dmg`). The ratio is about right, but
     `my_all_rocks_near(rock_reach 3.4, ±60°)` only reaches rocks within 3.4 m.
   - Change: make the rock search the **lane** (about 2.5 bh long, plus the wall's length along the aim), so
     "Rocksweeping" along a Tetraform-style row works.
   - Also stagger the launches by about 0.08 s each, so they read as a stream rather than a single volley
     (`_punch`, `launch`).
2. **[aim] [mechanic] The RMB slam lands where she hops: about 1–1.5 bh ahead, with a large circle.**
   - Ours: `_slam` uses `HeroZones.walk(.., reach 2.4)`, so the centre is 2.4 m ahead while she stays put.
   - Source: she **hops forward** into the centre. The circle (radius about 2.5 bh) touches her at the start.
   - Change:
     - Add a small hop (`travel(~1.2, 0.15)`) before `_slam`.
     - Lower `reach` to about 1.3.
     - Raise `radius` to about [2.2, 2.7].
   - Also add the source's "jump while charging = leap forward". Ours only has the air dive. In `rmb_hold_tick`, a
     jump press during the hold should do a forward `travel()` and carry the circle with it.
3. **[reticle] RMB charge telegraph.**
   - Ours: no ground circle while charging (`rmb_hold_tick` only plays an animation).
   - Source: a big red circle with a bright rim that fills as the charge builds, plus an inner sweet-spot ring that
     grows from about 0.5 to 1 bh. Both are visible to everyone and follow her.
   - Change:
     - In `rmb_hold_tick`, create a `tele_circle` for the outer ring (radius from `k`) and a second one for `core`.
     - Update both each tick to `h.pos + aim_dir * reach`.
     - End them on release, the same way `mage_kit.gd` handles `coil_tele`.
4. **[reticle] LMB hold: the punch lane.**
   - Source: a white outlined rectangle with chevrons, about 2.5 bh by 1 bh, shown from the moment the hold starts.
   - Ours: there is no ground indicator, only `mel_hold`.
   - Change: in `lmb_override` when `lmb_t > tap`, create a `tele_lane(h.pos, aim_dir, reach, 1.0, col, 0)`, update it
     each tick, and end it in `_punch`.
   - Also make the hit test a **lane** rather than the current cone (`arc` 120°, `reach` 2.7). The source is a narrow
     forward box.
5. **[numbers] LMB hold timing.**
   - Source: about 0.75 s from the hold to the punch, with a step forward of about 0.5 bh on release.
   - Ours: `tap` 0.28 and `full` 0.9 already fit.
   - Add the step: a `travel(0.5, 0.08)` in `_punch`.
6. **[mechanic] Landslide pushes the rock ahead throughout, and the rock slows.**
   - Source: the rock spawns at the **start** in front of her, rides ahead during the dash, then rolls on about
     5–6 bh, exploding for 160 and **SLOWED**.
   - Ours: the boulder appears at the end (`_landslide_launch`) and flies 12 m. On a hit it applies Shred, not Slow.
   - Change:
     - Show a boulder mesh in front of her during `travel`. It can be purely visual if placement legality is the
       worry.
     - Cut `rock.range` for the dash rock to about 6.
     - Add `KitStatus.apply(e, "slow", ~1.5)` in `_rock_end` when `src == "dash"`.
   - Also: the dash rock shoving an enemy toward the abyss is the setup for the dunk combo. Consider adding push on the
     rock's path (`kb` 5 is there; raise it to about 8).
7. **[vfx] Rocks and the boulder look.**
   - Source: the boulder is molten orange with an ember trail and **explodes with a red ground ring** (about 1.5 bh).
     Launched rocks explode bigger, with shrapnel.
   - Ours: a tan `spawn_shot` with tracer 1.0. `_rock_end` already has ring and burst.
   - Change: add an end ring for the tap boulder too, a small AoE of about 0.8 m. This is also a **[mechanic]** gap:
     ours has no splash on the boulder.
8. **[mechanic] Rockwave placement.**
   - Source: about 2 bh ahead, a slightly curved row, 3 rocks, up in 0.25 s after a red ground flash.
   - Ours: 3 m ahead with a gap of 1.45 (span about 2.9 m), in a straight line.
   - Change: bring `dist` down to about 2.2, curve the row by moving the outer two rocks back about 0.3, and add a
     0.2 s red ground flash (a `tele_circle`) before `_new_rock`.
9. **[mechanic] Passive cone.**
   - Source: a narrow wedge (about 35–40°), long (10+ bh), visible to the player as a pale cone, growing with sneak
     time.
   - Ours: 70°, 16 m, with no cone drawn.
   - Change: in `_tick` while crouched, draw a cone telegraph and widen the angle from about 25° to 40° over about
     2 s of sneaking. Today it is a fixed 35° half-angle in `stonesight()`.
10. **[mechanic] RMB charge length and the reset.**
    - Source: a full charge takes about 1.0–1.5 s, the cooldown is 9 s, and the reset fires on a knock or kill.
    - Ours: `hold` 0.2 + `time` 0.8 (1.0 s total), `cooldown` 10. The reset already matches.
    - Change: `time` to about 1.2 and `cooldown` to 9.
11. **[anim] Slam animation.**
    - Source: crouch with glowing fists, a hop forward, a two-fist smash, and a scorched crater that lingers about 1 s.
    - Ours: `dolm_rmb_wind` lifts the fists overhead, which is a different pose from the source's crouch. `dolm_rmb`
      drives them into the ground, which is close.
    - Change: make `dolm_rmb_wind` a low crouch with the fists drawn in at the hips, and add a `lift` of about 0.4 in
      the first key of `dolm_rmb` for the hop.
    - Add a lingering scorch decal of about 1 s (a `tele_circle` held, dark red).
12. **[vfx] Shield ring after the slam (rank 3).**
    - Source: a yellow ring around her.
    - Ours: sets `h.shield` with no ring visual of its own beyond the global shield look. Check the global shield
      visual and add a ring if it is missing.
13. **[mechanic] Tetraform (folded).**
    - Source: rocks spawn centre-out with a delay and slow enemies, and the wall angle can be dragged.
    - Ours: the rank-3 E adds a second row and a bridge.
    - Optional: make E rank 3's second row spawn centre-out with a 0.1 s stagger, and apply a short slow to foes
      within 1.5 m of a rock as it rises.
    - The drag-to-angle is lost because R is the Merge. A hold-E drag is possible (the same pattern as the Vireo E
      suggestion) if the owner wants it.
14. **[sfx]** The commentary covers the game audio and was not transcribed. Nothing to note.

## 6. Rename: every player-facing place that still says "Dolm" (it should say Breah)

| File | What it is |
|---|---|
| `content/archetypes/dolm.json` line 3 | `"name": "Dolm"` (the kit card, the HUD, the hero picker and gen_wiki all read this) |
| `scripts/match/hero_kit.gd` line 24 | `"dolm": {"name": "Dolm", "cls": "medium"}` (the hero roster table) |
| `docs/wiki/Class-Dolm.md` | Wiki page. gen_wiki builds the file name from the name, so after the JSON change regenerate it with `tools/gen_wiki.py` and delete the old file. |
| `docs/wiki/Classes.md` lines 8, 64, 74 | Generated by gen_wiki; regenerate |
| `docs/wiki/Weapons.md` line 23 | Rubble Fists row; generated; regenerate |
| `docs/wiki/Inspirations.md` line 19 | **Hand-written** row; edit by hand |
| `docs/ROADMAP.md` line 11 | Release note (history; probably keep, or add the rename) |
| `docs/ARCHETYPES.md` line 1206 | Inspired-by table (internal) |

**Code comments only (not player-facing):** `dolm_kit.gd:3`, `pair_demo.gd:3`, `hero_zones.gd:3`, `hero_arms.gd:3`,
`gear_pair.gd:3–4`, `arena_demo.gd:225`, `hunter_anim.gd:1254`, `models.gd:1519`, `tools/gen_pair_sfx.py:1` (a
docstring) and `tools/hero_pair_check.gd:2,320`.

**Not found:** no "Dolm" in `translations/rebrand.en.po` (the rename could be done there as a msgid/msgstr pair if the
JSON should keep the old name, but changing the JSON is cleaner). No "Dolm" in the sfx labels (`pay_rockfall`) either.

## 7. Open questions

1. **Tap boulder range:** does it stop at the cursor or fly to max range? Every throw had the dummy in line with the
   cursor. Does its explosion splash?
2. **Rockwave and Tetraform rock lifetime:** they held for 5 s or more on screen, but the expiry was not shown.
3. **Volcano Crusher while moving:** can she walk while charging? She stood still except for jumps and punches.
   Exact damage scaling: 188 outer vs 225 to 413 centre.
4. **The KNOCK beam on the dunk** (`0989`): is that the dunk itself, or the generic knock effect?
5. **Landslide:** does the dash itself damage or push enemies it passes through, before the rock launches?
6. **Commentary:** spoken tips may add timing details (for example the jump-charge window). Install whisper and
   transcribe `audio.wav` if needed.

## Ultimate (on X)

**Source:** Tetra, Tetraform, from the commentated guide. Frames are in `/home/claude/svvid/ult/breah/` at 10 fps (frame N = 141 s + (N-1)/10 of the guide video). Earlier 4 fps refs are `frames/0571`–`0677`.

**Card** (read at full size, guide at 142.5 s), 35 s, 25 mana:

> TAP to create a giant wall of rocks. Casting this over Abyss will also create temporary terrain. HOLD and drag to position the wall at your desired angle. Rocks spawn after a short delay, from the center outward, and Slow nearby enemies for a brief duration. Punch rocks with Quake Punch (LMB) to launch them, dealing damage and shredding Armor.

1. **Input:**
   - **Tap:** the wall is placed perpendicular to her aim, at the cursor.
   - **Hold and drag:** the press point fixes the wall's centre, and dragging the cursor **rotates** the wall around that centre. Release to cast.
   - In f35–f41 the cursor swings left (red line) while the preview line pivots.
2. **Aim:**
   - The centre is **at the cursor** (clamped).
   - The wall is about 10–12 bh long and one rock thick.
   - She can move while aiming. The cast itself is instant on release.
3. **Reticle / telegraph:**
   - A thin **white line with inward-pointing chevrons** along it.
   - A small circle at the centre point.
   - It shows only to the caster while held.
   - After release, enemies see **orange cracks and fire puffs** along the line for about 0.2 s before the rocks rise.
4. **Animation beats:**
   - f35–f44: the hold and drag preview.
   - f45 (release): fire puffs along the line with orange crack lines.
   - f47–f51 (0.4 s): rock spikes **erupt from the centre outward**, each with a small flame burst.
   - f55–f59: the full ridge of about 12 tall dark basalt spikes with glowing orange bases.
   - It stood for at least about 5–6 s in the footage.
   - Over the Abyss (guide about 161–169 s): a sand-coloured walkway with spikes along both sides appears as walkable terrain.
5. **VFX:** a line of fire puffs, then rocks rising centre-out, then a rock ridge. Rocks are generic. The look of our Breah's earth (Dolm) is ours to keep.
6. **Sound** (commentary audio, not transcribed: no whisper or vosk installed): it suggests a ground rumble and staggered rock cracks.
7. **Numbers:**
   - 35 s and 25 mana.
   - The slow is "brief".
   - Punched rocks deal Quake Punch rock damage (244 each, from the earlier sheet).
   - Rocks block bodies and projectiles.
8. **Ends / combo:**
   - It ends when the rocks expire (duration not shown; at least 5 s) or are punched away.
   - Combo: wall off a fleeing enemy or cut a fight in half, then **held Quake Punch launches every rock in the lane** (big burst plus Armor shred), or a Volcano Crusher slam launches rocks outward.
   - Over the Abyss it is a bridge or escape route.
   - In the guide (f115) it is also dropped inside an allied zone ult to cage enemies.

**Key frames:** `breah/ult_0025.jpg` (before, aim line), `ult_0035.jpg` (hold: chevron line preview), `ult_0041.jpg` (dragged and rotated preview), `ult_0045.jpg` (release: fire cracks), `ult_0047.jpg` (centre rocks erupt), `ult_0051.jpg` (spreading outward), `ult_0055.jpg` (full ridge), `ult_0059.jpg` (finished wall), `ult_0115.jpg` (wall used inside a teammate's zone).

**Build notes:**
- **What to build:** X = tap for a wall at the cursor perpendicular to aim, or hold and drag to rotate it. There is a 0.2 s crack telegraph, then rocks rise centre-out over 0.4 s (11 bh, a brief slow, blocking terrain, a bridge over gaps). Our E rank-3 "second row and bridge" fold can go back into being a plain E.
- **Bond:** the wall deals no damage itself. Pay **0.3** for each hunter slowed by the rise, and **+0.15 per rock launched into a hunter** within 4 s (Quake Punch), capped at 0.8. The ult is built to be cashed in with punches, and that's what fills the bar.

## Body, scale and movement feel

**Method.** Measured on the 1080p guide video. Frame N = t x 4 + 1.
- The guide's camera zoom changes between sections: the editor zooms in on some clips, and the in-game camera differs from the main video. So pixel sizes are not compared across videos.
- Instead I use a zoom-free ratio. The nameplate sits a fixed height above every hunter's ground point, so (ground to head top) / (ground to plate bottom) is a height measure. A medium (Ghost, Joule in the main video) scores about **0.90-0.93**.

### 1. Height and bulk
- **Height ratio** (128.6 s / 0515, standing on the bridge): plate bottom to feet about 74 px at half resolution, head top about 10 px under the plate. That gives **0.86**, about **0.95 of a medium**.
- **Bulk:** broad and blocky. Big forearms and fists make the silhouette about **1.2x a medium's width** at the hands, and the stance is wide.
- **Ours:** `dolm`, medium, **1.0**.
- **Target:** **0.95-1.0** height, bulk about **1.2** (shoulders and forearms). Keep it a short, wide read, not a tall one.

### 2. Locomotion
- **Speed:** not cleanly measurable. The guide zoom shifts and most walking is short (182.0-184.0 s / 0729-0737; 128.6-128.8 s just before a dash). Nothing suggests she differs from the common run speed.
- **Gait** (182-184 s, 10 fps): a grounded, wide-legged walk with the fists carried low and forward of the hips. No hop or bounce.
- **Sneak:** a crouched walk while sneaking (the existing section 2, Stonesight).
- **Turning:** she faces the cursor at once; the body turns, not the legs.

### 3. Idle
- She stands wide with the fists low and ready (0730-0736).
- No loop is resolvable.

### 4. Ground dash (Landslide)
- **Timeline** (128.8-129.4 s / 0516-0518; bridge clip, measured against the fixed platform edge):
  1. At 128.8 s a rock spike bursts up just ahead of her.
  2. She drives forward behind it at a steady **640-690 px/s at this zoom** (about 4.5 hero heights per second, or **9-11 m/s**).
  3. At about 129.2 s the rock is launched as a fireball and she settles.
- **Distance:** about **2.5-3 bh in about 0.45 s**.
- **Pose:** a shoulder-down shove behind the rock, fists forward, low centre of mass.
- **Recovery:** short; she is upright behind the launched boulder within about 0.15 s.
- **Ours:** 4.2 m in **0.28 s** (15 m/s). That is shorter in time and faster than the source; the source is a **heavier, longer push**.

### 5. Air dash
- Not shown as a dash.
- The airborne moves in the guide are the RMB hop (jump while charging leaps forward; existing section 2, Volcano Crusher) and the dash-into-dunk combo (246-249 s / 0985-0997). Both are too small at that zoom for body detail.

### 6. Jump and landing
- **Hop:** the RMB release (0258 → 0259) is a short forward hop of about 1-1.5 bh, then a two-fist smash on landing.
- **Landing:** a big starburst, rock shards and a scorched crater for about 1 s. The landing is the attack; there is no separate landing recovery beyond a crouch.

### 7. Cast and attack body language
The largest motion budget of the five.
- **Punch:** a deep crouch and a cocked fist on the hold, then a straight drive.
- **Slam:** a crouched charge with glowing fists, a hop, then a fold-over smash.
- **Stone Row:** a stomp.
- **Squash:** strong on every landing and impact. The holds read as visibly compressed.

### 8. Build notes
- **Model scale:** about 0.97 height, bulk 1.2, with the forearms and fists the largest parts.
- **Collision:**
  - The medium `hit_r` 0.40 fits.
  - **Fairness:** the fists widen the silhouette but are not body; don't widen the hitbox for them.
- **Camera and nameplate:** the shared plate height (her head sits a little under it, like a medium); no camera change.
- **KMOVES and locomotion:**
  - `ARCH_STANCE["dolm"]` is close: knee 0.3, width 0.2. Set lean 0.1, bounce 0, breath 1.6, arm 0.7.
  - Fists carried low and forward while running, with a short, heavy arm swing.
  - Cadence 1.0 (a medium's).
- **Ground dash curve and pose:**
  - `time` **0.42-0.45**, `dist` about 4.6 (2.5 bh).
  - Constant speed after a 0.05 s start.
  - **Order:** spawn the rock first (by about 0.05 s), then move; launch it at the end.
  - `breah_dash` (kitfix) already has the shove pose. Stretch its keys to 0.07 / 0.18 / 0.4 / 0.48, then rest by 0.8.
- **Air dash:** the class long dash using `breah_exdash` (kitfix).
- **Sound:**
  - Footsteps: heavy, gritty stomps with gravel.
  - Dash: a stone crack as the rock bursts up, a grinding roll under the push, then a cannon thump at the launch.

### 9. Unclear
- **Run speed:** needs a straight 2 s run at a known zoom (the guide's match footage around 1045-1117 frames is the best bet, if a stretch of plain running is found).
- **Landslide speed curve:** needs a cleaner 60 fps view without the fire covering her (the bridge clip is the best one available).
- **Air dash and landing squash:** needs a match clip of a jump-pad or ledge dash.
- **Idle:** needs a 5 s idle.
