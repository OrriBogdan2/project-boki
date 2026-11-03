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
