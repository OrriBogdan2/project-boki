## Dash facing and aim, every Hunter (`--move-feel-check` "dash facing" rows, 2026-11-22)

Asked: through a dash, does the body face the dash and turn back to the cursor at the end, and does an LMB pressed
mid-dash go out along the cursor? `tools/move_feel_dash_turn.gd` runs one row per Hunter on the real match step: the
cursor held north, a tap dash east (a side dash), a tap dash south (back the way the cursor faces), LMB down on the
fourth step of the side dash and held. Read: the body's angle off the cursor at the press, mid-dash, one step after the
dash and 6 steps after it (9 after the back dash: a 180 takes 8.4 steps at `turn_rate` 1280 deg/s), the widest the body
turns off the cursor in the back dash, and the first round's angle off the cursor. A swing counts as its fan's mean
direction, and what the dash throws itself (Albert's spin) is taken out first by a run with no LMB.

The rule (`Hunter._physics`, `ArchKit.aims_in_dash`, no code changed): a kit whose LMB fires in the dash keeps the body on
the cursor; every other body turns along the dash at the source's yaw rate and is back on the cursor within 0.1 s of
its end. A press that waits (the "buffer" rows in `content/dash_flow`) goes out along the live cursor once the dash is
over, never along the dash. The clip layer turns the model along the travel for the kits that keep the body on the
cursor (`heading` / `legs_heading` in `content/rules/warden_anim`).

| Hunter (source) | Source frame of the body through the dash | Ours: mid-dash, off the cursor | LMB mid-dash: round off the cursor |
|---|---|---|---|
| Lace (Hem, pin.md) | [?] no frame: pin.md:361 "roll follows movement or aim" is open; the roll is a forward dive (pin.md:325) | on the cursor (1-2 deg), legs carried by the `heading` clip | 0.0, after the dash (draw released) |
| Kael (Brall, juggernaut.md) | body goes flat along the path (juggernaut.md:263); "dash in your facing direction" | along the dash (90 deg), 69 deg at end+1, 1 deg at end+6 | 0.0, after the dash (buffer row) |
| Vex (Ghost, venator.md) | 0150-0151: slides up-left, aims and fires up-right, "no turning to the slide direction" | on the cursor (1 deg) | 0.3, in the dash |
| Albert (Oath, bjorn.md) | [?] no frame of the body: the 360 Smash is a dash then one spin (bjorn.md:129-142) | along the dash (90 deg), 69 / 1 deg | 0.0, in the dash (the smash's fan, mean direction) |
| Neve (Celeste, tamsin.md) | skater's stance facing the aim while firing (tamsin.md:277) | along the dash with no LMB; on the cursor (1 deg) once LMB is down | 0.0, in the dash |
| Cinder (Felix, linwick.md) | head-first lunge, body stretched along the dash (linwick.md:79); the dash goes to the cursor | on the cursor (1 deg); the `heading` clip points the lunge along the travel | no round (the stream is aimed by the cursor) |
| Tenzo (Tetra, breah.md) | dash and red aim line toward the cursor (breah.md:156); body turns at once (breah.md:427) | on the cursor (hop goes to the cursor) | no round (punch lane, aimed by the cursor) |
| Sparkle (Joule, vireo.md) | [?] no frame: Surge goes toward the cursor, she faces the cursor (vireo.md:28, 72) | on the cursor (surge goes to the cursor) | 0.0, in the dash |
| Grimble (Kingpin, dredge.md) | turns back to the aim within about 0.1 s after a dash (dredge.md:296, 493.45-493.55 s) | along the dash (90 deg), 69 deg at end+1, 1 deg at end+6 (0.1 s) | 3.0 (shotgun sway), after the dash |
| Meeko (Elluna, mooshmoosh.md) | [?] f155-158 show the dash along the movement with the cursor far left, no body read (mooshmoosh.md:85) | along the dash (90 deg), 1 deg at end+6 | 0.0, after the dash |
| Sable (Shiv, dancer.md) | [?] a sideways cartwheel with the body turning in the plane of travel (dancer.md:120, 275); no read of the facing | on the cursor (2 deg), cartwheel `heading` clip | 2.0, in the dash |
| Motley (Void, ostra.md) | [?] no frame: the Trade is a lob, she does not travel | on the cursor (the body stays; no travel) | 0.0, in the dash |
| Gil (ours) | [?] our own Hunter, no source hero | on the cursor (1 deg) | 25.0 (his thrust fan edge), in the dash |

Before and after (same check, same box, `MOVE FEEL CHECK DONE`): main 626 `MFEEL` lines, failures: 14; branch 640 lines
(14 new: the 13 Hunters and `dash_back_on_cursor_deg`, worst 1.2 deg against the 5 deg limit), failures: 14, the same
14 older rows (none of them a dash-facing row). No stray found, so no kit or HunterAnim change: every Hunter's body is
back on the cursor inside the source's 0.1 s and every LMB goes out along the cursor. Open: the [?] rows stay on the
shared rule until footage shows the body in a dash.
