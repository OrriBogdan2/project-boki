extends RefCounted
## --cliff-mantle-check's ledge census (DECISIONS: ledges always responsive). Every ledge the Hollow
## Crown's generator makes is sampled by its height: terrace steps 1..N terraces (World.LEVEL each), the sides of
## stair flights (a face that grows along the flight), sheer cliff lips, ruin walls and boulders (World.BLOCK_H) and
## island rims over the abyss. Then a light, a medium and a heavy Hunter (Meeko, Vex, Albert) fly into faces of each
## height from a run (a running jump), a standing jump and a glide. A height inside the reach (a jump's apex plus
## Hunter.MANTLE_REACH, or the glide's) must top every try with no snap; a height past it must never top by jumping.

const HEROES := ["tender", "gunslinger", "bulwark"]  # light Meeko, medium Vex, heavy Albert (the brief's classes)
const MODES := ["run", "jump", "glide"]
const PER_HEIGHT := 6  # faces driven per height bucket
const SNAP_M := 0.2  # m: one step's move this far off what its velocity explains is a snap

var c  # the cliff check (tools/cliff_mantle_check.gd): its Match, Hunter, _try
var census := {}  # "kind height" -> faces counted, over both tiers
var rows := {}  # "height kind hero mode" -> {n, top, snap}


func _init(check) -> void:
	c = check


## Every ledge on the current map, by kind and height, and the faces to drive (a few per height).
func sample() -> Array:
	var w: World = c.w
	var picks := {}
	for z in w.h:
		for x in w.w:
			if w.kind[w.idx(x, z)] != World.T_GROUND:
				continue
			for d: Vector2i in c.DIRS:
				var b := Vector2i(x, z) + d
				if not w.inb(b.x, b.y):
					continue
				var f := _face(Vector2i(x, z), d)
				if f.is_empty():
					continue
				var key := "%s %.2f" % [f["kind"], f["h"]]
				census[key] = int(census.get(key, 0)) + 1
				if f["kind"] in ["step", "stair_side"] and c._runway(Vector2i(x, z), d):
					picks.get_or_add(key, []).append(f)
	var out: Array = []
	for k in picks:
		var arr: Array = picks[k]
		var stride := maxi(1, ceili(arr.size() / float(PER_HEIGHT)))
		for i in range(0, arr.size(), stride):
			out.append(arr[i])
	return out


## The ledge from low tile a up into its neighbour along d: {kind, h, a, d, rise, la}, or {} for no ledge.
func _face(a: Vector2i, d: Vector2i) -> Dictionary:
	var w: World = c.w
	var b := a + d
	var ib := w.idx(b.x, b.y)
	var ga := w.level[w.idx(a.x, a.y)] * World.LEVEL
	if w.stairs.has(w.idx(a.x, a.y)):
		return {}
	var edge := Vector2(a.x + 0.5, a.y + 0.5) + Vector2(d) * 0.5
	if w.kind[ib] == World.T_BLOCK:
		return {"kind": "wall", "h": w.block_top_of(ib) - ga}
	if w.kind[ib] != World.T_GROUND:
		return {}
	var dv := Vector2(d) * 0.02
	var hb := w.ground_at(edge.x + dv.x, edge.y + dv.y) - ga
	if hb <= World.STEP:
		return {}
	var kind := "step"
	if w.sheer.has(ib):
		kind = "sheer"
	elif w.stairs.has(ib):
		kind = "stair_side"
	if kind == "stair_side":
		# a flight's side grows along it: only a lip that is level across the body's width is a ledge of one height
		var sv := Vector2(d.y, d.x) * 0.4
		for sgn in [-1.0, 1.0]:
			if absf(w.ground_at(edge.x + dv.x + sv.x * sgn, edge.y + dv.y + sv.y * sgn) - ga - hb) > 0.1:
				return {}
	hb = snappedf(hb, 0.4 if kind == "stair_side" else 0.01)
	return {
		"kind": kind,
		"h": hb,
		"a": a,
		"d": d,
		"rise": w.level[ib] - w.level[w.idx(a.x, a.y)],
		"la": w.level[w.idx(a.x, a.y)],
		"top_y": ga + hb
	}


## One face, every hero and mode.
func drive(f: Dictionary) -> void:
	for arch in HEROES:
		c.h.set_arch(arch)
		c.h.unlock_all()
		for mode in MODES:
			var r: Dictionary = c._try(f, {"run": "jump_0", "jump": "stand", "glide": "glide_in"}[mode])
			if r.get("skip", false):
				continue
			var k := "%5.2f %-10s %-10s %s" % [f["h"], f["kind"], arch, mode]
			var s: Dictionary = rows.get_or_add(k, {"n": 0, "top": 0, "snap": 0, "snap_m": 0.0})
			s["n"] += 1
			s["top"] += 1 if r["top"] else 0
			s["snap"] += 1 if r.get("snap", 0.0) > SNAP_M else 0
			s["snap_m"] = maxf(s["snap_m"], r.get("snap", 0.0))
			if c.verbose and (r.get("snap", 0.0) > SNAP_M or r["top"] != (f["h"] <= reach(mode))):
				print("CLIFF htry %s at %s dir %s: %s" % [k, f["a"], f["d"], r])


## The census and the hit table; asserts through the cliff check's ok().
func report() -> void:
	var ks := census.keys()
	ks.sort()
	for k in ks:
		print("CLIFF census %-18s %5d faces" % [k, census[k]])
	var rk := rows.keys()
	rk.sort()
	print("CLIFF height rows: height kind hero mode  topped/tries  snaps (worst m)")
	for k in rk:
		var s: Dictionary = rows[k]
		var hgt := float(String(k).substr(0, 5))
		var mode := String(k).get_slice(" ", String(k).get_slice_count(" ") - 1)
		print("CLIFF height %s  %d/%d  snaps %d (%.2f)" % [k, s["top"], s["n"], s["snap"], s["snap_m"]])
		c.ok(s["snap"] == 0, "%s: no snap over the lip" % k)
		if hgt <= reach(mode):
			c.ok(s["top"] == s["n"], "%s: inside the reach (%.2f m), tops every try" % [k, reach(mode)])
		elif mode != "glide":
			c.ok(s["top"] == 0, "%s: past a jump's reach (%.2f m), never topped" % [k, reach(mode)])


## The highest ledge a mode tops: a jump's apex plus the mantle reach; a glide comes in at the lip.
static func reach(mode: String) -> float:
	if mode == "glide":
		return 99.0
	return Hunter.JUMP_V * Hunter.JUMP_V / (2.0 * Hunter.H_GRAV) + Hunter.MANTLE_REACH
