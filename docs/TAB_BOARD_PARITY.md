# Tab board: what the source showed, and what we show

Owner 2026-11-11: holding Tab shows YOUR stats, what you wear, your Boki and your TEAMMATES (kills, deaths,
assists, items). Rival squads' stats, items and who is alive must NOT be shown; it should not be easy to see
who is still up. The owner thinks the source hid that too. Built in `scripts/ui/squad_board.gd`
(`--scoreboard-check`); see docs/HUD.md.

## What the source (SUPERVIVE) showed

Researched 2026-11-11 from the official Steam patch notes (Steam News API, app 1283700) and the fan wiki.
The wiki says official servers closed on 2026-02-25, so the game can't be checked live. Gameplay videos weren't watched
(not reachable from this worker), so the screen's layout itself is **unconfirmed**.

| Point | What the sources say | Confidence |
|---|---|---|
| There was a scoreboard | "'Gold Score' ... is shown in the top right, next to damage, and on the scoreboard next to Held Gold" (FEB 5 2025 patch, [Steam][feb5], [wiki][wfeb5]) | Sure |
| Gold columns on it | Held Gold and Gold Score columns (same note) | Sure |
| Enemy info on it | The same note says "You can use this score to roughly calibrate enemy strength in terms of what they've purchased ... or compare farm rates with the rest of your team." This suggests rivals' Gold Score could be seen somewhere, maybe on the scoreboard. It doesn't say where. | **Unsure** |
| Squads left | Announcer lines for "4 and 3 squads remaining" (FEB 5 2025, [Steam][feb5]). The count was public. | Sure |
| Your squad's state | The left-side Team HUD shows each teammate's level ([wiki: Level][wlvl]); MARCH 5 2025 made "clearer at a glance whether a teammate is dead or alive" ([Steam][mar5]) | Sure |
| Hiding rivals | 1.03 (SEP 3 2025): drop pods no longer show which team is which, "to prevent cases where players are target dropping on known teams"; only spectators see team colours ([Steam][p103]). Season 2 (OCT 22 2025) added an "Anonymize Names" custom-game setting ([Steam][s2]). The studio did hide rival identity in places. | Sure |
| K/D/A columns | Knocks and assists were tracked (missions and XP count "Knocks/Assists", [Steam][apr2]). No source says which columns the in-match scoreboard had. | **Unsure** |

**Where it differs from the owner's view:** the source did have a scoreboard, and its own patch note
suggests rivals' gold strength could be read in a match. No source shows whether rival squads were listed
with names, K/D/A or alive state. We follow the owner: rivals get only the squads-left count, which the
source also announced aloud.

## What we show (0.24.6)

- **SQUADS LEFT** with a single number. No total, no list of squads, no pips.
- One row per hunter in **your squad**, yours first with a teal outline and a gold name:
  - the portrait (greyed when downed or out)
  - the name, and alive / downed / out / got out
  - K / D / A: `Hunter.kills`, `deaths` and the new `assists`
  - damage dealt
  - the four gear slots worn (`GearPanel.cell`, the same cells as the HUD)
  - the Boki: its name, level and evolved form, and what it is doing (ready, fighting, down, merged...)
- The base branch's rival rows ("Squad N" with alive / downed / out pips) and its Ways Out line are gone.
  Ways Out wasn't on the owner's list, and fewer boxes was asked for.
- **Assists** were not tracked before. `DashReset.takedown` already found the teammates whose hit or CC
  landed within 4 s of a knock or kill; it now also counts them. The knock and the finish after it count
  one assist for the same hits (`Ent.assist_t`).

Known gap: stats aren't synced over Net. In an online game a remote teammate's kills and assists only
count what your own game saw (this was already true of knocks). Logged in docs/DEBT.md.

[feb5]: https://store.steampowered.com/news/app/1283700/view/1790848102589412
[mar5]: https://store.steampowered.com/news/app/1283700/view/1793384379343843
[apr2]: https://store.steampowered.com/news/app/1283700/view/1795917897275785
[p103]: https://store.steampowered.com/news/app/1283700/view/1809869179984309
[s2]: https://store.steampowered.com/news/app/1283700/view/1814309641394166
[wfeb5]: https://supervive.wiki.gg/wiki/Gold_+_Mobility_+_Discord_Patch
[wlvl]: https://supervive.wiki.gg/wiki/Level
