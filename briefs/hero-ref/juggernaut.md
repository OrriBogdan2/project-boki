# Juggernaut (our id `juggernaut`), source: Brall

- **Footage:** `/home/claude/svvid/hero/juggernaut/frames/`, 5 fps; frame N = video second 360 + (N-1)/5.
  - I confirmed the window by the "BRALL" title card (0001-0013) and the next hero's "KINGPIN" title card at about 457 s.
  - The ability windows: LMB 0014-0120, RMB 0121-0250, Air Slam 0251-0300, Tether Chain 0301-0366, Quick Dash 0371-0420, Retaliation 0421-0465, summary screen 0466-0480.
- **Key frames:** `/home/claude/hero-ref/juggernaut/`.
- **Our code:** origin/main 4f82978. The kit is `scripts/arch/kits/juggernaut_kit.gd`, the data `content/archetypes/juggernaut.json`, the moves are `jug_*` in `scripts/match/hunter_anim.gd` KMOVES (lines 1041-1120), and the design notes are in `docs/ARCHETYPES.md` ("Juggernaut = Brall", line 1066). There is no `docs/heroes/juggernaut.md`.
- **The footage version matches our port's structure.** The names differ from the wiki names our port cites (Blazing Spirit / Adaptive Strike / Flame Step / Feysteel Chain / Volcanic Rebuke): the video shows Fighting Spirit / Heavy Attack / Quick Dash / Tether Chain / Retaliation. The video is the newer or alpha build.
- **Scale:** Brall is about 50 px tall. "bh" is one body height, about 1.8 m in our world. Our ranges match the measured bh × 1.8; see venator.md.

## 1. Source summary

The text was read from the in-game cards (`juggernaut/cards_ingame.png`) and the summary screen (`summary_screen.png`).

| Slot | Ability | Input | Aim type | Cooldown / cost | Effect |
|---|---|---|---|---|---|
| Passive | Fighting Spirit | none | none | none | "Deal damage to become **Empowered**." Summary: "**Heal** when you knock an enemy or kill a creep." |
| LMB | Quick Attack | press = melee series; hold = ranged blast | melee cone toward the aim; the blast is a direction projectile flying past the cursor to max range | 0.2 s | "Quick attack, hold to fire a projectile." |
| RMB | Heavy Attack | press = **Execution Slam**; hold = **Charge Dash**; airborne = **Air Slam**; while tether-chaining = **Anti-Heal Spin** | Slam and Dash in the aim direction with a lane; Air Slam lands on a **cursor-placed** circle | 1.2 s (Air Slam card 5 s), 20 mana | Slam: execution damage, and **resets Retaliation if you knock an enemy**. Dash: charge and release a dash attack. Air: strike down, Slow and Stun. Spin: spin attack + Anti-Heal. |
| Shift | Quick Dash | press, **3 charges** (summary) | facing / aim direction | 0.4 s between uses, 20 mana | "Dash while attacking in your facing direction." |
| E | Tether Chain | press, then press again (recast) | a skillshot hook toward the cursor | 9.4 s, 25 mana | Attaches to enemies or walls; reactivate to pull yourself to it. |
| R | Retaliation | press | self, with a forward strike rectangle | 21.7 s, 20 mana | "Become **Invulnerable**, then strike back with a heavy attack." "Killing an enemy with this attack resets it." |

## 2. Per ability

### Passive: Fighting Spirit
1. **Input:** none. Damage you deal builds it, then you are Empowered.
2. **Aim:** none.
3. **Reticle:** none.
4. **Animation:** none.
5. **VFX:**
   - After the execution knock (0158-0175), **the whole screen tints red** and a red aura with dark-red drips sits on Brall. This is likely Empowered, or the knock feedback.
   - A **green heal orb and a green light-rain column** drop on Brall at the knock (0158-0165, 0455-0458). That is the knock heal.
7. **Numbers:** no meter is readable.
8. **Payoff:** knocks heal. Retaliation resets on a kill; the Execution Slam resets Retaliation on a knock.

### LMB: Quick Attack (0014-0120; `quick_attack_strip.jpg`)
1. **Input:**
   - Press for a melee **series**. The swings alternate: right-to-left, then left-to-right (0026 / 0029 / 0033).
   - He keeps walking while swinging.
   - Hold to fire a ranged blast. A charge of about 0.6-1.0 s shows a **thin white circular arc around Brall** (0087), then the blast fires.
2. **Aim:**
   - The slash is a wide arc in front of him, about 180°, with a radius of about 1.8 bh (0026, 0029).
   - Several swings face away from the cursor (0053, 0057), so the swing may follow the facing (movement) direction rather than the cursor. Unconfirmed.
   - The blast flies toward the cursor and **past it** to max range, leaving the screen (0081-0082, 0088, 0095).
3. **Reticle:** no indicator for slashes. The charge arc shows for the blast.
4. **Animation:**
   - A one-handed greatsword swung flat at waist height. Each swing is about 1 frame of wind-up and 1 frame of swing (0.2-0.4 s).
   - The blade is held trailing behind between swings, with a flaming yellow trail on the edge (0027, 0034).
5. **VFX:**
   - The slash arc is a **two-tone crescent: a magenta outer edge and a yellow-white flame inner fill** (0026, 0029, 0050).
   - The blast is a **red crescent bolt with a red glow**, flying at about 20 bh/s. On hitting a target, a red burst (0118).
7. **Numbers:**
   - Body hits are 94 (0047-0051).
   - A **tip / sweet-spot hit is 151, with a big white star flash** (0054, 0058). The tip is about 1.6x.

### RMB: Heavy Attack (0121-0250; `charge_dash_strip.jpg`)
**Hold: Charge Dash** (0121-0127, 0141-0146)
- **Input and charge:**
  - Hold to charge. Brall crouches with the blade low behind (0124-0125).
  - A **translucent red lane grows forward from him** as he charges (0124-0125). It **turns bright magenta at full charge** (0126, 0145). Full charge comes after about 0.6-0.8 s.
- **Release:**
  - He dashes about 2.5-3 bh (about 5 m) in about 0.2 s along the lane.
  - He stops at the target with a **huge white burst and a horizontal red slash** (0127, 0146).
- **Numbers:** a short charge hit for 559; a full charge for **771** (large yellow crit-style numbers).

**Press: Execution Slam** (0154-0158)
- The target **under the execute threshold is outlined in red** (0154: the red rim on the dummy).
- Brall winds up for about 0.6 s (0155-0157) with the blade cocked low behind.
- A **short magenta lane** shows at the end of the wind-up (0157).
- The strike reaches about 2.4 bh (the dummy) with a giant **magenta "1066" and a lightning glyph** (0158). The dummy is executed.
- Then the knock effects: a red KO star, the green heal column, and the red screen tint.
- It isn't certain this was a press rather than the hold variant. The card says the press is the execution.

**Airborne: Air Slam** (0251-0300)
- He jumps (or launches off a ledge).
- A **purple glowing disc (about 1.2 bh radius) is drawn at the landing point under the cursor** (0263, 0286-0287): cursor-placed.
- He slams down: a white dust explosion with multicolour spikes (0288). 370 damage.
- On the cliff demo the dummy was knocked off the edge (0291-0292: the knock-out beam).
- Card: 5 s, Slow and Stun.

**While chaining: Anti-Heal Spin** (0333-0336)
- Recast the chain to pull in, press RMB on arrival.
- A **magenta ring spin** of about 1.2 bh radius. 253 damage, with the Anti-Heal ⊘ icon on the target.

### Shift: Quick Dash (0371-0420)
1. **Input:** press. **3 charges.** 0.4 s between uses.
2. **Aim:** in the facing / aim direction (0387: toward the cursor).
3. **Reticle:** none.
4. **Animation:** a short dash, about 2 bh in about 0.2 s, with the sword thrust forward and **orange flame streaks behind** (0387-0388).
5. **VFX:** the flame streaks; a burst on hit (0401).
7. **Numbers:** 161 on the dummy (0401-0403). He ends next to or past the dummy.

### E: Tether Chain (0301-0366)
1. **Input:** press to throw; press again to pull himself to the attached point.
2. **Aim:** a skillshot toward the cursor. On the wall test it flies about 7 bh in about 0.4 s (0303-0305).
3. **Reticle:** no lane seen.
4. **Animation:** a throwing arm cocks and casts. During the pull he leans into the chain.
5. **VFX:**
   - In flight the chain is an **orange wavy zig-zag** (0303-0304).
   - Once attached it becomes a **straight striped chain (orange and dark links)** with a yellow spark at the anchor (0305).
   - **The tether stays attached while Brall walks** (0305-0317: about 2.5 s, still connected).
6. **Pull:** recast → he is pulled about 5 bh in about 0.4 s. A white dust puff marks the start point (0333).
7. **Numbers:** 9.4 s and 25 mana. Anti-Heal on a hooked enemy (the ⊘ icon, 0333-0341).

### R: Retaliation (0421-0465; `retaliation_strip.jpg`)
1. **Input:** press.
   - Brall takes a **guard stance with the blade vertical in front** and a golden glow (0425-0429, 0436).
   - A **white translucent rectangle (about 1 bh wide, 1.5 bh long) shows in front**: the strike area (0435-0436, 0458-0460).
   - After about 0.4-1.0 s, a **huge red vertical crescent strike** comes forward (0430, 0438), then a white impact cloud (0431, 0439).
   - The video does not show whether the strike comes early when he is hit (the dummy deals no damage).
2. **Aim:** the forward rectangle in the aim direction.
3. **Numbers:**
   - 396 per strike, plus 161 (the Quick Dash, 0437).
   - On the kill test (0451-0462), the kill gives a big red KO star, the green heal column and **the ability is immediately reusable**: the rectangle reappears at 0458 and he strikes again at 0461.
   - Card: 21.7 s and 20 mana.

## 3. Key frames (`/home/claude/hero-ref/juggernaut/`)

| File | Caption |
|---|---|
| 0026.jpg, 0029.jpg | Quick Attack alternating slashes: magenta + yellow crescent arcs. |
| 0058.jpg | Tip hit: a white star flash, 151. |
| 0081.jpg | The hold blast leaving: a red crescent bolt. |
| 0087.jpg | Hold-blast charge: the white arc around Brall. |
| 0126.jpg | Charge Dash: the lane turns magenta at full charge. |
| 0127.jpg | Charge Dash impact: 559. |
| 0145.jpg / 0146.jpg | Fully charged dash, then a 771 impact. |
| 0154.jpg | Execute threshold: the red outline on the low-HP target. |
| 0158.jpg | Execution Slam: 1066 with the execute glyph. |
| 0263.jpg / 0287.jpg | Air Slam landing disc at the cursor. |
| 0288.jpg | Air Slam impact. |
| 0304.jpg | Tether Chain in flight: the wavy orange chain. |
| 0333.jpg | Hooked dummy; Brall pulls in (start puff). |
| 0335.jpg | Anti-Heal Spin on arrival (253). |
| 0387.jpg | Quick Dash with flame streaks. |
| 0401.jpg | Quick Dash hit (161). |
| 0435.jpg | Retaliation guard and strike rectangle. |
| 0437.jpg | Retaliation red crescent strike. |
| 0454.jpg / 0455.jpg | Kill: a red KO star, then the green heal column. |
| cards_ingame.png | All in-game cards at full resolution. |
| summary_screen.png | The summary screen: the Heavy Attack variants and Quick Dash's 3 charges. |
| charge_dash_strip.jpg | 0122-0127 and 0141-0146: lane growth to magenta, then the impact. |
| quick_attack_strip.jpg | 0023-0034: the slash series. |
| retaliation_strip.jpg | 0425-0462: guard, strike, the kill reset. |

## 4. Gaps against ours (ranked by how much they change the feel)

1. **`mechanic`: Doomfall is unreachable, which kills the Smash payoff.**
   - `content/rules/boki_system.json` has `"class_ults": false`, so R is the Merge and `JuggernautKit.cast_r` never runs. But the Execution Slam's "sweet spot resets Doomfall" (`_slam`, `_reset_doom`) and "a knock resets Doomfall" are still the design's payoff.
   - The source's R (Retaliation) is a different move anyway: a guard stance that grants invulnerability, then a forward strike in a rectangle, reset on a kill. Ours is a rise-and-crash.
   - Change: fold something the player can actually trigger into a non-R slot, and re-point the Smash payoff. For example, make the Execution Slam sweet spot / knock give a Rampage charge back or Enrage instantly. Or fold a "guard then strike back" variant into RMB.
   - Files: `scripts/arch/kits/juggernaut_kit.gd` `_slam`, `_reset_doom`, `on_knock`, plus the card text in `juggernaut.json`.
2. **`reticle`: the Charge Dash (our Lunge) has no lane.**
   - Source: a translucent red lane grows forward while charging and **turns bright magenta at full charge**. The release dash follows it, and the impact is a huge white burst and a horizontal red slash.
   - Ours: `rmb_hold_tick` only plays the `jug_lunge_wind` pose.
   - Change: add `tele_lane(h.pos, aim, lunge length at k, ...)` updated per tick with `lunge_k`, and colour-flip it at k = 1. Add a big white burst on `_tick_lunge` contact.
3. **`numbers`: the Lunge length.**
   - Source: about 2.5-3 bh (about 5 m), whether short or full charge; damage grows from 559 to 771 (about 1.4x).
   - Ours: 3 → 7 m with damage 14 → 22 (1.6x).
   - Change: `rmb.lunge.dist` to about [4.5, 5.5]. Keep the damage ratio.
4. **`reticle` / `mechanic`: the Execution Slam telegraph and target.**
   - Source: **a low-HP target shows a red outline** (the execute threshold). The slam has a short magenta lane and reaches about 2.4 bh (about 4.3 m).
   - Ours: a 3.2 m, 100° cone, a "!" word over the head and a 1.3 m ring around self.
   - Change: (a) outline foes under `low` (35%) in red when Juggernaut has RMB ready (a status tell). (b) Swap the "!" ring for a forward lane or rectangle telegraph during `slam_w`. (c) Consider a 4.3 m reach.
5. **`mechanic` / `aim`: Air Slam (our Meteor Drop) is cursor-placed in the source.**
   - Source: a purple disc at the cursor while airborne, then the slam lands there.
   - Ours: `_meteor` slams straight down where you are.
   - Change: in `_meteor`, travel to the cursor (clamped to about 5 m) before the impact. Show the landing disc during the descent.
6. **`mechanic`: Quick Dash has 3 charges and a near-zero gap.**
   - Source: 3 charges, 0.4 s between uses, about 2 bh (about 3.6 m), 161 damage on hit.
   - Ours: Rampage has 2 charges (the third at rank 3), 9 s each, 4.4 m.
   - Change: 3 charges at rank 1 if the owner wants the source feel (`dash.cd`, extra charge logic). The dash distance could drop to about 3.6 m.
7. **`vfx`: the slash look.**
   - Source: wide (about 180°) two-tone crescents, magenta outside and flame-yellow inside, that alternate. The tip hit is a **white star flash**.
   - Ours: `_slash` uses a 140° arc through `h._strike` and its default slash fx.
   - Change: widen `lmb.arc` to about 170-180. Use a two-tone slash fx for the greatsword. Add a star flash for tip hits.
8. **`reticle`: the hold-blast charge tell.** Source: a thin white arc circles Brall while charging. Ours: `h.mel_hold` (the generic hold ring). Probably fine; make sure a ring is visible around the body, not only at the cursor.
9. **`vfx`: the Warchain look.** Source: a wavy orange chain in flight that straightens into a striped link chain once attached; the tether stays attached while you walk (about 2.5 s+). Ours: check `cast_e` / `_tick_chain`. The 4 s attach window matches.
10. **`vfx` / `sfx`: knock feedback.** Source: a giant red KO star, a green heal column on Brall and a red screen tint (0454-0458). Ours: `on_knock` heals 20%. Add a heal column and a brief red screen flash for the local player.
11. **`numbers`: cooldowns.** Source: RMB 1.2 s (ours 3 s), Air Slam 5 s, chain 9.4 s (ours 13 s). The source hunter is level 9, so these may be reduced. Ours reach 2.4 s and 10.4 s at rank 3. Consider shortening RMB toward 2 s at rank 1.

## 5. Rename
Not applicable: Juggernaut is not on the rename list (Dancer, Pin, Bjorn, Venator, Linwick, Moosh Moosh, Breah).

## 6. Open questions
- Does Quick Attack swing toward the cursor or the movement direction? Some swings point away from the cursor.
- Was 0154-0158 a press (Execution Slam) or the hold dash on an executable target? The lane looks the same.
- Retaliation: does it strike early when hit, or after a fixed guard time? The dummy deals no damage, so this can't be seen.
- Air Slam max range from the jump point.
- What Empowered actually gives (no numbers on the card); and the hold-blast range and damage (no number caught).

## Ultimate (on X)

**Source:** Brall, Retaliation. This is for **Zedran** (id `juggernaut`); the brief's older name "Juggernaut" is now Zedran. Card: "Block damage then strike back with a heavy attack", 21.7 s, 20 mana. Frames are in `/home/claude/svvid/ult/juggernaut/` (frame N = 442 s + (N-1)/10). Casts start at f33 and f51, then a kill test at f77–f101.

1. **Input:** tap.
   - A fixed guard window, then an automatic counter-strike.
   - Fine print: **Invulnerable for 0.65 s**, then strike back.
   - Whether getting hit ends the guard early isn't visible (the dummy deals no damage).
2. **Aim:**
   - The strike goes in the **facing / cursor direction**.
   - A short forward rectangle shows the hit area, about 1 bh wide and 1.5–2 bh long.
   - He lunges about 1 bh into the strike.
   - Movement during the guard looks locked; he stays planted in f33–f38.
3. **Reticle / telegraph:** a white translucent rectangle ahead of him during the guard (f36–f38, and again at f99–f101 after the reset). A **gold glow** on his body during the guard tells enemies "don't hit me".
4. **Animation beats:**
   - f33–f38 (0.6 s): guard. The blade is held vertical in front, his body flares gold, and small gold sparks appear.
   - f39 (0.1 s): the strike, a **long red vertical crescent slash** about 2 bh tall swung down through the target.
   - f40: impact, a red burst plus the damage number.
   - f41–f42: a white smoke and impact cloud.
   - He recovers by about f44, a total of about 1.1 s.
5. **VFX:** a gold guard glow, then a red crescent and a white cloud. The single huge red crescent is the identity; make ours a different colour or shape (for example a gold-to-white upward cleave).
6. **Sound:** none. It suggests a metallic guard "ting" on each blocked hit, then a heavy whoosh and a crunch.
7. **Numbers:**
   - **396** per strike (f40, f55). The 161 alongside is a Quick Dash hit.
   - Fine print: 190 + 90%, and he **heals for 80% of the damage dealt**.
   - On a kill the ult was **immediately reusable** (the rectangle reappears at f99, strike at f101). That is either a training-range reset or a kill reset; open question.
8. **Ends / combo:**
   - It ends after the strike.
   - Combo: dive with Quick Dash or the Air Slam, eat the enemy's burst during the 0.65 s invulnerability, and answer with the counter. It is best used to dodge a telegraphed ult.

**Key frames:** `juggernaut/ult_0033.jpg` (press, guard begins), `ult_0036.jpg` (gold guard glow), `ult_0038.jpg` (guard end, rectangle), `ult_0039.jpg` (red crescent strike), `ult_0040.jpg` (impact 396), `ult_0041.jpg` (white impact cloud), `ult_0055.jpg` (second cast strike), `ult_0101.jpg` (re-cast after a kill).

**Build notes:**
- **What to build:** X = 0.65 s invulnerable guard (planted, gold body glow), then an automatic forward cleave (1 bh × 2 bh) that heals 80% of damage dealt. Optional: if he blocks a hit during the guard, the strike gains +X% damage.
- **Bond:** landing the counter on a hunter adds **0.6**. Each hit blocked during the guard adds +0.1 (up to +0.2), so a real "retaliation" fills about 80%.

## Body, scale and movement feel

Method and units are as in venator.md's section of the same name: the hunter's ground motion comes from tracking the bar plus the camera pan. Distances are in 960 px units, 1 px ≈ 0.0375 m, 1 bh = Ghost's height ≈ 48 px ≈ 1.8 m. Zoom is the same in every clip; the training dummy is an Oath-model hunter, ~107 px tall and ~115 wide at 1080p.

### 1. Height and bulk
- **Brall:** ~95 px at 1080p from head to sole in his normal hunched stance (0171) and ~85 px crouched (0257). The body is 55-75 px wide (the big upper arms and shoulders).
- **His overhead bar sits much higher than his head:** the cyan line is ~135-140 px above the soles (~1.45 bh), with ~40 px of clear space over the hunched head.
  - Ghost's bar is ~1.15 bh and the Oath dummy's ~1.35 bh. So the game treats Brall as the tallest of the six. He carries that height bent forward, which is why his on-screen silhouette is no taller than Ghost's.
- **Against Ghost:** the silhouette is ~1.0x as tall, ~1.2-1.4x as wide, and the "true" height ~1.2x (by the bar anchor). Against the Oath dummy: about the same height and narrower.
- **Ours:** juggernaut is heavy, 1.14 × 1.035 = **1.18x medium**.
- **Target scale factor ~1.12**, slightly down, with the stature carried as a deep hunch. Keep the heavy build, and stance width (0.25) and knee (0.34) as they are.

### 2. Locomotion
- **Run speed:**
  - The median steady move is 104 px/s ≈ 3.9 m/s, **the slowest of the six but only ~6% under Ghost.**
  - Plain runs reach 113-124 px/s (0012-0017, 0403-0408, 0412-0418).
  - Slower stretches of 85-95 px/s line up with the Heavy Attack hold (0178-0181, 0198-0208).
  - Ours: heavy 4.55 against medium 4.8 (-5%). That matches, as long as the hold slow is kept.
- **Start:** 8 → 58 → 122 px/s in 2 frames at 399.43 s (≈0.07 s). The stop is the same.
- **Cadence:** stride cycle ~2.26 Hz (≈4.5 steps/s). Ours: heavy 1.41 Hz. **Ours is much slower-stepping than the source.**
- **Lean:**
  - He runs hunched, chest well forward over the knees (362.2-363.15 s, 0012-0016).
  - The greatsword is held out in front, low, in one hand, leading the run.
  - The shoulders roll a little with the steps.
  - Ours: lean 0.1, shoulders rolling ±0.06, a footfall drop of 0.035. **Increase the run lean to ~0.35.**
- **Turning:** quick. The upper body follows the cursor with the blade.

### 3. Idle
- A low, heavy stance with the blade held low to the side (0169-0175, 0449-0450).
- No loop is visible beyond a held pose. Ours (breath 1.35, wide planted stance) fits.

### 4. Ground dash (Shift: Quick Dash)
- **Body (434.40-435.35 s, 0372-0377):**
  - Wind-up 0.15-0.2 s: he crouches with the blade cocked up and back over the shoulder (434.40-434.60).
  - Dash ~0.3 s (434.70-434.95): the body goes flat and horizontal and turns into a bright fire-lit streak and afterimage along the path.
  - Recovery ~0.35 s (435.00-435.35): he stays low with the blade dragging a fire trail behind, then stands.
  - The whole move takes ~0.9 s.
- **Distance and curve:**
  - 116 px ≈ 4.3 m ≈ 2.4 bh over 0.4 s above run speed. Peak 430 px/s (~16 m/s) at +0.1 s, then decay (143 → 365 → 423 → 336 → 266 → 190 → 112 px/s).
  - A second cast covers 153 px ≈ 5.8 m over 0.57 s (0386-0388).
- **Heavy Attack lunge, for comparison:** 110 px ≈ 4.1 m in 0.3 s, peak 493 px/s (0219-0220).
- **Ours (kitfix-dancer-juggernaut):** Rampage is 3.6 m in 0.3 s. The `jug_dash` keys are a shoulder-down drive with the blade levelled, tip out at 0.22, done by 0.65.
  - **Difference:** the source has a visible ~0.15-0.2 s wind-up crouch before the move and a longer ~0.35 s low recovery. The distance is ~4.3-5.8 m against our 3.6.

### 5. Air dash
- Not shown as a dash. In the air he uses the Air Slam (§6).

### 6. Jump and landing (Air Slam)
- **Rise (412.0-412.85 s, 0261-0266; also 410.0-410.6 s):** he leaves the ground at ~412.0 s while the gold landing marker stays on the ground. He rises to the apex by ~412.3 s with a slash at the top.
- **Drive down:** steep, 412.5-412.8 s, into a purple ground circle.
- **Impact at ~412.85 s:**
  - A big white dust cloud ~2 bh across.
  - The deepest squash of the six: a crouch onto the knees.
- **Recovery:** ~0.5 s in a low crouch with the blade dragged (413.3-413.9 s).
- **Airtime:** ~0.85 s, longer than a plain jump because of the slam. No plain jump is shown.

### 7. Cast and attack body language
- **Budget:** big.
  - Wind-ups are clear crouches (Quick Dash, Heavy Attack hold).
  - Slashes step into the swing, about 1 frame of wind-up and 1 frame of swing.
  - Every heavy move lands in a long low recovery.
- **Squash and stretch:**
  - A strong squash on landings and dash recoveries.
  - A flat stretch during the dash streak.
- **Timing:** the wind-up beat is 0.15-0.2 s, the action 0.2-0.3 s, and the recovery 0.35-0.5 s.

### 8. Build notes
- **Model scale:** ~1.12, hunched.
- **Collision:** hit_r 0.50 against a ~0.6-0.75 m-wide body is generous to attackers. Keep it; it fits a frontline tank. Don't shrink it with the scale change.
- **Camera and nameplate:** his source anchor is the highest, ~1.45 bh ≈ 2.6 m. Use **~2.75 m** instead of the shared 2.35 so the plate clears his raised blade.
- **KMOVES and locomotion:**
  - Cadence about `spd*2.9` (drop the heavy 1.95).
  - Run lean ~0.35, the blade carried ahead and low.
  - Keep the shoulder roll and footfall weight.
- **Dash curve:**
  - Quick Dash: add a 0.15 s crouched wind-up key (blade cocked high behind) before `jug_dash`'s drive.
  - The drive covers ~4.5 m in ~0.3 s, peaking at ~16 m/s at 0.1 s into the drive.
  - Extend the recovery to ~0.35 s low with the blade dragging (end the keys at ~0.85 s).
  - `jug_exdash` (our air variant) has no footage. Keep it.
- **Sound:**
  - Footsteps: heavy, quick, with a leathery thud and a blade scrape every few steps.
  - Dash: a fire roar whoosh with a crackle tail during the recovery drag.
  - Slam landing: a deep boom plus a gravel spray.

### 9. Unclear
- A plain jump and landing with no Air Slam. Settle it with a clip of a plain jump or ledge drop.
- What happens if Quick Dash is cast in the air. Settle it with a mid-jump Shift.
- Cadence at 60 fps. Settle it with a straight run without the heavy hold.
