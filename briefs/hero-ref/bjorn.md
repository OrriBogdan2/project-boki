# Bjorn (id `bulwark`): reference sheet for source Oath

Footage: `/home/claude/svvid/hero/bjorn/frames/`, 5 fps. Frame N is video second 758 + (N-1)/5.
Scale: a hunter is about 50 px tall at 960 px width. That is "1 h" below (about 1 unit).
Ability windows by frame:
- LMB: 0011-0151
- Passive: 0153-0177
- RMB: 0179-0361
- Shift: 0365-0382
- E: 0383-0496
- R: 0498-0576

**The LMB has no spin in the source.** The brief expected Oath's LMB to spin. In this footage the hold is a single charged forward swing.
- The spin is the **Shift** ability, "360 Smash".
- During the LMB hold (0102-0108) the player sweeps the cursor in a circle round Oath. Oath turns with it, so he rotates about 1.5 turns in 1.2 s. That is aim-tracking, not an automatic spin. Every swing release is one crescent in front of him.

## 1. Source summary

| Slot | Ability | Input | Aim type | Cooldown / cost (card) | Effect |
|---|---|---|---|---|---|
| Passive | Knockout | - | - | - | Hitting enemies into walls stuns them ("STUNNED" label, stars) |
| LMB tap | Hammer (throw) | tap | **lands at the cursor** (clamped); the hammer stays planted; tap again to recall it | 0.45 s | 175 on the way out, 175 again on the way back |
| LMB hold | Hammer (swing) | hold, release | turn-to-cursor melee, a ~180° arc in front | - | 521 at a short hold, 976 fully charged; heavy knockback |
| RMB | Barrier Shield | hold | faces the cursor | 0.15 s, no cost | A curved shield in front blocks projectiles until it breaks |
| Shift | 360 Smash | tap | dash in the aim direction | 9.2 s, 20 | A short dash, then one 360° spin hit around him: 350 |
| E | Purify Zone | tap | at the **planted hammer** (on himself if the hammer is in hand) | 10 s, 60 | A healing zone (green beam and disc) |
| R | Earthshatter | tap | line in the aim direction | 33.3 s, 30 | A travelling fissure inside a rectangle telegraph, leaving a lasting crack |

Augment seen: **Empower Shield Bash** (4.8 s, 30): "Empower shield blocking damage and knocking enemies away from you" (frame 0296).

## 2. Per ability

### LMB tap: hammer throw (0024-0067, 0406-0427)

**Input.** Tap throws the hammer. It flies to the cursor and stays planted there. Pressing again recalls it.
- 0406-0426: planted for 3.6 s or more, then recalled.
- 0028-0031 and 0034-0037: recalled almost at once (about 0.4 s round trip).
- No automatic return is ever seen.

**Aim.** The hammer lands **at the cursor**:
- 0408: the cursor sits on the landing hammer.
- 0024-0025, 0029 and 0066: the hammer stops at the cursor, even past the dummy.

The hammer is not seen flying past the cursor, so it is clamped at max range (the max range is not shown; at least about 7 h is used). There is no line indicator. The body turns to the throw direction.

**Reticle.**
- The normal cursor: a small white ring about 14 px across with a centre dot.
- Over an enemy it shows a cross (0037, 0040).
- No throw-specific telegraph.

**Animation.**
- 0033 → 0034: the wind-up, about 1 frame. The arm is cocked back low and behind.
- 0034: release. An overhand throw, arm forward.
- 0035: in flight.
- 0036: at the cursor.
- Out-flight takes 0.2-0.4 s for about 5-7 h, so about 20-30 h/s.
- Recall flight takes about 0.2-0.4 s. 0031 / 0044 / 0427: caught with a small orange flash at the hand.
- Full cycle on the dummy (0039-0045): 1.2 s.

**VFX.**
- In flight the hammer glows gold and orange.
- 0408 (`distinctive`): when planted it stands tilted in the ground and sends up a tall golden light ray with chevron arrows. Our version should keep a vertical beacon function in our own look.
- 0037: a small purple-blue swirl shows at the landing point.

**Numbers.** 175 on the way out (0041), plus a second 175 on the way back (two numbers at 0043 and 0049).

### LMB hold: charged swing (0101-0110, 0116-0128, 0132-0149, 0160-0172)

**Input.** Hold to charge. Release swings.
- 0116-0118: a short hold of about 0.2-0.4 s gives 521.
- 0133-0146: a hold of about 2.6 s gives 976.

**Aim.** A melee crescent in front, towards the cursor. During the hold the hero **turns freely to face the cursor**, and the hammer stays cocked on the side away from the cursor (0102-0108).
- Movement while charging: not seen. He stays in place in both holds, which could be the player's choice (open question).

**Reticle.**
- No ground indicator during the hold. The cursor is unchanged.
- The tell is on the hammer head:
  - A 4-point white-gold **glint** appears about 0.6 s into the hold (0136).
  - It pulses on the head through the hold (0138-0144).
  - It becomes a large bright flare at full charge (0145).

**Animation.**
- Wind-up pose: crouched and side-on, the hammer held back low behind him, the shield arm forward (0133-0145).
- Release (0146 / 0109 / 0126): one frame (≤0.2 s). The hammer sweeps from behind to the front in about a 180° arc.
- Impact (0147 / 0119 / 0127): the frame after, with a white dust cloud at the target.
- Recovery: about 0.4 s (0147-0149).
- **There is no forward lunge.** Oath stays where he stood.

**VFX.**
- The crescent arc (0109, 0146): a flaming ribbon, yellow core with orange and red edges, about 1.5 h in radius, gone after one frame.
- Impact: a white dust puff.
- Knockback: the target flies about 2-3 h along the swing direction with a red debris trail (0148-0151).

**Numbers.** 521 at minimum (about 3x the throw) and 976 at full (about 5.6x the throw).

### Passive: Knockout (0153-0177)

1. The dummy stands with its back to a pillar.
2. A fully charged swing hits it (0169-0171, 976).
3. It is driven into the pillar: a "STUNNED" label over its health bar and a ring of white stars round the head (0170-0174, about 1 s or more visible).

No heal number on Oath is visible in these frames (open question).

### RMB: Barrier Shield (0179-0361)

**Input.** Hold to keep it up. The card shows a 0.15 s cast and no cost.

**Aim.** The shield faces the cursor and sweeps round with it at once (0185-0200). Oath turns with it.

**Look.**
- A pale gold, translucent, slightly curved slab.
- About 2.2 h wide and about 0.3 h thick.
- It stands about 0.5 h in front at chest height (0179, 0217).

**Blocking.**
- Enemy beams stop at the shield with a yellow spark burst (0217, 0226).
- After about 15 s of dummy fire: "SHIELD BROKEN" text, a yellow explosion and gold shards flying outward (0258-0259).

**Movement while held.** Not clearly seen; he mostly stands still.

**Augmented version (0282-0361).**
- The shield turns red-orange with crackles.
- 0300: a hit gives a big white-pink flare.
- 0309: the dummy is hit as the shield goes down (red flash), which matches the bash knock-away of the augment.

### Shift: 360 Smash (0365-0382)

**Aim.** A dash in the aim direction:
- 0370: Oath is about 2.5-3 h from the dummy.
- 0371: he is at the dummy.

So he covers about 3 h in ≤0.2 s. The cursor was further away than where he stopped, which suggests a **fixed-length dash, not to the cursor**.

**Animation and VFX.**
- 0370: a white-purple spark at his feet at the start.
- On arrival (0371): **one full 360° spin**, with a red and orange swirl ring about 1.2 h in radius around him.
- 0372: a fading gold tail.
- About 0.4 s recovery.
- The second use (0379-0380) shows the ring yellow at first, then dark gold.

**Tell (unclear).** A blue ring appears around the target dummy the frame before (0370, 0378), together with "ENEMY SPOTTED" text. This could be the target's reveal from the hammer rather than part of the dash.

**Numbers.** 350 (2x the throw). 9.2 s, 20 cost.

### E: Purify Zone (0383-0480, also 0269-0281)

**Aim.** At the planted hammer (0412-0420, 0436-0447, 0461-0470).
- 0269: the hammer was in hand, and the zone came down **on Oath himself**.

**Animation and VFX.**
1. A green light column comes down from the sky onto the spot (0412-0416).
2. A green disc about 1.3 h in radius, with concentric rings.
3. A pulse outward with green streaks rising (0418).
4. Gone by about 1.8 s (0421).

Healing shows as rising green bars on the units inside.

**Numbers.** 10 s, 60 cost.

### R: Earthshatter (0498-0576)

1. 0498: telegraph. A cyan rectangle outline about 2 h wide and 8 h long ahead of Oath, with a square near him.
2. 0500-0512: eruption. A pillar of fire bursts in the near square, then square sections advance along the line over about 2 s.
3. Afterwards: a glowing yellow zig-zag crack stays on the ground for about 10 s (0513-0560).

33.3 s, 30 cost. **Dropped in ours**, because R is the Merge.

### Sound
The footage has no audio to judge from.

### Combo / payoff
1. Throw the hammer to set the zone spot and get vision.
2. Use a charged swing or the shield bash to knock the foe into a wall: a Knockout stun.
3. Follow up with a throw and recall (two hits).
4. Purify Zone at the hammer heals the fight spot.

## 3. Key frames (`/home/claude/hero-ref/bjorn/`)

| File | Caption |
|---|---|
| 0034.jpg | Throw release, arm forward; the cursor marks the target |
| 0035.jpg | Hammer in flight towards the cursor |
| 0036.jpg | Hammer at the cursor (purple marker) |
| 0041.jpg | Throw hit on the dummy, 175 |
| 0043.jpg | Return hit, second 175 |
| 0104.jpg | Hold: hammer cocked away from the cursor, glint on the head |
| 0109.jpg | Swing release: flaming 180° crescent |
| 0138.jpg | Hold pose next to the dummy, glint |
| 0145.jpg | Full-charge flare on the hammer head |
| 0146.jpg | Full-charge swing arc |
| 0147.jpg | Impact dust, 976 |
| 0171.jpg | Knockout into the pillar: STUNNED |
| 0179.jpg | Barrier Shield up, facing the cursor |
| 0217.jpg | Shield blocking a beam |
| 0258.jpg | SHIELD BROKEN burst |
| 0371.jpg | 360 Smash: spin ring on arrival, 350 |
| 0408.jpg | Planted hammer with the golden beacon ray, the cursor on it |
| 0414.jpg | Purify Zone column and disc at the hammer |
| 0498.jpg | Earthshatter rectangle telegraph |
| 0505.jpg | Earthshatter eruption travelling |

## 4. Gaps against ours, ranked by how much they change the feel

Files:
- Kit: `scripts/arch/kits/bulwark_kit.gd`
- Data: `content/archetypes/bulwark.json`
- Moves: `scripts/match/hunter_anim.gd` (KMOVES `bul_*`)

1. **Throw lands at the cursor** (`aim`, `mechanic`)
   - Ours: `_throw` sets `dir` only, and `_tick_mace` flies until `throw_range` (9 m) or a wall. The mace always goes the full 9 m.
   - Source: it stops at the cursor, clamped to max range.
   - Fix: store `"to": aim_at(throw_range)` in `_throw`, and in `"fly"` land when `d >= min(dist_to_target, throw_range)`.
2. **Damage ratios** (`numbers`)
   - Ours: throw 16 / recall 10 / smash 14-34.
   - Source: the throw and recall hit equally (175 / 175), and the swing is 3x (min) to 5.6x (full) the throw.
   - Ours makes a weak swing do less than a throw.
   - Suggest `recall_dmg` = `throw_dmg`, and `smash_dmg` about `[3, 5.6] x throw` (with throw 11: `[33, 62]`, then tune). Shift is 2x the throw: `whirl_dmg` 6 → about 22.
3. **LMB hold: no lunge, free turning, and a hammer-head glint** (`anim`, `reticle`, `mechanic`)
   - Ours: `_smash` adds 3-8 m/s of forward velocity. The source does not move. Remove the carry, or keep it only as our own jump-into-glide extra.
   - Make sure the body yaw tracks the aim continuously during `bul_smash_wind`, with the hammer held on the far side.
   - Add the charge tell: a glint on the mace head from 0.6 s that grows, and a flare on full (driven by `smash_k()`).
   - Ours fully charges at 1.25 s. The footage only shows that full is reached by 2.4 s, so keep 1.25.
4. **Swing VFX** (`vfx`, `anim`)
   - Ours: dust and a ring.
   - Source: a one-frame flaming 180° crescent in front (about 1.5 h radius), a white dust puff on the target, and a long knockback with a debris trail.
   - Add a crescent `m.fx.slash` in `_smash` (`arc` 130 → about 180 to match the look).
   - In `bul_smash` the hammer should sweep from behind to front, rather than the current pitch-down slam.
5. **Shift is a short dash ending in ONE 360° spin hit** (`anim`, `vfx`, `numbers`)
   - Ours (Whirl): a 3.6 m travel with three slashes along the way, and the `bul_whirl` full turn takes 0.2 s.
   - Source: about 3 h in ≤0.2 s, then a single spin ring on arrival (1.2 h radius) that does the damage.
   - Fix: move the hit to the end of `travel`, play one ring burst, and keep `bul_whirl` at one turn.
   - Cooldown: 10 s → about 9.
6. **Planted hammer and recall** (`mechanic`, `vfx`)
   - Ours: auto-recall after `lie_t` 6 s, with a 4.5 m vision ring pulsing every 0.5 s.
   - Source: it stays until you recall it (≥3.6 s seen), and its tell is a tall vertical beacon ray (`distinctive`: use our own beam look).
   - Keep the vision; make the main visual a vertical light beam on the mace.
7. **E with the mace in hand lands on yourself** (`mechanic`, `aim`)
   - Ours: `cast_e` uses `aim_at(7)` when the mace is not lying.
   - Source: it comes down on Oath when the hammer is in hand (0269).
   - Change the fallback to `h.pos`. Also make the beam-from-sky the telegraph during our 1 s delay.
8. **Shield look** (`vfx`): a curved slab about 2.2 h wide (ours: a 3 m flat wall) in pale gold, with yellow sparks on block and a gold shard explosion and "SHIELD BROKEN" on break (ours already has the word).
9. **Bash on RMB release** (`mechanic`, our extension): in the source the bash knock-away is an augment (Empower Shield Bash). Ours bashes on every release. Keep it (it is documented), but note it as an extra and not a match.
10. **Passive heal** (`numbers`): ours heals 24 on a Crush. The footage shows only the stun, so it neither confirms nor contradicts the heal.

## 5. Rename (Bjorn): player-facing places still saying "Bulwark"

- `content/archetypes/bulwark.json` `"name": "Bulwark"`: the class name used on the kit card, HUD and pickers.
- `scripts/match/hero_kit.gd:19` `"bulwark": {"name": "Bulwark", "cls": "heavy"}`.
- Wiki output (generated by `tools/gen_wiki.py`):
  - `docs/wiki/Class-Bulwark.md` (title, file name)
  - `docs/wiki/Classes.md` (lines 9, 59, 75)
  - `docs/wiki/Home.md:22`
  - `docs/wiki/Weapons.md` (lines 8, 29)
  - `docs/wiki/_Sidebar.md:12`
  - `docs/wiki/Inspirations.md:18`
- `tools/gen_wiki.py:423`: hard-coded text "the Bulwark's shield and mace".
- `docs/ABILITIES.md` / `tools/gen_abilities_doc.py:112`: these mean the separate **Bulwark ability** of the minigun (`content/abilities/bulwark.json`, `"name"/"short": "Bulwark"`), a name clash to resolve or keep.
- sfx label: `tools/sfx_combat.py:534` comment "Bulwark Shield Slam".
- Code comments only, not player-facing:
  - `bulwark_kit.gd` header
  - `verbs.gd:384`
  - `main.gd:1512`
  - `models.gd:1696`
  - `hunter_anim.gd:1366`
  - `arena_demo.gd:22,363`
- No string "Bjorn" exists anywhere in origin/main yet.

## 6. Open questions

- Can Oath walk while charging the swing? He never moves in the footage. Ours walks at 0.55x.
- Throw max range, and whether a throw past it lands short (it is never thrown beyond about 7 h).
- Does the planted hammer ever return by itself?
- Does Knockout heal Oath? Its exact stun length? A STUNNED label is visible for about 1 s or more.
- Is the 360 Smash a fixed distance or up to the cursor? (It stopped short of the cursor once.) Is it invulnerable?
- Shield health and regeneration, and movement speed while shielding.
- What is the blue ring on the target before the Smash (0370, 0378)?

## Ultimate (on X)

**Source:** Oath, Earthshatter. Card: "Create a large fissure that damages enemies caught in it", 33.3 s, 30 mana. Frames are in `/home/claude/svvid/ult/bjorn/` (frame N = 855 s + (N-1)/10). Cast 1 at f25; cast 2 at about f81.

1. **Input:** tap. Fine print wasn't found; the old thebackdash text for Oath's ult is a copy of Kingpin's and is wrong.
2. **Aim:**
   - A **fixed-length lane toward the cursor**, about 2.5 bh wide and about 8–9 bh long, starting at Oath.
   - It is not cursor-clamped: the lane ran past the dummy.
   - He is planted for the wind-up and slam (f25–f31).
3. **Reticle / telegraph:**
   - On press (f25), a **cyan outline rectangle** for the whole lane appears, with a cross-line splitting off a **square cell** around Oath.
   - The lane reads as stacked square cells, each about 2.5 × 2.5 bh.
   - The outline stays while the fissure travels, so enemies see the whole danger area for about 0.4 s before the first eruption.
4. **Animation beats:**
   - f25–f28 (0.4 s): wind-up, hammer raised overhead.
   - f29: the slam into the near cell, which floods with **gold light**.
   - f31–f35 (0.4 s): a **bright fire and light streak races down the lane** to the far end.
   - f35–f39: the cells crack (white zig-zag cracks), and each cell lifts as a **translucent glass-like slab or block**, one after another from near to far (f39: the 2nd cell raised).
   - The dummy is hit at about f37 (a red burst).
   - f43 onward: a glowing **yellow zig-zag crack** stays along the lane's centre line for about 10 s (it was gone by f71 of cast 1).
5. **VFX:** the cyan cell grid, the gold flash, the racing streak, cracking cells that pop up as slabs, and the lingering lightning-crack. The **cyan cell grid with rising glass slabs** is `distinctive`. Ours should keep "a lane erupts near to far, then a scar remains" with our own rock look.
6. **Sound:** none. It suggests a heavy slam thud, then a rolling rumble that runs down the lane and a crackle while the scar persists.
7. **Numbers:** the damage number wasn't legible (the dummy was knocked in cast 2). The lingering crack's effect (damage, slow, or just a visual) isn't shown.
8. **Ends / combo:**
   - It ends after the eruption. The scar persists for about 10 s, function unknown.
   - Combo: Barrier Shield to walk forward safely, then Earthshatter down the line of enemies. Thrown-hammer positioning (Purify Zone) also sets up the angle.
   - Allies: unaffected.

**Key frames:** `bjorn/ult_0023.jpg` (before), `ult_0025.jpg` (cyan lane telegraph), `ult_0027.jpg` (wind-up), `ult_0029.jpg` (slam, gold cell), `ult_0031.jpg` (streak racing), `ult_0035.jpg` (cells cracking), `ult_0037.jpg` (dummy hit), `ult_0039.jpg` (slab rising), `ult_0043.jpg` (zoomed-out lane), `ult_0053.jpg` (lingering crack).

**Build notes:**
- **What to build:** X = a 0.4 s planted wind-up showing a 2.5 × 9 bh lane toward the cursor, then the fissure erupts cell by cell (about 0.15 s per cell), knocking up each enemy once. It leaves a 10 s scar; suggest a mild slow so it has a function.
- **Bond:** the first hunter hit adds **0.6**, and each extra hunter adds 0.1, capped at 0.8. The long lane is easy to land on a group, so per-target pay keeps it fair.

## Body, scale and movement feel

Method and units are as in venator.md's section of the same name: the hunter's ground motion comes from tracking the bar plus the camera pan. Distances are in 960 px units, 1 px ≈ 0.0375 m, 1 bh = Ghost's height ≈ 48 px ≈ 1.8 m. Zoom is the same in every clip. **Note: the training dummy "Kimic" in every clip is an Oath-model hunter, so Oath's size can be read off the dummy in every segment.**

### 1. Height and bulk
- **Dummy (Oath, standing neutral):** ~107 px at 1080p from helm to sole and ~110-123 px wide (`pin 0065`, `juggernaut 0041`, `vireo 0050`, `bjorn 0101`).
- **Bjorn himself:**
  - ~105 px in the crouched swing stance (0471) and up to ~145 px when walking toward the camera, where the forward lean adds depth (0425).
  - He is 140-160 px wide across the pauldrons (0471).
- **Against Ghost (~96 px tall, ~55 wide):** about **1.1-1.15x as tall and about 2x as wide**. Most of the difference is bulk, not height.
- **Ours:** bulwark is heavy, scale 1.14 × CLASS_LOOK size 1.035 = **1.18x medium**, with build 1.14.
- **Target scale factor ~1.15**, a hair down from 1.18. Push the width instead: a per-hero build of ~1.35 (pauldrons and torso) so he reads as a wall, not a tall man.

### 2. Locomotion
- **Run speed:**
  - The median steady move is 117 px/s ≈ 4.4 m/s.
  - Stretches vary from 104 to 139 px/s: 0082-0089 at 136, 0110-0115 at 104, 0173-0177 at 134, 0450-0454 at 117, 0487-0491 at 115, 0558-0562 at 139.
  - That is **no slower than Ghost (110) or the lights (113)**. Ours: heavy 4.55 against medium 4.8 and light 5.0. The source has no heavy slowdown.
- **Start and stop:** instant, like everyone else.
  - Start: 6 → 135 px/s in one 30 fps frame at 774.27 s.
  - Stop: 84 → 39 → 17 px/s at 775.9 s.
- **Cadence:** the leg-region oscillation measures ~2.5 Hz stride (rough, ±15%), no slower than the lights. The legs are mostly hidden under the bulk from this camera. Ours: heavy `spd*1.95` → 1.41 Hz. **Ours is far slower-stepping than the source.**
- **Lean:**
  - At a run he pitches far forward with the shield shoulder leading and the hammer held low and back on the other side (0082-0089, 774.2-775.6 s). The silhouette goes long and low in the travel direction.
  - The shoulders stay level and square. There is almost no visible shoulder roll or bob.
  - Ours: bulwark lean 0.0 and shoulders square (yaw ×0.5). The square shoulders are right; **the missing piece is the strong forward pitch when running.**
- **Turning:** the body turns to the aim almost at once. During the charged swing the player sweeps the cursor and he turns about 1.5 turns in 1.2 s (0102-0108).
- **Weapon carry:** the hammer is low and trailing, and the shield arm is forward.

### 3. Idle
- He stands square and wide with the hammer hanging at the side (0463-0479, between casts).
- No breathing or fidget loop can be seen at this resolution. The idle reads as planted and still.
- Ours (breath 1.5, wide stance) fits.

### 4. Ground dash (Shift: 360 Smash; there is no separate plain dash in the footage)
- **Timing:** 831.80-831.90 s and 833.50-833.60 s (frames 0369-0370, 0377-0378).
  - The dash proper takes ~0.15-0.2 s. The body is stretched forward behind the hammer with a blue spark trail at the hammer head.
  - Then comes **one full spin in ~0.15-0.2 s** (831.95-832.10, 833.65-833.80), a single yellow crescent ring round him.
  - Then **~0.4 s of low, crouched recovery** (832.15-832.35 and 833.85-834.25).
- **Distance and speed:**
  - Measured travel: 144 px ≈ 5.4 m ≈ 3 bh over 0.33 s (0377-0379), peaking at 530 px/s (~20 m/s) 0.17 s in.
  - Other casts: 123 px (4.6 m, 0.4 s, 0516-0518) and ~86 px (0369-0370).
  - He keeps sliding forward through the spin.
- **Curve:** a fast rise (218 → 495 → 524 px/s over 0.1 s), then a decay through the spin.
- **Ours (kitfix-pin-bjorn):**
  - 360 Smash is 4.2 m in 0.28 s at 15 m/s, then the spin.
  - `bul_whirl` keys: lean-in to 0.26 s, the turn 0.26-0.42, settle by 0.66.
  - The structure matches. **Difference: the source dash is shorter and harder (~0.17 s at ~20 m/s peak) and keeps carrying through the spin; ours is a slower 0.28 s run-up.**

### 5. Air dash
- Not shown. He never leaves the ground in the clip apart from ult effects.

### 6. Jump and landing
- Not shown.

### 7. Cast and attack body language
- **Budget:** big and slow, with heavy wind-ups.
  - Throw: the hammer is cocked low behind for one frame, then an overhand throw (see §2 of this sheet).
  - Charged swing: a long hold, then one crescent in a single frame with the body lunging after it, then ~0.4 s of recovery.
  - Purify: the hammer is hauled up, then driven down.
  - Every big move ends in a low crouch.
- **Squash and stretch:**
  - Stretch forward on the Smash dash.
  - Squash into the recovery crouch after the spin and after the swing.

### 8. Build notes
- **Model scale:** ~1.15x medium, with a per-hero build width of ~1.35.
- **Collision:** hit_r 0.50 (heavy). His shoulders run ~1.4-1.6x Ghost's width each side, so a 0.5 m radius is still a little inside the pauldrons. That is fair to attackers only if the ring stays a slight undersize, which is our usual bias. Keep 0.5 and don't grow it with the build widening, so a wider model doesn't become an easier target than the kit intends.
- **Camera and nameplate:**
  - The dummy's bar sits ~131 px (1080p) above its soles, about 1.35 bh ≈ 2.45 m.
  - Move his overhead anchor from the shared 2.35 to **~2.6 m** (`ui/hud.gd:416` per-hero offset, or scale it by model scale).
  - Camera: nothing hero-specific.
- **KMOVES and locomotion:**
  - Cadence about `spd*2.9` (drop the heavy 1.95 special case).
  - Running lean: a forward pitch of ~0.3-0.35 rad at full run on top of the current stance, shield shoulder leading (yaw +0.3), hammer low behind.
  - Keep the shoulders square (yaw ×0.5) and the bob small (the current `off.y -= |cos ph|*0.025` is fine).
- **Dash curve:**
  - 360 Smash: ~0.17 s to ~20 m/s peak, about 3.5 m covered, then the spin with ~1 m of extra glide.
  - Shorten `bul_whirl`'s run-up key from 0.26 to ~0.17, keep the 0.16 s spin, and add a crouched recovery hold to ~0.55-0.6 s.
  - `bul_lumber` (our long air dash) has no footage to match. Keep it.
- **Sound:**
  - Footsteps: heavy but quick, plate clank on every step, no slow stomp (he steps as fast as the lights).
  - Smash dash: a short metal scrape and whoosh, a heavy whoom on the spin, and a boot grind on the stop.

### 9. Unclear
- Jump, landing and air dash. Settle them with a clip of Oath taking a jump pad or dropping off a ledge, ideally Smash cast mid-air.
- Cadence (the legs are hidden). Settle it with a side-on 60 fps run, or a run past the camera's lower edge.
- Why some runs are faster (136-139 px/s at 0082-0089 and 0558-0562): a buff, or downhill. Settle it with a plain run with no ability up.
