extends RefCounted
## --glide-shots --shots-dir=<dir> [--wardens=a,b] [--size=360]: every Hunter (Arch.ORDER) in a live training match,
## high up, through one glide: a fall, the glider opening, a straight hold, a hard turn left and one right (the keys
## kept 60 degrees off the heading: the glider turns as fast as it can), the dive (crouch held) and the glide catching
## again. <dir>/<arch>/{back,side}/f000.png... at 15 fps: from behind (the bank reads) and from the left (the dive's
## pitch reads), the body's lean toward the match camera (CamRig.char_lean) left out, as it would read as a roll from
## here. Prints one GLIDE_SHOT line a frame with the rig's tilt and the body's, so a strip reads with them.
## Needs a renderer.

const HEIGHT := 60.0       # m above the ground: room for the dive
const EVERY := 4           # sim steps (60 Hz) per frame: 15 fps
const STEER := 60.0        # degrees the keys sit off the heading in a hard turn
const DIST := 7.5          # m from the Hunter
const FOV := 30.0
## s: the phases, each to the next one's start
const PHASES := [["fall", 0.0], ["open", 0.3], ["hold", 0.7], ["left", 1.2], ["level", 2.0], ["right", 2.4],
	["level", 3.2], ["dive", 3.7], ["catch", 4.5], ["end", 5.1]]

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
	cam.fov = FOV
	var sync := h.model.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync:
		sync.set_process(false)
	for v in ["back", "side"]:
		DirAccess.make_dir_recursive_absolute(dir.path_join(v))
	var heading := Vector2(1, 0)
	var step := 0
	var t := 0.0
	while t < float(PHASES[-1][1]):
		var ph := _phase(t)
		if Vector2(h.vel.x, h.vel.z).length() > 1.0:
			heading = Vector2(h.vel.x, h.vel.z).normalized()
		var steer := 0.0       # (a Vector2 of x, z turns right for a positive angle)
		if ph == "left": steer = -STEER
		elif ph == "right": steer = STEER
		h.inp["move"] = heading.rotated(deg_to_rad(steer))
		h.inp["aim"] = h.pos + Vector3(heading.x, 0, heading.y) * 8.0 + Vector3(0, 0.9, 0)
		var glide: bool = ph not in ["fall", "end"]
		h.inp["glide"] = glide
		h.inp["glide_btn"] = glide
		h.inp["crouch"] = ph == "dive"
		m.step(Match.DT)
		h.render(Match.DT, 1.0)
		h.model.basis = Basis(Vector3.UP, h.face).scaled_local(h.model.scale)
		if sync:
			sync._process(Match.DT)
		if step % EVERY == 0:
			var i := step / EVERY
			var on := "gl=%d dv=%d" % [int(h.gliding), int(h.plunging())]
			print("GLIDE_SHOT %s f%03d %-5s %s %s" % [arch, i, ph, on, _body(h)])
			_aim(h, 180.0, 0.25)
			await _grab(dir.path_join("back/f%03d.png" % i))
			_aim(h, 90.0, 0.1)
			await _grab(dir.path_join("side/f%03d.png" % i))
		step += 1
		t = step * Match.DT
	m.queue_free()
	await tree.process_frame

## The rig's and the shown body's tilt off upright, in degrees: roll (+ leaning left) and pitch (+ nose-down), from
## the Rig node, and from the .glb's hips-to-head line when it wears one.
func _body(h: Hunter) -> String:
	var rig := h.model.get_node("Rig") as Node3D
	var up := h.model.global_basis.inverse() * rig.global_basis.y
	var out := "rig roll=%4.0f pitch=%4.0f" % [rad_to_deg(asin(clampf(-up.normalized().x, -1.0, 1.0))),
		rad_to_deg(atan2(-up.z, up.y))]
	var glb := h.model.get_node_or_null("Warden")
	var sk := WardenGlb.skeleton(glb) if glb else null
	if sk:
		var inv := h.model.global_transform.affine_inverse() * sk.global_transform
		var hips := inv * sk.get_bone_global_pose(WardenSkeleton.find(sk, "hips")).origin
		var line := inv * sk.get_bone_global_pose(WardenSkeleton.find(sk, "head")).origin - hips
		out += " body roll=%4.0f pitch=%4.0f" % [rad_to_deg(asin(clampf(-line.normalized().x, -1.0, 1.0))),
			rad_to_deg(atan2(-line.z, line.y))]
	return out

## The camera `yaw` degrees round from the Hunter's front (180: behind it, 90: its left), `rise` of the way up.
func _aim(h: Hunter, yaw: float, rise: float) -> void:
	var at := h.model.global_position + Vector3(0, 1.0, 0) * h.model.scale.y
	var y := h.model.global_rotation.y + deg_to_rad(yaw)
	cam.global_position = at + Vector3(-sin(y), rise, -cos(y)) * DIST * h.model.scale.y
	cam.look_at(at)

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)
