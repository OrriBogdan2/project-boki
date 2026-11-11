extends RefCounted
## --flinch-layer-check: a hit during each Hero's LMB hold keeps the ability clip running and adds the flinch
## (WardenFlinch): the clip, its weights and the legs are as without the hit; the torso leans away from the hit
## (front, back, left, right); a harder hit leans further; it settles back; only a stagger plays the hit clip.

const LMB := {"archer": "arc_draw", "thief": "thf_lmb_r", "tender": "mm_shot_r", "gunslinger": "gunslinger_lmb",
	"ashwick": "as_lance", "mage": "mage_lmb_l", "dolm": "breah_punch", "rimewright": "tm_spear_aim",
	"dredge": "dr_shot", "bulwark": "bul_smash_wind", "ostra": "ostra_snap_wind", "juggernaut": "jug_slash_r"}
const DT := 1.0 / 30.0
const HOLD_T := 0.2            # s into the move the check holds it
const LEAN_M := 0.02           # m the head must move away from the hit within 0.3 s
const LEG_RAD := 0.003         # the legs may turn this much off the unhit pose
## Where the hit pushes (x, z in the world) and where the head must go (the model faces -Z, its right is +X).
const DIRS := {"front": [Vector2(0, 1), Vector3(0, 0, 1)], "back": [Vector2(0, -1), Vector3(0, 0, -1)],
	"left": [Vector2(-1, 0), Vector3(-1, 0, 0)], "right": [Vector2(1, 0), Vector3(1, 0, 0)]}

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("FLINCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	for id in LMB:
		_hero(String(id), String(LMB[id]))
	print("FLINCH_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## One Hero held in its LMB move twice, one model hit and one left alone, stepped in lockstep.
func _hero(id: String, move: String) -> void:
	var pair: Array = []
	for i in 2:
		var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
		m.set_meta("anim_seed", 1)
		holder.add_child(m)
		var sync := m.get_node_or_null("Warden/Sync")
		if sync == null or sync.get("clips") == null or sync.get("flinch") == null:
			ok(false, "%s: wears clips and a flinch layer" % id)
			return
		sync.set_process(false)
		var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "kmove": move, "kmove_t": HOLD_T, "hit_t": 99.0}
		m.set_meta(WardenClips.STATE, s)
		pair.append({"m": m, "sync": sync, "s": s, "clips": sync.get("clips"),
				"sk": WardenGlb.skeleton(m.get_node("Warden"))})
	var hit: Dictionary = pair[0]
	var ctl: Dictionary = pair[1]
	var clips: WardenClips = hit["clips"]
	ok(clips.lib.has_animation(String(clips.d["kmoves"][move]["clip"])), "%s: %s is a keyed move" % [id, move])
	_frames(pair, 12)
	var owns := clips.act_w + clips.up_w
	ok(clips.proc_w <= 0.0 and owns >= 0.99, "%s: LMB hold: %s owns the body (%.2f)" % [id, move, owns])
	# (the twins may differ by a fixed offset, Ostra's float: every test is the change from it)
	var off := _gap(pair)
	var legs0 := _bone(ctl, "thigh.L").angle_to(_bone(hit, "thigh.L"))
	var peaks := {}
	for nm in DIRS:
		var up := clips.up_w
		var act := clips.act_w
		var cur := clips.cur
		peaks[nm] = _hit(pair, DIRS[nm][0], 1.0, DIRS[nm][1], off)
		ok(clips.cur == cur and clips.proc_w <= 0.0 and absf(clips.up_w - up) < 0.01 and absf(clips.act_w - act) < 0.01,
				"%s: %s hit: the %s clip keeps running" % [id, nm, move])
		ok(peaks[nm] >= LEAN_M, "%s: %s hit leans the torso away (%.3f m)" % [id, nm, peaks[nm]])
		var legs := _bone(ctl, "thigh.L").angle_to(_bone(hit, "thigh.L"))
		ok(absf(legs - legs0) < LEG_RAD, "%s: %s hit: the legs hold the clip" % [id, nm])
		_frames(pair, 14)
		ok((_gap(pair) - off).length() < 0.005, "%s: settles after the %s hit" % [id, nm])
	var heavy := _hit(pair, DIRS["front"][0], Oomph.HEAVY_FLINCH, DIRS["front"][1], off)
	ok(heavy > peaks["front"] * 1.5, "%s: a stagger leans further (%.3f m vs %.3f)" % [id, heavy, peaks["front"]])
	for r in pair:
		(r["m"] as Node).free()

func _bone(r: Dictionary, nm: String) -> Quaternion:
	var sk: Skeleton3D = r["sk"]
	return sk.get_bone_pose_rotation(WardenSkeleton.find(sk, nm))

## Where the hit model's head is from the untouched one's.
func _gap(pair: Array) -> Vector3:
	var h: Array = []
	for r in pair:
		var sk: Skeleton3D = r["sk"]
		h.append(sk.get_bone_global_pose(WardenSkeleton.find(sk, "head")).origin)
	return (h[0] as Vector3) - (h[1] as Vector3)

func _frames(pair: Array, n: int) -> void:
	for i in n:
		for r in pair:
			var s: Dictionary = r["s"]
			s["hit_t"] = minf(float(s["hit_t"]) + DT, 99.0)
			(r["sync"] as Node).call("_process", DT)

## One hit of the given push and weight on the first model: the furthest its head gets toward where it should lean
## within 0.3 s.
func _hit(pair: Array, push: Vector2, k: float, want: Vector3, off: Vector3) -> float:
	var s: Dictionary = (pair[0] as Dictionary)["s"]
	s["hit_t"] = 0.0
	s["hit_dir"] = push
	s["hit_k"] = k
	var peak := 0.0
	for i in 9:
		_frames(pair, 1)
		peak = maxf(peak, (_gap(pair) - off).dot(want))
	s["hit_t"] = 99.0
	return peak
