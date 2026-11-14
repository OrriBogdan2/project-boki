# Raised axe and pickaxe at the farm camera (ext/anim-tool-swing-clear)

`--tool-raise-shots --shots-dir=<dir>` (tools/tool_raise_shots.gd): rows are Albert axe, Albert pickaxe, Kael axe,
Kael pickaxe; columns are the Hunter turned 0, 45, 90 and 180 degrees from facing away from the camera, at the top of
the swing, at the Settings default camera (66 degrees down, body leaned back 20).
`before_xvfb.jpg` is the poses of origin/main, `after_xvfb.jpg` this branch (xvfb, opengl3).

`after_gpu.jpg` is the same sheet from a real GPU (`jobq submit --needs gpu`, job 20261112-133409-19824, worker rp1-3);
its seen-shares (head / haft, per turn 0/45/90/180): Albert axe 97,100,100,99 / 60,53,53,86; Albert pickaxe
99,100,99,100 / 42,41,44,85; Kael axe 97,100,100,98 / 76,77,77,68; Kael pickaxe 99,99,99,97 / 63,66,65,61.
The "before" GPU job (origin/main's poses) was still queued when the branch was pushed; the xvfb pair above is the comparison.
