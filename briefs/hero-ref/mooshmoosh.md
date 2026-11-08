# Moosh Moosh (`tender`): reference sheet (source: Elluna)

Footage: `/home/claude/svvid/hero/mooshmoosh/frames`, 5 fps, video 700-760 s, so frame N = second 700 + (N-1)/5. The video has no audio.
Our code was read at origin/main **4f82978** (descendant of 7881774; no tender changes in between).
Scale: the hunter is about 55 px tall (1 bh = 1 body height).

The kit matches docs/heroes/tender.md slot for slot:

| Source | Ours |
|---|---|
| Backpack | Bearer |
| Moon Shot | Lantern Crook |
| Bound by Fate | Burrseed |
| (Super) Lighter Than Air | Relay Step |
| Rejuvenating Aura | Hearthlight |
| Divine Intervention | dropped; its revive is folded into Hearthlight rank 3 |

The end summary (`0292`) shows that player's own keybinds; the default layout is used below.

## 1. Source summary

| Slot | Ability | Input | Aim type | Cooldown (card) | Cost | Effect |
|---|---|---|---|---|---|---|
| Passive | Backpack | walk over | none | none | none | Walk over ally wisps to pick up and carry them |
| LMB | Moon Shot | hold / tap (auto-repeat) | skillshot, **flies to max range past the cursor** | 0.4 s | none (restores mana) | Mana-restoring shots with ramping damage; after a short pause the next shot is Empowered |
| RMB | Bound by Fate | tap (aim telegraph while held) | skillshot lane to max range | ≈7.1-7.3 s (card blurry) | 40 | Shot that, after a delay, roots and damages in an area |
| L Shift | Lighter Than Air / Super Lighter Than Air | tap | movement direction | 9.2 s (Super) | 35 | Base: short dash, further in the air. Super: long dash; through an ally refunds half its cooldown and 1 s of E |
| E | Rejuvenating Aura | tap, then recast | self, then thrown **to the cursor** | 10 s | 45 | Healing zone on you; reactivate to throw it |
| R | Divine Intervention | tap (channel) | target an ally in a big radius | 41.6 s | 50 | Channel a heal on an ally; teleports them to you at the end if they're knocked; can resurrect wisps |

## 2. Per ability

### Passive: Backpack (`0292`)
- The card says "Walk over ally wisps to carry them away."
- It isn't demonstrated: frames 11-50 show only movement and a dash.
- Ours (Bearer) already does this. Nothing to measure.

### LMB: Moon Shot (`0057`, `0074`, `0084`, `0094`, `0098`)
1. **Input:**
   - Hold to fire repeatedly. Shots come every 2-3 frames (0.4-0.6 s); the card says 0.4 s.
   - The hunter keeps walking while firing.
2. **Aim:**
   - Skillshot toward the cursor.
   - The bolt **does not stop at the cursor**. In `0057` it is already past the cursor ring and keeps going to max range (about 7-8 bh).
   - The hunter turns to the cursor.
3. **Reticle:**
   - Cursor ring, plus one thin white line from the hunter to the cursor.
   - No range or ramp indicator on the HUD that can be seen.
4. **Anim:**
   - A one-handed flick toward the target.
   - On each shot, a **thin white circle swirl appears around the hunter's casting hand and upper body** for 1 frame (`0074`, f60, f63).
5. **VFX:**
   - The bolt: a blue-white glowing comet head, about 0.3 bh, with a soft blue trail about 1 bh. It moves about 3-4 bh per frame, so it is fast.
   - On hit: a small blue-violet flash on the target.
   - The target gets a faint violet glow at its feet as the ramp builds (f84-98).
   - Damage numbers turn from white to yellow as the ramp grows (`0094`, `0098`).
6. **Sound:** n/a.
7. **Numbers:** consecutive hits on one dummy read **64, 66, 84, 93, 93**. That's about +45% over 4-5 hits, then it plateaus.
8. **Combo:** the card says "After not firing for a brief time, your next shot is Empowered" (`0292`). Ours has this as the idle-crook ember.

### RMB: Bound by Fate (`0106`, `0109`, `0110`, `0123`, `0126`, `0130`)
1. **Input:**
   - Hold to aim with a telegraph, release to fire.
   - In the second demo the telegraph is up about 1 s before the shot (f116-120).
2. **Aim:**
   - Skillshot along a fixed lane to **max range** (about 8-9 bh). The lane runs past the cursor (`0106`).
   - The first enemy hit gets the effect. A miss travels the whole lane and does nothing visible (f110-115).
3. **Reticle:**
   - A **translucent white rectangle lane**, about 0.4 bh wide and about 20% opacity, with small dots spaced along its centre.
   - It runs from the hunter to max range and is shown while aiming (`0106`, f116-120).
4. **Anim:**
   - A cast flick.
   - The cast frame has a **large bright blue-white flare around the hunter**, about 1.5 bh (`0109`).
5. **VFX** (the crescent-moon motif is `distinctive`):
   - Projectile: a blue comet orb like Moon Shot but bigger. About 4 bh in 1 frame (f121-122).
   - On hit (`0123`): a **purple-blue disc about 1.2 bh in radius** under the target, with a violet rim, and a soft purple light column falling over the target.
   - About 0.6 s later (`0126`, f126) the disc flares larger (about 1.8 bh) and brighter, and the target is hit and rooted.
   - The root shows as a smaller disc plus a purple beam over the target (`0130`, f128-131), lasting about 1 s or more.
6. **Sound:** n/a.
7. **Numbers:** cooldown about 7.1-7.3 s, 40 mana.
8. **Combo:** root, then follow up with Moon Shot ramp hits.

### L Shift: Lighter Than Air / Super Lighter Than Air (`0157`)
- **Input:** tap.
- **Direction:** the dash goes in the **movement direction**, not toward the cursor. Card: "Long dash in your direction". In f155-158 the cursor is far left and the dash goes along the movement.
- **Distance:** about 3-4 bh in ≤0.2 s.
- **VFX:** the same **red burst left at the start point**, with an ember scorch about 1 s (`0157`, f181). This looks like the shared hunter dash effect; Dredge's dash shows it too.
- **Ally pass:** the Super version, through an ally, refunds half its cooldown and 1 s of E. Ours already does this.
- **Numbers:** Super is 9.2 s, 35 mana.

### E: Rejuvenating Aura (`0196`, `0204`, `0205`, `0216`, `0218`)
1. **Input:** tap to summon on yourself. Tap again to throw.
2. **Aim:**
   - The zone first **follows the hunter** (f201-203 move with her).
   - The recast throws it **to the cursor**. It lands centred on the cursor ring (`0205`, `0218`), within about 1 frame, so it's near-instant.
3. **Reticle:**
   - No extra telegraph; the zone ring itself is the indicator.
   - While it's on her, the cursor line runs from the hunter to the cursor.
4. **Anim:** a raised casting hand on the summon (`0196`, `0216`).
5. **VFX:**
   - **Summon:** a large bright **green plus-shaped glowing orb** at the hunter, about 1 bh, for 1-2 frames. Green vertical light streaks rise around her (`0196`, `0216`).
   - **Zone:** a soft pink-white rim ring about **1.3-1.5 bh in radius**, a faint blue interior, and drifting sparkles.
   - **Thrown:** it turns into a **bright cyan-blue disc**, about 1.6 bh in radius, with a white rim (`0205`, `0218`). It fades over about 1.5-2 s.
   - No heal numbers were shown (nobody was hurt).
6. **Sound:** n/a.
7. **Numbers:** cooldown 10 s, 45 mana.
8. **Combo:** the ally dash refunds 1 s of this.

### R: Divine Intervention (`0255`, `0279`)
- Tap to channel on an ally.
- A **large gold range circle** around the hunter (about 8 bh radius).
- A **pink-gold tether beam** from the hunter to the ally, with green plus sparkles on the ally, for about 2.4 s (f249-271).
- At the end a green burst plays and the ally appears **next to the hunter** (`0279`): the teleport.
- Cooldown 41.6 s, 50 mana.
- The summary adds "Can be used on ally Wisps to Resurrect them."
- Our R is the Merge, and the doc folds the revive into the Hearthlight rank 3 flare.

## 3. Key frames (`/home/claude/hero-ref/mooshmoosh/`)

| File | Caption |
|---|---|
| 0057.jpg | Moon Shot bolt past the cursor (flies to max range) |
| 0074.jpg | Shot cast: white swirl ring at the hunter, blue comet bolt |
| 0084.jpg | First ramp hit: 64 |
| 0094.jpg | Ramp: 84, violet glow on the target |
| 0098.jpg | Ramp: 93 (yellow), hit flash |
| 0106.jpg | Bound by Fate lane telegraph to max range |
| 0109.jpg | Bound by Fate cast flare at the hunter |
| 0110.jpg | Bound by Fate orb in flight |
| 0123.jpg | On hit: purple disc plus light column (the delay) |
| 0126.jpg | About 0.6 s later: disc flares, root |
| 0130.jpg | Rooted: small disc plus purple beam |
| 0157.jpg | Dash: red burst at the start point |
| 0196.jpg | Aura summon: green plus orb, rising rays, ring |
| 0204.jpg | Aura recast: thrown |
| 0205.jpg | Thrown aura lands as a cyan disc |
| 0216.jpg | Second summon (close-up of the plus burst) |
| 0218.jpg | Thrown disc centred on the cursor |
| 0255.jpg | Divine Intervention: gold range circle plus tether to an ally |
| 0279.jpg | Ally teleported beside the hunter at the end |
| 0292.jpg | Kit summary screen |

## 4. Gaps against ours, ranked by how much they change the feel

1. **[mechanic] The Burrseed delay and speed are much slower than the source.**
   - Source: a fast orb (about 20 bh/s). On hit, a disc marks the area at once and roots about **0.6 s** later (`0123` to `0126`).
   - Ours: a slow seed (`rmb.seed.speed` 12 m/s), then a **2.0 s** wait (`seed.delay`).
   - Change `tender.json` `rmb.seed`: `speed` ≈ 30, `delay` ≈ 0.6-0.8.
   - Rescale `burst_dmg` if the shorter window makes it too reliable.
2. **[reticle] The Burrseed has no aim telegraph.**
   - Source: a translucent white lane with dots, about 0.4 bh wide, out to max range, shown while aiming (`0106`).
   - Ours: none. `fire_rmb` fires on press (`hold` 0).
   - Show a `tele_lane` from the hunter along `aim_dir()` with length `seed.range` and width `hit_r*2`. It needs a short hold, or a show-on-press, fire-on-release flow (`rmb_hold_tick`).
3. **[vfx] The Burrseed doesn't show its area during the delay.**
   - Source: as soon as it lands, a purple disc the size of the burst radius sits under the target, with a light column. It flares at the trigger (`0123`-`0130`).
   - Ours: a small glowing sphere on the foe and a 0.9 m ring pulse every 0.5 s (`_stick`, `_tick_burrs`).
   - Draw a ring at `burst_r` under the stuck foe that fills toward the trigger (`m.fx.telegraph_progress`). Then a big flare plus a root beam on burst (`_burst`).
4. **[aim/mechanic] The Hearthlight toss should land at the cursor, near-instantly.**
   - Source: the recast puts the zone on the cursor point in about 1 frame (`0205`, `0218`). No latching was seen.
   - Ours: it flies at `toss_speed` 18 (0.5 s for 9 m) and latches onto the first teammate it passes (`e_recast`, `_tick_hearth`).
   - Raise `toss_speed` to about 45, or set it at the cursor after 0.1 s. Keep the latch only when the cursor is on a teammate (owner call; latching is our extension).
5. **[numbers] The Hearthlight radius looks large next to the source.**
   - Source ring: about 1.3-1.5 bh radius on her; the thrown disc about 1.6 bh.
   - Ours: `e.radius` 3.5 m.
   - Check the bh-to-m scale (hunter height in metres) before changing. If a hunter is about 1.8 m tall, the source is about 2.5-2.9 m.
6. **[vfx] Hearthlight cast and thrown look.**
   - Source cast: a big green glowing **plus** orb plus rising green rays.
   - Source thrown: a bright cyan disc with a white rim (`0196`, `0205`).
   - Ours: a lamp sphere plus a ring and the word "HEARTHLIGHT" (`cast_e`, `_hearth_node`).
   - Keep our lantern art, but add a 0.3 s cast burst (rising rays) and give the thrown state a filled, brighter disc than the carried ring. The plus symbol is generic heal language and fine to use.
7. **[numbers] Cooldowns.**
   - Bound by Fate ≈7.1-7.3 s vs ours `rmb.cooldown` 10.
   - Aura 10 s vs ours `e.cooldown` 11 (close).
   - Super dash 9.2 s vs ours `dash.cd` 7.5.
   - Suggest Burrseed about 8 s, and leave the others.
8. **[anim/vfx] Crook cast swirl.**
   - Source: each shot draws a thin white ring swirl around the casting hand for 1 frame (`0074`).
   - Ours: no per-shot cast mark for the Lantern Crook (the weapon's default).
   - Add a small ring flash at the crook head in the weapon fire FX, or as a tender `on_fire` hook.
9. **[vfx] Ramp readability.**
   - Source: numbers shift white to yellow as the ramp grows, and the target gets a violet foot glow (`0094`, `0098`).
   - Ours: ember sparks per Kindle stack (`tells.half`) and "KINDLED" at 5.
   - Optionally tint damage numbers by Kindle stacks (warm yellow at 3+).
10. **[mechanic] Dash direction.**
    - Source: the long dash goes in the movement direction.
    - Ours: `on_dash` uses `h.roll_dir` (movement) when set. This now matches, and the new "Dash toward the cursor" setting covers the other preference. No change.
11. **[sfx]** No audio in the footage.

## 5. Rename (Linnet to Moosh Moosh), every place the old display name appears
- **Player-facing:**
  - `content/archetypes/tender.json:3` (`"name": "Linnet"`). This feeds the hero picker, kit card and wiki.
  - `scripts/match/hero_kit.gd:22` (`"tender": {"name": "Linnet", ...}`).
  - Wiki output of `tools/gen_wiki.py` (regenerate after the json change):
    - `docs/wiki/Class-Linnet.md` (rename the file and its links)
    - `docs/wiki/Classes.md` (3 places: lines 8, 62, 74)
    - `docs/wiki/Weapons.md:17` (Lantern Crook owner)
    - `docs/wiki/_Sidebar.md:13`
- **Sound tool labels:** `tools/gen_care_sfx.py:5` and `:53` ("Linnet's ... sounds"). The comments name the sound set; the files themselves are `tend_*`.
- **Tester-facing check text:** `tools/support_check.gd:2`.
- **Comments and docs only:**
  - `scripts/arch/kits/tender_kit.gd:3`
  - `scripts/arch/kits/care_util.gd:3`
  - `scripts/match/hero_gear_care.gd:3`, `:24`
  - `scripts/match/hunter_anim.gd:1219`
  - `docs/ARCHETYPES.md:1204` (Inspired-by row)
  - `docs/heroes/tender.md:1`
- The role word "Tender" stays (`"role": "Tender"`).

## 6. Open questions
- **Bound by Fate:** does the area stick to the target and move with it, or stay on the ground where it hit? The dummy doesn't move. Also the root duration exactly, and the damage.
- **Rejuvenating Aura:** heal amounts and tick rate; whether it lasts the same when thrown; the max throw range. No hurt allies were shown.
- The ramp: how many stacks, how long it lasts, and whether it decays per target.
- The Empowered idle shot: the pause length and its bonus (range? damage?). Not isolated in the clip.
- **Backpack:** carry speed, the shield, and drop rules. Not shown.
- Divine Intervention teleported a standing ally (`0279`), though the card says "if they're knocked". The dummy's state is unclear.

## Ultimate (on X)

**Source:** Elluna, Divine Intervention. Card: "Channel a heal on an ally, teleporting them to you at the end if they're knocked", 41.6 s, 50 mana. Frames are in `/home/claude/svvid/ult/mooshmoosh/` (frame N = 747 s + (N-1)/10). Cast at f25, end at f74.

1. **Input:**
   - Tap with the cursor over an ally. This is unit-targeted, so you need an ally (or an ally's wisp) under the cursor; f19–f24 show the aim line onto the ally.
   - Then a **channel of about 5 s** (f25→f74).
2. **Aim / movement:**
   - Ally-targeted.
   - **Elluna can walk during the channel**. She moves several bh in f41–f72, and the tether follows.
   - A **large gold ring about 7 bh in radius** centred on her marks the tether range. It probably breaks if the ally leaves it; the video doesn't test this.
3. **Reticle / telegraph:**
   - Targeting: the usual line to the cursor.
   - Channel:
     - a **pink-white light beam** tether from her to the ally;
     - a small white ring under each of them;
     - the gold range ring;
     - green "+" sparkles rising off the ally.
4. **Animation beats:**
   - f25: a green plus-burst on the ally.
   - f26–f73: she holds a channel pose with one raised hand and walks normally.
   - f74–f75: the end. A **green burst at Elluna's side** and the ally reappears there (teleported).
   - f77: both stand together, and the green sparkle fades. Recovery is instant.
5. **VFX:** the tether beam, the range ring, the heal sparkles and the green arrival burst. A healing tether is generic; the crescent-moon motif elsewhere in her kit is the distinctive part, so avoid it.
6. **Sound:** none. It suggests a soft choir or hum during the channel and a chime and whoosh on the teleport.
7. **Numbers:**
   - Card: 41.6 s and 50 mana.
   - Fine print (thebackdash): heals the ally or allied **Wisp** for 44 + 11.2% **per second for 5 s**. **Wisps are resurrected and teleported to you.**
   - The heal-tick numbers weren't legible in the frames.
8. **Ends / combo:**
   - It ends at 5 s, with the teleport if the ally is knocked or a wisp.
   - Combo: a save button. Tether a diving or knocked teammate, walk away from danger, and they arrive at your side healed.
   - Pairs with Rejuvenating Aura thrown on the arrival spot.

**Fine print not found:** whether damage interrupts the channel, whether there's a break range, and whether enemies can stop the teleport.

**Key frames:** `mooshmoosh/ult_0019.jpg` (target line onto an ally), `ult_0025.jpg` (cast: green burst, tether), `ult_0028.jpg` (range ring appears), `ult_0041.jpg` (walking while channelling), `ult_0060.jpg` (mid-channel), `ult_0072.jpg` (late channel), `ult_0074.jpg` (end: arrival burst), `ult_0075.jpg` (ally teleported beside her), `ult_0077.jpg` (after).

**Build notes:**
- **What to build:** X on an ally (or a downed ally or their wisp): a 5 s heal tether that lets her move, with a range of about 7 bh. At the end a downed ally is teleported to her and revived, or a wisp is resurrected.
- **Bond:** a support ult can't "land" on enemies. Pay **0.6** on a completed channel, and **0.8** if it rescued a downed ally or wisp. The ally's own bond meter could get +0.2 too.

## Body, scale and movement feel

This section covers the source's **motion and scale only**, never its look. Method:
- 10 fps full-resolution frames of 700-760 s, and 30 fps crops for the walk (729.3-730.5 s), the air dash (730.7-732.4 s) and the LMB casts (716.3-717.6 s).
- Times are video seconds. `f` numbers are the 5 fps frames above (f = (s − 700) × 5 + 1).
- Every pixel figure is at 1920×1080. The nameplate bar is 106-107 px wide in every clip measured (Elluna, Shiv, Myth, Joule, Celeste, Oath), so all these clips share one camera zoom. The editor zooms in only in a few spots (around 727.6-729 s and 722 s); those spots were not used for scale.
- Speeds come from tracking the hunter's nameplate on screen and the camera pan (optical flow on the background, with the hunter masked out). That gives her ground position in screen pixels.
- **1 medium bh ≈ 95 px ≈ 1.8 m.** This fits the 1.8 m/bh that venator.md and linwick.md use. The check: her walk comes out at 4.7 m/s against our medium's 4.8.

Saved sheets in `/home/claude/hero-ref/mooshmoosh/`:
- `body_scale_vs_heavy_m566.png`
- `body_footprint_arcs.png` (Myth, Joule, Shiv, Elluna)
- `body_walk_30fps_729.3s.jpg`
- `body_airdash_30fps_730.7s.jpg`
- `body_lmb_cast_30fps_716.3s.jpg`
- `body_rmb_cast_m210-225.jpg`
- `body_idle_m560-580.jpg`

### 1. Relative height

| Hunter (same zoom) | Crown to soles | Notes |
|---|---|---|
| **Elluna** standing (756.1-756.5 s, f281-283) | **≈67 px** (≈82 px to the ear tips) | Same frame as the heavy ally below |
| Elluna in her usual crouched ready or casting pose (726.7 s, f134; 716-718 s) | 45-60 px | Low, hunched, knees bent |
| Oath-type heavy ally "Kimic" (same frame) | ≈125 px | |
| Shiv (291 s), Myth (604 s) | ≈95 px | Typical mediums |
| Joule (22 s), Celeste (1079 s) | ≈70-72 px | The small-framed mediums |

- **The source is ≈0.70 of a medium's height** (67/95) standing up, ≈0.86 counting the ears, and ≈0.54 of the heavy in the same frame.
- In her normal crouched stance she reads at **≈0.5-0.6 of a medium**. That posture is a large part of why she "feels tiny".
- **Footprint:** her white facing-arc (the ring under the feet) has a radius of ≈21 px. Mediums are ≈25-28 px and the heavy ≈35 px. So her footprint is **≈0.8 of a medium**: smaller, but less so than her height.
- **Ours now:** `tender` is `"weight": "medium"`.
  - `Models.hunter` sets `root.scale = CLASSES.medium.scale (1.0) × CLASS_LOOK.medium.size (1.0) × race scale` (0.8-1.17 from the player's look). That is **1.0 of a medium** for a Human look.
  - On top of that, the archetype's silhouette is "the tall pack-frame with its lantern above the head". That brings the visual top to roughly **1.1-1.2 of a medium**.
  - `hit_r` is 0.40 (medium).
  - So today she is at least as big as any medium, about 1.5× the source's ratio.
- **Target: model scale ≈0.74 of a medium**, with the top of any headgear, ears or pack at most ≈0.85 of a medium's height.

### 2. Locomotion

1. **Ground speed: the same as everyone.**
   - Sustained walking camera pan, as the median of runs of 5 or more frames:
     - Elluna 25 px per 0.1 s (individual runs 22.5-26.6)
     - Shiv 26.6
     - Oath 26.8
   - Elluna is ≈0.93-0.95 of them, which is within measurement noise. That is ≈250 px/s ≈ 2.6 medium bh/s ≈ **4.7 m/s**.
   - Because she is 0.7 the size, she covers **≈3.6 of her own heights per second** against a medium's 2.6. That reads as a quick scurry without being faster.
2. **Cadence** (30 fps, 729.3-730.5 s, f147-153; low confidence, because the top-down view hides the feet):
   - The foot glows and the body centroid repeat every ≈17 frames, ≈0.57 s per stride. That is **≈3.5 steps/s**, with a stride of ≈0.7 m ≈ 0.55 of her own height: short, quick steps.
   - Ours: `ph += dt·spd·2.15` gives 3.3 steps/s at 4.8 m/s, on full-size legs.
3. **Vertical bob:** small, about ±4-5 px (±5-7% of her height), peaking once per stride (≈1.75 Hz). There is no bouncy hop-walk.
   - The visible "life" comes from **secondary motion**: a long trailing appendage (ears and braid on the source) swings ±30-45° at the stride rate, lagging the body by ≈0.1 s.
4. **Lean and pose:**
   - She walks low and crouched, with the torso pitched well forward (≈25-35°) and the arms held out from the sides for balance.
   - She strafes and backpedals freely: the torso keeps facing the cursor while the legs go the way she moves. In the walk sample she moves right while aiming left.
5. **Acceleration and stopping:** both are snappy, with no slide.
   - Start: the camera pan goes from 1 to 16 to 24 px per 0.1 s (729.2-729.4 s), so full speed in ≤0.2 s.
   - Stop: 24, 15, 4, 0 (730.4-730.7 s), so ≈0.2 s. The camera's follow lag is included in these, so the true figures are a little shorter.
6. **Float or hover:**
   - **On the ground she does not hover.** The ring sits under her feet and the shadow touches her.
   - **In the air she is floaty.**
     - A jump lifts her ≈0.5 of her own height in ≈0.2 s.
     - During the air dash she holds ≈0.6-0.7 of her own height (60-70 px) above her ground marker for ≈0.6 s, barely sinking, then drops in the last ≈0.15 s (730.9-731.9 s).
     - After the ult (754.4-755.2 s) she hops and hangs ≈0.5 s before touching down.

### 3. Idle

The clip never leaves her alone for more than about 2 s, so no long fidget loop is visible.

Two idles were seen:
- **(a) Open-arms hold** (756-758 s, f281-290, 1.9 s):
  - Both arms out wide, palms open and fingers spread, feet planted.
  - The body is still to within 1-2 px.
  - The trailing appendage sways like a slow pendulum, **period ≈1.2 s**, about ±20°.
- **(b) Compact crouch** (725.7-727.5 s, f129-138):
  - She is balled up low.
  - Small torso turns of ≈15-20° every ≈0.5 s.
  - The appendage flicks with each turn.

### 4. Hop and dash

- **The ground dash is never shown cleanly.** Every dash in the clip comes 0.1-0.3 s after a jump: her ground marker separates from her before the burst. This happens at 706.8 s (f35), 731.1 s (f157), 735.9 s (f181) and 745.1 s (f227).
  - The card says the base dash is a "short dash, further in the air".
  - For reference, other hunters' ground dashes measure about 1.5-2.5 bh in ≈0.2 s, staying on the ground (dancer.md, linwick.md).
- **The air dash is her signature.** Per-0.1 s ground travel from tracking:

| Dash | Displacement per 0.1 s (px) | Total | Lands |
|---|---|---|---|
| 731.1 s | 28, 94, 97, 81, 99, 82, 63, 67, 62, 59, 44, 15 | ≈790 px ≈ 8.3 bh ≈ 15 m | 1.1 s |
| 706.8 s | 70, 104, 96, 107, 90, 94, 83, 74, 72, 59, 50, 42 | ≈940 px (runs into a glide off a ledge) | — |
| 735.9 s (through an ally) | 49, 97, 108, 106, 103, 44, 34, 42, 31 | ≈610 px ≈ 6.4 bh | ≈0.9 s |
| 745.1 s (through an ally) | 39, 113, 124, 87, 119, 68, 81, 44, 22 | ≈700 px ≈ 7.4 bh | 0.8 s |

- **Speed curve:**
  - A **0.1 s ramp**.
  - A **flat burst at ≈1000-1200 px/s (≈10-12 bh/s ≈ 19-22 m/s) for 0.4-0.6 s**.
  - A **float-out at ≈40-65% of that speed for 0.2-0.5 s**.
  - A **dead stop on touchdown**.
  - In total **≈6-8 bh (≈11-15 m) over 0.8-1.1 s**. That is 3-4 times the distance and about 5 times the duration of a normal hunter dash.
- **Shape:** it is flat, not an arc. She is already up from the jump and keeps her height through the burst, then sinks slowly.
- **Pose beats** (30 fps sheet):
  1. **Takeoff** (0-0.07 s): a small crouch, then up. The jump comes first.
  2. **Streak** (0.07-0.25 s): the body goes horizontal, head first, with the arms reaching forward, the legs trailing and the body long and stretched.
  3. **Float** (0.25-0.8 s): she curls into a seated, knees-tucked float, arms out to the sides, drifting forward. It looks like being carried rather than flying.
  4. **Touchdown** (≈0.1 s): the ring returns. There is almost no squash, and she walks straight out of it with the arms still raised.
- **How it compares:**
  - To her own (unseen) ground dash: by the card, shorter.
  - To other hunters: theirs are grounded, short and snappy. Hers is an airborne glide that stays in the air.
  - **To ours:**
    - Relay Step on the ground is 4.2 m in 0.16 s.
    - The air dash uses the class `ex_dist` 4.6 m in 0.2 s.
    - `mm_dash_air` is a tucked forward roll, 0.42 s.
    - Ours is roughly a third of the source's length and a fifth of its duration, and the roll reads as acrobatic rather than floaty.

### 5. Cast and attack body language

**She carries no weapon in the source.** Everything comes out of her hands.

1. **LMB** (716.3-717.6 s, f84-91):
   - She plants a wide, low stance. Shots in this clip come every ≈0.55 s (the card says 0.4 s).
   - Each shot:
     - **Wind (≈0.07 s):** the casting hand pulls back toward the hip, and the torso twists away ≈30°.
     - **Release (0.03-0.07 s):** a **straight-arm, punch-like push** with the hand open or glowing toward the target. The torso unwinds 45-60°, the appendage whips, and the cast swirl flashes around her upper body.
     - **Hold:** the arm stays extended ≈0.1 s.
     - **Recover (≈0.2-0.3 s):** the other hand rises open-palmed, a flourish, and the next shot comes from the other side.
   - The torso yaw swings ±45° from shot to shot. The stance drops ≈5% on the push.
   - Squash and stretch are slight. The life comes from big rotation and the alternating arms, not from scaling.
2. **RMB aim and release** (720.9-722.4 s, f105-113):
   - **Aim:** side-on, with the casting fist pointed down the lane, held steady.
   - **Release:** a **small hop**, ≈0.5 of her own height and ≈0.3 s in the air, with a forward push of both arms. The flare sits on her during the hop.
3. **E summon** (738.9 s, f195): both arms straight up overhead, ≈0.3 s, then down.
4. **R channel:** one hand raised while she walks normally (see Ultimate above).

### 6. Build notes for our game

1. **Model scale: 0.74 of a medium.** Two ways to do it:
   - **Per archetype:** add an archetype size to `Models.hunter`, `root.scale = class scale × CLASS_LOOK.size × (arch size 0.74)`. Ignore or clamp the race scale for her so a Stoneborn look doesn't push her back up. Keep `ring.scale` dividing by the same visual-only factors so the ring still shows the true hitbox.
   - **Moving her weight to `"light"`:** that gives 0.9 × 0.95 = 0.855, which would still need ×0.87. It would also change HP, speed and dash rules, so the per-archetype route is cleaner.
   - Rework the silhouette so nothing stands above ≈0.85 of a medium; the lantern-above-head frame is the main offender. Express her identity low and wide instead.
2. **Collision:**
   - The source footprint is ≈0.8 of a medium. Set **`hit_r` to 0.34** (from 0.40), between light (0.35) and the strict 0.32.
   - Shot height doesn't change with the model: `match.shot_band` uses a fixed 1.5 m top for every Hunter. So she is not harder to hit vertically; only the 2D radius shrinks.
   - Against a 0.15 m shot, the hit width goes from 1.10 m to 0.98 m, about 11% narrower. That is fair at medium HP (145).
   - Only if `hit_r` goes to 0.32 or below (≈15% narrower) would a matching trim be warranted: about 5% off HP or armour. Otherwise leave HP and armour alone.
   - Melee and AoE checks using `e.r` scale the same way.
3. **Nameplate and overhead offsets:**
   - Source: the plate bottom sits ≈92 px above her soles, against ≈95-100 for mediums and ≈131 for the heavy. The plate drops only a little.
   - Ours: others' nameplates use a fixed `_head(h, 2.35)` for every hunter, and the own-overhead uses `2.7 × cdat.scale`.
   - Give her **≈2.05 m** for the nameplate and **≈2.35 m** for her own overhead. That keeps the bar just above the smaller model rather than floating far above it.
4. **Camera:** no zoom change. Every source clip is at the same zoom. If any camera or aim height samples the model's head or chest, use her scaled heights; shots should still leave at a believable hand height (≈0.7 m rather than 0.95).
5. **Locomotion (KMOVES and `HunterAnim`):**
   - **Speed:** keep 4.8 m/s, so she matches everyone.
   - **Stance:** `ARCH_STANCE.tender` is `{"lean": 0.04, "knee": 0.14, "width": 0.08, "breath": 2.2, "arm": 0.9}`. Change it to about `{"lean": 0.24, "knee": 0.32, "width": 0.1, "bounce": 1.1, "breath": 2.9, "arm": 1.3}`: low, forward, arms out.
   - **Cadence:** add a per-archetype cadence factor (today only heavy changes it, 2.15 → 1.95). Use **×1.25 for tender**, ≈2.7, giving ≈4.1 steps/s at full speed. The shorter legs need more steps to avoid foot-skate, and that lands close to the source's quick, short stride. Tune it until the feet don't slide.
   - **Bob:** add a `tender` branch beside the thief and juggernaut ones: `off.y += absf(sin(ph)) * 0.015 * r1`, small and once per step. Most of the liveliness should come from a secondary sway: something of our own design (a pack strap, a tail, the lantern) swinging ±0.5 rad at the stride rate, lagging the body by ≈0.1 s.
   - **Strafe:** the torso keeps facing aim and the legs follow movement. `legs_yaw` already supports this; make sure her kit doesn't lock the legs to the aim.
   - **Starts and stops:** ≤0.2 s ramps with no slide-out.
   - **Idle:**
     - A default hold with the arms out and palms open, plus a slow sway of the secondary piece (period 1.2 s, ±0.35 rad).
     - Add `"bounce"` and a "compact crouch" fidget (quick 15-20° torso turns every 0.5 s) to her fidget pool.
6. **Dash curve:**
   - **Ground Relay Step:** keep it short and quick. 4.2 m in 0.16 s is fine, since other hunters measure 2.7-4.5 m. Give it a small lift (`lift` ≈0.15) so it reads as a hop. The owner can supply footage to confirm this; see the clips list below.
   - **Air dash** (`use_ex`): make it hers rather than the class default. Roughly:
     - **0.1 s** ramp to **≈19 m/s**
     - hold for **0.4 s**
     - ease to **≈9 m/s** over **0.35 s**
     - stop on touchdown
     - **≈10-12 m** in total
     - gravity scaled to ≈0.15 during the float, so height is held and then drops in the last 0.15 s.
   - Even at the conservative end (≈8 m) this is a big buff on our 4.6 m. It is **an owner and balance call**; the cooldown could rise to match.
   - **Replace `mm_dash_air`'s forward roll** with three beats:
     1. A **streak**, 0-0.2 s: pitch about −1.3, stretched (`sq` −0.3), arms forward, legs trailing.
     2. A **seated float**, 0.2-0.8 s: knees tucked (`legs` about [1.4, −2.0, 1.3, −1.9]), arms out to the sides (`hw`/`rw` 1.0, wide), `lift` held.
     3. A **soft touchdown**: `sq` 0.12 at most, walking straight out.
7. **LMB and cast moves:**
   - The source's push comes from the hand, not a weapon. Our Lantern Crook can stay as our design.
   - The `mm_shot` timing (cock 0.06, release 0.1, settle 0.34) is close to the source. Add:
     - a **bigger torso unwind**: yaw ±0.6 rad instead of 0.2
     - an **alternating free-hand flourish** on every other shot
     - a **straighter forward thrust** of the casting arm (more punch, less overhead flick)
   - **`mm_seed`:** add a small hop on release, `lift` 0.2 for ≈0.3 s.
   - **`mm_hearth`:** already arms-up and matches.
8. **Sound character:** there is no audio in the footage. Suggested direction:
   - **Light and airy.** Quieter (−3 to −4 dB), higher-pitched footsteps (+3 to 5 semitones against a medium), quick pitter-patter.
   - Cloth flutter while floating.
   - A soft pop plus a rising chime and whoosh on the air dash.
   - A light tap on landing, never a thud.
   - A short puff or sparkle on each cast push.
   - Raise `tend_hop` from pitch 0.9/1.0 to ≈1.15/1.25.

**Clips that would settle the gaps.** The owner can supply these (60 fps if possible, default camera):
1. The **ground dash** with no jump first: from standing and from a run, two or three times each.
2. **Standing idle for ≥10 s** with no input, to see the fidget loop.
3. A **straight walk for 3 s without casting**, ideally passing a medium hunter side by side, for cadence, bob and relative height.
4. A **plain jump** (no dash), and a jump-then-air-dash, both over flat ground, for airtime and hang.
5. **LMB at full rate (0.4 s)** standing, then while walking.
6. The **base dash and the Super dash** each done on its own, clearly labelled.
7. Elluna **standing still beside a medium** (Shiv or Jin) in one frame.

### 7. Clean-room note

Moosh Moosh stays an original character. Take only the **scale, timing and motion** above: very small, quick and light on the ground, floaty in the air, casting with pushes of the hands. Express the small, cute, light support archetype through **our own shapes, proportions, palette, clothing, props and VFX**. Do not copy the source's outfit, hair, face, colours, silhouette details, ears or braid, or its crescent motif. Where these notes mention a "trailing appendage", use a secondary-motion piece of our own design.
