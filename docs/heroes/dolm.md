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
- Quakefall 14-30, the sweet spot x1.2 (source 188 outer vs 225 centre), stun 0.5-1.2s by charge. RMB cooldown 9s (source 11s, ratio 0.82; the
  dash is 12s as in the source, no longer equal to it). Full charge 1.4s (0.2s tap window + 1.2s; source 1.0-1.5s).
- Punch hold: full at 0.9s (source about 0.75s release), step 0.6m (source 0.5 bh). Rocks 45 hp, 9s.
- Scale: one body height (bh) is about 1.8m, for gameplay ranges and visuals alike: the punch lane 4.2 by 1.8m (2.5 by 1 bh),
  the slam a 2m hop ahead with a 3.6-4.5m radius (about 2.5 bh), the row 3.4m ahead (2 bh) spanning about 5m (3 bh).
- Rubble Leap: up to 5m in 0.45s in the kit numbers (2.5-3 bh in about 0.45s, the body study), with the global dash feel
  on top like every dash (x0.85 distance, x1.15 time: about 4.25m in 0.52s).

## Per-slot table
| Slot | Input | Aim and telegraph | What it does (ours) | Anim (KMovesStone) | Sound |
|---|---|---|---|---|---|
| Passive Molten Guard | punch | a gold ring under her | a punch that sends any of her rocks flying (Stone Row, Basalt Spine or a leap's rock in the lane) gives a shield stack of 18, up to 4, 6s; one stack per punch whatever the number of rocks | none | none |
| Passive Tremor Sense | sneak (crouch) | a pale cone toward the cursor, 16m, 25 deg widening to 40 over 2s | foes in the cone show through walls and fog as a molten ring, refreshed every 0.5s | `breah_sense` on a find | `br_sense` |
| LMB tap: boulder | tap (under 0.28s) | the shared aim line; flies its full 11m (AimMode.MAX) | 9 dmg, a molten tumbling boulder with an ember trail; bursts with a red ground ring, splashing foes within 0.9m for half | `breah_throw` | `br_throw`, `br_boulder_hit` |
| LMB hold: punch | hold, release | from the hold: a pale lane 4.2m by 1.8m with 3 chevrons toward the cursor, filling; the cursor charge ring; the fist glows molten orange, hotter with the charge | 12-24 dmg to foes in the lane, knockback 6-11, a 0.6m step, a dust ring and molten spray at the lane's end on the hit; into a wall = 0.9s stun (stars); every rock of the team in the lane flies, and rocks lined up further along the aim (gaps up to 2.8m, to 12m) follow one after another, 0.08s apart. Held past full +0.5s it punches by itself and winds the next one | `breah_wind` (hold), `breah_punch` | `br_wind`, `br_punch`, `br_launch`, `br_burst` |
| RMB Quakefall | hold to charge, release | everyone sees a red circle a hop (2m) ahead, radius 3.6-4.5m, its sweet spot growing 0.9-1.8m; the cursor charge ring and full flare; both fists glow molten | release: a short hop (a real 0.35s jump arc, about 2m: 1.1 body heights, 0.4m up) into the centre, then the slam as she lands: 14-30, centre x1.2 and stun 0.5-1.2s (stars), rocks in the ring fly outward, foes in the air are dunked (+40%, +20 over the abyss); a molten starburst, rock chips flying, a dust ring at the edge and a dark red cracked crater for 1s. While charging: walk at 55%, jump = a real leap 3.2m forward, about 1.2m up (circle comes along; let go in the air = the arc carries on, slam on landing), a punch = a 1.5m lunge. In the air: dive and slam on landing. The hop and the leap are real jump arcs (not dashes, which hold your height), so glide works out of them: opening or holding the glider drops the pending slam and the glider takes over, never dragged down | `breah_crouch` (hold), `breah_leap`, `breah_lunge`, `breah_slam`, `breah_dive`, `breah_slam_land` | `br_leap`, `br_shove`, `br_slam` |
| Shift Rubble Leap | tap | to the cursor (1.2m to about 4.25m); everyone sees the landing circle (1.8m) filling through the flight | the rock bursts up under her (0.06s crouch), she leaps in an arc to the spot (0.52s), lands with a crash (dust, no ring or blast): 8 dmg and a shove to everyone within 1.8m, then the rock comes down 0.14s after her and rolls on 6m: 12 dmg, Shred, 1.5s slow. In the air: the class long dash, her own heavy shove with a dust after-image | `breah_dash`, `breah_leap_land`, `breah_exdash` | `br_rise`, `br_leap`, `br_slam`, `br_roll`, `br_shove` |
| E Stone Row | tap | a 0.2s red-orange flash on the ground at each spot (everyone sees it) | three rocks of jagged basalt columns (tapered, broken tops, leaning apart) in a slight curve 3.4m ahead (outer two 0.45m back, 2.4m apart), thin molten cracks in the ground at their feet cooling over 0.6s; 9s, 45 hp; they block bodies and enemy shots; only she climbs them (walking into one lifts her onto it, no jump) and stands on them; any punch, slam or dash-launch sends them flying | `breah_raise` | `br_crack`, `br_raise` |
| X Basalt Spine (level 6, 45s) | tap, or hold and drag, release | while X is held (yours only): a pale line 19.8m long with inward chevrons and a centre ring, at the cursor (up to 11m), across the aim; dragging the cursor 0.8m+ from the centre swings it round the centre toward the cursor. On release everyone sees molten cracks along it for 0.2s | 13 rocks of hers erupt from the centre outward over 0.4s with flame bursts: foes within 1.6m are slowed 35% for 1s (1 damage), bodies on the line are moved to their side of it. The rocks stand 7s, block foes and their shots, carry and climb like hers, and fly when punched, slammed or dashed into (a punch along the ridge sweeps it); one cast's rocks deal at most 40 to any one hunter. They are Stone Row's own rocks (same length, top and thickness), lying along the line, one rock deep. Only solid ground takes a rock: the line is clipped where it crosses the abyss (it never calls HeroZones.bridge), and a line with no ground under it is refused with a small "No ground for the ridge" note and a puff of grit, unspent. A stun, knock or merge while aiming cancels it unspent | `breah_spine_aim` (hold), `breah_spine` | `br_spine` |
| Merge (the `ultimate` action; its key from Settings.key_cap) | (Boki Merge) | | | | |

Rank 3: Quakefall gives a Molten Guard stack (18, the same stacks the punch gives, up to 4, a gold ring) per slam that catches
something; Rubble Leap takes a second charge and goes a third further; Stone Row raises an extra row of three behind the first (the source's "extra Rock Wall").

**Unfolded:** the kit pass had folded the source's Tetraform into Stone Row rank 3 (a centre-out second row that slowed, and a
bridge over the abyss). Now that Tetraform is Basalt Spine on X, the row moved there and rank 3 is the source's plain extra
row again. The bridge is gone altogether (owner review item 15: no terrain over the abyss from her ult).

## Quakefall review (owner review item 14, Nov 3)
- **Before:** the hop was the shared dash motion (2m in 0.15s, 13 m/s, height held flat), so the release read as a quick
  lunge forward, the same family of motion as the dash; the charge leap was the same flat dash (3.2m in 0.32s, never
  left the ground). Quakefall has never raised a rock: the slam only throws rock chips (the flying lumps of the impact
  look) and launches rocks already standing in the ring. The rock the owner saw is most likely those chips plus the flat
  lunge, or Rubble Leap's rock (Shift).
- **Source (Tetra's Volcano Crusher):** hold to charge, a short hop forward (about 1-1.5 bh) into a circular slam,
  centre stun, the sweet spot grows with the charge, jump while charging for a longer forward leap. No rock.
- **Now:** the release is a short hop, a real jump arc of 0.35s (about 2m, 1.1 bh, 0.4m up) with a dust kick at the
  push-off; the slam lands as she does (`breah_slam` re-timed: push-off 0.05, fists high behind the head at the top
  0.16, swung down 0.28, the smash on landing 0.35, low in the crater to 0.7, up by 1.2). The charge leap is a real
  jump (about 3.2m, 1.2m up). Nothing in Quakefall makes a rock. Sweet spot 0.9-1.8m by charge, only it stuns.
- **Game data items:** Molten Guard as the base passive and no slam reset were already done by the data pass
  (asserted there); the charge leap is now a real leap.
- Asserted (`--dolm-combo-check`): `rmb (item 14): let go = a short hop...`, `anim (item 14): breah_slam smashes down...`,
  `rmb (item 14): no rock comes from Quakefall`, `rmb (item 14): the tap's slam raises no rock either`,
  `rmb (item 14): only the sweet spot stuns...`, `rmb: jump while charging is a real leap, longer than the hop...`.
  Strip: /home/boki/shots-s2/breah/review/breah_rmb_strip.png (`--breah-shots`, tools/breah_shots.gd).

## Combinations (`--dolm-combo-check`, tools/breah_combo_check.gd; placement in `--zone-check`)
| Combo | Result | Asserted by |
|---|---|---|
| Stone Row, then punch along it | every rock flies in a stream (first at once, the rest 0.08s apart), bursts, shreds, slows, ROCKFALL | `combo: a punch along a row launches every rock in a stream`, `combo: launched rocks burst on the foe...` |
| Stone Row, then slam | rocks in the ring fly outward | `combo: Stone Row > slam launches the rocks` |
| Stone Row, then walk into a rock | she rises onto it and walks over (0.53s to cross, no jump); anyone else is stopped | `rock (item 25): walking into her own rock lifts her...`, `rock (item 25): an ally / a foe walking or jumping into her rock is stopped`, `rock: dropped onto a rock, she stands on its top` |
| Punch into a wall | 0.9s stun with stars | `combo: punch into a wall = stun, with stars over the head` |
| Charge, jump, let go | a real leap forward with the circle, slam on landing | `rmb: jump while charging is a real leap...`, `rmb: the circle comes with her`, `rmb: let go mid-leap = the leap's arc carries on...` |
| Quakefall (hop, leap or air press), then glide | the glider opens and the slam is dropped; she keeps her height (item 26) | `glide (item 26, hop/leap/air): ...` |
| Charge, punch | a lunge forward, no punch | `small: a punch during the charge lunges her forward` |
| Slam that knocks or kills | nothing: Quakefall has no reset (data pass) | `data: a slam that knocks does not reset Quakefall` |
| Rubble Leap beside a foe | the landing crash shoves it, then the rock comes down after her and rolls into it (shred, slow) | `dash: the landing crash hits and shoves a foe beside the spot`, `dash: the rock comes down after her landing`, `dash: the rock rolls on from the landing and hits` |
| Rubble Leap shove, then slam | the crash pops the foe up, the slam dunks it while it is airborne | `dash: the landing crash ...`, `rmb: a foe in the air is dunked` |
| Two bursts on one foe | the second inside 0.8s deals 30% less | `small: a second burst on the same foe inside 0.8s deals 30% less` |
| Boulder into a pair | the one beside takes half | `small: the boulder's burst splashes the foe beside it` |
| Merge start | dive, charge, its leap, Rubble Leap, the Spine's aim and telegraphs all drop | `merge hold: ...` |
| Basalt Spine, then a punch along it | the whole ridge flies in a stream at whoever is down the line (40 cap per hunter), ROCKFALL | `ult combo: a punch along the ridge launches its rocks in a stream` |
| Basalt Spine across a fleeing foe | the foe is shoved to its side of the line and slowed; the ridge walls it off | `ult: a body on the line is shoved off it...`, `ult: the rise slows a foe beside it` |
| Basalt Spine over the abyss | rocks on the banks only, clipped at the edges; no walkway; a line fully over the abyss is refused | `spine (item 15): over the abyss no walkway...`, `spine (item 15): the line is clipped...` (`--zone-check`), `spine (item 15): a cast fully over the abyss is refused...` |
| Basalt Spine, punch, then the merge | the target lives (burst cap) | `ult burst: ridge, punch, merge and its ultimate leave a full-health light hunter standing` |
| Quake Fist charge, then her air dash (item 51) | the charge carries through and charges on (short of the auto punch); let go in it and she punches as it ends, in the air, the step bending the speed she carries instead of replacing it | `item 51: the Quake Fist charge carries through her air dash...`, `item 51: let go in the air dash...` |

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
| Slam resets on knock or kill | wiki | yes | removed in the data pass: the owner's tooltip data has no reset |
| Allies hop over friendly rock walls by jumping against them | wiki (Rockwave), patch 1.01 | no | not built: the owner wants only the rock's own caster to climb it (review item 25 overrides the source and the data pass's ally climb); allies and foes are stopped, walking or jumping |
| Tetraform: tap places it across the aim; hold and drag sets the angle | card (patch 1.01 notes), wiki | yes (ult f35-f44) | built on X; asserted `ult drag: ...` |
| Tetraform rocks spawn after a short delay, centre-out, and slow nearby foes | card, wiki | yes (ult f45-f55) | built: 0.2s cracks, 0.4s rise, 35% slow 1s; asserted `ult beats: ...`, `ult: the rise slows ...` |
| Tetraform over the abyss makes temporary terrain | card, wiki | yes (guide 161-169s) | not built: the owner wants rocks only, never land over the abyss (review item 15); the line is clipped at the edges |
| Tetraform can't be used to leave the arena bounds | patch 1.04 notes | no | built by placement: rocks only on legal ground (HeroZones.fits) |
| Punched Tetraform rocks launch like any rock (Rocksweeping) | card, guide | yes | built (the punch sweep takes ult rocks); asserted |
| Tetraform terrain lasts longer per rank (+2.5s at levels 2 and 3) | wiki | no | not built: our X has no ranks |
| Landslide rock shoves enemies toward the abyss (dunk setup) | footage tip "Dash -> RMB Dunk Combo" | yes (0965-1010) | built as the leap's landing crash (a shove with a lift) and the rock rolling on |
| Rock Molten Guard shield per rock fired (2.00 passive) / hitting your rocks with the punch gives a shield | patch 2.00 notes, owner's tooltip data | no | built (data pass) as the base passive: one stack per punch |
| Landslide: 12s, -2s / +1 charge / dash 33% longer | owner's tooltip data | no | built: 12s (10.2s at rank 2 by the shared recharge step), a second charge and the third further at rank 3 |

## Data pass (SERVER_UPDATE7, owner's tooltip data)
- Molten Guard is the base passive (above); the slam's rank-3 stacks are the data's "slamming enemies or rocks grants a stack".
- The slam reset on a knock or kill is removed (Volcano Crusher has none).
- The leap rests 12s (was 9s; durations match directly); rank 2 recharges in 10.2s (the shared -15% step; the data's -2s), rank 3
  adds the second charge (the data's +1 charge) and the third-further reach (its +33%) on top of the shared step (8.4s per
  charge, faster than the data's 10s: the shared rank step cannot be switched off for one hunter).
- Allies climbing the rocks: the data pass let any hunter jump onto a rock; owner review item 25 replaced that: only the
  rock's caster climbs it (see Rock ownership).
- Not touched: the X wiring and numbers (45s as in the data), the slam and Stone Row cooldowns (9s and 13s against the
  data's 11s and 12.5s, within the ratio the other hunters use).

## Assumptions (the footage is silent; easy to change in content/archetypes/dolm.json)
- The tap boulder flies its full range rather than stopping at the cursor, and its burst splashes 0.9m for half damage.
- She can walk while charging Quakefall, at 55% speed.
- One punch-lunge per charge.
- Rocks last 9s (the footage only shows 5s or more).
- The KNOCK beam on the dunk is our DUNKED word plus a vertical light (a generic knock look in the source, it seems).
- Anyone dropped onto a rock from above (a glide, a knock) stands on it and can walk off; only climbing is the caster's.
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
| RMB charge, leap, lunge, release, dive | `breah_crouch` (hold), `breah_leap`, `breah_lunge`, `breah_slam`, `breah_dive`, `breah_slam_land` | `anim_br_slam`, `anim_br_leap`, `anim_br_lunge`, `anim_br_dive`; `--breah-shots` (rmb) |
| Shift (the leap and its landing), the long air dash | `breah_dash` (0.58s: ends on the landing, where `breah_leap_land` takes over), `breah_leap_land`, `breah_exdash` (0.23s, the air dash's own length); both dash moves are the whole pose (`dodge_anim` "kit": no shared roll) | `anim_br_dash`, `anim_br_exdash`; `--breah-shots` (dash) |
| E | `breah_raise` | `anim_br_raise` |
| X | `breah_spine_aim` (hold), `breah_spine` | `anim_br_spine` |
| Passive find | `breah_sense` | `anim_br_sense` |

## Dash -> ability flow (owner review item 32; rows in content/dash_flow/dolm.json, table in docs/heroes/dash_interactions.md)
- Rubble Leap is a dash DashFlow sees (`in_dash()` from the press until she lands, `dash_left()` the planned flight
  left); it is no longer in `kit_owns`.
- Ground (the leap): LMB fires mid-leap, the arc carries on (the guide's "Punch to Extend Dash"); RMB starts the charge
  mid-leap, let go in the air and the slam lands with her (the guide's "Dash -> RMB Dunk Combo"); E waits for the
  landing (Rockwave is ground-only); X and Q go mid-leap. Air (the long dash): LMB waits for its end (the shared dash
  can't fire the weapon; a Quake Fist charge held into it charges on, item 51), RMB, X and Q go mid-dash, E never goes off in the air (ground-only, source-correct).
- Shift during the punch's wind-up, the charge, Stone Row's flash or the Spine's aim leaps at once and the ability carries
  on (into_dash rows). A second leap while the first one's rock is still coming down sends that rock on at once.
- Stone Row from on top of one of her rocks measures from the ground just past it (it used to find no room).

## Dash moves (owner review item 35)
- Ground (Rubble Leap, the owner's leap over the source's shove): `breah_dash`, crouched on the rock as it heaves up (0.06),
  kicked off it stretched long (0.12), tucked with both fists overhead (0.30), legs reaching down (0.46), the fists-high
  drop that `breah_leap_land` picks up on landing (0.58 = the 0.06s crouch + the 0.52s flight).
- Air (the class long dash; the footage shows no air dash, so it takes the source's ground shove, footage 128.8-129.4s:
  shoulder down behind the rock, fists forward): `breah_exdash`, a gather (0.03), a shoulder-first barge with the lead
  fist low and the legs trailing (0.08-0.18), a brace with the knees up (0.23 = the dash's 0.2s x the dash feel).
- No blasts or rings on either: the leap's start is a dust kick as the rock heaves up, its landing a dust crash (the hit
  area is the landing circle everyone sees through the flight); the air dash leaves only her dust after-image.
- Asserted: `item 35: her ground and air dash moves are two distinct ids...`, `...each dash move ends with its dash`,
  `...her air dash plays breah_exdash as the whole pose`, `...her ground/air dash draws no ground ring and no blast`.
  Strips: /home/boki/shots-s2/breah/review/breah_dash_ground_strip.png, breah_dash_air_strip.png.

## Rock ownership (owner review item 25)
- A rock belongs to the Breah who raised it (Stone Row, Basalt Spine): the wall's `by`. Only she climbs it: walking into
  its face (moving into it, no jump) lifts her at 5 m/s with her walk carried on, so she rises onto the top and walks
  over it in about half a second (asserted at most 0.6s). Everyone else, allies included, and every bot and Boki is
  stopped by it as by a full wall, walking or jumping; another Breah's rocks are a wall to her too. A body that lands on
  a rock from above still stands on it and can walk off.
- This replaces the data pass's ally climb (the source lets allies hop friendly walls); the owner's call wins.
- Code: StoneStand.top_for (the height a rock blocks the body moving now: its top for its caster, a full wall for others),
  StoneStand.mover (set and cleared by Hunter around its move step), StoneStand.climb (caster only).

## Engine notes
- Rocks are Verbs walls with `top` 1.25m and `th` 0.42 (HeroZones.rock). Verbs.wall_blocks asks StoneStand.top_for how
  tall a rock is for the body moving (Rock ownership above); Ent.ground reads StoneStand.top_under; Hunter's move step
  sets StoneStand.mover and calls StoneStand.climb.
- Every projectile is an ordinary Match shot (spawn_shot), so the height rules and Net behave as for every shot; KitLooks only
  replaces the shared sphere with a pooled skin.
- Net: rocks travel as `["zone", ...]` events (the Spine's too); `top` is a constant. The Spine no longer lays a
  walkway, so it never sends the shared `"bridge"` event (HeroZones.bridge stays for other kits).
- Basalt Spine: `scripts/arch/kits/breah_spine.gd` (BreahSpine). Its hold field is `phase == "aim"`, cleared by
  `DolmKit._drop_holds()` through `spine.drop()`. Main sends only the X press, so BreahSpine._held() reads the local key (tests hold it with `inp["x_down"]`).
