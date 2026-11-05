extends RefCounted
## --boki-rig-check: a rigged Boki (BokiRig, art/kin/cindle/cindle.glb) has its clips and faces, picks them from
## the same metas KinPuppet reads, wears each Boki's own colours and marks, stays inside its budgets.
## Prints PASS/FAIL lines.

const Shots := preload("res://tools/boki_rig_shots.gd")
const SPECIES := "cindle"
const CLIPS := ["idle", "walk", "run", "attack", "ability", "hop", "sleep", "eat", "pet", "chop", "mine", "carry"]
const SHAPES := ["blink", "closed", "happy", "sad", "sleepy", "angry", "m_smile", "m_frown", "m_snarl", "m_chomp",
	"m_o"]
const MAX_TRIS := 12000
const MAX_BONES := 64

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOKIRIG %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	ok(BokiRig.has(SPECIES), "the starter has a rigged model")
	ok(not BokiRig.has("pebbit"), "a species without one keeps its KinModels body")
	var k := Shots.rigged_kin(SPECIES)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	_contents(rig)
	await _states(main, k, rig)
	await _own_look(main)
	k.queue_free()
	print("BOKIRIG DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _contents(rig: BokiRig) -> void:
	for c in CLIPS:
		var a := rig.player.get_animation(c)
		ok(a != null and a.length > 0.1, "clip %s" % c)
	for c in BokiRig.LOOPED:
		ok(rig.player.get_animation(c).loop_mode == Animation.LOOP_LINEAR, "%s loops" % c)
	for s in SHAPES:
		ok(rig.face.find_blend_shape_by_name(s) >= 0, "blend shape %s" % s)
	var tris := 0
	for mi in rig.model.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		for si in m.get_surface_count():
			tris += (m.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	ok(tris <= MAX_TRIS, "%d tris, budget %d" % [tris, MAX_TRIS])
	var skel := rig.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	ok(skel.get_bone_count() <= MAX_BONES, "%d bones, budget %d" % [skel.get_bone_count(), MAX_BONES])

func _clip_for(rig: BokiRig, key: String, value: Variant) -> String:
	rig.root.set_meta(key, value)
	rig._pick_clip(0.016)
	var got := rig.clip
	rig.root.remove_meta(key)
	return got

func _states(main: Node, k: Node3D, rig: BokiRig) -> void:
	ok(rig.clip == "idle", "starts idle")
	ok(_clip_for(rig, "kstate", "sleep") == "sleep", "kstate sleep sleeps")
	ok(_clip_for(rig, "kwork", "chop") == "chop", "kwork picks a work clip")
	ok(_clip_for(rig, "kact", "pet") == "pet", "kact pet")
	ok(BokiRig.work_clip({}) == "", "no job, no work clip")
	ok(BokiRig.work_clip({"job": {"phase": "work", "kind": "ore"}}) == "mine", "an ore job mines")
	ok(BokiRig.work_clip({"job": {"phase": "to", "kind": "chop"}}) == "carry", "taking it home carries")
	ok(_clip_for(rig, "happy", true) == "hop", "happy hops")
	rig._speed = 4.0
	rig._pick_clip(0.016)
	ok(rig.clip == "run", "fast runs")
	rig._speed = 1.2
	rig._pick_clip(0.016)
	ok(rig.clip == "walk", "slow walks")
	rig._speed = 0.0
	k.set_meta("pulse", 123)
	rig._pick_clip(0.016)
	ok(rig.clip == "ability", "a cast pulse plays the ability")
	rig._shot_left = 0.0
	rig._pick_clip(0.016)
	ok(rig.clip == "idle", "and it goes back to idle")
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

func _own_look(main: Node) -> void:
	var rec := Save.new_kin(SPECIES, "Spot")
	rec["dna"] = Unique.roll(12345)
	rec["dna"]["mark"] = "spots"
	rec["dna"]["eye"] = "sky"
	var k := Shots.rigged_kin(SPECIES, rec)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	var marks := rig._coat.next_pass as ShaderMaterial
	ok(marks != null and marks.shader.resource_path.ends_with("boki_marks.gdshader"), "its coat marks are on")
	var iris := rig.eye_mat.get_shader_parameter("iris") as Color
	ok(iris.b > iris.g * 0.8, "its own eye colour: %s" % iris.to_html())
	k.queue_free()
