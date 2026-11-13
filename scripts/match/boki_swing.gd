class_name BokiSwing
extends RefCounted
## The short clips a Boki plays when it attacks or casts in a match: "lunge" and "cast" (wind-up, release, recover).
## Each species keeps its own keyed "attack" and "ability" (the Model Room and the shots play those); here they are
## retimed at load so the release (the frame of the strike or the burst, found as the peak of the motion) lands
## exactly WIND seconds in. Kin holds the bite or the skill for WIND, so the hit lands on the release frame.
## A Blender pass can key these natively per species later: same names, same WIND, and this stops applying.

const LUNGE_WIND := 0.12      # s from the start of the lunge to its release (the bite lands)
const LUNGE_LEN := 0.42       # s the whole lunge lasts
const CAST_WIND := 0.2        # s from the start of the cast to its release (the skill fires)
const CAST_LEN := 0.56        # s the whole cast lasts
const FROM := {"lunge": "attack", "cast": "ability"}
const WIND := {"lunge": LUNGE_WIND, "cast": CAST_WIND}
const LEN := {"lunge": LUNGE_LEN, "cast": CAST_LEN}
const EARLY := 0.15           # the release is searched between this and LATE (x the keyed clip's length):
const LATE := 0.6             # past that it is the follow-through, and the wind-up would be squeezed too hard
const SAMPLE_S := 0.02        # s between the samples the peak of the motion is looked for in
const MOVE_PER_M := 5.0       # rad of turning one metre of root travel counts as, finding the peak of the motion

## Adds "lunge" and "cast" to a rig's player once per library (the library is shared by every copy of the model).
static func add_clips(player: AnimationPlayer) -> void:
	var lib := player.get_animation_library(player.get_animation_library_list()[0])
	for id in FROM:
		if not lib.has_animation(id):
			var src := lib.get_animation(FROM[id])
			var clip := retimed(src, release_of(src), WIND[id], LEN[id])
			clip.loop_mode = Animation.LOOP_NONE
			lib.add_animation(id, clip)

## The time (s) of the peak of the motion in a keyed clip: the strike or the burst, sampled every SAMPLE_S and
## smoothed over three samples.
static func release_of(a: Animation) -> float:
	var n := int(a.length / SAMPLE_S)
	var speed := PackedFloat32Array()
	speed.resize(n + 1)
	for t in a.get_track_count():
		var type := a.track_get_type(t)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		for i in range(1, n + 1):
			if type == Animation.TYPE_ROTATION_3D:
				speed[i] += a.rotation_track_interpolate(t, (i - 1) * SAMPLE_S).angle_to(a.rotation_track_interpolate(t, i * SAMPLE_S))
			else:
				speed[i] += a.position_track_interpolate(t, (i - 1) * SAMPLE_S).distance_to(a.position_track_interpolate(t, i * SAMPLE_S)) * MOVE_PER_M
	var best := a.length * 0.5
	var best_v := -1.0
	for i in range(maxi(2, ceili(n * EARLY)), mini(n, int(n * LATE))):
		var v := speed[i - 1] + speed[i] + speed[i + 1]
		if v > best_v:
			best_v = v
			best = i * SAMPLE_S
	return best

## A copy of `a` with its keys moved so `release` lands at `wind` and the clip ends at `total` (all s).
static func retimed(a: Animation, release: float, wind: float, total: float) -> Animation:
	var out := a.duplicate() as Animation
	for t in out.get_track_count():
		for i in out.track_get_key_count(t):
			var at := out.track_get_key_time(t, i)
			if at <= release:
				at = at * wind / release
			else:
				at = wind + (at - release) * (total - wind) / (a.length - release)
			out.track_set_key_time(t, i, at)
	out.length = total
	return out
