class_name BokiClipCover
extends RefCounted
## Whether a baked clip is worth playing (the coverage test of docs/ANIM_COVERAGE.md): a clip that holds one pose,
## or never leaves the poses idle passes through, is not. BokiHomeClips plays a species' own eat and sleep clips when
## they pass; --anim-coverage-check reads the same numbers.

const STILL_DEG := 2.0  # no bone turns more than this over the clip: it holds one pose
const NEAR_IDLE_DEG := 3.0  # every pose within this of a pose idle passes through: it shows idle
const SAMPLES := 16


## Does `clip` move and leave the idle pose? A sleep clip that holds one pose fails too: the built nap breathes,
## and every clip a Boki plays must move (--boki-anim-audit).
static func passes(clip: Animation, idle: Animation) -> bool:
	if clip == null:
		return false
	var smp := sample(clip)
	return motion(smp) >= STILL_DEG and off_idle(smp, sample(idle)) > NEAR_IDLE_DEG


## bone -> [Quaternion at SAMPLES even steps over the clip], rotation tracks only.
static func sample(a: Animation) -> Dictionary:
	var out := {}
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D or a.track_get_key_count(i) == 0:
			continue
		var qs: Array = []
		for n in SAMPLES:
			qs.append(a.rotation_track_interpolate(i, a.length * n / float(SAMPLES)).normalized())
		out[String(a.track_get_path(i).get_concatenated_subnames())] = qs
	return out


## The largest turn (deg) of any bone away from its first key.
static func motion(smp: Dictionary) -> float:
	var top := 0.0
	for b in smp:
		for q in smp[b]:
			top = maxf(top, rad_to_deg((q as Quaternion).angle_to(smp[b][0])))
	return top


## How far (deg) the clip gets from the idle loop: over its poses, the largest distance to the nearest idle pose
## (a pose's distance: its bone furthest from that idle pose's).
static func off_idle(smp: Dictionary, idle: Dictionary) -> float:
	var top := 0.0
	for n in SAMPLES:
		var near := INF
		for u in SAMPLES:
			var far := 0.0
			for b in smp:
				if idle.has(b):
					far = maxf(far, rad_to_deg((smp[b][n] as Quaternion).angle_to(idle[b][u])))
			near = minf(near, far)
		top = maxf(top, near)
	return top
