extends RefCounted
## --dash-dir-shots --shots-dir=<dir> [--wardens=a,b] [--size=160]: every Hunter (Arch.ORDER) in a live training match,
## aiming north, dashes forward, back, left and right of that aim, on the ground and from a jump.
## <dir>/<arch>/<ground|air>_<f|b|l|r>/f00.png... at 20 fps, the match camera's angle zoomed on the Hunter.
## Prints one DASHDIR_SHOT line a frame: the dash's way, the body's facing off the aim, the move and the clip playing.
## Needs a renderer.

const CAM_PITCH := 66.0    # degrees: the default match camera (CamRig STYLES "supervive")
const CAM_DIST := 23.0     # m: the match camera's distance
const MATCH_FOV := 9.0     # degrees: the match angle, cropped to the Hunter
const EVERY := 3           # sim steps (60 Hz) per frame: 20 fps
const FRAMES := 9          # frames a dash is followed for
const AIR_UP := 2.5        # m: the lift before an air dash
## Direction name -> move input: the aim is north (-z).
const WAYS := {"f": Vector2(0, -1), "b": Vector2(0, 1), "l": Vector2(-1, 0), "r": Vector2(1, 0)}

var tree: SceneTree
var cam: Camera3D
var px := 160

func run(main: Node) -> void:
	tree = main.get_tree()
	Save.no_write = true
	var out := ""
	var only: Array = Arch.ORDER
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): only = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	if out != "":
		main.get_window().size = Vector2i(px, px)
		main.get_viewport().size = Vector2i(px, px)
	for arch in only:
		await _hunter(main, String(arch), out)
	print("DASHDIR_SHOTS_DONE")
	tree.quit()

func _hunter(main: Node, arch: String, out: String) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch)})
	m.set_process(false)
	m.hud.visible = false
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var h: Hunter = m.player
	h.set_arch(arch)
	h.unlock_all()
	for other in m.hunters:
		if other != h:
			other.ctrl = "idle"
			other.teleport(h.pos + Vector3(60, 0, 60))
	for i in 20:
		m.step(Match.DT)
	cam = Camera3D.new()
	m.add_child(cam)
	cam.make_current()
	var sync := h.model.get_node_or_null("Warden/Sync")
	if sync:
		sync.set_process(false)
	var home := h.pos
	for air in [false, true]:
		for way in WAYS:
			var dir := "%s/%s_%s" % [arch, "air" if air else "ground", way]
			if out != "":
				DirAccess.make_dir_recursive_absolute(out.path_join(dir))
			await _dash(m, h, sync, [home, air, way], dir, out)
	m.queue_free()
	await tree.process_frame

func _dash(m: Match, h: Hunter, sync: Node, at: Array, dir: String, out: String) -> void:
	var home: Vector3 = at[0]
	var air: bool = at[1]
	var way: String = at[2]
	h.vel = Vector3.ZERO
	h.roll_t = 0.0
	h.teleport(home + (Vector3(0, AIR_UP, 0) if air else Vector3.ZERO))
	var mv: Vector2 = WAYS[way]
	var aim := Vector3(0, 0.9, -8)
	h.inp["move"] = Vector2.ZERO
	h.inp["aim"] = h.pos + aim
	for i in 40:
		m.step(Match.DT)
		h.render(Match.DT, 1.0)
		if sync:
			sync.call("_process", Match.DT)
	h.teleport(home + (Vector3(0, AIR_UP, 0) if air else Vector3.ZERO))
	h.dashes = h.max_dashes()
	h.ex_cd = 0.0
	h.inp["move"] = mv
	h.inp["aim"] = h.pos + aim
	h.grounded = not air
	h.do_dash()
	var cl: WardenClips = sync.get("clips") if sync else null
	for i in FRAMES * EVERY:
		h.inp["move"] = mv
		h.inp["aim"] = h.pos + aim
		m.step(Match.DT)
		h.render(Match.DT, 1.0)
		if sync:
			sync.call("_process", Match.DT)
		if i % EVERY != 0:
			continue
		var fr := i / EVERY
		var off := rad_to_deg(wrapf(h.face - atan2(-h.roll_dir.x, -h.roll_dir.y), -PI, PI))
		print("DASHDIR_SHOT %s f%02d roll=%.2f body_off_dash=%4.0f turn=%4.0f aims=%d kmove=%s clip=%s" % [dir, fr,
			h.roll_t, off, rad_to_deg(cl.head_turn) if cl else 0.0, int(h.ak != null and h.ak.aims_in_dash()),
			h.ak.anim_id if h.ak else "-", cl.cur if cl else "proc"])
		if out != "":
			_aim(h)
			await RenderingServer.frame_post_draw
			tree.root.get_texture().get_image().save_png(out.path_join("%s/f%02d.png" % [dir, fr]))

func _aim(h: Hunter) -> void:
	var at := h.model.global_position + Vector3(0, 0.8, 0)
	var p := deg_to_rad(CAM_PITCH)
	cam.fov = MATCH_FOV * h.model.scale.y
	cam.global_position = at + Vector3(0, sin(p), cos(p)) * CAM_DIST
	cam.look_at(at)
