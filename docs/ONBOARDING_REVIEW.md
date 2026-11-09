# Fresh-player review: the first ten minutes (2026-11-09, origin/main d255acbee)

Method: `--onboarding-flow-shots` (tools/onboarding_flow_shots.gd) plays the real screens on a fresh save, in the order a
new player meets them: title, prologue, Hunter creator, egg and hatch, Relic put-on, the tutorial match, results, the
first farm visit, the first expedition (pick screen, loading, drop map). It takes a shot every 3 s on menus and every
8 s of match time. Hob and the farm steps come from `--hob-check --shots-dir` and `--farm-hob-shots`. 1280x720, run
through `jobq --needs gpu`. The tutorial match is played by `TutorialDrive`, so its pacing (the long stays on `gkey`
and `rank`) is the driver's, not a player's. Shots are in `docs/onboarding_review/` (960 px).

At every stop a new player had one obvious thing to do, with these exceptions.

## Fixed here (3)
1. **Welcome home card hidden under toasts.** The three arrival toasts (Relic unlock ready, new blueprints, Old Pell's
   market) stacked over the card's title. `Home._toast` now waits while the Welcome card is open.
   `welcome_toasts_before.jpg` / `welcome_toasts_after.jpg`.
2. **Loading screen: the conditions line ran into "Spawning…".** At 720p the raid blurb and the stage label overlapped.
   The mode, conditions and blurb lines sit 8 to 12 px higher. `loading_overlap_before.jpg` / `_after.jpg`.
3. **"Mask" in player text.** Three loading-screen lore lines said Mask (`A Mask holds the soul`, `dug up Masks`,
   `Not every Mask has a face`). They say Relic now, like the rest of the text.

## Open (not fixed)
| # | Moment | What a new player sees | Shot |
|---|---|---|---|
| 1 | First expedition, pick screen | The Hunter grid and the squad column run off the right edge at 1280 wide: the countdown and the Ready state are not visible, 90 s of waiting with no cue. Already fixed in flight: READY ext/prematch-declutter-rebased 8f1ccd06a (countdown banner, 4-wide grid). Re-shoot after it merges. | `prematch_clipped.jpg` |
| 2 | Results after the tutorial | Five blocks of small text (stats, "Relic challenge done! Hold to unlock...", loot, armory, closing line) around one clear button. Readable, but the Relic line is the only one that says what to do next and it is the smallest. | `results_dense.jpg` |
| 3 | First farm look, after Welcome | Three prompts at once, all about Hob (top line, Goals card, bottom "Talk to Hob" key). They agree, so nothing is lost, but the Goals card also lists four unrelated goals (air hits, 3 expeditions, boss, farm level 2). | `farm_first_look.jpg` |
| 4 | Farm steps 2 and 3 | The "Hob hands you an axe" toasts sit over the site's "Needs 1 more stone" world label. | hob-check shot 5 (offer line) |
| 5 | Tutorial, Boki steps | The G card ("Send Vespyx out") and a toast about Kindling are up together, with "Vespyx is down" in the corner: three small voices in one fight. A downed Boki counts as done for the step, so it never blocks. | `tutorial_gkey.jpg` |
| 6 | Prologue slide 3 | One frame of black with grass patches during the slide change (shot 07 of the first run). Transient, not reproduced in the second run. | - |
| 7 | Plan your drop | The legend (boss lair, vault, rare Boki, item cache, ways out) is 11 lines of 8 px text next to the map. Nothing says which island to pick for a first drop. | - |
| 8 | Names | "Old Pell" is named in a toast before any scene introduces him. | `welcome_toasts_after.jpg` |

Retired words: no Warden, Mantle or Mask in any shot after fix 3. A source grep still finds `Warden`/`mantle` only as
ids, doc strings and mechanic names (the glide mantle), not as player text.

Never a moment with no next step, apart from open item 1 (in flight).
