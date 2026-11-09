class_name BokiIdle
extends RefCounted
## A rigged Boki standing still: its own breathing loop and, every few seconds, one short fidget picked from who it
## is (content/rules/boki_idle.json). Both are made at runtime from the species' own idle clip, so no re-export:
## "idle" is re-timed and deepened where the species shared the generic breath, and "idle_fidget" is that same
## clip with a few bones moved over a window in the middle. The fidget starts and ends on the idle's own pose, and
## the clips loop on their first key, so every crossfade between them holds at any blend weight.
## BokiRig plays it only while it would stand idle: any action takes over at once.

const PATH := "res://content/rules/boki_idle.json"
const FIDGET := "idle_fidget"
const KEY_STEP := 1.0 / 30.0          # s between the keys a fidget writes
## The bones a breath deepens: the torso, not the head (which already sways) or the limbs.
const TORSO := ["root", "hips", "spine", "neck"]
const TICKS := ["ear", "nip"]          # bone prefixes a calm idle stops flicking every loop
const TICK_KEEP := 0.2                 # share of a flick that stays (the ear still rides the breath)
const CHAIN_LAG := 0.07                # cycles each next bone of a swinging chain trails the one before
const AXES := {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}

static var _cfg := {}

var _gap := 0.0

static func config() -> Dictionary:
	if _cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = parsed if parsed is Dictionary else {}
	return _cfg

## Gives the player this species' breathing "idle" and its "idle_fidget" (once per model: the clips are shared).
static func build(player: AnimationPlayer, skel: Skeleton3D, species: String) -> void:
	var lib := player.get_animation_library(&"")
	var spec: Dictionary = (config()["species"] as Dictionary).get(species, {})
	if spec.is_empty() or lib.has_animation(FIDGET):
		return
	var idle := lib.get_animation("idle").duplicate() as Animation
	if spec.has("breath"):
		_breathe(idle, spec["breath"])
	lib.remove_animation("idle")
	lib.add_animation("idle", idle)
	lib.add_animation(FIDGET, _fidget(idle, spec["fidget"], skel))

## Re-times the loop to `len` s and deepens the torso; `calm` takes the tick out of the ears.
static func _breathe(idle: Animation, breath: Dictionary) -> void:
	var stretch := float(breath["len"]) / idle.length
	var amp := float(breath["amp"])
	for t in idle.get_track_count():
		var bone := String(idle.track_get_path(t)).get_slice(":", 1)
		var gain := amp if bone in TORSO else 1.0
		if breath.get("calm", false) and _is_tick(bone):
			gain = TICK_KEEP
		var times := []
		var values := []
		for k in idle.track_get_key_count(t):
			times.append(idle.track_get_key_time(t, k) * stretch)
			values.append(idle.track_get_key_value(t, k))
		for k in range(times.size() - 1, -1, -1):
			idle.track_remove_key(t, k)
		for k in times.size():
			_insert(idle, t, float(times[k]), _scaled(values[0], values[k], gain) if gain != 1.0 else values[k])
	idle.length = float(breath["len"])

static func _insert(anim: Animation, track: int, at: float, v: Variant) -> void:
	match anim.track_get_type(track):
		Animation.TYPE_ROTATION_3D: anim.rotation_track_insert_key(track, at, v)
		Animation.TYPE_POSITION_3D: anim.position_track_insert_key(track, at, v)
		Animation.TYPE_SCALE_3D: anim.scale_track_insert_key(track, at, v)
		_: anim.track_insert_key(track, at, v)

static func _is_tick(bone: String) -> bool:
	for p in TICKS:
		if bone.begins_with(p):
			return true
	return false

static func _scaled(first: Variant, v: Variant, gain: float) -> Variant:
	if v is Quaternion:
		return (first as Quaternion).slerp(v as Quaternion, gain)
	if v is Vector3:
		return (first as Vector3).lerp(v as Vector3, gain)
	return v

## The idle again with the fidget's rows added over its window; it ends where the idle ends.
static func _fidget(idle: Animation, spec: Dictionary, skel: Skeleton3D) -> Animation:
	var fid := idle.duplicate() as Animation
	fid.loop_mode = Animation.LOOP_NONE
	_tile(fid, ceili((float(spec["at"]) + float(spec["dur"]) + 0.05) / idle.length))
	var base := _skeleton_path(idle)
	var samples := {}                        # track -> its local rotation every KEY_STEP
	for row in spec["rows"]:
		for hit in _bones(skel, String(row[0])):
			var bone := String(hit[0])
			var path := NodePath("%s:%s" % [base, bone])
			var track := fid.find_track(path, Animation.TYPE_ROTATION_3D)
			if track < 0:
				track = fid.add_track(Animation.TYPE_ROTATION_3D)
				fid.track_set_path(track, path)
			var at := skel.find_bone(bone)
			if not samples.has(track):
				samples[track] = _sample(fid, track, skel.get_bone_rest(at).basis.get_rotation_quaternion())
			var frame := skel.get_bone_global_rest(at).basis.get_rotation_quaternion()
			_add_row(samples[track] as Array, row, hit, spec, frame)
	for track in samples:
		_write(fid, track, samples[track])
	return fid

## Repeats the clip `n` times over (so it ends on its first pose again, however short the idle).
static func _tile(anim: Animation, n: int) -> void:
	var one := anim.length
	for t in anim.get_track_count():
		var count := anim.track_get_key_count(t)
		var times := []
		var values := []
		for k in count:
			times.append(anim.track_get_key_time(t, k))
			values.append(anim.track_get_key_value(t, k))
		for rep in range(1, n):
			for k in range(1, count):
				_insert(anim, t, float(times[k]) + rep * one, values[k])
	anim.length = one * n

static func _skeleton_path(anim: Animation) -> String:
	return String(anim.track_get_path(0)).get_slice(":", 0)

## [bone, lag (cycles), share of the row's swing, side sign] for every bone a row names: "tail*" swings as a chain,
## "name*" is a cluster, "name.*" is both sides.
static func _bones(skel: Skeleton3D, pattern: String) -> Array:
	var names := []
	if pattern.ends_with("*"):
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).begins_with(pattern.trim_suffix("*")):
				names.append(skel.get_bone_name(i))
	else:
		names.append(pattern)
	var chain := pattern.begins_with("tail") and pattern.ends_with("*")
	var found := []
	var trails := chain or (pattern.ends_with("*") and not pattern.ends_with(".*"))
	var share := 1.0 / names.size() if chain else 1.0
	for i in names.size():
		var side := -1.0 if String(names[i]).ends_with(".R") else 1.0
		found.append([names[i], CHAIN_LAG * i if trails else 0.0, share, side])
	return found

## A rotation track's local value every KEY_STEP (`rest` where the clip has none).
static func _sample(anim: Animation, track: int, rest: Quaternion) -> Array:
	var out := []
	for s in ceili(anim.length / KEY_STEP) + 1:
		var at := minf(s * KEY_STEP, anim.length)
		out.append(anim.rotation_track_interpolate(track, at) if anim.track_get_key_count(track) > 0 else rest)
	return out

## Rotates the samples inside the fidget's window about the row's game axis, set in the bone's rest frame
## (`frame`) like the clips' own keys. y and z swing mirrored on the right side.
static func _add_row(samples: Array, row: Array, hit: Array, spec: Dictionary, frame: Quaternion) -> void:
	var axis_name := String(row[1])
	var peak := float(row[2]) * float(hit[2]) * (float(hit[3]) if axis_name != "x" else 1.0)
	var cycles := float(row[3])
	var phase := float(row[4]) + float(hit[1])
	for s in samples.size():
		var u := (s * KEY_STEP - float(spec["at"])) / float(spec["dur"])
		if u <= 0.0 or u >= 1.0:
			continue
		var hump := sin(PI * u)
		var angle := peak * hump * (hump if cycles == 0.0 else sin(TAU * (cycles * u + phase)))
		samples[s] = (samples[s] as Quaternion) * (frame.inverse() * Quaternion(AXES[axis_name], angle) * frame)

static func _write(anim: Animation, track: int, samples: Array) -> void:
	for k in range(anim.track_get_key_count(track) - 1, -1, -1):
		anim.track_remove_key(track, k)
	for s in samples.size():
		anim.rotation_track_insert_key(track, minf(s * KEY_STEP, anim.length), samples[s])

## Called every frame the Boki would stand idle: "idle", or FIDGET when one is due. `clip` is the one now playing.
func step(dt: float, player: AnimationPlayer, clip: String, rng: RandomNumberGenerator) -> String:
	_gap -= dt
	if clip == FIDGET:
		return FIDGET if player.is_playing() else "idle"
	if _gap > 0.0 or not player.has_animation(FIDGET):
		return "idle"
	var gap: Array = config()["gap_s"]
	_gap = rng.randf_range(float(gap[0]), float(gap[1]))
	return FIDGET

## Called when it isn't idle: the next fidget is a fresh few seconds off.
func rest(rng: RandomNumberGenerator) -> void:
	var gap: Array = config()["gap_s"]
	_gap = rng.randf_range(float(gap[0]), float(gap[1]))
