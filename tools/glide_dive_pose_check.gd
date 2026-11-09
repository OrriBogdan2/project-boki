extends RefCounted
## The glider's dive pose (GlideDivePose), run by --move-feel-check for each of the 12 Hunters on its own model: it
## is up within 0.1 s of the plunge starting and differs from the glide pose the clips show (the hand sits well off
## where the glide holds it), it hands back to the glide after the pull-out, a touchdown drops it at once, and
## heavier bodies pull out with less swing than light ones. Never touches the save.

const DT := 1.0 / 60.0
const START_S := 0.1          # s: the pose must be up this soon after the plunge starts
const HAND_MOVED := 0.15      # m: the hand's move against the glide, in the hip's own frame
const RECOVER_S := 1.0        # s: the pull-out is over by this long after release

var failures := 0
var _lines: Array = []

## Runs every Hunter; returns [failures, lines to print].
func run(holder: Node3D) -> Array:
	var swing := {}
	for id in WardenGlb.ART:
		swing[id] = _hunter(holder, String(id))
	var light := 0.0
	var heavy := 0.0
	for id in swing:
		match Arch.weight(String(id)):
			"light": light = maxf(light, float(swing[id]))
			"heavy": heavy = maxf(heavy, float(swing[id]))
	_ok(light > heavy, "light pull-out swing %.2f beats the heaviest's %.2f" % [light, heavy])
	return [failures, _lines]

func _ok(cond: bool, what: String) -> void:
	_lines.append("%s glide dive pose: %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		failures += 1

## One Hunter: returns the largest pull-out swing it showed.
func _hunter(holder: Node3D, id: String) -> float:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var anim := HunterAnim.new(model)
	var sync := model.get_node("Warden/Sync") as WardenGlb.Sync
	var clips: WardenClips = sync.clips
	var s := {"fired": 99.0, "face": 0.0, "grounded": false, "gliding": true, "vel": Vector3(0, -1.5, 0)}
	sync.set_process(false)
	_run(anim, sync, s, 40)
	var glide_hand := _hand(sync)
	s["gliding"] = false
	s["diving"] = true
	s["plunge"] = true
	s["vel"] = Vector3(0, -32.5, 0)
	_run(anim, sync, s, roundi(START_S / DT))
	_ok(anim.plunge.k >= 0.9 and bool(s["dive_on"]) and clips.proc_w >= 0.9,
			"%s tucked in %.2f s (k %.2f, rig %.2f)" % [id, START_S, anim.plunge.k, clips.proc_w])
	var moved := (_hand(sync) - glide_hand).length()
	_ok(moved >= HAND_MOVED, "%s hand %.2f m off the glide pose" % [id, moved])
	_run(anim, sync, s, 20)
	s["gliding"] = true
	s["diving"] = false
	s["plunge"] = false
	var peak := 0.0
	for i in roundi(RECOVER_S / DT):
		_run(anim, sync, s, 1)
		peak = maxf(peak, anim.plunge.flare)
	_ok(peak > 0.1 and not bool(s["dive_on"]) and clips.proc_w <= 0.01,
			"%s pulled out (swing %.2f) and is back on the glide clip" % [id, peak])
	s["gliding"] = false
	s["diving"] = true
	s["plunge"] = true
	_run(anim, sync, s, 20)
	s["grounded"] = true
	s["plunge"] = false
	s["diving"] = false
	_run(anim, sync, s, 1)
	_ok(anim.plunge.k == 0.0 and not bool(s["dive_on"]), "%s touchdown leaves no dive pose for the landing" % id)
	model.queue_free()
	return peak

func _run(anim: HunterAnim, sync: WardenGlb.Sync, s: Dictionary, frames: int) -> void:
	for i in frames:
		anim.update(DT, s)
		sync._process(DT)

## The left hand in the hips' own frame (so the rig's tip does not count).
func _hand(sync: WardenGlb.Sync) -> Vector3:
	var sk := sync.skel
	var hips := sk.get_bone_global_pose(WardenSkeleton.find(sk, "hips"))
	var hand := sk.get_bone_global_pose(WardenSkeleton.find(sk, "hand.L"))
	return hips.basis.inverse() * (hand.origin - hips.origin)
