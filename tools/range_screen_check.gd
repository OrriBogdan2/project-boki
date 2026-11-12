extends RefCounted
## --range-screen-check: does every aimed slot's end stay on screen at its max range?
## For the 12 Hunters (Gil, the Novice Mage, is not one) and every slot that reaches somewhere (LMB the weapon's
## range; RMB, E, R, dash: the largest range-like number in the slot's data; plus Cinder's flight), the Hunter
## stands at the camera focus (the screen's centre, feet a little below it) and the slot's end, `reach` metres
## out along the aim up, down, left and right on the ground, is projected through the match camera at the
## default and the closest wheel zoom, at 1280x720, 1920x1080, 2560x1080 and 1024x768 (the lens is vertical, so
## 4:3 shows less width and 21:9 more). It prints one table row per slot (docs/MOVEMENT_FEEL.md, "Ability ranges
## on screen") with the ways whose end is off screen, and once more with the view leaning toward the end as the
## cursor held there makes it. Ranges are source data and stay as they are, so off-screen ends are reported, not
## failed. It fails when a Hunter has no rows (the data drifted), or when a range up to 18 m (half the source's
## 37 m across) has its end off screen left or right at 1920x1080, zoom 1.0.

const VIEWS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1024, 768)]
const EDGE_PX := 20.0      # CamRig.on_screen's margin: an end closer to the edge than this is off
const DIRS := {"up": Vector3(0, 0, -1), "down": Vector3(0, 0, 1), "left": Vector3(-1, 0, 0), "right": Vector3(1, 0, 0)}
const SLOTS := ["lmb", "rmb", "e", "x", "dash"]
## data keys that name a distance in metres (matched on the whole key or its last word, "wave_range", "air_dist")
const REACH_KEYS := ["range", "reach", "dist", "distance", "length", "len", "travel", "rmax", "tether_max"]
const SIDE_OK_M := 18.0     # m: the widest range the source's 37 m across is meant to hold left and right
const MIN_REACH := 5.0     # m: nearer ends are on screen in any view the camera has

var bad := 0
var rows: Array = []        # [hunter, slot, what, reach]

func ok(cond: bool, what: String) -> void:
	print("RANGESCREEN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	_collect()
	var vp := SubViewport.new()
	main.add_child(vp)
	var cam := CamRig.new()
	vp.add_child(cam)
	cam.use_style("supervive")
	var zooms: Array = [1.0, float(CamRig.RULES["zoom"]["match"]["min"])]
	print("RANGESCREEN table | Hunter | Slot | Reach m (data key) | ways off screen, Hunter centred, per view at")
	print("RANGESCREEN table | zoom 1.0 / %.1f (1280x720, 1920x1080, 2560x1080, 1024x768) | with the lean |" % zooms[1])
	for r in rows:
		var cells: Array = []
		for v in VIEWS:
			vp.size = v
			var per: Array = []
			for z in zooms:
				cam.zoom = z
				cam.snap(Vector3.ZERO)
				per.append(_ways_off(cam, float(r[3]), v))
			cells.append(" / ".join(per))
		vp.size = VIEWS[1]
		cam.zoom = 1.0
		cam.snap(Vector3.ZERO)
		var leaned := _ways_off(cam, float(r[3]), VIEWS[1], true)
		print("RANGESCREEN row | %s | %s | %.1f (%s) | %s | %s |" % [r[0], r[1], r[3], r[2], " ; ".join(cells), leaned])
		if float(r[3]) <= SIDE_OK_M:
			cam.snap(Vector3.ZERO)
			var off := _ways_off(cam, float(r[3]), VIEWS[1])
			ok(not (off.contains("left") or off.contains("right")),
					"%s %s %.1f m: left and right stay on screen at 1920x1080, zoom 1.0" % [r[0], r[1], r[3]])
	vp.queue_free()
	print("RANGESCREEN CHECK DONE, %d rows, failures: %d" % [rows.size(), bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## "up down" style list of the ways whose end is off screen ("-" none); `lean`: the view leans toward the end
## (CamRig.lean_to: what the cursor held at the end does) instead of keeping you at the centre.
func _ways_off(cam: CamRig, reach: float, v: Vector2i, lean := false) -> String:
	var out: Array = []
	for dn in DIRS:
		var end: Vector3 = DIRS[dn] * reach
		if lean:
			cam.snap(cam.lean_to(end))
		if not _on(cam, end, v):
			out.append(dn)
	return " ".join(out) if not out.is_empty() else "-"

## Every Hunter's reaching slots, read from its data.
func _collect() -> void:
	var ids := Arch.ids().filter(func(a): return a != "gil")
	ok(ids.size() == 12, "12 Hunters (%d)" % ids.size())
	for a in ids:
		var d := Arch.def(a)
		var title := String(d.get("base_name", a))
		var first := rows.size()
		var wr := float(Data.weapon_stats(String(d["signature"])).get("range", 0.0))
		_add(title, "lmb", "weapon " + String(d["signature"]), wr)
		for s in SLOTS:
			var found: Array = []
			_scan(d.get(s, {}), s, found)
			if not found.is_empty():
				found.sort_custom(func(p, q): return float(p[1]) > float(q[1]))
				_add(title, s, String(found[0][0]), float(found[0][1]))
		if a == "ashwick":
			var x: Dictionary = d["x"]
			_add(title, "x", "flight speed x time", float(x["speed"]) * float(x["time"]))
		ok(rows.size() > first, "%s has aimed slot rows" % title)

func _add(hunter: String, slot: String, what: String, reach: float) -> void:
	var same := func(r: Array) -> bool: return r[0] == hunter and r[1] == slot and is_equal_approx(float(r[3]), reach)
	if reach >= MIN_REACH and not rows.any(same):
		rows.append([hunter, slot, what, reach])

func _scan(o: Variant, path: String, out: Array) -> void:
	if o is Dictionary:
		for k in o:
			_scan_value(o[k], path + "." + String(k), String(k), out)
	elif o is Array:
		for i in o.size():
			_scan_value(o[i], path + "[%d]" % i, path.get_slice(".", path.get_slice_count(".") - 1), out)

func _scan_value(v: Variant, path: String, key: String, out: Array) -> void:
	if (v is float or v is int) and _is_reach(key):
		out.append([path, float(v)])
	else:
		_scan(v, path, out)

func _is_reach(key: String) -> bool:
	return REACH_KEYS.has(key) or REACH_KEYS.has(key.get_slice("_", key.get_slice_count("_") - 1))

func _on(cam: CamRig, at: Vector3, v: Vector2i) -> bool:
	if cam.is_position_behind(at):
		return false
	var s := cam.unproject_position(at)
	return s.x >= EDGE_PX and s.y >= EDGE_PX and s.x <= v.x - EDGE_PX and s.y <= v.y - EDGE_PX
