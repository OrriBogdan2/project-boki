extends RefCounted
## --boki-anim-audit: every rigged Boki's walk and run, driven through the live BokiRig at the speeds Boki move at
## (HOME_SPEEDS and the species' own match speed, KinLib kin_speed), unscaled and at the size roll's ends. Per gait:
## the planted feet's slide as a share of the move speed, steps per second, then the loop seams and the idle-to-walk
## pop. Fails a slide over MAX_SLIDE (except the OVER ceilings), an idle, walk or run seam over MAX_SEAM (except the
## SEAM_OVER ceilings) and a pop over MAX_POP; Boki with no stepping feet are EXEMPT from the slide and listed.
## BokiRig.STRIDE must also match what the clips measure, and so must BokiRig.CONTACT (the starter lines' attack
## contact), each to a frame; driven live, the contact must land within a frame of the hit (Kin.STRIKE_WINDUP).
## Tables: docs/art/kin/RIGGED_BOKI.md "Gait audit" and "Attack contact".

const Shots := preload("res://tools/boki_rig_shots.gd")
const Check := preload("res://tools/boki_rig_check.gd")
## m/s: a stroll, a home wander, a home fetch (home.gd), a led Boki at its catch-up top (home_lead.json), and the
## match speed per species.
const HOME_SPEEDS := [1.5, 2.4, 4.4, 5.4]
const SIZES := [1.0, 0.8, 1.25]       # the Boki's world scale: a size roll scales its stride too
const MAX_SLIDE := 0.25       # of the move speed: how fast a planted foot may slip against the ground
const STRIDE_TOL := 0.05      # BokiRig.STRIDE vs the measured clip, as a fraction
const FEETLESS := 0.1         # m/s: a foot that sweeps less than this is not stepping (it floats, glides or is tucked)
const GLIDE_STRIDE := [1.5, 2.9]      # what such a Boki keeps: BokiRig.STRIDE before it was measured
## No stepping feet, so not gated: the check asserts these are exactly the ones whose feet do not sweep.
const EXEMPT := {"thrumbird": "flyer", "selenfin": "flyer (fins)", "zephyrak": "serpent", "glomwort": "blob",
	"gloamshell": "blob (snail foot)", "gibbelle": "blob"}
## Ratchet: gaits that slide more than MAX_SLIDE at some size and speed even at the best rate BokiRig picks, with
## the most they may slide: the planted paw's speed is uneven (a sine swing from the hip), and at match speeds the
## step is too short even at BokiRig.MAX_CADENCE. Ceilings only come down: lower or drop a row when a clip is
## re-keyed with boki_gait.planted (docs/DEBT.md). Six rose 2-5 points once the clips lost the frame each loop held
## at its start (glb_clip_start.py): that frame let the rig play them faster under MAX_CADENCE, and slid itself.
const OVER := {
	"burrlet walk": 0.30, "burrlet run": 0.75, "cairnback run": 0.60,
	"glintmole walk": 0.35, "glintmole run": 0.75, "hivara run": 0.70, "kestrike walk": 0.40, "kestrike run": 0.65,
	"marchleaf walk": 0.50,
	"marchleaf run": 0.65, "nettlynx run": 0.80, "pebbit walk": 0.30, "pebbit run": 0.70, "puddlet run": 0.70,
	"rimeshrew run": 0.50, "wisplet run": 0.30, "caecilith walk": 0.70, "caecilith run": 0.90,
}
## A loop's wrap may be no rougher than the roughest moment inside the clip (seam()).
const MAX_SEAM := 1.0
## Ratchet: clips whose motion breaks at the loop point (a bone turns or changes speed at the wrap: the first and last
## keys match in pose, not in speed), with the most their seam may read. Lower or drop a row when the clip is re-keyed
## so its ends match in speed too (docs/DEBT.md).
const SEAM_OVER := {
	"puddlet walk": 1.20, "burrlet walk": 1.05, "cairnback walk": 1.65, "gloamshell walk": 2.05, "kestrike walk": 1.35,
	"kindlewren walk": 1.05, "lodestick walk": 1.15, "mossgrade walk": 1.10, "caecilith walk": 1.40,
	"goliathite idle": 1.05, "goliathite walk": 1.45, "goliathite run": 1.25, "hoarheron idle": 1.10,
	"hoarheron walk": 1.45, "hoarheron run": 1.25, "floenatee idle": 1.05, "floenatee walk": 1.40,
	"floenatee run": 1.25
}
const MAX_POP := 3.0          # the idle-to-walk hand-over's biggest bone jump over the steady walk's (pop())
const SAMPLES := 48           # poses per loop
const HELD := 0.1             # a walk or run whose first sample moves less than this of the median one holds still
const PLANTED := 0.5          # a foot in the lowest this fraction of its lift, moving back, is on the ground
const DT := 1.0 / 60.0        # s per frame when the rig is driven live (the idle-to-walk pop)
## Bones that are not limbs when a Boki has no paws and its lowest limb stands in for a foot.
const NOT_LIMB := ["root", "hips", "spine", "neck", "head"]
const STARTERS := ["cindle", "puddlet", "burrlet"]      # Vespyx, Prismander, Mycroll: they must have a CONTACT
const REACH := 0.9            # of its forward travel: the front of the Boki has struck once it is this far out

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOKIGAIT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for id in STARTERS:
		ok(id in BokiRig.CONTACT, "%s has its attack contact in BokiRig.CONTACT" % id)
	for id in Check.SPECIES_LIST:
		await _species(main, id)
	print("BOKIGAIT DONE, failures: %d" % bad)
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
	for clip in ["walk", "run"]:
		var even := start(rig, clip)
		ok(even > HELD, "%s %s sets off at once (first sample %.2f of the median)" % [id, clip, even])
	var loops: Array = []
	for clip in ["idle", "walk", "run"]:
		var sm := seam(rig, clip)
		var most: float = SEAM_OVER.get("%s %s" % [id, clip], MAX_SEAM)
		ok(sm <= most, "%s %s loop seam %.2f, under %.2f" % [id, clip, sm, most])
		loops.append(sm)
	var popped := pop(k, rig)
	ok(popped <= MAX_POP, "%s idle-to-walk pop %.1f, under %.1f" % [id, popped, MAX_POP])
	var seams := "seam idle %.2f walk %.2f run %.2f" % loops
	print("BOKIGAIT %s measured walk %.2f run %.2f m/s, %s, pop %.1f" % [id, measured[0], measured[1], seams, popped])
	if id in BokiRig.CONTACT:
		_contact(k, rig, id)
	var feetless: bool = measured.min() < FEETLESS
	ok(feetless == (id in EXEMPT), "%s is %s" % [id, "EXEMPT " + EXEMPT[id] if id in EXEMPT else "gated"])
	if feetless:
		ok(BokiRig.STRIDE[id] == GLIDE_STRIDE, "%s has no stepping feet, so it keeps the shared stride" % id)
		k.queue_free()
		return
	for i in 2:
		var near: bool = absf(measured[i] - BokiRig.STRIDE[id][i]) <= STRIDE_TOL * measured[i]
		ok(near, "%s %s stride %.2f matches its clip" % [id, ["walk", "run"][i], BokiRig.STRIDE[id][i]])
	var speeds: Array = HOME_SPEEDS + [match_speed(id)]
	var row: Array = []
	for grown in SIZES:
		k.scale = Vector3.ONE * grown
		rig._keep_flex()
		for v in speeds:
			var got := _gait(rig, steps, id, grown, v)
			if grown == 1.0:
				row.append("%.0f%% %.1f/s" % got)
	print("BOKIGAIT ROW %s | %s | %s" % [id, " | ".join(row), seams])
	k.queue_free()

## The attack clip's contact, read off the clip and then driven live through the rig as a Boki's bite plays it.
func _contact(k: Node3D, rig: BokiRig, id: String) -> void:
	var curve := front_reach(rig)
	var at := contact_time(curve)
	ok(absf(at - BokiRig.CONTACT[id]) <= DT, "%s attack contact %.3f s matches its clip (%.3f s)" % [id,
			BokiRig.CONTACT[id], at])
	var lo: float = curve[0]
	var struck: float = lo + REACH * (curve.max() - lo)
	rig.set_clip("idle", 0.0)
	rig._shot_left = 0.0
	rig._attacking = false
	k.set_meta("kstate", "attack")
	var hit_at := INF
	for f in int(1.0 / DT):
		rig._pick_clip(DT)
		rig.player.advance(DT)
		if _front(rig) >= struck:
			hit_at = (f + 1) * DT
			break
	k.set_meta("kstate", "")
	rig._shot_left = 0.0
	rig.player.speed_scale = 1.0
	ok(absf(hit_at - Kin.STRIKE_WINDUP) <= DT, "%s bite connects at %.3f s, the hit lands at %.3f s" % [id, hit_at,
			Kin.STRIKE_WINDUP])

## How far forward (m, models face -Z) the front-most bone reaches, per frame (DT) of the attack clip at speed 1.
static func front_reach(rig: BokiRig) -> Array:
	rig.set_clip("attack", 0.0)
	var anim := rig.player.get_animation("attack")
	var out: Array = []
	for f in int(anim.length / DT) + 1:
		rig.player.seek(f * DT, true)
		rig.player.advance(0.0)
		out.append(_front(rig))
	return out

## s into the clip the front first gets REACH of the way from where it starts to its farthest.
static func contact_time(curve: Array) -> float:
	var lo: float = curve[0]
	var struck: float = lo + REACH * (curve.max() - lo)
	for f in curve.size():
		if curve[f] >= struck:
			return f * DT
	return INF

static func _front(rig: BokiRig) -> float:
	var skel := rig.skeleton()
	var best := -INF
	for b in skel.get_bone_count():
		var nm := skel.get_bone_name(b)
		if not (nm.begins_with("prop_") or nm.begins_with("part_")):
			best = maxf(best, -rig.model.to_local(skel.to_global(skel.get_bone_global_pose(b).origin)).z)
	return best

## m/s the species runs at in a match (Kin.speed before its level and mutation).
static func match_speed(id: String) -> float:
	var ks := KinLib.kin(id)
	return KinLib.stat_value("kin_speed", KinLib.points(ks, {}) if ks else {})

## One species at one size and speed: the clip and rate the rig picks, and how fast its feet slip at them.
## Returns [slide %, steps/s].
func _gait(rig: BokiRig, steps: Dictionary, id: String, grown: float, v: float) -> Array:
	rig._speed = v
	rig._pick_clip(0.016)
	var length := rig.player.get_animation(rig.clip).length
	var sc := rig.player.speed_scale
	var slid := slip(steps[rig.clip], length, v / grown, sc)
	var limit: float = OVER.get("%s %s" % [id, rig.clip], MAX_SLIDE)
	var why := " (at full cadence)" if is_equal_approx(sc, BokiRig.MAX_CADENCE * length) else ""
	var what := "%s x%.2f at %.1f m/s (%s x%.2f, %.1f steps/s)" % [id, grown, v, rig.clip, sc, sc / length]
	ok(slid <= limit, "%s slides %.0f%% of its speed%s, under %.0f%%" % [what, slid * 100.0, why, limit * 100.0])
	return [slid * 100.0, sc / length]

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
		rig.advance(0.0)
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

## m/s a foot on the ground moves back at speed 1 (BokiRig.STRIDE): the median over every foot's contact, the rate
## that keeps the planted feet closest to the ground's speed most of the time.
static func stride(steps: Array, length: float) -> float:
	var all: Array = []
	for foot: Array in steps:
		for dz: float in foot:
			if not is_nan(dz):
				all.append(dz)
	if all.is_empty():
		return 0.0
	all.sort()
	return all[all.size() / 2] / (length / SAMPLES)

## The worst foot's mean slip against the ground while it is down, as a share of the move speed, when the body moves
## at `v` m/s and the clip plays at `rate`. A planted foot that goes back at half the body's speed slips 50%.
static func slip(steps: Array, length: float, v: float, rate: float) -> float:
	var h := length / SAMPLES
	var worst := 0.0
	for foot: Array in steps:
		var slid := 0.0
		var n := 0
		for dz: float in foot:
			if not is_nan(dz):
				slid += absf(1.0 - dz * rate / (v * h))
				n += 1
		worst = maxf(worst, slid / maxi(n, 1))
	return worst

## How far the bones move in a loop's first sample, over the median sample: near 0 the clip holds its first pose a
## while (Blender keys from frame 1 and Godot fills the gap before it with that pose; boki_rig.export slides clips to
## 0 s, glb_clip_start.py the glbs baked before that). 1 is an even start.
static func start(rig: BokiRig, clip: String) -> float:
	var poses := _loop(rig, clip)
	var jumps: Array = []
	for i in SAMPLES - 1:
		jumps.append(_jump(poses[i], poses[i + 1]))
	var first: float = jumps[0]
	jumps.sort()
	return first / maxf(jumps[jumps.size() / 2], 0.0001)

## The loop seam: the sharpest change in any bone's motion (its step's change from one sample to the next: a jump, a
## stop or a turn) across the wrap, over the sharpest inside the clip. At most 1 the loop point is no rougher than
## the clip itself; over 1 the wrap is its roughest moment (a held frame, a pose jump, a break in speed).
static func seam(rig: BokiRig, clip: String) -> float:
	var poses := _loop(rig, clip)
	var kinks: Array = []
	for i in SAMPLES:
		kinks.append(_kink(poses[(i + SAMPLES - 1) % SAMPLES], poses[i], poses[(i + 1) % SAMPLES]))
	var inside: Array = kinks.slice(1, SAMPLES - 1)
	return maxf(kinks[0], kinks[SAMPLES - 1]) / maxf(inside.max(), 0.0001)

## The bones' places at SAMPLES even steps round a clip.
static func _loop(rig: BokiRig, clip: String) -> Array:
	rig.set_clip(clip, 0.0)
	var anim := rig.player.get_animation(clip)
	var poses: Array = []
	for i in SAMPLES:
		rig.player.seek(anim.length * i / SAMPLES, true)
		rig.advance(0.0)
		poses.append(_bones(rig.skeleton()))
	return poses

## The idle-to-walk pop, driven live: the Boki stands, then sets off at HOME_SPEEDS[0]; the biggest one-frame jump
## of any bone while the rig hands the idle over to the walk, over the biggest in the steady walk after it.
## 1 is a smooth start; past MAX_POP the body snaps into the walk.
static func pop(k: Node3D, rig: BokiRig) -> float:
	k.position = Vector3.ZERO
	rig.set_clip("idle", 0.0)
	rig._pos_prev = k.global_position
	rig._speed = 0.0
	var prev := _bones(rig.skeleton())
	var start := -1
	var hand := 0.0
	var steady := 0.0
	for f in int(2.0 / DT):
		if f >= int(0.5 / DT):
			k.position.z -= HOME_SPEEDS[0] * DT
		rig._track_speed(DT)
		rig._pick_clip(DT)
		rig.advance(DT)
		var now := _bones(rig.skeleton())
		var jump := _jump(prev, now)
		prev = now
		if start < 0 and rig.clip == "walk":
			start = f
		if start < 0:
			continue
		if f - start <= int((rig.gait_fade() + 0.1) / DT):
			hand = maxf(hand, jump)
		else:
			steady = maxf(steady, jump)
	k.position = Vector3.ZERO
	return hand / maxf(steady, 0.0001)

static func _bones(skel: Skeleton3D) -> Array:
	var out: Array = []
	for b in skel.get_bone_count():
		out.append(skel.get_bone_global_pose(b).origin)
	return out

static func _jump(a: Array, b: Array) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, (a[i] as Vector3).distance_to(b[i]))
	return worst

## The most any bone's step changes over three poses in a row.
static func _kink(a: Array, b: Array, c: Array) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, ((a[i] as Vector3) - 2.0 * (b[i] as Vector3) + (c[i] as Vector3)).length())
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
