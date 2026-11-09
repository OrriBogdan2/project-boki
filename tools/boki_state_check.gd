extends RefCounted
## --boki-state-check [--shots-dir=<dir>]: every state a Boki shows (garden: nap, eat, pet, play; match: attack,
## ability, hit, faint, perch; and walk, run, work) on every rigged species is driven by a clip or the flinch layer,
## not the rest pose (a T-pose), not frozen, and blends in under 0.2 s. With --shots-dir it also draws the
## contact sheet of all of them (needs a renderer). Prints PASS/FAIL lines.

const Shots := preload("res://tools/boki_rig_shots.gd")
const Rig := preload("res://tools/boki_rig_check.gd")
## state -> the metas that ask for it, and the clip that plays ("" for the flinch layer over whatever runs).
const STATES := {
	"idle": {"clip": "idle"},
	"walk": {"clip": "walk", "speed": 1.2},
	"run": {"clip": "run", "speed": 4.0},
	"play": {"clip": "hop", "meta": {"happy": true}},
	"nap": {"clip": "sleep", "meta": {"kstate": "sleep"}},
	"eat": {"clip": "eat", "meta": {"kact": "eat"}},
	"pet": {"clip": "pet", "meta": {"kact": "pet"}},
	"chop": {"clip": "chop", "meta": {"kwork": "chop"}},
	"perch": {"clip": "idle", "meta": {"kstate": "perch"}},
	"attack": {"clip": "attack", "meta": {"kstate": "attack"}},
	"ability": {"clip": "ability", "meta": {"pulse": 777}},
	"hit": {"clip": "idle", "meta": {"hit": true}, "layer": true},
	"faint": {"clip": "sleep", "meta": {"kstate": "faint"}},
}
const MAX_BLEND := 0.2        # s a state may take to show
const STEP := 0.02            # s per frame of the blend test
const MOVE_EPS := 0.0005      # rad: a bone has moved
const SHEET_PX := 160
const SHEET_SETTLE := 12      # frames a tile runs before it is grabbed

var bad := 0
var out := ""

func ok(cond: bool, what: String) -> void:
	print("BOKISTATE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
	ok(BokiRig.FADE < MAX_BLEND, "clips crossfade in %.2f s" % BokiRig.FADE)
	ok(1.0 / BokiRig.HIT_RATE < MAX_BLEND, "the flinch eases in within %.2f s" % (1.0 / BokiRig.HIT_RATE))
	for id in Rig.SPECIES_LIST:
		var k := Shots.rigged_kin(id)
		main.add_child(k)
		await main.get_tree().process_frame
		var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
		for st in STATES:
			_state(id, st, STATES[st], k, rig)
		k.queue_free()
	if out != "":
		await _sheet(main)
	print("BOKISTATE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Asks for the state the way the game does (metas), settles from idle, and checks what it shows.
func _state(id: String, st: String, spec: Dictionary, k: Node3D, rig: BokiRig) -> void:
	_reset(k, rig)
	_ask(k, rig, spec)
	var peak := 0.0
	var worst := 0.0
	var prev := 0.0
	for i in int(MAX_BLEND / STEP):
		rig._pick_clip(STEP)
		rig._keep_flex()
		rig._face_step(STEP)
		peak = maxf(peak, rig._hit_k)
		worst = maxf(worst, absf(rig._hit_k - prev))
		prev = rig._hit_k
	var want: String = spec["clip"]
	var tag := "%s %s" % [id, st]
	ok(rig.clip == want and rig.player.has_animation(want), "%s plays %s (got %s)" % [tag, want, rig.clip])
	ok(rig.player.is_playing(), "%s: the clip is running" % tag)
	if spec.get("layer", false):
		ok(peak >= 0.9 and worst <= 0.2, "%s: the flinch reaches %.2f, steps of at most %.2f" % [tag, peak, worst])
	else:
		ok(peak == 0.0, "%s: no stray flinch" % tag)
	rig.player.advance(MAX_BLEND)       # the crossfade is over
	var moved := _bones_off_rest(rig, 0.3 * rig.player.current_animation_length)
	ok(moved > MOVE_EPS, "%s is not the rest pose (%.3f)" % [tag, moved])
	if want in BokiRig.LOOPED:
		var span := rig.player.current_animation_length
		ok(_bones_apart(rig, 0.25 * span, 0.75 * span) > MOVE_EPS, "%s is not frozen" % tag)
	_reset(k, rig)

func _ask(k: Node3D, rig: BokiRig, spec: Dictionary) -> void:
	rig._speed = float(spec.get("speed", 0.0))
	var metas: Dictionary = spec.get("meta", {})
	for key in metas:
		k.set_meta(key, metas[key])

func _reset(k: Node3D, rig: BokiRig) -> void:
	for key in ["happy", "kstate", "kact", "kwork", "hit", "pulse"]:
		k.remove_meta(key)
	rig._speed = 0.0
	rig._shot_left = 0.0
	rig._pulse = 0
	rig._hit_left = 0.0
	rig._hit_k = 0.0
	rig._hit_was = false
	rig.set_clip("idle", 0.0)

## Summed bone turn and shift off the rest pose at `at` seconds into the current clip.
func _bones_off_rest(rig: BokiRig, at: float) -> float:
	var skel := rig.skeleton()
	rig.player.seek(at, true)
	var sum := 0.0
	for b in skel.get_bone_count():
		sum += skel.get_bone_pose_rotation(b).angle_to(skel.get_bone_rest(b).basis.get_rotation_quaternion())
		sum += skel.get_bone_pose_position(b).distance_to(skel.get_bone_rest(b).origin)
	return sum

func _bones_apart(rig: BokiRig, a: float, b: float) -> float:
	var skel := rig.skeleton()
	rig.player.seek(a, true)
	var first: Array[Transform3D] = []
	for i in skel.get_bone_count():
		first.append(skel.get_bone_pose(i))
	rig.player.seek(b, true)
	var sum := 0.0
	for i in skel.get_bone_count():
		sum += skel.get_bone_pose_rotation(i).angle_to(first[i].basis.get_rotation_quaternion())
		sum += skel.get_bone_pose_position(i).distance_to(first[i].origin)
	return sum

## Every species (rows) in every state (columns), grabbed after the blend has settled.
func _sheet(main: Node) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var shots := Shots.new()
	shots.main = main
	var names: Array = STATES.keys()
	var sheet := Image.create(SHEET_PX * names.size(), SHEET_PX * Rig.SPECIES_LIST.size(), false, Image.FORMAT_RGBA8)
	var vp := shots._stage(Vector2i(SHEET_PX, SHEET_PX))
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = 30.0
	for row in Rig.SPECIES_LIST.size():
		var id: String = Rig.SPECIES_LIST[row]
		var k := Shots.rigged_kin(id)
		vp.add_child(k)
		k.rotation.y = PI * 0.8
		var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
		rig.manual = true
		var top: float = BokiRig.FRAME[id]["top"]
		cam.position = Vector3(0, top * 0.55, top * 6.0 + 1.5)
		cam.look_at(Vector3(0, top * 0.5, 0))
		for col in names.size():
			_reset(k, rig)
			_ask(k, rig, STATES[names[col]])
			for i in SHEET_SETTLE:
				rig._pick_clip(1.0 / 60.0)
				rig._keep_flex()
				rig._face_step(1.0 / 60.0)
				await main.get_tree().process_frame
			var tile := Rect2i(0, 0, SHEET_PX, SHEET_PX)
			var shot := vp.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(shot, tile, Vector2i(col, row) * SHEET_PX)
		k.queue_free()
	sheet.save_png("%s/states.png" % out)
	print("BOKISTATE sheet: %s columns %s; rows %s" % [out, str(names), str(Rig.SPECIES_LIST)])
