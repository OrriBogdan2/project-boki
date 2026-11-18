# Ghost / Dark split: list vs game data

Owner, 11-10: Shadow becomes Ghost and Dark (19 types). The list is `GHOST_DARK_SPLIT.md` (14 Ghost, 14 Dark). It names
28 Boki by Bokidex file id; this game has 50 species with their own ids, and a species' type is its `theme` in
`content/kin_v2/<id>.json`. Only four species had `shadow`, so only those four changed. Nothing was guessed: each
row below says which way it went and why.

## Changed (4 of 4 Shadow species)

| Game id | Game name | Was | Now | List entry used |
|---|---|---|---|---|
| duskapi | Snuffapi | shadow | ghost | Snuffapi (Ghost) |
| umbrathere | Umbrathere | shadow | ghost | Umbrathere / Ribbrella (Ghost) |
| gloamshell | Gloamshell | shadow | dark | Gloamshell / Duskargot (Dark) |
| caecilith | Zippelith | shadow | dark | Zippelith / Zipperpent (Dark) |

The game name of `duskapi` is "Snuffapi", which is the list's file id; matched by name. `umbrathere` and `gloamshell`
match by file id (the list's display names Ribbrella and Duskargot differ from the game's names).

## Mismatches

1. **24 listed Boki are not in this game's data** (no kin_v2 id or name): Wickapi, Chandelapi / Candelapi, Blotlet,
   Slog, Sloggoth, Parasolth, Ghoulamari, Sarcobra, Cindermaw, Palloth, Bellowlet, Furnacowary / Furnowary (Ghost);
   Zipling, Seamwyrm, Lurklet, Snapler, Maulangler, Lodestaff / Magnestaff, Gloamspire / Duskspire, Umbrink /
   Nightmink, Howlop, Eclipsowl, Reelacine (Dark). They live in the Bokidex roster only. Nothing to do here.
2. **Lodestick** is Dark on the list; the game has `lodestick` as **gravity**, and it never had Shadow. Left as
   gravity. Alternative: set its theme to `dark` (one line in `content/kin_v2/lodestick.json`); that also changes
   its merge style, so it is the owner's call.
3. **Bellowlet and Furnacowary** (Fire to Ghost): not in the game. The closest game species is `cindowary`
   ("Bellowary", ember). Names differ and it is not on the list, so it stays ember. Alternative: theme `ghost`.
4. **The game has one type per Boki**; the list says "keep its other type". The Bokidex roster has two types per
   Boki, so only the Bokidex patch (`art-review/ghost-dark-1110`) has any "other type" to keep.
5. **Old type names stay** (ember, frost, stone, bloom, storm, venom, gravity, prism, lunar, titan, swarm, tempest,
   spore, echo). Only Shadow was renamed. The game has 16 themes after the split (15 before), the Bokidex 19 types.

## Left alone on purpose

`shadow_step`, Shadow Knife, sight shadows, the shadow lore text and render shadows are not types.
No type matchups were added (owner 11-10).
