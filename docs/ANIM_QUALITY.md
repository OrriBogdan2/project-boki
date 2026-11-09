# Knock and elimination animation (audit)

Rule (briefs/DECISIONS.md 2026-11-07): match the source's weight and timing; poses come from our own characters.
Decision 0019: a knocked Hunter falls, then becomes a Wisp; an eliminated Hunter's body goes.

## What we found (ext/anim-knockdown)

- Every Hunter has all of `hit_f`/`hit_b` (Ostra: `hit`), `death`, `downed`, `revive` in its GLB and in
  `content/rules/warden_anim/<art>.json` (`states`). Nothing was missing, so no clip needed authoring through
  `tools/art1`.
- The fall that `ext/anim-downed` added played `hit_f` over 0.35 s. That clip is a flinch: the head dropped
  about 0.1 m (7%) before the Wisp, so the knock had no weight (strip: `docs/art/anim_knockdown/before_*.jpg`).
- A Wisp that bled out or was executed made the hero reappear and play a fresh `death` clip for 1.3-1.6 s (the body
  "came back" after the Wisp broke).
- Source fall time: `briefs/hero-ref` has no timing for the fall (the footage notes cover the callout and the Wisp, not
  the fall), so there is no measured number. We use the owner's 0.3-0.6 s window, set at 0.5 s.

## What changed

- The fall plays the collapse of the Hunter's own `death` clip (first 75% of it, `WardenClips.FALL_OF_DEATH`;
  `states.fall_of_death` overrides per Hunter, Breaker uses 1.0) over `pop_in.time` = 0.5 s. The rise on revive
  plays it backwards over 0.3 s.
- Handover: blends into the fall clip over 0.05 s (`FALL_FADE`, a hit should be quick); the Wisp fades in over the last
  0.15 s (`pop_in.fade`) while the body is still on screen, then the hero hides under the opaque Wisp, so nothing snaps.
- Elimination: straight from standing, the `death` clip plays for `dead_t` s and the body goes (unchanged). From a Wisp
  (`HunterWisp.SNUFFED`), the Wisp breaks into sparks and no body comes back.

## Per Hunter

| Hunter (art) | Hero | `death` s | `hit_f` s | Fall plays | Head, standing -> at 0.4 s | Drop |
|---|---|---|---|---|---|---|
| Breaker | bulwark | 1.3 | 0.37 | 100% of death | 2.20 -> 1.56 m | 29% |
| Hem | archer | 1.5 | 0.43 | 75% of death | 1.42 -> 0.23 m | 84% |
| Kael | juggernaut | 1.5 | 0.43 | 75% of death | 1.72 -> 0.24 m | 86% |
| Vex | gunslinger | 1.5 | 0.43 | 75% of death | 1.44 -> 0.67 m | 53% |
| Ryzz | mage | 1.5 | 0.43 | 75% of death | 1.34 -> 0.56 m | 58% |
| Tarek | dolm | 1.6 | 0.4 | 75% of death | 1.51 -> 0.81 m | 46% |
| Sable | thief | 1.5 | 0.43 | 75% of death | 1.55 -> 0.41 m | 74% |
| Claire | rimewright | 1.5 | 0.43 | 75% of death | 1.45 -> 0.40 m | 72% |
| Cinder | ashwick | 1.5 | 0.43 | 75% of death | 1.52 -> 0.59 m | 61% |
| Pip | tender | 1.5 | 0.43 | 75% of death | 0.72 -> 0.10 m | 86% |
| Dredge | dredge | 1.5 | 0.43 | 75% of death | 1.45 -> 0.93 m | 36% |
| Ostra | ostra | 1.6 | 0.35 | 75% of death | 1.58 -> 1.09 m | 31% |

The head is the head bone's height above the feet in the live match (`--knock-fall-shots`); the old `hit_f` fall
moved it 0.03-0.1 m. Every row blends in over 0.05 s and fades the Wisp in over the last 0.15 s of a 0.5 s fall.
Breaker kneels (his own death ends at about -30%); Dredge, Ostra and Dolm settle on all fours or sit, so their drop
is smaller. Per-Hunter retiming is not needed: all 12 read inside the window.

## Proof

- `--downed-anim-check` (all 12 Heroes plus a remote: fall 0.3-0.6 s, head drops at least 25%, Wisp fades in last,
  bleed-out leaves no body), `--wisp-check`, `--clip-check`, `--warden-clips-check`.
- Strips (4 Hunters: Hem, Breaker, Sable, Ryzz; columns 0, 0.1, 0.2, 0.3, 0.4, 0.55 s after the knock):
  `docs/art/anim_knockdown/before_hem_breaker_sable_ryzz.jpg` (hit clip) and `after_hem_breaker_sable_ryzz.jpg` (death
  collapse). Make more with `--knock-fall-shots --heroes=a,b,c,d --shots-dir=<dir>` (`--clip=`, `--elim=`).
  The big orb in the first column is not the Hunter Wisp (it shows before the knock lands); not investigated.
- Ideas not built: a short ground-thud sound and dust puff when the body lands; a per-Hunter fall length.
