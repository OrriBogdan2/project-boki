# ElevenLabs sound-effects pilot (11-10)

A trial of AI-generated sound effects next to the synthesised ones (docs/AUDIO.md). `tools/gen_sfx_el.py` sends each prompt to the ElevenLabs sound-generation API (`eleven_text_to_sound_v3`, a fixed duration per take), trims the clip and levels it to the sound's category in `content/rules/sfx_levels.json`, then writes `audio/<name>.wav` + `<name>_1..n.wav` under the names the game already loads. No loader change.

## Budget
- The API key can't read the balance (no `user_read`), so the cost is counted here, not read.
- Rate: 40 credits per second of requested duration (ElevenLabs sound-effects docs, duration set on every request).
- Hard cap: 3,000 credits. The script logs each request below before sending it, refuses one that would pass the cap, and stops at the first 401/402/429 or quota error.

## What was made (2,816 credits)
Prompts, categories and take counts are `PLAN` in `tools/gen_sfx_el.py`. A/B page: `/home/boki/art-review/sfx-1110/index.html` (old synthesised vs new, per take).
- **Dodge (new, wired):** `dodge` + 3 takes (category dash). `Match.on_perfect_dodge` played the pitched-up `dash`; it now plays `dodge`. The "miss" side is the same moment (a shot passing through the dash), so it is one sound. It is listed in `content/sfx/combat.json` (shared combat sounds), so `--sfx-set-check` covers its file and level.
- **Archer (Hem), the thinnest kit:** every kit sound except `pin_patter` (0.12 s, under the API's 0.5 s minimum): the bow (`pin_loose`, `pin_loose_super`, `pin_draw`, `pin_stage`, `pin_perfect`, `pin_super`, `pin_overdraw`), Heavy Shot (`pin_heavy_draw`, `pin_heavy`, `pin_heavy_hit`), `pin_super_hit`, Hail Wall (`pin_hail`, `pin_rain`), Spirit Walk (`pin_spirit`, `pin_spirit_end`), Starpiercer (`pin_ult_cast`, `pin_ult_nock`, `pin_ult_beam`, `pin_ult_final`) and the signature `archer_thread_twang`.
- **Kael (juggernaut) chain / drop / ult:** `jug_chain`, `juggernaut_chain_bite`, `jug_taut`, `jug_reel`, `juggernaut_chain_rattle`, `jug_drop`, `jug_meteor`, `jug_guard`, `jug_riposte`, `jug_ting`.
- **The other kits' main weapon:** `bjorn_throw`, `br_throw`, `dr_shot`, `vn_rifle`, `vv_bolt`, `os_orb`, `rime_shard`, `tend_ember`, `dj_bolt`, `lw_roar`.
- **Frequent impacts:** `rimewright_dart_hit`, `dj_encore_hit`, `br_boulder_hit`, `bjorn_block`.

Every replaced sound keeps its name and take count, so no loader, set or kit change was needed and no stale take is left behind.

## Not done
- `pin_patter` (one arrow of the Hail Wall rain, 0.12 s): planned in `PLAN` with a 0.2 s trim cap (the API's minimum request is 0.5 s), 4 takes = 80 credits, which would bring the tally to 2,896. The 11-11 follow-up ran on worker w2, which has no API key, so nothing was sent. To make it, run `python3 tools/gen_sfx_el.py pin_patter` on hetzner.
- The A/B page was rebuilt on w2 from git (old = origin/main, new = this branch), at the same path. The raw clip cache (`RAW`) is on hetzner only.

## Notes
- About 1 clip in 13 came back silent or near-silent. Those were counted, set aside in `raw/rejected` and re-rolled; `build` now skips any clip under 1% peak.
- The model tends to make short, fast-decaying sounds. The trim keeps the tail until its 20 ms RMS is 40 dB down, so several new sounds are shorter than the old ones (`archer_thread_twang` base 0.19 s vs 0.55 s). The ult sounds and `jug_guard` were re-rolled once with "rings out" prompts.
- `jug_riposte` starts with 0.096 s of silence (`LEAD` in `tools/gen_sfx_el.py`) so its onset lands at the cleave's strike_t (0.1 s), the timing main gave the synthesised one (Kael ult commit ef783455b). The take has no sub-ms edge like the synth's; the A/B page is where to judge that.
- Rerunning a group's synth script (`gen_sfx_lisette.py`, `gen_sfx_kael.py`...) overwrites these files; rerun `gen_sfx_el.py --relevel <names>` afterwards to restore them from the cached clips.
- Licence: generated on the owner's ElevenLabs plan (docs/CREDITS.md), not CC0. AUDIO.md's CC0-only rule has an exception for this pilot.

## Credit tally
Every request, in order. `credits` = seconds x 40; `total` = running sum.

| # | clip | seconds | credits | total | note |
|---|---|---|---|---|---|
| 1 | dodge | 0.60 s | 24 | 24 | sent |
| 2 | dodge_1 | 0.60 s | 24 | 48 | sent |
| 3 | dodge_2 | 0.60 s | 24 | 72 | sent |
| 4 | dodge_3 | 0.60 s | 24 | 96 | sent |
| 5 | pin_loose | 0.50 s | 20 | 116 | sent |
| 6 | pin_loose_1 | 0.50 s | 20 | 136 | sent |
| 7 | pin_loose_2 | 0.50 s | 20 | 156 | sent |
| 8 | pin_loose_3 | 0.50 s | 20 | 176 | sent |
| 9 | pin_loose_super | 0.80 s | 32 | 208 | sent |
| 10 | pin_draw | 0.60 s | 24 | 232 | sent |
| 11 | pin_heavy_draw | 0.90 s | 36 | 268 | sent |
| 12 | pin_stage | 0.50 s | 20 | 288 | sent |
| 13 | pin_perfect | 0.80 s | 32 | 320 | sent |
| 14 | pin_super | 0.80 s | 32 | 352 | sent |
| 15 | pin_overdraw | 0.50 s | 20 | 372 | sent |
| 16 | pin_heavy | 0.70 s | 28 | 400 | sent |
| 17 | pin_heavy_hit | 0.50 s | 20 | 420 | sent |
| 18 | pin_heavy_hit_1 | 0.50 s | 20 | 440 | sent |
| 19 | pin_heavy_hit_2 | 0.50 s | 20 | 460 | sent |
| 20 | pin_heavy_hit_3 | 0.50 s | 20 | 480 | sent |
| 21 | pin_super_hit | 0.70 s | 28 | 508 | sent |
| 22 | pin_super_hit_1 | 0.70 s | 28 | 536 | sent |
| 23 | pin_super_hit_2 | 0.70 s | 28 | 564 | sent |
| 24 | pin_hail | 0.80 s | 32 | 596 | sent |
| 25 | pin_rain | 1.10 s | 44 | 640 | sent |
| 26 | pin_spirit | 0.90 s | 36 | 676 | sent |
| 27 | pin_spirit_end | 0.70 s | 28 | 704 | sent |
| 28 | pin_ult_cast | 1.00 s | 40 | 744 | sent |
| 29 | pin_ult_nock | 0.50 s | 20 | 764 | sent |
| 30 | pin_ult_beam | 0.80 s | 32 | 796 | sent |
| 31 | pin_ult_final | 1.30 s | 52 | 848 | sent |
| 32 | archer_thread_twang | 0.55 s | 22 | 870 | sent |
| 33 | archer_thread_twang_1 | 0.55 s | 22 | 892 | sent |
| 34 | archer_thread_twang_2 | 0.55 s | 22 | 914 | sent |
| 35 | archer_thread_twang_3 | 0.55 s | 22 | 936 | sent |
| 36 | jug_chain | 0.60 s | 24 | 960 | sent |
| 37 | juggernaut_chain_bite | 0.50 s | 20 | 980 | sent |
| 38 | jug_taut | 0.50 s | 20 | 1000 | sent |
| 39 | jug_reel | 0.60 s | 24 | 1024 | sent |
| 40 | juggernaut_chain_rattle | 0.60 s | 24 | 1048 | sent |
| 41 | juggernaut_chain_rattle_1 | 0.60 s | 24 | 1072 | sent |
| 42 | juggernaut_chain_rattle_2 | 0.60 s | 24 | 1096 | sent |
| 43 | jug_drop | 0.50 s | 20 | 1116 | sent |
| 44 | jug_meteor | 1.40 s | 56 | 1172 | sent |
| 45 | jug_guard | 0.75 s | 30 | 1202 | sent |
| 46 | jug_riposte | 0.75 s | 30 | 1232 | sent |
| 47 | jug_ting | 0.50 s | 20 | 1252 | sent |
| 48 | jug_ting_1 | 0.50 s | 20 | 1272 | sent |
| 49 | jug_ting_2 | 0.50 s | 20 | 1292 | sent |
| 50 | pin_draw | 0.60 s | 24 | 1316 | sent |
| 51 | pin_spirit_end | 0.70 s | 28 | 1344 | sent |
| 52 | bjorn_throw | 0.50 s | 20 | 1364 | sent |
| 53 | bjorn_throw_1 | 0.50 s | 20 | 1384 | sent |
| 54 | bjorn_throw_2 | 0.50 s | 20 | 1404 | sent |
| 55 | bjorn_throw_3 | 0.50 s | 20 | 1424 | sent |
| 56 | br_throw | 0.50 s | 20 | 1444 | sent |
| 57 | br_throw_1 | 0.50 s | 20 | 1464 | sent |
| 58 | br_throw_2 | 0.50 s | 20 | 1484 | sent |
| 59 | br_throw_3 | 0.50 s | 20 | 1504 | sent |
| 60 | dr_shot | 0.75 s | 30 | 1534 | sent |
| 61 | dr_shot_1 | 0.75 s | 30 | 1564 | sent |
| 62 | dr_shot_2 | 0.75 s | 30 | 1594 | sent |
| 63 | dr_shot_3 | 0.75 s | 30 | 1624 | sent |
| 64 | vn_rifle | 0.50 s | 20 | 1644 | sent |
| 65 | vn_rifle_1 | 0.50 s | 20 | 1664 | sent |
| 66 | vn_rifle_2 | 0.50 s | 20 | 1684 | sent |
| 67 | vn_rifle_3 | 0.50 s | 20 | 1704 | sent |
| 68 | vv_bolt | 0.50 s | 20 | 1724 | sent |
| 69 | vv_bolt_1 | 0.50 s | 20 | 1744 | sent |
| 70 | vv_bolt_2 | 0.50 s | 20 | 1764 | sent |
| 71 | vv_bolt_3 | 0.50 s | 20 | 1784 | sent |
| 72 | os_orb | 0.50 s | 20 | 1804 | sent |
| 73 | os_orb_1 | 0.50 s | 20 | 1824 | sent |
| 74 | os_orb_2 | 0.50 s | 20 | 1844 | sent |
| 75 | os_orb_3 | 0.50 s | 20 | 1864 | sent |
| 76 | rime_shard | 0.50 s | 20 | 1884 | sent |
| 77 | rime_shard_1 | 0.50 s | 20 | 1904 | sent |
| 78 | rime_shard_2 | 0.50 s | 20 | 1924 | sent |
| 79 | rime_shard_3 | 0.50 s | 20 | 1944 | sent |
| 80 | tend_ember | 0.50 s | 20 | 1964 | sent |
| 81 | tend_ember_1 | 0.50 s | 20 | 1984 | sent |
| 82 | tend_ember_2 | 0.50 s | 20 | 2004 | sent |
| 83 | tend_ember_3 | 0.50 s | 20 | 2024 | sent |
| 84 | dj_bolt | 0.60 s | 24 | 2048 | sent |
| 85 | dj_bolt_1 | 0.60 s | 24 | 2072 | sent |
| 86 | dj_bolt_2 | 0.60 s | 24 | 2096 | sent |
| 87 | dj_bolt_3 | 0.60 s | 24 | 2120 | sent |
| 88 | lw_roar | 0.66 s | 26 | 2146 | sent |
| 89 | lw_roar_1 | 0.66 s | 26 | 2172 | sent |
| 90 | lw_roar_2 | 0.66 s | 26 | 2198 | sent |
| 91 | lw_roar_3 | 0.66 s | 26 | 2224 | sent |
| 92 | pin_loose_1 | 0.50 s | 20 | 2244 | sent |
| 93 | pin_loose_3 | 0.50 s | 20 | 2264 | sent |
| 94 | vv_bolt | 0.50 s | 20 | 2284 | sent |
| 95 | tend_ember_3 | 0.50 s | 20 | 2304 | sent |
| 96 | archer_thread_twang | 0.55 s | 22 | 2326 | sent |
| 97 | pin_ult_cast | 1.00 s | 40 | 2366 | sent |
| 98 | pin_ult_final | 1.30 s | 52 | 2418 | sent |
| 99 | jug_guard | 0.75 s | 30 | 2448 | sent |
| 100 | rimewright_dart_hit | 0.50 s | 20 | 2468 | sent |
| 101 | rimewright_dart_hit_1 | 0.50 s | 20 | 2488 | sent |
| 102 | rimewright_dart_hit_2 | 0.50 s | 20 | 2508 | sent |
| 103 | rimewright_dart_hit_3 | 0.50 s | 20 | 2528 | sent |
| 104 | dj_encore_hit | 0.50 s | 20 | 2548 | sent |
| 105 | dj_encore_hit_1 | 0.50 s | 20 | 2568 | sent |
| 106 | dj_encore_hit_2 | 0.50 s | 20 | 2588 | sent |
| 107 | dj_encore_hit_3 | 0.50 s | 20 | 2608 | sent |
| 108 | br_boulder_hit | 0.80 s | 32 | 2640 | sent |
| 109 | br_boulder_hit_1 | 0.80 s | 32 | 2672 | sent |
| 110 | br_boulder_hit_2 | 0.80 s | 32 | 2704 | sent |
| 111 | br_boulder_hit_3 | 0.80 s | 32 | 2736 | sent |
| 112 | bjorn_block | 0.50 s | 20 | 2756 | sent |
| 113 | bjorn_block_1 | 0.50 s | 20 | 2776 | sent |
| 114 | bjorn_block_2 | 0.50 s | 20 | 2796 | sent |
| 115 | bjorn_block_3 | 0.50 s | 20 | 2816 | sent |
