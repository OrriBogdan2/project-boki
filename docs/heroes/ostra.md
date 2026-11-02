# Ostra (archetype id `ostra`, Medium)

Internal note: the behaviour reference is the SUPERVIVE hero Void. Nothing below is player-facing; every name, number and
word in the shipped game is our own (finish-pass renames: Swap -> Lantern Trade, Rift Snap -> Shard Fan, which had matched
or echoed the source; "gravity orb" became "drifting orb").

## Research summary
- Sources read: https://supervive.wiki.gg/wiki/Void (abilities, level table, patch history), plus the Void rows in
  docs/DASHES_AND_ABILITY_FEEL.md (dash: aimed lob, 1.7s travel, 1.25s empowered, swaps places).
- Patch history used: 05.02.25 the orb charge became binary (charged or not, not time-scaled); 18.12.24 unempowered shots
  stopped piercing terrain and gained 35% range, Swap cooldown cut (12/9/9 -> 10/7/7), bomb damage +10%; 22.01.25 Swap level-4
  shield for the caster and allies.
- Disagreements: the feel doc (read Oct 2026) records a 1.7s lob and 1.25s empowered, and the Dec 2024 patch cut the cooldown; ours is 1.0s / 0.72s Swollen
  because our fights are shorter. The wiki gives no ranges, so ours are derived.
- Version chosen: the page as of Nov 2026 (final values; the game shut down Feb 2026).
- Copied: structure and interactions only. Not copied: names, text, numbers, art, sound.

## Design
Weight Medium (145 hp). Fixed weapon Tether Lantern (`content/weapons/tether_lantern.json`, hero_only). Palette pearl and sea
teal `#7fe0d0` with brass; wrapped headcloth, pale mantle, long hem, three small lanterns hung behind. Payoff word COLLAPSE (sound
`pay_collapse`).

## Scaling used
- Health class Medium; numbers set so a seed pop at full growth (up to 12 x 3.5 = 42) plus
  one Fan is a kill threat on a Medium, never a one-shot.
- Rank 2: cooldown -10%, +15% damage (RMB, E), dash recharge 9 -> 7.6s. Rank 3: RMB +30% damage and cooldown 7.2s; dash shields
  allies near the landing for 20; E pulls in then bursts and the growing seed burns.
- Swell: 0.045 per damage, x10 on hunters, drains 12/s after 4s idle; Swollen 7s. Orb 9 dmg / 0.6s; Settled +30% dmg, +40% speed,
  10% slow for 1.5s. Fan: 11 centre + 6 side shards, stun 0.3-1.0s by distance, Swollen +40%. Seed: 12 dmg up to 3.5x, radius to 3m
  (3.9m Swollen), Grounded 1s. Lantern Trade: 12m, 1.0s (0.72s Swollen), slow 40% for 3s.

## Per-slot table
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive Swell | damage dealt | fills 10x faster on hunters; full = Swollen 7s; a knock heals 20% | damage builds Empowered (much faster vs hunters); floats (no footsteps, water or sand effects); heals on a knock | footstep silence and water immunity not built: no equivalent stealth model in our footsteps yet |
| LMB Tether Lantern | tap / hold | orb 9 dmg, 0.6s; after 1.4s without firing the next is Settled: +30% damage, +40% speed, slows 10% for 1.5s | charged shot after a pause: more damage, faster, passes terrain, slows | binary like the later patch; no terrain pass-through (our walls are tile blockers) |
| RMB Shard Fan | tap | three shards in a 9 degree fan, 12m; the middle one stuns 0.3-1.0s by distance; Swollen +40% | shard cluster, stun on first target grows with travel | numbers ours; no movement-speed boost on cast (later patch) |
| Shift Lantern Trade | tap | lob a lantern up to 12m, 1s later you are there and foes at the spot go to where you were, slowed 40% for 3s; Swollen 0.72s; rank 3 shields allies near the landing | aimed lob then teleport swapping places with units there; swapped enemies slowed | over the abyss you land on the last solid ground (no hover); remote foes are slowed but not moved |
| E Brimseed | tap, tap again | seed up to 9m, grows 5s to 3m; pop for 12 up to 3.5x, foes Grounded 1s; Swollen larger and quicker | placed bomb grows, re-press detonates, more damage the longer held, extra vs Grounded foes | Grounded is applied by the pop itself (we have no separate grounding source) |
| R Singularity | none | folded into Brimseed rank 3: the pop pulls foes within 1.3x the radius to the middle, the growing seed burns | vortex that stuns and pulls for 3.5s, strong against destructibles | flavour R dropped; pull kept as a rank-3 upgrade |

## Ult choice
Folded into Brimseed rank 3 (pull-in and burn) and not kept as a separate R: R is the Boki Merge now, and the pull-in is what makes
the seed a team combo piece, so it lives on the tool the hero already uses.

## Combinations (`--ostra-combo-check`; tools/hero_pair_check.gd)
| Combo | Result | Asserted by |
|---|---|---|
| Hits on a hunter vs a mob | ten times the Swell | `passive: Swell fills ten times faster on hunters` |
| Full Swell | Swollen: quicker Trade, +40% Fan, bigger seed | `passive: full Swell = Swollen`, `combo: Swollen Fan hits 40% harder`, `combo: Swollen Trade is quicker` |
| Pause then orb | Settled orb, harder, slows; the next one is plain | `lmb: a pause primes the next orb`, `lmb: the Settled orb hits harder and slows`, `lmb: the next orb is plain again` |
| Fan far vs near | longer stun | `rmb: Shard Fan stuns longer the further it flew` |
| Seed, Fan, pop | stunned foe stays in the pop | `combo: Seed > Fan > pop catches the stunned foe` |
| Seed under you, Trade away through the foe | the foe lands in the seed | `combo: Seed > Trade puts the foe inside it` |
| Trade | trades places, slows the foe | `dash: Trade trades places and slows the foe` |
| Seed left to full growth | Collapse payoff | `e: a seed left alone pops at full growth (Collapse)` |
| Seed growth | later pop hits harder, grounds | `e: the longer the seed grows, the harder the pop`, `e: the pop grounds what it catches` |
| Knock | heals 20% | `passive: a knock heals 20%` |
| Rank 3 pop | pulls foes at the rim to the middle | `rank 3: the pop pulls foes at the rim to the middle` |
| Placement | seed and Trade respect ground, walls, abyss; Net rebuilds the seed | `seed: ...`, `swap: ...` (lands on solid ground, stops before a rock), `net: the seed is announced...` in `--zone-check` |

## Animation moves (HunterAnim.KMOVES)
| Ability | Move id |
|---|---|
| LMB orb | none (default fire pose) |
| Lantern Trade | `ostra_dash` |
| Shard Fan | `ostra_rmb` |
| Brimseed | `ostra_e` |
Stance entry `ostra` (slight back lean, narrow stance). Strips: `--arena-demo=anim_ost_dash|ost_snap|ost_seed|ost_orb`.

## Engine notes
- Kit: `scripts/arch/kits/ostra_kit.gd`, data `content/archetypes/ostra.json`, weapon `tether_lantern.json`; `no_hold: true`
  (no hold input on the kit card).
- The seed uses HeroZones for ground and wall legality; `["zone", "seed" | "pop", ...]` events (Net 0.10.1) so a second game
  rebuilds the same growth. Disoriented (the Trade slow) is a KitStatus effect `dsr` with a DIZZY word and teal ring.
- Look: `scripts/match/gear_pair.gd`, `hero_arms.gd`. Sound: tools/gen_pair_sfx.py. Bot logic in the kit's `bot_use`.
