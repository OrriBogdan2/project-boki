extends RefCounted
## The v95 Hunters through all 15 ANIM_COVERAGE states (warden_clips_check runs it): each Hunter's .glb is bound (every
## clip track names a bone of its skeleton; each walk/run clip keys every bone of the contract's limbs), and every state
## is driven through HunterAnim and the clip tree: the pose leaves the rest pose (no T-pose) and the legs move in
## a walk, a run and a strafe (no frozen bone). One line per Hunter, the failing states named; `--verbose-states`
## prints all.
## Never touches the save.

const Cov := preload("res://tools/anim_coverage_check.gd")
const DT := 1.0 / 60.0
const STATES := ["idle", "walk", "run", "attack", "hit", "death", "jump", "land", "glide", "dash", "cast", "stomp",
	"strafe", "crouch", "upper"]
const MOVE_FRAMES := 45        # frames a held state is sampled over
const MOVE_MAX_S := 1.2        # s: the longest a kit move is sampled for
const T_POSE_RAD := 0.035      # rad (2 deg): a state whose every contract bone stays this near rest is a T-pose
const FROZEN_RAD := 0.03       # rad (1.7 deg): the legs turn less than this over a walk, run or strafe: frozen
const LOCO_LEGS := ["walk", "run", "strafe"]
## Motley has no legs: he hovers on his spring, so his walk and run turn the hips.
const LEGLESS := ["ostra"]
const RUN_V := 4.8             # m/s (the run in warden_clips_check)

var bad := 0
var verbose := false
var idle_pose := {}      # bone -> its local rotation in the standing idle

func run(holder: Node3D) -> int:
	verbose = OS.get_cmdline_user_args().has("--verbose-states")
	for id in Arch.ORDER:
		_hunter(holder, String(id))
	return bad

func _hunter(holder: Node3D, id: String) -> void:
	var art := WardenGlb.art(id)
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	var sk := WardenGlb.skeleton(m.get_node_or_null("Warden"))
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	var notes: Array = _bind(sync.clips, sk) if sync.clips else []
	var an := HunterAnim.new(m)
	idle_pose.clear()
	for st in STATES:
		var r := _state(an, sync, sk, art, st)
		var line := "%s %s: %.1f deg off rest, %.1f off idle, movers turn %.1f" % [art, st, rad_to_deg(r["rest"]),
				rad_to_deg(r["idle"]), rad_to_deg(r["moved"])]
		if r["rest"] < T_POSE_RAD:
			notes.append("%s T-pose" % st)
		if st != "idle" and r["idle"] < T_POSE_RAD:
			notes.append("%s is the idle pose" % st)
		if st in LOCO_LEGS and r["moved"] < FROZEN_RAD:
			notes.append("%s frozen bones" % st)
		if verbose:
			print("STATE ", line)
	var tris := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count() if mesh else 0:
			tris += mesh.surface_get_array_index_len(si) / 3
	print("CLIPS %s %s: %d tris, %s, %d clips, 15 states driven%s" % ["ok  " if notes.is_empty() else "FAIL", art,
			tris, WardenGlb.DIR + "/%s/%s.glb" % [art, art], sync.clips.lib.get_animation_list().size() if sync.clips
			else 0, "" if notes.is_empty() else ": " + "; ".join(notes)])
	bad += 0 if notes.is_empty() else 1
	m.free()

## Retarget: every track of every clip names a bone of the skeleton; the walk and run clips key each limb bone.
func _bind(clips: WardenClips, sk: Skeleton3D) -> Array:
	var notes: Array = []
	var lib := clips.lib
	for nm in lib.get_animation_list():
		var a := lib.get_animation(nm)
		var lost := 0
		for i in a.get_track_count():
			if a.track_get_type(i) == Animation.TYPE_ROTATION_3D or a.track_get_type(i) == Animation.TYPE_POSITION_3D:
				lost += 1 if WardenSkeleton.find(sk, String(a.track_get_path(i).get_concatenated_subnames())) < 0 else 0
		if lost > 0:
			notes.append("clip %s: %d tracks name no bone" % [nm, lost])
	var loco: Dictionary = clips.d.get("loco", {})
	var names: Array = [loco.get("idle", "")]
	for gait in ["walk", "run"]:
		if loco.get(gait) is Dictionary:
			names.append_array((loco[gait] as Dictionary).values())
	for nm in names:
		if not lib.has_animation(String(nm)):
			continue
		var a := lib.get_animation(String(nm))
		var keyed := {}
		for i in a.get_track_count():
			if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				keyed[String(a.track_get_path(i).get_concatenated_subnames())] = true
		for b in WardenGlb.LEG_BONES:
			if not keyed.has(sk.get_bone_name(WardenSkeleton.find(sk, b))):
				notes.append("clip %s keys no %s" % [nm, b])
	return notes

## One state, driven from the standing idle: how far the pose turns from the rest pose, from the idle pose, and how far
## the moving bones (the legs; a hovering Hunter's hips) turn over the state, in rad.
func _state(an: HunterAnim, sync: WardenGlb.Sync, sk: Skeleton3D, art: String, st: String) -> Dictionary:
	var base := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
	play(an, sync, base, 40)
	var out := {"rest": 0.0, "idle": 0.0, "moved": 0.0}
	var first := {}
	var movers := ["hips"] if art in LEGLESS else WardenGlb.LEG_BONES
	for f in frames(an, sync, art, st, base):
		play(an, sync, f, 1)
		for b in WardenGlb.BONES:
			var bi := WardenSkeleton.find(sk, b)
			if b == "root" or bi < 0:
				continue
			var q := sk.get_bone_pose_rotation(bi)
			out["rest"] = maxf(out["rest"], q.angle_to(sk.get_bone_rest(bi).basis.get_rotation_quaternion()))
			if st == "idle":
				idle_pose[b] = q
			else:
				out["idle"] = maxf(out["idle"], q.angle_to(idle_pose[b]))
			first[b] = first.get(b, q)
			if b in movers:
				out["moved"] = maxf(out["moved"], q.angle_to(first[b]))
	play(an, sync, base, 30)
	return out

## The state dicts of one state, a frame each: a held state's dict repeated, a kit move's clock stepped.
func frames(an: HunterAnim, sync: WardenGlb.Sync, art: String, st: String, base: Dictionary) -> Array:
	var s := base.duplicate()
	match st:
		"walk":
			s["vel"] = Vector3(0, 0, -2.0)
		"run":
			s["vel"] = Vector3(0, 0, -RUN_V)
		"strafe":
			s["vel"] = Vector3(RUN_V, 0, 0)
		"hit":
			s.merge({"hit_t": 0.05, "hit_k": 3.0, "hit_dir": Vector2(0, 1)})
		"death":
			s.merge({"dead": true, "dead_t": 0.5})
		"jump":
			s.merge({"grounded": false, "vel": Vector3(0, 5, 0)})
		"glide":
			s.merge({"grounded": false, "gliding": true, "vel": Vector3(0, -1, -RUN_V)})
		"stomp":
			s["stomp"] = 0.5
		"crouch":
			s["crouch"] = 1.0
		"land":
			var fall := {"vel": Vector3(0, -8, 0), "face": 0.0, "grounded": false}
			play(an, sync, fall, 20)
		"attack", "dash", "cast", "upper":
			return _move_frames(art, st, s)
	var out: Array = []
	for i in MOVE_FRAMES:
		out.append(s)
	return out

func _move_frames(art: String, st: String, s: Dictionary) -> Array:
	var moves: Dictionary = WardenClips.data(art).get("kmoves", {})
	var pick := ""
	for k in moves:
		var dash := RegEx.create_from_string(Cov.DASH_RE).search(String(k)) != null
		var cast := RegEx.create_from_string(Cov.CAST_RE).search(String(k)) != null
		if (st == "dash" and dash) or (st == "cast" and cast and not dash) \
				or (st == "upper" and (moves[k] as Dictionary).has("upper")) \
				or (st == "attack" and not dash and not cast and k != "mf_xform"):
			pick = String(k)
			break
	var out: Array = []
	for i in MOVE_FRAMES:
		var f := s.duplicate()
		if pick == "":
			out.append(f)
			continue
		f["kmove"] = pick
		f["kmove_t"] = minf(i * DT, MOVE_MAX_S)
		out.append(f)
	return out

func play(an: HunterAnim, sync: WardenGlb.Sync, s: Dictionary, n: int) -> void:
	for i in n:
		an.update(DT, s)
		sync._process(DT)
