# 0010: Dash -> ability flow

- **Status:** accepted; amended by 0015 (combo flow: jump and hold rows, owner item 51) and below (dash buffering in the source)
- **Date:** 2026-11-03
- **Area:** movement / combat

## Problem
Owner review item 32: dash -> ability presses must flow like the source, per hero and per pair, from one rule set. Today a press during a dash goes wherever its own code sends it: RMB, E, X and Q mostly fire mid-dash, an LMB tap is lost (`Hunter.can_fire` is false while `roll_t` runs), and a few kits drop or end the dash on their own (Vireo's X and Zedran's early air RMB are lost; Cinder's X ends the dash).

## Options
1. Per-kit special cases in each kit's cast code: what grew today; no table, nothing to check across heroes.
2. One helper, `DashFlow` (`scripts/arch/dash_flow.gd`), at the one point the presses are read (`Hunter.tick`, just before the dash and ability keys; `HunterKeys.ult_pressed` for X), reading per-hero rows from `content/dash_flow/<hero>.json` (one file per hero, so per-hero branches never touch the same file).

## Decision
Option 2. Per ground or air dash and slot (LMB, RMB, E, X, Q) a row says `fire` (mid-dash), `buffer` (held to the dash's end; the default for a missing row) or `cancel` (ends the dash; `carry` keeps its momentum). A held press is never dropped: it goes the step the dash ends, or up to `Loco.press_buffer` (0.15 s) later while the hunter can't act yet, through its own path (cast or deny cue). Today's behaviour became the starting rows (fire where it fired), so the only change is that presses that used to be lost now buffer. `variant` and `into_dash` (Shift during an ability's wind-up or recovery) are data for the kits to read: the kits still decide the reverse direction (Grimble, Zedran, Vireo, Motley and Neve refuse Shift during some abilities in `on_dash`; Bjorn holds it to the end of the Faultline plant).

## Consequences
- "In a dash" is `ArchKit.in_dash()` (the shared Effects dash). A kit that runs its dash in its own state overrides `in_dash()` and `dash_left()` (the seconds left, which `--dash-flow-check` uses to press on the dash's last step): Motley's Trade flight and Tenzo's Rock Hop do. Until it does, it lists that dash in `kit_owns` and DashFlow doesn't route it (Neve's Rink Run, on the ground). Zedran's crouch before the drive and Vireo's charge before the Wirerun (`wire`) are outside it too.
- Kit-side cases for the per-hero rows to absorb: Vex's and Neve's `fires_in_dash`, Cinder's jet ending the dash.
- A press at the end of a stun, root or Grounded goes through the same held slots (0022, `--cc-exit-buffer-check`).
- Check `--dash-flow-check`; table `docs/heroes/dash_interactions.md` (gen_wiki). No Net or save change.

## Amendment: dash buffering in the source (DECISIONS "match the reference")
Re-checked 2026-11-23 (ext/feel-dash-buffer-source), building on the 11-03 finding (ext/dash-buffer-source 7690213d, `content/dash_flow/_source_buffering.json` there). Result: **not determinable**, so the default stands: a `buffer` press made at any point in a dash is held and goes the step the dash ends (then up to `Loco.press_buffer`, 0.15 s, while the hunter can't act). It never expires inside the dash and never cancels it.
- **Game data: nothing.** No dump has an input-buffer, queue or cancel-window field; the ability system and C++ defaults are encrypted, and the named tunables list no input timing. The tooltips never say what a press inside a dash does.
- **Frames checked (briefs/hero-ref on ext/agent-briefs):** every press seen inside a dash fires mid-dash, which is the `fire` rows, not a buffer: Shiv's empowered shot leaves on the Cartwheel's own frame (dancer.md:131-134, frame 0193); Ghost fires the rifle through the slide (venator.md:88, 0149-0151); Celeste fires the whole skate (tamsin.md:78-79, 0239-0245, 0285-0290); Tetra's "Punch to Extend Dash/RMB" (breah.md:8-9) resolves only its RMB half. A sweep of every hero-ref for buffer, queued, held to/until, a lost/dropped/eaten press or "after the dash ends" finds nothing new.
- **Not seen anywhere:** a press held to a dash's end, a press lost, or one expiring after a time. So neither how early a press is kept nor whether it fires at the end or cancels can be read; the 0.05/0.15/0.3 s-before-end assert waits for a source.
- If a source limit turns up: `held[slot]` would count from the press (not only in `_release` after the dash), a press older than the limit at the dash's end would be dropped with the deny cue, and `press_buffer` would mean the maximum age since the press; `--dash-flow-check` and `--move-feel-check` would assert it.
