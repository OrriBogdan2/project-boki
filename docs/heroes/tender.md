# Linnet, the Tender (`tender`, medium support)

Internal design doc. Source behaviour reference: SUPERVIVE's Elluna (gameplay only; nothing of her names, look or text is used in the game).

## Research summary
Sources: supervive.wiki.gg/wiki/Elluna (ability and upgrade tables); Deltia's Gaming "Supervive: Elluna Abilities Guide" and a Dot Esports note on skill priority (Q first); a patch-note search found no Elluna-specific changes newer than the wiki page, so the wiki's current kit is the version built.
Disagreements: none material. The wiki lists no E (her heal is on Q, her ult is R); we map Q to our E because Q is the glove slot here. The guides stress Q first, matching our `order`.

## Our kit
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive Bearer | run into a downed teammate | Carry up to 2 downed teammates (never one a rival stands on); a 40 (+6/level) shield refills on pickup; they don't bleed or get stomped; you move 30% slower; interact sets them down; shield break, stun, root or hex drops them, stuns you 0.6s and locks pickup 4s | Soulpack | Shield scaled to our 145 HP; carried teammates ride at your back; online squadmates get a "carry" event so their own game follows you |
| LMB Lantern Crook | hold | Ember every 0.4s, 9m, 8 dmg. Hits Kindle (max 5, 4s): +1 damage per stack on embers, and an ember into a Kindled foe winds Hearthlight back 0.2s. After 1s without firing the next ember flies 40% further and winds back 0.4s | Crescent Bolt + Moon Burn, empowered shot | Mana return becomes cooldown wind-back (no mana in this game) |
| RMB Burrseed | tap | Slow seed, sticks to the first foe (9), 2s later bursts: 35 dmg and a 1.1s root in 2.2m, Kindles all | Darkside Binding | Numbers scaled; rank 3 +0.3s root; bots use it from mid range |
| Shift Relay Step | tap (air: long dash) | 4.2m hop; passing through a teammate refunds half a dash and winds Hearthlight back 1s. Rank 3: picking up a teammate refreshes the air dash | Lunar Dash | Same |
| E Hearthlight | tap, tap again to toss | Ring of light (3.5m, 2.5s) heals teammates 10 over its life then flares for 22; self at a third; a downed teammate's bleed bar five times over. Press again: toss up to 9m, +50% healing for 1s (2s at rank 3), latches onto the first teammate it passes (or onto the one you carry). A stun on you puts it out. Rank 3: the flare stands a downed teammate in the ring back up | Moonlight Blessing | See R decision |
| R | none | Removed per owner update | Divine Intervention | The channel heal on a wisp/ally is flavour; its revive half is folded into Hearthlight rank 3 |
| Knock reward | | the shared +250 HP knock reward already exists, so the +10% extra from the WIP was removed | restores HP on knock | |

Scaling: HP 145 (medium). Source ratios kept: ember 8 (about 1/18 of a seed burst), Hearthlight 10+22 = about 22% of max HP per squadmate, seed burst 35 = about 24% HP.

R choice: dropped as flavour. It does not reset on knocks, refresh the passive or enable a combo; the thing worth keeping, bringing a downed ally back to their feet, is Hearthlight's rank 3 flare.

## Combinations
| Interaction | Implemented in | Check |
|---|---|---|
| Ember into Kindled foe winds Hearthlight back | `on_deal` | `--tender-combo-check` |
| Kindle adds damage to embers | `outgoing` | same |
| Idle crook empowers the next ember (range, double wind-back) | `_tick` | same |
| Burrseed sticks, bursts, roots, Kindles | `_stick`, `_burst` | same |
| Relay Step through a teammate: half dash + 1s off Hearthlight | `on_dash` | `--support-check` |
| Hearthlight toss latches onto first teammate, or the one you carry | `e_recast` | both |
| Hearthlight on a downed teammate (5x), rank 3 revive on flare | `_pulse`, `_hearth_end` | `--support-check` |
| Stun on you puts Hearthlight out | `_tick_hearth` | `--support-check` |
| Carry: shield, slow, no bleed, drop on stun/shield break, set down | `_tick_carry` | `--support-check` |
| Rank 3 dash: picking up a teammate refreshes the air dash | `pick_up` | |

Engine gaps: none blocking. Online carry uses the new "carry" event (Net 0.6.3); heals and revives reuse "heal" and "rev".
