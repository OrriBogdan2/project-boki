# 0041: Stealing Boki wisps

- **Status:** accepted (prototype, behind the boki_wisps setting)
- **Date:** 2026-11-09
- **Area:** match flow, networking, save (Field Book field)

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
back to their hunter, who keeps them for that down. Soul echo: the dex entry's optional `echo` count (seen = true);
no save migration (an old entry without it is 0). Left out: bots grabbing, echo hatch odds, extraction bonus, HUD
icons (ext/ui-boki-box-summon, ext/vfx-stolen-wisps).

## The break-loose rule (T3, owner leaning of 2026-11-09)
A wisp breaks loose only from a hunter who is downed or dead (`KinSteal.can_break`); otherwise it stays linked.
- **Killed summon:** its hunter up, the wisp folds where the Boki fell and flies home at 25 m/s (`home_mps`), showing
  the hunter through walls for 2 s (`home_reveal_s`, Hunter.reveal_t); cooldown x1.25 (`knocked_cd_mult`). Its
  hunter downed or dead, it breaks loose where it fell. A stolen Boki's thief counts as its hunter here.
- **Guardian x steal:** while `KinGuardian.protecting(h)`, nothing riding with h can break loose or be stolen: the
  stolen wisps a downed thief carries stay linked until their own guardian is beaten or its window ends. A Boki
  whose wisp is loose or stolen never comes out as a guardian (`KinGuardian.on_down`).
- Alternatives: (b) a killed summon is always stealable (punishes a summon misplay with a loss; rejected by the
  owner leaning); a guardian that also shields the wisps after it ends (too strong in duos, WISP_DESIGN_OPEN Q4).

## Consequences
- Net.VERSION 0.31.0 (ext/soul-link-integ, with the wisp, summon and guardian fields): kin snapshot 29-31 = loose s,
  carrier id, stolen summon used (KinNet.STEAL_AT; 28 is 0040's guardian flag); kcmd "wgrab"/"wsum" ask the Boki's
  own game. Net.VERSION 0.31.1: kin snapshot 32 = the homing flag (KinNet.HOME_AT, a killed summon's wisp flying home).
- With 0040: a down with the summon ready brings the guardian out (no loose wisp); with it resting the wisp breaks
  loose (KinGuardian.on_down runs first; KinSteal.ride only takes a wisp at the shoulder).
- Numbering: ext/combat-summon-band also wrote a 0041; it landed as 0042-summon-band.md (T2).
- match.gd +3 (interact, match end), hunter.gd +2. `--wisp-steal-check` covers it; `--wisp-check` the flight home,
  `--wisp-guardian-check` the guardian x steal rule.
- HUD (ext/ui-stolen-wisps): up to two rows above the Boki box (`BokiHud.stolen_wisps`): the critter in its colours inside
  an ally-blue thief ring, its carry passive at `passive_k`, the summon key while ready / "OUT 4s" / "USED". A teammate's
  squad row wears a count badge (`TeamBoki`). It sits on the Boki box's group, so the HUD stays at five groups.
  `--stolen-hud-check` covers it.
