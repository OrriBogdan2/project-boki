# Crowd control on a summoned Boki

Status: decided 2026-11-11 (job a6). Applies to a Boki out of its wisp (DECISIONS 2026-11-09: damage does not
end a summon, a kill does). Rules data: `content/rules/summon_cc.json`. Code: `SummonCc` (scripts/match/summon_cc.gd),
asked by `KitStatus.apply`. Check: `--summon-cc-check`.

## Source data
The repo's source notes (SUPERVIVE_DATA.md, KIT_PARITY.md, docs/heroes) have nothing on how the source treats
pets or summons under crowd control. So every row below is the closest Hunter rule. If footage of a source summon
under CC turns up, change the row, not the code path.

## No second system
A summoned Boki is an `Ent` like a Hunter. Stun, root, slow and knock go through `Ent.hurt` (diminishing returns,
the stun immunity that follows, recall weakness), Daze and Grounded through `KitStatus.apply`, pulls through
`Displace.tow`, tethers through `Verbs.add_tether`. The only code is one question in `KitStatus.apply`: is this
kind in the summon's `immune` list.

## The rule per kind
| Kind | On a summoned Boki | Why |
|---|---|---|
| Stun | Lands as on a Hunter, with the same diminishing returns and stun immunity. It stops moving and attacking. | Hunter rule. |
| Root | Lands as on a Hunter. It cannot move but still fights from where it stands (Kin.gd already does). | Hunter rule. |
| Slow | Lands as on a Hunter (a slow's own strength, else the Boki's usual 0.6x). | Hunter rule. |
| Daze | Lands. It is only a damage window (Vex hits harder), so it changes nothing else. | Hunter rule; the source's Daze has no movement part. |
| Grounded | **Does not land.** No cords, no toast. | Grounded takes away dash, jump and glide; a Boki has none of the three, so it would be a free, invisible nothing. |
| Knockback | Lands as on a Hunter (`mass()` scales it). It never ends the summon. | Hunter rule. |
| Pull (yank, tow) | Works as on a Hunter. | Hunter rule. |
| Kael's tether | Attaches as on a Hunter; it snaps if the Boki runs out of range, and its stun and yank land as above. | Hunter rule. |

## Around the rules
- The summon window keeps running while the Boki is CC'd. Stopping the clock would make CC a buff for the
  Boki's owner; a stun costs the window what it costs in a fight.
- None of these ends a summon. Damage that kills the Boki does, as already decided.
- A Boki still in its wisp form is not a target, so nothing here applies to it.
- Leash: after a knock or pull past the summon's leash the normal follow brings it back; no extra rule.
- Hunter Wisps (downed) are not summons and keep their own rules.

## Wiring
`SummonCc.summoned(e)` is true for a Kin with the `summoned` meta or whose `summon` (KinSummon, branch
ext/wisp-summon) is out. The branch needs no change: it is read by duck typing. Online, `Net.VERSION` and the save
are untouched; the immunity is applied by the game that owns the body, as for any `kst` event.
