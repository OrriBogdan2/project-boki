# Hit flinch by strength (ext/anim-flinch-data)

`--clip-shots --warden=<arch> --clips=none --flinch [--solid|--heavy]`: running at 4 m/s, hit from the front 0.2 s in,
every other frame of 1 s. Rows: chip hit (3% of max health, 2 m/s knock: hit_k 1.19, layer weight 0.49), solid hit (9%,
8 m/s: hit_k 2.09, weight 0.82); Vex adds a stagger row (hit_k 2.6: the whole-body hit clip). Legs keep the run in
the first two rows; the arms flinch further on the solid hit.

Rendered locally with xvfb + opengl3 (the jobq gpu queue had ~100 jobs ahead). Albert is shot from further out
(`--dist=11 --at=1.5`). Vex = gunslinger, Kael = juggernaut, Albert = bulwark (`--warden` takes the arch id).
