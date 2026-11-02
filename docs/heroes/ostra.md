# Ostra (archetype id `ostra`, Medium)

Internal note: the behaviour reference is the hero named in the Inspired-by table in docs/ARCHETYPES.md. Nothing below is
player-facing; every name, number and word in the shipped game is our own (renames: Swap -> Lantern Trade, Void Snap -> Shard
Snap, Unstable Anomaly -> Brimseed, gravity orb -> Tether Lantern orb).

## Research summary
- Sources: the reference sheet from footage (briefs/hero-ref/ostra.md, outside the repo), the wiki page
  (https://supervive.wiki.gg/wiki/Void) and the Steam patch-note text (Nov 2024 - Dec 2025).
- Owner notes (sync61) override the footage: spamming Shift must never dash in a random direction; Shift keeps her height; RMB
  has one charge and must visibly stun, the training dummy too.

## Design
Weight Medium (145 hp), floats. Fixed weapon Tether Lantern (`content/weapons/tether_lantern.json`): a pale crook with a curled
hook, a brass-caged lantern with a teal flame round a void-glass core, two violet shards beside it (hero_arms.gd). Palette
pearl and sea teal `#7fe0d0`, with void violet `#b06bff` for what she throws and pink `#ff4fd8` for Swollen. Payoff COLLAPSE.

## Scaling used (ratios from the source)
- Orb 9 dmg / 0.6s, 30 m/s, full 14m range; Settled +30% (source 280 vs 212), x1.4 speed, 10% slow 1.5s (wiki).
- Snap 12.5, about 1.4x an orb (source 190 vs 140), stun 0.8-1.8s by distance (card), one charge, 9s.
- Trade 1.7s, 1.25s Swollen (wiki: 1.7 / 1.25), 12m, slow 40% for 3s (wiki).
- Seed grows 6.5s (card) to 3.2m (4.2m Swollen, +30% as the wiki's Empowered size), damage up to 3.5x (wiki), Grounded 1s.
- Swollen 9s (the footage showed about 9s).

## Per-slot table
| Slot | Input | Aim and telegraph | What it does (ours) | Anim (KMovesStone) | Sound |
|---|---|---|---|---|---|
| Reticle | always | a thin pale line with an arrowhead from her to the cursor | | | |
| Passive Swell | builds | the pink sphere round her while Swollen | hits fill Swell (x10 on hunters); full = Swollen 9s: seed larger and quicker, Trade 1.25s, Snap +40%; a knock heals 20% | `ostra_empower` (a full turn in the air) | `os_empower` |
| LMB Tether Lantern | tap or hold | the aim line; orbs fly their full range (`"aim": "max"`) | 9 dmg violet teardrop orbs every 0.6s; after a 1.4s pause the next is Settled: a long blue-violet bolt, +30%, x1.4 speed, slows 10% for 1.5s; the charge shows as a light at her hand | `ostra_orb`, `ostra_orb_hot` | `os_orb`, `os_orb_hot`, `os_prime` |
| RMB Shard Snap | tap (1 charge) | holding RMB, or during the wind-up, the line becomes two rails the bundle's width (0.7m) | a 0.2s wind-up (a black orb at her hand; she slows 25%), then one bundle of crystal shards to 13m: 12.5 dmg, stuns the first foe 0.8s up close to 1.8s at range, stars over its head and STUNNED, on anyone including the training dummy | `ostra_snap_wind` (hold), `ostra_snap` | `os_snap_wind`, `os_snap`, `os_snap_hit` |
| Shift Lantern Trade | hold to aim, release (a tap casts at once) | while held: both ends (her ring, the landing ring at the cursor and the link); in flight: both ends for everyone, the sigil filling | a high lob (over 4m up) to the cursor, 1.7s; then she is there, keeping her height over the ground and her momentum, and anyone standing in the landing ring (foes slowed 40% 3s, allies too) goes to where she stood. It never travels by itself: a press in flight is ignored, a press with no charge is refused | `ostra_swap_aim` (hold), `ostra_swap`, `ostra_arrive` | `os_swap_lob`, `os_swap` |
| E Brimseed | tap, recast | at the cursor (9m), a ring everyone sees growing, dashed until full | a small orb drops onto the spot; a pale drum of indigo swirl grows 6.5s to 3.2m; a light column rises from 68%; E again (from 0.3s) pops it: an implosion, 12 dmg up to 3.5x, Grounded 1s; left alone it pops 0.5s after full (COLLAPSE on a hunter at full) | `ostra_seed`, `ostra_pop` | `os_seed`, `os_full`, `os_pop` |
| R | (Boki Merge) | | Black Hole stays folded into the rank-3 seed pull | | |

Rank 3: Snap +30%; Trade shields allies beside her when she leaves or at the landing (20, 3s); the pop pulls foes within 1.3x
its radius to the middle first and the growing seed burns.

## Combinations (`--ostra-combo-check`, tools/ostra_combo_check.gd; placement in `--zone-check`)
| Combo | Result | Asserted by |
|---|---|---|
| Snap, then the seed on the stunned foe, then pop | the foe can't leave before the pop | `combo: Snap > seed on the stunned foe > pop` |
| Seed under you, Trade through the foe | the foe lands in the seed | `combo: Seed > Trade puts the foe inside it` |
| Swollen Snap / Trade | +40% / 1.25s | `combo: Swollen Snap hits 40% harder`, `combo: Swollen Trade is quicker` |
| Pause, then fire | a Settled bolt that slows, then plain again | `lmb: the Settled orb hits harder and slows`, `small: the charge is stepped` |
| Spam Shift | no travel, no second lob; no charge = refused | `owner: spamming Shift in flight never dashes`, `owner: with no charge Shift is refused` |
| Trade in the air | arrives at the same height, same momentum | `owner: the Trade keeps her height`, `small: the Trade keeps her momentum` |
| Merge start | Trade, its aim, the Snap wind-up and the prime drop | `merge hold: ...` |

## Small mechanics
| Mechanic | Source | Footage | Ours |
|---|---|---|---|
| The orb charge is binary (charged or not), since 05.02.25 | patch notes, wiki | yes (the bolt) | built (one Settled orb, then plain) |
| Charged orb: faster, slows 10% for 1.5s | wiki | yes (SLOWED) | built |
| Charged orb passes through terrain | wiki | no | not built (our shots stop on terrain; a pierce would read as a bug on our islands) |
| Snap slows Void while casting (25% less since Jan 2025) | patch notes | no | built: 25% slower during the 0.2s wind-up |
| Snap stun grows with distance | wiki, card | yes | built 0.8-1.8s |
| Swap swaps whoever is at the destination; they go to the origin | wiki | partly (0193 is ambiguous) | built, allies included ("any units") |
| Swap travel 1.7s, 1.25s Empowered | wiki | yes (about 1.8s) | built |
| Over the abyss she hovers and keeps her previous momentum; Swap preserves momentum | wiki | no | built: momentum and height kept; over the abyss she lands on the last solid ground (our placement rule) |
| Level 4: allies (and wisps) entering the outgoing zone get a shield | wiki, patch Jan 2025 | no | built: allies beside her when she leaves or at the landing |
| Anomaly grows 6.5s, up to 3.5x; recast to detonate | wiki | yes | built, recast from 0.3s (sheet) |
| Empowered builds 10x faster on hunters; +30% Singularity size; knock heals | wiki | | built (Swollen); Swollen seed +30% size |

## Assumptions (easy to change in content/archetypes/ostra.json)
- Shift is hold-to-aim, release-to-cast (a tap casts at once): the source shows the landing ring before the press, and this
  is the only way a keyboard player sees it; it also removes any chance of a stray dash.
- With no dash charge, or pressed in the air, Shift never falls back to the long base dash (owner note). So she has no base dash
  variant; her Trade's lob and arrival are her dash moves.
- Brimseed pops by itself 0.5s after full growth (the source does not say).
- Swollen lasts 9s and fills as before (the source does not show what fills it).
- Snap range 13m; the orb's range stays 14m.

## Animation moves (KMovesStone)
| Ability | Moves | Strip |
|---|---|---|
| LMB orb, Settled bolt | `ostra_orb`, `ostra_orb_hot` | `--arena-demo=anim_os_orb`, `anim_os_orb_hot` |
| RMB | `ostra_snap_wind` (hold), `ostra_snap` | `anim_os_snap` |
| Shift | `ostra_swap_aim` (hold), `ostra_swap`, `ostra_arrive` | `anim_os_swap`, `anim_os_arrive` |
| E | `ostra_seed`, `ostra_pop` | `anim_os_seed`, `anim_os_pop` |
| Passive proc | `ostra_empower` | `anim_os_empower` |

## Engine notes
- Kit `scripts/arch/kits/ostra_kit.gd`; looks `kit_looks.gd` (pooled skins, aura, stun crown, column); the seed's drum in
  HeroZones.seed_visual (shaders/void_glass.gdshader). Every shot goes through spawn_shot.
- Net unchanged (0.15.0): the seed and Trade still travel as `["zone", ...]` events.
