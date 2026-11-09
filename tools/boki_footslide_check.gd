extends RefCounted
## --boki-footslide-check: a rigged Boki's walk and run keep their planted foot under the ground it covers.
## Each species is moved at SPEEDS (m/s) through the live rig; the foot speed is measured off the clip it picks
## (planted paw, back along the body, at speed_scale 1), times the speed_scale it got, and compared with the speed.
## Slip is the difference per stride. BokiRig.STRIDE must also match what the clips measure.
## Prints PASS/FAIL lines.

const Shots := preload("res://tools/boki_rig_shots.gd")
const Check := preload("res://tools/boki_rig_check.gd")
const SPEEDS := [1.0, 3.0]
const SLIP_MAX := 0.15        # of a stride: the planted foot may slide this far per step
const STRIDE_TOL := 0.05      # BokiRig.STRIDE vs the measured clip, as a fraction
const FEETLESS := 0.1         # m/s: a foot that sweeps less than this is not stepping (it floats, glides or is tucked)
const GLIDE_STRIDE := [1.5, 2.9]      # what such a Boki keeps: BokiRig.STRIDE before it was measured
## Ratchet: gaits (species x speed) too short a stride even at BokiRig.MAX_CADENCE (docs/DEBT.md).
const MAX_SHORT := 13
const SAMPLES := 48           # poses per loop
const PLANTED := 0.5          # the lowest this fraction of a foot's lift counts as planted
## Bones that are not limbs when a Boki has no paws and its lowest limb stands in for a foot.
const NOT_LIMB := ["root", "hips", "spine", "neck", "head"]

var bad := 0
var short_clips := 0

func ok(cond: bool, what: String) -> void:
	print("BOKIFOOT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for id in Check.SPECIES_LIST:
		await _species(main, id)
	ok(short_clips <= MAX_SHORT, "%d gaits too short a stride at full cadence (ratchet %d)" % [short_clips, MAX_SHORT])
	print("BOKIFOOT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _species(main: Node, id: String) -> void:
	var k := Shots.rigged_kin(id)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.manual = true
	var stride: Array = BokiRig.STRIDE[id]
	var measured := [foot_speed(rig, "walk"), foot_speed(rig, "run")]
	print("BOKIFOOT %s measured walk %.2f run %.2f m/s" % [id, measured[0], measured[1]])
	if measured.min() < FEETLESS:
		ok(stride == GLIDE_STRIDE, "%s has no stepping feet, so it keeps the shared stride" % id)
		k.queue_free()
		return
	for i in 2:
		var near: bool = absf(measured[i] - stride[i]) <= STRIDE_TOL * measured[i]
		ok(near, "%s %s stride %.2f matches its clip" % [id, ["walk", "run"][i], stride[i]])
	for v in SPEEDS:
		rig._speed = v
		rig._pick_clip(0.016)
		var planted: float = measured[1 if rig.clip == "run" else 0] * rig.player.speed_scale
		var slip := absf(v - planted) / planted
		var cap := BokiRig.MAX_CADENCE * rig.player.get_animation(rig.clip).length
		var short := slip >= SLIP_MAX and is_equal_approx(rig.player.speed_scale, cap)
		var what := "%s at %.0f m/s (%s x%.2f)" % [id, v, rig.clip, rig.player.speed_scale]
		var verdict := " (clip too short)" if short else ""
		ok(slip < SLIP_MAX or short, "%s slips %.0f%% of a stride%s" % [what, slip * 100.0, verdict])
		short_clips += int(short)
	k.queue_free()

## m/s the planted foot moves back at speed 1 in `clip` (the median of the feet), from SAMPLES poses over its loop.
static func foot_speed(rig: BokiRig, clip: String) -> float:
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
	var speeds: Array = []
	for path in paths:
		speeds.append(_planted_speed(path, anim.length / SAMPLES))
	speeds.sort()
	return speeds[speeds.size() / 2]

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

## Mean speed (m/s) a foot moves back along the body (models face -Z) while it is in the lower half of its lift.
static func _planted_speed(path: Array, dt: float) -> float:
	var lo := INF
	var hi := -INF
	for p: Vector3 in path:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var limit := lo + PLANTED * (hi - lo) + 0.0005
	var sum := 0.0
	var n := 0
	for i in path.size():
		var a: Vector3 = path[i]
		var b: Vector3 = path[(i + 1) % path.size()]
		if a.y <= limit and b.y <= limit and b.z > a.z:
			sum += (b.z - a.z) / dt
			n += 1
	return sum / maxf(n, 1)
