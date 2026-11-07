# Little Lantern (base character Lumi; `tender`, a small support on medium stats)

Internal design doc (was "Linnet"; the id and file names stay `tender`). Source behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (gameplay only; nothing of its names, look or text is used in the game). The fidelity pass (ext/kitfix-moosh-tamsin) worked from the footage reference sheet (`briefs/hero-ref/mooshmoosh.md`), the public wiki page and the owner's notes. Scale: 1 body height (bh) = 1.8 m.

## Our kit
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive Bearer | run into a downed teammate | Carry up to 2 downed teammates behind a 40 (+6/level) shield; they don't bleed and can't be stomped; no slow while you carry; crouch sets them down; shield break, stun, root or hex drops them (no stun on you, 4s lockout). Never one a rival is standing on. Embers Kindle foes (up to 5, 4s): +0.72 damage per stack (about +45% at 5), and an ember into a Kindled foe winds Hearthlight back 0.2s (0.4s Empowered) | Soulpack + Moon Burn | Mana return becomes cooldown wind-back (no mana here) |
| LMB Ember Cast | hold | No weapon: an ember pushed out of one hand, then the other, every 0.4s; it flies its full 12m, past the cursor (`"aim": "max"`). After 1s without firing, the next ember is Empowered: 40% further, double wind-back, its own two-handed push and chime | Crescent Bolt | Same; the range is the footage's 7-8 bh (about 13 m) less a little |
| RMB Burrseed | press; a fixed 1s wind-up, then it throws itself (owner item 118) | Wind-up: half speed, a short 6m dotted lane along the aim (AimKit `dotted`), a ring round her and a coiled pose; not a hold, letting go does nothing; a stun, Hex or going down loses the throw, not the charge. At the end, along the aim of that moment: a fast seed (30 m/s) sticks to the first foe (9 damage). A violet disc the size of the burst shows under them at once for everyone, filling. 0.7s later it flares: 32 damage and a 1.1s root in 2.2m, with root beams, and Kindles all. 10.5s cooldown (the data's 11.5 : 12 against Hearthlight). Rank 3: the root lasts 0.3s longer and the burst is twice as wide (4.4m) | Darkside Binding / Bound by Fate | Footage timing (a fast orb, 0.6-0.8s) over the wiki's 2s |
| Shift Relay Step | tap (in the air: her long glide) | A skip where you move, 3.6m in 0.2s after the global dash feel (Elluna's ground dash). In the air: Elluna's long floaty glide, 13.3m over 0.95s (a 0.1s ramp, a 0.4s burst at about 17 m/s, then a float out easing to 45% of that, held up while it floats; the move keys steer it at 3 rad/s; `dash.air`). The glide is airborne only: on the ground with the hop spent, Shift is refused. No bonus for passing through a teammate (data pass). Rank 3: picking up a teammate refreshes the air dash | Lunar Dash | Goes in the movement direction (footage); the "Dash toward the cursor" setting covers the other preference. Both dashes copy Elluna's distances and timings (owner 18:20, replacing item 24's 3x rule); see "Dashes: Elluna's numbers and ours" |
| E Hearthlight | tap, tap again to throw | A 2.6m (1.4 bh) ring of light on you for 2.5s heals teammates 10 over its life, then blooms to heal 22 more (a soft swell of the disc, light rising and a quiet chime: no ring, blast or shake); you at a third, a downed teammate five times over. E again throws it to the cursor (up to 9m) at 45 m/s: it lands almost at once as a brighter 2.9m disc, heals 50% more for 1s (100% more at rank 3, still 1s), and latches onto the first teammate it passes (or onto the one you carry, aimed at yourself). A stun does not put it out | Rejuvenating Aura / Moonlight Blessing | Radius from the footage (1.3-1.6 bh). Rank 3 is the source's level 4 (the throw's healing increase doubled, same 1s); the revive it borrowed went back to the X ultimate |
| X Hearth Call (level 6) | X with the cursor on a teammate (tap) | While it is ready and the cursor rests on a teammate in reach, a gold ring of 12.6m (7 bh) round her shows the reach and a line runs onto them. X starts a lantern tether that heals them 7 a second for 5s while she walks and casts freely. At the end a downed teammate is pulled to her side and stood up (a green arrival burst). While they are down the tether heals them (it tops up their bleed-out pool, as the data's heal on an ally or Wisp). It breaks if she is knocked or stunned or they leave the ring. 46s cooldown. Solo (no teammate in the match): it lights on her | Divine Intervention | Our own lantern tether and arrival look (no crescent motif) |
| R | none | The Boki Merge | (Merge) | Merge stays on R |

Body: a very small hunter (`body` in tender.json; legs 0.98, torso 1.02, shoulder 1.12, neck -0.036 since the ART-1 rebuild): fallback model 0.6, .glb 0.66 of a medium (body size 0.68; owner item 108 took her down from 0.78, about 13%), nothing above her head, hitbox radius 0.34 (from 0.40; the 0.85x floor of item 46's band, so it stays there), nameplate 1.85 m (it came down with her head) and own bars 2.35 m (`Arch.plate_y` / `Arch.body`, for the HUD to read). A low forward-leaning scurry at 1.25x step cadence with a small per-step bob, her ember-tipped tail swinging with each step; the torso keeps facing the aim while the legs go where she moves. Run speed is the shared one.

Scaling: HP 145 (medium). Hearth Call heals 35 over 5s (7/s, about a quarter of a medium health bar); cooldown 46s against Hearthlight's 11s (source card 41.6 : 10). Ratios kept: an ember is 8, rising to about 11.6 at 5 Kindle (+45%; footage 64 -> 93). The seed burst is 32 (4x an ember). Hearthlight is 10 + 22 per squadmate. Cooldown ratio: Burrseed 10.5s against Hearthlight 11s (the data's 11.5 : 12).

## Parity pass (owner 18:45: LMB first, then the rest by distance from the source)
Source vs ours per slot. [data] = briefs/supervive-data (supervive_kits.md, Elluna), [footage] = briefs/hero-ref/mooshmoosh.md.

| Slot | Source | Ours | Asserted (`--tender-combo-check`) |
|---|---|---|---|
| LMB cadence and reach | a shot every 0.4s (card); flies to max range past the cursor [footage] | 0.4s, the full 12m past the cursor | `mm LMB: a shot every 0.4 s ...`, `... flies its full range ...` |
| LMB ramp, Empowered | more damage on each later hit; after not firing briefly the next shot is Empowered [data] | Kindle on the foe (+45% at 5); Empowered after 1s idle | `mm passive: Kindle ramps ...`, `mm LMB: after a pause ...` |
| LMB animation and tracking | a straight-arm push from alternating hands, the torso unwinding 45-60 degrees; she strafes and backpedals with the torso on the cursor [footage 716.3-717.6s, 729.3-730.5s] | `mm_shot_r` / `mm_shot_l`: the torso turns 0.8 rad (46 degrees), a straight push; legs go with the movement, every ember leaves at the cursor as it swings round her | `mm LMB: each ember leaves at the cursor ...`, `... unwinds the torso ...` |
| RMB | a small hop (about half her height, 0.3s) with a forward push of both arms [footage]; root after a delay [data] | `mm_seed`: the coil, a hop with a two-handed push; root 0.7s after it sticks | `mm RMB: ...` |
| E | both arms straight up for about 0.3s [footage]; the zone follows her, recast throws it [data] | `mm_hearth`; follows her, recast throws it to the cursor | `mm E: ...` |
| Shift / air dash | Elluna's numbers (see "Dashes: Elluna's numbers and ours") | copied: 3.6m / 0.2s, 13.3m / 0.95s, cooldowns 7s / 14s | `mm dashes: ...` |
| X | channel a heal on an ally while walking, one hand raised [footage] | `mm_call` then `mm_call_hold`, walking freely | `--support-check`, care ult rows |

Nothing in her LMB was off the source beyond what the earlier passes fixed; this pass adds the asserts.

## Audit (Nov 3 23:40)
Every Moosh Moosh row of briefs/specs/kit-audit/cinder_dredge_moosh.md section 3 (audited on main 200effce) against this branch.

| Row | Sev | Verdict | Where / why |
|---|---|---|---|
| The dropped 3x rule still enforced (10.7 m glide, the 2.7-3.3 check) | HIGH | (a) | 89edfb96, af549ca4: Elluna's 13.3 m / 0.95 s; the ratio check is now the source's 3-4x; see "Dashes: Elluna's numbers and ours" |
| On the ground with the hop spent, Shift fires the glide along the ground | HIGH | (b) | 99f79210: the glide is airborne only; `mm dashes: on the ground with the hop spent, Shift is refused ...` |
| No steering in the glide (owner: air control) | MED | (b) | 99f79210: the move keys bend the heading at 3 rad/s (`dash.air.steer`); `mm air dash: the move keys steer the glide ...` |
| Ground dash numbers can't be found ("copy Elluna") | MED | (a) | 89edfb96: the measured hunter ground dash (2 bh in 0.2 s), flagged as an owner clip in the dash table |
| Dash cooldowns | ok | (a) | b0106659: 7 s / 14 s (data) |
| Burrseed cd 8 s vs about 10.5 s (data ratio to E) | MED | (b) | 99f79210: 10.5 s (ranks 9.5 / 8.4 s); `mm RMB: Burrseed 10.5 s ...` |
| Hearth Call heals her instead of the downed ally (data: an ally or Wisp) | MED | (b) | 99f79210: it heals the downed teammate's bleed-out pool (`wisp_k`); `mm X: the tether heals the downed teammate ...` (care ult check) |
| Hearthlight self_k 0.33 (not in the data) | LOW | (c) | kept, noted: healing yourself fully would make her solo-unkillable |
| Ember Cast magazine 18 and a 15% slow while firing | LOW | (b) | 99f79210: no magazine (99) and no firing slow; `mm LMB: Ember Cast has no magazine ...` |
| Empowered as +40% range | LOW | (c) | kept: the source names Empowered without saying what it adds |
| Pickup ring (cosmetic) | LOW | (b) | 99f79210: removed (the CARRY word and the sound stay) |
| Self screen shake | MED | (c) | ext/no-shake owns it |
| Dash -> ability rows | LOW | (c) | left as they are (a separate agent researches presses during a dash) |
| RMB shape, E, X shape, Bearer, rank 3, dash VFX | ok | (a) | matched in the audit |

## Small mechanics
| Mechanic | Source | Footage confirms | Built | Check |
|---|---|---|---|---|
| A teammate being stomped can't be picked up | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes | "a teammate being stomped can't be scooped up" |
| The shield refills on each pickup; a break or crowd control drops them with a 4s no-pickup lock (no stun on you, no carry slow: data pass) | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes (existing) | `--support-check` Bearer rows |
| The Empowered shot after a pause: more range, double return | [wiki](https://supervive.wiki.gg/wiki/Elluna), card | card only | yes | "after a pause the next ember is Empowered" |
| Embers fly to max range, past the cursor | footage | yes | yes | "the ember flies its full range past the cursor" |
| Bound by Fate shows a lane to max range while aiming and fires on release | footage | yes | yes | "held, a dotted lane..."; "nothing leaves while it is held" |
| Its area shows at once and roots about 0.6-0.8s later | footage (the wiki says 2s) | yes | yes, 0.7s | "it roots about 0.7 s after it sticks" |
| The aura's recast throws it to a spot, and it sticks to the first ally it passes | [wiki](https://supervive.wiki.gg/wiki/Elluna), footage | the spot, yes | yes | "thrown, it lands on the cursor"; `--support-check` latch |
| A stun on you does not put out the aura (data pass; the wiki's rule was not in the tooltip data) | tooltip data | no | yes | `--support-check` |
| Dashing through an ally refunds nothing (data pass: the source has no such bonus) | tooltip data | no | removed | `--support-check` |
| Rank 3 (source level 4): picking up a wisp refreshes the air dash | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes | `--support-check` |
| Healing is x5 on wisps and x0.33 on yourself | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes | `--support-check` |
| Relay Step goes where you move, not at the cursor | footage | yes | yes | "Relay Step goes where you move" |
| X: she can move while the tether channels | footage (f41-f72) | yes | yes | "mm X: she walks while it channels" |
| X: other abilities can be cast during the channel | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes | "mm X: other abilities still cast during the channel" |
| X: it ends if she is knocked or stunned, or moves too far from the teammate | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes (break range = the 7 bh ring) | "mm X: it breaks when the teammate leaves the ring, and pays nothing" |
| X: on a downed teammate (wisp) the heal goes to her, and at the end they are resurrected and teleported to her | [wiki](https://supervive.wiki.gg/wiki/Elluna), footage f74-f75 | the teleport, yes | yes | "mm X: the tether heals the downed teammate ...", "... pulled to her side and stood up" |
| X: unit-targeted, an aim line onto the ally first | footage f19-f24 | yes | yes (a tap; the line and ring show while the cursor is on a teammate) | "mm X: with the cursor on a teammate, the 7 bh reach ring and a line onto them" |

## Assumptions
Where the footage and the wiki are silent, this is the most likely behaviour, and each is easy to change in `content/archetypes/tender.json`:
- The Burrseed area **sticks to the foe** and moves with them (the dummy in the footage doesn't move).
- The root lasts 1.1s (wiki). Damage is 32 (4x an ember), down from 35, because the shorter window is more reliable.
- The Hearthlight keeps its heal amount and duration when thrown. The throw reach is 9m.
- Kindle: 5 stacks, 4s, refreshed per hit, no per-stack decay (the wiki says up to 5).
- The Empowered pause is 1s.
- **Hearth Call:** it can't be ended early (no recast in the source); X again is ignored. Damage on her does not break it (the wiki lists only knocked, stunned and range). The break range is the same 12.6m as the cast range. A downed teammate in our game is the source's wisp. Its healing does not scale with ranks (no X ranks); it grows with level (LevelGrowth). The cooldown starts on the cast. With no teammate in the match at all it lights on her (healing at a third) so the key is never dead in solo play.
- **Hearth Call and the bond:** a completed tether counts as a "hit" for `KinBond.from_ult` (with the cast's `HeroUlt.cast_id`), a rescue (a downed teammate stood up) as its top event ("kill"); a broken one pays nothing. The sheet's +0.2 on the teammate's own meter is not built (the amounts are the main session's, in boki_system.json).
- **Body and movement** (owner study, 23:00): the scale, hitbox and cadence are from the study; the dashes are Elluna's (below).
- Starts and stops use the shared acceleration (no per-hero change).
- Kindle readability is a foot glow that warms from violet to ember per stack. Tinting damage numbers by stack (sheet gap 9, optional) is not done: the numbers come from the shared damage path.

## Dashes: Elluna's numbers and ours (owner 18:20: "copy Elluna")
Item 24's "air about 3x the ground" rule is dropped; both dashes copy the source. Her cute moves stay (`mm_skip`, `mm_float`, retimed to the new lengths). Precedence: data, then footage (briefs/hero-ref/mooshmoosh.md section 4; 50 px = 1 m, 1 bh = 1.8 m).

| | Source (Elluna) | Where from | Ours (data) | Ours (in game) |
|---|---|---|---|---|
| Ground dash distance | about 2 bh (3.6 m): her own ground dash is never shown cleanly, so this is the measured hunter ground dash (1.5-2.5 bh); the data only says the air one goes further | data (Lunar Dash), footage section 4 | `dash.dist` 4.2 | 3.6 m (x0.85 dash feel) |
| Ground dash time | about 0.2 s | footage section 4 | `dash.time` 0.174 | 0.2 s (x1.15 dash feel) |
| Air glide distance | 11-15 m (6-8 bh) over the three landed dashes: 15 m / 1.1 s, 11.5 m / 0.9 s, 13.3 m / 0.8 s; mean 13.3 m | footage (731.1 s, 735.9 s, 745.1 s) | `dash.air.dist` 13.3 | 13.3 m (no dash feel) |
| Air glide time | 0.8-1.1 s, mean 0.93 s | footage | `dash.air.time` 0.95 | 0.95 s |
| Air speed curve | a 0.1 s ramp, a flat burst at about 19-22 m/s (the 731.1 s dash averages 18.5) for 0.4-0.6 s, a float out at 40-65% for 0.2-0.5 s, a dead stop on touchdown | footage | `ramp` 0.1, `burst` 0.4, `out_k` 0.45 | peak 17.1 m/s for 0.4 s, then easing from 100% to 45% (72% on average) over 0.45 s; she leaves it at about 7.7 m/s, so a glide opened from it keeps the shared 70% hand-off (`--airdash-glide-check`) |
| Air height | flat, held up for about 0.6 s, dropping in the last 0.15 s | footage | `float_fall` 1.2 | held to a 1.2 m/s sink until the last 0.15 s |
| Air vs ground | 3-4x the distance, about 5x the time | footage | | 3.8x, 4.75x |
| Cooldowns | ground 7 s, air 14 s (separate) | data | `dash.cd` 7.0, `dash.air.cd` 14.0 (`ArchKit.long_dash_cd`) | 7 s per hop charge, 14 s for the glide (owner: copy Elluna) |

Asserted in `--tender-combo-check` ("mm dashes: Elluna's cooldowns ...", "mm dashes: the ground hop is Elluna's ...", "... the air glide is Elluna's ...", "... 3-4x the hop's distance and about 5x its time").

## Combinations
| Interaction | Implemented in | Check (`--tender-combo-check` unless noted) |
|---|---|---|
| Ember into a Kindled foe winds Hearthlight back | `on_deal` | "an ember into a Kindled foe winds Hearthlight back" |
| Kindle adds damage to embers (+45% at 5) | `outgoing` | "Kindle ramps embers about +45% at 5 stacks" |
| Idle hands: the next ember is Empowered | `_tick`, `_tick_look` | "after a pause the next ember is Empowered" |
| Burrseed: a fixed wind-up (no hold, aim sampled at the throw), sticks, the area at once, roots at 0.7s, Kindles | `fire_rmb`, `_tick_seed`, `_throw_seed`, `_stick`, `_tick_burrs`, `_burst` | the "mm RMB" rows |
| Relay Step through a teammate refunds nothing | `on_dash` | `--support-check` |
| Hearthlight thrown to the cursor; latches onto the first teammate it passes | `e_recast`, `_tick_hearth` | "thrown, it lands on the cursor"; `--support-check` |
| Hearthlight thrown at yourself lands on the one you carry | `e_recast` | `--support-check` |
| Hearthlight on a downed teammate (5x), rank 3 revive on the flare | `_pulse`, `_hearth_end` | `--support-check` |
| A merge start ends the Burrseed aim with no throw (`seed_aim`, `rmb_down`) | `_drop_holds` | "drop_holds ends the Burrseed aim" |
| Hearth Call: the aim telegraph (ring, line) on a teammate under the cursor, X to tether; heals while she walks; pulls a downed teammate home and stands them up | `_call_preview`, `cast_ult`, `_tick_call`, `_call_home` | the "mm X" rows |
| Hearth Call + Hearthlight thrown on the arrival spot (the sheet's pairing) | both run at once | "mm X: other abilities still cast during the channel" |
| Hearth Call pays the bond only on a completed tether or a rescue | `_call_end` -> `KinBond.from_ult` | "mm X: no bond is paid for the cast alone", "... pays the bond as a hit", "a rescue pays ... (kill)", "it breaks ... and pays nothing" |
| Ground skip, then the air glide: Elluna's distances and timings, each its own move, no ring or burst | `on_dash`, `_start_glide`, `own_dash_trail`, `dodge_anim`, KMovesCare `mm_skip` / `mm_float` | "mm dashes: the ground hop is Elluna's ..."; "... the air glide is Elluna's ..."; "... 3-4x the hop's distance and about 5x its time"; "mm dashes: each plays its own move, never the shared roll"; "mm dashes: each move covers its dash and settles soon after (ground 0.16-0.25 s)"; "mm dashes: no other kit plays her dash moves"; "mm dashes: no ring or burst on her hop or glide (two tiny dust puffs, soft motes)" |
| Hearthlight runs out: the last heal blooms, no blast | `_hearth_end`, `_bloom` | "mm E: the light's last heal blooms (heals, no ring, blast or shake; a quiet chime)" |
| A merge start ends Hearth Call (no pull, no bond; `hearth_call`) | `_drop_holds`, `ArchKit.drop_holds` | "mm merge: drop_holds ends Hearth Call" |

## Animation moves
The moves live in `scripts/match/kmoves_care.gd` (`KMovesCare.MOVES`, read by `HunterAnim.km_sample`). The kit plays them with `play()` for abilities, or `play_soft()` for procs (it waits for the current move to finish). She holds nothing (HunterAnim hold `palm`), so both hands are free and every move keys them (`fl` / `fr`).

| Ability | Move | Beats (s) | Shape |
|---|---|---|---|
| LMB ember | `mm_shot_r`, `mm_shot_l` (alternating) | 0.04 wind, 0.08 thrust, 0.18 hold, 0.3 recover, 0.42 | the fist pulled to the hip with the body twisted away, then a straight-arm punch-push at the cursor with the whole body turning about 45 deg past square and the stance dropping; held, then the other hand rises for the next. A swirl, a flash and sparks at that hand on the thrust |
| LMB Empowered | `mm_shot_emp` | 0.09 / 0.14 / 0.3 / 0.55 | a deep coil, then up on the toes with a two-handed push and the free arm flung back |
| RMB wind-up | `mm_seed_aim` | 0.2 turned side-on, 1.0 the throw | side-on (about 70 deg), the fist pointed down the lane, the other hand drawn up by the ear, sinking on the back leg |
| RMB throw | `mm_seed` | 0.05 coil, 0.12 hop and push, 0.32 land, 0.55 | a small hop forward with a two-handed push; the cast flare round her |
| RMB root goes off | `mm_tug` | 0.05 / 0.11 / 0.36 | a tug back on the free hand |
| E lit | `mm_hearth` | 0.08 crouch, 0.18 up, 0.4 hold, 0.65 | a deep crouch, then both arms straight up overhead (the plus and rising rays) |
| E thrown | `mm_toss` | 0.06 / 0.12 / 0.26 / 0.5 | an underhand one-handed fling at the cursor |
| E flare (payoff) | `mm_flare` | 0.07 / 0.15 / 0.3 / 0.6 | both arms flung up |
| Shift Relay Step | `mm_skip` | 0 squash, 0.04 take-off, 0.11 apex, 0.17 touchdown squash, 0.21 bounce, 0.24 | a skip off one foot, the lead knee up and the arms flung up behind like little wings, tucked at the top, a squash on landing and a happy bounce with a shoulder wiggle; a tiny dust puff at take-off and landing |
| Air glide | `mm_float` | 0.06-0.26 somersault, 0.36-0.62 float, 0.85 legs down, 0.95 touchdown, 1.05 | tucked into a ball for one forward somersault, then a seated float with the knees tucked and the arms out wide like a drifting seed, a little sway, a soft squash on touchdown |
| Bearer pickup | `mm_pickup` | 0.12 squat, 0.3 heave, 0.55 | a scoop and a heave onto her back |
| Kindled to 5 | `mm_kindled` | 0.06 / 0.12 / 0.34 | a snap of the fingers by the shoulder, a little bounce |
| X cast (f25) | `mm_call` | 0.05 coil, 0.1 thrust high, 0.2 overshoot, 0.35 into the channel | the hand pulled back low, then thrust up as the plus bursts on the teammate |
| X channel (f26-f73) | `mm_call_hold` (hold) | 0 / 0.3 | one hand held high over the tether; the legs keep walking |
| X end (f74-f77) | `mm_call_end` | 0.07 sweep down, 0.14 arms open, 0.3 | the raised hand swept down to her side (the pull home), open on the arrival burst |

Her dashes leave a few soft ember motes (CareLook "mote") instead of the shared after-image pill, burst and ring (`own_dash_trail`), and her moves are the whole dash pose (`dodge_anim` "kit": no shared roll under them).

Strips: `--arena=thief --arena-demo=care_tender_<lmb|emp|rmb|e|dash|air|airsteer|carry|payoff|walk|pose|ultaim|ultkey|ult> --arena-shot=<dir>/x.png [--care-close]` (scripts/match/care_demo.gd) saves each key moment at its moment and a strip of 4-6 frames cropped round her, at the gameplay camera or (with `--care-close`) a low close-up.

## Look and sound
- Pooled looks (`scripts/arch/kits/care_look.gd`, shaders `care_disc` and `care_glow`, both mixed rather than additive so the colours hold on bright grass): the 0.44 m amber ember comet with a 1.6 m tail and a violet-star impact, the burr orb, the saturated violet Burrseed root disc with thorns, the violet light column and root beams, the lantern plus and rising rays, the warm ring on her and the thrown disc (amber in the middle to teal at a bright rim, with a small caged lantern of light floating over it and drifting motes; no floor plus), the Kindle foot glow, and the dash's ember motes. Nothing is created per shot. Hearth Call's tether (a braid of warm light with two twisting strands) is pooled in `UltLook` (`ult_look.gd`, extends CareLook); its reach ring, pick ring and aim line are AimKit circles and a line.
- Loudness (owner review item 23): the Hearthlight's closing chime plays at -8 dB, and the generic explosion sounds (`boom`, `ab_blast`, `ab_slam`: Boki bursts and riders, area hits) sit 7 dB under the rest of the mix (`Sfx.BLAST_DB`), so their peak stays under -6 dBFS (`Sfx.BLAST_PEAK_DB`, "audio: the explosion category peaks under the agreed level").
- No weapon: an ember glow cupped in each palm; a small satchel and bedroll low on her back, and a long ember-tipped tail (`hero_gear_care.gd`). The character is due an original redesign; this pass only removed the tall pack-frame and the lantern above her head.
- Sounds (`tools/gen_sfx_pip.py`, set `content/sfx/tender.json`, docs/AUDIO.md; light, warm and cute, never fiery): the
  Ember Cast as soft puffs of light with a twinkle (`tend_ember`, three takes; `tend_ember_emp`), `tend_kindled`, Burrseed
  (`tend_seed_aim`, `tend_seed`, `tend_stick`, the woody `tend_root`), Hearthlight (`tend_hearth`, a warm swell, with her
  signature `tender_lantern_chime`; `tend_toss`, `tend_land`, the closing `tend_flare`), `tend_hop`, `tend_pickup`, Hearth Call
  (`tend_call`, a soft wordless choir and the lantern; `tend_call_hum`, three takes; `tend_arrive`) and `tender_cheer` when it
  mends someone, plus her own dash, light little footsteps and a small wordless voice (`tender_hurt`, `_down` with the
  lantern flickering, `_death` with its star dimming). The old names still load through `SfxKits.NAMES`.

## Engine notes
- Kit: `scripts/arch/kits/tender_kit.gd`, with helpers in `care_util.gd`. Data: `content/archetypes/tender.json`, `content/weapons/lantern_crook.json`.
- Merge-start hold fields: `seed_aim` and `rmb_down` (the Burrseed aim), the carry (set down, unbroken), and `hearth_call` (the X channel).
- X: the shared ult base `HeroUlt` (`scripts/arch/hero_ult.gd`, byte-identical across the six ult branches) plugs into main's X path: `HunterKeys.ult_pressed` (the `hunter_ult` key, the level gate) calls the kit's `cast_ult`, which returns `HeroUlt.press(self, _start_call)` (the cooldown in `cd["x"]`, the recast, a cast id); the kit also overrides `has_ult`, `ult_running`, `ult_recast`. Numbers are under `"x"` in `content/archetypes/tender.json`. A downed online teammate rides home on the existing "carry" event and stands up through "rev".
- Net: unchanged (0.16.0, main's); the ult adds no sync shape. The carry uses the existing "carry" event; heals and revives reuse "heal" and "rev". The Burrseed area and the thrown disc are local looks; remote players see the existing Net rings.
- Checks: `--support-check` (all), `--tender-combo-check` (support + combos, `tools/care_combo_check.gd`).
