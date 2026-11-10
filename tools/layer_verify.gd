extends "res://tools/idle_shots.gd"
## --layer-verify [--wardens=gunslinger,dolm] [--shots-dir=<dir>] [--size=256]: the upper-body layers (a held shot, a
## boulder, a punch, the hit flinch, the aim pitch) over every walk and run, in four directions. Each run is a
## model walking, a layer on for LAYER_ON s, then off, set against the same run with no layer. Prints per run the
## legs' slide off the unlayered run (m), the worst extra hand or head jump a frame (of the Hero's height), and the
## recoil's leftover after the last shot (deg). With --shots-dir (a renderer) also films <dir>/<id>/<layer>_<gait>_<dir>/
## f###.png, FILM_FRAMES across the run. The checks are in --clip-check.

const ART := {"gunslinger": "vex", "dolm": "tarek"}     # Hero id -> its warden_anim file
const DIRS := {"f": Vector2(0, -1), "b": Vector2(0, 1), "l": Vector2(-1, 0), "r": Vector2(1, 0)}     # (x, z) off the facing
const SETTLE := 30              # frames on the gait before anything starts
const LAYER_AT := 0.2           # s into the run the layer comes on
const LAYER_ON := 1.0           # s it stays on
const TAIL := 0.6               # s filmed after it goes off
const FILM_FRAMES := 8
const POP := 0.16               # of the Hero's height: the extra a frame may move the hand or head (as --clip-check)
const SHOT_GAP := 0.12          # s between a held rifle's shots (the quill rifle's rate)
const AIM := 0.35               # rad: the aim pitch's clamp, held

## id -> layers: kmove (a held move's id and how its clock runs: "cycle" s then it restarts, else it runs on), or a state.
const LAYERS := {
	"gunslinger": {
		"shoot": {"kmove": "gunslinger_lmb", "cycle": SHOT_GAP}, "rmb": {"kmove": "gunslinger_rmb"},
		"knock": {"kmove": "gunslinger_knock"}, "flinch": {"hit": true}, "aim_up": {"aim": AIM}, "aim_down": {"aim": -AIM}},
	"dolm": {
		"wind": {"kmove": "breah_wind"}, "boulder": {"kmove": "breah_throw"}, "punch": {"kmove": "breah_punch"},
		"flinch": {"hit": true}, "aim_up": {"aim": AIM}, "aim_down": {"aim": -AIM}},
}

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = LAYERS.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	if out != "":
		if main.get("fade") != null:
			main.fade.reveal(0.01)
		main.get_window().size = Vector2i(frame_px, frame_px)
		main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 30.0
	for id in ids:
		await _hero(String(id), out)
	print("LAYER_VERIFY_DONE")
	tree.quit()

func _hero(id: String, out: String) -> void:
	var lc: Dictionary = WardenClips.data(ART[id])["loco"]
	var layers: Dictionary = LAYERS[id]
	for gait in ["walk", "run"]:
		var speed := float(lc[gait + "_speed"])
		for dn in DIRS:
			var plain := await _take(id, {}, DIRS[dn] * speed, "", false)
			for ln in layers:
				var dir := out.path_join("%s/%s_%s_%s" % [id, ln, gait, dn]) if out != "" else ""
				var rec := await _take(id, layers[ln], DIRS[dn] * speed, dir, false)
				var solo := await _take(id, layers[ln], DIRS[dn] * speed, "", true) if layers[ln].has("kmove") else plain
				_report(id, "%s %s_%s" % [ln, gait, dn], rec, plain, solo, layers[ln])

## One run of LAYER_AT + LAYER_ON + TAIL s: per frame the feet, the hands and head (skeleton-local), the arm bone's turn.
func _take(id: String, layer: Dictionary, vel: Vector2, dir: String, solo: bool) -> Array:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var clips: WardenClips = sync.get("clips")
	var tall := _height(m)
	if dir != "":
		cam.position = Vector3(tall * 1.2, tall * 0.7, -tall * 2.0)
		cam.look_at(Vector3(0, tall * 0.5, 0))
	var s := {"vel": Vector3(vel.x, 0, vel.y), "face": 0.0, "grounded": true, "hit_t": 99.0, "fired": 99.0}
	m.set_meta(WardenClips.STATE, s)
	for k in SETTLE:
		sync.call("_process", DT)
	var steps := int((LAYER_AT + LAYER_ON + TAIL) / DT)
	var film_step := maxi(steps / FILM_FRAMES, 1)
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var rec: Array = []
	for i in steps:
		_drive(s, layer, i * DT - LAYER_AT, m)
		if solo:      # (the move's own clip, whole body: what its hand does by itself)
			clips.force = {}
			if s.has("kmove"):
				var clip := String(clips.d["kmoves"][s["kmove"]]["clip"])
				clips.force = {"clip": clip, "t": minf(float(s["kmove_t"]), clips.lib.get_animation(clip).length - 0.001)}
		sync.call("_process", DT)
		await tree.process_frame
		var f := {"legs": [], "pts": [], "arm": sk.get_bone_pose_rotation(WardenSkeleton.find(sk, "upper_arm.R"))}
		for b in ["shin.L", "shin.R", "foot.L", "foot.R"]:
			f["legs"].append(_at(sk, b))
		for b in ["hand.R", "hand.L", "head"]:
			f["pts"].append(_at(sk, b))
		rec.append(f)
		if dir != "" and i % film_step == 0 and i / film_step < FILM_FRAMES:
			await _grab(dir.path_join("f%03d.png" % (i / film_step)))
	m.free()
	return rec

func _at(sk: Skeleton3D, bone: String) -> Vector3:
	var bi := WardenSkeleton.find(sk, bone)
	return sk.get_bone_global_pose(bi).origin if bi >= 0 else Vector3.ZERO

## The state at t s from the layer coming on (negative before it, past LAYER_ON after it).
func _drive(s: Dictionary, layer: Dictionary, t: float, m: Node3D) -> void:
	var on := t >= 0.0 and t < LAYER_ON
	s.erase("kmove")
	s["hit_t"] = 99.0
	s["fired"] = 99.0
	m.set_meta(WardenAim.PITCH, float(layer.get("aim", 0.0)) if on else 0.0)
	if not on or layer.is_empty():
		return
	if layer.has("hit"):
		s["hit_t"] = t
		s["hit_dir"] = Vector2(0, -1)
	if layer.has("kmove"):
		s["kmove"] = layer["kmove"]
		s["kmove_t"] = fmod(t, float(layer["cycle"])) if layer.has("cycle") else t
		s["fired"] = s["kmove_t"]

func _report(id: String, what: String, rec: Array, plain: Array, solo: Array, layer: Dictionary) -> void:
	var legs := 0.0
	var pop := 0.0
	var at := 0.0
	for i in rec.size():
		for j in 4:
			legs = maxf(legs, (rec[i]["legs"][j] as Vector3).distance_to(plain[i]["legs"][j]))
		if i == 0:
			continue
		for j in 3:
			var step := (rec[i]["pts"][j] as Vector3).distance_to(rec[i - 1]["pts"][j])
			var calm := (plain[i]["pts"][j] as Vector3).distance_to(plain[i - 1]["pts"][j])
			for k in range(maxi(i - 2, 1), mini(i + 3, solo.size())):      # (a frame or two either way: the fade)
				calm = maxf(calm, (solo[k]["pts"][j] as Vector3).distance_to(solo[k - 1]["pts"][j]))
			if step - calm > pop:
				pop = step - calm
				at = i * DT - LAYER_AT
	var left := 0.0
	if layer.has("cycle"):
		var i := rec.size() - 1
		left = rad_to_deg((rec[i]["arm"] as Quaternion).angle_to(plain[i]["arm"]))
	print("LAYER %s %s: legs off %.3f m, hand/head jump +%.3f m @%.2f s, arm left %.2f deg" % [id, what, legs, pop, at, left])
