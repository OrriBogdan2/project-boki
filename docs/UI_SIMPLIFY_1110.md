# UI simplification pass (10 November 2026)

Owner order 11-10: simplify the whole UI from a player's point of view. Every menu, HUD element,
overlay and popup was read twice, as a first-time player ("what do I need to see and do here?") and
as a returning one ("what is in my way every time?"). The Void & Masks look stays (torn violet
panels, neon edge, parchment tabs, the one magenta ticket), but there is less of it: only the panel
is torn, cards inside it are plain, the speckle and runes are half as dense. Branch `ext/ui-simplify`,
rebased onto `ext/ui-void-masks-v3` (the "before" shots are `ext/ui-void-masks`, the branch this
pass started from; v3's chunkier frames landed in parallel). Before/after: `/home/boki/art-review/ui-simplify-1110/` (`before/`,
`after/`, `before_after.jpg`), taken with `--void-ui-shots` (extended for this pass with the
inventory, the pre-match lobby, the match HUD and the results).

## Per screen

**Title.** First time: one big "New game", a few quiet items. Returning: "Continue" and go.
Noise: the version printed twice (bottom left and on the playtest chip), and "Demo match", the
owner's filming match, sitting between Arena and Save files as if it were a mode. *Changed:* the
bottom-left version label is gone (the chip has it); Demo match only shows when admin tools are
allowed (desktop, not `--showcase`). The menu is Continue, Arena, (Play with friends), Save files,
Settings, Quit.

**Save files.** Six slots, one primary. Noise: the explanatory subtitle ("Each save has its own
island...") and every empty slot saying "Empty slot / Start a new story here" twice. *Changed:* no
subtitle; an empty slot is "Empty" with its New game button. The torn card-in-card look is gone
with the plain `card()`.

**Settings.** Seven tabs for a player who mostly wants volume and keys: Gameplay, Controls, Camera,
Audio, Video, Accessibility, Demo. *Changed:* five. Camera is a group inside Gameplay (three rows);
Demo (filming) only exists for the owner (`Overlay.settings_tabs()`); the rows, hints and the
Reset / Done footer are unchanged.

**Esc menu (home and match).** Noise: a subtitle saying where you are ("Your island"), Settings
and Controls as two full buttons for one panel, Save files as a full button you press once a
month. *Changed:* no subtitle; one Settings button (Controls is its second tab, and the panel opens
on the tab you used last); Save files joins the quiet link row with Change your look and I'm stuck.
Home: Resume, Inventory, Training area, Settings, the quiet row, Save and go to the main menu, Save
and quit. Match: Resume, (Change Hunter), Settings, Leave match.

**Creator ("Make yourself").** One panel, one primary, the model to turn. Fine as it is: no change.

**Hatch intro card, egg pick.** One line and one ticket each. No change.

**A new Boki's reveal.** On `ext/ui-void-masks` the name was on screen twice: a big title over the
scene and the parchment tab on the card. This pass cut the title; the parallel v3 pass then rebuilt
the reveal as one big card with the Boki in its void window and the name as a banner on it, which
has the name once already, so v3's reveal is kept as is.

**Welcome home modal.** Two short lines and Let's go. No change.

**Farm HUD.** Top left: your partner, gems, tonics, crops, materials, treat. For a new player that
was "1 tonic · 0 crops · 0 wood · 0 stone · 0 fibre · 0 coals" of zeros. *Changed:* a chip shows only
once you have any of the thing (tonics, crops, materials). Bottom: six key hints every second of
play, including WASD and Space that every player knows. *Changed:* four hints (use, whistle, build,
Esc menu). Goals tracker and hub bar unchanged.

**Inventory.** Six tabs (Items, Seeds, Crops, Furniture, Kin, Field Book), four of them usually
empty. *Changed:* four tabs: Items, Farm (seeds, crops and furniture on one page), Kin, Field Book.

**Market stall.** A title, a subtitle ("Goods for your Boki, your Hunter, the farm and the house"),
a row of stall tabs, a row of goods tabs, cards, a footer line. *Changed:* the subtitle is cut (the
tabs say it); the rest stands, the goods cards are plain now.

**Black Market.** A two-line subtitle with the broker's name and a number of expeditions.
*Changed:* one short line ("Boki nobody came for, word from whoever took yours, and rare things
under the counter.").

**Job Board.** Twelve jobs with Off/Low/Normal/High each is a lot of buttons, but it is the whole
screen's job and each row reads the same; one subtitle and one footer line explain it. No change.

**Boki Burrow.** With nothing picked, the side column was a six-sentence manual. *Changed:* two
lines (room on the farm; click to see, drag to move or swap). The rest of the rules show up where
they bite (the farm-full and duplicate notes on the results screen).

**A Boki's page.** Four tabs, bars, likes, work elements and a footer of five actions with Feed as
the primary. Dense but every piece is something you do here. No change.

**Build menu.** Categories, a search, Store / Undo / Done. No change.

**Pre-match lobby (Hunter pick).** An eyebrow ("Before the drop"), the title, a two-sentence hint,
and a squad/chat column that fell off the right edge of a 1280-wide window. *Changed:* no eyebrow,
the hint is one sentence ("Picks lock when the timer ends."), the side column is narrower and the
Hunter grid fits as many cards per row as the window allows, so the squad column is on screen.

**Loading screen.** Kicker, title, blurb, mode line, conditions and their blurb, progress bar with
a stage and a percent, then a tip card holding a tip AND a line of lore. *Changed:* the lore line is
gone (the tip card is one thing to read); everything else stays.

**Match HUD.** Supervive-style and kept minimal on purpose (`hud.gd` is frozen). Audit notes: two
tip banners can stack at the top centre at once; the "Your kit" panel (eight rows) sits over the
world labels on the right for 14 s after every landing. *Changed:* after three expeditions the kit
panel shows names and keys only (`Hud.KIT_FULL_RUNS`); a first-time player still gets the
descriptions. Not touched: the vitals, slots, minimap, clock bar, feed, squad plates.

**Tutorial prompts.** One banner that settles into a pill, a check beside it, messages in their own
lane: already one lane per thing. No change.

**Results.** Kicker tag and tier, your Hunter's name and title, the big outcome, a sentence, four
big stats, a second row of four small stats, mastery line, loot chips, the Boki card, notes, one
primary. *Changed:* the name line is gone (you know who you are), the small stats row is gone and
the big strip is the four a player asks about: Knocks, Kills, Damage, Time (the armour tier was a
strange headline).

## The look, less of it

- `UI.card()` is a plain rounded frame again. Panels, buttons, tabs, tiles, tooltips and popups keep
  the torn edge; a list of cards inside a torn panel no longer reads as boxes in boxes.
- The panel's blotches, speckle and runes run at half density (`UiTheme._panels`, grain 0.5).
- Subtitles only where the title alone doesn't say what the screen is for.

## Cut

Title version label; Demo match (for players); the Save files subtitle and "Start a new story
here"; the Camera tab (now a group) and the Demo tab (for players); the Esc menu subtitle and its
Controls and Save files buttons; zero-count farm chips; WASD and Space
hints at home; the Seeds / Crops / Furniture tabs (one Farm tab); the Market subtitle; the Black
Market's long subtitle; four paragraphs of Burrow help; the lobby eyebrow and half its hint; the
loading screen's lore line; the results' name line and small-stats row; the kit panel's descriptions
for returning players.

## Checks

See the report in briefs/EXT_TO_MAIN.md: the checks run were the UI ones (`--title-check`,
`--uipolish-check`, `--keybind-check`, `--prematch-check`, `--market-check`, `--hatch-check`,
`--tutorial-hud-check`, `--layout-check`, `--hero-title-check`, `--farm-tutorial-check`) and
`tools/health.py --strict`. `--uipolish-check` and `--title-check` were updated for the new tab
list and the gated Demo match.
