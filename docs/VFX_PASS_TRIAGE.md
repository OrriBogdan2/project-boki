# ext/vfx-pass triage against 0.24.5 (2026-11-12)

`ext/vfx-pass` (b7d8bf3c0) merges the 13 READY 11-08 VFX branches; `ext/vfx-origin-v2-rebased` (82998a018) sits on
it. Both were held (docs/MERGE_0246_ANIM.md on ext/anim-stop-on-stride) because they conflict in 31 files with 0.24.5's
HeroVfx rework and cel roll. They are **not merged**. This branch, ext/vfx-pass-triage, ports the parts that still add
readability onto 0.24.5's HeroVfx data instead. Base: origin/main + origin/ext/release-integ-0245 (272368589).

"Covered" was judged from the scorecard in docs/VFX_QUALITY.md, the branch's strips (`vfxq-before/after-<arch>`)
and whether 0.24.5's kit already draws that Hero through HeroVfx data (`content/vfx/<arch>.json`).

## The 13 branches

| branch | Hero | 0.24.5 | call |
|---|---|---|---|
| ext/vfx-quality-base 9a9bb3b79 | all | merged (signature colours, shared ring/flash/bolt fixes, the scorecard) | covered |
| ext/vfx-archer ba59ff093 | Lace | merged (orchid HeroVfx, 16 -> 27) | covered |
| ext/vfx-kael-polish 2500aca86 | Kael | merged (X crescent on the strip, 27 -> 29) | covered |
| ext/vfx-bulwark f612a5702 | Albert | his own kit VFX pass (681d0cf7f, content/vfx/bulwark.json: hammer, shield, slam) replaced the branch's look | superseded |
| ext/vfx-tender cfbdc5abe | Meeko | her own HeroVfx data (7816700fc, content/vfx/tender.json, starlight heals) replaced it | superseded |
| ext/vfx-rimewright-quality 8b5e2c51d | Neve | already HeroVfx and re-cut by the 11-10 cel roll; the branch re-tunes the same moves on the pre-cel data | superseded; re-tune on 0.24.5 data if wanted |
| ext/vfx-cinder-polish 89e74c9cb | Cinder | HeroVfx data, but not the branch's ground-landing motes (f7bfb8df3) or palm heat glow (ecfc61828) | small polish (28 -> 30), not ported |
| ext/vfx-mage 43524c781 | Sparkle | 0.24.5's own Sparkle kit pass (68df1a589) cut the non-gameplay bursts; she keeps the teal-body / pink-core lightning (DECISIONS) on VVFx | mostly superseded; the all-pink HeroVfx move is an owner colour call |
| ext/vfx-dredge 794ca0e37 | Grimble | not in 0.24.5; carried by the 0.24.6 wave ext/w0246-audio-vfx (c633f8297, content/vfx/dredge.json) | covered by the wave |
| ext/vfx-thief (a97ed6c09) | Sable | not in 0.24.5 (still DJFx kit looks; LMB hits faint); 6 conflicted files incl. the dj_fx shader include | still worth it (18 -> 25); next to port |
| ext/vfx-dolm 9871872fa | Tenzo | not in 0.24.5 (worst row, 14) | **ported** |
| ext/vfx-ostra-abilities d21f7a537 | Motley | not in 0.24.5 (worst row, 14: opaque domes, violet) | **ported** |
| ext/vfx-gunslinger 1bb6c7bcd | Vex | not in 0.24.5 (ember-orange kit looks against her lime colour, faint tracer, opaque X disc and pillar) | **ported** |

ext/vfx-pass's own commits on top (shared StunMark, Tenzo punch/dash/rock bursts in cobalt stone, Neve dash pill,
Albert hammer/dash palette, Sable ult hits) are not ported: the StunMark overlaps 0.24.5's CC body reads
(ext/vfx-cc-body-reads-0245), and the rest are per-Hero tweaks on looks 0.24.5 replaced.

## Ported (the three that add the most readability, worst rows first)

- **Tenzo** (ext/vfx-dolm, 14 -> 24 on its strips): slam, RMB charge, hop landings and Basalt Spine are
  `content/vfx/dolm.json`: a crack crater, a wall out to the hit edge, rock debris, crack lanes under the spine, in
  cobalt. `scorch_t` leaves dolm.json (nothing reads it). His punch, boulder and launched-rock bursts stay `Fx` calls.
- **Motley** (ext/vfx-ostra-abilities, 14 -> 25): Snap, Brimseed and Nightwell are `content/vfx/ostra.json` in sea
  teal over void cores; no violet flashes or opaque domes; the Snap trail follows the spear. Reel parts in
  `tools/vfx_reel/ostra.gd`. Dash, LMB and Swollen pink are untouched.
- **Vex** (ext/vfx-gunslinger, 15 -> 26): LMB tracer and muzzle, reload, Longneedle charge/fire/hit and Cinderfall
  are `content/vfx/gunslinger.json` in lime; the opaque X disc and pillar are gone. 0.24.5's logic stays: the Burr
  flight over slopes, the Longneedle turn cap and view push, the pink Daze (its own colour), the miss puff with no
  ring, and the Cinderfall shot on the clip's kick key (`_fire` now plays `x_cast`; the fall sound stays at the cast).

All three recipes have their smoke cut to 0.24.5's cel rule (4c8167e3f: cel puffs are near opaque, so fewer and about
0.6x the size).

## vfx-origin-v2 (effects leaving the hands and weapons): still off, ported in part

0.24.5 still fires Sable's bolts 0.28 m to the side of her body and her knife from her chest, Grimble's slugs 0.9 m
ahead of him, Tenzo's boulder from his chest and Cinder's RMB from the body. `ShotOrigin` + `content/shot_origins.json`
(ec66cc712) now seat those rounds at the measured muzzle and put the flash on the .glb empties (all present on today's
models: sable weapon_muzzle / weapon_muzzle_l, tarek anchor_fist_R, dredge and cinder weapon_muzzle). Not ported:
Sparkle (0.24.5 already seats her bolts on anchor_finger_L / weapon_muzzle), Lace and Vex (HeroVfx anchors; the .glb
fixes are on ext/vfx-emit-anchors-0245). Open: the [side, forward] numbers were measured on the 11-09 v2 models;
the 11-10/11-11 swaps may move them a few cm. Re-measure from the reels below if a strip shows a gap.

## Proof

Checks (headless, this branch): `--hero-vfx-check` OK (incl. the origin rows), `--dolm-combo-check` 172/0,
`--ostra-combo-check` 213/0, `--gunslinger-combo-check` 130/0, `--dredge-combo-check` 112/0,
`--ashwick-combo-check` 125/0, `--dancer-combo-check` 144/0.

Reel strips (`--hero-vfx-reel --reel-hero=<arch>`, GPU through jobq, before = 272368589, after = this branch):
see the table at the end of this file.

| item | Hero (`--reel-hero`) | before job (jobq label) | after job (jobq label) |
|---|---|---|---|
| ext/vfx-dolm port | dolm | 20261112-023058-17230 (vpt-dolm-before) | 20261112-023217-17343 (vpt-dolm-after) |
| ext/vfx-ostra-abilities port | ostra | 20261112-023228-21446 (vpt-ostra-before) | 20261112-023241-18394 (vpt-ostra-after) |
| ext/vfx-gunslinger port | gunslinger | 20261112-023255-18767 (vpt-gunslinger-before) | 20261112-023308-11668 (vpt-gunslinger-after) |
| origin-v2: Sable bolts, knife | thief | 20261112-023322-20679 (vpt-thief-before) | 20261112-023335-28518 (vpt-thief-after) |
| origin-v2: Grimble slugs | dredge | 20261112-023349-03039 (vpt-dredge-before) | 20261112-023403-26828 (vpt-dredge-after) |

Sheets land in `/home/boki/jobq/done/<id>/out/reel_<arch>/<arch>_<part>.png`. They were still queued (GPU queue 112
deep) when this branch was posted, so the look is not yet seen on a GPU strip.
