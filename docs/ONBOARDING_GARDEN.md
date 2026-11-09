# Fresh-player onboarding in the Boki base (garden)

DECISIONS rule: any onboarding change is reviewed with a fresh-player playthrough; there is never a moment where
the player does not know what to do next. This is that review for the base (`base_mode` on, GARDEN.md section 8).

## How it was run

`--garden-fresh-run` (`tools/garden_fresh_run.gd`, registered in `tools/check_registry.gd`) starts a brand new save
as the hatch leaves it (one trusted starter Boki, `hatched`/`intro`/`match` set, `base_mode` on), opens the home,
and then does **only what the screen offers**: it presses the buttons that are on screen (`Let's go`, `Feed`,
`Base`) and walks up to the marker. At every step it logs the tutorial line, the base card's next-step line, the
world marker, the Boki's own cue (speech bubble or want) and the open panel. It then asserts:

- no 8 s window (sampled twice a second) with no line, marker or Boki cue
- each step's line names an action that exists (no named button that is not on screen)
- the camera never swings to Hob while the first step is the Boki
- jargon first-appearances are logged (step by step) for review below
- panel groups are counted for every open panel

`--shots-dir=<dir> --size=WxH` saves a screenshot per step (GPU: `jobq submit --needs gpu`). The hatch itself
(egg pick, name card) is not driven: the run starts where `hatch.gd _finish` leaves the save.
Alternative not taken: scripting the Hatch scene through its buttons; the hatch is untouched by the garden.

Result on the fixed code: 0 failures, 0 gaps. Result before the fixes: the feed step could not be completed
(finding 1), and four asserts failed.

## Findings, ranked

Status: **fixed** = text/hint change in this branch; **listed** = not fixed (bigger than S or an owner call).

### 1. Blocker, fixed: the Feed step cannot be done
The tutorial hands over 3 Emberberries into `Save.d["items"]`, but Emberberry is a crop: the Feed panel reads
`Save.d["crops"]` and says "Nothing to feed it. Harvest crops, or buy kibble and buns at the market stall." In the
base there is no crop to harvest and nothing to sell, and the step never completes, so the toy and portal steps
never come. `--farm-tutorial-check` missed it because it fed through `Evo.eat` directly.
Fix: `FarmTutorial.give_food` puts a crop on the crop shelf. The check's `_berries()` now reads the shelf.

### 2. High, fixed: the tutorial line is hidden in base mode
`FarmGuide._refresh_hint` clears the hint box in base mode ("BaseHud holds the next step") but BaseHud showed
"Pip is happy: take a trip, or place a toy" during meet and feed, contradicting the marker ("Feed your Boki").
Fix: `BaseHud.next_action` returns the tutorial step line while the tutorial runs (and its signature includes the
step so it redraws). Screen (fixed): `docs/shots/garden_fresh/before_02_hob_calls.png`, card at left now says "Click your Boki ..."
(before the fix the same card read "Pip is happy: take a trip, or place a toy"; seen in the run log, not in a shot).

### 3. High, fixed: the arrival text points at the old farm
- Welcome home said "Hob will show you around". Hob does not show the base around. Now (base):
  "Say hello to it, give it a snack and put a toy down. Out in the wild, what you find is only yours once you make it back."
  (text moved to `farm_tutorial.json` `welcome` / `base.welcome`, `FarmTutorial.welcome()`; same line count in `home.gd`).
- The "F Talk to Hob" prompt is on screen from the first second, and his first talk was about the market stall,
  a house, an axe and chopping a tree, none of which exist in base mode. New `intro_base` lines in
  `farm_builder.json` (base: "This is your base. Your Boki lives here, and it plays on its own.", etc).

### 4. High, fixed: two leads at arrival
Once the Welcome card closed, the camera swung to Hob, who shouted "Hey! Over here!" while step 1 said "Your Boki".
Screen (before the fix): `docs/shots/garden_fresh/before_02_hob_calls.png`, "Hey! Over here!" over Hob. Fix: `HobTalk._intro` skips the camera swing and `FarmHob._call_out` skips the shout every 9 s in base mode;
the run asserts it. After: `docs/shots/garden_fresh/after_02_boki_only.png` (card and marker both say feed your Boki, no shout);
`after_12_portal_line.png` is the last step's line. The Boki is the only lead.

### 5. Medium, fixed: the last step names a button that does not exist
The `out` step said "press Stay to keep playing", but the Stay and Skip buttons live in the hint box that base mode
hides. Text now: "Press F at the portal when you want to head out. Until then, your Boki keeps playing."

### 6. Medium, listed (M): the base tutorial can be neither skipped nor finished by staying
Same cause as 5: `FarmGuide._skip_buttons` (Skip, Stay) is unreachable in base mode, so `FarmTutorial.skip()`
and `event("stay")` never fire from the UI; the end reward (`end_gems`) is paid only by going through the portal.
A player who stays sees the portal line forever (a fine standing hint, but never the "happy" line).
Options: show Skip/Stay on the BaseHud card; or end the tutorial when the toy step is done and keep the portal
line as the card's idle line. Owner call.

### 7. Medium, listed (M): the Boki card has 11 groups, and the tutorial sends you there
"Click your Boki ... choose Feed" opens the full card (`docs/shots/garden_fresh/04_boki-card.png`): 4 tabs, Bond, needs,
Likes, Journal, Work elements, Role, and 5 footer buttons (Brush, Bath, Nap, Dress, Feed). Feed is the primary
button, so the next action is clear, but it is the heaviest screen in the first minute. Jargon that shows first
here with no explanation: **nature** ("Mischievous nature"), **farmhand** ("Make farmhand"), **Boki Burrow**,
**Partner**, **Work elements** (Spark, Haul, Forage). Suggestion for base mode: Care tab only, Feed and Play
up front, Training/Growth/work rows behind "More".

### 8. Medium, listed (S/M): the build bar opens on dead ends
Pressing Build opens the Buildings tab: House 10 wood 6 stone, Crop patch, Cooking pot, Market stall, but base
mode has no axe or pickaxe, so the House cannot be bought. The line "Press B, open Base" is right, but the tab the
player lands on is the wrong one, and **Garden** and **Island** are never explained (`docs/shots/garden_fresh/07_build-open.png`, `08_build-base.png`).
The bar footer shows "Farm level 1 · 0/6" and "Talk to Hob for more" (farm jargon). Suggest: base mode opens on
the Base tab and hides House/crop/pot/stall; footer hint names the toy tab.

### 9. Low, listed (S): step 1 flashes past
The Boki spawns within 3 tiles of the player, so Meet completes at once when the Welcome card closes; "This is
your Boki. Walk up and say hello." is only readable under the card. Suggest starting the player farther, or
removing the Meet step and opening with the Feed line.

### 10. Low, listed (S): the top bar and the toy hand-off
- The bottom bar shows Expedition, Boki, Bag, Market, Build, Settings, Relics at once (7 groups, over the 5
  limit): **Relics** and **Market** are unexplained, and Market has nothing to do in the base.
- When the ball is picked up (`docs/shots/garden_fresh/09_ball-held.png`), the line still reads "open Base and set a toy down"; nothing says
  where to click to put it (the world marker is empty in the `place` stage).
- **portal** first shows at the last step, but its marker says "Portal" over the portal, which explains it.
- No Boki cue at all in the first minute: Pip never speaks or walks to the player (`Boki:` empty in every
  step), so "Boki lead" is only the marker. Waiting for the come-and-look work (`ext/garden-come-look`).

### Also fixed on the way
`HomeToys._lean` crashed once a Boki had eaten a typed snack (`rec["lean"]` is a dictionary after the lean foods,
the toy code read it as a string; a script error each toy weighing). It now reads `Evo.lean`; `--toy-check`
builds its record with a lean dictionary.

## Windows and panels, measured

| Moment | Prompt on screen | Marker | Boki cue | Longest silent stretch |
|---|---|---|---|---|
| Welcome card | Welcome home (3 groups), one button | Your Boki | none | 0 s |
| Meet / feed | "Click your Boki ..." (card + marker) | Feed your Boki | none | 0 s |
| Boki card | same line | same | none | 0 s (11 groups, finding 7) |
| Feed panel | 2 groups, Feed button | same | none | 0 s |
| Toy | "Press B, open Base ..." | none | none | 0 s |
| Watch / portal | "Press F at the portal ..." | Portal | none | 0 s |

The silent-stretch column is 0 everywhere because the base card always carries a line; what the run cannot
measure is whether the line is the right one, which is what findings 1-5 were.

## Checks

`--garden-fresh-run` (new, 0 fail), `--farm-start-check` (the known `open meadow it tints green` fail on main,
plus one headless-timing fail that changes between runs), `--base-check`, `--farm-tutorial-check`,
`--base-hud-check`, `--toy-check`, `python3 tools/health.py --strict`, `python3 tools/gen_wiki.py --check`.

The branch carries the unmerged garden stack it needs (`ext/tutorial-garden-4`, which brings `ext/garden-base-mode`,
`ext/garden-toys` and `ext/garden-lean-foods`; `ext/garden-snack-patch`; `ext/ui-base-hud`).
