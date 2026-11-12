# Owner picks for 0.24.6

Seven held calls. Each is two options, what you'd notice in play, my pick and why, and an A/B to look at.
"0245" means the current 0.24.5 line (ext/release-integ-0245 and the ext/w0246-* waves built on it).
Clips are in `docs/shots/owner-picks-0246/`. The movement clips were rendered on the GPU through jobq
from throwaway trees: the wave tree, and the same tree with only the picked number or branch changed.
The two clip rigs (`--face-ab`, `--glide-ab`) were temporary and are not in the game.
GPU jobs (jobq, 11-12): face A 20261112-044900-19226, face B 20261112-044916-26739, glide A 20261112-045043-29521,
glide B 20261112-044930-07514, camera A 20261112-045209-31301, camera B 20261112-045222-18631.
To answer, reply with one letter per pick, e.g. `1A 2B 3B 4A 5B 6B 7A`.

## 1. Facing turn: ext/feel-facing-turn-rebased d5333f969
- **A:** `Hunter.FACE_TURN` 5400 deg/s, read off footage (a 180 takes 2 sim steps).
- **B:** keep 0245's `HunterMove.turn_rate` 1280 deg/s from the game data (move-parity-1, 11-10).
- **In play:** after a 180 flick the body faces the cursor in 33 ms with A and about 150 ms with B. With B
  you can see the turn: for about 9 frames the shot lines up before the body does.
- **Pick: B.** 1280 is the source's own RotationRate. The footage reading is a 60 fps estimate of a turn
  that is already that fast. If you want A anyway, it is one number in `content/rules/hunter_move.json`,
  not the branch (the branch predates turn_rate and would add a second constant).
- **Clip:** `face_A5400.jpg` vs `face_B1280.jpg` (cursor flips 180 at 0 ms, 12 frames at 60 fps, degrees
  turned under each frame). Headless numbers: A 90/180/180 deg after steps 1-3, B 21/43/64.

## 2. Dash camera: ext/feel-cam-dash-rebased c48367ea6 vs ext/feel-camera-fast (in ext/w0246-feel)
- **A:** the camera trails a dash and catches up (min(15 x gap, sqrt(2 x 28 x gap)) m/s, at most 3.5 m behind).
- **B:** keep feel-camera-fast's locked follow: the Hunter stays at screen centre through every dash.
- **In play:** A pans at about 700 px/s, so a dash reads as moving away from the camera, and the camera
  settles about 0.45 s after the dash ends. B never lets the Hunter leave centre, so aim stays steady
  but the dash reads mostly through the ground moving.
- **Pick: B.** It is already merged and checked in the feel wave (`--camera-fast-check`, and
  ext/feel-w0246-camera builds on it). A matches one footage read (dredge.md), but with A the reticle drifts while you aim out of a dash.
- **Clip:** `cam_A_trail.jpg` (`--camera-follow-shots` on the cam-dash branch: Grimble's barge) vs `cam_B_locked.jpg`
  (`--camera-fast-shots` on ext/w0246-feel: the Wirerun, the worst case). White line = screen centre.

## 3. Glider heat and swoop: ext/glider-heat-parity e8de9552e
- **A:** data heat: 14 s of level glide (`glide_heat_s`), and the 2.5x swoop above 8.5 m.
- **B:** keep 0245: `GLIDE_TIME` 9 s, and owner item 8 (11-08), where height never turns into speed.
- **In play (same glide, 30 m up):** A holds 10.2 m/s for the first 6 s and overheats at about 17 s.
  B flies at 5.0 m/s all the way and overheats at about 11 s. A crosses gaps that B can't.
- **Pick: B.** Both of B's rules are your later calls ("lasts too long, not punishing enough", item 8).
  The branch is also built on an older base and would bring the swoop back. Worth keeping from it:
  moving the heat numbers into `hunter_move.json` with source tags (a port, not this merge).
- **Clip:** `glide_A_data.jpg` vs `glide_B_0245.jpg` (one whole view every 1.5 s, gliding out over the abyss from 30 m; time, heat left, speed and height above
  the start for each frame are in `captions.txt`).

## 4. Cooldown scale: ext/cooldown-parity-verify 2be9877c2
- **A:** every kit at 1.0x of the source's level-1 cooldowns (Knife 28 s, rank texts recomputed).
- **B:** keep the line's 0.8x of the data, which the rank parity (combat-ranks-a/b/c) is built on (Knife 10.7 s, Meteor 7.2 s, Warchain 12.8 s).
- **In play:** A means about 25% longer waits on every E/RMB/ult, so fights have more basic-attack time
  between casts. B keeps the faster casting you have played since 11-08.
- **Pick: B.** The 0.8x pace is what the ranks, rank texts and checks on the line assume. Taking A means
  rebasing three rank branches plus ext/grimble-parity-verify and ext/kit-parity-rows-a, and the gain is
  a number match the player can't see. ext/parity-stranded-0246 already has A merged as one commit:
  revert it to keep B.
- **Clip:** not a movement call. Numbers: `godot --headless --path . -- --cooldown-parity-check` on each branch.

## 5. Short tutorial + first-time hints (12 branches)
The branches: tutorial-beats-7-8-rebased, tutorial-beats-5-6-rebased-rebased, first-hints-check-rebased,
hunter-first-hints, tut-first-fuse, tut-dive-hint, tut-wall-kick-hint, tut-first-heartspark-rebased,
tut-first-proc, tut-ways-out, tut-belt-hint, tut-hints-blight-camp-box.
- **A:** take the line: a 10-beat match tutorial (decision 0023, 11-08); the cut steps become one-time hints in real matches.
- **B:** keep 0245's 23-step run-levels tutorial (11-10, one ability per level). Port only the hint system
  (FirstTimeHint, MatchHints, hints.json) as one change, then cherry-pick the nine hint children.
- **In play:** A gets a new player into a real match in about half the time, but abilities are explained
  as they come up, not up front. B keeps the long guided start (you rated it 4/10) and still adds the
  in-match hints.
- **Pick: B, with the hint port.** The 11-10 tutorial is your later direction, and the hints are the part
  of the line that works on either tutorial. Taking A replaces a tutorial three days newer than it.
- **Clip:** `godot --headless --path . -- --tutorial-hud-shots --shots-dir=<dir>` on ext/w0246-tutorial (B)
  vs ext/tutorial-beats-5-6-rebased-rebased (A); hints: `--first-hints-check` on ext/first-hints-check-rebased.

## 6. Tutorial text budget: ext/tut-text-budget 326714a75
- **A:** take the budget: `--tutorial-text-check` (one short sentence per step, key tokens, no early
  jargon), and rewrite 0245's tutorial lines to pass it.
- **B:** keep 0245's lines; drop the branch (the wave merged and then reverted it).
- **In play:** A gives shorter banners (19 run-levels lines fail it today). Its farm rewrites also drop
  facts that `--farm-tutorial-check` asserts, so those rewrites would have to go.
- **Pick: A, as a port:** keep the check and rewrite the 19 lines, and leave the farm text alone. Short
  banners help any tutorial. Only if you pick 5A does this turn back into "take the branch".
- **Clip:** `--tutorial-text-check` on ext/tut-text-budget lists every line over budget; `--tutorial-hud-shots` shows the banners.

## 7. Kael's Haul Slam stun (ours-only): in ext/parity-kael-cc-riders 75e706c4a
- **A:** remove it (`rmb.haul.stun` 0.25 to 0.6 s), with the fireblast slow and the Chain Lunge stun,
  as DECISIONS 2026-11-07 says (keep no ours-only riders).
- **B:** keep the Haul Slam stun as a documented Kael move; remove only the other two riders.
- **In play:** with A, a Haul Slam knocks foes down and pushes them but doesn't hold them, so Kael's
  E-into-RMB stops being a sure follow-up. With B, Kael keeps one lockdown the source doesn't have.
- **Pick: A.** It follows your 11-07 rule, and Meteor Drop's sourced core stun stays as Kael's lockdown.
  KIT_PARITY flagged only this rider for you because it changes a move the docs describe. Already
  merged as one commit on ext/parity-stranded-0246.
- **Clip:** `godot --path . -- --combo51-shots --combo51-hero=juggernaut --combo51-part=chain --shots-dir=<dir>`
  (Haul strip) on ext/parity-kael-cc-riders vs ext/w0246-combat-b-wip.
