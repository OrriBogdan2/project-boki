# Tenzo the Stone Seer (archetype id `dolm`, Medium; was "Dolm")

Internal note: the behaviour reference is the hero named in the Inspired-by table in docs/ARCHETYPES.md. Nothing below is
player-facing; every name, number and word in the shipped game is our own (renames: Stonesight -> Tremor Sense, Landslide ->
Rock Hop (first Rubble Leap), Rockwave -> Stone Row; the hero Dolm -> Breah, owner, Nov 2026). Ids and file names stay `dolm`.

## Research summary
- Sources: the reference sheet from guide footage (briefs/hero-ref/breah.md, outside the repo), the reference hero's wiki page
  (https://supervive.wiki.gg/wiki/Tetra) and the full patch-note text from the Steam news feed (patches 1.01-2.04, 2025).
- Owner notes (sync61 playtest) override the footage: raised rocks give verticality (stand on them, climb them), punching
  rocks sends them flying, LMB is a hold.
- **Deliberate change from the source (owner dash note, Nov 2):** the source's Landslide is an odd short dash followed by a
  rock thrown at you. Ours is a **leap**: the rock bursts up under her, she leaps in an arc to the cursor, lands with a crash
  that shoves everyone beside her, and the rock comes down right after her and rolls on. Two hits (the landing, then the
  rock) read better than one. **Owner item 111 (Nov 5) replaced the single leap with Rock Hop:** 2-3 steerable hops off rocks
  he raises, the skateboard/parkour idea. See Rock Hop below; the crash and the rolling rock stay on the last landing.
- Copied: structure, timing ratios and interactions. Not copied: names, text, raw numbers, art, sound.

## Design
Weight Medium (145 hp). Fixed weapon Rubble Fists (`content/weapons/rubble_fists.json`): a huge basalt gauntlet on each fist,
with magma cracks (shaders/molten_rock.gdshader), knuckle studs and a hot core (scripts/match/hero_arms.gd); the gauntlets
ride her hands (HunterAnim's "fist" hold), so every move's arm reach shows. Body (content "body"): 0.97 tall, 1.2 wide (big
forearms and fists, a short wide read); the medium hitbox 0.40 is kept (the fists are not body). Palette ochre stone `#d9a35b`
with molten orange `#ff7a2a`. Payoff word ROCKFALL. Kit: `scripts/arch/kits/dolm_kit.gd`, the slam in `breah_slam.gd`,
looks in `kit_looks.gd`, standing on rocks in `scripts/arch/stone_stand.gd`, moves in `scripts/match/kmoves_stone.gd`,
sounds from `tools/gen_sfx_tarek.py` (names in `scripts/core/sfx_kits.gd`).

## Scaling used (ratios from the source)
- Boulder 9 (source 169); a launched rock 14, about 1.5x the boulder (source 244 vs 169, 1.45x). Punch 12-24 (source 199).
- Quakefall 14-30, the sweet spot x1.2 (source 188 outer vs 225 centre), stun 0.5-1.2s by charge. RMB cooldown 9s (source 11s, ratio 0.82; the
  dash is 12s as in the source, no longer equal to it). Full charge 0.45s (0.2s tap window + 0.25s; owner item 61 overrides the source's 1.0-1.5s).
- Punch hold: full at 0.9s (source about 0.75s release), step 0.6m (source 0.5 bh). Rocks 45 hp, 9s.
- Scale: one body height (bh) is about 1.8m, for gameplay ranges and visuals alike: the punch lane 4.2 by 1.8m (2.5 by 1 bh),
  the slam a 2m hop ahead with a 3.6-4.5m radius (about 2.5 bh), the row 3.4m ahead (2 bh) spanning about 5m (3 bh).
- Rock Hop: 2.8m and 0.26s a hop in the kit numbers, with the global dash feel on top like every dash (x0.85 distance,
  x1.15 time: about 2.4m in 0.3s), 7.5m along a whole chain with its skids.

## Parity pass (owner 18:45: animation and ability parity, LMB first)
Source vs ours per slot; [data] = the game data, [footage] = hero-ref/breah.md at 5 fps. Asserted in `--dolm-combo-check`
(`parity breah: ...`, tools/parity_pvb.gd, plus the existing `lmb: ...` lines).

| Slot | Source | Ours | Status |
|---|---|---|---|
| LMB tap beats | an underarm or side hurl from the right gauntlet, no long wind-up [footage 0108] | `breah_throw`: out at 0.07 s | matches; asserted |
| LMB tap cadence, speed, range | 0.6 s [data card; footage 1 per 2-3 frames]; a slow molten boulder, about 10-12 bh/s; a small burst with a red ground ring [footage] | 0.6 s, 20 m/s, 11 m, a red ring and a 0.9 m splash | matches; asserted |
| LMB hold beats | the gauntlet drawn back in a deep crouch, a straight drive that steps her about 0.5 bh; about 0.75 s hold [footage 0118-0121] | `breah_wind` (held) then `breah_punch`, out at 0.05 s; a 0.6 m step (0.8 m measured) | matches; asserted |
| LMB hold tracking | the lane points at the cursor, fixed length [footage] | the lane and her body follow a moved cursor during the hold; 4.2 m by 1.8 m | matches; asserted |
| RMB Volcano Crusher | hold, crouch with glowing fists, hop forward and smash; jump while charging leaps forward [data, footage] | Quakefall: the same (Quakefall review, item 14) | matches |
| E Rockwave | three rocks about 2 bh ahead, a slight curve, a red flash first [footage] | Stone Row: the same | matches |
| X Tetraform | tap or hold-drag, rocks centre-out, slow [data, footage] | Basalt Spine: the same, rocks only (owner item 15) | owner rule over data |
| Shift Landslide | a rock ahead, a shove dash, the rock launched [footage] | Rock Hop (owner item 111), dust only (no ring or blast) | owner design |

## Audit (Nov 3 23:40)
Rows of briefs/specs/kit-audit/tarek_ostra_claire.md. (a) done on this branch, (b) fixed now, (c) not applied, with
the reason. Asserts: `--dolm-combo-check` (`audit tarek: ...`, `rock ...`, `glide slam: ...`, `small: ...`).

| Row (sev) | Verdict | Where / why |
|---|---|---|
| RMB out of a glide (HIGH) | (a) | 5e00729a: folds the glider, plunges at the glider's dive speed, slams where he lands |
| RMB cooldown 9 vs 11 (LOW) | (b) | 11 s (data) |
| RMB reset on knock (LOW) | (c) | the owner removed it (item 14); the in-game card (frame 0240) does show it, if he wants it back |
| RMB air press (LOW) | (a) | kept and reused for the glide slam |
| Molten Guard from any team rock (LOW) | (b) | only his own rocks give a stack (ally rocks still fly); asserted |
| E: allies hop the rocks (MED) | (b) | owner 23:55 (the data): an ally jumping against his rock is lifted onto it and over; walking, allies are stopped; foes are stopped either way; he still climbs his own by walking (item 25). Asserted |
| E cooldown 13 vs 12.5 (LOW) | (b) | 12.5 s |
| Shift ground (n/a), Shift air shove (LOW) | (c) | the owner's leap stays; the air dash has no source (owner question if wanted) |
| Dash -> LMB air buffer (LOW) | (c) | the source-buffering finding keeps modes (coordinator) |
| LMB punch auto-release (LOW) | (b) | held as long as you like, full stays full, one punch on release; asserted |
| LMB damage ratios (LOW) | (c) | the charge scaling is ours (noted) |
| X Basalt Spine, X auto-cast after 3 s (LOW) | (c) | documented; the 3 s cap keeps a forgotten hold from blocking the ult |
| Hunter viewer moves (MED) | (b) | RMB `breah_crouch`, `breah_slam`; X `breah_spine_aim`, `breah_spine`; asserted |
| Player-facing wiki name (MED) | (c) | the Tenzo rename is main's (done there) |
| Self-shake (MED) | (c) | ext/no-shake |
| Explosion/ring rule (n/a) | (a) | complies |

## Per-slot table
| Slot | Input | Aim and telegraph | What it does (ours) | Anim (KMovesStone) | Sound |
|---|---|---|---|---|---|
| Passive Molten Guard | punch | a gold ring under her | a punch that sends any of her rocks flying (Stone Row, Basalt Spine or a leap's rock in the lane) gives a shield stack of 18, up to 4, 6s; one stack per punch whatever the number of rocks | none | none |
| Passive Tremor Sense | sneak (crouch) | a pale cone toward the cursor, 16m, 25 deg widening to 40 over 2s | foes in the cone show through walls and fog as a molten ring, refreshed every 0.5s | `breah_sense` on a find | `br_sense` |
| LMB tap: boulder | tap (under 0.28s) | the shared aim line; flies its full 11m (AimMode.MAX) | 9 dmg, a molten tumbling boulder with an ember trail; bursts with a red ground ring, splashing foes within 0.9m for half | `breah_throw` | `br_throw`, `br_boulder_hit` |
| LMB hold: punch | hold, release | from the hold: a pale lane 4.2m by 1.8m with 3 chevrons toward the cursor, filling; the cursor charge ring; the fist glows molten orange, hotter with the charge | 12-24 dmg to foes in the lane, knockback 6-11, a 0.6m step, a dust ring and molten spray at the lane's end on the hit; into a wall = 0.9s stun (stars); every rock of the team in the lane flies, and rocks lined up further along the aim (gaps up to 2.8m, to 12m) follow one after another, 0.08s apart. Held as long as you like (no timeout): full stays full until you let go | `breah_wind` (hold), `breah_punch` | `br_wind`, `br_punch`, `br_launch`, `br_burst` |
| RMB Quakefall (owner item 61) | tap, or a short hold | tap: nothing shows, it lands on the release. Hold: everyone sees a red circle a hop (2.5m plus what the hop keeps of his run) ahead, radius 3.82-4.5m, its sweet spot growing 0.9-1.8m; the cursor charge ring; both fists glow molten; the charge is capped at 0.45s (0.2 tap window + 0.25) and fires by itself there | tap: no hop, nothing vertical: an instant slam 1.6m ahead, radius 3.82m (0.85 of the hold's), 14 dmg, centre x1.2 and 0.5s stun. Hold: a real 0.6s jump arc, 2.5m forward and 0.66m up, keeping half his ground speed; the move keys bend it by up to 1.3 m/s (about 0.8m at the landing); he slams as he lands: 14-30 by charge, full circle and centre at the cap, centre x1.2 and stun 0.5-1.2s (stars), rocks in the ring fly outward, foes in the air are spiked (+40%, +20 over the abyss). Jump while holding: the bigger leap (3.2m, 1.57m up). Punch while holding: a 1.5m lunge. Air press: dive and slam on landing; from a glide the glider folds | `breah_crouch`, `breah_slam` (hop, smash at 0.6s), `breah_slam_land` (tap, air), `breah_leap`, `breah_dive`, `breah_lunge` | `br_slam`, `br_leap` |
| Shift Rock Hop | tap, then a re-press per hop | toward the cursor (1.2m to about 2.4m a hop, up to 3 hops); everyone sees the landing circle (1.8m) filling through each hop | a low rock bursts up under him (0.06s crouch), he springs off in a 0.3s low arc, a fresh rock rises to meet his feet and he skids along it (up to 0.55m). A press within 0.6s of the take-off sends the next hop at the cursor as it is then; none, and the skid ends in the landing. Each landing but the last: a small shove, no damage. The last landing: the crash, 8 dmg and a shove within 1.8m, then the rock comes down 0.14s later and rolls on 6m: 12 dmg, Shred, 1.5s slow. The recharge runs from the chain's end. In the air: the class long dash, his own heavy shove with a dust after-image | `breah_hop`, `breah_skate`, `breah_leap_land`, `breah_exdash` | `br_rise`, `br_leap`, `br_slam`, `br_roll`, `br_shove` |
| E Stone Row | tap | a 0.2s red-orange flash on the ground at each spot (everyone sees it) | three rocks of jagged basalt columns (tapered, broken tops, leaning apart) in a slight curve 3.4m ahead (outer two 0.45m back, 2.4m apart), thin molten cracks in the ground at their feet cooling over 0.6s; 9s, 45 hp; they block bodies and enemy shots; only she climbs them (walking into one lifts her onto it, no jump) and stands on them; any punch, slam or dash-launch sends them flying | `breah_raise` | `br_crack`, `br_raise` |
| X Basalt Spine (level 6, 45s) | tap, or hold and drag, release | while X is held (yours only): a pale line 12m long, bent in a shallow arc (25 degrees end to end, the middle bowing away from her), with inward chevrons and a centre ring, at the cursor (up to 11m), across the aim; dragging the cursor 0.8m+ from the centre swings it round the centre toward the cursor. On release everyone sees molten cracks along it for 0.2s | 9 rocks of hers erupt from the centre outward over 0.4s with flame bursts: foes within 1.6m are slowed 35% for 1s (1 damage), bodies on the line are moved to their side of it. The rocks stand 7s, block foes and their shots, carry and climb like hers, and fly when punched, slammed or dashed into (a punch along the ridge sweeps it); one cast's rocks deal at most 40 to any one hunter. They are Stone Row's own rocks (same length, top and thickness), lying along the arc, one rock deep. Over the abyss the rocks are ground (Ent.over_void reads StoneStand.top_under): she and any hunter can land on the ridge and walk along it with no fall or abyss sink while the rocks stand, and fall as normal when they crumble. A rock on a different level of ground than the ridge is left out; it never calls HeroZones.bridge (no tiles change). A stun, knock or merge while aiming cancels it unspent | `breah_spine_aim` (hold), `breah_spine` | `br_spine` |
| Merge (the `ultimate` action; its key from Settings.key_cap) | (Boki Merge) | | | | |

Rank 3: Quakefall gives a Molten Guard stack (18, the same stacks the punch gives, up to 4, a gold ring) per slam that catches
something; Rock Hop takes a second charge and each hop goes a third further; Stone Row raises an extra row of three behind the first (the source's "extra Rock Wall").

**Unfolded:** the kit pass had folded the source's Tetraform into Stone Row rank 3 (a centre-out second row that slowed, and a
bridge over the abyss). Now that Tetraform is Basalt Spine on X, the row moved there and rank 3 is the source's plain extra
row again. The bridge is gone altogether (owner review item 15: no terrain over the abyss from her ult).

## Quakefall review (owner review item 14, Nov 3)
- **Before:** the hop was the shared dash motion (2m in 0.15s, 13 m/s, height held flat), so the release read as a quick
  lunge forward, the same family of motion as the dash; the charge leap was the same flat dash (3.2m in 0.32s, never
  left the ground). Quakefall has never raised a rock: the slam only throws rock chips (the flying lumps of the impact
  look) and launches rocks already standing in the ring. The rock the owner saw is most likely those chips plus the flat
  lunge, or Rock Hop's last rock (Shift).
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

## Quakefall review (owner review item 61, Nov 4; overrides the hold length above and the source's)
- **Owner:** "it's a short hold or tap". The 1.2s charge is gone: the charge is capped at 0.45s and fires by itself there.
  Tap: no hop, an instant slam just ahead in a circle 0.85 of the hold's, still hitting and stunning at the centre.
  Short hold: the hop goes further and higher than item 14's (2.5m, 0.66m up, 0.6s instead of 2m, 0.4m, 0.42s), keeps half
  his ground speed, and the move keys bend it. The damage and the sweet spot still grow through the short window; the
  full numbers are the slam at the cap.
- `slam` data: `time` 0.25 (the charge past the 0.2 tap window), `reach` 1.6 (the tap's spot), `hop` 2.5, `hop_up` 4.4,
  `carry` 0.5, `nudge` 1.3 m/s, `radius` [3.82, 4.5]. `breah_slam` is re-keyed to the 0.6s arc (smash at 0.6, ends 1.36).
- The circle shown during the hold is where the hop will land, run speed included (BreahSlam.center).
- Asserted (`--dolm-combo-check`): `item 61: the charge never passes the cap...`, `item 61: the tap is a slam on the spot...`,
  `item 61: the hold carries him at least 2m forward...`, `item 61: the move keys nudge the landing...`,
  `item 61: a hop off a run keeps some of its speed...`.
  Strips: /home/boki/shots-s2/kits/tarek/new/breah_rmb_strip.png (hold), breah_rmb_tap_strip.png (tap).

## Rock Hop (owner item 111, Nov 5)
Code `scripts/arch/kits/breah_hop.gd` (BreahHop); numbers `dash` in `content/archetypes/dolm.json`; the ability id stays `landslide`.
- **The chain:** press: a rock under him, 0.06s crouch, hop 1. `window` (0.6s) runs from each take-off, so it covers the flight
  (0.3s) and the skid: press any time in it, and the next hop goes `skid_min` (0.1s) after touchdown, at the cursor as it is
  then. No press: the skid (up to `skid` 0.55m in `skid_t` 0.3s) ends in the landing. Three hops at most; the third lands at once.
- **Distance:** 3 hops of about 2.4m plus 2 skids of 0.2-0.55m: 7.5-8.2m, against the 7.5m the item names. That is more than the
  old single leap's 4.25m (the item's "roughly equal" and its "3 x 2.5m" disagree; we built the number), but it takes 1.2-1.5s:
  about a run's speed plus a third, so it isn't a bigger escape than the old 0.58s leap. One hop is about 2.9m.
- **Damage:** only the last landing: 8 and the rolling rock's 12, as before. Other landings: a shove of 3.5 (`shove_kb`), no damage.
  The kin dodge rider fires once, for the whole chain. Invulnerability (0.08s) on hop 1 only, as the old leap had one.
- **Rocks:** real rocks, 0.6m tall (`hop_top`), 30 hp, 1.2s (`hop_rock_t`), laid along the hop so the skid is a rail. They stop foes,
  allies hop them (StoneStand reads any wall with a `top`), never rise in a body (no room: he lands on the ground), don't count
  among his 6, and a punch or slam doesn't launch them (`w["hop"]`): the dash's damage stays on the last landing. Over the Net
  they are a normal `zone rock` with an optional 13th field, `top`.
- **Under his foot:** `footrock`, a held slab (KitLooks, placeholder until the art lane replaces it) under him for the whole chain.
- **Abyss (ours; the item doesn't say; `tarek_splash.png` shows Rock Hop across a canyon):** a hop can land over the void on a rock at his height
  only if ground lies on that line within the reach of the hops left. So a gap he can finish is crossed, and open abyss is
  not: the hop pulls back to the last solid ground. Out on a void rock with no press, the chain ends there: the rock crumbles and he
  falls or glides. Off the map's grid nothing is ground, so a chain can't leave it.
- **Rough ground:** a hop up a terrace (up to 2.5m) uses the shared sure arc over the lip; drops take the same hop time; a wall in reach pulls the
  spot back; no spot at all ends the chain where he is, with the crash.
- **Other moves:** RMB let go mid-hop: the slam lands with that hop and the chain ends there (crash and slam, as the old leap). Opening the
  glider, being downed or a merge drops the chain with no crash. Bots ride the whole chain.
- **Cooldown:** the charge is spent at the press; the recharge waits for the chain's end (`_hold_charge` undoes the shared step).
- **Anim ids:** `breah_hop` (each hop), `breah_skate` (the skid), `breah_leap_land` (the crash). ART-1 Tenzo maps `breah_hop` -> `dash_hop` and `breah_skate` -> `dash_skate`.
- **Hooks for S3/S4 (placeholders use existing dust and sounds):** take-off `br_leap` at the feet; rock rise `br_rise`; touchdown `br_slam` (soft); crash `br_slam`; roll `br_roll`.

## Taller rocks (owner review item 67, Nov 4)
- Every raised rock is 2.2m tall (was 1.25m; 1.76x): taller than a hunter's head, the tallest column 2.32m. Same footprint
  (length 1.3m, `th` 0.42), same blocking. Stone Row and Basalt Spine share it; Rock Hop's rolling rock (`dashrock`) is 1.8x
  taller and rides higher, so it does not sink into the ground. Rock Hop's own rocks are 0.6m tall: the same crags, stood straight and squashed.
- Look (scripts/arch/rock_look.gd, RockLook): tapered craggy columns, warm umber and sandstone faces (`molten_rock` got an
  optional warm `rim`), pale tops that read from the top-down camera, a soft ground shadow. They rise over 0.22s with a
  dust and earth burst and a short rumble (`br_rumble`, at most one per 0.09s so a ridge rumbles as one); broken or timed
  out they crack and slump into the ground with chips and dust (`br_crumble`, Verbs' `kx_end`). A launched rock still leaves
  by flying.
- The climb: StoneStand lifts the caster at 8.5 m/s, easing off 0.85m under the top so it ends about 0.2m past it (a straight
  8.5 m/s would throw him 2m up). Crossing a rock takes 0.58s (0.52s before). `CLIMB_MAX` 2.7m.
- A punch or slam from on top of a rock still takes it (HeroZones.rock_in_reach, the old 2m reach would have missed it).
- Allies still hop over by jumping (owner 23:55, DECISIONS), which item 67's "nobody else can" does not override: foes cannot.
- Asserted (`--dolm-combo-check`): `item 67: a rock's top is at least 1.6x...`, `item 67: the look reaches the top...`,
  `item 67: every rock has a ground shadow`, `rock (item 25): ...`. Old vs new: /home/boki/shots-s2/kits/tarek/.

## Combinations (`--dolm-combo-check`, tools/breah_combo_check.gd; placement in `--zone-check`)
| Combo | Result | Asserted by |
|---|---|---|
| Stone Row, then punch along it | every rock flies in a stream (first at once, the rest 0.08s apart), bursts, shreds, slows, ROCKFALL | `combo: a punch along a row launches every rock in a stream`, `combo: launched rocks burst on the foe...` |
| Stone Row, then slam | rocks in the ring fly outward | `combo: Stone Row > slam launches the rocks` |
| Stone Row, then walk into a rock | he rises onto it and walks over (0.58s to cross, no jump); anyone else is stopped | `rock (item 25): walking into her own rock lifts her...`, `rock (item 25): an ally / a foe walking or jumping into her rock is stopped`, `rock: dropped onto a rock, she stands on its top` |
| Punch into a wall | 0.9s stun with stars | `combo: punch into a wall = stun, with stars over the head` |
| Charge, jump, let go | a real leap forward with the circle, slam on landing | `rmb: jump while charging is a real leap...`, `rmb: the circle comes with her`, `rmb: let go mid-leap = the leap's arc carries on...` |
| Quakefall (hop, leap or air press), then glide | the glider opens and the slam is dropped; she keeps her height (item 26) | `glide (item 26, hop/leap/air): ...` |
| Glide, then Quakefall (owner 23:00) | the glider folds, she plunges at 32.5 m/s (the data's glider dive) and slams where she lands, about 0.25 s from 8 m | `glide slam: RMB in a glide folds the glider...`, `glide slam: she slams where she lands...` |
| Charge, punch | a lunge forward, no punch | `small: a punch during the charge lunges her forward` |
| Slam that knocks or kills | nothing: Quakefall has no reset (data pass) | `data: a slam that knocks does not reset Quakefall` |
| Rock Hop beside a foe | a mid-chain landing nudges it with no damage; the last landing's crash shoves it, then the rock comes down after him and rolls into it (shred, slow) | `shove: a mid-chain landing nudges with no damage`, `crash: the last landing hits and shoves a foe beside it`, `crash: the rock comes down after him`, `crash: the rock rolls on and hits` |
| Rock Hop crash, then slam | the crash pops the foe up, the slam dunks it while it is airborne | `crash: the last landing hits ...`, `rmb: a foe in the air is dunked` |
| Two bursts on one foe | the second inside 0.8s deals 30% less | `small: a second burst on the same foe inside 0.8s deals 30% less` |
| Boulder into a pair | the one beside takes half | `small: the boulder's burst splashes the foe beside it` |
| Merge start | dive, charge, its leap, Rock Hop, the Spine's aim and telegraphs all drop | `merge hold: ...` |
| Basalt Spine, then a punch along it | the whole ridge flies in a stream at whoever is down the line (40 cap per hunter), ROCKFALL | `ult combo: a punch along the ridge launches its rocks in a stream` |
| Basalt Spine across a fleeing foe | the foe is shoved to its side of the line and slowed; the ridge walls it off | `ult: a body on the line is shoved off it...`, `ult: the rise slows a foe beside it` |
| Basalt Spine over the abyss | the rocks are laid on the gap and are ground: a hunter lands on the ridge, stands and walks along it, and falls when the rocks crumble | `spine: over the abyss the rocks are the walkway...`, `spine: rocks stand over the gap...`, `spine walkway: ...` |
| Basalt Spine, punch, then the merge | the target lives (burst cap) | `ult burst: ridge, punch, merge and its ultimate leave a full-health light hunter standing` |
| Quake Fist charge, then her air dash (item 51) | the charge carries through and charges on (short of the auto punch); let go in it and she punches as it ends, in the air, carried on at about the dash's end speed (the punch step, 7 m/s in the air, along her aim) | `item 51: the Quake Fist charge carries through her air dash...`, `item 51: let go in the air dash...` |

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
| Tetraform over the abyss makes temporary terrain | card, wiki | yes (guide 161-169s) | built as rocks, not tiles (owner, Nov 2026, reversing item 15): over the abyss the ridge's rocks are ground you can stand on while they last |
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
- Rock Hop's landing spots: the cursor clamped to a hop's reach, pulled back to the nearest ground a body fits on (never into
  a wall). In the air Shift stays the class long dash. See Rock Hop below.
- Body, plain jumps, idle (not in the footage, built from her character): a short, wide brawler (0.97 tall, 1.2 wide) who
  stomps (a small dip on each step, no bounce), carries both fists low and forward when running and standing, breathes
  slowly (1.6), and lands every jump with the shared heavy squash. Her air dash (the class long dash) is a heavy shove with
  the shared DashTrail.
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
| Shift (Rock Hop, its skid and crash), the long air dash | `breah_hop` (0.28s), `breah_skate`, `breah_leap_land` on the crash, `breah_leap_land`, `breah_exdash` (0.23s, the air dash's own length); both dash moves are the whole pose (`dodge_anim` "kit": no shared roll) | `anim_br_dash`, `anim_br_exdash`; `--breah-shots` (dash) |
| E | `breah_raise` | `anim_br_raise` |
| X | `breah_spine_aim` (hold), `breah_spine` | `anim_br_spine` |
| Passive find | `breah_sense` | `anim_br_sense` |

## Dash -> ability flow (owner review item 32; rows in content/dash_flow/dolm.json, table in docs/heroes/dash_interactions.md)
- Rock Hop is a dash DashFlow sees (`in_dash()` from the press until the chain ends, `dash_left()` the planned flight
  left); it is no longer in `kit_owns`.
- Ground (the leap): LMB fires mid-leap, the arc carries on (the guide's "Punch to Extend Dash"); RMB starts the charge
  mid-leap, let go in the air and the slam lands with her (the guide's "Dash -> RMB Dunk Combo"); E waits for the
  landing (Rockwave is ground-only); X and Q go mid-leap. Air (the long dash): LMB waits for its end (the shared dash
  can't fire the weapon; a Quake Fist charge held into it charges on, item 51), RMB, X and Q go mid-dash, E never goes off in the air (ground-only, source-correct).
- Shift during the punch's wind-up, the charge, Stone Row's flash or the Spine's aim leaps at once and the ability carries
  on (into_dash rows). A second leap while the first one's rock is still coming down sends that rock on at once.
- Stone Row from on top of one of her rocks measures from the ground just past it (it used to find no room).

## Dash moves (owner review item 35)
- Ground (Rock Hop, item 111, over the source's shove): `breah_hop`, crouched on the rock (0), kicked off it long (0.06), knees tucked, arms out for balance (0.16), feet reaching
  down (0.28), once per hop; `breah_skate`, a skater's low stance along the rock, for the skid; `breah_leap_land` on the crash.
- Air (the class long dash; the footage shows no air dash, so it takes the source's ground shove, footage 128.8-129.4s:
  shoulder down behind the rock, fists forward): `breah_exdash`, a gather (0.03), a shoulder-first barge with the lead
  fist low and the legs trailing (0.08-0.18), a brace with the knees up (0.23 = the dash's 0.2s x the dash feel).
- No blasts or rings on either: the leap's start is a dust kick as the rock heaves up, its landing a dust crash (the hit
  area is the landing circle everyone sees through the flight); the air dash leaves only the shared DashTrail.
- Asserted: `item 35: her ground and air dash moves are two distinct ids...`, `...each dash move ends with its dash`,
  `...her air dash plays breah_exdash as the whole pose`, `...her ground/air dash draws no ground ring and no blast`.
  Strips: /home/boki/shots-s2/breah/review/breah_dash_ground_strip.png, breah_dash_air_strip.png.

## Rock ownership (owner review item 25)
- A rock belongs to the Tenzo who raised it (Stone Row, Basalt Spine): the wall's `by`. Only she climbs it: walking into
  its face (moving into it, no jump) lifts her at 5 m/s with her walk carried on, so she rises onto the top and walks
  over it in about half a second (asserted at most 0.6s). Everyone else, allies included, and every bot and Boki is
  stopped by it as by a full wall, walking or jumping; another Tenzo's rocks are a wall to her too. A body that lands on
  a rock from above still stands on it and can walk off.
- This replaces the data pass's ally climb (the source lets allies hop friendly walls); the owner's call wins.
- Code: StoneStand.top_for (the height a rock blocks the body moving now: its top for its caster, a full wall for others),
  StoneStand.mover (set and cleared by Hunter around its move step), StoneStand.climb (caster only).

## Engine notes
- Rocks are Verbs walls with `top` 2.2m and `th` 0.42 (HeroZones.rock). Verbs.wall_blocks asks StoneStand.top_for how
  tall a rock is for the body moving (Rock ownership above); Ent.ground reads StoneStand.top_under; Hunter's move step
  sets StoneStand.mover and calls StoneStand.climb.
- Every projectile is an ordinary Match shot (spawn_shot), so the height rules and Net behave as for every shot; KitLooks only
  replaces the shared sphere with a pooled skin.
- Net: rocks travel as `["zone", ...]` events (the Spine's too); `top` is a constant. The Spine's walkway is the rocks
  themselves (no tiles change), so it never sends the shared `"bridge"` event (HeroZones.bridge stays for other kits);
  each rock event carries its own direction, so the arc needs no new Net field (Net.VERSION unchanged).
- Basalt Spine: `scripts/arch/kits/breah_spine.gd` (BreahSpine). Its hold field is `phase == "aim"`, cleared by
  `DolmKit._drop_holds()` through `spine.drop()`. Main sends only the X press, so BreahSpine._held() reads the local key (tests hold it with `inp["x_down"]`).
