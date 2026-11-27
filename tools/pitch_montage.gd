extends RefCounted
## SCRATCH (private pitch footage, never shipped): shot 16, the garden worlds hop montage (r12). Motley walks into the
## Waystone's ring and steps through its light; the next world is already there, he walks out of the same kind of light
## and goes on. Home farm -> Glasswater -> Cinderstep -> Hushwood -> Kitewind Ridge. The encoder (encode_montage.py in the
## clip folder) cuts at the marks: cutN_out / cutN_in around each hop (a hard cut through white, no dissolve), jumpN_out /
## jumpN_in where Motley is set down again before the pad (a hard cut). Run through tools/pitch_worlds.gd (`w`).

const FPS := 60
const HOME_AWAY_M := 7.0  # m from the Waystone Motley starts (home farm)
const PAD_AWAY_M := 5.5  # m from a return pad Motley is set down again, facing it
const STONE_MID_M := 0.9  # m from the stone's middle he must reach before the light takes him (the ring's standing stones stop him nearer)
const ENTER_S := 3.5  # s at most to reach it
const STROLL_S := 2.7  # s of walking in a world after he lands
const STROLL_AHEAD_M := 9.0  # m the walk on is aimed past the pad (the view's up on landing)
const STEP_S := 0.5  # s the Waystone's light is up before the ink wipe (rules hop_fade_s)
const EMERGE_S := 0.45  # s he takes to step out of the light on the other side
const AWAY_RAD := [0.52, -0.52, 0.0, 1.05, -1.05, 1.57, -1.57, 2.1, -2.1, 2.6, -2.6, 3.14]  # tried in order: 0 = south of the stone
const LEVEL_TIP := 0.1  # rad: a view tipped more than this over a wall is not filmed
const MONTAGE_AT := [Vector2(-2.4, 3.6), Vector2(2.5, 5.0)]  # (m right, m ahead) of the landing: two Boki either side of the straight walk on, close enough to read
const HUSHWOOD_CLOCK := 0.74  # Hushwood's own hour is deep dusk (0.78, daylight 0.3): the film shows it at 0.7 daylight, warm and readable
const ZONE_ORDER := ["glasswater", "cinderstep", "hushwood", "ridge"]
const PILLAR_H := 3.6
const PILLAR_R := 0.7
const PILLAR_A := 0.45  # its strongest see-through

var w  # tools/pitch_worlds.gd
var _cuts := 0
var _jumps := 0
var _s0 := Vector3.ONE  # Motley's own scale (the hunters are x1.10)


func _init(worlds) -> void:
	w = worlds


func play() -> void:
	GardenZones.info("hushwood")["clock"] = HUSHWOOD_CLOCK
	w._stage_at = MONTAGE_AT
	await w._load(GardenZones.HUB)
	_s0 = w.h.player.scale
	await _jump(HOME_AWAY_M)
	_partner_aside()
	w.rig.mark("montage")
	await w._wait(0.3)
	for z in ZONE_ORDER:
		await _into_stone()
		await _through(z)
		await _stroll()
		if z != ZONE_ORDER[-1]:
			await _jump(PAD_AWAY_M)
	w.rig.mark("end")
	await w._wait(0.4)


## Motley is set down `dist` m from the stone on open ground, tree-free, the view turned to face it. Each start is tried
## by walking it to the stone (unfilmed); the first whose view stays level all the way is kept (a wall or cliff behind
## the camera tips the view top-down, which is not filmed). The hard cut: jumpN_out before, jumpN_in after the settle.
func _jump(dist: float) -> void:
	var h: Node = w.h
	var stone: Vector3 = h.hway.node.position
	_jumps += 1
	if _jumps > 1:
		w.rig.mark("jump%d_out" % (_jumps - 1))
	var best := 99.0
	var best_a := 0.0
	for a in AWAY_RAD:
		var at := _start_for(stone, a, dist)
		if at == Vector3.INF:
			continue
		await _set_down(at, stone)
		var top := await _trial(stone)
		if top < best:
			best = top
			best_a = a
		if top <= LEVEL_TIP:
			break
	if best == 99.0:
		w.rig.fail("no open approach to the stone")
		return
	await _set_down(_start_for(stone, best_a, dist), stone)
	print("PITCH jump%d dist=%.1f away=%.2f tip_max=%.2f" % [_jumps, dist, best_a, best])
	if _jumps > 1:
		w.rig.mark("jump%d_in" % (_jumps - 1))


## The open, tree-free, Boki-free spot `dist` m from the stone at angle `a` (0 = south of it), or INF.
func _start_for(stone: Vector3, a: float, dist: float) -> Vector3:
	var from := stone + Vector3(sin(a), 0.0, cos(a)) * dist
	var at: Vector3 = w.h.world.free_spot_near(from, [], 1.2, 0.9, 2.0)
	if at.distance_to(from) > 1.5 or not w._trees_clear(at, [stone]) or _boki_near(at):
		return Vector3.INF
	return at


func _set_down(at: Vector3, stone: Vector3) -> void:
	w._place(at)
	w.h.farm_cam.yaw = atan2(-(stone.x - at.x), -(stone.z - at.z))  # keys' up is away from the camera: up = toward the stone
	w.h.cam.snap(at)
	await w._wait(0.4)


## Walks to the stone's middle, returns the most the view tipped on the way.
func _trial(stone: Vector3) -> float:
	var top: float = w.h.farm_cam.tip
	var left := 6 * FPS
	while left > 0 and Vector2(stone.x - w.h.ppos.x, stone.z - w.h.ppos.z).length() > STONE_MID_M:
		w._keys(w._steer(stone).rotated(w.h.cam.yaw))
		await w.rig.main.get_tree().process_frame
		w._tidy()
		top = maxf(top, w.h.farm_cam.tip)
		left -= 1
	w._keys(Vector2.ZERO)
	return top


## The partner stands off to the side of the walk in, not in the ring.
func _partner_aside() -> void:
	var stone: Vector3 = w.h.hway.node.position
	var dir: Vector3 = (stone - w.h.ppos).normalized()
	var at: Vector3 = w.h.world.free_spot_near(stone + Vector3(-dir.z, 0.0, dir.x) * 3.6 - dir * 0.6, [], 1.5, 1.1, 3.0)
	for pin in w._pins:
		pin[1] = at
		((pin[0] as Dictionary)["node"] as Node3D).position = at


func _boki_near(at: Vector3) -> bool:
	for n in w._show:
		var p: Vector3 = (n as Node3D).global_position
		if Vector2(p.x - at.x, p.z - at.z).length() < 3.2:
			return true
	return false


## Walks up to the stone and into its ring, up to the middle.
func _into_stone() -> void:
	var stone: Vector3 = w.h.hway.node.position
	await w._walk(stone, STONE_MID_M, ENTER_S)


## Steps through the light: the pillar rises round him as the stone lights, he keeps walking and goes into it; the mark
## cutN_out is where the ink wipe starts. On the other side the new Home is built, he stands tiny in the pad's pillar,
## the wipe lifts (cutN_in) and he steps out of it, walking on.
func _through(zone: String) -> void:
	var h: Node = w.h
	var col := Color(String(GardenZones.info(zone).get("colour", "c9c2b2")))
	var pillar := _pillar(h, h.hway.node.position, col)
	if not h.hway.hop(zone):
		w.rig.fail("hop to %s refused" % zone)
		return
	_cuts += 1
	var from := h
	var steps := roundi(STEP_S * FPS)
	for i in steps:
		var f := float(i + 1) / float(steps)
		_set_pillar(pillar, PILLAR_A * minf(1.0, f * 2.5))
		h.player.scale = _s0 * lerpf(1.0, 0.04, smoothstep(0.3, 1.0, f))
		w._keys(Vector2(0.0, -1.0))
		await w.rig.main.get_tree().process_frame
		w._tidy()
	w._keys(Vector2.ZERO)
	w.rig.mark("cut%d_out" % _cuts)
	await w._arrived()
	if w.h == from:
		w.rig.fail("no new Home after the hop to %s" % zone)
	h = w.h
	_s0 = h.player.scale
	h.player.scale = _s0 * 0.04
	var fade: ScreenFade = w.rig.main.fade
	while fade.covered or fade.rect.color.a > 0.01:
		await w.rig.main.get_tree().process_frame
		w._tidy()
		h.player.scale = _s0 * 0.04
	var here := _pillar(h, h.hway.node.position, col)
	_set_pillar(here, PILLAR_A)
	w.rig.mark("cut%d_in" % _cuts)
	var n := roundi(EMERGE_S * FPS)
	for i in n:
		var f := float(i + 1) / float(n)
		_set_pillar(here, PILLAR_A * (1.0 - smoothstep(0.4, 1.0, f)))
		h.player.scale = _s0 * lerpf(0.04, 1.0, smoothstep(0.0, 0.8, f))
		w._keys(Vector2(0.0, -1.0))
		await w.rig.main.get_tree().process_frame
		w._tidy()
	w._keys(Vector2.ZERO)
	here.queue_free()


## After landing: walks straight on between the two Boki (they stand either side of the way), so the world and its
## Boki are read; the way is cleared of props first.
func _stroll() -> void:
	var h: Node = w.h
	var goal: Vector3 = h.world.free_spot_near(
		h.hway.node.position + Vector3(0.0, 0.0, -STROLL_AHEAD_M), [], 1.2, 0.9, 3.0
	)
	w._clear_path(h.ppos, [goal])
	await w._walk(goal, 0.5, STROLL_S - EMERGE_S)
	await w._wait(0.15)


## A soft column of the zone's colour standing on the stone (film-only; the game's own light-up is its burst).
func _pillar(parent: Node, at: Vector3, col: Color) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = PILLAR_R
	cyl.bottom_radius = PILLAR_R
	cyl.height = PILLAR_H
	cyl.radial_segments = 20
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col.lightened(0.35), 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at + Vector3(0.0, PILLAR_H * 0.5, 0.0)
	parent.add_child(mi)
	return mi


func _set_pillar(mi: MeshInstance3D, a: float) -> void:
	var m := mi.material_override as StandardMaterial3D
	m.albedo_color = Color(m.albedo_color, clampf(a, 0.0, 1.0))
