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

## Concept note: the eerie jester (item 18, before any modelling)
Our own design, written before modelling; nothing below is modelled yet. She stays "she" here as in the rest of this page
(item 39's table lists the Void Jester as male: an owner question for the concept pass).
- **Silhouette:** a tall, narrow jester who never touches the ground. No hood and no long robe: from the waist down,
  layered violet ribbons fray into a dark-violet smoky tail that curls behind her as she glides, shedding faint pale
  motes; a soft shadow sits a clear gap below the tail tip, and she bobs gently.
- **Face:** a lacquered porcelain mask split down the middle: the right half a fixed, too-wide grin cut into
  mother-of-pearl, the left half blank but for one violet keyhole where the eye should be. The grin is part of the
  mask, never painted skin.
- **Head and collar:** a three-tailed cap whose tips each end in a tiny brass-caged lantern (the Tether Lantern's
  kin), and a stiff collar of folded paper points like a broken fan, edged with small brass bells that never ring.
- **Palette and hands:** pearl and sea teal for the mask and collar, void violet for the ribbons and tail, pink
  only when Swollen; long pale gloves with fingers a little too long, which carry the menace in her casts.
- **Kept clear of:** the source hero's look (no hooded figure, no reaching shadow hands or tendrils) and of famous
  clowns (no green hair, purple suit or painted scar-smile, no animatronic mascot). Hitbox and ring stay at ground
  level; the portrait framing gets redone once the cap's height is known.

## Scaling used (ratios from the source)
- Orb 9 dmg / 0.6s, 30 m/s, full 14m range; Settled +34% (owner's data 353 vs 263; was +30%), x1.4 speed, 10% slow 1.5s (wiki).
- Snap 9.5, about 1.05x an orb (data pass: owner's data 277 vs the orb's 263), stun 0.8-1.8s by distance (card), one charge, 10s.
- Trade 1.8s (the owner's "about 1.8-2s per the sheet"; wiki 1.7), 1.25s Swollen, 12m, slow 40% for 3s (wiki).
- Seed grows 6.5s (card) to 3.2m (4.2m Swollen, +30% as the wiki's Empowered size), damage 12.5 up to 3.5x (wiki; data pass: 365 vs the orb's 263 is 1.39x of 9), no Ground on the pop.
- Swollen 9s (the footage showed about 9s).

## Per-slot table
| Slot | Input | Aim and telegraph | What it does (ours) | Anim (KMovesStone) | Sound |
|---|---|---|---|---|---|
| Reticle | always | a thin pale line with an arrowhead from her to the cursor | | | |
| Passive Swell | builds | the pink sphere round her while Swollen | hits fill Swell (x10 on hunters); full = Swollen 9s: seed larger and quicker, Trade 1.25s, Snap +44% (data 399 vs 277); no knock heal (data pass); she floats, so ground hazards (lava, spore pods, puddles) do nothing to her, but a sky strike does | `ostra_empower` (a full turn in the air) | `os_empower` |
| LMB Tether Lantern | tap or hold | the aim line; orbs fly their full range (`"aim": "max"`) | 9 dmg violet glass teardrop orbs (0.28m, 0.8m long, a 1.2m magenta tail) every 0.6s; after a 1.4s pause the next is Settled: a 1.6m blue-violet bolt with a white core, +30%, x1.4 speed, slows 10% for 1.5s; the charge shows as a blue-violet mote at her hand | `ostra_orb`, `ostra_orb_hot` | `os_orb`, `os_orb_hot`, `os_prime` |
| RMB Shard Snap | tap (1 charge) | holding RMB, or during the wind-up, the line becomes two rails the bundle's width (0.7m) | a 0.32s wind-up (an opaque black orb with a thin pale rim swelling at her hand as she coils back; she slows 25%), then on the release beat (both palms shoved out) one 2.7m bundle of dark violet crystal prisms with bright rims flies 29.5 m/s to 13m (0.44s at full range) and the damage lands on its impact: 9.5 dmg, stuns the first foe 0.8s up close to 1.8s at range, stars over its head and STUNNED, on anyone including the training dummy; a 0.15s recovery keeps her slowed (item 40: the data has no timing, so the whole cast is +40%, 0.54s -> 0.76s at full range, all in the wind-up and the flight; the footage's bundle crosses about 30 m/s) | `ostra_snap_wind` (hold), `ostra_snap` | `os_snap_wind`, `os_snap`, `os_snap_hit` |
| Shift Lantern Trade | hold to aim, release (a tap casts at once) | while held: both ends (her ring, the landing ring at the cursor and the link); in flight: both ends for everyone, each with a rune sigil (teal at her, violet at the circle) whose ring lights segment by segment and whose hexagram brightens | a dark indigo star-orb lobbed high (over 4m up) to the cursor, or 12m along it if the cursor is further, with no ground, wall or abyss check on the target, with a violet trail, 1.8s; meanwhile she drifts at 20% of run speed (`dash.fly_slow`, CastHold) at the height she cast at, even over the abyss (no fall); then she is there (both ends fold in on themselves, motes drawn inward with no ring or blast, and her appear-pop), keeping her height, and everyone in the 1.5m circle (foes, allies, Boki off the shoulder) goes to where she is when it lands, each keeping its place in the circle; foes are slowed 40% 3s (SLOWED). A knock while it flies still shoves her (only her height is held). It never travels by itself: a press in flight is ignored, a press with no charge is refused | `ostra_swap_aim` (hold), `ostra_swap` (ground), `ostra_swap_air` (air), `ostra_arrive` | `os_swap_lob`, `os_swap` |
| E Brimseed | tap, recast | at the cursor (9m), a ring everyone sees growing, dashed until full | a small violet mote drops onto the spot; a dark indigo glass drum with a violet swirl and a teal rim grows 6.5s to 3.2m; a light column rises from 68%; E again (from 0.3s) pops it: an implosion, 12.5 dmg up to 3.5x; left alone it pops 0.5s after full (COLLAPSE on a hunter at full) | `ostra_seed`, `ostra_pop` | `os_seed`, `os_full`, `os_pop` |
| X Nightwell (level 6, 64s) | tap | at the cursor, clamped to 10m (on ground short of walls, like the seed): a pale dome of the well's exact size that everyone sees, filling over 1.0s (with a pink core when Swollen) | it opens into a turning violet disc for 3.5s, 3.6m wide (5.1m Swollen): every foe inside in sight of its centre, or who walks in, is stunned until it closes and drawn to the middle (12 m/s), taking 0.16 every 0.1s. Allies are untouched. Ostra is locked in the cast pose from the press until it closes (item 16): no moving, jumping, dashing, other abilities, the glove or the Boki's C, or attacks, no turning after the 0.25s wind-up; she sinks, then rises with her arms flung wide and the crook raised under a swelling black orb while the dome fills, and when it opens hauls her fists in to her chest round a violet mote and strains there until it closes. A stun or knock, or a merge, frees her (the placed well goes on). The source's Void acts freely while it holds (footage f50); the owner's item 16 overrides that. It closes with no blast. A merge or a knock on her doesn't end the placed well | `ostra_well`, `ostra_well_snap` (on opening, looped while it pulls), `ostra_well_end` | `os_well`, `os_well_hum` |
| Merge (the `ultimate` action; its key from Settings.key_cap) | (Boki Merge) | | | | |

Rank 3: Snap +30% and a burst of speed (+11% on the cast, +22% on a hit, 2s: the data's +50 and +100 of 465); Trade shields
allies beside her when she leaves or at the landing (26, 3s: the data's 375 shield as a share of a level-15 hunter's health,
on 145); the growing seed burns foes inside for 8.2 a second (the data's 250 against a 365 bomb) and rests 8s.

**Unfolded:** the kit pass had folded the source's Black Hole into Brimseed rank 3 (the pop dragging foes from 1.3x its radius
to the middle). Now that Black Hole is Nightwell on X, the pull is gone from the pop; the burn stays, as it is the source's own
level-4 bonus.

## Combinations (`--ostra-combo-check`, tools/ostra_combo_check.gd; placement in `--zone-check`)
| Combo | Result | Asserted by |
|---|---|---|
| Snap, then the seed on the stunned foe, then pop | the foe can't leave before the pop | `combo: Snap > seed on the stunned foe > pop` |
| Seed under you, Trade through the foe | the foe lands in the seed | `combo: Seed > Trade puts the foe inside it` |
| Swollen Snap / Trade | +44% / 1.25s | `combo: Swollen Snap hits 44% harder`, `combo: Swollen Trade is quicker` |
| Pause, then fire | a Settled bolt that slows, then plain again | `lmb: the Settled orb hits harder and slows`, `small: the charge is stepped` |
| Spam Shift | no travel, no second lob; no charge = refused | `owner: spamming Shift in flight never dashes`, `owner: with no charge Shift is refused` |
| Trade in the air, over the abyss | she drifts at 20% speed at her height until it lands (a knock still shoves her), then arrives at that height | `item 17: ...` (drift at `dash.fly_slow`, constant height over the abyss, origin at resolve, knock), `far cast: ...` |
| Trade into a crowd | a foe and an ally in the circle both end up at her origin, apart; a remote body is moved by its own game | `owner: two units in the circle ...`, `small: each keeps its place ...`, `net: a body another game owns ...` |
| Merge start | Trade, its aim, the Snap wind-up and the prime drop; a placed Nightwell keeps going | `merge hold: ...`, `merge: a merge doesn't take the placed well down` |
| Nightwell, then Seed on the middle, then pop | everyone caught sits stunned at the centre for the seed to grow on them | `ult open: ...`, `ult: the caught foe is drawn to the middle` |
| Nightwell, then anything | she is locked in the cast pose until it closes, then free; a stun or a knock frees her early | `lock: ...` (ult check) |
| Shard Snap timing | the press, a 0.32s wind-up, the release, the flight; the damage on the impact | `item 40: ...` |
| Trade in flight, then any ability (item 32) | the Trade's flight is her dash for DashFlow (`in_dash`); LMB, RMB, E, X and the glove fire mid-flight, ground or air (content/dash_flow/ostra.json, docs/heroes/dash_interactions.md); Shift during the Nightwell lock is refused, or held for the step she is freed when pressed in its last 0.15s | `--dash-flow-check`, `dash flow: ...` (ult check) |
| Trade, ground or air | her own dash move each (`ostra_swap`, `ostra_swap_air`), ids no other hero uses, inside the 1.25s Swollen Trade | `item 35: ...` |
| Swollen, then Nightwell | the bigger 5.1m well | `ult Swollen: ...` |
| Nightwell, then the merge | the target lives (burst cap) | `ult burst: the well, merge and its ultimate leave a full-health light hunter standing` |

## Data pass (SERVER_UPDATE7, owner's tooltip data)
Conversions: damage by the ratio to the orb (9 for the data's 263): Snap 277 -> 9.5, Settled 353 -> +34%, Swollen Snap 399 ->
+44%, the seed 365 -> 12.5, its damage over time 250 a second -> 8.2. Durations and cooldowns match directly: Snap 10s, Trade
9.5s, seed 10s. Speed bursts as a share of the data's 465: +50 -> 10.8%, +100 -> 21.5%. The ally shield by health: 375 of a
2074-hp hunter (level 15) -> 26 of 145.
- Done: the pop no longer Grounds; the knock heal is gone; ground hazards pass her by (`incoming`; the lightning rod's sky
  strike still hits); Snap's speed bursts at rank 3 (the data's rank IV); the seed's burn at rank 3 is 8.2 a second and its
  cooldown is 10s -> 8s at rank 3 through the shared rank step (the data's -2s at rank IV).
- Kept, not in the data: the seed still pops by itself at full growth (the data only says "reactivate to detonate"; one of the
  open questions); the Snap's distance-scaled stun (the owner's note: RMB visibly stuns); the Trade's 1.8s (no number in the
  data).
- Not done: the Settled orb passing through terrain (our shots stop on terrain); items in the swap circle (the data says "all
  units"; pickups are each game's own copies); an ice patch's slide still takes her (ground grip is not hers to change).
- Rank paths that do not fit: the data's Snap +20% damage at ranks 2 and 3, the seed's +10% each and the Trade's -1.5s twice go
  through the shared rank step (+15%/+30% damage, -10%/-20% cooldown on RMB and E, -15%/-30% recharge on the dash).

## Small mechanics
| Mechanic | Source | Footage | Ours |
|---|---|---|---|
| The orb charge is binary (charged or not), since 05.02.25 | patch notes, wiki | yes (the bolt) | built (one Settled orb, then plain) |
| Charged orb: faster, slows 10% for 1.5s | wiki | yes (SLOWED) | built |
| Charged orb passes through terrain | wiki, owner's data | no | not built (our shots stop on terrain; a pierce would read as a bug on our islands) |
| Snap slows Void while casting (25% less since Jan 2025) | patch notes | no | built: 25% slower during the 0.32s wind-up and the 0.15s recovery |
| Snap stun grows with distance | wiki, card | yes | built 0.8-1.8s |
| Swap swaps whoever is at the destination; they go to the origin | wiki | partly (0193 is ambiguous) | built, allies included ("any units") |
| Swap travel 1.7s, 1.25s Empowered | wiki | yes (about 1.8s) | built |
| Over the abyss she hovers and keeps her previous momentum; Swap preserves momentum | wiki | no | changed by the owner's notes: she hovers (no momentum) while the lantern flies, drifting at 20% speed (15-25% band, no source value in the data) with her height held; the origin is where she is when it resolves (default; the source doesn't say), so the drift matters |
| Level 4: allies (and wisps) entering the outgoing zone get a shield | wiki, patch Jan 2025 | no | built: allies beside her when she leaves or at the landing |
| Anomaly grows 6.5s, up to 3.5x; recast to detonate | wiki | yes | built, recast from 0.3s (sheet) |
| Empowered builds 10x faster on hunters; +30% Singularity size; knock heals | wiki | | built (Swollen); Swollen seed +30% size; the knock heal is removed (the owner's tooltip data has none) |
| Black Hole stuns and pulls enemies to its centre for 3.5s, small damage every 0.1s | card, wiki | yes (ult f33-f66) | built on X; asserted `ult open`, `drawn to the middle`, `small ticks` |
| A dome telegraph of the final size before it opens | footage | yes (f23-f32, 1.0s) | built, everyone sees it; asserted |
| Enemies who enter during the 3.5s are caught too ("for 3.5s") | card | no | built; asserted `a foe who walks in later is caught too` |
| Empowered: radius 350 -> 500 (and a June patch made Empowered really enlarge it) | card, patch notes (June 25) | yes (f89-f101) | built: 3.6m -> 5.1m when cast Swollen; asserted |
| Void acts freely while it holds | footage | yes (f50, shooting) | overridden by the owner (item 16): she is locked in the cast pose for the dome and the pull; asserted `lock: ...` |
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
  hem drifting; a jump keeps the hover (no landing squash beyond the shared small one); her only "air dash" is the Trade
  (cast in the air it plays her own sling-and-drift move, `ostra_swap_air`; the footage shows no air cast, and the
  sheet's build note asks for a smooth drift with no tumble and the hem streaming), and any dash she does get (a merge's dodge) leaves a streak of violet motes instead of the shared pill.
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
| Shift (her dash, item 35) | `ostra_swap_aim` (hold), `ostra_swap` (ground: the underhand lob, 0.85s), `ostra_swap_air` (air: an overhead sling, then a leaning drift with the hands and hem trailing, swaying, held until she arrives; 0.45s to the drift), `ostra_arrive` | `anim_os_swap`, `anim_os_swap_air`, `anim_os_arrive` |
| E | `ostra_seed`, `ostra_pop` | `anim_os_seed`, `anim_os_pop` |
| Passive proc | `ostra_empower` | `anim_os_empower` |
| X | `ostra_well` (wind-up, held), `ostra_well_snap` (held while it pulls), `ostra_well_end` | `anim_os_well` (`--strip-w=760` shows the dome and the well beside her) |

## Engine notes
- Kit `scripts/arch/kits/ostra_kit.gd`; looks `kit_looks.gd` (pooled skins, aura, stun crown, column); the seed's drum in
  HeroZones.seed_visual (shaders/void_glass.gdshader). Every shot goes through spawn_shot.
- Net: the seed travels as `["zone", ...]` events; Trade's moves go through Displace (`["disp", "tp", ...]`, decision 0011).
  Nightwell runs on the caster's game like the seed's pop: hits carry the stun, and every caught body (a player online on
  their own game) is drawn to the centre by a Displace "glide" tow.
- Nightwell: `scripts/arch/kits/ostra_well.gd` (OstraWell); its looks are pooled KitLooks kinds `well_dome` and `well`. It
  adds no hold field (nothing to drop on a merge).
