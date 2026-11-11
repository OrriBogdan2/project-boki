# Hushwood port (GARDEN.md 10.7 step 7c): zone shots

`--garden-zone-shots --zone=hushwood` on a real GPU: jobq 20261111-213321-32057 (worker rp1-2, rc=0, 74 s),
submitted from the worktree of the session that built ext/hushwood-port (port commit 2e1bf92f9; that tree is gone,
but the port's moss and motes show in the frames).

- `zone_day.jpg`: the island by day. Gloom flora (purple ferns, mushrooms, pebbles), lantern moss tufts
  (teal dots) and the drifting motes; Training post, dig patch and snack patch next to the return pad.
- `zone_night.jpg`: the same view at night. The moss and motes stay lit against the dark ground.
- `zone_wide.jpg`: the whole island with its neighbours.

The log has no script errors. It does show 3 `!is_inside_tree()` engine errors from
`home.gd _slice -> _ready_rest`, which build a Hunter rest pose before the node is in the tree.
These are not part of this change. The day shot is brighter than the "dusk" the theme aims for, because
the shot takes the zone's clock at noon. That is a look note only.
