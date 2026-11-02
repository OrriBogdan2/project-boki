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
