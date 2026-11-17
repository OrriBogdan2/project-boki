class_name PolishTools
extends RefCounted
## Screenshot and test tooling for the polish pass (--chest-demo, --at-stairs), moved out of
## match.gd, which cannot grow. `m` is the running Match.

## Every flight of stairs as {"dir", "tiles"} (tiles in order across the flight), widest first.
static func stair_flights(world) -> Array:
	var seen := {}
	var out: Array = []
	for si in world.stairs:
		if seen.has(si):
			continue
		var d: Vector2i = world.stairs[si]
		var side := Vector2i(d.y, d.x)
		var c := Vector2i(si % world.w, si / world.w)
		while world.inb(c.x - side.x, c.y - side.y) and world.stairs.get(world.idx(c.x - side.x, c.y - side.y), Vector2i.ZERO) == d:
			c -= side
		var tiles: Array = []
		while world.inb(c.x, c.y) and world.stairs.get(world.idx(c.x, c.y), Vector2i.ZERO) == d:
			seen[world.idx(c.x, c.y)] = true
			tiles.append(c)
			c += side
		out.append({"dir": d, "tiles": tiles})
	out.sort_custom(func(a, b): return a["tiles"].size() > b["tiles"].size())
	return out

## --at-stairs[=N|E|W|S|N]: where to start so a flight of stairs is in view (else `at` unchanged).
static func stairs_start(m, at: Vector3) -> Vector3:
	var at_st := Array(OS.get_cmdline_user_args()).filter(func(a): return String(a) == "--at-stairs" or String(a).begins_with("--at-stairs="))
	if not at_st.is_empty() and not m.world.stairs.is_empty():
		# test: start at the foot of a flight of stairs, in line with its middle step
		# (--at-stairs=N: the Nth flight, widest first; prints every flight's width)
		var fl := stair_flights(m.world)
		var pick_s := String(at_st[0]).substr(12) if String(at_st[0]).length() > 12 else "0"
		var pick_n := int(pick_s)
		if pick_s in ["E", "W", "S", "N"]:
			# --at-stairs=E: the widest flight climbing that way (E = +x, S = +z, toward the camera)
			for fi in fl.size():
				if {Vector2i(1, 0): "E", Vector2i(-1, 0): "W", Vector2i(0, 1): "S", Vector2i(0, -1): "N"}.get(fl[fi]["dir"], "") == pick_s:
					pick_n = fi; break
		var F: Dictionary = fl[clampi(pick_n, 0, fl.size() - 1)]
		print("STAIRS flights=%d widths=%s picked=%d (width %d)" % [fl.size(), str(fl.map(func(f): return "%d%s" % [f["tiles"].size(), {Vector2i(1, 0): "E", Vector2i(-1, 0): "W", Vector2i(0, 1): "S", Vector2i(0, -1): "N"}.get(f["dir"], "?")])), clampi(pick_n, 0, fl.size() - 1), F["tiles"].size()])
		var mid: Vector2i = F["tiles"][F["tiles"].size() / 2]
		var sd: Vector2i = F["dir"]
		at = Vector3(mid.x + 0.5 - sd.x * 2.5, 0, mid.y + 0.5 - sd.y * 2.5)
		at.y = m.world.ground_at(at.x, at.z)
		m.set_meta("stairs_demo", Vector3(mid.x + 0.5, at.y, mid.y + 0.5))
	return at

## --chest-demo: a row of crate, chest, pot, second chest and powder keg 1.7 m apart on a flat open
## patch near the start, you just below it, so the two kinds of prop can be told apart in one frame.
static func chest_row(m) -> void:
	# test (--chest-demo): on a flat open patch near where you start, a row of crate, chest, pot,
	# second chest and powder keg 1.7 m apart, you just below it, so the two kinds of prop can be
	# told apart in one frame
	var base: Vector3 = m.player.pos
	var busy: Array = []      # exits, portals, pads, chests and breakables already there
	for ed in m.world.exit_defs: if ed.has("pos"): busy.append(ed["pos"])
	for ps in m.world.portal_spots: busy.append(ps)
	for pd in m.world.pads: busy.append(pd["pos"])
	for c0 in m.chests: busy.append(c0["pos"])
	for b0 in m.breaks: busy.append(b0["pos"])
	var flat := func(c: Vector3) -> bool:
		for bp in busy:
			if Vector2((bp as Vector3).x - c.x, (bp as Vector3).z - c.z).length() < 6.5:
				return false
		for dz in [-1.0, 0.0, 1.0, 2.0, 3.0]:
			for dx in [-4.0, -2.0, 0.0, 2.0, 4.0]:
				var q: Vector3 = c + Vector3(dx, 0, dz)
				if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z) or absf(m.world.ground_at(q.x, q.z) - c.y) > 0.05 or m.world.stairs.has(m.world.idx(int(floor(q.x)), int(floor(q.z)))):
					return false
		return true
	var found := false
	for r in range(0, 60):
		for k in maxi(1, r * 6):
			var ang := TAU * float(k) / float(maxi(1, r * 6))
			var c: Vector3 = base + Vector3(cos(ang), 0, sin(ang)) * float(r)
			c = Vector3(floor(c.x) + 0.5, 0, floor(c.z) + 0.5)
			if m.world.is_void(c.x, c.z): continue
			c.y = m.world.ground_at(c.x, c.z)
			if flat.call(c):
				base = c; found = true; break
		if found: break
	var row := ["crate", "chest", "pot", "chest", "keg"]
	for k in row.size():
		var q: Vector3 = base + Vector3((k - 2) * 1.7, 0, 0)
		match String(row[k]):
			"chest": m.add_chest(q)
			_: m._add_break(String(row[k]), q)
	m.player.teleport(base + Vector3(0, 0, 2.6))

## Screenshots: no monsters standing over what is being shown.
static func clear_mobs(m) -> void:
	# screenshots: no monsters standing over what's being shown
	for mb in m.mobs.duplicate():
		if (mb as Mob).pos.distance_to(m.player.pos) < 9.0:
			m.mobs.erase(mb); mb.queue_free()
