extends RefCounted
## --aim-pitch-shots --shots-dir=<dir> [--size=360] [--warden=<id>]: every Hero side-on (facing right) holding the LMB
## aim at a ledge 2 tiers down, flat, and 2 tiers up (AimPitch): <dir>/<id>_{down,flat,up}.png. Needs a renderer.

const FRAMES := 45
const AIM_DIST := 4.0       # m to the aim point
const TIER := 0.8           # m: World.LEVEL
const STEPS := {"down": -2.0, "flat": 0.0, "up": 2.0}     # tiers of the aim point over the shooter

var holder: Node3D
var cam: Camera3D
var tree: SceneTree

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var px := 360
	var ids: Array = Arch.ids()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--size="): px = int(a.substr(7))
		if a.begins_with("--warden="): ids = [a.substr(9)]
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	_stage(main)
	for k in 30:
		await tree.process_frame       # (past the title's fade)
	for id in ids:
		for step in STEPS:
			var pitch := AimPitch.rise(float(STEPS[step]) * TIER, AIM_DIST)
			await _shot(String(id), pitch, out.path_join("%s_%s.png" % [id, step]))
	print("AIM_PITCH_SHOTS_DONE")
	tree.quit()

func _shot(id: String, pitch: float, path: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	(m.get_node_or_null("TeamRing") as Node3D).visible = false
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var an := HunterAnim.new(m)
	var s := {"grounded": true, "fired": 0.0, "face": 0.0, "aim_pitch": pitch}
	for i in FRAMES:
		an.update(1.0 / 60.0, s)
		sync.call("_process", 1.0 / 60.0)
	for k in 3:
		await tree.process_frame       # (frame_post_draw never fires on some workers: the 11-10 strip hung)
	var img := tree.root.get_texture().get_image()
	if img != null:
		img.save_png(path)
	m.free()

func _stage(main: Node) -> void:
	holder = Node3D.new()
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
	cam.fov = 30.0
	cam.position = Vector3(5.2, 1.07, 0.0)
	holder.add_child(cam)
	cam.look_at(Vector3(0, 0.82, 0))
	cam.make_current()
