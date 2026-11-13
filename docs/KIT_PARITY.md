# Kit parity audit: 12 Hunters against the source (main 7907d9afe, 2026-11-07; re-audit on ext/release-integ-0244c 23cc281bd, 2026-11-11)

**Refresh 2026-11-09 (main d255acbee):** the Vex, Kael, Lace, Cinder, Meeko and Tenzo tables below were re-checked row by row against main and use the canon display names (briefs/DECISIONS.md, ids unchanged). A closed gap names the commit that closed it; `pending ext/<branch>` is a READY branch not yet on main that would close or move the row. The other six tables and the top-20 list below are still the 7907d9afe text and use the old names.

PARITY FIRST audit (briefs/DECISIONS.md 2026-11-07, briefs/PRIORITIES.md step 2). Read-only: no game code changed.
PARITY FIRST audit (briefs/DECISIONS.md 2026-11-07, briefs/PRIORITIES.md step 2). Read-only for the first audit; the ranges table below changed four numbers (data only).

## 0.24.5 verify: Meeko, Tenzo, Grimble, Neve, Motley, Albert, Sparkle, Sable (ext/release-integ-0245 92df78ce4, 2026-11-11)

Each row was read against `content/archetypes/*.json` and the kit code on the 0.24.5 line. **No row regressed**: every `done ... (main)` row above still holds (Meeko Carrier shield gone, drop lock 4 s; Tenzo ally hop; Grimble air slot 12.5 s; Neve Chill 4 s with no slow, late dart homing; Motley bomb 3.5x; Albert throw rate 0.45, E zone 2.3 m, aegis block rules; Sparkle dash to LMB; Sable LMB 8.5 m, no Shred). `--kit-parity-check` 0 failures; combo checks: tender 104, dolm 172, dredge 112, rimewright 116, ostra 213, bulwark 166, mage 143, dancer (Sable) 144, all 0 failures. `--cooldown-parity-check` does not exist on this line (it lives on ext/cooldown-parity-verify).

**Every "branch ready" fix of the 0.24.4 re-audit is still missing from the 0.24.5 line** (none of these branches is an ancestor of it). All trial merges conflict, so each needs a rebase before it can land:

| Hunter | Row still open on 0.24.5 | Fix branch | Conflicts on a trial merge |
|---|---|---|---|
| Meeko | Empowered +40% range (`shot_range_k` 1.4, tender_kit.gd:117,172), Hearthlight `self_k` 0.33 | ext/parity-no-riders-meeko 0d6177875 | KIT_PARITY.md, docs/heroes/tender.md |
| Tenzo | rock `slow_t` 0.8 / `slow_k` 0.3, Rock Hop `slow_t` 1.5 (dolm.json); punch dmg [12, 24] and kb [6, 11] scale with charge | ext/parity-tenzo-rock-slows 44040c047; ext/parity-no-riders-grimble-tenzo 7b130d5c7 | rock-slows: KIT_PARITY.md only; grimble-tenzo: dolm.json, dredge.json, dredge_kit.gd, docs |
| Grimble | E Grounds the foe (dredge.json); cooldowns RMB 12, E 7, R 21 vs 18, 12, 36 | ext/parity-no-riders-grimble-tenzo; ext/grimble-parity-verify d94bc7769 | dredge.json (the E line, also edited by ext/anim-time-grimble-rebased) |
| Albert | Guard meter, Shield Slam, slam stun 0.6 (bulwark.json `resource`, `slam`); Crushing Blow `smash_stun` 0.4; aegis routing; R cd 40 vs 50 | ext/albert-parity-verify b69c6ca3b (carries guardcut); ext/parity-albert-blow-stun 46a88e3a1; ext/combat-albert-aegis-input 91c3dba10 | bulwark.json, bulwark_kit.gd, bjorn_fx.gd, archer_bulwark_combo_check.gd, wiki |
| Motley | un-popped Brimseed fizzles at 10 s (`hold_full` 10.0) | ext/motley-seed-fizzle 9f521695a | KIT_PARITY.md, docs/heroes/ostra.md |
| Neve, Sparkle, Sable, Meeko, Albert | cooldowns not at source level 1 (see each section) | ext/cooldown-parity-verify 2be9877c2 | rimewright.json, thief.json, dredge.json and the slice heroes' data |
| Sparkle | Skycall circle 1.5 (source reading 1.8) | ext/parity-skycall-size 7a40610b7 | KIT_PARITY.md |
| Sable | E range 14 (source reading 16.2) | ext/parity-ranges-rest bee6f9728 | KIT_PARITY.md |

Not a regression but stale text: the Albert section's E row says r 3.5; the data is 2.3 (the ranges table is right). Still owner or `[?]`, unchanged: Tenzo ridge 12 m, Motley orb slow 10% vs 6%, floats, Neve rink +15%, Sparkle slide 3.4. Filed in docs/DEBT.md.

## Re-audit 2026-11-11 (0.24.4 candidate, ext/release-integ-0244c 23cc281bd)

Every row below marked differ, missing or `[?]`, and the top-20 table, was re-read against the candidate's `content/` and kit code. Each one now ends with a mark: **done** `ext/<branch>` (the branch that fixed it; `main` = already on main d255acbee, else only on the candidate), **open** (still a gap), or **owner** (an owner note overrides the source, or the fix needs an owner call). "Branch ready" = a READY branch in briefs/EXT_TO_MAIN.md that fixes it but is not on the candidate (docs/GATE_0244.md lists what was merged). No numbers or code were changed here.

**Still open, slice Hunters first:**

| Hunter | Still open | Fix waiting |
|---|---|---|
| Vex | R cd 42 vs 55 (0.76x), RMB cd 6.5 vs 9 (gap 10) | branch ready: ext/cooldown-parity-verify 2be9877c2 |
| Vex | Hold dash measured 10.3 m (0.18 s skid, then the 7 m slide), against 7 m in this doc; the source gives no hold length `[?]` | reported by ext/verify-starter-trio (not re-measured here) |
| Vex | R cast range 14 `[?]` (no clamp in the source) | none (no data) |
| Kael | Ours-only CC riders: fireblast slow 30% (`lmb.wave_slow`), Chain Lunge stun 0.35 s, Haul Slam stun 0.25 to 0.6 s (`rmb.haul.stun`); the source has none | none; Haul is a documented move, owner call |
| Kael | Air RMB cd 7.2 vs 9, R cd 36 vs 45 (gap 10) | branch ready: ext/cooldown-parity-verify |
| Kael | Warchain leash 24 m and slam angle 70 `[?]` (no data) | none |
| Lace | 8 of 17 dash-flow rows unsourced `[?]` (6 hold rows `keep`, 2 Q rows ours) | none (no source) |
| Lace | RMB range 14, E reach 9, R range 18 / width 0.5 `[?]` (not in the footage) | none |
| Lace | Spirit Walk ending inside a ledge: the candidate sets her on top; the follow-up puts her back on last clear ground and fixes the expiry snap-back | branch ready: ext/combat-lace-spirit-ledges-rebased 40f7865d8 |
| Cinder | RMB cd 7 vs 9, R cd 36 vs 45 (gap 10) | branch ready: ext/cooldown-parity-verify |
| Cinder | RMB range 14 `[?]`; 3 dash-flow `keep` rows and `dash.ground.lmb` unsourced `[?]` | none |
| Albert | Invented Guard meter and Shield Slam (gap 15, owner 11-07 said cut), Shield Slam stun 0.6 s | branch ready: ext/parity-bulwark-guardcut b2e942eb4 |
| Albert | RMB aegis/bash routing `[?]` | branch ready: ext/combat-albert-aegis-input 91c3dba10 |
| Albert | Crushing Blow stun 0.4 s (no source row); R cd 40 vs 50 | none / ext/cooldown-parity-verify |
| Meeko | Empowered +40% range and Hearthlight self_k 0.33 are ours (source silent); R cd 46 vs 60 | branch ready: ext/parity-no-riders-meeko 0d6177875; ext/cooldown-parity-verify |
| Grimble | E Grounds the foe (ours); RMB 12 vs 18, E 7 vs 12, R 21 vs 36 (0.58x to 0.67x) | branch ready: ext/parity-no-riders-grimble-tenzo 7b130d5c7; ext/cooldown-parity-verify |
| Tenzo | Punch charge scaling (ours); rock slow 30% 0.8 s and Rock Hop crash slow 1.5 s (ours) | grimble-tenzo branch covers the punch; the slows have no branch |
| Neve | E cd 17 vs 20 (gap 10) | ext/cooldown-parity-verify |
| Motley | E fizzle 10 s (ours); orb slow 10% (wiki) vs 6% (card read); "floats" `[?]` (the body hovers 0.3 m, a gameplay float not traced) | none; the slow is an owner call |
| Sparkle | RMB cd 8 vs 10, R 42 vs 60; Skycall circle 1.5 / slide 3.4 kept on purpose `[?]` | ext/cooldown-parity-verify |
| Sable | RMB cd 7 vs 13, R 24 vs 50, E 15 vs 28 (level 1); pair stun 0.9 vs ~1.8 s (owner pacing) | ext/cooldown-parity-verify |
| All | Dash curves not decoded (`dash_exit_run` 1.0 stands in) `[?]`; a glide dive held to the ground does not land at the glide sink | branch ready: ext/glide-dive-land e4081da34 |

**Owner, not gaps:** air control (DECISIONS 2026-11-08 "real matches HAVE air control" overrules the source's 0.015), Kael's air RMB as a straight down slam 2.4 m 0.8 m ahead (owner 11-10, ext/jugg-downslam), Neve's rink 8.3 m (owner 11-08 +15%), Vex Coin Blast and palm-fired Longneedle (owner 11-08 presentation; ext/vex-coin-palm-1108 not on the candidate), and every `differ (owner)` row below.

**A check that asserts a stale number:** `content/rules/kit_parity.json` pins Kael's `rmb.drop.radius` at 2.2 ±0.22 (the source's cursor disc); the candidate's down slam is 2.4 (ext/jugg-downslam, owner 11-10), so `--kit-parity-check` passes only at the edge of the tolerance (2.42). Owner call: re-pin it to the owner's 2.4 or drop the row, since the down slam is no longer the source's cursor disc. No other row is stale; the ranges table's Neve rink "7.2, match" was stale and is fixed below (not asserted anywhere).

**How to read a verdict.** `match`: same mechanic, within footage error. `differ`: built, not the same (says how). `missing`: not built. `differ (owner)`: an owner note overrides the source, so it stays unless the owner reverses it; not a gap. `ours`: not in the source at all.

**Evidence:** [D] game data (supervive_kits.md, supervive_physics.md), [F] footage (briefs/hero-ref), [O] owner note. Order of trust: O > D > wiki > F. Source references live only on `origin/ext/agent-briefs` (briefs/supervive-data, briefs/hero-ref, briefs/specs/kit-audit).

**What was and was not verified.**
- Numbers, modes and code paths were read from main. The Nov 3 audit (briefs/specs/kit-audit) is stale: many of its gaps are closed, and rows here were re-checked against main before use. `ext/online-displace` and `ext/no-shake` are merged, so the online pull bug and self-shake are closed.
- All 12 `--<hero>-combo-check` runs pass: 1,560 PASS, 0 FAIL. They assert our spec, not the source, so a pass is not parity proof.
- **Animation timing was not re-measured frame by frame.** Animation rows report clip coverage (computed from kit code, `warden_anim/*.json` and each GLB) plus timings already recorded in docs/heroes. Hitbox rows use content numbers; the in-game hit shapes of Vex, Kael, Lace and Cinder were then measured and shot with the hitbox circles (section "Hit shapes in game"), the other eight were not.
- `[?]` marks a row carried from a hero doc that I could not settle from code here.

**Every Hunter, shared:**
- **Q:** ours (a glove, gear slot, with V). Not in the source, so no parity target. DashFlow fires it through dashes.
- **Keys:** R = hunter ult (JSON slot `x`), X = Fuse, G = Boki (owner).
- **Run speed, ground accel, gravity, fall cap:** match [D]. **Stopping, air control, dash carry:** differ, see gaps 2 to 4.
- **Buffer:** `Loco.press_buffer` 0.15 s past a dash's end; the data gives no window.
- **Run speed, ground accel, gravity, fall cap:** match [D]. **Stopping, air control, dash carry:** match since the source brake 22.2 + friction 2, air control 0.015 and a dash that exits at run speed (bc1a70608, 4071fe66a; gaps 2 to 4 closed). **Jump:** 6.8 kept over 7.5 on purpose and pinned (0f70d1a8a). **Glide dive:** built (280404102, gap 18).
- **Run speed, ground accel, gravity, fall cap:** match [D]. **Stopping, air control, dash carry:** differ, see gaps 2 to 4 (re-audit 11-11: stopping and carry **done**, air control **owner**).
- **Buffer:** `DashFlow.BUFFER_S` 0.15 s past a dash's end; the data gives no window.
- **Cooldowns below** read ours / source level 1 [D].

**0.24.4 recheck (2026-11-12, main 88b06b9e7, slice Vex, Zedran = Kael, Hem = Lace, Cinder).** The last column of the four Hunter tables and of the Kael, Lace, Vex and Cinder rows in the ranges table says `still done`, `closed` (done since the audit), `changed` (an owner change) or `regressed`. Read from `content/` and the kit code, not played in `--arena` (no row needed eyes; Hem's ledge walk, gap 8, stays open unplayed). Combo checks gunslinger 126, juggernaut 210, archer 167, ashwick 125 PASS, 0 FAIL; `--kit-parity-check`, `--dash-flow-check`, `--move-feel-check` 0 failures. `--ttk-check` is the known red tracking bar (22 rows FAIL, 11 of them slice; ours / source: Vex LMB 3.25, combo max 0.78; Kael LMB 0.65, combo 0.55 and 0.59; Cinder LMB 0.78 and 0.74, combo 0.76 and 0.61; Hem passes). Not re-read against the source this time: CC numbers (Zedran's Meteor Drop ring slow 40% is gone with the down slam, 0a97eddab), the felt-dash and health tables (weight classes 124/145/193 unchanged).

## Ranges and radii: RMB, E, R (main d255acbee, 2026-11-10)

Source = `briefs/supervive-data/supervive_kits.md` (the tooltips carry no range numbers, so only the Black Hole radius, 350/500 uu = 3.5/5.0 m, is data) plus the footage measures in `briefs/hero-ref` (1 body height = 1.8 m; a later per-ultimate re-measure wins over the first sheet). Ours = `content/archetypes/<id>.json`, metres. The aim indicator and the hit read the same JSON field for every row below; the Bola lane is drawn at the width the hit reaches (0.45 + body radius per side). **fixed** = changed here and asserted in `--kit-parity-check`. `[?]` = not measurable from the source, or an owner note stands.

| Hero | Slot, number | Ours | Source | Verdict | 0.24.4 main (11-12) |
|---|---|---|---|---|
| Vex | RMB range, cone, lane | 10.5, 6 m at 100, 0.72 | 5-6 bh (9-10.8), 3.5 bh at 100, 0.4 bh | match |
| Vex | E range, beam width | 18, 1.8 | 10+ bh (18+), beam 0.5 bh (0.9) | range match; width differs (owner item 68 widened it) |
| Vex | R range, disc | 14, 3.4 | clamp not seen, 1.8-2 bh (3.2-3.6) | disc match; range **Not determinable**: Mini Nuke frames f29-f45 (dummy ~5 bh = 9 m away) and f95-f111 (empty ground) land at the cursor, and no cast was made at the cursor's maximum, so 14 stays |
| Kael | RMB slam reach, angle | 4.0, 70 | 2.4 bh (4.3), a lane not a cone | reach match; angle **Not determinable**: the one slam (frames 0154-0158) hit a dummy dead centre at 2.4 bh, no foe off-centre, so neither a cone nor a lane can be told apart; 70 stays |
| Kael | RMB lunge length | 4.5 to 7.5 | 5 flat (4.1-5.8) | differ (owner: release flings far) |
| Kael | RMB air slam disc, reach | **2.2** (was 2.6), 5 | 1.2 bh (2.16), cursor to ~5 | **fixed** |
| Vex | E range, beam width | 18, 1.8 | 10+ bh (18+), beam 0.5 bh (0.9) | range match; width differs (owner item 68 widened it) · **owner** |
| Vex | R range, disc | 14, 3.4 | clamp not seen, 1.8-2 bh (3.2-3.6) | disc match; range [?] · **open** [?] |
| Kael | RMB slam reach, angle | 4.0, 70 | 2.4 bh (4.3), a lane not a cone | match; angle [?] · **open** [?] |
| Kael | RMB lunge length | 4.5 to 7.5 | 5 flat (4.1-5.8) | differ (owner: release flings far) · **owner** |
| Kael | RMB air slam disc, reach | 2.4, 0.8 m ahead (straight drop; was 2.2 at the cursor) | 1.2 bh (2.16), cursor to ~5 | differ · **owner** (11-10 down slam, ext/jugg-downslam); the check still pins 2.2 ±0.22 (see the re-audit) |
| Kael | RMB chain spin radius | **2.2** (was 2.6) | 1.2 bh (2.16) | **fixed** |
| Kael | E range, tether max | 13, 24 | 7 bh (12.6), max not determinable (no clip pays out past the throw) | range match; tether max **not determinable**, 24 m ours (clips: docs/heroes/juggernaut.md "Tether length") |
| Kael | E range, tether max | 13, 24 | 7 bh (12.6), max not seen | range match; tether [?] (owner Warchain note) · **open** [?] (ext/kael-chain-length re-checked, no data) |
| Kael | R strip | 3.6 x 1.8 | 1.5-2 bh x 1 bh (2.7-3.6 x 1.8) | match |
| Lace | RMB range | 14 | grows with the charge, max not seen | [?] |
| Lace | E arc, reach | 120, 9 | 120, cursor seen to 6 bh (10.8) | arc match; reach [?] |
| Lace | R range, width | 18, 0.5 | not in the footage | [?] |
| Cinder | RMB range | 14 | clamp not seen (6.5 bh = 11.7 reached) | **Not determinable**: the only miss (frame 0133) ended at 6.5 bh (11.7 m), short of 14 m, so a cursor clamp and a 14 m cap both fit; 14 stays |
| Lace | RMB range | 14 | grows with the charge, max not seen | [?] · **open** |
| Lace | E arc, reach | 120, 9 | 120, cursor seen to 6 bh (10.8) | arc match; reach [?] · **open** |
| Lace | R range, width | 18, 0.5 | not in the footage | [?] · **open** |
| Cinder | RMB range | 14 | clamp not seen (6.5 bh = 11.7 reached) | [?] · **open** |
| Cinder | E radius | 4.5 | 2.5 bh (4.5) | match |
| Cinder | R carpet, ring, flight | 1.8, 2.2, 22.7 | 1 bh, 1.2 bh, 16-18 | width, ring match; flight longer (owner item 20) |
| Meeko | RMB range, burst | 14, 2.2 | 8-9 bh (14.4-16.2), disc 1.2 bh (2.2) | match, burst locked: the sheet reads the disc as the burst area and the 1.8 bh (3.2) flare as the trigger VFX; one target only, so nothing shows a wider hit |
| Meeko | E ring, thrown, reach | 2.6, 2.9, 9 | 1.3-1.5 bh, 1.6 bh, - | match; reach not determinable: every throw lands on the cursor, no clamp is reached (sheet open question) |
| Cinder | R carpet, ring, flight | 1.8, 2.2, 22.7 | 1 bh, 1.2 bh, 16-18 | width, ring match; flight longer (owner item 20) · **owner** |
| Meeko | RMB range, burst | 14, 2.2 | 8-9 bh (14.4-16.2), disc 1.2 bh (2.2; flare 1.8 bh = 3.2) | match; flare [?] · **open** |
| Meeko | E ring, thrown, reach | 2.6, 2.9, 9 | 1.3-1.5 bh, 1.6 bh, - | match; reach [?] · **open** |
| Vex | RMB range, cone, lane | 10.5, 6 m at 100, 0.72 | 5-6 bh (9-10.8), 3.5 bh at 100, 0.4 bh | match | still match (10.5, 6 m at 100, .72) |
| Vex | E range, beam width | 18, 1.8 | 10+ bh (18+), beam 0.5 bh (0.9) | range match; width differs (owner item 68 widened it) | still as noted (18; width 0.9 each side = 1.8) |
| Vex | R range, disc | 14, 3.4 | clamp not seen, 1.8-2 bh (3.2-3.6) | disc match; range [?] | still match (14, 3.4) |
| Kael | RMB slam reach, angle | 4.0, 70 | 2.4 bh (4.3), a lane not a cone | match; angle [?] | still match (4.0, 70) |
| Kael | RMB lunge length | 4.5 to 7.5 | 5 flat (4.1-5.8) | differ (owner: release flings far) | still differ (owner) |
| Kael | RMB air slam disc, reach | **2.2** (was 2.6), 5 | 1.2 bh (2.16), cursor to ~5 | **fixed** | **regressed (data)**: radius 2.4 m, centred 0.8 m ahead (owner's down slam 0a97eddab); source 2.16 is +11%. Owner call, backlog line |
| Kael | RMB chain spin radius | **2.2** (was 2.6) | 1.2 bh (2.16) | **fixed** | still fixed (2.2) |
| Kael | E range, tether max | 13, 24 | 7 bh (12.6), max not seen | range match; tether [?] (owner Warchain note) | still (13, 24) |
| Kael | R strip | 3.6 x 1.8 | 1.5-2 bh x 1 bh (2.7-3.6 x 1.8) | match | still match (3.6 x 1.8) |
| Lace | RMB range | 14 | grows with the charge, max not seen | [?] | still open `[?]` (14) |
| Lace | E arc, reach | 120, 9 | 120, cursor seen to 6 bh (10.8) | arc match; reach [?] | still arc match; reach open (120, 9) |
| Lace | R range, width | 18, 0.5 | not in the footage | [?] | still open `[?]` (18, .5) |
| Cinder | RMB range | 14 | clamp not seen (6.5 bh = 11.7 reached) | [?] | still open `[?]` (14) |
| Cinder | E radius | 4.5 | 2.5 bh (4.5) | match | still match (4.5) |
| Cinder | R carpet, ring, flight | 1.8, 2.2, 22.7 | 1 bh, 1.2 bh, 16-18 | width, ring match; flight longer (owner item 20) | still (1.8, 2.2, 12.6 x 1.8 s = 22.7) |
| Meeko | RMB range, burst | 14, 2.2 | 8-9 bh (14.4-16.2), disc 1.2 bh (2.2; flare 1.8 bh = 3.2) | match; flare [?] |
| Meeko | E ring, thrown, reach | 2.6, 2.9, 9 | 1.3-1.5 bh, 1.6 bh, - | match; reach [?] |
| Meeko | R range | 12.6 | tether ring 7 bh (12.6) | match |
| Tenzo | RMB radius, core | 4.5 (3.82 tap), 0.9-1.8 | 2.5 bh (4.5), 0.5-1 bh | match |
| Tenzo | E ahead, span | 3.4, 5 | 2 bh (3.6), 3 bh (5.4) | match |
| Tenzo | R ridge length, cast range | 12, 11 | 10-12 bh (18-21.6), - | differ ~40%, kept: f2b60dc70 narrowed it 19.8 to 12 on purpose, no DECISIONS line either way; [?] |
| Tenzo | Passive cone length (Tremor Sense, sneaking) | 18 growing to 25 over the 2 s `grow` that widens it 25 to 40 deg (`passive.len`, `len_max`) | 10-14 bh (18-25), lengthens with the hold (breah.md 0693-0725); closes dolm.md row 9 | match |
| Tenzo | R ridge length, cast range | 12, 11 | 10-12 bh (18-21.6), - | differ ~40%, kept: f2b60dc70 narrowed it 19.8 to 12 on purpose, no DECISIONS line either way; [?] · **owner** |
| Grimble | RMB range | 11.5 | 6-7 bh (10.8-12.6) | match |
| Grimble | E depth, angle | 3.0, 110 | 1.5 bh deep x 2 bh wide (2.7 x 3.6), a box | depth match, locked; angle not determinable: the source hit box is a rectangle, not a sector (ours 8.6 m², the box 9.7 m²) |
| Grimble | E depth, angle | 3.0, 110 | 1.5 bh deep x 2 bh wide (2.7 x 3.6) | within footage error [?] · **open** |
| Grimble | R fan, depth | 105, 5.9 | 100-110, 3.3 bh (5.9) | match |
| Neve | RMB range, zone, burst | 12, 2.2, 2.7 | lands at the cursor, zone 1.2 h (2.16), dome 1.5 h (2.7) | zone, burst match, locked; range not determinable: it lands on the cursor and no clamp is reached (owner: travel time grows with distance) |
| Neve | E width, slide | 1.8 to 4.5, 4.5 m/s to 16.2 | 1 h to 2.5 h (1.8-4.5), 6 h in 2.4 s (4.5 m/s) | width, speed match, locked; slide length not determinable: one slide seen (6 h), stop rule unknown (sheet open question) |
| Neve | R rink radius | 7.2 | 4 bh (7.2) | match |
| Motley | RMB range | 13 | hit after about 3 h; bundle crosses 6 h (10.8) in a frame, max not seen | not determinable: no miss to max range in the clip (sheet open question) |
| Neve | RMB range, zone, burst | 12, 2.2, 2.7 | lands at the cursor, clamp and rings not measured | [?] (owner: travel time grows with distance) · **open** |
| Neve | E width, slide | 1.8 to 4.5, to 16.2 | narrow to ~2.5 h (4.5), slide not measured | width match; slide [?] · **open** |
| Neve | R rink radius | 8.3 (was 7.2; this row said match) | 4 bh (7.2) | differ +15% · **owner** (11-08, c05e9d3a5) |
| Motley | RMB range | 13 | bundle seen over 6 h (10.8), max not seen | [?] · **open** |
| Motley | E seed radius | 3.2 | 1.8 h (3.2) | match |
| Motley | R radius, range | 3.6 / 5.1 swollen, 10 | 350 / 500 uu (3.5 / 5.0), cast 2-3 bh away | radius match; range not determinable: cast only on a near dummy, the clamp is never reached |
| Albert | RMB aegis, slam | 4.2 at 140, 2.6 at 100 | slab 2.2 h wide (4.0), no slam in the kit | aegis match; slam not determinable: the source has no slam (its only knock is the Empower Shield Bash augment, unmeasured), and DECISIONS 2026-11-07 cuts the Shield Slam (left to the owner) |
| Motley | R radius, range | 3.6 / 5.1 swollen, 10 | 350 / 500 uu (3.5 / 5.0), - | match; range [?] · **open** |
| Albert | RMB aegis, slam | 4.2 at 140, 2.6 at 100 | slab 2.2 h wide (4.0), bash not seen | aegis match; slam [?] · **open** |
| Albert | E zone radius | **2.3** (was 3.5) | green disc 1.3 h (2.34) | **fixed** |
| Albert | R lane | 16 x 4.5 | 9 bh x 2.5 bh (16.2 x 4.5) | match |
| Sparkle | RMB range | 13 | 7.5 bh (13.5) | match |
| Sparkle | E radius, reach, slide | 1.5, 11, 3.4 | circle ~2 bh across (radius 1.8), -, ~4 bh (7.2) | differ 17% and 53%, kept: mage.md set 1.5 as the hit on purpose; [?] · **owner** |
| Sparkle | R radius, range | 2.7, 14.4 | ring 1.5 bh (2.7), 8 bh | match |
| Sable | RMB range, lane | 7 + 3.8, **1.8 wide** (was 1.4) | lane 5.5-6 bh (9.9-10.8), 1 bh wide (1.8) | **fixed** (width) |
| Sable | E range | **16.2** (was 14) | no-target dagger landed about 9 bh out (16.2) | **fixed**: 14 could not reach the landing seen; 16.2 is the least range that does, max not seen |
| Sable | E range | 14 | landed at 9 bh (16.2), max not seen | [?] · **open** |
| Sable | R ring | 5.4 (rim band outer 25%) | 3 bh (5.4); the first sheet's 3.5 bh is superseded | match |

Second pass (2026-11-11): the open Meeko, Grimble, Neve, Motley, Albert and Sable rows above are settled or marked not determinable from the hero-ref sheet measures (the frames behind them, 1 bh = 1.8 m); settled numbers are locked in `content/rules/kit_parity.json`.

Left alone and why, for the owner: Kael lunge (owner), Vex needle width (owner item 68), Cinder flight (owner item 20), Tenzo ridge (deliberate narrowing, source 10-12 bh), Sparkle Skycall circle (deliberate). Ideas of ours stay out of the build.

## Hit shapes in game: Vex, Kael, Lace, Cinder (main 88b06b9e7, 2026-11-12)

How: `--hit-shape-fine` (tools/hit_shape_fine.gd) fires each input of the four hunters at ONE training dummy moved around, in a match stepped at the game's 60 Hz, level 6 (rank 3 numbers apply): a scan along the aim line gives the nearest and farthest foe centre that still takes damage, a scan across the middle gives the lane, a scan round it the arc; the numbers below have the foe's circle taken off. `--hit-shape-shots` (tools/hit_shape_shots.gd) fires the same inputs at a field of dummies, each wearing its ground circle (its hitbox), at the gameplay camera: strips in `docs/shots/verify-hitbox-slice/`. Ours = `content/archetypes/<id>.json`; source = `briefs/supervive-data/supervive_kits.md` (no sizes) and the footage sheets in `briefs/hero-ref` (1 bh = 1.8 m).

What the game does with a number (so a row reads straight): areas (cone, ring, strip, disc, lane of a beam) take a foe in when its body circle, 0.40 m, touches them, so measured = content to 0.15 m. Bullets, hooks and swing rays take it in at body circle + 0.08 m + their own radius; a bullet starts 0.6 m ahead of the hunter and lives to the end of the 1/60 s step in which its range runs out (74 m/s: +1.2 m, 90 m/s: +1.5 m); a swing is a fan of 7 or 9 such rays 0.22 m wide, so its arc reads about 30 degrees wider than the drawn one (175 reads 206).

| Hero | Move | Ours | Measured in game | Source | Verdict |
|---|---|---|---|---|---|
| Vex | LMB rifle | range 11, bullet 0.13 | reach 11.9, lane 0.24 (11 + 0.13 + 0.6 start, then the step) | no number; tracers ~1.5 bh, reach not seen | match; source gap |
| Vex | RMB Burr | range 10.5, lane 0.72, cone 6 at 100 deg | lane reach 11.1, cone flank 6.1 from the stick point; angle not isolated (a lone foe leaves the cone by its length first) | 5-6 bh (9-10.8), 0.4 bh (0.72), cone 3.5 bh at 100 | match |
| Vex | E Longneedle | range 18, beam 1.8 wide (JSON `width` 0.9 is the half) | reach 18.0, lane 1.8 | 10+ bh (18+), 0.5 bh (0.9) thick | match; width 2x source (owner item 68) |
| Vex | R Cinderfall | range 14, radius 3.4 | disc centre 14.0 (cursor clamped), radius 3.4 | clamp not seen, disc 1.8-2 bh (3.2-3.6) | match; clamp [?] |
| Kael | LMB sword | reach 3.1, arc 175 | reach 3.7, arc of centres 206 (ray 0.22 + circle) | ~180 deg, radius 1.8 bh (3.2) | match (-4%, -3%) |
| Kael | LMB hold, Searing Wave | range 7 to 14, size 0.3 to 0.6, 36 m/s | full charge: reach 14.4, lane 1.14 | flies 20 bh/s (36), reach no number | match; reach gap |
| Kael | RMB tap, Smash | radius 4, 70 deg | reach 4.0, angle 70 | 2.4 bh (4.3), a lane not a cone | match; angle and lane width [?] |
| Kael | RMB hold, Lunge | 4.5 to 7.5 | full charge: reaches 8.6 with the body (7.5 + circles) | 5 flat | differ (owner: release flings far) |
| Kael | E Warchain | range 13 | reach 14.2 (13 + hook + step), lane 0.44 | 7 bh (12.6) | match |
| Kael | R Riposte | strip 3.6 x 1.8 from where he planted | length 3.6, width 1.8 | 1.5-2 bh x 1 bh (2.7-3.6 x 1.8) | match; the drawn lane and the hit read one field |
| Lace | LMB, Empowered | range 12, arrow 0.18 | reach 13.7 (12 + 0.2 + 0.6 start + step) | lands at the cursor, ~6 bh (10.8) seen | match |
| Lace | LMB, Supercharged | range 16 | reach 18.1 | no number | match; source gap |
| Lace | RMB Heavy Shot | 14 (+3 at rank 3), size 0.3 | reach 18.5 at rank 3 (17 + 0.6 + step) | gold bar ~2 bh while held; range not seen | match; range [?] |
| Lace | E Hail Wall | reach 9, 120 deg, 1.8 deep | wall centre 9.0, arc 125 | 120 deg, centre at the cursor (8-10.8) | match |
| Lace | R Starpiercer | range 18, width 0.5 | reach 20.4 (18 + 0.6 + 1.5 step), lane 0.5 | ~1.5x normal range (1.5 x 12 = 18) | match |
| Cinder | LMB flame | range 6.1, width 0.65 to 2.85 | reach 6.8, fan 1.8 wide at 4 m (2.8 in foe centres) | ~4 bh (7.2) whatever the cursor; 0.3 bh to 1-1.5 bh wide | match; reach -15% to source |
| Cinder | RMB Cinder Shot | range 14, size 0.3 | reach 13.9 | flew 6-8 bh (10.8-14.4); a miss ended at the cursor (11.7) | match; always-full-range vs ends at cursor [?] |
| Cinder | E Furnace Cloak | radius 4.5 | radius 4.5 | 2.5 bh (4.5) | match |
| Cinder | R Flue Flight | 12.6 m/s for 1.8 s, carpet 1.8 | carpet along the whole 22 m, lane 1.8 | 7 bh/s (12.6) for 1.3-1.4 s (16-18), carpet 1 bh | match; flight 26-40% longer (owner item 20) |

**Result:** 20 moves, no plain mismatch between what the game draws, what it hits and what the content says, so no kit was changed. The follow-ups are all source gaps:
1. Kael's sword has two numbers: `greatsword.json` says range 3.4, arc 160, the kit draws and hits `lmb` reach 3.1, arc 175 (the first is what `--hit-shape-check` and HITBOX_SIZE.md read; it also feeds bot range). One of them should go.
2. Cinder's flame is 6.1 m against the footage's 4 bh (7.2); the far end is 2.85 wide against 1.8-2.7.
3. Cinder Shot always flies 14 m; the footage shows a miss ending at the cursor (11.7 m) once, with no clamp read. The card says "long-range".
4. Open source numbers, nothing to compare yet: Vex R range clamp, Kael slam lane width and wave range, Lace Supercharged and Heavy Shot max range, the Hail Wall depth.
5. Already filed above for the owner: Kael lunge, Vex needle width, Cinder flight.
6. The coarse `--hit-shape-check` reads swings and cones short (a ray stops at the first dummy of the grid, 20 Hz steps): Kael LMB there is 1.6 m / 113 deg against 3.7 / 206 here. Use `--hit-shape-fine` for those four heroes' areas.

## Vex (`gunslinger`, source Ghost) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold; 51 a round, 30 rounds, rapid refill when idle, first 10 rounds stronger [D]; opens at 2x, 50% by round 10, 0.08 s [wiki] | 12 -> 6 over 10 rounds (51 of 1285 = 6 of 154), cadence 0.08, mag 30, refill 40/s after 0.35 s, no fire slow | match (ext/parity-ttk-vex, docs/TTK.md) |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) |
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | `quill_rifle.json`: rate 0.12, mag 30, refill 40/s after 0.35 s, 10-round sustain (half punch after), Dazed +90% | match |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Burr Charge from the launcher, cd 6.5/9 (footage 5.4) | differ (owner, item 112) |
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | Cadence 0.08 (~12 rounds/s, docs/WEAPON_FIRING_DATA.md; was 0.12 until fun audit 11-11), mag 30, refill 40/s after 0.35 s, 10-round sustain, no fire slow | match |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) |
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | Cadence 0.12, mag 30, refill 40/s after 0.35 s, 10-round sustain, no fire slow | match |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) · **owner**; cd **open** (gap 10) |
| Q | none | glove | ours |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, dmg 24 (the source's 0.157 of a target; 36 until 11-11), recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m, hold 7 m at +40% cd, cd 8.5, all `fire` rows; feel applied once (2f24ae36b) | match; pending `ext/vex-dash-parity` efbd6af96 (one Shift charge by the archetype's own `dash.charges`, eased Shift) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m/.45 s (F 4.8/.47), off the dash feel; hold 7 m at +40% cd, 8.5 s, all rows `fire`, sourced 15/15 | match |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +38% rifle (+39 on the 102 opening) | match |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) · cd **open** (branch ready: ext/cooldown-parity-verify) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m/.45 s (F 4.8/.47), off the dash feel; hold 7 m at +40% cd, 8.5 s, all rows `fire`, sourced 15/15 | match |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +76% rifle (the source's +39 on 51; the ours-only pause of the string's falloff on a Dazed foe is gone) | match |
| Anim | Footage poses | 7 moves, all on `vex.glb` clips (36) | match on coverage |
| Slot | Source | Ours | Verdict | 0.24.4 main (11-12) |
|---|---|---|---|---|
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | Cadence 0.12, mag 30, refill 40/s after 0.35 s, 10-round sustain, no fire slow | match | still done (rate .12, mag 30, refill .35 s at 40/s; combo check 126 PASS) |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) | still differ (owner, item 112); cd 6.5 unchanged |
| Q | none | glove | ours | ours |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match | still done (charge .6, range 18, width 0.9 each side = 1.8, shave .2/.3, cd 11.5) |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) | still done (delay 1.6, zone 3 s, slow 30%, cd 42) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m/.45 s (F 4.8/.47), off the dash feel; hold 7 m at +40% cd, 8.5 s, all rows `fire`, sourced 15/15 | match | still done (4.8 m/.45 s, hold 7 m, cd 8.5; 15/15 dash-flow rows `fire`, all sourced; Ghost speed curve fitted d2adc51b) |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +90% rifle | match | still done (6%, 3.5 s) |
| Anim | Footage poses | 7 moves, all on `vex.glb` clips (36) | match on coverage | still done (`vex.glb` 36 clips) |

## Kael (`juggernaut`, source Brall) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Press combo; hold ranged fireblast [D] | Rate .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; ground dash→LMB still buffers, now cited: the dash is his attack [D] (gap 9, 4e788af65 left it) |
## Kael (`juggernaut`, source Brall; was Zedran) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Press combo; hold ranged fireblast [D] | Cadence .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; dash→LMB `fire` |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D] | cd 2.0, hold .3, perfect release, over-head pose | match in shape; overhead/perfect differ (owner) |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2, cursor marker | match; 0.8x cd |
| LMB | Press combo; hold ranged fireblast [D] | Cadence .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; dash→LMB buffers (gap 9) · **done** `ext/parity-dashlmb` (main): `buffer` kept, sourced (Flame Step is itself the attack) |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D] | cd 2.0, hold .3, perfect release, over-head pose | match in shape; overhead/perfect differ (owner) · **owner** |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2; now a straight down slam, 2.4 m hit 0.8 m ahead | differ · **owner** (11-10, `ext/jugg-downslam`); cd 0.8x **open** (gap 10) |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2, straight down slam r 2.4 hit 0.8 m ahead (owner 11-10) | match; 0.8x cd; radius pinned at the owner 2.4 in kit_parity.json |
| Q | none | glove | ours |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source length unknown |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal .8, cd 36; a Hunter knocked or killed by the strike resets it (e152b31d6) | match; 0.8x cd |
| Dash | Dash attack, charges, 13 s [D] | 4.5 m/.17 s raw, ×.85/×1.15 feel (applied once, 2f24ae36b), 2 charges, cd 10.4 | match; dist scaled, cd 0.8x |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash `[?]` (no data, no frame shows one; 24 m kept) |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash **not determinable** (no data; no clip pays the chain out past its throw, 11-11; 24 m kept) |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match in shape; kill reset `[?]` |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash `[?]` (no data, no frame shows one; 24 m kept) |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match; kill reset settled: a hunter taken down by the cleave (docs/KNOCK_RESETS.md) |
| Dash | Dash attack, charges, 13 s [D] | 0.07 s dip, then 4.5 m/.17 s raw (owner 113.8), ×.85/×1.15 feel: felt 3.8 m/.2 s (F ~2 bh/.2 s), 2 charges, cd 10.4 | differ (owner) |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash `[?]` (no data, no frame shows one; 24 m kept) · **open** [?] |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match in shape; kill reset `[?]` · kill reset **done** `ext/kael-ult-reset-rebased-rebased` (through HeroUlt, asserted); cd 0.8x **open** (gap 10) |
| Dash | Dash attack, charges, 13 s [D] | 0.07 s dip, then 4.5 m/.17 s raw (owner 113.8), ×.85/×1.15 feel: felt 3.8 m/.2 s (F ~2 bh/.2 s), 2 charges, cd 10.4 | differ (owner) · **owner** |
| Passive | Damage empowers; heal on knock [D] | Rage, Enrage 6 s, heal_knock .2 | match in shape |
| Anim | Full set | 20 moves, all on `kael.glb` clips (49) via `warden_anim/kael.json` | match on coverage; **closed** (gap 1): 3419a661a (merged a4e410361) |

## Lace (`archer`, source Myth) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold to charge, release; perfect speeds next draw [D,F] | PinDraw two stages, reticle, stops at cursor, cadence .5, perfect (0.15 s) → quick draw | match |
| RMB | Hold, release, knock, wall stun up to 173 extra on 35 [D] | Hold .15 (was .5), wall pin 4.94x the shot, stun 1.2, cd 16 | match; **closed** (gaps 6, 7): 4aa011a49 |
| Anim | Full set | 20 moves, all on `kael.glb` clips (49), map `warden_anim/kael.json` | match on coverage (gap 1 closed) |
| Anim | Full set | 49 clips on `kael.glb` (v1 retargeted, 3419a661a), 21 moves in `warden_anim/kael.json` | match on coverage (gap 1 closed); clips retargeted, not authored for this body |
| Anim | Full set | **20 moves. `kael.glb` has 0 clips and no `warden_anim/kael.json`: stays on procedural HunterAnim** | **missing** (gap 1) · **done** `ext/kael-v2-model` (main): `kael.glb` has 49 clips, `warden_anim/kael.json` maps them |
| Slot | Source | Ours | Verdict | 0.24.4 main (11-12) |
|---|---|---|---|---|
| LMB | Press combo; hold ranged fireblast [D] | Cadence .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; dash→LMB buffers (gap 9) | still done (.34, .22-.95, wave 36, arc 175, reach 3.1); gap 9 open: dash-flow rows 3 `buffer`, 4 `cancel` |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D] | cd 2.0, hold .3, perfect release, over-head pose | match in shape; overhead/perfect differ (owner) | still done in shape (cd 2.0, hold .3, slam 4.0 at 70) |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2, cursor marker | match; 0.8x cd | changed by the owner (0a97eddab, adc81b267): Meteor Drop is a straight-down slam, 2.4 m circle 0.8 m ahead, knock-down .45 s, core stun .8 s, cd 7.2; no cursor marker, no ring slow. Not a regression |
| Q | none | glove | ours | ours |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash `[?]` (no data, no frame shows one; 24 m kept) | still done (13 m, tether 24, cd 12.8) |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match in shape; kill reset `[?]` | still done (guard .65, strike .1, recover .35, heal .8, cd 36) |
| Dash | Dash attack, charges, 13 s [D] | 0.07 s dip, then 4.5 m/.17 s raw (owner 113.8), ×.85/×1.15 feel: felt 3.8 m/.2 s (F ~2 bh/.2 s), 2 charges, cd 10.4 | differ (owner) | still differ (owner); .07 dip, 4.5 m/.17 s, x.85/x1.15 unchanged, curve fitted d2adc51b; felt-dash rows pass |
| Passive | Damage empowers; heal on knock [D] | Rage, Enrage 6 s, heal_knock .2 | match in shape | still done (Enrage 6 s, heal_knock .2) |
| Anim | Full set | **20 moves. `kael.glb` has 0 clips and no `warden_anim/kael.json`: stays on procedural HunterAnim** | **missing** (gap 1) | **closed**: `kael.glb` 49 clips, `warden_anim/kael.json` (a4e410361); gap 1 done |

## Lace (`archer`, source Myth; was Hem) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold to charge, release; perfect speeds next draw [D,F] | PinDraw two stages, reticle, stops at cursor, cadence .5, perfect → quick draw | match |
| RMB | Hold, release, knock, wall stun up to 173 extra on 35 [D] | Hold .5 dead zone (ours), wall_dmg 12, `wall_mult` 4.94, stun 1.2, cd 16 | match: wall payoff ~5x (gap 6 closed) |
| RMB | Hold, release, knock, wall stun up to 173 extra on 35 [D] | Hold .15 tap guard, `pin.wall_mult` 4.94, stun 1.2, cd 16 | match on payoff (gap 6 closed, 4aa011a49); draw start vs footage open (gap 7) |
| RMB | Hold, release, knock, wall stun up to 173 extra on 35 [D] | Hold .5 dead zone (ours), wall_dmg 12, floor .4, stun 1.2, cd 16 | **differ**: payoff ~0.4x vs ~5x (gap 6) · **done** `ext/parity-lace` (main): `pin.wall_mult` 4.94, hold 0.15 from the press (gap 7) |
| Q | none | glove | ours |
| E | Cone of arrows, slow, anti-heal, 15 s [D] | Tell .35, 4.4 s, slow 35%, curved wall, cd 15 | match |
| R | 3 empowered shots, no charge, 60 s [D] | 3 travelling arrows (90 m/s, dfaeae389), window 6 s, nock .5, recover 1.0 (97ffe28a9), cd 60 | match |
| Dash | Roll to cursor, then Phase Walk through terrain incl. raised walls, 9.5 s [D] | 3.5 m/.24 s raw, ×.85/×1.15 feel, 2.8 s walk; rocks, trees, barriers pass, terrain ledges still stop it | differ; pending `ext/parity-phasewalk-rebased` 2178ea313 (raised terrain passes, ending inside snaps back; gap 8) |
| Passive | Fog vision of injured; tall-ledge climb [D] | Hawk Sense 22 m, `climb_tall` | match; **closed** (gap 5): Focus/Deadeye cut, ffa20b0f7 |
| Anim | Footage poses | 17 moves, all on `hem.glb` (48 clips) | match on coverage |
| Flow | Silent on shooting in the walk [F] | Dash→LMB `fire` (4e788af65); 8 of 17 rows unsourced `[?]` (hold.lmb/rmb × 3, Q × 2) | match; sources open (item 20 below) |
| R | 3 empowered shots, no charge, 60 s [D] | 3 shots, window 6 s, nock .3, cd 60 | match |
| Dash | Roll to cursor, then Phase Walk through terrain incl. raised walls, 9.5 s [D] | Roll 3 m/.27 s (F), off the dash feel; walks rocks and barriers, **not ledges** | differ (gap 8) |
| Passive | Fog vision of injured; tall-ledge climb [D] | Hawk Sense 22 m only; the invented Focus/Deadeye is gone (gap 5 closed) | differ: tall-ledge climb not built |
| Passive | Fog vision of injured; tall-ledge climb [D] | Hawk Sense 22 m; Focus/Deadeye cut (ffa20b0f7) | match (gap 5 closed) |
| Dash | Roll to cursor, then Phase Walk through terrain incl. raised walls, 9.5 s [D] | Roll 3 m/.27 s (F), off the dash feel; walks rocks and barriers, **not ledges** | differ (gap 8) · **done** `ext/parity-phasewalk-rebased`, `ext/lace-phasewalk-verify`: passes raised terrain, set on top if it ends inside; follow-up in ext/combat-lace-spirit-ledges-rebased (not on the candidate) |
| Passive | Fog vision of injured; tall-ledge climb [D] | Hawk Sense 22 m; **Focus/Deadeye invented** | differ (gap 5); owner question open · **done** `ext/parity-lace-focus` (main): Focus and Deadeye cut, Hawk Sense kept; climb asserted (`ext/lace-tall-climb-rebased`) |
| Anim | Footage poses | 18 moves, all on `hem.glb` (48) | match on coverage |
| Flow | Silent on shooting in the walk [F] | Dash→LMB `fire`; 8 of 17 rows unsourced | gap 9 closed here |
| Flow | Silent on shooting in the walk [F] | Dash→LMB buffers; 8 of 17 rows unsourced | gap 9 · LMB **done** `ext/parity-dashlmb` (main, fires mid-dash); 8 rows unsourced **open** [?] |
| Slot | Source | Ours | Verdict | 0.24.4 main (11-12) |
|---|---|---|---|---|
| LMB | Hold to charge, release; perfect speeds next draw [D,F] | PinDraw two stages, reticle, stops at cursor, cadence .5, perfect → quick draw | match | still done (perfect_t .15; combo check 167 PASS) |
| RMB | Hold, release, knock, wall stun up to 173 extra on 35 [D] | Hold .5 dead zone (ours), wall_dmg 12, floor .4, stun 1.2, cd 16 | **differ**: payoff ~0.4x vs ~5x (gap 6) | **closed** (4aa011a49): wall pin pays 4.94x, hold .15, stun 1.2, cd 16; gaps 6, 7 done |
| Q | none | glove | ours | ours |
| E | Cone of arrows, slow, anti-heal, 15 s [D] | Tell .35, 4.4 s, slow 35%, curved wall, cd 15 | match | still done (tell .35, 4.4 s, slow 35%, cd 15) |
| R | 3 empowered shots, no charge, 60 s [D] | 3 shots, window 6 s, nock .3, cd 60 | match | still done (3 shots, window 6 s, cd 60); nock now .5 (97ffe28a9) |
| Dash | Roll to cursor, then Phase Walk through terrain incl. raised walls, 9.5 s [D] | Roll 3 m/.27 s (F), off the dash feel; walks rocks and barriers, **not ledges** | differ (gap 8) | still differ, open (gap 8, ledges): roll 3.0 m/.27 s unchanged; not played in --arena |
| Passive | Fog vision of injured; tall-ledge climb [D] | Hawk Sense 22 m; **Focus/Deadeye invented** | differ (gap 5); owner question open | **closed** (ffa20b0f7): Focus/Deadeye cut, Hawk Sense 22 m kept; gap 5 done |
| Anim | Footage poses | 18 moves, all on `hem.glb` (48) | match on coverage | still done (`hem.glb` 48 clips) |
| Flow | Silent on shooting in the walk [F] | Dash→LMB buffers; 8 of 17 rows unsourced | gap 9 | gap 9 closed for Hem (4e788af65): 11 `fire` rows; 8 of 17 rows still unsourced `[?]` (open) |
| Slot | Source | Ours | Verdict | Re-check 2026-11-10 (ext/release-integ-0244-fix ec3c9dafb, Training Area) |
|---|---|---|---|---|
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | Cadence 0.12, mag 30, refill 40/s after 0.35 s, 10-round sustain, no fire slow | match | A round every 0.13 s held (0.12 on the clock, frame-rounded), first 0.07 s after the press; 6.0, 5.7, 5.4, 5.1 on the first hits, 3.0 by round 10; 82 dmg in 3 s. **match** |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) | 22 dmg + Dazed, lands 0.20 s after the press at 6 m, cd 6.5 s; wall cone 16 + shove, fuse 0.9 s (combo check). Still named Burr Charge: owner 11-08 Coin Blast not on this branch (gap A). **match, rename missing** |
| Q | none | glove | ours | not measured (ours) |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match | Beam at 0.63 s, 36 dmg (+20% on Dazed, passes a wall), cd 11.5 s, shave 20%/30%. Still fires from the rifle: owner 11-08 Palm Lance (palm origin) not on this branch (gap A). **match, palm missing** |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) | Impact 1.62 s after the press (24, 36 in the core), then 3 per tick for 3 s, cd 42 s. Ticks are 0.52 s apart, not 0.5 (gap C). **match** |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m/.45 s (F 4.8/.47), off the dash feel; hold 7 m at +40% cd, 8.5 s, all rows `fire`, sourced 15/15 | match | Tap 4.85 m, 98% by 0.43 s (data 4.8/.45); hold 10.3 m in 0.82 s: the 0.18 s skid then the 7 m slide, charge cost 1.4 (gap B); 8.5 s per charge. Fires through both; dash-flow rows 0 fail. **match; hold is skid + 7 m** |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +90% rifle | match | 6% for 3.5 s, one stack; Dazed +90% rifle, all PASS in the combo check. **match** |
| Anim | Footage poses | 7 moves, all on `vex.glb` clips (36) | match on coverage | Clip on within 0.03 s (LMB), 0.10 s (RMB); move lengths RMB 0.5, dash 0.87 (legs back 1.30 on a hold), E 1.07, R 0.60 s; all PASS. **match** |

## Kael (`juggernaut`, source Brall; was Zedran) · slice Warden

| Slot | Source | Ours | Verdict | Re-check 2026-11-10 (ext/release-integ-0244-fix ec3c9dafb, Training Area) |
|---|---|---|---|---|
| LMB | Press combo; hold ranged fireblast [D] | Cadence .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; dash→LMB buffers (gap 9) | Taps swing every 0.35 to 0.40 s at 0.1 s press steps (0.34 s rate, 3 slashes in 1 s PASS), 8 then 12.8 per slash; hold 0.5 s lets go a wave of 15.3 (12 to 20 by hold), 20 at full 0.95 s, the wave flies 36 m/s (0.15 s to 6 m); held 3 s it never fires. **match** |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D] | cd 2.0, hold .3, perfect release, over-head pose | match in shape; overhead/perfect differ (owner) | Slam 26 lands 0.72 s after a tap (0.6 wind-up); Lunge 16 at hold 0.45 s, 20 at 0.8 s and over; cd 2.0 s. Held 5 s it never fires, blade over the head, a flash each second; release on the flash flings 7.8 m against 6.6 m (+18%, owner note). **match** |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2, cursor marker | match; 0.8x cd | Air row PASS (airborne after a chain launch = Meteor Drop); cd 7.2 s in the data, disc 2.2 m. **match** |
| Q | none | glove | ours | not measured (ours) |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash `[?]` (no data, no frame shows one; 24 m kept) | Hook 8 dmg 0.28 s after the press at 10 m (32 m/s), cd 12.8 s from the cast; recast hauls 9.4 m, within 2 m of the foe 0.37 s later (22 m/s); holds 5 s, pays out to 24.06 m and holds taut, a strafe or a look bends the pull 2.9 m aside, backing away slings 24.5 m/s (owner Warchain note PASS). **match** |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match in shape; kill reset `[?]` | Guard 0.65 + strike 0.1: 43 dmg at 0.77 s, cd 36 s (source 45). **match; cd 0.8x** |
| Dash | Dash attack, charges, 13 s [D] | 0.07 s dip, then 4.5 m/.17 s raw (owner 113.8), ×.85/×1.15 feel: felt 3.8 m/.2 s (F ~2 bh/.2 s), 2 charges, cd 10.4 | differ (owner) | 4.14 m in 0.35 s (0.07 dip, 3.1 m by 0.2 s: 3.8 m felt plus 0.35 m exit carry); 2 charges, a charge back every 10.4 s; hold = tap. dash-flow rows 0 fail. **match** |
| Passive | Damage empowers; heal on knock [D] | Rage, Enrage 6 s, heal_knock .2 | match in shape | Damage fills Rage, full = Enraged +15%, ability and dash haste (combo check PASS). **match** |
| Anim | Full set | **20 moves. `kael.glb` has 0 clips and no `warden_anim/kael.json`: stays on procedural HunterAnim** | **missing** (gap 1) | Still `kael.glb` 0 clips (gap 1 below). **missing** |

## Lace (`archer`, source Myth; was Hem) · slice Warden

| Slot | Source | Ours | Verdict | Re-check 2026-11-10 (ext/release-integ-0244-fix ec3c9dafb, Training Area) |
|---|---|---|---|---|
| LMB | Hold to charge, release; perfect speeds next draw [D,F] | PinDraw two stages, reticle, stops at cursor, cadence .5, perfect → quick draw | match | Tap 0.1 s: 15 at 0.20 s at 6 m; Empowered 0.6 s: 30; Supercharged 1.15 s: 60; overdraw 1.65 s: half. Shots at least 0.60 s apart at 0.1 s press steps (rate 0.5); perfect window opens at +0 and closes by +0.19 s (+0.13 s counts). **match** |
| RMB | Hold, release, knock, wall stun up to 173 extra on 35 [D] | Hold .5 dead zone (ours), wall_dmg 12, floor .4, stun 1.2, cd 16 | **differ**: payoff ~0.4x vs ~5x (gap 6) | A 0.1 s tap loosens nothing and costs no charge; 0.6 s hold 23, full 1.1 s 30, wall pin 178 on the shot (173 extra, 4.94x); stun 1.2 s; cd 16 s; 38% speed while held. Gap 6 closed. **match** |
| Q | none | glove | ours | not measured (ours) |
| E | Cone of arrows, slow, anti-heal, 15 s [D] | Tell .35, 4.4 s, slow 35%, curved wall, cd 15 | match | First tick 0.38 s (tell 0.35), 5 per tick, 8 ticks in 4.4 s at 0.52 s (gap C); slow 35%, cd 15 s. **match** |
| R | 3 empowered shots, no charge, 60 s [D] | 3 shots, window 6 s, nock .3, cd 60 | match | First beam 0.90 s after the press and fire held (nock 0.5); 18, 18, 25 (finisher under 12%), 1.52 s apart (footage 1.5), cd 60 s. **match** |
| Dash | Roll to cursor, then Phase Walk through terrain incl. raised walls, 9.5 s [D] | Roll 3 m/.27 s (F), off the dash feel; walks rocks and barriers, **not ledges** | differ (gap 8) | Roll 3.03 m, 98% by 0.37 s (data 3.0/.27), cd 9.5 s; Spirit Walk passes rocks and terrace walls (combo PASS). Gap 8 closed on terraces. dash-flow rows 0 fail. **match** |
| Passive | Fog vision of injured; tall-ledge climb [D] | Hawk Sense 22 m; **Focus/Deadeye invented** | differ (gap 5); owner question open | Hawk Sense shows only the injured (PASS); Focus and Deadeye cut. **match** |
| Anim | Footage poses | 18 moves, all on `hem.glb` (48) | match on coverage | Draw, loose, perfect, overdraw, Heavy and ult clips all PASS by name. **match** |
| Flow | Silent on shooting in the walk [F] | Dash→LMB buffers; 8 of 17 rows unsourced | gap 9 | Draw and hold carry through a dash, jump out in 0.1 s (item 51 PASS). **match** |

## Cinder (`ashwick`, source Felix) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold, hose, ignite, % HP vs Ignited [D,F] | Hose stream (`ashwick_hose.gd`), range 7, .35 relight, no fuel; 31/s = 258 x 154/1285 (docs/TTK.md frame; Flashover bonus sized by `--ttk-check`) | match |
| RMB | Bolt + Slow, upgrades Ignite, 9 s [D] | Range 14, slow 30%, cd 7, +1 charge at rank 3; 13 dmg = 106 x 154/1285 | match; 0.78x cd |
| Q | none | glove | ours |
| E | Spin pull, shield per foe, knock resets, 13 s; ~.2 s arm fling [D,F] | Instant, r 4.5, pull 14 m/s, cd 10.5; 9 dmg = 76.8/106 x the bolt 13 | differ (owner item 11); damage ratio match |
| R | Fly forward, burning ground + Slow, 45 s [D] | 12.6 m/s, 1.8 s, trail 5.2 s, slow 30%, cd 36; carpet 4.5/s (source 239.2/s would be 28.7) | owner: burst cap (SERVER_UPDATE6) holds the carpet at 4.5/s; 0.8x cd |
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | 3.4 m/.33 s (F), air poof 6.8 m/.28 s, off the dash feel; stops on foe, 2 charges; 18 dmg = 150.4/106 x the bolt 13, tier IV +5 (+40) | match |
| E | Spin pull, shield per foe, knock resets, 13 s; ~.2 s arm fling [D,F] | Instant, r 4.5, pull 14 m/s, cd 10.5 | differ (owner item 11) |
| R | Fly forward, burning ground + Slow, 45 s [D] | 12.6 m/s, 1.8 s, trail 5.2 s, slow 30%, cd 36 | match; 0.8x cd |
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | Ground 3.4 m/.33 s, air poof 6.8 m/.28 s, both off the global feel (`dash_feel.json`), stops on foe, 2 charges | match; **closed** (gap 11): 2f24ae36b |
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | 3.4 m/.33 s (F), air poof 6.8 m/.28 s, off the dash feel; stops on foe, 2 charges | match |
| Passive | Ignite levels, bonus dmg [D] | Flashover 1/2, `ignite_bonus`, heal_knock .16 (wiki only) | match |
| Anim | Footage poses | 12 moves, all on `cinder.glb` (41 clips) | match on coverage |
| Flow | Silent | Dash→LMB `fire` (4e788af65); RMB, E (ground) buffer and X cancels, each cited | match |

## Meeko (`tender`, source Elluna)
| LMB | Hold, hose, ignite, % HP vs Ignited [D,F] | Hose stream (`ashwick_hose.gd`), range 7, .35 relight, no fuel | match |
| RMB | Bolt + Slow, upgrades Ignite, 9 s [D] | Range 14, slow 30%, cd 7, +1 charge at rank 3 | match; 0.78x cd · cd **open** (gap 10) |
| Q | none | glove | ours |
| E | Spin pull, shield per foe, knock resets, 13 s; ~.2 s arm fling [D,F] | Instant, r 4.5, pull 14 m/s, cd 10.5 | differ (owner item 11) · **owner** |
| R | Fly forward, burning ground + Slow, 45 s [D] | 12.6 m/s, 1.8 s, trail 5.2 s, slow 30%, cd 36 | match; 0.8x cd · cd **open** (gap 10) |
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | 3.4 m/.33 s (F), air poof 6.8 m/.28 s, off the dash feel; stops on foe, 2 charges | match |
| Passive | Ignite levels, bonus dmg [D] | Flashover 1/2, `ignite_bonus`, heal_knock .16 (wiki only) | match |
| Anim | Footage poses | 12 moves, all on `cinder.glb` (41) | match on coverage |
| Slot | Source | Ours | Verdict | 0.24.4 main (11-12) |
|---|---|---|---|---|
| LMB | Hold, hose, ignite, % HP vs Ignited [D,F] | Hose stream (`ashwick_hose.gd`), range 7, .35 relight, no fuel | match | still done; owner retune 11-10 (632de4b22): reach 7 to 6.1 m, stream .65 to 2.85 m wide, combo check 125 PASS |
| RMB | Bolt + Slow, upgrades Ignite, 9 s [D] | Range 14, slow 30%, cd 7, +1 charge at rank 3 | match; 0.78x cd | still done (range 14, slow 30%, cd 7, rank 3 +1 charge) |
| Q | none | glove | ours | ours |
| E | Spin pull, shield per foe, knock resets, 13 s; ~.2 s arm fling [D,F] | Instant, r 4.5, pull 14 m/s, cd 10.5 | differ (owner item 11) | still differ (owner item 11); r 4.5, pull 14, cd 10.5 unchanged |
| R | Fly forward, burning ground + Slow, 45 s [D] | 12.6 m/s, 1.8 s, trail 5.2 s, slow 30%, cd 36 | match; 0.8x cd | still done (12.6 m/s, 1.8 s, trail 5.2 s, slow 30%, cd 36) |
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | 3.4 m/.33 s (F), air poof 6.8 m/.28 s, off the dash feel; stops on foe, 2 charges | match | still done (3.4 m/.33 s, air 6.8 m/.28 s, off the dash feel) |
| Passive | Ignite levels, bonus dmg [D] | Flashover 1/2, `ignite_bonus`, heal_knock .16 (wiki only) | match | still done (Flashover, heal_knock .16) |
| Anim | Footage poses | 12 moves, all on `cinder.glb` (41) | match on coverage | still done (`cinder.glb` 41 clips) |

## Meeko (`tender`, source Elluna; was Pip)

**0.24.5:** tender-combo 104/0. Carrier shield gone and the 4 s drop lock stand. Open (fix not on the line): Empowered range and `self_k` (ext/parity-no-riders-meeko); cooldowns RMB 10.5, E 11, R 46 vs 11.5, 12, 60 (ext/cooldown-parity-verify).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Ramp per hit; idle shot Empowered [D] | Rate .4, Empowered +40% range (ours) | match; range bonus ours |
| RMB | Shot, delayed Root, 11.5 s [D] | Burrseed: wind-up 1.0, seed delay .7, root 1.1, range 14, cd 10.5 | differ `[?]` motion; pending `ext/meeko-rmb-verify` eba7147eb (checked vs footage: press to seed ~0.36 s, root 1.1 s match; cd 10.5 vs 11.5 and tap vs hold-aim stay open) |
| Q | none | glove | ours |
| E | 2.5 s zone, burst, throw, attaches, 12 s [D] | 2.5 s, r 2.6, throw, cd 11, self_k .33 (ours) | match |
| R | Channel on ally/Wisp; revive and pull; cancels on stun, knock, range; 60 s [D] | Tether 5 s, range 12.6, cd 46 | match in shape; 0.77x cd |
| Dash | Ground 7 s, air 14 s, separate [D] | 7 s and 14 s, raw 4.2 m/.174 s and 13.3 m/.95 s, air steer (owner) | match |
| Passive | Carry Wisps; damage or stun drops, 4 s lockout [D] | Carry up to 2, a hit or stun drops them, lock 4 s; Carrier shield removed | match; **closed** (gap 19, Meeko's share): 3bcb50eca |
| Anim | Footage poses | 16 moves, all on `pip.glb` (45 clips) | match on coverage |
| Flow | Silent | Dash→LMB buffers (cited), RMB, E, X, Q `fire`; 3 `keep` rows unsourced `[?]` | pending `ext/flow-rows-source` dd2c83be5 |
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered = cue only (no range, no refund) | match; Empowered effect is not in the source, our rider removed |
| RMB | Shot, delayed Root, 11.5 s [D] | Hop form, windup 1.0, cd 10.5 | differ `[?]` motion |
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered +40% range (ours) | match; range bonus ours |
| RMB | Shot, delayed Root, 11.5 s [D]; wiki 2 s delay | Hop form, windup 1.0, cd 10.5; roots after 2 s of the foe within 15 m (owner 11-10), unwinds 2x out of it | differ `[?]` motion |
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered +40% range (ours) | match; range bonus ours · **open** (branch ready: ext/parity-no-riders-meeko) |
| RMB | Shot, delayed Root, 11.5 s [D]; wiki 2 s delay | Hop form, windup 1.0, cd 10.5; roots after 2 s of the foe within 15 m (owner 11-10), unwinds 2x out of it | differ `[?]` motion · **owner** (11-10) |
| Q | none | glove | ours |
| E | 2.5 s zone, burst, throw, attaches, 12 s [D] | 2.5 s, r 2.6, throw, cd 11, no self factor | match |
| R | Channel on ally/Wisp; revive and pull; cancels on stun, knock, range; 60 s [D] | Tether 5 s, range 12.6, cd 46 | match in shape; 0.77x cd |
| Dash | Ground 7 s, air 14 s, separate [D]; ally pass refunds half the cd + 1 s E only on the footage card's Super (older build), absent at every rank in [D] | 7 s and 14 s, 3.6 m/.2 s (F) and 13.3 m/.95 s (F), off the dash feel, air steer (owner); no ally refund | match; ally refund `[?]` (tender.md "Ally-pass refund") |
| Passive | Carry Wisps; damage or stun drops, 4 s lockout [D] | Carry up to 2 + Carrier shield (ours) | differ: shield ours. Drop lockout built (lock 4 s); which hits drop not traced |
| Dash | Ground 7 s, air 14 s, separate [D] | 7 s and 14 s, 3.6 m/.2 s (F) and 13.3 m/.95 s (F), off the dash feel, air steer (owner) | match |
| Passive | Carry Wisps; damage or stun drops, 4 s lockout [D] | Carry up to 2; the Carrier shield is cut (owner 11-07) | match. Drop lockout built (lock 4 s); which hits drop not traced |
| E | 2.5 s zone, burst, throw, attaches, 12 s [D] | 2.5 s, r 2.6, throw, cd 11, self_k .33 (ours) | match · self_k **open** (branch ready: ext/parity-no-riders-meeko) |
| R | Channel on ally/Wisp; revive and pull; cancels on stun, knock, range; 60 s [D] | Tether 5 s, range 12.6, cd 46 | match in shape; 0.77x cd · cd **open** (gap 10) |
| Dash | Ground 7 s, air 14 s, separate [D] | 7 s and 14 s, 3.6 m/.2 s (F) and 13.3 m/.95 s (F), off the dash feel, air steer (owner) | match |
| Passive | Carry Wisps; damage or stun drops, 4 s lockout [D] | Carry up to 2 + Carrier shield (ours) | differ: shield ours. Drop lockout built (lock 4 s); which hits drop not traced · shield **done** `ext/parity-no-riders` (main); drop triggers **done** `ext/meeko-carry-drop-rebased` (stun, or damage past the shield) |
| Anim | Footage poses | 16 moves, all on `pip.glb` (45) | match on coverage |

## Tenzo (`dolm`, source Tetra)
## Tenzo (`dolm`, source Tetra; was Tarek)

**0.24.5:** dolm-combo 172/0. Ally hop stands; cooldowns 11, 12.5, 45, 12 already match the source. Open: rock and Rock Hop slows, punch charge scaling (ext/parity-tenzo-rock-slows, ext/parity-no-riders-grimble-tenzo).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Tap boulder; hold punch launches rocks, .6 s [D] | Boulder .6, punch .7 (step .6) | match |
| RMB | Hold slam, centre stun, jump to leap, 11 s [D] | Hold .2, cd 11, glide slam at 32.5 m/s | match |
| Q | none | glove | ours |
| E | Three rocks, allies hop by jumping, ~12.5 s [D] | Stone Row, cd 12.5; an ally jumping against a rock hops it, walking and foes are stopped (`--dolm-combo-check`) | match; **closed** (gap 14): 5968c387e; the audit missed it |
| E | Three rocks, allies hop by jumping, ~12.5 s [D] | Rock wall, cd 12.5; allies hop it by jumping (owner 23:55, `StoneStand`) | match (gap 14 closed) |
| E | Three rocks, allies hop by jumping, ~12.5 s [D] | Rock wall, cd 12.5; allies hop by jumping (eb93c5b62), bots too (618098895) | match (gap 14 closed) |
| R | Tap wall, hold drag angle, Slows, 45 s [D] | 9 rocks, drag, cd 45, slow data present | differ (owner item 15 said rocks only) |
| Dash | Landslide: dash, launches rock, ~12 s [D] | Rock Hop: 3 hops, cd 12 | differ (owner item 111) |
| Passive | Punching rocks grants Shield [D] | Molten Guard, built; charge scaling ours | match |
| Anim | Footage poses | 17 moves, all on `tarek.glb` (48 clips) | match on coverage; hand polish pending `ext/anim-hand-tenzo` f44d76294 |
| Flow | Silent | Dash→LMB, →RMB, air LMB `fire` (4e788af65); 6 `keep` rows unsourced `[?]` | match; sources open |
| Dash | Landslide: dash, launches rock, ~12 s [D] | Rock Hop: 3 hops of 2.8 m/.26 s raw ×.85/×1.15 = 2.4 m/.3 s, cd 12 | differ (owner item 111) |
| Passive | Punching rocks grants Shield [D] | Built; charge scaling ours | match |
| E | Three rocks, allies hop by jumping, ~12.5 s [D] | Rock wall, cd 12.5; **no ally hop** | missing: ally hop (gap 14) · **done** `ext/tenzo-ally-hop`: an ally clears a teammate's rock (bots hop at once), asserted |
| R | Tap wall, hold drag angle, Slows, 45 s [D] | 9 rocks, drag, cd 45, slow data present | differ (owner item 15 said rocks only) · **owner** |
| Dash | Landslide: dash, launches rock, ~12 s [D] | Rock Hop: 3 hops of 2.8 m/.26 s raw ×.85/×1.15 = 2.4 m/.3 s, cd 12 | differ (owner item 111) · **owner** |
| Passive | Punching rocks grants Shield [D] | Built; charge scaling ours | match · charge scaling **open** (branch ready: ext/parity-no-riders-grimble-tenzo) |
| Anim | Footage poses | 17 moves, all on `tarek.glb` (48) | match on coverage |

## Grimble (`dredge`, source Kingpin)

**0.24.5:** dredge-combo 112/0. Air slot 12.5 s stands. Open: E Grounds the foe (ext/parity-no-riders-grimble-tenzo); cooldowns 12, 7, 21 vs 18, 12, 36 (ext/grimble-parity-verify, ext/cooldown-parity-verify).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | 7 slugs, bloom [D]; [F] fan 20 rested, 30 firing, fixed stop ~3.5 bh, no falloff with range | 7 slugs, the first volley of a burst on the aim line (owner 11-10), then fan 20 + bloom to 30 (was 30 + 15, fixed), stop 6.3 m, no falloff; aimed volley 14.0 at 2, 6 and 6.2 m; a 30 degree volley 14.0 at 2 m, 8.9 (3 slugs) at 6 m and 6.2 m, asserted in `--dredge-combo-check` | match |
| RMB | Arm pierces terrain, pulls first target, 18 s [D] | 11.5 m through terrain, reel, 20% braced shuffle, cd 12 | match; 0.67x cd |
| LMB | 7 slugs, bloom [D] | Seven-slug blast, slugs hang at 6.3 m, bloom folds back 0.7 s after the last shot | match |
| RMB | Arm pierces terrain, pulls first target (enemy or ally), scoops Wisps, 18 s [D] | Abyssal Hand: 11.5 m through rocks and cliffs (a placed wall stops it), reel, braced shuffle at 1/5 walk, ally and Wisps caught, cd 12 | match; 0.67x cd (gap 10) |
| LMB | 7 slugs, bloom [D] | Seven-slug blast, bloom | match |
| RMB | Arm pierces terrain, pulls first target, 18 s [D] | 11.5 m through terrain, reel, 20% braced shuffle, cd 12 | match; 0.67x cd · cd **open** (gap 10) |
| Q | none | glove | ours |
| E | Slam, stun, dunk, 12 s [D] | Anchor Drop: windup .38, r 3, 25 dmg, stun 1.1, air dive ring 3.2 m, rank 3 double over the abyss, cd 7, Grounded (ours) | match; **0.58x cd** (gap 10) |
| R | Two waves, 36 s [D] | Brass Broadside: charge 1.1, 2 waves of 6 slugs, 4 dmg + Anti-Heal 3 s, cd 21 | match; **0.58x cd** (gap 10) |
| Dash | One every 7 s; own air slot 12.5 s [D] | Barge: 3 chained shoves, cd 10. Air pounce 35% further, 3.7 m with the dash feel applied once, **own 12.5 s slot, 2 s less per rank** | differ (owner): 3 charges, cd 10 vs 7. Air slot closed `0a5b33f48`, double scale closed `2f24ae36b` |
| Passive | Stacks of max HP [D] | Salvage 10, +2.5% each, lose 1 on down, knock heals 16%; hits on a back +50% (ours) | match; back bonus ours |
| Anim | Footage poses | 13 moves plus the fusion move, all on `dredge.glb` (40 clips); hook-arm v2 model `315cdf2af` | match on coverage |
| E | Slam, stun, dunk, 12 s [D] | Windup .38, r 3, stun 1.1, cd 7, Grounded (ours) | match; **0.58x cd** |
| R | Two waves, 36 s [D]; [F] 6-7 orbs, ~120 degrees, ~756 a close volley against 193 for the gun | Charge 1.1, 2 waves of 6, 105 degrees, 4 a slug (3.4x a gun volley, burst cap), no falloff, cd 21 | match; **0.58x cd**; damage ratio 3.4x vs 3.9x is held by the burst cap |
| E | Slam, stun, dunk, 12 s [D] | Windup .38, r 3, stun 1.1, cd 7 | match; **0.58x cd** |
| R | Two waves, 36 s [D] | Charge 1.1, 2 waves, cd 21 | match; **0.58x cd** |
| Dash | One every 7 s; own air slot 12.5 s [D] | 3 chained, 3.2 m/.16 s raw (owner 23:40; F 4.6 m/.12 s) ×.85/×1.15 = 2.7 m/.18 s, air ×1.35 = 3.7 m (scaled once), cd 10, air on its own 12.5 s slot (0a5b33f48) | differ (owner); gap 13 closed |
| E | Slam, stun, dunk, 12 s [D] | Windup .38, r 3, stun 1.1, cd 7, Grounded (ours) | match; **0.58x cd** · cd **open** (gap 10); Grounded **open** (branch ready: ext/parity-no-riders-grimble-tenzo) |
| R | Two waves, 36 s [D] | Charge 1.1, 2 waves, cd 21 | match; **0.58x cd** · cd **open** (gap 10) |
| Dash | One every 7 s; own air slot 12.5 s [D] | 3 chained, 3.2 m/.16 s raw (owner 23:40; F 4.6 m/.12 s) ×.85/×1.15 = 2.7 m/.18 s, air ×1.35 = 3.7 m (scaled once), cd 10, air shares slot | differ (owner); air slot missing (gap 13) · **owner**; air slot **done** `ext/parity-grimble-airdash` (main): `dash.air.cd` 12.5, 2 s less a rank |
| Passive | Stacks of max HP [D] | Salvage 10, +2.5%, lose 1 on down | match |
| Anim | Footage poses | 13 moves, all on `dredge.glb` (40) | match on coverage |

## Neve (`rimewright`, source Celeste)
## Neve (`rimewright`, source Celeste; was Claire)

**0.24.5:** rimewright-combo 116/0. Chill 4 s with no slow and the late skating homing stand. Open: E cd 17 vs 20 (ext/cooldown-parity-verify).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold, semi-homing, 3 heavy at end of burst, 0.5 s barrage cd [D]; one uniform stream while held [F] | Hold = one burst of plain darts (0.18 s), 3 large on the let-go, 0.5 s pause; skating: beams, semi-homing, 2x damage | match (burst); skating darts 2x (wiki, `dash.skate_dart_dmg_k`; footage 1.6x, no data number); skating beams semi-homing (owner, gap 16 done) |
| LMB | Hold, semi-homing, 3 heavy at end [D] | 4 plain + 3 large darts; they leave along the aim, then curve onto the foe at the cursor over 35 to 70% of the flight. **Skating beams home the same way** after leaving straight on the aim | match; gap 16 closed `e5c73480c` (bend assert pending `ext/parity-neve-skate-home` 9b65ea7f1) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Ice Spear: pushed out to the cursor (12 m), 18 dmg, 2.2 m slow zone 35%, bursts 60 at 1.8 s, 2 charges, cd 10.2 | differ (owner: push-like release); 0.85x cd |
| Q | none | glove | ours |
| E | Wall pushes, recast freezes, 20 s [D] | Rink Wall: 0.2 s tell, slides 4.5 to 16.2 m, grows 1.8 to 4.5 m, 70 HP, E again freezes 6 s, cd 17 | match; 0.85x cd |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Rimelock: hold 3.5, skate carry .8 (owner), 40 dmg + 0.75 s stun, early recast cancels, cd 80 | match |
| Dash | Hold, release stops, 13 s; ice islands over the abyss [D] | Skate 11.5 m/s (F 10 to 11), up to 1.6 s, early-release refund .6 (owner), ice ribbon in the air, cd 13 | match; refund owner |
| Passive | Chill 4 s, shatter on knock [D] | Hoarfrost: Chill 4 s, 8 darts shatter, knock shatters. **Chill slow removed** | match; closed `3bcb50eca` |
| Anim | Footage poses | 19 moves plus the fusion move, all on `claire.glb` (49 clips); v2 model `59ac7b48d` | match on coverage |
| Body | 1.1 to 1.15 [F] | size 1.014 (1.56 m, owner height chart `4538174a8`) | differ (owner) |
| LMB | Hold, semi-homing, 3 heavy at end [D] | 4 plain + 3 large; straight while skating | match; skate tracking owner question (gap 16) · **done** `ext/parity-neve-skate-home`, `ext/neve-dart-homing`: late homing while skating, asserted |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2 | differ (owner) · **owner** |
| LMB | Hold, semi-homing, 3 heavy at end [D] | 4 plain + 3 large; straight, 2x damage while skating | match; skating darts 2x (wiki, `dash.skate_dart_dmg_k`; footage 1.6x, no data number); skate tracking owner question (gap 16) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2; detonation 22 = 190/156 x hit 18 | differ (owner); damage ratio match |
| LMB | Hold, semi-homing, 3 heavy at end of burst, 0.5 s barrage cd [D]; one uniform stream while held [F] | Hold = one burst of plain darts (0.18 s), 3 large on the let-go, 0.5 s pause; skating: beams, semi-homing, 2x damage | match (burst); skating darts 2x (wiki, `dash.skate_dart_dmg_k`; footage 1.6x, no data number); skating beams semi-homing (owner, gap 16 done) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2 | differ (owner) |
| Q | none | glove | ours |
| E | Wall pushes, recast freezes, 20 s [D] | Slide, grow, freeze, 200 HP (~50 own darts), cd 17 | match; 0.85x cd |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Hold 3.5, carry .8 x1.05 speed (owner), rink 4 bh +15% (owner), body as ice, cd 80; crash 18 = 155/156 x spear hit 18 | match; +15% radius, +5% slide (owner 11-08) |
| Dash | Hold, release stops, 13 s [D] | 11.5 m/s (F 10-11), 1.6 s, early-release refund .6 (owner) | match; refund owner |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2 | differ (owner) |
| Q | none | glove | ours |
| E | Wall pushes, recast freezes, 20 s [D] | Slide, grow, freeze, 200 HP (~50 own darts), cd 17 | match; 0.85x cd |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Hold 3.5, carry .8 x1.05 speed (owner), rink 4 bh +15% (owner), body as ice, cd 80 | match; +15% radius, +5% slide (owner 11-08) |
| Dash | Hold, release stops, 13 s [D] | 10.5 m/s (F 10-11, the mean), 1.6 s, early-release refund .6 (owner) | match; refund owner |
| Passive | Chill 4 s, shatter on knock [D] | Chill + 15% slow (ours) | differ: slow ours |
| E | Wall pushes, recast freezes, 20 s [D] | Slide, grow, freeze, 200 HP (~50 own darts), cd 17 | match; 0.85x cd · cd **open** (gap 10) |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Hold 3.5, carry .8 x1.05 speed (owner), rink 4 bh +15% (owner), body as ice, cd 80 | match; +15% radius, +5% slide (owner 11-08) · **owner** |
| Dash | Hold, release stops, 13 s [D] | 11.5 m/s (F 10-11), 1.6 s, early-release refund .6 (owner) | match; refund owner |
| Passive | Chill 4 s, shatter on knock [D] | Chill + 15% slow (ours) | differ: slow ours · **done** `ext/parity-no-riders` (main): slow cut; `ext/neve-chill-shatter` asserts Chill 4 s and the knock Shatter |
| Anim | Footage poses | 19 moves, all on `claire.glb` (49) | match on coverage |
| Body | 1.1-1.15 [F] | size 1.15 | match |

## Motley (`ostra`, source Void)
## Motley (`ostra`, source Void; was Ostra)

**0.24.5:** ostra-combo 213/0. Bomb 3.5x stands. Open: the 10 s seed fizzle (ext/motley-seed-fizzle); floats `[?]` and the orb slow stay owner/untraced.

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Orb; idle next orb stronger, terrain, Slow [D] | Tether Lantern: 9 dmg every 0.6 s, 14 m; waiting up to 1.4 s makes the next +34% with a Slow; every orb pierces terrain | differ (owner items 60, 117; data overruled) |
| RMB | Shards, stun, 10 s [D] | Shard Snap: wind-up .32 vs .2, 13 m, stun .8 to 1.8 s by flight, cd 10 | differ (owner item 40) |
| LMB | Orb; idle next orb stronger, terrain, Slow [D] | .6, continuous charge to 1.4 s, every orb pierces | differ (owner items 60, data overruled) · **owner** |
| RMB | Shards, stun, 10 s [D] | cd 10, wind-up .32 vs .2 | differ (owner item 40) · **owner** |
| Q | none | glove | ours |
| E | Bomb grows, reactivate, up to 3.5x [D] | Brimseed: grows 6.5 s, 12.5 dmg up to **3.5x**, fizzles 10 s (ours), cd 10 vs 8 | match; peak closed `5b9a528d2`; fizzle ours |
| R | Vortex stun + pull, 70 s [D] | Nightwell: tell 1.0, 3.5 s, r 3.6, pull 12, cd 70 | match; ~1 s lock (owner) |
| Dash | Lob, swap all units, faster when Empowered [D] | Lantern Trade: 12 m lob, 1.8 s (Swollen 1.25 s), drift 30%, moves foes and allies, cd 9.5 | match |
| Passive | Damage Empowers; floats [D] | Swell fills Swollen 9 s; floats, ground hazards turn him away (`hazards_dodged`) | match; footstep silence `[?]` |
| Anim | Footage poses | 15 moves plus the fusion move, all on `ostra.glb` (45 clips); v2 model `76f589389` | match on coverage |
| E | Bomb grows, reactivate, up to 3.5x [D] | Grows 6.5 s, dmg_max_k 3.0, fizzles 10 s (ours) | differ: 3x vs 3.5x, fizzle ours · 3.5x **done** `ext/parity-ostra-bomb` (main); fizzle 10 s **open** (ours) |
| E | Bomb grows, reactivate, up to 3.5x [D] | Grows 6.5 s, dmg_max_k 3.5, waits at full size until popped, no timer; cooldown on the plant [?] | match (the fizzle is removed) |
| R | Vortex stun + pull, 70 s [D] | Tell 1.0, 3.5 s, pull 12, cd 70 | match; ~1 s lock (owner) |
| Dash | Lob, swap all units, ~9.5 s [D] | 1.8 s lob, drift at 67.5% speed (owner 11-08, halved slow 11-10; source gives no drift), moves foes and allies (counters both) | match |
| Passive | Damage Empowers; floats [D] | Swollen variants | match; floating `[?]` |
| Dash | Lob, swap all units, ~9.5 s [D] | 1.8 s lob, drift 30%, moves foes and allies (counters both) | match |
| Passive | Damage Empowers; floats [D] | Swollen variants | match; float = no footsteps + ground hazards pass him [D] (wiki: water/sand, none on our maps); no gap hover, slower fall or landing change in any source, so none built |
| Dash | Lob, swap all units, ~9.5 s [D] | 1.8 s lob, drift 35% (owner 11-08 +17%; source gives no drift), moves foes and allies (counters both) | match |
| Passive | Damage Empowers; floats [D] | Swollen variants | match; floating `[?]` · **open** [?] (the body hovers 0.3 m; a gameplay float not traced) |
| Anim | Footage poses | 14 moves, all on `ostra.glb` (45) | match on coverage |

## Albert (`bulwark`, source Oath)
## Albert (`bulwark`, source Oath; was Bjorn)

**0.24.5:** bulwark-combo 166/0. Throw rate 0.45 and E zone 2.3 m stand (the E row's r 3.5 is stale text). Open: Guard meter and Shield Slam, Crushing Blow stun 0.4, aegis routing (ext/albert-parity-verify, ext/parity-albert-blow-stun, ext/combat-albert-aegis-input); R cd 40 vs 50 (ext/cooldown-parity-verify).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Throw + recall; hold charged swing [D] | Tap whirl hold (owner), carry 1.5-1.8 m + perfect launch 4 m (owner #30, #49), cadence .45 on every press (recall too: TTK 1.16x), walks 55% vs stands | differ (owner) |
| RMB | Hold shield, front block, Shift = bash 198 = 1.03x throw, 6 s [D] (supervive_kits.md:89-90) | hold .1, aegis, bash 12.4 (0.95x throw 13), cd 6 | match; routing `[?]` |
| LMB | Throw + recall; hold charged swing [D] | Tap throws and recalls (cadence **.45**), hold is the source's wind-up, swing 36 to 66. Owner-kept: walks 55% while charging (#59), 1.5 to 1.8 m step + 4 m perfect launch (#30, #49) | match; riders differ (owner). Cadence `1eecee8c3`, hold `e625aa8e0`, hold-walk assert `9c336682d` |
| RMB | Hold shield, front block, Shift = bash, 6 s [D] | Aegis hold .1, 160 HP, Shield Charge on Shift, cd 6 | match; routing `[?]` |
| LMB | Throw + recall; hold charged swing [D] | Tap whirl hold (owner), carry 1.5-1.8 m + perfect launch 4 m (owner #30, #49), cadence .45 (1eecee8c3), walks 55% vs stands | differ (owner); cadence matches (gap 12 closed) |
| RMB | Hold shield, front block, Shift = bash, 6 s [D] | hold .1, aegis, bash cd 6 | match; routing `[?]` |
| LMB | Throw + recall; hold charged swing [D] | Tap whirl hold (owner), carry 1.5-1.8 m + perfect launch 4 m (owner #30, #49), cadence .48 vs .45, walks 55% vs stands | differ (owner); cadence S fix (gap 12) · **owner**; cadence **done** `ext/parity-mossy-cadence` (main): `throw_rate` 0.45 |
| RMB | Hold shield, front block, Shift = bash, 6 s [D] | hold .1, aegis, bash cd 6 | match; routing `[?]` · **open** on the candidate (`ext/mossy-shield-bash`, `ext/parity-aegis-block` merged); closed on ext/combat-albert-aegis-input (branch ready) |
| Q | none | glove | ours |
| E | Zone around hammer, burst, Wisps, 8 s @IV [D] | Mending Ground: r 3.5, delay 1, 4 s, burst, cd 12/8 | match |
| R | Fissure stun, AoE, heavy Slow, 50 s [D] | Faultline: 4 cells, stun .5, cd 40 | match; 0.8x cd |
| Dash | Spin Dash 8 s, knock [D] | 360 Smash 3.5 m, cd 8 | match |
| Passive | Wall knock Stuns [D] | Crushed built. **Guard meter and Shield Slam still on main** | differ (gap 15): pending `ext/parity-bulwark-guardcut` b2e942eb4 (also in `ext/misc-ready-integ` 55446e046) |
| Anim | Footage poses | 17 moves plus the fusion move, all on `breaker.glb` (48 clips) | match on coverage |
| E | Zone around hammer, burst, Wisps, 8 s @IV [D] | r 3.5, delay 1, 4 s, burst, cd 12/8 | match |
| R | Fissure stun (31 = 0.16x throw), AoE series 396 = 2.06x, heavy Slow, 50 s [D] (supervive_kits.md:93) | 4 cells, strike 1.9 (.16x), eruption 24.8 (2.06x), stun .5, cd 40 | match; 0.8x cd |
| R | Fissure stun, AoE, heavy Slow, 50 s [D] | 4 cells, stun .5, cd 40 | match; 0.8x cd · cd **open** (gap 10) |
| E | Zone around hammer, burst, Wisps, 8 s @IV [D] | r 2.3, delay 1, 4 s, burst, cd 12/8 | match |
| R | Fissure stun, AoE, heavy Slow, 50 s [D] | 4 cells, stun .5, cd 40 | match; 0.8x cd |
| Dash | Spin Dash 8 s, knock [D] | Whirl 3.5 m/.17 s (F), off the dash feel, cd 8 | match |
| Passive | Wall knock Stuns [D] | Built; **Guard meter, Shield Slam invented** | differ (gap 15); owner question open · **open**: Guard and `resource.slam` still in `bulwark.json`; branch ready: ext/parity-bulwark-guardcut (owner 11-07 said cut) |
| Anim | Footage poses | 17 moves, all on `breaker.glb` (48) | match on coverage |

## Sparkle (`mage`, source Joule)
## Sparkle (`mage`, source Joule; was Ryzz)

**0.24.5:** mage-combo 143/0. Dash to LMB stands. Open: cooldowns RMB 8, E 10.5, R 42 vs 10, 12, 60 (ext/cooldown-parity-verify); Skycall radius 1.5 (ext/parity-skycall-size).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Bolt + Static, F .8 s [D,F] | Coilcaster: 12 dmg every .648 s, 13 m, stops on first foe, 1 Static | differ (owner items 70, 116) |
| RMB | Hold/release, knock, orb, 10 s [D] | Storm Rod: hold 1.0 (tap .33), 18 to 30 dmg, knock, stun on wall .8, 1 Static, charge orb, cd 8 | match; 0.8x cd |
| LMB | Bolt + Static, F .8 s [D,F] | .648, range 13, no pierce | differ (owner items 70, 116) · **owner** |
| RMB | Hold/release, knock, orb, 10 s [D] | Hold 1.0, cd 8 | match; 0.8x cd · cd **open** (gap 10) |
| Q | none | glove | ours |
| E | Press, or hold + drag aim, 12 s, 1 Static [D] | Skycall: delay .8, 20 dmg, slide 3.4, drag built, 1 Static, cd 10.5 | match; 0.88x cd |
| R | Launch, recast, crash, spreads Static, 60 s [D] | Kitefall: hover 1.7, crash 22, spread built, cd 42 | match; 0.7x cd |
| Dash | Press or hold, pass dmg, reset on 4 Static, 9 s [D] | Wirerun 40 m/s vs ~32 (owner), lane 7.5 to 13 m, dmg 20, Blowout reset, cd 8 | differ (owner) |
| Passive | Static, 4 stacks [D] | Static 4 stacks, 4.5 s, orb pickup resets Wirerun (items 71, 74) | match |
| Anim | Footage poses | 16 moves plus the fusion move, all on `ryzz.glb` (45 clips); v2 model `6355dee78` | match on coverage |
| Flow | Silent | Dash→LMB fires mid-dash (closed `4e788af65`); X row `[?]` | match; X unsourced |
| E | Press, or hold + drag aim, 12 s, 1 Static [D] | Drag built, delay .8, stacks 1, cd 10.5 | match |
| R | Launch, recast, crash, spreads Static, 60 s [D] | Hover 1.7, spread built, cd 42 | match; 0.7x cd |
| Dash | Press or hold, pass dmg, reset on 4 Static, 9 s [D] | Lane 5.6-9.75 m at 40 m/s (owner item 70, cut 11-10), time ×1.15 feel (felt ~35 m/s vs ~32), dmg 20, Blowout reset, cd 8 | differ (owner) |
| R | Launch, recast, crash, spreads Static, 60 s [D] | Hover 1.7, spread built, cd 42 | match; 0.7x cd · cd **open** (gap 10) |
| Dash | Press or hold, pass dmg, reset on 4 Static, 9 s [D] | Lane 7.5-13 m at 40 m/s (owner), time ×1.15 feel (felt ~35 m/s vs ~32), dmg 20, Blowout reset, cd 8 | differ (owner) · **owner** |
| Passive | Static, 4 stacks [D] | Built, orb reset closed by owner | match |
| Anim | Footage poses | 16 moves, all on `ryzz.glb` (45) | match on coverage |
| Flow | Silent | Dash→LMB `fire`, X buffer | gap 9 closed for LMB |
| Flow | Silent | Dash→LMB, X buffer | gap 9 · **done** `ext/parity-dashlmb` (main): LMB fires mid-dash; 5 rows unsourced **open** [?] |

## Sable (`thief`, source Shiv)

**0.24.5:** dancer-combo 144/0. LMB 8.5 m and no Shred stand. Open: cooldowns RMB 7, E 15, R 24 vs 13, 28, 50 (ext/cooldown-parity-verify); E range 14 `[?]` (ext/parity-ranges-rest).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Bolt, stacks passive [D] | Arc Shots .45, to the cursor, 12 m, 13 dmg | match; range unconfirmed |
| RMB | Bolas, Ground, two targets stun, 13 s [D] | Bola: 7 m, Ground 1.5 s, slow 30% (owner item 53), two foes stun .9 + 13, cd 7 | differ (owner); **0.54x cd** (gap 10) |
| LMB | Bolt, stacks passive [D] | .45, to cursor, 12 m, 13 dmg | match; range unconfirmed · **done** `ext/sable-lmb-range`: 8.5 m (9.5 empowered), bolt 37.5 m/s, asserted |
| RMB | Bolas, Ground, two targets stun, 13 s [D] | Bola 30% slow (owner item 53), cd 7 | differ (owner); **0.54x cd** · **owner**; cd **open** (gap 10) |
| Q | none | glove | ours |
| E | Dagger, 6 s forced return, 20 s @IV [D] | 14 m, 6 s, wall refund .25, foe .5, cd 15 | match; 0.75x of @IV |
| R | Barrage, edge bonus, resets dash, 50 s [D] | Encore: r 2.3 to 5.4, rim band blights, 10 blades in 2 s, gives the Vault back, cd 24 | match; **0.48x cd** (gap 10) |
| Dash | Dash, empower 2.34x, reset on hit, ~5 s [D] | Vault 4.5 m/.48 s (8.4 m from a jump), next shot 2.34x + 2 Marks, landing it resets, cd 4.5, off dash_feel | match |
| Passive | +16 per hit stacking; heal on knock [D] | Marks +10% each (16 of the 160 shot), no cap; knock heals 15% extra. **Shred gone** | match; closed `3bcb50eca` (stale text only) |
| Anim | Footage poses | 17 moves plus the fusion move, all on `sable.glb` (47 clips); v2 model `1c5d44fac` | match on coverage |
| E | Dagger, 6 s forced return, 20 s @IV [D] | 14 m, 6 s, cd 15 | match; 0.75x of @IV |
| R | Barrage, edge bonus, resets dash, 50 s [D] | Encore r 2.3-5.4, rim band, 10 shots, cd 24 | match; **0.48x cd** |
| Dash | Dash, empower 2.34x, reset on hit, ~5 s [D] | 4.5 m/.48 s, the same in the air (item 183), off the dash feel, prime 2.34x, cd 4.5 | match |
| Passive | +16 per hit stacking; heal on knock [D] | Marks; empowered Shred (ours) | differ: Shred ours `[?]` |
| E | Dagger, 6 s forced return, 20 s @IV [D] | 14 m, 6 s, cd 15 | match; 0.75x of @IV · cd **open** (gap 10; level 1 is 28 s) |
| R | Barrage, edge bonus, resets dash, 50 s [D] | Encore r 2.3-5.4, rim band, 10 shots, cd 24 | match; **0.48x cd** · cd **open** (gap 10) |
| Dash | Dash, empower 2.34x, reset on hit, ~5 s [D] | 4.5 m/.48 s, air 8.4 m/.95 s (F), off the dash feel, prime 2.34x, cd 4.5 | match |
| Passive | +16 per hit stacking; heal on knock [D] | Marks; empowered Shred (ours) | differ: Shred ours `[?]` · **done** `ext/parity-no-riders` (main): Shred was stale text, removed |
| Anim | Footage poses | 17 moves, all on `sable.glb` (47) | match on coverage |

## Gil (`gil`, no source hero) · 13th Hunter, 0.24.4

Ours only: there is no source row to compare, so every verdict is `ours` and the numbers below are the content values (`content/archetypes/gil.json`, measured shapes in docs/HITBOX_SIZE.md, time to knock in docs/TTK.md, bot use in docs/BOT_KIT_USE.md). `content/rules/kit_parity.json` has no Gil row for the same reason.

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | none | Fencer: two thrusts 7 and a lunge 11 (reach 2.5/2.5/3.2), rate 0.32 s, each steps forward, the third slows 30% 0.5 s | ours |
| RMB | none | Grab Bag: 5 potions (thunder 10 + stun 0.5 s, slime slow, gust, fire, Super Zeep), 2 charges, cd 5 s, tap 8 m, hold 12 m | ours |
| E | none | Riptide: 2 s spin (radius 2.2, tick 2 to 5), press again for a spout, 10 damage + 1 s knockup, cd 12 s | ours |
| R | none | Tidal Wave: 14 m, 18 damage, 1 s knockup then slow 50% 2 s, 40 shield, cd 90 s, unlock rank 6 | ours |
| Dash | none | Ground Swim: 6 m in 0.4 s, 4 damage, 0.5 s knockup, cd 8 s | ours |
| Passive | none | Fish Out of Water: three different potion marks in 5 s Beach a foe (stun 0.75 s, once per 8 s) | ours |
| Health | none | 124 (light weight), 0.80 of the roster mean | ours |

Measured outliers, not retuned: the swordfish chain reads one dummy at 0.8 m in `--hit-shape-check` against a 3.1 m content reach (as Kael and Tenzo read low too); his combo knocks in 5.0 to 7.7 s (the bag is shuffled, so it varies) against 1.3 to 4.2 s for the other combos with a source row, only Motley slower (docs/TTK.md); bots use Ground Swim about once per duel.
## Starter trio re-check: Vex, Kael, Lace (2026-11-10, ext/release-integ-0244-fix ec3c9dafb)

DECISIONS 2026-11-10: the first pick is Lace, Kael or Vex, so every new player touches these three. The last column of the three hero tables above is the re-measure, run in the Training Area (`Match.start({"training": true})`, a 10000 HP dummy, a clean `XDG_DATA_HOME`). The base is the release integration branch, not main: main has no `--kit-parity-check` or parity bench yet.

**Method.** Each number is read from the dummy's HP over 60 Hz steps (first hit after the press, hit sizes, gaps) and from the kit's cooldown table; dashes are the hunter's travel with no keys held, aimed along +x. The same driver was run on origin/main d255acbee: every LMB, RMB, E and R number is identical there, so the integration broke none of them. The only changes are the dash lengths (the merged dash-feel pass: Vex tap 4.32 to 4.85 m, Lace 3.35 to 3.03 m, Kael 3.99 to 4.14 m), all toward the sourced figures. `--parity-bench-check` 19 ok, 0 FAIL; the bench panel reads the same hit and status events.

**Cancels and buffers (docs/heroes/dash_interactions.md).** `--dash-flow-check` 0 failures (140 rows for the three, 14 skipped for all heroes). Kael: ground and air dash into LMB buffer to the dash's end (0.02 s after it), RMB fires mid ground dash and cancels the air dash into the Meteor Drop, E fires mid-dash and cancels out with Shift, X cancels the dash. Vex: every pair fires mid-dash, LMB, RMB, E and X keep running into a dash. Lace: every slot fires mid-dash, the draw carries through a dash, a jump or a hold lets go in the air.

**Owner notes.**
- Kael's Warchain: PASS. The chain pays out to 24 m as he backs away and holds taut there, the pull bends with a strafe or a look and slings when he backs away (combo check "jug chain").
- Kael RMB: PASS. Held 5 s it never fires; a release on the flash flings about 18% further (7.8 against 6.6 m).
- Lace's missed arrows linger: PASS. A spent arrow stays stuck in the ground at the cursor (`pin vfx` check).
- Vex Coin Blast and Palm Lance: **not on this branch**, gap A.

**Gaps, none an integration regression.**
- **A. Vex Coin Blast / Palm Lance (owner 11-08).** `content/archetypes/gunslinger.json:59` still "Burr Charge", `:92` still "Longneedle", fired from the rifle. The work is READY as ext/vex-coin-palm-1108 `0478765f6` (9 commits on ext/vfx-gunslinger) and was never merged into the integration or main.
- **B. Vex hold slide is 10.3 m, not 7.** `scripts/arch/kits/gunslinger_kit.gd:369-372`: a held Shift joins the slide at the tap's 0.18 s mark, after the skid has already gone about 3.2 m; `:392` then adds the data's 7 m. Main did the same (9.1 m). Source length for a hold `[?]`; decide whether the 7 m includes the skid.
- **C. Zone ticks run 0.52 s, not 0.5.** `scripts/arch/kits/gunslinger_ult.gd:181-183` (Cinderfall) and `scripts/arch/kits/archer_kit.gd:401-404` (Hail Wall) reset the tick timer and drop the remainder, so 0.5 s costs 31 frames. 3% slow, same on main. Keep the remainder (`+= every`) in both.

## Crowd control: every stun, root, Ground, slow, Daze and knock effect (main d255acbee, 2026-11-09)

Read from `content/archetypes/*.json` and the kit code. Source = the card text in `supervive_kits.md` [D] and the footage reads in `briefs/hero-ref` [F] (5 fps, so a read is good to about +-0.2 s). **The card gives no CC duration or strength except Ostra's (Snap 0.8 to 1.8 s, Black Hole 3.5 s, orb 6%) and the upgrade steps (Binding +0.3 s root, Primal Slam +0.1 s and +0.2 s stun).** Every other source row is a footage read or just the word "Slow", "Stun", "Daze". No silence and no knock-up (a launch that disables) is built anywhere, and none is in these 12 kits' cards except Oath's Faultline (queued, skipped). Self-slows (cast, charge, carry) are not CC and are left out. Albert's Faultline and Spin Dash are skipped (queued job). Sable's 30% bola slow stays (owner item 53).

| Hunter | Effect (ours) | Source | Verdict |
|---|---|---|---|
| Vex | Burr Charge Daze 1.4 s (only +38% rifle, +20% Railgun, no slow); wall slam: stun 0.7 s and Daze +0.6 s; Cinderfall zone slow 30% (0.6 s refreshed) | Daze about 1.2 s [F]; wall: "Dazed longer and Stunned" and zone "Slow", no numbers [D] | match (1.4 vs 1.2 is one frame at 5 fps) |
| Zedran | Meteor Drop: core stun 0.8 s, ring slow 40% 1.5 s | "Slow + 88 dmg; center hits Stun" [D], no numbers | match in shape |
| Zedran | Fireblast (full) slow 30% 1 s; Chain Lunge stun 0.35 s; Haul Slam stun 0.25 to 0.6 s | none: the tooltips list no slow on the blast and no stun on the chain | ours-only riders, see suggestions |
| Hem | Heartpiercer wall stun 1.2 s (rank 3: dash charge); Rain of Arrows slow 35% 0.8 s refreshed | "enemies that collide with terrain are Stunned", "Slow + Anti-Heal", no numbers; wall stun not shown cleanly [F] | match; numbers unsourced |
| Cinder | Cinder Shot slow 30% 1.5 s; Flue Flight carpet slow 30% 0.5 s refreshed | "Slow" on both [D]; dummy read SLOWED once, maybe the jump pad [F] | match; numbers unsourced |
| Pip | Burrseed root 1.1 s, +0.3 s at rank 3 | Root, +0.3 s upgrade [D]; root seen about 1 s or more [F] | match |
| Tarek | Punch wall stun 0.9 s; Volcano slam centre stun 0.5 to 1.2 s by charge; Basalt Spine slow 35% 1.0 s; rocks slow 30% 0.8 s; Rock Hop crash slow 30% 1.5 s | wall stun and centre stun, slam stun about 1 s [F]; Tetraform slows [D]; no number | match for the stuns and Spine; rock and hop slows are ours-only |
| Grimble | Anchor stun 1.1 s (+0.1 s a rank, +0.2 s rank 3); the hook's foe is stunned the whole reel (0.2 s refreshed), Grimble Grounded while reeling; no Ground after the Anchor (ours-only rider cut, DECISIONS 11-07) | Anchor stun 1.2 to 1.4 s [F]; +0.1 s and +0.2 s steps [D]; reeled foe stunned, caster Grounded [F] | match. Dredge gap 3 ("about a third", it was 0.45 s) is **closed**: 1.1 s is 80 to 90% of the read, inside footage error |
| Claire | Ice Spear zone slow 35% and hit slow 35% 0.6 to 0.8 s; Rimelock stun 0.75 s with a slow that builds 15% +12%/s to 55%; Rink Wall touch slow 30% 1 s; splinter slow 30% 1.2 s | Spear "slow zone", Ice Crash "slowing zone, stuns after a delay", slow stacks up to 3.5 s [D,F]; stun not legible, dummy encased about 0.5 s | match in shape; numbers unsourced |
| Ostra | Snap stun 0.8 to 1.8 s by flight; Nightwell stun and pull 3.5 s; full orb slow 6% 1.5 s | 0.8 to 1.8 s; 3.5 s; "slow 6% for 1.5 s" [D, in-game card text read in the footage] | Snap and Nightwell match. Orb slow fixed 10% to 6% (2026-11-11): the data file only says "Slows"; the card text is game text, so D outranks the wiki 10%; 1.5 s agrees. `lmb.prime_slow` 0.06, locked in kit_parity.json, asserted in `--ostra-combo-check`; reasoning in `docs/heroes/ostra.md` "Orb slow" |
| Albert | Crush (any knock into a wall): stun **1.0 s** (was 0.5), 8 damage; Shield Slam stun 0.6 s; full Crushing Blow stun 0.4 s | "Knocked into a wall, Stuns"; STUNNED label up about 1 s or more [F] | **fixed**: 0.5 to 1.0 s. Shield Slam and the blow's stun are ours (no source row) |
| Ryzz | Storm Rod wall stun 0.8 s; Skycall Grounded 1.5 s | Stun on a wall or second target [D]; Grounded 1.5 s or more [F] | match |
| Sable | Bola: first foe Grounded 1.5 s and slowed 30% (owner item 53); a pair stun 0.9 s; Shadow Knife slow 50% 2.5 s | Grounded, rings about 1.5 bh [F]; pair "Stunned", the label showed about 1.8 s [F]; knife "Slows" | match for Ground and slow; pair stun 0.9 kept: the footage has no two-foe tie (0115-0125 is one dummy and a tree, and a dummy never acts), so the 1.8 s is label time, not a stun; not measurable, frames and verdict in `docs/heroes/thief.md` "Pair stun length"; asserted in --dancer-combo-check |
| Sable | Bola: first foe Grounded 1.5 s and slowed 30% (owner item 53); a pair stun 0.9 s; Shadow Knife slow 50% 2.5 s | Grounded, rings about 1.5 bh [F]; pair "Stunned", the label showed about 1.8 s [F]; knife "Slows", 50% in the wiki row, no time anywhere (`docs/heroes/thief.md`, "Shadow Knife audit") | match for Ground and slow, knife time 2.5 s `[?]`; pair stun 0.9 vs 1.8 is noted in `docs/heroes/thief.md` as an owner pacing call, kept |

**Fixed in this change (1):** Albert's Crush stun 0.5 to 1.0 s (`content/archetypes/bulwark.json` `resource.crush_stun`, text and docs), asserted by `combo bulwark: a Crush stuns 1.0 s` in `--bulwark-combo-check`.

**Suggestions, not built (PARITY FIRST):**
- Zedran: drop the fireblast slow (`lmb.wave_slow`), the Chain Lunge stun and the Haul Slam stun (`rmb.haul.stun`): the source has no CC on them. Removing the Haul stun changes a documented move, so it needs the owner.
- Tarek: drop `rock.slow_*` and `dash.slow_t` (the source rocks shred armour, they do not slow).
- Albert: the Shield Slam stun 0.6 s and the Crushing Blow stun 0.4 s have no source row.
- Ostra: decide 10% (wiki) or 6% (card read) for the full orb slow. Sable: pair stun 0.9 or about 1.8 s (no footage clip can time it; needs a match clip with two tied foes).

## Moving while casting: the slice four (main 88b06b9e7, 2026-11-12)

Vex, Kael, Lace and Cinder, every held or cast ability (LMB hold, RMB hold or charge, E, R), the same columns as the
eight-Hunter table of ext/cast-move-eight. **Source** is the walk speed inside the ability's frame window in the hero sheet
(briefs/hero-ref on ext/agent-briefs), in px/s and body heights a second against that sheet's run plateau; the frames
themselves are not on this worker, so a row the sheet does not measure stays "not seen" and nothing moves. **Ours** is the
kit's `move_k` times the weapon's `fire_slow` / `draw_slow` (`Hunter._fire_slow`), a share of the run. A row is a fix
only when ours is off the source's band by more than 15%; owner rows keep the owner's number. The earlier RMB/E tables for
these four (ext/cast-move-a, ext/feel-cast-move, docs/heroes, never merged) are folded in here; their one fix, Kael's Lunge
charge walk, landed on main through the mc line (`rmb.lunge.walk_k` 0.8).

| Hunter (sheet, run) | Ability, phase | Source | Ours | Verdict |
|---|---|---|---|---|
| Vex `gunslinger` (venator.md, 110 px/s = 2.3 bh/s) | LMB rifle held | walks while firing, upper body on the cursor, "no visible slow" (0007-0023); no px/s inside the firing window | 1.0 (`quill_rifle.fire_slow`) | match (no slow shown); `--gunslinger-combo-check` "she keeps walking while she fires" |
| | RMB Burr Charge | a 0.2 s overhand throw, "the legs keep walking" | a tap, no hold (owner item 112); 1.0 | match (owner) |
| | E Longneedle, 0.6 s cast | stands still through the cast bar (555.8-556.4 s); then a 0.5 bh recoil shove and about 0.4 s of recovery | 0 for the cast (`e.self_slow` 1.0); free the step it fires, with the shove | match for the cast; the recovery walk is not measured; asserted "Vex cast-move" |
| | R Cinderfall | a tap; keeps walking and jumping while it falls (f103, a jump pad) | 1.0 | match |
| Kael `juggernaut` (juggernaut.md, 104 px/s median = 2.1 bh/s; plain runs 113-124) | LMB swings | "keeps walking while swinging" | 1.0 (greatsword, melee) | match |
| | LMB held, Searing Wave charge (0.6-1.0 s) | not measured (the white arc grows, 0087) | 0.55 past the 0.22 s tap | not seen; kept |
| | RMB tap, Finishing Slam wind-up (0.6 s) | not measured (blade cocked low, 0155-0157) | 0.6 | not seen; kept |
| | RMB held, Lunge charge | 85-95 px/s = 1.7-1.9 bh/s against 113-124 plain runs: 0.69-0.84 (0178-0181, 0198-0208) | 0.8 (`rmb.lunge.walk_k`) | match; asserted "juggernaut RMB hold: he walks at 80%" |
| | RMB air, Meteor Drop | hang, crash, about 0.5 s of low recovery; walk not measured | 0 airborne and 0.2 s planted, then 0.3 rising to 1.0 by 0.5 s | not seen; kept |
| | E Warchain, throw and hooked | no lock; the tether stays on while he walks about 2.5 s (0305-0317), no px/s | 1.0 | match (no slow shown) |
| | R Gilded Riposte | planted through the 0.6 s guard (f33-f38), recovered by f44 | 0 in the guard and strike, 0.5 through the 0.5 s recovery | match for the guard; the recovery walk is not measured |
| Lace `archer` (pin.md, 113 px/s = 2.05 bh/s) | LMB draw held | "walks slowly while drawing", body side-on (0111-0116); no px/s | 0.7 (`longbow.draw_slow`); 0.85 on the quick draw after a perfect | a slow is shown, its size is not measured; kept |
| | LMB, the 0.5 s after a shot | "she can walk between shots", no px/s | 0.8 (the ranged `fire_slow` default) | not measured; kept |
| | RMB Heavy Shot held | the draw pose, sunk lower (0494, f264); no px/s | 0.38 (`rmb.pin.hold_move`) | owner item 114 (slowed while holding RMB); the number is ours |
| | Shift Spirit Walk | 117-126 px/s = 2.1-2.3 bh/s against 113: 1.04-1.12 (0349-0356) | 1.1 (`dash.walk_k`) | match; asserted "pin cast-move" |
| | E Hail Wall | a tap, instant; the bow raised, no stop (f456, f496) | a 0.35 s lob tell, no lock; 1.0 | match |
| | R Starpiercer | a tap self-buff with no cast lock; "she can walk between shots" | 1.0; the empowered draws keep the LMB's 0.7 | match |
| Cinder `ashwick` (linwick.md, 205-230 px/s at 50 px/m = 4.1-4.6 m/s, 2.3-2.6 bh/s) | LMB stream held | walks while firing, "no visible slow" (0007-0019); no px/s | 1.0 (the kit runs the lance; no `fire_slow`) | match (no slow shown); `--ashwick-combo-check` "lance audit ... at his full walk" |
| | LMB, 0.35 s after letting go | not resolvable at 5 fps (sheet gap 12: "subtle", keep) | 0.6 (`lmb.slow_after`) | not seen; kept |
| | RMB Cinder Shot, lane held about 0.4 s, release | "does not stop moving" (0072-0137); a quick arm thrust | 1.0 | match; asserted "cinder cast-move" |
| | E Furnace Cloak | arms wide about 0.2 s, then the blast; walk not stated | instant on the press (owner item 11); 1.0 | match (no lock shown) |
| | R Flue Flight | a flight: about 500 px/s (10 m/s) for 1.6 s, the ult clip 9-10 bh in 1.3-1.4 s; walks on with no landing beat | the flight carries her (12.6 m/s for 1.8 s); 1.0 on landing | n/a for a walk factor; match on landing |

**Result:** no row is off by more than 15%, so no kit data moved. The two rows the sheets measure (Kael's Lunge charge
0.69-0.84 against 0.8, Lace's Spirit Walk 1.04-1.12 against 1.1) match; every other row either shows no slow where we have
none, or has no number. **Checks:** the four combo checks (`--gunslinger-combo-check`, `--juggernaut-combo-check`,
`--archer-combo-check`, `--ashwick-combo-check`) and `--move-feel-check`. **Footage to get:** a straight walk during Kael's
wave charge, Slam wind-up and Meteor recovery, Lace's draw and Heavy Shot hold, and Cinder's 0.35 s after the stream.
- Zedran: drop the fireblast slow (`lmb.wave_slow`), the Chain Lunge stun and the Haul Slam stun (`rmb.haul.stun`): the source has no CC on them. Removing the Haul stun changes a documented move, so it needs the owner. **Re-audit 11-11: open**, all three still in `juggernaut.json` / `juggernaut_kit.gd`.
- Tarek: drop `rock.slow_*` and `dash.slow_t` (the source rocks shred armour, they do not slow). **Open**: no branch; ext/parity-no-riders-grimble-tenzo removes only the punch charge scaling and Grimble's Ground.
- Albert: the Shield Slam stun 0.6 s and the Crushing Blow stun 0.4 s have no source row. **Open**: Shield Slam goes with ext/parity-bulwark-guardcut (branch ready); `lmb.smash_stun` 0.4 has no branch.
- Ostra: decide 10% (wiki) or 6% (card read) for the full orb slow. Sable: pair stun 0.9 or about 1.8 s. **Owner**, both unchanged.
- Ostra: full orb slow decided, 6% (card text = game data, over the wiki 10%), done 2026-11-11. Sable: pair stun 0.9 or about 1.8 s.

## Felt dash per kit (gap 4)

`content/rules/dash_feel.json` defaults to ×1 / ×1: a kit whose dash is the source's measured one runs it as-is. The owner's "slower and shorter" (×.85 distance, ×1.15 time) stays only where no source number exists; Ryzz gets the time part only (his lane is the owner's, item 70). Felt = raw × feel, measured in `--move-feel-check` (`felt dash` rows, ±5% / ±0.035 s) to the moment the dash ends: the step it ends in runs the dash for the time it had left, then the hand-over (on the ground the run, in the air the dash's speed carried on under drag, owner 11-08), and that tail isn't counted.

| Kit | Raw ground | Raw air | Sourced | Feel | Felt ground | Felt air |
|---|---|---|---|---|---|---|
| Vex | 4.8 m/.45 s tap | 4.7 m/.33 s (2/3 hold, patch notes) | F tap | ×1 | 4.8 m/.45 s | 4.7 m/.33 s |
| Zedran | 4.5 m/.17 s (+.07 dip) | class long dash | no (owner 113.8) | ×.85/×1.15 | 3.8 m/.2 s | ×feel |
| Hem | 3.0 m/.27 s roll | 5.0 m/.22 s flick (light long dash) | F roll | ×1, speed ×0.7 (owner item 9) | 3.0 m/.39 s | 5.0 m/.22 s |
| Cinder | 3.4 m/.33 s | 6.8 m/.28 s | F | ×1 | 3.4 m/.33 s | 6.8 m/.28 s |
| Pip | 3.6 m/.2 s | 13.3 m/.95 s glide | F | ×1 | 3.6 m/.2 s | 13.3 m/.95 s |
| Tarek | 2.8 m/.26 s hop | class long dash | no (owner item 111) | ×.85/×1.15 | 2.4 m/.3 s | ×feel |
| Grimble | 3.2 m/.16 s | 4.3 m/.16 s (×1.35) | no (owner 23:40) | ×.85/×1.15 | 2.7 m/.18 s | 3.7 m/.18 s |
| Claire | Skate 10.5 m/s, up to 1.6 s | same | F speed | none (not a travel) | as raw | as raw |
| Ostra | lob 12 m, 1.8 s | same | F time | none (not a travel) | as raw | as raw |
| Bjorn | 3.5 m/.17 s whirl | 4.2 m/.3 s lumber | F whirl | ×1 | 3.5 m/.17 s | 4.2 m/.3 s |
| Ryzz | lane 5.6-9.75 m at 40 m/s | same | no (owner item 70, lane cut 11-10) | time ×1.15 | 5.6-9.75 m at ~35 m/s | same |
| Sable | 4.5 m/.48 s | the ground one with a charge (item 183) | F | ×1 | 4.5 m/.48 s | 4.5 m/.48 s, then the air's drag |

On a ×1 kit every Shift move runs its raw numbers, including the moves with no source figure: Bjorn's Shield Charge (4.2 m at 18 m/s), his short dash during the wind-up and his lumber, Vex's long dash and Hem's flick are now about 18% longer and 13% quicker than before.

Those five, measured against the footage (`origin/ext/hero-ref-footage`, 5 fps; 1 bh = 1.8 m) and `briefs/supervive-data` on 2026-11-12: none shows the move, so none has a measure, no number moved and no `felt dash` row was added. DECISIONS has no owner line on any of them.

| Move | Raw (ours) | Source | Looked at | Row |
|---|---|---|---|---|
| Bjorn Shield Charge | 4.2 m / .23 s (18 m/s) | Oath Shield Bash: knock-back and brief invulnerability, no travel figure (supervive_kits.md) | bjorn 0180-0362 every 6th, 0296-0311 and 0343-0362 every frame: the shield is held planted; the bash flares (0300, 0352-0353) move his body under 5 px (0.2 m), the second one at point blank on the dummy, so no travel can be read | [?] |
| Bjorn short dash in the wind-up | 2.6 m / .13 s (20.5 m/s) | none: Spin Dash is a plain Shift | bjorn 0100-0172 every 3rd (the charged swings: he walks the hold, no Shift in it); 0363-0371 (the 360 Smash starts with no charge glint) | [?] |
| Bjorn lumber (long dash) | 4.2 m / .3 s (14 m/s) | none: the source has no long dash; Oath never leaves the ground (bjorn.md 5) | same frames as above; 0512-0518 is Earthshatter, not a dash | [?] |
| Vex long dash (air slide) | 4.7 m / .33 s (2/3 of the 7 m / .55 s hold) | patch notes only; Combat Slide card has no figure | venator_ghost 0114-0153 every 3rd: the three slides (0117, 0135, 0150) are all on the ground, no hold told apart, none in the air | [?] |
| Hem flick (long dash) | 5.0 m / .22 s (light class) | none: Phase Walk has no long dash, an air Shift is the same roll (item 183) | pin 0048-0056 (pin.md 5's 2.3 m push): it is her wall climb up the tower (Soul Hunter), not a dash; 0388-0389 is the ground roll | [?] |

## The 20 biggest feel gaps, ranked

Slice Wardens and LMB rank first (PRIORITIES step 2). Effort: S under a day, M a few days, L a week or more. `owner` = needs an owner call before building.

**Status** (Nov 9, checked against origin/main d255acbee): `closed <sha>` is on main, `pending ext/<branch>` is a READY branch not yet merged, `open` has neither. The Grimble, Neve, Motley, Albert, Sparkle and Sable tables above were re-checked the same day (canon names, ids unchanged).

| # | Gap | Fix | Files | Effort | Status |
|---|---|---|---|---|---|
| 1 | Kael has no authored animation: `kael.glb` 0 clips, 20 moves procedural | Rig and author clips, add the map | art/wardens/kael, content/rules/warden_anim/kael.json | L | closed `ca52dc648` (Kael v2 model, 49 clips, `warden_anim/kael.json`; `ext/parity-kael-clips` is superseded) |
| 2 | Stopping is a hard stop for all 12: brake 110 vs 22.2 m/s² | Move brake to source, retune | content/rules/hunter_move.json, scripts/match/hunter.gd | M | closed `64e6c681f` (brake 22.2, friction 2) |
| 3 | Air control 0.3 vs 0.015, 20x source | Lower it; keep owner-asked steer rows | hunter_move.json, hunter_move.gd | M | closed `64e6c681f` (air control 0.015) |
| 4 | Dashes stop dead: keep 15%/30% vs carry; global ×.85/×1.15 | Raise carry; drop scale where kit numbers already match | hunter.gd, content/rules/dash_feel.json | M | closed `64e6c681f` (dash exits at run speed), `2f24ae36b` (single dash scale) |
| 5 | Lace's invented Focus/Deadeye sits over the draw | Remove, or owner keeps it | archer_kit.gd, archer.json | M, owner | closed `ffa20b0f7` (Focus and Deadeye cut) |
| 6 | Lace's Heavy Shot wall payoff ~0.4x vs ~5x | Raise wall_dmg, drop .4 floor | archer.json | S | closed `4aa011a49` (wall pin 4.94x) |
| 7 | Lace's RMB .5 s dead zone before the draw reads | Match the footage start | archer.json, pin_needle.gd | S | closed `4aa011a49` (dead zone 0.15 s) |
| 8 | Lace's Phase Walk stops at raised walls | Passable ledge faces | pin_spirit.gd, map height | L | pending `ext/parity-phasewalk-rebased` 2178ea313 |
| 9 | Dash→LMB buffers on 6 kits (Lace, Albert, Kael, Cinder, Sparkle, Tenzo air), and Kael, Albert and Cinder keep `cancel` rows; item 51 says combine | Flip rows to `fire`, source them | content/dash_flow/*.json | S | closed `4e788af65` (Zedran, Albert keep buffer/cancel as sourced) |
| 10 | Cooldown pace is uneven: 0.48x to 1.0x of data | One rule per kit | content/archetypes/*.json | S, owner | open (`ext/parity-cooldowns` 69c9753c5 exists, no READY; DECISIONS default is 1.0x, main still 0.48x to 1.0x) |
| 11 | Cinder's dash is short: ground felt 2.9 m vs 3.4 m; his and Grimble's air dashes apply feel twice (likely bug) | Exempt or raise ground; scale air once (Kael already undoes it, `juggernaut_kit.gd:826`) | ashwick_kit.gd:521, dredge_kit.gd:684, ashwick.json | S | closed `2f24ae36b` |
| 12 | Albert's cadence .48 vs .45; hold walks | Set .45; check hold | bulwark.json | S | closed `1eecee8c3` (cadence .45); hold-walk kept per owner #59, asserted `9c336682d` |
| 13 | Grimble's air dash lacks its own 12.5 s slot | Add slot | dredge_kit.gd, dredge.json | M | closed `0a5b33f48` |
| 14 | Tenzo's allies can't hop his rocks | Add jump hop | dolm_kit.gd | M, owner | closed `eb93c5b62` (already on main at the audit; bots hopping pending `ext/tenzo-ally-hop` 618098895) |
| 15 | Albert's Guard meter and Shield Slam are invented | Remove, or owner keeps | bulwark_kit.gd, bulwark.json | M, owner | pending `ext/parity-bulwark-guardcut` b2e942eb4 (also in `ext/misc-ready-integ` 55446e046) |
| 16 | Neve's darts fly straight while skating | Owner answer, then home | rimewright_kit.gd | S, owner | closed `e5c73480c` (darts and skating beams home late; bend assert pending `ext/parity-neve-skate-home` 9b65ea7f1) |
| 17 | Motley's bomb peaks 3x vs 3.5x | Set 3.5 | ostra.json | S | closed `5b9a528d2` |
| 18 | Glide: steered accel, no -32.5 m/s dive | Add dive | hunter.gd | M | closed `45f26a5b5` (dive numbers asserted; key is ours) |
| 19 | Ours-only riders: Chill slow, Shred, Meeko's shield | Remove, or owner keeps | kit JSON, kits | S, owner | closed `3bcb50eca` (Chill slow, Meeko's shield out; Shred was already gone) |
| 20 | Jump 6.8 vs 7.5 m/s (deliberate, sourced below); 19 dash-flow rows have no source `[?]` (Lace 8, Sparkle 5, Tenzo 6), listed below | Jump sourced and checked; rows marked `[?]`, not guessed | content/dash_flow, tools/move_feel_check.gd | S | closed `0f70d1a8a` (jump pinned, 6.8 kept on purpose); source notes on the hold rows pending `ext/flow-rows-source` dd2c83be5 |
| # | Gap | Fix | Files | Effort |
|---|---|---|---|---|
| 1 | Done: Zedran's animation (`kael.glb` 49 clips, `warden_anim/kael.json`) | none | art/wardens/kael | done |
| 2 | Stopping is a hard stop for all 12: brake 110 vs 22.2 m/s² | Move brake to source, retune | content/rules/hunter_move.json, scripts/match/hunter.gd | M |
| 1 | **Closed** 3419a661a (2026-11-07): `kael.glb` carries the 49 v1 clips retargeted onto the v2 rig by bone name, `warden_anim/kael.json` maps his moves (21 `kmoves`), clip-check covers him; kept through the appeal3 body swap d38cbfaa3. Still differs: the clips are retargeted v1 clips, not authored for this body | none | art/wardens/kael, content/rules/warden_anim/kael.json | done |
| 2 | **Closed** bc1a70608 (2026-11-07): brake 22.2 m/s² plus ground_friction 2/s (source), a let-go from a run slides ~0.3 m; 5a2831b2b retired the last ours number (`GROUND_SHED` 110), over-run speed now sheds under the same brake. Still differs: nothing in the stop; asserted in --move-feel-check | none | content/rules/hunter_move.json, scripts/match/hunter.gd | done |
| 3 | Air control 0.3 vs 0.015, 20x source | Lower it; keep owner-asked steer rows | hunter_move.json, hunter_move.gd | M |
| 4 | Dashes stop dead: keep 15%/30% vs carry | Raise carry. **Scale part done:** the ×.85/×1.15 layer runs only on kits with no source dash (table below) | hunter.gd | M |
| 5 | Done: Hem's Focus/Deadeye is removed (Hawk Sense only) | none | archer_kit.gd | done |
| 6 | Done: Hem's Heavy Shot wall payoff is `wall_mult` 4.94 | none | archer.json | done |
| 5 | **Closed** ffa20b0f7 (2026-11-08, owner decision 2026-11-07): Focus meter, its +20% range and the Deadeye crit cut; Hawk Sense kept. Still differs: nothing; checks assert no meter and a plain arrow into a pinned foe | none | archer_kit.gd, archer.json | done |
| 6 | **Closed** 4aa011a49 (2026-11-07): `wall_dmg` 12 and the .4 floor replaced by `pin.wall_mult` 4.94, the source's 173 extra on 35. Still differs: nothing in the payoff | none | archer.json | done |
| 7 | Hem's RMB .5 s dead zone before the draw reads | Match the footage start | archer.json, pin_needle.gd | S |
| 8 | Hem's Phase Walk stops at raised walls | Passable ledge faces | pin_spirit.gd, map height | L |
| 9 | Dash→LMB still `buffer` on Zedran and Bjorn (Hem, Vex, Cinder, Ryzz, Tarek are `fire`); Zedran, Bjorn and Cinder keep `cancel` rows; item 51 says combine | Flip rows to `fire`, source them | content/dash_flow/*.json | S |
| 10 | Cooldown pace is uneven: 0.48x to 1.0x of data | One rule per kit | content/archetypes/*.json | S, owner |
| 11 | Done: Cinder is off the dash feel (3.4 m/.33 s, poof 6.8 m/.28 s); Grimble's air barge is scaled once (measured 3.7 m/.2 s) | none | asserted in --move-feel-check | done |
| 12 | Bjorn's cadence .48 vs .45; hold walks | Set .45; check hold | bulwark.json | S |
| 13 | Grimble's air dash lacks its own 12.5 s slot | Add slot | dredge_kit.gd, dredge.json | M |
| 14 | Done: Tarek's allies hop his rocks (owner 23:55, `StoneStand`) | none | stone_stand.gd | done |
| 12 | **Closed** 1eecee8c3 (2026-11-07): `throw_rate` .48 → .45, the source card's; bjorn_launch_check asserts it. Still differs: the hold walks at 55% where the footage only shows him standing; no source number, owner note keeps it | none | bulwark.json | done |
| 13 | **Closed** 0a5b33f48 (2026-11-07): the air pounce is its own 12.5 s slot, 2 s less per rank (source Brute Dash (Air)), asserted in the combo check. Still differs: the ground charges recharge in 10 s against the source's 7 s (owner dash row, Grimble table) | none | dredge_kit.gd, dredge.json | done |
| 14 | **Closed** eb93c5b62 (2026-11-03, owner 23:55): an ally's jump against a friendly rock lifts them over, walking stops them, foes stay blocked; 618098895 (2026-11-08) makes bots hop a teammate's rock and the check asserts the ally clears it. Still differs: nothing known | none | dolm_kit.gd | done |
| 15 | Bjorn's Guard meter and Shield Slam are invented | Remove, or owner keeps | bulwark_kit.gd, bulwark.json | M, owner |
| 16 | Done: Claire's skating beams home late like her darts (owner: semi-homing, 2x damage) | none | asserted in --rimewright-combo-check | done |
| 17 | Ostra's bomb peaks 3x vs 3.5x | Set 3.5 | ostra.json | S |
| 18 | Glide: steered accel, no -32.5 m/s dive | Add dive | hunter.gd | M |
| 16 | Claire's darts fly straight while skating | Owner answer, then home | rimewright_kit.gd | S, owner |
| 17 | **Closed** 5b9a528d2 (2026-11-07): `dmg_max_k` 3.5; the old 3.0 already peaked at 3.5x through its formula, so damage is unchanged and the field now reads true; the check asserts a full pop = 3.5 × 12.5. Still differs: whether the cooldown starts on the plant is `[?]` | none | ostra.json | done |
| 18 | **Closed** 280404102 (2026-11-08): hold Ctrl under the glider to plunge at 32.5 m/s, all dive tunables from the data (`dive_*` in hunter_move.json); b512c864c (2026-11-09) put the glide steer and start fall on the source too (decision 0027). Still differs: the key is ours (the source names none) and the swoop out of a dive is capped at the glide's max | none | hunter.gd, hunter_move.json | done |
| 19 | Ours-only riders: Chill slow, Shred, Pip's shield | Remove, or owner keeps | kit JSON, kits | S, owner |
| 20 | Jump 6.8 vs 7.5 m/s (deliberate, sourced below); 19 dash-flow rows had no source `[?]` (Hem 8, Ryzz 5, Tarek 6): 1 settled by Breah's footage, 14 now cite what was checked as "Not determinable", the 4 Q rows stay ours | Jump sourced and checked; rows marked `[?]`, not guessed | content/dash_flow, tools/move_feel_check.gd | S |
| 20 | Jump 6.8 vs 7.5 m/s (deliberate, sourced below); 55 dash-flow rows are `[?]` (no source, or "Not determinable"), listed below | Jump sourced and checked; rows marked `[?]`, not guessed | content/dash_flow, tools/move_feel_check.gd | S |
| # | Gap | Fix | Files | Effort | 0.24.4 (re-audit 11-11) |
|---|---|---|---|---|---|
| 1 | Zedran has no authored animation: `kael.glb` 0 clips, 20 moves procedural | Rig and author clips, add the map | art/wardens/kael, content/rules/warden_anim/kael.json | L | **done** `ext/kael-v2-model` (main): 49 clips mapped |
| 2 | Stopping is a hard stop for all 12: brake 110 vs 22.2 m/s² | Move brake to source, retune | content/rules/hunter_move.json, scripts/match/hunter.gd | M | **done** `ext/parity-move-feel`, `ext/phys-150-parity` (main): `physics.brake` 22.2 + friction 2 |
| 3 | Air control 0.3 vs 0.015, 20x source | Lower it; keep owner-asked steer rows | hunter_move.json, hunter_move.gd | M | **owner**: DECISIONS 2026-11-08 "real matches HAVE air control" overrules 0.015 (`tuning.json` air) |
| 4 | Dashes stop dead: keep 15%/30% vs carry | Raise carry. **Scale part done:** the ×.85/×1.15 layer runs only on kits with no source dash (table below) | hunter.gd | M | **done** `ext/parity-move-feel` (main): `dash_exit_run` 1.0, the dash hands over to the run; `ext/feel-dash-scale-source`, `ext/dash-curve-fit`; exact curves not decoded `[?]` |
| 5 | Hem's invented Focus/Deadeye sits over the draw | Remove, or owner keeps it | archer_kit.gd, archer.json | M, owner | **done** `ext/parity-lace-focus` (main) |
| 6 | Hem's Heavy Shot wall payoff ~0.4x vs ~5x | Raise wall_dmg, drop .4 floor | archer.json | S | **done** `ext/parity-lace` (main): `wall_mult` 4.94 |
| 7 | Hem's RMB .5 s dead zone before the draw reads | Match the footage start | archer.json, pin_needle.gd | S | **done** `ext/parity-lace` (main): hold 0.15, the charge counts from the press |
| 8 | Hem's Phase Walk stops at raised walls | Passable ledge faces | pin_spirit.gd, map height | L | **done** `ext/parity-phasewalk-rebased`, `ext/lace-phasewalk-verify`; end-inside follow-up is branch ready (ext/combat-lace-spirit-ledges-rebased) |
| 9 | Dash→LMB buffers on 6 kits (Hem, Bjorn, Zedran, Cinder, Ryzz, Tarek air), and Zedran, Bjorn and Cinder keep `cancel` rows; item 51 says combine | Flip rows to `fire`, source them | content/dash_flow/*.json | S | **done** `ext/parity-dashlmb` (main): Lace, Sparkle, Cinder, Tenzo air fire; Kael, Albert (and Grimble, Meeko) `buffer` is sourced; the remaining `cancel` rows (Kael, Albert, Cinder X; Kael air RMB, E) carry a source line |
| 10 | Cooldown pace is uneven: 0.48x to 1.0x of data | One rule per kit | content/archetypes/*.json | S, owner | **open**: candidate cds unchanged (0.48x to 1.0x); branch ready: ext/cooldown-parity-verify 2be9877c2 (every kit at 1.0x level 1, `--cooldown-parity-check`) |
| 11 | Done: Cinder is off the dash feel (3.4 m/.33 s, poof 6.8 m/.28 s); Grimble's air barge is scaled once (measured 3.7 m/.2 s) | none | asserted in --move-feel-check | done | **done** `ext/parity-dash-scale` (main) |
| 12 | Bjorn's cadence .48 vs .45; hold walks | Set .45; check hold | bulwark.json | S | **done** `ext/parity-mossy-cadence` (main): `throw_rate` 0.45; hold walk is owner #59 |
| 13 | Grimble's air dash lacks its own 12.5 s slot | Add slot | dredge_kit.gd, dredge.json | M | **done** `ext/parity-grimble-airdash` (main): 12.5 s air slot |
| 14 | Tarek's allies can't hop his rocks | Add jump hop | dolm_kit.gd | M, owner | **done** `ext/tenzo-ally-hop` |
| 15 | Bjorn's Guard meter and Shield Slam are invented | Remove, or owner keeps | bulwark_kit.gd, bulwark.json | M, owner | **open** on the candidate; branch ready: ext/parity-bulwark-guardcut b2e942eb4 (owner 11-07: cut) |
| 16 | Claire's darts fly straight while skating | Owner answer, then home | rimewright_kit.gd | S, owner | **done** `ext/parity-neve-skate-home`, `ext/neve-dart-homing` |
| 17 | Ostra's bomb peaks 3x vs 3.5x | Set 3.5 | ostra.json | S | **done** `ext/parity-ostra-bomb` (main) |
| 18 | Glide: steered accel, no -32.5 m/s dive | Add dive | hunter.gd | M | **done** `ext/parity-glide-dive` (main): `dive_vy` 32.5; steer from `ext/glide-steer-parity`; landing at the glide sink is branch ready (ext/glide-dive-land) |
| 19 | Ours-only riders: Chill slow, Shred, Pip's shield | Remove, or owner keeps | kit JSON, kits | S, owner | **done** `ext/parity-no-riders` (main): Chill slow, Shred text, Meeko's shield; the rest (Meeko Empowered range, Grimble Ground, Tenzo punch scaling) branch ready, Kael and Tenzo CC riders open |
| 20 | Jump 6.8 vs 7.5 m/s (deliberate, sourced below); 19 dash-flow rows have no source `[?]` (Hem 8, Ryzz 5, Tarek 6), listed below | Jump sourced and checked; rows marked `[?]`, not guessed | content/dash_flow, tools/move_feel_check.gd | S | **done** `ext/parity-jump-flowrows` (main): jump kept 6.8, pinned as 0.85 to 1.0 of 7.5; the 19 rows stay **open** `[?]` |

## Item 20: jump speed and the unsourced flow rows

**Jump speed.** Source: JumpZVelocity 750 uu/s = 7.5 m/s at gravity 14.7 m/s² (supervive_physics.md:45, [D]). Ours: `Hunter.JUMP_V` 6.8 m/s. Kept on purpose (`docs/MOVEMENT_FEEL.md`, "Jump 9 → 6.8"): 7.5 lets jump plus mantle top four terraces. It is a map-grammar deviation, not a source value; the owner can flip it once the terraces change. `--move-feel-check` now asserts `jump_speed_vs_source` (lift-off over 7.5, must sit in 0.85 to 1.0), so the source number is pinned and the gap cannot drift.

**Dash-flow rows marked `[?]`.** A row in `content/dash_flow` that exists but has no `source`, or whose `source` starts "Not determinable". No source or footage settles these; they run as the kit's default (`keep` for holds, `fire` for Q and the silent dash rows). Not guessed. `tools/gen_wiki.py` puts `[?]` at the start of each one's Source cell in `docs/heroes/dash_interactions.md` (a pair with no row stays empty), so both places list the same 55 rows (names as of 2026-11-09; `*` = already says "Not determinable"):

| Hero | Rows | Result |
|---|---|---|
| Lace (`archer`, Pin) | `hold.lmb.{ground,air,jump}`, `hold.rmb.{ground,air,jump}` (6, `keep`) | Not determinable, each `source` cites what was checked: pin.md:33-47 (draw, walks while drawing, frames 0111-0116), :91-110 (Impaling charge, 0264-0269, 0494), :247 (open question 'whether you can shoot during it'), :322-334 (roll bare 0388-0389; air dash and jump not shown); supervive_kits.md:73-75, :78. Kept `keep`. Still `[?]` |
| Sparkle (`mage`, Vireo) | `hold.rmb.{ground,air,jump}` (3, `keep`) | Not determinable: vireo.md:80-94 (spear hold 1.2 s, she stood still, frames 0043-0049, 0057-0063, 0078-0084), :211-219 (spear thrown, then Surge), :386 (open question 5), :460-476, :503 (air Surge and jump not shown); supervive_kits.md:66-67. Kept `keep`. Still `[?]` |
| Tenzo (`dolm`, Breah) | `hold.rmb.jump` (1, `keep`) | **Sourced**: breah.md:114 (card frame 0240) 'when she jumps while charging, she leaps forward and the circle comes with her'; supervive_kits.md:106 'Jump while charging to leap forward'. The charge survives the jump, so `keep` is the source. No longer `[?]` |
| Tenzo (`dolm`) | `hold.rmb.{ground,air}`, `hold.lmb.{ground,air,jump}` (5, `keep`) | Not determinable: breah.md:71-82 (punch wind-up 0117-0124), :98-115 (charge, 0938-0958 is a punch pressed during a charge), :140-143 (dunk casts RMB after the dash), :145-158, :357 (open question 3), :361 (no transcript; the tip title 'Punch to Extend Dash/RMB' cannot be read), :433-449 (air dash 'not shown as a dash'); supervive_kits.md:105-106. Kept `keep`. Still `[?]` |

Left as ours: Hem (`archer`) `dash.ground.q`, `dash.air.q` and Ryzz (`mage`) `dash.ground.q`, `dash.air.q` (4, `fire`; Q is ours, no source exists).

Suggestion (not built): the Breah tip 'Punch to Extend Dash/RMB' may describe a held punch through a dash. Settle it with the spoken tip (whisper on breah/audio.wav) or a clip of a punch pressed in a Landslide; if it is a hold-through-dash, `hold.lmb.ground` stays `keep` and gains the source.
| Hero (id) | Rows `[?]` |
|---|---|
| Vex (`gunslinger`) | dash.ground.{rmb,e,x}\*, dash.air.{lmb,rmb,e,x}\* (7) |
| Kael (`juggernaut`) | hold.lmb.jump, hold.rmb.{ground,air,jump} (4) |
| Cinder (`ashwick`) | dash.ground.lmb\*, hold.rmb.{ground,air,jump} (4) |
| Meeko (`tender`) | hold.rmb.{ground,air,jump} (3) |
| Tenzo (`dolm`) | hold.lmb.{ground,air,jump}, hold.rmb.{ground,air,jump} (6) |
| Lace (`archer`) | dash.ground.lmb\*, dash.air.{lmb,rmb,e,x}\*, dash.{ground,air}.q (Q is ours), hold.lmb.{ground,air,jump}, hold.rmb.{ground,air,jump} (13) |
| Grimble (`dredge`) | dash.ground.lmb\* (1) |
| Neve (`rimewright`) | hold.rmb.{ground,air,jump} (3) |
| Sparkle (`mage`) | dash.{ground,air}.{lmb,rmb,e,x}\*, dash.{ground,air}.q (Q is ours), hold.rmb.{ground,air,jump} (13) |
| Albert (`bulwark`) | hold.lmb.jump (1) |

Dash -> LMB fires mid-dash for Lace, Sparkle, Cinder (both dashes) and Tenzo (air dash), where the source is silent (`--dash-flow-check` SOURCE_ROWS); Kael and Albert dash as the attack and buffer it; Grimble's ground row stays buffered (owner fallback) and his air pounce has its own row.
| Hem (`archer`) | `hold.lmb.{ground,air,jump}`, `hold.rmb.{ground,air,jump}` (6, `keep`); `dash.ground.q`, `dash.air.q` (2, `fire`; Q is ours, no source exists) |
| Ryzz (`mage`) | `hold.rmb.{ground,air,jump}` (3, `keep`); `dash.ground.q`, `dash.air.q` (2, `fire`, ours) |
| Tarek (`dolm`) | `hold.lmb.{ground,air,jump}`, `hold.rmb.{ground,air,jump}` (6, `keep`) |

Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows without a source (Cinder 3, Zedran 3, Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`. Re-checked 2026-11-09 (ext/dash-nd-rows-a) against data, footage and the wiki lines in the briefs: Vex `dash.air.lmb` is settled by the card's unqualified "can fire the rifle while sliding" plus the wiki's air tap (asserted in `--dash-flow-check`); Vex `dash.{ground,air}.{rmb,e,x}`, Cinder and Grimble `dash.ground.lmb` stay "Not determinable", each `source` says which lines and frames were read.
Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x} (all 13 re-checked 11-09 against the data, the pin/vireo frames, the cancel-matrix-a/b tables and the patch lines; none settled, each `source` says why in one line). Other heroes carry further `keep` rows without a source (Cinder 3, Zedran 3, Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`.
Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows (Cinder 3, Kael 4, Albert 1, Neve 3, Meeko 3). Each now has a `source` that reads "Not determinable" and cites what was checked, so they stay `[?]`: Kael `hold.lmb.jump`, `hold.rmb.{ground,air,jump}` (juggernaut.md:41, :57-64, :75-83, :284, frames 0087, 0121-0127, 0141-0146, 0251-0300; supervive_kits.md:21-22); Cinder `hold.rmb.{ground,air,jump}` (linwick.md:57-58, :267-286, :323, frames 0073-0074, 0102-0103, 0131, 0143-0144, 0159-0161); Albert `hold.lmb.jump` (bjorn.md:74, :365-366, :398, frames 0116-0118, 0133-0146); Neve `hold.rmb.{ground,air,jump}` (tamsin.md:18, :294, :297-298, :332-334; the source spear is a tap); Meeko `hold.rmb.{ground,air,jump}` (mooshmoosh.md:63, :340, :346-366, :386-388, :453, frames f105-113). No press inside a dash and no hold carried through a dash or jump is visible in any of them, so no row's behaviour changed (all `keep`; every interaction chains). Not covered here: Claire, Pip, Grimble and the other heroes' rows.
Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows without a source (Cinder 3, Zedran 3, Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`.
Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows without a source (Cinder 3, Kael 4 on the candidate (was 3), Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`.

## Health

PARITY FIRST ratio audit (briefs/DECISIONS.md 2026-11-07). Our numbers are on a smaller scale than the source's, so each Hunter is compared as a share of its own roster's average: ours = max health / 154 (mean of the 12), source = Base HP / 1285 (mean of the 12). Ratio = ours share / source share; 1.00 is parity, the bar is 1.25x either way.

**Where the numbers live.** Source: `Base HP` column of the per-hunter attribute table, supervive_physics.md (`origin/ext/agent-briefs`, briefs/supervive-data; `supervive_kits.md` has no HP rows) [D]. Ours: `Data.CLASSES[weight].hp` in `scripts/core/data.gd` (light 124, medium 145, heavy 193); every archetype takes its weight class's health (`Arch.weight`), `hunter.gd` adds kin and level growth on top. **Armour:** ours is `round(base health x ARMOR_DUR 2.2)`, so its ratio is the health ratio. The source has no per-hunter armour (a loadout item, `docs/SUPERVIVE_DATA.md` section 3), and no hunter has a base shield in either game (Bjorn's Brightshield, Grimble's and Pip's shields are ability shields, not base stats). So health is the only per-Hunter number.

| Hunter (weight) | Ours | Share | Source (Base HP) | Share | Ratio |
|---|---|---|---|---|---|
| Vex / Ghost (medium) | 145 | 0.942 | 1225 | 0.953 | 0.99 |
| Zedran = Kael / Brall (heavy) | 193 | 1.253 | 1290 | 1.004 | **1.25** |
| Hem = Lace / Myth (light) | 124 | 0.805 | 1100 | 0.856 | 0.94 |
| Cinder / Felix (heavy) | 193 | 1.253 | 1290 | 1.004 | **1.25** |
| Pip = Meeko / Elluna (medium) | 145 | 0.942 | 1290 | 1.004 | 0.94 |
| Tarek = Tenzo / Tetra (medium) | 145 | 0.942 | 1290 | 1.004 | 0.94 |
| Grimble / Kingpin (heavy) | 193 | 1.253 | 1445 | 1.124 | 1.12 |
| Claire = Neve / Celeste (light) | 124 | 0.805 | 1290 | 1.004 | **0.80** |
| Ostra = Motley / Void (medium) | 145 | 0.942 | 1150 | 0.895 | 1.05 |
| Bjorn = Albert / Oath (heavy) | 193 | 1.253 | 1475 | 1.147 | 1.09 |
| Ryzz = Sparkle / Joule (light) | 124 | 0.805 | 1290 | 1.004 | **0.80** |
| Sable / Shiv (light) | 124 | 0.805 | 1290 | 1.004 | **0.80** |

**Verdict: no outlier over 1.25x, so no health number was changed** (global scale untouched). Kael and Cinder sit at 1.249 and Neve, Sparkle and Sable at 0.802 (1/1.247): inside the bar by a hair, caused by the same thing: three weight classes against a source where 8 of 12 Hunters share 1290. No owner note on tankiness was found in DECISIONS or OWNER_REVIEW_1103, so none overrides these rows. `--archetype-check` ("health:" rows) asserts every Hunter is inside 0.8x to 1.25x.

**Suggestion, not built.** The source is flatter: 1100 to 1475 (1.34x spread) against our 124 to 193 (1.56x). Lowering heavy to about 185 and raising light to about 128 would bring all five near-limit Hunters to about 1.2x/0.83x. That moves a whole weight class, so it is the owner's call. Per-archetype health (Hem and Motley a little lower, Bjorn and Grimble a little higher) would match the source more exactly but breaks the one-weight-one-health rule.
## Friendly fire (--friendly-fire-check)

**Rule** [O: owner brief, PARITY FIRST]: a Hunter's abilities never hurt a teammate or the caster; a world explosion (powder keg, meteor) hurts everyone. `supervive_kits.md` states no exception: every damage line names "enemies", "struck targets" or "foes"; `docs/SUPERVIVE_DATA.md` has no self-damage row.

**Audit (all 128 `.hurt(` call sites).** Every damage source picks its victims through one of three team-filtered lists, so there is no per-kit exception to fix and none was added:
**The other kits' `keep` rows (2026-11-11).** The rows in the sentence above now carry a `source`. Each one cites the frames and lines checked. None could be settled: in every clip the held ability and the dash or jump are in separate windows. All stay `keep` and still `[?]`, and no behaviour changes.

| Hero | Rows | Checked |
|---|---|---|
| Cinder (`ashwick`, Felix) | `hold.rmb.{ground,air,jump}` (3) | linwick.md:55-63 (bolt lane 0073-0074, 0102-0103, 0131), :267-276 (bash 0143-0144, 0159-0160, never inside a lane), :278-279 and :285-286 (air dash and jump not shown); supervive_kits.md:41-42 |
| Zedran (`juggernaut`, Brall) | `hold.rmb.{ground,air,jump}`, `hold.lmb.jump` (4; the old count of 3 missed `hold.lmb.jump`) | juggernaut.md:20 (card 'Dash while attacking', silent on a charge), :41 (blast charge 0087), :57-65 (Charge Dash 0121-0127, 0141-0146), :86-92 and :259-266 (Quick Dash on its own, 0371-0420), :273-274 (air dash not shown), :283 (no plain jump; jumps are Air Slams 0251-0300); supervive_kits.md:18, 21-22, 26 |
| Bjorn (`bulwark`, Oath) | `hold.lmb.jump` (1) | bjorn.md:67-74 (swing holds 0101-0172, all standing), :271 (open question: can he move while charging), :363-366 (air and jump not shown); supervive_kits.md:88 |
| Claire (`rimewright`, Celeste) | `hold.rmb.{ground,air,jump}` (3) | tamsin.md:18 (the spear is a tap in the source), :48-53 (RMB 0094-0168) against :66-79 (Skate 0169-0296), no overlap; :293-298 (air dash and jump not shown); supervive_kits.md:33-34 |
| Pip (`tender`, Elluna) | `hold.rmb.{ground,air,jump}` (3) | mooshmoosh.md:61-72 and :386-388 (aim f105-113, f116-120), :340 (dashes at f35, f157, f181, f227, none in an aim; no clean ground dash); supervive_kits.md:9-11. Ours: holding RMB does nothing past the wind-up, so these rows have nothing held to act on |

I re-checked Cinder's and Grimble's `dash.ground.lmb`: nothing new. Cinder's LMB is never pressed inside a bash (linwick.md:267-276). Grimble's Buckshot (0040-0080) and his ~0.12 s Brute Dash (0188, dredge.md:100-103, 302-306) are in separate windows. Their sources stand as written.

To settle any of these rows, a clip has to show the held ability running into the move: Felix aiming the bolt and then bashing, Brall charging and then Quick Dashing, Oath charging and then jumping, Elluna aiming and then dashing. For Celeste the spear is a tap, so the hold is ours and there is no source row to match.

**Not reached by the check (no foe damage in that case):** `archer` and `bulwark` RMB taps, `bulwark`, `dolm` and `tender` E (shields, heals), the dashes of `archer`, `dredge`, `gunslinger`, `ostra`, `rimewright`, `tender` and `thief`. Utility belt items (`content/utility`) carry no damage. Boki species abilities (G, ~40 species through `Effects`/`KinExec`) go through the same `foes_of` but are not cast per species here.
## Boots and charms (gear parity, `--gear-parity-check`)
Loadout is 2 gloves, 2 charms, boots (DECISIONS). Searched briefs/supervive-data and briefs/hero-ref
(origin/ext/agent-briefs, 2026-11-10) for boots actives, cooldowns and passive move speed: the source data
has no boots or charm items at all (no item tables; PHYSICS_PARITY only says gear scales move speed at
runtime, with no numbers). So no piece has a source match and nothing was changed; the list below goes to
the owner. The check pins these values so any change goes through this list.

| Kind | Piece | Cooldown | Stats (Common) | Source match |
|---|---|---|---|---|
| boots | Springheel Boots (`boots`) | none (passive) | +8% move speed | none |
| boots | Quickstep Boots (`quickstep_boots`) | none | dash back 15% sooner, +3% move speed | none |
| boots | Skylark Boots (`skylark_boots`) | none | +35% glider heat | none |
| boots | Windstep Boots (`windstep_boots`) | none | +10% glide speed, +15% glider heat | none |
| charm* | `booster` | none | +20% glide speed, +20% glider heat | none |
| charm* | `focus` | none | 18% cooldown reduction | none |
| charm* | `heat_sink` | none | +45% glider heat | none |
| charm* | `power_core` | none | +12% damage | none |

\* Charms are not built yet (note 0005): there is no charm gear kind, and these passive gloves are the
pieces meant to become charms. No boots piece has an active, so none needs a key: the HUD boots cell
(GearPanel) shows the icon and rarity with no key and no cooldown, and its hover reads "Boots" plus the
stat line; the check asserts both for every boots piece.
## Friendly fire (--friendly-fire-check)

**Rule** [O: owner brief, PARITY FIRST]: a Hunter's abilities never hurt a teammate or the caster; a world explosion (powder keg, meteor) hurts everyone. `supervive_kits.md` states no exception: every damage line names "enemies", "struck targets" or "foes"; `docs/SUPERVIVE_DATA.md` has no self-damage row.

**Audit (all 128 `.hurt(` call sites).** Every damage source picks its victims through one of three team-filtered lists, so there is no per-kit exception to fix and none was added:

| Victim list | Filter | Sources (file:line) |
|---|---|---|
| `Match.foes_of(team)` (`match.gd:2032`) | `h.team != team`, kins not wild, mobs | gunslinger_kit.gd:558,564,660; gunslinger_ult.gd; juggernaut_kit.gd:798, juggernaut_ult.gd:151; ashwick_kit.gd:408, ashwick_jet.gd:243; effects.gd:325,336,701 (gloves, Boki abilities); verbs.gd:442; fields.gd; abilities.gd:16; merge_kit.gd:156, merge_augment.gd:167,246,256; match.gd:3471 (bolas), 5189 (well); kin.gd:683; mob.gd / boss.gd / blight.gd (monsters, own team -2) |
| `ArchKit.foes_in(at, r)` (`arch_kit.gd:602`) | `m.foes_of(h.team)` + radius | archer, ashwick:670, bulwark, dolm:185,424,470,476, breah_hop/slam/spine, juggernaut_kit.gd:533, juggernaut_drop.gd, mage_kit.gd:668,673, ostra_kit.gd:564,625, ostra_well.gd, rimewright_kit.gd:135,639,682,1019, tender_kit.gd:452 |
| `Match._shot_targets(s)` (`match.gd:3304`) | `h.team != s.team`, `k.team != s.team` | every projectile, `_boom` (match.gd:3562) |
| World, no team | none on purpose | `Breakables._hurt_around` (`breakables.gd:133`: kegs and barrels hit hunters, mobs and kins; credit is dropped for the lighter's own team), `Match._meteor_hit` (match.gd:5279), glider heat, fall and wall damage (`by` null or the last enemy) |

**Result.** `--friendly-fire-check` casts each of the 12 kits' LMB, RMB tap and hold, E (and a second press), R, X and dash, plus the four damaging gloves (blink, grapple, quake, shock; Bubble only reflects), with a foe, a teammate and the caster all inside: 707 checks, 0 failures. It counts hits through `CombatBus.hit_landed`. A powder keg hurts the caster, a teammate and a foe. Control run: with `foes_of` changed to include the caster's team, 127 checks fail across all 12 kits and the gloves, so the check does bite.

**Not reached by the check (no foe damage in that case):** `archer` and `bulwark` RMB taps, `bulwark`, `dolm` and `tender` E (shields, heals), the dashes of `archer`, `dredge`, `gunslinger`, `ostra`, `rimewright`, `tender` and `thief`. Utility belt items (`content/utility`) carry no damage. Boki species abilities (G, ~40 species through `Effects`/`KinExec`) go through the same `foes_of` but are not cast per species here.
## Health

PARITY FIRST ratio audit (briefs/DECISIONS.md 2026-11-07). Our numbers are on a smaller scale than the source's, so each Hunter is compared as a share of its own roster's average: ours = max health / 154 (mean of the 12), source = Base HP / 1285 (mean of the 12). Ratio = ours share / source share; 1.00 is parity, the bar is 1.25x either way.

**Where the numbers live.** Source: `Base HP` column of the per-hunter attribute table, supervive_physics.md (`origin/ext/agent-briefs`, briefs/supervive-data; `supervive_kits.md` has no HP rows) [D]. Ours: `Data.CLASSES[weight].hp` in `scripts/core/data.gd` (light 124, medium 145, heavy 193); every archetype takes its weight class's health (`Arch.weight`), `hunter.gd` adds kin and level growth on top. **Armour:** ours is `round(base health x ARMOR_DUR 2.2)`, so its ratio is the health ratio. The source has no per-hunter armour (a loadout item, `docs/SUPERVIVE_DATA.md` section 3), and no hunter has a base shield in either game (Bjorn's Brightshield, Grimble's and Pip's shields are ability shields, not base stats). So health is the only per-Hunter number.

| Hunter (weight) | Ours | Share | Source (Base HP) | Share | Ratio |
|---|---|---|---|---|---|
| Vex / Ghost (medium) | 145 | 0.942 | 1225 | 0.953 | 0.99 |
| Zedran = Kael / Brall (heavy) | 193 | 1.253 | 1290 | 1.004 | **1.25** |
| Hem = Lace / Myth (light) | 124 | 0.805 | 1100 | 0.856 | 0.94 |
| Cinder / Felix (heavy) | 193 | 1.253 | 1290 | 1.004 | **1.25** |
| Pip = Meeko / Elluna (medium) | 145 | 0.942 | 1290 | 1.004 | 0.94 |
| Tarek = Tenzo / Tetra (medium) | 145 | 0.942 | 1290 | 1.004 | 0.94 |
| Grimble / Kingpin (heavy) | 193 | 1.253 | 1445 | 1.124 | 1.12 |
| Claire = Neve / Celeste (light) | 124 | 0.805 | 1290 | 1.004 | **0.80** |
| Ostra = Motley / Void (medium) | 145 | 0.942 | 1150 | 0.895 | 1.05 |
| Bjorn = Albert / Oath (heavy) | 193 | 1.253 | 1475 | 1.147 | 1.09 |
| Ryzz = Sparkle / Joule (light) | 124 | 0.805 | 1290 | 1.004 | **0.80** |
| Sable / Shiv (light) | 124 | 0.805 | 1290 | 1.004 | **0.80** |

**Verdict: no outlier over 1.25x, so no health number was changed** (global scale untouched). Kael and Cinder sit at 1.249 and Neve, Sparkle and Sable at 0.802 (1/1.247): inside the bar by a hair, caused by the same thing: three weight classes against a source where 8 of 12 Hunters share 1290. No owner note on tankiness was found in DECISIONS or OWNER_REVIEW_1103, so none overrides these rows. `--archetype-check` ("health:" rows) asserts every Hunter is inside 0.8x to 1.25x.

**Suggestion, not built.** The source is flatter: 1100 to 1475 (1.34x spread) against our 124 to 193 (1.56x). Lowering heavy to about 185 and raising light to about 128 would bring all five near-limit Hunters to about 1.2x/0.83x. That moves a whole weight class, so it is the owner's call. Per-archetype health (Hem and Motley a little lower, Bjorn and Grimble a little higher) would match the source more exactly but breaks the one-weight-one-health rule.

## 0.24.4 main re-check: eight Hunters (2026-11-12, main 88b06b9e7)

Albert (`bulwark`, section "Bjorn"), Neve (`rimewright`, "Claire"), Tenzo (`dolm`, "Tarek"), Sparkle (`mage`, "Ryzz"), Grimble (`dredge`), Meeko (`tender`, "Pip"), Sable (`thief`) and Motley (`ostra`, "Ostra"). Marks: **done** = still as the row says; **fixed since** = the row's gap is closed on main, the row text above is stale; **open** = still a gap or an owner call; **regressed** = was done, no longer. Numbers were read from `content/archetypes/*.json`, `content/weapons` and `content/dash_flow`; animation coverage and live behaviour were not re-measured, the combo checks stand for them.

**Checks on 88b06b9e7:** `--bulwark-combo-check` 166/0, `--rimewright-combo-check` 116/0, `--dolm-combo-check` 172/0, `--mage-combo-check` 143/0, `--dredge-combo-check` 112/0, `--tender-combo-check` 104/0, `--dancer-combo-check` (Sable) 144/0, `--ostra-combo-check` 213/0, `--kit-parity-check` 0 failures, `--dash-flow-check` 0 failures (14 skipped), `--ttk-check` **22 failures** (the count the 0.24.4 gate already lists; 11 rows are these Hunters: mage 4, bulwark 3, ostra 4).

**Regressed: none.** Health (124/145/193), cooldowns, ranges, crowd-control numbers and the felt-dash table all match the rows above.

| Hunter | Row | 0.24.4 main mark |
|---|---|---|
| Albert | LMB | open (owner): tap whirl, carry and perfect launch stay; **fixed since**: cadence `throw_rate` 0.45 (gap 12 closed) |
| Albert | RMB, E, R, Dash | done: aegis 4.2 at 140, slam 2.6 at 100 stun 0.6, bash cd 6; E zone r **2.3** (the row's "r 3.5" is stale), delay 1, 4 s, cd 12/8; R 4 cells x 4 m, width 4.5, stun 0.5, cd 40; whirl 3.5 m at 20.5 m/s (0.17 s), cd 8 |
| Albert | Passive | open (owner, gap 15): Guard meter and Shield Slam still built; Crush stun 1.0 s done |
| Albert | Dash-flow | open (gap 9): `dash.ground/air.lmb` still `buffer` (sourced from footage, not flipped to `fire`) |
| Neve | LMB | **fixed since** (gap 16): skating beams home like darts (`rimewright_kit.gd`) |
| Neve | RMB, E, R, Dash | done / owner as before: 2 charges cd 10.2 (owner), E 200 HP cd 17, R hold 3.5 s cd 80 rink 8.3 (7.2 +15%, owner), dash 11.5 m/s up to 1.6 s cd 13 refund 0.6 |
| Neve | Passive, Body | open (owner, gap 19): Chill slow is ours-only. Body size is **1.014**, not 1.15: the owner's height chart (4538174a85, Neve 1.56 m) set it; the "Body ... match" row is stale and is an owner call |
| Tenzo | LMB, RMB, Passive | done: boulder 0.6, punch 0.7, slam hold 0.2 cd 11 |
| Tenzo | E | **fixed since** (gap 14): allies hop the rocks (`hop rocks` in `--dolm-combo-check`, owner 23:55); cd 12.5, 3.4 ahead, span 5 done |
| Tenzo | R, Dash | open (owner): ridge 12 m (source 18-21.6, kept), 9 rocks cd 45 range 11; Rock Hop 3 x 2.8 m/0.26 s cd 12 (owner item 111) |
| Tenzo | Dash-flow, CC | gap 9 **fixed since** (`dash.*.lmb` is `fire`); open: 6 `[?]` hold rows, ours-only rock and hop slows (CC suggestions) |
| Sparkle | LMB, RMB, E, R | done: bolt 0.648 s range 13 (`coilcaster.json`, owner); RMB hold 1.0 cd 8; E delay 0.8, stacks 1, cd 10.5, r 1.5 reach 11 slide 3.4; R hover 1.7 cd 42 r 2.7 range 14.4 |
| Sparkle | Dash | open (owner): lane **5.6-9.75 m** at 40 m/s, dmg 20, cd 8 (the section row's "7.5-13 m" is stale; the felt-dash table is right) |
| Sparkle | Flow, Passive | gap 9 **fixed since** (`dash.*.lmb` is `fire`, source "not determinable" `[?]`); passive done |
| Grimble | RMB, E, R, Passive | done: reel 11.5 m cd 12; slam windup 0.38 r 3 stun 1.1 cd 7; R charge 1.1 fan 105 cd 21; Salvage max 10 at +2.5% |
| Grimble | Dash | **fixed since** (gap 13): the air pounce has its own 12.5 s slot (`dash.air.cd`, 10.5/8.5 at ranks 2/3; asserted in `--dredge-combo-check`); the row's "air slot missing" is stale. Open (owner): ground dash off the 0.85/1.15 feel; cooldowns 0.58x of the data |
| Meeko | LMB, E, R, Dash, Anim | done: E 2.5 s r 2.6 cd 11, R 5 s range 12.6 cd 46, dash 3.6 m/0.2 s cd 7 and 13.3 m/0.95 s cd 14, carry 2 with 4 s lock |
| Meeko | RMB, Passive | open: hop form root after 2 s (owner 11-10), motion `[?]`; Carrier shield is ours-only (gap 19) |
| Sable | LMB, E, R, Dash | done: E 14 m 6 s cd 15; R r 2.3 to 5.4, 10 shots, cd 24; Vault 4.5 m/0.48 s cd 4.5, prime +1.34 (2.34x). The row's "air 8.4 m/0.95 s" is stale: the air dash is the ground cartwheel with a charge (item 183) |
| Sable | RMB, Passive | open (owner): bola cd 7 (0.54x of the data) and the 30% slow; R cd 24 is 0.48x; Shred is ours-only `[?]`; pair stun 0.9 vs ~1.8 s |
| Motley | LMB, RMB, R, Dash | done / owner as before: charge from 0.6 s (owner 60), RMB cd 10 (owner 40), Nightwell tell 1.0, 3.5 s, pull 12, cd 70, lob 1.8 s cd 9.5. RMB wind-up 0.32 was not located by key in the JSON (combo check passes) |
| Motley | E | **fixed since** (gap 17): `dmg_max_k` 3.5; grow 6.5 s and r 3.2 done; the fizzle stays ours |
| Motley | CC | open: orb slow 10% (wiki) vs 6% (card read) undecided |

**Shared rows still open for these eight:** gap 2 (stopping), 3 (air control), 4 (dash carry), 10 (cooldown pace 0.48x to 1.0x), 19 (ours-only riders); health ratios unchanged (Neve, Sparkle, Sable 0.80 against the 1.25x bar); every `?` range in the ranges table stays `?`.
