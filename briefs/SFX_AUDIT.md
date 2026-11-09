# SFX audit (owner priority 6: "every ability, hit, UI action, ambience")

Written 2026-11-09 by job 20261109-061440-a4 against `origin/main` d255acbee. Read-only: no game code changed. File paths below are on main (this briefs branch carries an older tree).

## Method (re-runnable)
1. Listed `audio/` (939 .wav, 20 .ogg, 470 distinct sound names with take suffixes folded) and the 14 sound sets in `content/sfx/*.json` (12 Wardens, `boki`, `ui`).
2. Scanned every `sfx(...)` / `Sfx.play/voice/ensure(...)` literal in `scripts/` and every `"sfx"/"sound"/"n"` key in `content/`: 309 names, **all have a file** (no missing-file bug; `--sfx-set-check` 0 failures, `--check` 0 failures).
3. Read each kit's cast, hit and passive paths for which sound they play, and whether it is the Warden's own (`<arch>_*`, `vn_*`, `jug_*`, `lw_*`, `br_*`, `dr_*`, `os_*`, `rime_*`, `tend_*`, `vv_*`, `dj_*`, `pin_*`, `bjorn_*`) or a **shared stock sound** (`throw`, `boom`, `zap`, `whoosh`, `click`, `pickup`, `unlock`, `hit`, `skill`, `knock`, ...).
4. Frequency = my estimate of times a player hears it in one 10-minute match (no telemetry exists for this; treat as order of magnitude). "Placeholder" = a shared stock sound pitch-shifted to stand in for something that deserves its own.

All new sounds must be original synthesis (`tools/gen_sfx_<group>.py` + `tools/sfx_lib.py`, per docs/AUDIO.md) or CC0 logged in docs/CREDITS.md. No franchise audio.

## Verdict
Warden kits are in good shape: every one of the 12 has its own dash, hurt/down/death voice, 4-surface footsteps, weapon, RMB, E and ultimate sounds (22-29 files each). The gaps are **outside the kits**: the shared layer (hits, movement, gloves, items, pickups, UI beyond buttons), the **Boki** (most abilities use one generic cue), and the **ambience** (one wind bed in every match).

## Ranked by how often a player hears it

| # | Event | Per match (est.) | Status | Gap / fix |
|---|---|---|---|---|
| 1 | Footsteps | 500+ | OWN x12, 4 surfaces (`<arch>_step_grass/stone/wood/snow`, `Juice.footstep`) | Only 4 surfaces; no sand/water/metal. Fine until maps add them. |
| 2 | Music + ambience bed | constant | Music: 4 layers (calm/drive/boss/extract) + hollow/match. Ambience: `amb_match` wind, `amb_abyss` + `amb_ruins` layers by position | **Same wind bed on the title screen and every match; no weather, biome, water, lair or creature beds. `amb_rain` plays at home only.** Gap A. |
| 3 | LMB fire/swing | 100-400 | OWN x12 (weapon sound or kit `lmb_override`) | Weapon JSON still names stock sounds for 6 signature weapons (`flamethrower` smg, `rubble_fists` thump, `tower_shield` cleave, `shotgun`, `spellstaff` zap, `longsword/twin_blades` swipe); the kits override most of them, so confirm by ear that none leaks. Pickup weapons (smg, rifle, burst rifle, shotgun, sniper) are shared stock: acceptable, but 5 guns that sound alike. |
| 4 | Your hit lands (hit tick) | 100-300 | **SHARED**: `hit`/`crit` tick for every weapon; `slash_hit` (melee), `armor_hit`, `hit_heavy` (>=28 dmg) layered in `Juice` | Same tick for all 12 Wardens and all targets (Warden, mob, Boki, wall). No per-weapon-class or per-target-material impact. Gap B. |
| 5 | You take damage | 50-150 | OWN x12 hurt voice; `armor_hit` | No low-HP warning (heartbeat/pulse); nothing signals "one hit from down". Gap C. |
| 6 | Jump / land / glide / wall kick | 60-150 | **SHARED** by all 12 (`jump`, `land`, `glide`, `step_stone` for wall kicks) | Same for a 400 kg Albert and a light Sable. Pitch/weight variant per `weight` class in `archetypes/*.json` is cheap. |
| 7 | UI buttons (click/hover/confirm/back) | 20-60 (menus) | OK: `Ui` auto-assigns `click`/`ui_confirm`/`ui_back`/`hover` to every button | Sliders, toggles, tabs and inventory drag/drop were not verified; `ui_tab` has 1 call site. |
| 8 | Dash | 40-70 | OWN x12 (`<arch>_dash`) | OK. `Feel.DASH_SOUND` is a stale 8-entry table of layered stock sounds that the own sounds supersede; delete it when touching feel.gd. |
| 9 | Boki ability cast | 30-100 | **PLACEHOLDER**: `kin.gd:420` plays `k_<theme>`; only 6 of 15 themes have a file (spore, gravity, venom, echo, lunar, prism = 18 of 50 Boki). The other **32 Boki** (stone, shadow, titan, ember, frost, bloom, swarm, storm, tempest) fall back to generic `skill` | Gap D (biggest single fix). The comment says six "types", but the 11-08 type table is 18 types and the key is `theme`, so the cue names are also stale (Gravity->Psychic, Lunar->Fairy, Prism->Crystal, Echo->Sound). |
| 10 | Boki hit / throw / recall / voice | 30-80 | **SHARED**: `kinhit`, `throw`, `recall`, `kin_happy/unsure/alert` for all 50 species | No per-species voice; a 2-note chirp per species (pitch + formant) would make the Boki recognisable by ear. |
| 11 | RMB / E ability cast + impact | 20-60 each | OWN x12 (all slots have a cast sound; impacts for most) | Placeholders inside kits: Cinder cloak blast (`shield` + `crit`), Albert (`click` ready-tick, `warn` ult interrupt), Sparkle (`ab_wall` stock on rod hit), Meeko (`knock` x3 for tosses/drops), Sable (`swipe`, `unlock`, `pay_cashin`, `click`), Vex ion needle end (`hero_skewer`), Tenzo (`glide` on hop-slam), Grimble (`warn`). |
| 12 | Pickups (loot, ammo, armor, keys, chests) | 15-40 | **SHARED**: one `pickup` for everything; Grimble/Meeko have own (`dredge_pickup`, `tend_pickup`). Keys have `key_get`, locked chests `lock_rattle` | Armor vs weapon vs ammo vs gem vs key all sound the same. 4-5 short rising/falling variants by category (loot value tier). Gap E. |
| 13 | Gloves (gear actives, 13 glove items) | 5-20 | **PLACEHOLDER**: `Effects`/`Verbs` pick by effect type (`whoosh`, `cloak`, `boom`, `zap`, `shield`, `ping`, `grab`, `thump`), pitch-shifted. Hook = `throw`, Vortex = `throw` | No glove has its own sound (Barrier, Blink, Mirror, Ice Bridge, Hook, Gust, Hover, Ledge, Fissure, Rocket, Vortex, Skyhook, Decoy). Gloves with no verb (Focus, Power, Cooling, Glider) are probably passives; not checked. Gap F. |
| 14 | Utility belt (tonic, armor kit, smoke, pad, scan, throwables) | 5-15 | **SHARED** (`heal`, `build`, `cloak`, `ping`, `throw`, `shield`, `pickup`) | Reasonable stand-ins; tonic drink and armor-kit repair deserve their own short sounds. |
| 15 | Ability-ready blip | 20-60 | Shared `ab_ready` (one per cooldown end, quiet) | Fine; but there is no **recast-window** cue (DECISIONS: "a short sound cue when it opens and a warning tick before it closes"). Grep finds none. Gap G. |
| 16 | Mob voices and attacks | 10-60 | OWN voice per kind (`v_skitter`, `v_spitter`, `v_brute`, `v_bomber`, `v_sentinel`, `v_glimmer`, `v_warden`); attacks reuse `k_spore`, `k_gravity`, `throw`, `boom` | Boss/mob attacks borrow Boki cue names; fine, but the Boki cue rename (Gap D) must keep these working. |
| 17 | Break/destroy props | 5-30 | OWN (`break_wood/clay/metal`, `fuse_hiss`, barrel `boom`) | OK. |
| 18 | Ultimate | 1-4 | OWN x12 (cast + impact + loop where held) | OK. Check Tenzo and Neve ult tails by ear. |
| 19 | Downed / revive / death | 1-5 | OWN x12 voices; revive loop `revive_hum`/`revive_done` | OK for Wardens. **Boki** versions exist as files (`boki_downed`, `boki_revive`, `boki_eat`, `boki_sleep`, `boki_fuse`, `boki_unfuse`) but **are never played**: `kin_downed.gd` and the fuse flow use `kin_unsure`, `heal`, `charge`, `armor_hit` instead. Wire them. Gap H. |
| 20 | Extraction (countdown, horn, boarding, hatch) | 2-6 | Mostly OK (`horn` x16 sites, `warn`, `portal`, `extract_ok`) | No countdown tick for the last seconds found in a grep. |
| 21 | Lair/boss events, Blight, rolling storm | 2-6 | Mixed: `horn`, `warn`, `boom`, `k_*` borrowed | Blight onset and storm front have no dedicated rumble; they reuse `v_skitter`/`k_echo`. |
| 22 | Farm (home): build, harvest, work, water, eat | 50+ at home | `build`, `plant`, `harvest`, `boki_work`, `splash`/`swim`/`drip` own; `unlock` reused ~55 times for any "good thing" (hob offers, shop buys, unlocks, level ups) | **`unlock` is the placeholder for ~half the farm UI reactions.** Eating/sleeping/petting a Boki: silent or `kin_happy`. |
| 23 | Swim / water in a match | rare | **None** in match code (`splash`/`swim` only in `home_water.gd`) | Add if any match map has swimmable water. |

## What is silent or a placeholder, in one list
No sound: low-HP warning; recast open/close; countdown ticks; match water; match weather and biome beds; per-glove actives for the 4 verb-less gloves; Boki eat/sleep/fuse/downed (files exist, unplayed).
Placeholder (shared stock reused): hit tick, jump/land, pickups, 13 gloves, 32 Boki casts, all Boki voices, utility items, `unlock` on the farm, the kit leftovers in row 11.

## Fix plan, in order (each is one small job; sounds are synthesised, no code redesign)
1. **Gap D** Boki cast cue: decide the key (theme, 15 values today, or the 18 types) and generate the 9 missing theme cues (stone, shadow, titan, ember, frost, bloom, swarm, storm, tempest) in `tools/gen_sfx_boki.py`; rename the 6 old ones if the key becomes the type. ~9-12 files, 1 line of lookup. Highest "heard per match x variety".
2. **Gap B** hit tick by class: light gun / heavy gun / blade / blunt / ability, plus a different tick when the target is armour/Boki/mob. ~6 files in `Juice`.
3. **Gap A** ambience: a biome bed per map and a rain/wind-gust layer in matches (`tools/gen_ambience.py`); distinct title-screen bed.
4. **Gap E** pickup variants by category (5 files).
5. **Gap F** glove sounds (13): Blink, Barrier, Hook, Rocket first.
6. **Gap C/G** low-HP pulse and recast-window open/close tick (3 files).
7. **Gap H** wire the existing Boki downed/revive/eat/sleep/fuse sounds (no new audio).
8. Weight-aware jump/land (4 files by `weight`), then the kit leftovers in row 11.

## Listening checklist for the owner (for the READY line)
In a Hollow Crown match with Vex: (1) walk across grass, stone, wood, snow; (2) shoot a Boki, a Warden and a wall, hearing whether the hit tick differs; (3) cast three different Boki and listen for the 32 that all say "skill"; (4) pick up armor, a gun and a key; (5) stand still 30 s for the ambience; (6) drop below 20% HP; (7) use any glove.
