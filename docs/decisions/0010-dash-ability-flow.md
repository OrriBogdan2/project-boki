# 0010: Dash -> ability flow

- **Status:** accepted; amended by 0015 (combo flow: jump and hold rows, owner item 51)
- **Date:** 2026-11-03
- **Area:** movement / combat

## Problem
Owner review item 32: dash -> ability presses must flow like the source, per hero and per pair, from one rule set. Today a press during a dash goes wherever its own code sends it: RMB, E, X and Q mostly fire mid-dash, an LMB tap is lost (`Hunter.can_fire` is false while `roll_t` runs), and a few kits drop or end the dash on their own (Vireo's X and Zedran's early air RMB are lost; Cinder's X ends the dash).

## Options
1. Per-kit special cases in each kit's cast code: what grew today; no table, nothing to check across heroes.
2. One helper, `DashFlow` (`scripts/arch/dash_flow.gd`), at the one point the presses are read (`Hunter.tick`, just before the dash and ability keys; `HunterKeys.ult_pressed` for X), reading per-hero rows from `content/dash_flow/<hero>.json` (one file per hero, so per-hero branches never touch the same file).

## Decision
Option 2. Per ground or air dash and slot (LMB, RMB, E, X, Q) a row says `fire` (mid-dash), `buffer` (held to the dash's end; the default for a missing row) or `cancel` (ends the dash; `carry` keeps its momentum). A held press is never dropped: it goes the step the dash ends, or up to `DashFlow.BUFFER_S` (0.2 s: one frame of the 5 fps source footage, the finest its chains resolve; see the window table in docs/heroes/dash_interactions.md) later while the hunter can't act yet, through its own path (cast or deny cue). Today's behaviour became the starting rows (fire where it fired), so the only change is that presses that used to be lost now buffer. `variant` and `into_dash` (Shift during an ability's wind-up or recovery) are data for the kits to read: the kits still decide the reverse direction (Grimble, Zedran, Vireo, Motley and Neve refuse Shift during some abilities in `on_dash`; Bjorn holds it to the end of the Faultline plant).

## Consequences
- "In a dash" is `ArchKit.in_dash()` (the shared Effects dash). A kit that runs its dash in its own state overrides `in_dash()` and `dash_left()` (the seconds left, which `--dash-flow-check` uses to press on the dash's last step): Motley's Trade flight and Tenzo's Rock Hop do. Until it does, it lists that dash in `kit_owns` and DashFlow doesn't route it (Neve's Rink Run, on the ground). Zedran's crouch before the drive and Vireo's charge before the Wirerun (`wire`) are outside it too.
- Kit-side cases for the per-hero rows to absorb: Vex's and Neve's `fires_in_dash`, Cinder's jet ending the dash.
- Check `--dash-flow-check`; table `docs/heroes/dash_interactions.md` (gen_wiki). No Net or save change.
