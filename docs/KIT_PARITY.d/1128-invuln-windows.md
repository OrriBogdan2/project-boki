## Invulnerability windows (reference pass 11-28, ext/kit-invuln-windows)

Reference: the 11-27 catalog's cross-hunter pattern 12 ("invulnerability / projectile immunity on dashes and ults:
0.65 s, 1.6 s, 3.5 s") and each hero section. Ours: measured in game by `--invuln-window-check`, frame by frame from
the press (melee-proof = `inv_t` or Kael's guard; shot-proof adds `phase_t`, which real shots fly through). The check
then hits each Hunter with one melee hit and one real shot in the middle of the window (both refused) and 0.1 s after
it (both land); a row with no window must take both hits mid-move. Gil is ours and not audited.

| Hunter | Move | Reference | Ours (measured) | Verdict |
|---|---|---|---|---|
| Vex | Slipstep | none listed | 0.12 s, all hits | ours; source silent [?] |
| Kael | Rampage | none listed | 0.07 s (from 0.07 s), all hits | ours [?] |
| Kael | R Gilded Riposte | invulnerable 0.65 s, then the strike | guard 0.65 s (`x.guard`), all hits; the strike and recovery take hits | match |
| Lace | Spirit Walk roll | none listed | 0.28 s, all hits (the footage's roll) | ours [?] |
| Cinder | dash hop | none listed | 0.07 s, all hits | ours [?] |
| Meeko | Foxtrot | none listed | 0.13 s, all hits | ours [?] |
| Tenzo | hop chain | none listed | 0.08 s on hop 1, all hits | ours [?] |
| Grimble | Barge | none listed | 0.07 s, all hits | ours [?] |
| Neve | Free Skate | none listed | none | match |
| Neve | R Rimelock | invulnerable, zone up to 3.5 s | sealed 3.38 s (`x.hold` 3.3 + the snap), all hits | kept: the hold is the footage's 3.2-3.4 s (docs/heroes/rimewright.md); "up to 3.5" is the cap [?] |
| Motley | dash | none listed (ground-hazard immunity only, not a hit window) | none | match |
| Albert | Tideturner | none listed | 0.12 s, all hits | ours [?] |
| Albert | Shield Charge (shield up + Shift) | "briefly invulnerable", no length | 0.35 s, all hits | match in shape; no length to match [?] |
| Sparkle | Surge (Wirerun run) | projectile-immune; less damage and knock taken while dashing (no number) | shots pass 0.48 s; melee-proof 0.23 s (the run) | shots match; melee: ours refuses it where the source only reduces it, no number [?] |
| Sparkle | R Kitefall | projectile-immune in the air | 2.35 s in the air, all hits; the 0.3 s crouch is open | shots match; melee: docs/heroes/mage.md has the source's invulnerable tag [?] |
| Sable | Vault | none listed | melee-proof 0.52 s, shots 0.58 s | ours [?] |

**Fixed:** nothing. No row is a plain mismatch with a number on both sides: Kael's 0.65 s already matches, Neve's
3.3 s hold is footage-measured, and the Shield Charge and Surge rows have no source length. No window was added and
none of ours was removed (the source not listing one is not a "none").

**The 1.6 s in pattern 12:** no hero section gives a 1.6 s invulnerable or projectile-immune window. The only 1.6 s
figures are Neve's skate length and Vex's ult delay, neither a hit window. [?]

**Open, needs a rule rather than a data row:** Sparkle's Surge taking melee at reduced damage (the source has no
percentage). Left as is.
