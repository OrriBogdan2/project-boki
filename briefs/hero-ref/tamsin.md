# Tamsin (id `rimewright`): reference sheet for source Celeste

Footage: `/home/claude/svvid/hero/tamsin/frames/`, 5 fps. Frame N is video second 1055 + (N-1)/5. 1 h is about one hunter height (about 50 px).
Ability windows by frame:
- LMB: 0009-0090
- RMB: 0094-0168
- Shift: 0169-0296
- E: 0297-0358
- R: 0361-0392
- Match footage: 0489-0576

## 1. Source summary

| Slot | Ability | Input | Aim type | Cooldown / cost (card) | Effect |
|---|---|---|---|---|---|
| Passive | Shatter (on the LMB card) | - | - | - | Hits add Shatter; at 8 stacks it detonates for area damage |
| LMB | Ice Dart | **hold** | homing darts towards the cursor | 0.56 s (shown at the top right of the card) | A stream of homing darts, 35 each; 8 stacks → Shatter 520-529 |
| RMB | Ice Spear | tap | **lands at the cursor** | 0.3 s on the card (the cooldown is likely charge-based) | A spear makes a slow zone, then detonates after a delay: 584 |
| Shift | Skate | **hold** | your movement direction | 8.3 s, 15 | Skate while held, stop on release; darts get stronger while skating |
| E | Ice Wall | tap | travels towards the cursor | 16.7 s, 30 | A wall that grows, slides, and pushes enemies; blocks shots |
| R | Ice Crash | tap | self | 45.8 s, 50 | Invulnerable, a large slowing dome, then stuns everyone inside |

## 2. Per ability

### LMB: Ice Dart and Shatter (0009-0090)

**Input.** Hold. A continuous stream, about one dart per 0.2 s at 5 fps (possibly faster).
- **No light/heavy pattern or pause is visible.** The darts look the same all the way through.

**Aim.**
- Darts leave towards the cursor side and fly a **curving, homing arc**:
  - 0027-0030: the cursor is up-left and the darts bow out.
  - 0045-0047: the cursor is up-right.
- With the cursor on the dummy they fly nearly straight into it (0060-0066).
- The curves end around the cursor area.
- Range limit not clear.

**Reticle.** A thin white aim line from her to the cursor, like Void's (0045-0047, 0300).

**VFX.**
- Dart: a bright blue-white streak with a glowing head.
- Hit: a red flash on the target and "35" (0063).
- Stacks: the target takes on a growing **blue frost glow** (0066-0067).
- At 8: an icy shell, then a big **burst of cyan ice-crystal spikes** about 1.5 h in radius (0068), and **520-529** (0069).

**Numbers.** Dart 35; Shatter about 15x a dart.

### RMB: Ice Spear (0094-0168)

**Aim.** Lands **at the cursor**:
- 0107-0108: the spear flies to the cursor up-right.
- 0129-0130: at the dummy's feet where the cursor was.

**Spear and slow zone.**
- Spear: a 4-point star head with a long white trail (`distinctive` star tip), fast (crosses about 5 h in ≤0.2 s).
- On landing: a small blue burst and a **slow-zone ring** about 1.2 h in radius with a spinning crystal sparkle in the middle (0132-0139).

**Timing.** The detonation comes **about 1.8-2.0 s after landing** (0098 → 0107, 0130 → 0140).

**Detonation.** A big blue-white flash dome about 1.5 h in radius, **584** (0140).

**After.** The target looks **encased in ice** (bright blue body with a gold ring) for about 3.5 s (0141-0158). At 0160 it is knocked down: a pink-red starburst with an X.

**Numbers.** 584 at detonation. Card: 0.3 s, cost about 15.

### Shift: Skate (0169-0296)

**Input.** Hold to skate in "your direction", release to stop.

**Direction.** Follows the movement input; the cursor is elsewhere (0193-0199).

**Look.** A long trail of blue ice crystals behind her (0193-0197), with a skating lean.

**Speed.** About 1.5x running, estimated from the trail length; the camera follows her, so it cannot be measured exactly.

**Edges.** At 0199 she carries on over the ledge (she does not stop at the edge).

**Firing while skating.** Allowed.
- During a skate the darts become **straight, thick laser-like beams** and hit for **56 instead of 35** (0239-0245, 0285-0290): 1.6x.

**Numbers.** 8.3 s, 15.

### E: Ice Wall (0297-0358)

**Cast.** A purple-white sparkle at her feet for about 0.2 s (0300).

**Spawn.** The ice block erupts **about 1 h in front of her** (0301-0303).

**Travel.**
- It slides along the aim line towards the cursor (0306-0313).
- It **widens from about 1 h to about 2.5 h** as it goes.
- About 6 h in about 2.4 s (2.5 h/s).

**Effects.**
- It pushes and carries the dummy (0313, 0356).
- It blocks an enemy beam with a flash (0334-0335, 0352).
- It disappears after about 3 s (0357).

**Freeze.** No re-press freeze is shown.

**Numbers.** 16.7 s, 30.

### R: Ice Crash (0361-0392)

1. 0363: a blue dome edge expands from her.
2. A huge slowing dome about 4 h in radius for about 3 s. She sits invulnerable at the centre on a crystal star.
3. 0379-0381: a blue-white burst of spikes; the target is frozen (stun), about 6xx damage.

**Dropped in ours**, because R is the Merge.

### Sound
No audio judged.

### Combo / payoff
1. Skate in.
2. Hold LMB, so the darts hit harder.
3. Stack Shatter to 8 for the burst.
4. Spear on a pushed or slowed target for the delayed detonation.
5. The wall shoves foes into position or blocks shots.

## 3. Key frames (`/home/claude/hero-ref/tamsin/`)

| File | Caption |
|---|---|
| 0028.jpg | Darts arcing towards the cursor up-left |
| 0046.jpg | Darts arcing to the up-right cursor; aim line visible |
| 0061.jpg | Darts streaming straight into the dummy |
| 0066.jpg | Shatter stacks: frost glow on the target |
| 0068.jpg | Shatter detonation: cyan crystal spikes |
| 0069.jpg | Shatter number, 520 |
| 0107.jpg | Spear in flight to the cursor (star head) |
| 0108.jpg | First spear detonating; the second just landed |
| 0130.jpg | Spear landing at the dummy's feet |
| 0132.jpg | Slow-zone ring with spinning crystal |
| 0140.jpg | Spear detonation, 584 |
| 0141.jpg | Target encased in ice afterwards |
| 0195.jpg | Skate with the ice-crystal trail |
| 0241.jpg | Firing while skating: straight beams, 56 |
| 0243.jpg | Skate and beam hits on the dummy |
| 0300.jpg | Ice Wall cast sparkle at her feet; aim line |
| 0303.jpg | Wall erupts just ahead of her |
| 0309.jpg | Wall sliding and widening |
| 0313.jpg | Wall reaching and pushing the dummy |
| 0352.jpg | Wall blocking an enemy beam |

## 4. Gaps against ours, ranked by how much they change the feel

Files:
- Kit: `scripts/arch/kits/rimewright_kit.gd`
- Data: `content/archetypes/rimewright.json`
- Weapon: `content/weapons/hoar_fan.json`

1. **LMB fire pattern** (`mechanic`)
   - Ours: a 4-light + 3-heavy flurry (heavy x2 damage, 1.35x speed, 1.4x range), then a 0.5 s pause (`_throw_shard`, `seq_i`).
   - Source: a uniform continuous stream with no pause. Remove the heavy phase and the pause, and fire a steady stream (about 0.15-0.2 s apart).
2. **Homing strength and shape** (`aim`)
   - Ours: soft steering, 2.4 rad/s inside ±40°, flying straight along the aim to 10 m.
   - Source: clearly curved, bowed paths that home on the target near the cursor.
   - In `_tick_darts`: a stronger turn rate (about 6-8 rad/s), a wider acquire cone, and prefer the foe nearest the cursor point.
3. **Shatter payoff size** (`numbers`, `vfx`)
   - Ours: 8 fan hits → Splinter 20 (about 6x a 3.4 shard).
   - Source: 8 stacks → about 15x a dart (529 / 35).
   - Raise `fan_splinter` to about 50.
   - Make the burst a big crystal-spike starburst.
   - Show the stack build-up as a frost glow that grows per stack (ours glitters at 6+ only).
4. **Spear lands at the cursor, with a long delay** (`aim`, `numbers`, `vfx`)
   - Ours: `spawn_shot` flies the full 12 m unless it hits something; a 0.7 s delay; burst 15 versus impact 12.
   - Source:
     - it lands at the cursor (clamped)
     - leaves a visible **slow-zone ring** with a spinning crystal
     - detonates **about 1.8-2 s** later
     - the **detonation is the big hit** (584), and the target is frozen-looking after
   - Fix: target `aim_at(range)`; `delay` 0.7 → about 1.8; shift damage onto `burst_dmg`; draw a lingering ring telegraph.
5. **Ice Wall spawn and growth** (`mechanic`, `vfx`)
   - Ours: spawns 5 m ahead at the full 4.2 m length, slides 3.2 m/s for 4 s, and can be frozen with a recast (8 s).
   - Source:
     - spawns about 1 h ahead, **narrow**
     - widens to about 2.5 h as it slides along the aim line
     - pushes and carries foes
     - lasts about 3 s
   - Fix: in `cast_e`, spawn at `reach` about 1 m with a short length, and grow `a`/`b` in `_tick_wall`.
   - The freeze recast and the ally frost shield are our extensions; keep them, flagged.
6. **Darts while skating** (`numbers`, `vfx`)
   - Ours: x2 damage.
   - Source: x1.6 (35 → 56), and the darts become **straight thick beams** (no homing curve).
   - Change the doubling to 1.6 and skip the homing during a Rinkrun.
7. **Skate over edges** (`mechanic`)
   - Ours: `_tick_rinkrun` stops when `not h.grounded`.
   - Source: she carried on over the ledge (0199).
   - Consider letting the Rinkrun carry on over a gap. This links to the open rank-3 ice-bridge question.
8. **Cooldowns** (`numbers`)
   - Skate: 11 s ours versus 8.3 s.
   - Wall: 20 s versus 16.7 s.
9. **Aim line** (`reticle`): the source shows a thin aim line to the cursor (shared with Void). Ours has none.
10. **Rink Wall cast tell** (`anim`): a 0.2 s sparkle at her feet before the block erupts. Ours `rime_slam` plays at once with the wall.

## 5. Rename
Tamsin is not in the rename list; the archetype JSON is already "Tamsin".

## 6. Open questions

- Dart range: do darts stop at the cursor, or fly on?
- Dart fire rate: 5 fps may hide a faster stream.
- Ice Spear charges (ours 2): the card's 0.3 s may be the cast time; the cooldown and charges are not shown.
- Is the ice-encased look after the spear a freeze or root (crowd control), or just Chill visuals?
- Does the wall stop at the cursor or at a fixed distance? Can it be re-pressed?
- Skate max duration and refund rules.
- The passive name is not shown separately; "Shatter" comes from the LMB card.

## Ultimate (on X)

**Source:** Celeste, Ice Crash. Card: "Become **invulnerable** and create a large slowing zone. Stuns all targets after a delay." 45.8 s, 50 mana. The card shows at **1128–1148 s**, not about 1168 as the task listed; after 1150 s the video moves to unrelated gameplay. Frames are in `/home/claude/svvid/ult/tamsin/` (frame N = 1125 s + (N-1)/10). There are four casts:

| Cast | Start | Stun |
|---|---|---|
| 1 | f25 | f57 |
| 2 | f83 | f117 |
| 3 | f155 | about f187 |
| 4 | f195 | f227 |

1. **Input:**
   - Tap to enter. **Recast ends it early**.
   - Fine print: if recast "late enough" (about 3.2–3.5 s in), it deals the damage and **stuns everyone in the radius**. Line of sight blocks it.
   - Every cast in the video waited the full about 3.2–3.4 s.
2. **Aim / movement:**
   - **Self-centred.** She is encased in an ice crystal and stays **rooted** for the duration.
   - The zone is centred on her and doesn't move.
3. **Reticle / telegraph:**
   - The zone itself: a **translucent blue disc of about 4 bh radius** that snaps out over about 0.2 s (f25→f27), with a ragged, crystalline edge.
   - Cracked-ice lines spread through it and brighten as the timer runs (f35→f55). The brightness is the countdown cue for enemies.
4. **Animation beats:**
   - f25: a **star-shaped ice crystal** forms around her, with spikes radiating out. She is invulnerable inside it.
   - f27–f55 (about 3 s): the hold. The zone slows enemies, with stacking slow, and the crack network glows brighter.
   - f57: the crash. A **blue light pillar** comes down, an ice block encases each enemy in range (the dummy shows **607** and an ice-block stun), and her crystal **shatters into a radial burst of blue shards** about 2 bh (f57–f59).
   - f61: recovery. The zone is gone and she is free.
5. **VFX:**
   - A blue zone with crack lines, a star crystal shell, a shard burst on release and ice blocks on stunned targets.
   - The 8-point crystal "snowflake star" shell is `distinctive`.
   - Ours (Tamsin) should use its own frost-shell shape.
6. **Sound:** none. It suggests a crackling freeze on cast, creaking ice during the hold and a glassy shatter-boom on release.
7. **Numbers:**
   - **607** on release (f57).
   - Fine print: 120 + 125% plus a stun for everything in the radius, and the **slow stacks for up to 3.5 s**.
   - The stun duration wasn't legible (the dummy stayed encased about 0.5 s).
8. **Ends / combo:**
   - It ends on the timer or on a recast.
   - Combo: Ice Wall pushes enemies into the zone (or traps them inside it), then the crash stun into a Glacial or LMB burst.
   - It doubles as a full-invulnerability panic button: an early recast gives a short invulnerability without the stun.
   - Allies: unaffected; no ally buff is mentioned.

**Key frames:** `tamsin/ult_0023.jpg` (before), `ult_0025.jpg` (crystal shell, zone snaps out), `ult_0027.jpg` (full zone), `ult_0035.jpg` (cracks spreading), `ult_0053.jpg` (bright pre-crash), `ult_0057.jpg` (crash: pillar, 607), `ult_0058.jpg` (shard burst), `ult_0059.jpg` (shards, ice-block target), `ult_0061.jpg` (recovery), `ult_0110.jpg` (second cast, mid-hold).

**Build notes:**
- **What to build:** X = rooted and invulnerable inside a frost shell, with a 4 bh stacking-slow zone. Recast any time to end it. At 3.2 s or later (or automatically at 3.5 s) it releases damage and a stun in the radius, with line of sight checked.
- **Bond:** each hunter stunned by the release adds 0.4, capped at **0.8**. An early-cancelled (defensive) use gives 0, so the meter only pays for holding your nerve.

## Body, scale and movement feel

The method and yardsticks match `linwick.md` (same camera zoom; 50 px ≈ 1 m; a medium is about 90 px head to foot; the nameplate sits about 110 px above the ground point for everyone). Frame N = (t - 1055) x 5 + 1.

### 1. Height and bulk
- **Height:** about **110-120 px** head to toe (1073.0 s / 0091, 1074.2 s / 0097, 3x grid crops). Her head sits just under the plate. That is about **1.2x a medium**; the skating lean inflates the number slightly, so take **1.15** as the true height ratio.
- **Width:** only about 25-30 px across the torso, against a medium's 55-60 px. That is **about half the breadth**: long legs, a narrow body, and the arms often held out to the sides (about 90-100 px fingertip to fingertip).
- **Ours:** light, 0.9 x 0.95 = **0.855** of a medium. That is too short.
- **Target:** **1.1-1.15** in height with a slim build (race/build bulk about 0.75), so she reads tall and thin.

### 2. Locomotion
- **Run speed:** a steady **240 px/s ≈ 4.8 m/s** for 3 s (1105.4-1108.4 s / 0253-0268). She is the fastest of the five on foot. Ours (light) is 5.0, which is fine.
- **Gait** (60 fps, 1095.2-1095.9 s / 0202-0205):
  - Long, wide skater's strides: the legs split far apart, then close.
  - A wide split comes about every **0.17 s**. At this size I could not tell left from right, so a full two-leg cycle is 0.17 or 0.34 s.
  - The body leans forward and the arms are held out for balance. A long ribbon or scarf streams behind.
- **Bob:** none readable; she glides more than she bounces.
- **Stopping and turning:** she turns to face a new direction in about 0.1 s (1095.75-1095.9 s), stepping round rather than spinning.

### 3. Idle
- A skater's stance: one leg back, arms out, a slight forward lean, facing the aim (1073-1074 s).
- No loop timing is readable in the short still windows.

### 4. Ground dash (Skate, held)
- **Speed:** **450-600 px/s ≈ 10-11 m/s**, about **2.2x her run**.
  - 1102.0-1104.0 s / 0236-0246, about 1.8 s.
  - 1111.2-1112.8 s / 0282-0290, about 1.6 s.
  - The earlier 1093.2-1094.5 s run reads lower (about 335 px/s), because the ice trail confused the pan.
- **Curve:** full speed within about **0.2 s** (the pan goes 124 → 479 px/s in one 0.2 s step), a flat cruise, then a stop on release within about 0.1-0.2 s.
- **Pose:** low and leaning forward, arms out, legs in long push strides. She turns to face the cursor and fires while skating (0239-0245).
- **Trail:** a long, thick ribbon of blue ice crystals along the whole path, several bh long.
- **Edges:** she carries straight on over ledge edges.
- **Ours:**
  - main: 11.5 m/s for 1.6 s, which matches the source.
  - kitfix: **8 m/s for 2.4 s**. That is too slow, and it lasts longer than the longest skate seen (about 2 s).

### 5. Air dash
- Not shown. The skate carries over ledges but no airborne dash is used.
- Ours uses the class long dash with `tm_dash_air` (a tumbling side flip). That is our own addition and has no source behind it.

### 6. Jump and landing
- Not shown.

### 7. Cast and attack body language
- **Light and flowing:** casts happen while moving, with the arms doing the work.
  - Darts: thrown from the hands while walking or skating.
  - Spear: a full overhand throw.
  - Wall: both hands pushed forward.
- **Squash:** little. The motion is mostly extension: arms out, long legs.

### 8. Build notes
- **Model scale:** height **1.1-1.15**, build bulk **0.75**, long-legged (leg length about 1.15x).
- **Collision:**
  - Keep the light `hit_r` 0.35. From the top-down camera she looks about 0.5-0.6 m across the body, so this is honest.
  - **Fairness:** the extra height adds nothing to her top-down target, so don't raise `hit_r` because of it. Do check that her nameplate and shadow don't make her look bigger than she is.
- **Camera and nameplate:**
  - Plate at the shared height. Her head will sit right under it, as in the source.
  - No camera change.
- **KMOVES and locomotion:**
  - `ARCH_STANCE["rimewright"]`: knee 0.22, lean 0.14, width 0.1, bounce 0.4 (less springy than now), breath 2.4, arm 1.25 (arms held out).
  - Cadence about 1.4x with stride about 0.85 (long splits).
  - Arms out to the sides while running, not swinging.
- **Ground dash curve and pose:**
  - `speed` 10.5-11, `max_t` 1.6-1.8.
  - Ramp: speed ramps to full within 0.2 s.
  - Stop: within 0.15 s on release.
  - Pose: `tm_skate` already pushes every 0.28 s, which matches the look; keep it.
  - `tm_skate_go` (0.16 s push-off) and `tm_skate_stop` (hockey stop) are good.
- **Air dash:** the class long dash. If there is no source evidence, prefer the stretched skate glide pose over the tumbling flip, so she stays in character.
- **Sound:**
  - Footsteps: soft, quick steps with a blade tick.
  - Skate: a continuous blade hiss and scrape that rises in pitch over the first 0.2 s, with crackling ice along the trail and a hard scrape for the stop.

### 9. Unclear
- **Left/right step timing:** needs a 60 fps side-on clip of her running 2 s.
- **Air dash:** needs a clip of Skate off a ledge, or a dash in the air.
- **Idle loop:** needs a 5 s close idle.
- **Jump and landing:** not in this video; any match clip with a jump pad would settle it.
