# Tab board: what the source showed, what we show

Owner, 11-11: holding Tab shows **your** stats, what you're wearing, your Boki and your **teammates**
(kills / deaths / assists, items). Rival squads' KDA, items and who is still alive must **not** show.
Seeing who is alive should stay hard.

## What SUPERVIVE's hold-Tab screen showed (research, 11-11)
Public sources say very little about this screen. Sources checked:

| Source | What it says | Confidence |
|---|---|---|
| SteamDB patch note 17253819 (search snippet only, because the page returns 403 to fetches): https://steamdb.info/patchnotes/17253819 | Added "Gold Score" (held + spent gold) "on the scoreboard next to Held Gold", next to damage in the top right. So a scoreboard existed, with a held-gold column and damage nearby. | Medium. The snippet is not the full note, and it doesn't say which teams the scoreboard lists. |
| SUPERVIVE wiki Glossary (last edited 31 July 2025): https://supervive.wiki.gg/wiki/Glossary | Treats Knock, Kill, Elimination and Team Elimination as separate events. It says nothing about the Tab screen. | High for the terms, none for the screen. |
| XDI.GG Supervive Stats (Overwolf, third-party): https://overwolf.com/app/xdi.gg-supervive_stats | A companion app that shows kills / deaths / assists / knocks live, so the game tracks those per player. It isn't the in-game screen. | Medium (the data exists). It says nothing about the screen itself. |
| superpatch.gg patch archive: https://zeyrin.github.io/superpatch.gg | No "scoreboard" in the 1.0 or 1.01 summaries. The full archive page didn't load. | Inconclusive. |

**Uncertain (not confirmed by any source I could read):**
- whether the scoreboard listed **every** squad's players and stats, or only your own;
- whether it showed which rival players were still alive.

The "next to Held Gold" wording points to a per-player table. From memory of gameplay footage (I couldn't
check it here), that table may have listed rival squads as well. **If it did, the source showed more about
rivals than the owner thinks.** We follow the owner anyway: no rival rows. The earlier note in docs/HUD.md
("the source shows no scoreboard") was not supported by any source and has been corrected.

## What we show (`scripts/ui/squad_board.gd`)
- **Squads left:** one number. No start total, rival rows, names, pips or alive state.
- **Your squad, you first, your row lit (teal edge, gold name):** hunter portrait (greyed when out),
  Alive / Downed / Out / Got away, kills / deaths / assists, damage, the four worn gear pieces
  (icon, rarity edge), and the Boki: form name, level, evolutions and state (Up / Down / Out / Resting).
- **Ways Out line** (your exit's state, else how many are open), kept from the base branch.

Stats come from Hunter (`kills`, `deaths`, `dmg_done`, `gear`, `kin`). Assists were not tracked:
`Hunter.assists` now counts a rival knocked by someone else within 5 s of your hit (ArchKit's existing
knock window). A hunter without an archetype kit (arch "none") gets no assists.

## Not done / differences
- No gold column: we have no gold economy in the match.
- In net play, a remote teammate's numbers are what this client has seen. Kills, knocks, damage and
  assists aren't in the Net sync shape (unchanged from before; adding them would bump Net.VERSION).
