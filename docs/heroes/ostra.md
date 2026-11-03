# Void Jester (base character Ostra; archetype id `ostra`, Medium)

Internal note: the behaviour reference is the hero named in the Inspired-by table in docs/ARCHETYPES.md. Nothing below is
player-facing; every name, number and word in the shipped game is our own (renames: Swap -> Lantern Trade, Void Snap -> Shard
Snap, Unstable Anomaly -> Brimseed, gravity orb -> Tether Lantern orb).

## Research summary
- Sources: the reference sheet from footage (briefs/hero-ref/ostra.md, outside the repo), the wiki page
  (https://supervive.wiki.gg/wiki/Void) and the Steam patch-note text (Nov 2024 - Dec 2025).
- Owner notes (sync61) override the footage: spamming Shift must never dash in a random direction; Shift keeps her height; RMB
  has one charge and must visibly stun, the training dummy too.
- Owner dash note (Nov 2) on the Trade: a target circle at the cursor with a landing marker; while the lantern flies she
  hovers in place in the air, even over the abyss; when it lands everything in the circle (foes, allies, Boki) goes to where
  she was and she goes to the circle; both ends are marked during the wait; bots and online handle it.

## Design
Weight Medium (145 hp), floats: body 0.9 (content "body"), hovering about 0.3m over her ground point with a slow
+-0.03m bob at 0.6 Hz, legs at a tenth of a step (no step cycle, no footsteps), the hem trailing. The hover is visual
only: her hitbox and ring stay on the ground, so it never dodges low shots. Fixed weapon Tether Lantern (`content/weapons/tether_lantern.json`): a pale crook with a curled
hook, a brass-caged lantern with a teal flame round a void-glass core, two violet shards beside it (hero_arms.gd). Palette
pearl and sea teal `#7fe0d0`, with void violet `#b06bff` for what she throws and pink `#ff4fd8` for Swollen. Payoff COLLAPSE.

## Scaling used (ratios from the source)
- Orb 9 dmg / 0.6s, 30 m/s, full 14m range; Settled +30% (source 280 vs 212), x1.4 speed, 10% slow 1.5s (wiki).
- Snap 12.5, about 1.4x an orb (source 190 vs 140), stun 0.8-1.8s by distance (card), one charge, 9s.
- Trade 1.8s (the owner's "about 1.8-2s per the sheet"; wiki 1.7), 1.25s Swollen, 12m, slow 40% for 3s (wiki).
- Seed grows 6.5s (card) to 3.2m (4.2m Swollen, +30% as the wiki's Empowered size), damage up to 3.5x (wiki), Grounded 1s.
- Swollen 9s (the footage showed about 9s).

## Per-slot table
| Slot | Input | Aim and telegraph | What it does (ours) | Anim (KMovesStone) | Sound |
|---|---|---|---|---|---|
| Reticle | always | a thin pale line with an arrowhead from her to the cursor | | | |
| Passive Swell | builds | the pink sphere round her while Swollen | hits fill Swell (x10 on hunters); full = Swollen 9s: seed larger and quicker, Trade 1.25s, Snap +40%; a knock heals 20% | `ostra_empower` (a full turn in the air) | `os_empower` |
| LMB Tether Lantern | tap or hold | the aim line; orbs fly their full range (`"aim": "max"`) | 9 dmg violet glass teardrop orbs (0.28m, 0.8m long, a 1.2m magenta tail) every 0.6s; after a 1.4s pause the next is Settled: a 1.6m blue-violet bolt with a white core, +30%, x1.4 speed, slows 10% for 1.5s; the charge shows as a blue-violet mote at her hand | `ostra_orb`, `ostra_orb_hot` | `os_orb`, `os_orb_hot`, `os_prime` |
| RMB Shard Snap | tap (1 charge) | holding RMB, or during the wind-up, the line becomes two rails the bundle's width (0.7m) | a 0.2s wind-up (an opaque black orb with a thin pale rim at her hand; she slows 25%), then one 2.7m bundle of dark violet crystal prisms with bright rims to 13m: 12.5 dmg, stuns the first foe 0.8s up close to 1.8s at range, stars over its head and STUNNED, on anyone including the training dummy | `ostra_snap_wind` (hold), `ostra_snap` | `os_snap_wind`, `os_snap`, `os_snap_hit` |
| Shift Lantern Trade | hold to aim, release (a tap casts at once) | while held: both ends (her ring, the landing ring at the cursor and the link); in flight: both ends for everyone, each with a rune sigil (teal at her, violet at the circle) whose ring lights segment by segment and whose hexagram brightens | a dark indigo star-orb lobbed high (over 4m up) to the cursor with a violet trail, 1.8s; meanwhile she hovers where she cast it, at that height, even over the abyss (no fall, no drift); then she is there (an implosion and her appear-pop), keeping her height, and everyone in the 1.5m circle (foes, allies, Boki off the shoulder) goes to where she stood, each keeping its place in the circle; foes are slowed 40% 3s (SLOWED). It never travels by itself: a press in flight is ignored, a press with no charge is refused | `ostra_swap_aim` (hold), `ostra_swap`, `ostra_arrive` | `os_swap_lob`, `os_swap` |
| E Brimseed | tap, recast | at the cursor (9m), a ring everyone sees growing, dashed until full | a small violet mote drops onto the spot; a dark indigo glass drum with a violet swirl and a teal rim grows 6.5s to 3.2m; a light column rises from 68%; E again (from 0.3s) pops it: an implosion, 12 dmg up to 3.5x, Grounded 1s; left alone it pops 0.5s after full (COLLAPSE on a hunter at full) | `ostra_seed`, `ostra_pop` | `os_seed`, `os_full`, `os_pop` |
| X Nightwell (level 6, 64s) | tap | at the cursor, clamped to 10m (on ground short of walls, like the seed): a pale dome of the well's exact size that everyone sees, filling over 1.0s (with a pink core when Swollen) | it opens into a turning violet disc for 3.5s, 3.6m wide (5.1m Swollen): every foe inside in sight of its centre, or who walks in, is stunned until it closes and drawn to the middle (12 m/s), taking 0.16 every 0.1s. Allies are untouched; Ostra acts freely; it closes with no blast. A merge or a knock on her doesn't end the placed well | `ostra_well`, `ostra_well_snap` (on opening) | `os_well`, `os_well_hum` |
| Merge (the `ultimate` action; its key from Settings.key_cap) | (Boki Merge) | | | | |

Rank 3: Snap +30%; Trade shields allies beside her when she leaves or at the landing (20, 3s); the growing seed burns foes
inside (the source's level-4 damage over time).

**Unfolded:** the kit pass had folded the source's Black Hole into Brimseed rank 3 (the pop dragging foes from 1.3x its radius
to the middle). Now that Black Hole is Nightwell on X, the pull is gone from the pop; the burn stays, as it is the source's own
level-4 bonus.

## Combinations (`--ostra-combo-check`, tools/ostra_combo_check.gd; placement in `--zone-check`)
| Combo | Result | Asserted by |
|---|---|---|
| Snap, then the seed on the stunned foe, then pop | the foe can't leave before the pop | `combo: Snap > seed on the stunned foe > pop` |
| Seed under you, Trade through the foe | the foe lands in the seed | `combo: Seed > Trade puts the foe inside it` |
| Swollen Snap / Trade | +40% / 1.25s | `combo: Swollen Snap hits 40% harder`, `combo: Swollen Trade is quicker` |
| Pause, then fire | a Settled bolt that slows, then plain again | `lmb: the Settled orb hits harder and slows`, `small: the charge is stepped` |
| Spam Shift | no travel, no second lob; no charge = refused | `owner: spamming Shift in flight never dashes`, `owner: with no charge Shift is refused` |
| Trade in the air, over the abyss | she hovers in place until it lands, then arrives at that height | `owner: over the abyss she hovers in place ...`, `owner: she arrives at the landing keeping the height she hovered at` |
| Trade into a crowd | a foe and an ally in the circle both end up at her origin, apart; a remote body is moved by its own game | `owner: two units in the circle ...`, `small: each keeps its place ...`, `net: a body another game owns ...` |
| Merge start | Trade, its aim, the Snap wind-up and the prime drop; a placed Nightwell keeps going | `merge hold: ...`, `merge: a merge doesn't take the placed well down` |
| Nightwell, then Seed on the middle, then pop | everyone caught sits stunned at the centre for the seed to grow on them | `ult open: ...`, `ult: the caught foe is drawn to the middle` |
| Nightwell, then Snap | she acts freely while it holds | `ult: Ostra is free to act while it holds (a Snap)` |
| Swollen, then Nightwell | the bigger 5.1m well | `ult Swollen: ...` |
| Nightwell, then the merge | the target lives (burst cap) | `ult burst: the well, merge and its ultimate leave a full-health light hunter standing` |

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
| Over the abyss she hovers and keeps her previous momentum; Swap preserves momentum | wiki | no | changed by the owner's dash note: she hovers in place (no momentum) while the lantern flies and keeps her height; the lantern lands on solid ground |
| Level 4: allies (and wisps) entering the outgoing zone get a shield | wiki, patch Jan 2025 | no | built: allies beside her when she leaves or at the landing |
| Anomaly grows 6.5s, up to 3.5x; recast to detonate | wiki | yes | built, recast from 0.3s (sheet) |
| Empowered builds 10x faster on hunters; +30% Singularity size; knock heals | wiki | | built (Swollen); Swollen seed +30% size |
| Black Hole stuns and pulls enemies to its centre for 3.5s, small damage every 0.1s | card, wiki | yes (ult f33-f66) | built on X; asserted `ult open`, `drawn to the middle`, `small ticks` |
| A dome telegraph of the final size before it opens | footage | yes (f23-f32, 1.0s) | built, everyone sees it; asserted |
| Enemies who enter during the 3.5s are caught too ("for 3.5s") | card | no | built; asserted `a foe who walks in later is caught too` |
| Empowered: radius 350 -> 500 (and a June patch made Empowered really enlarge it) | card, patch notes (June 25) | yes (f89-f101) | built: 3.6m -> 5.1m when cast Swollen; asserted |
| Void acts freely while it holds | footage | yes (f50, shooting) | built; asserted with a Snap |
| Allies unaffected; it never breaks allied destructibles (patch) | sheet, patch notes (June 25) | | built: foes only; it hurts no walls at all |
| Empowered damage is Explosive (175 a tick to destructibles) | wiki | no | not built: our destructibles are walls that take shot damage; a well tick is not a shot (owner question) |
| It closes with no explosion | footage | yes (f66) | built |

## Assumptions (easy to change in content/archetypes/ostra.json)
- Shift is hold-to-aim, release-to-cast (a tap casts at once): the source shows the landing ring before the press, and this
  is the only way a keyboard player sees it; it also removes any chance of a stray dash.
- With no dash charge, or pressed in the air, Shift never falls back to the long base dash (owner note). So she has no base dash
  variant; her Trade's lob and arrival are her dash moves.
- Brimseed pops by itself 0.5s after full growth (the source does not say).
- Trade: loose items on the ground are not traded. Pickups are each game's own copies; moving them on one game would leave
  the others disagreeing. Boki riding a shoulder (or benched) stay with their hunter.
- Trade: the bodies keep their offset from the circle's centre at her origin; one that would land on the abyss or a step
  over 1.5m goes to her exact spot instead.
- Body, idle, jumps (not in the footage, built from her character): the hover-glide above; idle is the hover bob with the
  hem drifting; a jump keeps the hover (no landing squash beyond the shared small one); her only "air dash" is the Trade,
  and any dash she does get (a merge's dodge) leaves a streak of violet motes instead of the shared pill.
- Swollen lasts 9s and fills as before (the source does not show what fills it).
- Snap range 13m; the orb's range stays 14m.
- Nightwell range 10m (the footage only shows a 2-3 bh cast), placed like the seed: on ground short of walls.
- A foe behind a wall from the well's centre is not caught (the source doesn't show one).
- A caught foe is stunned until the well closes, without stun diminishing returns (it is the ult; the card says 3.5s).
- Ticks: 0.16 every 0.1s (the source's 2.5 a tick against a 140 orb, scaled to our 9 orb).
- The well stays when Ostra is knocked or merges; it is a placed thing, and she is free during it.
- Bond: paid when a hunter is caught (a hit), topped up if one is knocked or killed inside it; never per tick. The sheet's
  0.4 per hunter capped at 0.8 is the main session's to set (KinBond.from_ult).

## Animation moves (KMovesStone)
| Ability | Moves | Strip |
|---|---|---|
| LMB orb, Settled bolt | `ostra_orb`, `ostra_orb_hot` | `--arena-demo=anim_os_orb`, `anim_os_orb_hot` |
| RMB | `ostra_snap_wind` (hold), `ostra_snap` | `anim_os_snap` |
| Shift | `ostra_swap_aim` (hold), `ostra_swap`, `ostra_arrive` | `anim_os_swap`, `anim_os_arrive` |
| E | `ostra_seed`, `ostra_pop` | `anim_os_seed`, `anim_os_pop` |
| Passive proc | `ostra_empower` | `anim_os_empower` |
| X | `ostra_well`, `ostra_well_snap` | `anim_os_well` |

## Engine notes
- Kit `scripts/arch/kits/ostra_kit.gd`; looks `kit_looks.gd` (pooled skins, aura, stun crown, column); the seed's drum in
  HeroZones.seed_visual (shaders/void_glass.gdshader). Every shot goes through spawn_shot.
- Net unchanged: the seed and Trade still travel as `["zone", ...]` events. Nightwell runs on the caster's game like the
  seed's pop: hits carry the stun, and a remote body is moved to the centre with the `"tp"` zone event once, on its catch.
- Nightwell: `scripts/arch/kits/ostra_well.gd` (OstraWell); its looks are pooled KitLooks kinds `well_dome` and `well`. It
  adds no hold field (nothing to drop on a merge).
