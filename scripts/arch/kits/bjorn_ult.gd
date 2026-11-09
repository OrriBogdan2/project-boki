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
## The landing is the impact: a hit-stop for him (his own screen never shakes, item 50), a shake for players near,
## a dust ring, rock debris, a cracked-ground decal and a sub-heavy quake under the slam.
##
## Look (pooled): gold light flooding the near cell on the slam, an ember streak racing down the lane,
## a basalt slab with molten seams heaving up in each cell, then a flickering ember crack along the
## centre line. Bond: every hunter it hits goes to HeroUlt.landed; the best event of the cast pays.

const EMBER := Color("ff9a3a")
const GOLD := Color("ffd25a")
const ROCK := Color("5a4a42")
const MAX_CELLS := 6           # pooled slabs
const SHARDS := 4              # basalt spikes per cell
## Each spike's place in its cell (along, across as shares of the cell), its lean and its height.
const SHARD_AT := [Vector4(-0.22, -0.28, 0.35, 1.5), Vector4(0.18, 0.22, -0.3, 1.9), Vector4(0.3, -0.1, 0.2, 1.2),
	Vector4(-0.3, 0.3, -0.25, 1.1)]

## The hop's shape, as shares of "windup": a short hop, hammer overhead, a hang, then the slam
const LEAP_CROUCH := 0.15      # he crouches this share before he leaves the ground
const LEAP_TOP := 0.5          # by here he is "leap_h" up (easing out)
const LEAP_HANG := 0.8         # he hangs to here, sinking to HANG_SINK of the top, then drives down
const HANG_SINK := 0.9
const DRIVE_CAP := 40.0        # m/s the drive down may fall at (past the usual 12 m/s fall cap)
const SLAM_STOP := 0.09        # s of hit-stop for him on the landing, foes or none: the weight of the slam
const QUAKE_SHAKE := 0.8       # the shake players near the landing feel (Shake.incoming_big; never his own)
const DUST := Color("b8a58a")

var k: BulwarkKit
var h: Hunter
var leap := false              # cast on the ground: the wind-up is the hop (in the air he falls as before)
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
var _slabs: Array = []         # one per cell: {shards (SHARDS basalt spikes), seam, t, at}
var _streak: MeshInstance3D
var _streak_t := 0.0
var _flood: MeshInstance3D
var _flood_t := 0.0
var _scar: MeshInstance3D

func _init(kit: BulwarkKit) -> void:
	k = kit
	h = kit.h
	top_level = true
	name = "BjornUlt"

func _ready() -> void:
	var rock_mat := Models.toon(ROCK, true, 0.2)
	for i in MAX_CELLS:
		var shards: Array = []
		for j in SHARDS:
			shards.append(KitMeshes.inst(self, Models.crystal(0.55, 1.0, 5), rock_mat))
		var seam := KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("streak", EMBER, true))
		KitShaders.param(seam, "tail", 0.0)
		_slabs.append({"shards": shards, "seam": seam, "t": 0.0})
	var streak_mat := KitShaders.mat("streak", Color(1.0, 0.75, 0.35), true)
	_streak = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), streak_mat)
	_flood = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("panel", GOLD))
	_scar = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("streak", EMBER, true))
	KitShaders.param(_scar, "tail", 0.0)

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
	leap = h.grounded
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
		else:
			_hop(dt)
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
		_scar_show(length)

## m over the cast's ground he should be at `s` (share of the wind-up) into the hop.
func leap_y(s: float) -> float:
	var top := float(xd().get("leap_h", 1.2))
	if s < LEAP_CROUCH:
		return 0.0
	if s < LEAP_TOP:
		return top * ease((s - LEAP_CROUCH) / (LEAP_TOP - LEAP_CROUCH), 0.4)
	if s < LEAP_HANG:
		return top * lerpf(1.0, HANG_SINK, (s - LEAP_TOP) / (LEAP_HANG - LEAP_TOP))
	return top * HANG_SINK * (1.0 - ease(minf(1.0, (s - LEAP_HANG) / (1.0 - LEAP_HANG)), 1.8))

## Steers his height onto the hop's curve this step (Hunter's air step takes gravity off before it moves him).
func _hop(dt: float) -> void:
	if not leap or dt <= 0.0:
		return
	var want := origin.y + leap_y(t / float(xd().get("windup", 0.4)))
	if h.grounded and want <= h.pos.y + 0.001:
		return
	h.grounded = false
	h.vel.y = (want - h.pos.y) / dt + Hunter.H_GRAV * dt

## m/s his fall may reach while the hop drives him down (0: the usual cap).
func dive_cap() -> float:
	return DRIVE_CAP if leap and phase != "" and not h.grounded else 0.0

## The lane everyone sees: one outlined cell per square, each filling as it erupts.
func _telegraph() -> void:
	var x := xd()
	for i in cells.size():
		var a: Vector3 = cells[i]
		var done := 1.0 if i < erupted else 0.0
		AimKit.lane(h, "x%d" % i, {"from": a, "dir": dir, "len": cell_len(), "width": float(x.get("width", 5.5)),
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
	_place_flat(_flood, c0 + Vector3(0, 0.08, 0), Vector2(cell_len(), float(x.get("width", 5.5))))
	_streak_t = float(x.get("cell_t", 0.15)) * cells.size() + float(x.get("lead", 0.2))
	k.m.fx.burst(c0 + Vector3(0, 0.4, 0), GOLD, 24, 7.0, 0.4, 3.0, 1.3)
	k.m.fx.dust(c0, 14)
	k.net_ring(c0, cell_len() * 0.6, GOLD)
	_impact(origin + Vector3(dir.x, 0, dir.y) * 1.0)

## The landing's weight: hit-stop, a shake for the players round it, a dust ring, rock debris, cracked ground
## and the quake.
func _impact(at: Vector3) -> void:
	var m: Node = k.m
	var w := float(xd().get("width", 5.5))
	if h == m.get("player") and not bool(m.get("net_on")):
		m.freeze_frame(SLAM_STOP)
	else:
		h.freeze_t = maxf(h.freeze_t, SLAM_STOP)
	for f in k.foes_in(origin, cell_len() * 1.2):
		if hit.has(f.get_instance_id()):
			Feel.hitstop(m, h, f, float(xd().get("strike_dmg", 4.0)), {"heavy": true, "payoff": true})
	Shake.incoming_big(m, at, QUAKE_SHAKE, h)
	m.fx.ring(at + Vector3(0, 0.15, 0), w * 0.5, DUST, 0.45)
	m.fx.ring(at + Vector3(0, 0.1, 0), w * 0.8, DUST, 0.7)
	m.fx.burst(at + Vector3(0, 0.3, 0), ROCK, 18, 8.0, 0.8, 18.0, 1.6, Vector3.UP, 55.0)
	m.fx.burst(at + Vector3(0, 0.2, 0), DUST, 14, 5.0, 0.6, 2.0, 1.8)
	LDFx.of(m).scorch(at, 2.0, 1.8, Color("8a7a66"), Color("2a241e"))
	m.sfx("bjorn_ult_quake", at, 0.0 if h.is_local() else -4.0)

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

## One cell heaves up: a slab with molten seams, each foe on it thrown once.
func _erupt(i: int) -> void:
	var x := xd()
	var mid := _cell_mid(i)
	var slab: Dictionary = _slabs[i % MAX_CELLS]
	slab["t"] = 0.9
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
		if AimMode.in_lane(a, dir, cell_len(), float(xd().get("width", 5.5)), f.pos, f.r):
			out.append(f)
	return out

## The scar: foes standing on it are slowed; it flickers out over its last second.
func _tick_scar(dt: float) -> void:
	scar["t"] = float(scar["t"]) - dt
	if float(scar["t"]) <= 0.0:
		scar = {}
		_scar.visible = false
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

func _scar_show(length: float) -> void:
	var mid := origin + Vector3(dir.x, 0, dir.y) * length * 0.5
	_place_flat(_scar, Vector3(mid.x, _trail_y(mid) + 0.06, mid.z), Vector2(length, 0.5))
	_scar.visible = true

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
	if _scar.visible and not scar.is_empty():
		var fade := clampf(float(scar["t"]), 0.0, 1.0)
		KitShaders.param(_scar, "power", (1.0 + 0.35 * sin(Time.get_ticks_msec() * 0.012)) * fade)

## Each cell's basalt spikes heave up out of the ground fast, hang, then sink back; the molten seam under
## them glows then cools.
func _tick_slabs(delta: float) -> void:
	var w := float(xd().get("width", 5.5))
	var along := Vector3(dir.x, 0, dir.y)
	var across := Vector3(-dir.y, 0, dir.x)
	for s in _slabs:
		var seam: MeshInstance3D = s["seam"]
		var live := float(s["t"]) > 0.0
		seam.visible = live
		for shard in s["shards"]:
			(shard as MeshInstance3D).visible = live
		if not live:
			continue
		s["t"] = float(s["t"]) - delta
		var age := 0.9 - float(s["t"])
		var rise := clampf(age / 0.12, 0.0, 1.0) * clampf(float(s["t"]) / 0.35, 0.0, 1.0)
		var at: Vector3 = s["at"]
		for j in SHARDS:
			var shard: MeshInstance3D = s["shards"][j]
			var spot: Vector4 = SHARD_AT[j]
			var tall := spot.w * (0.4 + 0.6 * rise)
			var foot := at + along * spot.x * cell_len() + across * spot.y * w
			shard.global_position = foot + Vector3(0, tall * 0.5 - 0.3, 0)
			shard.rotation = Vector3(spot.z * rise, atan2(-dir.y, dir.x) + j, -spot.z * 0.6 * rise)
			shard.scale = Vector3(1.0, tall, 1.0)
		_place_flat(seam, at + Vector3(0, 0.1, 0), Vector2(cell_len() * 0.95, w * 0.85))
		KitShaders.param(seam, "power", 2.2 * clampf(float(s["t"]) / 0.9, 0.0, 1.0))
