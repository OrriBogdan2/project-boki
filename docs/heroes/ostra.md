# Ostra (archetype id `ostra`, Medium)

Internal note: behaviour reference is the SUPERVIVE hero Void. Nothing below is player-facing.

## Research summary
Sources: supervive.wiki.gg/wiki/Void (abilities, rank table, patch notes listed on the page: orb charge became binary,
unempowered orb range). Disagreements: none found; the wiki gives no ranges, so ours are derived. Version: the page as of Nov 2026.

## Design
Weight Medium (145 hp). Fixed weapon Tether Lantern. Palette pearl and sea teal `#7fe0d0` with brass; wrapped headcloth, pale
mantle, long hem, three small lanterns hung behind. Payoff word COLLAPSE (sound `pay_collapse`).

| Slot | Input | Ours | Source behaviour | Difference |
|---|---|---|---|---|
| Passive Swell | damage dealt | fills 10x faster on hunters; full = Swollen 7s; a knock heals 20% | builds Empowered, knock heals | footstep silence and water immunity not built |
| LMB Tether Lantern | tap/hold | orb 9 dmg, 0.6s; after 1.4s without firing the next is Settled: +30% damage, +40% speed, slows 10% for 1.5s | charged shot after a pause | no terrain pass-through |
| RMB Rift Snap | tap | three shards in a 9 degree fan, 12m; middle one stuns 0.3-1.0s by distance; Swollen +40% | shard cluster, stun grows with distance | |
| Shift Swap | tap | lob a lantern up to 12m, 1s later you are there and foes at the spot go to where you were, slowed 40% 3s; Swollen 0.72s | teleport swap | over the abyss you land on the last solid ground (no hover); remote foes are slowed but not moved |
| E Brimseed | tap, tap again | seed up to 9m, grows 5s to 3m; pop for 12 up to 3.5x, foes Grounded 1s; Swollen larger and quicker | Unstable Anomaly | |
| R Singularity | none | folded into E rank 3: the pop pulls foes within 1.3x the radius to the middle, the growing seed burns | vortex stun/pull | flavour R dropped |

Rank 2: shorter cooldown, +15% damage. Rank 3: Snap +, Swap shields nearby allies 20, Brimseed pull and burn.

## Combinations (`--ostra-combo-check`)
| Combo | Result |
|---|---|
| Hits on a hunter vs a mob | ten times the Swell |
| Full Swell | Swollen: quicker Swap, +40% Snap, bigger seed |
| Pause then orb | Settled orb, harder, slows |
| Snap far vs near | longer stun |
| Seed, Snap, pop | stunned foe stays in the pop |
| Seed under you, Swap away through the foe | the foe lands in the seed |
| Seed left to full growth | Collapse payoff |
| Knock | heals 20% |
| Rank 3 pop | pulls foes at the rim to the middle |
