# World sound coverage (outside the kits)

`--sfx-set-check` section 11 (`tools/sfx_world_cues.gd`) walks the cues of the world's systems listed in
`content/rules/sfx_world.json`: mobs and bosses, pickups and loot, gloves, utilities, the garden games and
the Ways Out (Heartspark, uplink outposts, quest seats). Every cue a system plays must be one of its own
sounds (a sound in the system's `content/sfx` sets) that exists; a shared stock sound (`pickup`, `thump`,
`zap`...) or a borrowed Boki `k_*` cue is a **hole**. The check prints every hole (`SFXSET hole <system>:
<file> <function>/<match arm>:<cue>`). The table's `holes` list is a ratchet: a hole it does not list
fails, and a listed hole that is gone fails too ("drop from sfx_world.json"), so the list only shrinks.
Gloves are walked from data as well: each active glove's effect blocks play the stock sound `Effects` plays
for that effect type unless the block names its own `"sfx"`.

Written 2026-11-11 on the 0.24.5 line (ext/release-integ-0245 272368589 + ext/sfx-kit-coverage 51e25e658).
Filled here: the uplink outposts (`exits.gd`: `uplink_start`, `uplink_steal`, `uplink_fizzle`,
`uplink_sputter`, `uplink_shut`, `uplink_lift`, `tools/gen_sfx_heart.py`, set `heart`) instead of
warn/zap/thump/unlock/portal, and the two Blight mob wind-ups (`v_bl_skitter`, `v_bl_warden`,
`tools/gen_sfx_blight_mobs.py`), which had no file and played nothing.

## Holes left (57), ranked by how often a player hears them

Per match is an estimate (no telemetry), as in the kit audit.

| # | Event | Per match (est.) | Status | Gap / fix |
|---|---|---|---|---|
| 1 | Pickups: chest open, box loot and take, pack stash/swap/wear, held-item swap/drop (`chest_loot`, `life take_item/loot_box`, `pack`, `loot_full`) | 15-40 | **SHARED** `pickup` x10; `lock_rattle` (pack full, locked chest), `key_get`, `unlock` | READY ext/sfx-pickups 0bb0bffab (set `pickups`: 5 pickup sounds by item category, PickupSfx). Merge it, then drop the rows it fixes. |
| 2 | Mob attacks: spitter spit, sentinel volley, bomber fuse, warden slam (`mob _strike/*`) | 10-60 | **BORROWED** `k_spore`, `throw`, `boom`, `k_gravity` | READY ext/sfx-mob-attacks ceb82b274 (set `mob`: `mob_<kind>_atk/_hit`). |
| 3 | Gloves: every effect-built glove's cast (`match use_gear:skill`), Blink's slash, Grapple and Shock bolts, Ward's cloak; the inline gloves gust_fan, platform, rocket, skyhook, hover | 5-20 | **SHARED** `skill`, `boom`, `throw`, `cloak`, `glide`, `shield`, `jump` | READY ext/sfx-gloves ae71a7811 (set `gloves`: 21 `gl_*` cues named in content/gear). |
| 4 | Utilities: drink, repair, mend, smoke, scan, pad, effect items, tonic and armour kit done (`utility_use`) | 5-15 | **SHARED** `pickup`, `build`, `heal`, `cloak`, `ping`, `skill`, `throw`, `shield` | READY ext/sfx-utilities-2 e06c2ce8c (set `belt`: a start and end cue per item); ext/sfx-utility-items-rebased 82befd1f0 is the older take: merge one. |
| 5 | Bosses (Colossus, Serpent, Brood): tells, slams, throws, dash, storm, spit, brood, burrow, phase-up (`boss *`) | 2-10 | **BORROWED** `v_warden`, `k_gravity`, `k_spore`, `zap`, `boom`, `whoosh`, `throw`, `die_small` | READY ext/sfx-mob-attacks covers `boss_<kind>_tell` and the boss strikes; what it leaves, it lists. |
| 6 | Uplink yard: lift pulse while open (`exits _tick_outpost/open`), a monster wave arriving (`exits _waves`) | 2-8 | **SHARED** `thump` | Own: a low pulse of the lift (`uplink_pulse`) and a wave arrival thud, in gen_sfx_heart.py. Cheap; left so this branch stays one change. |
| 7 | Heart wake / final gate (`heart _force`) | 1-2 | **SHARED** `portal` | HeartSfx already plays `heart_gate_open` on the same beat: check by ear whether the `portal` layer is wanted; if not, delete it (no new sound). |
| 8 | Blight tide tick (`heart _tide_tick`) | 2-6 | **SHARED** `thump` | READY ext/sfx-blight-front 79731c9cd (TideSfx: `tide_onset`, `tide_rumble`, `tide_warn`): when merged, the `thump` here can go. |
| 9 | Quest seat opens (`quest_seat _force`) | 1-3 | **SHARED** `horn` under `ways_open` | Same beat as `HeartSfx.call_out("open")`: by ear, then drop the `horn` or give the seat its own. |
| 10 | Sealed Lair reseals (`quest_seats _reseal`) | 0-1 | **SHARED** `boom` | Own gate-slam in gen_sfx_heart.py. |
| - | Garden games (race, shove, seek, volley, and the cue table in `garden_sfx.gd`) | - | OWN | 0 holes. |
| - | Mob wind-up voices (`v_<kind>` for every kind that attacks through `Mob`) | 10-60 | OWN | `v_bl_skitter`, `v_bl_warden` added here; bosses run their own attacks. |
