# VFX origins on the v2 models (11-09)

Where each Hunter's round or cast leaves the model, before and after `content/shot_origins.json`
(`scripts/arch/shot_origin.gd`, docs/HERO_VFX.md "Shot origins"). Sheets: `<hero>_before_after.jpg`. Each row is one
move's `--hero-vfx-reel` part (3x3 frames from the key press), before on the left and after on the right.

The offsets were measured headless against the .glb empties at the release pose. They are metres from the feet along the
aim: forward, up, side (+ right). The round keeps its height (the hit band), so "after" shows the gameplay height and the
muzzle flash sits on the real node.

| Hunter / move | anchor (model) | before | after |
|---|---|---|---|
| Vex LMB (Longneedle) | `weapon_muzzle` 0.28-0.38, 0.77, 0 | 0.60, 0.95, 0 | 0.32, 0.95, 0 |
| Lace LMB (bow) | `anchor_nock` 0.35, 0.92, -0.52 | 0.61, 0.86, 0 | 0.35, 0.86, -0.52 |
| Sparkle LMB (finger guns) | `anchor_gun_R` / `_L` | 0.30, -, ±0.11 | R 0.35, +0.15; L 0.45, -0.52 |
| Sable bolts (two crossbows) | `weapon_muzzle` 0.42, 0.07; `_l` 0.39, -0.51 | 0.60, 0.86, ±0.28 | 0.42, +0.07 / 0.40, -0.50 |
| Sable E (star) | right crossbow hand | 0.60, 0.95, 0 | 0.22, 0.95, +0.21 |
| Grimble LMB (gun) | `weapon_muzzle` 0.56, 0.82, -0.19 | 0.62, 1.08, -0.16 | 0.59, 1.08, -0.19 |
| Cinder RMB (palm) | `GunMuzzle` at RMB 0.58, -0.41 | 0.60, 0.95, 0 | 0.50, 0.95, -0.30 |
| Tenzo boulder (fists) | `anchor_fist_R` 0.03, 0.97, 0.07 | 0.60, 0.95, 0 | 0.30, 0.95, +0.07 |

Already on the anchor (no change): Cinder LMB (`weapon_muzzle`, 0.00 off), Vex RMB (`launcher_muzzle`, 0.01 off),
Sparkle RMB / E (hands).

Left as is, with reasons:
- Vex E (Palm Lance from the open palm) is on ext/vex-coin-palm-1108.
- Lace RMB is on ext/lace-playtest-1108.
- Lace E falls from above by design.
- Sable's RMB bola whirls overhead by design.
- Grimble's RMB / E and Tenzo's punch impact are hits at range, not spawns.
- Sparkle's rod anchors sit on her back (y 1.6); her rounds use the finger-gun anchors.
- Grimble's reel has only the hook part, so it has no sheet; his offset is in the table.
