# 0041: Stealing Boki wisps

- **Status:** accepted (prototype, behind the boki_wisps setting)
- **Date:** 2026-11-09 (rebuilt on main 2026-11-15)
- **Area:** match flow, networking

## Problem
DECISIONS 2026-11-09 (Stealing): a downed Hunter's Boki wisps break loose and float; anyone grabs one, the owner
too if revived in time; a thief holds 1-2 with each one's carry passive and one summon; dying scatters them; at
match end they go home and the thief keeps a soul echo. WISP_DESIGN_OPEN.md Q6/Q8 recommends the numbers.

## Options
1. Move the Boki into the thief's kin slots. Touches every `h.kin` reader and the save path.
2. Keep the Kin where it is; `home_h` is its own hunter, `owner_h` its carrier. Orbit, leash, hit credit and AI
   follow the carrier for free; the owner's carry passives, Boki key and Summon check `owner_h == self`.

## Decision
Option 2, in `KinSteal`. Numbers in `content/rules/boki_summon.json` "steal": loose 10 s, grab 0.6 s hold within
2 m, carry 2, passives at 50 % clamped at the carry cap, one summon at half the window (min 5 s) when your own Boki
is resting or gone. The wisp pops 2.5 m off its fallen hunter so the grab never fights the stomp/revive prompt.
A thief who goes down (not only dies) scatters: the same moment that frees the owner's wisp. Ungrabbed wisps go
back to their hunter, who keeps them for that down.
Carry-passive stacking (Q8): `Hunter._refresh_kin_stats` sums your own Boki at 100 % and each stolen wisp at
`passive_k` (x its carry_k, like your own), then clamps the one sum per stat at the carry cap (KinParts.OWNER_STATS).
Soul echo (kept from ext/merge-lane-integ-1115): a grab adds to the dex entry's optional `echo` count (seen = true;
Care.dex_mark). Left out: guardian interplay, bots grabbing, extraction bonus, HUD icons (backlog: Wisp line UI).

## Consequences
- Net.VERSION 0.24.15: kin snapshot 28-30 = loose s, carrier id, stolen summon used; kcmd "wgrab"/"wsum" ask the
  Boki's own game.
- match.gd +3 (interact, match end), hunter.gd +2, KinLoss and KinCommand skip a Boki whose wisp is not with its
  own hunter. `--wisp-steal-check` covers it, including the stacking rows.
- HUD: up to two rows above the Boki box (`BokiHud.stolen_wisps`): the critter in its colours inside an ally-blue thief
  ring, its carry passive at `passive_k`, the summon key while ready / "OUT 4s" / "USED". A teammate's squad row wears a
  count badge (`TeamBoki`). It sits on the Boki box's group. `--stolen-hud-check` covers it.
