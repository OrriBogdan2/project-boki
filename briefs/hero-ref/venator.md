# Venator (our id `gunslinger`), source: Ghost

**Footage warning:** `segs.txt` gives Ghost as 81-159 s, but that window holds a different hero: a sniper kit with Snipe, Bird Bomb, Disengage, Eyes in the Sky and Legendary Bullet (see `hero/venator/cards_ocr.txt`). Ghost's real segment is **523-578 s**, between the Kaiju Blast hero and the "MYTH" title card. I extracted that window to
`/home/claude/svvid/hero/venator_ghost/frames/` (5 fps, 960 px; frame N = video second 523 + (N-1)/5), with its own `cards_ocr.txt` and `README.txt`. **Every frame reference below is to that folder.** The other segments may also be shifted, so check them; the Linwick and Juggernaut windows were confirmed separately.

Our code: origin/main at 4f82978 (it contains 7881774). The kit is `scripts/arch/kits/gunslinger_kit.gd`, the data `content/archetypes/gunslinger.json`, the weapon `content/weapons/quill_rifle.json` and the doc `docs/heroes/gunslinger.md`. The current display name in code is **Marlowe**.

Scale: Ghost is about 45-50 px tall in the normal top-down view (960 px frames). Below, "bh" means one body height.

**Converting to our metres:** our hunters are about 1.8 m tall (shots leave at 0.95 m, chest height). Our existing ranges match the measured bh × about 1.8 consistently: Felix's flame is about 4 bh against our 6 m, and his dash about 2.3 bh against our 4.4 m. So **1 bh ≈ 1.8 m in our world**, not 1 m, and the metre figures below use that.

## 1. Source summary

The card text was read from full-resolution frames (`venator/cards_ingame.png`). The hunter is level 9 in the clip, so these cooldowns may already be reduced by level.

| Slot | Ability | Input | Aim type | Cooldown / cost | Effect |
|---|---|---|---|---|---|
| Passive | Combat Stim | none | none | none | "Knocking an enemy resets Combat Slide (L SHIFT) cooldown." Nothing else in this build. |
| LMB | HK7R City Sweeper | hold | direction; bullets fly to **max range** past the cursor | "0.3s" on the card | "Hold to fire, deals extra damage to dazed enemies." Auto rifle. Damage decays over a string, about 60 down to 30. |
| RMB | Spike Grenade | press and aim with a lane, then release (lane shown while held) | direction; the grenade flies along the lane to max range, **not to the cursor**. It sticks to the first enemy or wall. | 5.4 s, 20 mana | "Throw a sticky grenade, dazes enemies." On a wall it explodes in a cone back out (summary screen). |
| Shift | Combat Slide | press = short slide; hold = longer slide | movement direction, **not the cursor**; can fire the rifle while sliding | 7.5 s, 18 mana | "Slide forward, hold to slide further." |
| E | Ion Cannon | press; a ~0.6 s cast bar, then the beam | direction; a fixed long line (well past the cursor) through terrain | 10 s, 40 mana | "Fire a long range laser beam." |
| R | Mini Nuke | press with a cursor area reticle | **cursor-placed** area (ground target) | 37.5 s, 40 mana | "Fire a mini nuke at target location." Impact, then a ~4 s damage zone. |

The end-of-segment summary screen (`venator/summary_screen.png`, frames 0260-0268) shows a different keymap: Grenade on E, Slide on SPACE, Ion on L SHIFT, Nuke on Q. It shows the mana costs (20/18/40/40) under the icons and adds "The grenade explodes in a cone if it hits a wall". The in-game cards use the standard keys above.

## 2. Per ability

### Passive: Combat Stim
1. **Input:** none. A knock resets Combat Slide's cooldown.
2. **Aim / 3. reticle / 4. animation / 5. VFX:** not shown. No knock on a hunter happens in the clip.
7. **Numbers:** none on the card.
8. **Role:** a slide refresh on a kill, which keeps the hunter mobile through a fight.

### LMB: HK7R City Sweeper (frames 0007-0036, 0075-0110, 0149-0160)
1. **Input:** hold to fire continuously. He fires while walking (0007-0023) and while sliding (0149-0151).
2. **Aim:**
   - Direction only, and the shots travel to max range. In 0019-0021 the tracers pass through the cursor reticle and keep going beyond it; in 0012 they run up to and past the cursor.
   - A skillshot: no homing, and the tracers stay on a straight line from the muzzle.
   - The upper body turns to the cursor and the legs keep walking.
   - There is no visible slow while firing.
3. **Reticle:**
   - The cursor is a small white circle with four short crosshair ticks, the same reticle for every ability.
   - While firing, two **green arcs** bracket Ghost left and right ("( )" at about 0.7 bh radius; 0026, 0099). They look like a firing or bloom indicator.
   - A faint, very large circle around the hunter is visible in most frames (0039, 0182). It may be a range ring, but this is unclear.
4. **Animation:** the rifle is shouldered at hip-to-chest height and points at the cursor. Small recoil kicks show in the muzzle flash only. Nothing else stands out.
5. **VFX:**
   - Muzzle: a yellow-green starburst with a green crescent swoosh (0020, 0026).
   - Tracers: long thin yellow-green bolts, each about 1.5 bh long with a fading tail (0012, 0020).
   - The target flashes solid red on each hit (0027-0033).
   - Damage numbers are small and white. **While the target is Dazed they turn large and yellow**, crit style (0077: 117/120/123; 0101-0106: 102-111).
7. **Numbers:**
   - A sustained string decays from 57-60 (0027) through 45 (0029) to 30-36 (0031-0035), about 50% over about 1.4 s.
   - On a Dazed target the hits read 102-111 at the start of a string, about 1.9x. The numbers dropped back to 30 the moment the Daze ended (0107-0109). Decay may be suspended during the Daze, or it may just add a large multiplier; unclear.

### RMB: Spike Grenade (frames 0037-0074 on a dummy and a wall; 0088-0106 stick on a dummy)
1. **Input:**
   - While the button is held, an aim lane shows. In 0037-0040 and 0090-0094 the lane is visible for about 0.6-1.0 s before the throw. The throw comes on release, or this is quick-cast with an indicator; I can't tell which.
   - One throw per cast. No recast.
2. **Aim:**
   - The lane is a **fixed length, about 5-6 bh**, and does not stop at the cursor (0039: the cursor sits mid-lane; 0094 and `grenade_throw_strip.jpg`: the lane runs past the dummy).
   - The grenade follows the lane. On a miss it flew past the cursor (0044-0045: the grenade is beyond the cursor, near the top edge).
   - It sticks to the first enemy (0096-0097) or to a wall (0055).
   - An enemy inside the lane is tinted pink/magenta while aiming (0090-0094: the target highlight).
3. **Reticle / telegraph:**
   - A translucent white rectangular lane about 0.4 bh wide, from the hand to a pointed (arrow) tip (0039, `grenade_throw_strip.jpg` 541.2-541.6).
   - The lane is replaced by a thin single line during the throw.
   - On a wall stick, a **green filled cone (fan, about 100°, about 3.5 bh long) with a cyan outline** shows from the stick point back out the way the grenade came. It shows for about 0.6 s before the blast (0056-0058, 0070-0072). The cone is drawn opposite the incoming direction, so it points back at the thrower.
4. **Animation:**
   - The grenade is held cocked above the right shoulder while aiming (`grenade_throw_strip.jpg` 541.2-541.6: a dark spiked object above the head).
   - On release, a fast overhand throw (541.8). The rifle stays in the left hand.
   - Total commit is about 0.2 s, and he can walk.
5. **VFX:**
   - The projectile is a dark spiked canister with a magenta glow. Flight takes about 0.4 s over about 6 bh (about 15 bh/s), with a slight arc and a magenta smear (0041-0044, 0095).
   - Stuck: it sits on the target's front with a pulsing pink-white glow (0096-0100).
   - Blast on an enemy: a purple-magenta spiky burst with a dome flash. Then **Dazed: a magenta swirl and sparkles around the target for about 1.2 s** (0101-0106).
   - Wall blast: a purple torus or dome at the wall point, magenta spikes along the cone, and a big knock (0059, 0073).
6. **Sound:** none in the footage.
7. **Numbers:**
   - Card: 5.4 s and 20 mana.
   - **Fuse after sticking: about 0.8-1.0 s.** Stuck at 0096-0097, blast at 0101. On a wall: stuck at 0055, blast at 0059 (0.8 s).
   - Blast damage is 243 (0073-0074, 0101).
   - Daze lasts about 1.2 s (0101-0106).
   - Wall-cone knock: the dummy was thrown about 3.5 bh **away from the wall, toward Ghost**, in about 0.4 s (0073 → 0077).
8. **Combo:** this is the kit's core. Stick (or wall-cone) → Daze → rifle at about 1.9x for the Daze window (0075-0080, 0098-0106). The wall cone also knocks the target toward Ghost, where the rifle is strongest.

### Shift: Combat Slide (frames 0116-0153)
1. **Input:** press for a short slide, hold for a longer one (card). He **fires the rifle during the slide** (0149-0151).
2. **Aim:** **movement direction, not the cursor.** In 0150-0151 he slides up-left while the cursor and tracers go up-right. No turning to the slide direction: the upper body keeps aiming.
3. **Reticle:** none. A **white ring is left on the ground at the start point** (0136, 0151).
4. **Animation:**
   - A low, feet-first slide with the torso leaning back and the rifle kept up and aimed (0118-0120, 0135-0137).
   - Tap slide: about 3 frames (0.6 s), start to stand (0118 → 0121).
5. **VFX:**
   - A **bright green afterimage silhouette at the start point**, fading to dark green over about 0.4 s.
   - **Purple ribbon trails** from the shoulders back to the afterimage.
   - A brown dust or scrape disc under him (0118, 0135).
   - A spiky cyan burst once (0136); it may belong to the arena.
7. **Numbers:** 7.5 s and 18 mana. Tap distance is roughly 2.5-3.5 bh (the afterimage-to-hunter gap at 0136 and 0151 is about 3 bh while still moving). The long hold variant isn't clearly separable in the clip.

### E: Ion Cannon (frames 0164-0189; `ion_pose_strip.jpg`)
1. **Input:** press. A **cast bar (thin cyan bar over the health bar) fills for about 0.6 s** (555.8 → 556.4 s), then the beam fires. He stands still through the cast.
2. **Aim:** direction. The beam is **a fixed long line** that reaches well past the cursor and the dummy, off screen. In the cliff demo (0176-0189) it crosses a chasm and an island, about 10+ bh, and passes through terrain.
3. **Telegraph:**
   - At cast, a **thick bright white-violet line** is drawn full length at once (0166).
   - Over the cast it **narrows** to a thin yellow-green core line with faint edges (0167-0168).
   - At fire, a **cyan sphere at the muzzle and a flat green horizontal flare** (0169).
4. **Animation:**
   - The rifle is shouldered forward and braced through the cast.
   - On fire, a **white smoke ring bursts around Ghost and he is shoved back about 0.5 bh by recoil** (0170, 556.6 → 556.8 s).
   - Recovery takes about 0.4 s.
5. **VFX:**
   - The beam is thick (about 0.5 bh), green and white with a rainbow-ish edge (0170-0171).
   - It thins and darkens over 0172-0173 and is gone by 0174. Total visible time is about 0.8 s.
7. **Numbers:** 10 s and 40 mana. No damage number was caught on screen.

### R: Mini Nuke (frames 0190-0255; impact 0203 and 0235)
1. **Input:** press. Aiming shows the area at the cursor.
2. **Aim:**
   - **Cursor-placed area.** Nuke 1 was placed on the dummy (0191-0195). Nuke 2 was placed on empty ground away from it (0226-0228).
   - Max range was not reached in the clip.
3. **Reticle:**
   - While aiming, a thin white **circle with four tick marks**, about 1.6 bh radius, at the cursor, plus a thin line from Ghost to the cursor (0194, 0227).
   - At cast, it becomes a **ring of spinning purple glyphs with a cyan rim and a pink heart-shaped core marker**, with a pale light column from the sky (0195-0202).
   - The ring shifts to cyan as the impact nears (0199-0202).
4. **Animation:**
   - The rifle is raised vertically, barrel to the sky (561.8-562.0 s).
   - He fires a shell straight up: a teal and purple column with stacked teal rings (562.2-562.4 s).
   - Then the rifle comes back down. About 0.8 s committed, with no move seen.
5. **VFX:**
   - At impact, a green energy column comes down and the ring turns **yellow-green with green spikes** (0203, 0235). The impact number is 931.
   - Then a lingering **zone: a dark purple disc with green blotches and a yellow-green glyph rim** (0204-0222, 0236-0255). It is `distinctive` (nuke and radiation look).
7. **Numbers:**
   - Card: 37.5 s and 40 mana.
   - Cast to impact: 1.6 s (0195 → 0203) and 1.4 s (0228 → 0235). Launch to impact is about 1.0-1.2 s.
   - The impact hit for 931.
   - The zone ticks 144 (0204-0218) and 115 (0245-0252) every 0.4-0.5 s while a target stands in it.
   - The zone lasts about 4 s (0235 → 0255).

## 3. Key frames (`/home/claude/hero-ref/venator/`)

| File | Caption |
|---|---|
| 0012.jpg | LMB: tracers go to and through the cursor (max-range autos); title card. |
| 0020.jpg | LMB: a bolt beyond the cursor reticle; the muzzle starburst and green crescent. |
| 0031.jpg | LMB string decay: numbers 30-36 after an opening of 57-60. |
| 0039.jpg | RMB aim: a fixed-length white lane with an arrow tip; the cursor is mid-lane. |
| 0045.jpg | RMB miss: the grenade has flown past the cursor (it is not cursor-placed). |
| 0057.jpg | RMB on a wall: the green cone telegraph with a cyan outline, pointing back at Ghost. |
| 0059.jpg | RMB wall blast: a purple dome with magenta spikes. |
| 0073.jpg | Wall blast on a dummy in the cone: 243 damage, the dummy thrown toward Ghost. |
| 0077.jpg | Rifle on a Dazed target: large yellow 117/120/123. |
| 0101.jpg | Stuck-grenade blast (243) and the start of the Daze swirl; yellow 111. |
| 0118.jpg | Combat Slide start: green afterimage, purple ribbons, dust disc. |
| 0150.jpg / 0151.jpg | Sliding one way while shooting another; the white ring at the slide start. |
| 0166.jpg | Ion Cannon: the full-length bright line at cast start. |
| 0170.jpg | Ion Cannon fire: thick green-white beam, smoke ring, recoil. |
| 0182.jpg | Ion Cannon range: across the chasm, through terrain. |
| 0194.jpg | Mini Nuke aim reticle: a ticked circle at the cursor. |
| 0197.jpg | Mini Nuke launch: rifle fired straight up; the glyph ring at the target. |
| 0203.jpg | Mini Nuke impact: green column, yellow-green ring, 931. |
| 0245.jpg | Mini Nuke zone ticking (115) on a second dummy. |
| cards_ingame.png | All 5 in-game ability cards at full resolution. |
| summary_screen.png | The end-of-segment summary: passive text and mana. |
| grenade_throw_strip.jpg | 541.2-542.2 s: lane, cock, throw, flight, stick. |
| ion_pose_strip.jpg | 555.8-557.4 s: cast bar, charge orb, recoil smoke, fade. |

## 4. Gaps against ours (ranked by how much they change the feel)

1. **`numbers` / `mechanic`: the Daze payoff on the rifle is far weaker in ours.**
   - Source: a Dazed target takes about 1.9x from the rifle (51-60 → 102-111). The yellow crit-style numbers make the window obvious.
   - Ours: Rattled gives +28% (`resource.rattle_k` 0.28 in `content/archetypes/gunslinger.json`, applied in `GunslingerKit.outgoing`).
   - Change: raise to about +80-100%. Show weapon hits on a Rattled target as big yellow numbers (the damage-number call for `src == "shot"` on a Rattled target). Consider pausing `sus_n` decay (`hunter.gd _emit_shot`, the `sustain_loss` line) while the target is Rattled.
2. **`mechanic` / `vfx` / `reticle`: the wall cone has no pre-telegraph and fires instantly.**
   - Source: wall stick, then a green 100° cone with a cyan outline drawn back out for about 0.6-0.8 s, then the blast. Targets in the cone are thrown about 3.5 bh **toward the thrower**.
   - Ours: the wall fuse is 0.85×0.7 = 0.6 s with only the blinking burr, then `m.fx.cone` at detonation.
   - Change, in `_tick_burrs` (the walled branch): spawn a cone telegraph at stick time and hold it until `_detonate`. Make the wall fuse about 0.8 s. Keep `push` large (it is already 7.5, so check that it reads as about 3.5 bh).
2b. **`numbers`: the wall cone is too short and the knock too small.**
   - Source cone: about 3.5 bh long, which is about 6 m; it threw the dummy about 3.5 bh (about 6 m).
   - Ours: `cone_len` 3.8 m with `push` 7.5.
   - Change: `cone_len` to about 6. Tune `push` so a target travels about 6 m (check that `kb` 7.5 gets there).
   - The rest of the ranges convert fine: the grenade lane is 5-6 bh (about 9-11 m, ours 11), Longneedle at 10+ bh is 18+ m (ours 14, so it could be longer), and the slide tap at about 3 bh is about 5 m (ours 3.4).
3. **`numbers`: the fuse is a little short.** Source stick-to-blast is about 0.8-1.0 s; ours is 0.7 (`rmb.burr.fuse`). Make it 0.9.
4. **`aim` / `reticle`: the RMB aim lane.**
   - Source: while RMB is held, a fixed-length white lane (about 0.4 bh wide, arrow tip) to max range, and enemies inside it are tinted magenta. The throw comes on release.
   - Ours: tap and throw instantly along `aim_dir`, with no lane (`fire_rmb`, `rmb.hold` 0.0).
   - Change: add a held aim lane (`tele_lane`) that shows while the button is held and throws on release, plus the target highlight. The max-range-not-cursor behaviour is already right.
5. **`mechanic`: the slide allows shooting on a tap too, and the cooldown is shorter.**
   - Source: fires during any slide, cooldown 7.5 s.
   - Ours: `fires_in_dash()` only on a held slide; `dash.cd` is 11.5.
   - Change: return true for any active `slide`, and set cd to about 8 (the source cooldowns may be level-reduced, so pick a middle value).
6. **`mechanic` / `numbers`: the passive.**
   - This build's Combat Stim is **only "a knock resets Combat Slide"**. Ours adds the Fever omnivamp stacks (from the wiki's Combat Rush), up to 8 × 6%.
   - The owner should decide. The video version is simpler: keep the knock refresh and drop or tone down Fever. Files: `gunslinger_kit.gd` `on_deal`/`add_fever`, and `resource` in the JSON.
7. **`anim` / `mechanic`: Ion Cannon (our Longneedle) timing and recoil.**
   - Source: a 0.6 s cast bar standing still; a smoke ring and about 0.5 bh **recoil shove back** on fire; the beam stays visible about 0.8 s.
   - Ours: a 0.8 s charge at 55% slow (`e.charge`, `e.self_slow`), `m.fx.beam(..., 0.35)`, and no knockback on self.
   - Change: `e.charge` 0.6. Consider standing still (self_slow 1.0, or a short root). Add a self-push along `-d` of about 0.5 m in `_fire_needle`. Lengthen the beam linger to about 0.7 s. Update `gunslinger_e` in `hunter_anim.gd` KMOVES to a 0.6 s brace.
8. **`reticle`: the Longneedle telegraph style.**
   - Source: a thick bright line drawn full length at cast, which **narrows** to a thin core as the cast completes, then a muzzle orb and a flat flare.
   - Ours: a lane with a progress fill (`tele_lane` + `telegraph_progress`).
   - Change: invert to full width shrinking to a thin line (the `_tick_needle` progress mapping), and add a muzzle flash orb at fire.
9. **`numbers`: cooldowns.** Source card: RMB 5.4 s, Shift 7.5 s, E 10 s. Ours at rank 1: 9 / 11.5 / 12. The source is level 9 in the clip, so these are probably reduced, and ours reach 6 / 8.5 / 9 at rank 3. Ranks 2 and 3 look aligned; rank 1 is slower. Low priority.
10. **`vfx`: the Combat Slide identity.** Source: a green afterimage silhouette left at the start, purple ribbon trails, a white ring at the origin, and a dust disc. Ours: `trail: roll` plus dust. Add an afterimage and a start-ring flash in `on_dash` (in our palette).
11. **`vfx`: Dazed status look.** Source: a magenta swirl on the target for the Daze window. Ours: Rattled stars (`KitStatus "rat"`). Fine as our own look; just make sure it reads clearly for the whole 1.2 s.
12. **`anim`: the grenade throw.** Source: cocked above the shoulder **while aiming**, then an overhand throw. Ours: `gunslinger_rmb` has a 0.14 s cock and a lob. With the hold-to-aim change in gap 4, hold the cocked pose while the button is held.
13. **`mechanic`: R (Mini Nuke).** It is dropped in ours, as the project rule requires (R is the Boki Merge). If anything is folded in, the readable part is a cursor-placed area with a 1.4-1.6 s delay and a 4 s zone. It is not needed for the loop. No change suggested.
14. **`numbers`: mana.** The source abilities cost mana (20/18/40/40). Ours have no mana. No change; noted for completeness.

## 5. Rename: places the old display name "Marlowe" appears (player-facing first)
- `content/archetypes/gunslinger.json` `"name": "Marlowe"`. This drives the kit card, the title screen and the HUD.
- `scripts/match/hero_kit.gd:17` `{"name": "Marlowe", ...}`.
- The gen_wiki output: `docs/wiki/Class-Marlowe.md` (title and file name), `docs/wiki/_Sidebar.md:10`, `docs/wiki/Classes.md:8,41,57,74`, `docs/wiki/Home.md:22` and `docs/wiki/Weapons.md:21`. Regenerate with `tools/gen_wiki.py` after the JSON change.
- The sfx label comment: `tools/gen_hero_sfx.py:6,61` ("Marlowe's payoff").
- Internal comments and docs (not player-facing):
  - `docs/heroes/gunslinger.md:1`, `docs/ARCHETYPES.md:1180-1201`, `docs/ROADMAP.md:11`
  - `scripts/arch/kits/gunslinger_kit.gd:3`, `scripts/arch/kit_status.gd:7`, `scripts/arch/hero_demo.gd:3`
  - `scripts/match/arena_demo.gd:14,199`, `scripts/match/hero_gear.gd:368`, `scripts/match/hunter_anim.gd:1173`, `scripts/match/models.gd:1675`
  - `tools/arena_check.gd:118`, `tools/hero_combo_check.gd:3`, `tools/archetype_check.gd:120,176,736`
- No `translations/` hits.

## 6. Open questions
- Does RMB throw on release (hold to aim), or is the lane a quick-cast indicator? The clip shows the lane up for 0.6-1.0 s before each throw.
- What happens to a grenade that hits nothing (0045: it flew past the cursor off screen)? Does it fizzle, or land and blast?
- Press-versus-hold slide distances aren't separable. Is the rifle fire rate truly the "0.3s" on the card (a burst interval?) or about 8-10 rounds/s? At 5 fps it can't be resolved.
- Ion Cannon damage and width weren't caught; does it pierce several targets?
- Is Daze a stun or only a damage-taken mark? The dummy can't show it.
- Combat Stim's knock reset isn't demonstrated, and no knock happens in the clip.
- The large faint circle around Ghost: a range ring, or arena art?
