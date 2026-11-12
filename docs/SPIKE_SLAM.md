# Spike / slam: how the reference does it, and our version

Owner order 11-10: look up how spiking/slamming works in the reference game and give it to the right abilities;
Kael's RMB is a dive and must not slam. We take the mechanic only: our own names, numbers, text and look.

## 1. What the reference does (research, 2026-11-10)

Two separate things share the "knocked out of the sky" idea:

- **Glider spike.** A gliding player whose glider is overheated (or who takes enough damage while gliding to
  reach overheat) and then takes damage from another player is spiked: killed outright over the abyss,
  stunned over land. Monsters drain the glider but don't spike. Some attacks fill the heat at once. We already
  have this (`Hunter.hurt`, glider heat; docs/EXPEDITION_SPEC.md, docs/SUPERVIVE_DATA.md: 0.7s landing stun).
- **Dunk (slam).** A few abilities "stun and propel victims downward"; over the abyss they act like a spike.
  The wiki lists four, out of the whole roster: an ultimate, a fist slam ahead of the caster, a downward
  sword blow after a flip, and the greatsword hero's airborne strike. The sword blow's text: struck enemies
  are slammed downward and briefly Grounded; over the abyss also briefly stunned. A dunk's stun and its
  downward force scale with the target's missing health (docs/SUPERVIVE_DATA.md, 0.35-1.0s).
- **Grounded**: cannot use movement abilities (dash, and anything flagged as movement).
- **What never dunks**: basic attacks, dashes and other movement abilities, projectiles. Dunks are a short,
  deliberate list of heavy downward strikes, each on a cooldown with a readable wind-up or hook first.
- **Counterplay**: dodge the wind-up (the fist and the hook have a beat before the stun), glide high or over
  ground rather than the abyss, keep heat low so only a real dunk can bring you down.
- Not found in any source: an explicit immunity window after a dunk. We add none beyond "one landing stun per
  fall" (the landing clears it).

Note: the reference's greatsword hero *does* slam with his airborne strike. Our Kael is our own, and the owner
ruled his Meteor Drop a dive that must not slam; we apply that rule to every dive and leap.

Sources: [wiki glossary (Spike, Dunk, Grounded)](https://supervive.wiki.gg/wiki/Glossary),
[wiki: the duelist hero (Death Blow)](https://supervive.wiki.gg/wiki/Jin),
[wiki: the greatsword hero](https://supervive.wiki.gg/wiki/Brall),
[PCGamesN: the brawler reveal (slam on gliders)](https://www.pcgamesn.com/supervive/kingpin-reveal),
[Deltia's gliding guide](https://deltiasgaming.com/?p=298691), and our own docs/SUPERVIVE_DATA.md.

## 2. Our design

One path: the glider spike, `scripts/match/glide_spike.gd` (`GlideSpike`, decision 0022). Every downward
strike drives its foe through `Displace.spike(f, vy, by)`, which reaches the game that owns the body and spikes
a glider driven down at `slam_min` (10 m/s) or more: glider folded, plunge, the 0.7s landing stun and 8 fall
damage (`content/rules/hunter_move.json` "glide_spike").

An ability spikes a foe in the air, gliding or not, when its archetype data carries a `spike` block and its
code passes that block for the move that strikes down; dives, leaps and dashes pass `{}`:

| Field | Meaning | Tenzo tap Quakefall | Grimble ground Anchor Drop |
|---|---|---|---|
| `bonus` | extra damage share on a foe in the air | 0.4 (+40%) | none (it already stuns and Grounds) |
| `vy` | m/s down, through `Displace.spike` (10 or more spikes a glider) | 22 | 16 |

`GlideSpike.dunks(f, spike)` is the test: the block is set and the foe is off its feet and gliding, or more
than 0.35m up (`GlideSpike.AIR_GAP`). The caller adds the bonus, keeps the hit from lifting, and drives the
foe down after the hit. A hunter's fall cap (`HunterMove.fall_max`, 12 m/s) still applies on its next tick.

What we change from the reference: no missing-health scaling (one fixed fall and stun reads better at our
sizes); dives and leaps never spike through a `spike` block; no extra damage over the abyss (the fall takes
them); the stat "spikes" counts only gliders brought down, as the "Spike!" goal says.

Rule for which abilities carry a block: **a strike that comes down onto someone, from a caster who stays put.**
If the caster's own body travels to the hit (dash, leap, hop, dive), it does not.

## 3. Every hunter ability

| Hunter | Ability | Spike | Why |
|---|---|---|---|
| Kael | LMB greatsword combo | no | basic attack |
| Kael | RMB tap Finishing Slam | no | a level cleave ahead, not a downward strike |
| Kael | RMB hold Lunge | no | a dash |
| Kael | RMB air Meteor Drop | **no** block | a dive; its own landing still knocks everyone down and drives the airborne down through `Displace.spike` (owner 11-10 down slam, `juggernaut_drop.gd`), unchanged; `--juggernaut-combo-check` |
| Kael | RMB with E: Cinder Spin / Haul Slam / Chain Lunge | no | spin, and arrivals by chain (movement) |
| Kael | E Warchain, X Gilded Riposte, Shift Rampage | no | hook, upward cleave, dash |
| Tenzo | RMB tap Quakefall (instant slam ahead) | **yes**, +40% | fists brought down in front, caster planted |
| Tenzo | RMB hold Quakefall (hop) / air (dive) | no | a leap / a dive (both spiked before; removed) |
| Tenzo | E Stone Row, X Basalt Spine, Shift Rock Hop | no | walls and ridges rise up; a hop |
| Grimble | E Anchor Drop on the ground | **yes**, +0% (it already stuns and Grounds) | a fist slammed down into the cone |
| Grimble | E Anchor Drop in the air (dive) | no | a dive (spiked before; removed) |
| Grimble | RMB Abyssal Hand, X Brass Broadside, Shift Barge | no | hook, projectiles, dash |
| Albert | RMB Aegis / Shield Charge / Shield Slam, Shift 360 Smash | no | horizontal shoves and dashes |
| Albert | X Faultline | no | the ground erupts upward (a knock-up setter, not a spike) |
| Sparkle | E Skycall | no (candidate) | lightning from above, but it slides foes along the ground; a spike would fight that tow |
| Sparkle | RMB Storm Rod, X Kitefall, Shift Wirerun | no | projectile; Kitefall is a dive |
| Vex | RMB Burr Charge, E Longneedle, X Cinderfall, Shift Slipstep | no | projectiles and a shell zone; dash |
| Cinder | RMB Cinder Shot, E Furnace Cloak, X Flue Flight, Shift Soot Ram | no | projectile, burst, flight, dash |
| Lace | RMB Heavy Shot, E Hail Wall, X Starpiercer, Shift Spirit Walk | no | arrows, a zone, a dash |
| Neve | RMB Ice Spear, E Rink Wall, X Rimelock, Shift Skate | no | projectile, wall, shell, movement |
| Meeko | RMB Burrseed, E Hearthlight, X Hearth Call, Shift Relay Step | no | support kit |
| Motley | RMB Shard Snap, E Brimseed, X Nightwell, Shift Lantern Trade | no | projectiles, a pulling dome, a swap |
| Sable | RMB Bola (ground or air), E Shadow Knife, X Encore, Shift Vault | no | projectiles, a vault |
| all | LMB basic attacks | no | the glider-heat spike covers them |

Outside the hunter kits, two older spikes keep their own airborne test and numbers (not ported here, see
docs/DEBT.md): the `spike` effect on area hits in `scripts/combat/effects.gd` (the legacy greatsword weapon
utility Earthshatter, a leap slam, kept as it was, owner call) and the Boki `spike` modifier
(`scripts/kin/parts.gd`, Boulder Heave and Gravity Slam, `KinExec.apply_foe`).

## 4. Checks

- `--dolm-combo-check`: the tap slam drives a foe 2m up down at 22 m/s for +40% (yes row); the dive landing
  on the same foe does not spike it (no row).
- `--dredge-combo-check`: the ground Anchor Drop drives a foe held 1.2m up down at once (yes row).
- `--juggernaut-combo-check`: Meteor Drop unchanged.
