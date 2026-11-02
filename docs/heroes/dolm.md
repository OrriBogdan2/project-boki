# Breah (archetype id `dolm`, Medium; was "Dolm")

Internal note: the behaviour reference is the hero named in the Inspired-by table in docs/ARCHETYPES.md. Nothing below is
player-facing; every name, number and word in the shipped game is our own (renames: Stonesight -> Tremor Sense, Landslide ->
Rubble Rush, Rockwave -> Stone Row; the hero Dolm -> Breah, owner, Nov 2026). Ids and file names stay `dolm`.

## Research summary
- Sources: the reference sheet from guide footage (briefs/hero-ref/breah.md, outside the repo), the reference hero's wiki page
  (https://supervive.wiki.gg/wiki/Tetra) and the full patch-note text from the Steam news feed (patches 1.01-2.04, 2025).
- Owner notes (sync61 playtest) override the footage: raised rocks give verticality (stand on them, climb them), punching
  rocks sends them flying, LMB is a hold.
- Copied: structure, timing ratios and interactions. Not copied: names, text, raw numbers, art, sound.

## Design
Weight Medium (145 hp). Fixed weapon Rubble Fists (`content/weapons/rubble_fists.json`): one huge basalt gauntlet with magma
cracks (shaders/molten_rock.gdshader), knuckle studs, a hot core (scripts/match/hero_arms.gd). Palette ochre stone `#d9a35b`
with molten orange `#ff7a2a`. Payoff word ROCKFALL. Kit: `scripts/arch/kits/dolm_kit.gd`, the slam in `breah_slam.gd`,
looks in `kit_looks.gd`, standing on rocks in `scripts/arch/stone_stand.gd`, moves in `scripts/match/kmoves_stone.gd`,
sounds from `tools/gen_stone_sfx.py` (names in `scripts/core/sfx_kits.gd`).

## Scaling used (ratios from the source)
- Boulder 9 (source 169); a launched rock 14, about 1.5x the boulder (source 244 vs 169, 1.45x). Punch 12-24 (source 199).
- Quakefall 14-30, the sweet spot x1.2 (source 188 outer vs 225 centre), stun 0.5-1.2s by charge. RMB cooldown 9s equal to the
  dash's 9s (card 9 and 9). Full charge 1.4s (0.2s tap window + 1.2s; source 1.0-1.5s).
- Punch hold: full at 0.9s (source about 0.75s release), step 0.6m (source 0.5 bh). Rocks 45 hp, 9s.
- Scale: the sheet's bh is read as about 1.8m for the visuals (AimKit.BH) and as the sheet's metre figures for gameplay ranges
  (its gap list gives metres: lane 3.2 by 1.4m, slam reach 1.3m, row 2.2m ahead).

## Per-slot table
| Slot | Input | Aim and telegraph | What it does (ours) | Anim (KMovesStone) | Sound |
|---|---|---|---|---|---|
| Passive Tremor Sense | sneak (crouch) | a pale cone toward the cursor, 16m, 25 deg widening to 40 over 2s | foes in the cone show through walls and fog as a molten ring, refreshed every 0.5s | `breah_sense` on a find | `br_sense` |
| LMB tap: boulder | tap (under 0.28s) | the shared aim line; flies its full 11m (AimMode.MAX) | 9 dmg, a molten tumbling boulder with an ember trail; bursts with a red ground ring, splashing foes within 0.9m for half | `breah_throw` | `br_throw`, `br_boulder_hit` |
| LMB hold: punch | hold, release | from the hold: a pale lane 3.2m by 1.4m with 3 chevrons toward the cursor, filling; the cursor charge ring; the fists glow | 12-24 dmg to foes in the lane, knockback 6-11, a 0.6m step; into a wall = 0.9s stun (stars); every rock of the team in the lane flies, and rocks lined up further along the aim (gaps up to 2.2m, to 12m) follow one after another, 0.08s apart. Held past full +0.5s it punches by itself and winds the next one | `breah_wind` (hold), `breah_punch` | `br_wind`, `br_punch`, `br_launch`, `br_burst` |
| RMB Quakefall | hold to charge, release | everyone sees a red circle a hop (1.3m) ahead, radius 2.3-3.0m, its sweet spot growing 0.9-1.8m; the cursor charge ring and full flare | release: a hop forward into the centre, then the slam: 14-30, centre x1.2 and stun 0.5-1.2s (stars), rocks in the ring fly outward, foes in the air are dunked (+40%, +20 over the abyss), a 1s scorched crater. While charging: walk at 55%, jump = leap 3.2m forward (circle comes along; let go in the air = slam on landing), a punch = a 1.5m lunge. A knock or kill resets it. In the air: dive and slam on landing | `breah_crouch` (hold), `breah_leap`, `breah_lunge`, `breah_slam`, `breah_dive`, `breah_slam_land` | `br_leap`, `br_shove`, `br_slam` |
| Shift Rubble Rush | tap | toward the cursor | a rock bursts up in front, rides ahead through the 4.2m barrel shoving whoever it meets (kb 8), then rolls on 6m: 12 dmg, Shred, 1.5s slow. The long air dash is her own heavy shove | `breah_dash`, `breah_exdash` | `br_rise`, `br_roll`, `br_shove` |
| E Stone Row | tap | a 0.2s red-orange flash on the ground at each spot (everyone sees it) | three basalt-column rocks in a slight curve 2.2m ahead (outer two 0.3m back), 9s, 45 hp; they block bodies and enemy shots; you stand on them and climb them with a jump; any punch, slam or dash-launch sends them flying | `breah_raise` | `br_crack`, `br_raise` |
| R | (Boki Merge) | | the source's Tetraform is folded into Stone Row rank 3 | | |

Rank 3: Quakefall gives a Molten Guard shield of 18 per slam that catches something (up to 4 stacks, a gold ring); Rubble Rush
runs a third further; Stone Row raises a second row that erupts from its centre outward (0.1s apart) and slows foes within
1.5m, and aimed over the abyss raises a temporary bridge.

## Combinations (`--dolm-combo-check`, tools/breah_combo_check.gd; placement in `--zone-check`)
| Combo | Result | Asserted by |
|---|---|---|
| Stone Row, then punch along it | every rock flies in a stream (first at once, the rest 0.08s apart), bursts, shreds, slows, ROCKFALL | `combo: a punch along a row launches every rock in a stream`, `combo: launched rocks burst on the foe...` |
| Stone Row, then slam | rocks in the ring fly outward | `combo: Stone Row > slam launches the rocks` |
| Stone Row, then jump into a rock | she climbs on top and stands there | `rock: jump into a rock and you climb onto it`, `rock: dropped onto a rock, she stands on its top` |
| Punch into a wall | 0.9s stun with stars | `combo: punch into a wall = stun, with stars over the head` |
| Charge, jump, let go | leap forward with the circle, slam on landing | `rmb: jump while charging leaps her forward`, `rmb: the circle comes with her`, `rmb: let go mid-leap = slam where she lands` |
| Charge, punch | a lunge forward, no punch | `small: a punch during the charge lunges her forward` |
| Slam that knocks or kills | Quakefall resets | `combo: a slam that knocks resets Quakefall` |
| Rubble Rush into a foe, then slam | the rock shoves the foe ahead (toward the abyss), the slam dunks it if airborne | `small: the rock shoves a foe in its path during the dash`, `rmb: a foe in the air is dunked` |
| Two bursts on one foe | the second inside 0.8s deals 30% less | `small: a second burst on the same foe inside 0.8s deals 30% less` |
| Boulder into a pair | the one beside takes half | `small: the boulder's burst splashes the foe beside it` |
| Merge start | dive, charge, leap, carried rock and telegraphs all drop | `merge hold: ...` |

## Small mechanics
| Mechanic | Source | Footage | Ours |
|---|---|---|---|
| Punched rocks explode, slow (0.8s) and shred armour | patch 2.00 notes (Steam news feed, appid 1283700) | yes (fireballs on the dummy) | built: 0.8s slow, Shred +15% |
| Repeat rock explosions on one target within 0.8s deal 30% less | patch 2.00 notes | no | built (`repeat_t`, `repeat_k`) |
| Mid-air LMB carries momentum, with a penalty (air impulse penalty 15% -> 50%) | patch 2.00 notes | no | built: the punch step in the air is half as long |
| Punch cooldown starts at cast, not on release | patch 2.01 / 2.04 notes | no | built (`fire_cd` set when the punch fires) |
| A flick tech hit several enemies in an arc; removed | patch 1.03 notes | no | not built: the punch is a narrow lane |
| Jump while charging leaps forward | wiki (Volcano Crusher) | yes (frames 0938-0958) | built |
| Punch to extend the charge | footage tip title "Punch to Extend Dash/RMB" | yes | built (one lunge per charge) |
| Slam resets on knock or kill | wiki | yes | built |
| Allies hop over friendly rock walls by jumping against them | wiki (Rockwave), patch 1.01 | no | built more broadly: anyone can climb a rock with a jump and stand on it (owner note) |
| Rocks spawn centre-out and slow nearby foes (Tetraform) | wiki | yes (0583-0587) | built on the rank-3 second row |
| Landslide rock shoves enemies toward the abyss (dunk setup) | footage tip "Dash -> RMB Dunk Combo" | yes (0965-1010) | built (the carried rock shoves) |
| Rock Molten Guard shield per rock fired (2.00 passive) | patch 2.00 notes | no | not built: our rank-3 slam shield covers the role |
| Landslide 2 charges from level 3 | patch 2.04 notes | no | not built (our dash charges come from the weight class) |

## Assumptions (the footage is silent; easy to change in content/archetypes/dolm.json)
- The tap boulder flies its full range rather than stopping at the cursor, and its burst splashes 0.9m for half damage.
- She can walk while charging Quakefall, at 55% speed.
- One punch-lunge per charge.
- Rocks last 9s (the footage only shows 5s or more).
- The KNOCK beam on the dunk is our DUNKED word plus a vertical light (a generic knock look in the source, it seems).
- Anyone (not only allies) can climb a rock; the owner asked for verticality, and enemies standing on her rocks is fair play.
- Landslide's carried rock deals 2 damage on the shove (the source shows no number before the launch).

## Animation moves (KMovesStone)
| Ability | Moves | Strip |
|---|---|---|
| LMB tap | `breah_throw` | `--arena-demo=anim_br_throw` |
| LMB hold, release | `breah_wind` (hold), `breah_punch` | `anim_br_punch` |
| RMB charge, leap, lunge, release, dive | `breah_crouch` (hold), `breah_leap`, `breah_lunge`, `breah_slam`, `breah_dive`, `breah_slam_land` | `anim_br_slam`, `anim_br_leap`, `anim_br_lunge`, `anim_br_dive` |
| Shift, the long air dash | `breah_dash`, `breah_exdash` | `anim_br_dash`, `anim_br_exdash` |
| E | `breah_raise` | `anim_br_raise` |
| Passive find | `breah_sense` | `anim_br_sense` |

## Engine notes
- Rocks are Verbs walls with `top` 1.25m and `th` 0.42 (HeroZones.rock). Verbs.wall_blocks lets feet at the top walk over a
  wall with a `top`; Ent.ground reads StoneStand.top_under; Hunter's move step calls StoneStand.climb (one line).
- Every projectile is an ordinary Match shot (spawn_shot), so the height rules and Net behave as for every shot; KitLooks only
  replaces the shared sphere with a pooled skin.
- Net is unchanged (0.15.0): rocks still travel as `["zone", ...]` events; `top` is a constant.
