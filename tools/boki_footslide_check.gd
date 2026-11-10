extends RefCounted
## --boki-footslide-check: a rigged Boki's walk and run keep their feet still on the ground it covers.
## Each species is moved at SPEEDS (m/s) through the live rig, unscaled and at the size roll's ends; for the clip
## and speed_scale it picks, each foot's slide while it is down is measured off the clip and compared with the
## ground the body covers in the same loop (the stride). BokiRig.STRIDE must also match what the clips measure.
## Prints PASS/FAIL lines.

const Shots := preload("res://tools/boki_rig_shots.gd")
const Check := preload("res://tools/boki_rig_check.gd")
const SPEEDS := [1.0, 3.0]
const SIZES := [1.0, 0.8, 1.25]       # the Boki's world scale: a size roll scales its stride too
const SLIP_MAX := 0.15        # of a stride: how far a foot may slide on the ground per loop
const STRIDE_TOL := 0.05      # BokiRig.STRIDE vs the measured clip, as a fraction
const FEETLESS := 0.1         # m/s: a foot that sweeps less than this is not stepping (it floats, glides or is tucked)
const GLIDE_STRIDE := [1.5, 2.9]      # what such a Boki keeps: BokiRig.STRIDE before it was measured
## Ratchet: gaits whose clip slides more than SLIP_MAX at any rate BokiRig picks (an uneven stance, or too short a
## step even at BokiRig.MAX_CADENCE), with the most they may slide. Lower or drop a row when a clip is re-keyed.
const OVER := {
	"cindle run": 0.16, "rimeshrew run": 0.17, "wisplet walk": 0.17, "wisplet run": 0.16, "zapple walk": 0.24,
	"zapple run": 0.28, "kestrike run": 0.18, "kindlewren run": 0.18, "lodestick walk": 0.25, "lodestick run": 0.31,
	"mossgrade walk": 0.22,
}
const SAMPLES := 48           # poses per loop
const PLANTED := 0.5          # a foot in the lowest this fraction of its lift, moving back, is on the ground
## Bones that are not limbs when a Boki has no paws and its lowest limb stands in for a foot.
const NOT_LIMB := ["root", "hips", "spine", "neck", "head"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOKIFOOT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for id in Check.SPECIES_LIST:
		await _species(main, id)
	print("BOKIFOOT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _species(main: Node, id: String) -> void:
	var k := Shots.rigged_kin(id)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.manual = true
	var steps := {}
	var measured: Array = []
	for clip in ["walk", "run"]:
		steps[clip] = contact_steps(rig, clip)
		measured.append(stride(steps[clip], rig.player.get_animation(clip).length))
	print("BOKIFOOT %s measured walk %.2f run %.2f m/s" % [id, measured[0], measured[1]])
	if measured.min() < FEETLESS:
		ok(BokiRig.STRIDE[id] == GLIDE_STRIDE, "%s has no stepping feet, so it keeps the shared stride" % id)
		k.queue_free()
		return
	for i in 2:
		var near: bool = absf(measured[i] - BokiRig.STRIDE[id][i]) <= STRIDE_TOL * measured[i]
		ok(near, "%s %s stride %.2f matches its clip" % [id, ["walk", "run"][i], BokiRig.STRIDE[id][i]])
	for grown in SIZES:
		k.scale = Vector3.ONE * grown
		rig._keep_flex()
		for v in SPEEDS:
			_gait(rig, steps, id, grown, v)
	k.queue_free()

## One species at one size and speed: the clip and rate the rig picks, and how far its feet slide at them.
func _gait(rig: BokiRig, steps: Dictionary, id: String, grown: float, v: float) -> void:
	rig._speed = v
	rig._pick_clip(0.016)
	var length := rig.player.get_animation(rig.clip).length
	var sc := rig.player.speed_scale
	var slid := slip(steps[rig.clip], length, v / grown, sc)
	var limit: float = OVER.get("%s %s" % [id, rig.clip], SLIP_MAX)
	var why := " (at full cadence)" if is_equal_approx(sc, BokiRig.MAX_CADENCE * length) else ""
	var what := "%s x%.2f at %.0f m/s (%s x%.2f)" % [id, grown, v, rig.clip, sc]
	ok(slid < limit, "%s slides %.0f%% of a stride%s, under %.0f%%" % [what, slid * 100.0, why, limit * 100.0])

## Per foot, the back-along-the-body step (m, models face -Z) of each of SAMPLES even slices of `clip` at speed 1
## while the foot is down (both ends in the lowest PLANTED of its lift, moving back), NAN while it is up or swinging
## forward. The clips are swung from the hips, so a paw also passes low on its way forward.
static func contact_steps(rig: BokiRig, clip: String) -> Array:
	rig.set_clip(clip, 0.0)
	var anim := rig.player.get_animation(clip)
	var skel := rig.skeleton()
	var feet := _feet(skel)
	var paths: Array = []
	for f in feet:
		paths.append([])
	for i in SAMPLES:
		rig.player.seek(anim.length * i / SAMPLES, true)
		rig.player.advance(0.0)
		for f in feet.size():
			var at := skel.get_bone_global_pose(feet[f]).origin
			paths[f].append(rig.model.to_local(skel.to_global(at)))
	var steps: Array = []
	for path in paths:
		steps.append(_steps(path))
	return steps

static func _steps(path: Array) -> Array:
	var lo := INF
	var hi := -INF
	for p: Vector3 in path:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var limit := lo + PLANTED * (hi - lo) + 0.0005
	var out: Array = []
	for i in path.size():
		var a: Vector3 = path[i]
		var b: Vector3 = path[(i + 1) % path.size()]
		out.append(b.z - a.z if a.y <= limit and b.y <= limit and b.z > a.z else NAN)
	return out

## m/s a foot on the ground moves back at speed 1, over every foot's contact (BokiRig.STRIDE).
static func stride(steps: Array, length: float) -> float:
	var sum := 0.0
	var n := 0
	for foot: Array in steps:
		for dz: float in foot:
			if not is_nan(dz):
				sum += dz
				n += 1
	return sum / maxf(n, 1) / (length / SAMPLES)

## The most any foot slides on the ground per loop, as a fraction of the ground covered per loop, when the body
## moves at `v` m/s and the clip plays at `rate`. A foot down for half the loop at half the body's speed slides 25%.
static func slip(steps: Array, length: float, v: float, rate: float) -> float:
	var h := length / SAMPLES
	var worst := 0.0
	for foot: Array in steps:
		var slid := 0.0
		for dz: float in foot:
			if not is_nan(dz):
				slid += absf(h - dz * rate / v)
		worst = maxf(worst, slid / length)
	return worst

## The paws, or the lowest limb bones of a Boki without any.
static func _feet(skel: Skeleton3D) -> Array:
	var paws: Array = []
	var limbs: Array = []
	for b in skel.get_bone_count():
		var nm := skel.get_bone_name(b)
		if nm.contains("paw"):
			paws.append(b)
		elif not (nm in NOT_LIMB or nm.begins_with("prop_") or nm.begins_with("part_")):
			limbs.append(b)
	if not paws.is_empty():
		return paws
	limbs.sort_custom(func(a: int, b: int) -> bool:
		return skel.get_bone_global_rest(a).origin.y < skel.get_bone_global_rest(b).origin.y)
	return limbs.slice(0, 2)
