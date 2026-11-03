# 0010: Dash -> ability flow

- **Status:** accepted; amended by 0015 (combo flow: jump and hold rows, owner item 51) and below (dash buffering in the source, owner 19:50)
- **Date:** 2026-11-03
- **Area:** movement / combat

## Problem
Owner review item 32: dash -> ability presses must flow like the source, per hero and per pair, from one rule set. Today a press during a dash goes wherever its own code sends it: RMB, E, X and Q mostly fire mid-dash, an LMB tap is lost (`Hunter.can_fire` is false while `roll_t` runs), and a few kits drop or end the dash on their own (Vireo's X and Zedran's early air RMB are lost; Linwick's X ends the dash).

## Options
1. Per-kit special cases in each kit's cast code: what grew today; no table, nothing to check across heroes.
2. One helper, `DashFlow` (`scripts/arch/dash_flow.gd`), at the one point the presses are read (`Hunter.tick`, just before the dash and ability keys; `HunterKeys.ult_pressed` for X), reading per-hero rows from `content/dash_flow/<hero>.json` (one file per hero, so per-hero branches never touch the same file).

## Decision
Option 2. Per ground or air dash and slot (LMB, RMB, E, X, Q) a row says `fire` (mid-dash), `buffer` (held to the dash's end; the default for a missing row) or `cancel` (ends the dash; `carry` keeps its momentum). A held press is never dropped: it goes the step the dash ends, or up to `DashFlow.BUFFER_S` (0.15 s) later while the hunter can't act yet, through its own path (cast or deny cue). Today's behaviour became the starting rows (fire where it fired), so the only change is that presses that used to be lost now buffer. `variant` and `into_dash` (Shift during an ability's wind-up or recovery) are data for the kits to read: the kits still decide the reverse direction (Dredge, Zedran, Vireo, Ostra and Tamsin refuse Shift during some abilities in `on_dash`; Bjorn holds it to the end of the Faultline plant).

## Consequences
- "In a dash" is `ArchKit.in_dash()` (the shared Effects dash). A kit that runs its dash in its own state overrides `in_dash()` and `dash_left()` (the seconds left, which `--dash-flow-check` uses to press on the dash's last step): Ostra's Trade flight and Breah's leap do. Until it does, it lists that dash in `kit_owns` and DashFlow doesn't route it (Tamsin's Rink Run, on the ground). Zedran's crouch before the drive and Vireo's charge before the Wirerun (`wire`) are outside it too.
- Kit-side cases for the per-hero rows to absorb: Venator's and Tamsin's `fires_in_dash`, Linwick's jet ending the dash.
- Check `--dash-flow-check`; table `docs/heroes/dash_interactions.md` (gen_wiki). No Net or save change.

## Amendment: Dash buffering in the source (owner 19:50)
Owner, 19:50 UTC: "whatever SUPERVIVE does" for presses made during a dash. Searched (paths under `/home/boki/briefs-s2/`): every file in `briefs/supervive-data/`, the 12 footage studies in `briefs/hero-ref/` (5 fps; Breah's guide is 4 fps), `briefs/kit-review/` (both rounds) and the owner notes.

**The rule found.**
- **Game data: nothing.** No dump has an input-buffer, queue or cancel-window field (searched for buffer, queue, InputBuffer, bCanBuffer, BufferWindow, cancel, "during", "while"). The movement dumps are the CharMoveComp blueprint overrides only; the ability system and every C++ default are encrypted on disk (`supervive_physics.md:94-96`), and the named-but-undecoded tunables (`:98-108`) list no input timing. The tooltips (`supervive_kits.md`) never say what a press inside a dash does.
- **Footage: every visible case fires mid-dash.** Shiv's empowered shot leaves on the same frame as the Cartwheel that empowers it (`dancer.md:131-134`, frame 0193; the Cartwheel runs 0.45-0.5 s, `:420-425`). Ghost fires the rifle through the slide (`venator.md:88`, 0149-0151; `:308`). Celeste fires the whole skate (`tamsin.md:78-79`, 0239-0245 and 0285-0290). Tetra's guide titles a tip "Punch to Extend Dash/RMB" (`breah.md:8-9`), but only its RMB half is resolved in frames.
- **Not seen anywhere:** a press held to the dash's end, a press lost, or a press expiring after a time. So **no window length can be read from the source**; each other hero x slot x dash is "not determinable" and keeps today's row (owner 18:20 UTC: source where known, else held to the dash end). Item 51 (any ability casts mid-dash where the source is silent) is why the silent `fire` rows stay `fire`.
- **Rows whose source text claims more than the briefs show:**
  - Pin LMB (`pin.md:247` lists shooting in Spirit Walk as an open question).
  - Linwick ground LMB (the data has no "no fire during it").
  - Dredge ground LMB (`dredge.md:306` shows aiming, not a shot).
  - Their modes stay; only the text changes.
- **One owner rule touches a dash row:** Tamsin's X from a skate carries her forward before the seal (INBOX 13:20 ET, refining item 27), so `dash.ground.x` becomes `cancel` with `carry`.

**BUFFER_S.** The source shows no time limit, so `DashFlow.BUFFER_S` (0.15 s, item 32's default; DECISIONS.md "about 0.1 s" for chaining) and its meaning stay. Today a `buffer` press never expires inside the dash: `held[slot]` starts at 0 at the press and only counts in `_release`, after the dash, while `kit.busy()`. If a source limit turns up (presses expire N s after the press), DashFlow would need three changes:
1. Age every held press in `route()` while dashing, not only after the dash.
2. At the dash's end, drop (with no replay) a press older than N.
3. `BUFFER_S` would then mean the maximum age since the press, not the grace after the dash.

`--dash-flow-check`'s "no input in the buffer window is lost" assert would need the same split.

**Per hero.** The rows to copy, with the full citations, are in `content/dash_flow/_source_buffering.json`. The game doesn't read that file; each hero's agent applies its own rows to `content/dash_flow/<hero>.json`. In the table:
- **Source:** what SUPERVIVE shows, with the confidence in brackets.
- **Ours -> recommended:** the row today, then the row to use.
- **[source]:** keep the mode, fix or fill the source text.
- **[add]:** write the missing row out explicitly.
- **[carry]:** flip the carry flag.
- **Q:** gloves are ours, so Q has no source anywhere.

| Hero (source) | Slot | Ground dash: source; ours -> recommended | Air dash: source; ours -> recommended |
|---|---|---|---|
| Dancer (Shiv) | LMB | **fires mid-dash** (medium); ours fire (empowered) -> fire | fires mid-dash, inferred (low); ours fire (empowered) -> fire |
| Dancer (Shiv) | RMB | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Dancer (Shiv) | E | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Dancer (Shiv) | X | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Dancer (Shiv) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Zedran (Brall) | LMB | unknown; ours buffer -> buffer | unknown; ours buffer -> buffer |
| Zedran (Brall) | RMB | unknown; ours fire +carry -> fire +carry | unknown; ours cancel -> cancel |
| Zedran (Brall) | E | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Zedran (Brall) | X | unknown; ours cancel -> cancel | unknown; ours cancel -> cancel |
| Zedran (Brall) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Pin (Myth) | LMB | unknown; ours buffer -> buffer [source] | unknown; ours buffer -> buffer [source] |
| Pin (Myth) | RMB | unknown; ours fire -> fire | unknown; ours fire -> fire [source] |
| Pin (Myth) | E | unknown; ours fire -> fire | unknown; ours fire -> fire [source] |
| Pin (Myth) | X | unknown; ours fire -> fire | unknown; ours fire -> fire [source] |
| Pin (Myth) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Bjorn (Oath) | LMB | unknown; ours buffer -> buffer | unknown; ours buffer -> buffer |
| Bjorn (Oath) | RMB | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Bjorn (Oath) | E | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Bjorn (Oath) | X | unknown; ours cancel -> cancel | unknown; ours cancel -> cancel |
| Bjorn (Oath) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Vireo (Joule) | LMB | unknown; ours buffer (missing row) -> buffer [add] | unknown; ours buffer (missing row) -> buffer [add] |
| Vireo (Joule) | RMB | unknown; ours fire -> fire [source] | unknown; ours fire -> fire [source] |
| Vireo (Joule) | E | unknown; ours fire -> fire [source] | unknown; ours fire -> fire [source] |
| Vireo (Joule) | X | unknown; ours buffer (missing row) -> buffer [add] | unknown; ours buffer (missing row) -> buffer [add] |
| Vireo (Joule) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Venator (Ghost) | LMB | **fires mid-dash** (high); ours fire -> fire [source] | unknown; ours fire -> fire [source] |
| Venator (Ghost) | RMB | unknown; ours fire -> fire [source] | unknown; ours fire -> fire [source] |
| Venator (Ghost) | E | unknown; ours fire -> fire [source] | unknown; ours fire -> fire [source] |
| Venator (Ghost) | X | unknown; ours fire -> fire [source] | unknown; ours fire -> fire [source] |
| Venator (Ghost) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Linwick (Felix) | LMB | unknown; ours buffer -> buffer [source] | unknown; ours buffer -> buffer |
| Linwick (Felix) | RMB | unknown; ours buffer -> buffer | unknown; ours fire -> fire |
| Linwick (Felix) | E | unknown; ours buffer -> buffer | unknown; ours fire -> fire |
| Linwick (Felix) | X | unknown; ours cancel +carry -> cancel +carry | unknown; ours cancel +carry -> cancel +carry |
| Linwick (Felix) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Dredge (Kingpin) | LMB | unknown; ours buffer -> buffer [source] | unknown; ours buffer -> buffer |
| Dredge (Kingpin) | RMB | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Dredge (Kingpin) | E | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Dredge (Kingpin) | X | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Dredge (Kingpin) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Moosh Moosh (Elluna) | LMB | unknown; ours buffer -> buffer | unknown; ours buffer -> buffer |
| Moosh Moosh (Elluna) | RMB | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Moosh Moosh (Elluna) | E | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Moosh Moosh (Elluna) | X | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Moosh Moosh (Elluna) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Tamsin (Celeste) | LMB | **fires mid-dash** (high); ours fire +carry (beam) -> fire +carry | owner; ours buffer -> buffer |
| Tamsin (Celeste) | RMB | unknown; ours fire +carry -> fire +carry | owner; ours buffer -> buffer |
| Tamsin (Celeste) | E | unknown; ours fire +carry -> fire +carry | owner; ours buffer -> buffer |
| Tamsin (Celeste) | X | owner; ours cancel -> cancel +carry [carry] | owner; ours buffer -> buffer |
| Tamsin (Celeste) | Q | unknown; ours fire +carry -> fire +carry | owner; ours buffer -> buffer |
| Breah (Tetra) | LMB | **fires mid-dash** (low); ours fire +carry -> fire +carry | unknown; ours buffer -> buffer |
| Breah (Tetra) | RMB | unknown; ours fire +carry -> fire +carry | unknown; ours fire -> fire |
| Breah (Tetra) | E | unknown; ours buffer -> buffer | unknown; ours buffer -> buffer |
| Breah (Tetra) | X | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Breah (Tetra) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Ostra (Void) | LMB | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Ostra (Void) | RMB | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Ostra (Void) | E | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Ostra (Void) | X | unknown; ours fire -> fire | unknown; ours fire -> fire |
| Ostra (Void) | Q | unknown; ours fire -> fire | unknown; ours fire -> fire |
