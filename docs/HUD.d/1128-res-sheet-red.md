## Resolution sheet 11-28: red panels (1280x720, 1920x1080, 2560x1440, text 100%/150%)

Sheets: /home/boki/gens/ui-hud-res-sheet/sheet_<W>x<H>.png (border only: green = clean, red = problem). The UI lays out at a
logical 1280x720 at every window size, so the three sheets show the same layout; only the text size changes it.
`--safe-area-check` (rows below) fails 2 of 3 text sizes of the farm HUD: the same 2 rows at each of the 3 sizes.

Follow-up rows (one per red panel):
- [ui] Farm HUD: the "Next: ..." goal chip is clipped at Text size 125% and 150% (`Next: Fly through 10 air`, `Next: Make it out of 3 e`); widen or wrap the chip (red in all 3 sheets, farm_150).
- [ui] `--safe-area-shots` 150% "hud" frame has the results card ("EXTRACTED / The Hired Gun made it out") and the farm panels (Pip, Back to the...) drawn over the match HUD; check if the shot leaks the last screen (harness) or a real layering bug (red, hud_150).
- [ui] `--safe-area-shots` "pick" frame at 100% is a near-black capture (red, pick_100); the pick screen needs a longer wait before the grab.
- [ui] `--combat-hud-shots` has no `--size` (fixed 1920x1080); add it so the 1280 and 2560 frames can be sheeted.
- [ui] No single shot tool shows a 3-squad + Boki box + XP tracker together; the sheet pairs the safe-area "hud" frame (squad 3, Boki box) with the XP tracker crop.
