# Ability sounds against the beat (11-18)

Does each Hero's own sound land on what it belongs to? Measured by `--sfx-strike-check`
(tools/sfx_strike_check.gd) on origin/main 0a0b02d277 plus the three sound moves below. Every move of the 12 kits (LMB tap, LMB held 0.5 s, RMB tap, RMB held 0.5 s, E, R)
is pressed once in a real match at a dummy 3 m away, 60 steps a second. Every fire, cast, impact and signature
sound of the Hero's set (content/sfx/<arch>.json) is timed.

- **strike**: the frame the faster hand moves fastest in the skeleton, as the clip is played in the match
  (blends included). A Hero with no clip on that move, or a hand slower than 8 m/s (a rifle's aim), has none.
- **release**: the frame a shot of the Hero's own first appears (a throw, a bolt, a swing's reach), and the first
  rock of a Stone Row or a Basalt Spine rising.
- **hit**: every frame the dummy takes damage (the gameplay hit).
- **heard**: a sound counts from its play plus its lead-in, the first 10 ms of its file at 30% of its peak. Most
  cues start at once; a few are built to lead in (jug_riposte 100 ms, br_spine 150 ms) and are on the beat that late.
- Wind-up sounds (a name part: wind, aim, draw, overdraw, charge, tell, summon, place, count, whirl, hum, creak,
  shield_up, pilot, spin, leap, prime, and Stone Row's tell br_crack) belong before the beat and are not timed.
- A sound heard more than 50 ms from every event of its move fails its kit's row, unless it is listed below as
  right where it plays (`KNOWN` in the check). Re-run it for fresh numbers:
  `godot --headless --path . -- --sfx-strike-check [--strike-only=<arch>]` prints one `ROW` line per move.

## Fixed (sound played by the event itself, asserted by the check)

| Hero | Move | Sound | Event | Change |
|---|---|---|---|---|
| Albert (bulwark) | LMB hammer throw | bjorn_throw | the hammer leaving his hand (+43 ms of the clip's strike) | was at the press |
| Tenzo (dolm) | E Stone Row | br_raise | the first rock up (+0) | was its own `m.later` timer |
| Grimble (dredge) | RMB hook, tap and held | dr_throw | the arm's launch after the coil-back (+0) | was at the press, 217 ms early |

## Release gesture (Meeko and Motley)

`mm_shot_r/l/emp` fade 0.03 s, `mm_hearth` 0.05 s, `ostra_seed` 0.03 s (was the default 0.1 s), and Meeko's
`THRUST_T` 0.03: the gesture shows on the release instead of a blend after it.

## Right where they play (KNOWN in the check)

Sounds past 50 ms of every event of their move: a sound on its own event (travel time or a delayed effect: Lace E
rain, Cinder R jet landing, Vex grenade thunk and nuke, Kael heal, Motley seed press, Meeko chime, Grimble coin
jingle, Tenzo punch and Basalt Spine end) or a clip that lands early or late, listed for an anim pass: Cinder
LMB-hold lw_roar (-100), Neve E rime_wall (-67), Sparkle R vv_ult_rise (-67), and the ready pings jug_ting and
dolm_rock_crunch (played from the arch's ready cue, not a strike).

## Rows (ms after the press: clip strike, release, hit; each sound is `name@ms (offset from the nearest event)`)

| arch | move | strike | release | hit | sounds |
|---|---|---|---|---|---|
| ROW | archer | lmb | - | - | - | pin_draw@17 (wind-up) |
| ROW | archer | lhold | - | 500 | 533 | pin_draw@17 (wind-up), archer_thread_twang@500 (+0), pin_loose@517 (-7), pin_arrow_hit@533 (+0) |
| ROW | archer | rmb | - | - | - |  |
| ROW | archer | hold | 517 heavy | 500 | 533 | pin_heavy_draw@17 (wind-up), pin_heavy@500 (+0), pin_heavy_burst@500 (+0), archer_hit@533 (+0) |
| ROW | archer | e | - | 0 | 383 | pin_hail@0 (+0), pin_rain@367 (-17), pin_patter@383 (+0), archer_hit@383 (+0) |
| ROW | archer | r | - | 0 | 17 | pin_super_hit@17+30 (+30), archer_hit@17 (+0) |
| ROW | ashwick | lmb | 33 lance_end | - | - | lw_pilot@0 (wind-up), ashwick_tank_hiss@17 (-17) |
| ROW | ashwick | lhold | - | - | 400 | lw_pilot@0 (wind-up), lw_roar@300 (-100 !), ashwick_hit@400 (+0), ashwick_tank_hiss@500 (+100 !) |
| ROW | ashwick | rmb | - | 17 | 100 | lw_bolt@17 (+0), ashwick_hit@100 (+0), lw_bolt_hit@100 (+0), as_ignite@100+80 (-3) |
| ROW | ashwick | hold | 217 aim | 500 | 583 | lw_bolt@500 (+0), ashwick_hit@583 (+0), lw_bolt_hit@583 (+0), as_ignite@583+80 (-3) |
| ROW | ashwick | e | 33 cloak | - | 0 | lw_shield@0+180 (+147 !), ashwick_cloak_hit@0 (+0), ashwick_hit@0 (+0) |
| ROW | ashwick | r | 33 jet | - | 533 | lw_jet@0 (-33), lw_trail@467+20 (-47), ashwick_hit@533 (+0), lw_jet_land@1967 (+233 !) |
| ROW | bulwark | lmb | 67 lmb_throw | - | 183 | bjorn_throw@100 (+43), bulwark_hammer_clang@183 (+0), bjorn_plant@233 (+50) |
| ROW | bulwark | lhold | 533 lmb_slam | 500 | 550 | bjorn_spin@200+80 (wind-up), bjorn_slam@500 (+0) |
| ROW | bulwark | rmb | - | - | - |  |
| ROW | bulwark | hold | 33 rmb_guard | - | - | bjorn_shield_up@117+160 (wind-up), bulwark_hull_creak@117+50 (wind-up) |
| ROW | bulwark | e | - | - | - | bjorn_purify@0 |
| ROW | bulwark | r | 417 x_slam | - | 400 | bjorn_ult_slam@400 (+0), bjorn_ult_rumble@400 (+0), bjorn_ult_quake@400 (+0), bjorn_slam@817 (+0) |
| ROW | dolm | lmb | 117 lmb_throw | 150 | 267 | br_throw@150 (+0), br_boulder_hit@267 (+0), dolm_hit@267 (+0) |
| ROW | dolm | lhold | 583 lmb_wind | - | 500 | br_wind@267 (wind-up), dolm_rock_crunch@367 (-133 !), br_punch@500+60 (-23), dolm_hit@500 (+0) |
| ROW | dolm | rmb | 33 rmb_land | - | 17 | br_slam@17 (+0), dolm_hit@17 (+0) |
| ROW | dolm | hold | 1133 rmb_slam | - | 1367 | dolm_rock_crunch@67 (-1067 !), br_crack@467 (wind-up), br_leap@617 (wind-up), br_slam@1367 (+0) |
| ROW | dolm | e | 100 e_row | 200 | - | br_crack@0 (wind-up), br_raise@200 (+0) |
| ROW | dolm | r | 67 x_spine | 233 | 233 | br_crack@0 (wind-up), dolm_hit@233 (+0), br_slam@1017 (+683 !) |
| ROW | dredge | lmb | - | 0 | 133 | dr_shot@0 (+0) |
| ROW | dredge | lhold | - | 0 | 133 | dr_shot@0 (+0) |
| ROW | dredge | rmb | 100 throw | 217 | 350 | dr_throw@217 (+0), dr_grab@350 (+0), dr_reel@350 (+0), dredge_coin_jingle@600 (+260 !) |
| ROW | dredge | hold | 100 throw | 217 | 350 | dr_throw@217 (+0), dr_grab@350 (+0), dr_reel@350 (+0), dredge_coin_jingle@600 (+260 !) |
| ROW | dredge | e | 317 anchor | - | 383 | dr_anchor_wind@0+30 (wind-up), dr_anchor@383 (+0) |
| ROW | dredge | r | - | 1083 | 1117 | dr_blast@1083 (+0) |
| ROW | gunslinger | lmb | - | 0 | 17 | vn_rifle@0 (+0) |
| ROW | gunslinger | lhold | - | 0 | 17 | vn_rifle@0 (+0) |
| ROW | gunslinger | rmb | - | - | 100 | gunslinger_grenade_thunk@0 (-100 !), vn_blast@100 (+0) |
| ROW | gunslinger | hold | - | - | 100 | gunslinger_grenade_thunk@0 (-100 !), vn_blast@100 (+0) |
| ROW | gunslinger | e | 633 e | - | 633 | vn_ion_charge@0+90 (wind-up), vn_ion_fire@633 (+0) |
| ROW | gunslinger | r | 50 x | - | 1600 | vn_nuke_fire@133 (+83 !), vn_nuke_boom@1600 (+0) |
| ROW | juggernaut | lmb | 100 slash_r | 17 | 67 | juggernaut_blade_hiss@17 (+0), jug_slash@17+80 (-3) |
| ROW | juggernaut | lhold | 567 wave | 500 | 550 | jug_ting@317 (-183 !), jug_wave@500 (+0), juggernaut_blade_hiss@500 (+0) |
| ROW | juggernaut | rmb | 567 slam | - | 600 | jug_slam_wind@17+50 (wind-up), jug_slam_hit@600 (+0) |
| ROW | juggernaut | hold | 533 lunge | - | 600 | jug_ting@67 (-467 !), jug_charge@317+210 (wind-up), jug_lunge_hit@600 (+0) |
| ROW | juggernaut | e | 100 chain | 0 | 67 | jug_chain@0 (+0), juggernaut_chain_rattle@0 (+10), juggernaut_chain_bite@67 (+0), jug_taut@67 (+0) |
| ROW | juggernaut | r | 667 riposte | - | 750 | jug_riposte@633+90 (-27), juggernaut_heal@750+100 (+100 !) |
| ROW | mage | lmb | - | 0 | 67 | vv_bolt@0 (+0), mage_zap@67 (+0), mage_hit@67 (+0) |
| ROW | mage | lhold | - | 0 | 67 | vv_bolt@0 (+0), mage_zap@67 (+0), mage_hit@67 (+0) |
| ROW | mage | rmb | - | 350 | 400 | vv_rod_throw@350 (+0), mage_hit@400 (+0), mage_zap@400 (+0), mage_rod_hit@400 (+0) |
| ROW | mage | hold | - | 500 | 533 | vv_rod_summon@17 (wind-up), vv_rod_throw@500 (+0), mage_hit@533 (+0), mage_zap@533 (+0) |
| ROW | mage | e | - | - | 817 | vv_sky_place@0 (wind-up), vv_sky_count@17+160 (wind-up), vv_sky_strike@817 (+0), mage_hit@817 (+0) |
| ROW | mage | r | 350 ult_air | - | - | vv_ult_rise@283 (-67 !) |
| ROW | ostra | lmb | - | 0 | 33 | os_orb_hot@0 (+0), ostra_hit@33 (+0), os_prime@1433 (wind-up) |
| ROW | ostra | lhold | - | 0 | 33 | os_orb_hot@0 (+0), ostra_hit@33 (+0), os_prime@1433 (wind-up) |
| ROW | ostra | rmb | 367 snap | 333 | 400 | os_snap_wind@0+60 (wind-up), os_snap@333 (+0), os_snap_hit@400 (+0), ostra_hit@400 (+0) |
| ROW | ostra | hold | 367 snap | 333 | 400 | os_snap_wind@0+60 (wind-up), os_snap@333 (+0), os_snap_hit@400 (+0), ostra_hit@400 (+0) |
| ROW | ostra | e | 33 seed | - | - | os_seed@0 (-33) |
| ROW | ostra | r | 117 well | - | 1000 | os_well_hum@983 (wind-up), ostra_hit@1000 (+0) |
| ROW | rimewright | lmb | 33 dart_l | 0 | 133 | rime_shard@0 (+0), rimewright_hit@133 (+0) |
| ROW | rimewright | lhold | 33 dart_l | 0 | 133 | rime_shard@0 (+0), rimewright_hit@133 (+0) |
| ROW | rimewright | rmb | 83 spear | 117 | 183 | rime_spear_aim@17+200 (wind-up), rime_lance@117 (+0), rime_zone@183 (+0), rimewright_chime@183 (+0) |
| ROW | rimewright | hold | 150 spear_aim | 600 | 667 | rime_spear_aim@17+200 (wind-up), rime_lance@600 (+0), rime_zone@667 (+0), rimewright_chime@667 (+0) |
| ROW | rimewright | e | 150 wall | - | 283 | rime_wall_tell@0+70 (wind-up), rime_wall@217 (-67 !), rimewright_hit@283 (+0) |
| ROW | rimewright | r | 50 rime | - | - | rime_creak@583+20 (wind-up) |
| ROW | tender | lmb | 33 shot_r | 0 | 67 | tend_ember@0 (+0), tender_hit@67 (+0) |
| ROW | tender | lhold | 33 shot_r | 0 | 67 | tend_ember@0 (+0), tender_hit@67 (+0) |
| ROW | tender | rmb | 600 seed | 600 | 650 | tend_seed_aim@0+30 (wind-up), tend_seed@600 (+0), tend_stick@650 (+0), tender_hit@650 (+0) |
| ROW | tender | hold | 600 seed | 600 | 650 | tend_seed_aim@0+30 (wind-up), tend_seed@600 (+0), tend_stick@650 (+0), tender_hit@650 (+0) |
| ROW | tender | e | 33 hearth | - | - | tend_hearth@0+60 (+27), tender_lantern_chime@0 (-33) |
| ROW | tender | r | - | - | - |  |
| ROW | thief | lmb | 33 lmb_r | 0 | 50 | dj_bolt@0 (+0), thief_hit@50 (+0) |
| ROW | thief | lhold | 500 lmb_l | 0 | 50 | dj_bolt@0 (+0), thief_hit@50 (+0) |
| ROW | thief | rmb | 383 bola | - | 467 | dj_bola_whirl@0+20 (wind-up), dj_bola_throw@417+60 (+10), thief_hit@467 (+0), dj_bola_wrap@467+20 (+20) |
| ROW | thief | hold | 383 bola | - | 467 | dj_bola_whirl@0+20 (wind-up), dj_bola_throw@417+60 (+10), thief_hit@467 (+0), dj_bola_wrap@467+20 (+20) |
| ROW | thief | e | 83 knife | 133 | 200 | dj_knife_throw@133+40 (-27), thief_hit@200 (+0), thief_knife_stick@200 (+0) |
| ROW | thief | r | 33 encore | 400 | 500 | dj_blade@400+20 (+20), thief_hit@500 (+0), dj_encore_hit@500 (+0) |
