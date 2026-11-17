# Review kit (added 11-10). Run from the repo root after any batch of changes.
- `RULES.md`: the owner's 12 art rules as a checklist. Score every Boki against it; do not review from memory.
- Measured audit (outline, soft shading, detail density, backdrop, cropping, sheet view count, hero holes): the script is in the 11-10 session notes; rebuild it from `tools/flat_card.py`, `tools/autopick_sheet.py` and `tools/herocut.py`.
- Sheet-versus-card colour check: compare the colour histogram of each card's creature with its sheet's; overlap under about 0.42 usually means the sheet is an older design.
- Icon pass: view every hero at 72 px on a dark background.
- Look-alike pass: silhouette overlap plus colour overlap for every pair from different lines; judge the top 30 by eye (mostly false alarms).
- Pokemon pass: put the riskiest Boki beside official artwork of the nearest Pokemon (PokeAPI sprites repo), not just memory.
- Independent reviewer: spawn a separate agent that sees only the art and `RULES.md` and writes `REVIEW_AGENT_<date>.md`. The art session is biased toward its own picks.
- Owner page: a single-file review page (every line, OK / Change per Boki, notes copied back into chat).
