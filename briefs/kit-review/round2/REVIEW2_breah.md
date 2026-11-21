# Re-review (round 2): Breah (`dolm`), origin/ext/kitfix-breah-ostra @ d1a7bdb9

**Verdict: PASS (minor nits).** All 7 round-1 items are done or mostly done. The ranges are now at the source's scale, the slam has a molten starburst and crater, and the Stone Row rocks are jagged basalt with cooling cracks. The owner's overrides are all met: climbable rocks, rocks flung by punches, LMB as a hold, and the dash as a leap with a rock. The ult (Basalt Spine) matches its reference section. The open points are small: the boulder in flight and a launched rock in flight still aren't caught at gameplay zoom, the throw and sense strips are still quiet, and a few text and capture nits.

Shots: /home/claude/review-v5/breah/v2/ (polish/ is current, taken on this head's code, with `_z1` = gameplay zoom and no suffix = close-up). The v2 root files, `after_*`, `before_*` and `anim/` are round-1 shots and stale, and so is the kit card `after_pair_card_dolm.png` (it still says "Rubble Rush", shows no X tile, and prints "X reset"). Code read via `git show origin/ext/kitfix-breah-ostra:...` (content/archetypes/dolm.json, scripts/arch/kits/dolm_kit.gd, scripts/match/kmoves_stone.gd, docs/heroes/dolm.md).

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Spatial scale about 0.6x the source | Done. dolm.json: slam radius [3.6, 4.5], core [0.9, 1.8], reach 2.0, Row dist 3.4 / gap 2.4 (about 5 m span), punch lane 4.2 x 1.8, X ridge 19.8 m. The doc's scale line now reads 1 bh = 1.8 m for gameplay and visuals alike. The slam circle at gameplay zoom is about 9 m across and clearly readable. | polish/pair_breah_slam_tele_z1.png; dolm.json; docs/heroes/dolm.md:32 |
| 2 | Slam impact was a generic white disc | Done. A molten orange starburst with flying rock chips, a dust ring at the edge, then a dark-red cracked crater that holds for about 1 s, with STUNNED. The charge fists are molten orange-yellow, not white (the shared charge orb is replaced by her own fists via `charge_orb()`). The starburst core is a pale yellow-cream disc for a frame or two. | polish/pair_breah_slam_hit_z1.png, anim_br_slam_z1.png, anim_br_slam.png |
| 3 | Animations that barely move | Mostly done. Raise: a rear-up, a slam down, then a heave, clear in the strip. Lunge: a real body drive with the fists thrown out. Dash, slam and punch strips read. **Not fixed:** the throw frames 3-4 are identical and the arm motion is small; the sense strip is 5 near-identical crouched frames (it is a held pose, so tolerable). | polish/anim_br_raise.png, anim_br_lunge.png, anim_br_throw.png, anim_br_sense.png |
| 4 | Stone Row look and tell | Done. Jagged, leaning basalt columns with thin molten cracks that cool, and a red-orange ground flash with spike lines at each spot before the rise. They read as rock, not coins. | polish/pair_breah_row_tele_z1.png, pair_breah_row_hit_z1.png |
| 5 | Boulder and launched rocks in flight | Partial. The tap boulder is a small orange blob on the dummy side at gameplay zoom, and the red ring plus orange burst on impact reads. No frame catches a punched rock in flight as a flaming boulder: the pay shot shows two rocks left standing and 24 damage only; the ROCKFALL + SHRED burst is in the dash shot. | polish/pair_breah_throw_key_z1.png, pair_dolm_pay_z1.png, pair_breah_dash_rock_z1.png |
| 6 | Punch impact burst | Done at close-up (dust ring, molten spray, chips). At gameplay zoom it is faint: a small flash and the number. | polish/pair_breah_punch_hit.png, pair_breah_punch_hit_z1.png |
| 7 | Capture hygiene | Done. The HUD caption no longer prints twice, no hover tooltip is in the strips, and the dash roll-on and its burst are in frame. | polish/anim_br_dash_z1.png, pair_breah_dash_hit_z1.png |

## Owner overrides (INBOX, 22:40 and 23:40 UTC)
- **Raised rocks are climbable.** Done. `StoneStand` carries a jump into a standable rock onto its 1.25 m top, and walking into one is blocked; both are asserted in breah_combo_check. Round-1 evidence (breah_row_hit.png, root) shows her standing on a rock.
- **Punching sends rocks flying.** Done. A held punch sweeps every rock in the 4.2 x 1.8 m lane (Rocksweeping, up to 12) and a slam launches them outward; ROCKFALL and SHRED show. See item 5 for the missing in-flight frame.
- **LMB is a hold.** Done. A tap throws the boulder, a hold shows the chevron lane and a cocked fist, and release drives the punch. polish/pair_breah_punch_tele_z1.png, anim_br_punch_z1.png.
- **Dash is a leap with a rock.** Done, and recorded as a deliberate change in docs/heroes/dolm.md:12. The rock bursts up under her, she crouches, leaps in an arc to the cursor (landing circle shown to all, filling through the flight), lands with a crash (8 damage, a shove, a starburst and crater), then the rock comes down 0.14 s after her and rolls on 6 m (12 damage, Shred, a 1.5 s slow). polish/anim_br_dash.png, anim_br_dash_z1.png, pair_breah_dash_hit_z1.png.
- **Dash feel x0.85 / x1.15.** Done. The leap applies `dash_feel()` to distance and time itself (5.0 m x 0.85 = 4.25 m, 0.45 s x 1.15 = 0.52 s; asserted "5m x 0.85"), and the air dash goes through `travel()`. The card text says "about 4m".
- **X is the ult, C is Merge.** Done. Basalt Spine is on X (`cast_ult()` through HunterKeys.ult_pressed). No hard-coded X or C in the player text (see Keys below).

## New checks
- **Ultimate (Basalt Spine).**
  - It matches the reference. Tap puts a ridge at the cursor (clamped to 11 m) across the aim; hold and drag swings it round its centre, and the cursor-press point fixes the centre. A thin pale line with inward chevrons and a centre ring is the caster's telegraph. Molten cracks show along the line for 0.2 s, then the rocks erupt centre-out over 0.4 s, slow foes beside them by 35% for 1 s, and shove anyone on the line aside. The ridge holds 7 s, blocks bodies and shots, and can be climbed. A punch along it launches the whole line, with a 40 damage cap per hunter. Over the abyss it is a 2 m walkway. It is 13 rocks and 19.8 m, against the source's 12 bh (about 21.6 m).
  - Bond: pays through `KinBond.from_ult` with a `breah_<n>` cast id (0.3 per hunter slowed, and per rock launched into a hunter).
  - Visuals: the ridge reads well as a diagonal wall of dark basalt cylinders with glowing orange cracks and bases. The telegraph at gameplay zoom is a pale line with small chevrons and a ring; it matches the source's white line, though it is thin.
  - Evidence: polish/pair_breah_spine_tele_z1.png, pair_breah_spine_hit_z1.png, anim_br_spine_z1.png; ult/breah_ult_impact.png (older, and its frame is flooded with a yellow tint).
- **Body and dashes.**
  - Body: `body.size` 0.97 and `build` 1.2 (the hook is `Arch.body()` in models.gd), hit radius 0.40 kept, gauntlets ride both hands (the "fist" hold). That matches the sheet (0.95-1.0 tall, bulk 1.2). The portrait reads as a short, wide brawler with big tan fists (dolm/pair_portrait_dolm.png). Wide grounded stomps, no bounce.
  - The leap is 4.25 m in 0.52 s after the feel, against the source's 2.5-3 bh (4.5-5.4 m) in 0.45 s; close, and the owner's leap overrides the shape anyway.
- **Readability at gameplay zoom.** Good for the slam (circle, starburst, crater), the Stone Row, the Spine, the leap and its landing circle, and the landing crash. Weaker: the tap boulder in flight, the punch impact (small), and the punch lane, which is a pale grey-white rectangle (polish/pair_breah_punch_tele_z1.png).
- **Colours.** Ochre, molten orange and dark basalt throughout. No white on the projectiles or the areas. The only whites are the thin aim and Spine lines (as in the source) and the lane fill above.
- **Bugs and oddities.**
  - ROCKFALL, SHRED and the damage number stack close together and overlap the training DPS readout in the dash shot (polish/pair_breah_dash_hit_z1.png). Mostly the training readout, but offset them a little.
  - In the slam shot STUNNED is half-hidden by the DPS readout (polish/pair_breah_slam_hit_z1.png).
  - The portrait for the old "Dolm" name is gone; the roster, card and wiki say Breah.
- **Hard-coded keys.** None. dolm.json and docs/wiki/Class-Breah.md name no key letters: the X line says "from level 6" and "hold ... and drag", Merge goes through `Settings.key_cap`, and the kit card tile uses `key_cap("hunter_ult")`. The `window_note` in content/rules/merge_forms.json says "no C", but it is a developer note, not player text (all four branches carry it).
- **Clean room.** OK. Our own look: a quarry-hand with a stone shoulder and molten-cracked basalt gauntlets, ochre and orange, jagged basalt rocks, our own leap and landing crash, and a hand-built chevron lane. Names and effects (Rubble Fists, Quakefall, Stone Row, Rubble Leap, Basalt Spine) are ours.

## Data pass (from the owner's kit_comparison, dolm section; does not block this verdict)
1. **Molten Guard** (the source's core passive: hitting your own rocks with Quake Punch grants a shield) is still not in the base kit. The shield appears only as a rank-3 slam bonus (dolm.json `rank3.sec`).
2. **Slam reset.** The comparison calls it invented, but the reference sheet says the slam resets on a knock or kill; the kit follows the sheet. The owner should confirm which wins.
3. **Landslide.** The source's +1 charge at rank III is missing (ours is "a third further"), and the source cooldown is about 12 s against our 9 s.
4. **Rockwave.** Allies can't hop over friendly rocks.
5. **Cooldowns on X.** Basalt Spine is 45 s (source 35 s, 25 mana); the reference gives it a 12 bh length, ours is 11 bh.
6. **Jump while charging** and **Tetraform** are now built (the leap of 3.2 m, X with tap and drag, the slow and the abyss bridge), so those comparison items are closed.

## Fix list
None blocking. Nits, in order:
1. **Boulder and launched rocks in flight.** Add one gameplay-zoom frame of the tap boulder mid-flight, and one of a punched rock flying as a flaming boulder (retime `pair_dolm_pay` and the throw key). Make the boulder about 0.5 m with a clear ember trail.
2. **Throw and sense strips.** Give the throw frames 3-4 a visible follow-through (a twist and an arm arc), and give Tremor Sense a slow settle into the crouch so the strip isn't five identical frames.
3. **Punch lane colour.** Tint the lane a molten orange (low alpha) instead of the pale grey-white, and strengthen the gameplay-zoom fist impact (a bigger ring and spray).
4. **Status words.** Offset ROCKFALL, SHRED and the damage number so they don't stack on each other or on the DPS readout.
5. **Retake the kit card** on this head (the Rubble Leap, the X tile and "Backspace reset").
6. **Plate height.** dolm.json sets no `plate_offset`. Converge on `HudPlate.plate_offset(h)` when merging (INBOX 02:30).
