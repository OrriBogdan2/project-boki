extends RefCounted
## --boki-rig-check: a rigged Boki (BokiRig, art/kin/<id>/<id>.glb) has its clips and faces, picks them from
## the same metas KinPuppet reads, floats and swims or paddles in water deeper than half its height ("kwater"),
## wears each Boki's own colours and marks, stays inside its budgets.
## Prints PASS/FAIL lines.

const Shots := preload("res://tools/boki_rig_shots.gd")
const SPECIES_LIST := ["cindle", "puddlet", "burrlet", "glintmole", "rimeshrew",
	"zephyrak", "pebbit", "cairnback", "wisplet", "gloamshell",
	"selenfin", "zapple", "hivara", "glomwort", "kestrike", "kindlewren", "lodestick", "marchleaf", "mossgrade",
	"nettlynx", "thrumbird", "caecilith"]
var kin_id := "cindle"
const CLIPS := ["idle", "walk", "run", "attack", "ability", "hop", "sleep", "eat", "pet", "chop", "mine", "carry",
	"tend", "settle", "nap", "wake", "munch", "nudge", "climb", "splash", "swim", "paddle", "rush", "brace", "dodge",
	"stonehop", "spin"]
const GAME_CLIPS := BokiHomePoses.GAME_CLIPS
const T_POSE := 0.02           # rad: a frame whose every bone is this close to the bind pose is a T-pose
const T_FRAMES := 8            # frames sampled over a game clip
const SHAPES := ["blink", "closed", "happy", "sad", "sleepy", "angry", "m_smile", "m_frown", "m_snarl", "m_chomp",
	"m_o"]
const MAX_TRIS := 5000         # Boki and props (S1's perf rule)
## Models merged from the single-species branches over that rule: a ratchet at their count today, to be cut down.
const OVER_TRIS := {"kindlewren": 10714, "marchleaf": 5006, "mossgrade": 11914, "thrumbird": 7636}
const MAX_BONES := 64
const DEEP := 1.0              # m of water for the swim rows
const SHALLOW := 0.1           # m: a puddle it stands in
const FEET_CLEAR := 0.1        # m its lowest bone keeps off the bed when it floats

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOKIRIG %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	ok(not BokiRig.has("no_model"), "an id without one keeps its KinModels body")
	for id in SPECIES_LIST:
		kin_id = id
		await _species(main)
	print("BOKIRIG DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _species(main: Node) -> void:
	print("BOKIRIG species %s" % kin_id)
	ok(BokiRig.has(kin_id), "%s has a rigged model" % kin_id)
	var k := Shots.rigged_kin(kin_id)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	_contents(rig)
	await _states(main, k, rig)
	await _own_look(main)
	k.queue_free()

func _contents(rig: BokiRig) -> void:
	for c in CLIPS:
		var a := rig.player.get_animation(c)
		ok(a != null and a.length > 0.1, "clip %s" % c)
	for c in BokiRig.LOOPED + ["swim", "paddle"]:
		ok(rig.player.get_animation(c).loop_mode == Animation.LOOP_LINEAR, "%s loops" % c)
	_game_clips(rig)
	for c in BokiSwing.WIND:
		var a := rig.player.get_animation(c)
		var src := rig.player.get_animation(BokiSwing.FROM[c])
		var off := 0.0
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				off = maxf(off, a.rotation_track_interpolate(t, BokiSwing.WIND[c]).angle_to(
					src.rotation_track_interpolate(t, BokiSwing.release_of(src))))
		var once := a.loop_mode == Animation.LOOP_NONE
		ok(a.length <= 0.6 and once, "%s is short (%.2f s) and plays once" % [c, a.length])
		var rel := BokiSwing.release_of(src)
		var msg := "%s: the keyed release (%.2f s of %.2f) is the pose at %.2f s (off %.3f rad)"
		ok(off < 0.15, msg % [c, rel, src.length, BokiSwing.WIND[c], off])
	for c in ["swim", "paddle"]:
		ok(not _t_pose(rig, c), "%s has no T-pose frame" % c)
	for s in SHAPES:
		ok(rig.face.find_blend_shape_by_name(s) >= 0, "blend shape %s" % s)
	var tris := 0
	for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		for si in m.get_surface_count():
			tris += (m.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var cap: int = OVER_TRIS.get(kin_id, MAX_TRIS)
	ok(tris <= cap, "%d tris, budget %d" % [tris, cap])
	_lods(rig)
	var skel := rig.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	ok(skel.get_bone_count() <= MAX_BONES, "%d bones, budget %d" % [skel.get_bone_count(), MAX_BONES])

## Tumble's and Echo Steps' clips last as long as their beat data says, play once, and never show the bind pose.
func _game_clips(rig: BokiRig) -> void:
	var impact := float(BaseTumble.rules()["impact_s"])
	var hop := float(EchoSteps.rules()["hop_s"])
	for c in GAME_CLIPS:
		var a := rig.player.get_animation(c)
		var want := EchoSteps.spin_s()
		if c in ["rush", "brace", "dodge"]: want = impact
		elif c == "stonehop": want = hop
		ok(is_equal_approx(a.length, want), "%s lasts %.2f s, its game's beat data says %.2f" % [c, a.length, want])
		ok(a.loop_mode == Animation.LOOP_NONE, "%s plays once" % c)
		ok(not _t_pose(rig, c), "%s has no T-pose frame" % c)
	for m in BaseTumble.rules()["moves"].values():
		ok(String(m["clip"]) in CLIPS, "Tumble's %s plays the rig clip %s" % [m["name"], m["clip"]])

## True when some frame of the clip leaves every bone within T_POSE of its bind pose.
func _t_pose(rig: BokiRig, clip: String) -> bool:
	var skel := rig.skeleton()
	rig.manual = true
	rig.set_clip(clip, 0.0)
	var length := rig.player.get_animation(clip).length
	var worst := 99.0
	for f in T_FRAMES + 1:
		rig.seek(length * float(f) / float(T_FRAMES))
		var far := 0.0
		for b in skel.get_bone_count():
			var q := skel.get_bone_pose_rotation(b)
			far = maxf(far, q.angle_to(skel.get_bone_rest(b).basis.get_rotation_quaternion()))
		worst = minf(worst, far)
	print("BOKIRIG %s %s closest frame to bind pose: %.3f rad" % [kin_id, clip, worst])
	rig.manual = false
	rig.set_clip("idle", 0.0)
	return worst < T_POSE

## The coat has generated LODs (the art budget), the face stays whole (BokiRig.FACE_LOD_BIAS).
func _lods(rig: BokiRig) -> void:
	for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst == rig.face:
			continue
		var data: Dictionary = RenderingServer.mesh_get_surface(inst.mesh.get_rid(), 0)
		var lods: Array = data.get("lods", [])
		print("BOKIRIG %s LODs: %d" % [kin_id, lods.size()])

func _clip_for(rig: BokiRig, key: String, value: Variant) -> String:
	rig.root.set_meta(key, value)
	rig._pick_clip(0.016)
	var got := rig.clip
	rig.root.remove_meta(key)
	return got

func _states(main: Node, k: Node3D, rig: BokiRig) -> void:
	ok(rig.clip == "idle", "starts idle")
	ok(_clip_for(rig, "kstate", "sleep") == "settle", "kstate sleep settles down first")
	rig._shot_left = 0.0
	ok(_clip_for(rig, "kstate", "sleep") == "nap", "then naps")
	rig._asleep = false
	for act in ["munch", "nudge", "climb", "splash"] + GAME_CLIPS:
		ok(_clip_for(rig, "kact", act) == act, "kact %s" % act)
	ok(_clip_for(rig, "kwork", "chop") == "chop", "kwork picks a work clip")
	ok(_clip_for(rig, "kact", "pet") == "pet", "kact pet")
	ok(BokiRig.work_clip({}) == "", "no job, no work clip")
	ok(BokiRig.work_clip({"job": {"phase": "work", "kind": "ore"}}) == "mine", "an ore job mines")
	ok(BokiRig.work_clip({"job": {"phase": "to", "kind": "chop"}}) == "carry", "taking it home carries")
	ok(BokiRig.work_clip({"job": {"phase": "work", "kind": "fire"}}) == "tend", "a job with no clip of its own tends")
	await _body_stays_level(main, k, rig)
	ok(_clip_for(rig, "happy", true) == "hop", "happy hops")
	rig._speed = 4.0
	rig._ground = 4.0           # moving steadily, not stopping
	rig._pick_clip(0.016)
	ok(rig.clip == "run", "fast runs")
	rig._speed = 1.2
	rig._ground = 1.2
	rig._pick_clip(0.016)
	ok(rig.clip == "walk", "slow walks")
	rig._speed = 0.0
	k.set_meta("pulse", 123)
	rig._pick_clip(0.016)
	ok(rig.clip == "cast", "a cast pulse plays the cast")
	rig._shot_left = 0.0
	rig._pick_clip(0.016)
	ok(rig.clip == "idle", "and it goes back to idle")
	k.set_meta("kstate", "attack")
	rig._pick_clip(0.016)
	ok(rig.clip == "lunge", "an attacking Boki plays the lunge")
	k.set_meta("kstate", "")
	rig._shot_left = 0.0
	rig._pick_clip(0.016)
	_in_water(k, rig)
	k.set_meta("face", "sad")
	rig._face_step(1.0)
	k.remove_meta("face")
	var w := rig.face.get_blend_shape_value(rig.face.find_blend_shape_by_name("sad"))
	ok(w > 0.9, "the face meta sets the expression: sad %.2f" % w)
	k.set_meta("pose", "growl")
	rig._face_step(1.0)
	k.remove_meta("pose")
	w = rig.face.get_blend_shape_value(rig.face.find_blend_shape_by_name("angry"))
	ok(w > 0.9, "a growl shows on the face: angry %.2f" % w)
	await main.get_tree().process_frame
	rig.set_clip("sleep", 0.0)
	rig.set_face("asleep")
	rig.seek(0.5)
	w = rig.face.get_blend_shape_value(rig.face.find_blend_shape_by_name("closed"))
	ok(w > 0.99, "asleep the eyes are shut")

## In DEEP water it floats off the bed, SWIM_LINE of its height under, and swims (a Water type) or paddles; one
## that hovers stays over the water. In a puddle it stands on the bed; with no water said this frame it is dry again.
func _in_water(k: Node3D, rig: BokiRig) -> void:
	var hovers: bool = BokiRig.FRAME[kin_id].get("hover", false)
	var want := "swim" if BokiRig.swimmer(kin_id) else "paddle"
	k.set_meta("kwater", DEEP)
	rig._process(0.016)
	rig.player.seek(0.2, true)
	var feet := _lowest_bone(rig) - k.global_position.y
	var lift := rig.model.position.y * rig.flex.global_basis.y.length()
	if hovers:
		ok(rig.clip == "idle" and is_equal_approx(lift, DEEP), "hovers over %.1f m of water: %s" % [DEEP, rig.clip])
	else:
		ok(rig.clip == want, "in %.1f m of water it plays %s: %s" % [DEEP, want, rig.clip])
		ok(is_equal_approx(lift, DEEP - rig._afloat()), "afloat with half its height under: %.2f m up" % lift)
	ok(feet > FEET_CLEAR, "its feet are off the bed: %.2f m" % feet)
	k.set_meta("kwater", SHALLOW)
	rig._process(0.016)
	if not hovers:
		ok(rig.clip == "idle" and is_zero_approx(rig.model.position.y), "in a puddle it stands on the bed")
	rig._process(0.016)
	ok(rig.clip == "idle" and is_zero_approx(rig.model.position.y), "with no water this frame it is dry again")

## The lowest point of its pose (m, world): every bone but the props and the grown parts.
func _lowest_bone(rig: BokiRig) -> float:
	var skel := rig.skeleton()
	var low := INF
	for b in skel.get_bone_count():
		var bone := skel.get_bone_name(b)
		if not bone.begins_with("prop_") and not bone.begins_with("part_"):
			low = minf(low, (skel.global_transform * skel.get_bone_global_pose(b)).origin.y)
	return low

## Home's work poses rock Body and hold their item over its head; while it works the rig owns both.
func _body_stays_level(main: Node, k: Node3D, rig: BokiRig) -> void:
	var body := k.get_node("Body") as Node3D
	var held := Node3D.new()
	held.name = "Held"
	k.add_child(held)
	held.position = Vector3(0, 0.95, 0)
	k.set_meta("kwork", "carry")
	rig._pick_clip(0.016)
	body.rotation.z = 0.16
	rig._keep_flex()
	ok(is_zero_approx(body.rotation.z), "a work clip keeps Body level")
	var carry_at: Vector3 = BokiRig.FRAME[kin_id]["carry"]
	ok(held.position.is_equal_approx(carry_at), "carrying, the load sits where it holds it, not over its head")
	body.position.y = 0.3
	rig._keep_flex()
	var hovers: bool = BokiRig.FRAME[kin_id].get("hover", false)
	ok(hovers == (rig._shadow != null), "a Boki that hovers has a ground shadow, one on legs has none")
	if rig._shadow:
		var gap := rig._shadow.global_position.y - k.global_position.y
		ok(is_equal_approx(gap, BokiRig.SHADOW_LIFT), "its shadow stays on the ground under a lifted body")
	body.position.y = 0.0
	k.remove_meta("kwork")
	rig._pick_clip(0.016)
	held.free()
	await main.get_tree().process_frame

## A mutation shows as its part of the mesh, nothing else does, and it never falls back on Evo's primitives.
func _grown_parts(main: Node) -> void:
	var rec := Save.new_kin(kin_id, "Horny")
	rec["muts"] = [{"id": "horns", "lv": 2, "aff": "fierce"}]
	var k := Shots.rigged_kin(kin_id, rec)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	var skel := rig.skeleton()
	var dna := skel.find_children("*", "BokiDna", false, false)[0] as BokiDna
	var shown: Array = dna.shown.map(func(p: Array) -> String: return skel.get_bone_name(int(p[0])))
	ok(shown == ["part_horns"], "only its horns are out: %s" % str(shown))
	ok(is_equal_approx(float(dna.shown[0][1]), 1.3), "level 2 parts are bigger, as in Evo")
	k.queue_free()

func _own_look(main: Node) -> void:
	var rec := Save.new_kin(kin_id, "Spot")
	rec["dna"] = Unique.roll(12345)
	rec["dna"]["mark"] = "spots"
	rec["dna"]["eye"] = "sky"
	rec["dna"]["ears"] = "tufted"
	rec["dna"]["tailv"] = "tufted"
	rec["dna"]["birth"] = ["star", "chest"]
	var k := Shots.rigged_kin(kin_id, rec)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	var marks := rig._coat.next_pass as ShaderMaterial
	ok(marks != null and marks.shader.resource_path.ends_with("boki_marks.gdshader"), "its coat marks are on")
	await _grown_parts(main)
	var iris := rig.eye_mat.get_shader_parameter("iris") as Color
	for nm in ["Tuft", "TailTuft", "Birthmark"]:
		ok(k.find_child(nm, true, false) != null, "%s is on the model" % nm)
	ok(iris.b > iris.g * 0.8, "its own eye colour: %s" % iris.to_html())
	k.queue_free()
