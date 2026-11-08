# Re-review (round 2): Ostra, origin/ext/kitfix-breah-ostra @ d1a7bdb9

**Verdict: PASS (minor nits).** All 6 round-1 items are done. The projectiles can now be seen (orb, Settled bolt, Snap bundle), the white placeholders are gone (a black Snap wind-up orb, a dark indigo star-orb lob, a magenta Swollen sphere), and the Trade has an arrival and rune sigils. The owner's Swap is built as specified: she hovers in place, even over the abyss, the circle's contents swap to her origin, and she goes to the target. The ult (Nightwell) matches its reference section. The open points are small: the hover-glide body is shown but not captured moving, her robe and hat read near-white on grass, and a few text and capture nits.

Shots: /home/claude/review-v5/ostra/v2/ (polish/ is current, taken on this head's code, with `_z1` = gameplay zoom and no suffix = close-up). The v2 root files, `anim/` and the `ostra/pair_*` files outside v2 are round-1 shots and stale. Code read via `git show origin/ext/kitfix-breah-ostra:...` (content/archetypes/ostra.json, scripts/arch/kits/ostra_kit.gd, ostra_well.gd, scripts/match/kmoves_stone.gd, docs/heroes/ostra.md).

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Projectiles must be visible | Done. The orb is a violet glass teardrop (0.28 m) with a magenta tail and reads in flight at gameplay zoom. The Settled bolt is a long blue-violet streak. The Snap bundle is a 2.7 m dark-violet crystal bundle in the strip (frame 3); at gameplay zoom the key frame catches only the hand ring, and the stun result shows. | polish/pair_ostra_orb_key_z1.png, pair_ostra_hot_key_z1.png, anim_os_snap_z1.png, pair_ostra_snap_key.png |
| 2 | White where the reference is dark or saturated | Done. The Snap wind-up is an opaque black orb with a pale rim. The Trade lob is a dark indigo star-orb with a violet trail. The Swollen sphere is saturated magenta and reads on grass (it prints "SWOLLEN" twice, above and below, which is cosmetic). | polish/pair_ostra_snap_tele_z1.png, pair_ostra_swap_key_z1.png, pair_ostra_swollen_key_z1.png |
| 3 | Trade arrival and destination | Done. The destination is a rune sigil (a star polygon in a ring) that fills over the flight, teal at the origin and violet at the target. The arrival strip now shows an implode ring, a stretch, a squash and a settle. | polish/pair_ostra_swap_tele_z1.png, anim_os_swap_z1.png, anim_os_arrive_z1.png |
| 4 | Brimseed at full growth | Done. The full drum is a dark indigo swirl with a teal rim and a light column, plus the recast moment, the COLLAPSE pop and GROUNDED. | polish/pair_ostra_seed_full_z1.png, pair_ostra_seed_key.png, pair_ostra_seed_collapse.png |
| 5 | Status word | Done. The swapped foe now reads SLOWED (not DIZZY), and the Snap leaves its word to the stun (STUNNED only). | polish/pair_ostra_swap_hit_z1.png, pair_ostra_snap_hit_z1.png |
| 6 | Retake mislabelled shots, duplicated HUD caption | Done. The wind-up shot shows the rails and the black orb before release, and the caption prints once. | polish/pair_ostra_snap_tele_z1.png, pair_ostra_fan.png |

## Owner overrides (INBOX, 22:40 and 23:40 UTC)
- **Shift never goes in a random direction.** Done. Shift is hold-to-aim, release to lob. A press with no charge is refused with a deny cue, a press during a swap is ignored, and a press in the air does not travel her anywhere (`on_dash` never moves her). Asserted in ostra_combo_check.
- **RMB has 1 charge and visibly stuns.** Done. `charges: 1`, a 0.2 s wind-up, one bundle that stuns the first foe for 0.8-1.8 s by distance flown; STUNNED plus stars on the dummy. polish/pair_ostra_snap_hit.png, pair_ostra_snap_hit_z1.png.
- **The swap (pick a circle, hover, then everything in the circle comes to the origin).** Done, and asserted.
  - She picks a circle: holding Shift shows both ends (her origin and a 1.5 m landing circle at the cursor, up to 12 m); the landing is clamped short of walls, and over the abyss it lands on the last solid ground.
  - She hovers in place while it is in flight (1.8 s, 1.25 s when Swollen): `_hover_at` zeroes her velocity and holds her height, over the abyss too ("she hovers in place while the lantern flies (no fall, no drift)", "keeps the height she hovered at").
  - Then everything in the circle (foes, allies and Boki, each keeping its place in the circle) is sent to where she was, and she goes to the target. "Two units in the circle both end up at her origin" is asserted, and a body owned by another game is moved over Net. Items are not included.
  - Both ends are marked with rune sigils filling through the wait, a link line and chevrons.
  - Evidence: polish/pair_ostra_swap_tele_z1.png, pair_ostra_swap_key_z1.png, pair_ostra_swap_hit_z1.png, anim_os_swap_z1.png. There is no screenshot of the abyss hover itself, only the check.
- **Hover-glide instead of walking.** Built: `KMovesStone.gait("ostra")` is 0.1 (her legs barely walk, and no footstep timing), a 0.3 m hover with a +-0.03 m bob at 0.6 Hz, body scale 0.9, and the hit radius kept at ground level. In the shots she is a footless robe floating over her shadow. No strip captures her gliding while moving.
- **Dash feel x0.85 / x1.15.** Judgement call. Her Trade is not a `travel()` dash, so the multiplier is not applied: it is 12 m and 1.8 s (the source: a lob of about 1.8-2 s). It is a reasonable reading of "aimed moves keep the cursor", but it is not asserted and not documented in docs/heroes/ostra.md. See data pass 6.
- **X is the ult, C is Merge.** Done. Nightwell is on X (`cast_ult()` through HunterKeys.ult_pressed).

## New checks
- **Ultimate (Nightwell).**
  - It matches the reference. A tap puts a pale dome of the exact final size at the cursor (clamped to 10 m, on ground short of walls) that everyone sees for 1.0 s, then the well opens for 3.5 s: 3.6 m wide (5.1 m when Swollen, against the source's 350 to 500 units), stunning every foe inside (or who walks in) once on the catch and drawing it to the middle, with a small tick every 0.1 s. Allies are untouched and she is free to act. Bond pays on the catch.
  - Visuals: a dark violet disc with rotating arms and black debris orbs orbiting the rim, a stunned foe pulled to the middle, STUNNED and BOND +60%. The source's hand-tendril cast was dropped, as the reference advised. The disc and arms are alpha-blended, so they keep their colour on grass.
  - Evidence: polish/pair_ostra_well_tele_z1.png (the pale blue translucent dome at the final size, as in the source), pair_ostra_well_key_z1.png, pair_ostra_well_hit.png, anim_os_well.png, ult/.
- **Body and dashes.** `body.size` 0.9 plus the 0.3 m hover reads as 1.0 total, as the sheet asks. The robe has no legs and its hem trails. The portrait shows a short robed lamplighter with a staff-lantern (ostra/pair_portrait_ostra.png). The Trade is her only mobility, as in the source; the air press does the same Trade.
- **Readability at gameplay zoom.** Good for the Trade (both sigils, the high lob, the SLOWED word), the Swollen sphere, the Settled bolt, the orb, the Brimseed drum and the Nightwell. Weaker: the Snap bundle itself is a one-frame streak at gameplay zoom (STUNNED does the work), and the hover itself is subtle top-down (a small bob and a shadow gap).
- **Colours.** Teal, violet, indigo and magenta. No white defaults on projectiles or areas. The one concern is the character: the tall hat, cape and robe are cream-white, so at gameplay zoom she is the palest body on the grass (polish/pair_ostra_swap_key_z1.png, ostra/pair_portrait_ostra.png). It is an outfit choice, but a teal or violet cape and hat would sit better with the kit's colour language.
- **Bugs and oddities.**
  - The Snap shot overprints "STUNNED" on the training "DPS ... last 13" readout (polish/pair_ostra_snap_key_z1.png). That is the training readout, but offset the word.
  - The HUD hero portrait is cropped to a white collar and hat brim, so it doesn't show a face (every Ostra gameplay shot). Check `hud.gd` portrait framing for the hover or tall-hat offset.
  - The ground label reads "Heavy dummy" and the training banner text overlaps the top right; both are arena staging.
- **Hard-coded keys.** None for X, R or C. Two letters remain in player text, both in ostra.json and its wiki page: the Brimseed desc says "press E again", and the Trade desc says "Hold Shift to see both ends" (lines 61 and 113). They match main's convention (the Dancer review flagged the same "Press E again"), but should go through `Settings.key_cap` if main wants all key text rebindable. The kit card tiles and the Merge row use `key_cap`.
- **Clean room.** OK. Our own look: a lamplighter with a tall hat, a caped robe, a lantern on a staff, teal and violet, glass orbs, star-orbs, rune sigils and a swirling indigo drum. Names and effects (Tether Lantern, Shard Snap, Lantern Trade, Brimseed, Nightwell) are ours. The source's tendril cast was dropped.

## Data pass (from the owner's kit_comparison, ostra section; does not block this verdict)
1. **The swap** now moves foes, allies and Boki, so that item is closed. Items are not included.
2. **The seed still pops by itself** at 6.5 s and Grounds everyone for 1 s (ostra.json `ground: 1.0`, `grow 6.5`). The source detonates on reactivation; the reference lists auto-detonation as an open question, and the rank-3 "-2 s" is missing.
3. **Void Snap.** The move-speed boost on cast and impact is still missing (no `boost` in ostra.json). The stun scaling with distance is built.
4. **Passive.** The 20% knock heal is built but not in the source's tooltip. The floating part of Hands of Fate (no footsteps, avoids ground hazards) is only visual: she hovers but is still hurt by ground hazards.
5. **Singularity / Black Hole** is now its own X (Nightwell), so that comparison item is closed. Numbers: 64 s against 58.3 s, a tick of 0.16 against the source's 2.5 per 0.1 s (about 87.5 over 3.5 s), and Swollen widens it to 5.1 m as in the sheet.
6. **Trade timing.** The sheet gives about 2 s (Empowered 1.25 s) and ours is 1.8 s (1.25 s); with the global dash feel x1.15 it would be 2.07 s and 10.2 m. Decide whether it is scaled.

## Fix list
None blocking. Nits, in order:
1. **Outfit colour.** Tint the hat and cape teal or violet (or at least a darker cream) so she doesn't read white on the grass.
2. **Capture the hover-glide.** Add a short strip of her moving (the hem trail and the bob) and one of the abyss hover during a Trade, since only the check proves it.
3. **Snap bundle at gameplay zoom.** Retime the key frame so the 2.7 m bundle is in flight, not only the hand ring.
4. **Text.** Route "press E again" and "Hold Shift" in ostra.json (and the regenerated wiki) through the key-cap names. Remove the doubled "SWOLLEN" label, and offset STUNNED from the training readout.
5. **Portrait framing.** Fix the HUD portrait crop so her face shows.
6. **Plate height.** ostra.json sets no `plate_offset`, and she hovers 0.3 m. Converge on `HudPlate.plate_offset(h)` when merging (INBOX 02:30).
