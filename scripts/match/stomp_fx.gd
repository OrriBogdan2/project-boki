class_name StompFx
extends Node3D
## How a stomp reads to everyone watching (docs/decisions/0061-stomp-lock.md): a pin ring on the ground
## round the wisp that tightens on it for the whole Stomp.TIME and squeezes on every slam, so allies see
## from afar that someone is being finished. It ends the way the stomp did:
##   done     the ring closes onto the wisp while its core gutters out (HunterWisp.collapse), no blast
##   broken   the ring shatters into arcs that fly apart and the wisp bobs free (HunterWisp.bob_free)
##   gone     (revived, bled out, extracted) the ring just fades
## Stomp.start/end call pin/release on every game, the stomper's own and the ones the "stomp" event
## reaches, so everyone sees the same. All nodes come from a pool made once; a fifth stomp at the same
## time takes the oldest slot.

const POOL := 4                 # stomps on screen at once
const SHARDS := 4               # arcs the ring breaks into
const SHARD_ARC := 0.18         # fraction of a turn each arc covers (the rest are the cracks)
const RING_FROM := 1.3          # m, the ring's radius as the stomp starts: a step round the wisp
const RING_TO := 0.42           # m, at the finish: hugging the wisp's body (0.3 m)
const SLAM_SQUEEZE := 0.14      # fraction the ring pulls in on each slam
const SLAM_DECAY := 9.0         # 1/beat, how fast a slam's squeeze and the wisp's squash ease off
const COLOR := Color("ff6a5a")  # the stomp's warning red (the STOMP word, the toast)
const CLOSE_S := 0.45           # s the ring takes to close on a finished stomp (the Wisp's collapse time)
const SHATTER_S := 0.4          # s the arcs fly
const SHATTER_GROW := 2.2       # the arcs end this many times the ring's radius out
const FADE_S := 0.15            # s a ring takes to fade when the stomp ends any other way
const LIFT := 0.07              # m above the feet, over the team ring

var _slots: Array = []          # {"ring", "shards", "o": wisp, "s": stomper, "mode", "t", "r": radius now}

func _init() -> void:
	name = "StompFx"
	for i in POOL:
		var slot := {"ring": _make_ring(1.0), "shards": [], "o": null, "s": null, "mode": "", "t": 0.0, "r": 0.0}
		for k in SHARDS:
			slot["shards"].append(_make_ring(SHARD_ARC))
		_slots.append(slot)

func _make_ring(arc: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Models.flat_quad(2.0)
	var mat := Models.ring_mat(COLOR, 0.14)
	mat.set_shader_parameter("arc", arc)
	mat.set_shader_parameter("halo", 1.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

## The wisp o is being stomped by s: its ring starts at RING_FROM.
func pin(o: Hunter, s: Hunter) -> void:
	var slot := _slot_for(o)
	if slot.is_empty():
		slot = _slots[0]
		for sl in _slots:
			if sl["mode"] == "":
				slot = sl
				break
			if float(sl["t"]) > float(slot["t"]):
				slot = sl
	_hide(slot)
	slot.merge({"o": o, "s": s, "mode": "pin", "t": 0.0, "r": RING_FROM}, true)
	(slot["ring"] as MeshInstance3D).visible = true

## The stomp on o ended (Stomp.end's why): close, shatter or fade its ring, and play the wisp's side.
func release(o: Hunter, why: String) -> void:
	var slot := _slot_for(o)
	if slot.is_empty():
		return
	slot["t"] = 0.0
	match why:
		"done":
			slot["mode"] = "close"
			HunterWisp.collapse(o)
		"broken":
			slot["mode"] = "shatter"
			(slot["ring"] as MeshInstance3D).visible = false
			HunterWisp.bob_free(o)
			if o.visible:
				o.m.sfx("armor_break", o.pos, -12.0, 1.5)
		_:
			slot["mode"] = "fade"

## How hard the wisp o is pressed down right now, 0..1: a hold that grows over the stomp and a squash
## at each slam that eases off. 0 when nobody is stomping it. HunterWisp squashes the Wisp by it.
static func press(o: Hunter) -> float:
	var s := o.get_meta("stomped_by", null) as Hunter
	if s == null or not is_instance_valid(s) or s.stomp.is_empty():
		return 0.0
	var hold := 0.25 + 0.25 * float(s.stomp["t"]) / Stomp.TIME
	return hold + (1.0 - hold) * _slam(s)

## A slam's kick, 1 as the foot lands and easing off; 0 before the first one.
static func _slam(s: Hunter) -> float:
	var b := Stomp.beat(s)
	if b < Stomp.SLAM:
		return 0.0
	return exp(-fposmod(b - Stomp.SLAM, 1.0) * SLAM_DECAY)

func _process(delta: float) -> void:
	tick(delta)

func tick(dt: float) -> void:
	for slot in _slots:
		if slot["mode"] == "":
			continue
		var o := slot["o"] as Hunter
		if not is_instance_valid(o):
			_hide(slot)
			continue
		slot["t"] = float(slot["t"]) + dt
		match String(slot["mode"]):
			"pin": _pose_pin(slot, o)
			"close": _pose_end(slot, o, CLOSE_S, RING_TO * 0.1)
			"fade": _pose_end(slot, o, FADE_S, float(slot["r"]))
			"shatter": _pose_shatter(slot, o)

## Tightening from RING_FROM to RING_TO over the stomp, thicker and brighter as it goes, squeezing in
## on each slam.
func _pose_pin(slot: Dictionary, o: Hunter) -> void:
	var s := slot["s"] as Hunter
	if not is_instance_valid(s) or s.stomp.is_empty():
		slot["mode"] = "fade"      # a stomp ended without a word here: don't leave its ring behind
		slot["t"] = 0.0
		return
	var k := clampf(float(s.stomp["t"]) / Stomp.TIME, 0.0, 1.0)
	var slam := _slam(s)
	var r := lerpf(RING_FROM, RING_TO, smoothstep(0.0, 1.0, k)) * (1.0 - SLAM_SQUEEZE * slam)
	slot["r"] = r
	var ring := slot["ring"] as MeshInstance3D
	_place(ring, o, r)
	var mat := ring.material_override as ShaderMaterial
	mat.set_shader_parameter("thickness", lerpf(0.12, 0.3, k))
	mat.set_shader_parameter("wash", 0.3 + 0.5 * slam)
	mat.set_shader_parameter("color", Color(COLOR.lerp(Color.WHITE, 0.5 * slam), lerpf(0.6, 0.95, k)))

## Closing (to `to`) or staying put, fading out over `secs`.
func _pose_end(slot: Dictionary, o: Hunter, secs: float, to: float) -> void:
	var k := clampf(float(slot["t"]) / secs, 0.0, 1.0)
	var ring := slot["ring"] as MeshInstance3D
	_place(ring, o, lerpf(float(slot["r"]), to, k * k))
	var mat := ring.material_override as ShaderMaterial
	mat.set_shader_parameter("color", Color(COLOR, 0.95 * (1.0 - k)))
	if k >= 1.0:
		_hide(slot)

## The arcs fly out from where the ring was, turning a little, and fade.
func _pose_shatter(slot: Dictionary, o: Hunter) -> void:
	var k := clampf(float(slot["t"]) / SHATTER_S, 0.0, 1.0)
	var out := 1.0 - pow(1.0 - k, 3.0)
	var r := float(slot["r"]) * lerpf(1.0, SHATTER_GROW, out)
	for i in SHARDS:
		var sh := slot["shards"][i] as MeshInstance3D
		_place(sh, o, r)
		sh.rotation.y = TAU * i / SHARDS + 0.5 * out * (1.0 if i % 2 == 0 else -1.0)
		var mat := sh.material_override as ShaderMaterial
		mat.set_shader_parameter("thickness", 0.3)
		mat.set_shader_parameter("color", Color(COLOR.lerp(Color.WHITE, 0.4 * (1.0 - k)), 1.0 - k * k))
	if k >= 1.0:
		_hide(slot)

func _place(mi: MeshInstance3D, o: Hunter, radius: float) -> void:
	mi.position = o.position + Vector3(0, LIFT, 0)
	mi.scale = Vector3.ONE * maxf(radius, 0.01)
	mi.visible = o.visible

func _slot_for(o: Hunter) -> Dictionary:
	for slot in _slots:
		if slot["o"] == o and slot["mode"] != "":
			return slot
	return {}

func _hide(slot: Dictionary) -> void:
	slot["mode"] = ""
	slot["o"] = null
	slot["s"] = null
	(slot["ring"] as MeshInstance3D).visible = false
	for sh in slot["shards"]:
		(sh as MeshInstance3D).visible = false

## The slot showing the stomp on o ({} when none does): for the checks.
func ring_of(o: Hunter) -> Dictionary:
	return _slot_for(o)
