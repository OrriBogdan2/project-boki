extends RefCounted
## --flue-flight-shots --shots-dir=<dir> [--size=360]: Cinder's Flue Flight in a live training match, for the clip map
## (content/rules/warden_anim/cinder.json): the take-off hover, the steady flight, a hard turn left then right, the
## early landing and the settle. <dir>/{back,side}/f000.png... at 15 fps, one FLUE_SHOT line a frame with the move
## and the bank. Needs a renderer.

const EVERY := 4           # sim steps (60 Hz) per frame: 15 fps
const DIST := 6.0          # m from her
const FOV := 32.0
const FLY_AT := 0.2        # s: the cast
const LEFT_AT := 0.8       # s: the aim swings left of the heading
const RIGHT_AT := 1.3      # s: and right of it
const LAND_AT := 1.8       # s: X again
const END_AT := 2.6        # s: the settle is long over
const SWING := 1.5         # rad: how far the aim sits off the heading in a turn

var tree: SceneTree
var cam: Camera3D
var px := 360

func run(main: Node) -> void:
	tree = main.get_tree()
	Save.no_write = true
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--size="): px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(px, px)
	main.get_viewport().size = Vector2i(px, px)
	await _flight(main, out)
	print("FLUE_FLIGHT_SHOTS_DONE")
	tree.quit()

func _flight(main: Node, dir: String) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight("ashwick"), "arch": "ashwick", "weapon": Arch.signature("ashwick")})
	m.set_process(false)
	m.hud.visible = false
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var h: Hunter = m.player
	h.set_arch("ashwick")
	h.unlock_all()
	h.lvl = 6
	for other in m.hunters:
		if other != h:
			other.ctrl = "idle"
			other.teleport(h.pos + Vector3(60, 0, 60))
	for i in 20:
		m.step(Match.DT)
	cam = Camera3D.new()
	m.add_child(cam)
	cam.make_current()
	cam.fov = FOV
	for v in ["back", "side"]:
		DirAccess.make_dir_recursive_absolute(dir.path_join(v))
	var sync := h.model.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync:
		sync.set_process(false)
	var k := h.ak as AshwickKit
	var heading := Vector3(1, 0, 0)
	var step := 0
	while step * Match.DT < END_AT:
		var t := step * Match.DT
		var turn := 0.0
		if t >= LEFT_AT and t < RIGHT_AT: turn = -SWING
		elif t >= RIGHT_AT and t < LAND_AT: turn = SWING
		h.inp["aim"] = h.pos + heading.rotated(Vector3.UP, turn) * 8.0 + Vector3(0, 0.9, 0)
		if step == roundi(FLY_AT / Match.DT):
			k.cd["x"] = 0.0
			HunterKeys.ult_pressed(h)
		if step == roundi(LAND_AT / Match.DT):
			HunterKeys.ult_pressed(h)
		m.step(Match.DT)
		h.render(Match.DT, 1.0)
		h.model.basis = Basis(Vector3.UP, h.face).scaled_local(h.model.scale)
		if sync:
			sync._process(Match.DT)
		if step % EVERY == 0:
			var i := step / EVERY
			print("FLUE_SHOT f%03d %s bank=%.1f" % [i, k.anim_id, rad_to_deg(h.anim.glide_bank)])
			_aim(h, 180.0, 0.25)
			await _grab(dir.path_join("back/f%03d.png" % i))
			_aim(h, 90.0, 0.1)
			await _grab(dir.path_join("side/f%03d.png" % i))
		step += 1
	m.queue_free()
	await tree.process_frame

## The camera `yaw` degrees round from her front (180: behind, 90: her left), `rise` of the way up.
func _aim(h: Hunter, yaw: float, rise: float) -> void:
	var at := h.model.global_position + Vector3(0, 1.0, 0) * h.model.scale.y
	var y := h.model.global_rotation.y + deg_to_rad(yaw)
	cam.global_position = at + Vector3(-sin(y), rise, -cos(y)) * DIST * h.model.scale.y
	cam.look_at(at)

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)
