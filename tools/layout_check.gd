extends RefCounted
## --layout-check: owner item 151 (the training area's layout: no stray small rocks to get stuck on).
##  1. Rock hops: next to every rock, tree or wall tile of the training map, a Hunter jumps into it with the keys
##     held. Wherever that leaves them, they can always walk away (some key moves them >= FREE_M in FREE_S).
##  1b. Landing on a blocker from above (a glide or a knock onto a clump of rocks or trees): out, never stuck.
##  1c. The same on a 3x3 clump of rocks carved into open ground (where the pushes alone moved you from tile to
##      tile inside it): landing on any of its tiles puts you out.
##  2. A probe grid over the training area: from every walkable spot, some key moves the Hunter away.
##  3. No colliding thing is taller than a walkable step but shorter than a mantle (no 1-block snag).

const SEED := 4242               # the training area (scripts/main.gd: the training match)
const FREE_S := 1.0              # s each key is held while trying to walk away
const FREE_M := 0.5              # m that counts as having walked away
const HOP_S := 1.2               # s of jumping into a rock with the keys held
const MAX_HOPS := 60
const MAX_LANDINGS := 80         # blocker tiles landed on (an even sample over the map)
const GRID := 4                  # tiles between probe spots
const DIRS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7)]

var bad := 0
var notes := 0

func ok(cond: bool, what: String) -> void:
	print("LAYOUT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _match(main: Node) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": SEED, "no_drop": true})
	m.set_process(false)
	return m

func _clear(m: Match) -> void:
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	for other in m.hunters:
		if other != m.player:
			other.ctrl = "idle"
			other.teleport(Vector3(-500, 0, -500))

func _idle(h: Hunter) -> void:
	for k in ["jump", "dash", "fire", "sec", "sec_hold", "sig", "ult", "glide", "glide_btn"]:
		h.inp[k] = false
	h.inp["move"] = Vector2.ZERO

## True if some key walks the Hunter FREE_M away from where they stand.
func _can_leave(m: Match, h: Hunter) -> bool:
	var start := h.pos
	for d: Vector2 in DIRS:
		h.teleport(start)
		h.vel = Vector3.ZERO
		_idle(h)
		m.step(Match.DT)
		h.inp["move"] = d
		for i in int(FREE_S / Match.DT):
			m.step(Match.DT)
		if Vector2(h.pos.x - start.x, h.pos.z - start.z).length() >= FREE_M:
			_idle(h)
			return true
	_idle(h)
	return false

func _walkable(w: World, x: int, z: int) -> bool:
	return w.inb(x, z) and w.kind[w.idx(x, z)] == World.T_GROUND and w.ground_at(x + 0.5, z + 0.5) > World.VOID + 1.0

## 1. Jump into each blocker from the ground beside it.
func _hops(m: Match) -> void:
	var h: Hunter = m.player
	var w: World = m.world
	var tried := 0
	var stuck := 0
	var on_top := 0
	for z in w.h:
		for x in w.w:
			if tried >= MAX_HOPS:
				break
			if w.kind[w.idx(x, z)] != World.T_BLOCK:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var sx := x + d.x * 1
				var sz := z + d.y * 1
				if not _walkable(w, sx, sz) or not _walkable(w, sx + d.x, sz + d.y):
					continue
				if absf(w.ground_at(sx + 0.5, sz + 0.5) - float(w.level[w.idx(x, z)]) * World.LEVEL) > 0.05:
					continue
				tried += 1
				_clear(m)
				var from := Vector3(sx + 0.5 + d.x * 0.2, w.ground_at(sx + 0.5, sz + 0.5), sz + 0.5 + d.y * 0.2)
				h.teleport(from)
				h.vel = Vector3.ZERO
				_idle(h)
				for i in 10:
					m.step(Match.DT)
				var into := Vector2(-d.x, -d.y)
				var top := 0.0
				for i in int(HOP_S / Match.DT):
					h.inp["move"] = into
					h.inp["jump"] = i % 20 == 0
					m.step(Match.DT)
					top = maxf(top, h.pos.y - from.y)
				_idle(h)
				for i in 40:
					m.step(Match.DT)
				if top > World.BLOCK_H - 0.5:
					on_top += 1
				var left := _can_leave(m, h)
				if not left:
					stuck += 1
					print("LAYOUT stuck after a hop into the rock at %d,%d (from %s, now %s, rose %.2f m)" % [
						x, z, from, h.pos, top])
				break
	ok(tried > 5, "the training area has walls to hop into (%d tried)" % tried)
	print("LAYOUT note %d of %d hops went over the rock's top" % [on_top, tried])
	ok(on_top == 0, "a jump into a rock or wall never lifts you over it (%d of %d)" % [on_top, tried])
	ok(stuck == 0, "a hop into a rock never leaves you stuck (%d of %d)" % [stuck, tried])

## 1b. Every blocker tile, dropped onto from above.
func _landings(m: Match) -> void:
	var h: Hunter = m.player
	var w: World = m.world
	var tiles: Array = []
	for i in w.kind.size():
		if w.kind[i] == World.T_BLOCK:
			tiles.append(i)
	var every := maxi(1, ceili(tiles.size() / float(MAX_LANDINGS)))
	var tried := 0
	var stuck := 0
	for n in range(0, tiles.size(), every):
		var i: int = tiles[n]
		var x: int = i % w.w
		var z: int = i / w.w
		tried += 1
		_clear(m)
		var top := float(w.level[i]) * World.LEVEL + World.BLOCK_H
		h.teleport(Vector3(x + 0.5, top + 0.4, z + 0.5))
		h.vel = Vector3.ZERO
		h.grounded = false
		_idle(h)
		for k in 50:
			m.step(Match.DT)
		if not _can_leave(m, h):
			stuck += 1
			print("LAYOUT stuck after landing on the blocker at %d,%d (now %s)" % [x, z, h.pos])
	ok(tried > 5, "the training area has blockers to land on (%d)" % tried)
	ok(stuck == 0, "landing on a rock, tree or wall never leaves you stuck (%d of %d)" % [stuck, tried])

## 1c. A 3x3 clump on open ground, landed on tile by tile.
func _clump(m: Match) -> void:
	var h: Hunter = m.player
	var w: World = m.world
	var at := Vector2i(-1, -1)
	for z in range(3, w.h - 3):
		for x in range(3, w.w - 3):
			if at.x >= 0:
				break
			var lv: int = int(w.level[w.idx(x, z)])
			var flat := true
			for dz in range(-3, 4):
				for dx in range(-3, 4):
					var q := Vector2i(x + dx, z + dz)
					flat = flat and _walkable(w, q.x, q.y) and int(w.level[w.idx(q.x, q.y)]) == lv
			if flat:
				at = Vector2i(x, z)
	ok(at.x >= 0, "open ground for a test clump")
	if at.x < 0:
		return
	var tiles: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var i: int = w.idx(at.x + dx, at.y + dz)
			w.kind[i] = World.T_BLOCK
			tiles.append(i)
	var stuck := 0
	var spots := [Vector2(0.5, 0.5), Vector2(0.2, 0.8), Vector2(0.85, 0.15)]
	for i: int in tiles:
		for sp: Vector2 in spots:
			_clear(m)
			var top := float(w.level[i]) * World.LEVEL + World.BLOCK_H
			h.teleport(Vector3(i % w.w + sp.x, top + 0.4, i / w.w + sp.y))
			h.vel = Vector3.ZERO
			h.grounded = false
			_idle(h)
			for k in 50:
				m.step(Match.DT)
			if not _can_leave(m, h):
				stuck += 1
				print("LAYOUT stuck in the test clump at tile %d,%d (now %s)" % [i % w.w, i / w.w, h.pos])
	for i: int in tiles:
		w.kind[i] = World.T_GROUND
	ok(stuck == 0, "landing anywhere on a 3x3 clump never leaves you stuck (%d of %d)" % [
		stuck, tiles.size() * spots.size()])

## 2. The probe grid.
func _grid(m: Match) -> void:
	var h: Hunter = m.player
	var w: World = m.world
	var spots := 0
	var stuck := 0
	for z in range(1, w.h - 1, GRID):
		for x in range(1, w.w - 1, GRID):
			if not _walkable(w, x, z):
				continue
			spots += 1
			_clear(m)
			h.teleport(Vector3(x + 0.5, w.ground_at(x + 0.5, z + 0.5), z + 0.5))
			h.vel = Vector3.ZERO
			_idle(h)
			for i in 6:
				m.step(Match.DT)
			if not _can_leave(m, h):
				stuck += 1
				print("LAYOUT stuck at the probe spot %d,%d (%s)" % [x, z, h.pos])
	ok(spots > 20, "the probe grid covers the training area (%d spots)" % spots)
	ok(stuck == 0, "no probe spot leaves you stuck (%d of %d)" % [stuck, spots])

## 3. Colliding things between a step and a mantle.
func _snags(m: Match) -> void:
	var w: World = m.world
	var n := 0
	for i in w.kind.size():
		if w.kind[i] != World.T_BLOCK:
			continue
		var hgt := World.BLOCK_H
		if hgt > World.STEP and hgt < Hunter.MANTLE_REACH:
			n += 1
	ok(n == 0, "no colliding prop between step (%.2f m) and mantle (%.2f m) height: %d" % [
		World.STEP, Hunter.MANTLE_REACH, n])

func run(main: Node) -> void:
	Save.no_write = true
	var m := _match(main)
	for i in 20:
		m.step(Match.DT)
	_clear(m)
	_snags(m)
	_hops(m)
	_landings(m)
	_clump(m)
	_grid(m)
	m.queue_free()
	await main.get_tree().process_frame
	print("LAYOUT DONE, failures: %d" % bad)
	main.get_tree().quit()
