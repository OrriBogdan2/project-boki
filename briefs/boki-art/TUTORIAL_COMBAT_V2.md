# Combat tutorial v2: First Flight, rebuilt around your Boki

Owner: "the combat tutorial gets rebuilt around the Boki ... a rework, not an add-on" (DECISIONS.md 2026-11-09)
and "Match tutorial: 22 steps -> about 8" (2026-11-08). Rules it teaches come from WISP_DESIGN_OPEN.md (the
recommended answers). Written 2026-11-09 by a worker session (synth) from game main d255acbee.

## What's wrong with the current tutorial

Files: content/rules/tutorial.json (steps and words), content/maps/tutorial.json (the course "First Flight"),
scripts/match/tutorial.gd (step logic, 667 lines), scripts/match/tutorial_drive.gd (headless driver),
scripts/match/tutorial_text.gd (token fill), scripts/ui/tutorial_hud.gd (banner, pill, lane).

1. **22 steps** (tutorial.json `steps` 0 to 21) against the owner's target of about 8. Eight of them are the
   one-line hints the owner moved out of the tutorial: `exdash`, `crouch`, `pickup`, `rank`, `utility`, `orders`,
   `key`, `uplink`, `defend`, `goexit`.
2. **Four Boki steps teach the pet model the wisp design removes.** `gkey` ("Send %s out"), `throw` ("Tap to send
   %s at the monster"), `orders` ("Hold to give %s an order") and `kin1` ("Watch %s use %A") all assume a walking
   Boki you send, recall and throw. None of them exist once the Boki rides as a wisp. There is no summon, no
   timer, no cooldown, no passive and no wisp in the tutorial at all.
3. **Boki beats pass silently when the Boki is down.** tutorial.gd `done()` returns true for `gkey`, `throw`,
   `orders` and `kin1` when `p.kin.state == "downed"` (lines 371, 391 to 395), so a player whose Boki got knocked
   is told the step is done without having learned it. `kin1` also passes after a 12 s wait (`KIN_WATCH_T`) whether
   or not the Boki ever used its ability.
4. **Nothing about going down, revives or Hunter Wisps.** The one-life rule, the round Hunter Wisp (decision
   0019) and "round = Hunter, critter = Boki" are the match's most important readability rule and are never shown.
   No rival Hunter appears in the whole course (only `skitter` and `spitter` monsters, `_foes()` line 246 on).
5. **Monsters are 5x health sponges** (tutorial.json `mob.hp` 5.0, `scale` 1.4, `dmg` 0.1). The `shoot` step
   ends after 3 hits (`need.shoot`), so the player never sees a monster die from their gun, and the `fight` step
   (3 monsters, `fight_n`) is a slog with no danger. A kill should be the payoff of the first shooting beat.
6. **No visible Skip.** The owner asked for one on both tutorials; tutorial.gd has only the `--tut-from=` test
   flag (line 210). The only exit is to play all 22 steps.
7. **Long silent waits.** `RANK_WAIT_T` and `KEY_WAIT_T` are 60 s, `NAG_T` 15 s: a stuck player can sit a minute
   on a step the owner wants as a hint.
8. **Docs disagree with the data.** docs/wiki/Getting-Started.md says "three small islands"; the map has eight
   (`islands` in content/maps/tutorial.json). tutorial.gd's header also says "every ability open" while the
   `rank` step hands out a level for real. Both get rewritten with this rework.
9. **The voice drifts.** Lines mix "%W the monster", "Capture the uplink mast" and "Defend the outpost": shooter
   jargon next to kid-plain lines. The Boki never speaks in its own voice (BOKI_TALK) during the course.

What's worth keeping: the banner-to-pill HUD (tutorial_hud.gd, one lane, nothing in the middle of the screen),
the "a fall puts you back at the stop" rule (`STOP_AFTER`), the Boki running ahead to pads (`leads()`), the token
system in tutorial_text.gd, the headless driver, and the fixed, no-random course map.

## The rebuilt course: 9 beats

Rules for every beat (same as the owner's tutorial decision):
- One banner line (<= 8 words, a key cap beside it), one plain detail line under it, kid-readable, the game's own
  words (Boki, Hunter, wisp, Relic, Field Book, lift). No jargon before it's shown.
- A **Skip** button is on screen the whole time (bottom-right, small). Skipping gives everything the course would
  have given (nothing to give here: the course has no rewards) and marks `tutorial.done`.
- Nothing blocks more than a few seconds. Waits auto-advance at 20 s with the Boki saying the line once more.
- Failure never ends the course. A fall returns you to the beat's stop; a monster that kills you (it can't: tutorial
  monsters do 10 % damage) would restart the beat.
- Tokens: %s your Boki's name, %T the Boki key, %E your Hunter's E key, %F interact, %G glide, %P your Boki's carry
  passive name (`carry.name`, e.g. "Toxin"), %D its summon seconds, %C its cooldown seconds.
- The Boki talks in its own voice between beats through BOKI_TALK bubbles (2 s, <= 6 words), never in the banner.
- Tutorial tuning in content/rules/tutorial.json: `summon_cd_mult` 0.33 (a 60 s cooldown is 20 s here, the number
  on the ring says 20 so nothing lies), monsters `hp` 1.6 (not 5.0), `dmg` 0.1, the rival bot at 40 % health.

### Beat 1: Drop in
- **Goal:** steer the landing, walk to the beam. (Was `land` + `move`.)
- **Banner:** "Steer down to the meadow" then "Walk to the glowing beam"
- **Detail:** "Your Boki %s rides with you as a little light. Watch it bob."
- **Bubble (%s):** "Here we go!"
- **Success:** on the meadow, then within 2 m of the beam.
- **Retry:** missing the meadow drops you at the land stop (as now).

### Beat 2: Cross the gap
- **Goal:** dash and glide in one beat. (Was `dash`, `exdash`, `glide`.)
- **Banner:** "Dash, then hold %G to glide across"
- **Detail:** "Jump off the glowing edge. Dash in the air, then hold %G."
- **Success:** land on the range island.
- **Retry:** a fall puts you back on the pad; after two falls the detail line changes to "Just jump and hold %G.
  The wind carries you." Air dash becomes a first-time hint later, not a requirement.

### Beat 3: Your first monster (and your passive)
- **Goal:** shoot a monster dead; see that the wisp is already helping. The passive is shown, not explained.
- **Banner:** "Shoot the monster"
- **Detail:** "%s gives you %P just by riding with you. See the glow on your shots."
- **Success:** one `skitter` killed (not 3 hits). Monster health 1.6x so it takes about a magazine.
- **Retry:** if 20 s pass with no kill the monster stands still and the Boki says "Aim at the critter!".
- **Shows:** the ability bar appears here for the first time with only the weapon and the Boki slot (bright, ready,
  no numbers yet).

### Beat 4: Your Hunter's ability
- **Goal:** use E once on a group. (Was `sig`, needed 2.)
- **Banner:** "Press %E on the group"
- **Detail:** the hunter's own card line (tutorial_text.gd `ability_tip`), unchanged.
- **Success:** E cast once and it touched a monster.
- **Retry:** a miss keeps the monsters standing; the banner stays; auto-advance at 20 s after one cast.

### Beat 5: Summon! (and the timer)
- **Goal:** the first summon, and watching it end. Two lines, one beat.
- **Banner:** "Press %T to summon %s"
- **Detail:** "%s bursts out and fights for %D seconds. Watch the ring."
- **On summon**, the banner swaps to: "%s is out! %D seconds" with the ring draining on the Boki slot and on the
  ground under the Boki. A `spitter` arrives for it to fight (the Boki's auto skill fires on its cue).
- **At 3 s left:** warning tick; detail: "Almost time. %s is getting tired."
- **On shrink:** detail: "Back to a light. %s rests now."
- **Bubble (%s):** "I'm here!" on bloom, "Phew!" on shrink.
- **Success:** the summon window ran to its end (timer) or ended by the Boki killing everything.
- **Retry:** if the player recalls early (tap again) the banner says "That calls it back early. Try letting it
  stay." and the cooldown is set to 0 so they can summon again at once. If the Boki is killed by the monster
  (unlikely at 10 % damage) the detail says "%s got beaten and flew back to you. It needs a longer rest." and the
  beat still passes (that is the rule, shown honestly, not skipped silently).

### Beat 6: Dim means resting
- **Goal:** the cooldown, fighting without the Boki, and the second summon when it brightens. (Was `fight`.)
- **Banner:** "Beat the pack. Summon again when the ring is bright"
- **Detail:** "Dim light means %s is resting (%C seconds). Bright means ready."
- **Monsters:** 3 (`skitter`, `spitter`, `skitter`), arriving in two waves so the second wave lands as the ring
  nears ready.
- **Bubble (%s)** on ready: "Ready again!"
- **Success:** all three dead and the player summoned a second time at any point after the ring went bright.
- **Retry:** if the pack is dead before the ring is ready, the banner says "Wait for the bright ring, then press
  %T" and one more `skitter` arrives when it is. If the player goes down here, the **guardian summon** fires if
  ready, and a one-time hint shows: "Your Boki came out on its own to guard you!" (the Boki revives you in 8 s;
  tutorial monsters don't stomp). This is a hint, not a beat, so nobody has to go down to finish the course.

### Beat 7: A rival falls
- **Goal:** knock down a rival Hunter and see wisps for the first time: one round, some critters.
- **Setup:** a rival bot Hunter (the match bots, scripts/match/bot.gd) glides onto the range island at 40 % health with its
  own Boki wisp, enemy colour. It fights back at tutorial damage.
- **Banner:** "Knock down the rival Hunter"
- **Detail:** "Other Hunters carry Boki lights too. Beat them and watch what happens."
- **On knock:** the rival pops into a round Hunter Wisp (decision 0019); its Boki wisp breaks loose and bounces
  beside it. Slow-motion 0.5 s, camera nudge, so the moment is seen.
- **Success:** the rival is downed.
- **Retry:** the rival never kills you (10 % damage). If 30 s pass it drops to 10 % health and stops dodging.

### Beat 8: Round or critter?
- **Goal:** the readability rule, then the grab. The two things that look alike are taught side by side.
- **Banner:** "Round glow is a Hunter. Critter glow is a Boki"
- **Detail:** "You can't take a Hunter. You can take a Boki. Hold %F on the critter light."
- **Markers:** a label over each: "Hunter: can't be taken" over the round wisp, "Boki: hold %F" over the critter
  wisp. Walking to the round wisp first shows the toast "That's the Hunter. Try the little critter."
- **On grab (0.6 s hold):** the stolen wisp joins your orbit with your team-colour ring and a tether. Toast:
  "You carry a stolen Boki. It goes home when the match ends, and you keep its echo." Bubble (%s): "A new friend?"
- **Success:** the stolen wisp is on you.
- **Retry:** the loose wisp does not time out in the tutorial (its 10 s float is paused). If the player stands
  still 20 s the Boki says "Hold %F on it!" and the tether marker pulses.
- **Shows:** the stolen slot appears beside the Boki slot. The downed rival bleeds out and vanishes 5 s after the
  grab (no body to loot, nothing else to learn here).

### Beat 9: Chest, then the lift
- **Goal:** open a chest with a key, then extract with the stolen wisp. (Was `key` + `chest` + `goexit` + `uplink`
  + `defend` + `extract`.) The uplink and defend become the first-time outpost hint in real matches.
- **Setup:** the rival dropped a key where it fell; a chest sits on the path to the lift.
- **Banner:** "Grab the key and open the chest" then "Step into the light"
- **Detail:** "Hold %F by the chest. Then get to the lift to take your Boki home." then "You leave with %s and the
  stolen light. Stolen Boki fly home to their Hunter when the match ends. You keep its echo."
- **Success:** chest open, then standing in the lift until it closes.
- **Retry:** skipping the chest is allowed: standing in the lift ends the course regardless (the chest hint repeats
  in the first real match).
- **Results screen (tutorial-only lines):** "%s came home." and "Soul echo: <stolen species> (Field Book)". The
  Field Book opens its card once to show the echo entry and the summon line ("Burst: out 8 s, rests 60 s").

## What the course no longer teaches (moved to one-line first-time hints in real matches)

Air dash, crouch/scout, item pickup, rank-up, the RMB utility, the order wheel, the key as a separate step,
uplink and defend, base-to-teammate, the merge (R). Each hint is one banner line the first time it matters
(tutorial_hud.gd banner lane), per the 2026-11-08 decision. The order wheel hint fires the first time the Boki is
summoned in a real match: "Hold %T to give %s an order."

## Map changes (content/maps/tutorial.json)

Keep the landing meadow, one gap island (the dash and glide gap is the same hop), the range island and the lift.
Cut the dash isle / ledge / lookout split (3 islands) and the walled outpost isle. The rival lands on the range
island. The course table drops the stops for the cut beats. Rough size: 5 islands, about 60 m.

## Code shape (for the worker who builds it; no code here)

- tutorial.json `steps` becomes the 9 ids above; `detail`, `labels`, `need`, `mob` rewritten; new `summon_cd_mult`
  and `rival` block. Tokens %P %D %C added to tutorial_text.gd `fill()` from the player's KinSpec.
- tutorial.gd: `KEYS` maps summon beats to `throw`; the downed-Boki pass-throughs (lines 371, 391 to 395) go; a
  `rival` spawn in `_start()`; `done()` cases for the beats above; a Skip button in tutorial_hud.gd.
- Checks: `--tutorial-drive` runs the 9 beats headless (tutorial_drive.gd), `--tutorial-hud-check` gets the Skip
  button and the three banner swaps of beat 5; a new check asserts the beats pass in order and never pass on a
  downed Boki.
- Docs: docs/wiki/Getting-Started.md step 3 and Arena-and-Training.md "The tutorial" rewritten to this list.

## Why this order

Shoot before summon so the first summon is a relief, not a crutch. Timer and cooldown in two beats so each has
one idea. The rival after the second summon, because the player must have a Boki they understand before they
see one taken. Round-versus-critter taught at the exact moment both glows are on screen. The lift last, because
"it goes home, you keep the echo" is the sentence that makes stealing feel fair, and it lands best when you
leave with one.
