# Spirit Walk (Lace Shift): before | after, against the footage

`--parity-strip --hero=archer --slot=dash --frames=349-366 --hold=1.4 --pillar=5.5 --footage-dir=<footage/pin>` at the
match camera, 5 fps from the press: ours on the top row of each pair, footage pin 0349-0366 below (frame 0349 =
the press). A dark pillar stands on one rock tile 5.5 m ahead; she rolls, walks through it and stops 1.4 s in,
the walk running on to its end. Our pillar is closer than the footage's (in at +1.0 s, out at +1.4 s; footage
in about +1.8 s, out about +2.6 s).

- `xvfb_before.jpg`: origin/main 88b06b9e7 (the strip tool from this branch). Nothing on her screen while she
  walks in the open, the dark blue wash only while inside the pillar (+1.2 s), no mark where she went in or out.
- `xvfb_after.jpg`: ext/vfx-lace-spirit-walk. Her own screen takes a wash of her deep shade for the whole walk
  (the grass about 15% duller, more at the edges), the full dark wash inside (+1.2 s), fading with her shell at
  the end (+3.2 s). A laced portal opens on each side of the pillar where she went in and came out (+1.2 s to
  +2.4 s), seen by every game. The roll shows only its trail, as before.

The xvfb pair is software GL (xvfb, opengl3, llvmpipe) on rpc5.

- `gpu_after.jpg`: ext/vfx-lace-spirit-walk 7ac757639 on a GPU (jobq 20261112-002459-18519, pc-MRROBOTO,
  RTX 4070 SUPER, OpenGL 3.3 compatibility; same arguments, re-run because the first job 20261111-220025-09470
  lost its tree). Same read as `xvfb_after.jpg`: dark wash inside the pillar (+1.2 s), a laced portal on the
  far side where she came out (+1.4 s on), held through the end of the walk. The whole-walk wash is subtle at
  this camera (the grass only a little duller than at +0.0 s); the footage's ghost world is much darker.
