# Boki roster

The roster is array G of `briefs/boki-art/ROSTER_100.html` (ext/agent-briefs), per the owner decision
"roster of 109, evolution, sex, Inks" (2026-11-08). The 18:07 owner note "three stages is now the default"
grew G to **124**; the game follows G. History of the first 50: ROSTER_50.md.

- **Every species is a file** `content/kin_v2/<id>.json`. Old ids stay (cindle is Vespyx); new species use
  their lowercase name. Each has `theme` (first type), optional `type2`, and a `roster` block: art status
  (locked, todo, new), the line's first form, the stage, the form it evolves `from`, and the `raised`
  path (fierce, steadfast, curious, swift) or `ink` (a theme) that picks a branch (docs/KIN_GRAMMAR.md).
- **Live vs data-only.** 51 species are live (a model or the generic parts, home data in `content/kin`).
  The other 73 have no model yet and are `data_only`: name, types, description and links only, never
  spawned. A species goes live by filling in the full grammar and its home data.
- **Types** gain tide, wyrm and wild (`KinParts.THEMES`).
- **Mystery egg** = Ermink (wild, `Hatch.MYSTERY`), live on the generic parts until its model ships. Its nine
  Ink forms and Jarmit's line are data-only.
- **Riding:** any large grown or final form with mount speed x1.1 or more is rideable; no upper cap.
- Check: `godot --headless -- --roster-check` (tools/roster_check.gd).
