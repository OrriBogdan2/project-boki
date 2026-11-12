# ADS camera (Supervive "ADS camera distance 12700 uu")

Status: spec only, nothing built (PARITY FIRST, DECISIONS 2026-11-07). Evidence is too thin to build.

## What the source says
- Only one line exists: `briefs/supervive-data/supervive_physics.md:16`, "ADS camera distance | 12700 uu | Fog-of-war radius x1.25, 30° cone".
  PHYSICS_PARITY.md:43 repeats it as "not audited". Beside it, CameraDistance is 5500 uu for all 12 hunters.
- 12700 / 5500 = 2.31. That reads as the camera boom length, not a pan: if the view is the same lens, a boom 2.3x longer shows ~2.3x the width.
  But the note says the fog-of-war radius is only x1.25 and the view is a 30° cone, so the sight (vision) range grows 25% inside a narrow cone. This is
  a vision mode (look further in one direction), not a zoom of the whole screen. The two readings disagree; the data does not say which.
- Which input: unknown. The data names none. Not found in supervive_kits.md, hero-ref sheets (5 fps) or the wiki. The nearest
  matches are hold-to-aim kit inputs (Vex's Palm Lance, Lace's draws, Linwick's Fire Bolt) but no sheet records the camera moving for them;
  the sheets say "no per-hero camera change" (bjorn, breah, linwick) and "one fixed zoom" (linwick.md:242, mooshmoosh.md:264).
- Closest real analogue: Breah's Stonesight (breah.md:22-44): hold Sneak, a 35-40° pale cone that follows the cursor and widens
  the longer it is held. It matches "30° cone" best, so ADS is probably the Sneak (crouch) vision, shared by all hunters, not a gun scope.
- Speed and amount of pan/zoom: not measurable from any sheet.

## What we already have
- `cam.gd` `cast_view()` (item 68): aimed casts (gunslinger Needle, view_zoom 0.25, range 18) widen the view 25% and lean along the aim
  over ~0.2 s (CAST_EASE 16). That is the only "look further while aiming" behaviour, and it is hold-to-aim, like the source's long shots.
- Cursor pan presets (`FOLLOW`): supervive caps the lean at 7.5 m.
- Sneak key is `crouch` (settings.gd:114), "Sneak". DECISIONS tutorial line: crouch lets you "see further". No new key is needed for a Sneak-bound view.

## Fit and options
A. Do nothing (recommended now). cast_view already covers hold-to-aim long shots. No evidence for a separate ADS key. Controls list is final (R ult, X fuse, Q/V gloves, 1-4 belt, F, Y, Shift, E).
B. If the owner reads the row as the Sneak vision cone: while crouched, widen the view `cast_zoom`-style by ~0.25 and lean toward the cursor, behind a `cam_style` preset flag, no new key, ~0.2 s ease (same as CAST_EASE). Small change in cam.gd plus a fog-radius x1.25 in a 30° cone. Needs a vision/fog rule check first.
C. A dedicated ADS key: not recommended; unsupported by the data and DECISIONS lists no free key (Settings.key_cap must show it).

## Recommendation
Do not build. To settle it, the owner can supply 60 fps footage of a hunter holding Sneak with a long-range weapon and the default camera; measure screen
width in metres before and after. If the width grows ~25%, take option B.
