# Early camps and the bigger drop (0.24.4 gate, ext/early-camps-0244)

Spec: `briefs/specs/EARLY_CAMPS_DROP.md` on `origin/ext/spec-early-camps`. Decisions: [0048](decisions/0048-camps-and-xp.md) (camps, XP), [0049](decisions/0049-drop-height.md) (the drop), [0050](decisions/0050-hard-landing.md) (Hard Landing). Map: [MAP_2X.md](MAP_2X.md), [MAP_REGIONS.md](MAP_REGIONS.md).
Gate job 20261111-093019-a1 (rpc4). Base `origin/ext/early-base` 0f023137a, which already held `ext/early-camps-core`, `-layout`, `-drop-height`, `-hard-landing` and `-camps-map-ui` (the merges were no-ops).

## What is in
- **Camps** (`scripts/match/camps.gd`, `content/rules/camps.json`): 28 camps on the 2x Hollow Crown (12 Small, 9 Camp, 7 Great, 79 monsters), one size up in the hot zone. One bundle on the last kill, to the squad that lands it; one comeback, one size up. Replaces `Match._spawn_mobs` and the rolling copy.
- **XP is a kill reward** (`content/rules/xp.json`, `XpRules`): no passive XP, no level XP for damage (Hunter damage still builds armor), each monster pays on its death to the last hit's squad and squadmates within 30 m (a stealer takes it), knock 40 + 15 x the victim's level.
- **Camps on the maps**: drop map region lines ("N camps: to level L"), hot-zone line, legend row, minimap icons, cleared and returning states, smoke columns from the air, first-match guide lines.
- **The drop**: 110 m ship, faster dive you hold, dive view, cloud layer, wind streaks, team ribbons, soft landing without rings.
- **Hard Landing**: the dive key held to the ground staggers and hurts monsters in 6 m (never Hunters), ring, dust, debris, crack, boom.

## Numbers as shipped
| Thing | Value | File |
|---|---|---|
| Small / Camp / Great / Chief | 2 / 3 / 4 / 4 monsters; armor 25 / 50 / 50 / 50; perk orb 0 / 50% / always / always; Great gear +0, Chief gear +1 rarity | `camps.json` |
| Monster XP | Skitter, Puffbomb, Spitter 30; Sentinel 50; Brute 100; Chief's Brute 170; stray 8 | `xp.json` |
| Camp XP (sum) | Small 60, Camp 110, Great 190, Chief 260 | derived |
| First clear per region | rim 230, mid 360, Crown 680 | derived |
| Share radius, knock | 30 m; 40 + 15 x level | `xp.json` |
| Comeback | 150 s after the clear, one size up, nobody within 30 m, safe for 60 s, none after 7:00 (420 s), 85 camp monsters at most | `camps.json` |
| Ship | 110 m high, 14 m/s, plan phase 12 s | `drop.json` |
| Launch | 18 m/s, lift 8 m/s, locked 2.5 s | `drop.json` |
| Dive / canopy | fall 20 / 5 m/s, flat 16 / 9 m/s, canopy opens at 10 m | `drop.json` |
| Hard Landing | 6 m radius, 30 damage, 1.5 s stagger, you are slowed 0.4 s, heard to 60 m, bots take it half the time onto a live camp | `drop.json` |
| Dive view / cloud | FOV +10 deg over 0.4 s, tilt 12 deg; cloud sheet at 60 m, 0.3 s haze | `drop.json` |

Owner calls built as the spec defaults: 110 m ship, Hard Landing hits monsters only.

## Checks (final commit, headless, one godot at a time, 4 in parallel for the sweep)
| Check | Result |
|---|---|
| Full suite: 226 registered `-check` flags (all but bench/shots/gallery/perf-budget) | 213 green; 13 red on the first pass, see below |
| `python3 tools/health.py --strict` | HEALTH OK, STYLE OK |
| `--check` | 0 failures |
| `--camps-check` | 0 failures |
| `--camp-layout-check` | pass |
| `--camp-map-check` | pass |
| `--camp-pace-check` | **does not exist**: it belongs to the bots task (`ext/early-camps-bots`), which is not on origin; no pace table |
| `--drop-feel-check` | pass (also on a GPU, below) |
| `--drop-launch-check` | pass |
| `--hot-zone-check` | pass |
| `--perf-budget-check --quality=low` (headless, worker under load) | draws 0 (headless), shadow lights 1, **frame ms FAIL** (worst 75 against 50): the known worker-load red in DEBT (`d97cf5ece`) |
| `--simtest --teams=10 --squad=3 --god` | ran to the end, rc 0, 0 script errors |

The 13 reds of the sweep:
- **Pre-existing** (red on the release candidate before any camp work, or listed red in `docs/INTEG_0244.md`): `--boki-hit-table-check` (Ashwick on a summoned Boki; red on the pre-camp tree e30b77695 too), `--online-displace-check` (Kael sling, red on e30b77695 too), `--grammar-runtime-check`, `--hitch-check`, `--load-trim-check`, `--load-check`, `--merge-form-check`, `--pack-ui-check`, `--rate-card-check` (rc 134 at exit), `--stretch-check`, `--ttk-check`.
- **Flaky under load**: `--toy-check` (green on rerun).
- **New, not fixed: `--bot-sanity-check`, seed 3.** One 5 s window of one bot has 15 facing flips (limit 14) on a glide crossing at about 1:08. Green on every branch alone (camps-core, layout, drop-height, hard-landing) and on the merge of core and layout (01989d37e); red from the merge `76bb4c856` (early-base into camps-map-ui), so it needs the map-ui side (camps in the spawn plan, smoke, guide) together with the layout and the Hard Landing line. Most likely a butterfly of the bots' drop picks, not a logic bug, but it was not proved. Left red.

## GPU runs (jobq, `--needs gpu`)
GPU workers restarted under most jobs for hours ("lost after 3 attempts"); results below are from the runs that completed.

`--perf-bench` (60 s busy expedition, 1920x1080, medium quality, RTX 4070 SUPER on pc-MRROBOTO, the same worker for both runs; a first base run on an Apple M5 is not comparable and is not used):

| | `ext/early-base` 0f023137a | this branch | Limit | Result |
|---|---|---|---|---|
| Match average frame | 26.8 ms | 26.3 ms | within +0.5 ms | pass (-0.5) |
| Match p99 | 53.0 ms | 48.2 ms | within +3 ms | pass (-4.8) |
| Draw calls | 933 | 856 | under 1,500 | pass |
| Emitting particle nodes | 76 | 72 | | the bench has no Hard Landing |
| Hitches over 100 ms | 0 | 1 (166 ms at 2.5 s: the first hero effect build, nothing from the drop) | | noise, not a regression |

Three squads Hard Landing in view: `--drop-feel-check` on a GPU (Apple M5, mac-Naruto-Founder, medium quality, job 20261111-103559-06704): 9 Hard Landings in one second, **252 particles at most (under 4,000), worst frame 13.3 ms (limit 50; 11.9 ms the second before)**. `--perf-bench` itself has no landing scenario, so this check is the "no frame over 50 ms" gate.


## Shots
`jobq submit --needs gpu -- --region-shots --shots-dir=shots` (RTX 4070 SUPER, pc-MRROBOTO), saved as JPEG under `docs/shots/early-camps-0244/`:
- `drop_map.jpg`: the drop map with the 28 camps, the region lines ("N camps: to level L"), the hot zone's ring and legend row.
- `dive_smoke.jpg`: mid-dive above the cloud layer (the sheet at 60 m) with the camps' smoke columns, orange in the hot zone.
- `hard_landing.jpg`: a Hard Landing on the hot zone's camp: the 6 m ring, the Puffbomb and Brute hit for 30.
- `minimap_cleared.png` (the minimap beside a cleared camp): **not saved.** The two runs that completed showed the full map open over the HUD, because the tool called `open_map(false)` (which opens it) where it needed `close_map()`. That is fixed in `tools/region_shots.gd` but the fix is unverified: the rerun sat in the GPU queue for over an hour. Run `jobq submit --needs gpu --tree <tree> --out shots -- --region-shots --shots-dir=shots` and copy `minimap_cleared.png` over.


## Pace table
Not produced: `--camp-pace-check` and the bots-by-level and levels-core work (pace curve, catch-up bonuses, the XP bar, level on nameplates, 300 boss pay) are not in this branch. `ext/early-levels-core`, `ext/early-camps-bots` are not on origin. The XP bar (`ext/ui-xp-tracker`) and the level gap badge (`ext/ui-level-gap`) are separate READY branches, not merged here. So the spec's pace targets (section 2.5, level 4 at 2:00 and so on) are untested.

## Zone spec comparison (section 2.10)
Against the latest Blight zone spec on origin, `LIMITED_WAY_OUTS.md` rev 2 (`origin/ext/spec-ways-out-zone` 31c118f4f, five beats 2:00 to 10:00, circle 1 at 136 m). Checked on the real camp coordinates in `content/maps/hollowcrown.json` for each of the three Sealed Lair picks (84 camp and pick pairs), the wall closing linearly as the spec says, circle 3's centre taken on the Heart (it leans 14 m at most):
- **Rim**: first covered 2:10 (130 s), no camp before 1:45. Holds.
- **Crown**: first covered 10:16, last. Holds.
- **Mid: does not hold for 5 of 84 pairs.** The spec said "no mid camp before 4:00" and read it off island clocks (4:10 to 6:20). The mid regions' Small Camps and one Camp sit on their islands' outer edges: Frostgate's Small Camp is covered at **2:48** (forge or hive lair), Thornwood's Small Camp at 2:56 (eyrie), Stormbreak's Small Camp at 2:56 (forge), Frostgate's Camp at 2:59 (hive). Wall shrinks during beat 1 (2:00 to 3:00) before they could be farmed fully.
- The two clock numbers that would move: **2:48 (earliest mid camp covered) against the 4:00 rule**. To meet 4:00 the zone's first beat would have to start at about 3:12, or circle 1 would have to be about 150 m instead of 136 m on the lean-away side. Nothing was changed. `Camps.safe_for` still answers from the match length until the zone lands, and then blocks those comebacks.

## Left out
- Everything above under Pace table.
- Net clients have no camp list (`Camps.spawn_all` returns early for non-hosts), so they see no camp markers or smoke (DEBT).
- Later `[early]` tasks of the spec (boss boon, wisp refund, guarded Boki, camp dressing, results screen).
