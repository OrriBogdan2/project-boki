extends RefCounted
## --abyss-check: islands are solid all the way down, and the abyss is short.
##   1. falling beside an island just below its lip, pushing in: you catch the ledge and climb up
##   2. knocked into an island's side from below with no keys held: you catch it too
##   3. deeper than the grab reach: you slide down the face (no snag) and the abyss takes you
##      within a short drop below the lip
##   4. dashing, gliding and being knocked toward an island from below never puts you inside or
##      under it
##   5. sheer cliffs still don't catch you as you fall past them
##   6. a bot knocked off beside a ledge climbs back the same way
##   7. monsters knocked at an island from below are blocked, and fall out promptly
## Prints "ACHECK ok|FAIL ..." lines and "ACHECK DONE, failures: N".

var bad := 0
## How far under the lowest lip around a hunter is lost (movefeel: the hunter's abyss is deeper than the
## monsters' World.ABYSS_DEPTH; it was 6m, the old checks' "< 7m")
const KILL_DEPTH := World.ABYSS_DEPTH + Hunter.ABYSS_EXTRA
var m: Match
var w: World
var h: Hunter
var marker := Vector3.ZERO      # where god mode puts a fallen player back: seeing it means "fell"

func ok(cond: bool, what: String) -> void:
	print("ACHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Grabbable rim tiles with open sky below and beside them: [{at, dir, top, ex, ez}] (dir points out).
func _edges(n: int, sheer := false) -> Array:
	var out: Array = []
	var seen := {}
	for k in 6000:
		if out.size() >= n: break
		var g := w.random_ground()
		var gi := w.idx(int(floor(g.x)), int(floor(g.z)))
		if seen.has(gi): continue
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var ti := w.idx(int(floor(g.x + d.x * 0.9)), int(floor(g.z + d.y * 0.9)))
			if not w.is_void(g.x + d.x * 1.6, g.z + d.y * 1.6) or w.is_void(g.x, g.z): continue
			var is_sheer := w.sheer.has(gi) or w.sheer.has(ti)
			if is_sheer != sheer: continue
			# (and a grabbable rim stays grabbable two tiles either way along it: a hand-made map's sheer
			# arcs end somewhere, and a float that drifts along the face onto a sheer stretch isn't a ledge test)
			var mixed := false
			for s2 in [-2.0, -1.0, 1.0, 2.0]:
				for q2 in [Vector2(g.x + d.y * s2, g.z + d.x * s2), Vector2(g.x + d.x * 0.9 + d.y * s2, g.z + d.y * 0.9 + d.x * s2)]:
					if w.sheer.has(w.idx(int(floor(q2.x)), int(floor(q2.y)))) != sheer and not w.is_void(q2.x, q2.y): mixed = true
			if mixed: continue
			var open := true
			for dd in [1.1, 1.6, 2.2, 2.8, 3.4, 4.0]:
				for s in [-0.6, 0.0, 0.6]:
					if not w.is_void(g.x + d.x * dd + d.y * s, g.z + d.y * dd + d.x * s): open = false
			# the rim tile's neighbours along the edge are the same height (a clean straight rim)
			var top := w.ground_at(g.x, g.z)
			for s in [-1.0, 1.0]:
				if absf(w.ground_at(g.x + d.y * s, g.z + d.x * s) - top) > 0.05: open = false
			if not open: continue
			var ex := g.x; var ez := g.z
			while not w.is_void(ex + d.x * 0.25, ez + d.y * 0.25):
				ex += d.x * 0.25; ez += d.y * 0.25
			seen[gi] = true
			out.append({"at": g, "dir": d, "top": top, "ex": ex, "ez": ez})
			break
	return out

func _reset(at: Vector3, v: Vector3) -> void:
	h.out = false; h.gone = false; h.downed = false; h.down_hp = 100.0
	h.teleport(at)
	h.grounded = false; h.vel = v; h.pad = {}; h.lfloat = {}; h.grap = {}; h.grap_cd = 0.0; h.roll_t = 0.0
	h.gliding = false; h.glide_fuel = 1.0; h.glide_cd = 0.0; h.knock_t = 0.0; h.fly_t = 0.0
	h.stun_t = 0.0; h.kb_t = -9.0; h.mantle_cd = 0.0; h.shot_down = false; h.air_t = 0.0
	h.inp["move"] = Vector2.ZERO; h.inp["glide"] = false; h.inp["jump"] = false; h.inp["dash"] = false
	h.hp = h.max_hp

## The lip the abyss is measured from beside a rim at p: the lowest island ground around it.
func _ref(p: Vector3) -> float:
	if not w.has_method("abyss_ref"): return p.y
	var a: float = w.abyss_ref(p.x, p.z)
	return minf(p.y, a) if a > World.VOID + 1.0 else p.y

## Inside an island's column: over ground, but well below its top.
func _inside(e: Ent) -> float:
	if w.is_void(e.pos.x, e.pos.z): return 0.0
	var g := w.ground_at(e.pos.x, e.pos.z)
	return maxf(0.0, g - e.pos.y - 0.3)

## Runs the player for up to `sec`, with `drive` called every frame. Returns what happened.
func _run(sec: float, drive: Callable) -> Dictionary:
	var r := {"mantled": false, "landed": false, "fell": false, "low": h.pos.y, "inside": 0.0, "stuck": 0, "t": 0.0, "clip": 0.0}
	var t := 0.0; var still := 0; var last_y := h.pos.y
	while t < sec:
		drive.call(t)
		var before := h.pos
		m.step(Match.DT); t += Match.DT
		if h.pos.distance_to(marker) < 0.01 and before.distance_to(marker) > 0.5:
			r["fell"] = true; r["t"] = t
			break
		if h.pos.y < float(r["low"]):
			r["low"] = h.pos.y
			r["low_at"] = h.pos
		r["inside"] = maxf(float(r["inside"]), _inside(h))
		if h.mantling():
			r["mantled"] = true
			r["clip"] = maxf(float(r["clip"]), _inside(h))
		elif not h.grounded and h.pad.is_empty() and not h.mantling():
			# hanging in the air without moving: snagged on the face
			still = still + 1 if absf(h.pos.y - last_y) < 0.002 and not h.gliding else 0
			r["stuck"] = maxi(int(r["stuck"]), still)
		last_y = h.pos.y
		if r["mantled"] and not h.mantling() and h.pad.is_empty() and h.grounded:
			r["landed"] = true; r["t"] = t
			break
		if not h.grounded: r["air"] = true
		if h.grounded and not r["mantled"] and r.has("air"):
			r["t"] = t
			break
	return r

func run(main: Node) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	w = m.world
	h = m.hunters[0]
	h.set_arch("")      # edge physics with the plain class dash (archetype dashes: --archetype-check)
	for o in m.hunters:
		o.ctrl = "idle"
		if o != h: o.teleport(w.random_ground())
	h.ctrl = "local"
	for kk in [h.kin, h.kin2]:
		if kk: m.kins.erase(kk); kk.queue_free()
	h.kin = null; h.kin2 = null
	m.opts["god"] = true             # a fall puts you back at the marker instead of ending the run
	marker = w.random_ground()
	h.ai["land"] = marker
	var edges := _edges(10)
	var lv0 := edges.filter(func(e): return float(e["top"]) < 0.05).size()
	print("ACHECK %d test rims (%d at ground level), lowest top %.1f" % [edges.size(), lv0, w.lowest_top() if w.has_method("lowest_top") else 0.0])
	# ---------------------------------------------------------------- 1. just below the lip
	for depth in [0.8, 1.8, 2.7]:
		var n := 0; var good := 0; var clip := 0.0; var times: Array = []
		for e in edges:
			var dir: Vector2 = e["dir"]; var top: float = e["top"]
			_reset(Vector3(e["ex"] + dir.x * (h.r + 0.6), top - depth, e["ez"] + dir.y * (h.r + 0.6)), Vector3(0, -3.0, 0))
			h.last_gy = top
			var r := _run(3.0, func(_t): h.inp["move"] = -dir)
			n += 1
			if r["mantled"] and r["landed"] and absf(h.pos.y - top) < 0.6: good += 1
			clip = maxf(clip, r["clip"]); times.append(snappedf(r["t"], 0.01))
		ok(good == n and clip < 0.06, "falling %.1fm below the lip, pushing in: climbed %d of %d, clip %.2fm, times %s" % [depth, good, n, clip, str(times)])
	# ---------------------------------------------------------------- 2. knocked into the side
	var kn := 0; var kgood := 0
	for e in edges:
		var dir: Vector2 = e["dir"]; var top: float = e["top"]
		_reset(Vector3(e["ex"] + dir.x * 2.2, top - 1.2, e["ez"] + dir.y * 2.2), Vector3(-dir.x * 9.0, -1.0, -dir.y * 9.0))
		h.last_gy = top
		h.kb_t = m.time; h.knock_t = 0.25
		var r := _run(2.0, func(_t): h.inp["move"] = Vector2.ZERO)
		kn += 1
		if r["mantled"] and r["landed"]: kgood += 1
	ok(kgood == kn, "knocked into an island's side from below, no keys: climbed %d of %d" % [kgood, kn])
	# ---------------------------------------------------------------- 3. too deep: slide, then the abyss
	var dn := 0; var dgood := 0; var worst_drop := 0.0; var worst_t := 0.0; var stuck := 0; var grabbed := 0
	for e in edges:
		var dir: Vector2 = e["dir"]; var top: float = e["top"]
		_reset(Vector3(e["ex"] + dir.x * (h.r + 0.6), top - (Hunter.MANTLE_REACH_ABYSS + 0.1), e["ez"] + dir.y * (h.r + 0.6)), Vector3(0, -4.0, 0))
		h.last_gy = top
		var r := _run(6.0, func(_t): h.inp["move"] = -dir)
		dn += 1
		if r["mantled"]: grabbed += 1
		if r["fell"]: dgood += 1
		worst_drop = maxf(worst_drop, _ref(Vector3(e["ex"], top, e["ez"])) - float(r["low"]))
		worst_t = maxf(worst_t, float(r["t"]))
		stuck = maxi(stuck, int(r["stuck"]))
	ok(grabbed == 0, "%.1fm below the lip: no ledge grab (%d grabbed)" % [Hunter.MANTLE_REACH_ABYSS + 0.1, grabbed])
	ok(dgood == dn and worst_drop < KILL_DEPTH + 1.0 and worst_t < 2.4, "below the grab reach the abyss takes you: %d of %d, deepest %.1fm below the lowest lip around, within %.2fs" % [dgood, dn, worst_drop, worst_t])
	ok(stuck < 6, "sliding down the face never snags (longest hang %d frames)" % stuck)
	# a plain walk off the edge: how far below the lip before the abyss
	var e0: Dictionary = edges[0]
	var d0: Vector2 = e0["dir"]
	_reset(Vector3(e0["ex"] - d0.x * 1.5, e0["top"], e0["ez"] - d0.y * 1.5), Vector3.ZERO)
	h.grounded = true; h.last_gy = e0["top"]
	h.dashes = 2.0
	var r0 := _run(8.0, func(t):
		h.inp["move"] = d0 if t < 0.3 else Vector2.ZERO
		h.inp["dash"] = t < Match.DT * 1.5)
	# the dash's speed carries on in the air (Loco.air_step), so measure under the lips where you fell, not the edge
	var at0: Vector3 = r0.get("low_at", Vector3(e0["ex"], 0, e0["ez"]))
	var ref0 := _ref(Vector3(at0.x, e0["top"], at0.z))
	ok(r0["fell"] and ref0 - float(r0["low"]) < KILL_DEPTH + 1.0, "dashing off an edge: lost %.1fm below the lip (%.1fm below the lowest lip around) after %.2fs" % [float(e0["top"]) - float(r0["low"]), ref0 - float(r0["low"]), r0["t"]])
	# walking (no dash, no jump) toward the edge takes a player over it: the edge doesn't hold you
	var wgood := 0; var wn := 0; var bheld := 0
	for e in edges.slice(0, 6):
		var dw: Vector2 = e["dir"]
		for who in ["local", "bot"]:
			_reset(Vector3(e["ex"] - dw.x * 1.2, e["top"], e["ez"] - dw.y * 1.2), Vector3.ZERO)
			h.grounded = true; h.last_gy = e["top"]
			h.ctrl = who
			var lowest: float = e["top"]; var went := false
			for i in int(1.6 / Match.DT):
				h.inp["move"] = dw
				h.inp["glide"] = false
				m.step(Match.DT)
				lowest = minf(lowest, h.pos.y)
				if w.is_void(h.pos.x, h.pos.z) and not h.grounded and h.pos.y < float(e["top"]) - 1.0:
					went = true; break
			h.inp["move"] = Vector2.ZERO
			if who == "local":
				wn += 1
				if went: wgood += 1
				else: print("ACHECK   walk-off miss at %s: lowest %.2f top %.2f at %s" % [str(e["at"]), lowest, e["top"], str(h.pos)])
			elif not went and not w.is_void(h.pos.x, h.pos.z): bheld += 1
	h.ctrl = "local"
	ok(wgood == wn, "walking toward an edge goes over it and falls: %d of %d" % [wgood, wn])
	ok(bheld == wn, "bots walking at an edge keep their edge guard: %d of %d held" % [bheld, wn])
	# ---------------------------------------------------------------- 4. dash, glide, knockback from below
	var ins := 0.0; var cases := 0
	for e in edges:
		var dir: Vector2 = e["dir"]; var top: float = e["top"]
		for depth in [1.5, 3.4, 4.8]:
			for how in ["dash", "glide", "knock", "drift"]:
				cases += 1
				_reset(Vector3(e["ex"] + dir.x * 2.5, top - depth, e["ez"] + dir.y * 2.5), Vector3(0, -1.0, 0))
				h.last_gy = top
				var r := _run(2.0, func(t):
					h.inp["move"] = -dir
					h.inp["glide"] = how == "glide"
					if how == "glide" and t < Match.DT * 1.5:
						h.gliding = true
					if how == "dash" and t < Match.DT * 1.5:
						h.inp["dash"] = true
						h.dashes = 2.0
					if how == "knock" and t < Match.DT * 1.5:
						h.impulse(-dir * 22.0)
					if how == "drift":
						h.inp["move"] = -dir if t < 0.05 else Vector2.ZERO
						h.vel.x = -dir.x * 6.0; h.vel.z = -dir.y * 6.0)
				ins = maxf(ins, r["inside"])
	ok(ins < 0.05, "dash / glide / knockback / drift into an island from below (%d cases): deepest inside a column %.2fm" % [cases, ins])
	# a glider low under the lip with heat to spare still gets back up
	var gl_ok := 0; var gl_n := 0
	for e in edges.slice(0, 5):
		var dir: Vector2 = e["dir"]; var top: float = e["top"]
		_reset(Vector3(e["ex"] + dir.x * 3.0, top - 3.4, e["ez"] + dir.y * 3.0), Vector3(0, -6.0, 0))
		h.last_gy = top; h.air_t = 1.0
		var r := _run(4.0, func(_t):
			h.inp["glide"] = true
			h.inp["move"] = -dir)
		gl_n += 1
		if not r["fell"] and h.grounded and absf(h.pos.y - top) < 0.6: gl_ok += 1
	ok(gl_ok == gl_n, "gliding up out of the abyss from 3.4m below the lip: back on top %d of %d" % [gl_ok, gl_n])
	# the glider's lift grows with how deep you are: gentle just under the lip, a surge deep down
	_lift_by_depth(edges[0])
	# ---------------------------------------------------------------- 5. sheer cliffs
	var sh := _edges(8, true)
	if not sh.is_empty():
		var caught := 0
		for e in sh:
			var dir: Vector2 = e["dir"]; var top: float = e["top"]
			_reset(Vector3(e["ex"] + dir.x * (h.r + 0.6), top - 1.0, e["ez"] + dir.y * (h.r + 0.6)), Vector3(0, -2.0, 0))
			h.last_gy = top
			var r := _run(2.0, func(_t): h.inp["move"] = -dir)
			# caught: fine only if it pulled you onto a neighbouring rim with a lip, not the sheer one
			if r["mantled"]:
				var lx := int(floor(h.pos.x)); var lz := int(floor(h.pos.z))
				var at: Vector3 = e["at"]
				print("ACHECK   sheer rim %s caught onto %s (sheer=%s)" % [str(at), str(h.pos), w.sheer.has(w.idx(lx, lz))])
				if w.sheer.has(w.idx(lx, lz)) or Vector2(lx + 0.5 - at.x, lz + 0.5 - at.z).length() < 1.2: caught += 1
		ok(caught == 0, "sheer cliffs: caught %d of %d falling past (should be 0)" % [caught, sh.size()])
	# ---------------------------------------------------------------- 6. a bot knocked off a ledge
	m.opts["god"] = false
	var b: Hunter = m.hunters[1]
	b.ctrl = "bot"
	b.ai["skill"] = 0.0       # no glider: it has to catch the ledge
	var bn := 0; var bgood := 0
	for e in edges.slice(0, 6):
		var dir: Vector2 = e["dir"]; var top: float = e["top"]
		b.out = false; b.gone = false; b.downed = false; b.hp = b.max_hp
		b.teleport(Vector3(e["ex"] + dir.x * 0.9, top - 0.4, e["ez"] + dir.y * 0.9))
		b.grounded = false; b.vel = Vector3(dir.x * 3.0, -2.0, dir.y * 3.0); b.pad = {}; b.lfloat = {}; b.grap_cd = 0.0
		b.last_gy = top; b.kb_t = m.time - 0.35; b.gliding = false
		var t := 0.0; var deep := 0.0
		while t < 3.0 and not b.out:
			m.step(Match.DT); t += Match.DT
			deep = maxf(deep, _inside(b))
			if b.grounded and b.pad.is_empty() and not b.mantling() and absf(b.pos.y - top) < 0.7 and t > 0.1: break
		bn += 1
		if not b.out and b.grounded and deep < 0.05: bgood += 1
	ok(bgood == bn, "bots knocked off beside a ledge climb back: %d of %d" % [bgood, bn])
	b.ctrl = "idle"
	# ---------------------------------------------------------------- 7. monsters
	var mb_in := 0.0; var mb_fell := 0; var mb_n := 0; var mb_low := 0.0
	for e in edges.slice(0, 6):
		var dir: Vector2 = e["dir"]; var top: float = e["top"]
		var mb := m.spawn_mob("skitter", e["at"])
		mb.teleport(Vector3(e["ex"] + dir.x * 2.0, top - 2.0, e["ez"] + dir.y * 2.0))
		mb.grounded = false; mb.vel = Vector3.ZERO
		mb.impulse(-dir * 18.0, 0.0)
		var t := 0.0
		while t < 4.0 and not mb.dead:
			m.step(Match.DT); t += Match.DT
			mb_in = maxf(mb_in, _inside(mb))
			mb_low = maxf(mb_low, _ref(Vector3(e["ex"], top, e["ez"])) - mb.pos.y)
		mb_n += 1
		if mb.dead: mb_fell += 1
	ok(mb_in < 0.05, "monsters knocked at an island from below stay out of it (deepest %.2fm)" % mb_in)
	ok(mb_fell == mb_n and mb_low < 7.0, "monsters off the edge fall out promptly: %d of %d, deepest %.1fm below the lowest lip around" % [mb_fell, mb_n, mb_low])
	m.queue_free()
	await _home(main)
	print("ACHECK DONE, failures: ", bad)
	main.get_tree().quit()

## Depths below the lip the lift is measured at (the point of no return is ~13m: Hunter.abyss_kill_y).
const LIFT_DEPTHS := [1.0, 2.0, 4.0, 7.0, 10.0, 12.0]

## Opens the glider (full heat) 4m out over the void, `depth` under the lip, falling at 4 m/s, keys
## off. Per depth: the fastest climb in the first 0.5s and the time back up to the balloon line
## (0.5m under the lip), or -1 if it never gets there in 4s.
func _lift_by_depth(e: Dictionary) -> void:
	var dir: Vector2 = e["dir"]; var top: float = e["top"]
	var rows: Array = []
	for dp in LIFT_DEPTHS:
		_reset(Vector3(e["ex"] + dir.x * 4.0, top - dp, e["ez"] + dir.y * 4.0), Vector3(0, -4.0, 0))
		h.last_gy = top; h.air_t = 1.0; h.gliding = true
		var peak := -99.0; var t_up := -1.0; var t := 0.0
		while t < 4.0:
			h.inp["glide"] = true
			m.step(Match.DT); t += Match.DT
			if h.pos.distance_to(marker) < 0.01: break
			if t <= 0.5: peak = maxf(peak, h.vel.y)
			if t_up < 0.0 and h.pos.y >= top - 0.5: t_up = t; break
		rows.append([dp, peak, t_up])
	h.inp["glide"] = false
	_lift_report("expedition", rows)

func _lift_report(where: String, rows: Array) -> void:
	var txt := ""
	var grows := true
	var all_up := true
	for i in rows.size():
		txt += "%s%.0fm: climb %.1f m/s, up in %s" % ["" if i == 0 else "; ", rows[i][0], rows[i][1], ("%.2fs" % rows[i][2]) if rows[i][2] > 0.0 else "never"]
		if rows[i][2] <= 0.0: all_up = false
		if i > 0 and float(rows[i][1]) < float(rows[i - 1][1]) + 0.5: grows = false
	print("ACHECK lift (%s): %s" % [where, txt])
	ok(all_up, "%s: the glider lifts you back to the lip from every depth down to %.0fm" % [where, float(rows[-1][0])])
	ok(grows, "%s: the deeper you are, the harder it pulls you up (fastest climb rises with depth)" % where)
	ok(float(rows[0][1]) <= 6.5, "%s: just under the lip the lift is gentle (%.1f m/s at %.0fm)" % [where, float(rows[0][1]), float(rows[0][0])])

## The same at home (the farm's rims use the same movement).
func _home_lift(hm, e: Dictionary) -> void:
	var dir: Vector2 = e["dir"]; var top: float = e["top"]
	var DT := 1.0 / 60.0
	var rows: Array = []
	for dp in LIFT_DEPTHS:
		hm.climb = {}; if "lfl" in hm: hm.lfl = {}
		hm.ppos = Vector3(e["ex"] + dir.x * 4.0, 0, e["ez"] + dir.y * 4.0)
		hm.py = top - dp; hm.pvy = -4.0; hm.pvel = Vector3.ZERO; hm.dash_t = 0.0
		hm.safe_at = Vector3(e["at"].x, 0, e["at"].z) - Vector3(dir.x, 0, dir.y) * 3.0
		hm.gliding = true
		_press(Vector2.ZERO)
		Input.action_press("glide")
		var peak := -99.0; var t_up := -1.0; var t := 0.0
		while t < 4.0:
			var before: Vector3 = hm.ppos
			hm._move_player(DT); t += DT
			if hm.ppos.distance_to(hm.safe_at) < 0.01 and before.distance_to(hm.safe_at) > 0.5: break     # lost: set back
			if t <= 0.5: peak = maxf(peak, hm.pvy)
			if t_up < 0.0 and hm.py >= top - 0.5: t_up = t; break
		Input.action_release("glide")
		rows.append([dp, peak, t_up])
	_lift_report("home", rows)

# ---------------------------------------------------------------- 8. at home
func _press(dir: Vector2) -> void:
	for a in ["left", "right", "up", "down"]: Input.action_release(a)
	if dir.x > 0.1: Input.action_press("right", dir.x)
	if dir.x < -0.1: Input.action_press("left", -dir.x)
	if dir.y > 0.1: Input.action_press("down", dir.y)
	if dir.y < -0.1: Input.action_press("up", -dir.y)

func _home(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var pk := Save.new_kin("zapple", "Pip"); Save.d["roster"].append(pk); Save.d["active"] = pk["uid"]
	Save.d["tutorial"]["home"] = true; Save.d["tutorial"]["day1_done"] = true
	Econ.ensure()
	var hm = load("res://scripts/home/home.gd").new()
	main.add_child(hm)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	hm.set_process(false)
	var keep_w := w
	w = hm.world
	var edges := _edges(6)
	w = keep_w
	print("ACHECK %d home rims" % edges.size())
	var DT := 1.0 / 60.0
	var climbed := 0; var lost := 0; var lost_low := 0.0; var inside := 0.0; var n := 0; var grabbed_deep := 0
	for e in edges:
		var dir: Vector2 = e["dir"]; var top: float = e["top"]
		for depth in [1.0, 2.2, 4.5]:
			for dash in [false, true]:
				n += 1
				hm.climb = {}
				hm.ppos = Vector3(e["ex"] + dir.x * 0.8, 0, e["ez"] + dir.y * 0.8)
				hm.py = top - depth; hm.pvy = -2.0; hm.pvel = Vector3.ZERO; hm.gliding = false; hm.dash_t = 0.0
				hm.safe_at = Vector3(e["at"].x, 0, e["at"].z) - Vector3(dir.x, 0, dir.y) * 3.0
				if dash: hm.start_dash(-dir, Hunter.DASH_SPEED, Hunter.DASH_TIME)
				var low: float = hm.py; var did_climb := false; var back := false
				for i in 240:
					_press(-dir)
					var before: Vector3 = hm.ppos
					hm._move_player(DT)
					if not hm.climb.is_empty() or not hm.lfl.is_empty(): did_climb = true
					if hm.ppos.distance_to(hm.safe_at) < 0.01 and before.distance_to(hm.safe_at) > 0.5:
						back = true; break
					low = minf(low, hm.py)
					if not hm.world.is_void(hm.ppos.x, hm.ppos.z) and hm.world.ground_at(hm.ppos.x, hm.ppos.z) > hm.py + 0.3 and hm.climb.is_empty() and hm.lfl.is_empty():
						inside = maxf(inside, hm.world.ground_at(hm.ppos.x, hm.ppos.z) - hm.py)
					if did_climb and hm.climb.is_empty() and hm.lfl.is_empty() and hm.pvy == 0.0 and absf(hm.py - top) < 0.05: break
				_press(Vector2.ZERO)
				if depth < 3.6:
					if did_climb and absf(hm.py - top) < 0.05 and not hm.world.is_void(hm.ppos.x, hm.ppos.z): climbed += 1
					else:
						var ins: Array = []
						for kk in [0.5, 1.0, 1.5, 2.0]: ins.append("%s/%.1f" % [hm.world.is_block(e["ex"] - dir.x * kk, e["ez"] - dir.y * kk), hm.world.ground_at(e["ex"] - dir.x * kk, e["ez"] - dir.y * kk)])
						print("ACHECK   home miss: depth %.1f dash %s climb %s low %.2f top %.2f at %s dir %s inward %s" % [depth, dash, did_climb, low, top, str(e["at"]), str(dir), str(ins)])
				else:
					if did_climb: grabbed_deep += 1
					if back: lost += 1
					lost_low = maxf(lost_low, top - low)
	var near_n := n * 2 / 3
	ok(climbed == near_n, "home: caught the island's side from below and pulled up %d of %d" % [climbed, near_n])
	ok(grabbed_deep == 0 and lost == n - near_n and lost_low < World.ABYSS_DEPTH + Hunter.ABYSS_EXTRA + 2.0, "home: deeper, you slide off and the wind sets you back at the same point of no return as out there: %d of %d, deepest %.1fm" % [lost, n - near_n, lost_low])
	ok(inside < 0.05, "home: never inside or under the island (deepest %.2fm)" % inside)
	# walking toward the farm island's edge takes you over it
	var hw := 0
	for e in edges.slice(0, 4):
		var dw: Vector2 = e["dir"]
		hm.lfl = {}; hm.climb = {}; hm.gliding = false; hm.dash_t = 0.0; hm.pvy = 0.0; hm.pvel = Vector3.ZERO
		hm.ppos = Vector3(e["ex"] - dw.x * 1.2, 0, e["ez"] - dw.y * 1.2); hm.py = e["top"]
		hm.safe_at = Vector3(e["at"].x, 0, e["at"].z) - Vector3(dw.x, 0, dw.y) * 3.0
		for i in 120:
			_press(dw)
			hm._move_player(DT)
			if hm.world.is_void(hm.ppos.x, hm.ppos.z) and hm.py < float(e["top"]) - 1.0:
				hw += 1; break
		_press(Vector2.ZERO)
	ok(hw == mini(4, edges.size()), "home: walking toward the edge goes over it and falls: %d of %d" % [hw, mini(4, edges.size())])
	_home_lift(hm, edges[0])
	hm.queue_free()
