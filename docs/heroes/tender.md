# Linnet, the Tender (`tender`, medium support)

Internal design doc. Source behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (gameplay only; nothing of its names, look or text is used in the game).

## Research summary
Sources:
- The reference hero's public kit page and guides (see the Inspired-by table in docs/ARCHETYPES.md)

Version chosen: the wiki's current kit as it stood when the branch was built (late Oct 2026). No patch history was needed.
Disagreements: none material. The wiki lists no E (her heal is on Q, her ult is R); we map Q to our E because Q is the glove slot here. The guides stress Q first, matching our `order`.

## Our kit
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive Bearer | run into a downed teammate | Carry up to 2 downed teammates (never one a rival stands on); a 40 (+6/level) shield refills on pickup; they don't bleed or get stomped; you move 30% slower; crouch (Ctrl) sets them down (not F, which belongs to the Boki system); shield break, stun, root or hex drops them, stuns you 0.6s and locks pickup 4s | Soulpack | Shield scaled to our 145 HP; carried teammates ride at your back; online squadmates get a "carry" event so their own game follows you |
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
| Ember into Kindled foe winds Hearthlight back | `on_deal` | `--tender-combo-check` ("embers Kindle a foe", "ember into a Kindled foe winds Hearthlight back") |
| Kindle adds damage to embers | `outgoing` | same |
| Idle crook empowers the next ember (range, double wind-back) | `_tick` | same |
| Burrseed sticks, bursts, roots, Kindles | `_stick`, `_burst` | same |
| Relay Step through a teammate: half dash + 1s off Hearthlight | `on_dash` | `--support-check` |
| Hearthlight toss latches onto first teammate | `e_recast` | `--support-check` ("tossed, latches onto a teammate") |
| Hearthlight toss at yourself lands on the one you carry | `e_recast` | `--tender-combo-check` |
| Hearthlight on a downed teammate (5x), rank 3 revive on flare | `_pulse`, `_hearth_end` | `--support-check` |
| Stun on you puts Hearthlight out | `_tick_hearth` | `--support-check` |
| Carry: shield, slow, no bleed, drop on stun/shield break, set down | `_tick_carry` | `--support-check` |
| Rank 3 dash: picking up a teammate refreshes the air dash | `pick_up` | `--support-check` (Relay Step rank 3) |

## Ult choice
No R. The source's R is a channel heal on an ally or wisp; it does not feed the Kindle, carry or Hearthlight loop, and R on our keyboard now belongs to the Boki Merge. Its useful half (bring a downed friend back up) lives in Hearthlight rank 3.

## Animation moves
Full-body cast moves are `HunterAnim.KMOVES` entries, played by the kit with `play()` when the ability goes off.

| Ability | KMOVES id | Shape |
|---|---|---|
| RMB Burrseed | `tend_seed` | wind back with the seed by the ear, flick forward (hit at 0.17s) |
| E Hearthlight | `tend_hearth` | crouch to gather the light, rise with the lantern hand lifted (0.24s) |
| LMB, Relay Step, carry | none | the shared weapon-hold, dash and carry poses are used as they are |

Strips: `tender_rmb_strip`, `tender_e_strip` and the others in the shots folder (made with `--arena=thief --arena-demo=care_tender_<what> --arena-shot=...`, see `scripts/match/care_demo.gd`).

## Engine notes
- Kit: `scripts/arch/kits/tender_kit.gd`, shared helpers in `care_util.gd` (heals that reach bots and online squadmates, revive hook, carry). Gear and look: `scripts/match/hero_gear_care.gd`. Data: `content/archetypes/tender.json`, `content/weapons/lantern_crook.json`. Sounds: `audio/tend_*.wav` (made by `tools/gen_care_sfx.py`).
- No R in the data: `ArchKit` skips the ult path, the kit card shows the Boki Merge tile, `--archetype-check` skips R rows for the pair.
- Net: carrying adds one "carry" event (`["carry", target nid, carrier nid]`, handled in `match.gd` by `CareUtil.set_carry`), so Net.VERSION is 0.14.0. Heals and revives reuse "heal" and "rev".
- `life.gd` asks `CareUtil.carried_tick` so a carried teammate neither bleeds nor can be stomped.
- Checks: `--support-check` (all), `--tender-combo-check`.
