class_name ZoneReveal
extends RefCounted
## The moment a woken zone's standing stone at the hub's Waystone lights (DECISIONS 2026-11-10): the stone
## warms from dark to the zone's colour, a soft glow rises off it, its lock look (moss and key marks,
## FarmModels.stone_lock) tips off and shrinks away, then its cap pops on. Once per zone per save:
## GardenZones.attune and wake leave {"reveal": true} on the zone's save entry and the first hub that
## shows the stone plays it and clears it (an older save has no flag, so nothing replays). Only tweens and
## two shared Fx calls (body_glow, ring) per stone: nothing per frame of its own.

const WAIT_S := 1.0        # s before it starts: the arrival's ink wipe clears (after waking, the burst goes first)
const LIGHT_S := 0.9       # s the stone takes to warm from dark to its zone's colour
const LOCK_AT_S := 0.25    # s into the light-up that the lock look starts to fall
const LOCK_FALL_S := 0.6   # s it takes to fall LOCK_DROP, tip over and shrink away
const LOCK_DROP := 0.45    # m it falls
const LOCK_TIP := 0.9      # rad it tips outward while falling
const CAP_S := 0.3         # s the cap takes to pop on once the stone is lit

## Is zone `id` woken but its stone not yet shown lighting?
static func owed(id: String) -> bool:
	return bool(Save.d.get("zones", {}).get(id, {}).get("reveal", false))

## Plays the reveal on each stone of the hub's Waystone `stone` (built in GardenZones.ids() order) that is owed one.
static func play_owed(h, stone: Node3D) -> void:
	var ids := GardenZones.ids()
	for i in ids.size():
		if owed(ids[i]):
			Save.d["zones"][ids[i]].erase("reveal")
			_play(h, stone, i, String(GardenZones.info(ids[i])["colour"]))

static func _play(h, stone: Node3D, i: int, colour: String) -> void:
	var col := Color(colour)
	var body: MeshInstance3D = stone.get_node("Stone%d" % i)
	var mat: ShaderMaterial = body.material_override
	var cap: Node3D = stone.get_node("Cap%d" % i)
	var lock := FarmModels.stone_lock(colour, {"seed": true, "lean": true})
	lock.name = "Lock%d" % i
	lock.position = Vector3(body.position.x, 0, body.position.z)
	lock.rotation.y = body.rotation.y
	stone.add_child(lock)
	_light(mat, col, 0.0)
	cap.scale = Vector3.ZERO
	var foot: Vector3 = stone.position + lock.position
	var tw := stone.create_tween()
	tw.tween_interval(WAIT_S)
	tw.tween_callback(func():
		h.fx.body_glow(foot, col)
		h.fx.ring(foot, 0.9, col, LIGHT_S))
	tw.tween_method(func(k: float): _light(mat, col, k), 0.0, 1.0, LIGHT_S).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lock, "position:y", -LOCK_DROP, LOCK_FALL_S).set_delay(LOCK_AT_S) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(lock, "rotation:x", LOCK_TIP, LOCK_FALL_S).set_delay(LOCK_AT_S)
	tw.parallel().tween_property(lock, "scale", Vector3.ZERO, LOCK_FALL_S).set_delay(LOCK_AT_S)
	tw.tween_callback(lock.queue_free)
	tw.tween_property(cap, "scale", Vector3.ONE, CAP_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The stone `k` of the way from dark (0) to lit in its zone's colour (1).
static func _light(mat: ShaderMaterial, col: Color, k: float) -> void:
	mat.set_shader_parameter("albedo", Color(FarmModels.STONE_DARK).lerp(col, k))
	mat.set_shader_parameter("glow", FarmModels.STONE_GLOW * k)
