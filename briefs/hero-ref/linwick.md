# Linwick (our id `ashwick`), source: Felix

- **Footage:** `/home/claude/svvid/hero/linwick/frames/`, 5 fps; frame N = video second 214 + (N-1)/5. I confirmed the window against the "FELIX" title card (0004-0030) and the next hero's "SHIV" title card at about 279 s.
- **Key frames:** `/home/claude/hero-ref/linwick/`.
- **Our code:** origin/main 4f82978. The kit is `scripts/arch/kits/ashwick_kit.gd`, the data `content/archetypes/ashwick.json`, the weapon `content/weapons/flamethrower.json`, the moves `scripts/match/kmoves_pair.gd` (`as_*`) and the doc `docs/heroes/ashwick.md`. The current display name is **Ashwick**.
- **Scale:** Felix is about 45 px tall. "bh" is one body height. Our world uses about **1 bh ≈ 1.8 m**: our existing ranges equal the measured bh × 1.8 almost exactly, for example the dash at 2.3 bh against our 4.4 m and the shield ring at 2.5 bh against our 4.5 m. Metre figures below use that conversion.

## 1. Source summary

The text was read from the in-game cards at full resolution (`linwick/cards_ingame.png`). The hunter is level 9.

| Slot | Ability | Input | Aim type | Cooldown / cost | Effect |
|---|---|---|---|---|---|
| Passive | Ignite | none | none | none | "Damaging enemies sets them on fire, going from **Burning** to **Blazing**." The summary screen says "Dealing damage Ignites enemies in flames, dealing damage over time." |
| LMB | Flamethrower | hold | direction; the stream runs its full length (about 4 bh, about 7 m) regardless of the cursor. The stream **lags like a hose** when swept. | "0s" | Hold to fire; it ignites. |
| RMB | Fire Bolt | press, a lane shows, then fire | a direction skillshot; it **appeared to end at the cursor** on a miss (0133), so it may be cursor-clamped | 5.8 s, 20 mana | A long-range bolt that "deals damage and spreads Ignite to nearby enemies". |
| Shift | Flame Skull Bash | press; **2 charges** | toward the cursor; a short dash that **stops on impact** | 0.4 s between uses, 20 mana | "Dash a short distance and impact enemies, applying Ignite." |
| E | Flame Shield | press | self-centred ring, about 2.5 bh (about 4.5 m) | 8.3 s, 15 mana | Damage nearby, Anti-Heal, pull them in, and a shield scaled by the number of enemies hit. |
| R | Jetpack | press | flies forward along the aim | 25 s, 40 mana | "Lift off and fly forward, setting the ground on fire behind you." It applies Ignite. |

## 2. Per ability

### Passive: Ignite, Burning then Blazing (0021-0060; `burn_stages_strip.jpg`)
1. **Input:** none. Any of his damage builds it.
2. **Aim:** none.
3. **Reticle:** none.
4. **Animation:** none.
5. **VFX (on the target, `distinctive` only in style):**
   - **Burning:** one small orange flame icon floats above the target's health bar after about 1-2 s of flame (220.2 s).
   - **Blazing:** **three flame icons**, and the health bar gets an orange-red glow, after about 3 s of continuous flame (222.2 s).
   - Blazing keeps burning after the flame stops (0048-0060: ticks keep landing, icons stay).
7. **Numbers:**
   - Flamethrower ticks read 29 before the burn and 36 once Burning (219.0 → 220.2 s), so the flame itself seems to hit harder on a burning target.
   - Burn ticks: Burning 24; Blazing 47 and 83.
   - Ignite from the bolt ticks 19 (0078-0083). Ticks come about every 0.5 s.
8. **Payoff:** a two-stage burn. Sustain the flame (or stack abilities) to push Burning into Blazing.

### LMB: Flamethrower (0007-0046; title 0004-0019)
1. **Input:**
   - Hold. A **cyan pilot flame flickers at the nozzle** for one frame (about 0.2 s) before the fire comes out (0021 → 0022).
   - On release the fire stops at once (0047), and the pilot stays visible as a small cyan flame at the nozzle.
2. **Aim:**
   - Direction. The stream reaches about **4 bh** (0012: about 190 px, while the cursor was only about 60 px away), so it does not stop at the cursor.
   - **The stream is not a rigid cone.** When Felix sweeps, the fire lags behind and curves (0016: the nozzle points left, the stream bends down where he was aiming a moment before). It behaves like particles thrown from the nozzle that keep their own velocity.
   - He walks while firing (0007-0019). There is no visible slow.
3. **Reticle:** the normal cursor only. No cone indicator.
4. **Animation:** the nozzle is held low at the right hip and pointed forward; the body faces the aim. Nothing else stands out.
5. **VFX:**
   - A narrow stream at the nozzle (about 0.3 bh) that billows wider (about 1-1.5 bh) and turns yellow-orange at the far end and around a target (0024-0042).
   - The colour runs from bright yellow at the core to orange.
   - The cyan pilot flame at the nozzle is `distinctive` in its contrast: a cool blue nozzle with warm fire.
6. **Sound:** none in the footage.
7. **Numbers:** 29-36 per tick, with ticks about every 0.1-0.2 s (two or three numbers appear per frame).

### RMB: Fire Bolt (0072-0137)
1. **Input:**
   - A white aim lane shows for about 0.4 s before the shot (0073-0074, 0102-0103, 0131). This is the same lane style as Ghost's grenade, so it is probably "hold to aim, release to fire" or quick-cast with an indicator.
   - Felix does not stop moving.
2. **Aim:**
   - A direction skillshot.
   - On a miss, the bolt **ended at the cursor**: 0133 shows a small blue ring flash at the reticle, about 6.5 bh out, and the bolt is gone by 0135. So it is probably **cursor-clamped to a max range**. The card says "long-range".
   - On a hit it stops at the first enemy.
3. **Reticle:** a thin translucent white lane from Felix toward the cursor. On a miss, a small blue-white ring flash at the end point.
4. **Animation:** a quick forward thrust of the gun arm. The rest is unclear at this zoom.
5. **VFX:**
   - The bolt is a red-pink fireball with a yellow core, a blue-violet halo and a dark smoke trail (0075, 0105).
   - Speed is about 13-15 bh/s (about 6-8 bh in 0.4-0.6 s), which is about 25 m/s.
   - On hit: a red flash and an **ember shower** (red sparks) around the target (0076-0079), then the Ignite flame icon.
7. **Numbers:** 248 on hit (0077, 0107), then Ignite ticks of 19. The dummy also showed "SLOWED" after the hit (0077-0083); this may come from the jump pad it stood on, so it is unconfirmed.
8. **Combo:** on a burning target, the bolt spreads Ignite to enemies nearby (card text). This isn't demonstrated with several dummies.

### Shift: Flame Skull Bash (0138-0165; `bash_strip.jpg`)
1. **Input:** press. **2 charges** (summary screen). The card shows 0.4 s, probably the gap between charges.
2. **Aim:**
   - **Toward the cursor.** 0159: the cursor is lower-left and he dashes left.
   - A **short** dash, about 2.3 bh (about 4.2 m), taking about 0.2-0.4 s.
   - **It stops at the first enemy** ("impact"). In 0141-0145 the dash goes into the dummy, a big burst lands on contact, and he does not pass through.
3. **Reticle:** none seen.
4. **Animation:** a head-first lunge with the body stretched forward. A **flaming crescent or skull shape wraps his front** like a battering ram, with flame tails streaming behind (0159). He lands upright (0160-0161).
5. **VFX:**
   - On hit, a large red-orange flash covering Felix and the target, with red embers (0144-0146).
   - The crescent fireball shape on the front is `distinctive` (the flame skull).
7. **Numbers:** 279 on impact (0144-0145), then Ignite ticks of 19.

### E: Flame Shield (0179-0220, and in the jetpack trail at 0278-0282)
1. **Input:** press.
   - Frame 0181: a **thin orange ring at full radius (about 2.5 bh) shows for about 0.2 s**, and Felix spreads his arms.
   - Frame 0182: the blast.
2. **Aim:** self-centred. It hits everything inside the ring.
3. **Telegraph:** the thin orange ring at the edge of the area, for one frame (0181).
4. **Animation:**
   - Arms flung wide at the blast (0181-0182).
   - The pull drags the target in to touching distance within about 0.4 s (0182 → 0184).
5. **VFX:**
   - A **huge yellow-orange spiky sunburst** filling the ring (0182).
   - Then a ring of fire with a scorched, cracked ground decal and a smoke puff over the target (0183).
   - Then the **shield: a swirling yellow-orange ring hugging Felix (about 0.8 bh radius)** for about 2.5-3 s (0184-0196).
   - The target shows an "ANTI-HEAL" label and a purple ⊘ icon.
7. **Numbers:** 117 on the blast, then burn ticks. Card: 8.3 s and 15 mana. The shield amount isn't readable.
8. **Combo:** pull enemies into the jetpack fire trail (0278-0298: the dummy is pulled into the lava trail and takes trail ticks of 16).

### R: Jetpack (0221-0300)
1. **Input:** press. Lift-off is immediate.
2. **Aim:**
   - Flies forward along the aim direction (0223-0229: up-right, toward the cursor).
   - The distance is long, about 8-10 bh (about 15-18 m), over about 1.2 s.
   - Whether it is cursor-placed or a fixed distance isn't clear.
3. **Reticle:** none seen.
4. **Animation:** a red ember ring bursts at the feet on lift-off (0223). He flies low and upright. The landing isn't clearly shown.
5. **VFX:**
   - A **wide lava-like fire carpet** (about 1 bh ≈ 1.8 m wide) along the whole path: molten orange and yellow with dark purple scorched edges (0224-0232).
   - It lasts about 4 s (0276 → 0298).
7. **Numbers:** 25 s and 40 mana. Trail ticks are 16 on a dummy standing in it (0284-0296).

## 3. Key frames (`/home/claude/hero-ref/linwick/`)

| File | Caption |
|---|---|
| 0012.jpg | Flamethrower stream reaching about 4 bh while the cursor is close: full length regardless of the cursor. |
| 0016.jpg | Hose lag: the stream curves behind a sweep. |
| 0021.jpg | The cyan pilot flame for one frame before the fire. |
| 0024.jpg | Flame on the dummy: 29s, the narrow-then-billowing stream. |
| 0042.jpg | Blazing: three flame icons, ticks of 83 and 47. |
| 0048.jpg | After release: Blazing keeps burning. |
| 0073.jpg | Fire Bolt aim lane. |
| 0075.jpg | Fire Bolt in flight: a fireball with a blue halo and a smoke trail. |
| 0077.jpg | Bolt impact: 248, an ember shower. |
| 0133.jpg | A missed bolt ending at the cursor with a small blue ring flash. |
| 0144.jpg | Flame Skull Bash impact on the dummy (279). |
| 0159.jpg | Flame Skull Bash mid-dash: a flaming crescent on the front, flame tails. |
| 0181.jpg | Flame Shield telegraph ring, arms spread. |
| 0182.jpg | Flame Shield blast: the sunburst, Anti-Heal on the target. |
| 0186.jpg | Flame Shield: the swirling shield ring on Felix. |
| 0223.jpg | Jetpack lift-off: the ember ring. |
| 0226.jpg | Jetpack fire carpet. |
| 0280.jpg | Flame Shield pulling the dummy into the jetpack trail (the combo). |
| cards_ingame.png | All 6 in-game cards at full resolution. |
| summary_screen.png | The summary screen (Fire Bolt on E, Bash on SPACE with 2 charges, Shield on L SHIFT, Jetpack on Q). |
| burn_stages_strip.jpg | 219.0-224.6 s: no burn, then Burning (one icon), then Blazing (three icons). |
| bash_strip.jpg | 0157-0164: the dash toward the cursor, then recovery. |

## 4. Gaps against ours (ranked by how much they change the feel)

1. **`mechanic` / `vfx`: the flamethrower is a rigid instant cone in ours; the source is a lagging hose stream.**
   - Source: the fire leaves the nozzle and keeps its own velocity, so a sweep curves the stream (0016). It is narrow at the nozzle and billows at the end.
   - Ours: `_flame_look` re-aims two quads straight along `aim_dir` every frame, and `_flame_tick` hits a 44° cone at once.
   - Change: in `ashwick_kit.gd`, build the stream from a chain of short-lived segments emitted at the muzzle (or sample the aim direction with a delay along the length). Hit along those segments rather than in an instant cone. Narrow the near end (about 0.5 m) and widen the far end (about 2-2.5 m).
2. **`mechanic` / `aim`: Spark Leap passes through the foe; the source bash stops on impact.**
   - Source: a short dash toward the cursor that ends on the first enemy with a big impact burst (279 damage).
   - Ours: `travel(... "shove": true ...)` over the full 4.4 m, and `_leap_char` charring every foe along the segment ("leap through").
   - Change: in `on_dash`, cut the travel at the first foe hit and deal the impact there (a burst). Update the doc and card text, which say "through the foe".
3. **`vfx` / `anim`: the dash identity.**
   - Source: head-first, with a flaming ram (crescent) in front and flame tails behind.
   - Ours: `as_leap` is a deep crouch then stretched out, with a `dust` trail.
   - Change: a fire-front shape on the leading edge and ember tails in our own look, in `on_dash`. Change `as_leap` to a head-first lunge.
4. **`numbers` / `mechanic`: two burn stages.**
   - Source: Burning (one icon) after about 1-2 s of flame, then Blazing (three icons, a glowing bar, much bigger ticks) after about 3 s. The flame also hits harder on a burning target (29 → 36).
   - Ours: Flashover levels 1 and 2 at 31 Char each (30 Char/s, half while burning), so level 1 at about 1 s and level 2 at about 3 s. That matches well.
   - Gaps: (a) the flame's own ticks do not go up on a burning foe. Add about +25% in `_flame_tick` when `burning(f) > 0`. (b) Show the stage on the target as 1 vs 3 flame pips over the health bar, plus a bar glow at level 2. Today the tell is only "glows white-hot".
5. **`reticle` / `aim`: the Cinder Shot lane and its range.**
   - Source: a white aim lane shows before the shot, and a miss ended at the cursor (0133).
   - Ours: tap, a fixed 14 m projectile (`rmb.range`).
   - Change: add the aim lane (`tele_lane`) while held. Clamp travel to the cursor distance, up to 14 m (a `range` override from `inp["aim"]` distance in `fire_rmb`), and add a small end-point fizzle ring. Confirm against more footage, since it is one miss.
6. **`reticle` / `anim`: Furnace Cloak timing.**
   - Source: a 0.2 s edge ring with arms flung wide, then the sunburst blast, then a visible swirling shield ring on Felix for about 2.5-3 s.
   - Ours: an instant ring + burst, and a small 1.2 m ring when shielded.
   - Change: in `cast_e`, add a 0.2 s ring telegraph before the effect (`m.later`). Keep a looping shield swirl on Linwick while `h.shield_t > 0`.
7. **`mechanic`: the dash has charges and a near-zero gap.** Source: 2 charges, 0.4 s between uses. Ours: 2 heavy-class charges at 9 s each. That is fine; just check that two leaps can chain within about 0.4 s.
8. **`mechanic`: the folded ultimate (Jetpack) trail.**
   - Source: about 8-10 bh (about 15-18 m) of lava carpet, about 1.8 m wide, lasting about 4 s.
   - Ours (rank 3 Leap): a trail only along the 4.4 m leap, 3 s, radius 1.0.
   - Change: lengthen `trail_t` to 4. Optionally render the trail as one continuous molten strip with dark scorched edges (`_tick_trail` only spawns small bursts every 0.3 s now).
9. **`vfx`: the bolt impact.** Source: an ember shower plus a red flash. Ours: `_cinder_hit` (check it). Add a persistent ember spray for about 0.6 s.
10. **`vfx`: the pilot flame.** Source: a **cyan** pilot at the nozzle before the fire and while idle. Ours: an orange ring + flash (`m.fx.ring ... Color("ffb04a")`). A cool-coloured pilot gives the warm/cool read; ours can use our own palette.
11. **`numbers`: fuel.** Ours has 8 s of fuel and a reload (`mag` 80). The source card shows "0s" with no fuel bar visible in 6 s of continuous fire. Fine to keep. Noted as a difference.
12. **`numbers`: self-slow.** Ours slows to 0.8 while flaming and 0.6 for 0.35 s after release (`move_k`). No slow is visible in the source footage (it is subtle at 5 fps). Keep the wiki value.

## 5. Rename: places the old display name "Ashwick" appears
- Player-facing:
  - `content/archetypes/ashwick.json:3` `"name": "Ashwick"` (drives the kit card, title and HUD)
  - `scripts/match/hero_kit.gd:21` `{"name": "Ashwick", ...}`
- gen_wiki output (regenerate with `tools/gen_wiki.py`):
  - `docs/wiki/Class-Ashwick.md` (title and file name)
  - `docs/wiki/Classes.md:9,61,75`
  - `docs/wiki/Weapons.md:14`
- sfx labels: `tools/sfx_heroes_pair.py:1,58`.
- Internal (comments, docs, class name):
  - `class_name AshwickKit` in `scripts/arch/kits/ashwick_kit.gd:1,3` and `scripts/arch/arch_kit.gd:47`
  - `scripts/match/kmoves_pair.gd:3,36`, `scripts/match/arena_demo.gd:101`, `scripts/match/arena_demo_pair.gd:3,81`, `scripts/match/hero_gear_pair.gd:3,8`
  - `tools/ashwick_combo_check.gd:2,30`, `tools/arena_check.gd:113`
  - `docs/heroes/ashwick.md:1,62`, `docs/ARCHETYPES.md:1202`, `docs/ROADMAP.md:11`
- No `translations/` hits.

## 6. Open questions
- Does Fire Bolt really stop at the cursor (one miss sample), and is "SLOWED" on the dummy from the bolt or the jump pad?
- The spread of Ignite from a bolt on a burning target isn't shown (only one dummy).
- The shield amount and duration exactly; the pull range limit and line-of-sight rule aren't shown.
- Jetpack: cursor-targeted or fixed distance? Can he act while flying? The landing isn't clear.
- What resets or ends Blazing, and how long does Burning last on its own? Ticks were still going at 0060 (about 3 s after release).
- The flamethrower's real range limit and fuel (none visible).

## Ultimate (on X)

**Source:** Felix, Jetpack. Card: "Lift off and fly forward, setting the ground on fire behind you", 25 s, 40 mana. Frames are in `/home/claude/svvid/ult/linwick/` (frame N = 256 s + (N-1)/10). Three casts start at f25, f65 and f127; the third ends in a Flame Shield combo at f137–f139.

1. **Input:** tap. Lift-off is instant. Fine print: **reactivating ends the flight early**.
2. **Aim:**
   - The flight starts toward the cursor and **steers toward the cursor while flying**. The fire trails are visibly curved: f34→f38 bends from up-right to up, and the second cast bends as well.
   - Flight length is about 9–10 bh in about 1.3–1.4 s (about 7 bh/s).
   - It is not cursor-clamped. He flies the full duration unless recast.
3. **Reticle / telegraph:** none beyond the normal cursor. Enemies see only the burst and the growing trail.
4. **Animation beats:**
   - f25 (0.1 s): a **red-orange ember burst** ring about 1.2 bh around his feet.
   - f26–f39 (about 1.4 s): he flies low and upright. The trail is laid continuously under him.
   - The landing has no big impact. He simply continues on foot (f39–f41).
   - In cast 3 he fires Flame Shield the moment he lands: an orange ring of about 2.2 bh at f137, then a big yellow starburst explosion and a pull at f139.
5. **VFX:**
   - The trail is a **molten carpet about 1 bh wide**: yellow-orange cracked lava with dark purple, charred edges and floating embers.
   - It lasts about **4 s**, then fades from the oldest end.
   - The lava with purple char is a palette, not a shape, so it isn't strongly distinctive. Still, use our own palette.
6. **Sound:** none. It suggests a jet roar on lift-off and fire crackle along the trail.
7. **Numbers:**
   - Trail ticks **16** on a dummy (earlier sheet). 11 on the shield combo (f139).
   - Fine print (thebackdash): the fire deals 160 + 44% per second for **4 s**, **slows**, and **builds Ignite quickly**.
8. **Ends / combo:**
   - It ends at the end of the flight or on a recast.
   - Combo: fly through or around enemies to lay a slowing, Igniting carpet, then land on them with **Flame Shield** (pull + Anti-Heal + shield). The pull drags them into the lava.
   - Escape use: fly away and leave fire behind to block a chase.

**Fine print not found:** whether he can be interrupted or is crowd-control immune while flying, and whether he can cross gaps. The flight looked to be over ground only.

**Key frames:** `linwick/ult_0024.jpg` (before), `ult_0025.jpg` (ember burst lift-off), `ult_0027.jpg` (trail begins), `ult_0034.jpg` and `ult_0038.jpg` (curving trail, steering), `ult_0068.jpg` (second cast, early trail), `ult_0072.jpg` (full trail), `ult_0137.jpg` (lands into Flame Shield ring), `ult_0139.jpg` (shield explosion on the trail).

**Build notes:**
- **What to build:** X = a 1.4 s steerable flight at about 7 bh/s that follows the cursor with a capped turn rate. It lays a 1 bh lava strip (4 s, slow, Ignite build-up). X again lands early.
- **Bond:** each distinct enemy hunter that the lava touches adds 0.3, capped at **0.7**. Landing E on someone standing in the lava adds a +0.1 combo bonus, so a full Jetpack→E play fills about 80%.

## Body, scale and movement feel

Method, shared by all five sheets written in this pass:
- Measured on 1080p frames pulled from `all.mp4`; times are video seconds, frame numbers are this hero's 5 fps frames (N = (t - 214) x 5 + 1).
- The main video uses one fixed camera zoom for every hero, so pixel sizes compare directly between heroes. Ground scale: about **50 px = 1 m** (the existing sheets' 1 bh = 90 px = 1.8 m).
- **Height** is the on-screen head-to-foot length of the standing figure (the camera looks steeply down, so this mixes height and depth, but it does so the same way for every hero).
- **Medium reference:** Ghost and Joule measure about **90 px** (main video 95 s and 20 s).
- **Nameplate:** the plate sits a fixed ~110 px above the ground point for every hero (Felix 112, Kingpin 108, Void ~114). It does not move with body size.
- **Speeds** come from camera pan, measured by phase correlation on the ground, plus the hero's own screen drift, so camera lag cancels out. Each is good to about ±10%.

### 1. Height and bulk
- **Height:** about **80 px** standing (241.5 s / 0138, 223.6 s / 0049). That is 0.89 of a medium hunter.
- **Width:** about 50 px across the body and pack (74 px including the hose loop). A medium is about 55-60 px.
- **Bulk:** a small, compact, round body with a big backpack mass. Head top to plate bottom is about 32 px; mediums have only 5-10 px there, so the plate floats well clear of his head.
- **Ours:** heavy class, 1.14 x 1.035 = **1.18** of a medium (times the race scale).
- **Target:** about **0.90** overall, a factor of **x0.76** on today's root scale. The tall hat may rise above that line; the body should not.

### 2. Locomotion
- **Run speed:** steady camera-follow plateaus of **205-230 px/s** (241.4-241.8 s, 251.4-251.8 s). That is about **4.4 m/s**: the same band as Void (~4.1) and a little under Celeste (~4.8). Ours (heavy) is 4.55 m/s, which is fine.
- **Cadence:** a quick scurry. A trailing foot shows about every **0.15-0.2 s** (60 fps crop, 241.2-241.9 s / 0137-0140), so roughly 5-6 footfalls a second with short strides. Ours takes about 0.35 s per step at heavy speed (`ph += spd*1.95`), so the source cadence is about **2x ours**.
- **Bob:** small, about 2-4 px (3-5% of height).
- **Lean:** none readable; he runs upright and compact.
- **Accelerating, stopping and turning:** all instant at 60 fps. There is no visible slide when he stops, and he turns on the spot within 1-2 frames.
- **Weapon carry:** the nozzle stays up and forward at the right shoulder with the hose looped behind. It stays raised while running and does not swing.

### 3. Idle
- He stands square and planted, facing the aim (223-227 s, while firing).
- No breathing or fidget loop can be resolved at this zoom in the 3-4 s of standing shown.

### 4. Ground dash (Flame Skull Bash, the source's dash slot)
- **Free dash** (245.53-245.87 s / 0159-0160): about **170 px ≈ 3.4 m in 0.33 s**, an average of ~10 m/s (about 2.3x run).
- **Speed curve:** front-loaded. Camera speed is about 700 px/s for the first 0.1 s, then 450-500 px/s, then it stops dead.
- **Pose:** a head-first horizontal lunge, the body compact inside a flame shell, with a long flame tail streaming back about 2-3 body lengths.
- **Recovery:** he comes out upright with feet apart and the gun already on the aim, at once (245.9 s).
- **Into a target** (242.5-242.6 s / 0143-0144):
  - The lunge reaches the dummy in about 0.12 s and stops on contact.
  - Within about **0.1 s** he is knocked back to roughly where he started (about 1 bh of recoil).
  - Then he stands while the target burns.
- **Ours** (Soot Ram, kitfix): 4.4 m in 0.26 s, which is about 17 m/s: **faster and longer** than the source.

### 5. Air dash
- Not shown. Every use in the footage is on the ground.
- The closest air move is the R jetpack (259.2-260.8 s / 0227-0235):
  - A low, upright flight at about **500 px/s ≈ 10 m/s** for about 1.6 s.
  - No tilt into the flight is readable.
  - He sets down and walks on with no visible squash.

### 6. Jump and landing
- No jump is shown.
- The jetpack set-down has no visible dust or squash at this zoom.

### 7. Cast and attack body language
- **Small motion budget:** the body barely moves for LMB (he walks while firing, nozzle at hip height) or RMB (a quick forward arm thrust).
- **E:** arms flung wide for one ~0.2 s beat as the ring flashes, then the blast.
- **Big moves:** only the bash and the jetpack.
- **Squash and stretch:** only the stretch into the bash and the snap back on impact.

### 8. Build notes
- **Model scale:** about 0.90 of medium (today 1.18).
  - Keep the hat as the tall read above the body.
  - Keep the body short and round: a race "bulk" of about 1.05 on a short body.
- **Collision:**
  - The heavy `hit_r` is 0.50, but a 0.9-scale body would look about 0.42.
  - **Fairness:** a hitbox larger than the model is a hidden penalty for him. Either give Linwick his own `hit_r` of about 0.44, or keep 0.50 and let the ring under his feet (already drawn at the real size) show it.
  - Do not shrink the hitbox below what the model shows.
- **Camera and nameplate:**
  - No per-hero camera change.
  - Keep the plate at the shared fixed height (as the source does). At 0.9 scale it floats about a hand above the hat; that is fine and matches the source.
- **KMOVES and locomotion:**
  - `ARCH_STANCE["ashwick"]`: knee 0.2, lean 0.02, width 0.12, bounce 0.6, breath 2.4, arm 0.9.
  - Add a per-arch cadence multiplier of about **1.8**: steps every ~0.19 s at 4.4 m/s, with short strides (stride 0.45 instead of 0.62).
  - Keep the nozzle carry raised at the shoulder while running, with no arm swing on the gun side.
- **Ground dash curve and pose:**
  - `dist` 3.6, `time` 0.32.
  - Speed curve: 1.4x the average for the first 30%, then 0.85x, and a hard stop with no carry (`DASH_CARRY_GROUND` 0).
  - `as_leap`: keep the 0.08 s crouch, but hold the stretched pose (p -0.75) through 0.30 and release by 0.42.
  - On a hit: a 0.1 s recoil of about 1.5 m back along the path (kitfix `recoil` 3.5 is in this range), landing upright with the gun up.
- **Air dash:** none in the source. Use the class long dash, keeping the same compact head-first pose.
- **Sound** (the video has no audio; this is the intended character):
  - Footsteps: light and fast patter with a small metallic clink from the pack on every other step.
  - Bash: a gas-burner whoosh that ignites on start, a dull fiery thump on contact, and a short scrape on the recoil.

### 9. Unclear
- **Idle loop and breathing:** needs 5+ s of Felix standing with no input at close zoom, for example a hero-select or lobby idle.
- **Exact stride count:** needs a 2+ s straight run at 60 fps, moving across the screen rather than toward the camera; 241.2-241.9 s runs up-screen.
- **Air bash, jump arc and landing squash:** none are in this video. They need a match clip of Felix using the bash off a ledge or jump pad.
