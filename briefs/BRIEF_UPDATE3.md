# Brief update 3 (from the main session, Nov 1 evening). Applies to every agent on both machines.

## Main is now sync57 (e85193d): the Boki system has shipped
G throw/recall/hold, C Boki ability, downed Boki rescue and Merge on R are on main. Net.VERSION on main is **0.9.0**.

- Re-fetch origin/main and merge sync57 into your branch before your final checks.
- Class R code is now behind a `class_ults` flag (off). Don't build or extend class R abilities; ext/cleanup deletes that code after the hero ports land. Fold loop-critical ults into kits as before (BRIEF_HEROES_UPDATE1 §1).

## Main-session files (off limits, in addition to the BRIEF_UPDATE2 list)
kin_command.gd, kin_downed.gd, kin_strike.gd, kin_net.gd, merge_look.gd, merge_form.gd, boki_hud.gd, bot_kin.gd.
Keys G, C, R and F stay reserved. If your work needs a hook into the Boki system, call its public functions from your own files; if a hook is missing, list it in your report instead of editing those files.

## Net versions (replace BRIEF_UPDATE2's table)
Bump above main's 0.9.0 only if your branch changes the sync shape; report the number. The integrator reconciles.

| Branch | Net version |
|---|---|
| ext/fixes | 0.9.1 |
| ext/economy | 0.9.2 |
| rolling | 0.9.3 |
| feelfix | 0.9.4 |
| ext/heroes-joule-ghost | 0.9.5 |
| ext/heroes-elluna-celeste | 0.9.6 |
| ext/heroes-kingpin-felix | 0.9.7 |
| ext/heroes-tetra-void | 0.9.8 |
| ext/heroes-myth-oath | 0.9.9 |
| ext/kits2-nor | 0.9.10 |
| ext/gear, ext/classes, ext/farmbuild, ext/cleanup | 0.9.11 to 0.9.14, in that order |

## Economy / follower Boki
ext/economy must adapt its follower Boki to the shipped Boki system (command, downed, net, bot_kin) rather than run a parallel system. Reuse the shipped downed/rescue behaviour for followers.
