# 0.24.6 audio-vfx wave: audio checks, alone

Base `origin/main` + `origin/ext/w0246-audio-vfx` (70b9bd7b9, 65 branches, no suite run). Every audio check in
`tools/check_registry.gd`, one at a time, `xvfb-run godot --headless --path . -- --<flag>`, 600 s timeout, own temp XDG
(rpc7). 0.24.5 = `origin/ext/release-integ-0245`. "n/a" = the check is not on 0.24.5 (the wave adds it).

| Check | 0.24.5 | Wave as merged | After this branch |
|---|---|---|---|
| --sfx-set-check | green | green | green |
| --sfx-strike-check | n/a | green | green |
| --sfx-occlusion-check | n/a | green | green |
| --music-leave-check | green | **RED 1** (leave duel: farm beds) | green |
| --match-audio-check | green | **RED 2** (armor_kit end cue; voices left) | green |
| --knock-sfx-check | n/a | green | green |
| --xp-cue-check | n/a | green | green |
| --recast-cue-check | green | green | green |
| --armor-break-sfx-check | n/a | green | green |
| --status-sfx-check | n/a | green | green |
| --ready-cue-check | n/a | green | green |
| --ways-out-sfx-check | green | green | green |
| --garden-audio-check | green | green | green |
| --garden-sfx-check | green | **RED 5** (all chime rows) | green |
| --sting-check | green | green | green |

No voice-cap or mix check is registered under an audio name (`--unstable-mix-check` is the Nook's breeding mix).

## The three reds and their causes (none is a renamed cue, a missing file or a bus change)

- **garden-sfx chimes**: `StatBudget` kept `rec.loose` as a per-stat dict on the wave but `Care` and `GardenItems`
  keep one int pool. A garden record has `loose = 0`, so `StatBudget.add` died on `0.get(...)`, no stat rose and no
  chime fired. 0.24.5 fixed it in 725a26228 ("one loose-point pool"), which main lacks; cherry-picked here (also fixes
  `--stat-budget-check` rows).
- **music-leave / match-audio, farm beds**: the garden now sounds its own `Sfx.amb_layer` beds (time of day, zone,
  pond; `HomeAmbience`), so "no amb layer left after a match" and `Sfx.match_voices() == 0` were red on the farm. Both
  checks now name the match's beds (abyss, ruins, meadow, cliffs, water, gust, rain, blight) and fail only if one of
  those is left; `match_voices` is compared after the farm's own beds. The title still asserts no layers at all.
- **match-audio, armor_kit end cue**: a rival's Boki walks up to the idle user and hits it every ~1 s (12.9 HP, 4 hits
  in the belt rows); each hit spills the 1.6 s repair, so the "end" cue never plays (the 1.0 s tonic slipped through).
  The check now removes the rivals' Boki before the belt rows (as `--online-displace-check` does).

Nothing here belongs to a held line (wisp-summon, utilities-shops).

Also: `docs/wiki/Rules.md` and `Boki-Species.md` were stale on the train; regenerated with `tools/gen_wiki.py`.
