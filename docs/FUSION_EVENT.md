# Fusion enter and release: readability scores

Every Fusion should feel like an event (briefs/DECISIONS.md): a release gives a 6 s rest plus afterglow, a timeout a
10 s rest, and a ground ring means gameplay (no bursts, rings or discs on moments that are not). The enter
(`MergeXform`, 0.7 s) and the release (`MergeRelease`, `MergeXform.separate`) were never scored per type.

**How:** `--fusion-event-sheet --shots-dir=<dir> [--only=a,b] [--slow=0.1]` fuses one Boki per look, then releases,
at the match camera on grass and on a dark floor; `fe_<look>_<ground>.png` has the enter on the top row (0.04, 0.25, 0.46,
0.6, 1.0 s after R) and the release on the bottom (0.1, 0.5, 1.5, 3.2, 5.0 s after). Looks: the 13 types that reach a
fallback form, plus the 3 kit forms (Stormwing, Tidal Shell, Titan; Fire and Flying Boki only reach those). Normal, Water
and Dragon have no species yet. The captures were rendered with xvfb + llvmpipe on rpc1 (the GPU queue was 17 h deep).
Strips: `docs/art/fusion_event/before_0..3.jpg` (all 16), `after_worst5.jpg`.

## Scores (0-3 each; /12)
Started = an enemy can tell a Fusion began; Type = the type reads; Afterglow = reads as resting; Clean = no ground ring or burst.

| Look | Started | Type | Afterglow | Clean | Before | After |
|---|---|---|---|---|---|---|
| Stormwing, Tidal Shell, Titan (kit) | 3 | 3 | 1 | 0 | 7 | (not re-shot) |
| Crystal, Dark, Grass, Poison, Psychic, Rock, Sound, Spore | 3 | 2 | 1 | 0 | 6 | (not re-shot) |
| **Bug** | 3 | 1 | 1 | 0 | 5 | 8 |
| **Electric** | 3 | 1 | 1 | 0 | 5 | 8 |
| **Fairy** | 3 | 1 | 1 | 0 | 5 | 8 |
| **Ice** | 3 | 1 | 1 | 0 | 5 | 8 |
| **Steel** | 3 | 1 | 1 | 0 | 5 | 8 |

**Before:** the flash read as an event, but it came with 3-5 ground rings on the enter, two on the release and a ring
and a burst on the afterglow (against DECISIONS). The type read only through glow colour and the small silhouette parts:
Bug, Electric, Steel and Fairy all glow cream or gold, and Ice washes out on grass. The afterglow was gone in about 0.5 s.

## What changed (worst five: Bug, Electric, Fairy, Ice, Steel)
`KinTypeFx.fusion` plays the type's cast accent twice in its colour plus a wide light column; no ring. `MergeXform`
(begin, contact, release, remote events, surge) and `MergeRelease.afterglow` and its 0.4 s sparkles call it instead of
`Fx.ring` and `Fx.burst`. All types get it, the five are the ones re-shot.
**After (the five):** Started 2 (the first 0.3 s is dots and the spiral until the flash at 0.46 s; the rings are gone),
Type 2 (accent in Bug amber, Electric yellow, Fairy pink, Ice cyan, Steel grey), Afterglow 2 (motes on the hunter through
about 1 s), Clean 2 (the shell bubble ring and the Boki's rest ring are gameplay and stay, as does the form ult's own ring).

## Left open
- The afterglow lasts 3 s but its motes are still faint past ~1.5 s; the 6 s rest shows only the Boki's rest ring.
- The vertical column foreshortens at the match camera (65 degrees), so it reads as a bright streak, not a pillar.
- Not re-shot after the change: the other 11 looks. The `kin-type-fx-check` asserts the Fusion moment draws no ring.
- Sound has no dots or streaks, so its Fusion moment is plain gold streaks until it gets its own accent.
