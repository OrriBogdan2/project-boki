class_name BokiSteps
extends RefCounted
## The footsteps of a walking or running Boki (one per BokiRig): a sound each time a planted foot comes down in the
## playing clip, at the pace the rig plays it (BokiRig.STRIDE and its cadence), so the sound follows the legs. The
## sound is a size family (by weight, so a size roll can change it) on the ground underfoot (Juice.ground_surface):
## boki_step_<family>_<surface>, made by tools/gen_sfx_boki.py. Quiet and positional, and only the MAX_VOICES
## nearest Boki sound at once. A species with no entry in TOUCH (wisps, flyers, serpents, blobs) makes none.
## --boki-steps-check re-measures TOUCH from the clips.

const SAMPLES := 48
## Per species and clip, the poses (of SAMPLES even slices of the loop) where a foot comes down; feet that land
## together are one sound. Measured by --boki-steps-check.
const TOUCH := {
	"cindle": {"walk": [1, 14, 24, 37], "run": [0, 6, 16]},
	"puddlet": {"walk": [1, 17, 25, 40], "run": [7, 17]},
	"burrlet": {"walk": [3, 13, 26, 35], "run": [9, 16]},
	"glintmole": {"walk": [2, 17, 26, 40], "run": [8, 17]},
	"rimeshrew": {"walk": [4, 13, 26, 35], "run": [9, 17]},
	"pebbit": {"walk": [3, 13, 26, 35], "run": [9, 16]},
	"cairnback": {"walk": [4, 12, 27, 36], "run": [5, 12, 28, 36]},
	"zapple": {"walk": [1, 15, 20, 38, 42], "run": [1, 30, 39]},
	"hivara": {"walk": [0, 13, 26, 35], "run": [0, 5, 14, 27, 35]},
	"kestrike": {"walk": [1, 21, 44], "run": [0]},
	"kindlewren": {"walk": [2, 20, 43], "run": [3, 21, 44]},
	"lodestick": {"walk": [1, 15, 23, 35], "run": [2, 15, 19, 35]},
	"marchleaf": {"walk": [2, 18, 41], "run": [4, 11, 19, 40]},
	"mossgrade": {"walk": [1, 12, 16, 25, 35, 39], "run": [2, 8, 15, 19, 23, 30, 34, 42, 46]},
	"nettlynx": {"walk": [1, 5, 13, 28, 35], "run": [0, 11, 16]},
	"caecilith": {"walk": [1, 12, 36], "run": [2, 14, 36]},
}
## Weight (kg, base weight times the size roll cubed) below which a Boki steps as that family; heavier is "heavy".
const FAMILY_KG := [["tiny", 2.2], ["small", 8.0], ["medium", 35.0]]
const MAX_VOICES := 4         # Boki that may step at once: the nearest to the listener
const HEAR_M := 14.0          # m: further than this a step is not played at all
const MIN_GAP_S := 0.1        # s between one Boki's steps: legs can beat faster (22/s), which would rattle
const LIVE_S := 0.8           # s a Boki still counts as stepping after its last step
const VOL_DB := -20.0         # quieter than a Hunter's step (-17), many of them walk at once
const PITCH_VAR := 0.1

## Boki that stepped lately: rig id -> [flat distance to the listener (m), time (ms)].
static var _live := {}

var _ground: World            # the ground it walks on, found at the first step
var _since := 0.0             # s since this Boki last played a step
var _phase := -1.0            # where in the clip the last frame was (0..1); -1 when not on a stepping clip

## The poses where a foot comes down in `clip`, as the loop's 0..1 phases; empty when the Boki makes no steps.
static func touches(species: String, clip: String) -> Array:
	var poses: Array = (TOUCH.get(species, {}) as Dictionary).get(clip, [])
	return poses.map(func(i: int) -> float: return float(i) / SAMPLES)

## "tiny", "small", "medium" or "heavy" for a Boki of this species grown by `size_k` (the size roll).
static func family(species: String, size_k: float) -> String:
	var kg := float(Unique.base_size(species)["kg"]) * pow(size_k, 3.0)
	for f: Array in FAMILY_KG:
		if kg < float(f[1]):
			return f[0]
	return "heavy"

## Whether the Boki `id`, `dist` m from the listener, is among the nearest MAX_VOICES that stepped lately.
static func audible(id: int, dist: float) -> bool:
	var now := Time.get_ticks_msec()
	_live[id] = [dist, now]
	var nearer := 0
	for other: int in _live.keys():
		var e: Array = _live[other]
		if now - int(e[1]) > LIVE_S * 1000.0:
			_live.erase(other)
		elif other != id and float(e[0]) < dist:
			nearer += 1
	return nearer < MAX_VOICES

## Call every frame after the clip has been advanced: plays a step for each foot that came down since the last call
## (at most one per MIN_GAP_S) and tells the rig (BokiRig.stepped).
func update(rig: BokiRig, dt: float) -> void:
	_since += dt
	var poses := touches(rig.species, rig.clip)
	if poses.is_empty() or rig.player.current_animation != rig.clip:
		_phase = -1.0
		return
	var at := fposmod(rig.player.current_animation_position / rig.player.get_animation(rig.clip).length, 1.0)
	var before := _phase
	_phase = at
	if before < 0.0:
		return
	for t: float in poses:
		if _crossed(before, at, t):
			_play(rig)

## Whether phase `t` lies in (before, at], the loop wrapping from 1 back to 0.
static func _crossed(before: float, at: float, t: float) -> bool:
	if at >= before:
		return before < t and t <= at
	return t > before or t <= at

func _play(rig: BokiRig) -> void:
	if _since < MIN_GAP_S:
		return
	var pos := rig.root.global_position
	var dist := Vector2(pos.x - Sfx.listener.x, pos.z - Sfx.listener.z).length()
	if dist > HEAR_M or not audible(rig.get_instance_id(), dist):
		return
	var sname := "boki_step_%s_%s" % [family(rig.species, float(rig.root.get_meta("evo_scale", 1.0))),
		Juice.ground_surface(_world(rig.root), pos)]
	_since = 0.0
	Sfx.play(sname, pos, VOL_DB, PITCH_VAR)
	rig.stepped.emit(sname)

## The ground this Boki walks on (the World beside it in the farm or the match), or null (a tool's lone Boki).
func _world(from: Node) -> World:
	if is_instance_valid(_ground):
		return _ground
	var n := from.get_parent()
	while n != null and _ground == null:
		for c in n.get_children():
			if c is World:
				_ground = c
		n = n.get_parent()
	return _ground
