# Handoff: feelfix (branch `feelfix`, based on `integ36`)

Pushed to origin/feelfix, merged with main at sync58 (e5f25ec), ready for the main session to merge. Godot runs go through the `godot` queue wrapper (fresh temp XDG_DATA_HOME).
For screenshot checks (`--hero-check`, `--keybind-check`, `--swim-check`) pass
`--shot=/tmp/x.png --frames=99999 --shots-dir=<dir>`. The dummy `--shot` turns off the boot splash,
and `--shots-dir` is where the check writes its images. Screenshots are in /home/claude/shots/feelfix/.

| # | Item | State | Commit | Files |
|---|------|-------|--------|-------|
| 1 | No web version / Claude in player text | done | 5b82a0b | scripts/home/home.gd, scripts/ui/lobby.gd |
| 2 | Overhead dash pips | done | 08170b4 | scripts/ui/hud.gd (_dash_strip), scripts/main.gd + scripts/match/match.gd (--dashpip-demo) |
| 3 | Walk off ledges | done | 6d6200b | scripts/match/hunter.gd (guard: bots only), scripts/home/home.gd, tools/abyss_check.gd |
| 4 | Character view (lean) | done | aa403ae | scripts/match/cam.gd (char_lean/char_basis, 20 deg), scripts/match/hunter.gd, scripts/home/home.gd, scripts/ui/hud.gd (_head) |
| 5 | Abyss tint per reference | done | d3c11d8 | scripts/match/abyss_fx.gd, scripts/ui/hud.gd, scripts/home/home.gd, scripts/match/match.gd (--abyss-demo=dip), tools/move_feel_check.gd |
| 6 | Isle bridge placement | done | 62d027f | scripts/home/home_layout.gd (bridge_span/isle_bridge), scripts/home/home.gd, scripts/home/home_build.gd, tools/farm_start_check.gd |
| 7 | Water / swimming | done | d645bd7 + follow-ups | shaders/pond_water.gdshader, shaders/pond_foam.gdshader, audio/splash*, swim*, drip.wav, scripts/home/home_water.gd (all water logic), home.gd (a few wiring lines), home_build.gd, home_gather.gd, tools/swim_check.gd, scripts/main.gd (home-build-check) |
| 8 | Change hero on the farm | done | 3ddde53 | scripts/home/home.gd (_open_hero/_pick_hero), scripts/core/game.gd (J), settings.gd, overlay.gd, tools/hero_check.gd |
| 9 | Secondary keybinds, ult X | done | efeb072 | scripts/core/settings.gd, game.gd, scripts/ui/overlay.gd, arena.gd, duel.gd, drop_squad.gd, hud.gd, home.gd, home_training.gd, tools/keybind_check.gd |
| 10 | Demo landing safety | done | 305a174 | scripts/match/match.gd (demo_shielded), ent.gd, bot.gd, mob.gd |

## Notes per item
- 1: The Boki chat no longer shows an offline note. The ferry says it isn't running yet. Lobby status is neutral. Code comments and the Bridge internals are unchanged.
- 2: The dash pips are now one slim strip under the health bar. There is one segment per short dash plus a short pale-blue segment for the long dash. Fill is linear with a leading edge, a white flash shows when a charge returns, and the strip is pixel-snapped. Before/after: pips_before_strip.png and pips_after_strip.png.
- 3: The walk guard only applies when `ctrl == "bot"`. On the farm, `guard = false`. --abyss-check adds "walking toward an edge goes over it" (6/6 expedition, 4/4 home) and "bots keep their guard". --mantle-check passes.
- 4: Hunters lean back 20 deg about their feet, so their fronts turn up toward the camera. Comparison image: char_view_compare.png. Things to tune: CamRig.CHAR_LEAN. Kins are not leaned.
- 5: What the reference shows. In D1, the tint is strong from the first frame below the lip and stays on while falling. Frame 8 fades and frames 9-14 are clear while the glider lifts and glides, even though the player is still out over the void. The tint returns at 15-22 on a fall, and 23 is clear when rising again. In BH, onset is faint for one frame (21, 28, 36), then strong (11, 12, 20, 29), and frame 37 is crimson with dark edges. Implementation: a quick onset (0.55 by 12% of the drop), full at 95% of the drop, and 0 while vel.y > 1. The move-feel targets were not changed: tint_half is 0.726 and tint_end is 1.0. One new target was added: abyss_tint_rising <= 0.02. Contact sheet: abyss_dip_sheet.png.
- 6: The bridge position is computed from the real edges for each world (HomeLayout.bridge_span). The farm-start check covers 50 seeds and passes. The fixed Data.ISLES rects are only a fallback.
- 7: The farm's ponds use an animated water shader with bank foam. Water tiles are no longer solid; `occ` still marks them "w" so you can't build on them. Edge tiles are shallow: you wade at 0.68x speed. Deep tiles mean swimming: 0.5x speed, sunk to the shoulders, a forward stroke tilt, and no dash, jump or tools. Entering splashes, swimming plays a stroke sound, leaving drips. Boki paddle low and bob. Water is never void. All of this lives in `scripts/home/home_water.gd` (`Home.water`: depth(), step(), speed_mul(), drop_y(), tilt(), paddle()); home.gd only has wiring (it was over its health budget, so the logic was moved out). --swim-check passes. --home-build-check now asserts a pond tile is wadeable water that can't be built on (it used to assert it was a wall). Screenshots: swim_before_flatwater.png (the old flat pond, same scene) and swim_after.png. Left as is: no dedicated swim pose in HunterAnim (it uses the glide pose); the match map's flat blue areas were not touched (water there is not wadeable).
- 8: The key is J because H is the whistle. The training grounds read Arch.of_save(), so they follow the pick. The hero_unlocked / hero_requirement hooks are in home.gd. Screenshot: hero_panel.png.
- 9: A one-time migration (keys2_v) adds X to an empty ultimate slot and moves "separate" from X to Z. The arena and duel resets moved to Backspace. Home build mode still uses X to store items there (no clash outside the farm). Screenshots: keybinds_controls.png and keybinds_conflict.png.
- 10: Traced at seed 5 with a temporary damage log. Damage came from a brute camp and skitters next to the landing spot, from the rival bot "Waekri" (provoked when your Boki hit it), and from one unsourced hit. After the fix, a run to t=155 shows no damage until t=155, well after the 60 s grace. The handmap branch was not merged or tested; Net.VERSION was not touched.

## Final state
- Merged origin/main (sync58, e5f25ec, Net 0.10.0). Net.VERSION unchanged by this branch (no sync shape change; reserved number 0.9.4 unused).
- `python3 tools/health.py --strict` passes (home.gd 5938 / 5950, hud.gd 3754 / 3850). `tools/gen_wiki.py` regenerated Controls.md (R / X ultimate, J, Z).
- --arena-check now also presses X (must not reset) and Backspace (resets). --record-check never used the reset key and needed no change.
- Check assumptions fixed after "walking off an island is allowed now" (assertions unchanged): --drop-check scouting brings the player back first, --boss-check walks out for 1.5 s not 3 s and counts an outsider shoved off the updraft's lair as out, --obstacle-check skips clusters whose way out is over the edge, --farm-start-check picks a tree whose own spot resolves to it (a boulder beside it could win), --swim-check waits a frame after its no-jump press, --home-build-check treats ponds as wadeable.
- The Hunter edge guard is bots-only; anything new that walks a person near an edge in a check must expect a fall.
