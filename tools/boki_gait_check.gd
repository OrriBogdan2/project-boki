extends RefCounted
## --boki-gait-check: every rigged Boki's feet keep still on the ground. At its home walk and at its match run it plays
## the clip BokiRig.play_scale picks for that speed; the check measures how fast the feet that are down move back
## along the body against how fast the Boki moves. The slide (how far that is off, in percent of the move speed) must
## stay under MAX_SLIDE, or under its ceiling in OVER where the clips cannot reach (docs/art/BOKI_GAIT.md): a ceiling
## only ever comes down. A Boki with no feet on the ground (the sky serpents, the shell, a flier) has nothing to slide.
## Prints one BOKIGAIT line per species and gait (the numbers docs/art/BOKI_GAIT.md ranks) and PASS/FAIL lines.

const Shots := preload("res://tools/boki_rig_shots.gd")
const HOME_WALK := 2.4        # m/s: a farm Boki's wander pace (Home, before its personality's pace)
const MAX_SLIDE := 25.0       # percent of the move speed
const SAMPLES := 48           # poses per clip cycle
const DOWN := 0.5             # a foot is down while it moves back in the lowest part of its height range (fraction)
const LIFT_MIN := 0.02        # m: a foot that lifts less than this never leaves the ground
const STEP_MIN := 0.03        # m: feet that travel less than this along the body do not step (a flier's tucked feet)
const FOOT_BONES := ["paw", "lobe"]

## Species whose clips cannot keep up with their speed yet: [walk, run] slide ceilings, percent. Only ever lower them.
const OVER := {
	"kindlewren": [70, 86], "kestrike": [73, 85], "wisplet": [68, 84], "cairnback": [83, 80], "burrlet": [73, 80],
	"nettlynx": [73, 80], "rimeshrew": [71, 79], "lodestick": [65, 79], "mossgrade": [79, 65], "glintmole": [73, 78],
	"puddlet": [74, 75], "pebbit": [72, 74], "hivara": [67, 72], "cindle": [53, 70], "marchleaf": [68, 57],
	"zapple": [53, 65]}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOKIGAIT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for id in BokiRig.FRAME:
		await _species(main, id)
	print("BOKIGAIT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _species(main: Node, id: String) -> void:
	var k := Shots.rigged_kin(id)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.manual = true
	var feet := _feet(rig.skeleton()) if float(BokiRig.FRAME[id]["hip"]) > 0.0 else PackedInt32Array()
	var ks := KinLib.kin(id)
	var run_speed := KinLib.stat_value("kin_speed", KinLib.points(ks, {}))
	for g in [["walk", HOME_WALK], ["run", run_speed]]:
		var m := measure(rig, feet, String(g[0]), float(g[1]))
		var line := "BOKIGAIT %s %s speed=%.2f scale=%.2f" % [id, g[0], g[1], m["scale"]]
		if feet.is_empty() or float(m["travel"]) < STEP_MIN:
			print(line + " no feet on the ground")
			continue
		print("%s foot/move=%.2f slide=%.1f%% steps/s=%.1f stride=%.2f cycle=%.2fs feet=%d" % [
			line, m["ratio"], m["slide"], m["steps"], m["stride"], m["cycle"], feet.size()])
		var limit: float = OVER.get(id, [MAX_SLIDE, MAX_SLIDE])[0 if g[0] == "walk" else 1]
		ok(float(m["slide"]) < limit, "%s %s slide %.1f%% < %.0f%%" % [id, g[0], m["slide"], limit])
	k.queue_free()

## The bones that touch the ground: the paws (and the lobes of the one that walks on them).
func _feet(skel: Skeleton3D) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		if FOOT_BONES.any(func(f): return n.contains(f)) and skel.get_bone_children(i).is_empty():
			out.append(i)
	return out

## {scale, cycle, ratio, slide, stride, steps, travel} of clip `clip` at `speed` m/s: ratio is the feet's mean speed
## back along the body over the move speed, slide how far from 1 that is per foot (%), stride the m/s the feet cover
## back at playback speed 1 (what the gait row's stride should be), steps the footfalls per second of the whole Boki
## (a step per foot per cycle), travel the most any foot moves along the body (m).
func measure(rig: BokiRig, feet: PackedInt32Array, clip: String, speed: float) -> Dictionary:
	var rate := BokiRig.play_scale(rig.species, clip, speed)
	rig.set_clip(clip, 0.0)
	var cycle := rig.player.get_animation(clip).length
	var skel := rig.skeleton()
	var to_model := rig.model.global_transform.affine_inverse() * skel.global_transform
	var zs := PackedFloat32Array()     # feet x SAMPLES: where each foot is along the body (+z is back), and how high
	var ys := PackedFloat32Array()
	zs.resize(feet.size() * SAMPLES)
	ys.resize(feet.size() * SAMPLES)
	for s in SAMPLES:
		rig.seek(cycle * s / SAMPLES)
		for j in feet.size():
			var p := (to_model * skel.get_bone_global_pose(feet[j])).origin
			zs[j * SAMPLES + s] = p.z
			ys[j * SAMPLES + s] = p.y
	var dt := cycle / SAMPLES / rate
	var ratio := 0.0
	var slide := 0.0
	var travel := 0.0
	for j in feet.size():
		var y := ys.slice(j * SAMPLES, (j + 1) * SAMPLES)
		var z := zs.slice(j * SAMPLES, (j + 1) * SAMPLES)
		var lo: float = Array(y).min()
		var span: float = Array(y).max() - lo
		travel = maxf(travel, Array(z).max() - Array(z).min())
		var back := 0.0
		var down := 0
		for s in SAMPLES:
			var speed_back := (z[(s + 1) % SAMPLES] - z[(s + SAMPLES - 1) % SAMPLES]) / (2.0 * dt)
			var is_down := speed_back > 0.0 and (span < LIFT_MIN or y[s] <= lo + DOWN * span)
			if is_down:
				back += speed_back
				down += 1
		var foot_speed := back / maxi(down, 1)
		ratio += foot_speed / speed / feet.size()
		slide += absf(foot_speed - speed) / speed * 100.0 / feet.size()
	return {"scale": rate, "cycle": cycle, "ratio": ratio, "slide": slide, "stride": ratio * speed / rate,
		"steps": feet.size() * rate / cycle, "travel": travel}
