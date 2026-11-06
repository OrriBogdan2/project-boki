# Kael v2 redesign (owner-approved 2026-11-06)

| File | Model | Settings | Notes |
|---|---|---|---|
| kael_v2_master_sheet.png | Nano Banana Pro (no seed exposed) | 16:9, 4K edit pass | Final clothing pass: vivid crimson scarf and sash, wrist chains without hooks |

Prompt chain:
1. Three directions (Wall / Gladiator / Commander) → Wall.
2. A tall rectangular build.
3. Curse veins on one arm.
4. The X-harness outfit.
5. The two-tone ragged scarf (crimson over bone).
6. The scarf shortened to a collar.
7. The glowing sword restored.
8. Pale natural skin and crimson curse.
9. The clothing colour pass.

Design notes:
- Very pale skin, white mane, long scar.
- The scarf hides the mouth, except in the rage head.
- The curse spreads from the sword hand.
- The glowing cracked greatsword with a chain and hook on the pommel.

## Update (Nov 6, 12:44 ET)
| File | Model | Settings | Notes |
|---|---|---|---|
| kael_v2_master_sheet.png | Nano Banana Pro | 16:9, 4K edit | Eyes made visible (pale, sharp); a colour pass (neutral bg, true crimson); the tired head restored. Replaces the earlier master. |
| kael_v2_turnaround.png | Nano Banana Pro | 16:9, 4K | The 3D-modelling turnaround (sculpt-render style), colour-accurate; S2 models from this. |
| kael_v2_portrait.png | Nano Banana Pro | 1:1 (2000²) | Portrait bust: a three-quarter view, readable silver eyes, scar, crimson scarf, sword hilt and chain, curse at the neckline. Approved Nov 6. |
| kael_v2_splash_arena.png | Nano Banana Pro | 16:9, 4K, an edit chain | "The Hundredth Fight": seated cross-legged in a swept circle, a varied roster of arena champions at the edge. Chain: the original arena gen → the roster edit → the lion→executioner → the curse on one arm → the aura/space → the colour pass. Current pick; the fighter-scale edit didn't take. |
| kael_v2_splash_arena_foreground.png | Nano Banana Pro | 16:9, 4K, a fresh gen (refs: the colour-pass splash + the master sheet) | The arena splash with forced-perspective champions in the foreground corners (ogre L, executioner + war-hound R). Alternative to kael_v2_splash_arena.png. |
| kael_v2_splash_final.png | Nano Banana Pro | 16:9, 4K, a two-image merge (the knight layout + the moody dusk lighting) | **FINAL splash, "The Hundredth Fight".** Kael large and centre, glowing eyes and sword, the curse on one arm, a swept-sand ring; framing figures in the foreground (masked guard L, black knight R); the roster behind. |
| kael_v2_splash_final.png (replaced) | Nano Banana Pro | 16:9, 4K | Owner pick: the bright golden version (Kael large, a swept-sand ring, moderate red eyes, clean colours, the fighters at a distance). Replaces the darker foreground merge, which drifted magenta over repeated edits. |

## Splash: FINAL (Nov 6, 13:35 ET)
`kael_v2_splash_final.jpg`, "The Hundredth Fight".

Generation chain (Nano Banana Pro, 16:9, 4K):
1. The arena gen.
2. The varied champions.
3. The merge with the foreground framing (ogre L, executioner + war-hound R).
4. The scale fix ("realistic adult size next to him").
5. The duelist dives at him.
6. The stray blade removed.
7. The scarf edge redrawn (no lip-shaped fold).

Local colour pass (Python/PIL, not AI):
- Strong magenta → crimson (the scarf, eyes); weak magenta/purple → warm orange-brown.
- Gamma 1.15; a "spotlight" vignette (edges −50%, the top band −28%); Kael region +18%.
- Kael's skin desaturated ~40% toward neutral pale.
- The duelist dimmed 22%.

Replaces the earlier splash_final candidates.
