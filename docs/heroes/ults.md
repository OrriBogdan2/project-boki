# Hunter ultimates (R): cast lock against the source

Parity audit of 2026-11-09 (job ext/ult-lock-parity). "Lock" is the time the caster cannot walk, turn, dash, glide or use other abilities. Source = the footage sheets (`briefs/hero-ref/*.md`, "Ultimate (on X)") and `briefs/supervive-data/supervive_kits.md`. Ours = the kit data and code (`content/archetypes/<id>.json` `x`, `scripts/arch/kits/`). Owner rules are kept as they are.

| Hunter (source) | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|
| Lace (Myth, Primal Forces) | Self buff, no cast lock; walks between shots, 1.5 s per shot | No lock. Walks between shots (`move_k` above 0.9); nock 0.5 s + recover 1.0 s per shot | match (owner: no cast lock) | pin.md Ultimate 1, 4; `pin_bjorn_ult_check` "she can move between shots" |
| Cinder (Felix, Jetpack) | Instant lift-off, flies the full time, no landing lock | No lock; flies 1.8 s (owner item 20: a bit longer); only E works in flight, X lands, a jump leaves it | match (owner: only E). Card text was stale: fixed | linwick.md Ultimate 1, 4; `ashwick_ult_check` "ult 66" rows |
| Albert (Oath, Earthshatter) | Planted for wind-up and slam, about 0.6 to 0.7 s, then free | Planted 0.4 s wind-up + 0.2 s slam = 0.6 s (`move_k` 0), then free while it runs | match | bjorn.md Ultimate 4; `pin_bjorn_ult_check` "bjorn ult cast: planted" |
| Tenzo (Tetra, Tetraform) | Tap or hold-drag; moves while aiming; cast is instant | No lock; walks while aiming (3 s cap); rocks rise after a 0.2 s tell | match | breah.md Ultimate 1; `breah_ult_check` |
| Grimble (Kingpin, Kaiju Blast) | Planted 1.1 s charge, waves 0.6 s apart, about 2.1 s in all | Walks at 30% in the charge and 20% while firing (owner item 36), no gun or other ability until it ends | differs on purpose (owner item 36) | dredge.md Ultimate 1; `dredge_ult_check` "walks slowly through the charge" |
| Vex (Ghost, Mini Nuke) | Tap, keeps walking and jumping; 1.6 s to impact | No lock; moves and shoots while it falls; 1.6 s delay | match | venator.md Ultimate 1; `vv_ult_check` "Vex moves and can shoot while it falls" |
| Kael (Brall, Retaliation) | Planted 0.65 s guard, strike, recovered by about 1.1 s | Planted 0.65 s guard + 0.1 s strike, then 0.35 s recovery at 50% speed; a jump or Shift leaves the recovery | match; the recovery walk is not in the footage (unknown) | juggernaut.md Ultimate 2, 4; `dj_ult_check` |
| Sparkle (Joule, Eye of the Storm) | 0.3 s crouch, about 1.4 s airborne and invulnerable, free at once on landing | 0.3 s crouch, rise 0.3 s, hover up to 1.7 s, 0.2 s drop; `busy` until the strike, free in the 0.5 s after | match | vireo.md Ultimate 4; `vv_ult_check` "free again at once" |
| Motley (Void, Black Hole) | 1.0 s dome telegraph, then free to act while the vortex runs | 1.0 s lock (no move, no turn after 0.25 s, nothing else), then free; a stun or knock frees him | match (owner: about 1 s then free) | ostra.md Ultimate 4; `ostra_ult_check` "lock:" rows |
| Neve (Celeste, Ice Crash) | Invulnerable in a star crystal for about 3.3 s (3.2-3.4 s per cast), zone stays on her, recast ends early | Frost statue, invulnerable and rooted, 3.3 s (footage read 3.2-3.4 s per cast, rimewright.md "Rimelock length"); recast or Shift breaks out | match (owner: Rimelock ends on Shift) | tamsin.md Ultimate 1, 4; `care_ult_check`; `kit_parity_check` `x.hold` |
| Meeko (Elluna, Divine Intervention) | 5 s channel on an ally; she walks normally | No lock; walks and casts for 5 s; X again is swallowed | match | mooshmoosh.md Ultimate 1, 2; `care_ult_check` "she walks while it channels" |
| Sable (Shiv, Death Blossom) | 0.4 s ring grow, then 2 s of blades; moves, shoots and dashes freely | No lock; ring rides with her, free to move, shoot and dash | match; ring, cadence and damage measured in thief.md "Death Blossom: source vs ours" | thief.md Ultimate; `dj_ult_check` "she walks and fires freely", `dancer_ring` rows |

## Fixed
- Cinder: the card text (`ashwick.json` `x.desc`) still said the Cinder Shot works in the flight and Shift speeds it up. The kit, the hero sheet and the owner rule (Nov 5, item 66) say only the Furnace Cloak works. Text changed; asserted in the Cinder combo check. The hero sheet's cooldown cell said 32 s against the data's 36 s: fixed too.

## Left as they are
- Grimble's slow walk through the charge (owner item 36).
- Kael's recovery walk, Sparkle's stillness in the air, Neve's roots: the footage does not show them, so no source to match.

## Suggestions (ours, not built)
- Grimble: a short full-stop in the first part of the charge would match the footage, if the owner wants the source over item 36.

## R pose against the lock (job ext/anim-ult-lock-poses, 2026-11-11)
`--ult-pose-check` casts every Hunter's R with the walk key held and reads the clips (`content/rules/warden_anim/<art>.json`): the lock it measures must match the table above; while it lasts the R move owns the body (or the upper body, for Grimble's slowed walk) with no bare walk cycle; once it is over, a walking Hunter's legs are on the walk within 0.2 s. All twelve commit for the whole lock. Seven held a full-body clip over a free walk; they now take `"upper": "moving"` (the full clip while standing, the legs back on the walk the moment he moves):

| Hunter | Move | Lock ends | Full-body pose held to (before) |
|---|---|---|---|
| Albert | `bul_ult_slam` | 0.6 s | 1.1 s |
| Neve | `tm_rime_crash` | 3.5 s | 4.0 s |
| Sparkle | `mage_x_land` | 2.5 s | 3.1 s |
| Motley | `ostra_well_snap` | 1.0 s | 1.6 s |
| Cinder | `lw_land` | no lock | 0.45 s after the landing |
| Tenzo | `breah_spine` | no lock | 1.1 s |
| Sable | `thf_encore` | no lock | 0.4 s |

Also fixed: a kit move the kit ended early (`play("")`: Sable's dance, Grimble's blast, Kael's recovery left by a jump, Cinder's flight dropped by a merge) stayed in the hunter's anim state at its last time, freezing the pose until the next move; `Hunter._anim_state` now writes the move every frame.
Kael's riposte is full-body through the half-speed recovery and lets go with it at 1.1 s, as the footage recovers by about 1.1 s.
