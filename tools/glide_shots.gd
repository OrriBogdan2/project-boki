extends RefCounted
## --glide-shots --shots-dir=<dir> [--wardens=a,b] [--size=360]: every Hunter (Arch.ORDER) in a live training match,
## high up, through one glide: a fall, the glider opening, a straight hold, a turn, the Ctrl dive, the glide catching
## again, the glider closing into a fall, then a re-open and an air dash handed back to the glider.
## <dir>/<arch>/{match,side}/f000.png... at 15 fps: the match camera's angle (zoomed on the Hunter) and a side view.
## Prints one GLIDE_SHOT line a frame (phase, glide weight, fall speed, the body's numbers) so a strip reads with them.
## Needs a renderer.

const CAM_PITCH := 66.0    # degrees: the default match camera (CamRig STYLES "supervive")
const CAM_DIST := 23.0     # m: the match camera's distance
const MATCH_FOV := 9.0     # degrees: the match angle, cropped to the Hunter
const SIDE_FOV := 26.0
const SIDE_DIST := 7.5     # m
const HEIGHT := 60.0       # m above the ground: room for the dive
const EVERY := 4           # sim steps (60 Hz) per frame: 15 fps
## s: the phases, each to the next one's start
const PHASES := [["fall", 0.0], ["open", 0.3], ["hold", 0.7], ["turn", 1.4], ["dive", 2.2], ["catch", 3.0],
	["close", 3.6], ["reopen", 4.2], ["dash", 4.8], ["end", 5.6]]

var tree: SceneTree
var cam: Camera3D
var px := 360

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
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	for arch in only:
		await _hunter(main, String(arch), out.path_join(String(arch)))
	print("GLIDE_SHOTS_DONE")
	tree.quit()

func _phase(t: float) -> String:
	var at := "fall"
	for p in PHASES:
		if t >= float(p[1]):
			at = String(p[0])
	return at

func _hunter(main: Node, arch: String, dir: String) -> void:
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
	h.teleport(h.pos + Vector3(0, HEIGHT, 0))
	cam = Camera3D.new()
	m.add_child(cam)
	cam.make_current()
	var sync := h.model.get_node_or_null("Warden/Sync")
	if sync:
		sync.set_process(false)
	for v in ["match", "side"]:
		DirAccess.make_dir_recursive_absolute(dir.path_join(v))
	var dashed := false
	var step := 0
	var t := 0.0
	var end := float(PHASES[-1][1])
	while t < end:
		var ph := _phase(t)
		var turn_k := clampf((t - 1.4) / 0.4, 0.0, 1.0)
		var mv := Vector2(1, 0).rotated(turn_k * PI * 0.5)      # east, then a quarter turn to the south
		h.inp["move"] = mv
		h.inp["aim"] = h.pos + Vector3(mv.x, 0, mv.y) * 8.0 + Vector3(0, 0.9, 0)
		var glide: bool = ph in ["open", "hold", "turn", "dive", "catch", "reopen", "dash"]
		h.inp["glide"] = glide
		h.inp["glide_btn"] = glide
		h.inp["crouch"] = ph == "dive"
		if ph == "dash" and not dashed:
			dashed = true
			h.dashes = h.max_dashes()
			h.ex_cd = 0.0
			h.do_dash()
		m.step(Match.DT)
		h.render(Match.DT, 1.0)
		if sync:
			sync.call("_process", Match.DT)
		if step % EVERY == 0:
			var i := step / EVERY
			var cl: WardenClips = sync.get("clips") if sync else null
			print("GLIDE_SHOT %s f%03d %-6s gl=%d dv=%d roll=%.2f vy=%6.1f glide_w=%.2f %s" % [arch, i, ph,
				int(h.gliding), int(h.plunging()), h.roll_t, h.vel.y, cl.glide_w if cl else -1.0, _body(h, cl)])
			_aim_match(h)
			await _grab(dir.path_join("match/f%03d.png" % i))
			_aim_side(h)
			await _grab(dir.path_join("side/f%03d.png" % i))
		step += 1
		t = step * Match.DT
	m.queue_free()
	await tree.process_frame

## The body in the model's own frame (-Z ahead), in degrees and body heights: tilt is the hips-to-head line off
## upright (+ forward, past 90 the head is below the hips), bank its sideways lean, hands how far both hands sit over
## the head, feet how far the feet trail behind the hips.
func _body(h: Hunter, cl: WardenClips) -> String:
	if cl == null:
		return "proc"
	var inv := h.model.global_transform.affine_inverse() * cl.skel.global_transform
	var sk := cl.skel
	var at := func(b: String) -> Vector3: return inv * sk.get_bone_global_pose(WardenSkeleton.find(sk, b)).origin
	var hips: Vector3 = at.call("hips")
	var head: Vector3 = at.call("head")
	var up := head - hips
	var tall := maxf(up.length(), 0.01)
	var hands := minf((at.call("hand.L") as Vector3).y, (at.call("hand.R") as Vector3).y) - head.y
	var feet := ((at.call("shin.L") as Vector3).z + (at.call("shin.R") as Vector3).z) * 0.5 - hips.z
	var bank := rad_to_deg(asin(clampf(up.x / tall, -1.0, 1.0)))
	var tilt := rad_to_deg(atan2(-up.z, up.y))
	return "tilt=%4.0f bank=%4.0f hands=%5.2f feet=%5.2f" % [tilt, bank, hands / tall, feet / tall]

func _aim_match(h: Hunter) -> void:
	var at := h.model.global_position + Vector3(0, 0.8, 0)
	var p := deg_to_rad(CAM_PITCH)
	cam.fov = MATCH_FOV * h.model.scale.y
	cam.global_position = at + Vector3(0, sin(p), cos(p)) * CAM_DIST
	cam.look_at(at)

## From the Hunter's left, a little in front, level with the chest.
func _aim_side(h: Hunter) -> void:
	var at := h.model.global_position + Vector3(0, 0.8, 0) * h.model.scale.y
	var yaw := h.model.global_rotation.y + deg_to_rad(65.0)
	cam.fov = SIDE_FOV
	cam.global_position = at + Vector3(-sin(yaw), 0.15, -cos(yaw)) * SIDE_DIST * h.model.scale.y
	cam.look_at(at)

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)
