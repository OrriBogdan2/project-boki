## Deathbox rows: slot tag, arrows, Swap (11-28)

- A gear row in the loot window (box and yours) names its slot and the key that uses it ("GLOVE 2  ·  V",
  "BOOTS", through `Settings.key_cap`), after the rarity-coloured name. Columns are 450 px so the tags don't clip names.
- The compare card (`InvText.compare`) and the ground card (`GroundCompare`) write each changed number with
  `InvText.change_line`: a green up arrow when better, a red down arrow when worse. The "(better)"/"(worse)" words are gone.
- One click takes gear into the slot it belongs in. A piece that is not better reads Swap (it trades places with what
  you wear, yours goes into the box); a backpack piece with no room reads Swap and holds for you to pick what to give up.
- The footer names the confirm and menu keys through `Settings.key_cap`; the window listens for those actions.
- `--loot-window-check` also covers the arrow lines, the slot tags, the footer keys, one-click wear, Swap on a worse
  piece and the held swap prompt. `--loot-full-shots` adds `gear_box.png`.
