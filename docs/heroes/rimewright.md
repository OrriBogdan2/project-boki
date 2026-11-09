# Neve the Snowglide (`rimewright`, light ice controller)

Internal design doc. Source behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (gameplay only). The fidelity pass (ext/kitfix-moosh-tamsin) worked from the footage reference sheet (`briefs/hero-ref/tamsin.md`), the public wiki page and the owner's notes. Scale: 1 bh = 1.8 m.

**Owner decision (confirmed): she copies her source exactly, ice control and walls, with no added healing.** The earlier squad extra (an 18-point frost shield for teammates touching the Rink Wall) is removed. `--support-check` asserts the wall gives teammates no shield and no heal.

## Our kit
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive Hoarfrost | | Damaging abilities Chill for 4s (a frost burst, no slow: the source has none). 8 darts on one foe Shatter them: an icy shell closes over them for 0.15s, then a 2.7m starburst of opaque ice-cyan spikes, 60 (15x a dart) in 2.4m. Knocking a Chilled hunter or felling a Chilled monster Shatters them 0.4s later: 37 in 3m (9.3 darts, the data's 324 : 35), plus Chill. A frost glow on the foe grows with each dart | Shatter | Same |
| LMB Ice Dart | hold | A barrage, one dart every 0.18s with no pause: 4 plain darts, then 3 large ones (double damage, 1.5x speed, 1.3x reach, 1.5x the size, flung two-handed with `tm_dart_heavy`), then round again while held; letting go starts the next hold at the plain darts. Plain darts are slow (16 m/s) ice-blue shards with dark teal edges (0.26 m), leave 10 degrees off the aim to alternating sides, fly out straight, and home in toward the end of their flight (owner 23:55, as Celeste's: the turn ramps up from 35% to 70% of the way, up to 12 rad/s) onto the foe nearest the cursor (else the nearest ahead within 75 degrees, else the cursor point), 4 damage, 10m. While skating they fly as thick beams (30 m/s) at the cursor, wherever the skate is heading, and home in late the same way | Ice Darts | The game data's barrage with 3 larger darts at its end (the footage at 5 fps showed no visible pattern) |
| RMB Ice Spear | hold to aim, release to push; 2 charges, 10.2s | Held: the landing ring at the cursor (AimKit `circle`, clamped to 12m); she draws both palms in to her chest and the spear forms between them (growing over 0.3s), pointing at the cursor. Released: a push, not a throw (owner 19:50): both palms drive straight out (0.1s) and the big star-headed spear emerges from her palms, 0.9m in front of her chest, and drives out low at 18 m/s with a frosty trail to the cursor, so the further the target the longer it travels (4m: 0.2s, 12m: 0.65s); it lands there, or on a foe in the way: 18 and a short slow within 1.2m (the data's "small AoE + Slow"). Nothing shows at the target before it arrives. Landing: ice shards burst up, a chill puff, a small camera kick if it is within 7m of her, and a 2.2m slow zone (35%, Chill) with a spinning crystal that everyone sees filling; 1.8s later it detonates, the big hit: 60 in 2.7m, a slow and an ice shell (no root: the data has none), a full-size spike starburst, shards thrown high and a deep shatter. Rank 3: the detonation hits 45% harder | Cryo Spear | Lands at the cursor and detonates late (footage). Owner (item 13, and 19:50 replacing item 28's throw): the spear emerges from her on a two-palm push and travels out, slower than the footage's (about 45 m/s) so it reads, heavier. Data pass (SERVER_UPDATE7): the cooldown is the source's 12s against its 20s wall, scaled to our 17s wall (10.2s); rank 3 is the source's +45% explosion damage, not a wider burst |
| Shift Skate | hold | Skate at 11.5 m/s (full speed within 0.2s) where you move, up to 1.6s; she carves curves with the move keys (3.6 rad/s), throwing ice off the outside edge on a hard turn, and leaves a ribbon of ice chips. LMB keeps firing the whole way: darts become straight beams at the same damage. Rank 3: over the Abyss it lays ice underfoot (a 1.6m span 3.6m long every 0.2s, each holding 5s). It carries on over ledges. Release stops it with a hockey stop; the shorter the skate, the more of the charge comes back (up to 60%). Ice plates form under her blades and fade behind her after 3s (the owner's "a few seconds"), with a frost glint where the blade bites. She has no other dash, and the HUD shows no long-dash pip. Shift pressed in the air (jumping, falling or gliding) starts the skate at once at full skate speed (owner item 62): she skates through the air along her height on a thin ribbon of ice under her blades, sinking only 1.5 m/s (`dash.air_fall`), so it carries her over a gap without being flight; the normal rules hold (hold to keep going, 1.6s, release to stop, the early-stop refund), landing mid-skate goes straight on along the ground, and ending in the air drops her into the normal fall / glide. The ribbon is visual only (the rank-3 ice islands stay the rank upgrade). 13s (the data) | Skate | Main's speed and length (owner 23:20); steering, firing and the refund by shortness are the owner's favourites (23:40). Data pass: the dart bonus while skating (not in the source) is gone; the early-release refund stays by owner request. Rank 3's ice over the abyss is real terrain (`HeroZones.bridge`, ice-tinted) |
| E Rink Wall | tap, tap again | A 0.2s tell (a sparkle at her feet, the path shown to everyone), then a narrow 1.8m block of ice erupts 1 bh ahead and slides at 4.5 m/s toward the cursor (it stops there, 4.5 to 16.2m of travel, up to 3.6s), widening to 4.5m over the slide, stopping enemy shots and carrying foes it meets. It stands 4.5s in all; E again while it slides freezes it in place for 6s. 70 HP. 17s | Frozen Barricade | Travel +50% over the footage's (owner item 13: it did not go out far enough; the data has no number). Her own look: a row of leaning ice pillars on a frosted footing |
| X Rimelock (level 6) | tap; X again to end or set it off | Sealed in her frost bud (six curved ice petals closing over her), invulnerable and rooted. She is a frozen statue (owner item 65): her facing and pose are locked from the cast frame (no turning toward the cursor, no aim tracking, no idle sway or fidget). Cast from a skate (on the ground or in the air, items 62/64), the statue slides on along her skate's velocity and direction (0.8s, easing from the skate's 11.5 m/s to a stop with speed x (1 - (t/0.8)^2): about 6m, 86% of the speed still at 0.3s), without steering or turning, with the rink riding along, in her own braced seal (`tm_rime_carry`); then she is rooted as before until it ends or she breaks out. Cast standing she is rooted at once. A 7.2m (4 bh) rink snaps out round her in 0.2s, shown to everyone with a fill and cracks that brighten as it builds. Foes in it are Chilled and slowed 15%, rising 12% a second they stay, up to 55%. At 3.5s it cracks open: a light pillar on her, her shell bursts into shards, and every foe in the rink she can see takes 40 and a 0.75s ice-block stun. X in the last 0.75s sets it off early at two thirds (damage and stun); X earlier just breaks the shell (no damage, no stun). Nothing else fires while sealed, and she cannot glide (over the abyss she falls; each glide press is refused with a NO GLIDE word); ending it early is the only way out. Shift ends it as X again would and she skates straight out at full skate speed (any speed she had is kept for 0.5s, then eases to the skate's). 80s cooldown (the data) | Ice Crash (newer source of Chilling Finale) | Her own frost bud, not the source's eight-point star; damage set by the burst rule (see Scaling) |
| R | none | The Boki Merge | (Merge) | The Merge is on its own key (Settings.key_cap); the source ult is on X |

Body (`body` in rimewright.json): the final design (art/wardens/claire/IMPORT.md): a grown woman on skates, about 1.08 of a medium to the crown and 1.21 with the hood and horns. The hitbox stays the light 0.35 (her height adds nothing to the top-down target). Long skater's strides (1.4x step cadence), arms held out.

Scaling: light, HP 124. Ratios kept from the footage: dart 35 -> 4, Shatter 529 (15x) -> 60, skating darts x1.6 (56/35), spear detonation 584 (about 1.1x a Shatter) -> 60. Cooldown ratio Skate : Wall kept at 1 : 2 (8.3 : 16.7) -> 8.5 : 17. Rimelock: cooldown 47s against the Wall's 17 (source card 45.8 : 16.7). Its crash is 40 (10 darts, two thirds of a Shatter) instead of the footage's 17 darts (607 / 35): with 68 the crash straight into a merge and the Titan form's ultimate knocked a full-health medium hunter, which the owner's burst rule forbids. `--rimewright-combo-check` "burst:" asserts it (50 + 82 = 132 of 145 at level 6, no armor).

## Parity pass (owner 18:45: LMB first, then the rest by distance from the source)
Source vs ours per slot. [data] = briefs/supervive-data (supervive_kits.md, Celeste), [footage] = briefs/hero-ref/tamsin.md (5 fps).

| Slot | Source | Ours before | Ours now | Asserted (`--rimewright-combo-check`) |
|---|---|---|---|---|
| LMB rhythm | hold: a barrage of semi-homing darts, then 3 larger darts at its end (double damage, faster, longer range) [data]; about one dart per 0.2s, no visible pattern at 5 fps [footage] | a steady stream of identical darts | 4 plain, then 3 large (x2 damage, x1.5 speed, x1.3 reach), round again; 0.18s cadence | `tm LMB: the source's barrage ...`, `... one dart every 0.18 s` |
| LMB tracking | darts curve onto the cursor area [footage 0027-0066]; skating, she turns to face the cursor and fires straight thick beams at it [footage 0239-0245] | the same | the same; asserted while skating with the cursor swung round: the next beam leaves within 1 degree of it | `tm Shift: skating, the beams track the cursor ...`, `... curve back onto the foe` |
| LMB animation | thrown from the hands while walking or skating [footage] | alternating one-hand flicks, a two-hand drive while skating | the same, plus a bigger two-handed fling for the 3 large darts (`tm_dart_heavy`, 0.04 wind, 0.08 fling, 0.18) | `tm LMB: darts alternate hands ...` |
| RMB | lands at the cursor, slow zone, detonation 1.8-2s later [footage]; owner 19:50: a push, the spear emerges from her and travels out | an overhand throw from the raised hand | the two-palm push, travel time = distance / 18 m/s | `tm RMB: ...` (7 rows) |
| E | wall: both hands pushed forward [footage] | the arms flung up and out | both palms shoved out low and wide as the ice erupts | (animation only; the tell timing is asserted) |
| Shift | hold to skate, about 10-11 m/s, full speed in 0.2s, stop in 0.1-0.2s [footage] | 11.5 m/s, 0.2s ramp | unchanged (at parity) | `tm Shift: ...` |
| X | rooted and invulnerable 3.2-3.5s, then the crash [footage] | as the source, plus the owner's skate carry | unchanged | `tm X: ...` |

## Audit (Nov 3 23:40)
Every row of briefs/specs/kit-audit/tarek_ostra_claire.md section 3 (audited on main 200effce) against this branch. (a) done on the branch, (b) fixed now, (c) not applicable or disagree.

| Row | Sev | Verdict | Where / why |
|---|---|---|---|
| RMB is a throw (owner: a push-like emerge) | HIGH | (a) | acd818b3, 59a5b4a7; `tm RMB: the push ...`, `... travel time grows with distance` |
| X from a skate stops her dead (owner: carry, then rooted) | HIGH | (a) | 5909085d; `tm X: skating into it carries ...`, `... encased and rooted ...` |
| LMB stops homing while skating (owner 23:55: home toward the END of the flight, also skating) | HIGH | (b) | e5c73480: darts and skating beams fly out near the aim and turn in over 35-70% of the way; `tm LMB: a dart flies out straight ...`, `tm Shift: skating, beams aimed 1.5 m off a foe still home in late ...` |
| 3 heavy darts at the end of the burst (data) | MED | (a) | f6250bd1; `tm LMB: the source's barrage ...` |
| Ice trail 1.2 s vs "a few seconds" | MED | (b) | ec88bfc0: plates last 3 s; `tm Shift: her ice trail lasts a few seconds ...`. The trail does nothing in play (the data and footage show no gameplay on it) |
| Skate cd 8.5 s vs 13 s (data) | MED | (b) | ec88bfc0: 13 s (ranks 11 / 9.1 s); the owner's early-release refund stays; asserted in the same row |
| Spear impact 4 single-target vs a 156 small AoE + slow (data) | MED | (b) | ec88bfc0: 18 (156 : 35 darts) and a short slow within 1.2 m where it lands; the detonation stays the big hit (owner item 13); `tm RMB: the landing hits a small area ...` |
| Invented 0.5 s root on the detonation | MED | (b) | ec88bfc0: no root (data: damage + slow); the ice shell stays as the look; `tm RMB: it detonates ... no root` |
| X cd 47 s vs 80 s (data) | MED | (b) | ec88bfc0: 80 s; `tm X: its own cooldown (80 s, game data) ...` |
| RMB cd 10.2 s vs 12 s | LOW | (c) | kept: the data pass scaled it by our wall (17 s vs the source's 20 s); every Neve cooldown would have to move together |
| Passive: Chill's 15% slow (not in the source) | LOW | (a) | removed (owner, 2026-11-07: no ours-only riders) |
| Knock Shatter 30 vs about 37 | LOW | (b) | ec88bfc0: 37 |
| E wall touch slow (not in the data) | LOW | (c) | kept: it is how the sliding wall reads as carrying foes; noted here |
| Stale wiki link / name | MED | (a) | f1c1a91c (Class-Neve.md, Classes.md, sidebar) |
| "Merge stays on R" in this doc | MED | (b) | fixed in the table above |
| Self screen shake | MED | (c) | ext/no-shake owns it; nothing added here (the spear's cast shake was removed in acd818b3) |
| Body size 1.3 vs 1.1-1.15 | LOW | (c) | the concept heights (item 46) set it; not this branch's call |
| X numbers, X glide / Shift-out, air Shift (item 62 now skates at once) | n/a | (a) | already matched in the audit |

## Small mechanics
| Mechanic | Source | Footage confirms | Built | Check |
|---|---|---|---|---|
| Damaging abilities Chill for 4s; a Chilled foe knocked or a Chilled creep killed Shatters after a short delay | [wiki](https://supervive.wiki.gg/wiki/Celeste) | yes (Shatter) | yes | "knocking a Chilled foe Shatters them after a beat" |
| 8 dart hits on one target trigger Shatter | [wiki](https://supervive.wiki.gg/wiki/Celeste) | yes (0068) | yes | "8 darts on one foe Shatter them" |
| Darts are semi-homing, curving toward the cursor side | [wiki](https://supervive.wiki.gg/wiki/Celeste), footage | yes | yes | "darts come out slowly ... bowed", "the bowed darts curve back onto the foe" |
| Darts hit harder while skating | [wiki](https://supervive.wiki.gg/wiki/Celeste) (2x), footage (1.6x); not in the tooltip data | yes | removed in the data pass (straight beams, normal damage) | "darts while skating are straight beams at normal damage" |
| Hold to skate in your direction, release to stop, early release refunds part of the cooldown | [wiki](https://supervive.wiki.gg/wiki/Celeste) | yes | yes | "Shift held starts a skate", "letting go stops ... refunds" |
| Skating carries on over a ledge | footage (0199) | yes | yes | "she skates on over a ledge" |
| The spear: closer hits slow more, far hits deal more | [wiki](https://supervive.wiki.gg/wiki/Celeste) | no | replaced by the slow zone (footage) | (see Assumptions) |
| The spear detonates again after a delay | [wiki](https://supervive.wiki.gg/wiki/Celeste) | yes (1.8-2s) | yes | "it detonates about 1.8 s after landing" |
| The wall moves, blocks projectiles, pushes what it hits | [wiki](https://supervive.wiki.gg/wiki/Celeste) | yes | yes | "it slides toward the cursor, widening, and shoves the foe ahead"; "the wall stops a foe's shot" |
| Recast freezes the wall in place; a frozen wall lasts 6s | [wiki](https://supervive.wiki.gg/wiki/Celeste) (patch 22.01.25) | no | yes | "E again freezes it where it stands, for 6 s" |
| A thin aim line to the cursor | footage | yes | yes | "the thin aim line to the cursor is always up" |
| X: invulnerable and rooted inside the shell | card, footage | yes | yes | "tm X: inside the shell she is invulnerable and rooted, and nothing fires" |
| X: the zone's slow stacks for up to 3.5s | [wiki](https://supervive.wiki.gg/wiki/Celeste) | no | yes (15% + 12%/s, cap 55%) | "tm X: the slow on a foe in the rink stacks the longer they stay" |
| X: it goes off by itself at the end (about 3.5s) | footage (f25 -> f57) | yes | yes | "tm X: it cracks open by itself at 3.5 s" |
| X: reactivating in the final 0.75s gives 67% of the effects (damage and stun) | [wiki](https://supervive.wiki.gg/wiki/Celeste) (patch 05.03.25) | no | yes | "tm X: X in the last 0.75 s cracks it open early at two thirds" |
| X: reactivating earlier cancels it, no stun | [wiki](https://supervive.wiki.gg/wiki/Celeste), sheet correction | no | yes | "tm X: X early ends it with no damage, no stun and no bond" |
| X: the crash is blocked by line of sight | [wiki](https://supervive.wiki.gg/wiki/Celeste) | no | yes (from the rink's centre) | "tm X: a foe behind a rock is not hit (line of sight)" |
| X: the floor indicator always shows and the crash hits where it shows (height doesn't matter) | [wiki](https://supervive.wiki.gg/wiki/Celeste) (patch 05.03.25) | no | yes (the rink is fixed where she cast it, drawn for everyone) | "tm X: sealed in, the 4 bh rink shown to everyone" |
| X: allies are unaffected | footage, card | yes | yes (foes only) | (by construction: `foes_in`) |

## Assumptions
- **Dart range:** the darts curve to the cursor and fly on to 10m when nothing is there to home on.
- **Dart pattern:** the footage's uniform stream wins over the wiki's older "ends with 3 larger darts" (the sheet ranks it gap 1; the footage is newer).
- **Ice Spear:** 2 charges with a 10.2s recharge (the source's 12s, scaled by our wall's 17s against its 20s; the card's 0.3s is read as the cast time). Its direct hit is small; the detonation is the big hit. The ice-encased look after it is a 0.5s freeze plus a 1.5s ice shell. The wiki's near/far slow-versus-damage split is dropped in favour of the footage's slow zone.
- **Rink Wall:** it slides until its middle reaches the cursor (4.5 to 16.2m of travel, +50% by the owner) and stands 4.5s in all; the freeze recast is the wiki's (6s).
- **Body and movement (not in the footage):** she has **no separate air dash**: Shift is the skate everywhere, and in the air (owner item 62, replacing item 12's buffer to the landing) it starts at once and skates through the air (see the Skate row). Her **plain jump** is the shared one; her **idle** is the shared idle with her skater's stance (one leg back, arms out, a slight lean). The sheet asks for a ~0.15s stop on release: the stop keeps the shared 30% carry (about 0.1-0.2s to rest).
- **Skate:** 1.6s at most; it goes on over a ledge (and over the abyss it falls once it ends unless rank 3 has laid ice). The rank-3 ice (`dash.ice_*`: look 2m ahead, 3.6m long, 1.6m wide, every 0.2s, 5s) is our own shape and duration; the source gives only "ice islands". Remote players see it through the existing `zone bridge` event, which now carries an optional colour.
- **No squad shield or heal** (owner).
- **Rimelock:** the stun is 0.75s (the dummy stayed encased about 0.5s; the wiki gives no number). The slow ramp (15% + 12% a second, cap 55%) is ours; the wiki only says it stacks for 3.5s. Line of sight is checked from the rink's centre at chest height. The cooldown starts on the cast. Merging while sealed ends it with no crash.
- **Skating into Rimelock (owner 18:20, items 64/65):** the source roots Celeste for the whole ult (footage f25-f55) and says nothing about momentum; the owner wants the skate's velocity and direction to go on into the ult, symmetric with Shift out of it (item 27), and wants her a frozen statue while sealed ("you shouldn't be able to turn your character"). So a skating cast (ground or air skate) slides the statue on for `x.carry_t` (0.8s) at the skate's velocity, easing out as speed x (1 - (t/carry_t)^2): about 6m at 11.5 m/s, 86% of the speed left at 0.3s, no steering or turning; the rink and the crash centre ride with her and settle where she stops. Facing is locked from the cast frame throughout (`ArchKit.face_locked`; the anim state's `statue` key also zeroes the idle sway, glance and fidget). A standing cast roots at once. Carried over an edge she falls (no glide, item 27). Then she is rooted: zero planar speed until it ends or she recasts / Shifts out. Asserted in `--rimewright-combo-check` (`tm X (item 64)`, `tm X (item 65)` x3, `... encased and rooted ...`, `... an early recast frees her`).
- **Rimelock and Shift (owner item 27):** the source data says nothing about dashing out, so Shift ends it the way X again does (a late press still cracks it open at two thirds) and starts the skate at once at full speed. She is rooted while sealed, so the speed she carries out is the skate's own; any planar speed she still had (a knock) is kept for 0.5s. In the air the skate starts at once (item 62).
- **Rimelock and the bond:** `HeroUlt.landed` for each hunter the crash stuns; the cast pays once, for its best event ("hit", "knock" if a hunter went down, "kill" if one was eliminated), through `KinBond.from_ult` with one cast id per cast. Monsters pay nothing (the shared base counts hunters only). The sheet's 0.4 per hunter up to 0.8 is replaced by the main session's per-cast amounts (boki_system.json). An early break pays nothing.

## Combinations
| Interaction | Check (`--rimewright-combo-check` unless noted) |
|---|---|
| A steady stream of equal darts, slow and bowed, curving onto the foe at the cursor | "a steady stream ...", "every dart the same", "darts come out slowly ...", "the bowed darts curve back ..." |
| Darts Chill; the frost glow grows; 8 Shatter | "the frost glow on the foe shows the stacks", "8 darts on one foe Shatter them" |
| A knock on a Chilled foe Shatters them | "knocking a Chilled foe Shatters them after a beat" |
| Skate: the push-off, straight beams at normal damage, the stride loop, over a ledge, the hockey stop and refund; rank 3 lays ice over the Abyss | the "tm Shift" rows |
| Ice Spear: ring at the cursor while held, lands there, slows and Chills in the zone, detonates at 1.8s with a freeze; two charges on 10.2s; rank 3 hits 45% harder | the "tm RMB" rows |
| Rink Wall: the tell, erupts narrow ahead in her look, widens while sliding, shoves, stops at the cursor, freezes on E, stops shots | the six "tm E" rows |
| The wall gives teammates nothing | `--support-check` "Rink Wall: no squad shield or heal" |
| A merge start ends the skate, the spear aim and a wall still in its tell | "drop_holds ends the skate, the spear aim and the wall's tell" |
| Rimelock: sealed, rink for everyone, stacking slow, countdown, crash with the ice-block stun, late and early recasts, line of sight | the "tm X" rows |
| Rink Wall shoves foes into the rink, then the crash stuns them (the sheet's combo) | the wall's carry plus `foes_in` at the crash (the two run independently) |
| Rimelock pays the bond only when the crash stuns someone | "tm X: ... no bond for the cast", "the crash pays the bond as a hit", "three hunters stunned pay one event for the cast" |
| Burst: Rimelock straight into a merge and its ultimate does not knock a full-health hunter | "burst: Rimelock straight into a merge ..." |
| Rimelock in the air: no glide; Shift out of it skates on at speed | "tm X: glide held while sealed ...", "tm X: Shift ends Rimelock and she skates straight out ..." |
| Skate into Rimelock: the statue slides ~6m keeping >= 80% speed for 0.3s, facing locked while the cursor sweeps 360 deg, then rooted; a recast frees her | "tm X (item 64): ...", "tm X (item 65): ...", "tm X: then encased and rooted ...", "tm X: an early recast frees her ..." |
| Skate only: no charge, no dash; a tap is a short skate; an air press skates at once (no buffer); plates form | the "tm Shift:" rows of `_skate_only` |
| Air skate rules (item 62): a jump in the skate rises and the skate goes on, then sinks at `air_fall`; a press while gliding folds the glider; a jump press clear of the ground opens the glider with the speed kept; move id `tm_skate_air` | the rows of `_air_skate`, `_air_skate_rules` |
| Statue (item 65): no dart, jump, glove or Boki C (`cast_locked`), recast and Shift only | `_statue_locks` |
| Her dash moves are her skate only (`tm_skate_go`, `tm_skate`), used by no other hero and fitting the skate's length (owner item 35) | "tm Shift: her dash moves are her own skate ..." |
| Ice Spear throw: drawn back, leaves her hand at 18 m/s, lands on arrival, detonates 1.8s after landing; the wall's 16.2m travel | "tm RMB: let go, she draws back first ...", "tm RMB: the throw ...", "tm RMB: it travels to the target ...", "tm E: it travels 16.2 m at most ..." |
| A merge start ends Rimelock with no crash (`rime`) | "tm merge: drop_holds ends Rimelock with no crash and frees her" |

## Animation moves
In `scripts/match/kmoves_care.gd` ("tm_"), played with `play()` / `play_soft()`. The model plays hand-keyed clips on these timings (`content/rules/warden_anim/claire.json`, `tools/art1/claire_clips.py`): she carries the spear, so darts flick off its tip or her left palm, and the RMB push is both hands driving the shaft. Tone: gentle figure-skating, modest, never seductive.

| Ability | Move | Beats (s) | Shape |
|---|---|---|---|
| LMB dart | `tm_dart_r`, `tm_dart_l` (alternating) | 0.03 cock, 0.07 flick, 0.16 | the fan whipped across the body and out at the cursor with the torso (`wf`), then the free hand flicking a dart, a sharp twist each |
| LMB while skating | `tm_beam` | 0.04 / 0.08 thrust / 0.14 / 0.22 | both hands driven straight out ahead, a stiff lean |
| RMB held | `tm_spear_aim` (hold) | 0.12 | gathering: both palms drawn in to the chest round the forming spear, elbows back, weight on the back foot, a slight crouch |
| RMB release | `tm_spear` | 0.05 load deeper, 0.1 both palms fully out (the spear leaves them), 0.28 held through the recoil, 0.55 | a two-palm push into a lunge after it (owner 19:50: no arm-back wind-up, no throwing release) |
| RMB detonation | `tm_clench` | 0.05 / 0.1 / 0.34 | a sharp clench of the free hand |
| LMB large dart | `tm_dart_heavy` | 0.04 wound away, both hands back to the hip; 0.08 both arms sling forward, the fan snapping open; 0.18 | the barrage's 3 large darts |
| E | `tm_wall` | 0.1-0.2 the tell (a deep crouch, both palms drawn back to the hips), 0.27 both palms shoved out low and wide as the ice erupts, 0.42 held into the slide, 0.7 | footage: "both hands pushed forward" |
| E again | `tm_freeze` | 0.07 knee up, 0.13 stamp, 0.42 | a stamp of the blade, a fist pulled down |
| Shift start | `tm_skate_go` | 0.08 push, 0.16 into the stride | a crouch and a hard push off the back blade |
| Shift held | `tm_skate` (looped by the kit every 0.56s) | 0 / 0.28 / 0.56 | low and leaning hard, knees deep, long pushes one leg then the other, the arms and fan swinging against them, the body rocking |
| Shift release | `tm_skate_stop` | 0.07 / 0.22 / 0.5 | a hockey stop: turned side-on, leaning back hard over braced blades, ice spraying ahead |
| Shatter (payoff) | `tm_shatter` | 0.06 / 0.13 / 0.24 / 0.45 | a big flourish snapping the fan shut, the free fist clenched and pulled in, a lean into it |
| X sealed (f25-f27) | `tm_rime` | 0.06 crouch, 0.12 arms out as the rink snaps, 0.2 down into the seal | |
| X from a skate | `tm_rime_carry` | 0.08 whipped side-on, braced and leaning back, arms flung out; 0.28 grinding on low, arms swinging in; 0.5 sinking into the sealed crouch as she stops | the momentum carry (owner 18:20) |
| X held (f27-f55) | `tm_rime_hold` (hold) | 0 / 0.4 | hunched, arms crossed on the chest, the fan folded in, knees bent |
| X crash (f57-f61) | `tm_rime_crash` | 0.04 deeper, 0.1 flung wide, 0.2 overshoot, 0.4 recovery | everything flung out as the shell bursts |
| X early break | `tm_rime_break` | 0.08 / 0.3 | a shrug that pushes the shell off |

The skate leaves a ribbon of ice chips, ice plates under her blades (CareLook "slab") that fade behind her, and spray off the outside edge on a carve; not the shared after-image pill. No ring or burst on the push-off.

Strips: `--arena=thief --arena-demo=care_rimewright_<lmb|heavy|shatter|payoff|skatefire|rmb|e|dash|air|walk|pose|ultaim|ultkey|ult|ultskate|skateult> --arena-shot=<dir>/x.png [--care-close]`.

## Look and sound
- Pooled looks (`care_look.gd`, shaders `care_ice`, `care_disc`, `care_glow`, all mixed rather than additive so they keep their colour on bright ground): the ice dart (an ice-blue four-sided crystal with dark teal edges, tip first, with a frost streak), the 0.3 m skating beam with its cyan core, the star-headed spear (held in her hand while aiming, then thrown) with its long pale-cyan trail, the slow-zone flake disc with its spinning crystal, the detonation dome, the Shatter spikes, the ice shell, the frost glow, the skate's ice chips, and the Rink Wall's ice pillars (the shared wall node is hidden). Rimelock (`UltLook`, `ult_look.gd`): the rink (care_disc pattern 4: a ragged ice edge and a crack network whose glow is the countdown, a fringe of crystals), her frost bud, the light pillar and the ice block on each stunned foe; the shard burst reuses the Shatter spikes.
- The Hoar Fan model: nine bone slats with long ice-crystal tips, a frosted web and a teal tassel.
- Sounds (`tools/gen_sfx_claire.py`, set `content/sfx/rimewright.json`, docs/AUDIO.md): glass-clear ice, cracking-ice chirps, a steel blade on ice and a wordless woman's voice, airy and siren-like, cold on down and death. Darts `rime_shard` / skating `rime_beam` (3 takes each) and `rimewright_dart_hit` on each dart that lands; the spear `rime_spear_aim` (forming), `rime_lance` (pushed out), `rime_zone` (landing), `rime_burst` (detonation); the Shatter `rime_splinter`; the wall `rime_wall_tell`, `rime_wall`, `rime_freeze`; the skate `rimewright_dash` (push-off), `rimewright_skate_scrape` (each stride) and `rime_stop`; Rimelock `rime_lock`, `rime_creak` (the hold, quickening), `rime_crash` and `rime_crack` (the early break). Signatures: the skate scrape and `rimewright_chime` (the ice crystal chime: the 8-dart shell, the spear's spinning crystal, the wall freezing). Voice and steps through `HeroSfx`: `rimewright_hurt|down|death`, `rimewright_step_<surface>` (a light heel and the tick of her blade).

## Engine notes
- Kit: `scripts/arch/kits/rimewright_kit.gd`; data: `content/archetypes/rimewright.json`, `content/weapons/hoar_fan.json`.
- Merge-start hold fields: `rinkrun` (the skate), `spear_aim` and `rmb_down` (the spear aim), `wall_cast` (the wall's tell) and `rime` (the X seal).
- X: main's `HunterKeys.ult_pressed` takes the `hunter_ult` key (the level gate) and calls the kit's `cast_ult`, which returns `HeroUlt.press(self, _start_rime)` (the ult's own cooldown in `cd["x"]`, the recast, a cast id); the kit also overrides `has_ult`, `ult_running`, `ult_recast`. Numbers are under `"x"` in `content/archetypes/rimewright.json`. Invulnerability is the hunter's `inv_t`, the root its `root_t`.
- The wall is the shared `Verbs.add_wall` (blocking, the touch shove); the kit grows it, slides it, carries foes on its face and draws it.
- Dash flow (item 32): the skate is her dash for `DashFlow` (`in_dash()`); `content/dash_flow/rimewright.json` says LMB fires from it as beams (`variant: beam`, read by `fires_in_dash` and the dart throw), RMB/E/Q/X fire, in the air too (item 62); the statue's slide out of a skate counts as the skate going on, so skate -> X is a "fire" with carry (item 64).
- Net: unchanged (0.16.0, main's); the ult adds no sync shape. Checks: `--support-check`, `--rimewright-combo-check`.

## Parity verify, Nov 9
Verified on origin/main d255acbee against the Neve block of docs/KIT_PARITY.md, `briefs/hero-ref/tamsin.md`, `briefs/supervive-data/supervive_kits.md` (Celeste) and DECISIONS (owner notes win). Verdicts: match, differ (owner), regressed, open. K = `scripts/arch/kits/rimewright_kit.gd`, J = `content/archetypes/rimewright.json`, W = `content/weapons/hoar_fan.json`, D = `content/dash_flow/rimewright.json`. Checks on main: `--rimewright-combo-check` 90/0, `--hero-combo-check` 304/0, `--dash-flow-check` 0 fails, `--clip-check` 0, `--warden-clips-check` 0. No gameplay file changed here: K, J and `care_combo_check.gd` have unmerged Neve branches (neve-chill-shatter, parity-neve-skate-home, neve-lmb-celeste, vfx-neve-crash), so the one open row that needs K is listed, not fixed.

| Row | Source | Ours on main (file:line) | Verdict |
|---|---|---|---|
| Passive: Chill 4 s | Damaging abilities Chill for 4 s | `chill_t` J:53, `add_chill` K:72 | match |
| Passive: no Chill slow | Owner 11-07: no ours-only riders | Chill sets no slow; asserted `tm passive: Chill is 4 s ... no slow` | match |
| Passive: Shatter slow | Shatter is damage only (data) | the Shatter burst hurts with `slow 1.2 s, 30%` (K:138) | **open**: ours-only rider, needs K |
| Passive: 8 darts Shatter | 8 dart hits on one foe burst | `fan_hits` J:52, K:111-121 | match (damage scaled, 60 vs 529) |
| Passive: knock Shatter | Chilled foe knocked or minion killed shatters after a beat | K:98-108, delay J `splinter_delay` | match (37 vs 324, scaled) |
| LMB hold, rhythm | Hold; barrage then 3 larger darts at the end | `burst` 4, `heavy.n` 3, W:28-29; K:190 | match |
| LMB homing | Semi-homing, curves to the cursor | `_tick_darts` K:257, `_homing_k` K:305 | match |
| LMB homing, late in flight | Owner 11-07: home toward the end of the flight | `home_from` 0.35 to `home_full` 0.7, W:22-23; asserted `a dart flies out straight ... curves in late` | match |
| LMB while skating | Owner 11-07: darts semi-home while skating too | `skating` only swaps beam skin, speed, size (K:198-218); `_tick_darts` runs for beams too; asserted `skating, beams aimed 1.5 m off ... home in late` | match |
| LMB skating damage | Footage 56 vs 35 (1.6x) | normal damage (data pass); asserted `straight beams at normal damage` | differ (data pass); owner call if 1.6x returns |
| LMB cadence | One dart per ~0.2 s | `rate` 0.18, W:9 | match |
| RMB input | Tap, lands at the cursor | hold to aim, release pushes (K:540-604) | differ (owner) |
| RMB push emerge | Owner 19:50: push, not throw | K:604 (palms, 0.9 m out); asserted `the push: the spear emerges` | match (owner) |
| RMB travel time | Owner: grows with distance | `dist / speed`, speed 18, J:88; asserted `travel time grows with distance` | match (owner) |
| RMB slow zone, delayed blast | Zone, detonates 1.8-2 s later | K:628-690, `delay` 1.8 J:95 | match |
| RMB charges, cd | 2 charges, 12 s | 2, 10.2 s (J:84-85) | differ (owner scaling, 0.85x) |
| RMB numbers | Data 156 then 190; footage 584 | 18 then 60 | differ (footage ratio) |
| E Rink Wall | Pushes, blocks shots, recast freezes, 20 s | `cast_e` K:691, `_freeze_wall` K:756, cd 17 J:117 | match (0.85x cd) |
| Shift Skate hold | Hold to skate, release stops, 13 s | `_tick_rinkrun` K:380, cd 13 J:60 | match |
| Shift speed | 10-11 m/s, full speed 0.2 s | 11.5, J:61, `ramp` 0.2 | match (footage 10-11, owner kept 11.5) |
| Shift over ledges | Carries on over the edge | K:386-391; asserted `skates on over a ledge` | match |
| Shift ice path | Owner: skate with an ice path | `_lay_ice` K:441, plates K:522; rank 3 bridge over the Abyss | match |
| Shift release refund | None in source | 0.6 refund J:63 | differ (owner) |
| Air Shift | Not shown | skates at once in the air, no separate slot (item 62) | differ (owner) |
| X: carried forward, then encased | Owner: carry, then rooted until it ends or she cancels | `_start_rime` K:867, `carry_t` J:177; asserted `skating into it keeps >= 80% ... then encased and rooted` | match (owner) |
| X: radius, hold, cd | 4 bh zone, 3.5 s, 80 s | 7.2 m (4 x 1.8), 3.5, 80 (J:174-178) | match |
| X: crash, stun | Damage + stun at the end | `_rime_crash` K:1010, 40 and 0.75 s (J:181-182) | match (scaled) |
| X: cancel | Recast early ends it, no stun | `ult_recast` K:913, `_rime_cancel` K:1035 | match |
| X: late recast | Fine print: late recast stuns (67%, wiki) | `late` J:179 | match |
| X: zone stacks | Zone applies Shatter stacks | stacking slow + Chill in the rink (K:973) | differ (small; stacks are a slow ramp) |
| Cancels: Shift out of X | Owner item 27 | K:962; D `into_dash.x` cancel | match (owner) |
| Cancels: glide out of skate | Glide opens only on a double press | `_glide_pressed` K:434 | match |
| Dash-flow, ground/air to LMB RMB E X Q | Nothing stops a cast during the held skate | D:6-19 all `fire`, carry | match (`--dash-flow-check`) |
| Dash-flow, into_dash | Shift in a wind-up | D into_dash: LMB/RMB/E/Q fire, X cancel | match |
| Dash-flow, `hold.lmb` | none | no `hold.lmb` row in D (a missing row combines) | match (no source row) |
| Dash-flow, `hold.rmb` | none | `keep` x3, D | match (`[?]`, no source) |
| Dash-flow source text | Owner: darts home while skating | D:6 said "straight thick beams" | fixed here (text only, no behaviour) |
| Clips | Footage poses | every `tm_*` kit move has a clip in `claire.json`, 0 fails | match |

Open, not fixed (needs a file an unmerged Neve branch changes): the Shatter slow, K:138. Remove `"slow": 1.2, "slow_k": 0.3` from the `splinter` hit, and assert `foe.slow_t == 0` after a Shatter in `--rimewright-combo-check`. Stale text in files held by other branches: J card `dash` ("your darts fly straight and thick") and the Neve block of docs/KIT_PARITY.md (still "Claire", "15% slow", "straight while skating") are fixed by ext/neve-lmb-celeste and ext/parity-neve-skate-home once merged.
