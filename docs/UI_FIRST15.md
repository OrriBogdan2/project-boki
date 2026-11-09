# UI audit: the first 15 minutes on a fresh save

Owner rules (DECISIONS 2026-11-08): show only what is needed now; **no more than about 5 HUD groups at once**; **one "what to do next" prompt**.
This file counts the groups on every first-run screen, lists what clips, and lists jargon that shows before it is explained.
It feeds the declutter jobs. Only two clipping bugs were fixed here (section 3); everything else is listed, not changed.

## 1. How the shots were made

`godot -- --first15-shots --shots-dir=<dir> --size=1280x720` (tool: `tools/first15_shots.gd`; `--part=match|panels` runs one part). It
plays a fresh save through the real screens: title, prologue, hatch card, creator, eggs, name, first Relic, the tutorial, results,
farm, expedition panel, Relics page, a first expedition (plan, ship, landed, 15 s) and pause. It also writes `layout.txt`: every UI control
(Control node) that crosses the window edge (CLIPPED) or sits inside a 5% margin. HUD parts are drawn, not nodes, so they were checked on the
pictures.

- Shots: [`docs/ui_first15/1280x720/`](ui_first15/1280x720) (full set, 36) and [`docs/ui_first15/1920x1080/`](ui_first15/1920x1080) (the key ones).
- **Renderer: software (llvmpipe, `--rendering-driver opengl3` under Xvfb), not the GPU.** The GPU queue held 56 jobs (oldest 10 h) so the two
  `--needs gpu` jobs (`first15-1280x720`, `first15-1920x1080`) were never reached. The UI is 2D, so layout is the same; 3D looks (water, light) differ.
- **1920x1080 lays out in the same 1280x720 space** (UI scale 1.5, `Settings._apply_ui_scale`), so every position below holds for both sizes.
  No control was CLIPPED at either size; the 1080 run only differs in a few centred cards by about 20 px.
- The tutorial was driven by `TutorialDrive`, so Boki and kills happen faster than a person plays. The first expedition lands on the first spawn.
- "Group" = a separately placed block the player has to scan. HUD groups: minimap, clock/status strip, top-right counters, vitals (portrait, health, level),
  ability row (with the Boki and G tiles), glider strip, belt 1-4, Q/V/X item slots, weapon and ammo, Relics/Leave bar, tip card (the "what next" prompt),
  message lane (toasts, kill feed), perk line, world prompt.

## 2. Groups per screen

| # | Screen (shot) | Groups | Over 5? | Note |
|---|---|---|---|---|
| 01 | Title ([01](ui_first15/1280x720/01_title.jpg)) | 4 | no | menu, playtest card, key hints, version |
| 02-03 | Prologue ([02](ui_first15/1280x720/02_prologue_1.jpg)) | 5 | at the limit | progress pips, title, caption, skip, next |
| 04 | Hatch card ([04](ui_first15/1280x720/04_hatch_card.jpg)) | 2 | no | one line, one button |
| 05 | Creator ([05](ui_first15/1280x720/05_creator.jpg)) | 3 | no | but one panel has 10 option rows (Sex, Height, Build, Shroud, colour, Hollow, Glow, Ghost, Aura, name) |
| 06-07 | Egg pick, knock ([06](ui_first15/1280x720/06_hatch_eggs.jpg)) | 2 | no | title, 4 cards |
| 08 | Name your Boki ([08](ui_first15/1280x720/08_hatch_name.jpg)) | 1 card | no | but 2 text boxes, 4 idea chips, More, 2 buttons; stale subtitle "Every Boki is different..." stays under "Knock on the shell" |
| 09 | First Relic ([09](ui_first15/1280x720/09_first_mask.jpg)) | 1 | no | |
| 10 | Tutorial intro ([10](ui_first15/1280x720/10_tutorial_intro.jpg)) | 2 | no | card, Relics/Leave bar |
| 11 | Tutorial landing ([11](ui_first15/1280x720/11_tutorial_00_land.jpg)) | **9** | **yes** | minimap, vitals, ability row, glider strip, belt 1-4, Q/V/X, weapon, Relics/Leave, tip |
| 12-22 | Tutorial steps dash..chest ([12](ui_first15/1280x720/12_tutorial_02_dash.jpg), [17](ui_first15/1280x720/17_tutorial_07_gkey.jpg), [18](ui_first15/1280x720/18_tutorial_08_rank.jpg)) | **9-11** | **yes** | the same 9 plus toasts, a second prompt (Alt+E rank, Press F) |
| 23 | Tutorial fight ([23](ui_first15/1280x720/23_tutorial_17_fight.jpg)) | **12** | **yes** | 9 plus a stack of 3 toasts, the perk line, a loot prompt |
| 24-26 | go-exit, uplink, defend ([25](ui_first15/1280x720/25_tutorial_19_uplink.jpg)) | **10-11** | **yes** | 9 plus tip, a prompt bar, the kill feed |
| 27 | Results ([27](ui_first15/1280x720/27_results.jpg)) | 1 card | no | dense inside (4 stats, 4 small stats, 3 lists) |
| 28 | Farm arrival ([28](ui_first15/1280x720/28_farm_arrival.jpg)) | 5 | at the limit | "Welcome home" modal over top bar, Hob hint banner, quest tracker, bottom hotbar |
| 30 | Expedition panel ([30](ui_first15/1280x720/30_expedition_panel.jpg)) | 1 panel, 6 blocks | **yes** | Relic grid (12, 11 locked), Where (3), Match, Abilities strip, 3 mode links, Start; scrolls |
| 31 | Relics page / Hunter pick ([31](ui_first15/1280x720/31_hunter_pick.jpg), [after](ui_first15/1280x720/31b_hunter_pick_after_fix.jpg)) | 1 panel, 6 blocks | **yes** | 12 tiles, Mastery (4 goals), Glider, 3D viewer, kit tiles (6), Kit card |
| 32 | **Plan your drop** ([32](ui_first15/1280x720/32_expedition_plan.jpg)) | **7+** | **yes, the worst** | title and timer, squad panel, full map, "This match" legend (4 kinds + 4 states), "Ways out" (5), bottom HUD, counters |
| 33 | Ship ([33](ui_first15/1280x720/33_expedition_ship.jpg)) | 9 | **yes** | the match HUD, with locked ability slots reading "UNLOCK" |
| 34-35 | Landed, 15 s ([35](ui_first15/1280x720/35_expedition_15s.jpg)) | **10** | **yes** | minimap, clock, status strip (Dusk / Sight), counters, vitals, abilities, glider strip, belt, Q/V/X, weapon, plus the Truce chip |
| 36 | Pause ([36](ui_first15/1280x720/36_pause.jpg)) | 1 | no | 3 buttons, "I'm stuck", "Admin tools (F1)", Leave match, Save and quit |

**Breaches (over about 5):** tutorial landing and every tutorial step (9-12), the first expedition HUD (9-10), Plan your drop (7+), the expedition panel
and the Relics page (6 blocks each, plus 12 Relic tiles). The in-match HUD is the same 9 blocks from the first second; nothing is introduced a step at a time,
and every step adds a second prompt (the tip card plus a world prompt, or a toast) so "one what-to-do prompt" is also broken. In the tutorial the tip
card and its fading copy show twice at once (`18`, `25`: the faded copy sits at y 490-570 under the live card).

## 3. Clipping at 1280x720 and 1920x1080

Nothing is cut by the window edge except these two, **both fixed here** (under 20 lines):
1. **Level coin** (bottom-left of the vitals): centred at the portrait corner with a 30 px ring, so 6 px of it left the window to the left and below.
   `scripts/ui/hud_vitals.gd`: coin centre moved 8 px in (1 line). Before [11](ui_first15/1280x720/11_tutorial_00_land.jpg), after [35](ui_first15/1280x720/35_expedition_15s.jpg).
   (The 0.35 s pop on level-up still reaches past the edge by a few pixels.)
2. **Hunter tile names on the Relics page**: `clip_text` cut "The Scrap King", "The Silver Thief", "The Stone Seer", "The Barnacle Knight", "The Void Jester" and more
   to "The Scrap Kin" etc. (84 px label). `scripts/home/home_classes.gd`: the name wraps to two lines (1 line). Before [31](ui_first15/1280x720/31_hunter_pick.jpg),
   after [31b](ui_first15/1280x720/31b_hunter_pick_after_fix.jpg). Side effect: the tile grid is taller, so the Mastery list and the glider pick sit lower and the panel
   scrolls sooner; the Relics page needs a real redo (see section 5).

**Inside the 5% safe margin (64 x 36 px at 1280x720), not clipped:** the whole drawn HUD sits 18 px from the edges (minimap, vitals, counters, toast lane: about
1.4%), so every HUD block breaches a strict 5% safe area. Controls inside it: title version, Discord card and key hints (y 605-706); prologue caption and "Space next";
creator panel (x 48); Name-your-Boki buttons (y 644-690, 14 px above the bottom edge); the in-match Relics/Leave bar (y 648-706); the toast lane (x to 1256, y 17);
the farm top bar (y 24) and key hints (y 679). Decide the safe-area size before the declutter jobs: the HUD would need about 3x more margin to meet 5%.

## 4. Jargon shown before it is explained

Retired terms (Warden, Mantle, Bearer, Merge, Unmasked) were not seen on any first-15 screen. Terms that appear before any line explains them:
- **Creator:** Shroud, Hollow, Glow, Ghost, Aura (shown on screen 05; "You are one of the Empty" is the only line).
- **Hatch:** egg types Venom / Prism / Spore, "BOLD / GENTLE / CURIOUS" tags (06).
- **Tutorial HUD (from the first frame):** Fever (resource bar), FIGHTING / FOLLOW (status under the portrait), COMMON / UNCOMMON (armour tier), AUTO, "from Boki",
  "CARRY OFF FOLLOW", "Relics / Leave" bar and the key `J`, the glider strip (4 unlabeled icons), belt slots 1-4, Q V X, "Box 0/3", seeds, the weapon class label
  "THE HIRED GUN · MEDIUM". Toasts name perks before any perk is explained: "Kindling!", "LEVEL 6 · Deep Magazine", "Quick Feed, Hotload".
- **Results:** Knocks, Armor "Uncommon", Tidebloom seeds, "Into your armory", the name line "Hunter the Hired Gun" (the default player name is "Hunter").
- **Expedition panel:** Relic, The Meadow / Dusk Isles / The Hollow, "BOKI AT RISK", Solo / Duos / Trios, "Arena / Training area / Duel room", ability names (Hot, Cinderfall, Burr).
- **Relics page:** Mastery, Colourway, Emote, Trail, Glider, Field Wing, Hot Streak, Boki Fusion.
- **Plan your drop:** Boss lair, Vault, Rare Boki, Item cache, Skiff dock, Uplink outpost, Rift hatch, Shrine, Revive beacon, "Drop leader", "Pass the lead", Truce (on the HUD at landing).
- **Title:** "Arena", "Save files".

## 5. For the declutter jobs (not done here)

1. **Tutorial HUD in steps:** show minimap + vitals first; add ability row when "dash"/"shoot" steps start, Boki tiles at the G step, belt at the loot step, weapon panel at the shoot step; hide Q/V/X and the glider strip until used. Target: at most 5 at any time.
2. **One prompt:** when a tip card shows, hold toasts and world prompts; remove the faded copy under the tip card.
3. **First expedition HUD:** same rule; hide counters, clock/status strip and Truce chip until needed.
4. **Plan your drop:** first match only needs map, the timer and "Space to jump"; move the legend and the "Ways out" list behind a key.
5. **Expedition panel and Relics page:** first visit shows the picked Relic, the one open Where choice and Start; fold the locked Relics, Match modes and the three mode links. The Relics tile grid needs a layout where full names fit.
6. **Creator and name card:** fewer rows on the first pass (Sex, Height, Build, colour; the rest under "More").
7. **Safe area:** decide the margin (see section 3) and apply it in `HudStyle`, not per panel.
8. **Glossary pass** for section 4: explain a term at its first appearance or use plain words.
