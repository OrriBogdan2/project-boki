# Owner playtest review, 2026-11-03 (sync75 on his PC). Running list; more items will be added
Each item says which branch fixes it. Build on main sync75 or later. Use Sonnet. Keep fixes small, each with a check.

## 1. Venator's grenade (kit fix → ext/kitdata-vireo-venator, or a new ext/fix-venator-nade from main)
- **On a direct hit to a hunter:** it damages them and applies the damage-taken debuff (Dazed: they take more damage). It does NOT need to explode in a cone on a person, but it must hurt and debuff. Today it reads as passing through and only hitting walls.
- **On a wall or the ground:** it explodes in the visible cone as now, and **everyone hit by the cone also gets the same debuff**.
- Asserts: direct hit means damage plus debuff; wall cone means damage plus debuff on everyone in the cone; the debuff raises damage taken by the source's ratio (see the data in briefs/supervive-data/).

## 2. No ambiguous one-block walls (map design → ext/mapclean, from main)
- In the training area, a grenade thrown past a 1-block wall hit the wall unexpectedly. The owner wants no uncertainty: throwables and shots should go where you expect.
- **Remove isolated 1-tile (and tiny 1×2) wall or obstacle pieces** from the training area, arena and practice spaces, and from The Hollow Crown (generator: tools/make_hollowcrown.py; never hand-edit the JSON). Keep cover deliberate: larger, readable walls and structures placed with intent (lanes, cover lines, landmarks).
- Ruins or rubble decoration can stay only if it has **no collision** for projectiles, or is clearly big enough to read as a wall.
- Asserts: no wall or obstacle component smaller than N tiles exists (the check prints any it finds); --drop-check, --extract-check, --cover-check and --bot-sanity-check still pass.
- Screenshots: before and after of the training area and two Hollow Crown spots.

## 3. HUD ability bar: Merge shows on R, and there's no X ultimate tile (MAIN, reserved boki_hud.gd plus hud slots)
- In the owner's build (sync75), the bottom bar shows the Merge slot labelled **R**, and **no tile for the hunter's ultimate on X**. R is reload now. Merge is on T until the C-into-G pass, then on C. The ult is on X.
- Fix: the Merge slot reads `Settings.key_cap("ultimate")`. Add an X ultimate tile in the hunter's own bar, beside E/Shift: the ult icon, a level-6 lock before then, a cooldown sweep, and `key_cap("hunter_ult")`. Drop `BokiHud.r_slot` from the left bar if the right-side Boki box (ext/equal-loadout GripHud) already shows Merge.
- The round-2 reviewer flagged the missing X tile too. Assert in --hudref-check or --keybind-check that every shown key label comes from key_cap, and that an X tile exists for every hunter.

## 4. Venator's Slipstep shows a fake "explosion" (kit fix, same branch as item 1)
- At slide start, scripts/arch/kits/gunslinger_kit.gd (~lines 229–236) draws two expanding rings and a scorched disc at the start point. That's purely cosmetic, with no damage, but it reads like an explosion, and the tooltip says nothing about it. The owner was confused.
- Fix: remove both rings and the disc. Keep the ember after-image (echo), the dust and the skid sound. Optionally add short skid streaks on the ground along the path, low-contrast. Nothing should look like an area effect unless it does something.
- General rule for every kit: **a ring, disc or burst on the ground means gameplay** (damage, area, zone). Purely cosmetic flourishes must not use area-effect shapes.

## 5. Pin's bow: premature shots, a bad wind-up, and a draw readout split off to the side (kit fix, ext/kitdata-pin-bjorn or a new ext/fix-pin-draw from main)
The owner says "SUPERVIVE does this way better." Match the source's behaviour and readability (briefs/hero-ref/pin.md, the reticle and draw sections), with our own look.
- **Premature shots:** sometimes the arrow fires before the player releases. Find and fix every early-release path: an auto-release at full or overdraw, a draw timer firing on its own, input buffering, the hold-to-tap threshold, the perfect-window logic, and the bot/AI code path leaking into the player's. A shot fires only on LMB release (and the source's rule for an overdraw, if it has one: check the data in briefs/supervive-data/). Assert: holding LMB for 5 s never fires until release.
- **The wind-up feels bad:** it needs a clear, smooth draw:
  - the arrow nocks on press (within about 0.05 s)
  - a steady pull-back with the bow arm extended and the string hand travelling back, and the draw stages felt through the pose and a rising sound
  - a satisfying release snap and follow-through, with no hitch or pose pop between stages
  
  Time it to the source's stage timings in pin.md and the data.
- **Readout split to the side:** today the draw lines and charge readout sit offset to one side (the bow hand), which feels disconnected. Like the source, **centre the readout on the aim line**: the two lines converge from Pin toward the cursor symmetrically along the aim direction, merge on a ready stage, and extend past the cursor at full draw. Any stage or perfect cue sits at the cursor or on the aim line, not beside the character. Keep our feathered style and gold flash.
- Screenshots: a strip of the draw from press to release, the readout at each stage, and the perfect release. A check covers no early release, the release only on button up, and the readout centred on the aim line.

## 6. Pin's RMB Heavy Shot doesn't read as a big shot (same branch as item 5)
- When it fires, nothing stands out. In the source, the heavy shot is a big, unmistakable projectile you can't miss. Ours needs the same **readability**, in **Pin's own look**: her palette (teal/gold, not the source's colours) and our own arrow or bolt shape. Don't recreate the source's projectile art.
- Make it clear at gameplay zoom:
  - a large projectile, about 3–4× a normal arrow, with a bright core and a long trail
  - a release burst at the bow, a short screen kick, and a heavier sound than LMB
  - a clear impact: the pin into a wall with a stake/pin visual that stays, and a hit flash on the target
- The telegraph while holding is the RMB lane, already in aimkit; make sure it's clearly visible.
- Screenshots: release, mid-flight and impact (wall pin and body hit), at gameplay zoom. The check asserts that the Heavy Shot spawns its own projectile type, distinct from LMB.

## 7. Dancer still isn't the source in feel (NOTE ONLY; later, not now)
The owner: "fine for now". Dancer plays like a different character from her source. Her dash, and the dash-empowered autos that follow it, are key to the source's identity. Revisit after the resets, using briefs/hero-ref/dancer.md and the game data: the Cartwheel's empowered next shot, the dash-into-auto rhythm, and how the reset feels. Don't start this now.

## 8. No explosions on dashes (owner rule; Dancer now, merge dash for MAIN)
The owner saw an explosion when Dancer dashed, **while not merged**. His rule: "having explosions on dash is generally not a good idea."
- **Dancer (kit fix):** her Cartwheel landing shows a lilac ground ring (thief_kit.gd ~line 468, plus any other ring or burst on vault/land, ~402 and ~236). Replace it with a tight glint at the throwing hand: the "empowered bolt ready" cue, not a ground ring. Check every other burst or ring on her dash path (~236 `m.fx.burst`), and remove anything that reads as a blast. Mention the empowered next bolt in her kit text.
- **Every hunter's dash:** audit all 12 kits' dash and air-dash code for ring, disc or burst effects that aren't gameplay, and remove them (see item 4's rule). A dash that genuinely hits, like Bjorn's 360 spin, keeps its effect.
- **Merged form dash (MAIN, reserved):** merge_form.gd sets the form dash to `"burst"` (an area hit). Per the owner's rule, the main session should replace that with a non-explosive form dash: for example the type's trail, a short haste, or a shield on dash. Flagged in EXT_TO_MAIN.

## 9. Vireo's E: the fling travels away too fast, and the area is a bit big (kit fix)
- The flicked pull/throw sends foes off too quickly. Make it slower and more readable: lower the initial speed, a longer, smoother ease-out, about the same total distance or slightly less. The owner should be able to watch them slide.
- Shrink the area radius a little (about 15–20%, tunable in data); check it against briefs/hero-ref/vireo.md and the game data.
- Assert the new speed curve and radius in the mage combo check.

## 10. Bjorn: the auto attack should reset slightly faster (kit tuning)
- The basic hammer attack (the LMB tap/throw, recall and swing cadence) recovers a bit slowly. Shorten the time between attacks slightly, about 10–15%: recovery frames plus the cooldown or recall time, whichever gates the next auto. Check against the source data in briefs/supervive-data/ and use the data number if it exists. Keep it in data, keep the animation timings consistent (no pose pops), and update the combo check's timing assert.

## 11. Linwick's E (Furnace Cloak): instant, centred on himself, with a small animation (kit fix)
- Today it seems to have a delay and to land where the cursor is. It should **fire instantly on press**, **centred on Linwick** (a self-centred area that pulls in nearby foes and gives him a shield), not at the cursor.
- A **small, quick animation**: a short arms-out or chest-out flare pose (about 0.15–0.25 s) as it fires, plus the shield swirl on him. Any short ring at cast is the real area, so it must match the actual radius exactly.
- Remove any cursor-placed telegraph or aim for E. Check against briefs/hero-ref/linwick.md and the game data for radius, pull and shield numbers.
- Assert: E fires on the press frame, the area is centred on the caster, the pull and shield apply, and there's no cursor dependence.
