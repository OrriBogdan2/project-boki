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

## 12. Tamsin: only the skate, no separate fast dash, and more ice under her (kit fix)
- The owner sees **two** movement abilities: a fast dash **and** the skate. She should have **only the skate** (Rinkrun) on Shift.
  - Remove the separate dash: the tap dash, the air "usual long dash" fallback in rimewright.json and kit code, and any class dash still bound for her.
  - **In the air:** follow the source data in briefs/supervive-data/ if it says what Celeste does. Otherwise, pressing Shift in the air buffers the skate to start on landing; there's no air dash.
  - Update the kit text and any dash charges or pips shown in the HUD for her.
- **Make the skate read clearly:**
  - ice forming under her as she goes: small slabs or plates that appear under her feet and fade behind her as a trail
  - spray off her edges on turns
  - a frost sheen at the contact point
  
  Our own look, pooled effects. It has to be obvious she's skating on ice she makes, not sliding or dashing.
- **Assert:** Tamsin has no dash besides the skate (no `travel()` dash on Shift tap), the air press doesn't dash, and the trail emits while skating.

## 13. Tamsin's RMB (Ice Spear) and her wall (kit fix, same branch as item 12)
- **The RMB is too fast and doesn't feel impactful.**
  - Slow the spear's flight so you can see it travel; check the speed against briefs/hero-ref/tamsin.md and the data.
  - Give it weight: a wind-up pose (raise the spear, then throw), a heavier throw sound, and a big ice-blue spear with a frosty trail.
  - On landing: a shard burst, the slow-zone ring appearing (the real radius), a chill puff, a small screen kick if it's near, and the delayed detonation as the big hit, with a strong shatter effect and sound.
  - Use our own look.
- **The wall doesn't go out far enough.** Increase how far Rink Wall travels or slides out (distance and time). Match the source data if it exists; otherwise about +40–60%. It should still start close and widen as it slides, as specced.
- **Assert:** spear speed, wall travel distance, and the detonation timing.
- **Screenshots:** the spear in flight, the landing, the detonation, and the wall at full extension.

## 14. Breah's RMB (Quakefall): review it against the source (owner: "you should review this")
The owner sees Breah move forward in an animation on RMB, and thinks it creates a rock.
- **Intended (source):** hold RMB to charge a slam; on release she does a **short hop forward** (~1–1.5 body heights) into a circular slam. The centre stuns, and a sweet-spot ring grows while charging. Jumping while charging is a longer forward leap. A short hop is correct; a long lunge is not.
- **Not in the source RMB:** spawning a rock. Find out whether the slam creates or raises a rock. If it does, remove it; rocks come from E (Stone Row) and the dash (the leap with a rock). If what the owner saw was the dash's rock, make the RMB look clearly different from the dash: a hop and slam, not a leap with a rock.
- **Also from the game data** (kit_comparison.md, Dolm section; check whether ext/kitdata-breah-ostra d0d045e already covers it):
  - make "punching your rocks grants a shield" (Molten Guard) the base passive
  - remove the invented slam reset on knock or kill
  - jumping while charging leaps forward, as in the source
- **Deliver:** a short written verdict in this file under item 14 (what RMB does now vs the source, and what changed), plus a 4–6 frame strip of the RMB at gameplay zoom. Assert in the combo check: hop distance, no rock spawned by RMB, and the sweet-spot stun.

## 15. Breah's ultimate (X, Basalt Spine): rocks, not land; narrower; not over the abyss (kit fix, same branch as item 14)
- **Source behaviour (owner):** the ult raises a line of **rocks** that Breah can then **punch at people**, using the same rock entities as her E (Stone Row) and her punch-sends-rocks-flying LMB. Ours mostly makes **land or terrain**. Change it so the ult raises real rocks: punchable and climbable, blocking shots, with the same rules as her other rocks. That ties her ult into her core loop (raise rocks, punch them at people, gain shield from Molten Guard).
- **Too wide:** narrow the line's footprint (the width and depth of the raised area) to about one rock deep. Use the source data for length and count if it exists, otherwise keep today's length.
- **Can be cast over the abyss:** it mustn't be. Only solid ground counts. Clip the rock line at abyss edges, so no rocks spawn over the void, and remove the terrain-over-abyss bridge behaviour from the ult, including the rank-3 bridge idea. If the whole line would be over the abyss, the cast is refused with a small "no ground" cue.
- Keep the hold-and-drag rotation and the near-to-far eruption look, which match the reference.
- **Assert:** the ult spawns N rock entities that LMB can punch; there's no walkable terrain over the abyss; the line clips at edges; and a cast fully over the abyss is refused.

## 16. Ostra's ultimate (X, Nightwell): lock him into the cast animation (kit fix)
- While casting the ult, Ostra must be **locked** into his cast animation: no moving, no other abilities or attacks, and no turning after the commit point. The lock lasts through the cast and channel window the source uses (check briefs/hero-ref/ostra.md "Ultimate" and the data). Release him when the cast ends.
- Give the cast a clear, committed pose: both hands raised or drawing inward as the vortex forms, a short wind-up, then holding the pose while it pulls. The lock should read as deliberate.
- Interrupts: stuns or knocks behave per the source; if the data doesn't say, a hard CC cancels it. Clean up through `_drop_holds()` if a merge starts.
- **Assert:** during the cast window, movement input doesn't move him, other ability presses are ignored, and he's free again right after.

## 17. Ostra's Shift (swap): slow movement allowed while it's in flight, height held (kit fix)
- This refines the earlier "hovers in place" note. While the swap is in flight (from the cast until the swap resolves), Ostra **can move, but very slowly**: about 15–25% of run speed, tunable in data, per the source if the data has it.
- **He keeps his height (z) the whole time:** no falling. Over the abyss he hovers at his height and drifts slowly. Gravity resumes only after the swap resolves.
- The swap still resolves to the target circle and his origin as specced (everything in the circle goes to where he was). Decide per the source whether "origin" means where he cast or where he drifted to. Default: **where he is when it resolves**, so the slow drift matters. Note which you chose in docs/heroes/ostra.md.
- **Assert:** speed during the wait is within the slowed band, z stays constant over the abyss, and the swap lands units at the chosen origin.

## 18. Ostra's look: obviously floating, and an eerie jester rather than a nun (model and art, kit pair branch)
- **Floating has to read:** below the robe, replace the feet or hem-on-ground with a **wispy, smoky tail** that trails and curls behind him as he glides. Use a soft dark-violet wisp with faint motes. Add a faint shadow gap between him and the ground, and a gentle bob. It should be obvious at a glance that he never touches the ground.
- **Character feel:** change his costume from the robe-and-hood "nun" read to an **eerie jester / unsettling mask**: a stylised jester or harlequin silhouette (a collar with points, a cap with tails or a horn-like crown, a masked face with an unsettling fixed expression), in his violet palette.
- **Clean room:** this has to be **our own original design**. Don't recreate or approximate the source character's mask, costume or silhouette. Pick a distinctive concept of our own. Example direction: a porcelain theatre mask with a single painted tear and a crescent-moon cap, over layered violet ribbons that dissolve into the wisp. Before modelling, write a short concept note (3–5 bullet points) in docs/heroes/ostra.md, and make sure it doesn't look like the source.
- Update his portrait framing if the head shape changes (`portrait` override in ostra.json). Keep the hitbox at ground level, as specced, so hovering can't dodge low shots.
- **Screenshots:** before and after, gameplay zoom plus close-up, and the portrait.
- This is a one-off ahead of the full character concept pass, at the owner's request.

## 19. Linwick's RMB (Cinder Shot) always flies to max range (kit fix)
- The shot ignores cursor distance and always travels its full length in the aim direction. Remove any cursor clamp (AimKit "at cursor" mode); use the "max range in aim direction" mode. The aim lane shows the full fixed length.
- **Assert:** casting with the cursor at 2 m and at 20 m gives the same travel distance, the max.

## 20. Linwick's ultimate (X, Flue Flight) lasts a bit longer (kit tuning)
- Extend the flight, and with it the molten trail, by about 25–35%, or to the source's duration if the game data has it. Keep his steering and the trail's damage per second, and lengthen the trail's linger to match. Keep it in data, and update the ult assert.

## 21. Zedran's airborne RMB (air slam / Meteor Drop): slower, with a big, noticeable animation (kit fix; the owner says "very key")
- **Too fast:** the drop happens almost instantly. Slow it so the move reads. Give it a brief hang at the top (about 0.15–0.25 s) where he gathers, then a powerful but visible descent (not a teleport), then the impact. Match the source timing from briefs/hero-ref/juggernaut.md (the Air Slam section: ~0.85 s airborne, then ~0.5 s recovery) and the game data, with the slam landing at the cursor as the reference describes.
- **A big, readable animation:**
  - wind-up in the air: he pulls his weapon or fists high overhead, the body tucks, and there's a short spin or flip if it fits
  - a diving pose with flame or speed streaks on the way down
  - a heavy landing: crouch-squash, a ground crack decal, a shock ring at the real stun radius, dust and debris, a screen shake near you, and a heavy impact sound
  - recovery: rising from the crouch over the source's recovery time
- **Telegraph:** a landing marker at the target during the hang, so foes can read it. It's on its own cooldown slot per the data pass.
- **Assert:** airborne duration and recovery are within the source's timings, it lands at the clamped cursor point, the stun ring is the real radius, and the animation phases are present (wind-up, dive, impact, recovery).
- **Screenshots:** a 6-frame strip at gameplay zoom, plus the impact.

## 22. Zedran needs a dedicated feel pass: E (Warchain) control, and the RMB interactions (kit rework; one focused agent)
The owner says the E "doesn't feel controllable enough", compared with the source, and the "interactions with RMB feel weird. His kit needs more work." Do this together with item 21, as one Zedran pass.
- **Warchain (E), match the source's control** (briefs/hero-ref/juggernaut.md, supervive_kits.md, kit_comparison.md, and the 14:07 ET "small mechanics" note: "Brall's tether pull can be steered to the side"):
  - The throw goes where you aim; it hooks a foe or a wall.
  - Reactivate to pull yourself in, matching the source's input (recast vs hold).
  - **While being pulled you can steer sideways** with movement input, curving your arrival point (assert at least 1.5 m of lateral shift, and tune the feel).
  - You can cancel or exit per the source. Arrival keeps momentum into the next action.
  - Make the hooked state readable: a chain line, tension, and a sound.
- **RMB interactions:** list every combination the source has and make each one feel intentional:
  - RMB during the chain pull (the source's spin during the pull)
  - RMB right after arriving
  - the charged lunge into or out of a chain
  - the air slam after a chain launch
  - the Smash sweet spot after a pull
  
  Remove or fix anything that feels like a glitch: lost inputs, a pose snap, double moves, momentum killed for no reason, or an RMB variant firing when another was intended.
  
  Write a short table in docs/heroes/juggernaut.md (state, then RMB, then the result) so the rules are explicit, and match them to the source.
- **Feel:** responsive input buffering (about 0.1 s), clean transitions between his moves with no pose pops, and a readable animation for each variant.
- **Assert** each row of the interaction table in the combo check, plus the steer test. Screenshots or strips: the chain pull with a steer, the spin during the pull, the lunge, and the air slam.
- This is the most feel-critical item on the list. If Sonnet can't get it right in one pass, say so in STATUS.md; don't ship it half-right.
- **Owner addition (01:28):** "his E also doesn't go long enough. His E was very complex and well made in SUPERVIVE; I want the same level."
  - **Range:** match the source's Tether Chain range from the game data (supervive_kits.md / supervive_physics.md, uu → m at 1 uu = 1 cm, then our scale); if it's missing, use the footage measurement in juggernaut.md. Today's range is too short.
  - **Depth:** reproduce the full mechanic set of the source's chain, as documented in the data and the reference, rank upgrades included. That means every state (throwing, hooked to a foe, hooked to a wall, pulling, arriving, cancelled or missed), every interaction (with RMB variants, dash, jump and glide, abyss edges, allies, Boki) and every small mechanic. Write the state machine into docs/heroes/juggernaut.md, then build and assert each transition. Mechanics only; the look stays our own.
  - **Use Opus 5.5 at medium effort for item 22** (the owner wants the source's level of craft on this one). Everything else stays on Sonnet.

## 9b. Vireo's E, an update to item 9: the fling distance is too big as well
The owner: "Joule E sends people too far; it wasn't that drastic in the game." Item 9 said to keep about the same distance; that changes now.
- **Reduce the displacement distance,** matching the source's value from the game data (supervive_kits.md and supervive_physics.md) if it's there. If it isn't, cut it by about 40–50% from today's. The slower, smoother ease-out from item 9 still applies.
- It should read as a modest reposition, not a launch.
- **Assert** the max displacement against the new value.

## 23. Moosh Moosh: an unexplained, loud "explosion" (kit plus Boki audit; same rule as items 4 and 8)
The owner saw an explosion with Moosh Moosh and isn't sure whether it comes from her kit or from a Boki passive. Either way it's **too loud**.
1. **Find out exactly what it is.** Reproduce Moosh Moosh in the arena with and without a Boki, and not merged. Check tender_kit.gd (dash, air glide, casts, Hearthlight, passives) and the Boki side: a companion passive pulse, KinCompanion, the type rider, `pulses` in the merge stat passives. Name the source in your report.
2. **If it's from her kit and it's cosmetic:** remove it (owner rule: no explosions or ground bursts unless they're gameplay, and none on dashes). If it's gameplay, make it clearly readable as what it is, and put it in her tooltip.
3. **If it's from a Boki passive:** don't change the reserved Boki files. Write the change up for the main session: make it much less obnoxious (smaller, softer, its own non-explosion shape in the Boki's type colour), and say what it does in the Boki's info.
4. **Audio:** the explosion sound is too loud. Bring it down relative to the mix, and check other burst or explosion sounds across kits and Boki for the same problem (a short loudness pass). If the cause is in the shared sfx levels (scripts/core/sfx.gd), adjust the category gains; don't edit each call.
- **Assert:** no cosmetic ground burst on Moosh Moosh's dash or glide, and the explosion sound category's peak gain sits under the agreed level.

## 24. Moosh Moosh's dashes: cute animations, and the air dash about 3× the ground dash (kit fix, same branch as item 23)
- **Make both dash animations cute, especially the short ground one.** Moosh Moosh is the small, light, bouncy support. Give the ground dash a quick, endearing move in our own style: for example a little hop-skip or scamper with ears or tail bouncing, squash and stretch on take-off and landing, a tiny puff, and a happy settle, all in about 0.16–0.25 s. Same for the air dash: a playful tuck, spin or glide pose and a soft landing. No harsh streaks, no explosions.
- **Distance ratio:** the air dash should be **roughly 3× the ground dash.** Today the ground dash is ~4.2 m (before dash_feel), and the air glide was set to the source's ~12 m (owner, 02:20 UTC). Keep the ground dash short, and set the air dash so `air ≈ 3 × ground` after the dash_feel multiplier. Keep both values in data, and say in docs/heroes/tender.md which one moved.
- **Assert:** air distance / ground distance is between 2.7 and 3.3; both dashes play their own move (not the shared roll).
- **Screenshots:** a 5-frame strip of each dash at gameplay zoom, plus a close-up.

## 25. Breah's walls: she can nearly hover over and climb them easily; nobody else can (kit fix, Breah branch with items 14/15)
- Breah (only Breah) treats her own raised walls/rocks as climbable: walking into one carries her up and over smoothly, with a light "almost hovering" step-up (no hard stop, no jump needed), and she can stand on top.
- Every other hunter, bot and Boki is still blocked by them exactly as now (walls stay real cover for everyone else). Ownership by caster, so an enemy Breah's walls block an allied Breah? Default: only the wall's own caster climbs it; note it in docs/heroes/dolm.md.
- Check the source data in `briefs/supervive-data/` for Tetra's interaction with her own terrain and follow it if it's there.
- Assert: Breah crosses her own wall in ≤0.6 s without input other than moving; another hunter walking into it is stopped.

## 26. BUG: Breah RMB then glide sends her straight down instead of up (kit fix, same branch; do first)
- Repro from the owner: use RMB (the hop), then press glide/jump during or right after it; she drops straight down instead of rising/gliding.
- Likely the RMB hop's vertical velocity or z state isn't cleared/handed off when the glide starts (compare with ext/airdash-glide's handoff fix). Find the cause, fix it, and add a check: RMB → glide keeps z ≥ the hop's z for the first 0.3 s and enters normal glide.
- Check the same RMB-then-glide sequence on every hero with a hop/leap move (Zedran's air slam, Linwick, Moosh Moosh) and report any that drop.

## 27. Tamsin's ult: no glide during it, and Shift (skate) out of it keeps momentum (kit fix, Tamsin branch with items 12/13)
- **No glide while the ult is active.** If she goes over the abyss during the ult she falls; the only way to save it is to cancel the ult early (then normal glide rules apply). Show the usual glide-blocked feedback, no silent fail.
- **Shift during the ult:** pressing Shift (her skate) while ulting is allowed. It ends or carries through the ult (follow `briefs/supervive-data/` for Celeste if it says which; default: ends the ult) and she keeps moving: the skate starts at her current ult velocity and holds that momentum for a short while (~0.4–0.6 s) before easing to normal skate speed, rather than snapping to a stop.
- Assert: glide input during the ult does nothing; after Shift-out, her speed in the first 0.3 s is ≥ 80% of her speed just before the press.
- Screenshots: a strip of the Shift-out showing her carrying speed.

## 28. Tamsin's RMB is a throw, not a summon (kit fix, do together with item 13)
- Today the spear reads as appearing/summoned at the target. It must be a **throw**: a wind-up with her arm drawn back holding the ice spear, a release on the throw beat, the spear visibly travelling from her hand to the target (an arc or a line, per the source data in `briefs/supervive-data/`), then item 13's heavy landing and big detonation.
- Nothing spawns at the target before the spear arrives, except the gameplay telegraph (landing marker) if the source shows one.
- Assert: the projectile starts at her hand position and its travel time > 0; the impact happens on arrival, not at cast.
- Screenshots: a 5-frame strip from wind-up to impact.

## 29. Bjorn's shield, wall and ult (kit fix, Bjorn branch with item 10)
- **Shield pushes back, and shows it.** Enemies (and their projectiles/dashes, per source data in `briefs/supervive-data/` for Oath) that meet the raised shield are knocked back. While the shield is up, show a forward "bounce" indicator in front of it: a double chevron (>>) or two stacked arcs pointing outward, pulsing outward, in Bjorn's colours. On a push, flash it and play a short thud. This is a gameplay indicator, so it's allowed under the ground-shape rule. Use the source push distance; if none, ~2 m.
- **His wall: bigger and more real.** Scale it up (source size if the data has it; otherwise roughly +40% length and +30% height) and give it a solid, physical look in our own style: stacked stone/timber or forged plates with depth, edges and shading, a dust puff when it rises and crumble chunks when it breaks. No flat translucent slab.
- **Ult trail over the abyss:** the ult's trail/path visual must keep drawing as it extends out over the abyss, not cut off at the ground edge. Draw it at the travel height (floating) where there's no ground.
- Assert: an enemy walking into the raised shield is pushed ≥ the push distance away; the ult trail's drawn length equals its travel length even over abyss cells.
- Screenshots: the shield indicator idle and on a push; the old vs new wall; the ult trail over the abyss.

## 30. Bjorn's held LMB: stops on mantle and other actions; the swing lunges him forward and knocks back (kit fix, Bjorn branch)
- **Cancel rules:** the held LMB (the charged spin/swing) must end the moment he mantles, glides, dashes, gets displaced, or starts another ability. It doesn't keep running through the mantle or after it. Follow the source's cancel list in `briefs/supervive-data/` for Oath where it has one.
- **The swing moves him:** when the held attack swings, Bjorn steps/lunges forward in his facing (the source distance; default ~1.5–2 m over the swing) and the hit **knocks enemies back** along the swing direction (source value; default ~2 m). Don't add a ground ring or burst for it; the body motion plus hit sparks carry it.
- Assert: starting a mantle mid-hold ends the hold within one frame; the swing moves Bjorn ≥1.5 m forward; a dummy hit by it is pushed back.
- Screenshots: a 5-frame strip of the forward swing hitting a dummy.

## 31. Dredge's hook: hold his height, and let him move slowly while it's out (kit fix, Dredge branch)
- **Keep z:** from the hook's cast until it finishes (it misses and retracts, or it hits and the pull completes), Dredge holds his current height. If he's over the abyss or mid-air, he doesn't fall or drop during the hook. Normal gravity and abyss rules resume the moment it ends.
- **Slowed movement while it travels out:** same model as Ostra's Shift (item 17). He can walk at a reduced speed (default 15–25% of run speed; use the source value from `briefs/supervive-data/` for Kingpin if present) while the hook is going out. During the pull-back after a hit, follow the source; default: he stays rooted while he reels the target in.
- Share one small helper with item 17 (for example `CastHold.hover_slow(h, slow, until)` in a new file under scripts/heroes/) instead of two copies.
- Assert: z stays constant (±0.05) from cast to the end of the pull; planar speed during the out-flight is in the slow range; gravity resumes after.

## 32. ALL 12 HEROES: dash → ability interactions must flow like the source (cross-hero pass; high priority)
- Owner: "you need to work on all the dash->ability interactions — supervive makes these flow well."
- For every hero, go through every pair of dash (ground and air) → LMB / RMB / E / ult / Q glove, and the reverse (ability → dash). For each pair, record the source behaviour from `briefs/supervive-data/` first, then the footage (`/home/claude/hero-ref/<hero>.md`, frames): can the ability be pressed during the dash? Does it cancel the dash, buffer to the dash end, or fire mid-dash? Does the dash momentum carry into the ability (lunges, slams, throws)? Does dashing cancel an ability's wind-up or recovery? Are there special dash-variant abilities (e.g. an empowered auto after a dash)?
- Implement it with one shared rule set (a small per-hero data table in content/, read by one helper in a new file), not per-kit special cases. Inputs pressed during a dash must never be silently dropped: buffer them (default 0.15 s) unless the source cancels.
- Write the table to `docs/heroes/dash_interactions.md` (generated by gen_wiki if practical), one row per hero × pair, with the source and ours.
- Assert per hero: every dash → ability pair does what the table says (fires, buffers, or cancels), and no input in the buffer window is lost.
- Split the work by hero pairs as before. Do this after items 26 and 21–22 so it builds on those fixes. Use Sonnet, except Zedran's rows go with item 22 (Opus).

## 33. Dredge's E: a clear fist slam in front of him, with an impact marker (kit fix, Dredge branch with item 31)
- Today it looks awkward. Make it one clear move: a wind-up with his fist raised, then a heavy downward slam into the ground just in front of him, a recoil, then recovery. Read the timing from the source data/footage for Kingpin; default ~0.25 s wind-up, ~0.35 s recovery.
- **Indicator:** during the wind-up, show where it'll hit: the impact area on the ground in front of him, filling as the slam comes down. That's a gameplay telegraph, so it fits the ground-shape rule. On impact: cracks, dust and a short screen shake in that exact area.
- Assert: the hit area matches the drawn indicator; damage lands on the slam frame, not at the cast.
- Screenshots: a 5-frame strip, wind-up to impact.

## 34. NOTE: every hero portrait looks bad (already covered by briefs/specs/CONCEPT_PASS.md)
- Owner: all the portraits look horrible. This is in scope for the character concept pass (after the resets), which includes the portraits. No separate work now. When that pass starts, the portraits are a top deliverable for all 12, not an afterthought: one consistent painted style, readable at HUD size, each matching that hero's new concept. Owner review before merge.

## 35. Dash animations: each hero needs their own, closer to the source (cross-hero pass; pairs with item 32)
- Owner: most dashes look the same (Vireo and Venator are the exceptions). In general, the dash animations need to look more like the source.
- For each hero except Vireo and Venator, study the source's ground and air dash in the footage (`/home/claude/hero-ref/<hero>.md` body studies, frames in /home/claude/svvid) and build a distinct dash move in `HunterAnim` KMOVES that matches its silhouette, posture, timing and weight. Our own art; same motion feel.
- **Dredge example (owner):** a monstrous dash where he lunges forward low, almost clawing or grabbing the ground ahead and hauling himself along: heavy, bestial, knuckles or hands reaching forward. Not exactly that, but very monster-like.
- No shared roll or slide for anyone. Keep the gameplay timing from dash_feel; the animation fits inside it. No explosions or ground rings (item 8 rule).
- Do it per hero together with item 32's dash → ability rows, and item 24 for Moosh Moosh.
- Assert: no two heroes use the same dash move id; each dash's move length fits the dash duration.
- Screenshots: a 5-frame strip per hero, ground and air, next to one matching reference frame description (never copy the frames into the repo).

## 36. Dredge's ult: he can move slowly while charging and firing it (kit fix, Dredge branch with items 31/33)
- While the ult charges (the "loading" phase) and while it fires, Dredge can walk at a reduced speed instead of being rooted. Use the source's move-speed values for Kingpin's ult in `briefs/supervive-data/`; default ~30% of run speed while charging and ~20% while firing. He keeps turning to aim at the cursor throughout.
- Reuse item 31's slowed-cast helper.
- Assert: planar speed during charge and fire is in the slow range (> 0, below run speed); the aim follows the cursor.

## 37. NOTE for the concept pass: stronger personality and differentiation for every hero
- Owner: some heroes don't look differentiated enough; give them all a stronger personality. They're all built on the same main-character base, and that shows.
- In CONCEPT_PASS.md scope: each hero gets a distinct silhouette that reads at gameplay zoom (body proportions, height and bulk, posture, signature headwear or shape), plus their own idle stance, walk, colour identity and attitude in every animation (e.g. Dredge hulking and bestial, Moosh Moosh small and bouncy, Ostra floating and eerie). Allow per-hero body proportions on the shared rig rather than one body for all. Test: the 12 silhouettes filled black, side by side, should each be identifiable.

## 38. DECISION: hunters go by a descriptive class title, not a personal name (rename pass; titles are a draft for owner OK)
- Owner: players name their own character, so drop the hunters' personal names (Dancer, Zedran, Pin...). Use class titles, but not bare generic ones, so there's room for future related hunters (more archers, more gunmen): the pattern is **"<descriptor> <class>"**, like "Green Archer".
- Draft titles (owner to confirm or edit before the rename lands):

  | id | old name | new title |
  |---|---|---|
  | thief | Dancer | Silver Thief |
  | juggernaut | Zedran | Iron Juggernaut |
  | archer | Pin | Teal Archer |
  | bulwark | Bjorn | Oak Bulwark |
  | mage | Vireo | Storm Mage |
  | gunslinger | Venator | Dust Gunslinger |
  | ashwick | Linwick | Ash Pyromancer |
  | dredge | Dredge | Hook Brute |
  | tender | Moosh Moosh | Fox Tender |
  | rimewright | Tamsin | Rime Skater |
  | dolm | Breah | Stone Warden |
  | ostra | Ostra | Void Jester |

- Scope once confirmed: every player-facing string (archetype JSON display names, hero picker, HUD, kit cards, tooltips, gen_wiki output, docs/heroes pages, new-game flow text). Internal ids stay. The player's chosen name labels their hunter in a match; the title shows in the picker and on cards. Save migration isn't needed (ids unchanged). Assert: no old personal name remains in any player-facing string (grep check in tools/).
- **SUPERSEDED by item 39** (owner's final titles and the base-character naming model).

## 39. DECISION (final): class titles, base characters, and new looks for every class
**The naming model (owner):** each class is a slot with a fixed title (e.g. "Dark Archer"). Each class also has a canonical **base character**: a name, male/female, a written personality and our own art. That's our IP, and it lives in the wiki and the class-introduction screens ("the original Dark Archer is known as Pin"). When a player picks a class, their hunter is shown as **"<player name> the <title>"** (e.g. "Orri the Dark Archer"). Hero picker and cards show the title, with the base character's name and portrait in the class intro.

**Final titles and base characters** (names marked *new* are proposals for the owner to OK; genders are proposals to balance the roster 6 F / 5 M / 1 robot):

| id | title (final) | base name | gender | look / personality (owner) |
|---|---|---|---|---|
| thief | Silver Thief | *Sable* (new: "Dancer" now clashes with Icy Dancer) | F | (no change requested; concept pass gives a strong look) |
| archer | Dark Archer | Pin | F | assassin-like archer cloak with some red; a cool-looking character |
| juggernaut | Arena King | Zedran | M | spartan look: shirtless or very little clothing |
| bulwark | Frozen Bulwark | Bjorn | M | ice themed; a massive shield; a big man dressed for the cold, frozen outfit |
| mage | Storm Slayer | Vireo | F | badass and revolutionary: tattoos, shows skin, leather jacket, jewellery |
| gunslinger | Hired Gun | Venator | F | marine-like, but a cool marine |
| ashwick | Mad Pyromancer | *Cinder* (new, owner 06:53 UTC: Linwick becomes a woman with a fiery name) | F | salamander-folk woman (owner pick): slim lizard woman with ember-speckled scales, a frilled crest that flares when she casts, a long tail, slit pupils behind cracked goggles; mad-chemist outfit (goggles, apron, bandoliers of flasks) |
| dredge | Broken Abomination | Dredge | robot | a broken robot with corruption and evil energy leaking out; creepy, haunted machine |
| tender | Fox Cub | Moosh Moosh | F | small and fiery like a fox; if another race, a small version of it with red markings and fox features (ears, tail) |
| rimewright | Icy Dancer | Tamsin | F | (no change requested beyond the ice-skater theme) |
| dolm | Rock Elementalist | *Tarek* (new: Breah becomes a man) | M | a young, nimble, darker-skinned rock elementalist with a bandana tied over his eyes |
| ostra | Void Jester | Ostra | M | more menacing, a sinister and grinning jester (builds on item 18) |

**Originality guard (applies to the whole concept pass):** the owner named some outside characters as mood references (a famous animated young elemental monk, a horror-game haunted animatronic, a famous comic-book clown villain). Use them only for mood. Every design must be clearly our own and must **not** carry those characters' signature features: no arrow head or body tattoos, no monk robes in that character's colour scheme, no cartoon animal-mascot robot with a hat and bow tie, no green hair, purple suit or painted scar-smile. If a draft could be mistaken for any of them, redesign it.

**Scope now (small, server, Sonnet; branch ext/class-titles):** change every player-facing string to the titles above, add the "<player> the <title>" label in matches and on the end screen, and add base name + gender + a 2–3 line personality to each content/archetypes/<id>.json and the wiki (gen_wiki). Internal ids stay; no save migration. Add a grep check that no old title/name is used as a player-facing hero label. Display strings only, so it doesn't collide with the kit branches; rebase onto them at merge.
**Scope later (concept pass, after resets):** the looks in the table, items 18, 34 and 37, and portraits. Concepts go to the owner for approval before any modelling.

## 40. Ostra's RMB: slower, with a clear animation (kit fix, Ostra branch with items 16-18)
- Today it's too fast to read. Slow it to the source timing from `briefs/supervive-data/` for Void (wind-up, travel or cast, recovery); if the data lacks it, about +40% total cast time, all in the wind-up and travel.
- One clear move: a readable wind-up pose (hands gathering void energy, the body leaning in), a distinct release beat, the effect visibly travelling or forming from him, and a short recovery. Our own look, in his violet colours.
- Assert: the timing matches the data table; damage lands on the release or impact frame, not at the press.
- Screenshots: a 5-frame strip from wind-up to impact.

## 41. Concept pass notes (owner, 06:55 UTC)
- **Bjorn (Frozen Bulwark):** owner's mood reference is a well-known big, friendly shield-carrying hero from another game. Use it for **mood only**: a huge, warm-hearted, cold-climate protector whose massive shield is the centrepiece. Our own design, e.g. a giant northern ferryman whose shield is the frozen, iron-banded prow of his old ship, with a fur-lined coat, rime-crusted gauntlets and a big laugh in his idle. Must not be mistakable for that character (no copying his face, facial hair style, shield shape or outfit).
- **Ostra and Tamsin** are the two closest to their source heroes today. The concept pass must push both further from the source look; the owner is fine with differences. Ostra follows items 18 and 39 (menacing void jester). Tamsin gets an original ice-skater design (Icy Dancer).
- The rest of the roster already has clear directions in item 39.
- **Bjorn lore (owner, 06:56 UTC):** use the ferryman-with-a-frozen-prow-shield direction, and hint that he's undead, kept going by a ghoulish power. Keep it a hint, not a reveal: the lore suggests he went down with his ship in the ice and came back; his warmth and laugh sit oddly against small signs (frost that never melts on him, no breath in the cold, a faint cold-green glow in the shield's cracks or his eyes in the ult). Put this in his base-character personality text and the wiki.

## 42. BUG: Ostra's Shift can't be cast far away (kit fix, Ostra branch with items 16-18, 40; do early)
- Source behaviour (owner): Shift is castable **anywhere within range**: at the cursor, including over the abyss or on any ground. If the cursor is beyond max range, it casts at **max range along the cursor direction**. It never snaps the target back near him, and no ground or walkable check limits the target.
- Today it ends up near him or refuses far targets. Find the clamp/ground check that causes it and remove it. Keep item 17's behaviour for him during the flight (slowed movement, z held over the abyss).
- Assert: cursor at 0.5× range over the abyss → target at the cursor; cursor at 2× range → target at exactly max range in that direction; an abyss target is accepted.

## 43. Lore and prologue (owner, 07:00 UTC). Lore doc: https://claude.ai/artifact/JbNFft2zZD5okc2mtumx9T (owner's Lore Bible; ext keeps it in sync)
- Story spine: the Wyrm (an all-powerful dragon that takes human shape) ruled from the Crown as an ageless sovereign, sleeping on its hoard. The Wyrmheart at the bottom of the hoard grants one world-changing wish. A thief reached it, the Wyrm woke and broke the land (the existing prologue's Sundering). Fallen Wardens' powers scattered as Mantles; players are Bearers who take up a Mantle ("<name> the <title>"). Everyone races for the Wyrmheart: Menders (repair the world), Claimants (rule it), Free blades. Open-ended roster: new Mantles keep surfacing = new classes.
- **Prologue is too long (owner).** Proposal (pending owner OK; main owns scripts/ui/prologue.gd, so it lands as a small branch after the OK): 7 slides (~54 s) down to 5 (~35 s), reusing the existing scenes:
  1. BEFORE THE FALL: "Once, the sky held one great land, ruled from the Crown by a sovereign who never aged."
  2. THE WAKING: "The sovereign was the Wyrm in human shape, asleep on its hoard. The night a thief reached its heart, it woke."
  3. THE SUNDERING (land breaking + ships fleeing): "It broke the land into a thousand isles. The Wardens who stood against it fell, and their power scattered."
  4. THE BOKI (Boki + homestead): "On the broken isles, survivors found the Boki, and started over."
  5. THE RACE (hunters gliding in): "Somewhere in the ruins lies the Wyrmheart: one wish to remake the world, or rule it. Every hunter wants it. So does the Wyrm."

## 44. Mantles explained, and merge forms look like the original Warden + Boki (owner, 07:50 UTC)
- Lore: a Mantle is dormant until its wearer bonds with a Boki; the Boki awakens it; a Merge wakes it fully and the Bearer takes the original Warden's shape blended with the Boki. In the Lore Bible.
- Prologue slides 3-4 text explains it (S2, ext/prologue-polish).
- Merge forms: main's files; direction sent to main for after the concept pass (needs the base-character looks first).

## 45. DECISION: the Mantle look, 80% the original Warden and 20% you, with near-infinite variation (owner, 07:31 UTC)
- **The rule:** in a match, a Bearer looks like the class's original Warden: their gender, silhouette, outfit, signature pieces and animations (the 80%). The player's own build and features nudge that Warden model (the 20%), so every Bearer is a recognisable variant of the original, never a different character. Lore: the Mantle reshapes its wearer into the Warden's likeness.
- **Character creator (new-game card, editable later at home):** the player makes their own person with continuous sliders and pickers, giving near-infinite combinations:
  - body: height, build/bulk, shoulder width, proportions (head size, limb length);
  - face: face shape, eye shape and size, brow, nose, jaw, a few feature presets to start from;
  - skin tone, hair style and colour, eye colour, facial hair or markings, voice pitch;
  - name (already there).
- **Blend into the Mantle:** each slider maps onto the Warden's own model within a clamped range (default ±10–15% for body sizes, smaller for face shape), so a big player becomes a slightly bigger version of the Warden and a slight player a slighter one. Colour picks tint within the Warden's palette (hair, skin, accent), never replacing signature colours (Pin's red stays red). Gender comes from the Warden.
- **At home (farm/hub)** with no Mantle on, the player appears as their own created person; the Mantle look applies in matches and the hero picker preview. (Owner to confirm; default yes.)
- **Gameplay safety:** hitboxes and hurtboxes stay per class, unaffected by sliders (fairness in PvP); only visuals change. Silhouettes must stay identifiable at gameplay zoom at both slider extremes (check).
- **Data and code:** player appearance saved in the profile as normalised slider values; one new pure function (e.g. `MantleLook.apply(warden_base, player_look) -> model params`) in a new file; Models.hunter takes the result (wiring only; models.gd is main's). Works with today's models now and with the concept-pass models later.
- **Checks:** sliders at min/max for every class stay within the clamp, hitbox unchanged, save/load round trip, silhouettes distinct at extremes; screenshots: one class at 5 slider settings side by side, and one player's look across 4 classes.

## 46. Hitboxes follow size, compressed; a ground circle shows each hunter's hitbox (owner, 16:15 UTC)
- Hitboxes differ by Warden size, but compressed toward the middle so small hunters aren't much harder to hit (the source game didn't make them exactly equal either). Default mapping: hit radius = standard × (0.85 to 1.15), scaled from the Warden's visual size (Moosh Moosh at the low end, Bjorn/Dredge at the high end). Values live in each archetype's existing `hit_r` (Arch.hit_r()); the creator's sliders (item 45) never change it.
- Every hunter has a ground circle under them whose radius equals their hitbox, in team colour (it's gameplay info, so it fits the ground-shape rule). Reuse the existing under-hunter ring; just drive its size from hit_r.
- Assert: every archetype's hit_r is within the 0.85–1.15 band; the drawn circle radius equals hit_r; hit tests use hit_r.

## 47. Dash / stamina bar: a proper fill-up UI (owner asked, 16:58 UTC; spec is ext's default until the owner adds notes)
- Today: dash charges are small yellow pips under the health bar over the hunter (hud_plate.gd) plus dash_strip.gd. They pop on and off; there's no visible refill.
- Build it like the source's readable stamina bar, in our own style: a segmented bar right under the health bar over the hunter, one segment per dash charge; each spent segment visibly **fills back up** (smooth sweep over its recharge time); a short bright flash + soft tick sound when a segment completes; spent segments dimmed, not hidden; a long/air dash shows its own state (e.g. the bar tints cool blue while the air dash is on cooldown); a gentle shake/red flash when you press dash with no charge. Same component in the bottom-left HUD block and for teammates (smaller). Read the values from the kit/class data, never hard-coded.
- Files: hud_plate.gd / dash_strip.gd / hud.gd are main's UI files: build the bar as a new component file (e.g. scripts/ui/stamina_bar.gd) with wiring-only edits, or hand it to main if wiring is more than a few lines.
- Checks: bar segments = charges for every hunter; fill fraction matches the recharge timer; flash fires on completion. Screenshots: a 6-frame strip of dash, dash, refill, refill-complete flash, empty press.

## 48. Bjorn's ult: he's only planted for the wind-up and slam, then moves while the fissure erupts (owner asked to confirm, 17:19 UTC)
- Footage check (ext, hero-ref bjorn.md, frames f25–f49 of the ult clip at 10 fps): Oath is planted for the wind-up and slam only (f25–f31, ~0.6 s). From the slam onward, while the fissure races down the lane and the cells erupt (~0.8 s more) and the scar lingers, he shifts position: he's free to move. Nothing in the data says he's slowed after the slam.
- Make ours match: root only during the wind-up + slam (~0.4 s wind-up, slam on ~0.6 s), then release him to full movement while the lane erupts. If ours currently holds him for the whole eruption or slows him, remove that. Keep the eruption itself independent of where he walks after.
- Assert: planar speed = 0 during wind-up + slam; ≥ 90% of run speed from ~0.1 s after the slam while the eruption is still running.

## 49. Bjorn's held LMB: a well-timed release launches him forward, with a clear animation, and the momentum carries into a glide (owner, 17:20 UTC; builds on item 30)
- Owner override (the source data/footage show no lunge; the owner wants this): the charged swing has a **timing window**. Releasing in it (default: the 0.18 s after the charge reaches full, flagged by the existing hammer-head glint plus a short ring-free flash on the hammer and a click sound) gives a **perfect swing**: a strong forward launch (default ~4 m over ~0.3 s, vs item 30's ~1.5–2 m for a normal release), bigger knockback, heavier hit-stop and screen shake.
- **Clear animation:** a big wind-up (hammer dragged back, body coiled), the release as a full-body heave that throws his weight forward, feet leaving the ground on a perfect swing, a skid/plant on landing. A normal release keeps the smaller step from item 30.
- **Into a glide:** if the perfect launch carries him off a ledge or he presses glide/jump during it, he goes straight into a glide keeping the launch speed (use the same hand-off as the airdash-glide fix: GLIDE_HANDOFF rules), so it's a movement tool.
- Mantle/ability cancels from item 30 still apply.
- Assert: a release inside the window moves him ≥3.5 m; outside it, ≤2 m; a perfect launch off a ledge enters the glide at ≥70% of launch speed. Screenshots: normal vs perfect swing strips, and the swing-into-glide strip.

## 50. RULE: almost no screen shake, and none from your own actions (owner, 18:04 UTC)
- Owner: "I don't like screen shake in general; it should be used very little, especially self-caused."
- **Your own abilities, dashes, landings and hits never shake your screen.** Show impact with hit-stop (a few frames), hit flashes, sparks, debris, sound and the target's reaction instead.
- Shake only for rare, big things that happen **to** you: a boss slam or a heavy ult landing on/near you, at low strength and very short (≤0.15 s). Everything else: none.
- Add a Settings slider "Screen shake" (0–100%, default 30%) that scales all remaining shake; 0 turns it off.
- This overrides earlier items that asked for shake (33 Dredge E, 49 Bjorn perfect swing, 13 Tamsin spear, the prologue's "screen shake" beat: make that a subtle camera rumble or none).
- Audit: main has ~188 shake references (feel.gd, oomph.gd, effects.gd, ability_fx.gd and most kit files). Route all of them through one helper that knows who caused it, and delete self-caused calls. Assert: no shake on the caster's own camera from any ability of all 12 hunters; total shake time in a scripted 60 s fight stays under a small budget.

## 51. RULE: every ability combos, especially with Shift and jump (owner, 18:04 UTC; extends item 32)
- Owner: "make sure you can jump while using this LMB hold and pair it together; in general I want all the abilities in the game to be able to be combo'd / paired together, especially with Shift or jumping."
- **Default for every hunter and every ability: combine, don't cancel.**
  - Holds and charges (Bjorn's LMB hold, Pin's draw, Breah's charge...) keep charging through a **jump** and a **Shift** dash; release in the air works and keeps your momentum.
  - Any ability can be cast mid-jump and mid-dash, and jump/Shift can be pressed mid-ability to move out of its recovery (where the source allows a cancel, keep that; where the source is silent, allow it).
  - Momentum carries: a jump or dash into an ability keeps its speed; an ability's lunge or launch into a jump or glide keeps its speed (same hand-off as the airdash-glide fix).
  - Only cancel where the source game clearly cancels or it breaks something (a mantle still ends Bjorn's hold, per item 30). Record every exception, with its reason, in the DashFlow data.
- **This supersedes item 30's "dash ends the hold"**: a Shift dash now keeps Bjorn's hold; mantling still ends it.
- Build on item 32's DashFlow: extend its table with `jump` and `hold` rows (jump -> ability, ability -> jump, hold through jump/dash) so it covers every hero × slot × {ground dash, air dash, jump}. --dash-flow-check iterates all of it.
- Assert: for every hunter, every held ability survives a jump and a dash and releases in the air; every ability can be cast mid-jump; jump/Shift during any ability's recovery acts within 0.1 s unless an exception is recorded.

## 52. Every Warden stands with attitude: a signature pose, never straight and generic (owner, 02:41 UTC Nov 4)
- Owner on the Meshy Vex: the in-game model is OK, but the texture/quality is still somewhat low and her design needs to be better (the image-gen agent is improving the base pictures first). And: "she should naturally be in some pose, as should the others, like slightly leaned forward or back; she looks very straight/generic now."
- Each Warden gets a signature stance on the shared rig, used for idle, and blended into run/aim so the attitude never fully drops: spine lean (forward/back), hip shift with weight on one leg, shoulder tilt, head tilt, a characteristic arm/weapon carry, knee bend. Data per Warden (e.g. content/rules/warden_stance.json), applied as pose offsets so it works on today's models and the Meshy models alike.
- Starting points (tune to each concept's personality): Vex rifle on the shoulder, hip cocked, slight back lean, relaxed; Pin hunched forward, bow low, predatory; Zedran chest out, leaning back, chin up; Bjorn wide planted stance, shield forward, slight forward lean; Ostra floating tilted forward, long fingers spread; Moosh Moosh bouncy, weight forward on her toes; Claire poised on one skate, arms graceful; Dredge hunched heavy, arms hanging low; Cinder crouched low, tail curled, flask at the ready; Tarek light, balanced, head tilted listening; Sable coiled, weight back, ready to spring; Vireo swagger, weight on one hip, staff resting on her shoulder.
- Plus a small idle cycle per Warden (breathing, a weight shift, a signature fidget every few seconds).
- Assert: no Warden's idle has a straight spine (lean or hip offset above a threshold), and every Warden's stance differs from the others. Screenshots: all 12 idle side by side at gameplay zoom and close-up.

## 53. Sable: make the dash reset loop feel like the source, and the Bola slows (owner, 18:51 UTC Nov 4)
- Owner: in the source, Shiv's dash resets when her empowered dash-auto hits, infinitely, with a cool flip; Sable should have this. Her RMB slows, and stuns if it hits 2 people in a line.
- **Already on main (S2's audit):** landing the empowered bolt gives the Vault (dash) back at once, and the Bola stuns both foes (+13, TANGLED) when it catches a second one in its lane. So the work is feel and clarity, not new rules:
  1. **The loop must be infinite and obvious:** confirm there's no cap or lockout on chaining Vault -> empowered hit -> Vault, and no input dropped between them (DashFlow buffer). On a reset: the dash pip refills with a bright flash and a crisp chime, a short "RESET" glint at her hand, and the next Vault is instantly available.
  2. **The flip:** the Vault is a stylish flip (a full aerial cartwheel/backflip with the crossbows tucked, wings flaring), clearly different from the old shared roll, and each chained Vault alternates or varies slightly so a loop looks like a routine, not one clip repeated. Our own animation; match the source's timing (data + hero-ref sable/shiv footage).
  3. **Bola slows (owner override on top of the data's Ground):** a single caught foe is Grounded AND slowed (default 30% for the Ground's 1.5 s); two in a line stays the stun + bonus damage. Update the card text.
- Assert: 5 chained Vault -> empowered-hit cycles in a row all reset (no cap); the slow applies on a single catch; a pair still stuns. Screenshots: a strip of a 3-cycle reset chain, and the Bola single vs pair.

## 54. Sable's ult (Encore): a real dance animation, and the source's blade rate (owner, 18:52 UTC Nov 4; with item 53)
- Owner: during the ult she does a dance around herself and everyone in the circle takes damage; the animation must be better. He believes she's slowed during it.
- Footage check (hero-ref dancer.md, R: Death Blossom, frames 0290–0357): the ring follows her and **she walks and fires her LMB freely** the whole 2 s; nothing in the data says she's slowed. **Default: no slow** (source); owner to confirm. If he wants it, make it data (`self_slow`, e.g. 20%).
- **Rate mismatch to fix:** the source flings a blade at each enemy in the ring about every **0.2 s** (~10 per target over 2 s); ours fires every 0.4 s, 5 max. Match the source's cadence and rebalance per-blade damage so the total stays in line with the data (88–108 close, 151–236 at the edge per hit in the footage, scaled to our numbers).
- **Animation: the dance.** While Encore runs, her upper body performs a looping twirl and fling routine (spins, arm sweeps, crossbow flourishes, wings flaring on the beats), layered over her legs so she can still walk and aim; each blade visibly leaves her hand toward its target on the beat. The ring pulses on each volley. Stylish, readable, our own choreography; no screen shake (item 50).
- Assert: blades every ~0.2 s per target; movement and LMB work during it (and the self-slow, if the owner wants it, applies only for the duration). Screenshots: a 6-frame strip of the dance with blades flying.

## 55. Hem (Red Stitch): the draw reticle must work exactly like Myth's (owner, 18:52 UTC Nov 4)
- Owner: "I really want the aimer for the timing for Red Stitch to be exactly like Myth's; I don't like the current look." Replace Hem's current draw/timing reticle with the source's behaviour, frame for frame, from `briefs/hero-ref/pin.md` section "3. Reticle" (frames 0101–0258 in the footage; S2 has the frames on the server):
  1. **Idle:** one faint thin line from the bow to the cursor; the cursor is a small ring with a dot.
  2. **Drawing to Empowered:** two thin lines leave the bow in a **V opening ~25° that closes onto the cursor line** as the charge builds; a bright 4-point star glint rides along the line (~1/3 out). When the V **closes into one bright line**, a flash pops at the bow: Empowered ready.
  3. **Drawing to Supercharged:** the V re-opens and closes again; at the end her body flashes for 1 frame; the line becomes **thicker, bright and extends past the cursor to max range**, with a large 4-point star at the bow. A target under the line gets a glow ring at its feet.
  4. **Overdrawn** (held ~0.4–0.6 s past Supercharged): the line and star dim to a thin pale line (and the shot is weaker, per the data).
  5. **Perfect release:** releasing on the ready frame spawns a **large 4-point star with a soft ring** beside the bow hand (~0.6 bh) for a moment.
  All drawn in world space on the ground plane, thin and clean (no thick UI arcs or side readouts). Timings: Empowered and Supercharged at the source's times (Supercharged ~1.2–1.4 s).
- **Colour:** the source uses pale green/white with a gold perfect-star. Default: same shapes and timing in Hem's own palette (red line, white Supercharged line, gold perfect-star). Owner can say "use the source colours".
- Delete the old reticle code it replaces. Assert: V angle shrinks monotonically to 0 at each stage; the line length switches to max range at Supercharged; overdraw dims it; the perfect window spawns the star. Screenshots: a 6-frame strip idle -> Empowered -> Supercharged -> overdrawn, plus the perfect-release star, side by side with the matching footage frame descriptions (never commit the frames).

## 56. BUG: your own Boki bends your abilities: collision must never ruin a stun, impact or momentum (owner, 18:53 UTC Nov 4)
- Owner: "my pet will make my abilities shoot them the wrong way (like with Hem's RMB); make sure the collision doesn't ruin the stun / impact momentum / effects."
- Rule for every hunter: **your own and allied Boki (and allied hunters) never alter your abilities.** They don't block or deflect your projectiles or skillshots; they don't redirect, stop or absorb a body you knock, impale, pull, launch or carry (the Displace path); a wall-stun or impact still triggers off real walls and terrain only; dash/lunge momentum isn't cut by bumping your own Boki. Enemy Boki behave per the source rules (they can be hit and can block where the source allows).
- Likely causes to check: projectile hit tests that treat the owner's Boki as a hit or blocker (Hem's Impaling Shot carrying the target into or around the Boki), Displace collision resolving against Boki bodies (changing the direction or ending the knock early, losing the wall stun), and character-body push between a hunter and its follower during dashes.
- Fix it once, centrally: a shared "ignore friendly bodies" rule in the projectile/skillshot hit filter and in Displace's collision step (friendly Boki and hunters are pass-through for these), not per-kit patches. Boki movement code is main's (kin_*), so if the fix needs a Boki-side change (e.g. Boki stepping out of an active displacement lane, or collision layers), list it for main.
- Assert, for every hunter's displacing or skillshot ability: with your own Boki standing in the path or next to the target, the projectile reaches the enemy, the displaced enemy's direction and distance match the no-Boki run within a small tolerance, wall-stuns still fire, and your own dash distance is unchanged. Hem's RMB impale into a wall with her Boki in between is the headline case.

## 57. Kael's Warchain: the haul must clearly curve toward where you're looking (owner, 18:54 UTC Nov 4)
- Owner: "if you chain someone and look to the left, you fly somewhat in the direction you're facing; right now it always goes direct."
- Main has the steer (juggernaut.json E: face_k 0.4, steer_max 3.0 m, steer_reach 3.5, steer_rate 7), but in play it reads as a straight line. Make looking aside a strong, visible input:
  - During the haul, your path bends toward your aim/facing direction: a cursor 90° to the side should swing you out by roughly 35–45° of arc (default `face_k` ~1.0, `steer_max` ~6 m), so you land beside or past the target on that side, not on top of it. Movement input steers too and stacks with it (capped).
  - The tether stays taut: you swing around the anchor like a pendulum/slingshot, keeping speed through the curve (no slowdown from turning), and you arrive still moving in the curved direction.
  - Show it: the chain line bends and a faint predicted-arc line appears while you hold aside, so players learn it.
  - Check the source data and footage (`briefs/supervive-data/supervive_kits.md` Brall, `briefs/hero-ref/juggernaut.md`) for the source's steer limit and match it if given; the owner's description wins where they differ.
- Assert: pulling with the cursor 90° left lands ≥3 m left of the straight-line endpoint; the cursor straight ahead still lands direct; speed through the curve stays ≥90% of the straight haul. Screenshots: a top-down strip of a straight haul vs a left-curved haul.

## 55b. CORRECTION to item 55 (owner, 18:56 UTC Nov 4): the source reticle is a FILLING LINE, not a closing V. Owner's description wins over the hero-ref notes.
- While drawing, the aim line **fills from near Hem outward** along the line toward the cursor, like a progress bar laid on the ground.
- A **small circle** sits on the line at the point that marks the perfectly timed shot. When the fill reaches the circle, the circle **flashes**: release then for the perfect shot.
- Keep from item 55 only what fits this: the idle thin line to the cursor; Supercharged extends the line to max range; overdraw dims it; the perfect release gives its burst at the bow. Drop the V-lines and the riding star glint.
- Assert: the fill fraction tracks the draw time; the circle sits at the perfect-timing fraction; the flash fires on the frame the fill reaches it; a release within the window counts as perfect. Screenshots: a strip of the fill growing, reaching and flashing the circle, then the perfect release.

## 58. BUG: Dredge's hook pulls at an off angle while Fused (owner, 18:58 UTC Nov 4)
- Owner: "when I'm fused as Abomination, my hook doesn't pull them to me; it goes at an off angle."
- Expected: while Fused, every hunter ability works exactly as unfused from the Fused body: the hook flies from the Fused body's hand and the hooked target is pulled straight to the Fused body's current position (its centre/front), not to a stale or offset point.
- Likely causes to check: the pull target uses the hunter node's position or a socket from the unfused model while the Fused form is offset or scaled (merge_form body centre ≠ hunter pos); the Fused body's own collision deflecting the pulled target (same family as item 56: friendly bodies must be pass-through for your displacements); the pull direction computed from aim instead of target -> caster.
- Sweep it for all Fused forms × every displacing ability (hooks, pulls, knockbacks, impales, chains): source/destination points come from the live Fused body. Merge-form files are main's: S2 fixes the shared hook/Displace side and lists any merge_form/merge_look change for main.
- Assert: Fused Dredge hooking a dummy at 0°, 45° and 90° pulls it to within 1 m of the Fused body's front, along the straight line; same for each Fused form's pull or knock abilities.

## 59. Breaker's LMB hold SPINS the hammer (owner override, 18:58 UTC Nov 4; reverses S2's parity change e625aa8e)
- Owner: "Oath definitely spins his LMB; the footage notes are wrong." S2's parity pass replaced the hold spin with a dragged-back wind-up based on hero-ref bjorn.md line 13. The owner wins: bring the spin back.
- Hold LMB: Breaker spins the hammer around him (a continuous whirl, the hammer head circling at arm's length, a readable motion trail), building charge while he can walk (keep the source hold-walk speed). Release: the charged forward slam, with item 49's perfect-timing launch on the flash, and items 48/51 (jump/Shift keep the hold; a mantle ends it).
- Whether the spin itself hits people on each revolution is the owner's call (ext is asking). Default until he answers: the spin is the charge motion only; the damage comes on the release slam.
- Keep the Shift 360 Smash as is. Update the card text and docs/heroes/bulwark.md's parity table (note the owner override).
- Assert: holding LMB rotates the hammer continuously (≥1 turn/s); the release still slams forward at the cursor; perfect launch still works. Screenshots: a 6-frame strip of the spin and the release.

## 60. Ostra's LMB: goes through walls, and the longer you wait between shots the bigger and harder the next orb (owner, 18:59 UTC Nov 4)
- Owner: "Void's LMB goes through walls, and holding it longer between hits means a bigger, higher-damage LMB. Fix this."
- Today (ostra.json lmb): after 1.4 s without firing, the next orb is a fixed "primed" bolt (+34% damage, faster, slow 10%, through terrain); otherwise a normal orb that walls stop. It's a binary switch, and it reads as no change.
- Make it a **continuous build-up**: the time since the last shot charges the next orb smoothly from normal to full over the source window (default 1.4 s; check `briefs/supervive-data` Void: 263 -> 353 at full, plus Slow). The orb grows visibly in size and brightness with the charge, its damage scales with it, and at full it also slows. A charge glow on Ostra's hand (or the lantern) shows the build-up, with a soft chime at full.
- **Through walls:** the source data says the strengthened orb goes through terrain. The owner says the LMB goes through walls: follow the owner: every LMB orb passes through walls/terrain (damage still only on hunters, Boki and breakables per the usual rules).
- Assert: damage is monotonic in wait time from 0 to the window and capped after; orb scale tracks the charge; orbs pass a wall between Ostra and a dummy at any charge; a full orb slows. Screenshots: a quick shot vs a full-charge orb side by side, and one passing through a wall.

## 61. Tarek (Cliff Runner) RMB Quakefall: a short hold or a tap, not a long charge (owner, 19:00 UTC Nov 4)
- Owner: "Cliff Runner shouldn't be able to hold RMB that long (it's a short hold or tap). If you hold, it should carry you forward and upwards a bit before slamming. If you tap, it should just stun/hit in front of you in the same circle, but slightly smaller."
- Today (dolm.json rmb): hold up to 1.2 s (`slam.time`), growing radius 3.6–4.5 m, damage 14–30, stun 0.5–1.2 s; tap is a quick hop and slam just ahead.
- New shape:
  - **Tap:** no hop; an immediate slam just in front of him: the same circle as the hold version but slightly smaller (default ~85% of the hold radius), hitting and stunning at the centre. Fast and snappy.
  - **Short hold** (cap the charge at ~0.4–0.5 s; past the cap it fires automatically, no long holding): he hops **forward and up** (default ~2.5 m forward, a modest arc), carrying his run momentum, then slams down at the landing: the full circle, full damage and stun. Movement input during the hop nudges the landing.
  - Keep: jump while holding = the bigger forward leap (data: "Jump while charging to leap forward"), air press = dive slam, spikes/dunks over the abyss, Molten Guard stacks, items 51 combos.
- Update the card, the variants text and docs/heroes/dolm.md (owner override on hold length).
- Assert: the charge never exceeds the cap; tap radius ≈ 0.85 × hold radius with no vertical motion; the hold carries Tarek ≥2 m forward with a rise before the slam. Screenshots: tap strip vs hold strip.

## 62. Claire (Frost Siren) can skate in the air (owner, 19:00 UTC Nov 4; supersedes item 12's "air press buffers the skate to landing")
- Owner: "for some reason Frost Siren can't dash while jumping / in the air; fix this."
- Today (rimewright.json dash): "In the air, press it to buffer the skate: it starts the moment you land" (from item 12). Replace that:
  - Pressed in the air (jumping, falling or gliding), the Skate starts at once: she skates through the air along her current height on a thin ice ribbon she lays under her skates, at skate speed, carving with the move keys, with a gentle descent (default ~1.5 m/s down, so it carries her well over gaps without being flight). It obeys the normal Skate rules: hold to keep going, up to its 1.6 s, release to stop, early stop refunds a share.
  - Over the abyss it carries her across like that; the data's upgrade "creates ice islands when dashing over Abyss" stays the rank upgrade (the ribbon is visual only at base).
  - Ending in the air drops her into normal fall/glide rules; landing mid-skate continues the skate on the ground seamlessly.
  - Combos per item 51: jump during the skate works, darts become beams while skating in the air too.
- Assert: Shift in mid-jump starts moving within one frame at skate speed; over a 6 m abyss gap from a jump she reaches the far side; the descent rate stays within the set value; no buffer-to-landing behaviour remains. Screenshots: a strip of a jump -> air skate across a gap.

## 63. Glider: an overheated glider must still open, and the abyss lift is too fast when low (owner, 19:01 UTC Nov 4)
- Owner: "glider heat still doesn't let me pull the glider for some reason; also it pulls up a little too fast when low in the abyss. Fix both."
- (1) DECISIONS: "An overheated glider still lifts you out of the abyss, at half strength, while it burns." In play, an overheated glider still refuses to deploy. Fix: the glide input always opens the glider, at any heat; overheated it burns you (overheat_dps) and lifts at half strength, but it always comes out. Check every path that can refuse a glide (heat gate, overheat lockout, recover-threshold 40, cooldown after overheat) and remove the refusal.
- (2) The abyss lift is too strong at depth: when you're low in the abyss the climb back up is too fast. Soften the low-altitude lift (FeelConfig glider heat group / abyss lift): e.g. scale lift with depth so it eases in, or cap the vertical speed of the abyss lift lower (default about -30% at the deepest point), keeping the burn cost (heat_lift_multiplier) the same so it still costs real heat. Check the source footage and data in `briefs/supervive-data/supervive_physics.md` for the lift speed.
- Assert: from 100% heat, pressing glide opens it every time; the overheated lift is half the normal lift; the vertical climb speed from the lowest recoverable depth stays under the new cap.

## 64. Claire: Skate -> ult must carry the skate's momentum (owner, 19:01 UTC Nov 4; item 51's rule, not working for her)
- Owner: "dash -> ult with her doesn't carry momentum either."
- Casting the ult while skating (ground or the new air skate, item 62) keeps her current skate velocity and direction going into the ult; it eases over the ult's own movement rules, never snaps to a stop. The reverse already exists (item 27: Shift out of the ult keeps momentum); make both directions symmetric.
- Check her DashFlow row (content/dash_flow/rimewright.json): skate -> X must be "fire" with carry, not "cancel" or "buffer to end".
- Assert: ult cast at full skate speed keeps ≥80% of that planar speed for the first 0.3 s, in the same direction. Do it with item 62.

## 65. Claire's Rimelock: a frozen statue: no turning (owner, 19:02 UTC Nov 4); reconciles item 64
- Owner: "you shouldn't be able to turn your character while she's in ult; she should be a frozen statue during it."
- During Rimelock she's sealed in ice as a statue: facing and pose locked from the cast frame (no turning toward the cursor, no aim tracking, no idle fidget), no other abilities except the ones the ult already allows (the recast to crack early, and Shift out per item 27).
- **With item 64 (momentum):** if cast while skating, the ice statue **slides** along her carried velocity and direction (it's ice on ice), easing to a stop over ~0.5–0.8 s, without steering or turning; once stopped she's rooted as before. Cast while standing: rooted in place at once.
- Assert: her facing and model rotation don't change for the whole ult while the cursor sweeps 360°; a skating cast slides ≥2 m in the skate direction and then holds still. Same branch as items 62/64.

## 66. Cinder (Mad Pyromancer) can't fire her LMB during her ult (owner, 19:02 UTC Nov 4)
- Owner: "pyro girl shouldn't be able to shoot her LMB during ult."
- While her ultimate (Flue Flight, the jetpack flight) is active, LMB does nothing: no flamethrower, no queued shot; the input is ignored (not buffered) and a soft "can't" tick plays on a press. Re-enable the moment the ult ends. Keep whatever the source/data allows during it (Heat Shield E mid-flight stays, per her DashFlow row and the data).
- Update her DashFlow/kit rules and card text. Assert: LMB held through the whole ult deals no damage and spawns no flame; LMB works again on the first frame after it ends.

## 67. Tarek's rocks: taller and more noticeable (owner, 19:05 UTC Nov 4)
- Owner: "rock guy's rocks should be taller and more noticeable."
- Applies to every rock he raises: Stone Row (E), the Rubble Leap rock, and the Basalt Spine ridge (X). Raise them to roughly 1.6–2× their current height (taller than a hunter's head, so they read as real cover from the top-down camera), and make them pop visually: a distinct silhouette (craggy, tapered columns, not smooth blocks), warm rim highlights and an earthy palette that contrasts with the grass, a dust burst and short rumble as they rise, and a crack-and-crumble when they break. A ground shadow under each.
- Gameplay: they still block what they block now (foes, shots); keep the collision footprint the same unless the source data says otherwise; standing/climbing on top (item 25) still works at the new height (adjust the step-up so Tarek climbs them as easily as before, nobody else can).
- Assert: rock top height ≥ 1.6× the old value; Tarek can still climb and stand on one; another hunter still can't. Screenshots: old vs new Stone Row at gameplay zoom.

## 68. Vex's E (Longneedle, the railgun): a wider beam, a pushed-out camera while aiming, aimed where she looks (owner, 19:06 UTC Nov 4)
- Owner: "Vex's E should be wider and give a pushed-out / bigger FOV view when shooting, and aimed in the direction she's looking."
- **Wider:** raise the beam's hit width (default ~1.5–2× the current width) and its visual thickness to match, so it reads as a heavy railgun shot; keep it piercing terrain and everything in the line (data: Arcane Railgun).
- **Camera:** while the E is winding up and firing, the camera eases outward (zoom out ~15–25%) and shifts its framing toward the aim direction so she can see the far end of the beam's range; it eases back after the shot. Smooth in and out (~0.2 s), no shake (item 50). Only the casting player's camera.
- **Aim:** the beam fires along the direction she is aiming/facing at release (cursor direction), and she turns to face the aim throughout the wind-up; the narrowing aim line follows the cursor until the shot, then the beam fires exactly along it.
- Keep: standing still for the wind-up per our data, the hit-a-hunter cooldown refund, the bonus vs Dazed.
- Assert: beam width ≥1.5× old; camera zoom during the cast ≥15% wider and restored within 0.3 s after; the beam's direction equals the aim direction at release (±1°). Screenshots: the wind-up with the pushed-out camera, and the beam.

## 69. Two gloves everywhere: the arena (and every loadout) lets you pick 2 gloves, on Q and V (owner, 19:07 UTC Nov 4)
- Owner: "I should be able to pick 2 gloves in arena / in general, if we are allowing 2 actives, right?" Yes: DECISIONS has "2 gloves, 2 charms" and the keys are Q and V.
- Today the arena (scripts/match/arena.gd: `var glove`, `give_glove`, the L loadout panel "Hunter, Boki, glove") only holds ONE glove, on Q.
- Fix: the arena loadout has two glove slots (Q and V), each pickable from every glove, cooldowns-off covering both; the L panel and its tooltip show both with their key caps (Settings.key_cap). Then sweep every other place a glove is chosen or shown for a single-glove assumption: the home bring-in loadout (equal.json bring rules), the Masks/hero screen, the HUD glove tiles, bots' loadouts, the deathbox/loot equip flow, save fields. Each should support 2 gloves, with a clear rule for picking up a third (swap prompt).
- Assert: in the arena, equipping glove A on Q and glove B on V lets both fire independently; the bring-in loadout accepts two; the HUD shows two glove tiles with Q and V.

## 70. Ryzz (Storm Chaser): slightly faster autos, and a much longer dash (owner, 19:08 UTC Nov 4)
- **Autos a tiny bit faster** (owner: "a little bit too slow, up them by a tiny bit"): content/weapons/coilcaster.json `rate` 0.8 -> 0.72 s between finger bolts (~11% more shots) and bolt `speed` 34 -> 37. Update the card text ("every 0.72s").
- **Dash (Wirerun, Surge in the source) goes much further** (owner: "her dash should go much further"): mage.json dash `dist` [5.0, 8.5] -> about [7.5, 13.0] (tap -> full hold, ~1.5x), keeping the 0.6 s hold, and raise `speed` 32 -> ~40 so the longer run doesn't feel slow. Keep the lane preview and the end ring scaled to the new length; DashFlow and dash_feel unaffected otherwise. DECISIONS already says Vireo/Ryzz dashes further than the rest.
- Assert: the new values in data; a full-hold Wirerun travels ≥12.5 m; the bolt interval is 0.72 s. Data + text only; no new code. Sonnet, quick.

## 71. Ryzz: Skycall flings her charge orbs too far, and an orb pulled toward her should come to her and reset her dash (owner, 19:08 UTC Nov 4)
- Owner: "her E flip on her RMB lightning orb goes too far. If it's in your direction, it should also just flip to you if it's reasonably close enough, to reset your dash."
- Today: Skycall flings caught charge orbs "the same way" as the drag and they become hers.
- Change:
  - **Shorter fling:** orbs flung away (or sideways) travel noticeably less (default ~50–60% of today's distance), so they land where she can use them.
  - **Toward her:** when the drag points toward Ryzz and the orb is within reach (default ≤ 9 m from her), the orb flies all the way to her instead of stopping short; when it reaches her it bursts like a Wirerun through it does, **resetting her Wirerun** (dash) at once, with the usual reset flash and chime (item 53's feedback style).
  - Beyond that reach, a toward-her drag behaves as today (shortened).
- Assert: an orb 6 m away dragged toward her arrives and resets the dash cooldown to 0; one 14 m away does not; away-flings are ≤60% of the old distance.

## 72. Ryzz's ult spreads Static: hitting a foe who has stacks spreads those stacks to everyone hit (owner, 19:09 UTC Nov 4)
- Owner: "hitting someone with stacks with the ult should spread those stacks to everyone."
- Kitefall: when the landing strike hits at least one foe carrying Static, every foe hit by the strike gets the highest Static count among the hit foes (then the ult's own +Static on top, capped at 4 as usual; reaching 4 triggers the sky bolt/Live as normal). Show it: arcs of lightning jump from the stacked foe to the others on impact.
- Assert: ult landing on foes with {3, 0, 1} stacks leaves all three at ≥3 (+ the ult's own stack, capped at 4); with no stacked foe, nothing spreads.

## 73. BUG: Ryzz's Skycall doesn't always push in the dragged direction (owner, 19:09 UTC Nov 4)
- Owner: "E also doesn't always push in the right direction."
- The committed drag direction (the arrow shown when you let go) must be the exact direction everyone inside is moved, every time. Likely causes: the direction re-read from the cursor at the strike (0.8 s later) instead of stored at commit; a tap's "away from you" default computed from Ryzz's position at the strike instead of at commit; small drags (near-zero length) giving a random/unstable direction (needs a minimum length, else use the tap default); per-target directions computed as "away from the circle centre" instead of the shared drag vector; Displace collision bending it (item 56, friendly bodies) or wall slides.
- Fix: store the drag vector at commit; show it as a clear arrow inside the circle for the 0.8 s; apply the same vector to every foe and orb inside; ignore friendly bodies in the displacement.
- Assert: for drags at 8 angles (and a tap), every dummy inside moves within 5° of the committed direction, even if Ryzz moves or the cursor sweeps during the 0.8 s. Same Ryzz branch as items 70–72.

## 74. BUG: Ryzz's Storm Rod adds 1–2 extra Static stacks a moment after the hit (owner, 19:10 UTC Nov 4)
- Owner: "it seems like RMB is giving 1 or 2 extra stacks slowly after; that shouldn't be the case."
- Cause (our data): every foe the Rod hits leaves a **charge orb at the impact that zaps nearby foes with Static** — so the foe just hit, standing in it, gets extra stacks over the next moments.
- Fix: the Rod hit gives exactly **1** Static (like every other source, per the passive). The charge orb must not add Static to anyone on its own; it stays only as a pickup/burst object for Wirerun and Skycall (items 71/73). If the source data says the orb does something else (check `briefs/supervive-data` Joule RMB), follow that, but never passive stacking.
- Assert: a Rod hit on a dummy standing still leaves exactly 1 Static for the following 4 s (no further stacks without another hit). Same Ryzz branch as items 70–73.

## 75. Ostra (Void Jester): move a bit faster while his Shift lantern is in flight (owner, 19:10 UTC Nov 4)
- Owner: "a little too slow during Shift; slightly faster than current is good."
- ostra.json dash `fly_slow` 0.2 (he drifts at 20% of run speed while hovering) -> **0.3**. Update the desc text ("drifting at 30% speed") and item 17's note. Data + text only.
- Assert: planar speed during the lantern flight ≈ 30% of run speed. Sonnet, quick; batch with item 60 (Ostra LMB).

## 76. Weapons look bolted on: seat every .glb weapon in the Warden's hands (owner, 19:33 UTC Nov 4)
- Owner: "the weapons look bolted on / not accurate to the 3D model in general; why?"
- Why (ext read scripts/heroes/warden_glb.gd `_hold_weapon`): the .glb's weapon is pulled out of the Meshy model and re-parented under the **old procedural rig's gun node** (`Rig/Torso/Aim/Gun`, or a hammer pivot), at that node's fixed offset and scale. The skinned body follows the rig bone by bone, but the weapon's grip was never fitted to the new model's hands: so it floats near the hand, at the procedural gun's angle and size, with fingers not closing on it, and on two-handed weapons the second hand isn't on it. The weapon also comes from a separate Meshy pass with its own scale and texel density, so it can look pasted on stylistically.
- Fix, per Hunter (data in warden_look.json, the pipeline in warden_glb.gd):
  1. **Grip fit:** a per-weapon grip transform (position, rotation, scale) so the handle sits inside the hand and matches the art's size relative to the body; authored from the turnaround/splash.
  2. **Hands:** a closed grip pose for the holding hand(s); for two-handed weapons (Vex's rifle, Kael's blade, Breaker's hammer and shield, Hem's bow) an off-hand target on the weapon so the second hand stays on it during aim, run and attacks (simple two-bone IK or a pose offset driven by the weapon).
  3. **Look:** match the weapon's texture density, colours and the Hunter shader/outline to the body, so it reads as one model (re-texture from the art where it's muddy, like the faces pass).
  4. Verify across every kit move: idle, run, aim, fire, the signature attacks (Breaker's spin, Kael's lunge, Hem's draw), so it never clips through the body or detaches.
- Assert: for each Hunter, the weapon's grip point stays within ~3 cm of the hand bone through all KMOVES; two-handed weapons keep the off-hand within tolerance. Screenshots: per Hunter, a close-up of the hands on the weapon (before/after) at idle and mid-attack.

## 76b. Weapons are part of each Warden's design: keep them ON the model, don't pin a separate copy (owner, 19:35 UTC Nov 4; refines item 76)
- Owner: "in some cases the weapon is part of the kit, like with Vex and Kael, actually most of them, so it looks off now. Can you fix this?"
- For most Wardens the weapon is designed as part of the character (Vex's gun on her mechanical arm and shoulder rig, Kael's chained demon blade, Breaker's hammer and shield, Hem's bow, Sable's twin crossbows, Cinder's flame chamber and hose, Ryzz's rod mast, Dredge's hook and claws, Ostra's lantern/props). Pulling it off the Meshy model and pinning it to the old gun node is what makes it look wrong.
- New approach (warden_glb.gd + the Blender step):
  1. **Keep the weapon in the character's .glb, skinned to the bones it belongs to** (the hand and forearm for held weapons; the arm/shoulder for built-in ones like Vex's), so it moves exactly with the body in every animation, at the art's size and angle. Don't re-parent it to `Rig/Torso/Aim/Gun`.
  2. The procedural gun node stays only as an invisible aim/FX reference: kit FX read their points from **empties on the skinned weapon** (muzzle, blade tip, bow string, hook mouth), so shots and trails leave the weapon you see.
  3. Two-handed weapons: weight the weapon to the main hand and keep the off-hand on it with the off-hand target from item 76.
  4. Only weapons that truly change at runtime (Hem's drawn arrow, Breaker's thrown hammer while in flight, Kael's chain while extended) are separate pieces, attached at the skinned weapon's socket for the duration and returned after.
  5. One weapon only: hide the procedural weapon meshes everywhere (already hidden) and make sure no second copy shows in any mode (Fused, Masks screen, portraits).
- Assert: per Hunter, through all KMOVES the weapon stays attached to its bone (no drift, no float), FX spawn within a few cm of the visible muzzle/tip, and only one weapon is drawn. Screenshots: per Hunter, idle + signature attack close-ups, old vs new.

## 77. BUG: a prologue slide's third text line runs off the screen (owner, 22:56 UTC Nov 4)
- Owner: "right now the 3rd line on the video thing goes off screen." A prologue caption wraps to a third line that is cut off at the bottom (likely the longer slide 3/4 captions, or the LORE_MASKS prologue text, at 1280x720 and smaller).
- Fix: the caption box sizes to its text and stays fully on screen at every resolution (anchor from the bottom with a margin, wrap width ~70% of the screen, grow upward); or shorten the lines to two. Check every slide at 1280x720, 1920x1080 and a small window.
- Small; whoever has budget. Not urgent.

## 78. LATER: redo the prologue film: open on an evil deity in human form (owner, 22:56 UTC Nov 4)
- Owner: "I think we need to redo the film to show an evil deity in human form first. All of it is pretty rough. Put that as a note for later."
- Direction for the rebuild (after the resets; with the art pipeline): the film opens on the **evil deity in human form**: the Wyrm-crowned Tyrant / the Wyrm as a human sovereign (DECISIONS + LORE_MASKS) on the Throne, so players meet the villain before the fall. Then the rest of the story beats from LORE_MASKS (the cold open with the girl in chains and the Mask, the Sundering, the Wardens' Masks scattering, the race for the Wyrmheart). Owner verdict on the current film: "pretty rough": plan it as a proper storyboarded short (key art from the image-gen pipeline, camera work, timing) rather than polishing the current scenes.
- Not now: logged for planning after the usage resets.

## 79. The Empty: the void look covers the whole head and body, not just the front of the face (owner, 22:57 UTC Nov 4; follows empty90 in sync91)
- Owner: "the whole face/body should be that void thing, not just the front of it."
- Today (empty90, shaders/void_face.gdshader) the void effect sits only on the front of the face, so from the side, back or above the head and body read as a normal surface.
- Change: the Empty's whole head and body use the void material (the starry, depthless look), from every angle, including the back of the head, neck, hands and body under the outfit's open areas. Outfits and accessories can sit on top as solid pieces. Keep the face marks (eyes, brows, blush) as decals floating on the void face. The look must read at the farm's camera distance (top-down), not only in the creator close-up.
- Check: the creator and farm screenshots from front, side, back and top-down show the void everywhere. Small; whoever has budget.

## 79b. CORRECTION to item 79 (owner, 22:58 UTC Nov 4): keep the face customisation; wrap the body in a shroud; drop skin colour
- Owner: "it's cool that you can change the face shape stuff, but the rest of the body should be in a shroud or something. It's weird you can change the skin colour and it's just plastered on the front for the look."
- **Head:** the whole head is the void (all sides), and the face shape and face marks stay customisable as now, floating on it.
- **Body:** covered by a shroud/cloak (a hooded or draped wrap that hides the body shape, with hands either void or wrapped). No exposed skin anywhere.
- **Creator:** remove the skin colour option. In its place: the shroud's colour (and, if cheap, 2–3 shroud styles or trims). Height, build and Male/Female still shape the silhouette under the shroud.
- Migrate saves: the old skin colour maps to the shroud colour (or a default).
- Supersedes item 79's "void on the body under the outfit".

## 80. The creator's "Motes" row is invisible and unexplained (owner, 22:58 UTC Nov 4)
- Owner: "I don't see what Motes does and don't know what it is."
- What it is (scripts/match/unmasked.gd `_motes`): None / A few / A swarm = 0 / 6 / 18 tiny specks of the face's glow colour drifting up around the head. They are so small and few that they don't read in the creator or in the world.
- Fix (default; the owner may say "just remove it"): rename the row to something self-explanatory, e.g. **"Aura"** (None / Faint / Strong), and make it clearly visible: bigger, brighter specks drifting up and around the head and shoulders (and the shroud from item 79b), with a short tooltip line "Glowing specks that drift around you". Show it in the creator preview at a size you can see. If it still doesn't add anything once visible, remove the row.

## 81. BUG: the Empty's feet clip through the ground (owner, 22:58 UTC Nov 4)
- Owner: "also his feet clip through the ground" (the Empty: creator preview and the farm/town).
- Likely cause: the Empty's "real height" and build scaling (empty90) scales the model from its centre instead of the feet, or the height offset isn't re-applied after scaling, so shorter/taller settings sink the feet. Also check the walk cycle's foot height on uneven ground.
- Fix: scale from a feet-level pivot and keep the soles on the ground for every height/build/gender setting; idle and walk keep the feet on the surface (no sinking). Assert: at min/mid/max height and both builds, the lowest foot vertex is within 2 cm of the ground in idle and across the walk cycle. Do it with items 79b/80 (same Empty files).

## 82. The new-Boki screen: less text, hoverable moves (owner, 22:59 UTC Nov 4)
- Owner: "the moves / bond move need to be hoverable when you get a new pet; right now the screen is too text-heavy and doesn't really say anything."
- Applies to the screen shown when you hatch or catch a new Boki (and the same panel anywhere a Boki's moves are listed).
- Redesign: lead with the Boki itself (big portrait/model, name, species, element, one-line personality). Show each move and the bond (Fusion) move as an **icon tile with its name only**; **hovering (or focusing with a controller) shows a tooltip** with what it does, in one or two plain lines with the key numbers (damage, cooldown, effect), plus the key to use it (Settings.key_cap). No paragraphs on the screen itself.
- The bond move gets a distinct tile (it's the special one) with a short teaser line ("Fuse to unlock: <name>").
- These are Boki UI files (capture_hud / boki_hud / field_book are reserved to main): whoever does it lists the wiring for main, or main does it after its reset.

## 83. The Mask moment must feel epic (owner, 22:59 UTC Nov 4; the in-world Mask moment from empty90)
- Owner: "the mask scene should feel more epic: like it fades to black, then stops, goes back, some sound, etc."
- Stage it as a short cinematic beat (~4–6 s, skippable after the first time):
  1. **Build-up:** the world quiets (music ducks, ambient fades), the camera eases in on you holding the relic; a low swell and a heartbeat.
  2. **The mask rises to the face** in slow motion; a ghostly porcelain face flickers over yours (DECISIONS' put-on beat).
  3. **Cut to black** on contact: a hard silence, a beat of nothing (~0.6–0.8 s).
  4. **A flash of the fallen Hunter:** 2–3 quick memory frames (their splash art / silhouette, a whisper of their voice line) in the black.
  5. **Snap back** to the world with a deep impact sound and a ripple of light: you're now the Warden (the 90% blend), a brief heroic pose, and their name and title on screen ("Vex, the Hired Gun").
  6. Music returns with a short sting in that Hunter's motif.
- Sound: our own sfx (swell, heartbeat, silence, whoosh, impact, sting); no shake (item 50) beyond a subtle camera punch-in.
- Logged for whoever has budget; it touches the empty90 Mask-moment code and audio.

## 84. The dash bar is unclear: show dash like the source does (owner, 23:01 UTC Nov 4; replaces item 47's look)
- Owner: "the dash bar is very unclear; check how SUPERVIVE and other games handle it (I think SUPERVIVE doesn't have one)."
- Research:
  - SUPERVIVE 1.0 (our HUD footage notes, briefs/hero-ref/HUD.md §2): no separate dash bar. Dash (L SHIFT) is one of the ability slots in the bottom bar, same as the others: icon, key label pill, base-cooldown tab. On cooldown the icon goes dark, with a large countdown number and a red frame. The older HUD had a small circular dash/glider gauge on the bottom bar.
  - Other games: Overwatch shows Tracer's blink charges as 3 small pips by the crosshair. Valorant shows ability charges as pips under the icon. Hades and Apex show no dash UI at all and rely on feel and sound.
- Change (default):
  - Make the dash a **normal ability slot** in the bottom bar (Shift key label), with **charge pips on the slot** (one per charge, filling as each recharges) and the same cooldown treatment as the other slots: dark slot, countdown number for the next charge, a flash and tick when a charge returns.
  - **Remove the stamina bar under the overhead health bar** (item 47's StaminaBar) and keep the overhead plate clean.
  - Optionally keep the air-dash state as a small marker on that slot.
- Assert: the slot shows the hunter's charge count; pips match the charges; the countdown matches the recharge timer. Screenshots: the bottom bar with 2 charges, 1 charge recharging, and 0.

## 85. First-match tutorial fixes (owner, 23:00–23:03 UTC Nov 4): being done now by ext on ext/tut-airdash
- Air-dash step: reaching the marker did nothing. Fixed in 046a7549: Vex's kit air dash never set dash_is_ex, so any dash started off the ground now counts.
- Lookout step: you had to stand on one exact pixel because the lookout is raised. It now completes anywhere on the lookout top.
- "Use Longneedle on the group" doesn't say what that means: explain it in plain words with the key.
- Before the first fight:
  - explain G (the single Boki button), with one try;
  - explain levelling up and unlocking abilities, and the keys or commands involved.
- Keys: "Oh look, there's a key! Grab it so you can open a chest", making clear that chests need keys.

## 86. Outposts: a clear physical structure instead of a VFX circle, with less clutter (owner, 23:04 UTC Nov 4)
- Owner: "the outpost needs to look more clear, not just be a circle with VFX, and it shouldn't cause visual clutter."
- Make each outpost a readable built object: a small stone or timber structure (a waystone, a beacon post, or a little shrine with a banner) whose silhouette you recognise from the top-down camera. It shows its state through the object itself: unlit or neutral, being captured (the beacon fills or lights up), and owned (lit in the team colour, banner raised).
- Keep the capture area as a subtle ground edge, a thin ring line or a change in the ground tint, only while it matters (when you're inside or it's contested). A ground ring means gameplay, so keep it but make it quiet.
- Remove the always-on particles and big VFX discs. Keep motion minimal (a flag stirring, a soft glow) so several outposts on screen don't add clutter.
- Check against the minimap and full-map icons so they match the new look.
- Screenshots: an outpost at match zoom in its neutral, capturing and owned states, plus a view with 2–3 outposts and a fight nearby to check the clutter.
- Logged for whoever has budget (map/world art).

## 87. The second Mask comes from Hob, in a conversation at the farm, instead of just appearing (owner, 23:05 UTC Nov 4)
- Owner: "the masks just appear (Kael, Pip, etc). Let's have Hob call you over when you get to the farm, explain stuff to you, then after a bit be like 'by the way, I see you found a Vex mask; could I interest you in another?' and then offer one of the 3."
- Flow on the first return to the farm (after the first expedition, per DECISIONS: Vex is free at the first portal; the second Mask is a pick of three):
  1. On arrival Hob waves and calls you over ("Hey! Over here!"), with a marker over him. Talking to him (interact key) starts the farm tutorial talk (the existing Hob/farm-hob steps).
  2. A little later in that flow (e.g. once the house is placed, or after one or two farm steps, not right away), Hob brings it up: "By the way... I see you found a Vex mask. Could I interest you in another?" and a short in-world pick of the three offered Masks (the DECISIONS set), each with its portrait, title, a one-line role and a preview clip; you choose one. It plays a short version of the Mask moment (item 83) for the new Mask.
  3. Remove the current behaviour where the extra Masks simply appear. Saves that already have them keep them.
- Files: farm_hob.gd / farm_tutorial.gd (ext's farm-hob code) + the empty90 "second-Mask beat" code (class_unlock / class_pick). Keep the Masks screen and unlock rules otherwise as they are.
- Assert: on a fresh save after the first expedition, no second Mask is owned until you accept Hob's offer; the offer shows exactly the three; picking one unlocks it. Screenshots: Hob calling you over, the offer dialogue, the three-Mask pick.

## 88. BUG: big lag while the Mask cards are on screen and while accepting one (owner, 23:05 UTC Nov 4)
- Owner: "it's also very laggy when the masks are on the screen / accepting them."
- Likely causes to profile (on a real GPU build if possible): each Mask preview builds a full 3D Warden (.glb load plus skeleton set-up) and/or plays a clip at once (three at a time), maybe several SubViewports rendering every frame; the high-resolution portrait/splash textures loading synchronously on open; and the accept running the Mask moment, a model swap and a save on the same frame.
- Fix: preload or cache the three preview models (or show the painted portraits with only the hovered card animating in 3D); render previews at a lower resolution and update only the focused one; load textures asynchronously (ResourceLoader threaded) with a short fade-in; spread the accept's work over a few frames behind the Mask-moment fade. Target: no frame over ~33 ms while the pick is open or on accept (measure frame times and include them in the report).
- Do it with item 87 (same screens).
- **Addition to item 84 (owner, 23:06 UTC):** the dash display on the farm isn't in sync with the one in matches. Both are bad and unclear today. Item 84's new dash slot must be the ONE shared component, used identically at home (farm, town, house) and in matches: same look, same charges and recharge state, the same data source (the hunter's dash charges and timers), and no separate farm-only version. Delete the farm's own dash bar.

## 89. Hob is a real person who stands by the stall and explains things face to face (owner, 23:06 UTC Nov 4)
- Owner: "Hob should be a person and he should stand by the stall, and explain how it works to you, not just a voice."
- **A real character:** today Hob is a placeholder figure. Give him a proper human NPC model in the game's style: a stocky, friendly builder with a tool belt, apron, rolled sleeves and a pencil behind his ear, plus idle animations (waving, hammering, leaning on the stall). Build it with the current Warden pipeline and quality bar, or as a solid stylised model if Meshy isn't available yet. He needs a portrait for his dialogue box.
- **Where:** he stands at the market stall on the farm, and walks to the house site when building.
- **How he teaches:** the farm-tutorial lines and the Mask offer (item 87) become an **in-person conversation**. Walk up and press interact, and a dialogue box opens with his portrait and name, one short line at a time, advanced with a click or key, and the camera eases toward him. When he explains something (the stall, the house, the build menu), he points at it, or the camera shows it briefly, then returns. The floating hint line stays only as a one-line reminder of the current goal. No disembodied voice-over.
- Same branch as items 87/88 (farm_hob.gd, farm_tutorial.gd, farm_guide.gd).

## 90. Building: hold to hammer, your Boki come to help, and materials are spent while you build (owner, 23:07 UTC Nov 4)
- Owner: "should be able to hold F, not press a lot, to build a house; also your pets should go and help you. It should also cost materials to build it, not just to place it."
- **Hold to build:** hold the interact key at a construction site and you hammer continuously (a looping swing animation with a hit sound on each beat), instead of pressing once per swing. Release to stop. The progress bar on the site fills while you hold.
- **Your Boki help:** when you start building (or a site is placed), your nearby Boki walk over on their own and help (their own build/work animation, sparks or dust), each adding build speed (species with building skill add more). No separate order is needed. They go back to their jobs when the site is done. (This is Boki behaviour, so list the kin_* wiring for main if it's needed.)
- **Materials cost during construction:** placing a site marks it out (free or nearly free). The real cost (wood, stone, etc. per building) is consumed as the build progresses, in steps (e.g. each 25% needs its share of materials). If you run out, the build pauses with a clear "Needs 2 more wood" prompt on the site, and resumes when you bring them. Scale the house cost to feel like a real build (e.g. 10 wood + 6 stone), and make sure the tutorial gives or points you to enough for the house.
- Applies to every buildable with a construction site, not just the house. Same branch as items 87–89.
- Assert: holding interact for N seconds advances the site the same as N/interval presses did; one Boki nearby makes it faster; materials drop as the progress steps pass; with no materials the build stops at the step. Screenshots: holding to build with Boki helping, and the "needs materials" pause.

## 91. Chopping, mining and building use real tools and animations, with the weapon put away (owner, 23:08 UTC Nov 4)
- Owner: "mining and chopping need an animation, not just swinging our weapon at it; the weapon should be holstered regardless of class when this happens."
- When you chop a tree, mine a rock or build (item 90): your weapon is put away (hidden or holstered, for every Hunter class and for the Empty), and the right **tool** appears in your hands: an axe to chop, a pickaxe to mine, a hammer to build. Each has its own animation: a two-handed overhead chop, a pickaxe strike, hammer taps. It plays with hit timing on the beat, wood chips, rock chips or sparks, a sound per hit, and the target reacting (the tree shakes and creaks, the rock cracks). Hold to keep working (like item 90). When you stop or walk away, the tool goes and the weapon comes back (in matches; at home, per the Empty rules, there's no class weapon out at all).
- At home generally: the Empty shouldn't carry a class weapon around the farm (noted in the unmasked report). Hide it at home and show tools only while working.
- Same branch as items 87–90. Assert: during a chop/mine/build the weapon nodes are hidden and the tool node is visible in the hands; they swap back after. Screenshots: chopping, mining, building.
- **Additions to item 89 (owner, 23:08 UTC):**
  - **Introduce Hob with the camera:** on the first arrival at the farm, the camera pans to Hob at the stall, holds about 1.5 s while he waves and calls out, then returns to you. Show his name tag above him the whole time until you've talked to him.
  - **Use a free character model for Hob** instead of the low-poly placeholder: a ready-made **market vendor / villager** model from a library with a **CC0 / commercial-use licence** (e.g. Quaternius or Kenney character packs, or another clearly CC0 source). Retexture or recolour it to fit the game's style. Record the source, author and licence in `docs/art/CREDITS.md` and next to the asset. Avoid anything that isn't explicitly free for commercial use, and anything with a recognisable brand or character. Rig it to play idle/wave/talk animations (the pack's own animations, if included and under the same licence).

## 92. Farm tutorial wording, plus a Boki page you can open from anywhere (owner, 23:09 UTC Nov 4)
- "Pick it a job" is bad English. Rewrite it ("Give your Boki a job") and proofread every farm-tutorial line. Being done now on ext/tut-airdash.
- "Open your Boki's page" doesn't say how. Name the key (C near the Boki, confirmed in code) on the same branch.
- **Feature (main's Boki UI if missing):** a button or key that opens your Boki's page **regardless of where the Boki is**: a roster key plus a HUD button listing your Boki, each opening its page. If one already exists, make it much clearer (a visible HUD button with its key cap).

## 93. Split teaching from playing: a guided "Trial Expedition", then a quiet first real expedition (owner, 23:15 UTC Nov 4)
- Owner: "I'm getting too many instructions during my first expedition. If this is the case, maybe have a 'trial expedition' where it pauses to give you instructions and guides you the whole way. Otherwise it's just distracting."
- **The Trial Expedition** (the current scripted tutorial course, tut84, reframed):
  - A short, clearly labelled guided run (e.g. "Trial Expedition" with Hob or your Boki as guide), offline, before your first real expedition.
  - It **pauses** at each lesson: a calm, centred card with one instruction, the key, and a tiny looping preview where useful. You do the action, then it continues. No timers or pressure, and the world waits for you.
  - It guides you the whole way, in order: move, dash, air dash, glide, crouch/scout, pick up, fight (%W, your ability, G and your Boki), level up and unlock abilities, keys and chests, outposts, extract.
  - Skippable for returning players. Replayable from the menu.
- **The first real expedition:** **no tutorial banners** at all; only the normal HUD, plus a single short reminder card if the player does something wrong (e.g. "Chests need a key"). Any remaining lessons move into the Trial or into contextual one-line tips the first time something happens, and each tip shows once and goes into a Tips log.
- This reframes items 85/92's tutorial fixes: their text and step fixes carry over into the Trial's cards.
- Logged for whoever has budget. It's the match tutorial (tutorial.gd/tutorial_drive.gd/tutorial_hud.gd), main's tut84 code.

## 94. Performance pass: the game is laggy (owner, 23:16 UTC Nov 4; high priority)
- Owner: "it's very laggy; the game needs to be more optimized." (Also item 88: lag on the Mask cards.) The lag got worse with the 3D Hunters.
- **Measure first:**
  - Add a toggleable performance overlay (Settings > Video or a debug key): FPS, frame time (ms, 1% low), draw calls, triangles on screen, and the top script costs.
  - Add a scripted benchmark run (a fixed 60 s match with 4 Hunters, Boki, a fight, outposts and particles) that logs frame times, so before/after can be compared. On the server it runs headless and software-rendered, so its absolute numbers mean little; compare relative costs there, and ask the owner for one capture on his PC (GPU).
- **Likely big wins, in order:**
  1. **3D Hunter meshes** (Meshy outputs are often 50–200k triangles each): decimate to a game budget (~10–15k tris per Hunter, less for Boki) with clean LODs (full / half / quarter by distance); one material and one atlas per Hunter where possible; textures compressed (VRAM/BPTC), mipmapped, and ≤1–2K.
  2. **Shadows and lights:** fewer shadow-casting lights, a sensible shadow distance and atlas size, no per-ability shadow lights.
  3. **Particles and VFX:** cap counts, prefer GPUParticles or simpler sprites, and kill always-on ambient particles (outposts, item 86; motes).
  4. **Scripts:** profile per-frame GDScript (e.g. Match._separate pair loops, HUD rebuilds every frame, path/bot ticks); throttle non-critical updates (HUD text, minimap) to 10–20 Hz; avoid allocating in _process.
  5. **UI previews:** SubViewports (Mask cards, portraits) render only when visible or focused.
  6. **Quality presets:** a Low/Medium/High preset that actually changes render scale, shadows, particles and LOD distance; default to Medium.
- **Target:** a steady 60 fps on a mid-range PC at 1080p Medium in the benchmark, and no frame over 33 ms in normal play. Report before/after numbers per change.
- Logged for whoever has budget; it touches shared files (models, main, match), so it's one careful branch.

## 95. Nameplates show just the player's name; a setting swaps them to the Hunter's name (owner, 23:17 UTC Nov 4; changes item 39's "<player> the <title>")
- Owner: "the names of people should just be their name (not X the Y), which is how it'd work with real people; you can tell who they're playing by the look. We can also have a setting for nameplates where it would say Vex or something instead."
- **In matches** (overhead nameplates, kill feed, scoreboard, end screen, party HUD): show only the player's own name (bots: their bot name). No "the <title>".
- **Setting** (Settings > Interface > "Nameplates show"): **Player names** (default) / **Hunter names**. Hunter names shows the Hunter on everyone's plate instead ("Vex", "Kael"), for people who'd rather see what each enemy is playing. Applies to nameplates and the kill feed; the scoreboard can show both columns.
- The title ("the Hired Gun") still appears on the Masks screen, hero picker, kit card and Mask moment, where it describes the Hunter.
- Small; whoever has budget. Update --hero-title-check (it asserts the "<player> the <title>" label today).

## 96. TOP PRIORITY with item 94: combat clarity (owner, 23:17 UTC Nov 4: "my biggest issue is the combat clarity is not great and the performance is really bad")
Goal: in a busy fight at match zoom, you can always tell where you are, where enemies are, what's about to hit you, and whether your hits land.
1. **You and them:** a crisp outline or rim per team on every Hunter (self = bright, allies = blue, enemies = red), with readable ground circles (item 46). Your own Hunter is always findable (a subtle self marker when you're in a crowd).
2. **Telegraphs:** every enemy ability that can hurt you shows a clear, consistent warning (red-edged area or line on the ground with a fill timer) for its wind-up; your own telegraphs use your team colour and are fainter. One visual language for all 12 kits (audit each kit's telegraphs against it).
3. **Less VFX noise:** cap VFX opacity, size and lifetime; no full-screen-ish bursts; allies' effects drawn dimmer than yours and enemies'; remove decorative ambient effects near fights (items 50, 86). A ground ring means gameplay (DECISIONS).
4. **Hit feedback:** a short hit flash on the target, consistent damage numbers (yours bigger and brighter, crits distinct), a clear hit sound per Hunter weapon, small hit-stop on heavy hits (no screen shake), and an obvious "you got hit" signal (a screen-edge pulse from the direction).
5. **Status readability:** stun, slow, grounded, dazed, Static, Marks: one compact, consistent icon row over the target, plus a body tint for hard CC (stunned = flashing outline).
6. **Projectiles:** enemy projectiles have a bright core and team-red trail; yours team-coloured; all readable against grass, stone and abyss.
- Deliver: an audit of a 60 s recorded fight (2v2 + Boki) listing every clarity problem, then the fixes, with before/after captures of the same fight. Pairs with item 94 (fewer effects also helps performance).

## 97. BUG: shields sometimes make a Hunter invisible; and the Boki shield effect looks bad (owner, 23:18 UTC Nov 4; part of item 96)
- Owner: "sometimes shields give invisibility, which seems unintentional. I also don't like those shields I'm assuming are coming from a Boki; it looks bad."
- **Invisibility bug:** find which shield source does it (Boki shield moves via kin_exec.gd "shield" and effects.gd "shield"/"ally_area", Breaker's aegis, gloves) and how. Likely suspects: the shield bubble's material or transparency sort hiding the body; the shield VFX node replacing or hiding the model's meshes (`visible = false` or a shared material being changed); a shield state flag reused by a stealth/untargetable path; the 3D Warden loader's hidden-mesh logic (glb_hidden) catching the shield mesh. Fix the cause; a shielded Hunter must stay fully visible and targetable unless an ability explicitly grants stealth. Add an assert: applying each shield type leaves every visible body mesh visible and the hunter targetable.
- **Shield look:** replace the current Boki shield visual with a clean, readable one in the combat-clarity language (item 96): a thin, team-coloured shell or rim around the body with a small shield-value bar on the nameplate (like armour), with a crisp break effect when it pops. Not a big opaque bubble, no lingering particles. Same for every shield source, so players learn one look.
- Boki-side files (kin_*) are main's: list wiring if needed.

## 98. Choose which ability to rank up (e.g. max E first), like the source (owner, 23:19 UTC Nov 4)
- Owner: "I don't see if there's an option to max one ability (I'm playing E-max Vex, etc). This should be the case. Maybe a 4th ability point that's one-time use after you max everything else (or not, not sure how SUPERVIVE did it)."
- CORRECTION (ext 00:30): the choice already exists: **Alt + an ability's key** spends a point on it (match.gd:3750 → Hunter.level_slot); the fixed `order` is only for bots (`_bot_spend`). The owner didn't discover it, so item 98 is mainly **discoverability**: the "+" on rankable slots, tier pips, the pulse for unspent points, and the tutorial step (now on ext/tut-airdash). Keep **Alt + key** (not Ctrl); clicking the "+" works too. Also check SLOT_MAX lets one ability reach its full tier IV (R III) as in the source.
- (Original note, wrong:) ranks are automatic in a fixed order.
- Source (supervive_kits.md header): each ability has its own upgrade tiers, II/III/IV for RMB, Shift, E (and the air dash, where separate), and II/III for R; you spend level-ups on the abilities you choose.
- Change:
  - **Each level-up gives one ability point.** A small "+" appears on each ability slot that can be ranked; press **Ctrl + the ability's key** (or click the "+") to rank it. The slot shows its tier pips (I–IV, R I–III). The ult's tiers only open at set levels (e.g. 6/11/16 equivalent on our level curve).
  - **You can max one ability first** (E-max Vex). Respect the source's per-tier effects (the "Upg:" lines in the data, as already implemented per rank).
  - **Owner's optional idea, a one-time bonus point once everything is maxed:** off by default; leave a data flag (`bonus_point_at_max`) the owner can turn on, and if on, it grants one extra tier on any ability (a "V" tier = a small, clearly visible bonus). Owner to decide.
  - Bots: rank by their current fixed order (unchanged) so they stay sensible.
  - Tutorial (items 85/93): the levelling lesson teaches this (+ on the slot, Ctrl+key).
  - Unspent points stay banked; a gentle pulse on the "+" reminds you.
- Assert: after N level-ups you can put all points into E up to its max; the ranks' effects apply; bots still rank automatically. Screenshots: the ability bar with "+" markers and tier pips.
- Main's HUD files are wiring-only; logged for whoever has budget, after items 94/96.

## 96b. Combat clarity when someone is downed (owner, 23:19 UTC Nov 4; part of item 96)
- Owner: "especially when someone is downed, it's hard to tell what's happening with their Boki and your Boki and everything."
- Add to the item 96 pass:
  - **Downed Hunter:** an unmistakable downed state, with a ground ring in their team colour, a bleed-out timer arc over them and a "Revive (hold F)" prompt for allies in range.
  - **Their Boki:** shows clearly what it is doing while its Hunter is down (guarding / fleeing / downed too), with a small icon above it and a tether line to its Hunter in the team colour.
  - **Your Boki:** always has a distinct own-team ring + tether to you, so it never gets lost in a fight.
  - **One rule of colour across all of it:** you = one colour, allies = team colour, enemies = red. Boki inherit their Hunter's colour.
  - **Kill feed / edge markers:** a short line ("Kael downed by Vex"); an off-screen arrow for a downed ally.
- Assert / screenshots: a 2v2 fight with one Hunter downed, showing both Boki, before and after.

## 99. Looting with a full inventory (owner, 23:22 UTC Nov 4)
- Owner: "If I smart-loot a box it says 'taken 3 things' even if my inventory is full, and if I try to grab something it just clicks like I took it but didn't. It should go to my inventory and have drop / replace options in this instance."
- Fix:
  - Smart loot only reports what actually moved ("Took 1 of 3, inventory full").
  - A click on an item that doesn't fit never fakes success: the loot panel opens your inventory beside the box with the clicked item held, so you can **swap** it with one of yours (the swapped item goes into the box) or **drop** one of yours to make room.
  - A clear "inventory full" cue on the item (red outline + a short sound).
  - Same flow for chests, death boxes and ground items.
- Assert: with a full inventory, smart loot takes nothing and says so; swap puts the old item in the box; the counts stay right.

## 100. Middle mouse = ping (owner)
- Owner: "Middle mouse button should default to pinging teammates / making pings on the map, same when the drop is happening."
- MMB is the default ping key: in a match (on the world at the cursor; on enemies / items / boxes it gives a contextual ping such as "Enemy here" or "Loot here"), on the full map, and during the drop / jump phase.
- Teammates see the ping in the world, on the minimap and as an edge arrow when off-screen. Rebindable in settings.
- Assert: MMB places a ping in each of the three contexts; the bot teammate receives it.

## 101. Whose box is it + reviving from a teammate's box (owner)
- Owner: "It's unclear if a box is a teammate's box vs an enemy's box. I should be able to tell on the map, and if I see a box, if it's a teammate's, be able to revive it."
- Death boxes are tinted by owner: ally boxes in team colour with the teammate's name + portrait; enemy boxes red/neutral. The same marker shows on the minimap and the full map (ally boxes always visible to the team).
- At an ally's box: "Hold F: take their [soul/token]" brings them back (follow the source's respawn rule; if it needs a respawn point, show the path there). Their Boki comes back with them.
- Assert / screenshots: an ally box vs an enemy box in the world and on the map; a revive from an ally box restores the teammate.

## 102. No overlapping popups + much less text on screen (owner, 23:24 UTC Nov 4; part of item 96)
- Owner: "There's a lot of double UI / text popping up on top of each other. If two need to pop up, they should not be on top of each other. And in general too much text clutter."
- One shared message queue / stack for all transient on-screen text (toasts, pickups, level-ups, hints, tutorial lines, objective messages):
  - Messages stack in a fixed lane, never on top of each other.
  - Repeats merge ("Ember x3").
  - At most ~3 visible at once; lower priority waits.
  - Short lifetimes.
- Cut the clutter:
  - Audit every popup / floating text in matches and on the farm.
  - Delete or shorten anything that isn't needed for a decision; prefer an icon, sound or flash over words.
  - Floating combat numbers small and fading.
  - Hints show once.
- Assert: firing 5 messages at once gives no overlap (layout check); screenshots before/after of a busy moment in a match and on the farm. List what was removed.

## 103. BUG: a sound keeps playing forever after an expedition (owner, 23:24 UTC Nov 4, "again")
- Owner: "Getting a sound bug again where it persists indefinitely from an expedition."
- Root-cause it, don't patch one sound:
  - Find every looping AudioStreamPlayer / ambient / channel loop started in a match (storm, glide wind, channelled abilities, extraction beacon, hold-to-build hammering, music layers).
  - On match end / extraction / death / scene change, all match audio must stop: parent it to the match scene or put it on a "Match" bus that is muted and cleared on exit.
  - Also stop loops when the owning node frees mid-channel (e.g. extracting during a channel).
- Add a check (register it): run a short match, extract mid-channel and return to the farm; assert no match-started players are still playing.
- Do this first in the item 94 perf pass (it touches the same audio/scene teardown).

## 104. Farm Boki speech text is now too big (owner, 23:24 UTC Nov 4)
- Owner: "The text from the Boki in your farm is too big now. Before it was too small but you went overboard."
- Bring the farm Boki speech/bubble text to the middle: roughly 65-70% of the current size, still readable at the farm camera. Shorter lines help too (item 102).
- One shared size constant for all Boki speech (farm + match) so it stays consistent.
- Screenshot at the normal farm camera before/after.
- Routed to the tutorial agent (ext/tut-airdash) as an add-on, since it already has the farm warm.

## 105. Boki talk: shorter, far less repetitive, about what's happening (owner, 23:30 UTC Nov 4)
- Owner: "They also talk too long / too-long text bubbles, and it's too repetitive. Can we hardcode a ton more phrases and try to make them relevant to what's happening?"
- Where the lines live: `scripts/core/KinSpeak` (`FEEL` / `ACTS` banks, the speech stages via Care.speech) for the farm; `scripts/match/kin_voice.gd` for match callouts. Move the banks to data (`content/rules/kin_lines.json`) so they're easy to grow.
- Shorter:
  - At most ~6 words per bubble (aim 2-4).
  - One sentence.
  - Bubbles last ~2 s.
  - Longer thoughts become two separate beats or an action ("(sniffs the crop)").
- Far more variety:
  - ~5x the current lines per situation.
  - Never repeat a line within the last ~10 said by that Boki.
  - A per-Boki cooldown so they don't chatter constantly.
  - Personality / element flavour where it fits (a Cindle line can mention warmth, a Puddlet one water).
- Relevant to the moment: triggers for what is actually happening.
  - **Farm:** a crop ready / watered, building in progress, being petted / fed, a new Boki arrives, rain or night, the player returning from an expedition (and how it went), working its job, idle near another Boki (they "talk" to each other), low needs.
  - **Match:** an enemy spotted, the Hunter hurt / downed, a kill, loot found, the storm closing, extracting, revived, level-up, the Boki's own ability used.
- Keep the speech-stage rule: young Boki only say their name with tone + actions; the variety at that stage comes from the tones and actions.
- English pass on every line (natural, short, warm, our own voice).
- Assert: no line repeats within 10; the max length is enforced in data; each trigger has ≥ 8 lines. Screenshots: 3 farm moments + 2 match moments.

## 106. Reticle: smaller default like the source's, plus customisable (owner, 23:31 UTC Nov 4)
- Owner: "The reticle should be customizable and the base one should be SUPERVIVE's base reticle. It's too big I think right now."
- Default: match the source's default cursor reticle in size and shape. Our data has no description of it, so take it from footage frames (briefs/supervive-data footage notes / clips) and confirm with the owner via a screenshot. The owner can send a screenshot of the source's reticle if handy. Our own drawing, same proportions. Clearly smaller than now.
- Settings → Reticle:
  - shape (default / dot / small circle / cross / circle + dot)
  - size slider
  - colour (preset swatches incl. high-visibility)
  - opacity
  - outline on/off
  - Saved in the player's settings (not the run save).
- Ability-specific aim visuals stay (Hem's filling line, item 55b; the charge visuals) and sit on top of the chosen reticle.
- Assert: settings persist and apply in the farm and the match; screenshots of the default + 2 custom styles.
- Bundle with the item 96 combat-clarity pass (reticle readability is part of clarity).

## 101b. Revive rules, from the owner (overrides the revive part of 101; owner, 23:32 UTC Nov 4)
- Owner: "SUPERVIVE doesn't make you carry them to a respawn. You can use a respawn beacon to revive all your teammates (and it makes a big sound and notifies people it's being used), or you can save an individual box by reviving it, which is like a 7-8 s thing where you're vulnerable while doing it (extra damage taken, like with potions)."
- Two ways back:
  1. **Revive a box:**
     - At an ally's death box, hold F for ~7.5 s (tunable, data).
     - While channelling you take extra damage (use the same vulnerability multiplier as drinking potions) and can't attack.
     - Moving / getting hit cancels it (follow the potion channel rule).
     - The teammate comes back at the box with their Boki.
     - A progress ring on the box + over you.
  2. **Respawn beacon:**
     - A map structure (several per map, shown on the map).
     - Using it revives ALL dead teammates at once (from anywhere).
     - It's loud: a big sound audible across a wide radius, plus a map/world notification to every player that a beacon is in use (location shown) for its duration.
     - Short channel, data-tuned.
- Ally boxes stay team-coloured on the map (101) so you know whom you can save.
- Assert: a box revive takes ~7.5 s with extra damage taken and cancels per the rule; a beacon revives all dead allies and every player gets the notification + sound.

## 107. A cooler, higher drop into the match (owner, 00:44 UTC Nov 5)
- Owner asked whether "the cooler / higher drop" is queued. It wasn't logged before, so here it is.
- Start the drop much higher, with a longer, more dramatic descent:
  - the camera pulls far out at the jump and the whole island is visible
  - clouds rush past
  - wind sound builds
  - a speed-lines / trail VFX
  - the glide opens with a satisfying snap
  - the camera eases back to the play zoom just before landing
  - a landing impact (dust ring + sound, no self screen shake per item 50)
- Steering keeps working the whole way; the total drop time is only slightly longer (data-tuned).
- Teammates are visible dropping beside you.
- MMB pings work during it (item 100).
- Keep it cheap (item 94 budget).
- Video/GIF of the drop for owner review.

## 108. Look pass from the owner (+ his sister's feedback) (owner, 00:49 UTC Nov 5)
- **Kael, Ostra, Breaker:** a model/look pass (Kael and Breaker were already ART-1 priorities; **add Ostra** right after them).
- **Pip:** a bit smaller (scale down ~10-15%; keep the hitbox matched per item 46).
- **Vex:** a better splash art (IMG agent / anthum; our own design, stronger composition and pose).
- **Hem:** more attractive / striking design (League-style appeal: confident pose, a better face and hair, a flattering fitted outfit in her red palette). Tasteful, not sexualised.
- Approval gates as for ART-1.

## 108b. Romi's notes (owner's sister), as relayed (owner, 00:54 UTC Nov 5). Owner picks pending; ext's recommendations noted
- **Hem:**
  - long hair
  - capris + a corset that shows her midriff
  - tanner skin
  - green eyes that pop (green against her red palette)
  - Romi also suggests a rename "to something like Liza". **Rename = owner decision** (ext: "Hem" ties to "the Red Stitch"; if renamed, keep a sewing/thread meaning).
- **Kael:** "not loving him": all gold, or **all silver with dark skin** (ext recommends silver + dark skin, crimson accents).
- **Cinder:** a cooler potion holder (a striking bandolier/rig for her vials).
- **Dredge:**
  - stands on one foot and extends up tall
  - can also roll like a ball (ext: a great fit for his own dash animation, item 35)
  - grey with a single green eye
  - Dredge uses the friend's Blender model, so a recolour + new animations, not a new model.
- The image-gen concepts come first (the owner prompts them by hand); then S2 builds from the owner's picks.

## 109. BUG/FEEL: Vex can't aim while dashing (owner, 04:46 UTC Nov 5)
- Owner: "Vex should be able to move her LMB and shoot while dashing. It sticks to one direction."
- Today, during Vex's dash/slide her LMB aim locks to a single direction (likely the dash direction or the aim at dash start).
- **Fix:**
  - While dashing (ground slide and air dash), Vex's rifle keeps tracking the cursor every frame and fires freely toward it. The dash direction and the aim direction are independent.
  - The upper body / gun rotates to the aim while the legs follow the dash; the shots spawn along the true aim.
  - Holding LMB through the dash keeps firing with no interruption (item 51 rule: everything combos with Shift/jump).
- **Check the other ranged Hunters** for the same lock (Lisette, Ryzz, Sable, Cinder's flamethrower): their primary should also track the cursor during dashes unless their kit says otherwise. List any changed.
- **Assert:** a dash east while aiming north fires its shots north (angle within ~5°), with no gap in the fire cadence across the dash. Add it to the gunslinger combo check.

## 110. Wing-glide as a per-Hunter unlock (owner, 05:07 UTC Nov 5) [LATER: cosmetics/progression]
- Owner: everyone uses gliders by default (gliders are a sellable cosmetic). Winged Hunters can **unlock gliding on their own wings** for that Hunter only, after a set number of games played with them (a mastery reward).
- **Winged Hunters:**
  - **Pip:** fairy wings.
  - **Sable:** her moth-wing coat tails open into wings.
  - **Claire:** her small bat wings flap fast, or grow while gliding.
- **Gameplay identical to the glider:** same speed, drop rate, steering, heat/overheat (item 63). Visual + animation + sound only.
- **Data:**
  - `glide_unlock: {hunter, games: N}` (N owner-tunable, e.g. 20).
  - Shown on the Hunter's mastery track; selectable in the loadout like any glider.
- **Future (optional):** signature glides for the other Hunters as premium cosmetics, e.g.:
  - Kael's scarf as a sail
  - Cinder's tank jets
  - Motley's spinning box
  - Grimble's junk umbrella
  - Breaker's balloon anglerfish
  - Lisette's thread wings
  - Ryzz's storm kite
- **Priority:** after the art and model passes and the glider-cosmetic system exist. Not now.

## 111. Tarek's dash becomes "Rock Hop" (rock-to-rock parkour), plus his look and lore (owner, 05:29 UTC Nov 5)
- **Owner:** "His dash: he jumps from rock to rock he spawns under him, maybe 2 or 3 jumps. Different from who he's based on, but I like the rock as a skateboard/parkour idea."
- **Today:** `dolm.json` dash "Rubble Leap" is a single leap to the cursor (~4-5 m, cd 12 s). A rock bursts up under him, the landing shoves, and the rock follows and rolls on 6 m (12 dmg, a shove, Shred, a 1.5 s slow).
- **New dash, Rock Hop (2-3 linked hops):**
  - Press Shift: a rock bursts up under him and he springs off it toward the cursor (hop 1).
  - A fresh rock rises under his feet at each landing and he chains up to **3 hops total**. Each re-press within ~0.6 s steers the next hop toward the cursor; no re-press means he lands.
  - **Parkour feel:** fast, low arcs (not floaty); he can rail-surf briefly on the rock as it rises (a short skid, like a skateboard).
  - Keep the total distance and damage roughly equal to today's single leap so balance holds: e.g. 3 × ~2.5 m. Data-tuned.
  - Each landing gives a small shove. The **last** landing keeps today's crash, plus the trailing rock that rolls on (12 dmg, Shred, slow), so the kit identity stays.
  - The rocks he hops off stay a moment and crumble (cheap). Allies can hop them too (they are his rocks, per the Tarek data rule).
  - **Cooldown:** starts when the chain ends. Each hop is a dash for the item 32 dash→ability flow (abilities usable mid-chain).
  - Air dash and glide: unchanged ("In the air: your long dash").
  - **Assert:** 3 inputs = 3 hops along a steered path; 1 input = 1 hop; total distance within ±10% of the target; damage only on the final crash.
- **Look (owner-picked, art):** keep his original identity; upgrade per `briefs/art-refs/tarek_FINAL_sheet.png` once saved.
  - one huge stone arm with molten cracks
  - a climbing harness + rope
  - dreadlocks with copper beads
  - a plain cloth blindfold
- **Lore:** Tarek is blind; **three floating eye-stones orbiting his head are his sight**. They look in different directions and turn toward enemies they spot. The blindfold does not glow.

## 112. Vex's grenade (RMB, Burr Charge): TAP ONLY, fired FROM HER ARM-CANNON (owner playtest, 12:12 UTC Nov 5)
- Owner: "Vex still throws the grenade and can hold it instead of it only being a tap. It should come from her arm as well (the bigger explosion thing, not the minigun)."
- **Tap only:**
  - Remove the hold variant / hold behaviour entirely.
  - RMB press = fire immediately; holding does nothing extra (no aim-hold, no charge).
  - Update `gunslinger.json` `rmb.variants`, the card text and the tutorial line.
- **No throw:**
  - Remove the throwing arm animation / hand spawn.
  - The grenade launches from the **top grenade-launcher tube** of her arm-cannon (the right arm), with a muzzle puff + thunk (S4's grenade sound) and a recoil kick on the cannon. The gatling barrels stay her LMB.
  - Spawn point = the launcher muzzle (an FX empty on the new model; on the old model, the gun's muzzle offset up).
- Kit numbers unchanged (dmg, cone, daze, wall stun, cd 6.5 s).
- **Assert:** a tap fires within one frame; a 1 s hold fires once at the press with no extra effect; the spawn is at the launcher muzzle, not the hand.
- Also check her other abilities for leftover "throw" anims (consistent with "her right arm IS the cannon").

## 106b. Reticle + aim line, matching the source exactly (owner playtest, 12:15 UTC Nov 5; overrides 106's default look)
- Reference: `briefs/supervive-data/refs/reticle_aimline.png` (look/proportions only; draw our own).
- **Reticle:** a SMALL thin white circle with a tiny dot in the centre, clearly smaller than ours today (in the ref, about the size of a Hunter's head at match zoom). No crosshair arms, no fill.
- **Aim line:**
  - A thin light-blue/white line from the Hunter to the reticle.
  - It starts faded/transparent at the Hunter and grows more opaque toward the cursor; its length = the distance to the cursor (it always ends at the reticle).
  - Subtle (thin, slightly glowing), drawn under the Hunters, above the ground.
- **Kept from 106:** these become the DEFAULT. The reticle-customisation settings stay; the aim line gets an on/off + opacity setting.
- Ability-specific aim visuals (Lisette's filling line, cones, charge bars) draw on top and replace the plain line while active.
- Screenshot at match zoom next to the ref.

## 113. Kael: accuracy pass vs the source's Brall (owner playtest, 12:19 UTC Nov 5). HIGH
Source of truth: Brall in `briefs/supervive-data/supervive_kits.md` + footage refs (owner notes win). Owner: "he relies on combos; he needs a better pass on accuracy compared to his original, Brall."
1. **Sword looks comically big and doesn't match his model/splash.** Use `kael_weapons.png` / the master sheet: a straight, broad, jagged greatsword (blade ~shoulder-to-ankle), the same mesh as the new model, glowing white-hot. Scale it to his hand and body, not oversized. (ART-1 Kael + the in-game held weapon.)
2. **Accidental glide:** holding RMB and pressing jump makes him glide. Not allowed.
   - No glide from the RMB hold.
   - During his R (ult), glide is blocked until the last ~1.5 s; in that window a glide input cancels the rest of the ult into a glide.
   - (ext's reading of "don't let him glide for like 1.5 s until near the end of his R"; confirm with the owner if unclear.)
3. **RMB hold pose:** the sword held overhead isn't pointing forward. It should be like the source's held stance: the blade angled FORWARD toward the aim, ready to lunge (partly a size problem; fix after 1).
4. **The ranged auto (LMB long / searing wave)** should be a SIDE SWING (horizontal sweep), not an overhead chop.
5. **E (Warchain)** still forces him forward, and he can't RMB to the side then E elsewhere.
   - E fires toward the CURSOR independently of his movement / RMB direction.
   - RMB in one direction, then immediately E in another: both work, no forced direction carry-over.
   - The chain pull per the existing tether rules (facing/movement steer, item 57).
6. **Down-RMB (air RMB / Meteor):** make it a vertical DOWN-SLAM like the source (drops straight down onto the target spot), not the current sideways diving slam.
7. **Combo must work:** E a foe → R (ult) → mid-ult, pull himself along the chain toward them so the ult's effect hits them as he goes.
   - E's tether persists into the ult, and the self-pull is usable during it.
   - Assert this combo end to end.
8. **Dash = a hit with a short animation:** it damages / knocks like the source but with a much shorter commit/animation than now.
- **Checks:** --juggernaut-combo-check updated with asserts for 2, 5, 6, 7, 8. A short GIF per change.

## 114. Lisette playtest fixes (owner, 12:21 UTC Nov 5). HIGH
1. **Idle/stance:** her standing pose / base model looks weird, as if leaning back. Use an upright, confident archer stance, weight forward, bow low and ready (ART-1 Lisette + the idle anim).
2. **The "V" attack visual is STILL there:** the owner doesn't want it (item 55b: a filling line + a small perfect-timing circle that flashes, no V, no extra UI).
   - NB: `ext/kit-hem-55b` was HELD by S5 (drop-phase shader-compile stutter), so main still has the V.
   - Fix the stutter (pre-warm the shaders at load) and land 55b.
3. **RMB (Heavy Shot):** she must visibly draw and hold a BIG needle arrow while charging: an oversized silver needle-arrow nocked on the bow, red thread trailing, glowing as it charges. Today no arrow is visible at all.
4. **RMB charge feel:**
   - A much stronger charge sound: a rising tension creak + thread hum + a glow-up, and a heavy release twang/whoosh (S4).
   - She is **slowed while holding it** (data: e.g. 35-40% move speed while drawing; tune).
5. **E VFX:** it starts GREEN then turns red. It must be **red the whole time** (her palette); remove any leftover green/default tint at the start (S3).

## 115. Vex's ult should be GREEN (owner, 12:21 UTC Nov 5)
Her R/ult VFX colour = toxic/neon green (her palette: tracers, the cyber-eye, the spine), not the current colour. Check every Vex VFX for off-palette colours (S3).

## 116. Ryzz playtest fixes (owner, 12:23 UTC Nov 5). HIGH
1. **Idle + walk/run:** too stiff. Give her a sexier, confident, bouncy idle and walk (hip sway, swagger, attitude), still playful. Use the bubblegum blow/pop in the idle (ART-1 Ryzz anims).
2. **LMB:** ~10% faster fire rate (data: the autos interval ×0.9) and PINK bolts (finger-gun lightning, per the FIDELITY_CHECKLIST).
3. **Static stacks on enemies:**
   - The counter over their head is PINK.
   - Like the source: a small lightning-bolt icon attached to the enemy per stack (1 bolt per hit, up to the max), so stacks read at a glance.
   - Copy the source's presentation; draw our own.
4. **Ult (Kitefall):**
   - It doesn't land exactly at the cursor. It must go exactly to the cursor position (clamped by range).
   - It still doesn't spread Static (item 72 not working in play): on impact it spreads her highest Static count to everyone hit.
   - Assert both in --mage-combo-check.
5. **Sound:**
   - Much better lightning sounds: a crackling zap per finger-gun shot, a sizzling stack-apply tick, a big thunder crack on the ult.
   - A distinct "reset" sound (a bright electric chime/zing) when her dash (Wirerun) resets from the orb pull (item 71) (S4).

## 116b. Ryzz's dash (Wirerun) on reset: ~1.5x further and a faster charge (owner, 12:23 UTC Nov 5). Reference: Joule's Surge (source)
- Source (supervive_kits.md, Joule): **Surge (Shift)**:
  - PRESS = dash forward, damaging enemies passed through; HOLD = charge a longer dash.
  - Dashing through a 4-Static enemy = massive bonus damage + a cooldown reset.
  - The Lightning Orb also resets it.
- **Owner:** the reset dash should go **~1.5x further** than now, and **charge a bit faster** (the hold-to-charge ramps quicker, e.g. ~0.75x the current charge time).
- **Match Joule's feel:**
  - A quick press = a short zap-dash through enemies (damage on pass-through).
  - A hold = a longer charged dash.
  - Pass-through damage + the 4-stack bonus + the reset loop should flow into chained dashes.
- Data-tuned; assert the reset distance ≈1.5x the base and that the charge-to-max time is reduced.
- Pairs with 116.5 (the reset zing sound).

## 117. Motley (ex-Ostra) LMB: goes THROUGH WALLS + is visibly bigger when charged (owner playtest, 12:24 UTC Nov 5)
- Item 60 ("charge-by-wait, through walls") shipped in `ext/small-60-66-75`, but in play the LMB still stops at walls and the slow vs fast shots look the same.
- **Fix:**
  - The LMB projectile passes through terrain (all of them, or at least the charged ones, per the source; check the data and pick the source rule).
  - The size scales with the charge: a quick fire = a small orb; a slow/charged fire = a clearly bigger orb (≥1.6x visual + hitbox), brighter, with a bigger impact.
- **Assert:** the charged shot hits a target behind a wall, and the projectile radius at full charge ≥1.6x the quick one.

## 118. Pip's RMB (Burrseed): a ~1 s WIND-UP, NOT holdable (owner playtest, 12:26 UTC Nov 5)
- **Today:** "hold to aim the lane, let go to throw" (`tender.json` rmb hold 0.25).
- **Owner:** "it needs a little wind-up time, and shouldn't be holdable. Like a solid near-1 s wind-up, so you flick it to land it."
- **Change:**
  - A press starts a fixed ~0.9-1.0 s wind-up: she raises her lantern / winds back, with a clear telegraph ring/glow on her, plus a short dotted lane preview along the current aim during the wind-up.
  - The seed throws automatically at the end, toward the cursor AT RELEASE TIME (so you "flick" the aim onto the target as the wind-up ends).
  - No hold, no charge, no extended aim; releasing early does nothing.
  - Movement slowed during the wind-up (tune, e.g. 50%).
  - Seed damage / root / burst unchanged.
- Update the data, the card text and the tutorial line.
- **Assert:** a press → the throw at ~1.0 s; the aim direction is sampled at the throw moment; holding longer doesn't delay or change it.

## 119. Remove the word popups: keep damage numbers and essentials only (owner, 16:55 UTC Nov 5; extends item 102)
- The owner: "getting rid of the ui for stuff like 'vault reset' or 'Sweet spot' - i dont think supervive does this and it clutters the screen - just keep dmg numbers and essentials".
- Remove the flavour word popups: every `ArchKit.payoff_fx(...)` word (SWEET SPOT, VAULT RESET, and the same kind in every kit: archer, ashwick, bulwark, dolm, dredge, gunslinger, juggernaut, mage, ostra, pin_ult, thief_chain, and so on).
  - Keep their VFX and sound; only the floating text goes.
  - Simplest route: payoff_fx stops spawning the label (one switch), and the callers stay.
- **Keep:**
  - Damage and heal numbers (crit styling OK).
  - Essentials that change a decision: DOWNED / REVIVING, the low-ammo and cooldown "not ready" feedback, pickup names, objective and extraction callouts.
  - When in doubt, cut it.
- **Assert:** a match with every kit firing its payoff spawns no word labels; damage numbers still appear.

## 120. Sable ult (Encore): spin, slowed, impactful; the outer edge hurts more (owner, 16:55 UTC Nov 5)
- The owner: "sable should spin around and be slowed during ult - it needs to feel impactful. and hurt people more on the outer edges".
- **Spin:** while Encore runs (2 s), she spins: a full-body spin (the Death Blossom read), not upper-body throws over walking legs. Blades fan out from the spin.
- **Slowed:** she moves ~50% slower while it runs (tune). This is a trade for the power, so she shouldn't dash freely through it; the current "keeps moving, shooting and dashing" goes.
- **Impact:**
  - Heavier cast hit: a short camera kick and a punchy sound.
  - The ring flares on each beat, and the blade hits read clearly.
  - A big final burst at the end.
- **Outer edge:** the outer-band bonus already exists in code (past 75% radius: harder + blight), but the owner doesn't feel it.
  - Make it obvious: a bigger multiplier (e.g. x1.6-2 vs the inner area).
  - A clearly visible gold rim band on the ground.
  - Rim hits look and sound different.
- Note: the owner may have tested an old build, but he wants this anyway.
- **Assert:** the cast → a spin anim playing for the duration; move speed ~0.5x; a rim hit deals ≥1.6x an inner hit.

## 121. Sable RMB (Bola): passes through people; a second contact (person OR tree/wall) stuns (owner, 16:56 UTC Nov 5)
- The owner: "sable rmb needs to pass through people and stun if it hits a second person (or a tree, anything it connects with - same with tree->person = stun)".
- Code today (thief_kit.gd header): it grounds and slows the first foe and flies on; it bounces once off a wall; a second foe means both are stunned. Missing: wall and tree contacts count as the stun trigger.
- **New rule:**
  - The Bola always passes through people.
  - Any second contact of any kind stuns:
    - person → person: both stunned (as now).
    - person → tree/wall/rock/any solid: that person stunned (pinned to it, the Ashe-style read).
    - tree/wall → person: the person hit after the wall is stunned.
  - The first person contact alone still grounds and slows.
  - Keep the bonus damage on a stun.
- Make the stun read: a tether/wrap VFX + a snap sound.
- Update the data, the card text and the tutorial line.
- **Assert:**
  - Each of the three cases stuns.
  - A single person with nothing behind → grounded and slowed only.

## 122. Ryzz: the lightning orb is always grabbable; her electricity is blue + pink, not yellow (owner, 16:57 UTC Nov 5)
- The owner: "ryzz should pick up the lightning orb even if she has a dash - it's a skill based thing. also her electricity should be a mix of blue and pink, not yellow".
- **Orb:** the mage_kit motes. Today an orb is only taken by Wirerun (_tick_run) or a Skycall pull, and on pickup _grab_mote refills dashes. Wherever it is gated or wasted when her dash is already up, remove that.
  - She can always pick it up: walking over it counts, as well as Wirerun.
  - Grabbing it is never wasted. With dashes full, bank 1 extra dash charge (overflow cap +1, tune), so chaining orbs is the skill expression.
  - Show the banked charge on the Shift icon.
- **Colours:** her whole electric palette goes blue + pink, with NO gold/yellow:
  - The kit's GOLD / DEEP_GOLD / COPPER become a hot pink (e.g. ff4fb8 / ff7ad0).
  - TEAL becomes an electric blue (e.g. 3fa9ff).
  - Covers the arcs, the orbs, Wirerun after-images, Static, the ult, the reset flash and the aim accent.
  - This matches item 116's pink LMB and pink stack counter.
- **Assert:**
  - Walk over an orb with full dashes → the extra charge is banked.
  - No yellow-hued colour (hue 35-65°) left in mage_kit / mage_sky / mage_ult / vv_fx.

## 123. Boki "Guard this spot": a small, visible zone it doesn't leave (owner, 16:58 UTC Nov 5)
- The owner: "'guard this spot' should keep them closer to a small area and it should be clear how small that area is - they shouldnt run out or be baited out by people so easily".
- Today: content/rules/boki_system.json follow.guard_leash = 24 m, so the Boki chases 24 m off its spot and is easy to bait.
- **Change:**
  - The guard zone radius is ~5 m (new key `guard_r_zone`, tune 4-6).
  - It attacks foes inside the zone, plus a short lunge reach (~2 m past the edge, e.g. its melee range).
  - It never pursues further. When a foe leaves, it walks straight back to the centre.
  - Ranged pokes from outside don't pull it out; it faces and growls at them instead.
- **Visible:**
  - While the order stands, draw the zone on the ground: a soft ring in the owner's team colour with paw-tick marks, and a brief pulse when the order is given.
  - The owner sees it clearly; teammates see it faintly; enemies see it subtly (fair warning, tune).
  - Also show the ring on the G flick-wheel "Guard" preview.
- **Assert:**
  - A foe kiting at 8 m from the centre → the Boki never goes past ~7 m.
  - After the foe leaves, it is back within 1 m of the centre in under 3 s.
  - The ring is drawn while cmd == "guard".

## 124. Boki wheel: merge Follow + Return into "With me"; the new slot is Bodyguard (owner, 17:02 UTC Nov 5)
- The owner: "i dont see a big difference between follow and return - should it just be one? and use the other slot for a diff ai command". He picked Bodyguard for the freed slot.
- **With me** (replaces Follow and Return):
  - It walks beside you and joins your fights as Follow does now.
  - Out of combat (no foe within combat_radius for ~2 s), it hops onto your shoulder by itself, so G throws it from there as Return does now.
  - The explicit-disengage behaviour of Follow stays.
- **Bodyguard (new):**
  - It sticks tight to you (≤2.5 m, never more than ~4 m away).
  - It intercepts whoever damages you: it hits them and body-blocks their line to you (stands between you and them).
  - It never chases. Once the attacker backs off past ~4 m from you, it returns to your side.
  - Its own ability prioritises peel and defence (knock away / shield) over damage.
  - A small shield-paw icon over it while active.
- **Wheel:** Chase, Guard, With me, Bodyguard.
  - Update the KinWheel icons and labels, the kin_command callout text ("with you" / "guarding you"), bots' order use and the tutorial line.
  - Old saves or orders using "return"/"follow" map to "with me".
- **Assert:**
  - Wheel picks → the four cmds.
  - With me, idle 2 s → on the shoulder.
  - Bodyguard: a foe hitting the owner from 8 m → the Boki engages, but stays within 4 m of the owner.

## 125. Vex Slipstep: tap/hold on ground AND air, a tap halves the cooldown, longer air dash (owner, 17:03 UTC Nov 5)
- The owner: "jump dash for vex should be longer. and her dash on both air and ground should be holdable or not for a short or long dash - and give 50% cd reduction if u tap it".
- Today (content/archetypes/gunslinger.json dash):
  - A tap = a 4.8 m skid; a hold = a 7 m slide with a 40% longer cooldown (cd 8.5).
  - In the air, only a tap (4.7 m, air_k 0.667).
- **New:**
  - **Ground:** a tap = a short skid (4.8 m) with **50% of the cooldown** (4.25 s at rank 1). A hold = the long slide (7 m) with the normal cooldown (8.5 s; drop the +40% penalty).
  - **Air:** the same tap/hold choice. The air dash gets longer: a tap ~6 m, a hold ~9.5 m (tune: it should feel like a real jump-dash).
    - The same rule: a tap = 50% cd, a hold = full.
    - Air after-images + skid streaks, as now.
  - Rank upgrades scale both (rank 2/3 lower the base, and the tap stays half).
  - The tap/hold threshold stays as it is now. Show the short-tap cooldown clearly on the Shift icon.
- Update the desc, the clip lines and the tutorial ("Tap: short skid, half cooldown. Hold: long slide. Works in the air too.").
- **Assert:**
  - Ground tap → cd 4.25; ground hold → cd 8.5.
  - Air tap → ~6 m, cd 4.25; air hold → ~9.5 m, cd 8.5.

## 126. Brall (Juggernaut) Warchain + Lunge: a straighter chain, a free Lunge aim, the Lunge + pull boost tech (owner, 17:10 UTC Nov 5)
- The owner: "his e works better now but it bends too much, looks weird. also his rmb hold forces you to go down his e still, it should be able to go anywhere and then trigger his e. also should be able to look away while holding rmb, use second pull of e, then release rmb mid air for a boost of speed type of thing".
- **Chain look:** the Warchain bends/sags too much.
  - Make it near-straight and taut: at most a slight sag at rest, dead straight under the pull.
  - A little whip only on the throw.
- **Lunge while tethered** (juggernaut_kit.gd:695 `_chain_lunge`, :811): today a charged Lunge released while chained is forced to run along the chain.
  - Remove that. The Lunge always goes where you aim, tethered or not; the chain stays attached and stretches.
  - Remove the Chain Lunge as the forced result.
  - A Lunge that hits still lets you recast E to pull afterwards.
- **Momentum play (owner's clarification, 17:12 UTC: "its not a speed boost trick but more how you can play with momentum to move in interesting ways"):**
  - The goal is a movement system: the pull's velocity and the Lunge combine as real momentum (vector add), so the aim angle vs the pull direction shapes the path (curves, swings, slingshots, redirects). It is not a fixed boost number.
  - The sequence below is one example of that.
  1. Hold RMB (the Lunge charging; he can look and aim anywhere).
  2. Recast E (the pull starts; :833 currently converts the charge into a Haul Slam, so remove that auto-conversion).
  3. Release RMB mid-pull or mid-air → the Lunge fires the aimed way, carrying the pull's momentum: a speed boost (e.g. pull velocity + the Lunge impulse, capped ~1.4x the normal Lunge distance).
  - The Haul Slam stays only if he releases RMB on arrival at the anchor (tune), or drop it if it conflicts.
  - It should feel like a slingshot when aimed with the pull, and like a swing or redirect when aimed across it. Momentum carries on into the landing (no hard stop).
- **Assert:**
  - Tethered + aiming 120° off the chain → the Lunge goes the aimed way.
  - Hold RMB → recast E → release mid-pull → the travel is longer/faster than a plain Lunge, in the aimed direction.
  - The chain's sag is ≤0.15 m at rest.

## 127. Sable: the pistols glow while the empowered shot is up + a stronger hit sound (owner, 17:11 UTC Nov 5)
- The owner: "sable needs her guns lit up for a few seconds while her auto is empowered after dashing. and she needs to have a stronger sound for when it hits".
- **Glow:**
  - While the post-Vault empowered bolt is ready (thief_kit.gd: the glint at her hand, :308), both pistols light up: an emissive violet/cyan glow on the barrels, a soft light and small sparks or a trail when she moves.
  - It shows for the full empowered window (a few seconds), then fades out quickly when spent or expired.
  - Visible to everyone, online too (it replaces or extends the small glint ping).
- **Sound:** a much punchier hit for the empowered bolt landing: a sharp crack + low thump + a short ring.
  - It should clearly stand out from a normal LMB hit (+3-4 dB, a layered transient).
  - S4's sound set; S5 can add it in vv_sfx/dj sfx if S4 is idle.
- **Assert:**
  - After a Vault → the gun glow is on until the empowered shot or the timeout.
  - The empowered hit plays the new sfx id.

## 121b. Sable Bola: fly further past the first person (owner, 17:12 UTC Nov 5)
- The owner, playing v0.23.0: "sable rmb was updated - but it doesnt go far enough, it needs to go a bit further past the first person".
- content/archetypes/thief.json rmb.bola.after 3.8 → **5.5 m** (rank 3 after_r3 +1 stays, so 6.5).
- Its lane preview shows the carry-on distance past the first contact.
- Do it together with item 121 (wall/tree stuns).

## 128. Sable E (Shadow Knife) works on walls: blink to beside where it sticks (owner, 17:12 UTC Nov 5)
- The owner: "sable e wont tp her if its in a wall - it should work on walls, just put her next to it".
- Today a knife that hits a wall (refund_wall 0.25) doesn't let her recast-blink to it.
- **Change:** a knife stuck in a wall/tree/rock is a valid blink target. She lands at the nearest walkable spot on her side of the surface, ~0.6 m out from the knife (snap to the nav ground; never inside or behind the wall).
  - The auto-step after 6 s works the same.
  - Keep the 25% wall refund.
- **Assert:**
  - Knife into a wall → recast → she is within 1 m of the knife, on the thrower's side, not overlapping collision.
  - The same for a tree.

## 129. A weird mid-air explosion on dash heroes (Vex, Sable so far) + Sable's air dash must match her ground dash (owner, 17:13 UTC Nov 5, v0.23.0)
- The owner: "i keep getting this weird explosion in air with dash characters - vex and sable so far. also sable dash in the air is different than on the ground, which is incorrect".
- **The explosion:** find it and kill it.
  - Suspects:
    - hunter.gd glide_handoff → `_glide_boost_fx` (boost_fx_t trail + whoosh) firing when an air dash ends and the glider opens.
    - A shared class air-dash (ex) burst.
    - ashwick's bellows "poof" leaking to other kits.
    - A payoff/DashReset flash.
  - Repro: jump + dash with Vex and with Sable on v0.23.0 and capture frames.
  - Remove whatever isn't the hero's own dash VFX. If it's the glide-boost, make it a subtle trail only (no burst).
  - Check every dash hero for the same thing.
- **Sable's air dash = her ground dash:** thief_kit.on_dash uses air_dist/air_time and the class long-dash ("ex") path in the air.
  - Make the air Cartwheel identical to the ground one: the same distance, time, anim, invuln, Vault charge use and empowering. Only gravity/landing differ (she still lands in her crouch).
  - Drop the separate air values (keep momentum into the landing).
- **Assert:**
  - No unexpected fx spawns (log the fx ids) on an air dash for all 12 heroes.
  - Sable's air dash distance and time == ground ±5%.

## 130. Vex Burr Charge: a miss is a miss, with no cone on the ground (owner, 17:13 UTC Nov 5)
- The owner: "if vex misses her grenade and it hits the ground/no one, it shouldnt explode with the cone - it just misses".
- Today (gunslinger.json rmb): a direct hit hurts and Dazes; meeting a wall OR the ground blasts a cone back at her.
- **Change:**
  - Landing on the ground or running out of range with no foe hit → a small dud puff + a fizzle sound, no damage, no Daze, no cone.
  - A direct hit is unchanged.
  - **Walls keep the cone-back blast** (ext's reading: the owner said "ground/no one"). If he wants walls to fizzle too, it's one flag: add `cone_on_wall` true by default.
- Update the desc/clip/tutorial text ("A direct hit Dazes; off a wall it blasts a cone back; anything else misses").
- **Assert:**
  - A ground landing → 0 damage events, no cone fx.
  - A wall → the cone as now.
  - A direct hit → as now.

## 131. Kael: the RMB hold pose + the sword's size and shape (owner, 17:14 UTC Nov 5)
- The owner: "kael rmb is more like he's holding it in the direction he's facing - it's over his head, but not held up. also his sword is too big still and doesnt look like his sword from the art".
- **RMB hold pose** (the Lunge charge and the Slam wind-up):
  - The blade is held level at about head height, pointing forward the way he faces: the hilt by his head/shoulder, the blade horizontal and aimed ahead like a spear. Brall's held pose.
  - Not raised vertically overhead.
  - The release follows from that line (a thrust/lunge forward, or for the Slam, a short arc down from it).
- **The sword:**
  - Scale it down to the art: roughly hip-to-shoulder length against his body in briefs/art-refs/kael_FINAL_sheet.png.
  - Remodel it to match briefs/art-refs/kael_weapons.png: the blade shape, guard, grip/wrap and colours.
  - Check it against the fidelity checklist.
- Owner: S2 (model + anim). S5 integrates.
- **Assert/screens:**
  - A side-by-side of the in-game sword vs kael_weapons.png.
  - A 4-frame strip of the RMB hold (front + side).

## 132. Breaker LMB hold spin: a faster ramp, carries him further, a clear timing release (owner, 17:15 UTC Nov 5, v0.23.0)
- The owner: "his spin doesnt spin / ramp up to fast enough speed and doesnt take him far enough - it also needs a 'timing' cast like brall auto and myth auto being held".
  - "ice guy" = Breaker; the owner knows his look is changing.
- Today (bulwark.json lmb): full 1.25 s, spin_turns [2.5, 4.0]/s, carry [1.5, 1.8] m, plus a `perfect` launch on the flash.
- **Change:**
  - **Ramp:** spin_turns ~[3, 9]/s on an ease-in curve, so it visibly whips up to a blur, with the motion trail thickening and a rising whoosh pitch.
  - **Carry:** the release slam carries him [3, 6] m (tune).
    - The perfect-timing release launches further (~8 m) with extra knockback and a "clang" hit-stop.
    - Momentum is kept into the landing (the same momentum feel as item 126).
  - **Timing cue,** the same language as Kael's (juggernaut) LMB hold and Myth's held auto:
    - A charge ring/bar on him that fills and then flashes bright in a short perfect window (~0.18 s).
    - A distinct ping sound on the window, and the hammer head flaring.
    - Releasing in the window = the perfect launch. Holding past it = a normal full slam (no penalty beyond losing the bonus).
    - The cue is readable to the player and subtle to enemies.
  - Use the same timing-window component for every held auto with a perfect release, so they all read alike.
- **Assert:**
  - Turns/s at full ≥ 8.
  - Normal full carry ≥ 5 m; a perfect release ≥ 7.5 m.
  - The window fx/sfx fire once per hold.

## 133. Cinder (the "pyromancer") dash: slower, shorter, and it always deals damage (owner, 17:16 UTC Nov 5)
- The owner: "pyromancer dash is too fast and takes her too far - it should also do dmg".
- Today (ashwick.json dash, Soot Ram):
  - Ground: 3.4 m / 0.28 s, stops on the first foe for 16 damage + shove + 17 Char.
  - Air: an 8 m / 0.24 s poof (~33 m/s) with no damage.
  - The ground one already deals damage, so the complaint is the air poof (ext's reading). Apply the feel to both.
- **Change:**
  - Air poof: 8 m → ~5 m and 0.24 → ~0.36 s (~14 m/s); keep a little momentum (air_keep 0.5 → 0.3).
  - Ground: unchanged distance; ease the start burst so it reads less snappy (tune).
  - **Damage on both:** the air poof hits the first foe it meets the same way the ground Ram does (16 + shove + 17 Char, stops on them).
    - Plus a small soot burst at the launch point: ~1.5 m, 6 damage, Char 5. It fits the "poof".
  - Check whether the poof's smoke cloud is the "weird explosion in air" from item 129. If it's oversized or misfiring on other heroes, fix it there.
- **Assert:**
  - Air dash distance ≤5.5 m and speed ≤15 m/s.
  - An air dash into a foe → a damage event + Char.
  - A ground dash is unchanged.

## 133b. Cinder dash: 2 real charges like Felix, each one shorter (owner, 17:16 UTC Nov 5)
- The owner: "she should have 2 charges of it like felix, but go less far".
- The data desc already says "Two charges", but in play she doesn't get them (probably the air poof uses the class long dash ("ex") path with its own single cooldown, or max_dashes isn't 2 for her).
- Make it 2 charges of the same dash on the ground AND in the air, sharing one pool, each recharging on cd 9 s (tune), like Felix's double hop.
  - The HUD shows 2 pips.
- Each one goes less far:
  - Ground 3.4 → ~2.6 m.
  - Air ~5 m (from item 133) → ~4 m.
  - Two in a row then cover about what one long one did.
- **Assert:**
  - max_dashes == 2 for ashwick.
  - Two back-to-back dashes go off on the ground and in the air.
  - The distances are within tune.

## 129 update: the purple dash explosion is FOUND: Gravadillo's dash rider (owner, 17:18 UTC Nov 5)
- The owner's base Boki is Gravadillo (kin id pebbit, glow #b48cff purple). Boki dash riders (docs/DASHES_AND_ABILITY_FEEL.md §3.5) give his Gravity Wake: an `on_end` burst 3.5 m + pull 8 at the end of EVERY dash, on any hero.
  - That is the purple explosion on Vex and Sable, ground and air. It is working as designed, but nothing in the game tells you about it.
- The owner decides what to do with it (ext is asking). Interim fix regardless:
  - The burst only fires if a foe is within 3.5 m. With nobody near: no explosion.
  - Its visual is a smaller, quicker gravity ripple (an inward pull), not a blast.
  - The HUD's Shift icon gets a small Boki badge, and its tooltip/card says "Gravadillo: Gravity Wake. Your dash ends in a pull."
  - The same for every Boki's rider.

## 62 again: Claire still can't air-dash (owner, 17:18 UTC Nov 5, v0.23.0)
- The owner: "i still cant air dash (should be same as regular dash) on claire".
- The work exists on `ext/claire-62-65` (c4cf394a, 15:48 UTC) but is NOT merged to main. S5: integrate it in the next batch.

## 61b. Tarek RMB Quakefall: a committed, locked forward slam (owner reiterates, 17:18 UTC Nov 5, v0.23.0)
- The owner: "tarek rmb should automatically start the animation and bring him forward - should not be holdable beyond like 2s. right now u can hold as long as u want and move during it - its not a spell u move during, it locks u into a forward slam animation that goes up and does a bigger slam".
- **On press:**
  - The slam animation starts at once and he is LOCKED into it: no free movement or steering, and no other abilities except the item-61 jump variant (decide by kit consistency; default: locked).
  - The animation itself carries him forward.
  - Holding only extends the rise: higher and a bigger slam, capped hard at ≤2 s total (default: the cap 1.0 s; full power at the cap; auto-release at the cap).
  - Release (or the cap) → he goes up and slams down ahead: a bigger radius/damage with more hold.
  - A tap = the quick small slam in front (item 61).
- His branch `ext/kit-tarek-61-67` (eb040e7d) has item 61 but ISN'T merged. S5 merges it; then whoever owns Tarek's kit adds the lock + the forward carry if 61 didn't already lock movement.
- **Assert:**
  - Holding RMB for 5 s → the slam fires at the cap.
  - Move input during it changes nothing (position delta only the forward carry).
