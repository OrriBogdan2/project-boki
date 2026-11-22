# Ostra (id `ostra`): reference sheet for source Void

Footage: `/home/claude/svvid/hero/ostra/frames/`, 5 fps. Frame N is video second 954 + (N-1)/5. 1 h is about one hunter height (about 50 px).
Ability windows by frame:
- LMB: 0009-0104
- RMB: 0105-0151
- Shift: 0152-0300
- E: 0311-0430
- R: 0434-0494

## 1. Source summary

| Slot | Ability | Input | Aim type | Cooldown / cost (card) | Effect |
|---|---|---|---|---|---|
| Passive | (Empowered) | builds by itself | - | - | Empowered state: a magenta sphere aura; it changes Swap and Black Hole (cards say "Empowered: ...") |
| LMB | Gravity Orb | tap / hold-fire | skillshot to **max range along the aim** (flies past the cursor) | 0.6 s | 140 (+68). Orbs charge while not firing; firing faster lowers projectile speed and damage. A fully charged orb slows 6% for 1.5 s |
| RMB | Void Snap | tap | skillshot along the aim | 5.8 s, 30 | A shard cluster, 190 (+357); stun 0.8 → 1.8 s, longer the further it flew |
| Shift | Swap | tap | **lands at the cursor** (lob) | 7.5 s, 30 | Lob, teleport to where it lands, and swap places with any units there. Empowered: 2 s → 1.25 s |
| E | Unstable Anomaly | tap, recast | **at the cursor** | (cooldown not read), cost about 15 | Bomb; recast after 0.3 s or more to detonate. 180 (+489.6) at minimum, up to 2.5x over 6.5 s, and it grows |
| R | Black Hole | tap | at the cursor | 58.3 s, 30 | A vortex stuns and pulls to its centre for 3.5 s, 2.5 per 0.1 s. Empowered: radius 350 → 500 |

## 2. Per ability

### Passive / idle look (0026-0037, 0085-0086, 0105-0151)

**Idle look.**
- She hovers, with an orange-gold glow disc under her.
- Two small purple crystal shards orbit her.

**Empowered turning on (0085-0086).**
- 0085: a dark purple vortex disc on the ground round her.
- 0086: a pink flash.
- She then sits inside a translucent **magenta sphere** for about 9 s (0105-0151; again at 0428).
- What fills it is not shown on screen.

### LMB: Gravity Orb (0009-0104)

**Input.** Tap or hold to fire one orb about every 0.6 s (0031 → 0034). The orbs charge while she is not firing.

**Aim.** A straight skillshot along the aim. Orbs fly **past the cursor** to max range (0031-0033). She turns to the aim.

**Reticle (important).**
- A **permanent thin white aim line** from Void to the cursor, ending in a small arrowhead at the cursor.
- It shows the whole time this hero is selected (0026-0037, 0057-0068, 0113, 0176).
- The cursor is the same small ring as the other heroes.

**Charge tell.**
- While charged, a blue-white ring orb with a bright core floats at her casting hand (0029-0030, 0036-0037).
- It is spent on the next shot.

**VFX.**
- Normal orb: a magenta-violet teardrop with a short trail (0031).
- Charged orb: a long blue-violet bolt (0034).
- Charged hit: a translucent blue bubble round the target (0058-0059, 0067) and a "SLOWED" label.

**Speed.** About 25 h/s (0034 → 0035).

**Numbers.** About 318 shown on a charged hit (0059, 0104). Plain hits are not readable.

### RMB: Void Snap (0113-0141, 0419-0421)

**Reticle while aiming.** **Two parallel thin white lines** to the cursor, showing the width of the cluster (0113-0114, 0136-0137). This replaces the single LMB line.

**Animation.**
1. 0115 / 0138 / 0419, one frame (about 0.2 s): a black sphere with a bright white rim appears at her hand.
2. Next frame (0116 / 0139): a long bundle of violet crystal shards, spear-shaped and about 1.5 h long, crossing about 6 h in 0.2 s (`distinctive`: the black-orb-then-crystal-spear look).

**Hit.**
- 0140: 751 (Empowered at the time), a pink flash.
- Then a "STUNNED" label and gold stars, about 1.2 s visible (0140-0146), after a flight of about 3 h.

**Card.** Stun 0.8 → 1.8 s, longer with distance.

### Shift: Swap (0152-0200)

**Reticle while aiming.**
- The aim line to the cursor.
- A **translucent landing circle at the cursor**, about 1.5 h across (0156-0157, 0183).

**Cast (0158 / 0184).**
- Pale cyan rings appear **both** around Void (the origin) and at the landing spot.
- A dark blue star-orb is launched.

**Flight.**
- A high lob: the star climbs well above the field with a purple trail, then curves down onto the spot (0159-0167).
- About **1.8 s** in total (card: 2 s; 1.25 s Empowered).
- Meanwhile a violet **rune sigil** fills in at the landing ring (`distinctive`).

**Landing.** Exactly at the cursor.

**Result.**
- 0168: with nobody at the landing spot, she teleports (the camera jumps).
- 0193: the dummy was standing **on top of Void at the origin**. After the lob the dummy was at the landing spot and Void **stayed at the origin**. So units in the origin ring were sent to the destination (see the open questions).

### E: Unstable Anomaly (0347-0411, 0423-0429)

**Aim.** At the cursor.

**Cast.** A small glowing orb drops onto the spot (0352).

**Growth.**
1. A pale blue translucent cylinder about 0.8 h in radius (0352).
2. It fills with a swirling dark indigo field.
3. It grows to about 1.8 h in radius over about 6.4 s (0352 → 0384).
4. From about 4.4 s in (0373) a **purple light column** rises from its top: the full-size tell.

**Detonate.**
- A violet-white swirl that **implodes** (0385), then dark shards (0386).
- Pink critical-style number: **1674** at about 6.4 s (0385).
- A quick pop at about 0.6-0.8 s (0405 → 0409): **461**. That is a ratio of about 3.6x (perhaps with Empowered).

**Combo shown (0419-0429).** Snap stun → bomb on the stunned dummy → pop (490).

### R: Black Hole (0437-0458, Empowered 0470-0492)

1. Telegraph: a pale blue dome about 2 h in radius for about 0.8 s (0437-0441).
2. Then a purple spiral vortex about 1.6 h in radius for about 3.2-3.5 s. The target is pulled to the centre with a pink stun marker over its head.
3. Empowered: larger, with a pink-magenta core.

**Dropped / folded in ours** (rank-3 seed pull).

### Sound
No audio judged.

### Combo / payoff
1. Snap to stun at long range.
2. Drop the bomb on the stunned target.
3. Let it grow.
4. Pop it.

Swap repositions you or the target into the bomb. Empowered shortens Swap and enlarges Black Hole.

## 3. Key frames (`/home/claude/hero-ref/ostra/`)

| File | Caption |
|---|---|
| 0029.jpg | Charged orb at the hand, permanent aim line to the cursor |
| 0031.jpg | Normal orb (magenta teardrop) flying past the cursor |
| 0034.jpg | Charged bolt released |
| 0059.jpg | Charged hit: blue bubble, SLOWED |
| 0085.jpg | Empowered turning on: purple vortex disc under her |
| 0113.jpg | Snap aiming: double-line width indicator |
| 0115.jpg | Snap wind-up: black sphere with white rim |
| 0116.jpg | Snap crystal-spear cluster in flight |
| 0140.jpg | Snap hit: 751, STUNNED |
| 0157.jpg | Swap aiming: landing circle at the cursor |
| 0158.jpg | Swap cast: rings at the origin and destination |
| 0161.jpg | Swap lob arcing high |
| 0167.jpg | Swap sigil filled, just before the teleport |
| 0193.jpg | Swap result with the dummy at the origin: the dummy at the landing spot |
| 0352.jpg | Bomb placed (pale cylinder) |
| 0372.jpg | Bomb mid-growth |
| 0384.jpg | Bomb full, with the light column |
| 0385.jpg | Full pop: implosion, 1674 |
| 0409.jpg | Early pop: 461 |
| 0445.jpg | Black Hole vortex |

## 4. Gaps against ours, ranked by how much they change the feel

Files:
- Kit: `scripts/arch/kits/ostra_kit.gd`
- Data: `content/archetypes/ostra.json`
- Weapon: `content/weapons/tether_lantern.json`

1. **LMB rhythm** (`mechanic`)
   - Ours: a binary prime after 1.4 s idle (+30% damage, +40% speed, 10% slow).
   - Source: the orb charges while idle (fully charged: slow 6% for 1.5 s), **and spamming is penalised** (faster firing lowers projectile speed and damage). Ours has no spam penalty, so holding fire is free.
   - Fix: in `_tick_weapon`, scale `dmg` and `speed` by time since the last shot, both below and above the base.
   - Ours says "slow drifting orbs" at 22 m/s. The source orb is quick (about 25 h/s), so raise `speed`.
2. **Permanent aim line, and Snap's double line** (`reticle`)
   - The source always draws a thin white line from the hero to the cursor with an arrowhead.
   - RMB aiming switches it to two parallel lines (the width of the cluster).
   - Swap aiming adds a landing circle at the cursor.
   - Ours has none of these; add a hero reticle hook in the kit.
3. **Swap timing and markers** (`numbers`, `vfx`)
   - Ours: 1.0 s (0.72 s Swollen).
   - Source: about 1.8-2 s (1.25 s Empowered), shown with a very high lob arc and markers at **both** ends (origin rings, a sigil filling at the destination).
   - Ours documents the shorter time on purpose. Either restore about 1.6-2.0 s, or keep it and note it.
   - Raise the lantern arc (ours peaks at `sin*2.2` m → about 4-5 m).
   - Add an origin ring.
   - Show the landing circle while aiming, before the press.
4. **Void Snap shape and stun** (`numbers`, `anim`, `vfx`)
   - Ours: three separate shards in a 9° fan, stun 0.3-1.0 s.
   - Source:
     - one tight cluster (a spear-like bundle)
     - stun **0.8-1.8 s**
     - a visible 0.2 s wind-up (a black orb at the hand) before release
   - Fix: `rmb.snap.stun` → `[0.8, 1.8]`. Narrow `fan_deg` (or fire a single fat projectile). Add a 0.2 s cast delay with a dark-orb tell in `fire_rmb` / `ostra_rmb`.
5. **Bomb growth and damage curve** (`numbers`)
   - Ours: grows 5 s to 3 m, damage up to 3.5x.
   - Source: 6.5 s to about 1.8 h, 2.5x on the card (3.6x seen).
   - Ours pops by itself at full growth. In the source it ended at about 6.4 s; whether that was manual is unclear.
   - Add a 0.3 s minimum before recast in `e_recast`.
   - Add the full-size tell (a light column) and an implosion pop.
6. **Empowered aura** (`vfx`)
   - The source wraps the hero in a magenta sphere for the whole Empowered state (about 9 s), with a vortex-disc and pink-flash trigger.
   - Ours: `tell` "full" (the lantern burns white, the hem lifts).
   - Swollen lasts 7 s; the source looked like about 9 s → consider 9 (`swollen_t`).
7. **Bomb cast is a lob** (`anim`)
   - Source: a small orb drops onto the spot before the field appears.
   - Ours: the seed appears at once. Add a 0.2-0.3 s drop.
8. **Black Hole** (`mechanic`): ours folds the pull into the rank-3 seed. The source pull is 3.5 s of stun-pull with a 0.8 s dome telegraph. Nothing to change beyond what is documented.

## 5. Rename
Ostra is not in the rename list.

## 6. Open questions

- Swap when units stand at the **origin** (0193): the unit was sent to the landing spot and Void stayed. Is that the rule (it swaps whoever is in the origin ring), or an artefact of the dummy?
- What fills Empowered, and how long does it last exactly?
- Does the bomb auto-detonate at 6.5 s?
- E cooldown (not legible on the card).
- Max ranges of the orb and Snap.
- Does the orb charge gradually, or in steps?

## Ultimate (on X)

**Source:** Void, Black Hole. Card: "Summon a powerful vortex that stuns and pulls enemies toward its center for 3.5s and deals 2.5 damage every 0.1s. **Empowered:** Radius increases from 350 to 500." 58.3 s, 30 mana. Frames are in `/home/claude/svvid/ult/ostra/` (frame N = 1039 s + (N-1)/10). A normal cast at f23; an Empowered cast at about f89.

1. **Input:** tap.
2. **Aim:** placed **at the cursor**, clamped to range. The cast was about 2–3 bh away, on the dummy, and the vortex centred there.
3. **Reticle / telegraph:**
   - On press, a **pale blue translucent dome** of the final radius (350 units, about 2 bh) appears at the target (f23).
   - **Violet tendrils or a reaching hand** extend from Void to the dome (f27–f30).
   - About 1.0 s later the dome becomes the vortex (f33).
   - Empowered: the dome is larger (500 units, about 2.8 bh) with a **hot pink core** (f89–f95).
4. **Animation beats:**
   - f23: a hand thrust.
   - f23–f32 (1.0 s): the telegraph.
   - f33: the vortex opens. The enemy is **snapped to the centre and stunned** (a pink marker over its head), then held.
   - f33–f66 (about 3.4 s): a purple spiral disc rotates, with small black debris orbs circling the rim.
   - f66: it closes with no explosion.
   - Void is free to act during it (f50: she is shooting).
5. **VFX:** the blue dome, then a rotating violet galaxy-spiral disc with orbiting black orbs. The "black-hole spiral" is common, but the hand-tendril cast is `distinctive`; drop it.
6. **Sound:** none. It suggests a rising suction whoosh and a low droning hum during the hold.
7. **Numbers:**
   - Card: 2.5 every 0.1 s for 3.5 s, about **87.5 total base**. Stun and pull for 3.5 s. Radius 350, or 500 Empowered.
   - Fine print: Empowered damage is **Explosive**, so it hits destructibles harder.
   - Card cooldown 58.3 s, 30 mana.
8. **Ends / combo:**
   - It ends after 3.5 s.
   - Combo: Void Snap (stun) or a Gravity Well bomb (Reactivate to detonate, 180 + scaling) into the clustered, stunned targets. Hands of Fate gets Empowered first for the bigger radius.
   - Allies: unaffected.

**Key frames:** `ostra/ult_0021.jpg` (aim), `ult_0023.jpg` (blue dome telegraph), `ult_0027.jpg` (tendrils reaching), `ult_0030.jpg` (dome about to snap), `ult_0033.jpg` (vortex opens, pull), `ult_0050.jpg` (hold, Void acting freely), `ult_0066.jpg` (closing), `ult_0089.jpg` (Empowered dome, pink core), `ult_0095.jpg` (Empowered telegraph), `ult_0101.jpg` (Empowered vortex, bigger).

**Build notes:**
- **What to build:** X = cursor-placed (clamped) 1.0 s dome telegraph, then a 3.5 s pull and stun vortex of about 2 bh (about 2.8 bh when Empowered) with small ticking damage. Ostra is free to act during it.
- **Bond:** each hunter caught when it opens adds 0.4, capped at **0.8**. A 3.5 s stun is huge, so pay on the catch, not per tick.

## Body, scale and movement feel

The method and yardsticks match `linwick.md` (same camera zoom; 50 px ≈ 1 m; a medium is about 90 px head to foot; the nameplate sits about 110 px above the ground point for everyone). Frame N = (t - 954) x 5 + 1.

### 1. Height and bulk
- **Height:** about **75 px of body** plus about 15 px of trailing hem tails, so about 90 px in all (961.0 s / 0036, 3x grid crop).
- **Width:** about 58 px across, which is medium.
- **She hovers.** There are no feet. Her shadow starts about 10-15 px below the hem, a gap the walking heroes don't have. She floats at about **0.15-0.2 of her height** (roughly 0.25-0.35 m), with a glow disc under her.
- **Ours:** medium, **1.0**.
- **Target:** about **0.9 for the body**, lifted by a hover of about 0.3 m, so the total reads 1.0.

### 2. Locomotion
- **Speed:** steady camera-follow plateaus of **160-260 px/s, averaging ~205 px/s ≈ 4.1 m/s** (970.2-971.2 s / 0082-0087; 974.2-975.0 s / 0102-0106; 988.2-989.2 s / 0172-0177). That is a little slower than Felix and Celeste. Ours (medium) is 4.8.
- **Gait:** none. She **glides**: no steps or leg cycle are seen at 20-30 fps, and the hem and tails trail behind the motion.
- **Bob and lean:** no bob readable. She stays upright with no lean into motion; the cloth does the reacting.
- **Starts and stops:** they look instant, like the others.

### 3. Idle
- She hovers in place, with the hem tails drifting and the casting hand's orb floating (961.0 s, 982.0 s).
- No loop timing is readable.

### 4. Ground dash (Swap)
- **There is no body dash.**
- **Timeline** (0152-0200):
  1. She lobs a star-orb with one arm.
  2. It flies about 1.8 s.
  3. She then **teleports instantly**: the camera jump-cuts (987.4 s).
- **During the lob** she stays roughly in place (985.0-987.2 s: almost no camera motion).
- **Ours** (kitfix): a 1.7 s lob with `ostra_swap` and `ostra_arrive`. That matches.

### 5. Air dash
- Not shown. The Swap is her only mobility.

### 6. Jump and landing
- Not shown. As a hoverer she should have no landing squash beyond a small dip of the hover height.

### 7. Cast and attack body language
- **The smallest body motion of the five.** Casts come from the hand and orb; the body barely shifts.
  - Orbs: one-hand flicks.
  - Snap: a forward push.
  - Swap: an underhand lob.
  - Black Hole: an arm raised.
- **Empowered:** a sphere aura surrounds her, but her body doesn't change pose.

### 8. Build notes
- **Model scale:** body 0.9, with a hover offset of about **0.3 m** on the rig root.
  - Add a slow hover bob: about ±0.03 m at about 0.6 Hz.
  - Drop the legs from the run cycle; the hem trails instead.
- **Collision:**
  - The medium `hit_r` 0.40, kept **at ground level**. The hover is visual only.
  - **Fairness:** the hurtbox stays the full height down to the ground, so the hover never dodges low shots.
  - Show the ring at the real ground point under her.
- **Camera and nameplate:** the shared plate height; the hover puts her head slightly closer to the plate, which is fine. No camera change.
- **KMOVES and locomotion:**
  - `ARCH_STANCE["ostra"]`: knee 0.05, lean 0.0, width 0.05, bounce 0, breath 1.4, arm 0.8.
  - Locomotion: no stride. Run the legs at about 0.1 of the normal stride and let `_cloth` trail.
  - Optionally drop speed to about 4.3-4.5 to match the gliding read.
- **Ground dash:** the kitfix Swap timing (1.7 s, Swollen 1.25 s) matches. Keep `ostra_swap` and `ostra_arrive`.
- **Air dash:** the class long dash. If used, play it as a smooth drift with no tumble, with the hem streaming.
- **Sound:**
  - No footsteps. A soft, low hum or whisper loop while moving.
  - Swap: a hollow "thoom" on the lob and a bright inverted pop on arrival.

### 9. Unclear
- **Hover height:** needs a side-on or low-angle shot. The steep camera only shows the shadow gap.
- **Body motion while gliding:** her aura covers it in 974-975 s. Needs a clean (non-empowered) 2 s run at 60 fps.
- **Air behaviour:** needs a clip of her crossing a ledge or jump pad.
- **Idle loop:** needs a 5 s idle.
