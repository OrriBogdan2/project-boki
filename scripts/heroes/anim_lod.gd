class_name AnimLod
## Animation level of detail for expedition frame rate, for Hero rigs (WardenGlb.Sync) and Boki rigs (BokiRig).
## A rig off screen (its VisibleOnScreenNotifier3D) or far from the camera updates its bones every few frames,
## catching up on the time it skipped; off screen or far it also casts no shadow, and a Boki drops its ink
## outline. Numbers: content/rules/tuning.json "perf"; all of it off on Ultra (Settings.QUALITY "anim_lod").

## m: a Hunter or a Boki, with room for the shadow it throws (what the notifier tests against the view)
const BOUNDS := AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3.0, 4.0, 3.0))
const FAR_HYST_M := 2.0           # m: a far rig comes back near this much inside the line (no flicker on it)

static var _cfg := {}
## (headless has no renderer, so no notifier ever reports on screen: the view test stands in, and CPU benches see
## the same rigs near as a window would)
static var _blind := DisplayServer.get_name() == "headless"

static func _perf() -> Dictionary:
	if _cfg.is_empty():
		_cfg = Content.rules("tuning")["perf"]
	return _cfg

## m from the camera past which a rig is far, for the quality preset (Ultra, not listed: never).
static func far_m() -> float:
	return float((_perf()["actor_far_m"] as Dictionary).get(Settings.quality(), INF))

## How many frames apart a rig at `at` updates: 1 on screen and near the camera. `seen` is the rig's notifier;
## without one the point is tested against the view.
static func every(at: Vector3, vp: Viewport, seen: VisibleOnScreenNotifier3D = null) -> int:
	var cam := vp.get_camera_3d()
	if cam == null or not Settings.q("anim_lod"):
		return 1
	if not (seen.is_on_screen() if seen and not _blind else cam.is_position_in_frustum(at)):
		return int(_perf()["anim_off_every"])
	if cam.global_position.distance_squared_to(at) > pow(far_m(), 2.0):
		return int(_perf()["anim_far_every"])
	return 1

## One rig's level of detail: its frame count, the time it skipped, its notifier and its shadow casters.
class Gate extends RefCounted:
	var n := randi() % 12       # (staggered: rigs on the same rate don't all update on one frame)
	var skipped := 0.0
	var seen: VisibleOnScreenNotifier3D
	var casters: Array = []      # [MeshInstance3D, its own cast_shadow]
	var near := true            # on screen and inside far_m: shadows and the full look

	func _init(under: Node3D) -> void:
		for mi in under.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				casters.append([mi, (mi as MeshInstance3D).cast_shadow])
		seen = VisibleOnScreenNotifier3D.new()
		seen.name = "LodSeen"
		seen.aabb = BOUNDS
		under.add_child(seen)

	## The time to animate by this frame (with what it skipped), or 0.0 on a frame it skips.
	func step(at: Vector3, vp: Viewport, dt: float) -> float:
		_near_now(at, vp)
		n += 1
		if n % AnimLod.every(at, vp, seen) != 0:
			skipped += dt
			return 0.0
		var out := dt + skipped
		skipped = 0.0
		return out

	func _near_now(at: Vector3, vp: Viewport) -> void:
		var cam := vp.get_camera_3d()
		var now := true
		if cam and Settings.q("anim_lod"):
			var line := maxf(0.0, AnimLod.far_m() - (FAR_HYST_M if not near else 0.0))
			var shown := cam.is_position_in_frustum(at) if AnimLod._blind else seen.is_on_screen()
			now = shown and cam.global_position.distance_squared_to(at) < line * line
		if now == near:
			return
		near = now
		for c in casters:
			if is_instance_valid(c[0]):        # (a re-equip frees the old weapon's meshes)
				(c[0] as MeshInstance3D).cast_shadow = c[1] if now else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
