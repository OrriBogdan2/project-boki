# Implicit state machines on main: audit, decision and migration plan

Job 20261109-025701-a3 (w2), 2026-11-09. Read-only audit of origin/main d255acbee, owner 11-08: "Find all of the
implicit state machines in the game. Make the best decision that will elevate everything." No game code changed.
Line numbers are main's. Queued branches were read for conflicts: ext/movement-unify (Loco + Fsm), ext/glide-no-hold,
ext/kael-tap-ult-1108, ext/islands-deeper-1108 and the rest of the 11-08 queue.

## 0. The short version

- The game has ONE explicit state machine that is live, and it is 12 hours old: `Fsm` + `Loco.S` on ext/movement-unify
  (scripts/core/fsm.gd, docs/decisions/0022). Even it is a mirror: hunter.gd:894 `_loco_state()` derives the state from
  the timers every step and `loco.go()` records it; only the glider open asks `loco.can()`. The only other enum state
  machine in the repo, `HunterController.State` (scripts/feel/hunter_controller.gd:16, 44 of the repo's ~47 `State.`
  uses), is a dead playground reached from `tests/feel_test.tscn` (main.gd:676), not by `Hunter`.
- Everything else is booleans, `*_t` timers, timestamps, string modes and dictionaries-as-states, read through
  if-chains. Measured on main: hunter.gd 43 bool vars + 43 `_t` timers (plus 9 dicts that mean "in this move");
  match.gd 44/8, home.gd 37/7, main.gd 45/3, hud.gd 31/6, hunter_anim.gd 18/21, kin.gd 13/12. Seven `enum`
  declarations repo-wide, three of them live (world tile kinds, terrain edges, message lanes), none a state machine.
- 21 implicit machines are mapped below (section 2). Eight owner bugs from 11-08 trace to five of them (section 3).
- DECISION (section 1): adopt `Fsm` as the one pattern, harden it a little (per-edge guards, a timed transition log
  with a reason, a registry + one F7 readout for every machine, a `--fsm-check`), and migrate machine by machine in the
  order of section 4, each migration making the machine the OWNER of its state (the flags it replaces are deleted in
  the same change). No library, no per-state classes, no second pattern.
- First three jobs after ext/movement-unify merges: M1 (Fsm hardening + delete the dead feel/ FSM), M3a (ArchKit
  ability slot machine, base + Kael + Albert: four owner bugs), M2a (glider as a state with one entry edge).

## 1. Decision: the one explicit-state pattern for GDScript

### 1.1 Keep `Fsm` (scripts/core/fsm.gd on ext/movement-unify) as the pattern

It is already the right shape and already small (70 lines): `enum` per owner, one `state: int`, a `TABLE` of
from -> [to], a guard per target (`guard(to, Callable)`), `on_enter`/`on_exit` hooks, `since` (s in state), `refused`
(count of transitions the table or a guard turned down), a 6-entry `history`. A change the table lacks is refused and
counted, never applied. Nothing but `go()` writes the state. That is the whole point: an illegal combo cannot exist
because there is no second variable to disagree with.

Rejected: a statechart library or hierarchical states (GDScript has no generics; nesting hides the table and the owner
asked for one explicit state), a class per state (13 kits x 6 states = a file explosion), signals-per-transition
(CombatBus already carries the gameplay events; the machine is local), and keeping the mirror pattern ("sync the enum
from the timers each step") beyond the first migration step: a mirror can only report an illegal combo after it has
already happened.

### 1.2 Harden it (M1, ~40 lines, no behaviour change)

1. **Per-edge guards.** `guard(to, f)` guards a target from every source; add `guard_from(from, to, f)`. The glider
   needs "AIRBORNE -> GLIDING only after a fresh press", "DASHING -> GLIDING at the dash's own speed": different guards
   for the same target.
2. **Transition log with reason and time.** `go(to, why := "")` appends `"%7.2f %s>%s %s" % [time, from, to, why]` to a
   32-entry log (today: 6 entries of `"from>to"`). Refusals log too (`refused_log`), so a check can print WHY the
   glider did not open. `why` is a short literal at the call site ("press", "landed", "hit", "dash", "timeout").
3. **Registry for readouts and checks.** `Fsm.new(names, table, start, label)` registers itself in a static
   `Fsm.live: Dictionary` (label -> weak ref) when `label != ""`. The F7 readout (`MoveReadout`, ext/movement-unify)
   becomes `FsmReadout`: it lists every live machine of the local player (loco, life, drop, each ability slot, the
   kin) with state, `since`, the last 3 log lines and the refused count. One label, one key, every machine.
4. **`--fsm-check`.** A tool that constructs every machine from its table and asserts: every `to` index is a state,
   every state is reachable from `start`, no self-edges listed, and the names array matches the enum size. Every
   migration job's own check also asserts `refused == 0` after a scripted input run (a refusal in a scripted check is a
   bug in the table or the input, never fine).
5. **Authority rule** (the non-negotiable one): when a machine is introduced, the booleans and timers it replaces are
   deleted in the same commit, and every reader switches to `fsm.is_in(S.X)` / `fsm.since`. Durations that were
   `*_t` countdowns become `since >= tuning duration` or a per-state `deadline` set in `on_enter`. Numbers go to
   content/rules/tuning.json (owner rule, 11-08). A mirror step (`go(_derived_state())`) is allowed for ONE job as
   scaffolding and must be gone by the end of the migration item.
6. **Networking.** State machines are local. Where a state is already on the wire as flag bits (match.gd:5702-5712:
   dropping/riding/diving/out/extracted) or an index (kin_follow.gd:15 `CMD_IDS`), the migration maps state -> the same
   bits/index so `Net.VERSION` does not move. If a shape must change, bump it (AGENTS.md rule).
7. **Where the machines live.** Not in the god files: `scripts/match/hunter_loco.gd` (the loco/life/drop tables and
   their hooks, Hunter keeps the var and the wiring), `scripts/arch/slot_fsm.gd` (the ability slot machine), kin's
   in `scripts/match/kin_follow.gd` (already the command module). hunter.gd is at 3334 of its 3500 budget: every
   migration touching it must be net-negative there (movement-unify already is, -100).

### 1.3 Delete the dead second FSM (M1)

`scripts/feel/hunter_controller.gd` (560 lines, its own `State` enum and tables), `scripts/feel/top_down_camera.gd`
(`enum Mode`), `scripts/feel/feel_config.gd`, `scripts/feel/feel_test_world.gd` and `tests/feel_test.tscn` are a
2-week-old SUPERVIVE feel prototype that `Hunter` never calls (hunter.gd:15 only cites it in a comment). AGENTS.md: no
duplicate systems. Removing it also removes the misleading "47 State uses" from the stats. `tools/move_feel_check.gd`
references it: the check moves to the live Hunter (movement-unify already retargeted the air numbers).

## 2. Inventory: the implicit machines (file:line, states, transitions, illegal combos)

Legend: **B** bool, **T** timer/timestamp, **S** string mode, **D** dictionary-as-state. "Allowed today" = a combination
the code can reach because two variables can disagree.

### 2.1 Hunter locomotion (scripts/match/hunter.gd) — the big one

States hidden in: `grounded`, `gliding`:206 B, `roll_t`:98 T (dash/rush; `move_kind`:1119 S "dash"|"rush" says which),
`fly_t`:103 T (a kit flight), `knock_t`:763 T + `kb_t`:116 (a TIMESTAMP compared as `m.time - kb_t > 0.4`), `stun_t`
(ent.gd:30), `root_t`/`slow_t` (ent.gd:28), `stagger_t`:140 (declared, read once: dead), `lfloat`:110 D (ledge
float), `grap`:112 D (floating up a ledge), `pad`:115 D (jump pad arc), `charge`:228 D (Ram), `wall_touch_t`:196 /
`wall_n` / `wall_moves.bounce_t`, `crouch`:193 B, `coyote`:101 T, `jump_buf`:102 T, `dash_buf`:1046 T (three buffers,
three consume rules; hunter.gd:1955 lists 11 countdowns decayed in one loop), `air_dashed`:169 B, `air_jumps`,
`glide_off_t`:912 T (doubles as "why it folded": 0.0 = let go, 9.0 = knock), `lift_t`:913 T, `air_t`:2520 T,
`_handoff`:963 D, `carry_mini`:107 D, `glide_dive.on` (glide_dive.gd:11) B, `glide_lift.hang_t/kicked/swoop`
(glide_lift.gd:14-17), `merge_st`:161 D with its own `phase`.

Transitions: `_physics` 2157-2420 picks the horizontal step by branch ORDER (2158 pad -> 2161 grap -> 2171 roll_t ->
2183 fly_t -> 2185 knock_t -> 2192 gliding -> 2220 grounded/hover -> 2228 feather -> 2232 lfloat -> 2234 air) and the
vertical step by a second order (2251 dropping -> 2256 glide_dive -> gliding -> 2268 MergeKit.rising -> 2270 roll_t
air -> air). `do_dash` 1123-1160, `dash_with` 1201-1245, `do_jump` 799-835, `impulse` 766-791, `_update_glide`
2521-2600, `_try_ledge_grab` 2604. Six gate modules each drop presses from their own view of the state: hunter.gd
2018-2031 `AirLimits.gate_drop`, `KinDowned.commit`, `MergeAugment.route`, `ak.gate_inputs()`, `_gate` x4,
`ak.flow.route` (DashFlow). `AirLimits.glide_locked` (air_limits.gd) decides "may glide" from `roll_t`, `charge`,
`ak.rmb_down`, `ak.dash_t`, `ak.chg`, `ak.fuse`, `cast_locked()`, `locks_glide()` and `move_running()`, which reads
the kit's ANIMATION id and three timestamps (`anim_at`, `dash_at`, `dash_press_at`, `jump_at`). Reads on main:
`gliding` 45x, `downed` 48x, `grounded` 66x, `dropping` 36x, `stun_t` 18x, `roll_t` 21x.

Allowed today:
- `roll_t > 0 and gliding`: a kit dash (`travel`/`dash_with`) does not fold the glider (only the ex path does,
  1155 / arch_kit `spend_dash`); `_update_glide` folds it one step later and records the fold as a knock
  (`glide_off_t = 9.0`, 2577), so FEATHER_KEEP is lost and the next press waits.
- `knock_t > 0 and roll_t > 0`: the roll branch wins (2171 before 2185); the knock moves nothing but `kb_t` is set
  (780), and `m.time - kb_t > 0.4` (2560) then refuses the glider for 0.4 s after a dash that "ate" a hit.
- `dropping and downed`: 2525-2537 returns before any `downed` check with `gliding = not grounded`; a hunter knocked in
  the drop glides on.
- `ex_next` left true: 1153 sets it before `Effects.run`; `dash_with` (1211-1214) clears it only when an effect row of
  type "dash" runs. A class dodge whose effects list has no dash row leaves the NEXT plain Shift flagged ex.
- `impulse(kb, lift)` with `lift >= 0.0` and no sideways push (774-778, 789-791) sets `grounded = false`: a status
  effect flips the locomotion state with no transition (see Lace, 3.5).
- `coyote`, `jump_buf`, `dash_buf` are consumed by three different rules (do_jump 822; 2032-2034; 2947 clears
  `dash_buf` from the gate) and `jump_buf` is never consumed by a landing (it is only decayed at 1955).
- The farm avatar (2.6) and `HunterAnim` (2.21) each keep their own copies of several of these.

On ext/movement-unify: `Loco.S {GROUNDED, AIRBORNE, GLIDING, DASHING, MANTLING, KNOCKED, STUNNED}` with a table, synced
by `loco.go(_loco_state())` each step (hunter.gd:2347 there) and asked once (`loco.can(S.GLIDING)` before the open).
Good table; still a mirror. Note its table has no DOWNED/RIDING/DROPPING: the life machine (2.2) is separate, by design.

### 2.2 Hunter life (hunter.gd + match.gd)

`downed`:126 B (match.gd:2224), `out`:129 B (2362, 5702, 5829), `gone`:130 B (2403, life.gd:508, blight.gd:399),
`extracted`:141 B (5318, 5704, 5874), `revive`:128, `stomp` dict (life.gd:128-160), `box_t`:134, `sick_t`:131.
Four bools = 16 combos, 5 legal (alive, downed, out, extracted, gone). The HUD derives the word by if-chain
(hud.gd:2036 `"Out" if h.out else ("Extracted" if h.extracted ...`), the net sends the bits (match.gd:5702-5712), the
tutorial reads `p.downed`/`p.extracted` directly (tutorial.gd:167, 172). Allowed today: `extracted and downed` (an
extract during a stomp), `out and not downed` for a wisp timeout is legal but indistinguishable from "died outright"
without `killcam_text`.

### 2.3 Hunter drop (match.gd, hunter.gd, drop_*.gd)

`riding`:233 B (match.gd:1207 on, 1289/1328 off), `dropping`:230 B + `diving`:232 B (1220-1221 and 1293-1294 on;
hunter.gd `_deploy` 2493 clears diving; 2395-2396 and 2535-2536 clear both), `drop_solo`:236 B (drop_squad.gd:201,
230), `drop_follow`:234 ref, `launch_at`:247 timestamp (`DropLaunch.locked`), `DropSquad.planning/plan_t/leads/_ack`
(drop_squad.gd:22-29), `drop_reticle.gd:49` writes `diving` from outside the hunter. Sequence RIDING -> LAUNCH ->
DIVING -> DEPLOYED -> LANDED lives in 3 bools + 1 ref + 2 timers across 5 files. Allowed today: `riding and dropping`
(a remote hunter: 1328 clears riding 6 s after the ship time regardless), `dropping and not diving and not gliding`
(deployed, then folded by a hit: `can` requires `not shot_down`, but 2527 forces `gliding = not grounded` every
step: the two lines fight).

### 2.4 Dash kind (hunter.gd + arch_kit.gd + kits + DashFlow)

One Shift press is decided four times: hunter.gd:1137-1140 computes `use_ex` (`not grounded or dashes < 1.0`, then
un-does it for a merge perk) before the kit sees the press; `ak.on_dash(use_ex)` in every kit decides again from its
own state (mage_kit.gd:349-375: `ult.airborne()`, `wire`, `run_t`, `h.dashes`; bulwark 707; juggernaut 455 with
`dash_held`:46 and `dash_after_plant`:53), `ArchKit.spend_dash` writes `h.ex_next`, `h.ex_cd`, `h.gliding = false`
back into the hunter, and `DashFlow` (scripts/arch/dash_flow.gd:11-19 MODES fire|buffer|cancel, MOVES ground|air|jump,
`move_now()` returns a string) reads content/dash_flow/<kit>.json rows, with content/rules/dash_feel.json and
content/rules/hunter_move.json per-kit sections layering more numbers. Four partial copies of "what dash is this":
`move_kind` (S), `dash_is_ex` (B), `ex_next` (B), the kit's `last_dash_kind` (S). Owner bug 3.1.

### 2.5 Ability phases (scripts/arch/arch_kit.gd + 12 kits)

Base (arch_kit.gd): `rmb_down`:20 B + `rmb_t`:21 T + `rmb_ctx` D (the press context), `e_t`:23, `r_t`:24, `dash_t`:26
(-1 sentinel = "not holding"), `bonded`:25, `full_was`:17, `cd` dict, `ch_rmb`, `chg` D, `fuse` D, `bot_hold` dict,
`res_wait`, `cd_off`:35. `press_rmb` 221-233 decides on the PRESS whether this is a tap (no hold variant or airborne:
fire now) else waits; `_release_rmb` 235-243 decides tap vs hold by `rmb_t >= hold (0.3)`; `tick` 156-199 auto-fires
at `rmb_auto_t()` and ends E/R by timer; `busy()`, `cast_locked()`, `gate_inputs()`, `locks_glide()` are per-kit
overrides that AirLimits and the hunter poll. There is no WINDUP / ACTIVE / RECOVERY / COOLDOWN state: each kit keeps
its own dicts and timers for them.

Per kit (hold/tap mentions, `_t` vars, bools): bulwark 65/13, 5, 6 (`mace{st: wind|fly|ground|back}`:28 and 527-613,
`lmb_t`:29, `hold_blocked`:50, `dash_after_plant`:53, `flared`:39, `wall` D); juggernaut 61/14, 5, 4 (`slam_w` D,
`lunge` D, `meteor`, `riposte`, `warchain`, `rmb_queued_at`:45 timestamp buffer, `dash_held`:46, `lunge_full`:57,
`perfect_flashed`:58; `_locked()` 639, `_flush_buffer` 643, `busy` 264, `no_glide` 269); ashwick 43/5; rimewright
41/4; archer 32/9 (`pin_aim`:16, `rain` D 341-400); dolm 30/7; mage 29/5 (`wire` D, `run_t`, `reset_dash_boost`);
dredge 26/2; ostra 21/8; gunslinger 14/5; thief 10/2; tender 9/0. Allowed today: a press while `_locked()` is
buffered by timestamp and dropped if older than BUFFER (juggernaut 643-648: "tap did nothing"); `hold_blocked`
(bulwark) and `rides_dash` return BEFORE the recall check (352-363), so a recall press is swallowed while `fire_cd`
runs; `mace` is never cleared by `_drop_holds` (merge) or by going down (only `_catch` 612 clears it): the hammer can
lie on the ground for the rest of the match; `rmb_down` stays true through a stun only because `tick` polls
`h.stun_t` every step (178). Owner bugs 3.3, 3.4.

### 2.6 Farm avatar (scripts/home/home.gd `_move_player` 1157-1290)

`climb`:1085 D ("unused since the ledge float; kept for anything that clears it": dead), `lfl`:1088 D, `gliding`:1040
B, `glide_hold`:1041 T, `dash_t`:1042 T + `dash_v`:1043, `dash_charges`:1044 + `ex_cd`:1045 (DEBT.md:32: a copy of the
Hunter's), `crouch_on`:94 + `p_crouch_k`:95, `water.swimming`, `wedge_t`:3645, `train`:3982 D, plus the UI gate
`can_act := panel_open == "" and not Overlay.is_open() and not chat_open and train.is_empty()` (1162). Its own
numbers: `SPEED`, `JUMP_V`, `GRAV`, exponential pulls 14/6/4 (1193), `Hunter.GLIDE_SPEED * 1.15` (1192: the farm glides
15% faster than the match), `HunterMove.dash_exit`. The jump/glide decision (1233-1246) is a 4-term boolean. Owner
bug 3.8. ext/movement-unify moves the numbers into `Loco` + tuning.json and adds the same mirror machine; the farm
remains a second mover with its own flags until M5.

### 2.7 Kin in a match (scripts/match/kin.gd, kin_follow.gd, kin_companion.gd)

`state`:17 S with 12 values (shoulder, active, flying, returning, flying_home, fused, bench, away, dazed, downed,
reviving, wild; set at 147, 195, 315, 381-384, 463, 475, 484-492, 502, 560, 566, 727, 810, 885, 896, 940, 954-959,
1006, 1021) x `cmd`:31 S (follow, guard, chase, return; kin_follow.gd `set_cmd` 92-125) x `fly` D (`to`, `dest`,
`leap`, `rush`) + `settle`, `hold_at`, `chase_target`, `disengaged`:34, `rest_t`:33, `rescue_on`:52, `mending`:56,
`down_void`:58, `dazed_t`:70, `hesitate_t`:61, `think_t`:66, `stuck_t`:39, `steady_t`:40, `path_t`:37. 48 state x cmd
combos, about 10 meaningful; `state in [...]` lists appear 14 times (174, 332, 381, 498, 910, 1026, 1046, 1053 ...),
each a different subset. `cmd` index goes over the net (kin_follow.gd:15 `CMD_IDS`). Allowed today: `cmd == "guard"`
with `hold_at == INF` (idle 343 falls through to follow behaviour while the HUD says Guard); `state == "returning"`
while `cmd == "guard"` (kin.gd:809: the guard leash sends it home, then 381 puts it back active with `hold_at` kept:
an oscillation at the leash edge); `fly.dest == "shoulder"` while `state == "fused"`. Companion (kin_companion.gd):
`pose`:57 S + `pose_t`, `scan_t`, `gap_t`, `lead_t`, callouts by category string. Owner bug 3.7.

### 2.8 Farm Boki (home.gd, the `k` dictionary per Boki)

No state var at all: `k["goal"]` (28 reads; set by a 10-branch if-chain 1324-1417: at your side, bed, another Boki,
random ground, a seat, the house door, a haunt), `k["nap_t"]`, `k["hold_t"]`, `k["busy"]`, `k["joy_t"]`,
`k["fetch"]["phase"]` (fly|ground, 2830-2850), `k["bath"]`, `k["leap"]`, `k["hop"]`, `k["going_in"]`, `k["nap_go"]`,
`k["stare"]`, `k["z_t"]`, `k["chase_t"]`, `k["called_t"]`, `k["emote_t"]`, `k["say_t"]`. `_kin_act` 2778 dispatches
`KinWants.action()` (feed|nap|bath|brush|pet, kin_wants.gd:50-55) computed fresh per call while the running act is
spread over `hold_t`/`nap_t`/`fetch`/`bath`. home.gd:1456 derives a `"kstate"` meta ("sleep" if `nap_t > 0`) for the
model. STYLE.md:55 ("dictionaries are for data from JSON; state in code is typed vars or a small class") is the rule
this breaks most.

### 2.9 Monsters (scripts/match/mob.gd, boss.gd)

mob.gd: `st`:7 S (idle, chase, windup, lunge, recover) + `st_t`:8, `calm_t`, `death_t`, `stagger_t`:28, `engaged`:128
B; transitions 95-105, 183-211, 249-253, 267, 297, 324-350. A string state machine with no table: the cheapest pilot
for `Fsm` outside movement (one file, 538 lines, one queued branch touches it). A stun during windup -> recover
(183-185) is exactly a guarded edge. boss.gd: `dormant`:17 B, `buried`:36 B, `enraged`:22 B, `atk`:23 S (""/an attack
id) + `atk_t`, `phase`:18 int, `awake_t`/`invul_t`/`empty_t`, `dash_t`:34. Allowed today: `buried and not dormant and
atk != ""`.

### 2.10 Bots (scripts/match/bot.gd)

`h.ai` dictionary keys as state: `tgt`, `goal`, `goal_kind` (URGENT_GOALS), `land`, `cross`, `pad_at`, `detour_dir`,
`react_t`, `burst`, `aim_hold`; `think()` 58-350 is one 300-line function. It is a data brain, not a machine to
convert; it should READ the hunter's loco/life states (2.1, 2.2) instead of `h.gliding/h.dropping/h.over_void()`
(bot.gd:276). Note only.

### 2.11 Match flow (scripts/match/match.gd, main.gd)

`over`:48 B (`_finish` 5406), `paused`:56 B (set by Overlay signals 3862-3867), `result["ending"]`, `_finish_now`:122,
`raid`:74 S, `net_on`:111, `is_host`:116, `warden_done`:32, `glimmer_done`:37, `collapse_warned`:79,
`player_engaged`:4861, `train_t`:4854, start/`start_staged` 135-139, `_start_drop` 1201, `ship_jump` 1282,
`_end_soon` 5395, `_extract` 5315. The HUD derives the phase word every frame (hud.gd:819-823: "ISLANDS FALLING" or
`exits.clock_line()`). The screen switch is a string (main.gd:740 `show_screen("match"|"home"|"lobby"|"hatch"|
"town"|"title"|"results"|"prologue"|"interior")`) guarded by a generation counter `_gen` and `current`, with the loading
screen `_ld` as a side state. Allowed today: `over and paused`, `result.ending and not over`, a `show_screen` racing a
`start_staged` (handled by `_gen` checks in 4 places: the counter IS the state machine, unnamed).

### 2.12 Drop squad (scripts/match/drop_squad.gd, drop_launch.gd, drop_reticle.gd)

PLANNING (`planning`:22 B, `plan_t`:23) -> DEPART (`_depart` 127) -> per-hunter LAUNCH (`DropLaunch.locked`,
`launch_at`) -> SEPARATE (`can_separate`, `drop_solo`) -> FORMATION (`drop_follow`) -> DEPLOY. Leads/acks in dicts
(`leads`, `_ack`, `_bot_ping`). Covered by the life/drop machine (2.3) plus one small squad machine.

### 2.13 Tutorial (scripts/match/tutorial.gd)

`step`:41 int + `intro`:42 B, `flag`:58 B (means something different per step: 352 "dashed", 357 "ex-dashed", 360
"glided", 374 "card shown"), `held`:69, `recalled`:72, `need_back`:73, 9 timers (intro_t, card_t, done_t, flash_t,
nag_t, spot_t, down_t, stall_t, crouch_t), `wait`. `_is_done` 342-410 is a `match sid` over 17 step ids
(KEYS 18-20) reading hunter flags directly (`p.roll_t > 0.0`, `p.gliding`, `p.dropping`, `p.kin.state == "downed"`).
Allowed today: `flag` carried into the next step if `_finish` is skipped by `--tut-from` (209-212 resets it only on
the normal path... it does at 218: fine; but `held`/`recalled`/`need_back` are never reset between steps).

### 2.14 Farm tutorial (scripts/home/farm_tutorial.gd + content/rules/farm_tutorial.json) — the GOOD example

Data-driven: 12 steps (axe, chop, stone, house, hammer, task, feed, crop, buy, sell, hob, expedition), each with a
`stage(id)` computed from the save (87-110) and per-stage `hints`/`world` text and `waits` in the JSON. No flags,
219 lines. The match tutorial (2.13) should become this.

### 2.15 UI screens, panels, pause (home.gd, overlay.gd, hud.gd, match.gd)

`Home.panel_open`:42 is the panel's TITLE TEXT (home.gd:2427 `panel_open = title_txt`, interior.gd:410, hob_talk.gd:52
`TALK`, home.gd:4959 `"reveal"`), compared as a string in 29 places in home.gd, 11 in interior.gd, 9 in hob_talk.gd;
`chat_open`:3144, `building_now`:88, `building`:10, `train`:3982, `nook_view`:4535, `kin_tab`:2963 S, `exp_mode`:3278 S.
Overlay: `page`:14 S (pause, settings, saves, admin, dex, inventory, spawn) + `stack`:16 + `ctx`:15 + `listening`:18.
HUD: `wheel_open`:2968, `loot_open`:2512 (a dict or null), `full_map.map_open()`, `toggle_pack` 2860, `guide_hidden`:1036,
`_h_down`:1046, `abyss_cued`/`abyss_warned` 2040-2041. Match recomputes `map_up`/`on_panel` every frame (3762-3763)
and pauses through `Overlay.closed` (3862-3867). "Who owns the keys right now" is answered by 5 different
conjunctions (home.gd:1162, match.gd:3762, hob_talk, interior, hud). Allowed today: the emote wheel over the loot
window, chat over a panel, `panel_open == "Feed Pip"` colliding with a Boki named "Feed".

### 2.16 Economy flows (home.gd, home_econ.gd, core/econ.gd, core/care.gd, core/incubator.gd)

Feed: `_open_feed` 5046-5073 builds rows from `Save.d["items"]` (Care.FOODS) and `Save.d["crops"]`; `Econ.pantry`
(econ.gd:239-245) is the same two stores. The trough (econ.gd:52 starter feeder with `"food": ["kibble", ...]`, `fill`
233, `auto_refill` 265) pulls kibble OUT of items into the feeder's own `food` list; the feed panel never looks there.
`_care_feed` 5075 then needs `_care_start(k)` and `have > 0` and silently returns otherwise. Three places where food
can be, one state ("what can I feed it") computed from two of them. Owner bug 3.6. Incubator: an egg's state
(shelf -> slot warming -> ready -> hatched) is implicit in `slot` presence, `progress(e) >= 1.0` (incubator.gd:134-139)
and `home_incubator.gd:18 ready_ids`. Work: `home_work.gd` jobs are dicts with `kind` strings (work, carry, fetch) and a
`taken` map.

### 2.17 Camera (scripts/match/cam.gd, match.gd)

`follow_mode`:53 S (supervive|locked, Settings cam_follow), `style_id`:78 S (`use_style` 84), `cast_k`/`cast_zoom`/
`cast_left` 73-75 (the aimed-cast view is its own 3-var easing state), `zoom/zoom_to`, `top/top_to`, `yaw/yaw_to`,
`chase/chase_to` pairs, `shake_*`. match.gd: `cam_style`:63 S (747, 3640), `killcam_text`:62 S used as the "you are
dead/down" state (2242, 2410, 2513, life.gd:499), `spectating()` 5380, `cam.snap()` from 7 sites (lairs, arena,
exits). No mode enum; a killcam and a spectate are text plus a target.

### 2.18 Hunter input gates (hunter.gd 2018-2031 + 6 modules)

Listed under 2.1 but worth its own row: `AirLimits`, `KitStatus` (a `gnd_until` META on the entity, kit_status.gd),
`KinDowned.commit`, `MergeAugment.route`, `ArchKit.gate_inputs`, `DashFlow.route`, `Hunter._gate`. Each is a
"may this press pass" rule reading a different flag set. In the target design these become the guards of the
loco/life/slot machines (one place per edge), not a pipeline of press-droppers.

### 2.19 Status effects on the hunter (ent.gd + hunter.gd)

`stun_t`, `root_t`, `slow_t`/`slow_k`, `burn_t`, `fortify_t`:120, `haste_t`:119, `cloak_t`:118, `shield_t`:122,
`inv_t`:100, `reveal_t`:195, `phase_t`:225, `sick_t`:131, `hex` (Hex.active), KitStatus "rattled"/"grounded" metas.
These are fine as timers (they stack and overlap by design) EXCEPT where they change locomotion: `stun_t` and the
`lift` path (2.1) must enter STUNNED/KNOCKED through the machine.

### 2.20 Merge and carry (hunter.gd, kin_merge.gd, kin_downed.gd)

`merge_st`:161 D with `phase`, `merge_cd`:162, `merge_free`:163, `hold_kind`:146 S + `hold_until`:147, `KinDowned`
(297 lines: begin/tick/stop/carry with `h.stomp`-style dicts), `mounted()`:401 derived from the kin's state. A
transformation is a locomotion state too (`MergeKit.rising`, hunter.gd:2268). Folds into the loco table as MERGING.

### 2.21 Hunter animation (scripts/match/hunter_anim.gd) — a consumer with its own copies

18 bools, 21 timers deriving the pose from the hunter's flags: `was_grounded`:234, `was_rolling`:251, its own
`roll_t`:245 and `dash_t`:252, `dash_kind`:253 S, `air_t`:235, `takeoff_t`:237, `trick`/`trick_t`/`trick_done`
238-242, `act_kind`:191 S, `fidget`:228 S, `emote_id`:274, `down_t`:276, `km_*` 1118-1122. After 2.1/2.2/2.5 own
their state, this file reads `loco.state`/`loco.since` and its edge-detection copies go (M13).

## 3. Owner bugs (11-08) traced to a machine

| # | Owner bug | Machine | Trace (main) | Queued patch | Fixed for good by |
|---|---|---|---|---|---|
| 3.1 | Sparkle (mage) class dodge fires on Shift with a normal dash | 2.4 dash kind | hunter.gd:1137 decides `use_ex` from `not grounded` before the kit sees the press; mage_kit.gd:349-375 decides again from `wire`/`run_t`/`ult.airborne()`; `spend_dash` (arch_kit.gd) writes `h.ex_next`/`h.gliding` back; `ex_next` can stay true (2.1). Four variables, no `DashKind`. | none | M2b + M3 (one `DashKind` decided once in `do_dash`, passed to the kit; delete `move_kind`, `dash_is_ex`, `ex_next`, `last_dash_kind`) |
| 3.2 | Holding Space opens the glider | 2.1 glider | match.gd:3775 `inp["glide"] = jump held OR glide held`; hunter.gd:2561 `want = inp["glide"] or auto_glide`; 2593 opens once `air_t >= GLIDE_ENGAGE` (0.1 s): there is no "fresh press" state, only "held". | ext/glide-no-hold adds `_glide_armed` + `_glide_btn_held` (two more bools) | M2a: GLIDING has one entry edge "press while AIRBORNE/DASHING" guarded by `can`; `auto_glide`, `_auto_glide_held`, `_glide_armed`, `_glide_btn_held`, `shot_down`, the `glide_off_t` 0/9 trick all go |
| 3.3 | Kael RMB tap does nothing | 2.5 slot phases | arch_kit.gd:221-243 press/release; juggernaut_kit.gd:630-648 a press while `_locked()` is a TIMESTAMP buffer dropped when stale, `busy()` (264) denies during the riposte, `spend_rmb` (arch_kit 246) denies with a buzz when `ch_rmb < 1` (cooldown 2 s): three silent exits for one press | ext/kael-tap-ult-1108 adds `cd["tap"]` + `_tap_strike` (another timer) | M3a: `Slot` machine IDLE -> WINDUP -> ACTIVE -> RECOVERY -> COOLDOWN with one buffered press that is consumed or refused WITH a reason the HUD can show |
| 3.4 | Albert (bulwark) hammer never returns | 2.5 bulwark `mace.st` | bulwark_kit.gd:527-613 wind -> fly -> ground|back -> catch; `lie_t` is 0.0 in content/archetypes/bulwark.json so "ground" never auto-recalls; the recall press is swallowed when `hold_blocked` or `not h.can_fire() or h.fire_cd > 0.0` return first (352-357); `_drop_holds` (merge) and going down never clear `mace` | none | M3a: the hammer is a `Slot` machine HAND -> WIND -> FLY -> PLANTED -> RECALL with a timeout edge and an "owner downed/merged" exit edge; the recall press is a guarded edge, not a side effect of the LMB handler |
| 3.5 | Lace (archer) E slow causes a bounce | 2.1 impulse | the Hail Wall applies `{"type": "slow"}` per tick (archer_kit.gd:397) through `Effects._hit_opts` -> `Ent.hurt` -> `impulse(kb, opts.get("lift", -1.0))` (ent.gd:152); hunter.gd:774-778 any `lift >= 0.0` (a 0.0 from any zone/field row that carries "lift") sets `grounded = false` with no sideways push: one airborne frame, a landing next frame (`land_t`, dust, the anim "land") = the bounce. Likely cause; a check must confirm which row carries the lift | none | M2b: `KNOCKED`/`AIRBORNE` are entered only through `loco.go()` with a guard "a lift under the hop threshold is not a transition"; status rows cannot touch `grounded` |
| 3.6 | "Nothing to feed it" with kibble | 2.16 feed | home.gd:5046-5073 reads items + crops; the trough's `auto_refill` (econ.gd:265) moved the kibble into the feeder's `food` list; the panel never offers trough food and `_care_feed` returns silently | none | M8: one `Pantry.food_sources()` (items, crops, each feeder) and a feed panel that lists "in the trough" rows; the empty text names where the food went |
| 3.7 | Guard Boki stands under the hunter | 2.7 kin | kin_follow.gd:102-107 `set_cmd("guard")`: `hop_off` leaps to `side_spot(k)`, which falls back to `o.pos` (27-32) when the companion has no heel spot, and `hold_at = fly["to"]` = that point; `idle` (343-351) steers straight to `hold_at` with NO `separation()` (only `steer` 263 applies it); kin.gd:809 the guard leash then flips it to "returning" and back | none | M4: a `KinState` machine with `GUARDING` entered through a guard "hold spot is ground, >= separation_r from every ally" and a per-state steer; cmd becomes an input to the table, not a second state |
| 3.8 | Farm vs match movement drift | 2.6 farm avatar | home.gd:1157-1290 is a second mover: its own `dash_t`, `gliding`, `glide_hold`, `lfl`, numbers (`GLIDE_SPEED * 1.15` at 1192, pulls 14/6/4 at 1193), `_dodge()` copy (DEBT.md:32) | ext/movement-unify (Loco + tuning.json, the mirror Fsm in Home too) | M5: Home owns a `Loco.machine()` as AUTHORITY and deletes its copies; `--air-control-check` farm = Training Area parity stays the gate |
| 3.9 | (movement-unify FLAG) Motley's air Shift not cancelled by a glide press | 2.4 + 2.5 | ostra_kit.gd:259 `on_dash` runs its own move outside `roll_t`; `AirLimits.glide_locked` reads it through `move_running()` (anim id + timestamps) | owner call pending | M2a/M3: the kit's move is a slot state; DASHING -> GLIDING is one edge for every kit |

## 4. Ranked migration plan

Value = bugs prevented + feel (readout, predictable cancels). Risk = lines touched x how many branches touch the same
file. "Conflicts" are queued/READY ext branches on 2026-11-09 that touch the same files; "after" = merge those first.

| Order | Item | Value | Risk | Files | Conflicts with queued jobs | Notes |
|---|---|---|---|---|---|---|
| 1 | **M1 Fsm hardening + registry + FsmReadout + `--fsm-check`; delete scripts/feel/** | high (every later item; the readout the owner asked for) | low (+40 lines in fsm.gd, -1200 dead) | scripts/core/fsm.gd, scripts/ui/move_readout.gd -> fsm_readout.gd, tools/fsm_check.gd, tools/check_registry.gd, scripts/feel/*, tests/feel_test.tscn, tools/move_feel_check.gd, main.gd:676 | after ext/movement-unify (creates fsm.gd, move_readout.gd) | writes docs/decisions/0023-explicit-state-machines.md (this section 1) |
| 2 | **M3a ArchKit `Slot` machine (base) + Kael (juggernaut) + Albert (bulwark)** | very high (3.3, 3.4, 3.1 half, 3.9; every tap-vs-hold) | medium-high (arch_kit.gd 1133, two kits ~1900 lines; 11 kits read `rmb_down`/`rmb_t`) | scripts/arch/slot_fsm.gd (new), arch_kit.gd, juggernaut_kit.gd, bulwark_kit.gd, air_limits.gd (glide_locked reads slot states), hud (recast/ready text) | ext/kael-tap-ult-1108 (juggernaut_kit, tuning.gd): merge it first, then fold `cd["tap"]` into the machine; ext/dash-refresh-assist (gunslinger, ent.gd) | checks: --dash-flow, --kael-*, --bulwark-*, the recast-clarity shots; `refused == 0` in scripted runs |
| 3 | **M2a Hunter glider as a state (GLIDING entry edge)** | very high (3.2, 3.9, feathering, heat, lift) | medium (hunter.gd 2521-2600 + 2192-2270; air_limits.gd) | hunter.gd (net-negative: -8 flags), scripts/match/hunter_loco.gd (new, the table + hooks from Loco), glide_lift.gd, glide_dive.gd, drop_launch.gd | after ext/movement-unify, ext/glide-no-hold (both rewrite this block), ext/islands-deeper-1108 (hunter.gd) | checks: --glide-hold, --air-control-check, --airdash-glide, --air-limits, --mantle; GPU --mantle-clip before/after |
| 4 | **M2b Dash / rush / knock / stun / fly / mantle edges + one `DashKind`** | very high (3.1, 3.5, the roll-vs-knock order bug, buffers) | high (do_dash, dash_with, impulse, _physics order, 12 `on_dash`) | hunter.gd, hunter_loco.gd, arch_kit.gd (`spend_dash` stops writing hunter flags), dash_flow.gd, ent.gd (`impulse` through the machine), effects.gd rows | ext/dash-refresh-assist (ent.gd, match.gd, dash_reset.gd), ext/sable-bola-instant (thief_kit), ext/tenzo-playtest-1108 (dolm_kit) | tuning.json gets dash.* numbers still in hunter consts (DASH_TIME, DASH_BUFFER, DASH_JUMP_CARRY, coyote, jump_buf); delete `stagger_t`, `move_kind`, `dash_is_ex`, `ex_next`, `knock_t`, `fly_t`, `kb_t`-as-timestamp |
| 5 | **M2c Hunter life + drop machine** | high (2.2, 2.3; tutorial/HUD/bot read one state; spectate/killcam text) | medium-high (match.gd 15 write sites; net bits mapped, no VERSION bump) | hunter_loco.gd (life table), hunter.gd, match.gd (wiring lines only), life.gd, drop_squad.gd, drop_launch.gd, drop_reticle.gd, hud.gd:2036, tutorial.gd | ext/loading-screen-1108-r2 and ext/demo-record-ready-1109 (match.gd, big) | the drop sequence RIDING -> LAUNCHED -> DIVING -> DEPLOYED -> LANDED replaces 3 bools + 2 timers; drop_reticle stops writing `diving` |
| 6 | **M4 Kin state machine (states x cmd as input)** | high (3.7, hop/leap oscillation, 14 ad-hoc state lists) | medium (kin.gd 1216 + kin_follow 400; `CMD_IDS` kept on the wire) | kin.gd, kin_follow.gd, kin_companion.gd, kin_net (read only), home.gd kin rows that read `state` | none queued touch kin.gd | pilot the non-movement readout: the kin's machine shows on F7 beside the hunter's |
| 7 | **M5 Farm avatar: Home owns the same machine (authority)** | high (3.8 for good; deletes the second mover's flags) | medium (home.gd 1157-1290 + 1470-1610; frozen file, must be net-negative) | home.gd, hunter_loco.gd (shared table), home_dash_slot.gd, home_water.gd | ext/expedition-pick-simplify-1108-r2, ext/ui-void-masks-2, ext/islands-deeper-1108 (all touch home.gd) | after M2a/M2b so the farm adopts, not re-invents; `climb` dict deleted (its own comment says unused) |
| 8 | **M9 Mob + Boss AI tables (pilot outside movement; can run early in parallel)** | medium (few owner bugs; clean windup/stun edges) | low (mob.gd 538, boss.gd 824, one queued branch) | mob.gd, boss.gd | ext/perf-render-presets-1108b (mob.gd, render only) | a good first job for a worker new to the pattern; proves `--fsm-check` on a table with a timeout edge |
| 9 | **M3b remaining 10 kits onto `Slot`** (one job per 2-3 kits) | high (every hold/tap/recast/cancel; Lace, Sparkle, Motley) | medium per kit | the 10 kit files, hero_zones, ult files | sable-bola-instant (thief), tenzo-playtest (dolm), dash-refresh-assist (gunslinger) | order inside: mage, archer, ostra (3.1, 3.5, 3.9), then ashwick, rimewright, dolm, dredge, gunslinger, thief, tender |
| 10 | **M6 UI focus owner (`UiFocus`: NONE / PANEL id / OVERLAY / CHAT / TRAIN / BUILD) + HUD panel exclusivity** | medium-high (5 copies of "who has the keys"; title-string panel ids) | medium (home.gd 29 sites, interior 11, hob_talk 9, hud, match 3762) | scripts/ui/ui_focus.gd (new), home.gd, interior.gd, hob_talk.gd, hud.gd, match.gd, overlay.gd | ext/ui-void-masks-2, ext/expedition-pick-simplify-1108-r2, ext/reticle-style-1108 (hud/overlay): merge all three first | panel ids become constants, never titles |
| 11 | **M10 Match phase machine (LOADING / PLANNING / DROP / PLAY / CLOSING / ENDING / OVER)** | medium (2.11; HUD phase text; pause/over combos) | medium (match.gd frozen; new scripts/match/match_flow.gd) | match_flow.gd (new), match.gd (wiring), hud.gd:819, main.gd show_screen (`_gen` named) | loading-screen-1108-r2, demo-record-ready-1109 | the `_gen` counter stays; the machine names what it protects |
| 12 | **M7 Match tutorial -> data-driven stages like farm_tutorial** | medium (per-step `flag` reuse; 9 timers) | low-medium (tutorial.gd 667; content/rules/tutorial.json) | tutorial.gd, tutorial.json, hud tutorial card | none | after M2c so steps read life/loco states |
| 13 | **M8 Feed / pantry / trough one view** (not an FSM; the owner bug) | medium (3.6) | low (3 files, ~60 lines) | home.gd `_open_feed`, home_econ.gd, econ.gd, care.gd | expedition-pick-simplify (home.gd, other region) | can run any time, even before M1 |
| 14 | **M13 HunterAnim reads the machines** | medium (feel: no late/double anim edges; -39 state vars) | medium (hunter_anim.gd 2120) | hunter_anim.gd, warden_clips.gd (read only) | ext/anim-time-* (warden_clips.gd) | after M2a-c and M3 |
| 15 | **M11 Camera `CamMode` (FOLLOW / LOCKED / CAST / KILLCAM / SPECTATE / SNAP)** | low-medium | low (cam.gd 150 lines of state; 7 snap sites) | cam.gd, match.gd killcam_text sites, life.gd:499 | none on cam.gd | with the first camera feel job that comes in |
| 16 | **M12 Incubator egg state + work job kinds** | low | low | core/incubator.gd, home_incubator.gd, home_work.gd | none | when next touched |

Dependencies: M1 before everything (except M8, M9 which can start on the current Fsm). M2a before M2b before M2c.
M3a can run in parallel with M2a (different files; both touch air_limits.gd: M2a owns that file, M3a adds a
read). M5 after M2b. M6 after the three UI branches land. M13 last of the hunter items.

### 4.1 Rules for every migration job (put in the job brief verbatim)

1. The machine OWNS its state: no file but the owner writes it, and only through `go(to, why)`. The flags/timers it
   replaces are deleted in the same commit (grep every reader). A mirror `go(_derived())` is scaffolding for at most
   the first commit of the item.
2. Table + guards are data at the top of the owner file, with a `##` line per state saying what it means and which
   inputs leave it. Numbers (durations, buffers, windows) in content/rules/tuning.json under the machine's key.
3. The job's check drives scripted input through the machine (as tools/air_control_check.gd does) and asserts the
   expected state sequence AND `refused == 0`. `--fsm-check` passes. The F7 readout lists the machine.
4. Net shape unchanged unless a shape must change (then `Net.VERSION`). Saves untouched (none of these are saved).
5. God files stay under budget and shrink: hunter.gd 3500 cap (3334 now), home.gd 5950 (5349), match.gd 6950 (6357),
   hud.gd 3850 (3265). New logic goes in the module files named in the table.
6. Test in a fresh save and in the Training Area; GPU before/after clip via `jobq submit --needs gpu` for anything in
   M2/M3/M5; suite-fast on the final commit. READY post with the refused-count table from the check.

## 5. Scale and method

Counted with grep over scripts/ on main (vars declared `:= true|false` or `: bool`, `var *_t`, `enum` and `State.`):
hunter.gd 43 bools (17 at file scope) / 43 `_t`; hunter_anim.gd 18/21; match.gd 44/8; home.gd 37/7; main.gd 45/3;
hud.gd 31/6; kin.gd 13/12; arch_kit.gd 6/6; bulwark 10/5, juggernaut 9/5, dredge 7/5, ashwick 6/4, mage 2/6, dolm 4/5,
tender 5/3, thief 4/4, rimewright 4/3, gunslinger 3/3, archer 1/2, ostra 0/3; tutorial.gd 6/9; blight.gd 3/7;
mob.gd 1/5; boss.gd 3/5. Enum declarations: 7 (shroud_skin parts, top_down_camera Mode, feel_config DashInput, world
tiles, terrain_mesh edges, hunter_controller State, msg_lane); live state-machine enums: 0 on main, 1 on
ext/movement-unify (Loco.S). Read: hunter.gd 2157-2600, 766-835, 1123-1245, 2018-2036; arch_kit.gd 156-260;
juggernaut_kit.gd 630-700; bulwark_kit.gd 352-372, 527-616, 707-730; mage_kit.gd 349-375; archer_kit.gd 341-400;
home.gd 1157-1290; kin.gd 147-1068 (transitions), kin_follow.gd 27-125, 263-352; drop_squad.gd, drop_launch.gd,
tutorial.gd 165-218, 342-410; farm_tutorial.gd; overlay.gd; main.gd 740-800; cam.gd; mob.gd; boss.gd; incubator.gd;
econ.gd 227-270; care.gd; the ext/movement-unify Fsm/Loco/MoveReadout and decision 0022; the glide-no-hold and
kael-tap-ult diffs. Not run: any Godot check (read-only audit, no code changed).
