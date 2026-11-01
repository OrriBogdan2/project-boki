# Brief update 2 (from the main session, Nov 1). Applies to every agent on both machines.

## Main is about to move (sync56)
sync56 lands on main shortly. It contains kits2 (Thief + Juggernaut), the feelfix base, The Hollow Crown handcrafted map (now the default expedition map; old map via --map=skyreach, procgen via --procgen), AGENTS.md, tools/health.py, docs/GAMEDEV_CHECKLIST.md and the wiki (docs/wiki).
- Re-fetch origin/main before every merge. Once sync56 is on main, merge it into your branch, then read AGENTS.md and docs/GAMEDEV_CHECKLIST.md and follow them.
- `python3 tools/health.py --strict` gates shipping: match.gd, home.gd, main.gd, hud.gd, hunter.gd, models.gd and world.gd cannot grow. Put logic in new files; wire with a few lines. Run it before your final push.
- When game data changes (archetypes, weapons, items), run `python3 tools/gen_wiki.py` and commit the result; ship checks verify the wiki with `--check`.
- Checks that load a match now use The Hollow Crown by default. If a check or screenshot hook assumed the old map, pass --map=skyreach or fix the check.

## Net versions (replaces all earlier assignments)
Main is 0.6.0 now and becomes 0.8.0 with sync56. The main session's Boki system (branch `bokisys`) will take 0.9.0. If your branch changes the sync shape, use your number below (after merging sync56) and report it; the integrator reconciles.

| Branch | Net version |
|---|---|
| ext/fixes | 0.8.1 |
| ext/economy | 0.8.2 |
| rolling | 0.8.3 |
| feelfix | 0.8.4 |
| ext/heroes-joule-ghost | 0.8.5 |
| ext/heroes-elluna-celeste | 0.8.6 |
| ext/heroes-kingpin-felix | 0.8.7 |
| ext/heroes-tetra-void | 0.8.8 |
| ext/heroes-myth-oath | 0.8.9 |
| ext/kits2-nor | 0.8.10 |
| ext/gear, ext/classes, ext/farmbuild, ext/cleanup | 0.8.11 to 0.8.14, in that order |

## Off limits (the main session is building the Boki system and Merge)
- Do not bind G, C, R or F to anything.
- Do not edit: scripts/match/kin.gd command/recall/faint paths, scripts/kin/kin_merge.gd, scripts/match/kin_companion.gd, anything in scripts/kin/, or the Hunter R/ult input.
- Archetype R abilities are being replaced by Merge: fold loop-critical ults into the kit (rank-3 upgrade, passive trigger or empowered ability), drop flavour ults.

## Hero kits: weapons
A separate task (ext/gear) will move rarity from weapons to gear and formalize signature weapons. Keep each hero's signature weapon defined in its own content file and kit script, so adopting the gear model later is a small change.

## Merge order the main session wants
1) feelfix 2) polish 3) ext/fixes 4) ext/economy 5) ext/heroes-* pairs as each is done 6) rolling 7) ext/gear 8) ext/classes 9) ext/farmbuild 10) ext/cleanup (only after feelfix and the heroes merge).
