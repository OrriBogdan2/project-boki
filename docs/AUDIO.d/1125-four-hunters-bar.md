## Ability bar: Sable, Sparkle, and the second pass for Grimble and Tenzo (11-25, ext/sfx-four-snd3)
The four Hunters scored Sound 3 in VFX_QUALITY. Sable and Sparkle get a `"bar"` (section 16 of `--sfx-set-check`, see
"Ability bar"); Grimble and Tenzo already had one and gain the beats below. New sounds are made by
`tools/gen_sfx_ability_bar.py` from the same primitives (no samples), at their category level. Bold = new.

| Hunter | ability | cast | travel | hit | end |
|---|---|---|---|---|---|
| Sable | LMB arc bolt | dj_bolt + **thief_bolt_tail** (shimmer) | - (0.23 s flight) | thief_hit | - |
| Sable | RMB Bola | dj_bola_whirl, dj_bola_throw | - (0.23 s flight) | **thief_hit_rmb** (cord pulls tight, weights knock) | thief_bola_tie |
| Sable | E Shadow Knife | dj_knife_throw + thief_knife_whisk | **thief_knife_fly** (loop, up to 0.375 s) | **thief_hit_e** (stab, ting) | thief_knife_stick |
| Sable | Shift Vault | thief_dash | - | - | - |
| Sable | X Encore | dj_encore + dj_encore_rise | dj_encore_whirr | **thief_hit_r** (blade slice; dj_encore_hit stays the look's) | thief_encore_end |
| Sparkle | LMB finger bolt | vv_bolt + **mage_bolt_tail** (sparks) | **mage_bolt_fly** (loop, 0.35 s) | mage_hit | - |
| Sparkle | RMB Storm Rod | vv_rod_summon, vv_rod_throw | - (0.24 s flight) | **mage_hit_rmb** (zap) | mage_rod_fizzle (a miss) |
| Sparkle | E Skycall | vv_sky_place | vv_sky_count | **mage_hit_e** (thunder tick) | vv_sky_strike |
| Sparkle | Shift Wirerun | vv_surge_charge | vv_surge_go | **mage_hit_dash** (whip crackle) | - |
| Sparkle | X Kitefall | vv_ult_charge | vv_ult_hum | **mage_hit_r** (crash) | vv_ult_slam |
| Grimble | LMB blunderbuss | dr_shot + **dr_shot_tail** (scrap rattling away) | **dr_slug_fly** (loop on the last slug) | dredge_hit | - |
| Tenzo | LMB boulder | br_throw + **br_throw_tail** (stone grinding) | br_boulder_fly | dolm_hit | br_boulder_hit |
| Tenzo | E Stone Row (punched rocks) | br_crack | **br_rock_fly** (loop on the last rock, 0.55 s) | dolm_hit_rock | br_burst |

`HeroSfx.fly` holds a travel loop on a shot's position while the kit keeps the shot (`Sfx.loop_hold`, so it stops
within 0.25 s of the shot's end). A Wirerun hit carries `ab: "dodge"`, now mapped to the `dash` slot in
`HeroSfx.HIT_SLOT`, so it plays `mage_hit_dash`. `--sfx-set-check` also reads `content/weapons` and `content/vfx` for the
sounds a bar names. `--hero-vfx-reel --reel-movie` records a Hunter's reel with the real mix (see the header of
`tools/hero_vfx_reel.gd`).
