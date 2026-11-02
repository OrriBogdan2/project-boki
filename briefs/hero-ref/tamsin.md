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
