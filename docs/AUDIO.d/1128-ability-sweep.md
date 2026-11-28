## Ability sweep (11-28, ext/sfx-ability-sweep)

Run on origin/main 8d8b678e3e: `--sfx-set-check` section 21 (`tools/sfx_ability_rows.gd`, 65 moves), sections 11 and 16
(`tools/ability_beat_sfx_check.gd`, `tools/sfx_bar_check.gd`). Every move of the 13 Hunters already had an own cast
and, where it hurts, an own hit; the one red on main is `lw_roar` (Cinder's flamethrower voice cap: "voices 10 plain -> 4
held, cap 3", unchanged by this pass). What was missing was the recast and the end of a few moves:

- **Recast open, tick and expire were stock for 9 Hunters.** `RecastCue` played the shared `ab_ready` chime (bright rings
  at 1.5-3 kHz, the arcade sound the grounded pass removed elsewhere) and a shared `click`; only Gil had own files and
  those were never played (`HeroSfx.of(h, "recast_open")` was asked for nowhere). `RecastCue` now plays the Hunter's own
  `<arch>_recast_open`, `_recast_tick` and `_recast_end` when its set has one, else the old stock sound.
- **Albert's raised shield had no end.** Letting go of RMB (or a Boki merge) lowers it silently; it now plays
  `bulwark_shield_down` (strap slackens, plate settles).
- Mark payoffs: all 13 Hunters already had their own named sound (list below); nothing to add.

`python3 tools/gen_sfx_recast.py` writes them (seed 11285, own stream): per Hunter the kit's material (Kael chain links,
Albert plate and strap, Tenzo stone and grit, Cinder valve hiss and flint, Neve ice, Sparkle static, Sable cloth and a
knife tip, Meeko wood and embers, Motley rubbery plucks, Gil a dull water plop for the expire). Recipe of the grounded
pass (`1126-grounded-sfx.md`): foley with a short body, everything low-passed at 3.8 kHz, no bells, no upward sweeps, 3
takes of the tick (it plays up to three times a window). Levelled to `ui` (-22 dB RMS) by `sfx_lib`; `bulwark_shield_down` to
`cast`. `sfx_arcade_audit.py` on the 28 new base names: median centroid 340 Hz, none bright (over 4 kHz); a few
"rising"/"dry" flags remain on 0.04-0.3 s foley (a tick is dry by nature).

Cue table after the pass (`ABILITY` rows of the check, split by when each is first heard; "Travel" collects the cues
named for a flight or a loop; `-` = the move has no such beat or does no damage; Gil's `_recast_tick` is the recast
hit he already had). Not done: Cinder's Furnace Cloak shield running out (it goes through `ShieldSfx`, not checked here) and
an own expire for moves that end by their hit (a bolt, a slam).

| Hunter | Slot | Cast | Travel | Hit | Expire / end |
|---|---|---|---|---|---|
| Lace | LMB | `pin_draw` | - | `archer_thread_twang`, `pin_loose`, `pin_arrow_hit` | - |
| Lace | RMB | `pin_heavy_draw` | - | `pin_heavy`, `pin_heavy_burst`, `archer_hit` | - |
| Lace | E | `pin_hail` | `pin_rain` | `pin_patter`, `archer_hit` | - |
| Lace | Shift | `archer_dash`, `pin_spirit` | - | - | `pin_spirit_end` |
| Lace | R | `pin_ult_beam`, `pin_ult_cast`, `archer_ult_cue` | - | `pin_super_hit`, `archer_hit` | - |
| Lace | mark payoff | - | - | `pay_called (wall stun), pay_deadeye (R)` | - |
| Kael | LMB | `jug_ting` | - | `jug_wave`, `juggernaut_blade_hiss`, `juggernaut_hit` | - |
| Kael | RMB | `jug_ting`, `jug_charge` | - | `juggernaut_dash`, `juggernaut_hit`, `jug_lunge_hit` | - |
| Kael | E | `jug_chain` | `juggernaut_chain_rattle` | `juggernaut_hit`, `juggernaut_chain_bite`, `jug_taut` | - |
| Kael | Shift | `jug_charge`, `juggernaut_dash` | - | `juggernaut_hit` | - |
| Kael | R | `jug_guard`, `juggernaut_ult_cue` | - | `juggernaut_dash`, `jug_riposte`, `juggernaut_heal` | - |
| Kael | recast open, tick, expire | **`juggernaut_recast_open`** (was shared `ab_ready` / `click`) | - | - | **`juggernaut_recast_tick`** (closing), **`juggernaut_recast_end`** (ran out) |
| Kael | mark payoff | - | - | `pay_rage` | - |
| Vex | LMB | `vn_rifle` | - | `gunslinger_hit` | - |
| Vex | RMB | `vn_coin_flip` | - | `vn_stim`, `gunslinger_hit`, `vn_blast` | - |
| Vex | E | `vn_ion_charge` | - | `vn_ion_fire`, `vn_stim`, `gunslinger_hit` | - |
| Vex | Shift | `gunslinger_dash`, `vn_slide` | - | - | - |
| Vex | R | `vn_nuke_fall`, `gunslinger_ult_cue`, `vn_nuke_fire` | - | `vn_nuke_boom`, `vn_nuke_burn`, `vn_stim` | `gunslinger_hit` |
| Vex | mark payoff | - | - | `combo` | - |
| Albert | LMB | `bjorn_spin` | - | `bulwark_dash`, `bjorn_slam`, `bulwark_hit` | - |
| Albert | RMB | `bjorn_shield_up`, `bulwark_hull_creak` | - | - | **`bulwark_shield_down`** (was silent) |
| Albert | E | `bjorn_purify` | - | - | `bjorn_purify_burst` |
| Albert | Shift | `bulwark_dash`, `bjorn_spin`, `bjorn_whirl` | - | `bulwark_hit` | - |
| Albert | R | `bjorn_ult_wind`, `bulwark_ult_cue` | `bjorn_ult_rumble` | `bjorn_ult_slam`, `bulwark_hit`, `bjorn_ult_quake` | `bjorn_slam`, `bjorn_ult_crackle` |
| Albert | recast open, tick, expire | **`bulwark_recast_open`** (was shared `ab_ready` / `click`) | - | - | **`bulwark_recast_tick`** (closing), **`bulwark_recast_end`** (ran out) |
| Albert | mark payoff | - | - | `pay_slam` | - |
| Neve | LMB | `rime_shard` | - | `rimewright_hit` | - |
| Neve | RMB | `rime_spear_aim` | - | `rime_lance`, `rime_zone`, `rimewright_chime` | `rime_burst`, `rime_splinter` |
| Neve | E | `rime_wall_tell`, `rime_wall` | - | `rimewright_hit` | - |
| Neve | Shift | `rimewright_dash`, `rime_stop` | `rimewright_skate_glide`, `rimewright_skate_scrape`, `rimewright_skate_hiss` | - | - |
| Neve | R | `rime_lock`, `rimewright_ult_cue` | - | `rime_creak`, `rimewright_hit`, `rime_crash` | - |
| Neve | recast open, tick, expire | **`rimewright_recast_open`** (was shared `ab_ready` / `click`) | - | - | **`rimewright_recast_tick`** (closing), **`rimewright_recast_end`** (ran out) |
| Neve | mark payoff | - | - | `rime_splinter` | - |
| Cinder | LMB | `lw_pilot`, `lw_roar` | - | `ashwick_hit`, `ashwick_tank_hiss` | - |
| Cinder | RMB | - | - | `lw_bolt`, `ashwick_hit`, `lw_bolt_hit` | - |
| Cinder | E | - | - | `lw_shield`, `ashwick_cloak_hit`, `ashwick_hit` | - |
| Cinder | Shift | `ashwick_dash`, `lw_bash` | - | `ashwick_hit`, `lw_bash_hit` | - |
| Cinder | R | `ashwick_dash`, `lw_jet`, `ashwick_ult_cue` | `lw_trail` | `ashwick_hit` | `lw_jet_land` |
| Cinder | recast open, tick, expire | **`ashwick_recast_open`** (was shared `ab_ready` / `click`) | - | - | **`ashwick_recast_tick`** (closing), **`ashwick_recast_end`** (ran out) |
| Cinder | mark payoff | - | - | `lw_blaze` | - |
| Tenzo | LMB | `br_wind` | - | `dolm_rock_crunch`, `br_punch`, `dolm_hit` | - |
| Tenzo | RMB | `dolm_rock_crunch` | - | `br_crack`, `br_leap`, `br_slam` | - |
| Tenzo | E | `br_crack`, `br_raise` | - | - | - |
| Tenzo | Shift | `br_rise`, `br_leap`, `br_slam` | `br_rock_fly` | `dolm_hit_dash` | `br_launch`, `br_roll`, `br_burst` |
| Tenzo | R | `dolm_ult_cue`, `br_crack` | - | `dolm_hit_r` | `br_slam` |
| Tenzo | recast open, tick, expire | **`dolm_recast_open`** (was shared `ab_ready` / `click`) | - | - | **`dolm_recast_tick`** (closing), **`dolm_recast_end`** (ran out) |
| Tenzo | mark payoff | - | - | `pay_rockfall` | - |
| Sparkle | LMB | `vv_bolt` | `mage_bolt_tail`, `mage_bolt_fly` | `mage_zap`, `mage_hit` | - |
| Sparkle | RMB | `vv_rod_summon` | `vv_rod_throw` | `mage_hit_rmb`, `mage_zap`, `mage_rod_hit` | - |
| Sparkle | E | `vv_sky_place` | `vv_sky_count` | `vv_sky_strike`, `mage_hit_e`, `mage_zap` | - |
| Sparkle | Shift | `vv_surge_charge`, `mage_dash`, `vv_surge_go` | - | `mage_hit_dash`, `mage_wire_hit`, `mage_zap` | `mage_bubble_pop` |
| Sparkle | R | `vv_ult_charge`, `mage_ult_cue`, `vv_ult_rise` | `vv_ult_hum` | `vv_ult_crack`, `vv_ult_slam`, `mage_hit_r` | - |
| Sparkle | recast open, tick, expire | **`mage_recast_open`** (was shared `ab_ready` / `click`) | - | - | **`mage_recast_tick`** (closing), **`mage_recast_end`** (ran out) |
| Sparkle | mark payoff | - | - | `hero_blowout` | - |
| Grimble | LMB | `dr_shot` | `dr_shot_tail`, `dr_slug_fly` | `dredge_hit` | - |
| Grimble | RMB | `dr_throw` | `dr_reach_fly` | `dredge_hit_rmb`, `dr_grab`, `dr_reel` | `dr_let_go`, `dredge_coin_jingle` |
| Grimble | E | `dr_anchor_wind` | - | `dredge_hit_e`, `dr_anchor` | - |
| Grimble | Shift | `dredge_dash`, `dr_barge`, `dredge_junk_clatter` | - | - | - |
| Grimble | R | `dr_blast_charge`, `dredge_ult_cue` | - | `dr_blast`, `dredge_hit_r` | `dr_blast_end` |
| Grimble | mark payoff | - | - | `dredge_coin_jingle` | - |
| Meeko | LMB | `tend_ember`, `tend_ember_emp` | - | `tender_hit` | - |
| Meeko | RMB | `tend_seed_aim` | - | `tend_seed`, `tend_stick`, `tender_hit` | `tend_root` |
| Meeko | E | `tend_hearth`, `tender_lantern_chime` | - | - | `tend_flare` |
| Meeko | Shift | `tender_dash`, `tend_hop` | - | - | - |
| Meeko | R | `tend_call`, `tender_ult_cue` | `tend_call_loop` | - | `tend_arrive`, `tender_cheer` |
| Meeko | recast open, tick, expire | **`tender_recast_open`** (was shared `ab_ready` / `click`) | - | - | **`tender_recast_tick`** (closing), **`tender_recast_end`** (ran out) |
| Meeko | mark payoff | - | - | `tend_kindled` | - |
| Sable | LMB | `dj_bolt` | `thief_bolt_tail` | `thief_hit` | - |
| Sable | RMB | `dj_bola_whirl` | - | `dj_bola_throw`, `thief_hit_rmb`, `dj_bola_wrap` | - |
| Sable | E | `dj_knife_throw` | `thief_knife_whisk`, `thief_knife_fly` | `thief_hit_e`, `thief_knife_stick` | - |
| Sable | Shift | `thief_dash` | - | - | `thief_cock` |
| Sable | R | `dj_encore`, `dj_encore_rise`, `thief_ult_cue` | `dj_encore_whirr` | `dj_blade`, `thief_hit_r`, `dj_encore_hit` | `thief_encore_end` |
| Sable | recast open, tick, expire | **`thief_recast_open`** (was shared `ab_ready` / `click`) | - | - | **`thief_recast_tick`** (closing), **`thief_recast_end`** (ran out) |
| Sable | mark payoff | - | - | `pay_cashin` | - |
| Motley | LMB | `os_orb_hot` | - | `ostra_hit` | `os_prime` |
| Motley | RMB | `os_snap_wind`, `os_snap` | - | `os_snap_hit`, `ostra_hit` | - |
| Motley | E | `os_seed` | - | - | `ostra_music_box` |
| Motley | Shift | `os_swap_lob` | - | - | `os_trade_swap`, `os_swap` |
| Motley | R | `os_well`, `ostra_ult_cue` | `os_well_hum` | `ostra_hit` | `os_well_close` |
| Motley | recast open, tick, expire | **`ostra_recast_open`** (was shared `ab_ready` / `click`) | - | - | **`ostra_recast_tick`** (closing), **`ostra_recast_end`** (ran out) |
| Motley | mark payoff | - | - | `pay_collapse` | - |
| Gil | LMB | `gil_thrust` | - | `gil_thrust_hit` | `gil_dash`, `gil_tide_lunge`, `gil_tide_hit` |
| Gil | RMB | `gil_toss` | - | `gil_pop_fire`, `gil_recast_tick` | - |
| Gil | E | `gil_spin` | - | `gil_recast_tick`, `gil_spout`, `gil_spout_hit` | - |
| Gil | Shift | `gil_dash` | - | `gil_surface` | - |
| Gil | R | `gil_dash`, `gil_wave`, `gil_ult_cue` | - | - | `gil_wave_land` |
| Gil | recast open, tick, expire | `gil_recast_open` (made, never played: now wired) | - | - | `gil_recast_tick` (closing), **`gil_recast_end`** (ran out) |
| Gil | mark payoff | - | - | `pay_flashpoint` | - |
