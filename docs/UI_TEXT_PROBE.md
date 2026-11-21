# UI text probe: no text one letter per line, off screen or on top of other text

`--ui-text-probe-check` (tools/ui_text_probe.gd, rules in tools/ui_text_scan.gd) opens the screens and panels the game can show and
judges every visible Label, RichTextLabel and Button. It fails when a text is
- **narrow**: autowrap is on and the column is under 3 average characters wide (the "name it" bug: 1 px wide, 55 lines);
- **tall**: more than 6 lines for under 40 characters;
- **outside**: partly outside the window (what a scroll area or clip hides on purpose does not count);
- **overlap**: drawn over another visible text, unless an opaque panel or a dimming scrim is drawn between them.

Screens: title, prologue, the hatch card, creator, eggs, knock, naming and first Relic, the pick, results, the farm and 40 of its panels (market tabs,
Boki tabs, loadout, expedition, burrow, kitchen, rack, job board, ...), settings (7 tabs), pause, confirm box, tooltip, controls, saves, admin, the
inventory (6 tabs), Field Book, the lobby, party, town, an interior, the match's pause / More / words / controls pages and the tutorial intro card.
Passes: 1280x720, 1920x1080 and 2560x1440 at Text size 100%, then 1280x720 at 150% (the biggest Text size).
It runs headless (layout only, no GPU), about 5 minutes, and is in the suite because every `-check` flag in `check_registry.gd` is.
A self-test first builds a made-up screen with one text per rule and a clean one, so a probe that went blind fails.

Options: `--size=WxH`, `--text=K`, `--scenes=a,b` (names as printed), `--report=<file>`, `--shots-dir=<dir>` (a jpg per scene; xvfb-run with
`LP_NUM_THREADS=2`, `--rendering-driver opengl3`). Each hit prints `UITEXT HIT <scene> | <node path> | <rule> | '<text>' | {size: detail}`.

Text the HUD draws itself through `TextCache` (`Hud._text`, `HudStyle.text` / `ctext`: the match HUD and drop plan) is
recorded while each screen is scanned and judged by the outside rule (path `drawn`). Not seen: the few raw `draw_string` calls
(tutorial strip and duo guide lines, Boki speech, tips) and world-hung text (names over heads).
A hit another branch owns goes in `KNOWN` (scene, path prefix, rule) until it merges.
Findings of the 11-17 audit (PR #247, shots in docs/shots/ui-vertical-audit/):

| Screen | Text | Rule | Size | Status |
|---|---|---|---|---|
| hatch_name | the naming subtitle, 1 px wide, 55 lines, off the top | narrow, outside | all | KNOWN: ext/name-it-vertical-1117 |
| hatch_creator | the subtitle ran 806 px off the right edge | outside | 150% text | fixed (`hatch.gd _top_over`) |
| pick, relics | "Start here" stamp over the hunter names | overlap | 150% text | fixed (`ClassCard.add_start_chip`) |
| match HUD (drop) | a message card over "Jump out: <key>" | overlap (drawn) | all | fixed (`DropHud.lane_top`) |
| minimap | place names over each other and the train's line | overlap (drawn) | all | fixed (`MapNames`) |
| drop plan / full map | region names over halt names, Ways Out timers, exit pills, hot zone, the jump pill; "Heart Gate" twice | overlap (drawn) | all, most at 150% | fixed (`MapNames`, 11 rows) |
| match HUD | the class resource name under a slot's UNLOCK | overlap (drawn) | 150% text | fixed (`HudSlot.locked`) |
