# UI simplify pass (11-11)

Owner, 11-11: "on soul shrine there's a vertical text bug - do a full review of all the ui, hovering stuff, if its too
bloated (a lot is), and make it super simplified and easy to understand/use". Built on the house look of
[UI_STYLE.md](UI_STYLE.md) (ext/ui-pro-1111); its new section 7 ("Words") holds the rules this pass follows. The
Training Grounds UI (L page) is left to ext/training-merge-1111.

Check: `--ui-words-check` (tools/ui_words_check.gd). It opens every farm panel and menu below in a made-up save and
fails on a collapsed label (the vertical text bug), a tooltip over one line (14 words), or a cut screen over its
word budget. With `--shots-dir=<dir>` (under `xvfb-run ... --rendering-driver opengl3`, or a GPU) it also saves one
shot per screen. Before/after sheets: [`docs/shots/ui-simplify-1111/`](shots/ui-simplify-1111).

## 1. The vertical text bug

`UI.label` turns on word wrap for text over 48 letters. A wrapping Label has no width of its own, so in an HBox
without an expand flag it gets 0 px and draws one letter per line. The Soul Shrine (and a grave's page) put the
"why you can't" line ("Needs a Soul Ember (found in vaults and on Watchers)", 52 letters) next to the button in a
row. Fixed at the root: every wrapping `UI.label` / `UI.para` now also takes the row's free width
(`UI.wrap_text`). The shrine and grave put the reason under the greyed button (`HomeEcon._gated`).

## 2. Audit: every screen, words shown and tooltips

Made-up save (3 Boki, 3 graves, 2 souls kept, a shrine, 0 embers, 40 gems). "Words" = every word on a visible
label or button; "tips" = controls with a tooltip / their total words. Cut = one of the 15 fixed in this pass.

| Screen | Cut | Words before -> after | Tips before | Tips after |
|---|---|---|---|---|
| soul shrine | yes | 93 -> 84 | 6 / 27 | 3 / 5 |
| shrine lot | yes | 55 -> 51 | 2 / 10 | 1 / 2 |
| graveyard |  | 48 | 1 / 2 | 1 / 2 |
| grave | yes | 95 -> 66 | 2 / 12 | 1 / 2 |
| armory | yes | 45 -> 44 | 6 / 45 | 5 / 29 |
| expedition | yes | 258 -> 233 | 24 / 186 | 21 / 140 |
| kin page | yes | 93 -> 80 | 9 / 98 | 9 / 58 |
| feed |  | 17 | 1 / 2 | 1 / 2 |
| train | yes | 78 -> 68 | 1 / 2 | 1 / 2 |
| wear |  | 20 | 1 / 2 | 1 / 2 |
| job board | yes | 165 -> 87 | 29 / 322 | 11 / 69 |
| welcome |  | 35 | 1 / 2 | 1 / 2 |
| kitchen |  | 24 | 1 / 2 | 1 / 2 |
| challenges | yes | 116 -> 112 | 33 / 143 | 33 / 143 |
| hall |  | 39 | 1 / 2 | 1 / 2 |
| music | yes | 77 -> 18 | 1 / 2 | 11 / 47 |
| ferry |  | 25 | 1 / 2 | 1 / 2 |
| house |  | 40 | 1 / 2 | 1 / 2 |
| burrow | yes | 159 -> 73 | 63 / 445 | 30 / 163 |
| nook | yes | 163 -> 71 | 13 / 243 | 13 / 57 |
| market | yes | 117 -> 91 | 12 / 143 | 12 / 84 |
| black market | yes | 51 -> 39 | 2 / 4 | 2 / 4 |
| hunters | yes | 199 -> 191 | 19 / 363 | 15 / 99 |
| settings |  | 118 | 7 / 9 | 7 / 9 |
| pause |  | 33 | 1 / 2 | 1 / 2 |
| inventory |  | 30 | 2 / 3 | 2 / 3 |
| results |  | 51 -> 50 | 0 / 0 | 0 / 0 |

Not in the table: the in-match HUD and fight pop-ups (UI_STYLE section 6 budget, ui-pro-1111), the item hover
cards in a match (InvText already shows only the numbers that change), the pre-match lobby (its card tooltip lost
the kit-name list, kept the stat line), the Training Grounds L page.

## 3. What was cut

- **Soul Shrine**: one short subtitle; two chips (embers, gems), the "souls kept" heart chip that looked like the
  ember chip gone (a full shrine says so under Keep); no paw icons; the reason under a greyed button.
- **Grave**: no-shrine text 28 -> 12 words; the 40-word "what changes" note -> one 12-word line, only next to
  Bring back; the "N of 3 souls kept" line gone.
- **Shrine lot**: the three needs read the same way (`1/3`, `0/1`, `you have 40`); the red reason under Build it
  (it repeated the first unmet need) gone.
- **Armory**: one-line chip tooltips; the ember chip only when you have one.
- **Expedition**: "Extraction: trios, 7 squads of three" gone (nothing to pick); the session tabs' tooltips (they
  repeated the line under them) gone; the condition chip's tooltip (it repeated the line under it) gone; the
  "Boki left behind" warning only on a tier where Boki are at risk, in red; Hunter cards' tooltips are the unlock
  line only.
- **Hunters (Relics)**: one-sentence subtitle (the K hint is the footer button); tile tooltips are the unlock line
  only (were unlock + name + five ability names, 20-34 words); the lone "challenge" header when a Hunter has no
  tier is gone; mastery rows lost a tooltip that repeated the row. `ClassCard.kit_tip` deleted.
- **Job Board**: rows for jobs no farm Boki can do (and nothing waits on) are hidden behind one faint "N more jobs"
  line (12 rows -> 6 here); zero counters gone from the head; work-element texts (`Work.ELEMENTS` desc, shared with
  the Boki page and the Burrow) cut to one line each.
- **Burrow**: the 90-word help box -> two lines; a Boki's tooltip is "Name the Form · Lv N" (the click/drag help
  was on every cell); the empty-cell tooltips and long sort/filter tooltips gone.
- **Nesting Nook**: one-line subtitle; "How it works" is two lines; the IV strip tooltip is the grade and total
  (was 52 words of per-stat lines, shown again when you click the Boki); a tile's tooltip is only whether it can
  pair; the chart's own tooltip (it repeated the stat cells) gone. `Care.IV_EXPLAIN` 28 -> 10 words.
- **Challenges**, **Market**, **Black Market**, **Train**, **Music**: shorter subtitles; market seeds lost the
  "Plant on a farm plot." prefix and a locked good's tooltip no longer repeats the unlock line on the card; Music
  shows the track count as the subtitle and an undiscovered track's hint on hover instead of a column of hints.
- **Boki page**: the empty Journal block is hidden; "find out more" shows only while a like is still unknown.

## 4. Left for later

- Settings: every row has a description line (118 words on Gameplay); worth a pass with the settings owner.
- Hunter pick: tile names on two lines, Relics vs Hunters naming (UI_STYLE section 8).
- `ClassUnlock.requirement` for a Hunter with no unlock challenge in the rules reads " (0/1)" (seen in the
  made-up save only; a real save opens those Hunters).
