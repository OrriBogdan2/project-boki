# Owner playtest review, 2026-11-03 (sync75 on his PC). Running list; more items will be added
<!-- briefs-trim pointer -->
> Trimmed 2026-11-06 by briefs-trim: 11 finished/superseded entries moved to briefs/archive/OWNER_REVIEW_1103-2026-11-06.md. Kept here: owner rules and decisions, open owner questions, unmerged READY branches, open assignments and review items, the latest SHIPPED/RELEASED, holds still in force, and the last 12 h. Older archives: briefs/archive/OWNER_REVIEW_1103-*.md
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

## 78. LATER: redo the prologue film: open on an evil deity in human form (owner, 22:56 UTC Nov 4)
- Owner: "I think we need to redo the film to show an evil deity in human form first. All of it is pretty rough. Put that as a note for later."
- Direction for the rebuild (after the resets; with the art pipeline): the film opens on the **evil deity in human form**: the Wyrm-crowned Tyrant / the Wyrm as a human sovereign (DECISIONS + LORE_MASKS) on the Throne, so players meet the villain before the fall. Then the rest of the story beats from LORE_MASKS (the cold open with the girl in chains and the Mask, the Sundering, the Wardens' Masks scattering, the race for the Wyrmheart). Owner verdict on the current film: "pretty rough": plan it as a proper storyboarded short (key art from the image-gen pipeline, camera work, timing) rather than polishing the current scenes.
- Not now: logged for planning after the usage resets.

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

## 134. Tarek ult (Basalt Spine) also raises a platform under him, which works over the abyss (owner, 17:19 UTC Nov 5)
- The owner: "tarek ult should spawn ground beneath him as well as the walls he can shoot - and that ground should spawn under him in abyss".
- Today: a 9-rock ridge at the cursor (12 m arc), his rocks for 7 s. Over the abyss the ridge is walkable, but nothing appears under HIM.
- **Add:** on cast, a basalt platform erupts under Tarek's feet at the same moment as the ridge.
  - A disc ~3.5 m radius (tune), flush ground-level stone with molten cracks; it lasts the ridge's 7 s.
  - Over the abyss or mid-air (he's above the abyss) it spawns directly under him and catches him: a real walkable floor, so the ult works as an abyss save/escape and a stage.
  - It crumbles with the ridge, with the same warning, and whoever stands on it falls.
  - Allies can stand on it too.
  - It counts as his rock for his kit interactions (punch launches, Rock Hop item 111 targets).
- **Assert:**
  - A cast over the abyss → Tarek grounded on the platform, not falling, for 7 s.
  - A cast on land → the platform drawn under him + the ridge at the cursor.

## 134b. Tarek ult walls: tall enough that a jump bounces up onto them, not over (owner, 17:19 UTC Nov 5)
- The owner: "walls should also be taller so if he jumps into them he doesnt go over them without bouncing up on them (as can teammates)".
- The ridge rocks get taller than a normal jump's apex (+ margin), e.g. ~2.6-3 m, tune vs jump height.
  - Jumping into one doesn't clear it; you land or bounce up ON TOP via the mantle/climb (Tarek and allies alike).
  - Foes are blocked and can't jump over.
- This builds on item 67 (taller rocks, on the unmerged ext/kit-tarek-61-67). Make sure the ult ridge uses the new height too.
- **Assert:** a plain jump at the ridge → it never passes over without contact; a jump + mantle → standing on top.

## 129 DECISION: remove Boki dash riders entirely (owner, 17:20 UTC Nov 5)
- The owner picked "Remove them entirely": dashes are purely the hero's own; Boki affect play only through their own abilities.
- Remove the rider system's runtime effect for all kin (Vespyx Venom Trail, Gravadillo Gravity Wake, Prismander Prism Decoy, Mycroll Spore Puff, Echolop Echo Step, Lunowl Moon Blink, + any others):
  - No on_pass / on_start / on_end / repeat / as-blink, and no +1 dodge charge from the perch.
  - Strip the rider text from the Boki cards and tooltips.
  - Mark docs/DASHES_AND_ABILITY_FEEL.md §3.4-3.5 as retired (the owner's decision 2026-11-05).
- This supersedes the interim cleanup in "129 update".
- **Assert:** for every kin, a dash spawns no kin fx and deals no damage/pull.

## 135. Motley (Void Jester) Shift, Lantern Trade: a loud travel sound, and much less slowed (owner, 17:20 UTC Nov 5)
- The owner: "his shift needs to make a noticeable sound as it's travelling. he's also slowed too much during it".
- (The owner also re-confirmed the 129 decision: "no explosion on dashes through boki, i dont like that ability, too distracting".)
- Today (ostra.json dash): the lantern lobs up to 12 m; he hovers and drifts at 30% speed (fly_slow 0.3) for 1.8 s until the swap.
- **Sound:**
  - A clearly audible looping travel sound on the lantern for its whole flight: an eerie chime/whirl with a rising pitch toward the landing, positional so foes hear where it's going.
  - A distinct "arrival" tick just before the swap.
  - S4's set if it's around; otherwise S5 picks from the library.
- **Slow:** fly_slow 0.3 → ~0.7 (he moves at ~70% speed while it's in flight; tune 0.65-0.8). He still hovers at his height over the abyss.
- **Assert:**
  - The travel sfx plays from the throw to the landing (one loop instance).
  - His move speed during it is ≥0.65x.

## 136. Motley rework: no weapon, void magic from his hands; RMB becomes a card flurry (8 cards, slow, stun on 4 hits) (owner, 17:22 UTC Nov 5). Big item: do it carefully.
- The owner: "void jester should be shooting void stuff and not have a weapon on him. we can make his rmb cards, and multifire, that slow and then stun if he hits 4 on someone (lets say he gets a burst of 8). this is different than void who does a wind up stun, so this is a bit of work to get this right".
- **No weapon:**
  - Remove the held weapon model (the tether_lantern).
  - His LMB keeps its mechanics: orbs to full range through walls, the longer-wait = bigger/faster/harder orb, a full orb slows.
  - Re-skin it as void magic cast from his hands: dark violet/black orbs with a teal rim (his palette), a hand-flick cast anim alternating hands, a gloved-hand glow while charging up the wait bonus.
  - Card text: "Void orbs" (no lantern).
  - The Shift "Lantern Trade" keeps its mechanics; its thrown object becomes a void card/orb (S5/S2 decide; keep the name or rename to "Void Trade" for consistency).
- **RMB: card flurry** (replaces Shard Snap, the source's wind-up stun):
  - A quick multi-fire burst of **8 cards**, flicked rapidly toward the cursor (~0.08 s apart, a slight fan/spread, tune), each a fast projectile.
  - Each card hit: small damage + a stacking slow on that foe.
  - **4 card hits on the same foe within the burst = a stun** (~0.8 s, tune), once per burst per foe. A big "pop" on the stun.
  - No wind-up: it fires on the press, and he can move while flicking (slight move slow, tune).
  - Read: void-tinted playing cards (jester theme) with a violet trail. A card tally on the target (pips 1-4) makes the stun readable.
  - Tune damage so 8/8 on one target ≈ Shard Snap's old burst value.
  - Cooldown ~10 s (as now, tune).
- **Art:**
  - S2 removes the weapon from his model, adds the hand-cast poses, and makes a card prop/VFX.
  - Check his FINAL sheet (`briefs/art-refs/ostra_FINAL_sheet.png`): if the sheet shows a weapon, keep it as a cosmetic only on his back/belt or drop it. Default: drop it.
- **Owner:**
  - Kit: S5, or S2 if S5 is overloaded.
  - Model/anims: S2.
  - Sounds: S4 (a card flick, a stun pop, void orb).
- **Assert:**
  - 8 cards per press.
  - 4 hits on one dummy → a stun once; 3 hits → slowed, not stunned.
  - No weapon node on his model.
  - LMB from the hand anchors.

## 136b. Motley LMB: a new look entirely (owner, 17:22 UTC Nov 5)
- The owner: "i dont like the look of his lmb either".
- Don't just recolour the current orb; design a fresh look with item 136.
- Ext's proposed direction until the owner says otherwise:
  - A small swirling void "eye"/rift orb: an inky black core, a thin violet-to-teal rim, faint card-suit glyphs (♠♦) orbiting it.
  - A wispy smoke-ribbon trail.
  - A charged (waited) shot: bigger, with a crackling rim and the glyphs spinning faster.
  - On hit: an implosion pop (a quick inward pull), not a splash.
- Post a 3-option VFX comparison strip (stills) to the owner via ext BEFORE integrating, so he picks.

## 137. Weapons: true to scale and part of the character, on ALL heroes (owner, 17:23 UTC Nov 5)
- The owner: "make sure the weapons dont all look oversized and out of place - they should look like they're part of the character / their kit". (Dredge looks bad, but he's becoming Grimble, so judge the Grimble model.)
- **A rule for every hero model:** the weapon's size, shape, colours and attachment match that hero's `<hero>_weapons.png` and `_FINAL_sheet.png` in briefs/art-refs.
  - Measured against the body on the sheet (e.g. "blade = hip-to-shoulder"), not eyeballed.
  - Held/attached at the right socket, so it looks like it belongs: Vex's cannon IS her right arm; Sable's pistols; Ryzz is hands-free; Motley has no weapon (item 136).
- **Add to FIDELITY_CHECKLIST.md:** a mandatory "Weapon scale + fit" row (the in-game weapon vs the sheet, a side-by-side at the match camera and a close-up).
- **S2:** do a weapon-scale audit across all 12 (one contact sheet of each hero in-game vs its weapons ref) as part of the ART-1 merges.
  - Fix the oversized ones before or with the merge.
  - Kael is already item 131.

## 138. Pip LMB embers: short and small when spammed; bigger and longer after a pause (owner, 17:24 UTC Nov 5)
- The owner: "her base auto goes too far. if you shoot slower, it should be bigger and go farther (like void), by waiting a bit between shots. otherwise you can spam it and it's shorter and smaller".
- Today (tender card): a hold pushes embers from alternating hands that fly PAST the cursor; each hit adds Kindle.
- **New:** the same "wait = prime" model as Motley's LMB (ostra.json lmb: idle 1.4, prime_dmg/speed/size).
  - **Spammed** (no gap): a short, small ember. Range cut to ~60% of today (e.g. it dies at/near ~8 m instead of flying past the cursor; tune), lower damage per hit, still adds Kindle.
  - **Waited** (gap ≥ ~1.0 s, tune; the prime builds over the gap): a bigger, faster ember that flies to today's full range or a bit more, with more damage (+~35%) and +1 extra Kindle.
  - Scale smoothly between the two by the gap length.
  - A visible "primed" tell: her lantern hand glows brighter and the next ember swells in her hand. A distinct primed-shot sound.
  - Shared code with Motley's prime if practical (one "prime by idle" helper), but Pip keeps her own look.
- **Assert:**
  - A spam ember range ≤ ~8 m.
  - An ember after a 1.2 s idle: range ≥ today's, size and damage greater.
  - Kindle +2 on a primed hit.

## 118b. Pip RMB wind-up: a stretch-and-gather animation, Elluna as the reference (owner reiterates, 17:25 UTC Nov 5)
- The owner: "rmb needs a windup time and shouldn't be holdable - like a 1s windup (maybe 1.5) where she does like a stretching motion to get the energy then shoots it at someone - look at elluna for reference".
- The mechanics are already done on `ext/kit-pip-118` (94a90a69: a fixed 1 s wind-up, then an auto-throw on the aim at that moment). It is NOT merged, so S5 merges it with the priority branches.
- **Add the animation and VFX** (S2 anim, S3 VFX):
  - Over the wind-up (1.0 s; tune to 1.2 if 1.0 feels rushed, max 1.5) she stretches: arms sweep up and out, rising onto her toes, light motes drawn in from around her into her lantern/hands (a gather), a swelling glow.
  - Then a snap forward release.
  - Elluna-like: a graceful, readable channel that enemies can see coming.
  - A rising gather sound into a bright release.
- **Assert:**
  - The anim length matches the wind-up.
  - The gather VFX is visible to enemies.
  - Hold or release timing doesn't change it.

## 140. Lisette (Red Stitch) RMB Heavy Shot: no arrow left on the ground, a smaller projectile, longer range, a better wind-up, a stronger slow, a loud Myth-like sound (owner, 17:27 UTC Nov 5)
- The owner: "red stitch rmb shouldnt leave an arrow on the ground, and its way too big. also her range should be longer and the windup feel better. rmb should slow her more and have a louder sound like myth rmb".
- Follows item 114 (the big needle arrow, slowed while charging, charge sound); that overshot on size.
- **No ground arrow:** the needle vanishes on impact or at max range with a short spark/thread fizz. No lingering prop or decal (a wall pin can show a brief stitch flash, then disappear).
- **Size:** the needle projectile goes down to ~half its current visual size (thin, long, needle-like). Its hitbox is unchanged unless it's oversized too.
- **Range:** pin.range 14 → ~20 m (rank 3 +3 stays). The aim lane shows the full range.
- **Wind-up feel:**
  - A smoother, weightier draw: the needle drawn back visibly with string tension, a slight camera tighten and a subtle zoom/vignette at full, the ring closing into a crisp "ping" at full (1.1 s).
  - No hitch at the 0.5 s start threshold; blend it.
- **Slow while drawing:** a stronger move slow (e.g. to ~40% speed while drawing, tune), so committing to it matters.
- **Sound:** a much louder, chunkier release like Myth's charged RMB: a deep bow thrum + a whip-crack + air tear on full charge, and a strong impact thunk.
  - The draw creak rises in volume too.
  - S4's sound set (S5 can pick from the library).
- **Assert:**
  - No node persists >0.3 s after impact.
  - The projectile mesh length is ≤ half the previous.
  - range == 20.
  - Move speed while drawing is ≤0.45x.
  - The release sfx is at least +4 dB vs today.

## 141. The perfect-timing window: the HERO lights up white (all timing heroes); Lisette's LMB window is a bit easier and quicker (owner, 17:27 UTC Nov 5)
- The owner: "she should also light up white (as should all timing characters) when they are in the perfect hit window - i think hers is also a tad too short, make it slightly easier to hit (and slightly faster) for her lmb".
- **The global rule** (extends item 132's shared timing-window component):
  - While ANY held attack is inside its perfect window, the hero's whole model gets a bright white rim/flash glow (a fresnel overlay ~0.6 strength, on for exactly the window).
  - Applies to Lisette LMB, Kael LMB/RMB holds, Breaker LMB spin, and any other kit with a "perfect" release.
  - Visible to the player clearly; to others subtly (it's a skill tell).
  - Plus the existing ping.
- **Lisette LMB:**
  - The perfect window is wider: perfect_t 0.15 → ~0.22 s (tune 0.2-0.25).
  - The draw time to reach the window is ~15% faster.
  - Both are data changes in archer.json + her timing code.
- **Assert:**
  - The white overlay is on iff in the window, for all timing kits.
  - Lisette window ≈0.22 s, reached ~15% sooner than now.

## 142. Lisette ult: visible big arrows, not a railgun beam, plus a map-wide ult sound (owner, 17:28 UTC Nov 5)
- The owner: "she should have big arrows for her ult so its less of a railgun looking thing - but not as big as the rmb is currently, like maybe half the size - and it should play a sound so people are aware she used her ult".
- **Visual:** replace the beam/railgun read with actual arrow projectiles.
  - Each shot is a big needle-arrow at ~half the CURRENT RMB arrow size, which is about the same as the new RMB size after item 140. Keep the ult a touch bigger/brighter than the RMB so it stays special.
  - Red thread trail, a visible arrow body in flight (no instant line).
  - An impact burst and no lingering arrow (the item 140 rule).
  - Gameplay speed/hit logic unchanged unless the beam was hitscan; then use a very fast projectile (≥80 m/s) to keep the feel.
- **Ult awareness sound:**
  - On cast, a distinctive loud cue heard by everyone in a wide radius (map-wide or ≥40 m): her signature (e.g. a taut string creak into a sharp needle "ting" + her voice line).
  - Audible to enemies so they know the ult is up.
  - Plus a release sound on each shot.
  - S4's set.
- **Assert:**
  - Ult shots spawn arrow meshes, not a beam.
  - The cast sfx plays for an enemy listener at 40 m.

## 143. Animation quality pass: crouch first, then everything (owner, 17:28 UTC Nov 5)
- The owner: "in general everyone's crouching animation (and animations in general) needs to look cooler".
- **Phase 1, crouch (all 12):**
  - A low, athletic, character-specific pose, not a generic squat:
    - The hips drop and the spine leans forward.
    - The weight is on the balls of the feet; one foot slightly forward; the head up, scanning.
    - The weapon/hands held ready in the hero's style.
  - Personality per hero:
    - Sable: predatory, low.
    - Kael: a blade-ready guard.
    - Pip: timid, lantern close.
    - Vex: a cocky half-kneel, cannon on the knee.
    - Breaker: heavy, a hammer-brace.
    - Ryzz: a bouncy coil, finger guns ready.
    - etc.
  - A crouch-walk with a smooth sneak cycle and anticipation on the enter/exit (a 0.1 s dip/settle), not a snap.
- **Phase 2, the core set per hero,** with the same principles: idle (breathing, a weight shift, a personality idle every ~8 s), run (lean into speed, arm swing, follow-through on hair/scarf/tails), jump/land (anticipation, squash on land), dash (a strong pose silhouette), hit react, downed.
  - Principles: clear silhouettes at the match camera, anticipation → action → follow-through, ease curves (no linear), secondary motion on cloth/hair.
  - Reference quality bar: SUPERVIVE / Arcane-style stylised game anims.
- **Process (S2):**
  - First, a before/after contact strip of the crouch for 3 heroes (Sable, Kael, Pip) to the owner via ext for a style OK.
  - Then roll out to all 12 alongside the ART-1 merges.
  - Weave in the anim notes already queued (131 Kael pose, 136 Motley casts, 139 Ryzz alternating, 118b Pip stretch).

## 140b. Lisette Heavy Shot knockback: reliable and obvious (owner, 17:29 UTC Nov 5)
- The owner: "her rmb also isnt knocking people back like it should, its very finicky - it should clearly push back".
- Data: pin.push [8, 12] (the card text says 6 → 12, so fix the mismatch). In play it's inconsistent.
- **Investigate:** is the push applied along the arrow's direction or from the shooter position? Is it eaten by the target's movement input/friction, cancelled by the stop-on-hit, or applied on a frame where the knock is overridden? Is it smaller for an uncharged release?
- **Fix:**
  - A guaranteed knockback along the arrow's travel direction: a minimum ~4 m displacement at the minimum charge and ~7 m at full (tune).
  - Applied as a short forced-movement (0.2-0.3 s, the target can't steer during it), not a velocity nudge.
  - A visible slide/dust trail on the target + a hit-stop on the impact.
  - The wall pin (within 3 m) still triggers off this travel.
- **Assert:**
  - On 20 test shots (varied charge, a moving target), the displacement is always ≥4 m in the arrow direction.
  - The card text matches the data.

## 144. Vex E (Longneedle): a limited turn rate while charging, Ghost's E as the reference (owner, 17:29 UTC Nov 5)
- The owner: "vex should have restricted movement on how far she can turn during her e, right now its too much - look at ghost e for reference".
- Today: a 0.6 s charge where the line "tracks your aim" freely; she stands still.
- **Change:**
  - During the charge, the aim direction follows the cursor at a capped turn rate (e.g. ~90°/s, tune 60-120; Ghost's E feel).
  - The aim is locked on the cast direction at the press, then can only drift slowly, so a flick across the screen doesn't drag the beam.
  - The line preview shows the actual (lagging) aim, not the cursor.
  - At fire, the beam goes along the constrained aim.
  - Her body rotation follows the same capped rate.
  - Online: send the constrained aim, not the cursor.
- **Assert:**
  - A 180° cursor flick at the press → the beam fires within 60° of the initial direction (at 90°/s × 0.6 s ≈ 54°).
  - A small tracking adjustment still works.

## 125b. Vex Slipstep ~10% faster (owner, 17:30 UTC Nov 5)
- Both the tap and the hold, ground and air: the same distances as item 125, ~10% shorter durations (roll_t 0.45 → ~0.41, slide_t 0.55 → ~0.5; air the same ratio).

## 144b. Vex E camera pull scales with aim distance (owner, 17:30 UTC Nov 5)
- The owner: "if you're hitting someone close range with your E, it shouldn't make the screen pull away; if you're aiming further away it should push the screen out further, but close to you less so, so it's not disorienting".
- view_zoom 0.25 is applied flat today. Scale the camera push-out by the aim distance:
  - ~0 for an aim within ~5 m.
  - Ramping smoothly up to the full 0.25 (or a bit more) at the full 18 m range.
  - It follows the (turn-capped, item 144) aim point, eased, with no sudden jumps.
- **Assert:** an aim at 3 m → camera offset ≈0; an aim at 18 m → the full push.

## 121c. Sable Bola: instant cast, no wind-up (owner, 17:31 UTC Nov 5)
- thief.json rmb.bola.cast 0.4 → 0. It throws on the press.
- Keep the lane preview only while aiming if the input model needs it; otherwise none.
- Bundle with 121/121b.

## 145. The little things flying around their head → MOTHS (owner, 17:31 UTC Nov 5)
- The owner: "the little things flying around their head should be moths, not random squares".
- Ext's reading: Pip's Kindle stacks shown orbiting a foe's head (her lantern theme: moths drawn to the light).
- If the squares are actually Sable's Marks or another status orbit, apply the same idea wherever these square orbiters are, and tell ext which it was.
- Replace the square particles with small moth sprites/meshes: two flapping wing quads, warm-lit wings, a fluttering erratic orbit, the count = the stacks.
- The VFX is S3's (or S5's).
- **Assert:** no square orbit particles remain; the moth count tracks the stacks.

## 146. Lisette dash: slightly farther + clearly 2 charges (owner, 17:32 UTC Nov 5)
- The owner: "stitch should go slightly farther with dash" + "she should also clearly have 2".
- +~15% dash distance (tune).
- She has 2 dash charges, shown clearly on the HUD (item 147).

## 147. Dash charges, resets and the dash UI: copy SUPERVIVE (owner, 17:32 UTC Nov 5)
- The owner: "check how supervive does dash resets, especially where characters like myth or brall have 2 charges. also check their ui for it / if they do it on the bottom etc - i want to copy it".
- **Research first, using the footage** (now on branch `ext/hero-ref-footage`, folders `pin` = Myth, `juggernaut` = Brall, `venator` = Ghost, etc.; see its README) + briefs/hero-ref/HUD.md:
  - How multi-charge dashes recharge: one at a time, or all together? Is the gap between uses ~0.4 s (Brall's notes say Quick Dash has 3 charges, 0.4 s between uses)?
  - How resets show: what refills (one charge or all), and the flash/sound.
  - Where the charge count is drawn (HUD.md: "small pink pips under the slot"; the old HUD had a circular dash gauge). Is there anything at the character's feet or under the health bar?
  - Write the findings to briefs/hero-ref/DASH_UI.md with cited frame numbers.
- **Then implement it to match:**
  - Charge pips on the Shift slot (and wherever SV shows them).
  - Recharge behaviour per the findings.
  - The reset cue matching SV.
  - Heroes with 2+ charges (Lisette, Cinder 133b, Kael's Rampage, etc.) show them clearly.
- **Owner:** S5 (UI + DashReset). Post the DASH_UI.md summary to ext before building, so ext can show the owner.

## 148. Remove the level-up weapon bonuses (Hotload, Long Reach, …) and their bottom-HUD strip (owner, 17:33 UTC Nov 5)
- The owner: "on the bottom, the hot load / long reach thing is confusing - it's blocking the ui. also i dont know why we get random bonuses like that during lvl up - did supervive do it? can probably remove".
- **SV check:** in SUPERVIVE, levelling ranks up your abilities (the rank badges on the slots). There are no random weapon stat bonuses on level-up; power comes from gear/items. So this is ours, not the source's.
- **Remove:**
  - The WeaponUps / WeaponPath grants on even levels (data.gd: hotload, deepmag, longreach and the rest of that group).
  - Their bottom-HUD display/toast.
  - Their level-up popups.
  - Level-ups keep only the ability ranks (as SV).
  - The same perks dropping as world orbs: also remove for now (they're the same confusing bonuses). Note this in DECISIONS if S5 wants a second opinion.
- **Balance:** this removes some late-game weapon damage. Check the TTK at levels 6-10 vs before; if it drops noticeably, add a small flat per-level weapon scaling to the base stats, invisible and not a popup.
- **Assert:**
  - Levelling 1→10 grants no WeaponUps.
  - Nothing new appears on the bottom HUD on level-up other than the rank prompts.
  - TTK is within ~10% of before at level 8.

## 149. Mantle/wall-bounce without the glider, repeatable, with sound, like SUPERVIVE (owner, 17:34 UTC Nov 5)
- The owner: "mantling up a wall without gliding still feels weird - i want to be able to just dance/bounce by the wall and not use glider like in supervive, making a sound when you do it but you can do it indefinitely there".
- **Goal:** next to a wall/ledge, jumping into it gives a springy upward hop (SV's mantle suction + mini-mantle). Do it again and again, "dancing" along or up the wall, no glider involved, no cooldown or limit.
- **Use SV's numbers** from briefs/supervive-data/supervive_physics.md §Mantle:
  - Suction upward force up to 1.5 m above you.
  - Z speed cap 250 uu/s.
  - The mini-mantle post-launch 0.75 s.
  - XY speed target 0.6 / min 350 uu/s.
  - Forward force multiplier 8.
  - Mantling from the abyss allowed.
- Compare the feel against the footage on `ext/hero-ref-footage` (any hero hopping on ledges).
- **Rules:**
  - Jump while touching or facing a wall within reach → a bounce/hop up (a mantle if the ledge is within reach, else a small wall-hop that keeps you near the wall).
  - The glider never auto-opens from this.
  - Repeatable indefinitely.
  - Each bounce plays a short scuff/tap sound (a footstep on stone), varied pitch, heard by others nearby.
- **Assert:**
  - 10 consecutive wall-bounces without the glider opening.
  - A ledge at ≤1.5 m above → a mantle succeeds from a standing jump.
  - The bounce sfx plays every time.

## 150. A movement physics parity pass vs SUPERVIVE: gravity, momentum, air control, landing (owner, 17:34 UTC Nov 5)
- The owner: "the gravity/momentum/physics still feels a bit weird compared to supervive in general".
- **Step 1, an audit table:**
  - Write briefs/supervive-data/PHYSICS_PARITY.md: every value in supervive_physics.md (World, Per-hunter movement, CharMoveComp, Mantle, Glide, Abyss fall, per-hunter overrides) next to OUR current value, converted to metres (100 uu = 1 m) and with the scaling we chose (our arena scale vs SV's).
  - Mark each one: match / deliberately different (why) / wrong.
  - Key suspects:
    - Gravity (SV -14.7 m/s² scaled).
    - Jump apex/time-to-apex.
    - Braking decel 2220 uu/s² and ground friction 1.0: how fast you stop.
    - Air control 1.0: full steering in the air.
    - Momentum carry from dashes/knockbacks into the air and landing (no hard stop).
    - Max walk 700 uu/s.
    - The fall speed cap.
    - The sync62 slowdown of base movement/dashes: re-check it against SV.
- **Step 2, frame-time comparison:**
  - Using the footage on `ext/hero-ref-footage`, measure 3 things (jump airtime, the stop distance after letting go of the keys, a dash's travel and decel) and compare them with ours in a headless capture.
  - Note which feel is off and by how much.
- **Step 3, fix:** align the wrong ones, keeping deliberate differences only where a game reason is written down. Re-run the dash/kit checks after (many kits hard-code speeds).
- Post the PARITY table summary to ext before Step 3, so ext can show the owner.
- Related: item 149 (mantle), item 126 (momentum play).

## 145 CORRECTION: the moths are for SABLE's Marks; Pip's Kindle needs its own indicator (owner, 17:35 UTC Nov 5)
- The owner: "the moths i was talking about are sable's stacks, not pip's - pip also gets increased dmg on each person, but no indicator for that".
- **Sable:** her Marks (thief_kit.gd ~:166, "spinning faster as they stack", currently square particles orbiting the target's head) become small dark-violet moths with a faint glow. The count = the Marks; they flutter faster as they stack and burst away when consumed. Everyone sees them, the victim included (as now).
- **Pip:** her Kindle stacks (per-foe increased damage) currently have NO indicator. Add one that's different from the moths:
  - Small lantern-flame embers floating over the target's head (a tiny warm flame pip per stack, or one flame that grows and brightens with stacks).
  - At max, a flicker + a soft chime.
  - Visible to Pip and her allies clearly, to the victim too.
- **Assert:**
  - Sable Marks render as moths, with the count = the stacks.
  - A Pip Kindle hit on a foe → the flame indicator appears and scales with the stacks.

## 151. Training area + map layout: no stray 1-high rocks you get stuck on; copy SUPERVIVE's layout rules (owner, 17:37 UTC Nov 5)
- The owner: "in the training area there are random rocks - you can get on top and then get stuck in these - supervive intentionally does not have many things where it's like 1 block up - lets try to copy their map layout / general layout so this isnt the case".
- **Immediate:**
  - In the training area, remove the scattered small rocks/props.
  - Anything left must be either flat walkable ground or a clearly climbable ledge (a full mantle height), never a 1-block step you snag on.
  - Fix the stuck case: standing on top of a small rock must never trap you (a collider/nav seam bug). Find and fix the root cause too (step height vs collider shape).
- **Layout rules** (a doc, briefs/supervive-data/LAYOUT_RULES.md, derived from the footage on `ext/hero-ref-footage` + SV knowledge):
  - Terrain comes in a few clear height tiers: ground, raised plateaus/cliffs (mantle-able, ≈1.5 m+ per SV mantle), abyss.
  - Few or no small 1-step obstacles. Cover is tall (blocks shots) or nothing.
  - Clean, readable edges with a visual lip.
  - Open lanes between POIs; chokepoints from big shapes, not clutter.
  - Small decor props are non-colliding (walk through) or tall enough to be walls.
  - Grass/brush for vision, not collision.
- **Apply:**
  - The training area first.
  - Then audit the match map generator (scatter, rocks, rubble) and remove collision from small decor, or snap its heights to the tiers.
  - Tarek's rocks/ridge are gameplay objects; keep them, but they follow the "climbable or wall" rule (item 134b).
- **Assert:**
  - A probe walking a grid over the training area never gets stuck (no position unchanged >1 s with move input).
  - A count of colliding props shorter than mantle height but taller than the step height == 0.

## 152. Prologue captions: never past the letterbox bar + a text rewrite (owner, 17:38 UTC Nov 5)
- The owner: "the beginning text/animation should never have the text go over the black line - if so, cut it. also do a review of the text cuz it's not very good right now".
- **Layout (scripts/ui/prologue.gd):**
  - The caption must sit entirely inside the bottom letterbox bar (bar_bot, 128 px).
  - Put the caption inside the bar with clip_contents on, so anything that would overflow is CUT, never drawn over the picture.
  - Hard max 2 lines; font size chosen so 2 lines fit at 720p and up.
  - The chapter label stays inside the top bar the same way.
  - Assert: at 1280×720 and 1920×1080, the caption's rect ⊆ bar_bot's rect for all 5 shots.
- **Text:** the current lines are long (3 lines), clunky and confusing ("He was the Wyrm in human shape", "skyfolk", "cursed fossils"). Ext's rewrite: the same lore beats, 2 lines max, ≤ ~52 chars per line. Use this unless the owner edits it:
  1. BEFORE THE FALL: "The Skylands bowed to one ageless Tyrant,\nenthroned on the Crown for a thousand years."
  2. THE WAKING: "But the Tyrant was a Wyrm in a man's shape.\nWhen a thief touched its heart, it woke."
  3. THE SUNDERING: "It tore the land apart and drank our essence.\nOur children were born without faces: the Empty."
  4. THE MASKS: "We had buried the old Hunters' Masks as cursed.\nNow they were the only faces left to wear."
  5. THE RACE: "Wear a Mask. Bond a Boki. Find the Wyrmheart.\nOne wish remakes the world. The Wyrm wants it back."
  - The title card stays "PROJECT BOKI" / "Every hunter's story starts with an egg."
- Keep the typewriter reveal; make sure the reveal timing still fits each shot's camera time.

## 153. The Empty creator: height + build as SLIDERS; many more, much more distinct shrouds (owner, 17:38-17:39 UTC Nov 5)
- The owner: "lets make height and build a slider" + "more shroud options too and more distinction between them so the player can have some personality".
- Today (scripts/match/unmasked.gd): HEIGHTS Short/Average/Tall (scale 0.9/1.0/1.1), BUILDS Slight/Average/Sturdy (width 0.86/1.0/1.16, bulk 0.9/1.0/1.14), SHROUDS Cloak/Wrap/Tatters (3, similar silhouettes), 12 colours.
- **Sliders:**
  - Height and Build become continuous sliders (0..1, default 0.5).
  - Height maps to scale 0.88 → 1.12; Build maps width 0.84 → 1.18 and bulk 0.88 → 1.16 (interpolated).
  - The same slider widget as the Mantle-look sliders in creator_panel.gd, with a live preview (SETTLE_S throttle).
  - Old saves map Short/Average/Tall → 0 / 0.5 / 1.
  - Hitboxes still never read it.
- **Shrouds:** ~10 styles with clearly different silhouettes, so a player reads as "theirs" at the match camera. Suggested:
  - **Hooded Cloak:** a deep hood, floor length.
  - **Wrap:** body bandage-wraps, lean.
  - **Tatters:** ragged strips.
  - **Long Coat:** a high collar, split tails.
  - **Poncho:** wide, a squared silhouette.
  - **Robe & Sash:** a monk-like belted robe, a long sash end.
  - **Mantle Cape:** a short shoulder cape over a fitted body.
  - **Shawl & Scarf:** a huge scarf trailing.
  - **Cowl & Feathers:** a feathered collar.
  - **Patchwork:** mismatched panels in 2 tones.
- **Personality layers** (separate rows): Hood up/down where it applies; a trim/pattern (plain, stitched, runes, stripes, embroidered edge); a second accent colour (trim); an accessory (none, belt pouches, satchel strap, charm necklace, lantern hook, bandolier).
- All of them animate with the cloth/drape (HeroKit.drape hems) and stay void-skinned (no skin shows).
- **Owners:** S5 the creator UI + data; S2 the new shroud meshes/drapes (procedural via HeroKit is fine).
  - Post a contact sheet of all shrouds on one body to ext for the owner.
- **Assert:**
  - Height/build sliders produce continuous scales.
  - An old save loads.
  - ≥10 shrouds selectable.
  - The unmasked_check passes.

## 153b. The Empty creator: more, more distinct Ghost features and Aura types (owner, 17:39 UTC Nov 5)
- The owner: "same with ghost - needs more options and differentiations" + "and aura too, can have different types of things, like darker aura, angelic aura, etc".
- **Ghost** (the faint ghosts of the missing features on the void face; today None / Eyes / Whole face / Stitched). Go to ~10, each clearly different at the match camera:
  - None.
  - Eyes.
  - Whole face.
  - Stitched.
  - Smile (a wide grin only).
  - Tears (glowing tear streaks).
  - Third Eye.
  - Cracked (porcelain-like crack lines).
  - Runes (glyph markings where the features would be).
  - Many Eyes (3-5 small scattered eyes).
  - Fanged (a jaw outline with teeth).
  - Hollow Stare (two deep dark sockets).
  - Plus a "ghost intensity" slider (faint ↔ vivid).
- **Aura:** split into Type + Strength (Strength = the old None/Faint/Strong, now a slider). Types with distinct shapes/motion, not just colour:
  - **Specks:** today's drifting specks.
  - **Dark:** smoky black wisps rising, a slight shadow pooling at the feet.
  - **Angelic:** soft gold-white light motes, a faint halo ring over the head, gentle upward drift.
  - **Ember:** sparks and heat shimmer.
  - **Frost:** a cold mist + tiny ice glints.
  - **Void:** small starfield fragments orbiting (matching the face).
  - **Spirit:** translucent ghostly ribbons trailing.
  - **Storm:** faint crackles.
  - **Bloom:** petals/leaves drifting.
  - **Shadow-wings:** a faint wing silhouette flickering behind you (rare and cool).
  - Aura colour follows the Glow pick by default, with an override.
- **Budget:** auras use pooled GPU particles within HeroVfx-like caps; in a match, others' auras are thinned (they're cosmetic).
- **Owners:** S5 the creator rows/data; S3 the aura VFX; S2/S5 the ghost features in the void_face shader.
  - Contact sheets of all ghosts and all auras to ext for the owner.

## 154. Starter egg pick: hover glow, then an "Are you sure?" confirm; no pop-out window (owner, 17:40 UTC Nov 5)
- The owner: "when pressing the egg, it pops out a bigger window - dont do this - just have it light up when hovered over, then 'are you sure?' text after you press".
- scripts/ui/hatch.gd, stage "pick" (3 starter eggs + Mystery).
- **Hover:** the egg lights up (a soft rim glow + a slight lift/wobble) and its name shows in a small label under it. No panel.
- **Click:** no enlarged window/detail card. A small inline confirm appears under that egg ("Choose the Venom Egg?" with Yes / Back buttons, or Enter / Esc).
  - Yes → the warm/hatching stage as now.
  - Back → returns to the pick with nothing changed.
- Remove the pop-out panel and its blurb text from this flow (the item 155 text-cut rule).
- **Assert:**
  - Clicking an egg spawns no panel bigger than the confirm.
  - Confirm → it hatches; Back → stage still "pick".

## 155. Text diet: remove unnecessary subtext everywhere (owner, 17:40 UTC Nov 5)
- The owner: "in general there's too much subtext, even like the subtext under new game or continue game - remove unnecessary text".
- **The rule:** a button or menu item is its label only. Subtext/descriptions only where a choice can't be understood without them, and then ≤1 short line or a tooltip on hover.
- **Pass** (S5 or S7), list every removal in the commit message:
  - **Main menu:** New Game / Continue / Settings / Quit with no subtext lines.
  - **Hatch flow:** cut the intro card's extra lines, the egg blurbs (→ hover tooltip at most), and the "Knock on the egg…" instruction → a single short prompt ("Click to knock").
  - **Home/hub panels, creator** (e.g. "At home you're yourself. In a Mantle…" → cut or tooltip), **tutorial cards:** trim to the essential.
  - **HUD:** no explanatory text in a match; item 119 already cut the word popups.
  - Ability cards keep their short descriptions, but check each for bloat (cut "(the owner's call…)" style asides that leaked into player text).
- **Assert:** a grep check over the UI strings: no menu button has a subtext label; flag any player-facing string >120 chars for review.

## 156. The hatch reveal: one dedicated "new Boki" screen (a Pokémon-style reveal), no double creature; cut the title subtext (owner, 17:41 UTC Nov 5)
- The owner: "when the egg hatches, you see the creature twice - do like a pokemon 'who is that pokemon' type of screen so you dont see the background when you see the 'new boki' screen". Also: "get rid of the subtext in the beginning under project boki".
- **Reveal** (scripts/ui/hatch.gd + egg_hatch.gd, stage hatching → name):
  1. After the hatch animation climbs out, cut to a full-screen reveal: the 3D scene/background is hidden (no second copy of the creature in the world behind it).
  2. Backdrop: a bold radial-burst/spotlight in the Boki's element colour over dark, Pokémon-style.
  3. Beat 1 (~0.8 s): the Boki as a solid black silhouette, centred, a little bob.
  4. Beat 2: a flash → the silhouette fills in with full colour, a small pose/hop, its first cry.
  5. Then the name entry ("Name your Boki") sits on that same screen. The species name is shown small.
  6. Exactly one creature on screen throughout.
- After naming, return to the 3D world with the Boki beside you as now (MaskMoment next).
- **Title card** (prologue.gd ~:530): remove the subtitle "Every hunter's story starts with an egg." "PROJECT BOKI" alone.
- **Assert:**
  - During the reveal, only one Boki node is visible.
  - The background/world is hidden.
  - The title card has no subtitle label.

## 157. The new-player Boki boxes: make clear that you DON'T choose a move; the UI boxes look too basic (owner, 17:41 UTC Nov 5)
- The owner: "do i choose a move for my boki? it implies that with the box - but it doesnt say. be clear here. also the ui/boxes look bad still, very basic".
- **Fact:** each species has a fixed `active` + `auto` ability (content/kin_v2/<id>.json). There is no move choice at hatch.
- **Fix:** find the box(es) in the starter flow (the egg pick info / name screen / first Boki card) that look like a selectable move slot.
  - Restyle them as a read-only info strip: "Ability: <icon> <name>, <one short line>" and "Passive: <icon> <name>".
  - No empty slot frames, hover states, or button-like borders on things you can't click.
  - If a later system lets you change moves, say so then, not here.
- **The look:** the panels/boxes across the new-player flow and home are plain rectangles and read as placeholder.
  - Do a UI skin pass with one consistent style (a UI style sheet, briefs/UI_STYLE.md):
    - Panels with a soft inner bevel and an ornamental corner/edge motif fitting the Skylands (gold-trim linework on a deep navy or parchment, matching the logo direction).
    - Rounded corners; a subtle texture/noise.
    - Clear header bars; icon tiles with frames.
    - Consistent spacing/type scale (UI.T_*).
    - Animated hover/press states only on interactive things.
  - Apply it to the hatch flow first, then the home panels.
  - Ext can produce a Nano Banana UI mockup for the owner to approve the style first; S5 uses the existing UI helpers until then.
- **Assert:** non-interactive info boxes have no hover/focus states; screenshots before/after to ext.

## 158. Putting on the Mask: a real transformation animation into the Hunter (owner, 17:42 UTC Nov 5)
- The owner: "there needs to be some animation of us transforming into the hunter after putting it on".
- Today (scripts/ui/mask_moment.gd): the Mask lifts to the hollow face, flickers, a flash, and you are swapped to mostly-Vex. A cut, not a transformation.
- **New sequence** (~2.5-3 s, skippable after the first time; reused for every first-time Mask):
  1. The Mask seals onto the void face; the void starfield on the head flares in the Mask's colour.
  2. Energy runs down from the Mask over the body: glowing seams/runes in the hero colour crawl over the shroud.
  3. The shroud unravels/burns away in strips (cloth peeling into motes) while the Hunter's outfit forms beneath, piece by piece from the head down (a dissolve shader edge in the hero colour).
  4. The body proportions morph smoothly from your Empty build to the Hunter's (a height/build blend), not a pop.
  5. Weapon/gear materialises last (Vex's arm cannon forms from light), a power pose, a shockwave ring, the Boki reacting (a hop, a cheer).
  6. A camera push-in on the reveal, then settle.
- Keep a little of you visible after (Unmasked.blend marks), as the design says.
- **Owners:** S5 the sequence/shader logic (a dissolve between the two models); S2 the pose/anim; S3 the VFX motes/seams when it's back; S4 a rising transformation sound into an impact.
- **Assert:** both models are present during the blend, with no frame where neither is visible; the total length is within 2.5-3.5 s; skippable on repeats.

## 159. Dash refresh on a knock or assist: a GLOBAL rule for every hero (owner, 17:43 UTC Nov 5)
- The owner: "I'm fairly sure ALL hunters get dash back on knock or assist from their team - this should be the case. … they changed Ghost's shift too - look into it. it should be a global thing".
- **SV research** (ext, supervive.wiki.gg):
  - Patch "Saros arrives / leveling adjustments / Hunter balance": "Hunters with multiple dashes (dash charges) only get 1 charge of their dash back on Knock" (Brall, Bishop, Crysta, Myth, Beebo, Felix) and "Joule no longer receives Dash refresh on Knock". So knock refresh is the norm across hunters, multi-charge heroes get 1 charge, and Joule is the exception.
  - Ghost's Combat Slide: "Knocks reset the cooldown"; press = a short slide, hold = further; released early on the ground → a reduced cooldown; minimum cd 3.5 s; patch 05.03.25 "can now be tapped in the air for 2/3 of the distance of the full hold".
  - Assists aren't documented on the wiki. The owner wants assists to count, so we include them.
- **Our rule** (DashReset, one place, not per kit):
  - When an enemy hunter is knocked, every hero on the knocking team who dealt damage to that hunter (or applied CC to it) in the last ~4 s refreshes their dash. The knocker always does.
  - Single-charge dashes: a full reset.
  - Multi-charge (Kael's Rampage, Cinder 133b, Lisette 146, …): +1 charge.
  - The existing reset cue (the chime + the Shift icon pop) for each recipient; an assist uses a softer version.
  - Per-hero opt-out flag in data (default ON for all 12).
    - SV removed it from Joule (= our Ryzz) because of her orb resets. Ext's call: keep Ryzz ON as well (owner said ALL), and flag it if it proves too strong with item 122's banking.
  - Remove/merge the per-kit knock resets that duplicate this (Vex's Hot Streak "knocking a hunter down gives Slipstep back", etc.) into the global one, so nothing double-fires.
- **Vex/Ghost:** our item 125 already matches SV's Combat Slide shape (tap/hold, early-release cd cut, air tap = 2/3). Add SV's "minimum cooldown 3.5 s" floor.
- **Assert:**
  - A knock with 2 assisters → 3 refreshes.
  - A multi-charge hero gets exactly +1.
  - A non-contributing teammate gets none.
  - No double reset for Vex.

## 160. Vex passive → match Ghost's current Combat Rush (ext, from the owner's question 17:45 UTC Nov 5; default = copy SV unless the owner objects)
- SV now (supervive.wiki.gg/wiki/Ghost):
  - Combat Rush: "Gain stacking 6% Omnivamp for 3.5s after landing a non-LMB ability" (8% at 05.03.25, cut to 6% at 19.03.25; all stacks expire together; Ghost's grenade attaching counted twice at intro).
  - Plus "restores 500 Health when Ghost knocks an enemy".
- Ours (Hot Streak / Fever): a knock gives Slipstep back (now global, item 159); each landing ability lights Fever, one flat 6% lifesteal for 3.5 s, not stacking.
- **Change:**
  - Fever stacks: +6% omnivamp per non-LMB ability hit (Burr Charge direct/cone, Longneedle, ult); all stacks share one 3.5 s timer refreshed on each new stack; cap ~4 stacks (tune). Grenade direct hit = 2 stacks.
  - Omnivamp heals from all her damage (rifle included, as now).
  - A knock heals her a chunk: SV's 500 on their HP scale. Map it to ours as ~the same % of max HP (S5 converts; ext's guess ≈ 20-25% of max).
  - The knock→Slipstep refresh comes from the global rule (159), not the passive.
  - The card text: "Combat Rush: abilities that land stack 6% lifesteal for 3.5s. Knocks heal you."

## 161. The tutorial intro card waits for a key: no 2 s auto-start (owner, 17:46 UTC Nov 5)
- The owner: "it says 'press any key' on the tutorial but then auto starts in a second anyways - make it pause until a key is pressed".
- Cause:
  - scripts/match/tutorial.gd `intro_wait`: `if intro_t >= INTRO_T: ack()`, with INTRO_T = 2.0.
  - tutorial_hud.gd:118 also fades the dim over intro_t 1.6 → 2.0.
- **Fix:**
  - Remove the timeout: only a key/click calls ack().
  - Keep the dim at full while the card is up; fade it out over ~0.3 s after ack (a separate timer).
  - Ignore input for the first ~0.3 s so a held key from the loading screen doesn't skip it instantly.
  - The match stays paused (the existing behaviour).
- **Assert:** with no input for 10 s, the card is still up; a key → it closes.

## 162. Restrict movement options while dropping/gliding down and falling (owner, 17:47 UTC Nov 5): tutorial AND the skyship drop
- The owner: "there's too much movement options in the air while gliding down - and falling should take away most movement options - fix this. this is for both tutorial but also skyship".
- **During the opening drop** (hunter.gd `dropping`; the skyship drop and the tutorial's drop):
  - Steering only: the glide heading + speed (SV-style dive/flare). No dash, no abilities, no jump/double-jump, no air-dash, no weapon fire, no Boki throw.
  - The HUD greys out the ability slots while dropping.
  - Landing restores everything.
- **During a free fall** (off a ledge, knocked into the air, glider closed):
  - Only limited air control (≈SV's air control, see item 150) + opening the glider. No air dash or movement abilities unless a kit explicitly has an air version (Cinder poof, Sable air dash = ground per 129, Vex air tap per 125).
  - Basic attack allowed; other abilities per kit design.
  - Review with the item 150 parity table: SV's air options.
- **Assert:** while dropping, pressing Shift/RMB/E/Space/G does nothing; while falling, there's no chained dash→dash→ability movement beyond what the kit allows.

## 163. Skyship upgrade (owner, 17:47 UTC Nov 5: "are we getting a skyship upgrade soon? i know it's in queue")
- Ext checked: there was NO skyship item in OWNER_REVIEW or any inbox. It is queued now.
- The skyship (drop_squad.gd planning phase + crossing; per-wave ships on the minimap) gets a proper art pass:
  - A hand-crafted model: a wooden sky-galleon hull with brass fittings and patched canvas balloon/sails in the Skylands style, with propellers and lanterns.
  - Animated: a gentle bob, spinning props, flags/banners in the team colour, contrails/clouds.
  - The interior/deck where players stand during planning (if they stand on it).
  - A launch moment (a horn, the hatch opening).
  - A distant-ship LOD for the other waves.
- Ext can prepare a Nano Banana concept for the owner first (on request); S2 models, S3 VFX, S4 sounds (engine hum, horn, wind).
- Priority: after the hero ART-1 merges.

## 164. Tutorial: fewer chests; a hand-held dash lesson on the ground; islands gated until done (owner, 17:48 UTC Nov 5)
- The owner: "there's too many random chests on the ground in the tutorial. also the dash shouldn't be over an island - should be on the ground (and maybe force them to not be able to get off each given island) until they do the right thing. can also auto reset cd for them with a notification - it needs to be handholding".
- **Chests:** remove the random loot chests from the tutorial. Keep only the one(s) a step actually teaches (looting), placed on purpose.
- **Dash lesson:**
  - Teach the dash on flat ground, not across a gap.
  - Prompt "Press Shift to dash", and a ghost arrow shows the direction.
  - Success = one dash. Then a second prompt for the hold/long version if the hero has one.
  - The cooldown auto-resets during the lesson, with a small notice ("Dash recharged!") so they can retry immediately.
- **Island gating:** each tutorial island is enclosed (an invisible wall/barrier with a soft shimmer at the edges) until its step is complete.
  - Then the barrier drops with a chime, and a path/bridge (or the gap-crossing step, now that dash is learned) opens.
  - No falling off mid-lesson: an edge pushes you back gently.
- **Handholding throughout:**
  - One instruction at a time.
  - Retry-friendly (cooldowns reset, no damage).
  - Success feedback per step.
  - The item 161 "press any key" fix.
- **Assert:**
  - The tutorial has ≤N intended chests.
  - You can't leave island k before step k is done.
  - The dash cd resets during the lesson.

## 163 REDEFINED: the skyship "upgrade" is the DROP itself: a squad rocket-launch, then SV-style physics gliding (owner, 17:50 UTC Nov 5)
- The owner: "the skyship upgrade is mostly for the height, and the way you drop with a squad (as a rocket together you can separate from mid air) - it should lock you into an animation for the first like 2-3s, then let you glide out your own way after - and it should be like supervive, not super fast gliding high in the air. they intentionally have a high z axis for more player control, and gliding is a physics based thing - our gliding is generally too fast and controllable relative to theirs".
- The art pass (the ship model) from the first version of 163 is secondary. This is the core:
  1. **Squad launch:**
     - When the squad jumps, all members launch together as one "rocket" (a shared streak/capsule VFX, a team-colour trail) along an arc.
     - Each player is LOCKED into the launch animation for ~2-3 s (tune 2.5): no steering, no input except an optional early "separate" press after ~1.5 s.
  2. **Separation:** after the lock, each player breaks off (a burst + their glider opens) and glides their own way.
  3. **Height:** start high (a high Z), so the descent is long and readable, with time to choose a landing and see others. The skyship altitude / launch apex raised accordingly.
  4. **SV glide physics** (briefs/supervive-data/supervive_physics.md §Glide; also applies to ALL gliding, not just the drop):
     - Glide speed ~MaxGlide 500 uu/s (5 m/s scaled to our world).
     - A force-based approach to the target speed (GlideTargetXYForce), not instant velocity.
     - A downward force toward the height target; MinZVelocity -350, exit -40.
     - **The swoop:** diving then pulling up converts fall speed into forward speed (ratio 2.5, fading over 1.5 s): the "feathering" skill.
     - The dive: Z target -3250 uu/s for a deliberate fast descent.
     - The net feel is slower, heavier, less twitchy than ours; steering has inertia.
  5. **Movement limits while dropping:** item 162.
- **Owners:** S5 (physics + drop flow), with item 150 (the parity table) covering the glide numbers; S3 the rocket/separation VFX; S4 the launch whoosh/rumble; S2 the ship art later.
- **Assert:**
  - Input is ignored for the lock window.
  - Members are co-located until separation.
  - Glide top speed ≈ SV-scaled ±10%.
  - A swoop gives forward speed.
  - Our glide accel is no longer instant.

## 165. Tutorial fight area: add walls so RMB can be used in interesting ways (owner, 17:50 UTC Nov 5)
- The owner: "maybe some walls in the fighting part of the tutorial so you can use your rmb in a more interesting way for them".
- Add 2-3 tall walls/pillars (full cover height, no 1-high steps, item 151) in the tutorial combat arena, placed for Vex's Burr Charge wall cone (item 130):
  - A prompt "Bounce your grenade off a wall to hit enemies behind it", with a dummy positioned so the cone catches it.
  - Also useful for Lisette pins etc. when the tutorial uses other heroes.

## 166. Tutorial highlighting: replace the plain blue circles with polished, diegetic markers (owner, 17:51 UTC Nov 5)
- The owner: "the blue circles in the tutorial are a bit weird to see - make the tutorial section better to look at in terms of highlighting stuff".
- **Replace** the flat blue ground circles (objective/target markers) with a consistent highlight language:
  - **Go-here spots:** a soft glowing pillar of light (a beam fading upward) + a gentle ground ring with animated dashes rotating, in a warm gold, not flat blue. It pulses subtly and fades out when reached.
  - **Interactables** (chest, Boki, egg, lever): a rim/outline glow on the object itself (a fresnel shader) + a small bobbing key prompt above it; no ground disc.
  - **Targets** (dummies): a red-orange outline + a small chevron above the head; a hit flash on success.
  - **Paths:** a short trail of floating motes/footprints leading to the next step, only when the player seems lost (idle > ~6 s).
  - **Barriers** (item 164 island gates): a shimmer wall with a soft hex/rune pattern.
- Everything fades in/out (no popping) and sits in the hero palette / gold UI accent (match item 157's UI style).
- The VFX are S3's (when it's back); S5 swaps the logic hooks now, using placeholders that already follow these shapes.
- **Assert:** no flat blue circle meshes remain in the tutorial scene; each marker type is used per the above.

## 167. Tutorial: add a creature-taming step early, and make the first island a teach-then-test hub (owner, 17:52 UTC Nov 5)
- The owner: "we should have a creature taming part of the tutorial - maybe near the beginning, where it explains they go into your inventory and come out of the expedition with you. the first island you land on (and are restricted to) should teach a lot before making the player test it".
- **First island = the teaching island** (gated, item 164):
  - Teach in small calm steps, each with a prompt + a success check + an auto-reset, BEFORE any combat test:
    1. Move/look.
    2. Jump + the wall-bounce/mantle (item 149).
    3. Dash on flat ground (164).
    4. LMB on a dummy.
    5. RMB (with the walls, item 165).
    6. E.
    7. Crouch/sneak.
    8. Glider open/close from a ledge.
    9. Your Boki: G throw / the command wheel basics (124).
    10. **Taming** (below).
    11. Pick up a chest item.
  - Only after all of them does the barrier drop to the combat/test island.
- **The taming step** (early, after movement basics):
  - A wild, weakened, friendly-looking Boki (a starter species) on the island.
  - Prompts: weaken it (a few hits) → the tame prompt (the real tame input/flow from the game) → success.
  - A clear card: "Tamed Boki go into your box (inventory). They come home with you when you extract."
  - Show the box/inventory slot it went into, with an arrow/highlight on the HUD box (ally boxes item 101) and the belt.
  - A safe retry: it can't die or flee during the tutorial; a failed tame resets it.
- Follow the handholding rules (one instruction at a time, the item 166 highlight language).
- **Assert:**
  - The tutorial order has taming within the first island.
  - Tamed → the Boki appears in the inventory/box UI.
  - The barrier stays up until every first-island step is done.

## 168. The default camera zoom is too close: start at a middle zoom everywhere (owner, 17:53 UTC Nov 5)
- The owner: "it still zooms in too much as a basic zoom for farm and elsewhere - base zoom should be more middle, not super in".
- Today:
  - home.gd HOME_ZOOM 1.2 (the wheel goes 0.8-1.6).
  - practice.gd ZOOM 0.55-1.6, user_zoom 1.0.
  - Farm, tutorial and other screens each set their own zoom_to (e.g. close-up framings).
- **Fix:**
  - One shared default "base zoom" constant (e.g. CamDefaults.BASE), noticeably wider than now (≈1.35-1.4 on the home scale, the visual middle of the wheel range), used on arrival at home/farm, the tutorial, practice and the match start.
  - Audit every `zoom_to =` / `zoom =` set on entry (home.gd, mask_offer.gd, farm screens, tutorial, practice, hatch) and route them to the base, unless it's a deliberate short cinematic close-up that returns to the base after.
  - Remember the player's own wheel zoom per area for the session.
- Post before/after screenshots at the same spot (farm + match) to ext.
- **Assert:** entering home/farm/tutorial/practice → cam.zoom_to == base; a cinematic close-up returns to the base within its beat.

## 87b. Masks still arrive too fast after the tutorial, on v0.23.0, although item 87 shipped (owner, 17:53 UTC Nov 5)
- The owner: "the masks are also coming too fast after beating the tutorial, but i think this change is logged from earlier to happen after the farm tutorial".
- Item 87 (Hob offers the 2nd Mask mid-farm-tutorial) shipped in v0.22.0 (S7 77-92), but the owner still sees Masks right after the tutorial.
- Find what still grants or offers them early. Suspects:
  - The old class_unlock / class_pick "second-Mask beat" (empty90) still firing on tutorial completion.
  - A tutorial-complete reward.
  - mask_offer.gd triggered by the first return home before Hob's flow.
- **Fix:**
  - After the tutorial, NO Mask offer or unlock.
  - The only path to the 2nd Mask is Hob's conversation, a few steps into the farm tutorial (after the house is placed).
  - Vex stays the only Mask until then.
- **Assert:** a fresh save → tutorial complete → arrive home: no mask offer/unlock UI until Hob's step N.

## 87c. The Mask pick stutters on hover: a perf fix (owner, 17:54 UTC Nov 5; reported before)
- The owner: "also is performance heavy, which i noted before too - it stutters you when you hover over them".
- Likely cause: hovering a Mask spawns its preview (HunterViewer: the hero model + ability clip + VFX) on demand, so a model build + shader/particle compiles hitch the frame.
- **Fix:**
  - Prebuild/prewarm all offered Masks' preview models and their materials/VFX while the offer screen opens (behind a short fade, or spread over frames). Hover then only shows/hides an already-built node.
  - Cache across hovers (no rebuild per hover).
  - Use the HeroVfx prewarm path (match.gd prewarm) for the preview clips' effects.
  - If a clip still hitches, show a still portrait on hover and play the clip only on select.
  - Check the same pattern in the hero/Mask select screens elsewhere (Masks screen, class pick).
- **Assert:** a frame-time probe while hovering across the 3 Masks repeatedly: no frame >25 ms after the screen's open (S1's hitch-check style).
- Owner: S5 (or S1, the perf owner, if it's free).

## 169. Hob's voice: a jolly old adventurers' helper with a crass mouth; rewrite all his lines (owner, 17:55 UTC Nov 5)
- The owner: "hob's language and character needs work - his english is bad, but let's turn it into his character - he's an old dude who helps adventurers, jolly, bit of a crass mouth".
- **The voice guide** (add to docs/wiki + LORE as Hob's character note):
  - Hob Brackenridge, old builder and retired adventurer.
  - Warm, booming laugh, calls you "kid"/"sprout".
  - Folksy, dropped g's ("buildin'"), playful exaggeration, mild crude humour, and light swearing ("bloody", "damn", "arse", "piss off" in jest). Never slurs, never mean-spirited.
  - Short lines (1-2 sentences, item 155's text diet).
  - Gives real info, wrapped in personality.
  - "Bad English" becomes deliberate dialect, not grammar errors.
- **Rewrites** (content/rules/farm_builder.json lines; use these):
  - first: "Name's Hob! I draw up the buildin's 'round here. House, patch, pot and pen to start. Grow this dump and I'll draw you fancier."
  - nothing: "Nothin' new, kid. Harvest, hatch, scan, and come back from an expedition in one piece. Then we'll talk."
  - level_2: "Ha! You've got a crew now. Let's give the little buggers somethin' to swing at."
  - level_3: "Real work needs a real bench. Can't saw planks on your knee forever."
  - level_4: "Pens, kilns, a proper hospital! Now we're bloody talkin'."
  - level_5: "Cold store. Keeps the meat fresh and my beer colder. Mind the draught."
  - level_6: "That's every blueprint I've got, sprout. Rest is up to you."
  - first_run: "First run done and you're not even dead! Here, a Challenge House. Six wood, four stone."
  - first_extract: "Came back breathin'! That's more'n most. Take this blueprint."
  - first_boss: "Bring me a trophy off somethin' big and ugly, and I'll carve the bastard in stone."
  - scan3: "Three Boki scanned? You'll be wantin' somewhere to stuff 'em."
  - toast: "New blueprints! Go bother Hob." / hint_more: "Talk to Hob for more."
- **Farm tutorial hints** (farm_tutorial.json) that Hob speaks get his voice too; keep the {keys} tokens. E.g.:
  - axe: "Here, take this axe. Trees give wood, wood builds everythin'. Don't lose a finger."
  - pickaxe: "Rocks give stone. Pickaxe, {interact}, swing. Easy."
  - house place: "Time for a roof over your head. Hit {build}, pick House, slap it on the marked spot. Costs nothin' 'til it goes up."
  - meet: "Oi! Come say hello. Press {interact} and I'll show you what you can build."
  - The Mask offer (item 87): "By the way… that's a Vex mask on your face, innit? Could I interest you in another? Pick one. Don't take all day."
- **Apply** the voice to every Hob line in the code (the farm_hob.gd conversation, item 87/92 dialogue, toasts). S5/S7: grep for every Hob string and rewrite it in this voice. Non-Hob system text stays neutral.
- Content rating: mild language only (the owner asked for "a bit crass"). Keep a settings toggle "Mild language: on/off" that swaps the swear words for gentler ones, if it's cheap.

## 170. Black Market tab "What happened" → "History"; also clarify the other tabs (owner, 17:55 UTC Nov 5)
- The owner: "'what happened' doesnt make sense as a name for the black market tab, idk what it's supposed to be".
- It's the log of past ransoms/trades/captures (home_black_market.gd TABS.log).
- Rename it to **"History"**.
- Tighten the others so a new player understands at a glance:
  - Ransom → "Lost Boki" (Boki nobody came back for: buy them back).
  - Captured → "Held by Rivals".
  - Their offers → "Rival Requests".
  - Rare stock → "Rare Goods".
- Each tab gets a one-line empty state (e.g. "No lost Boki. Good." in Old Pell's voice), no extra subtext (item 155).
- Old --open names keep working.

## 171. Arriving at the farm: the camera centres on Hob and the game requires you to talk to him first (owner, 17:55 UTC Nov 5)
- The owner: "i cant find hob - it should center on him when we land and force us to go talk to him".
- On the first arrival home (and whenever Hob has a required tutorial step):
  1. A short camera pan from the player to Hob (~1.5 s), Hob waving + "Oi! Over here!" (item 169 voice), then the camera returns to the player.
  2. A strong marker over Hob (the item 166 language: a gold light pillar + a bobbing "!" + an off-screen edge arrow pointing to him when he's not visible).
  3. **Gate:** other farm interactions/menus are locked until you've talked to him (a gentle "Hob's waiting for you" nudge on attempts).
  4. Talking to him starts the farm tutorial conversation (item 87 flow).
- He stands in a consistent, visible spot near the landing (not hidden behind the house); move his spawn if needed.
- **Assert:** a fresh save → home arrival → the cam pans to Hob; menus are blocked until talk; the edge arrow shows when he's off-screen.

## 172. Farm tutorial house step: no forced spot (and the marked spot is unbuildable, a bug) (owner, 17:56 UTC Nov 5)
- The owner: "it shouldn't tell you where to put the house - and the area it says to put it i can't put it there anyways".
- Today: farm_tutorial.json steps[3].hints.place "…then click the marked spot", with a pre-marked site that fails placement validation.
- **Fix:**
  - Remove the marked spot. The player places the house anywhere valid, with the normal build-mode ghost (green valid / red invalid) and a short tip on the ghost ("Somewhere flat and open").
  - The hint becomes: "Time for a roof over your head. Hit {build}, pick House and put it wherever you like." (in Hob's voice, item 169).
  - Root-cause why the old marked spot was invalid (a site/lot rule vs FarmSites.clean, an overlap with decor, the slope?). Make sure no other tutorial step points at an invalid spot (the crop patch "by the water" too).
  - If the first placement fails 2×, Hob suggests an open area with a soft highlight (a suggestion, not forced).
- **Assert:**
  - A fresh save → the house can be placed at ≥3 different valid spots; the step completes.
  - No tutorial marker points at a position that fails validation.

## 171b. Hob exists from the very first moment: he doesn't appear with the house (owner, 17:56 UTC Nov 5)
- The owner: "it looks like he spawns when the house spawns - he should be standing there at the beginning beforehand".
- Hob's spawn is tied to the house (farm_hob.gd stands "by the house"), so before the house he doesn't exist.
- **Fix:**
  - Hob is present from the first arrival, standing at a fixed visible spot near the landing (e.g. by a small camp: a crate, his drafting table, a lantern), where item 171's camera pan finds him.
  - Once the house is built, he can walk over to his spot by the house (a short walk, not a teleport), or keep his camp. Either way, he's never absent.
- **Assert:** a fresh save, frame 1 at home → the Hob node exists and is visible.

## 173. Build progress bar only moves forward, smoothly (owner, 17:57 UTC Nov 5)
- The owner: "i dont like how building stuff the bar goes forward then back, it should slowly go forward only".
- Likely cause: the bar shows a per-swing beat (fill on the hammer beat, then a reset/decay between swings), or it eases toward a target that's recomputed from the materials spent and overshoots.
- **Fix:**
  - The displayed progress is monotonic: displayed = max(displayed, true_progress), eased smoothly forward (lerp toward the true value, never down).
  - If there's a separate swing-timing indicator, show it as a small pulse on the hammer icon, not on the progress bar.
  - The same rule for every build/craft/chop/mine progress bar in the farm (HunterTool / farm_sites / builder).
- **Assert:** over a full build, the bar's displayed value never decreases between frames.
- 173 addendum (owner, 17:57): "or not move at all". When no work is happening (you stop hammering, the Boki idle, materials run out), the bar simply holds still: no decay, no wobble. It only ever moves forward, or stays put.

## 174. The "2" Boki list: an obvious, one-click route to each Boki's own sheet (owner, 17:58 UTC Nov 5)
- The owner: "from pressing 2 (which it offers me) you should be able to access the boki sheet / individual sheet easily (im not sure how) - so make it clear and easy to do".
- Today: the farm tutorial says "Click {boki}, or press {details} next to it, to open its page. Or press 2 for all your Boki." The list (2) doesn't make it obvious how to open one Boki's sheet.
- **Fix the list (2):**
  - A grid/row of cards (portrait, name, level, a mood icon).
  - The whole card is clickable (hover highlight + cursor) → opens that Boki's individual sheet.
  - Also a clear "View ›" button on each card, and a double-click / Enter on the selected one.
  - Arrow keys/WASD move the selection; Esc closes.
- **The individual sheet:**
  - A "‹ All Boki" back button returns to the list (with the same selection).
  - ◀ ▶ arrows (or Q/E) flip to the previous/next Boki without going back.
- **The farm tutorial step** (steps[5]): "Press 2, then click a Boki to see its sheet." Highlight the first card with the item 166 language on that step.
- Pressing 2 again or Esc closes from anywhere.
- **Assert:**
  - 2 → the list; click a card → the sheet of that Boki; back → the list; next/prev cycles.
  - The tutorial step completes on opening any sheet.

## 175. UI/text overlap: fix the "Enter / fill it up" prompt and stop overlaps everywhere (owner, 18:00 UTC Nov 5)
- The owner: "enter - fill it up - in the ui it overlaps right now (doing the tutorial). note to be careful of text/ui covering each other and fix it".
- **Immediate:** the farm tutorial's trough step ("Press {interact} at the trough to fill it…") prompt overlaps other UI (likely the world key-prompt over the trough vs the hint/goal tracker/bottom bar). Fix its placement.
- **The rule from now on (all sessions):**
  - No two UI/text elements may overlap.
  - Screen prompts/hints go in reserved layout zones (a top-centre hint lane, a bottom-centre action lane, the right goal tracker, world prompts anchored above objects and clamped away from HUD zones).
  - When two things want the same zone, they queue/stack (item 102's stacking rules) instead of drawing on top of each other.
- **Add a check:** a headless UI-overlap probe that walks the tutorial + farm steps + match HUD at 1280×720 and 1920×1080, collects the visible Control rects (and projected world prompts), and fails on intersecting text rects.
  - Run it in the suite.
  - Post a screenshot of each fixed spot to ext.

## 176. Action buttons close their menu (owner, 18:00 UTC Nov 5)
- The owner: "pressing 'fill it up' or most things should take you out of the menu, to save you having to hit escape".
- **The rule:** a button that completes the purpose of a menu (Fill it up, Plant, Place/Build, Assign job, Buy one, Confirm, Cook, Feed) performs the action AND closes the menu, returning you to the world.
  - A short toast confirms ("Trough filled").
- Menus stay open only for browsing/multi-actions: the market's repeated buying/selling (a stack-buy stays open), the Boki list/sheet navigation (174), the inventory sorting, the settings.
  - When in doubt: close.
- Audit every farm/home panel button and tag it as `closes` / `stays`.
  - Default `closes` for single-purpose interact menus (trough, patch, station, house, pot).
- The tutorial steps that wait on the menu closing must still complete.
- **Assert:**
  - Trough → Fill it up → the panel is closed, the trough filled.
  - Market buy ×3 → the panel is still open.

## 177. Name fields: placeholder hint, not pre-filled text (owner, 18:03 UTC Nov 5)
- The owner: "naming yourself or your boki should delete the placeholder text (hunter) so the player can just type in whatever".
- In the hatch flow (hatch.gd "Your name" / "Its name") and anywhere else a name is entered (the creator, renaming a Boki), the fields are pre-filled with real text ("Hunter", a default Boki name).
- **Fix:**
  - The field starts EMPTY with a greyed `placeholder_text` ("Your name" / "Name your Boki").
  - Auto-focus the field so typing works immediately.
  - If the player confirms empty, fall back to the default name ("Hunter" / the species name).
  - When renaming an existing name, select-all on focus so typing replaces it.
  - The "Ideas" chips still fill the field when clicked.
- **Assert:**
  - On the name stage, the LineEdit text == "" with a placeholder set and focus owned.
  - An empty confirm → the default name.

## 177b. The Boki naming screen asks for YOUR name again: remove it (owner, 18:04 UTC Nov 5)
- The owner: "why is there two name options after the boki name?"
- Cause: hatch.gd `_show_name` (~:708) adds a "Your name" row (ye, pre-filled from Save "name") under the Boki's name. You already named yourself in the creator (~:428).
- **Fix:**
  - Remove the "Your name" row from the Boki naming screen. _finish takes the saved player name.
  - The player name is set only in the creator (with item 177's empty-placeholder behaviour) and is editable later in settings/profile.
  - Also check "Skip the tutorial" on this screen. It's subtext-ish and risky for new players; keep it only as a small link, per the item 155 text diet.
- **Assert:** the Boki name screen has exactly one LineEdit.

## 178. New-player overload: drop the Mask ability showcase; teach controls and abilities one at a time, in use (owner playtest with his dad, 18:05 UTC Nov 5)
- The dad, on seeing the Mask UI: "so i have to learn all this stuff?" He also didn't know WASD is movement or Space is jump.
- **Principle:** never show a wall of abilities up front. Teach each thing at the moment it's used, one at a time, with the key shown big on screen.
- **Mask moment (mask_moment.gd):** remove the "short look at what Vex does" (the HunterViewer ability clips/cards) from the first-time flow.
  - After the transformation (item 158), just one line: "You're Vex now." Then straight into the tutorial.
  - The full ability page stays available later (the Masks/Hunter screen) for players who want it.
- **Controls from zero** (the first tutorial island, item 167):
  - Step 1, before anything: big animated key glyphs on screen, "W A S D to move". The step completes after moving ~3 m. Mouse-move-to-look comes in the same beat if needed.
  - Then "Space to jump" (with the glyph), then "Shift to dash", and so on. Each is shown as a large keycap graphic next to the character, not a line of text, and fades when done.
  - Abilities are introduced one per step as they unlock: LMB → RMB → E → the ult later, each with its keycap + a 1-line "what it does" + a target to try it on.
  - The ability bar only reveals each slot as it's taught (the untaught slots are hidden or dimmed with a lock), so the HUD isn't a wall of icons on frame 1.
- **Keycap glyphs:** use the bound keys from settings (rebinding-safe) and a controller variant later.
- **Assert:**
  - A fresh save's tutorial shows the WASD prompt as the first step.
  - The Mask moment has no ability showcase.
  - The ability slots unlock visually as they're taught.

## 178b. Teach the glider as "jump twice", and the dash as "Shift", clearly (owner, 18:06 UTC Nov 5)
- The owner: "we need to explain the glider with jump twice more easily too. and be clear shift is dash (say use space then shift)".
- **Glider step:**
  - At a ledge, show the keycaps "SPACE + SPACE" with a tiny animation (a jump, then a second press opens the glider). The text is just "Jump twice to glide".
  - Then "Let go to drop".
  - The step completes on opening the glider.
- **Dash steps:**
  - On flat ground: the keycap "SHIFT", text "Shift to dash" (item 164).
  - Then an air-dash step: the keycaps "SPACE → SHIFT", text "Jump, then Shift to dash in the air".
- Use the bound keys (rebinding-safe), the same keycap visuals as item 178.

## 179. Glider input: tap Space to jump, then press-and-HOLD Space to glide; release closes it. Holding the first jump never opens it (owner, 18:07 UTC Nov 5, confirmed)
- The owner: "holding space should not pull out glider - it must be a space, hold space - fix that everywhere". Confirmed choice: "Tap, then hold to glide".
- **Rules** (everywhere: matches, the tutorial, the farm, the drop exit):
  - First Space press = a jump. Holding it never opens the glider, however long.
  - A new Space press while airborne (after releasing the first) opens the glider, and it stays open only while Space is held. Releasing closes it (you fall).
  - Re-pressing while still airborne reopens it (subject to existing glider heat/limits).
  - From a ledge walk-off (no jump): a press+hold opens it (it's the "second" airborne press).
  - The drop (item 163): after the locked launch, the glider is open by default until landing, or follows the same hold rule after separation. Pick whichever matches SV, and note it.
- Update the tutorial text and keycaps (item 178b): "SPACE, then HOLD SPACE to glide. Let go to drop."
- **Remove** any auto-open on long hold or on falling.
- **Assert:**
  - Holding Space from the ground for 3 s → no glider.
  - Tap, then hold → glider open; release → closed.
  - The same in tutorial/farm/match.

## 178c. Tutorial instructions escalate when ignored (owner playtest with his dad, 18:08 UTC Nov 5)
- The owner: "my dad keeps missing the instructions - maybe make it highlight or something if they ignore it too long".
- **Placement:** the current instruction sits big and central, near the character (keycaps beside them, item 178), not in a corner.
- **Escalation** when the step isn't done:
  - After ~6 s: the prompt pulses (a scale 1.0 ↔ 1.08 + glow) and a soft chime plays.
  - After ~12 s: a gentle screen-edge dim spotlights the prompt + character; the keycap animates "pressing" itself; Hob/a voice line or a short text nudge ("Try pressing W").
  - After ~20 s: the camera eases toward the target/area (the item 166 mote trail) and the nudge repeats every ~10 s.
- Escalation resets the moment the player makes any progress on the step.
- Never block input; no harsh sounds.
- The same escalation for the farm tutorial's Hob prompts.
- **Assert:** idle 7 s → a pulse; 13 s → the spotlight; progress resets it.

## 178d. Tutorial pickup: only the one target item; no gust glove/other gear to confuse (owner playtest with his dad, 18:09 UTC Nov 5)
- The owner: "the gust glove confused him too. he's trying to pick up the wrong thing".
- The tutorial's "pickup" step spawns a vest (tutorial.gd ~:241, m.spawn_gear("vest")), but other gear (e.g. a gust glove from chests/ground loot) is lying around, and he went for that.
- **Fix:**
  - During the tutorial, no other gear or gloves on the ground: no random drops, chests or monster loot. Only the step's own item exists.
  - The target item gets the item 166 interactable highlight + a big "E to pick up" keycap when near.
  - Gloves (gust etc.) aren't introduced in the first tutorial at all. They come later, with their own short explainer the first time one is picked up in a real match ("Gloves give a special move on {key}").
  - If a non-target item somehow appears, it isn't highlighted and the prompt points at the right one.
- **Assert:** during the pickup step, the count of ground gear == 1 (the tutorial item).

## 178e. Teach "hold to fire" and "unlimited ammo"; hold-to-glide is covered by 179 (owner playtest with his dad, 18:09 UTC Nov 5)
- The owner: "he doesn't realize he can hold lmb instead of tapping (same with glider) and he didn't realize he has unlimited ammo".
- **LMB step:**
  - The keycap shows a mouse with the left button and the label "HOLD to fire", with an animated hold bar.
  - The step completes after ~1.5 s of continuous fire (not taps).
  - If he only taps, after 3 taps the nudge says "Try holding it down".
- **Ammo:**
  - The first time the drum/magazine empties, a big friendly callout: "Ammo refills by itself, just keep going".
  - Make the HUD ammo readout show a refill animation / ∞-style auto-refill icon, so it never reads as "out of ammo".
- **Glider:** the item 179 "SPACE, then HOLD SPACE" keycap with an animated hold bar (the same visual language as hold-to-fire).
- **Assert:** the LMB step requires a sustained hold; the ammo callout fires once, on the first empty.

## 178f. G command wheel: releasing to choose isn't obvious; also accept a click (owner playtest with his dad, 18:10 UTC Nov 5)
- The owner: "he also didn't realize for G hold you let go instead of pressing it".
- **Fix:**
  - Releasing G still picks the highlighted command.
  - While the wheel is open, a left-click (or pressing G again) also picks it. Both work, so nobody gets stuck.
  - The wheel shows a centre label: "Move to choose · Let go of G" with a small animated key-release glyph.
  - The highlighted segment enlarges + glows.
- **The tutorial's Boki-command step:**
  - The keycap "HOLD G", then an arrow animation of the mouse flick, then "let go".
  - It completes on any successful pick.
  - The item 178c escalation if the player is stuck holding with no pick.
- **Assert:** both the release and a click while the wheel is open select the highlighted option.

## 98b. Ability rank-up: say "Alt + key OR click the ability", and support the mouse (owner, 18:11 UTC Nov 5)
- The owner: "we should say press alt and e OR hover over the ability to level up".
- Builds on item 98 (Alt+key ranking already exists: match.gd → Hunter.level_slot; the work is discoverability).
- **When a rank point is available:**
  - Each rankable slot shows a glowing "+" badge.
  - Hovering a slot enlarges the "+" and shows a tooltip with the next rank's change (rank_next text).
  - Clicking the "+" (or the slot) ranks it up.
- **The prompt** (once per level-up, small, near the ability bar, not over other UI per item 175): "Level up! Alt + {key} or click an ability's +".
  - It uses the actual bound keys (e.g. Alt+E).
- **The tutorial:** the first level-up gets a dedicated step with the keycaps "ALT + E" and a pointer to the "+", completing on either method.
- **Assert:** with a point available, clicking a slot's + ranks it; Alt+E still works; the prompt shows both methods.

## 178g. Tutorial/prompts lead with the KEY, not the ability name; rename Vex's E "Longneedle" → "Railgun" (owner, 18:11 UTC Nov 5)
- The owner: "don't use ability names - it says use long needle, it should say use your E (longneedle). also that name should be changed to railgun".
- **Prompt format everywhere** (tutorial steps, hints, rank-up prompts, toasts): "Use your {key} ({Ability})", i.e. the key first (with the keycap glyph), the name in brackets after. E.g. "Use your E (Railgun)".
  - Applies to all heroes and slots (LMB, RMB, E, Shift, X/ult, G).
- **Rename:** Vex's E: name "Longneedle" → "Railgun", short "Needle" → "Rail".
  - Update gunslinger.json (name/short/desc/clip lines/variants/rank text, and passive text that mentions it), the wiki, docs/heroes/gunslinger.md and any code strings.
  - Keep the internal ids unchanged.
- **Assert:** no tutorial prompt string starts with an ability name; a grep for "Longneedle" in player-facing text = 0.
- 178g addendum (owner, 18:12): his dad didn't know "RMB" means the right mouse button. In ALL player-facing text, never use the abbreviations LMB/RMB/MMB.
  - Show a mouse glyph with the correct button highlighted. Where text is needed: "Left click" / "Right click" / "Middle click" (e.g. "Right click (Bola)").
  - Keyboard keys as keycap glyphs ("Shift", "Space", "E").
  - Covers ability cards, the HUD key pills, the tutorial, tooltips and settings.
  - Assert: a grep of the player-facing strings for \bLMB\b|\bRMB\b|\bMMB\b = 0.

## 178h. G tap (Sic): snap to the nearest foe near the cursor, so you don't need pixel-perfect aim (owner playtest with his dad, 18:13 UTC Nov 5)
- The owner: "he's having a hard time with the tap G to send it at monsters - make it so it's in the area rather than directly on it so it's easier".
- **Fix** (kin_command.gd Sic):
  - On a G tap, target the nearest valid foe within a generous radius of the cursor's ground point (~3 m, tune; scale with the camera zoom).
  - Prefer the foe closest to the cursor; tie-break by distance to the player.
  - If none is within the radius, it leaps to the cursor point as now.
- **Feedback:**
  - While hovering near a valid target, show a small Boki-paw reticle snapping onto the foe that would be chosen, so the player sees what G will hit before tapping.
  - On the tap, a quick line from the Boki to the target.
- **The tutorial step:** "Tap G near a monster to send your Boki at it".
- **Assert:** the cursor 2 m from a dummy → the tap targets the dummy; the cursor far from any foe → it leaps to the point.
- 175 addendum (owner, 18:14): in the tutorial, the blue guide arrow sometimes covers the instruction text.
  - The arrow is clamped out of the instruction's rect (it routes around it or sits beside it) and is drawn under the text, never over it.
  - Restyle it into the item 166 gold language.
  - Include the arrow's rect in the overlap probe.

## 178i. Key + chest step: only the right chest, and guidance that actually leads (owner playtest with his dad, 18:14 UTC Nov 5)
- The owner: "he opened the wrong chest with the key - he also isn't clear about the blue thing - it's not guiding him well enough".
- **The key step:**
  - Only ONE locked chest exists during it (with item 164's "remove random chests").
  - It's visually distinct (a big padlock icon, a gold outline, item 166), and the key icon floats over it ("Use your key here").
  - Nothing else in the area accepts the key.
- **Guidance:** replace the blue marker/arrow with a clearer, layered guide:
  1. A ground path of glowing footprints/motes from the player to the target (always on during "go to" steps, not only when idle).
  2. A light pillar on the target, visible from far away and through obstacles (a silhouette).
  3. An off-screen edge arrow that points toward the target when it's off-screen and hides when it's on-screen (so it never sits on top of things).
  4. The instruction text names the target plainly: "Walk to the glowing chest", not just an arrow.
- Every "go somewhere" step uses this same guide.
- **Assert:** in the key step, the count of chests == 1; the path renders from the player to the chest; the edge arrow is hidden while the chest is on-screen.

## 169b. Hob's farm instructions: clearer, and fix the axe confusion (owner playtest with his dad, 18:15 UTC Nov 5)
- The owner: "the hob instructions need to be more clear. he's looking for the axe but already has it".
- **Cause:**
  - The step hint says "Here, take this axe" (it's auto-given), but the toast says "Someone left a spare axe by the house", so the player goes looking for an axe on the ground.
  - The pickaxe toast is the same ("And a pickaxe for the rocks, too").
- **Fix the tools:**
  - Hob hands it over in person: a short hand-off anim + "Here, take my axe. It's in your hands now." (item 169 voice).
  - The tool appears in the player's hand and the toolbar slot flashes with a big keycap/label ("Axe equipped").
  - Remove the "spare axe by the house" / pickaxe toasts.
  - The next prompt names the action + target: "Walk to a tree and HOLD E to chop" (key-first, 178g; HOLD bar, 178e), and the nearest tree gets the item 178i guide.
- **General clarity for every Hob step:** one action per line (the verb + the key + the target), the guide on the target, the escalation if ignored (178c). Hob's flavour goes in a separate short line, so the instruction itself is never ambiguous.
  - E.g. Hob: "Need wood for a house, kid." / Instruction: "HOLD E at a tree to chop (0/6 wood)."
- **Assert:**
  - After the axe step, the player has the axe equipped with no toast mentioning a location.
  - Every farm tutorial instruction contains a key glyph + a target noun.
- 169b addendum (owner, 18:16): beginners don't read the top-of-screen hint. The action prompt must be IN THE WORLD, at the object.
  - When in range of a tree/rock/site, a big world-anchored prompt right by it: the keycap "HOLD F" (the actual bound interact key) + a hold ring that fills while held + "to chop" / "to mine" / "to build".
  - The top hint is secondary only.
  - Apply this to every interactable in the farm and the tutorial (the item 166/178d interactable highlight + keycap).
- 178c addendum (owner, 18:17): every time the instruction CHANGES (tutorial and farm), call attention to it.
  - The old one shows a quick "✓ done" tick + a chime, then the new one slides in big at the centre near the character for ~1.5 s (with its keycap) before settling into its normal spot.
  - A brief glow/pulse on arrival.
  - The goal tracker row flashes too.
  - A step change never happens silently.
- 178c addendum 2 (owner, 18:17): in menus during a tutorial step, gold-highlight the exact UI element to click.
  - E.g. after pressing B (build), the House button glows gold with a pulsing outline + a small bouncing pointer.
  - Other options are dimmed slightly.
  - The same for every menu-driven step (the trough Fill, the patch Plant, the Market Seeds tab / Buy / Sell tab, the Boki list card (174), a job assignment).
  - A generic "tutorial highlight" helper for Controls, in the item 166 gold language.
- 171b addendum (owner, 18:18): Hob spawned among trees, hard to see, and the tutorial rock spawned where it wasn't visible either.
  - Hob's camp spot and every tutorial target (the first tree, the rock, the trough site, the patch site) are placed in a clear, open, camera-visible area: no trees, rocks or props within ~3 m.
  - Each target is in view from the landing camera, or the guide (178i) points to it.
  - Enforce it in the farm generator: those spots are reserved clearings.
  - Assert: a probe raycasts from the camera to Hob and to each tutorial target with no occluder hits, and none has a tree within 3 m.

## 174b. F on a Boki opens its sheet at any range; C becomes Pet (owner, 18:19 UTC Nov 5)
- The owner: "pressing on a boki with f should pull up the menu for them and work at any range. can change c to pet".
- **On the farm/home:**
  - With the cursor over a Boki (any distance on screen, a generous pick radius), pressing F (interact) opens that Boki's individual sheet (174).
  - If no Boki is under the cursor, F keeps its normal nearest-interactable behaviour.
  - Clicking a Boki with the mouse does the same (174).
  - Pet moves to C (near the Boki, or the hovered one within a short range; it plays the pet reaction).
  - Update the keybind table/settings, world prompts ("F Details · C Pet" over a hovered Boki) and the tutorial text.
- A Boki under the cursor gets a soft outline (item 166) so it's clear which one F will open.
- In matches, nothing changes (F/C keep their match meanings) unless the bindings conflict; check the match bindings for C.
- **Assert:** hover a Boki 15 m away + F → its sheet opens; C near a Boki → the pet reaction.

## 172b. Placement spacing: a building can't sit where its interact zone overlaps another (owner, 18:20 UTC Nov 5)
- The owner: "he put the trough next to his door - make sure there has to be a distance to avoid issues where you can't interact with the obvious one".
- **Rule:**
  - When placing any interactable building/station (trough, patch, pot, pen, workbench, …), the ghost is invalid (red) if its interact zone overlaps another interactable's zone or blocks a door/entrance.
  - Doors get a keep-clear apron (~2 m in front).
  - Minimum spacing between interactables ≈ interact radius × 2 (tune).
  - The ghost shows faint interact-radius rings while placing, so the player sees why.
  - A short tip on the ghost: "Too close to the door" / "Too close to the trough".
- **Interaction priority as a safety net:** when two interactables are in range, F picks the one under the cursor first, else the one the player faces, else the nearest. The world prompt shows which one is active.
- **Assert:**
  - Placing a trough within the door apron → invalid.
  - With two in range, the prompt matches the target picked.

## 169c. The farm tutorial is a strict, logical sequence: only the needed interaction is possible (owner playtest with his dad, 18:40 UTC Nov 5)
- The owner: "make sure the tutorial forces the player to only interact with what's needed - after buying it should kick them from the window and show an arrow back to the crop after buying the seed - needs to be way more clear. also he planted all his berries before buying, so make sure it all works logically in the rework".
- **Strict mode for a new save's farm tutorial:**
  - At each step, ONLY the step's target is interactable.
  - Every other station/menu/build option is locked: dimmed, a small lock, and a gentle "Hob: one thing at a time, kid" nudge if tried.
  - The menus open only to the relevant tab with the right button gold-highlighted (178c addendum 2).
- **The logic order must hold:**
  - The starter seeds/berries can't be planted, eaten or sold out of order.
  - Either give no seeds until the buy step, or make the starter berries a separate food item (feed-only) that can't be planted.
  - The crop step uses only the seed the player just bought.
  - Audit every step's preconditions so no step can be completed or skipped early by an out-of-order action (free_order false for a new save).
- **After the purchase:**
  - The market window closes automatically (item 176).
  - A "✓ Seed bought" tick, then the guide path + edge arrow (178i) leads back to the crop patch.
  - The new instruction "HOLD F at the patch to plant" sits by the patch (169b).
- The same treatment for every transition (build → trough → patch → market → sell).
- **Assert:** a scripted run that tries every off-step action at each step → none succeeds or skips a step; the buy → the window closes → the arrow targets the patch.

## 180. Armour bar: ABOVE health, thinner, coloured by armour tier starting grey (owner, 18:43 UTC Nov 5)
- The owner: "armor should be over health in the ui (still smaller though) and start grey and go up like supervive - the current placement and blue makes it look like mana".
- **Change on every plate** (the bottom self vitals, the overhead plates, ally/rival plates):
  - The armour strip sits directly ABOVE the health bar, thinner than health (~1/3 height), the same width.
  - Its colour follows the equipped armour tier, SV-style rarity: grey (base/common) → green → blue → purple → gold/orange (legendary). Our tiers map 1:1 to the gear rarity colours.
  - Never cyan by default.
  - Keep the chip/trail behaviour and the number tag on the self plate.
  - Empty armour = a faint outline of the strip.
- Override the old HUD.md note (cyan under) as an owner decision; update briefs/hero-ref/HUD.md + docs.
- **Assert:**
  - The armour rect.y < the health rect.y on all plates.
  - The colour == the tier colour for each tier.
  - No cyan armour anywhere.
- Owner: P1 (the UI session) or S5.

## 99b. A full utility belt blocked the rift key: keys never use belt slots; swap/drop made obvious (owner playtest with his dad, 18:44 UTC Nov 5)
- The owner: "his utility belt was full and idk how to clear it - he wanted the rift key. needs to be easier to figure out".
- **Keys/quest items** (the rift key and any extraction/objective key):
  - Never go in the utility belt. They have their own key slot (shown by the belt/minimap with the key icon) and are always picked up, even with a full belt.
  - On pickup, a big callout: "Rift key! Find the rift to extract" + the guide toward the rift.
- **Full belt, normal items:**
  - Walking over/pressing F on an item with a full belt shows a world prompt: "Belt full: F to swap with [selected slot icon]", and pressing F swaps (the old item drops on the ground).
  - The belt's selected slot is highlighted.
- **Dropping:**
  - Each belt slot can be dropped: hold its number key ~0.5 s ("Hold 2 to drop"), or right-click the slot in the HUD, or drag it out.
  - Show "Hold # to drop" on the first time the belt is full.
- Builds on item 99 (full-inventory loot). Keep its rules otherwise.
- **Assert:**
  - With a full belt, the rift key is picked up into the key slot.
  - With a full belt + F on an item → a swap.
  - Holding a number key drops that slot.

## 162b. No glider during ability animations; open it only after, to carry momentum (owner, 18:45 UTC Nov 5)
- The owner: "should not be able to use glider during any animation, only after to maintain momentum (kael is using during rmb hold)".
- **Global rule:**
  - While any ability/attack animation is running (a wind-up, a charge/hold (Kael's RMB Lunge charge, Breaker's spin, Lisette's draw), a cast, a dash/blink, the release/recovery), the glider input is ignored.
  - Once the animation ends, the glider can open (item 179 tap-then-hold), and it inherits the current velocity, so momentum carries into the glide (the 126 momentum play).
  - If the player is holding Space as the animation ends, the glide opens then (a buffer), not mid-animation.
  - Applies to every hero.
  - The glider doesn't cancel abilities, and abilities don't cancel an open glider unless the kit says so.
- **Assert:**
  - Holding Kael's RMB + pressing Space in the air → no glider until release + recovery end, then it opens with the carried velocity.
  - The same for every kit's hold.

## 164b. Tutorial: no wild monsters on the first islands (owner, 21:00 UTC Nov 5)
- The owner: "get rid of the wild guys on the first few islands so it doesnt distract people learning".
- The teaching islands (item 167's first island, and every island before the combat test) have NO wild monsters/creatures, roaming or idle.
  - The only creatures are the ones a step needs (the taming step's friendly weakened Boki, 167; dummies for the attack steps).
  - Wild monsters appear only from the combat/test island on.
- **Assert:** before the combat-test step, the count of hostile/wild mobs == 0.

## 181. BUG: dashes look like an instant blink with no animation (Kael RMB Lunge, Sable dash) (owner's cousin playing, 21:09 UTC Nov 5)
- The owner: "some edit made the dashing way too fast - noticing it with rmb on kael and dash on silver thief… there's no animation, it's like a blink".
- **Ext checked v0.22.0 → v0.23.0:** no change to any dash distance/time/speed data or to thief_kit. juggernaut_kit only swapped its effects to HeroVfx (art2-kael). So the travel itself isn't faster in data.
- **Suspects** (find which):
  1. **Frame hitches during the dash:** a frame freeze (a shader/VFX first-use compile, the HeroVfx hold emitters, or perf) eats the dash's ~0.2-0.5 s, so the body appears at the end with no in-between. Check --hitch-check on Kael RMB + Sable dash.
  2. **Animation not playing:** the dash/roll pose isn't triggered (an animation LOD/throttle from perf-94, or a HeroVfx change hiding the model like Ryzz's Wirerun `model.visible = false`), so only the after-images show.
  3. **The cousin's PC frame rate:** at a low fps, a 0.2 s dash spans 2-3 frames. Ask the owner for the fps (Settings > Video > Frame rate overlay).
- **Fix:** whatever the cause, every dash/lunge must show visible travel with its animation for its full duration at any frame rate (interpolated, not teleported), and no hitch on first use.
- **Assert:** a frame capture of Sable's dash and Kael's Lunge shows ≥5 intermediate positions with the dash pose at 60 fps; no frame >33 ms during them.
- Priority: high (a feel-breaking bug in the current release).

## 182. Title screen redesign: more professional (owner, 21:10 UTC Nov 5)
- The owner: "the hero screen on project boki needs to be better - i dont like it right now… make it look more professional". The tagline and the "A short story first…" subtext are already removed (ext/brand-logo).
- **Redesign** in the Void & Masks style (UI_STYLE.md):
  - **Background:** replace the low-detail 3D lineup of Hunters on the dark island (it reads as rough and placeholder) with a polished key-art backdrop: one of the new splashes, or a composed group key-art image (ext can make one in Nano Banana), with a slow parallax drift, void specks and a soft vignette. If the 3D scene stays, frame and light it cinematically (fewer characters, posed, a depth-of-field blur).
  - **Menu:** a clean vertical stack of torn-parchment / ticket-stub items with a neon hover edge.
    - New game / Continue is the primary ticket button, with no orange flat button.
    - Consistent spacing; keycap hints only at the bottom right.
  - **News card:** restyled as a torn panel with a stamp ("PLAYTEST · 0.23"), short.
  - The version string is small in the corner (done).
- Owner: P1 (the UI session on the owner's PC) or S5. Before/after shots to ext.

## 183. Air dash rule for ALL heroes: same as the ground dash, OR a deliberately special one; never the generic default (owner, 21:13 UTC Nov 5)
- The owner: "tarek's jump dash should be the same as his regular dash - for some reason some characters have a default jump dash - it's either the same or special (like pip's)".
- **Rule:** a hero's air dash is either:
  - (a) **identical** to their ground dash (same distance, time, anim, effects; only gravity/landing differs), or
  - (b) a **designed special air version** listed in their kit data (e.g. Pip's glide hop, Cinder's poof per 133b, Vex's tap/hold per 125).
  - The shared class "default air dash" (the hunter.gd `ex` long dash / `air_dashes` path) must never be what a hero uses by accident.
- **Do:**
  - Audit all 12: list which path each hero's air dash takes today.
  - Tarek → identical to his ground dash (Rock Hop, item 111, once merged; until then his current ground dash).
  - Sable → identical (already item 129). Claire → her skate (item 62).
  - Any other hero on the generic default → identical, unless DECISIONS/OWNER_REVIEW gives them a special one.
  - Write the audit table to docs/heroes/AIR_DASH.md.
- **Assert:** for each hero, an air dash's distance/time == the ground ±5%, or the hero is in the "special" list, and no hero uses the class default path.
- 163 addendum (owner, 21:37 UTC): the skyship itself must be clearly visible while you fly. Today the camera only shows its edge.
  - Raise its flight altitude well above the players' drop camera and pull the camera back/up during the ride, so the whole ship is in frame (hull, balloon, props) with the squad aboard.
  - On launch, the camera follows the squad down and away, so the ship recedes overhead.
  - This goes with the 163 "high start" work.

## 184. Lunowl "teleports me randomly" (owner, 03:18 UTC Nov 6)
- The owner: "does lunowl teleport me randomly?" Yes, two ways:
  1. **Dash rider "Moon Blink"** (content/kin_v2/wisplet.json dodge_rider as "blink"): with Lunowl bonded, every dash becomes a blink/teleport. This is one of the Boki dash riders the owner already ordered REMOVED (item 129 decision, DECISIONS.md). It's still live in v0.24.0, so the 129 removal hasn't shipped yet; do it next.
  2. **Moon Swap** (its active, moon_swap.json): the Boki throws a moon mark on its own when a foe is within 8 m (cue foe_in_range), and the first foe hit SWAPS PLACES with the owner. Cast by the Boki's AI without the player asking, it reads as a random teleport.
- **Fix:**
  - Ship the 129 rider removal (so Moon Blink is gone).
  - Moon Swap never fires on its own. Abilities that move the PLAYER (swaps, pulls of the owner, blinks) are command-only: the player's G tap / cast key.
  - Audit every kin active for owner-moving effects and make the same rule for all of them (log it in docs).
  - Moonlift (the auto lift when falling into the abyss) can stay automatic. It's a save, and it reads clearly.
- **Assert:** Lunowl bonded and a foe at 5 m for 10 s with no input → the owner's position is never swapped; a dash with Lunowl → a normal dash, no blink.

## 184b. Boki design rule: nothing that takes agency away from the player (owner, 03:20 UTC Nov 6)
- The owner: "anything that takes away agency from the player or affects things in a weird way like that should be removed from boki abilities and changed with something else".
- **The rule** (DECISIONS.md): Boki abilities never move, steer, stop, swap, teleport, launch, root or otherwise act ON the player's own character or controls, auto or commanded.
  - Exception: Moonlift-style rescues that only help in an obvious emergency (falling into the abyss) and read clearly.
  - Boki act on enemies, the world, and the player's stats (heal, shield, buff), never on the player's position or input.
- **Do (S6, owner of the Boki):**
  - Audit every kin ability (actives, autos, merges, evolutions; all kin_v2 + abilities_v2 owned by kin) for effects whose target is the owner and that move or disable: swap places, pull/push the owner, blink/teleport the owner, launch, root/slow the owner, take camera control, force-glide, and so on.
  - Write the list to docs/BOKI_AGENCY_AUDIT.md: ability → the offending effect → its replacement.
  - **Replace each with an ability of the same theme and strength that acts on foes or the world instead.** Examples:
    - Moon Swap → "Moon Mark": the first foe hit is marked and revealed for 4 s and takes +15% damage from you, or is pulled 3 m toward the Boki, not you.
    - Anything that "pulls you to safety" → a shield bubble on you instead.
  - Keep each Boki's identity (lunar stays lunar, etc.). Keep balance roughly level.
  - Dash riders are already removed (129); verify none remain.
- **Assert:** a scripted test where every kin casts its kit 20× near an idle owner → the owner's position and velocity are never changed by kin effects (except the abyss-rescue whitelist).

## 131b. Kael's sword: scale 0.60 (owner, 07:30 UTC Nov 6)
- The owner finds the sword "way too big". Set Kael's sword to **0.60** of its current scale (all poses, RMB hold included), then run the FIDELITY_CHECKLIST weapon scale-and-fit check and post before/after shots.
- **Lane:** heroes (S2, corybogdan). Folds into item 131.

## 185. Bug 181 REOPENED: the "blink" dashes were caused by a BOKI interaction, not frame rate (owner, 07:30 UTC Nov 6)
- The owner says the cause of 181 (dashes look like an instant blink: Kael RMB Lunge, Sable dash) was a **Boki interaction changing the dash**, not frame rate. Reopen 181 with that root cause.
- Verify against the dash-rider removal (item 129 DECISION, DECISIONS 2026-11-05): confirm on current main that no Boki rider, passive, aura, stat buff or command alters dash distance, speed, duration, animation or i-frames. List every code path where a Boki touches the hero's dash or movement (grep the Boki kits, kin.gd, buffs) and remove or fence what remains.
- Asserts: with every Boki species equipped in turn, Kael's Lunge and Sable's dash keep identical duration/distance/animation frames to the no-Boki baseline (a check that fails if a Boki changes them).
- **Lane:** physics/perf (S1, orri-projectboki) with the Boki audit (186) as input.

## 186. AUDIT: every Boki interaction that affects the player character (owner direction A, 07:30 UTC Nov 6)
- The owner: Boki interactions that change the player's gameplay (movement, dash, abilities, stats, control) "have tended to hurt". Review **every** one. Anything that changes gameplay must be strongly justified; **default to removing or restricting**.
- Deliverable first (no code): briefs/BOKI_PLAYER_AUDIT.md, one row per interaction: Boki species, what it does to the player (movement / dash / abilities / stats / control), trigger, code path, and a **keep / cut / limit** recommendation with a one-line reason. Includes 184 (Lunowl Moon Swap) and the 184b agency rule. The owner reviews the list before anything is cut.
- **Lane:** Boki (S6 lane; scout/build-spec role). Supersedes the narrower 184b audit.

## 187. DESIGN PASS: make Boki feel central, not add-ons (owner direction B, 07:30 UTC Nov 6)
- Per PRIORITIES (Boki are the star). **Proposals first**: briefs/BOKI_CENTRAL_PROPOSALS.md with 3-5 concrete directions (how Boki drive the loop: fights, exploration, progression, identity), each with what changes, what it costs, and how it respects 184b (no agency taken) and 186 (fewer stat/move riders). The owner reviews before any build.
- **Lane:** Boki; **role: feel (Fable)**.

## 188. Rival dash bars: don't show them; our OWN dash charge UI is unclear (owner, 07:30 UTC Nov 6)
- **Rivals:** follow SUPERVIVE. briefs/hero-ref/HUD.md section 1 (overhead plate stack: name, segmented health, armour strip, shield strip, level chip, status icons) shows **no dash charges** on other hunters. So by default we **do not show enemies' dash charges**; remove them if our plates draw them.
- **Own dash UI:** the owner finds our own dash charge display unclear. Fix it as part of **item 147** (dash charges, resets and the dash UI: copy SUPERVIVE): write briefs/hero-ref/DASH_UI.md from the footage first, then make the self charge pips/gauge clear.
- **Lane:** UI (orribogdan lane), with 147.

## 189. In-game "Rate this build" card + feedback endpoint (owner, 07:35 UTC Nov 6)
- **Behaviour:** on the first return-to-title or quit on a **new game version**, after **>= 10 min** of play on that version, show a small **skippable** card in the Void & Masks style (briefs/UI_STYLE.md): four 1-10 ratings (combat feel, Boki, onboarding, look) and an optional one-line note. **Once per player per version.**
- **Submit:** JSON {version, player name/id, scores, note, minutes_played} by HTTP POST to a new **POST /feedback** on the existing matchmaker service (boki-us-1:8080; code on ext/matchmaker). Store JSONL. Keep the matchmaker's existing behaviour untouched; reject payloads over 2 KB and malformed JSON. If offline: queue locally and send on the next launch.
- **Coordinator side:** a cron pulls the JSONL into briefs/FUN_SCORES.md (per player, per version; owner vs testers) and the dashboard fun-score chart.
- Asserts: card shows only once per version after 10 min; skip works; offline queue flushes next launch; endpoint rejects oversize payloads; existing matchmaker endpoints unchanged.
- **Lane:** UI (orribogdan lane), **role: build-spec**.

## 131c. Kael's sword: match the final splash; try 0.70 (owner, 16:00 UTC Nov 6; revises 131b)
- The owner: try **0.70** instead of 0.60, and in general choose **whatever is most accurate to his final splash** (briefs/art-refs/kael_splash.png; the 12 final splashes are the reference; FIDELITY_CHECKLIST weapon scale-and-fit row).
- Method: render Kael in-game at 0.60, 0.70 and any value in between that the splash suggests (jobq submit --needs gpu, same camera/pose as the splash: blade length vs his height and hand), compare against the splash, pick the best match. Report the chosen value with before/after shots next to the splash.
- **Mind S2's warning:** art1-kael-2's sword is 1.26 m and conflicts in warden_look.json; resolve it in the same branch so the chosen length holds on both main's model and art1-kael-2.
- Supersedes the fixed 0.60 in 131b (ext/fix-kael-sword-131b 77368bca is the starting point, not the answer).
- **Lane:** heroes (S2, corybogdan).
