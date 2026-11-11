# Eyelid blink (close-ups)

`scripts/heroes/warden_blink.gd` (WardenBlink) blinks a Hero's modelled lids in close-ups: hero select, the Model
Room, the relic put-on. Every 2-6 s (random) a Timer wakes it; if the camera is within `WardenGlb.FAR_HIDE_D` (13 m,
the far-camera distance) of the head, the lids close over the clip's pose for 0.15 s (0.04 down, 0.04 shut, 0.07 up),
one blink in five a double. Past that distance (every match camera) it never blinks and runs nothing per frame.
The closed pose is data (`blink` in `content/rules/warden_anim/<art>.json`, see [CLIPS.md](CLIPS.md)): the deepest
the art's own clips shut each lid. `--warden-blink-check` holds both; `--warden-blink-shots --shots-dir=<dir>` draws
an open | closed close-up per Hero.

No .glb has blink blend shapes (no morph targets on any Warden); lids are bones.

## Hunters with lids (blink on)
| Art | Hero (id) | Lid bones | Closed |
|---|---|---|---|
| hem | Lace (archer) | lid.R, lid.L | turn 0.92 rad on Y (mirrored) |
| claire | Neve (rimewright) | lid.R, lid.L | turn -0.82 rad on X |
| ryzz | Sparkle (mage) | lid.R, lid.L | turn -0.82 rad on X |
| sable | Sable (thief) | lid.R, lid.L | turn -0.82 rad on X |
| cinder | Cinder (ashwick) | lid.R, lid.L | turn 1.30 rad on X |
| pip | Meeko (tender) | lid.R, lid.L | slide 0.05 m along the bone |
| vex | Vex (gunslinger) | lid.L only | turn -1.05 rad on X |
| dredge | Grimble (dredge) | lid (one eye) | turn -0.95 rad on Y |

## Hunters with no lids (for the art lane)
No eyelid bones and no blend shapes, so they stare in close-ups until the art lane gives them lids (`lid.R`/`lid.L`
under `head`, keyed in their clips); then add a `blink` block and the check covers them.
- **breaker** (Albert, bulwark): a glass face; WardenMood's face shader already blinks on a fixed 3.7 s beat.
- **kael** (Kael, juggernaut)
- **tarek** (Tenzo, dolm)
- **ostra** (Motley, ostra): `x_boxlid` is the box's lid, not an eyelid.
