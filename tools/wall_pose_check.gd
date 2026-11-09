extends "res://tools/wallmove_check.gd"
## --wallpose-check [--shots-dir=<dir>]: every Hero's body in a wall kick, a push-off kick and a wall bounce. Each
## Hero's model is put on the hunter and played as in a match (Hunter.render, then its Sync), once with the plant and
## push (WardenWall) and once without it, from the press or hit on. Asserts that with it the sole meets the
## wall face within CONTACT_M on the contact frame (the first with the plant in full) for all of them, and
## prints what the clips alone leave there. With --shots-dir and a renderer it also writes the frames side-on:
## <dir>/<id>_<case>_<on|off>_<frame>.png (tools/wall_pose_sheet.py lays them out). Never touches the save.

const CONTACT_M := 0.1         # m: the sole on the wall face, either side of it
const FRAMES := 24             # steps from the event the case watches (0.4 s: the plant, the push and the let go)

const SHOT_EVERY := 2          # steps between two frames of a strip
const SHOT_PX := 360           # px: a frame's side
const CAM_SIDE := 3.2          # m along the wall the camera stands
const CAM_UP := 1.1            # m above the feet
var shots := ""
var main_node: Node
var cam: Camera3D

func run(main: Node) -> void:
	main_node = main
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			shots = a.substr(12)
	_start(main)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		if main.get("fade") != null:
			main.fade.reveal(0.01)
		main.get_window().size = Vector2i(SHOT_PX, SHOT_PX)
		main.get_viewport().size = Vector2i(SHOT_PX, SHOT_PX)
		cam = Camera3D.new()
		cam.fov = 40.0
		m.add_child(cam)
		if m.cam:
			m.cam.set_process(false)
		if m.hud:
			m.hud.visible = false
	var wl: Dictionary = _carve(5, 1)[0]
	for id in Arch.ids():
		var look := PlayerLook.neutral()
		var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", look, id)
		h.set_model(model)
		var sync := model.get_node_or_null("Warden/Sync")
		var wall: WardenWall = sync.get("wall") if sync else null
		ok(wall != null, "%s: its model has the plant and push" % id)
		if wall == null:
			continue
		sync.set_process(false)
		for kind in ["kick", "push", "bounce"]:
			var on: Dictionary = await _case(String(id), kind, wl, sync, -1)
			var off: Dictionary = await _case(String(id), kind, wl, sync, int(on["contact"]))
			ok(on["event"] and absf(on["d"]) <= CONTACT_M, "%s %s: sole %.3f m off the wall on contact frame %d " % [
				id, kind, on["d"], on["contact"]] + "(clips alone: %.2f m), %d frames within %.2f m" % [
				off["d"], on["held"], CONTACT_M] + "; sole's biggest step to it %.3f m, after %.3f (alone %.3f)" % [
				on["reach"], on["push"], off["push"]])
	print("WALLPOSE DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Plays one case: with the plant when `contact` < 0 (the contact frame is the first with the plant in full), else
## without it, read on that frame. {event, contact, d (signed sole to face there; without the plant, the nearer sole),
## held (frames within CONTACT_M), reach and push (the biggest frame-to-frame move of that sole against the body, m,
## up to the contact frame and after it)}.
func _case(id: String, kind: String, wl: Dictionary, sync: Node, contact: int) -> Dictionary:
	var wall: WardenWall = sync.get("wall")
	var on := contact < 0
	sync.set("wall", wall if on else null)
	var n: Vector2 = wl["n"]       # (into the wall)
	if kind == "bounce":
		var dir := n.rotated(deg_to_rad(45.0))
		var at: Vector2 = (wl["at"] as Vector2) - n * 0.4
		_reset(Vector3(at.x, float(wl["low"]) + 0.5, at.y), false, Vector3(dir.x, 0, dir.y) * 10.0)
	else:      # (a push-off needs the wall touched: it starts against it)
		var at: Vector2 = (wl["at"] as Vector2) - n * (0.0 if kind == "push" else 1.0)
		_reset(Vector3(at.x, wl["low"], at.y), true)
	_frame(DT)
	var ev0 := int(h.anim_s.get("wall_ev", 0))
	var res := {"event": false, "contact": contact, "d": 9.0, "held": 0, "reach": 0.0, "push": 0.0}
	var out := Vector3(-n.x, 0.0, -n.y)
	var since := -1
	var last := Vector3.INF
	for i in 150:
		if kind != "bounce":
			var falling := not h.grounded and h.vel.y <= 0.5
			var press := i > 6 and falling and since < 0 and (kind == "kick" or h.wall_touch_t > 0.0)
			h.inp["jump"] = i == 6 or press
			h.inp["move"] = -n if press and kind == "push" else n
		m.step(DT)
		_frame(DT)
		if since < 0 and int(h.anim_s.get("wall_ev", 0)) != ev0:
			since = 0
			res["event"] = true
		if since < 0:
			continue
		var face: Vector3 = h.anim_s["wall_at"]
		var leg: int = wall.side
		if not on and absf((wall.sole(0) - face).dot(out)) < absf((wall.sole(1) - face).dot(out)):
			leg = 0
		elif not on:
			leg = 1
		var sole: Vector3 = wall.sole(leg)
		var d: float = (sole - face).dot(out)
		if since == int(res["contact"]) or (on and int(res["contact"]) < 0 and wall.w >= 1.0):
			res["contact"] = since
			res["d"] = d
		res["held"] = int(res["held"]) + (1 if absf(d) <= CONTACT_M else 0)
		var rel: Vector3 = h.model.global_transform.affine_inverse() * sole
		if last != Vector3.INF:
			var moved := rel.distance_to(last) * h.model.global_transform.basis.get_scale().y
			var k := "push" if int(res["contact"]) >= 0 and since > int(res["contact"]) else "reach"
			res[k] = maxf(float(res[k]), moved)
		last = rel
		if shots != "" and since % SHOT_EVERY == 0:
			await _shot(face, out, "%s_%s_%s_%02d" % [id, kind, "on" if on else "off", since])
		since += 1
		if since > FRAMES:
			break
	h.inp["jump"] = false
	h.inp["move"] = Vector2.ZERO
	sync.set("wall", wall)
	return res

## A drawn frame: the hunter posed (HunterAnim, then the Hero's clips and layers).
func _frame(dt: float) -> void:
	h.render(dt, 1.0)
	h.model.get_node("Warden/Sync").call("_process", dt)

func _shot(face: Vector3, out: Vector3, nm: String) -> void:
	var along := out.cross(Vector3.UP)
	var look := Vector3(face.x, h.pos.y + CAM_UP * 0.6, face.z) + out * 0.5
	cam.global_position = look + along * CAM_SIDE + out * 1.2 + Vector3.UP * (CAM_UP * 0.4)
	cam.look_at(look)
	cam.make_current()
	await main_node.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main_node.get_viewport().get_texture().get_image().save_png(shots.path_join(nm + ".png"))
