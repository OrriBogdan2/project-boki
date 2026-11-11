class_name BjornUlt
extends Node3D
## Breaker's ultimate on X, Faultline (docs/heroes/bulwark.md; hero sheet bjorn.md "Ultimate"). A tap plants
## him and raises the hammer for "windup" s while a lane of "cells" square cells ("cell_len" by "width")
## shows toward the cursor for everyone. Then the slam: the fissure races down the lane over "lead" s,
## striking every foe it reaches once (a small hit and the stun: data, "stuns struck targets"), and the
## ground erupts cell by cell to the far end ("cell_t" apart), throwing each foe on it up once (the big hit
## and a heavy slow, data: "explodes into a series of AoEs ... heavy Slow"). A wall or a raised ledge stops
## the fissure; it runs on over a drop. Where it ran, a glowing scar stays "scar_t" s and slows foes
## standing on it. A stun during the wind-up interrupts it (the cooldown comes back to "refund" s); a merge
## drops the wind-up with no slam.
##
## Look (pooled): one outlined lane over the whole reach with a lightning crack down its middle that glows
## brighter through the wind-up (the parity reel: a tall outlined rectangle with a crack), gold light
## flooding the near cell on the slam, a streak racing down the lane, a bright column of light erupting in
## each cell, then the crack left as a flickering ember scar. A foe the fissure stuns gets the stun stars.
## Bond: every hunter it hits goes to HeroUlt.landed; the best event of the cast pays.

const EMBER := Color("ff9a3a")
const GOLD := Color("ffd25a")
const MAX_CELLS := 6           # pooled eruption columns
const COLUMN_H := 4.5          # m, how high an eruption column stands at its peak
const COLUMN_T := 0.9          # s an eruption column lives
const CRACK_BREADTH := 1.0     # m the crack mesh is stretched across the lane (its kinks and width are in the mesh)

var k: BulwarkKit
var h: Hunter
var phase := ""                # "" | "wind" (planted, hammer up) | "erupt" (the fissure running)
var t := 0.0                   # s into the phase
var dir := Vector2.RIGHT       # the lane's direction, locked on the press
var origin := Vector3.ZERO
var cells: Array = []          # the cells the fissure reaches: their near-edge points
var erupted := 0
var struck := 0                # cells the racing fissure has struck
var hit := {}                  # foe instance id -> true: struck by the fissure this cast
var thrown := {}               # foe instance id -> true: thrown up by this cast
var hunters := 0               # (checks) hunters thrown this cast, casts that slammed, interrupted
var slams := 0
var interrupts := 0
var scar := {}                 # the scar: {t, a, len}
var _slabs: Array = []         # one per cell: {column, seam, t, at}
var _crack: MeshInstance3D     # down the lane's middle: the wind-up's glow, the slam's flash, then the scar
var _streak: MeshInstance3D
var _streak_t := 0.0
var _flood: MeshInstance3D
var _flood_t := 0.0

func _init(kit: BulwarkKit) -> void:
	k = kit
	h = kit.h
	top_level = true
	name = "BjornUlt"

func _ready() -> void:
	for i in MAX_CELLS:
		var column := KitMeshes.inst(self, KitMeshes.pillar(0.4, 1.0, 1.0), KitShaders.mat("panel", GOLD, true))
		var seam := KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("streak", GOLD, true))
		KitShaders.param(seam, "tail", 0.0)
		_slabs.append({"column": column, "seam": seam, "t": 0.0})
	var streak_mat := KitShaders.mat("streak", Color(1.0, 0.75, 0.35), true)
	_streak = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), streak_mat)
	_flood = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("panel", GOLD))
	_crack = KitMeshes.inst(self, KitMeshes.crack(0.3, 0.45, 16), KitShaders.mat("streak", AimKit.hero_col(h), true))
	KitShaders.param(_crack, "tail", 0.0)

func xd() -> Dictionary:
	return k.d.get("x", {})

## Planted: the wind-up and the slam's own beat (he can't move, swing, block or dash).
func planted() -> bool:
	return phase == "wind" or (phase == "erupt" and t < float(xd().get("plant", 0.2)))

## X pressed: plant, raise the hammer, lock the lane toward the cursor.
func cast() -> bool:
	dir = h.aim_dir().normalized()
	origin = h.pos
	cells = _reach()
	_place_crack()
	phase = "wind"
	t = 0.0
	erupted = 0
	struck = 0
	hit = {}
	thrown = {}
	hunters = 0
	h.vel = Vector3(0, h.vel.y, 0)
	k.play("bul_ult_wind")
	k.m.sfx("bjorn_ult_wind", h.pos, -3.0 if h.is_local() else -7.0)
	k.net_ring(origin + Vector3(dir.x, 0, dir.y) * cell_len() * 0.5, cell_len() * 0.5, EMBER)
	return true

func cell_len() -> float:
	return float(xd().get("cell_len", 4.0))

## The cells' near-edge points out to the full lane, stopping before a wall or a raised ledge; it runs on out
## over a drop or the abyss (those cells float at his height). The near cell is always struck.
func _reach() -> Array:
	var out: Array = []
	var cl := cell_len()
	var y0 := origin.y
	for i in int(xd().get("cells", 4)):
		var a := origin + Vector3(dir.x, 0, dir.y) * cl * i
		var c := a + Vector3(dir.x, 0, dir.y) * cl * 0.5
		var g: float = k.m.world.ground_at(c.x, c.z)
		if (k.m.world.is_block(c.x, c.z) or g > y0 + 1.2) and i > 0:
			break
		out.append(Vector3(a.x, y0, a.z))
	return out

## The height the lane's visuals sit at over `p`: the ground, or his own height where there is none (the
## abyss, or a drop far below), so the trail never cuts off at an edge.
func _trail_y(p: Vector3) -> float:
	var g: float = k.m.world.ground_at(p.x, p.z)
	return origin.y if g <= World.VOID + 1.0 or g < origin.y - 2.5 else g

## How far the trail is drawn (m): the whole reached lane, over the abyss too.
func trail_len() -> float:
	return cell_len() * cells.size()

## Every step: the phases, the telegraph and the scar.
func tick(dt: float) -> void:
	if h.model:
		h.model.set_meta(WardenMood.FLARE, phase != "")
	if not scar.is_empty():
		_tick_scar(dt)
	_glow_crack()
	if phase == "":
		return
	t += dt
	_telegraph()
	if phase == "wind":
		h.vel = Vector3(0, h.vel.y, 0)
		if h.stun_t > 0.0 or h.downed or h.out:
			_interrupt()
		elif t >= float(xd().get("windup", 0.4)):
			_slam()
		return
	var x := xd()
	var lead := float(x.get("lead", 0.2))
	var reached := mini(cells.size(), int(floor(t / maxf(0.01, lead) * cells.size())) + 1)
	while struck < reached:
		_strike(struck)
		struck += 1
	var due := int(floor((t - lead) / float(x.get("cell_t", 0.15)))) + 1
	while erupted < mini(due, cells.size()):
		_erupt(erupted)
		erupted += 1
	if erupted >= cells.size() and t > float(x.get("lead", 0.2)) + float(x.get("cell_t", 0.15)) * cells.size():
		phase = ""
		var length := cell_len() * cells.size()
		scar = {"t": float(x.get("scar_t", 10.0)), "a": origin, "len": length, "fx": 0.0}

## The lane everyone sees: one outlined rectangle over the whole reach in his colour, its gold fill running
## down it as the cells erupt.
func _telegraph() -> void:
	var done := float(erupted) / cells.size()
	AimKit.lane(h, "x", {"from": origin, "dir": dir, "len": trail_len(), "width": float(xd().get("width", 4.0)),
		"all": true, "col2": GOLD, "fill": done, "hot": done * 0.6, "lw": 0.14, "alpha": 1.6, "dur": 0.15})
	AimKit.entry(h, "x")["y"] = _trail_y(origin + Vector3(dir.x, 0, dir.y) * trail_len() * 0.5)

func _interrupt() -> void:
	phase = ""
	interrupts += 1
	k.cd["x"] = minf(float(k.cd["x"]), float(xd().get("refund", 8.0)))
	k.m.fx.word(h.pos + Vector3(0, 2.4, 0), "INTERRUPTED", Color("ff8a7a"), true)
	k.m.sfx("warn", h.pos, -4.0, 0.8)
	_hide_lane()

## A merge drops the wind-up with no slam; a fissure already running finishes (it's a cast).
func drop() -> void:
	if phase == "wind":
		phase = ""
		_hide_lane()

func _hide_lane() -> void:
	AimKit.hide(h, "x")
	_crack.visible = false

## The slam: the near cell floods gold and the streak races off (striking cell by cell, see tick).
func _slam() -> void:
	var x := xd()
	phase = "erupt"
	t = 0.0
	slams += 1
	k.play("bul_ult_slam")
	k.m.sfx("bjorn_ult_slam", origin, 0.0 if h.is_local() else -4.0)
	k.m.sfx("bjorn_ult_rumble", origin + Vector3(dir.x, 0, dir.y) * cell_len() * cells.size() * 0.5, -3.0)
	_strike(0)
	struck = 1
	var c0 := _cell_mid(0)
	_flood_t = 0.3
	_place_flat(_flood, c0 + Vector3(0, 0.08, 0), Vector2(cell_len(), float(x.get("width", 4.0))))
	_streak_t = float(x.get("cell_t", 0.15)) * cells.size() + float(x.get("lead", 0.2))
	k.m.fx.burst(c0 + Vector3(0, 0.4, 0), GOLD, 24, 7.0, 0.4, 3.0, 1.3)
	k.m.fx.dust(c0, 14)
	k.net_ring(c0, cell_len() * 0.6, GOLD)

## The racing fissure reaches cell `i`: each foe in it not struck yet takes the strike and the stun.
func _strike(i: int) -> void:
	var x := xd()
	var strike: float = float(x.get("strike_dmg", 4.0)) * k.m.dmg_mult(h) * LevelGrowth.ap(h)
	for f in _foes_in(i):
		if hit.has(f.get_instance_id()):
			continue
		hit[f.get_instance_id()] = true
		f.hurt(strike, h, {"src": "abil", "ab": "ultimate", "stun": float(x.get("strike_stun", 0.5)), "dr": true,
			"tags": ["ultimate"]})
		KitLooks.of(k.m).crown(f, float(x.get("strike_stun", 0.5)))
		if f is Hunter:
			HeroUlt.landed(k, f)

## One cell heaves up: a slab with molten seams, each foe on it thrown once.
func _erupt(i: int) -> void:
	var x := xd()
	var mid := _cell_mid(i)
	var slab: Dictionary = _slabs[i % MAX_CELLS]
	slab["t"] = COLUMN_T
	slab["at"] = mid
	k.m.fx.dust(mid, 10)
	k.m.fx.burst(mid + Vector3(0, 0.6, 0), EMBER, 12, 6.0, 0.4, 6.0, 1.1, Vector3.UP, 30.0)
	k.m.sfx("bjorn_slam", mid, -8.0, 0.7 + 0.08 * i)
	var dmg: float = float(x.get("dmg", 18.0)) * k.m.dmg_mult(h) * LevelGrowth.ap(h)
	for f in _foes_in(i):
		var key: int = f.get_instance_id()
		if thrown.has(key):
			continue
		thrown[key] = true
		f.hurt(dmg, h, {"src": "abil", "ab": "ultimate", "lift": float(x.get("lift", 7.0)),
			"slow": float(x.get("slow_t", 1.5)), "slow_k": float(x.get("slow", 0.5)),
			"dr": true, "tags": ["ultimate"]})
		k.m.fx.burst(f.pos + Vector3(0, 1.0, 0), Color("ff5a3a"), 10, 5.0, 0.3, 2.0, 1.0)
		if f is Hunter:
			hunters += 1
			HeroUlt.landed(k, f)

func _cell_mid(i: int) -> Vector3:
	var a: Vector3 = cells[i]
	var c := a + Vector3(dir.x, 0, dir.y) * cell_len() * 0.5
	return Vector3(c.x, _trail_y(c), c.z)

func _foes_in(i: int) -> Array:
	var a: Vector3 = cells[i]
	var out: Array = []
	for f in k.m.foes_of(h.team):
		if not f.hittable() or absf(f.pos.y - a.y) > 2.5:
			continue
		if AimMode.in_lane(a, dir, cell_len(), float(xd().get("width", 4.0)), f.pos, f.r):
			out.append(f)
	return out

## The scar: foes standing on it are slowed; it flickers out over its last second.
func _tick_scar(dt: float) -> void:
	scar["t"] = float(scar["t"]) - dt
	if float(scar["t"]) <= 0.0:
		scar = {}
		_crack.visible = false
		return
	var x := xd()
	var a: Vector3 = scar["a"]
	var length := float(scar["len"])
	var slow := float(x.get("scar_slow", 0.2))
	for f in k.m.foes_of(h.team):
		if not f.hittable() or absf(f.pos.y - a.y) > 1.5:
			continue
		if AimMode.in_lane(a, dir, length, float(x.get("scar_w", 1.4)), f.pos):
			f.slow_k = maxf(f.slow_k, slow) if f.slow_t > 0.0 else slow
			f.slow_t = maxf(f.slow_t, 0.25)
	scar["fx"] = float(scar["fx"]) - dt
	if float(scar["fx"]) <= 0.0:
		scar["fx"] = 0.7
		var mid := a + Vector3(dir.x, 0, dir.y) * length * 0.5
		k.m.sfx("bjorn_ult_crackle", mid, -16.0, randf_range(0.9, 1.1))

## The crack, laid down the lane's middle for the whole reach (it stays as the scar).
func _place_crack() -> void:
	var mid := origin + Vector3(dir.x, 0, dir.y) * trail_len() * 0.5
	_place_flat(_crack, Vector3(mid.x, _trail_y(mid) + 0.06, mid.z), Vector2(trail_len(), CRACK_BREADTH))

## Lays a quad flat on the ground along the lane's direction, `size` = (along, across).
func _place_flat(n: MeshInstance3D, at: Vector3, size2: Vector2) -> void:
	n.visible = true
	n.global_position = at
	n.rotation = Vector3(-PI * 0.5, atan2(-dir.y, dir.x), 0.0)
	n.scale = Vector3(size2.x, size2.y, 1.0)

func _process(delta_in: float) -> void:
	var delta := minf(delta_in, 1.0 / 30.0)
	if not is_instance_valid(h):
		return
	_tick_slabs(delta)
	if _flood_t > 0.0:
		_flood_t -= delta
		_flood.visible = _flood_t > 0.0
		KitShaders.param(_flood, "power", 2.0 * clampf(_flood_t / 0.3, 0.0, 1.0))
	if _streak_t > 0.0:
		_streak_t -= delta
		var total := maxf(0.05, float(xd().get("cell_t", 0.15)) * cells.size() + float(xd().get("lead", 0.2)))
		var u := 1.0 - clampf(_streak_t / total, 0.0, 1.0)
		var length := cell_len() * cells.size()
		var head := origin + Vector3(dir.x, 0, dir.y) * length * u
		_place_flat(_streak, Vector3(head.x, _trail_y(head) + 0.25, head.z), Vector2(2.4, 0.9))
		_streak.visible = _streak_t > 0.0

## The crack's glow: dim and hero-coloured as the cast starts, hotter and goldener every moment until the slam,
## white-gold as the fissure runs, then the cooling ember scar that flickers out over its last second.
func _glow_crack() -> void:
	if not _crack.visible:
		return
	var heat := 1.0
	var power := 3.0
	var col := GOLD
	if phase == "wind":
		heat = clampf(t / float(xd().get("windup", 0.4)), 0.0, 1.0)
		power = lerpf(0.8, 3.0, heat * heat)
		col = AimKit.hero_col(h).lerp(GOLD, heat)
	elif phase == "":
		power = (1.0 + 0.35 * sin(Time.get_ticks_msec() * 0.012)) * clampf(float(scar.get("t", 0.0)), 0.0, 1.0)
		col = EMBER
	KitShaders.param(_crack, "power", power)
	KitShaders.param(_crack, "color", col)

## Each cell's column of light shoots up fast over the whole cell, hangs, then fades; the molten seam under
## it glows then cools.
func _tick_slabs(delta: float) -> void:
	var w := float(xd().get("width", 4.0))
	for s in _slabs:
		var seam: MeshInstance3D = s["seam"]
		var column: MeshInstance3D = s["column"]
		var live := float(s["t"]) > 0.0
		seam.visible = live
		column.visible = live
		if not live:
			continue
		s["t"] = float(s["t"]) - delta
		var left := float(s["t"]) / COLUMN_T
		var rise := clampf((1.0 - left) / 0.12, 0.0, 1.0)
		var at: Vector3 = s["at"]
		column.global_position = at
		column.rotation = Vector3(0, atan2(-dir.y, dir.x), 0)
		column.scale = Vector3(cell_len() * 0.5, COLUMN_H * rise, w * 0.5)
		KitShaders.param(column, "power", 2.4 * clampf(left / 0.6, 0.0, 1.0))
		_place_flat(seam, at + Vector3(0, 0.1, 0), Vector2(cell_len() * 0.95, w * 0.85))
		KitShaders.param(seam, "power", 2.2 * left)
