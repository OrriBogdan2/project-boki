# Close-up blink

`scripts/heroes/warden_blink.gd` (WardenBlink) blinks a Hero in close-ups: hero select, the Model Room, the relic
put-on. Every 2-6 s (random) a Timer wakes it; if the camera is within `WardenGlb.FAR_HIDE_D` (13 m, the far-camera
distance) of the head, the lids come down for 0.15 s (0.04 down, 0.04 shut, 0.07 up), one blink in five a double.
Past that distance (every match camera) it never blinks, runs nothing per frame and draws nothing.

## How a lid is drawn
No .glb has blink blend shapes (no morph targets on any Warden), and on today's models no lid bone skins a single
vertex: the appeal3 swaps (Lace, Meeko, Cinder, Sparkle, ...) paint the eyes into the skin atlas, and Lace's v2
modelled lids (35 vertices each on lid.R/L, 91c6905ba) went with her appeal3 swap 5feab5daf. Posing the lid bones moved
nothing (job 20261111-123509-a1: 8 open/closed pairs, 0 pixels differ).

So each lid is a Decal: a skin-coloured ellipse with a dark lash rim at its bottom, projected 3 cm deep onto a painted
eye, riding the head bone. It hangs from the top of the eye and grows down to cover it, then goes back up; it is
hidden between blinks. Decals need the Forward+ renderer (desktop); on the compatibility renderer (web, mobile) the
eyes stay open.

The data is `blink` in `content/rules/warden_anim/<art>.json` (see [CLIPS.md](CLIPS.md)): `eyes`, each eye's middle
on the face, and `size`, one eye, in the model's bind space (m, the face looks along -Z); `skin`, the lid's colour (the
atlas's skin beside the eye). To place them, `--warden-blink-shots --shots-dir=<dir>` draws a straight-on close-up of
each Hero, open | closed (`blink_<art>.png`), and prints the frame: its middle in bind space and how many metres its
height covers; the image's right is the model's -X. `--warden-blink-check` holds the timing, the far camera and the
lid count.

## Hunters with lid bones (all blink)
| Art | Hero (id) | Lid bones | Eyes |
|---|---|---|---|
| hem | Lace (archer) | lid.R, lid.L | 2 |
| claire | Neve (rimewright) | lid.R, lid.L | 2 |
| ryzz | Sparkle (mage) | lid.R, lid.L | 2 |
| sable | Sable (thief) | lid.R, lid.L | 2 |
| cinder | Cinder (ashwick) | lid.R, lid.L | 2 |
| pip | Meeko (tender) | lid.R, lid.L | 2 |
| vex | Vex (gunslinger) | lid.L only | 2 |
| dredge | Grimble (dredge) | lid (one eye) | 1 |

## For the art lane
- **Modelled lids**: weight eyelid geometry (or a closed-eye blend shape) to the lid bones above, then drop that Hero's
  `blink` block; the decal is a stand-in for lids the meshes do not have.
- **No lids at all**: no eyelid bones and no blend shapes, so they stare in close-ups.
  - **breaker** (Albert, bulwark): a glass face; WardenMood's face shader already blinks on a fixed 3.7 s beat.
  - **kael** (Kael, juggernaut)
  - **tarek** (Tenzo, dolm)
  - **gil** (Gil, gil)
  - **ostra** (Motley, ostra): `x_boxlid` is the box's lid, not an eyelid.

  Where their eyes are painted on the atlas, a `blink` block (eyes placed from the shots) gives them the same decal
  blink with no art; not done here (the blink was scoped to Hunters with lid bones).
- Meeko's sun and cloud companions already blink through their mood atlas (`blink_cell`, WardenMood).
