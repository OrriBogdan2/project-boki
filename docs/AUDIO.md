# Audio: sound sets, loudness and buses

How the game's sound effects are made, named, levelled and played. Music and ambience are in `tools/compose.py`, `tools/gen_ambience.py` and `tools/gen_garden_ambience.py`.

## Making sounds
- Sounds are **synthesised in code** (numpy/scipy, `pip install numpy scipy`), one script per group: `tools/gen_sfx_<group>.py` (e.g. `gen_sfx_vex.py`, `gen_sfx_boki.py`, `gen_sfx_ui.py`). Each one imports `tools/sfx_lib.py`, calls `S.reseed(<its own seed>)` and writes `audio/<name>.wav` (44.1 kHz mono 16-bit). Then `godot --headless --import`.
- `sfx_lib.py` re-uses the primitives in `tools/sfx_combat.py` (filters, envelopes, kick, click, crack, sub, tail, reflections, ring, grains) and adds `voice()` (wordless grunts and cries through vowel formants), `chime()`, `creak()`, `fm()`, `sweep()`, `rattle()`, `hiss()`.
- Exception: the ElevenLabs pilot (`tools/gen_sfx_el.py`, docs/SFX_PILOT.md) generates some kit sounds through the API under the owner's plan.
- Outside sources only if **CC0**, logged in `docs/CREDITS.md` under the group's own section (source URL, author, licence, which file). No sounds from SUPERVIVE or any other game.
- Review: `python3 tools/sfx_look.py out.png audio/<names>*.wav` draws waveform + spectrogram + levels per sound (matplotlib). Use it to judge layering, clicks and harshness, and as the READY screenshot.
- Held sounds (a minigun spin, a charge hum): write them with `S.save_loop(name, x, cat)`, which cross-fades the tail into the head and skips the end fades, list them under `"loops"`, and play them with `Sfx.loop_start` / `loop_stop`.
- Variety: write takes with `S.takes_cat(name, fn, 3, cat)` (`name.wav` + `name_1..3.wav`); `Sfx` picks a different take each time.

## Loudness
Every sound is levelled to its **category** by `S.save_cat` / `S.takes_cat` (table: `content/rules/sfx_levels.json`): RMS over the audible part, peak ceiling -1 dBFS. The `vol_db` at the call site then only says intent (a quiet tell, a big ult), never fixes a file that is too loud.

| category | RMS dBFS | for |
|---|---|---|
| heavy_impact | -14.5 | a damage carry's hits (Vex, Kael, Grimble's blunderbuss, Mossy's hammer) |
| heavy_fire | -15.5 | a damage carry's weapon: a little louder than the lighter Hunters |
| impact | -16 | an ability or weapon landing |
| fire, signature | -17 | a shot or swing; a Hunter's recognisable sound |
| cast, grunt | -18 | an ability starting; hurt / downed / death voice |
| boki | -19 | Boki voices and moves |
| dash | -20 | |
| loop | -21 | held sounds |
| ui | -22 | menus and HUD |
| step | -23 | footsteps |

## Monsters
`content/sfx/mobs.json` (`tools/gen_sfx_mobs.py`): `mdie_<kind>` is each voiced kind's death in its `v_<kind>` family (bosses use the Watcher's, pitched by body; a Shrubling keeps `die_small`), `mstag_open` ticks when a stagger window opens and `mstag_hit` lands the stagger. `MobSfx` (scripts/match/mob_sfx.gd) plays them at the monster and caps a pack dying at once to 3 death cues per 200 ms across kinds. `--mob-sfx-check` asserts the kind -> cue map and the cap.
### Loudness audit (`tools/sfx_loudness.py`)
Measures every sound the game names (the sets in `content/sfx/*.json` and the `Sfx.NAMES`, `Sfx.VOICES`, `SfxKits.NAMES`, `VVSfx.NAMES` tables) and groups them by category; a table sound with no set gets one from `table_cats` in `content/rules/sfx_levels.json`. Its level is the RMS above (averaged over takes) plus the gain the game adds in play (`gain_db` there, and `Sfx.BLAST_DB`). A sound more than 3 dB (`tolerance_db`) from its category's **median** is an outlier: fix it with `gain_db` (data, applied by `Sfx.play` and `loop_start`), never by editing the file, or list it in `outliers_ok` with the reason it stands out on purpose. A positive gain may not push the peak past -1 dBFS. `python3 tools/sfx_loudness.py --check` fails on any other outlier, and `tools/health.py` runs it, so `--strict` fails too. `python3 tools/sfx_loudness.py` prints this table and every outlier.

| category | sounds | median level | target RMS | quietest | loudest | max peak | outliers (accepted) |
|---|---|---|---|---|---|---|---|
| impact | 98 | -16.2 | -16.0 | boom -22.9 | train_hit -13.2 | -0.9 | 5 (5) |
| signature | 36 | -17.0 | -17.0 | archer_thread_twang -17.4 | heart_take -17.0 | -1.0 | 0 (0) |
| fire | 30 | -17.0 | -17.0 | rail -20.9 | ab_rail -16.4 | -1.0 | 1 (1) |
| grunt | 46 | -18.0 | -18.0 | v_spitter -21.5 | hurt -16.0 | -1.1 | 1 (1) |
| cast | 126 | -18.0 | -18.0 | swap -21.8 | pay_rage -14.7 | -1.0 | 5 (5) |
| boki | 54 | -19.0 | -19.0 | grab -22.6 | scan_pop -18.6 | -1.1 | 1 (1) |
| dash | 36 | -20.0 | -20.0 | jump -23.7 | fall -18.9 | -1.2 | 1 (1) |
| loop | 14 | -21.0 | -21.0 | heart_charge -21.0 | revive_hum -16.8 | -1.1 | 1 (1) |
| ui | 38 | -22.0 | -22.0 | reload -24.2 | kill -15.0 | -1.1 | 4 (4) |
| step | 59 | -23.0 | -23.0 | step0 -23.4 | swim -20.1 | -4.6 | 0 (0) |

The set sounds all sit at their category (`--sfx-set-check` holds them there). The outliers were older table sounds made before the category standard: eight are brought to their median by `gain_db` (charge, cloak, v_glimmer, v_skitter, v_bomber, br_crumble, fuse_hiss, drip); the blast sounds (kept under on purpose), the kill/knock/extract confirm stings and 14 borderline ones (3-4.5 dB, mixed by ear at their call sites) are listed in `outliers_ok`. None of this has been listened to yet.


### 0.24.5 sets, measured (11-12)
The garden games, home chimes, Ways Out calls and Heartspark sets merged after the first audit were measured with `tools/sfx_loudness.py`: all 49 new cues are already at their category (each generator levels through `tools/sfx_lib.py`), so no `gain_db` was needed; their sets are enforced by the same `--check` (it reads every `content/sfx/*.json`; a cue pushed 3 dB off fails it). Before = RMS over the audible part, after = that plus `gain_db` (none). Peaks are all under -1 dBFS. The one edit: the `train_hit` accepted-outlier entry was dropped, since the new impact cues moved the median and it now sits 2.97 dB above it. The `amb_*` beds (`.ogg`, Ambience bus, levelled by layer in `HomeAmbience`) and `mask_*` are not part of this band: the garden beds read -17.9 to -28.3 LUFS (zone glasswater quietest) against -17 to -20.5 for the older beds, left as designed.

| cue | set | category | takes | peak | level before | level after | from median |
|---|---|---|---|---|---|---|---|
| echo_hit | garden | ui | 3 | -10.0 | -22.0 | -22.0 | +0.0 |
| echo_miss | garden | ui | 3 | -9.2 | -22.0 | -22.0 | -0.0 |
| echo_streak | garden | ui | 2 | -8.0 | -22.0 | -22.0 | -0.0 |
| garden_bat | garden | ui | 3 | -7.2 | -22.0 | -22.0 | -0.0 |
| garden_cheer_good | garden | boki | 3 | -7.4 | -19.0 | -19.0 | +0.0 |
| garden_cheer_miss | garden | boki | 3 | -7.6 | -19.0 | -19.0 | -0.0 |
| garden_cheer_perfect | garden | boki | 3 | -6.6 | -19.0 | -19.0 | +0.0 |
| garden_chime_evolve | garden | boki | 2 | -5.6 | -19.0 | -19.0 | -0.0 |
| garden_chime_level | garden | boki | 3 | -6.2 | -19.0 | -19.0 | -0.0 |
| garden_chime_stat | garden | boki | 3 | -7.0 | -19.0 | -19.0 | -0.0 |
| garden_count | garden | boki | 2 | -5.5 | -19.0 | -19.0 | +0.0 |
| garden_creak | garden | step | 3 | -10.1 | -23.0 | -23.0 | +0.0 |
| garden_crowd | garden | boki | 3 | -6.6 | -19.0 | -19.0 | -0.0 |
| garden_finish | garden | boki | 2 | -5.5 | -19.0 | -19.0 | +0.0 |
| garden_go | garden | boki | 2 | -6.8 | -19.0 | -19.0 | -0.0 |
| garden_hop | garden | boki | 2 | -6.8 | -19.0 | -19.0 | +0.0 |
| garden_lap | garden | ui | 3 | -9.3 | -22.0 | -22.0 | -0.0 |
| garden_sniff | garden | loop | 1 | -8.3 | -21.0 | -21.0 | -0.0 |
| garden_strain | garden | loop | 1 | -6.6 | -21.0 | -21.0 | -0.0 |
| garden_sulk_large | garden | boki | 3 | -5.8 | -19.0 | -19.0 | +0.0 |
| garden_sulk_medium | garden | boki | 3 | -5.6 | -19.0 | -19.0 | +0.0 |
| garden_sulk_small | garden | boki | 3 | -4.3 | -19.0 | -19.0 | +0.0 |
| garden_thud | garden | impact | 2 | -4.2 | -16.0 | -16.0 | +0.2 |
| garden_wake | garden | boki | 1 | -6.0 | -19.0 | -19.0 | -0.0 |
| garden_win_large | garden | boki | 1 | -8.5 | -19.0 | -19.0 | -0.0 |
| garden_win_medium | garden | boki | 1 | -8.1 | -19.0 | -19.0 | -0.0 |
| garden_win_small | garden | boki | 1 | -8.0 | -19.0 | -19.0 | -0.0 |
| relay_finish | garden | boki | 2 | -6.2 | -19.0 | -19.0 | +0.0 |
| relay_fumble | garden | boki | 3 | -4.3 | -19.0 | -19.0 | -0.0 |
| relay_handoff | garden | boki | 3 | -4.6 | -19.0 | -19.0 | -0.0 |
| show_crowd | garden | boki | 2 | -4.2 | -19.0 | -19.0 | +0.0 |
| show_reveal | garden | ui | 1 | -8.6 | -22.0 | -22.0 | -0.0 |
| tumble_clash_brace | garden | impact | 3 | -2.8 | -16.0 | -16.0 | +0.2 |
| tumble_clash_dodge | garden | boki | 3 | -4.1 | -19.0 | -19.0 | -0.0 |
| tumble_clash_rush | garden | impact | 3 | -2.9 | -16.0 | -16.0 | +0.2 |
| tumble_push | garden | step | 3 | -7.1 | -23.0 | -23.0 | -0.0 |
| tumble_ringout | garden | impact | 2 | -4.5 | -16.0 | -16.0 | +0.2 |
| heart_beat | heart | loop | 1 | -9.5 | -21.0 | -21.0 | +0.0 |
| heart_charge | heart | loop | 1 | -12.1 | -21.0 | -21.0 | -0.0 |
| heart_extract | heart | cast | 1 | -4.7 | -18.0 | -18.0 | -0.0 |
| heart_gate_open | heart | cast | 1 | -4.6 | -18.0 | -18.0 | +0.0 |
| heart_reveal | heart | cast | 1 | -6.0 | -18.0 | -18.0 | +0.0 |
| heart_take | heart | signature | 1 | -5.9 | -17.0 | -17.0 | +0.0 |
| ways_last | heart | ui | 1 | -6.1 | -22.0 | -22.0 | -0.0 |
| ways_open | heart | ui | 1 | -10.5 | -22.0 | -22.0 | -0.0 |
| ways_start | heart | ui | 1 | -9.7 | -22.0 | -22.0 | -0.0 |
| ways_taken_other | heart | ui | 1 | -10.7 | -22.0 | -22.0 | -0.0 |
| ways_taken_own | heart | ui | 1 | -10.3 | -22.0 | -22.0 | -0.0 |
| ways_warn | heart | ui | 1 | -13.3 | -22.0 | -22.0 | +0.0 |

## Names
- A Hunter's own sounds start with its archetype id: `gunslinger_*` (Vex), `archer_*` (Lace), `juggernaut_*` (Kael), `bulwark_*` (Mossy), `ostra_*` (Motley), `ashwick_*` (Cinder), `dredge_*` (Grimble), `rimewright_*` (Neve), `tender_*` (Meeko), `thief_*` (Sable), `mage_*` (Sparkle), `dolm_*` (Tenzo). Older kit sounds keep their names (`vn_*`, `jug_*`, `rime_*`...); a branch that replaces one regenerates that file under its old name.
- **Shared kinds picked per Hunter by `HeroSfx`** (falls back to the shared sound when a Hunter has none): `<arch>_dash`, `<arch>_dash_air`, `<arch>_hurt`, `<arch>_down`, `<arch>_death`, `<arch>_step_grass|stone|wood|snow`, `<arch>_pickup`. Wired at: the dash (`Hunter` and the Thief, Neve and Tenzo kits via `HeroSfx.dash_name`: `_dash_air` when the Hunter has no floor under it, positional for rivals; `tools/gen_sfx_dash.py` makes the air variants from the ground ones, and `dash_empty`, the soft tick of a Shift press with no charge, played by `PressDeny` in place of `ui_deny`; a kit's dash plays it too, through `ArchKit.travel` and the Hunter's dash), footsteps (`Juice.footstep`), loot picked up or put on (`Pack`), your own hurt (`Match` damage), downed (`Match` knock and its net event) and death (`Life.drop_box`). The voice lines are wordless.
- **Shared kinds picked per Hunter by `HeroSfx`** (falls back to the shared sound when a Hunter has none): `<arch>_dash`, `<arch>_hurt`, `<arch>_down`, `<arch>_death`, `<arch>_step_grass|stone|wood|snow`, `<arch>_pickup`. Wired at: the dash (`Hunter`; with its own dash, `Feel.dash_sound`'s shared layers are skipped), footsteps (`Juice.footstep`), loot picked up or put on (`Pack`), your own hurt (`Match` damage), downed (`Match` knock and its net event) and death (`Life.drop_box`). The voice lines are wordless.
- Lair bosses: `boss_<kind>_wake|phase|defeat` for each of `Data.BOSSES` (`content/sfx/boss.json`, `tools/gen_sfx_boss.py`, played by `BossSfx`). The wake carries 80 m (the lair band), the phase sting also plays for the enrage (pitched down), the defeat sting goes only to the squad that cleared the lair; `--boss-sfx-check`.
- **Shared kinds picked per Hunter by `HeroSfx`** (falls back to the shared sound when a Hunter has none): `<arch>_dash`, `<arch>_dash_air`, `<arch>_hurt`, `<arch>_down`, `<arch>_death`, `<arch>_step_grass|stone|wood|snow`, `<arch>_pickup`. Wired at: the dash (`Hunter` and the Thief, Neve and Tenzo kits via `HeroSfx.dash_name`: `_dash_air` when the Hunter has no floor under it, positional for rivals; `tools/gen_sfx_dash.py` makes the air variants from the ground ones, and `dash_empty`, the soft tick of a Shift press with no charge, played by `PressDeny` in place of `ui_deny`; with its own dash, `Feel.dash_sound`'s shared layers are skipped), footsteps (`Juice.footstep`), loot picked up or put on (`Pack`), your own hurt (`Match` damage), downed (`Match` knock and its net event) and death (`Life.drop_box`). The voice lines are wordless.
- Levelling sounds (`tools/gen_sfx_ui.py`, set `content/sfx/ui.json`), your own Hunter only, a rival hears nothing: `level_up` (soft, -6 dB, once per level), `rank_up` (a short rising pair when you rank a slot, pitched a pentatonic step per slot) and `rank_max` (a sting instead of the confirm when the slot reaches its top rank and its bonus opens). Played by `LevelSfx` from `Hunter.gain_xp` / `Hunter.level_slot`; `--sfx-set-check` and `--rank-ui-check` assert each fires once per event.
- Glider sounds: `glider_*` (`tools/gen_sfx_glider.py`, set `content/sfx/glider.json`), played per hunter by `GliderSfx` (a snap on opening, a `glider_wind` loop pitched and levelled by speed, the Ctrl dive whoosh, a crackle and `glider_burn` loop while overheated, a fold on landing or cancel). Other players' gliders are positional and 6 dB quieter, driven by the synced glide flag, velocity and the overheat bit (hunter flag bit 19). `--match-audio-check` asserts each state plays its cue once.
- Sky train sounds: `train_*` (`tools/gen_sfx_train.py`, set `content/sfx/train.json`), played by `TrainSfx` from the train's match-clock schedule, so every game hears the same cues with no network traffic. At each halt: `train_brake` as it eases in, `train_bell` as it stands, `train_door_open`, `train_whistle` `SkyTrain.DEPART_LEAD` (4 s) before it pulls out (carries 60 m, time to run for it; the rails pulse from then), `train_door_close` just before it goes. While it moves: `train_ride`, a quiet unpositioned loop while you ride a car, or else `train_rumble` at the car nearest the listener, stopped past its 40 m reach. Both pitch and swell with speed. The horn (someone on the rails ahead) and `train_hit` stay in `tools/gen_train_sfx.py`. `--train-check` asserts the cue order at every halt, the whistle lead and the loops.
- Garden minigames (Dash, Stump Shove, Seek, Spark Volley, Tumble, Echo Steps, Show Ring, Relay Cup): `garden_*`, `tumble_*`, `echo_*`, `show_*`, `relay_*`, `tools/gen_sfx_garden.py`, played through `scripts/home/garden_sfx.gd` at the Boki (positional, -6 dB): a three-beat countdown, a crowd cheer that follows the timing press (perfect, good, miss), a win fanfare and a loser huff per Boki size (small, medium, large from `Unique.size_tag`), the shove thump, a Seek sniffing loop and a Volley seed bat. Tumble: a clash in the move that decided the exchange (`tumble_clash_rush|brace|dodge`), a push scuff 0.25 s later when someone won it, `tumble_ringout` when the loser leaves the ring. Echo Steps keeps its generated stone notes and bed (`EchoSteps.tone`) and adds `echo_hit` on every hit, `echo_miss` on every miss and `echo_streak` at every `cheer_every` hits in a row (non-positional). Show Ring: `show_reveal` as the judges' cards come up, `show_crowd` 1.2 s later. Relay Cup: `relay_handoff` for a clean pass (no more lost than a good press), `relay_fumble` otherwise, `relay_finish` as each team's last runner is home. All of them are levelled to their category in `content/rules/sfx_levels.json` and play on the SFX bus at the garden level. `--sfx-set-check` asserts every name they play exists; `--garden-sfx-check` asserts each cue fires once per event.
- Mob and boss attacks (`content/sfx/mob.json`, `tools/gen_sfx_mob.py`) play by kind, never a Boki `k_*` cue: `mob_<kind>_atk` as the mob strikes, `mob_<kind>_hit` where it lands (`Mob._snd`; a spitter's or sentinel's shot carries `"snd"` and plays it on the hit), `boss_<kind>_tell` from the start of each boss telegraph (`Boss._begin`), swelling to the strike, plus `boss_slam|throw|boulder|spit|glob`. `--sfx-set-check` fails if `mob.gd` or `boss.gd` plays a `k_` name.
- Home chimes: `garden_chime_stat` / `_level` / `_evolve`, same script, played through `GardenSfx.cue` at the Boki by `scripts/home/home_chimes.gd` when a Boki gains a stat, a level (garden XP, `content/rules/garden_xp.json`, or a run) or a new form or part. Two, three and four soft notes over the Boki's chirp, pitched by species size (small x1.3, large x0.78); events on one Boki within 0.5 s share one chime (the biggest); nothing while it sleeps. The evolution scene keeps its own sounds. `--garden-sfx-check` row 6.
- Garden travel (`hub_waystone.gd`): `garden_hop` swells while the Waystone lights up, `garden_depart` (a short whoosh) as the screen goes, `garden_arrive_<zone>` (five, tuned to each zone's bed) on landing, `garden_locked` (a soft thud and a lock click) when a sleeping zone is picked; `--garden-audio-check` covers them.
- Eggs nearing their hatch: `egg_knock`, `egg_crack`, `egg_ready` (`tools/gen_sfx_egg.py`, set `content/sfx/egg.json`), played through `GardenSfx.cue` at the egg by `scripts/home/egg_sfx.gd` (`EggSfx`), which reads the progress the egg stores, never a clock of its own: a Rare Egg's warmth in its Incubator cradle (`Incubator.progress`, ticked by `HomeIncubator`), and for a pair's egg in the Nook's nest only whether it is ready. Past half a gentle wobble and a faint knock from inside (once), from 90% a small crack every 4 s while you are near, at 100% a ready chime (once); only within 10 m of the egg (`EggSfx.EARSHOT_M`). A step reached while you were away (an expedition, across the garden) plays when you next come near, once a session. These replace the Incubator's "ready to hatch" toast: no pop-ups.
- Build and decorate (the farm's build mode and the house's decorating, `scripts/home/build_sfx.gd`, `tools/gen_sfx_build.py`, set `content/sfx/build.json`, all category `ui`, played non-positionally on the SFX bus at `cue_db` from `content/rules/build_sfx.json`): `build_pick` (a piece comes into the hand, from the bar or off the ground), `build_rotate` (one dry tick per quarter turn), `build_place_wood` / `build_place_stone` (a new piece set down: a thunk by material, the stone ids listed in the rules file, wood otherwise), `build_move` (an existing piece set down in a new spot), `build_store` (a pop into the bag) and `build_blocked` (one dull knock). The knock plays once per attempt that can't be done and stays silent for `knock_quiet_s` (1.5 s) on the same spot (cell and turn), so a drummed click or a held key never repeats it. A turn or a store made of "pick it up, put it down" plays only its own cue (`BuildSfx.quiet`). `--sfx-set-check` section 10 asserts the names, the material pick, the knock latch and the wiring.
- Tutorial strip chime: one quiet `ui_open` (the existing UI set, no new file) as a new objective's strip pulse starts, from `TutorialStrip.chime` at the three places the objective changes (`Tutorial._enter`, `FirstMatchGuide._start`, `StripView.set_line`). A nag's re-pulse, a repeat of the same objective and a calm strip are silent. Levels are `cue_db` in `content/rules/sfx_levels.json` (`objective` -10 dB, `objective_fight` -20 dB while your Hunter was hurt in the last 3 s). `--sfx-set-check` section 11, `--tutorial-hud-check` (one chime per step).
- Hit ticks by weapon family (`tools/gen_sfx_hits.py`, set `content/sfx/hit.json`, levelled to the old `hit` at -18 dB RMS): `hit_gun`, `hit_bow`, `hit_blade`, `hit_blunt`, `hit_magic`, `hit_thrown`. A Hunter's left-click weapon names its tick in `"hit"` (`content/weapons/<id>.json`); `Match` plays it through `HeroSfx.hit_tick` for the player's own shot or primary hit, the shared `hit` for an ability's hit or a weapon with none. `crit`, `slash_hit`, `armor_hit` and `hit_heavy` are unchanged and layer on top. `--sfx-set-check` section 11 asserts every Hunter's weapon maps to one and each family is used.
- Boki sounds: `boki_*` (and the existing `kin_*` / `k_*` names); UI: `ui_*` (and the existing `click`, `hover`...).
- Garden sleepers: `boki_sleep` (a 6.2 s seamless loop, two slow breaths, the second with a tiny snore) and `boki_yawn` (two takes), in `tools/gen_sfx_boki.py`, played by `scripts/home/boki_nap_sfx.gd` (`BokiNapSfx`, stepped from `home.gd _move_kin` at 10 Hz). Every Boki with `nap_t` running and not indoors (napping alone, in a BaseLife pile, curled up outside) is a sleeper; only the 3 nearest you breathe, each through `Sfx.loop_hold` at its position (-12 dB, reach 7 m), pitched by height (sqrt of 30 cm over its `Unique.size_info` cm, 0.75-1.35, so a big Boki breathes slower and lower). A sleeper that wakes yawns (-8 dB, reach 9 m, at most one every 0.4 s so a garden waking at dawn does not chorus). Both are positional through Sfx, so they take the bus Sfx picks for the spot (far muffle; a reverb zone send once the garden has one). `--base-life-check` asserts the cap of 30, the size pitch, the night loops, the dawn yawn and an awake Boki's loop letting go.
- Species voices: `bk_<species>_<mood>` for every species the game can show (`Data.KIN`: the wild, the starters, the mystery egg's pool, the rare boss kin), moods happy, alert, unsure, sleepy, hurt, 2 takes each (set `content/sfx/boki_voices.json`, made by `gen_sfx_boki.py`). Pitch comes from the species' weight, the texture from its type (crackle Fire/storm, burble Water/venom, rustle Grass/spore/swarm, chime Crystal/moon/sound, else plain), the 3-note motif is its signature. Play them with `KinVoice.cue(species, mood)`: it falls back to `kin_happy` / `kin_alert` / `kin_unsure` / `boki_sleep` / `kinhit` for a species with no set. A new species appends its row to `SPECIES_VOICE` (at the end, so the older takes keep their random draws) and regenerates; `--sfx-set-check` fails if a shown species lacks a mood or would play a shared cue.
- Farm reactions: `garden_feed|pet|friend|trait|egg|toy` (UI set, `tools/gen_sfx_ui.py`), one per kind of good thing at home; `unlock` is only for real unlocks. The Boki eat and nap sounds (`boki_eat`, `boki_sleep`) play from the care states. `--garden-sfx-check` guards both. (No race exists on the farm yet, so there is no race cue.)
- Pairing in the Nesting Nook (`NookSfx`, UI set): `nook_note` twice (a chime, each note pitched by one parent's size, the bigger the lower), the egg settling (`garden_egg`), `nook_nuzzle` and `nook_settle` each layered with a parent's own `kin_happy` chirp, and `nook_wobble` for an unstable mix (a sour, soft wobble: it needs care, it did not fail). All at the nest, timed from the pairing click; `--nook-check` guards it.

## Sound sets (`content/sfx/<group>.json`)
```json
{"group": "gunslinger", "name": "Vex", "script": "tools/gen_sfx_vex.py",
 "sounds": {"gunslinger_dash": "dash", "gunslinger_hurt": "grunt", "vn_spin": "signature", "...": "..."},
 "signature": ["vn_spin", "gunslinger_grenade_thunk"],
 "kit_files": ["gunslinger_ult.gd"], "replaces": ["vn_rifle", "..."],
 "reach": {"gunslinger_fire": 45}, "loops": ["gunslinger_spin"]}
```
Vex's Cinderfall plays `vn_nuke_fall` at the landing point on the cast: a whistle rising in pitch and level over exactly the 1.6 s fall (`tools/gen_sfx_vex.py` `FALL_S`), cut at the impact `vn_nuke_boom`; it carries 40 m (`reach`); `--sfx-set-check` holds its length to `x.delay` within 50 ms.

`--sfx-set-check` asserts: every listed sound has its file(s); every take is within 3 dB of its category and under the ceiling; a Hunter set has hurt/down/death, dash, steps on all four surfaces, a `fire` sound and its signature list; `HeroSfx` picks them up; every literal `m.sfx("...")` in that Hunter's kit (`<arch>_kit.gd` plus its `kit_files`) names a sound that exists. `replaces` lists old-name files the set regenerated. `reach` (metres, 5-80) sets how far a sound carries: past the usual 22 m for a heavy sound, so you hear a carry coming, or less for a call that should stay close (`scan_call`: 11 m, half of gunfire) (past 9 m it plays through the muffled bus, so the low end is what carries); `Sfx` reads it from every set at start. Each sound under `loops` must repeat seamlessly.

## Playing and buses
- Always through `Sfx.play(name, pos, vol_db)` / `m.sfx(...)` (one-shots, pooled, distance falloff, far sounds muffled) or `Sfx.loop_start(key, name, pos)` / `loop_set` / `loop_stop` (held sounds). Never a new `AudioStreamPlayer`.
- They play on the **SFX** bus (compressor, a little room, limiter; far ones via **SFXFar**; ones behind terrain via **SFXMuffled**, a 700 Hz low-pass and -4 dB: `SfxOcclusion` runs one heightmap line test per positional sound, cached 100 ms, never within 3.5 m so your own Hunter and UI sounds stay clean; `--sfx-occlusion-check`). A match's sounds are torn down with the match (item 103, `Sfx.reset_scene_audio` stops keyed loops and pool voices on the match leaving the tree), so every held sound must be a keyed loop and stopped by its owner too.
- They play on the **SFX** bus (compressor, a little room, limiter; far ones via **SFXFar**). A match's sounds are torn down with the match (item 103, `Sfx.reset_scene_audio` stops keyed loops and pool voices on the match leaving the tree), so every held sound must be a keyed loop and stopped by its owner too.
- Flybys: a rival's shot passing within 2 m of you plays `flyby_<family>` (`scripts/match/flyby.gd`, cues from `tools/gen_flyby_sfx.py`, `--flyby-check`). There is no occlusion bus yet, so they go through SFX like the rest.
- New sounds load on first play (`Sfx._lazy`, takes included); no edit to `Sfx.NAMES` is needed.
- Cues for you alone carry no position and sit at the `ui` level: the reset cue (`Sfx.play_reset_cue`) and the ultimate-ready chime (`ui_ult_ready`, `UltReadyCue`: your R coming back, never a rival's or a teammate's, never at match start, held while you're down until you're up, 6 dB further down for 0.7 s after a `knock_confirm` or `kill` callout; Settings > Audio > Sounds turns it off). `--match-audio-check` asserts it.

## Footsteps (`StepReach`, `scripts/match/step_reach.gd`)
Steps are how you hear a flank. Both layers of a Hunter's step (the plain contact step on each foot plant, `StepReach.contact`, and the surface step while running, `Juice.footstep`) go through `StepReach`: a rival's carry `RIVAL_M` (20 m) with the usual roll-off and fade to nothing at the edge, seen or not (behind a wall, in a bush); a teammate's carry as far but `MATE_DB` (-6 dB) quieter; your own play at one steady level with no distance. Crouch walking (sneaking) cuts the distance to `SNEAK_K` (40%, 8 m) instead of muting the steps. Source: the data has no footstep distance or sneak cut (only SneakSpeedMultiplier 0.5, `briefs/supervive-data/supervive_physics.md`, and Void floats with no footstep noise, `supervive_kits.md`), so 20 m and 40% are ours `[?]`. Motley's float never steps (`KMovesStone.gait`). Steps are ordinary pool voices, so the pool and stacking caps apply. `--match-audio-check` asserts: a rival heard at 15 m, not at `RIVAL_M` + 5 m, a sneaking rival not at 15 m but at 6 m, a teammate quieter, your own one level wherever the camera is.
- **Armour break** (`Juice.armor_break`, reached once per break from `Hunter.hurt`): the `armor_break` crack plays at the victim, louder for the victim than for anyone else; the attacker alone also gets a high `click` tick (push now). Hits on empty armour play nothing; a refill re-arms it. `--armor-break-sfx-check`.

## Boki cries (`audio/cries/`)
- One short call per Boki (0.4-1.4 s), `audio/cries/<file_id>.wav`, made by `tools/gen_boki_cries.py` from `tools/boki_cries_roster.tsv` (who is in which evolution line, at which stage, branch, type, and the one-line cry brief). The manifest `audio/cries/cries.json` maps id to file, line, stage and recipe.
- A line shares one voice (seeded by the line id): source, vowel, flutter rate, texture and a motif unique to the line. The stage shapes it: first higher, shorter, squeakier; middle fuller; final lower, longer, with a growl and a low octave. Branch forms bend the last note and carry their own type's tint.
- Levelled to the `boki` category. `python3 tools/cries_stats.py` measures loudness, clicks, length and the family rule (line-mates closer than unrelated cries, no unrelated near-twins); `--boki-cries-check` asserts every species in `Data.KIN` has a cry and the manifest is whole.
- In game: `BokiCry.play(species_id)` (`scripts/ui/boki_cry.gd`), played when a Bokidex entry opens. Listening page: `python3 tools/cries_preview.py` writes `tools/cries_preview/index.html`.
## Ultimate cast cues
You hear an ultimate before you see it. Every Hunter's X goes through `HeroUlt.press`, which calls `UltCue.cast`: the Hunter's own `<arch>_ult_cue` at its position plus a team tag, `ult_tag_ally` (bright, rising) for your team or `ult_tag_foe` (low, falling) for a rival, both at the same level (the colour tells them apart, never loudness). They carry 60 m (`reach` in `content/sfx/ult_cues.json`, falling off with distance, muffled past 9 m) and play on the match's pool voices. Kits only run in their owner's game, so the cast also sends `["fx", "ucast", nid]` and the other games play it. Sounds: `tools/gen_sfx_ult_cues.py` (own seed; re-rolls nothing else). `--sfx-set-check` asserts a cue and reach per Hunter with an ultimate; `--match-audio-check` the ally/rival tag and the range.

## Ultimate tails
`python3 tools/sfx_stats.py --ults` measures every Warden's ult sounds (the `ULTS` table in the script): `t40` is when the 5 ms RMS envelope last stands above -40 dB of the peak, `tail` is `t40` minus the envelope maximum, `crest` is peak minus RMS. The sounds are already levelled to their category (RMS about -17 to -19 dB), so crest shows the shape, not the level. Tenzo's Basalt Spine is `br_spine`, one sound that holds a rumble while the rocks rise (a flat -12 to -14 dB for 0.8 s, then it falls and is past -40 dB at 1.37 s). Neve's ult is Rimelock (`rime_lock` into `rime_crash`); her Rink Wall (`rime_wall`, an E) ends at 0.64 s with a 0.53 s tail. Gil's X has no sound of its own, so he is not in the table.

Result (the audit's "check by ear" item): **neither is an outlier, so no generator was changed.** The impact tails of the other ten run 0.10 to 1.79 s (median 0.87); Tenzo's is 1.12 s and Neve's 1.31 s, level with Bjorn's slam (1.36 s) and Vv's (1.36 s) and shorter than Vex's nuke (1.79 s). Their crest (15.2 and 15.4 dB) is inside the others' 12.8 to 17.6 dB, and both fall away steadily (no plateau after the hit). Trimming them would only make the two sound unlike the heroes they sit between.

| Warden | role | sound | t40 s | tail s | crest dB |
|---|---|---|---|---|---|
| Pin | cast | pin_ult_cast | 0.93 | 0.52 | 15.1 |
| Pin | impact | pin_ult_final | 0.87 | 0.87 | 16.1 |
| Cinder | cast | lw_jet | 1.76 | 1.74 | 13.7 |
| Cinder | impact | lw_jet_land | 0.64 | 0.59 | 13.0 |
| Bjorn | cast | bjorn_ult_wind | 0.88 | 0.62 | 12.7 |
| Bjorn | impact | bjorn_ult_slam | 1.39 | 1.36 | 16.0 |
| Bjorn | loop | bjorn_ult_rumble | 1.78 | 1.71 | 15.7 |
| Tenzo | impact | br_spine | 1.37 | 1.12 | 15.2 |
| Dredge | cast | dr_blast_charge | 1.17 | 0.19 | 12.3 |
| Dredge | impact | dr_blast | 0.77 | 0.73 | 15.9 |
| Vex | cast | vn_nuke_fire | 0.73 | 0.70 | 14.9 |
| Vex | impact | vn_nuke_boom | 1.80 | 1.79 | 16.6 |
| Vex | loop | vn_nuke_burn | 3.09 | 2.96 | 19.3 |
| Kael | impact | jug_meteor | 1.00 | 0.97 | 17.6 |
| Vv | cast | vv_ult_rise | 0.64 | 0.25 | 14.4 |
| Vv | impact | vv_ult_slam | 1.37 | 1.36 | 17.1 |
| Vv | loop | vv_ult_hum | 2.19 | 1.63 | 11.9 |
| Ostra | cast | os_well | 1.58 | 0.52 | 13.4 |
| Ostra | loop | os_well_hum | 1.78 | 1.76 | 15.4 |
| Neve | cast | rime_lock | 1.17 | 0.64 | 15.9 |
| Neve | impact | rime_crash | 1.37 | 1.31 | 15.4 |
| Tender | cast | tend_call | 1.19 | 1.02 | 13.2 |
| Tender | impact | tend_arrive | 0.84 | 0.63 | 12.8 |
| Tender | loop | tend_call_hum | 0.66 | 0.41 | 11.5 |
| Sable | cast | dj_encore | 0.90 | 0.43 | 17.7 |
| Sable | impact | dj_encore_hit | 0.10 | 0.10 | 15.2 |
| Sable | loop | dj_encore_whirr | 1.96 | 0.77 | 16.8 |
| median of the other ten | cast | | 0.93 | 0.52 | 13.7 |
| median of the other ten | impact | | 0.87 | 0.87 | 16.0 |
| median of the other ten | loop | | 1.87 | 1.67 | 15.6 |
## Shield sounds (`content/sfx/shield.json`, `tools/gen_sfx_shield.py`)
`Hunter._mitigate` calls `ShieldSfx.hit` whenever a shield soaks damage: a dull `shield_<kind>_hit` while it holds, a glassy `shield_<kind>_break` when the hit takes the last of it (three takes each, pitched lower for a heavier hit). Yours plays centred, a rival's at their body (out of earshot past the usual range; the break carries 30 m). One family per material, named by `Hunter.shield_kind`, which the kit sets where it grants the shield and which clears when the shield breaks or runs out: `ward` (the default: heals, Boki shields, Gil, Motley), `cloak` (Cinder's Furnace Cloak and ram shield), `molten` (Tenzo's Molten Guard). Albert's aegis wall keeps its own `bjorn_block` / `bjorn_break`. `--match-audio-check` asserts the cue per material and the range.
## Rival casts (the threat layer)
A rival's E or R sounds like your teammate's, so you could not tell by ear that a threat started. The rule, in one place (`HostileCue`, `scripts/arch/hostile_cue.gd`): **every E, R and X cast by a Hunter on another team than yours also plays `hostile_cast`**, one short low edge shared by all Hunters; your own casts and your allies' play none. No kit plays it itself:
- E and R come from `CombatBus.ability_used` (`Hunter._on_ability_used`): the `kin` slot, and R once (its `ult_fuse`, or `ult` when it has no fuse). X plays it from `UltCue`, under the rival tag.
- It is positional like any one-shot and carries 30 m (`reach` in `content/sfx/ult_cues.json`, fading near the edge, muffled past 9 m), 4 dB under the cast it rides on.
- It goes through `Sfx.play`: the SFX bus with its compressor and limiter, the pool voices and the stacking cap, and `Sfx.MIN_GAP` 100 ms, so three rivals casting at once give one edge. It never ducks the music.
- Online it follows the caster's team: kits only run in their owner's game (bots in the host's), so that game sends `["fx", "hcast", nid]` and each other game plays it if that caster is its rival. A game that predates it ignores the event.

Sound: `tools/gen_sfx_ult_cues.py` (`hostile`, category cast). `--sfx-set-check` asserts the layer and its reach, that every Hunter's E and R start it once (RMB and dash never), that a rival's cast plays it and an ally's or a far rival's does not, and the wiring.

## Run stingers
Four short one-shots in the expedition score's key (A minor, `tools/compose.py` `STINGS`, rendered to `audio/sting_<name>.ogg`, each under 2.5 s): `extract` (you got out), `out` (taken out, or the islands fell), `last` (the last squad standing is yours) and `home` (back on the farm after a run). `Sfx.sting(name)` plays one on the Music bus, one at a time. `MusicDir` fires `extract`/`out` the moment the run is ending and `last` from `Exits.on_last_team`, and the layered stems fall away under it (to nothing at the end, to a sliver for `last`, then back). A sting still ringing when the match leaves is cut by `Sfx.reset_scene_audio`, so it never runs into the results music. `Home` plays `home` once after a run (it clears `Game.last_result`). `--sting-check` asserts one sting per outcome.

## Leaving a place: `--music-leave-check`
Music and ambience follow the screen: after each change only the new place's score is heard. The check walks Training Grounds -> duel room -> farm -> title, a match -> title, and the farm -> title, and reads every Sfx player on the Music / Ambience buses (playing and above -45 dB). What each row protects:
- **training: the layered score plays** / **match: layers and ambience beds are up**: the setup is sane (stems and abyss / ruins beds really come up), so the leave rows below are not passing on silence.
- **duel: a duel match is up** / **duel: the score is the Training Grounds's, one set of stems**: walking into the duel room keeps one set of layered stems, not a second set stacked on the first.
- **leave duel: no stem of the match score is left**: `Sfx.reset_scene_audio` stops the layered score when a match ends.
- **leave duel: only the farm's own music + ambience**: the farm starts its own track (`home*`, or a zone's) after a match.
- **leave duel: no match ambience beds**: the abyss / ruins beds `MusicDir` sets are cleared on leave, not left looping.
- **leave duel: nothing stray on the Music bus**: no player that Sfx no longer points at (an orphaned crossfade or sting) keeps playing.
- **match -> title: the score fades out rather than cutting**: the leave is a fade; right after the change the old score is still ringing out.
- **X -> title: music is the title track / no match layers, no amb layers / exactly one music player is audible** (after the duel, a match and the farm): the title never inherits a stem, a bed or a second music player from where you were.
- **all 18 rows ran**: a step that errors out (a script error ends that coroutine) can't skip its rows and still exit 0.

The check opens screens the way the game does (`Game.goto`). With a display (xvfb too) the old screen stays current until the 0.3 s ink fade has covered it, so it waits for a new current screen rather than a fixed frame count. Settles run at `Engine.time_scale` 4: the fades are game-time tweens.

## Soundtracks (Settings > Audio > Music)
`content/music/soundtracks.json` names one track per place (main menu, garden, an expedition's calm / fight / last moments, boss, a run that got out, training) for each style: **Classic Adventure** (the default: warm MIDI orchestra, flute, lute, harp, light drums), **Isles Folk** (the first score) and **Lantern Lo-fi**. Classic and Lo-fi are our own tunes, rendered by `tools/compose_soundtracks.py` through the same General MIDI bank as `compose.py`, each a whole number of bars with its tail wrapped onto the start, stretched by a few samples to end on a Vorbis block (no gap at the loop) and set to -14 LUFS with ffmpeg loudnorm (one linear gain). `Soundtrack` resolves the track: a hand pick for that place (`track_<place>`), else the style (`soundtrack`), else with `music_shuffle` a style rolled once per scene. The first score's tracks hand each place its own music back: the garden's islands and nights, and the expedition's layered stems. Any other pick makes `MusicDir` play one track per moment (boss, last moments, fight, calm) and crossfade when the moment changes. Soundtrack tracks don't join the house's record list (`Data.MUSIC`). `--soundtrack-check` covers it.

## Chop and mine sounds (`content/sfx/chop.json`, `tools/gen_sfx_chop.py`)
Played by `HomeGather._hit_sound` (each hit) and `finish` (the last), the same places the leaves, chips and crack marks react:
- **Tree**: `axe_bite` (3 takes) on every hit; `trunk_creak` from the second hit, pitched higher and louder as the hits add up; `tree_down` (whoosh, then the thud) when it falls.
- **Boulder**: `pick_strike` (3 takes) on every hit; `rock_crack`, pitched lower and louder as it weakens; `rock_break` on the last.
`--sfx-set-check` row 9 checks the files, their levels and that HomeGather plays only sounds that exist.

## Capture sounds (`content/sfx/capture.json`, `tools/gen_sfx_capture.py`)
All wired in `scripts/match/capture.gd`, so a rival's game plays them from the same net events (`scan_start`, `scan_stop`, `scan_done`) as the local one:
- **Scan hum**: the looping `revive_hum` on `Sfx.loop_start`, pitch rising from `rise_pitch[0]` to `[1]` with the scan fill, heard `hear_range` (26 m).
- **Success chime** by the Boki's rarity (`Capture.rarity_tier`, rules `pop_sounds`): `scan_pop` common, `scan_pop_fine` mutated, `scan_pop_rare` shimmer or a rare species. The music ducks (`duck_s`, `duck_db`) for a catch within hearing.
- **`scan_fail`**: a scan cancelled by Space, a dash or crowd control, a box that filled mid-scan, or a rival's scan that broke off.
- **`scan_call`**: the Boki's own short call at the catch, positional with a reach of 11 m.
- Voice limits are `Sfx.MIN_GAP` (a crowd of scans cannot stack one cue) and the pool's stacking cap.
- A monster's notice cue (`MobNotice`, `scripts/match/mob_notice.gd`): when an idle monster turns to chase (it saw a Hunter or was hit) its kind's `v_<kind>` voice plays from it, pitched as a short alert (small kinds high, heavy kinds low). A camp waking is one cue: a monster stays quiet while a camp-mate (camp spots within 5 m) is awake or cued in the last 3 s of match time. Clients cue from the synced idle -> chase change. Checked in `--mob-notice-check`.
- **Rarity stings** (`scripts/match/rarity_sting.gd`, `rarity_rare` / `rarity_very_rare`): a rare species (`Data.is_rare`) or a shimmer gets a short bell sting, 6 / 4 dB under full scale, so under the scan chime. Played when it comes into sight within 30 m in a match (`MusicDir` looks twice a second; once per Boki per match, the best of those new that look), when you claim it (`Capture._pop`, your own scans) and when it hatches (`EggHatch._pop`). While the fight stem is loud (`MusicDir.heat` 0.5 and up) a sight sting waits, and so does a claim sting (dropped). `--sfx-set-check` section 11.
## The Heart and the Ways Out calls
- `scripts/match/heart_sfx.gd` (`Heart.audio`) owns the Heartspark cues (`tools/gen_sfx_heart.py`, set `content/sfx/heart.json`) and the Ways Out calls: `call_out(event, seat, team)` with `open`, `start`, `taken`, `warn`, `last` plays one flat UI sting (`ways_*`) and writes the same line to the match feed and the toast lane, so sound and banner fire together. Each call plays once per seat (a squad's `start` again after 10 s); the quest seats call it the same way when they are built. `--ways-out-sfx-check` asserts it.
## The Blight tide (`scripts/match/tide_sfx.gd`, `tools/gen_sfx_tide.py`, set `content/sfx/tide.json`)
The tide ring closing on the Heart decides who gets out, so it is heard before it is seen. `TideSfx` is ticked by `HeartSfx.update` and reads only `Heart.tide_stage` and `Heart.tide_r`, so a client hears what the host does (no Net change). `tide_onset`: a 3 s rising swell when the tide starts (`tide_start_s`), flat, with the score ducked under it (`Sfx.duck`, 3 s, -8 dB). `tide_rumble`: a held loop (`Sfx.loop_hold`) on the ring's nearest point to you, carrying 70 m; `Sfx`'s distance roll-off makes it rise as the wall closes on you, and past 9 m it plays through the muffled bus so only the low end carries. `tide_warn`: a short falling two-note sting at each new close stage (11 stages, about 46 s apart), flat, score ducked 1 s, -5 dB. Joining mid-stage plays no cue. `--blight-check` section 7 asserts the onset once, a sting per stage and none inside one, the rumble on the ring and louder at 12 m than at 60 m; `--sfx-set-check` the files and levels.
## The garden's ambience (`scripts/home/home_ambience.gd`)
One bed for the part of the day on the home clock (`Home.day_t`): `amb_garden_morning` birds (0.2-0.4), `amb_garden_midday` a quiet hush (0.4-0.6), `amb_garden_evening` insects (0.6-0.8), `amb_garden_night` a slow wind; `amb_rain` while it rains. `amb_pond` comes up as you near water (full within 2 tiles, silent past 9, from `layout["water"]`). The beds go through `Sfx.amb_layer`, so they sit on the **Ambience** bus and follow its volume setting; a bed fades out as the next fades in over 20 s. At most 3 loops sound at once (the pond steps out during a crossfade), and the garden never plays `amb_match` (the title's wind). `Sfx` frees a bed once it has faded to nothing. Under them sits the bed of the zone you are in (GARDEN.md 10.2), `amb_zone_<zone>`, up in 3 s and kept: `hub` a quiet Waystone hum, `bramblebank` stream and nap-tree leaves, `glasswater` still pools and ice ticks, `cinderstep` warm cracks and embers, `hushwood` moss-soft hush with echoing knocks, `ridge` wind and humming stones. Hushwood's rule has `"clock": 0.7`, so its time-of-day bed stays at dusk. A hop plays `garden_hop` (0.64 s, swelling for the 0.5 s `hop_fade_s` light-up) from `HubWaystone.hop`; `GardenZones.wake(id)` opens a zone and plays `garden_wake`, once (the unlock step calls it). Regenerate the beds with `tools/gen_garden_ambience.py`, the two sounds with `tools/gen_sfx_garden.py`; `--garden-audio-check` asserts the zone beds, the hop and the wake. `--sfx-set-check` section 7 asserts all of this.
