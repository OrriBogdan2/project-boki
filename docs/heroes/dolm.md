# Breah (archetype id `dolm`, Medium; was "Dolm")

Internal note: the behaviour reference is the hero named in the Inspired-by table in docs/ARCHETYPES.md. Nothing below is
player-facing; every name, number and word in the shipped game is our own (renames: Stonesight -> Tremor Sense, Landslide ->
Rubble Leap, Rockwave -> Stone Row; the hero Dolm -> Breah, owner, Nov 2026). Ids and file names stay `dolm`.

## Research summary
- Sources: the reference sheet from guide footage (briefs/hero-ref/breah.md, outside the repo), the reference hero's wiki page
  (https://supervive.wiki.gg/wiki/Tetra) and the full patch-note text from the Steam news feed (patches 1.01-2.04, 2025).
- Owner notes (sync61 playtest) override the footage: raised rocks give verticality (stand on them, climb them), punching
  rocks sends them flying, LMB is a hold.
- **Deliberate change from the source (owner dash note, Nov 2):** the source's Landslide is an odd short dash followed by a
  rock thrown at you. Ours is a **leap**: the rock bursts up under her, she leaps in an arc to the cursor, lands with a crash
  that shoves everyone beside her, and the rock comes down right after her and rolls on. Two hits (the landing, then the
  rock) read better than one.
- Copied: structure, timing ratios and interactions. Not copied: names, text, raw numbers, art, sound.

## Design
Weight Medium (145 hp). Fixed weapon Rubble Fists (`content/weapons/rubble_fists.json`): a huge basalt gauntlet on each fist,
with magma cracks (shaders/molten_rock.gdshader), knuckle studs and a hot core (scripts/match/hero_arms.gd); the gauntlets
ride her hands (HunterAnim's "fist" hold), so every move's arm reach shows. Body (content "body"): 0.97 tall, 1.2 wide (big
forearms and fists, a short wide read); the medium hitbox 0.40 is kept (the fists are not body). Palette ochre stone `#d9a35b`
with molten orange `#ff7a2a`. Payoff word ROCKFALL. Kit: `scripts/arch/kits/dolm_kit.gd`, the slam in `breah_slam.gd`,
looks in `kit_looks.gd`, standing on rocks in `scripts/arch/stone_stand.gd`, moves in `scripts/match/kmoves_stone.gd`,
sounds from `tools/gen_stone_sfx.py` (names in `scripts/core/sfx_kits.gd`).

## Scaling used (ratios from the source)
- Boulder 9 (source 169); a launched rock 14, about 1.5x the boulder (source 244 vs 169, 1.45x). Punch 12-24 (source 199).
- Quakefall 14-30, the sweet spot x1.2 (source 188 outer vs 225 centre), stun 0.5-1.2s by charge. RMB cooldown 9s equal to the
  dash's 9s (card 9 and 9). Full charge 1.4s (0.2s tap window + 1.2s; source 1.0-1.5s).
- Punch hold: full at 0.9s (source about 0.75s release), step 0.6m (source 0.5 bh). Rocks 45 hp, 9s.
- Scale: one body height (bh) is about 1.8m, for gameplay ranges and visuals alike: the punch lane 4.2 by 1.8m (2.5 by 1 bh),
  the slam a 2m hop ahead with a 3.6-4.5m radius (about 2.5 bh), the row 3.4m ahead (2 bh) spanning about 5m (3 bh).
- Rubble Leap: up to 5m in 0.45s in the kit numbers (2.5-3 bh in about 0.45s, the body study), with the global dash feel
  on top like every dash (x0.85 distance, x1.15 time: about 4.25m in 0.52s).

## Per-slot table
| Slot | Input | Aim and telegraph | What it does (ours) | Anim (KMovesStone) | Sound |
|---|---|---|---|---|---|
| Passive Tremor Sense | sneak (crouch) | a pale cone toward the cursor, 16m, 25 deg widening to 40 over 2s | foes in the cone show through walls and fog as a molten ring, refreshed every 0.5s | `breah_sense` on a find | `br_sense` |
| LMB tap: boulder | tap (under 0.28s) | the shared aim line; flies its full 11m (AimMode.MAX) | 9 dmg, a molten tumbling boulder with an ember trail; bursts with a red ground ring, splashing foes within 0.9m for half | `breah_throw` | `br_throw`, `br_boulder_hit` |
| LMB hold: punch | hold, release | from the hold: a pale lane 4.2m by 1.8m with 3 chevrons toward the cursor, filling; the cursor charge ring; the fist glows molten orange, hotter with the charge | 12-24 dmg to foes in the lane, knockback 6-11, a 0.6m step, a dust ring and molten spray at the lane's end on the hit; into a wall = 0.9s stun (stars); every rock of the team in the lane flies, and rocks lined up further along the aim (gaps up to 2.8m, to 12m) follow one after another, 0.08s apart. Held past full +0.5s it punches by itself and winds the next one | `breah_wind` (hold), `breah_punch` | `br_wind`, `br_punch`, `br_launch`, `br_burst` |
| RMB Quakefall | hold to charge, release | everyone sees a red circle a hop (2m) ahead, radius 3.6-4.5m, its sweet spot growing 0.9-1.8m; the cursor charge ring and full flare; both fists glow molten | release: a hop forward into the centre, then the slam: 14-30, centre x1.2 and stun 0.5-1.2s (stars), rocks in the ring fly outward, foes in the air are dunked (+40%, +20 over the abyss); a molten starburst, rock chips flying, a dust ring at the edge and a dark red cracked crater for 1s. While charging: walk at 55%, jump = leap 3.2m forward (circle comes along; let go in the air = slam on landing), a punch = a 1.5m lunge. A knock or kill resets it. In the air: dive and slam on landing | `breah_crouch` (hold), `breah_leap`, `breah_lunge`, `breah_slam`, `breah_dive`, `breah_slam_land` | `br_leap`, `br_shove`, `br_slam` |
| Shift Rubble Leap | tap | to the cursor (1.2m to about 4.25m); everyone sees the landing circle (1.8m) filling through the flight | the rock bursts up under her (0.06s crouch), she leaps in an arc to the spot (0.52s), lands with a crash: 8 dmg and a shove to everyone within 1.8m, then the rock comes down 0.14s after her and rolls on 6m: 12 dmg, Shred, 1.5s slow. In the air: the class long dash, her own heavy shove with a dust after-image | `breah_dash`, `breah_leap_land`, `breah_exdash` | `br_rise`, `br_leap`, `br_slam`, `br_roll`, `br_shove` |
| E Stone Row | tap | a 0.2s red-orange flash on the ground at each spot (everyone sees it) | three rocks of jagged basalt columns (tapered, broken tops, leaning apart) in a slight curve 3.4m ahead (outer two 0.45m back, 2.4m apart), thin molten cracks in the ground at their feet cooling over 0.6s; 9s, 45 hp; they block bodies and enemy shots; you stand on them and climb them with a jump; any punch, slam or dash-launch sends them flying | `breah_raise` | `br_crack`, `br_raise` |
| X Basalt Spine (level 6, 45s) | tap, or hold and drag, release | while X is held (yours only): a pale line 19.8m long with inward chevrons and a centre ring, at the cursor (up to 11m), across the aim; dragging the cursor 0.8m+ from the centre swings it round the centre toward the cursor. On release everyone sees molten cracks along it for 0.2s | 13 rocks of hers erupt from the centre outward over 0.4s with flame bursts: foes within 1.6m are slowed 35% for 1s (1 damage), bodies on the line are moved to their side of it. The rocks stand 7s, block foes and their shots, carry and climb like hers, and fly when punched, slammed or dashed into (a punch along the ridge sweeps it); one cast's rocks deal at most 40 to any one hunter. Over the abyss the line becomes a 2m walkway for 7s. A stun, knock or merge while aiming cancels it unspent | `breah_spine_aim` (hold), `breah_spine` | `br_spine` |
| Merge (the `ultimate` action; its key from Settings.key_cap) | (Boki Merge) | | | | |

Rank 3: Quakefall gives a Molten Guard shield of 18 per slam that catches something (up to 4 stacks, a gold ring); Rubble Leap
goes a third further; Stone Row raises an extra row of three behind the first (the source's "extra Rock Wall").

**Unfolded:** the kit pass had folded the source's Tetraform into Stone Row rank 3 (a centre-out second row that slowed, and a
bridge over the abyss). Now that Tetraform is Basalt Spine on X, those parts moved there and rank 3 is the source's plain
extra row again.

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
| Rubble Leap beside a foe | the landing crash shoves it, then the rock comes down after her and rolls into it (shred, slow) | `dash: the landing crash hits and shoves a foe beside the spot`, `dash: the rock comes down after her landing`, `dash: the rock rolls on from the landing and hits` |
| Rubble Leap shove, then slam | the crash pops the foe up, the slam dunks it while it is airborne | `dash: the landing crash ...`, `rmb: a foe in the air is dunked` |
| Two bursts on one foe | the second inside 0.8s deals 30% less | `small: a second burst on the same foe inside 0.8s deals 30% less` |
| Boulder into a pair | the one beside takes half | `small: the boulder's burst splashes the foe beside it` |
| Merge start | dive, charge, its leap, Rubble Leap, the Spine's aim and telegraphs all drop | `merge hold: ...` |
| Basalt Spine, then a punch along it | the whole ridge flies in a stream at whoever is down the line (40 cap per hunter), ROCKFALL | `ult combo: a punch along the ridge launches its rocks in a stream` |
| Basalt Spine across a fleeing foe | the foe is shoved to its side of the line and slowed; the ridge walls it off | `ult: a body on the line is shoved off it...`, `ult: the rise slows a foe beside it` |
| Basalt Spine over the abyss | a walkway along the line (a bridge or an escape) | `bridge (Basalt Spine): abyss tiles become ground` (`--zone-check`) |
| Basalt Spine, punch, then the merge | the target lives (burst cap) | `ult burst: ridge, punch, merge and its ultimate leave a full-health light hunter standing` |

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
| Tetraform: tap places it across the aim; hold and drag sets the angle | card (patch 1.01 notes), wiki | yes (ult f35-f44) | built on X; asserted `ult drag: ...` |
| Tetraform rocks spawn after a short delay, centre-out, and slow nearby foes | card, wiki | yes (ult f45-f55) | built: 0.2s cracks, 0.4s rise, 35% slow 1s; asserted `ult beats: ...`, `ult: the rise slows ...` |
| Tetraform over the abyss makes temporary terrain | card, wiki | yes (guide 161-169s) | built: a 2m walkway for the rocks' 7s |
| Tetraform can't be used to leave the arena bounds | patch 1.04 notes | no | built by placement: rocks only on legal ground (HeroZones.fits), the walkway only on abyss tiles |
| Punched Tetraform rocks launch like any rock (Rocksweeping) | card, guide | yes | built (the punch sweep takes ult rocks); asserted |
| Tetraform terrain lasts longer per rank (+2.5s at levels 2 and 3) | wiki | no | not built: our X has no ranks |
| Landslide rock shoves enemies toward the abyss (dunk setup) | footage tip "Dash -> RMB Dunk Combo" | yes (0965-1010) | built as the leap's landing crash (a shove with a lift) and the rock rolling on |
| Rock Molten Guard shield per rock fired (2.00 passive) | patch 2.00 notes | no | not built: our rank-3 slam shield covers the role |
| Landslide 2 charges from level 3 | patch 2.04 notes | no | not built (our dash charges come from the weight class) |

## Assumptions (the footage is silent; easy to change in content/archetypes/dolm.json)
- The tap boulder flies its full range rather than stopping at the cursor, and its burst splashes 0.9m for half damage.
- She can walk while charging Quakefall, at 55% speed.
- One punch-lunge per charge.
- Rocks last 9s (the footage only shows 5s or more).
- The KNOCK beam on the dunk is our DUNKED word plus a vertical light (a generic knock look in the source, it seems).
- Anyone (not only allies) can climb a rock; the owner asked for verticality, and enemies standing on her rocks is fair play.
- Rubble Leap (the owner's leap, see Research summary): the landing crash deals 8 and shoves within 1.8m; the rock comes
  down 0.14s after her landing, just ahead of her, and rolls on 6m. It lands at the cursor, pulled back to the nearest ground
  a body fits on (it never leaps her into the abyss or a wall). In the air Shift stays the class long dash.
- Body, plain jumps, idle (not in the footage, built from her character): a short, wide brawler (0.97 tall, 1.2 wide) who
  stomps (a small dip on each step, no bounce), carries both fists low and forward when running and standing, breathes
  slowly (1.6), and lands every jump with the shared heavy squash. Her air dash (the class long dash) is a heavy shove with
  a dust and ember after-image instead of the shared pill.
- Basalt Spine: the drag sets the ridge along the line from its centre to the cursor (the footage shows the preview pivoting
  as the cursor swings, not which axis it follows).
- Basalt Spine rocks stand 7s (the footage shows at least 5-6s); the slow is 35% for 1s ("brief"), carried by a 1-damage hit.
- A body on the ridge's line is moved to its own side instead of leaving a gap (the source never shows one).
- One cast's rocks deal at most 40 to any one hunter (Shred included): our burst rule (an ult straight into a merge must not
  kill a full-health light hunter), not a source number. Without it a full ridge punched down a lane does about 80+.
- A stun, knock or merge while aiming cancels the cast and refunds it.
- Bond: the source sheet suggests 0.3 per slowed hunter and +0.15 per rock hit, capped at 0.8. The amounts are the main
  session's (KinBond.from_ult kinds hit/knock/kill, best event per cast), so a slowed hunter or a ridge rock hit inside 4s of
  the rise counts as a land of the matching kind.

## Animation moves (KMovesStone)
| Ability | Moves | Strip |
|---|---|---|
| LMB tap | `breah_throw` | `--arena-demo=anim_br_throw` |
| LMB hold, release | `breah_wind` (hold), `breah_punch` | `anim_br_punch` |
| RMB charge, leap, lunge, release, dive | `breah_crouch` (hold), `breah_leap`, `breah_lunge`, `breah_slam`, `breah_dive`, `breah_slam_land` | `anim_br_slam`, `anim_br_leap`, `anim_br_lunge`, `anim_br_dive` |
| Shift (the leap and its landing), the long air dash | `breah_dash`, `breah_leap_land`, `breah_exdash` | `anim_br_dash`, `anim_br_exdash` |
| E | `breah_raise` | `anim_br_raise` |
| X | `breah_spine_aim` (hold), `breah_spine` | `anim_br_spine` |
| Passive find | `breah_sense` | `anim_br_sense` |

## Engine notes
- Rocks are Verbs walls with `top` 1.25m and `th` 0.42 (HeroZones.rock). Verbs.wall_blocks lets feet at the top walk over a
  wall with a `top`; Ent.ground reads StoneStand.top_under; Hunter's move step calls StoneStand.climb (one line).
- Every projectile is an ordinary Match shot (spawn_shot), so the height rules and Net behave as for every shot; KitLooks only
  replaces the shared sphere with a pooled skin.
- Net is unchanged: rocks still travel as `["zone", ...]` events (the Spine's too, and its walkway as a `"bridge"` event);
  `top` is a constant.
- Basalt Spine: `scripts/arch/kits/breah_spine.gd` (BreahSpine). Its hold field is `phase == "aim"`, cleared by
  `DolmKit._drop_holds()` through `spine.drop()`. Main sends only the X press, so BreahSpine._held() reads the local key (tests hold it with `inp["x_down"]`).
