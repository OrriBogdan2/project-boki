extends RefCounted
## --crouch-shots --warden=<id> --shots-dir=<dir> [--variant=new|art1|proc] [--size=480] [--sneak=f|b|l|r]
## [--close-fov=24] [--close-at=0.62] [--upper=<clip>: played over the hold, as a shot from a crouch]: a Hero
## standing, going down, holding, sneaking, stopping and standing up, driven through the game state (HunterAnim, then
## WardenClips), at the match camera and a closer one: <dir>/<variant>/{match,close}/f000.png... at 15 fps.
## new: the crouch layer. art1: the same model with no crouch data, what the clips did before it. proc: the rig's
## procedural crouch retargeted on this model, what main's Heroes do. Needs a renderer.

const DT := 1.0 / 30.0
const CAM_PITCH := 66.0    # degrees: the default match camera (CamRig STYLES "supervive")
const CAM_DIST := 23.0
const SPEED_K := 0.55      # Hunter: the walking speed crouched, of the archetype's run speed
## s: down, up. Standing, 1.3 s held, 1.6 s sneaking, 0.5 s still, then up.
const T_DOWN := 0.4
const T_WALK := 1.7
const T_STOP := 3.3
const T_UP := 3.8
const T_END := 4.5

var tree: SceneTree
var cam: Camera3D
var px := 480

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var id := "thief"
	var variant := "new"
	var sneak := "f"
	var close_fov := 24.0
	var close_at := 0.62
	var upper := ""
	var grab: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--warden="): id = a.substr(9)
		if a.begins_with("--variant="): variant = a.substr(10)
		if a.begins_with("--size="): px = int(a.substr(7))
		if a.begins_with("--sneak="): sneak = a.substr(8)
		if a.begins_with("--close-fov="): close_fov = float(a.substr(12))
		if a.begins_with("--close-at="): close_at = float(a.substr(11))
		if a.begins_with("--upper="): upper = a.substr(8)
		if a.begins_with("--grab="): grab = Array(a.substr(7).split(",", false)).map(func(x): return int(x))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	var holder := _stage(main)
	var art_name := WardenGlb.art(id)
	if variant == "art1":
		WardenClips.data(art_name).erase("crouch")
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var yaw := deg_to_rad(-125.0)
	model.rotation.y = yaw
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var anim := HunterAnim.new(model)
	for k in 30:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	if variant == "proc" and clips:
		clips.force = {"proc": true}
	var dirs := {"f": 0.0, "b": PI, "l": PI * 0.5, "r": -PI * 0.5}
	var heading := yaw + float(dirs[sneak])
	var walk_v := Vector3(-sin(heading), 0, -cos(heading)) * float(HunterMove.of(id)["speed"]) * SPEED_K
	for dir in ["match", "close"]:
		DirAccess.make_dir_recursive_absolute(out.path_join(variant).path_join(dir))
	var ck := 0.0
	var t := -1.0
	var i := 0
	var step := 0
	while t < T_END:
		var down := t >= T_DOWN and t < T_UP
		ck = move_toward(ck, 1.0 if down else 0.0, DT * 8.0)     # Hunter.render
		var vel := walk_v if t >= T_WALK and t < T_STOP else Vector3.ZERO
		if upper != "":
			var ut := t - 1.0
			var on := ut >= 0.0 and ut < clips.lib.get_animation(upper).length
			clips.force = {"clip": upper, "t": ut, "upper": true} if on else {}
		anim.update(DT, {"vel": vel, "face": yaw, "grounded": true, "crouch": ck, "fired": 99.0})
		sync.call("_process", DT)
		t += DT
		if t >= 0.0 and step % 2 == 0:
			for c in ["match", "close"]:
				if grab.is_empty() or i in grab:
					_aim(String(c), close_fov, close_at)
					await _grab(out.path_join(variant).path_join(c).path_join("f%03d.png" % i))
			i += 1
		step += 1
	print("CROUCH_SHOTS_DONE ", i)
	tree.quit()

func _aim(which: String, fov: float, at: float) -> void:
	if which == "match":
		var p := deg_to_rad(CAM_PITCH)
		cam.fov = 8.0
		cam.position = Vector3(0, sin(p), cos(p)) * CAM_DIST + Vector3(0, 0.5, 0)
		cam.look_at(Vector3(0, 0.5, 0))
	else:
		cam.fov = fov
		cam.position = Vector3(0, at + 0.3, 5.0)
		cam.look_at(Vector3(0, at, 0))

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)

func _stage(main: Node) -> Node3D:
	var holder := Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()
	return holder
