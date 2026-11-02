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
