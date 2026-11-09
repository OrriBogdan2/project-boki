# Motley the Void Jester (archetype id `ostra`, Medium)

Internal note: the behaviour reference is the hero named in the Inspired-by table in docs/ARCHETYPES.md. Nothing below is
player-facing; every name, number and word in the shipped game is our own (renames: Swap -> Lantern Trade, Void Snap -> Shard
Snap, Unstable Anomaly -> Brimseed, gravity orb -> Tether Lantern orb).

## Research summary
- Sources: the reference sheet from footage (briefs/hero-ref/ostra.md, outside the repo), the wiki page
  (https://supervive.wiki.gg/wiki/Void) and the Steam patch-note text (Nov 2024 - Dec 2025).
- Owner notes (sync61) override the footage: spamming Shift must never dash in a random direction; Shift keeps his height; RMB
  has one charge and must visibly stun, the training dummy too.
- Owner dash note (Nov 2) on the Trade: a target circle at the cursor with a landing marker; while the lantern flies he
  hovers in place in the air, even over the abyss; when it lands everything in the circle (foes, allies, Boki) goes to where
  he was and he goes to the circle; both ends are marked during the wait; bots and online handle it.

## Design
Weight Medium (145 hp), floats: body 0.9 (content "body"), hovering about 0.3m over his ground point with a slow
+-0.03m bob at 0.6 Hz, legs at a tenth of a step (no step cycle, no footsteps), the hem trailing. The hover is visual
only: his hitbox and ring stay on the ground, so it never dodges low shots. Fixed weapon Tether Lantern (`content/weapons/tether_lantern.json`): a pale crook with a curled
hook, a brass-caged lantern with a teal flame round a void-glass core, two violet shards beside it (hero_arms.gd). Palette
pearl and sea teal `#7fe0d0`, with sea teal `#2ee6c0` over a void core for what he throws and pink `#ff4fd8` for Swollen. Payoff COLLAPSE.

## Concept note: the eerie jester (item 18, before any modelling)
Our own design, written before modelling; nothing below is modelled yet. He is male (owner, item 39: the Void Jester).
- **Silhouette:** a tall, narrow jester who never touches the ground. No hood and no long robe: from the waist down,
  layered violet ribbons fray into a dark-violet smoky tail that curls behind him as he glides, shedding faint pale
  motes; a soft shadow sits a clear gap below the tail tip, and he bobs gently.
- **Face:** a lacquered porcelain mask split down the middle: the right half a fixed, too-wide grin cut into
  mother-of-pearl, the left half blank but for one violet keyhole where the eye should be. The grin is part of the
  mask, never painted skin.
- **Head and collar:** a three-tailed cap whose tips each end in a tiny brass-caged lantern (the Tether Lantern's
  kin), and a stiff collar of folded paper points like a broken fan, edged with small brass bells that never ring.
- **Palette and hands:** pearl and sea teal for the mask and collar, void violet for the ribbons and tail, pink
  only when Swollen; long pale gloves with fingers a little too long, which carry the menace in his casts.
- **Kept clear of:** the source hero's look (no hooded figure, no reaching shadow hands or tendrils) and of famous
  clowns (no green hair, purple suit or painted scar-smile, no animatronic mascot). Hitbox and ring stay at ground
  level; the portrait framing gets redone once the cap's height is known.

## Scaling used (ratios from the source)
- Orb 9 dmg / 0.6s, 30 m/s, full 14m range, through walls (owner, item 60); a full charge is +34% (owner's data 353 vs 263; was +30%), x1.4 speed, +90% size, 10% slow 1.5s (wiki).
- Snap 9.5, about 1.05x an orb (data pass: owner's data 277 vs the orb's 263), stun 0.8-1.8s by distance (card), one charge, 10s.
- Trade 1.8s (the owner's "about 1.8-2s per the sheet"; wiki 1.7), 1.25s Swollen, 12m (the wiki's 40% slow on swapped foes is not built: the game data has none).
- Seed grows 6.5s (card) to 3.2m (4.2m Swollen, +30% as the wiki's Empowered size), damage 12.5 up to 3.5x (wiki; data pass: 365 vs the orb's 263 is 1.39x of 9), no Ground on the pop.
- Swollen 9s (the footage showed about 9s).

## Per-slot table
| Slot | Input | Aim and telegraph | What it does (ours) | Anim (KMovesStone) | Sound |
|---|---|---|---|---|---|
| Reticle | always | a thin pale line with an arrowhead from him to the cursor | | | |
| Passive Swell | builds | the pink sphere round him while Swollen | hits fill Swell (x10 on hunters); full = Swollen 9s: seed larger and quicker, Trade 1.25s, Snap +44% (data 399 vs 277); no knock heal (data pass); he floats, so ground hazards (lava, spore pods, puddles) do nothing to him, but a sky strike does | `ostra_empower` (a full turn in the air) | `os_empower` |
| LMB Tether Lantern | tap or hold | the aim line; orbs fly their full range (`"aim": "max"`) through walls and terrain (`shot_x.pierce_terrain` on the weapon; placed walls and domes still stop them) | 9 dmg violet glass teardrop orbs (0.28m, 0.8m long, a 1.2m magenta tail) every 0.6s. The wait between shots charges the next one in a straight line, from plain at 0.6s (`lmb.charge_from`, the fire rate, so held fire stays plain orbs) to full at 1.4s (`lmb.idle`): damage up to +34%, speed up to x1.4, size (drawn and hit) up to +90% (item 117: at least 1.6x; 31 vs 58 px wide at the match camera), glass, core and impact bigger and brighter with the charge; a full orb also slows 10% for 1.5s. `charge_from` is the one value for the curve: at 0 a held orb is already x1.39, so full is only 1.37x it and item 117's 1.6x no longer holds against held fire. A violet glow at his hand grows with the charge, with a soft chime at full | `ostra_orb`, `ostra_orb_hot` | `os_orb`, `os_orb_hot`, `os_prime` |
| RMB Shard Snap | tap (1 charge) | holding RMB, or during the wind-up, the line becomes two rails the bundle's width (0.7m) | a 0.32s wind-up (an opaque black orb with a thin pale rim swelling at his hand as he coils back; he slows 25%), then on the release beat (both palms shoved out) one 2.7m bundle of dark violet crystal prisms with bright rims flies 29.5 m/s to 13m (0.44s at full range) and the damage lands on its impact: 9.5 dmg, stuns the first foe 0.8s up close to 1.8s at range, stars over its head and STUNNED, on anyone including the training dummy; a 0.15s recovery keeps him slowed (item 40: the data has no timing, so the whole cast is +40%, 0.54s -> 0.76s at full range, all in the wind-up and the flight; the footage's bundle crosses about 30 m/s) | `ostra_snap_wind` (hold), `ostra_snap` | `os_snap_wind`, `os_snap`, `os_snap_hit` |
| Shift Lantern Trade | hold to aim, release (a tap casts at once) | while held: both ends (his ring, the landing ring at the cursor and the link); in flight: both ends for everyone, each with a rune sigil (teal at him, violet at the circle) whose ring lights segment by segment and whose hexagram brightens | a dark indigo star-orb lobbed high (over 4m up) to the cursor, or 12m along it if the cursor is further, with no ground, wall or abyss check on the target, with a violet trail, 1.8s; meanwhile he drifts at 30% of run speed (`dash.fly_slow`, CastHold) at the height he cast at, even over the abyss (no fall); then he is there (both ends fold in on themselves, motes drawn inward with no ring or blast, and his appear-pop), keeping his height, and everyone in the 1.5m circle (foes, allies, Boki off the shoulder) goes to where he is when it lands, each keeping its place in the circle (nobody is slowed: the data's Swap only swaps). A knock while it flies still shoves him (only his height is held). It never travels by itself: a press in flight is ignored, a press with no charge is refused | `ostra_swap_aim` (hold), `ostra_swap` (ground), `ostra_swap_air` (air), `ostra_arrive` | `os_swap_lob`, `os_swap` |
| E Brimseed | tap, recast | at the cursor (9m), a ring everyone sees growing, dashed until full | a small violet mote drops onto the spot; a dark indigo glass drum with a violet swirl and a teal rim grows 6.5s to 3.2m; a light column rises from 68%; E again (from 0.3s) pops it: an implosion, 12.5 dmg up to 3.5x (COLLAPSE on a hunter at full); left alone it waits at full size for the recast, and fizzles harmlessly after 10s unpopped | `ostra_seed`, `ostra_pop` | `os_seed`, `ostra_music_box`, `os_pop` + `ostra_spring_boing` |
| X Nightwell (level 6, 64s) | tap | at the cursor, clamped to 10m (on ground short of walls, like the seed): a pale dome of the well's exact size that everyone sees, filling over 1.0s (with a pink core when Swollen) | it opens into a turning violet disc for 3.5s, 3.6m wide (5.1m Swollen): every foe inside in sight of its centre, or who walks in, is stunned until it closes and drawn to the middle (12 m/s), taking 0.16 every 0.1s. Allies are untouched. Motley is locked in the cast for the 1.0s dome (Void's telegraph, footage f23-f33; owner 18:20): no moving, jumping, dashing, other abilities, the glove or the Boki's C, or attacks, no turning after the 0.25s wind-up; he sinks, then rises with his arms flung wide and the crook raised under a swelling black orb while the dome fills. When it opens he hauls his fists in to his chest, hunches over the pull, flings the hands away and is free: he can walk out at full speed, fight or Trade away while it keeps going (Void acts freely while it holds, f50). A stun or knock, or a merge, frees him early (the placed well goes on). It closes with no blast | `ostra_well` (held for the dome), `ostra_well_snap` (the release, 0.55s), `ostra_well_end` (knocked out of the cast) | `os_well`, `os_well_hum` |
| Merge (the `ultimate` action; its key from Settings.key_cap) | (Boki Merge) | | | | |

Rank 3: Snap +30% and a burst of speed (+11% on the cast, +22% on a hit, 2s: the data's +50 and +100 of 465); Trade shields
allies beside him when he leaves or at the landing (26, 3s: the data's 375 shield as a share of a level-15 hunter's health,
on 145); the growing seed burns foes inside for 8.2 a second (the data's 250 against a 365 bomb) and rests 8s.

**Unfolded:** the kit pass had folded the source's Black Hole into Brimseed rank 3 (the pop dragging foes from 1.3x its radius
to the middle). Now that Black Hole is Nightwell on X, the pull is gone from the pop; the burn stays, as it is the source's own
level-4 bonus.

## Parity pass (owner 18:45: LMB first, then the rest by distance from the source)
Source vs ours per slot. [data] = briefs/supervive-data (supervive_kits.md, Void), [footage] = briefs/hero-ref/ostra.md (5 fps; the ult at 10 fps).

| Slot | Source | Ours | Asserted (`--ostra-combo-check`) |
|---|---|---|---|
| LMB cadence and reach | an orb about every 0.6s (0031 -> 0034), flying past the cursor to max range [footage] | 0.6s, the full 14m | `lmb parity: held, an orb every 0.6 s ...`, `lmb: a plain orb flies past the cursor ...` |
| LMB tracking and animation | he turns to the aim; one-hand flicks, the body barely moves [footage] | `ostra_orb` (0.04 cock, 0.09 flick, 0.3), every orb along the current aim, also while drifting with the cursor swinging round him | `lmb parity: every orb leaves at the cursor ...` |
| LMB charge | after not firing, the next orb is stronger (353 vs 263) [data]; binary since a patch (wiki) | continuous (owner item 60): plain at 0.6s to full at 1.4s, +34%, x1.4 speed, +90% size; full also slows | `item 60: ...`, `item 117: ...`, `charge: ...`, `slow: ...`, `held fire: ...`, `glow: ...`, `chime: ...` |
| LMB spam penalty | "firing faster lowers projectile speed and damage" (card, footage) | none: the fixed 0.6s cadence can't be beaten, so there is nothing to penalise | (not built) |
| RMB | a 0.2s black-orb wind-up, one crystal-spear cluster, stun 0.8-1.8s by distance [footage] | 0.32s wind-up (owner item 40: slower), one bundle, 0.8-1.8s | `item 40: ...`, `rmb: ...` |
| Shift | a lob, about 1.8s, rings at both ends [footage] | 1.8s, both ends marked; he drifts at 30% (owner, item 75) | `item 17: ...`, `owner: ...` |
| E | grows 6.5s, recast from 0.3s, an implosion pop [footage, data] | as the source: it waits for the recast (a 10s fizzle cap at full) | `combo: ...`, seed rows |
| X | a 1.0s dome telegraph with his cast held, then a 3.5s pull while he acts freely [footage f23-f50] | locked for the 1.0s dome only, then free (owner 18:20) | `lock: ...`, `release: ...` (ult check) |

## Audit (Nov 3 23:40)
Every row of briefs/specs/kit-audit/tarek_ostra_claire.md section 2 (audited on main 200effce) against this branch.

| Row | Sev | Verdict | Where / why |
|---|---|---|---|
| Nightwell locks him 4.5 s (owner: about 1 s, then free) | HIGH | (a) | 59010b31, e62732d6; `lock: ...`, `release: ...` (ult check) |
| Nightwell text and DashFlow rows describe the old lock | HIGH | (a) | 59010b31, e62732d6 |
| X cd 64 s vs 70 s | LOW | (b) | 8e5c6340: 70 s; `ult cast: ... (70s, data)` |
| The seed pops by itself (data: reactivate to detonate) | MED | (b) | 8e5c6340: it waits at full size for the recast; left 10 s at full it fizzles with no damage (our cap, so it can't be parked forever); `e: a full seed waits for the recast ...`, `e: left unpopped ... fizzles out harmlessly` |
| The strong orb doesn't go through terrain (data) | MED | (b) | 8e5c6340, widened by item 60: `pierce_terrain` on every orb (owner over the data); `item 60: every orb passes ...`, `walls: ...` (also real maps, point blank and at range: tools/ostra_arena_check.gd), `net: ...` |
| Orb magazine 12 / 1.5 s reload (not in the source) | MED | (b) | 8e5c6340: mag 99 (no reload in play) |
| Spam penalty (footage card only) | LOW | (c) | not built: the fixed 0.6 s cadence can't be beaten, so there is nothing to penalise (parity table) |
| Trade slows swapped foes 40% for 3 s (invented) | MED | (b) | 8e5c6340: removed; `dash: Trade trades places; the foe is only moved, not slowed ...` |
| Shift hold-to-aim | LOW | (c) | kept: a tap behaves like the source; the hold shows both ends (owner Nov 2) |
| Shift radius 1.5 m | LOW | (c) | kept: the data has no number and the footage scale is about 2x uncertain |
| Pronouns and the old lamplighter concept in his text | MED | (b) | 8e5c6340: fantasy, silhouette and tells rewritten for the Void Jester; he/him in this doc, the DashFlow rows, kit comments and check names |
| Charged-orb ground ring (cosmetic) | LOW | (b) | 8e5c6340: removed (the hand glow stays) |
| Self screen shake | MED | (c) | ext/no-shake owns it |
| RMB, passive, items 17 and 42 | n/a | (a) | matched in the audit |

## Combinations (`--ostra-combo-check`, tools/ostra_combo_check.gd; placement in `--zone-check`)
| Combo | Result | Asserted by |
|---|---|---|
| Snap, then the seed on the stunned foe, then pop | the foe can't leave before the pop | `combo: Snap > seed on the stunned foe > pop` |
| Seed under you, Trade through the foe | the foe lands in the seed | `combo: Seed > Trade puts the foe inside it` |
| Swollen Snap / Trade | +44% / 1.25s | `combo: Swollen Snap hits 44% harder`, `combo: Swollen Trade is quicker` |
| Wait, then fire | the longer the wait, the bigger and harder the orb; full, it slows; held fire stays plain | `item 60: ...`, `charge: ...`, `slow: ...`, `held fire: ...` |
| Spam Shift | no travel, no second lob; no charge = refused | `owner: spamming Shift in flight never dashes`, `owner: with no charge Shift is refused` |
| Trade in the air, over the abyss | he drifts at 30% speed at his height until it lands (a knock still shoves him), then arrives at that height | `item 17: ...` (drift at `dash.fly_slow`, constant height over the abyss, origin at resolve, knock), `far cast: ...` |
| Trade into a crowd | a foe and an ally in the circle both end up at his origin, apart; a remote body is moved by its own game | `owner: two units in the circle ...`, `small: each keeps its place ...`, `net: a body another game owns ...` |
| Merge start | Trade, its aim, the Snap wind-up and the prime drop; a placed Nightwell keeps going | `merge hold: ...`, `merge: a merge doesn't take the placed well down` |
| Nightwell, then Seed on the middle, then pop | everyone caught sits stunned at the centre for the seed to grow on them | `ult open: ...`, `ult: the caught foe is drawn to the middle` |
| Nightwell, then anything | he is locked in the cast for the 1.0s dome, then free (walking out at full speed, casting) while the well runs; a stun or a knock frees him early | `lock: ...`, `release: ...` (ult check) |
| Shard Snap timing | the press, a 0.32s wind-up, the release, the flight; the damage on the impact | `item 40: ...` |
| Trade in flight, then any ability (item 32) | the Trade's flight is his dash for DashFlow (`in_dash`); LMB, RMB, E, X and the glove fire mid-flight, ground or air (content/dash_flow/ostra.json, docs/heroes/dash_interactions.md); Shift during the Nightwell's dome is refused, or held for the step it opens and frees him when pressed in its last 0.15s | `--dash-flow-check`, `dash flow: ...` (ult check) |
| Trade, ground or air | his own dash move each (`ostra_swap`, `ostra_swap_air`), ids no other hero uses, inside the 1.25s Swollen Trade | `item 35: ...` |
| Swollen, then Nightwell | the bigger 5.1m well | `ult Swollen: ...` |
| Nightwell, then the merge | the target lives (burst cap) | `ult burst: the well, merge and its ultimate leave a full-health light hunter standing` |

## Data pass (SERVER_UPDATE7, owner's tooltip data)
Conversions: damage by the ratio to the orb (9 for the data's 263): Snap 277 -> 9.5, full orb 353 -> +34%, Swollen Snap 399 ->
+44%, the seed 365 -> 12.5, its damage over time 250 a second -> 8.2. Durations and cooldowns match directly: Snap 10s, Trade
9.5s, seed 10s. Speed bursts as a share of the data's 465: +50 -> 10.8%, +100 -> 21.5%. The ally shield by health: 375 of a
2074-hp hunter (level 15) -> 26 of 145.
- Done: the pop no longer Grounds; the knock heal is gone; ground hazards pass him by (`incoming`; the lightning rod's sky
  strike still hits); Snap's speed bursts at rank 3 (the data's rank IV); the seed's burn at rank 3 is 8.2 a second and its
  cooldown is 10s -> 8s at rank 3 through the shared rank step (the data's -2s at rank IV).
- Kept, not in the data: the Snap's distance-scaled stun (the owner's note: RMB visibly stuns); the Trade's 1.8s (no number in the
  data).
- Not done: items in the swap circle (the data says "all
  units"; pickups are each game's own copies); an ice patch's slide still takes him (ground grip is not his to change).
- Rank paths that do not fit: the data's Snap +20% damage at ranks 2 and 3, the seed's +10% each and the Trade's -1.5s twice go
  through the shared rank step (+15%/+30% damage, -10%/-20% cooldown on RMB and E, -15%/-30% recharge on the dash).

## Small mechanics
| Mechanic | Source | Footage | Ours |
|---|---|---|---|
| The orb charge is binary (charged or not), since 05.02.25 | patch notes, wiki | no | changed by the owner (item 60): a continuous build-up over the same 1.4s window |
| Charged orb: faster, slows 10% for 1.5s | wiki | yes (SLOWED) | built |
| Charged orb passes through terrain | wiki, owner's data | no | not built (our shots stop on terrain; a pierce would read as a bug on our islands) |
| Snap slows Void while casting (25% less since Jan 2025) | patch notes | no | built: 25% slower during the 0.32s wind-up and the 0.15s recovery |
| Snap stun grows with distance | wiki, card | yes | built 0.8-1.8s |
| Swap swaps whoever is at the destination; they go to the origin | wiki | partly (0193 is ambiguous) | built, allies included ("any units") |
| Swap travel 1.7s, 1.25s Empowered | wiki | yes (about 1.8s) | built |
| Over the abyss he hovers and keeps his previous momentum; Swap preserves momentum | wiki | no | changed by the owner's notes: he hovers (no momentum) while the lantern flies, drifting at 30% speed (item 75; was 20%; 25-35% band, no source value in the data) with his height held; the origin is where he is when it resolves (default; the source doesn't say), so the drift matters |
| Level 4: allies (and wisps) entering the outgoing zone get a shield | wiki, patch Jan 2025 | no | built: allies beside him when he leaves or at the landing |
| Anomaly grows 6.5s, up to 3.5x; recast to detonate | wiki | yes | built, recast from 0.3s (sheet) |
| Empowered builds 10x faster on hunters; +30% Singularity size; knock heals | wiki | | built (Swollen); Swollen seed +30% size; the knock heal is removed (the owner's tooltip data has none) |
| Black Hole stuns and pulls enemies to its centre for 3.5s, small damage every 0.1s | card, wiki | yes (ult f33-f66) | built on X; asserted `ult open`, `drawn to the middle`, `small ticks` |
| A dome telegraph of the final size before it opens | footage | yes (f23-f32, 1.0s) | built, everyone sees it; asserted |
| Enemies who enter during the 3.5s are caught too ("for 3.5s") | card | no | built; asserted `a foe who walks in later is caught too` |
| Empowered: radius 350 -> 500 (and a June patch made Empowered really enlarge it) | card, patch notes (June 25) | yes (f89-f101) | built: 3.6m -> 5.1m when cast Swollen; asserted |
| Void is held for the cast, then acts freely while it holds | footage | yes (f23-f33 cast, f50 shooting) | built (owner 18:20, replacing item 16's full lock): locked for the 1.0s dome, free once it opens; asserted `lock: ...`, `release: ...` |
| Allies unaffected; it never breaks allied destructibles (patch) | sheet, patch notes (June 25) | | built: foes only; it hurts no walls at all |
| Empowered damage is Explosive (175 a tick to destructibles) | wiki | no | not built: our destructibles are walls that take shot damage; a well tick is not a shot (owner question) |
| It closes with no explosion | footage | yes (f66) | built |

## Assumptions (easy to change in content/archetypes/ostra.json)
- Shift is hold-to-aim, release-to-cast (a tap casts at once): the source shows the landing ring before the press, and this
  is the only way a keyboard player sees it; it also removes any chance of a stray dash.
- With no dash charge, or pressed in the air, Shift never falls back to the long base dash (owner note). So he has no base dash
  variant; his Trade's lob and arrival are his dash moves.
- Brimseed waits at full size for the recast (the data: "reactivate to detonate"); 10s unpopped at full it fizzles with no damage (ours, so it can't be parked forever).
- Trade: loose items on the ground are not traded. Pickups are each game's own copies; moving them on one game would leave
  the others disagreeing. Boki riding a shoulder (or benched) stay with their hunter.
- Trade: the bodies keep their offset from the circle's centre at his origin; one that would land on the abyss or a step
  over 1.5m goes to his exact spot instead.
- Body, idle, jumps (not in the footage, built from his character): the hover-glide above; idle is the hover bob with the
  hem drifting; a jump keeps the hover (no landing squash beyond the shared small one); his only "air dash" is the Trade
  (cast in the air it plays his own sling-and-drift move, `ostra_swap_air`; the footage shows no air cast, and the
  sheet's build note asks for a smooth drift with no tumble and the hem streaming), and any dash he does get (a merge's dodge) leaves a streak of violet motes instead of the shared pill.
- Swollen lasts 9s and fills as before (the source does not show what fills it).
- Snap range 13m; the orb's range stays 14m.
- Nightwell range 10m (the footage only shows a 2-3 bh cast), placed like the seed: on ground short of walls.
- A foe behind a wall from the well's centre is not caught (the source doesn't show one).
- A caught foe is stunned until the well closes, without stun diminishing returns (it is the ult; the card says 3.5s).
- Ticks: 0.16 every 0.1s (the source's 2.5 a tick against a 140 orb, scaled to our 9 orb).
- The well stays when Motley is knocked or merges; it is a placed thing, and he is free during it.
- Bond: paid when a hunter is caught (a hit), topped up if one is knocked or killed inside it; never per tick. The sheet's
  0.4 per hunter capped at 0.8 is the main session's to set (KinBond.from_ult).

## Animation moves (KMovesStone)
| Ability | Moves | Strip |
|---|---|---|
| LMB orb, full-charge orb | `ostra_orb`, `ostra_orb_hot` | `--arena-demo=anim_os_orb`, `anim_os_orb_hot` |
| RMB | `ostra_snap_wind` (hold), `ostra_snap` | `anim_os_snap` |
| Shift (his dash, item 35) | `ostra_swap_aim` (hold), `ostra_swap` (ground: the underhand lob, 0.85s), `ostra_swap_air` (air: an overhead sling, then a leaning drift with the hands and hem trailing, swaying, held until he arrives; 0.45s to the drift), `ostra_arrive` | `anim_os_swap`, `anim_os_swap_air`, `anim_os_arrive` |
| E | `ostra_seed`, `ostra_pop` | `anim_os_seed`, `anim_os_pop` |
| Passive proc | `ostra_empower` | `anim_os_empower` |
| X | `ostra_well` (wind-up, held), `ostra_well_snap` (held while it pulls), `ostra_well_end` | `anim_os_well` (`--strip-w=760` shows the dome and the well beside him) |

## Engine notes
- Kit `scripts/arch/kits/ostra_kit.gd`; looks `kit_looks.gd` (pooled skins, aura, stun crown, column); the seed's drum in
  HeroZones.seed_visual (shaders/void_glass.gdshader). Every shot goes through spawn_shot.
- Net: the seed travels as `["zone", ...]` events; Trade's moves go through Displace (`["disp", "tp", ...]`, decision 0016).
  Nightwell runs on the caster's game like the seed's pop: hits carry the stun, and every caught body (a player online on
  their own game) is drawn to the centre by a Displace "glide" tow.
- Nightwell: `scripts/arch/kits/ostra_well.gd` (OstraWell); its looks are pooled KitLooks kinds `well_dome` and `well`. It
  adds no hold field (nothing to drop on a merge).
