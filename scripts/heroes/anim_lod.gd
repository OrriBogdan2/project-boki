class_name AnimLod
## Animation level of detail for expedition frame rate: a Hero's rig off screen or far from the camera
## updates its bones every few frames, catching up on the time it skipped (Boki and monsters do the same in
## Match._process). Numbers: content/rules/tuning.json "perf"; off on Ultra (Settings.QUALITY "anim_lod").

static var _cfg := {}

## How many frames apart a rig at `at` updates: 1 on screen and near the camera.
static func every(at: Vector3, vp: Viewport) -> int:
	var cam := vp.get_camera_3d()
	if cam == null or not Settings.q("anim_lod"):
		return 1
	if _cfg.is_empty():
		_cfg = Content.rules("tuning")["perf"]
	if not cam.is_position_in_frustum(at):
		return int(_cfg["hero_anim_off_every"])
	if cam.global_position.distance_squared_to(at) > pow(float(_cfg["hero_anim_near_m"]), 2.0):
		return int(_cfg["hero_anim_far_every"])
	return 1
