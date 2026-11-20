# Stuck-integration triage 62ec7ba9 (job 20261115-201531-a1, main b9d6a0834e, 2026-11-15)

Input: 825 READY branches that merge-candidate keeps SKIPPING for conflicts. Each branch's newest READY sha
(briefs/EXT_TO_MAIN.md, else the tip) was classified against origin/main with `git merge-tree`; `triage.tsv` has one row each.

| class | n | what it means |
|---|---|---|
| CONFLICT | 785 | conflicts with main; most are thousands of commits behind (main moved ~14k commits) |
| CLEAN | 4 | merges clean: integ-1113-D1 (taken), sable-bola-instant-rebased (generated doc only; gen_wiki on main gives main's file: superseded), stuck-integ-b6204ee2 (registers tools/cast_predict_check.gd, which is in no tree on main: dropped), mantle-port-a (227 commits, 0.24.6 anim wave: needs its own gate) |
| MERGED | 3 | already in main |
| MISSING / GONE | 1 / 32 | READY sha not on the remote / branch deleted |

`landed_pct` = share of the branch's added lines (merge-base..READY sha) that are already present, as lines, in
main's copy of the same file. It overcounts unlanded work: main often fixed the same thing differently (spot checks:
combat-neve-lmb-torn's UiTorn corner fix and combat-ostra-seed-burn's burn band are both on main in another form).
Buckets over the 785 conflicts: >=95% landed 29, <=20 unlanded lines 21, 21-100 lines 111, 101-500 lines 266, >500 lines 358.

Ported on ext/stuck-integ-62ec7ba9: integ-1113-D1 (merge), combat-daze-status (hand port, 1a959429f0).
The rest needs per-area port jobs (sort triage.tsv by unlanded_lines and port smallest first; check each against
main's current code first: a red or a stale row here is often already solved).

## Pass 2 (job 20261115-203509-a1, role feel, main b9d6a0834e)

Read each small row's unlanded lines (`git diff -U0 merge-base..READY`, minus lines already in main's file) against main's
current code. Every one below is on main in another form, or only differs in generated/doc wording:

| branch | why superseded |
|---|---|
| fold-feel-glide-1112 | main's `_aim_rel` already clears mobs per run (`_clear_mobs`), the root cause of the aim_* reds |
| no-hardcoded-keys | main has all six actions (undo, keep_placing, level_mod, kit_card, confirm, push_to_talk) and SHARED_OK pairs |
| feel-fire-slow-sable | arc_bolts fire_slow 0.72 on main, RUN_KEEP [0.66, 0.78]; hoar_fan's 0.9 is live on main (`Hunter._fire_slow`), so it stays |
| tut-belt-hint-rebased | BeltTips ported (5fe58ca159); the pickup toast was replaced by LootFeed (f98a4044f1) |
| parity-pin-kael-drop | `rmb.drop.radius` row already in content/rules/kit_parity.json |
| ui-meeko-channel-ally | scripts/ui/channel_bar.gd on main; leftovers are a Net VERSION line and check wording |
| tut-hints-blight-camp-box | expedition_tips has blight/camp/deathbox (+wallkick) on main |
| series-boki-1112 | main draws through HeartRaid.boki_for / ModeBoki.draw (site_pool replaced) |
| sfx-silence-audit | tools/sfx_silence_audit.gd on main; leftovers are option text |
| vfx-albert-ivory-arcs | main's bulwark palette is a superset (adds "red") |
| tut-first-games-port, fix-ghost-shot-sfx-1113 | only generated wiki / hero-doc table wording left |
| 9 rows at 0 unlanded lines | creator-sex-distinct-shots scrapking-lmb-clips tut-first-heartspark-rebased tut-first-race-rebased vfx-archer-strips vfx-dolm-shots vfx-mage-strips vfx-neve-rimelock-area vfx-strips-tender |

Checks on this branch: --recast-cue-check 80 checks, 2 fails (ostra e ticks / EXPIRED), same 2 on main's files (79 checks):
NEW-RED 0. --wild-type-cue-check 0 fails. health --strict: style red in dj_fx.gd / glide_net_check.gd (main's, untouched),
sfx_loudness needs numpy (not on w2).

## Pass 3 (ext/stuck-integ-f1f63a7a, worker rpc7, main 0704553134, 2026-11-16)

Same list (~700 of the 825 rows). Not bulk-merged: 785 rows conflict and are thousands of commits behind; the newest
merge train ext/mc-20261115-1300 itself conflicts with main in 22 files (hunter.gd, match.gd, sfx.gd ...), so this
branch is main + ext/stuck-integ-62ec7ba9, not the mc train. Next 11 rows by unlanded_lines, read against main:

| branch | result |
|---|---|
| parity-sable-e-range | **ported** (509c64d23a): Sable E range 16.2 -> 15 m, frame re-read; KIT_PARITY row was "open" on main; --kit-parity-check 0 fails |
| vfx-kael-smash-lane-on-slam-lane | superseded: main's slam lane is already 0.72 m wide (main later chose red, not magenta) |
| anim-race-beats | superseded: crouch/burst/sulk clips timed by RaceBeats are on main (boki_home_clips.gd) |
| sfx-dash-per-hunter-rebased | superseded: HeroSfx picks <arch>_dash_air on main, 78 dash_air files |
| tarek-appeal, vex-body7-1111 | superseded: main's v95 masters are newer (tarek n95/c01, vex tilt1112 cand_A2) |
| warden-check-heights | superseded: main re-measured height_3d later (thief 1.10, mage 1.13 vs the branch's 1.18) |
| cinder-sable-polish-rebased | stale art: art1 paint/piece tweaks on a Sable source since rebuilt; needs an owner art pick, not a port |
| prologue-canon-2 | owner text call: main has Solmere/Malgrave/Hollowing; left: "the Beloved", "floating Skylands", shot 5 "Hunter's Relic" (DECISIONS 11-08 lines 361-362 lean to the branch) |
| anim-meeko-tiptoe | needs an anim job: the change is a re-baked glb (crouch_f/b/l/r), not text |
| vfx-cinder-ignite-orb | needs a vfx port job: ashwick_kit/ld_fx orb rider differs from main's |

## Pass 4 (ext/stuck-integ-f1f63a7a, worker rpc1, role feel, main 24078a184b merged in, 2026-11-16)

Next 22 rows by unlanded_lines, each read against main's current code:

| branch | result |
|---|---|
| parity-neve-rimelock-ramp | **ported** (4c55bebeab): Rimelock rink slows a flat 35%, the ours-only 15%+12%/s ramp is gone (PARITY FIRST); --rimewright-combo-check 137/0, --kit-parity-check 0 |
| tut-hatch-beat | **ported** (bug fix): `--hatch-check` divided a seconds clock by 1000, so the "beat < 2.5 s" row read ~0.002 s and could never fail; now 2.01 s, 0 failures |
| combat-neve-lmb-torn | superseded: main's UiTorn keeps corner points on the edge (depth 0 at k = 0 / steps) |
| combat-ostra-seed-burn | superseded: --ostra-combo-check reads `e.burn` from the data on main |
| ui-card-numbers | superseded: main's card text was rewritten since (Sable E "15m at most", Mage tap 16 dmg); the branch's numbers are stale |
| sfx-boki-wire | superseded: all six Boki cues are played on main (merge_xform, kin_downed, kin_net, home, home_econ) and asserted in --sfx-set-check |
| mantle-look-one-home | superseded: MantleLook takes the gender from the archetype JSON on main; no gender in mantle_look.json |
| kit-text-clear-fixes | superseded: main's names/fantasy lines were rewritten later (harbour hauler, quarry-hand, green-fire rifle) |
| ui-audio-buses | superseded: main's Settings.BUSES has six buses (adds voices, ui_sounds) and Sfx.play_sample |
| feel-dive-net | superseded: main shows another player's plunge from its fall speed (GliderSfx.DIVE_VY_MIN), no Net flag needed |
| no-squad-hint-1111 | superseded by a later design: main's first-match guide grew squad + mates lines on purpose (11-13) |
| ttk-kael | superseded: Kael was re-tuned on main later (LMB 8.0 vs the branch's 5.2); a TTK change needs --ttk-check, not a port |
| vfx-ground-ring-hitbox | superseded: main has no skate frost/scorch discs and no Basalt Spine cast ring |
| feel-neve-statue-time | **not ported, owner call**: footage reads 3.3 s, but KIT_PARITY's [D] row says 3.5 s and data outranks footage; main keeps 3.5 |
| cinder-flue-clips | needs an anim port job (lift-off clips + hero_vfx ribbon), not text |
| grimble-hook-arm-v2-rebased, anim-pilot-slice3, anim-meeko-crouch-stride, grimble-nose-1109 | art/glb rows: need art jobs from the owner's picks |
| warden-bob-damp-rebased | superseded: `loco.bob` is on main (WardenGait) and Kael was re-tuned to [1.0, 0.6]; leftovers are a Net VERSION line, release.yml comments, audit doc |
| tut-keycap-audit | partly on main (--key-text-check, Settings.key_cap in hatch/tutorial_text); left: some card/tutorial strings, not re-read this pass |
