## Loudness pass 11-28: every audio file by bus

Measured with `python3 tools/audio_lufs_report.py` (ffmpeg ebur128, integrated LUFS and true peak; one-shots under 0.4 s are looped to 2.4 s first, since ebur128 reads nothing shorter). Buses: ui (`ui` category sounds), kit (hunter/monster/world sets: steps, casts, impacts, fire, dash), hit (`hit_*`), ambience (`amb_*`), music (`music_*`), voice (`grunt`/`boki` sounds, `cries/`, `v_*`). Flag = more than 3 LU off the bus median.

| bus | files | median LUFS | flagged before | flagged after | re-rendered | peaks over -1 dBTP |
|---|---|---|---|---|---|---|
| ui | 213 | -24.1 | 18 | 18 | 0 | 0 |
| kit | 1565 | -20.6 | 574 | 559 | 16 | 71 |
| hit | 43 | -21.2 | 0 | 0 | 0 | 1 |
| ambience | 24 | -19.4 | 6 | 6 | 0 | 0 |
| music | 34 | -14.0 | 4 | 4 | 0 | 10 |
| voice | 1782 | -20.6 | 35 | 35 | 3 | 0 |

### What was re-rendered

Only 19 files changed. Outliers were moved by a constant gain (the linear form of `loudnorm`: same length and tail, no new sound) toward the median of their group (bus median, or for kit and voice the median of their set category), with the true peak held at or under -1 dBTP (`tools/audio_lufs_fix.py`).
The game already levels every named sound by RMS per category, with `gain_db` in `content/rules/sfx_levels.json` (`tools/sfx_loudness.py --check`) and per-take file checks in `--sfx-set-check`. A first pass re-rendered 284 outliers by LUFS; that broke both checks (106 outliers against 19 accepted, 18 failing sets), so every file named in a sound set was put back, and the checks are green again with the 19 left. Two oggs (`sting_home`, `sting_out`) also went back since vorbis re-encoding added 32 ms.
Most of the 559 kit files flagged are on purpose: steps sit 6 to 12 LU under the kit median and heavy impacts above it, inside their category band. Ambience and music beds were measured and left (levelled by layer in `HomeAmbience` and by the score, see docs/AUDIO.md). Peaks over -1 dBTP in kit and music are the originals' and untouched. Re-render the rest by tuning `gain_db` per sound, not by editing the wav.

### Ambience and music still flagged

| file | LUFS | off median |
|---|---|---|
| audio/amb_garden_morning.ogg | -23.8 | -4.4 |
| audio/amb_title.ogg | -13.8 | +5.6 |
| audio/amb_training_wind.ogg | -16.0 | +3.4 |
| audio/amb_zone_cinderstep.ogg | -25.2 | -5.8 |
| audio/amb_zone_glasswater.ogg | -28.3 | -8.9 |
| audio/amb_zone_hushwood.ogg | -24.5 | -5.1 |
| audio/music_home_night.ogg | -10.4 | +3.6 |
| audio/music_match_boss.ogg | -17.8 | -3.8 |
| audio/music_match_drive.ogg | -19.7 | -5.7 |
| audio/music_match_extract.ogg | -20.1 | -6.1 |

### Re-rendered files

| file | bus | before LUFS | gain dB | after LUFS |
|---|---|---|---|---|
| audio/armor_up_own.wav | kit | -16.3 | -4.3 | -20.6 |
| audio/kill.wav | kit | -16.7 | -3.9 | -20.6 |
| audio/mask_swell.wav | kit | -23.9 | +3.3 | -20.6 |
| audio/mask_whisper.wav | kit | -23.9 | +3.3 | -20.6 |
| audio/pay_cashin.wav | kit | -17.2 | -3.4 | -20.6 |
| audio/pay_cashin_1.wav | kit | -16.7 | -3.9 | -20.6 |
| audio/pay_flashpoint.wav | kit | -15.2 | -5.4 | -20.6 |
| audio/pay_flashpoint_1.wav | kit | -15.8 | -4.8 | -20.6 |
| audio/scan_pop.wav | kit | -17.5 | -3.1 | -20.6 |
| audio/smg.wav | kit | -24.4 | +0.9 | -23.5 |
| audio/smg_1.wav | kit | -24.3 | +1.7 | -22.6 |
| audio/smg_2.wav | kit | -24.7 | +0.7 | -24.0 |
| audio/smg_3.wav | kit | -24.7 | +1.3 | -23.4 |
| audio/st_chill.wav | kit | -17.3 | -3.3 | -20.6 |
| audio/sting_extract.ogg | kit | -12.2 | -8.4 | -20.6 |
| audio/sting_last.ogg | kit | -15.7 | -4.9 | -20.6 |
| audio/v_sentinel_1.wav | voice | -22.8 | +3.2 | -19.5 |
| audio/v_sentinel_2.wav | voice | -22.7 | +3.1 | -19.6 |
| audio/v_sentinel_3.wav | voice | -22.8 | +3.2 | -19.6 |
