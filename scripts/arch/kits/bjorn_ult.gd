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
## Look (content/vfx/bulwark.json): the path of the sea. His anglerfish lure flares as he plants, the slam floods
## the lane with deep sea-green water racing to the far end, foam sprays up cell by cell as each erupts, a
## churning vortex opens at the end, and wet foam stays along the scar while it lasts. Bond: every hunter it
## hits goes to HeroUlt.landed; the best event of the cast pays.

const EMBER := Color("ff9a3a")
const GOLD := Color("ffd25a")
const MAX_CELLS := 6           # lane cells the telegraph can show
const SCAR_LOOK_EVERY := 2.0   # s between the scar's wet foam looks (each lasts 2.2 s, so they overlap)

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
var scar := {}                 # the scar: {t, a, len, fx (s to the next crackle), look (s to the next foam)}

func _init(kit: BulwarkKit) -> void:
	k = kit
	h = kit.h
	top_level = true
	name = "BjornUlt"

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
	k.vfx("ult_wind", origin, dir)
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
	if not scar.is_empty():
		_tick_scar(dt)
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
		scar = {"t": float(x.get("scar_t", 10.0)), "a": origin, "len": length, "fx": 0.0, "look": 1.2}

## The lane everyone sees: one outlined cell per square, each filling as it erupts.
func _telegraph() -> void:
	var x := xd()
	for i in cells.size():
		var a: Vector3 = cells[i]
		var done := 1.0 if i < erupted else 0.0
		AimKit.lane(h, "x%d" % i, {"from": a, "dir": dir, "len": cell_len(), "width": float(x.get("width", 4.0)),
			"all": true, "col": EMBER, "col2": GOLD, "fill": done, "hot": done * 0.6, "dur": 0.15})
		AimKit.entry(h, "x%d" % i)["y"] = _trail_y(a + Vector3(dir.x, 0, dir.y) * cell_len() * 0.5)

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
	for i in MAX_CELLS:
		AimKit.hide(h, "x%d" % i)

## The slam: the lane floods with sea water racing off down it (striking cell by cell, see tick).
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
	k.vfx("ult_slam", Vector3(origin.x, _trail_y(origin), origin.z), dir, {"len": trail_len()})

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
		if f is Hunter:
			HeroUlt.landed(k, f)

## One cell erupts in a fountain of foam, each foe on it thrown once; the last opens the churning vortex.
func _erupt(i: int) -> void:
	var x := xd()
	var mid := _cell_mid(i)
	k.vfx("ult_cell", mid, dir)
	if i == cells.size() - 1:
		k.vfx("ult_end", mid + Vector3(dir.x, 0, dir.y) * cell_len() * 0.25, dir)
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
		k.vfx("ult_hit", f.pos, dir)
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

## The scar: foes standing on it are slowed; wet foam stays along it, renewed every SCAR_LOOK_EVERY s.
func _tick_scar(dt: float) -> void:
	scar["t"] = float(scar["t"]) - dt
	if float(scar["t"]) <= 0.0:
		scar = {}
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
	scar["look"] = float(scar["look"]) - dt
	if float(scar["look"]) <= 0.0 and float(scar["t"]) > 1.0:
		scar["look"] = SCAR_LOOK_EVERY
		k.vfx("ult_scar", Vector3(a.x, _trail_y(a), a.z), dir, {"len": length})
