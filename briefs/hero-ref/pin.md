# Pin (`archer`): reference sheet (source: Myth)

Footage: `/home/claude/svvid/hero/pin/frames`, 5 fps, video 578-701 s, so frame N = second 578 + (N-1)/5. The video has no audio.
Our code was read at origin/main **4f82978** (descendant of 7881774; no archer gameplay changes in between).
Scale: the hunter is about 55 px tall (1 bh = 1 body height).

**Version note:** this footage is newer than the kit our doc was built from (docs/heroes/archer.md):
- The LMB has an **overdraw** penalty.
- A perfect release now **speeds up the next charge** instead of adding damage.
- Shift is **Spirit Walk** (a dodge roll, then 2.8 s through walls and objects), not a 2-charge phase.
- The E wall is a **curved arc**.

The in-demo card names differ a little from the end summary (`0604`): "Supercharged Shots" on the card is "Charged Shot" in the summary. The summary also shows that player's own keybinds; the default layout is used below.

## 1. Source summary

| Slot | Ability | Input | Aim type | Cooldown (card) | Cost | Effect |
|---|---|---|---|---|---|---|
| Passive | Soul Hunter | none | none | none | none | See injured hunters through fog; climb tall (double) ledges with jump |
| LMB | Supercharged Shots (Charged Shot) | hold to draw, release | **lands at the cursor** (clamped to range); a Supercharged shot flies to its longer max range | 0.5 s | none | 2 stages: Empowered, then Supercharged (destruction damage, more range); hold too long and it's overdrawn (weaker); releasing right at a stage makes the next Empowered charge faster |
| RMB | Impaling Shot | hold to charge, release (tap fires uncharged) | skillshot toward the cursor | 9 s | none (shown) | Impales and knocks back; into a wall it stuns; a charged shot does more wall damage |
| L Shift | Spirit Walk | tap | dodge roll in the move direction, then free walking | 0.4 s (mana-gated) | 10 mana | 2.8 s through walls and objects (not terrain or vaults); damage ends it; ending inside a wall costs 30 mana and teleports you back to the entry point |
| E | Rain of Arrows | tap | wall centred at the **cursor distance** (clamped), curved arc across the aim | 8.3 s | 25 mana | Wall of raining arrows: damage per second, slow, anti-heal burn; knocking a burning enemy "cremates" them |
| R | Primal Forces | tap | none | 33.3 s | 40 mana | The next 3 Supercharged shots pierce, gain range, deal destruction damage and shred armor; the 3rd does execution damage |

## 2. Per ability

### Passive: Soul Hunter (`0604`)
- Gives vision of injured hunters through the fog of war, and lets you climb tall ledges.
- Not demonstrated on screen beyond the card (frames 1-60 show only a dummy).
- Ours has it already (Hawk Sense). The ledge climb is left out (heightmap).

### LMB: Supercharged Shots (`0102`-`0124`, `0167`-`0169`, `0209`-`0214`, `0252`-`0256`)

**1. Input**
- Hold to draw. Release to fire.
- The stages (frame counts from the hold sequence 161-170 and 102-107):
  - f0: the draw starts.
  - **Empowered ready at about 0.6-0.8 s** (3-4 frames): f105, f165.
  - The draw continues. **Supercharged ready at about 1.2-1.4 s**: f168.
  - Keep holding about 0.4-0.6 s past Supercharged and the shot is **overdrawn**: the white line fades back to a thin, dull line (f252-254). That release did 263, against 505 for a clean Supercharged (`0214`), so overdraw roughly **halves** the shot.
- Release before Empowered is a weak tap shot (not isolated in the clip).
- The hunter walks slowly while drawing; it keeps moving in f111-116.

**2. Aim**
- **An Empowered / stage-1 shot lands at the cursor.** With no target, every shot plants a glowing arrow in the ground exactly on the cursor ring (`0117`: cursor at about 6 bh, arrow stuck there; also f119, f126, f133).
- The **Supercharged** shot is different. Its aim line is drawn **past the cursor out to the long max range** (`0168`), and the shot flew past the cursor into the far wall (`0169`, f170).
- So: stage 1 stops at the cursor (clamped to range), and stage 2 goes to its full, longer range.
- The hunter turns to the cursor throughout.

**3. Reticle** (the core of the feel; all world-space, drawn on the ground plane)
- **Idle:** one faint thin line from the bow to the cursor (`0101`). The cursor is a small white ring with a dot.
- **Drawing toward Empowered:**
  - Two thin pale-green lines leave the bow in a **V that opens about 25° and closes toward the cursor line** as the charge builds (`0102` wide, then f103 narrower).
  - A bright 4-point star glint rides along the line (`0104`, about a third of the way out).
  - When the V **closes into one bright green line**, a yellow-white flash pops at the bow. That is Empowered ready (`0105`).
- **Drawing toward Supercharged:**
  - The V re-opens (f106/f166) and closes again.
  - At the end the hunter's whole body flashes white for 1 frame (`0167`).
  - The line becomes **thicker, white and extends past the cursor to max range**, with a large white 4-point star at the bow (`0168`, f250).
  - A target under the line gets a yellow-green glow ring at its feet while Supercharged is held on it (`0209`).
- **Overdrawn:** the white line and star dim to a thin pale line (`0252`).
- **Perfect release:**
  - Releasing on the ready frame spawns a **large gold 4-point star with a soft gold ring** just beside the hunter's bow hand, about 0.6 bh across, for 1 frame (`0124`, f178, f258).
  - This is the "released the moment it was ready" feedback. The card says the reward is a faster next Empowered charge.

**4. Animation**
- Draw pose: side-on, bow arm extended toward the cursor, string hand at the chest. The pose holds while drawing.
- Release: a small snap back of the string hand, about 1 frame (0.2 s).
- No big recoil on Empowered. On Supercharged the body flashes (`0167`) and the release kicks harder (f169).

**5. VFX**
- Empowered arrow:
  - A long thin green bolt with a soft green glow cloud near the far end. It crosses about 6 bh in 1 frame, so it's near-hitscan.
  - It leaves a **small glowing teal arrow stuck in the ground** at the landing point, which lingers 4+ s (`0117`, f119-135).
- Supercharged:
  - A wide white-teal beam-like arrow (`0169`).
  - On hit, a big teal X-shaped star burst on the target (`0214`).

**6. Sound:** n/a. Probably creaks and a ping at each ready, and a "shing" on perfect.

**7. Numbers**
- Cooldown 0.5 s.
- Supercharged hit 505. Overdrawn release 263.
- Knock at f224 (red X-star).

**8. Combo**
- Empowered, release on time, and the next draw is faster. This is the rhythm the kit is built around.
- Rain wall plus Impaling Shot knockback through it, then the burn and execute.

### RMB: Impaling Shot (`0270`, `0273`; charge seen in `0494`)
1. **Input:** hold to charge, release to fire.
2. **Aim:**
   - Skillshot toward the cursor.
   - It hits the first target and knocks it back about 2-3 bh along the shot (`0273`).
3. **Reticle:**
   - The same V lines as the LMB, but **gold/orange tinted** (f264-269).
   - While held, a **thick gold bar** extends from the bow along the aim, about 2 bh long (`0494`, f264).
4. **Anim:**
   - Charge pose like the LMB draw.
   - A small pink crescent swipe at the feet on the release frame (f268).
5. **VFX** (the arrow is `distinctive`):
   - A thick gold arrow with violet side-fins (`0270`).
   - Impact: a red-white burst, then a white dust cloud as the target is pushed back (`0271`, `0273`).
   - Then a white ring around the target (f274).
6. **Sound:** n/a.
7. **Numbers:** cooldown 9 s; hit 67 at low charge (f271).
8. **Combo:**
   - Into a wall: a stun, plus more damage when charged (card).
   - The wall stun wasn't demonstrated clearly in this clip.

### L Shift: Spirit Walk (`0360`)
- **Input and timing:**
  - Tap: a quick dodge roll (green burst at the hunter, f350), then 2.8 s of Spirit Walk.
  - The hunter glows green and walks *into* a black pillar and out the other side (f360-366).
- **Visuals:**
  - While the hunter is **inside** an object the whole screen turns dark blue (`0360`, f358-361).
  - The world returns to normal colour when the hunter is clear.
- **Rules (card):**
  - Damage ends it.
  - If it ends inside a wall you lose 30 mana and are teleported to where you entered.
- **Numbers:** card cooldown 0.4 s and 10 mana, so it's effectively mana-gated.

### E: Rain of Arrows (`0457`, `0498`)
1. **Input:** tap.
2. **Aim:**
   - The wall is centred **at the cursor distance** (cursor ring on the wall in `0457` at about 4.5 bh, and `0498` at about 6 bh).
   - The wall is a **curved arc concentric to the hunter**, about 120° wide, so roughly 8-10 bh of wall.
3. **Reticle:** none seen before the cast. It's instant.
4. **Anim:** the bow is raised and arrows are lobbed upward in curving green arcs (f456, f496).
5. **VFX:**
   - The wall is a strip of about 6-8 translucent green panels with bright edges, and arrow-fletch icons standing at the panel joins.
   - A green ground glow sits under it.
   - Green arrow streaks rain down continuously (`0498`).
   - Enemies inside burn with **blue flames** (the anti-heal burn) (f480).
   - It lasts about 4.4 s (f458-480).
6. **Sound:** n/a.
7. **Numbers:**
   - Cooldown 8.3 s, 25 mana.
   - Slow and anti-heal (summary).
   - Small damage ticks (138 on the burn, f466).
8. **Combo:** knocking a burning enemy cremates them (execute flavour).

### R: Primal Forces (`0570`)
- Tap. The hunter glows magenta.
- The next 3 Supercharged shots become long **magenta beams** that pierce and gain range. The aim line is a single magenta line running far past the cursor (`0570`).
- The 3rd shot does execution damage.
- Cooldown 33.3 s, 40 mana.
- Our R is the Boki Merge, and the doc drops this ultimate (Deadeye covers the role).

## 3. Key frames (`/home/claude/hero-ref/pin/`)

| File | Caption |
|---|---|
| 0102.jpg | Draw start: wide V of two lines from the bow toward the cursor |
| 0104.jpg | Star glint riding the line; the V closing |
| 0105.jpg | Empowered ready: lines merged into one bright line, flash at the bow |
| 0107.jpg | Empowered release on the dummy |
| 0117.jpg | Shot with no target lands **at the cursor**: glowing arrow stuck there |
| 0124.jpg | **Perfect release**: large gold 4-point star beside the bow hand |
| 0167.jpg | Body flashes white as Supercharged comes up |
| 0168.jpg | Supercharged ready: thick white line **past the cursor** to max range, white star |
| 0169.jpg | Supercharged beam flying past the cursor |
| 0209.jpg | Target under the Supercharged line glows at its feet |
| 0214.jpg | Supercharged hit: teal X-star, 505 |
| 0252.jpg | Overdrawn: the white line and star fading |
| 0256.jpg | Overdrawn release: 263 |
| 0270.jpg | Impaling Shot: thick gold arrow with violet fins |
| 0273.jpg | Impaling knockback: dust, target pushed about 2-3 bh |
| 0360.jpg | Spirit Walk inside a pillar: dark-blue screen tint |
| 0457.jpg | Rain of Arrows wall: curved arc at the cursor distance |
| 0498.jpg | Rain falling; Impaling charge bar at the bow |
| 0570.jpg | Primal Forces: magenta aura, long magenta aim line |
| 0604.jpg | Kit summary screen |

## 4. Gaps against ours, ranked by how much they change the feel

1. **[aim] Bow shots must stop at the cursor.**
   - Source: Empowered shots land on the cursor (clamped to the stage range) (`0117`).
   - Ours: `Hunter._emit_shot` always flies `rng` (12 / 15 m) for the bow. Only `boom` weapons clamp to the cursor.
   - For `draw` weapons, set `life = clamp(dist_to_aim, 1.5, rng) / spd` the way the `boom` branch does (`scripts/match/hunter.gd`, after `var rng`).
   - Exception: let the full-draw (stage 2) shot fly its full range, to match `0168`/`0169`.
   - Also plant a short-lived glowing arrow decal where an arrow lands with no hit.
2. **[reticle] There is no draw reticle at all.**
   - Ours: while drawing, the HUD shows only the ammo ring (`hud.gd` `_draw_crosshair` has no `draw_t` branch). The stage flashes are world flashes at the bow only (`ArcherKit._tick_draw_stages`).
   - Build the source's world reticle in `ArcherKit` (a node like `glint`):
     - Two thin lines from the bow to the cursor point, at an angle `lerp(25°, 0°, stage progress)`.
     - A 4-point star sprite sliding along the line.
     - On a stage ready, the lines merge into one bright line plus a flash at the bow.
     - Stage 2 ready: the line goes white, thicker, and extends to max range.
     - Overdrawn: it dims.
   - Optionally echo it on the HUD: a ring around the cursor that fills per stage.
3. **[mechanic] The perfect release reward is different.**
   - Source: it makes the *next* Empowered charge faster.
   - Ours: +15% / +25% damage (`ArcherKit.draw_bonus`, `perfect_k`).
   - Change `draw_bonus` to return 1.0 and set a flag such as `st["quick_draw"] = true`. While it's set, scale `h.draw_t` gain by about 1.6× in `Hunter.trigger` (the `draw_t += dt` line, hunter.gd about line 1378) until stage 1. Clear it on the next release.
   - Keep the PERFECT feedback, but make it the **gold 4-point star + ring beside the bow hand** (`0124`). Today it's a white word plus a green flash.
4. **[mechanic] No overdraw.**
   - Source: holding about 0.4-0.6 s past full draw weakens the arrow to about 50% (`0252`-`0256`).
   - Ours: full draw holds forever.
   - Add `overdraw_t` (≈0.5 s after the last stage) and `overdraw_k` (0.5) to `longbow.json`. In `Hunter._loose`, scale `dmg` when `t > last_stage + overdraw_t`. The reticle dims at that point.
5. **[numbers] Stage timing.**
   - Source: Empowered at about 0.6-0.8 s, Supercharged at about 1.2-1.4 s.
   - Ours: 0.4 / 0.9 (`longbow.json` `draw`). The doc says this was deliberate, for ranged TTK.
   - With the perfect-speedup loop (gap 3), stage 1 can go back to about 0.6 s and still feel fast. Owner call.
6. **[mechanic] Shift is a different ability.**
   - Source: Spirit Walk, a dodge roll plus 2.8 s of walking through walls and objects. Damage ends it; ending inside a wall teleports you back.
   - Ours: Grapple Arrow (zip to a ledge or hop).
   - The doc dropped phasing because of the heightmap. Spirit Walk is closer to doable than a 2-charge phase: pass through `is_block` cells and tall steps for 2.8 s and snap back if it ends inside one. Owner decision. This is the largest kit difference left.
7. **[aim/vfx] The Hail Wall shape is a straight line; the source is a curved arc.**
   - Source: an arc concentric to the hunter, about 120° wide, centred at the cursor distance (`0457`, `0498`).
   - Ours: a straight 6 m line across the aim at `aim_at(reach)` (`ArcherKit.cast_e`, `_in_rain`).
   - Make it an arc: radius = clamp(cursor distance, 2, reach), half-angle about 60°. Test membership by angle and radius band. Draw it as 6-8 panels with fletch posts, and add blue burn flames on foes inside.
8. **[numbers] Hail Wall cooldown.** Source 8.3 s; ours `e.cooldown` 15. Suggest about 9-10.
9. **[reticle] The Heavy Shot hold telegraph.**
   - Source: the same V reticle tinted gold, plus a thick gold bar growing from the bow (`0494`).
   - Ours: the shared `tele_lane` (pale, full length).
   - Recolour the hold lane to a gold bar from the bow that grows with `heavy_k()`, and reuse the V lines (`rmb_hold_tick`).
10. **[vfx] Supercharged hit and target highlight.**
    - Source: the target under a held full-draw line gets a glow ring (`0209`), and the hit is a big X-star (`0214`).
    - Ours: none and a generic hit.
    - Add both in `ArcherKit._tick_draw_stages` (raycast the line to the first foe) and on stage-2 hits.
11. **[anim] Body flash at full draw.**
    - Source: the whole body flashes white 1 frame when Supercharged comes up (`0167`).
    - Ours: a flash at the bow only. Add a modulate pulse on the body in `_tick_draw_stages` at `pw.x`.
12. **[vfx] Spent arrows.** Source arrows stick in the ground at the cursor and glow teal for about 4 s. Ours have nothing. A small mesh decal with fade (fx pool).
13. **[sfx]** No audio in the footage.

## 5. Rename (Archer to Pin), every player-facing place the old name appears
- `content/archetypes/archer.json`: `"name": "Archer"`. This feeds the hero picker, title, kit card and wiki through `Arch`.
- `scripts/match/hero_kit.gd:15`: `"archer": {"name": "Archer", ...}`.
- Wiki (generated by `tools/gen_wiki.py`; regenerate after the json change):
  - `docs/wiki/Class-Archer.md` (rename the file to Class-Pin.md and update links)
  - `docs/wiki/Classes.md` lines 7, 55, 73
  - `docs/wiki/Weapons.md:18` (Longbow owner column)
  - `docs/wiki/_Sidebar.md:8`
- Check output text (tester-facing): `tools/hero_check.gd:52` ("picking the Archer"), `tools/archetype_check.gd:195` ("Archer bow").
- Internal comments only (not player-facing): `arch_kit.gd:743`, `arena_demo.gd:22/363`, `models.gd:1654`, `archetype_check.gd:298/958`, `tools/sfx_combat.py:500`, and `docs/ARCHETYPES.md`. No sfx file or label uses "Archer".

## 6. Open questions
- Exactly where a stage-2 (Supercharged) shot ends with no target: full range or a longer clamp past the cursor? Seen once (`0169`).
- How much faster the next Empowered charge is after a perfect release. Not measurable from 5 fps.
- The size of the perfect window. It looks like about 1 frame (≤0.2 s).
- The tap-shot (released before Empowered) damage and range.
- The Impaling Shot wall stun duration and the charge time to full. The wall case isn't shown cleanly.
- How a knock "cremates" a burning enemy: VFX or a mechanic?
- Spirit Walk speed, and whether you can shoot during it.

## Ultimate (on X)

**Source:** Myth, Primal Forces. Card: "Tap to empower your next 3 Supercharged Shots (LMB) with Primal Forces. Primal Forces pierces enemies, has increased range, deals destruction damage, and shreds armor. The Final Shot also deals execution damage." Card: **33.3 s, 40 mana**. Frames are in `/home/claude/svvid/ult/pin/` (frame N = 685 s + (N-1)/10). Cast at f33; the empowered shots land at about f48, f63 and f78. A second round runs about f101–f129.

1. **Input:**
   - Tap. It's a self-buff with no cast lock.
   - The payoff is then delivered through **LMB charged shots**: you still draw the bow.
   - Fine print (thebackdash, an older version named "Virideth's Fury"): **empowered arrows need no charge**, and the buff **lasts 6 s**.
   - In the video, each shot still shows a short magenta draw of about 0.4–0.8 s.
2. **Aim:**
   - The same as LMB: a skillshot to the cursor direction.
   - Each shot becomes a **long piercing beam** that runs well past the target, at about 1.5× normal range.
   - She can walk between shots.
3. **Reticle / telegraph:**
   - Cast: a **pink-magenta burst** around her (f33).
   - While empowered, the draw reticle at her feet becomes a **magenta crosshair ring** (f36, f46), and her bow glows pink.
   - The HUD shows a 3-pip counter on the ult icon.
4. **Animation beats:**
   - f33 (0.1 s): the empower flash.
   - Each shot: the draw (magenta glow builds, about 0.4–0.8 s), then release (f48), a thick magenta beam that appears at once along the whole line, then impact on the target with a **white burst cloud** (f50).
   - The cadence is about **1.5 s per shot**, so all 3 shots fit in about 4.5 s, inside the 6 s window.
5. **VFX:**
   - A thick pink-magenta beam with a white core, lasting about 0.2 s, plus a white flak cloud on impact.
   - The final shot's beam is the same, with a slightly bigger burst.
   - A beam-arrow is generic. Our Pin should use our own colour.
6. **Sound:** none. It suggests a deeper bowstring thrum and a cracking boom per shot.
7. **Numbers:**
   - Hits of **463 – 503** on a dummy per empowered shot (f50, f64).
   - Fine print (older): 220 + 100% Explosive damage per shot, with the **final shot 280 + 105%**.
   - The current card adds **armor shred** and **execution damage on the final shot**.
8. **Ends / combo:**
   - It ends after 3 shots or after 6 s.
   - Combo: Impaling Shot (knockback or pin) or Rain of Arrows to hold a target, then three piercing beams down the lane, with the final one executing.
   - Piercing rewards lining enemies up.
   - Allies: no effect.

**Key frames:** `pin/ult_0031.jpg` (before), `ult_0033.jpg` (empower flash), `ult_0036.jpg` (magenta crosshair draw), `ult_0044.jpg` (draw with pink bow), `ult_0048.jpg` (beam release), `ult_0050.jpg` (white impact, 463), `ult_0062.jpg` (second beam), `ult_0064.jpg` (second impact), `ult_0066.jpg` (follow-through and number).

**Build notes:**
- **What to build:** X = a self-buff. The next 3 LMB shots (6 s window) become instant full-charge piercing beams at 1.5× range with armor shred, and the 3rd executes below a threshold.
- **Bond:** since the cast itself is free, pay only on hits. Each empowered shot that hits at least one hunter adds 0.22, and the final shot hit adds 0.12 extra. All three landing gives about **0.78**; a whiff gives nothing.

## Body, scale and movement feel

Method and units are as in venator.md's section of the same name: the hunter's ground motion comes from tracking the bar plus the camera pan. Distances are in 960 px units, 1 px ≈ 0.0375 m, 1 bh = Ghost's height ≈ 48 px ≈ 1.8 m. Zoom is the same in every clip; the training dummy is an Oath-model hunter, ~107 px tall at 1080p.

### 1. Height and bulk
- **Myth:** ~95-100 px at 1080p from head to sole standing (0148) and ~80 px in the low draw crouch (0532).
  - The body is slim, ~50-55 px wide. The bow and its arms spread to ~110 px when drawn.
  - The bar's cyan line sits ~110 px above the soles (~1.15 bh).
- **Against Ghost (~96 px, ~55 wide):** **the same height, ~1.0x, and the same slim build.** Against the Oath dummy she is ~0.9x as tall and half as wide.
- **Ours:** archer is light, scale 0.9 × CLASS_LOOK 0.95 = **0.855x medium**.
- **Target scale factor ~0.98** (about ×1.15 on what we have now). She should stand as tall as Venator, not a head shorter. Keep the light build (0.84).

### 2. Locomotion
- **Run speed:**
  - The median steady run is 113 px/s ≈ 4.25 m/s.
  - Stretches: 0030-0038 at 111 (1.6 s round the pit), 0046-0050 at 108, 0312-0318 at 120, 0367-0374 at 108, 0411-0416 at 116.
  - That is the same as Ghost (110) and Oath (117). Ours: light 5.0 against medium 4.8, a +4% the source doesn't show.
- **Spirit Walk run:** 117-126 px/s (0349-0356), about +5-10% over her normal run. Ours walk_k is 1.15; the source looks closer to 1.1.
- **Acceleration and stopping:** instant (the same one-frame ramps as the others).
- **Cadence:** stride cycle ~2.3 Hz (≈4.5 steps/s), quick short steps. Ours: light `spd*2.15` → 1.71 Hz.
- **Lean and bob:**
  - She runs fairly upright and tall with the head up (583.8-584.2 s, 0030-0036). The bow is carried low in the leading hand, out from the hip.
  - Drawing, she walks slowly with the body turned side-on to the cursor (0111-0116).
  - Spirit Walk changes the carriage: crouched, leaning hard forward, arms trailing (656.05-656.25 s, 0391-0392).
  - Ours: archer lean 0.0 and "runs tall" (+0.04): correct.
- **Turning:** the upper body snaps to the cursor and the legs follow the travel direction.

### 3. Idle
- She stands lightly in a slightly side-on stance with the bow held low (0136-0166 between shots).
- No loop or fidget can be resolved. Our breath 2.3 is fine.

### 4. Ground dash (Shift: Spirit Walk's dodge roll)
- **Timing:** 655.55-655.65 s (0388-0389).
  - A green burst at the start.
  - The body dives forward, stretched almost flat, for ~0.1-0.15 s (it reads as a quick dive-roll).
  - She goes straight into the crouched Spirit Walk run, with no landing beat.
- **Distance and curve:** 79 px ≈ 3.0 m ≈ 1.7 bh over 0.27 s above run speed. The speed rises 147 → 346 → 447 px/s (peak ~17 m/s at +0.13 s), then drops 258 → 125 px/s.
- **Ours (kitfix-pin-bjorn):** roll 2.6 m in 0.16 s (~16 m/s). `pin_roll` is a full forward roll by 0.16 s, up by 0.42. **This is a close match.** The source is ~0.4 m longer and shows no "standing up": the roll ends already in the crouched spirit run.

### 5. Air dash
- Not shown clearly. 0051-0053 (588.1 s) is a 62 px (~2.3 m) push over 0.37 s at only ~2x run speed, inside the pit ring, and could be a hop. It isn't a clean air dash.

### 6. Jump and landing
- Not shown. The passive's double-ledge climb is not demonstrated either.

### 7. Cast and attack body language
- **Budget:** small and precise.
  - The draw holds one locked side-on pose.
  - The release snaps in one frame with little recoil.
  - The Heavy Shot draw sinks lower.
  - The Rain of Arrows lob raises the bow high.
- **Squash and stretch:** the stretch is reserved for the roll. The draw crouch is the only squash.
- **Timing:** wind-up holds (the draw) are long, and releases are one-frame snaps.

### 8. Build notes
- **Model scale:** ~0.98 (raise from 0.855). This could be a per-archetype `size` override in Models (CLASS_LOOK is per class).
- **Collision:** hit_r 0.35 now. Scaled up 15%, her ~0.5 m-wide body would overhang a 0.35 m radius by very little. Raise it to ~0.37 so shots that visibly touch her count; at 0.35 she'd be slightly harder to hit than she looks, which is unfair to the shooter.
- **Camera and nameplate:** the bar sits ~1.15 bh above the soles, ~2.1 m. With the scale change our shared 2.35 m is fine (or use ~2.3).
- **KMOVES and locomotion:**
  - Cadence about `spd*2.9`, with a stride ~25% shorter.
  - Keep the tall run.
  - Spirit Walk: lean the pitch forward ~0.25 and trail the arms (`pin_walk` already does this), and the run speed bonus is ~1.1x rather than 1.15x.
- **Dash curve:** keep the 0.16 s roll, but carry it ~3 m with an ease-out tail (peak at 0.1 s, then decay over the next ~0.15 s into the Spirit Walk speed). End `pin_roll` in the crouched walk pose instead of standing at 0.42.
- **Sound:**
  - Footsteps: light, soft and quick (leather, no metal).
  - Roll: a short cloth whoosh and a soft thud. The spirit run is muffled, almost silent footsteps.

### 9. Unclear
- Air dash, jump and landing, and the ledge climb. Settle them with a clip of Myth jumping onto a double-height ledge and rolling in the air.
- Exact cadence. Settle it with a 2 s straight run at 60 fps without drawing.
- Whether the roll direction follows movement or aim. Settle it with a roll sideways to the cursor.
