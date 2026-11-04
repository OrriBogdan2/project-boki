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
