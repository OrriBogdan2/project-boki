# Solos vs trios pacing, 11-11 (owner 11-11: solos are back, 20 Hunters on a smaller play space, decision 0084)

Nobody had measured solo pacing. Ten real-paced bot-only expeditions on The Hollow Crown, seeds 1 to 5 in each mode: **solos** 20
squads of 1 (`--teams=20 --squad=1`, play space 118 m) and **trios** 10 squads of 3 (`--teams=10 --squad=3`, play space 160 m). Every
match runs at the game's own 1/60 s step with no shortcuts, to the island fall at 12:00. Tool: `godot --headless --path . --
--pacing-sim --map=hollowcrown --teams=N --squad=N --seed=N` (tools/pacing_sim.gd from ext/verify-expedition-pacing, unchanged).
Tables: `tools/pacing_report.py --compare solos docs/pacing_solos/solos?.log -- trios docs/pacing_solos/trios?.log` (new mode) and
`tools/pacing_report.py <logs>` (per run). Logs (the PACE lines): docs/pacing_solos/. Times are match seconds or m:ss from the drop.
**Measured only. No tuning was done in this job.**

**Tree:** origin/main (0.24.4) has neither Ways Out nor Solos. This branch is origin/main + `origin/ext/modes-solos-1111` 8b7f055fd
(which carries the 0.24.5 train `ext/release-integ-0245` 272368589) + `origin/ext/verify-expedition-pacing` 31db278ed (the tool).
The trios runs are re-measured on this tree rather than reused from docs/PACING_1111.md, because 0084's play space starts the trios
tide at 160 m, where PACING_1111 started it at 176 m. The caveats from PACING_1111 still apply: the XP rules are the old ones
(trickle + damage XP), and this is bots only.

**Definitions.** *First fight*: two numbers. The first is the median gap from a squad's landing to its first damage on anything
(camps), and the second is the first Hunter knocked by another Hunter. *Fights per minute*: Hunters out per minute over the first 4:00 (taken from the
30 s snapshots), plus Hunter-on-Hunter knocks per run. Raw knocks per minute would mislead: in trios a downed Hunter can be revived
and knocked again, while in solos a knock is the end. *Heart unlock*: the Heart wakes (ASLEEP>CHARGING), the spark is charged, and the
Heart's final exit opens. *Quest exits*: the Sealed Lair seat and the Uplink seat, opened and used. *Last team standing*: the first
time only one squad is left before the islands fall.

## Solos vs trios (median of 5 seeds each; a gap over 30% is flagged)
| measure | solos (median of 5) | trios (median of 5) | solos vs trios | flag |
|---|---|---|---|---|
| first damage after landing (median, s) | 1.53 | 1.85 | -17% |  |
| first Hunter knocked by a Hunter (s) | 29 | 38 | -24% |  |
| Hunter knocks a run | 17 | 37 | -54% | **over 30%** |
| Hunters out a minute, first 4:00 | 4.00 | 5.25 | -24% |  |
| share of the field out by 4:00 | 0.80 | 0.70 | +14% |  |
| camp clears a minute, first 4:00 | 3.00 | 3.25 | -8% |  |
| lair gate opens (s) | 86 (1 of 5 runs) | 78 (4 of 5 runs) | +11% |  |
| lair boss dies (s) | - (0 of 5 runs) | 228 (4 of 5 runs) | - |  |
| Heart wakes (s) | 240 | 240 | +0% |  |
| spark charged (s) | 315 | 315 | +0% |  |
| Heart final (s) | 600 | 484 | +24% |  |
| Sealed Lair seat opens (s) | 120 | 120 | +0% |  |
| Sealed Lair seat used (s) | - (0 of 5 runs) | 213 (1 of 5 runs) | - |  |
| Uplink seat opens (s) | 360 | 360 | +0% |  |
| Uplink seat used (s) | 400 (3 of 5 runs) | - (0 of 5 runs) | - |  |
| first extraction (s) | 432 (1 of 5 runs) | 272 (1 of 5 runs) | +59% | **over 30%** |
| half the squads out (s) | 76 | 149 | -49% | **over 30%** |
| one squad left (s), before the islands fall | 608 | 430 (3 of 5 runs) | +41% | **over 30%** |

## Where solos differ from trios by more than 30%
1. **The field halves twice as fast (76 s vs 149 s), but the last solo stands much later (10:08 vs 7:10 in the 3 trios runs that
   got there).** Solos lose 80% of the field by 4:00 (15-17 of 20 out) and trios lose 70% (17-23 of 30). After that the last
   2-5 solos hide out the 118 m ring and the closing tide, and one solo was left at 8:57-10:49 in every run. In trios, three runs got
   down to one squad (5:16, 7:10, 8:03) and two ended at 12:00 with two squads still in. Solo matches have a long, quiet back half.
2. **Hunter knocks per run: 17 vs 37 (-54%).** This follows from the mode: in solos a knock ends a Hunter, and the 1-6 who go out
   without a Hunter knock fell to the Blight, the abyss or mobs. Per Hunter it comes to 0.85 knocks in solos and 1.2 in trios. The
   rate that compares like for like, Hunters out a minute over the first 4:00, is 4.0 vs 5.25 (-24%, under the flag).
3. **First extraction: 7:11 vs 4:31 (+59%), but n = 1 in each mode.** Each mode had one extraction run: solos4 by Uplink, and trios1
   by the Sealed Lair seat. Both modes are mostly 0 extractions (the PACING_1111 gap 2: bots don't go for the ways out). Too few
   to read as a mode effect.
4. **"One squad left" is +41%** (row 1 again). Heart final opens at 10:00 or when one squad is left, so it moves with this row:
   10:00 vs 8:04 (+24%, under the flag).

## Differences under 30% or with no number, still worth knowing
- **No solo ever woke or killed a lair boss** (0 of 5). In trios, 4 of 5 runs killed one, at 2:36-4:58. In solos, one lair gate opened
  (solos3 at 1:26), and its boss never woke. Geometry is not the cause: the three lairs are 90-94 m from the Heart, so they are inside the
  118 m solos ring. The likely cause is that solos die before they get to it (80% out by 4:00), but this was not looked into further.
  The Sealed Lair seat follows the same pattern: solos 0 of 5 used it, trios 1 of 5.
- **Solos used the Uplink seat more** (3 of 5 runs took it to IN_USE, one run extracted) than trios (0 of 5).
- **The start is the same in both modes.** Landing 0:13-0:31, first damage after landing 1-2 s, first Hunter knock 0:26-0:42
  (solos) and 0:33-0:44 (trios), and the camps are cleared at the same rate (3.0 vs 3.25 a minute, 11-15 of 19 camps a run).
  Levels are also close: the median squad level at 2:00 is 4-5 in both, and 6-9 in solos vs 5.7-7 in trios at 4:00.
- **The tide.** In solos it holds at 118 m from 0:00 until the closing ring passes it (about 5:40), then follows the same ring as
  trios (112 / 80 / 48 m at 6:00 / 8:00 / 10:00). In trios it starts at 160 m and is at 144 m by 4:00. For the first 5 minutes
  solos have about half the area of trios (118² vs 160² ≈ 0.54) for two thirds of the Hunters. Each Hunter in solos gets about 0.8×
  the area a trios Hunter gets, so solos are only slightly more crowded.
- **The Heart clock is fixed and identical**: wakes 4:00, spark charged 5:15, Sealed Lair seat 2:00-5:30, Uplink seat 6:00-8:00. No
  Hunter carried the spark in either mode.

## Per run
| run | landed (first-last) | first damage after landing (median/worst) | first knock | first camp clear | 5th | camps cleared | L2 | L3 | L4 | L6 |
|---|---|---|---|---|---|---|---|---|---|---|
| solos1 | 0:16-0:30 | 2 s / 26 s | 0:42 | 0:25 | 0:40 | 15/19 | 0:24 | 0:34 | 0:44 | 1:04 |
| solos2 | 0:15-0:31 | 2 s / 22 s | 0:39 | 0:22 | 0:52 | 12/19 | 0:23 | 0:36 | 0:39 | 1:18 |
| solos3 | 0:19-0:30 | 1 s / 9 s | 0:29 | 0:25 | 0:49 | 12/19 | 0:28 | 0:29 | 0:50 | 1:47 |
| solos4 | 0:16-0:31 | 1 s / 12 s | 0:26 | 0:24 | 0:43 | 13/19 | 0:23 | 0:26 | 0:47 | 1:13 |
| solos5 | 0:16-0:30 | 2 s / 11 s | 0:28 | 0:29 | 0:37 | 13/19 | 0:23 | 0:28 | 0:41 | 0:59 |
| trios1 | 0:13-0:30 | 2 s / 18 s | 0:40 | 0:18 | 0:33 | 14/19 | 0:24 | 0:33 | 0:43 | 1:39 |
| trios2 | 0:14-0:30 | 2 s / 17 s | 0:44 | 0:28 | 0:46 | 15/19 | 0:29 | 0:37 | 0:57 | 1:21 |
| trios3 | 0:17-0:30 | 1 s / 6 s | 0:36 | 0:26 | 0:40 | 13/19 | 0:26 | 0:36 | 0:44 | 1:03 |
| trios4 | 0:13-0:30 | 2 s / 12 s | 0:38 | 0:18 | 0:40 | 14/19 | 0:20 | 0:35 | 0:50 | 1:31 |
| trios5 | 0:15-0:30 | 2 s / 6 s | 0:33 | 0:27 | 0:37 | 11/19 | 0:25 | 0:30 | 0:33 | 1:04 |

| run | squads' mean level at 2:00 (min/med/max, squads still in) | 4:00 | 5:15 | 8:00 | 10:00 |
|---|---|---|---|---|---|
| solos1 | 4.0 / 5.0 / 5.0 | 6.0 / 6.0 / 8.0 | 7.0 / 7.5 / 8.0 | 10.0 / 10.0 / 10.0 | 10.0 / 10.0 / 10.0 |
| solos2 | 3.0 / 4.0 / 6.0 | 5.0 / 6.5 / 8.0 | 6.0 / 7.0 / 8.0 | 9.0 / 9.0 / 10.0 | 10.0 / 10.0 / 10.0 |
| solos3 | 3.0 / 4.0 / 6.0 | 5.0 / 6.0 / 8.0 | 6.0 / 7.0 / 8.0 | 8.0 / 10.0 / 10.0 | 10.0 / 10.0 / 10.0 |
| solos4 | 4.0 / 5.0 / 6.0 | 5.0 / 7.0 / 8.0 | 6.0 / 7.0 / 9.0 | 8.0 / 9.0 / 10.0 | 8.0 / 9.0 / 10.0 |
| solos5 | 4.0 / 5.0 / 7.0 | 7.0 / 9.0 / 9.0 | 8.0 / 9.0 / 10.0 | 10.0 / 10.0 / 10.0 | 10.0 / 10.0 / 10.0 |
| trios1 | 3.7 / 4.7 / 5.0 | 5.0 / 7.0 / 8.0 | 5.3 / 7.8 / 8.3 | 6.7 / 8.7 / 9.3 | 6.7 / 9.0 / 9.7 |
| trios2 | 2.7 / 4.3 / 5.3 | 5.3 / 7.0 / 7.3 | 6.7 / 7.7 / 8.3 | 9.0 / 9.3 / 9.7 | 9.7 / 9.7 / 9.7 |
| trios3 | 3.0 / 4.3 / 5.7 | 5.3 / 6.7 / 7.0 | 6.0 / 7.0 / 7.7 | 7.3 / 9.0 / 9.0 | 8.0 / 9.7 / 10.0 |
| trios4 | 3.0 / 4.2 / 5.0 | 5.3 / 5.7 / 6.7 | 7.3 / 7.3 / 7.3 | 9.3 / 9.3 / 9.3 | 9.7 / 9.7 / 9.7 |
| trios5 | 5.0 / 5.3 / 5.7 | 7.0 / 7.0 / 7.0 | 8.0 / 8.7 / 9.3 | 10.0 / 10.0 / 10.0 | 10.0 / 10.0 / 10.0 |

| run | tide radius m at 2:00 / 4:00 / 6:00 / 8:00 / 10:00 | lair gate opens | boss awake | boss dies | Heart wakes | spark charged | Heart final | squads left <=5 / <=3 / 1 | ended |
|---|---|---|---|---|---|---|---|---|---|
| solos1 | 118 / 118 / 112 / 80 / 48 | - | - | - | 4:00 | 5:15 | 10:00 | 3:15 / 5:15 / 10:49 | t 720.5 result { "extracted": false, "why": "team wiped", "ending": tr |
| solos2 | 118 / 118 / 112 / 80 / 48 | - | - | - | 4:00 | 5:15 | 10:00 | 2:46 / 4:10 / 10:08 | t 720.5 result { "extracted": false, "why": "team wiped", "ending": tr |
| solos3 | 118 / 118 / 112 / 80 / 48 | 1:26 | - | - | 4:00 | 5:15 | 8:56 | 2:17 / 3:02 / 8:57 | t 720.5 result { "extracted": false, "why": "team wiped", "ending": tr |
| solos4 | 118 / 118 / 112 / 80 / 48 | - | - | - | 4:00 | 5:15 | 10:00 | 3:46 / 7:12 / 10:19 | t 720.5 result { "extracted": false, "why": "team wiped", "ending": tr |
| solos5 | 118 / 118 / 112 / 80 / 48 | - | - | - | 4:00 | 5:15 | 9:12 | 2:38 / 3:57 / 9:12 | t 720.5 result { "extracted": false, "why": "team wiped", "ending": tr |
| trios1 | 160 / 144 / 112 / 80 / 48 | 1:44 | 1:44 | 2:36, 4:30 | 4:00 | 5:15 | 10:00 | 3:12 / 6:17 / 12:00 | t 720.5 result { "extracted": false, "why": "team wiped", "ending": tr |
| trios2 | 160 / 144 / 112 / 80 / 48 | 1:32 | 4:35 | 4:58 | 4:00 | 5:15 | 8:03 | 3:01 / 3:42 / 8:03 | t 720.5 result { "extracted": false, "why": "abyss", "ending": true }  |
| trios3 | 160 / 144 / 112 / 80 / 48 | - | - | - | 4:00 | 5:15 | 10:00 | 2:08 / 2:57 / 12:00 | t 720.5 result { "extracted": false, "why": "finished", "ending": true |
| trios4 | 160 / 144 / 112 / 80 / 48 | 1:02 | 1:10 | 3:23 | 4:00 | 5:15 | 7:09 | 2:28 / 4:24 / 7:10 | t 720.5 result { "extracted": false, "why": "executed", "ending": true |
| trios5 | 160 / 144 / 112 / 80 / 48 | 0:56 | 1:33 | 4:12 | 4:00 | 5:15 | 5:16 | 1:44 / 2:01 / 5:16 | t 720.5 result { "extracted": false, "why": "finished", "ending": true |

- solos1 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 10:00 READY>FINAL
- solos2 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 6:40 IN_USE 6:59 OPEN 7:34 IN_USE 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 10:00 READY>FINAL
- solos3 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 8:56 READY>FINAL
- solos4 extractions: 7:11 b15 t15; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 6:08 IN_USE 7:04 TAKEN; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 10:00 READY>FINAL
- solos5 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 6:43 IN_USE 7:18 OPEN 7:30 IN_USE 7:33 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 9:12 READY>FINAL
- trios1 extractions: 4:31 b11 t3; Sealed Lair seat 2:00 OPEN 3:32 IN_USE 4:30 TAKEN; Uplink seat 6:00 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 10:00 READY>FINAL
- trios2 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 8:03 READY>FINAL
- trios3 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 10:00 READY>FINAL
- trios4 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 7:09 READY>FINAL
- trios5 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 5:16 READY>FINAL

## Not covered
Human players, other maps (Skyreach has its own play_space), the new XP rules (not on this tree), and online matches. Five seeds
per mode is enough for the large gaps above. It is not enough for the small ones, or for any measure that only 1 of 5 runs reached.
