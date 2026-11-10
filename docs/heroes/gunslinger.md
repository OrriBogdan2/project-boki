# Vex the Hired Gun (archetype id `gunslinger`, Medium; was Marlowe)

Internal design note (may cite the source for traceability; nothing in the game does).
Source behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (reference
sheet: briefs/hero-ref/venator.md, from the source's real segment; owner notes override the footage).
Our hero is an original character, the ember-rifle skirmisher: a visored cap, a cropped jacket, a long
streaming scarf, a bandolier of spiked charges, one bronze pauldron and a long-shrouded drum rifle.
Palette: ember orange, bronze and hot white. Payoff word: SKEWERED.

## Kit card (L picker)
- Role: Mid-range rifleman: Daze a foe with the grenade's cone, then shred them while it lasts.
- LMB, RMB, E, Shift, passive and the ultimate: one plain line each in `content/archetypes/gunslinger.json` `card`
  (the ultimate's line is `card.x`; the kit card's last tile shows it on the hunter-ultimate key).

## Scaling
Our Medium has 145 HP against roughly 1.4k to 1.6k, about 1/10. Rifle 6 per round, decaying to half
over a 10-round string; on a Dazed foe +90% (the source reads about 1.9x) with no decay. Grenade cone 16,
Longneedle 36. Cooldowns follow the source ratio 5.4 : 7.5 : 10 at our pace 6.5 : 8.5 : 11.5. Cinderfall: the source's impact read 931 on a
centred dummy (620 + 50%), about 62 at our scale; ours is 24 (36 in the centre) so that the ult straight into
a merge cannot one-shot a full-health Light even at level 10 (growth +35%). The patch is 3 every 0.5 s for 3 s (the source's 144 a tick is
about 14, held lower for the same cap) and slows 30%. Its cooldown follows the source's 37.5 s at our pace,
42 s. Ranges use
1 bh = 1.8 m: rifle 11 m, grenade lane 10.5 m (about 6 bh), cone 6 m (3.5 bh), Longneedle 18 m (10 bh),
slide tap 4.6 m and hold 7 m.

## Ranks: upgrade parity (rank 2 = source tier II, rank 3 = tiers II+III+IV)
The shared step (cooldown -10%, damage +15%, dash recharge 15% faster a rank) no longer applies to Vex: each slot reads
`rank_cd` / `rank_dmg` in the JSON, and a slot the source gives no such upgrade stays at 1.0. Source: Ghost, `Upg:` lines.

| Slot | Source upgrade | Ours before (rank 2 / 3) | Ours after (rank 2 / 3) |
|---|---|---|---|
| RMB Burr Charge | -1.5s cooldown x2, tier IV: resets on a knock | 5.85s / 5.2s, reset on a knock | 5.4s / 4.3s, reset on a knock at 3 |
| Space Slipstep | -1.5s recharge x2, tier IV: +25% speed 2s after a slide | 7.65s / 6.0s, speed burst at 3 | 7.4s / 6.3s, +25% speed 2s at 3 |
| E Longneedle | +20% damage x2, tier IV: 30% shave per hunter | cooldown 10.35s / 9.2s, damage +15% / +30%, shave at 3 | cooldown 11.5s flat, damage +20% / +40%, 30% shave per hunter at 3 |

## Audit (Nov 3 23:40)

The kit audit (briefs/specs/kit-audit/vex_vireo_sable.md, Vex rows, against main 200effce), row by row: (a) already
done on this branch, (b) fixed now, (c) not applicable or disagree, with the source. Asserts are in
`--gunslinger-combo-check` (tools/venator_parity_check.gd and tools/hero_combo_check.gd).

| Row (sev) | Call | What and where |
|---|---|---|
| RMB animation, side toss (HIGH) | (a) | 3ad081dd, 899102f9: held low and out wide at the hip, a sidearm flick at 0.05s, leaving 1.05m up. Assert `Vex parity RMB: a side toss ...` |
| Slide scrape disc every 0.05s (HIGH) | (b) | Dropped from `_tick_echo`; the after-images, dust and skid streaks stay. Assert `Vex audit: no ground ring, disc or column on a slide, its rank-3 end or a knock` |
| Self shake on E, the blast and the throw (HIGH) | (a) / (c) | The direct `add_trauma` calls went in 3ad081dd. `Feel.shake`'s caster share and `Oomph.punch_dir` belong to ext/no-shake (item 50); nothing added here |
| Rank-3 slide-end ring, knock ring and column (MED) | (b) | Removed; the knock keeps +KNOCK, its sound, the rifle flourish and the HUD reset cue. Same assert as the disc |
| Longneedle's ground smoke ring and cast ring (MED) | (b) | The recoil smoke now puffs up as a short column round her, and the cast's online ring is gone (everyone already sees the narrowing line) |
| LMB magazine and refill (MED) | (a) | 3ad081dd: 30 rounds, refilling at 40/s after 0.35s off the trigger. Assert `Vex parity LMB: a 30-round drum ...` |
| Dazed's 35% slow (MED) | (b) | Removed from KitStatus "rat": the data's Daze is only extra rifle and Railgun damage. Assert `Vex audit: Dazed is a damage window only` |
| Dash-flow sources and into_dash rows (MED) | (a) / (b) | Sources: 731ca7b9, from the dash-buffering finding. into_dash: all "fire" (item 51: every move combos with Shift), measured: Shift in the Longneedle charge slides and the beam fires; Shift right after the tapped Burr Charge slides at once. Assert `Vex audit: Shift in the Longneedle charge ...`. Jump rows: DashFlow has no jump rows; jumping already keeps every hold |
| Wall slam: Dazed longer (LOW) | (b) | `wall_daze` 0.6s on top of the cone's 1.4s (data: "Dazed longer and Stunned"). Assert `RMB wall slam: the walled foe is Dazed longer` |
| RMB cooldown and damage (LOW) | (c) | 6.5s follows the footage (5.4s at level 9) at our pace; the data's 9s is level 1. Owner pacing call, unchanged |
| Shift cooldown (LOW) | (c) | 8.5s sits between the data (11.5) and the footage (7.5) |
| Air dash barrel roll; LMB during it (LOW) | (b) | `fires_in_dash` reads the dash's LMB row (fire), so the rifle keeps going through the air roll too. The roll itself is ours (the source never shows an air dash). Assert `Vex audit: the rifle fires through her air roll` |
| Dash -> E (LOW) | (c) | Kept "fire" (item 51); the footage's braced stand is the plain cast |
| Passive, E numbers, X (-) | (c) | Match the data |
| She/her in the shown text (LOW) | (b) | `gunslinger.json` fantasy ("her rifle"), this page and the kit comments |
| Stale `dash_spent` tell (LOW) | (b) | "an ember afterimage and faint skid streaks" |

## Parity pass (LMB first)

The owner's parity request (INBOX 13:45 ET): the attack animations, how the aim tracks, and the cadence, slot by
slot against the source. [game data] is briefs/supervive-data (Ghost; the shared rotation rate from
supervive_physics.md); [footage] is briefs/hero-ref/venator.md (5 fps); owner notes override both. Asserted in
`--gunslinger-combo-check` (tools/venator_parity_check.gd, lines `Venator parity ...`).

| Slot | Beat | Source | Ours before | Ours now |
|---|---|---|---|---|
| LMB | pose | the rifle shouldered at the chest on the cursor, a low wide aim crouch; the recoil shows in the gun and the muzzle, the body stays still [footage 0007-0036, body 7] | a 0.14s torso kick restarted every round (a jitter at 8 rounds a second), no stance | a shouldered pose (chest over the front knee, stock in, a wide crouch standing); each round kicks the gun up and back by 0.025s, back on the shoulder by 0.09; after the last round it stays up a beat and eases out by 0.55 |
| LMB | legs | the upper body turns to the cursor and the legs keep walking [footage] | free | the crouch is a stance: none at a run |
| LMB | tracking | direction only, rounds to max range past the cursor; yaw 1280 deg/s [footage, game data] | the same | unchanged; asserted with the cursor sweeping round her at 6 rad/s while she walks: every round leaves on its own step's aim; 180 degrees in 0.15s |
| LMB | cadence | a string of about 10 rounds in about 1.4s [footage] | 0.12s | unchanged; asserted held |
| LMB | slow while firing | "no visible slow while firing" [footage] | the shared 80% | none (`fire_slow` 1.0) |
| LMB | magazine | a 30-round magazine that "rapidly reloads when not firing"; the first 10 rounds of each hit harder [game data]; no reload is seen in the footage | 24 rounds, then a 1.7s reload | 30 rounds; after 0.35s with no round leaving it refills at 40 rounds a second (a string after a pause starts full, as its first 10 rounds do). No reload exists (owner decision 23:45 UTC): run dry, the trigger is dead until the drum is full again (about 1.1s, held or not), then the string picks up |
| LMB | reticle | two arcs "( )" bracket the hunter left and right while firing, about 0.7 bh [footage 0026, 0099] | none | two thin arcs 1.25m out either side, on your screen only, while the rifle fires |
| RMB | launcher shot | the owner, item 112: fired from the cannon's top launcher, "the bigger explosion thing, not the minigun" (replaces the side toss and the footage's overhand) | cocked over the shoulder, an overhand whip, leaving 1.6m up | no throw: a recoil kick on the cannon, a muzzle puff and the grenade thunk |
| E | recoil | a ~0.5 bh shove back on fire [footage] | the shove, and a screen shake on your own camera | the shove; no screen shake (owner rule 50) |
| X | cast | the rifle raised straight up and fired [footage] | the same, and a screen shake on your own camera | no screen shake (owner rule 50) |
| Shift | | a front-loaded 0.45s skid, firing through it [footage] | already the source's (kit data pass) | unchanged |

## Timing pass (Nov 8)

Every move in content/rules/warden_anim/vex.json measured in game (`--gunslinger-combo-check`,
tools/vex_anim_time_check.gd, lines `TIME ...` and `Vex timing ...`): when the kit plays the move, when the clip
owns the body (blend in), the hit or release frame, and when the body is back with the legs (blend out), against
the footage frames in briefs/hero-ref/venator.md (one frame = 0.2 s, so anything under 0.2 s is within its
resolution) and the timings above. Blend in is 0.1 s and blend out 0.16 s on every move (WardenClips.FADE,
FADE_LOCO): both under one footage frame. Seconds from the press.

| Move | Source (s) | Ours before | Ours after |
|---|---|---|---|
| LMB | a round every ~0.12, recoil in the gun only | round and move on the press's frame, clip 0.53, re-played each round (0.12) | unchanged |
| RMB (launcher tap, owner item 112) | throw commit ~0.2 (superseded: a tap) | Burr at 0.02, clip 0.50, legs back 0.67; walking: the legs walk | unchanged |
| Shift tap | skid ~0.45, upright by 0.55-0.6 | skid ends 0.53 (dash feel's time scale), clip 0.87 (stand-up key 0.62), legs back 1.03; walking off: the clip's standing legs stayed on her (full 1.00) to 0.75 and past | walking off the skid, the legs are hers from the skid's end (loco blends in by 0.68) |
| Shift held | the slide holds, she stands as it ends | the clip stood up at 0.62 mid-slide (skid ends 0.73) | the clip holds its slide key (0.45) while she slides; stand-up 0.73, legs back 1.30 |
| Shift in the air / dash_ex | not in the footage | 0.87 clip at the air hop, 0.6 travel | unchanged |
| E Longneedle | cast bar 0.6, shove 0.2, recovery ~0.4 (settled ~1.2) | beam 0.63 on the clip's fire key (0.65), clip 1.07, legs back 1.23; walking after the shove: the clip's standing legs stayed on her to 1.05 and past | beam 0.63; walking off after the shove (from 0.8) the legs are hers (loco in by 1.03) |
| X Cinderfall | raise then fire ~0.2, ~0.8 committed, no move seen | star, column and shot sfx on the press (0.02); clip 0.60, arm down 0.77; walking: frozen legs (full 1.00) | the shot leaves on the clip's kick key (0.14: the barrel is up at 0.1); walking through it the legs walk (upper body raise); the disc and column still show at the press |
| Knock (gunslinger_knock) | not in the footage | 0.60 clip, back 0.77 | unchanged |
| Hit, land | not in the footage | hit 0.42, land 0.4 | unchanged |

Not built (ours, for the owner): an E recovery lock of ~0.4 s after the beam (the source's ~0.4 s recovery; ours
lets her walk right after the shove, which the recoil impulse already allows) and the source's ~0.8 s X commit
(ours is 0.6 s of clip, free to walk).

Clip re-keys for origin/ext/vex-v2-model (not done here: the GLB and tools/art1 are that branch's):

| Clip | Re-key |
|---|---|
| x | hold the barrel up from 0.1 to ~0.3 (the source's raise then fire) and settle by ~0.8 if the owner wants the source's 0.8 s commit; the shot's kick key stays at 0.14 (GunslingerUlt.FIRE_T) |
| rmb | the swing could return by ~0.3 (a tap, item 112); 0.5 now |
| dash | a loopable slide window around 0.45 (the held slide holds that key; a 2-3 key loop would read better than a still) |
| lmb | none: 0.53 at a 0.12 cadence re-plays from its kick each round |

## Per-slot table
| Slot | Input | Aim | What it does | Telegraph / reticle | Move (KMovesVV) | Sound |
|---|---|---|---|---|---|---|
| LMB Quill Rifle | hold | max range (11 m) past the cursor, `"aim": "max"` | auto rifle, a 30-round drum that refills fast whenever the trigger rests (no reload; run dry, it fires again once full, about 1.1s); a string loses half its punch over 10 rounds; a Dazed foe takes +90% in big gold numbers and the string doesn't decay | the aim line runs to full range; two firing brackets either side of her; ember tracers with a cooling tail, a bronze muzzle star | `gunslinger_lmb` (shouldered, the gun kicks per round) | `vn_rifle` |
| RMB Burr Charge | tap, fired from the cannon's launcher on the press (owner items: no hold, no throw) | max range, a fixed 10.5 m line along the aim | goes off on the first foe it strikes (22 damage, Dazed 1.4s, no cone); otherwise it flies the lane and sticks to a wall or the ground at the lane's end; a 6 m, 100° cone back toward you for 0.9s, then the blast on everyone in it: 16, a big shove along the cone, Dazed 1.4s; a hunter shoved into more terrain is stunned 0.7s | while held: a white lane with an arrow tip, foes inside it marked with a magenta ring; when stuck: the filling cone (everyone sees it); the blast front and a Dazed swirl | `gunslinger_rmb_hold` (low at the hip), `gunslinger_rmb` (a sidearm side toss) | `vn_cock`, `vn_throw`, `gunslinger_grenade_thunk`, `vn_blast` |
| Shift Slipstep | tap / hold | where you move, not the aim | tap 4.8 m skid, hold 7 m slide that is owed 40% more cooldown (the kit-data pass: no refund for releasing early); you shoot through either; an air tap slides 2/3 of the hold distance | none (a white ring and an ember afterimage at the start) | `gunslinger_dash` (feet first, leaning back, rifle up); with no charge in the air `gunslinger_dash_ex` | `vn_slide` |
| E Longneedle | press, stand still 0.6s | direction, a fixed 18 m line through terrain; the line locks to the press direction and turns toward the cursor at most `turn_deg_s` 90 deg/s (so a flick cannot drag it), and the beam goes exactly along it | a 1.8 m wide beam (0.9 m either side, was 0.5: item 68) through everything in line: 36, +20% on a Dazed foe, a Dazed hunter is Skewered (payoff); a hunter hit takes 20% off the cooldown (rank 3: 30% for every hunter hit); the recoil shoves you back a step | a wide bright line narrowing to a thin core over the cast (everyone sees it); cursor charge ring; muzzle orb, flat flare, smoke ring | `gunslinger_e` (brace, recoil overshoot, settle) | `vn_ion_charge`, `vn_ion_fire`, `hero_skewer` |
| Passive Hot Streak | | | a knock gives Slipstep back (the takedown heal is DashReset's 5%, the kit adds none); an ability that lands lights Fever (one flat 6% lifesteal, 3.5s) | one pip over the bar; a column and ring on a knock | `gunslinger_knock` (rifle spun up) | `vn_stim` |
| X Cinderfall (ultimate, level 6) | tap | at the cursor, clamped to 14 m; lands exactly there (no tracking) | the rifle snaps straight up and fires; 1.6 s later the shell lands: 24 to everyone within 3.4 m, +50% within 1.2 m of the centre; then the patch burns 3 s, 3 every 0.5 s and a 30% slow; she moves and shoots freely; 42 s cooldown | a 3.4 m ground disc with ticks that fills toward the impact, its hot red centre ring and a bronze rivet ring closing in (everyone sees all of it), a dark scorched disc, an ember light column; the shell (a big spiked charge) falls through the column for the last 0.8 s; impact: a white-hot column, ember shock rings, an ember spray, "DEAD CENTRE" on a centre hit; the patch: a scorched disc with a lit ember rim and flickering flames | `gunslinger_x` (rifle straight up, kick, back down by 0.6 s) | `vn_nuke_fire`, `vn_nuke_fall`, `vn_nuke_boom`, `vn_nuke_burn` |
| R / T | | | the Boki Merge (the Boki system's key) | | | |

## Combinations
| Combination | What fires | Check |
|---|---|---|
| Grenade past a foe, ground cone back over them | Dazed, shoved toward you | `--gunslinger-combo-check` |
| Dazed foe + rifle | +90%, gold numbers, no decay | `--gunslinger-combo-check` |
| Dazed foe + Longneedle | +20%, Skewered on a hunter | `--gunslinger-combo-check` |
| Grenade on a wall, foe shoved into terrain | stun, the cooldown is untouched | `--gunslinger-combo-check` |
| Longneedle hit on a hunter | cooldown -20%; rank 3 -30% per hunter hit | `--gunslinger-combo-check` |
| Slipstep while firing | rounds keep going, the slide follows the keys | `--gunslinger-combo-check` |
| Knock | Slipstep back, no kit heal; rank 3 resets the grenade | `--gunslinger-combo-check` |
| Stun during the Longneedle cast, or a Boki merge | cast cancelled, nothing fires | `--gunslinger-combo-check` |
| Longneedle, a flick across the screen at the press | the beam turns at most 90 deg/s x 0.6 s; a close aim leaves the camera alone | `--gunslinger-combo-check` |
| Burr Charge cone (Dazed, shoved toward you), then Cinderfall on them | a slowed foe in the disc is hard to get out in 1.6 s | `--gunslinger-combo-check` (disc, impact, slow) |
| Cinderfall on an enemy hunter, then the Merge | the impact fills the bond (KinBond.from_ult, a hit); the merge straight after never one-shots a full-health light hunter | `--gunslinger-combo-check` (burst) |
| Stepping off the disc | no damage and no bond | `--gunslinger-combo-check` |

## Cancels (ability to ability)

What a second press does during the first action's wind-up, active part and recovery: **cancels** it (the first
ends), **both** (the second goes now and the first runs on), **waits** (buffered, and for how long) or **ignored**.
Dash rows (Shift either way) are in [dash_interactions.md](dash_interactions.md), not repeated here. Sources: [D]
briefs/supervive-data/supervive_kits.md, [F] the footage sheet (5 fps: one frame is 0.2 s, so a buffer shorter than
that can't be seen), [W] the wiki page linked above, owner = DECISIONS / OWNER_REVIEW_1103. Ours is origin/main
d255acbee, read in the code and probed headless (cancel-matrix pass, 11-09). **Unsettled** means no frame, card
line or wiki line shows the pair: ours stays as it is and nothing was guessed. Any pair not in the table: both
(ArchKit has no shared cast lock), except that every press is ignored, not buffered, while stunned or downed,
and the attack key does nothing from a glide (`Hunter.can_fire`).

| First (phase) | Second | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|---|
| E Longneedle, wind-up (0.6 s, standing still) | LMB | not shown: the rifle is braced through the cast bar, no round seen leaving | both: the rifle fires through the charge (3 rounds in 0.3 s) and the beam still goes | unsettled | [F] 0164-0169 |
| E wind-up | RMB | not shown | both: the grenade leaves, the beam still goes | unsettled | |
| E wind-up | jump | not shown (he stands still, no jump pressed in the clip) | both: a 0.9 m hop, the charge goes on (walking is 0 in the cast) | unsettled | [F] 555.8-556.4 s |
| E wind-up | X | not shown | ignored, not buffered (`GunslingerUlt.cast` refuses while the needle charges) | unsettled | |
| E wind-up | glide | not shown | the glider opens, the charge goes on | unsettled | |
| E recovery (about 0.4 s after the recoil) | any | not shown | the cast is over at the beam: everything goes at once | unsettled | [F] 0170 |
| X Cinderfall, after the shot (shell falling 1.6 s) | walk, jump, LMB | free: he walks and takes a jump pad while it falls | free: she moves, jumps and shoots | match | [F] ult f103 |
| X | E, RMB | not shown | both | unsettled | |
| LMB held (the string) | RMB, E, X | not shown | both: the string goes on through each | unsettled | |
| LMB held | jump | not shown (he fires while walking) | both | unsettled | [F] 0007-0023 |
| RMB (the launcher shot) | any | owner item 112: a tap, no hold and no throw, so there is no wind-up to cancel | instant: everything goes at once | owner | OWNER_REVIEW_1103 112 |
| Glide | LMB | not shown | ignored | unsettled | |
| Glide | RMB, E, X | not shown | each goes (RMB as its air variant) | unsettled | |

Fixes made: none. No pair has a source frame or line that disagrees with ours. Timing note (not a cancel): the
wiki's Railgun reads "Charge for 0.8s"; ours is the footage's 0.6 s cast bar (a later patch than the clip, or the
level-9 hunter).

## Small mechanics
| Mechanic | Source | Footage | Built and checked |
|---|---|---|---|
| Rifle damage decays over the first 10 rounds to 50% | [wiki: Ghost](https://supervive.wiki.gg/wiki/Ghost) (rifle) | numbers 60 to 30 | yes: data asserted |
| Bonus damage to Dazed targets | [wiki](https://supervive.wiki.gg/wiki/Ghost) | 1.9x yellow numbers | yes: "+90%", gold numbers |
| Wall blast: cone, knockback, launched into terrain = stun | [wiki](https://supervive.wiki.gg/wiki/Ghost) (Spike Grenade) | cone shown | yes |
| The caster's view pushes out 25% and leans along the line through the cast, easing in and out over about 0.2 s, no shake | Owner item 68 | not shown | yes: "Vex item 68" |
| The Longneedle's aim locks at the press and turns at a capped 90 deg/s (`turn_deg_s`); a 180-degree flick moves the beam at most 54 deg, a small adjustment still lands | Owner item 144 (Ghost's E feel) | not shown | yes: "a 180-degree flick" |
| The push-out scales with the aim distance: none inside 5 m (`view_near_m`), a smooth ramp to the full 25% at the 18 m range, eased | Owner item 144b | not shown | yes: "an aim at 3 m leaves the camera alone" |
| Aim stays free through a dash: the body and rifle stay on the cursor, only the legs follow the slide (owner item 109) | Owner | slides up-left while firing up-right | yes: "Vex item 109", `--dash-aim-check` |
| Combat Slide: tapped in the air for 2/3 of the full-hold distance | [wiki](https://supervive.wiki.gg/wiki/Ghost) patch 05.03.25 | not shown | yes: "an air tap slides 2/3 of the full hold" |
| Hold = a longer dash on a longer cooldown, no refund | kit data (SERVER_UPDATE7) | not separable | yes: "a held slide is owed a longer cooldown and letting go early refunds nothing" |
| Knocks reset the slide | [wiki](https://supervive.wiki.gg/wiki/Ghost) | not shown | yes |
| The omnivamp stacks wear off all at once | [wiki](https://supervive.wiki.gg/wiki/Ghost) patch 05.03.25 | not shown | yes: "Fever wears off all at once"; "one flat level of 6%" |
| Railgun pierces terrain and every target | [wiki](https://supervive.wiki.gg/wiki/Ghost) | crosses a chasm | yes: through a wall, two targets |
| The grenade sticks to dynamic objects (shields, barricades) | [wiki](https://supervive.wiki.gg/wiki/Ghost) patch 20.11.24 | not shown | partly: it sticks to terrain blocks; other heroes' walls that are blocks count |
| Mini Nuke: lands where the cursor was at cast, 1.6 s after, no tracking | reference sheet (both casts) | f29 to f45 | yes: "it lands exactly at the cursor", "nothing lands before 1.6s" |
| Mini Nuke: +50% damage in the centre | [thebackdash hunter list](https://thebackdash.com) (older "arcane napalm" wording) | red-orange core (f41) | yes: "+50% in the centre" |
| Mini Nuke: the zone lasts 3 s, damages each second and slows | thebackdash | ticks about every 0.5 s (f48 to f60) | yes: "the patch burns and slows", gone after 3 s |
| The caster keeps moving after the cast | reference sheet | jump pad at f103 | yes: "Vex moves and can shoot while it falls" |

## Assumptions (the video is silent or the owner overrode it; the owner can correct these)
- **Owner rule (1103 playtest):** a direct hit on a hunter hurts and Dazes them; the grenade no longer passes through people. A wall or the ground at the lane's end still gives the cone, which Dazes everyone in it. Dazed raises the rifle by 90% and Longneedle by 20% (the source's reference ratios).
- RMB is a tap fired from the arm-cannon's top launcher (owner item 112: no hold, no throw): on the press, ground or air, no lane first. It leaves from `launcher_fire` on the new model, above the gun's muzzle otherwise; the flash waits 0.1 s for `launcher_muzzle`.
- **The drum, with no reload in the game (owner decision 23:45 UTC):** the data gives Ghost's rifle a 30-round
  magazine that "rapidly reloads when not firing", and the footage never shows a reload. Ours: after 0.35 s with no
  round leaving, the drum refills at 40 rounds a second (the data says only "rapidly"). Run dry, nothing fires until
  the drum is full again, whether the trigger is held or not (0.35 s + 0.75 s); that full refill is the only pause a
  long string has. No key, timer or animation reloads it. Data: `refill_after`, `refill_rate` in
  content/weapons/quill_rifle.json; rule: `GunslingerKit._tick_mag`.
  The firing brackets are a firing tell only; our rifle's spread doesn't bloom, so they don't move.
- Dazed is our Rattled status (slow plus the damage window); it now applies to the training dummy too.
- Fever follows the kit data: a flat +6% omnivamp for 3.5s from any ability hit (no stacks). The footage build only had the knock reset.
- The Longneedle has no movement while charging (self_slow 1.0) and its recoil is a short shove.
- A slide in the air spends a charge and stops short instead of carrying.
- Cinderfall: the range is 14 m (the footage only shows 5 bh in range); the disc is 3.4 m (about 1.9 bh) with a
  1.2 m centre; the zone ticks every 0.5 s (the footage; the older wording says per second) for 3 and slows 30%
  for 0.6 s per tick. Allies are untouched (no friendly fire is mentioned). A cursor over the abyss still drops it
  there. A Boki merge does not cancel a shell already fired (it is not a hold). Only the impact pays the bond;
  the sheet's 0.8 for a centre hit or two hunters is not one of the bond kinds (hit, knock, kill), so every hit
  pays the hit share (see the report's owner questions).

## Footage gaps, Nov 9 re-check
The ranked gaps in briefs/hero-ref/venator.md section 4 (written before 22ceca1e1), checked on main d255acbee.
Asserts named are in `--gunslinger-combo-check` (tools/hero_combo_check.gd, tools/venator_parity_check.gd).

| # | Gap | On main | Where |
|---|---|---|---|
| 1 | Daze payoff on the rifle | closed | 22ceca1e1: `rattle_k` 0.9, gold numbers, no string decay. Asserts `Dazed: the rifle does +90%`, `Dazed: big gold numbers`, `Dazed: the string's decay pauses` |
| 2 | Wall cone has no pre-telegraph | closed; in flight to be cut | 22ceca1e1: `_tick_burrs` fills an `AimKit.cone` for everyone over the fuse, then `_detonate`. Assert `RMB: the cone shows back toward you, for everyone`. ext/vex-greenfire-1108 (owner 11-08 item 12) makes Coin Blast hit-only and deletes the stick, fuse and cone |
| 2b | Cone length, knock | closed; in flight to be cut | 22ceca1e1: `cone_len` 6.0, `push` 11.0. Assert `RMB ground cone: damage + Dazed + shoved toward you`. Same greenfire note |
| 3 | Fuse 0.9 | closed; in flight to be cut | 22ceca1e1: `burr.fuse` 0.9. Assert `RMB: 0.9s fuse`. Same greenfire note |
| 4 | RMB held aim lane | owner override | OWNER_REVIEW_1103 item 112 (Nov 5, after the "side toss" line in DECISIONS): tap only, no hold; 04648e2a0. Assert `RMB tap: thrown on the press, nothing held, no lane shown`. The coin flick (ext/vex-coin-palm-1108) keeps the tap |
| 5 | Fires on a tapped slide; cooldown | firing closed; cooldown open (row 9) | `ArchKit.fires_in_dash` reads the dash's LMB row (`fire`). Assert `Slipstep tap: the rifle keeps firing`. ext/vex-dash-parity-rebased: one Shift charge |
| 6 | Passive: footage has only the knock reset | closed to the kit data | 65ffef1e7: the knock reset plus Fever, one flat 6% for 3.5 s (Combat Rush data, not ours). Asserts `Knock: Slipstep back ...`, `small: Fever is one flat level of 6%` |
| 7 | Longneedle timing, recoil | closed | 22ceca1e1: `charge` 0.6, `self_slow` 1.0, `recoil` 6.0, `linger` 0.75; `gunslinger_e` brace in kmoves_vv.gd. Asserts `Longneedle: fires at 0.6s`, `Longneedle: the recoil shoves you back`. In flight: ext/vex-e-turn (turn cap), ext/vex-coin-palm-1108 (from the palm) |
| 8 | Longneedle line narrows; muzzle orb | closed | 04648e2a0: `_tick_needle` `width_to` 12%; orb and flare in `_fire_needle`. Assert `Longneedle: the line narrows over the cast (18m)` |
| 9 | Cooldowns | open | Rank 1 RMB 6.5, Shift 8.5, E 11.5; footage (level 9) 5.4 / 7.5 / 10; data (level 1) 9 / 11.5 / 12. Which level "source values" means is the owner's call (DECISIONS 11-07 default 1.0x) |
| 10 | Slide identity | afterimage closed; ring owner override | 596288ff1 `_tick_echo` afterimages. Rings cut by DECISIONS "no bursts, rings or discs on dashes" and 1d5cdfd46. Assert `Vex audit: no ground ring, disc or column on a slide ...` |
| 11 | Dazed reads for the whole window | in flight | KitStatus `rat` on main; ext/combo-marks-a b7353ee3a adds the overhead Daze tag with a time ring |
| 12 | Grenade throw animation | owner override; in flight | Item 112: no throw, a cannon kick. Assert `Vex item 112: no throw pose ...`. ext/vex-coin-palm-1108 (owner 11-08): a coin flick from the cyborg hand |
| 13 | Mini Nuke | closed | 96831d533: Cinderfall, her ultimate (`gunslinger_ult.gd`) |
| 14 | Mana | no change | The sheet's own call: our kits have no mana |

The per-slot table's "while held: a white lane" and the Shift "white ring" lines are stale (rows 4 and 10); they
are left alone here because every in-flight Vex branch rewrites those rows.

## Ultimate choice
X is her own ultimate, Cinderfall (owner decision, SERVER_UPDATE6): the source's Mini Nuke, built from the
reference sheet's "Ultimate (on X)" section. It was never folded into another slot during the kit pass, so no
slot changes. The Boki Merge is on its own key.

## Ground shapes (telegraph audit)

Rule (DECISIONS items 4, 8, 50, 96): a ring, disc or burst on the ground means gameplay, so every one drawn must be the true hit area. `tools/hero_combo_check.gd` and `tools/vv_ult_check.gd` assert drawn size = hit size.

| Ability | Ground shape drawn | Hit | Seen by | Source read | Status |
|---|---|---|---|---|---|
| Rifle (LMB) | two thin arcs flanking her, r 1.25 m (firing brackets) | none (hitscan rounds) | her screen only | thin brackets while firing | kept: a tell on her body, not an area |
| Burr Charge (RMB), in flight | none | 0.72 m wide shot, 10.5 m | - | a shell, no ground shape | ok |
| Burr stuck (RMB), 0.9 s fuse | cone, 6.0 m long, 100 deg, pointing back at her | same cone (`cone_len`, `cone_deg`) | everyone locally | a cone back toward her | ok, asserted. Online the cone shows as a fixed 5 m fan (the net event has no length); a real fix needs a Net change, so it is a suggestion only |
| Burr hit / stuck / detonation | none (was a 1.0, 1.6 and 1.8 m ring) | the cone above | - | no ring on the burr | removed: cosmetic rings that matched no hit |
| Longneedle (E) charge | line 18 m long, 1.8 m wide narrowing to a core over 0.6 s | beam 18 m, 1.8 m wide, at 0.6 s | everyone locally | wide line narrowing to a core | ok, asserted |
| Slipstep (dash) | none | none | - | none | ok |
| Cinderfall (X) fall | disc r 3.4 m filling over 1.6 s, hot core 1.2 m, rivet ring closing onto r | 3.4 m, core 1.2 m, at 1.6 s | everyone locally | disc fills to the impact | ok, asserted |
| Cinderfall impact | one ring at r 3.4 m | the disc | everyone | impact ring | fixed: was two rings at 1.3x and 0.7x r |
| Cinderfall burn, 3 s | rim r 3.4 m fading | ticks inside 3.4 m | everyone locally | burning patch | ok |

Suggestion (not built): carry the burr cone length over the network so remote players see the true 6 m cone.

## Engine notes
- Kit `scripts/arch/kits/gunslinger_kit.gd`; pooled looks `scripts/arch/kits/vv_fx.gd`; moves
  `scripts/match/kmoves_vv.gd`; rifle model `scripts/match/hero_arms_vv.gd`; sounds `tools/gen_sfx_vex.py`.
- Rattled ("Dazed" on screen) is a `KitStatus` status carried by the existing Net event. No Net change.
- Cinderfall: `scripts/arch/kits/gunslinger_ult.gd` (GunslingerUlt) on the shared ult base `scripts/arch/hero_ult.gd`
  (HeroUlt); X reaches it through main's HunterKeys.ult_pressed and `GunslingerKit.cast_ult()`; numbers in
  `gunslinger.json` `x`.
- Merge cleanup: `_drop_holds()` ends `needle` and `slide`. Cinderfall
  has no hold or channel (a tap, then the shell is out), so it adds nothing there.
- Screenshots: `--vv-shots --shots-dir=<dir> --vv-hero=gunslinger`.
