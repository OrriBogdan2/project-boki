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

One path: `scripts/combat/spike.gd` (`Spike`). An ability spikes when its data carries a `spike` block
(`{"bonus": extra damage share, "stun": optional s on the hit}`) and its code passes that block for the move
that strikes down. A foe hit while **in the air** (off its feet and gliding, or more than 0.35m up):

| Part | Value | Why |
|---|---|---|
| Damage | +`bonus` (Tenzo 40%, Grimble 0%) | the payoff for catching someone in the air |
| Fall | at least 20 m/s down (`Spike.FALL_VY`), glider folded | a 2.5m glide is on the ground in ~0.2s |
| Grounded | 0.8s: no dash, jump or glide | no air-dash or re-glide out of it (the reference's Grounded) |
| Landing | the glider spike's landing: 0.7s stun, 8 fall damage, dust and ring (`Hunter.SPIKE_STUN`) | one landing for every spike |
| Abyss | no extra rule: over the void the fall takes them | the reference's "lethal over the abyss" |
| Feedback | tier-4 hit stop (`Feel`, already budgeted), a thin pale downward streak, a small SPIKED word, a low knock | kept quiet (owner: less in your face) |

What we change from the reference: no missing-health scaling (one fixed fall and stun reads better at our
sizes); dives and leaps never spike, even the airborne greatsword strike; the stat "spikes" counts only
gliders brought down, as the "Spike!" goal says.

Rule for which abilities spike: **a strike that comes down onto someone, from a caster who stays put.** If the
caster's own body travels to the hit (dash, leap, hop, dive), it does not spike.

## 3. Every hunter ability

| Hunter | Ability | Spike | Why |
|---|---|---|---|
| Kael | LMB greatsword combo | no | basic attack |
| Kael | RMB tap Finishing Slam | no | a level cleave ahead, not a downward strike |
| Kael | RMB hold Lunge | no | a dash |
| Kael | RMB air Meteor Drop | **no** | a dive (owner 11-10); checked by `--spike-check` |
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

Outside the hunter kits, already spiking and now on the same path: the legacy greatsword weapon utility
Earthshatter (`content/abilities/earthshatter.json`, a leap slam; kept as it was, owner call) and the Boki
`spike` modifier (`scripts/kin/parts.gd`, Boulder Heave and Gravity Slam).

## 4. Checks

`--spike-check` (tools/spike_check.gd): a gliding dummy hit by each spike ability is driven down (vy -20),
lands within 0.6s and is stunned by the landing; the dives (Kael's Meteor Drop, Tenzo's hop/dive landing,
Grimble's air Anchor) hit the same dummy and don't spike it.
