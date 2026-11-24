## Camera shake per hit class against the source (`--shake-check` section 5, 11-23)

Every camera shake is one row of `content/rules/shake.json`; a caller names its class (`Shake.big(m, at, "ult", cause)`),
never a number, and the hit tiers read their `<tier>_hit` row (`ImpactWeight.shake`). Shared by every row (the table's
`door`): it runs 0.15 s, is 0.25 world units at power 1 on top of you at full slider, falls off
linearly to 0 at 14 m, scales with the Screen shake slider (default 30%), never shakes whoever caused it
(or the owner of the Boki that did), and starts at most one shake per `shake_gap_s` (0.5 s) in a team fight.
Amplitude = power x 0.25 at the centre, full slider / the 30% default.

**Source.** The reference data documents no hit-stop, hit flash or screen shake ([gap] in the private reference data
notes), and the 5-10 fps footage shows none that can be measured, so no row has a reference number. Sourced rows are
the zero rows set by an owner rule or by this brief's decision; every other row keeps its value and is marked [?].

| Class | What | Power | Amplitude (full / 30%) | Duration | Falloff | Callers | Before (main dae69e1c59) | Source |
|---|---|---|---|---|---|---|---|---|
| self | anything you (your Boki, your Fuse) cause, on your own camera | 0 | 0 | - | - | none | 0 (asserted) | owner rule (§5.5, item 50): 0 |
| light_hit | a light hit on you (Feel, ImpactWeight light) | 0 | 0 | - | - | none | 0 | owner rule (§5.5, item 50): 0 |
| solid_hit | a solid hit on you (Feel, ImpactWeight solid) | 0 | 0 | - | - | none | 0 | owner rule (§5.5, item 50): 0 |
| heavy_hit | a heavy hit on you: an ult, a slam, a payoff (Feel, ImpactWeight heavy) | 0.6 | 0.1500 / 0.0450 | 0.15 s | linear to 0 at 14 m | none | 0.6 | [?] |
| knock | a knock (yours or on you): sound, feed and icon, no shake | 0 | 0 | - | - | none | no call | [?] |
| dash | a dash or blink, anyone's | 0 | 0 | - | - | none | 0 (asserted) | brief decision 11-23: 0 |
| hard_land | a landing from a height, anyone's | 0 | 0 | - | - | none | 0 (asserted) | brief decision 11-23: 0 |
| landing_strike | a landing attack's shock on bystanders (the Meteor Drop, Dredge's air smash, a Boki's landing strike); the struck still take their hit's tier | 0 | 0 | - | - | none | Meteor Drop 0.35, Dredge air smash 0.6, Boki landing strike 0.3 | brief decision 11-23: 0 |
| area_slam | an area ability landing that does not explode (a slam, a Fusion gust or wave; AbilityFx.land) | 0 | 0 | - | - | none | 0.5 (an enemy area 3 m+) | brief decision 11-23: 0 |
| ult | an enemy Hunter's ult going off near you | 0.6 | 0.1500 / 0.0450 | 0.15 s | linear to 0 at 14 m | `arch_kit.gd`, `bjorn_ult.gd`, `gunslinger_ult.gd`, `juggernaut_ult.gd`, `mage_ult.gd`, `merge_kit.gd` | 0.6 (Thunderhead as a 0.6 literal) | [?] |
| fuse | an enemy Fuse taking form near you (offline and online alike) | 0.7 | 0.1750 / 0.0525 | 0.15 s | linear to 0 at 14 m | `merge_xform.gd` | 0.7 (0.4 for a remote player's Fuse) | [?] |
| fuse_shell_break | a fused enemy's shell breaking near you | 0.5 | 0.1250 / 0.0375 | 0.15 s | linear to 0 at 14 m | `merge_xform.gd` | 0.5 | [?] |
| explosion | a real blast near you: a Rimewright detonation, a Boki's big boom burst, a falling meteor | 0.35 | 0.0875 / 0.0262 | 0.15 s | linear to 0 at 14 m | `rimewright_kit.gd`, `kin_exec.gd`, `match.gd` | Rimewright detonation 0.6, Boki boom burst 0.3, meteor 0.35 | [?] |
| boss_slam | a boss ground blast under 3 m | 0.35 | 0.0875 / 0.0262 | 0.15 s | linear to 0 at 14 m | `boss.gd` | 0.35 | [?] |
| boss_slam_wide | a boss ground blast of 3 m or more | 0.55 | 0.1375 / 0.0413 | 0.15 s | linear to 0 at 14 m | `boss.gd` | 0.55 | [?] |
| boss_fissure | a boss fissure line erupting | 0.5 | 0.1250 / 0.0375 | 0.15 s | linear to 0 at 14 m | `boss.gd` | 0.5 | [?] |
| boss_phase | a boss entering its next phase | 0.7 | 0.1750 / 0.0525 | 0.15 s | linear to 0 at 14 m | `boss.gd` | 0.7 | [?] |
| boss_wake | a lair boss waking | 0.6 | 0.1500 / 0.0450 | 0.15 s | linear to 0 at 14 m | `lairs_fight.gd` | 0.6 | [?] |
| lair_crack | a lair seal cracking, stronger per stage | 0.2 + 0.1/stage | 0.0500 / 0.0150 | 0.15 s | linear to 0 at 14 m | `lair_breach.gd` | 0.2 + 0.1 per stage | [?] |
| lair_break | a lair seal giving way | 0.6 | 0.1500 / 0.0450 | 0.15 s | linear to 0 at 14 m | `lair_breach.gd` | 0.6 | [?] |
| train_hit | the train striking someone near you | 0.9 | 0.2250 / 0.0675 | 0.15 s | linear to 0 at 14 m | `match.gd` | 0.9 | [?] |

Changed by the decision (explosions only for things that truly explode, nothing on dashes and landings):
- Landing attacks no longer shake bystanders: the Meteor Drop (0.35), Dredge's air smash (heavy 0.6) and a Boki's
  landing strike (0.3). A player struck by one still gets their hit's tier (a heavy hit shakes 0.6).
- An area ability landing (`AbilityFx.land`, 0.5 for an enemy area of 3 m or more: Earthshatter, the Fusion forms'
  gusts, waves and slams) no longer shakes: none of them explode. Their hits keep their tier.
- The explosion row is one value (0.35) for the three real blasts: the Rimewright detonation (was the heavy 0.6), a Boki's
  big boom burst (was 0.3) and a falling meteor (0.35).
- A Fuse taking form shakes the same 0.7 offline and online (a remote player's was 0.4).

Left for the owner: every [?] value (no reference number). Alternatives not taken: keeping ult impacts that are a leap
landing (none today: Faultline is a planted slam) under hard_land; counting `AbilityFx.land` areas as explosions.
`--shake-check` 5a-5c assert the rows (src, power, the 0 rows have no caller), every `Shake` call in `scripts/` (a table
class from a file its row lists; only Feel uses the power door) and each row firing at its power, duration and falloff.
