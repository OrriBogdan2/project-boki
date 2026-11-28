class_name BokiSteps
extends RefCounted
## Footsteps of the garden's walking Boki (docs/AUDIO.md): a soft paw on turf in one of three sets by body mass
## (boki_step_small, _medium, _large). A rigged Boki steps on the frames its walk or run clip plants a paw (the
## times BokiPlant reads off the clip); any other walker (a clip with no plants, a primitive body) steps on a cadence
## from its ground speed. Only the MAX_HEARD nearest walkers within their set's reach (content/sfx/steps.json) are
## stepped at all, so a garden of thirty is a few near paws, never a pattering crowd. Played through GardenSfx.cue.

const SOUND := "boki_step_"
const MASS_MEDIUM_KG := 4.0  # kg: from here a Boki steps in the medium set (a third of the species are lighter)
const MASS_LARGE_KG := 25.0  # kg: from here, the large set
const DB := -14.0  # dB: a paw sits under the Boki's voices (home_work.gd plays them at -8)
const MAX_HEARD := 4  # walkers stepping at once, the nearest to you
const CADENCE_M := {"small": 0.2, "medium": 0.32, "large": 0.5}  # m of ground per step when no clip plants
const MIN_STEP_S := 0.16  # s: paws landing closer than this sound as one step (a four-paw walk is not a drum roll)
const PITCH_JITTER := 0.1  # each step's pitch varies this much either way, on top of Sfx's own

var _clip := {}  # uid -> the gait clip heard last frame (plants)
var _at := {}  # uid -> s into it then (plants)
var _phase := {}  # uid -> share of a step walked since the last one (cadence)
var _hold := {}  # uid -> s left before its next step may sound
var _legs := {}  # "species clip" -> [Vector2(s the paw lands, s per step)] for each paw


## Called each farm frame (home.gd _move_kin) with all the Boki out on the farm.
func step(kins: Array, d: float) -> void:
	var at := Sfx.listener
	var near := []
	for k in kins:
		if _walking(k) and _flat(k["pos"], at) < reach(size_of(k["rec"])):
			near.append(k)
		else:
			_forget(String(k["rec"]["uid"]))
	near.sort_custom(func(a, b): return _flat(a["pos"], at) < _flat(b["pos"], at))
	for uid in _hold:
		_hold[uid] = maxf(0.0, float(_hold[uid]) - d)
	for i in near.size():
		var k: Dictionary = near[i]
		if i >= MAX_HEARD:
			_forget(String(k["rec"]["uid"]))
		elif _lands(k, d) and _free(String(k["rec"]["uid"])):
			var size := size_of(k["rec"])
			GardenSfx.cue(SOUND + size, k["pos"], 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER), DB)


## The set a Boki steps in, by body mass.
static func size_of(rec: Dictionary) -> String:
	var kg := float(Unique.size_info(rec)["kg"])
	if kg >= MASS_LARGE_KG:
		return "large"
	return "medium" if kg >= MASS_MEDIUM_KG else "small"


## Metres a set's paws carry (content/sfx/steps.json).
static func reach(size: String) -> float:
	return float(Sfx.sound_reach.get(SOUND + size, Sfx.hear_range))


static func _walking(k: Dictionary) -> bool:
	if k.get("busy", false) or k.has("indoors") or k.has("leap") or float(k.get("nap_t", 0.0)) > 0.0:
		return false
	var node := k.get("node") as Node3D
	if node == null or node.get_meta("aloft", false):
		return false
	return Vector2(k["vel"].x, k["vel"].z).length() >= BokiRig.WALK_SPEED


## Did a paw land this frame?
func _lands(k: Dictionary, d: float) -> bool:
	var uid := String(k["rec"]["uid"])
	var rig := (k["node"] as Node3D).get_node_or_null("Body/Flex/BokiRig") as BokiRig
	if rig != null and rig.clip in BokiRig.PLANT_GAITS:
		_phase.erase(uid)
		return _planted(uid, rig)
	_clip.erase(uid)
	_at.erase(uid)
	var speed := Vector2(k["vel"].x, k["vel"].z).length()
	var walked := float(_phase.get(uid, 0.0)) + speed * d / float(CADENCE_M[size_of(k["rec"])])
	_phase[uid] = fmod(walked, 1.0)
	return walked >= 1.0


## A paw of the playing gait passed its landing since the last look. A new clip starts over (no step on its first look).
func _planted(uid: String, rig: BokiRig) -> bool:
	var t := rig.player.current_animation_position
	var from := float(_at.get(uid, t))
	var same: bool = _clip.get(uid, "") == rig.clip
	_clip[uid] = rig.clip
	_at[uid] = t
	if not same:
		return false
	var window := fposmod(t - from, rig.player.current_animation_length)
	for leg: Vector2 in _paws(rig):
		if fposmod(t - leg.x, leg.y) < window:
			return true
	return false


func _paws(rig: BokiRig) -> Array:
	var key := "%s %s" % [rig.species, rig.clip]
	if not _legs.has(key):
		var paws := []
		for leg in BokiPlant.of(rig.species, rig.model, rig.skeleton(), rig.clip).legs:
			if leg.period > 0.0:
				paws.append(Vector2(leg.front, leg.period))
		_legs[key] = paws
	return _legs[key]


## True (and quiet again for MIN_STEP_S) when a Boki's last step has died away.
func _free(uid: String) -> bool:
	if float(_hold.get(uid, 0.0)) > 0.0:
		return false
	_hold[uid] = MIN_STEP_S
	return true


func _forget(uid: String) -> void:
	_hold.erase(uid)
	_clip.erase(uid)
	_at.erase(uid)
	_phase.erase(uid)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
