# Audio: sound sets, loudness and buses

How the game's sound effects are made, named, levelled and played. Music is in `tools/compose.py`; ambience beds in `tools/gen_ambience.py` (below).

## Making sounds
- Sounds are **synthesised in code** (numpy/scipy, `pip install numpy scipy`), one script per group: `tools/gen_sfx_<group>.py` (e.g. `gen_sfx_vex.py`, `gen_sfx_boki.py`, `gen_sfx_ui.py`). Each one imports `tools/sfx_lib.py`, calls `S.reseed(<its own seed>)` and writes `audio/<name>.wav` (44.1 kHz mono 16-bit). Then `godot --headless --import`.
- `sfx_lib.py` re-uses the primitives in `tools/sfx_combat.py` (filters, envelopes, kick, click, crack, sub, tail, reflections, ring, grains) and adds `voice()` (wordless grunts and cries through vowel formants), `chime()`, `creak()`, `fm()`, `sweep()`, `rattle()`, `hiss()`.
- Outside sources only if **CC0**, logged in `docs/CREDITS.md` under the group's own section (source URL, author, licence, which file). No sounds from SUPERVIVE or any other game.
- Review: `python3 tools/sfx_look.py out.png audio/<names>*.wav` draws waveform + spectrogram + levels per sound (matplotlib). Use it to judge layering, clicks and harshness, and as the READY screenshot.
- Held sounds (a minigun spin, a charge hum): write them with `S.save_loop(name, x, cat)`, which cross-fades the tail into the head and skips the end fades, list them under `"loops"`, and play them with `Sfx.loop_start` / `loop_stop`.
- Variety: write takes with `S.takes_cat(name, fn, 3, cat)` (`name.wav` + `name_1..3.wav`); `Sfx` picks a different take each time.

## Hit by target
The weapon's own hit sound says whose hit landed; a short quiet layer under it (`Juice.TARGET_DB`) says what it landed on. `HitClass.of` picks the class, `HitClass.SOUND` the sound (`tools/gen_sfx_targets.py`, set `content/sfx/targets.json`): `hit_armour` a bright crack and ring, `hit_body` a dull thump, `hit_boki` a soft squeak in the Boki voice range, `hit_monster` a wet crunch, `hit_wall` a dull thud when your shot ends on a wall or terrain. `--sfx-set-check` checks every class has its sound and that each take stays under 0.25 s.

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

## Names
- A Hunter's own sounds start with its archetype id: `gunslinger_*` (Vex), `archer_*` (Lace), `juggernaut_*` (Kael), `bulwark_*` (Mossy), `ostra_*` (Motley), `ashwick_*` (Cinder), `dredge_*` (Grimble), `rimewright_*` (Neve), `tender_*` (Meeko), `thief_*` (Sable), `mage_*` (Sparkle), `dolm_*` (Tenzo). Older kit sounds keep their names (`vn_*`, `jug_*`, `rime_*`...); a branch that replaces one regenerates that file under its old name.
- **Shared kinds picked per Hunter by `HeroSfx`** (falls back to the shared sound when a Hunter has none): `<arch>_dash`, `<arch>_hurt`, `<arch>_down`, `<arch>_death`, `<arch>_step_grass|stone|wood|snow`, `<arch>_pickup`. Footsteps on sand, shallow water and metal are not per Hunter: `step_<sand|water|metal>_<light|medium|heavy>` (set `steps`, `tools/gen_sfx_steps.py`, synthesised in code, no outside sound) play by the Hunter's weight class, a little louder the heavier it is, unless the Hunter has its own `<arch>_step_<surface>`. Wired at: the dash (`Hunter`; with its own dash, `Feel.dash_sound`'s shared layers are skipped), footsteps (`Juice.footstep`, the surface from `StepSurface`: a map's `surfaces` tile rects (sand, water, metal), its `bridges` and the farm's opened bridges = wood, the sky train's deck = metal), loot picked up or put on (`Pack`), your own hurt (`Match` damage), downed (`Match` knock and its net event) and death (`Life.drop_box`). The voice lines are wordless.
- Mob and boss attacks (`content/sfx/mob.json`, `tools/gen_sfx_mob.py`) play by kind, never a Boki `k_*` cue: `mob_<kind>_atk` as the mob strikes, `mob_<kind>_hit` where it lands (`Mob._snd`; a spitter's or sentinel's shot carries `"snd"` and plays it on the hit), `boss_<kind>_tell` from the start of each boss telegraph (`Boss._begin`), swelling to the strike, plus `boss_slam|throw|boulder|spit|glob`. `--sfx-set-check` fails if `mob.gd` or `boss.gd` plays a `k_` name.
- **Pickups by item category** (`PickupSfx`, `content/rules/pickup_sfx.json`, `tools/gen_sfx_pickups.py`): armour and boots `pickup_armor`, active gloves `pickup_weapon`, treasure and gems `pickup_gem`, belt items `pickup_consumable`, everything else `pickup_generic`; the category comes from the item's data (gear slot, treasure, belt item). A Hunter's own `<arch>_pickup` still wins. Keys keep `key_get`. The tonic drink plays `use_tonic`, the armour-kit repair `use_armor_kit`. `--sfx-set-check` asserts every category has a file.
- **Shared kinds picked per Hunter by `HeroSfx`** (falls back to the shared sound when a Hunter has none): `<arch>_dash`, `<arch>_hurt`, `<arch>_down`, `<arch>_death`, `<arch>_step_grass|stone|wood|snow`, `<arch>_pickup`. Wired at: the dash (`Hunter`; with its own dash, `Feel.dash_sound`'s shared layers are skipped), footsteps and landings (`MoveSfx`), loot picked up or put on (`Pack`), your own hurt (`Match` damage), downed (`Match` knock and its net event) and death (`Life.drop_box`). The voice lines are wordless.
- Boki wisp sounds (`tools/gen_sfx_wisps.py`, wired in `KinSummon`, played positional so far ones get the far muffle): `wisp_chirp_small|medium|large` (the riding wisp every 14-26 s and as it blooms, pitched by body size and the individual's voice), `wisp_bloom`, `wisp_shrink`, `wisp_ready` (cooldown over). `wisp_grab` (a thief catches a loose wisp) is made but has no call site until the steal rule exists. The Hunter Wisp hum (`wisp_hum`) is `tools/gen_wisp_sfx.py` on ext/hunter-wisp-outline: round = low hum, critter = chirp.
- Warnings (`content/sfx/warn.json`, `tools/gen_sfx_warn.py`): `warn_heartbeat` (the local Hunter under 25% health, quicker as it falls, silent when healed, downed or out: `WarnSfx.low_hp`), `warn_tick` (one a second, rising in pitch, for the last 10 s before a skiff comes in, leaves, or an uplink lift shuts: UI-level for your squad's exit, from the exit for a rival's; the rift hatch has its own unlock ticks), the skiff boarding cues in `ExitSfx` (`board_hum`, a loop for as long as you stand on the deck; `board_cancel` when you step off, go down or die with the skiff still at the pier; `depart_sting` as it casts off, UI-level when your squad is aboard, a distant one from the berth, reach 60 m, for rivals), and `blight_rumble` (a Skitter pack clawing out of the ground, a Blight Warden's shriek).
- Boki moments: `boki_downed` / `boki_revive` (a Boki goes down / comes round, `KinDowned`, `KinNet`), `boki_fuse` / `boki_unfuse` (`MergeXform`), `boki_eat` (feeding at home), `boki_sleep` (a nap starts at home). `--sfx-set-check` asserts each is in a set, exists and is named by the script that plays it (`WIRED`).
- Boki sounds: `boki_*` (and the existing `kin_*` / `k_*` names); UI: `ui_*` (and the existing `click`, `hover`...).
- Species voices: `bk_<species>_<mood>` for every rigged species (`art/kin/*`), moods happy, alert, unsure, sleepy, hurt, 2 takes each (set `content/sfx/boki_voices.json`, made by `gen_sfx_boki.py`). Pitch comes from the species' weight, the texture from its type (crackle Fire/storm, burble Water/venom, rustle Grass/spore/swarm, chime Crystal/moon/sound, else plain), the 3-note motif is its signature. Play them with `KinVoice.cue(species, mood)`: it falls back to `kin_happy` / `kin_alert` / `kin_unsure` / `boki_sleep` / `kinhit` for a species with no set. A new species adds its row to `SPECIES_VOICE` and regenerates; `--sfx-set-check` fails if a rigged species lacks a mood.

## Sound sets (`content/sfx/<group>.json`)
```json
{"group": "gunslinger", "name": "Vex", "script": "tools/gen_sfx_vex.py",
 "sounds": {"gunslinger_dash": "dash", "gunslinger_hurt": "grunt", "vn_spin": "signature", "...": "..."},
 "signature": ["vn_spin", "gunslinger_grenade_thunk"],
 "kit_files": ["gunslinger_ult.gd"], "replaces": ["vn_rifle", "..."],
 "reach": {"gunslinger_fire": 45}, "loops": ["gunslinger_spin"]}
```
`--sfx-set-check` asserts: every listed sound has its file(s); every take is within 3 dB of its category and under the ceiling; a Hunter set has hurt/down/death, dash, steps on all four surfaces, a `fire` sound and its signature list; `HeroSfx` picks them up; a Hunter of each weight class walked over every surface of the Hollow Crown (and the train deck on Skyreach) plays the expected step; every literal `m.sfx("...")` in that Hunter's kit (`<arch>_kit.gd` plus its `kit_files`) names a sound that exists. `replaces` lists old-name files the set regenerated. `reach` (metres, 22-80) makes a heavy sound carry past the usual 22 m, so you hear a carry coming (past 9 m it plays through the muffled bus, so the low end is what carries); `Sfx` reads it from every set at start. Each sound under `loops` must repeat seamlessly.

## Playing and buses
- **Positional one-shots pan.** With a position and a 3D camera, `Sfx` plays them from an `AudioStreamPlayer3D` placed at the sound, so you hear which side it is on; the level is still `Sfx`'s own falloff (Godot's attenuation is off, `Sfx.PAN` sets how hard it pans). UI sounds (no position) and keyed loops stay unpanned.
- **Movement sounds** (`MoveSfx`, numbers in `content/rules/move_sfx.json`): another Hunter's footsteps carry 14 m (`step_reach_m`), landings, dashes and the glider the usual 22 m. Footsteps and landings are weighted by the Hunter's height: taller is lower and louder (Kael 2.05 m about 0.89x and +2.7 dB, Neve 1.56 m about 1.01x and -0.2 dB). Footsteps are silent while crouched or unseen. `--match-audio-check` asserts an enemy's footstep plays placed at it, inside the reach and not past it.
- Always through `Sfx.play(name, pos, vol_db)` / `m.sfx(...)` (one-shots, pooled, distance falloff, far sounds muffled) or `Sfx.loop_start(key, name, pos)` / `loop_set` / `loop_stop` (held sounds). Never a new `AudioStreamPlayer`.
- They play on the **SFX** bus (compressor, a little room, limiter; far ones via **SFXFar**). A match's sounds are torn down with the match (item 103, `Sfx.reset_scene_audio` stops keyed loops and pool voices on the match leaving the tree), so every held sound must be a keyed loop and stopped by its owner too.
- **Squad cues** (`Sfx.CUES`: `knock_confirm` when you or a squadmate down a rival Hunter, `elim_confirm` when one is finished; wired in `Juice.knock` / `Juice.kill`): played flat (not positional) on their own voice, so footsteps and the combat crowd never steal or thin them. Rivals' kills, friendly knocks and mobs play nothing. `--knock-sfx-check`.
- A monster camp's tell (`MobAlert`, `scripts/match/mob_alert.gd`): when an idle monster sees a Hunter its kind's `v_<kind>` voice plays pitched as an alert (small kinds high, heavy kinds low), at most once per camp per 3 s; idle monsters within 16 m of the listener murmur the same voice quiet and low every 5-9 s. Checked in `--match-audio-check`.
- New sounds load on first play (`Sfx._lazy`, takes included); no edit to `Sfx.NAMES` is needed.

## Ultimate cast cues
You hear an ultimate before you see it. Every Hunter's X goes through `HeroUlt.press`, which calls `UltCue.cast`: the Hunter's own `<arch>_ult_cue` at its position plus a team tag, `ult_tag_ally` (bright, rising) for your team or `ult_tag_foe` (low, falling) for a rival, both at the same level (the colour tells them apart, never loudness). They carry 60 m (`reach` in `content/sfx/ult_cues.json`, falling off with distance, muffled past 9 m) and play on the match's pool voices. Kits only run in their owner's game, so the cast also sends `["fx", "ucast", nid]` and the other games play it. Sounds: `tools/gen_sfx_ult_cues.py` (own seed; re-rolls nothing else). `--sfx-set-check` asserts a cue and reach per Hunter with an ultimate; `--match-audio-check` the ally/rival tag and the range.

## Ambience beds
`Sfx.play_ambience` holds one main bed (`amb_match` wind in a match, `amb_title` on the title, `amb_home` on the farm); `Sfx.amb_layer` fades extra beds by place, 4 times a second (`MusicDir` -> `AmbBeds`, no allocation per tick). `tools/gen_ambience.py` writes them (seamless stereo Ogg loops, original synthesis; `amb_rain` is from `gen_music.py`):

| bed | plays when |
|---|---|
| `amb_abyss`, `amb_ruins` | near a void edge or gliding; among walls (`MusicDir`) |
| `amb_meadow`, `amb_cliffs` | on meadow/bloom islands; on frost/ember/storm/gloom rock. Nine samples round you vote, so the bed fades over the last metres of its island |
| `amb_water` | on the shore islands (`AmbBeds.WATER_ISLANDS`: Saltmere), over that island's own bed |
| `amb_gust`, `amb_rain` | the raid condition (`AmbBeds.GUST` / `RAIN`): ash storm is all gust, dusk and fog bring rain |
| `amb_blight` | a low rumble that follows `BlightDir.level` where you stand (up toward the core, up with the session's age) and climbs in the last 90 s before the islands fall |

## Recast cue sounds
Every Hunter's recasts sound the same (DECISIONS 2026-11-08, two-step abilities): `RecastSound` (`scripts/arch/recast_sound.gd`) reads `ArchKit.recast_window()` (`{slot, left}`) each step for the local hunter only and plays `recast_open` as a window opens and `recast_tick` 0.5s before it closes (`tools/gen_sfx_ui.py`, at the ui loudness). They are UI sounds (no position, so only the caster hears them), pitched per slot (`RecastSound.PITCH`) so an E and an X window differ. A window that waits for you (Bulwark's hammer) never ticks. `--recast-sound-check` asserts one chime and one tick per window for every recast kit.
