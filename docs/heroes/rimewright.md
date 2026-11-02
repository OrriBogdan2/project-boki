# Tamsin, the Rimewright (`rimewright`, light ice controller)

Internal design doc. Source behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (gameplay only). The fidelity pass (ext/kitfix-moosh-tamsin) worked from the footage reference sheet (`briefs/hero-ref/tamsin.md`), the public wiki page and the owner's notes. Scale: 1 bh = 1.8 m.

**Owner decision (confirmed): she copies her source exactly, ice control and walls, with no added healing.** The earlier squad extra (an 18-point frost shield for teammates touching the Rink Wall) is removed. `--support-check` asserts the wall gives teammates no shield and no heal.

## Our kit
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive Hoarfrost | | Damaging abilities Chill for 4s (15% slow, a frost burst). 8 darts on one foe Shatter them: an ice-spike starburst, 60 (15x a dart) in 2.4m. Knocking a Chilled hunter or felling a Chilled monster Shatters them 0.4s later: 30 in 3m, plus Chill. A frost glow on the foe grows with each dart | Shatter | Same |
| LMB Ice Dart | hold | A steady stream, one dart every 0.18s with no heavy phase or pause. Darts are slow (16 m/s), leave bowed 18 degrees to alternating sides and home hard (7 rad/s) onto the foe nearest the cursor (else the nearest ahead within 75 degrees, else the cursor point), 4 damage, 10m. While skating they fly straight as thick beams (30 m/s) for 1.6x | Ice Darts | The footage stream over the wiki's older 4+3 heavy pattern |
| RMB Ice Spear | hold to aim, release to throw; 2 charges, 7s | Held: the landing ring at the cursor (AimKit `circle`, clamped to 12m) and a raised-spear pose. Released: a fast star-headed spear (45 m/s) lands at the cursor (4 to a foe in the way, where it then lands), leaving a 2.2m slow zone (35%, Chill) with a spinning crystal that everyone sees filling; 1.8s later it detonates: 60 in 2.7m, a 0.5s freeze and an ice shell | Cryo Spear | Lands at the cursor and detonates late (footage) |
| Shift Skate | hold | Skate at 8 m/s (about 1.6x a run) where you move, up to 2.4s, steering gently (2.2 rad/s). It carries on over ledges. Release stops it with a hockey stop; stopping early refunds up to 60% of a charge. Darts become 1.6x beams. In the air: the long dash (a tumbling side flip). 8.5s | Skate | Rank 3's ice bridge over the abyss is still a visual only |
| E Rink Wall | tap, tap again | A 0.2s tell (a sparkle at her feet, the path shown to everyone), then a narrow 1.8m block of ice erupts 1 bh ahead and slides at 4.5 m/s toward the cursor (it stops there, 3 to 10.8m of travel), widening to 4.5m, stopping enemy shots and carrying foes it meets. It stands 3s; E again while it slides freezes it in place for 6s. 70 HP. 17s | Frozen Barricade | Her own look: a row of leaning ice pillars on a frosted footing |
| X Rimelock (level 6) | tap; X again to end or set it off | Sealed in her frost bud (six curved ice petals closing over her), invulnerable and rooted; a 7.2m (4 bh) rink snaps out round her in 0.2s, shown to everyone with a fill and cracks that brighten as it builds. Foes in it are Chilled and slowed 15%, rising 12% a second they stay, up to 55%. At 3.5s it cracks open: a light pillar on her, her shell bursts into shards, and every foe in the rink she can see takes 40 and a 0.75s ice-block stun. X in the last 0.75s sets it off early at two thirds (damage and stun); X earlier just breaks the shell (no damage, no stun). Nothing else fires while sealed. 47s cooldown | Ice Crash (newer source of Chilling Finale) | Her own frost bud, not the source's eight-point star; damage set by the burst rule (see Scaling) |
| R | none | The Boki Merge | (Merge) | Merge stays on R; the source ult was never folded into another slot |

Scaling: light, HP 124. Ratios kept from the footage: dart 35 -> 4, Shatter 529 (15x) -> 60, skating darts x1.6 (56/35), spear detonation 584 (about 1.1x a Shatter) -> 60. Cooldown ratio Skate : Wall kept at 1 : 2 (8.3 : 16.7) -> 8.5 : 17. Rimelock: cooldown 47s against the Wall's 17 (source card 45.8 : 16.7). Its crash is 40 (10 darts, two thirds of a Shatter) instead of the footage's 17 darts (607 / 35): with 68 the crash straight into a merge and the Titan form's ultimate knocked a full-health medium hunter, which the owner's burst rule forbids. `--rimewright-combo-check` "burst:" asserts it (50 + 82 = 132 of 145 at level 6, no armor).

## Small mechanics
| Mechanic | Source | Footage confirms | Built | Check |
|---|---|---|---|---|
| Damaging abilities Chill for 4s; a Chilled foe knocked or a Chilled creep killed Shatters after a short delay | [wiki](https://supervive.wiki.gg/wiki/Celeste) | yes (Shatter) | yes | "knocking a Chilled foe Shatters them after a beat" |
| 8 dart hits on one target trigger Shatter | [wiki](https://supervive.wiki.gg/wiki/Celeste) | yes (0068) | yes | "8 darts on one foe Shatter them" |
| Darts are semi-homing, curving toward the cursor side | [wiki](https://supervive.wiki.gg/wiki/Celeste), footage | yes | yes | "darts come out slowly ... bowed", "the bowed darts curve back onto the foe" |
| Darts hit harder while skating | [wiki](https://supervive.wiki.gg/wiki/Celeste) (2x), footage (1.6x) | yes | yes, 1.6x | "darts while skating are straight beams at 1.6x" |
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
- **Ice Spear:** 2 charges with a 7s recharge (the card's 0.3s is read as the cast time). Its direct hit is small; the detonation is the big hit. The ice-encased look after it is a 0.5s freeze plus a 1.5s ice shell. The wiki's near/far slow-versus-damage split is dropped in favour of the footage's slow zone.
- **Rink Wall:** it slides until its middle reaches the cursor (3 to 10.8m of travel) and stands 3s in all; the freeze recast is the wiki's (6s).
- **Skate:** 2.4s at most; it goes on over a ledge (and over the abyss it falls once it ends); rank 3's ice bridge stays a visual (no terrain editing).
- **No squad shield or heal** (owner).
- **Rimelock:** the stun is 0.75s (the dummy stayed encased about 0.5s; the wiki gives no number). The slow ramp (15% + 12% a second, cap 55%) is ours; the wiki only says it stacks for 3.5s. Line of sight is checked from the rink's centre at chest height. The cooldown starts on the cast. Merging while sealed ends it with no crash.
- **Rimelock and the bond:** one `KinBond.from_ult` call per crash with its best event ("hit", "knock" if a hunter went down, "kill" if one was eliminated). The sheet's 0.4 per hunter up to 0.8 is replaced by the main session's per-cast amounts (boki_system.json). An early break pays nothing.

## Combinations
| Interaction | Check (`--rimewright-combo-check` unless noted) |
|---|---|
| A steady stream of equal darts, slow and bowed, curving onto the foe at the cursor | "a steady stream ...", "every dart the same", "darts come out slowly ...", "the bowed darts curve back ..." |
| Darts Chill; the frost glow grows; 8 Shatter | "the frost glow on the foe shows the stacks", "8 darts on one foe Shatter them" |
| A knock on a Chilled foe Shatters them | "knocking a Chilled foe Shatters them after a beat" |
| Skate: the push-off, straight 1.6x beams, the stride loop, over a ledge, the hockey stop and refund | the five "tm Shift" rows |
| Ice Spear: ring at the cursor while held, lands there, slows and Chills in the zone, detonates at 1.8s with a freeze | the four "tm RMB" rows |
| Rink Wall: the tell, erupts narrow ahead in her look, widens while sliding, shoves, stops at the cursor, freezes on E, stops shots | the six "tm E" rows |
| The wall gives teammates nothing | `--support-check` "Rink Wall: no squad shield or heal" |
| A merge start ends the skate, the spear aim and a wall still in its tell | "drop_holds ends the skate, the spear aim and the wall's tell" |
| Rimelock: sealed, rink for everyone, stacking slow, countdown, crash with the ice-block stun, late and early recasts, line of sight | the "tm X" rows |
| Rink Wall shoves foes into the rink, then the crash stuns them (the sheet's combo) | the wall's carry plus `foes_in` at the crash (the two run independently) |
| Rimelock pays the bond only when the crash stuns someone | "tm X: ... no bond for the cast", "the crash pays the bond as a hit", "three hunters stunned pay one event for the cast" |
| Burst: Rimelock straight into a merge and its ultimate does not knock a full-health hunter | "burst: Rimelock straight into a merge ..." |
| A merge start ends Rimelock with no crash (`rime`) | "tm merge: drop_holds ends Rimelock with no crash and frees her" |

## Animation moves
In `scripts/match/kmoves_care.gd` ("tm_"), played with `play()` / `play_soft()`.

| Ability | Move | Beats (s) | Shape |
|---|---|---|---|
| LMB dart | `tm_dart_r`, `tm_dart_l` (alternating) | 0.03 cock, 0.07 flick, 0.16 | the fan snapped across the body, then the free hand flicking a dart |
| LMB while skating | `tm_beam` | 0.04 / 0.08 thrust / 0.2 | both hands driven straight out, a stiff lean |
| RMB held | `tm_spear_aim` (hold) | 0.12 | the spear raised high behind the head, leaning back |
| RMB release | `tm_spear` | 0.05 deeper, 0.11 whip, 0.26 overshoot, 0.55 | a whip through into a long lunge |
| RMB detonation | `tm_clench` | 0.05 / 0.1 / 0.34 | a sharp clench of the free hand |
| E | `tm_wall` | 0.1-0.2 the tell (deep crouch over the feet), 0.27 erupt (hands thrown up and out), 0.4 overshoot, 0.7 | |
| E again | `tm_freeze` | 0.07 knee up, 0.13 stamp, 0.42 | a stamp of the blade, a fist pulled down |
| Shift start | `tm_skate_go` | 0.08 push, 0.16 into the stride | a crouch and a hard push off the back blade |
| Shift held | `tm_skate` (looped by the kit every 0.56s) | 0 / 0.28 / 0.56 | low, leaning, legs pushing out in turn, arms swinging opposite, the body rocking |
| Shift release | `tm_skate_stop` | 0.08 / 0.2 / 0.45 | a hockey stop: side-on, leaning back over braced blades |
| Air dash | `tm_dash_air` | 0.05 tuck, 0.15 flip, 0.22 catch | a tumbling side flip |
| Shatter (payoff) | `tm_shatter` | 0.06 / 0.12 / 0.4 | the fan snapped shut, the fist clenched |
| X sealed (f25-f27) | `tm_rime` | 0.06 crouch, 0.12 arms out as the rink snaps, 0.2 down into the seal | |
| X held (f27-f55) | `tm_rime_hold` (hold) | 0 / 0.4 | hunched, arms crossed on the chest, the fan folded in, knees bent |
| X crash (f57-f61) | `tm_rime_crash` | 0.04 deeper, 0.1 flung wide, 0.2 overshoot, 0.4 recovery | everything flung out as the shell bursts |
| X early break | `tm_rime_break` | 0.08 / 0.3 | a shrug that pushes the shell off |

The skate leaves a trail of ice chips; the air dash leaves teal after-images.

Strips: `--arena=thief --arena-demo=care_rimewright_<lmb|skatefire|rmb|e|dash|air|payoff|pose|ultaim|ultkey|ult> --arena-shot=<png>`.

## Look and sound
- Pooled looks (`care_look.gd`, shaders `care_ice`, `care_disc`, `care_glow`): the ice dart (a four-sided crystal, tip first, with a frost streak), the skating beam, the star-headed spear with its long white trail, the slow-zone flake disc with its spinning crystal, the detonation dome, the Shatter spikes, the ice shell, the frost glow, the skate's ice chips, and the Rink Wall's ice pillars (the shared wall node is hidden). Rimelock (`UltLook`, `ult_look.gd`): the rink (care_disc pattern 4: a ragged ice edge and a crack network whose glow is the countdown, a fringe of crystals), her frost bud, the light pillar and the ice block on each stunned foe; the shard burst reuses the Shatter spikes.
- The Hoar Fan model: nine bone slats with long ice-crystal tips, a frosted web and a teal tassel.
- Sounds (`tools/gen_care_sfx.py`): `rime_shard`, `rime_beam`, `rime_spear_aim`, `rime_lance`, `rime_zone`, `rime_burst`, `rime_splinter`, `rime_run`, `rime_stop`, `rime_wall_tell`, `rime_wall`, `rime_freeze`, `rime_flip`, and for Rimelock `rime_lock` (a crackling freeze), `rime_creak` (the hold, quickening), `rime_crash` (a deep boom and a glassy shatter) and `rime_crack` (the early break), loaded through `SfxKits.NAMES`.

## Engine notes
- Kit: `scripts/arch/kits/rimewright_kit.gd`; data: `content/archetypes/rimewright.json`, `content/weapons/hoar_fan.json`.
- Merge-start hold fields: `rinkrun` (the skate), `spear_aim` and `rmb_down` (the spear aim), `wall_cast` (the wall's tell), `rime` (the X seal) and `x_aim` (ArchKit).
- X: `HeroUlt` routes the `hunter_ult` key; the kit overrides `cast_ult`, `ult_running`, `ult_recast`. Numbers are under `"x"` in `content/archetypes/rimewright.json`. Invulnerability is the hunter's `inv_t`, the root its `root_t`.
- The wall is the shared `Verbs.add_wall` (blocking, the touch shove); the kit grows it, slides it, carries foes on its face and draws it.
- Net: unchanged (0.16.0, main's); the ult adds no sync shape. Checks: `--support-check`, `--rimewright-combo-check`.
