extends RefCounted
## --mantle-clip --shots-dir=<dir>: item 185b's before/after clips on the Hollow Crown, at the match camera,
## 15 fps: <dir>/<case>/f000.png... for a running jump into a two-terrace face (jump), a jump and air dash
## into one (dash) and a fall below an island rim heading back in (abyss). The faces and approaches are
## --cliff-mantle-check's. Prints "MCLIP <case> topped|missed in <speed> lip <speed>". Needs a renderer
## (jobq --needs gpu). Never touches the save.

const STEPS_PER_FRAME := 4       # 60 Hz steps per 15 fps frame
const CLIP_S := 1.6
const CASES := [["jump", "jump_0", 2], ["dash", "jump_dash", 2], ["abyss", "abyss", 0]]

var main: Node
var chk

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var dir := "user://mantle_clip"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	chk = load("res://tools/cliff_mantle_check.gd").new()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	if main.get("fade") != null:
		await main.fade.reveal(0.01)       # the boot splash stays up when a tool starts the match by hand
	chk.m = m
	chk.w = m.world
	for i in 30:
		m.step(Match.DT)
	chk._clear_others()
	chk.h.set_arch("thief")
	chk.h.unlock_all()
	var faces: Array = chk._faces()
	var rims: Array = chk._rims()
	if m.hud:
		m.hud.visible = false
	for c in CASES:
		var pool: Array = rims if c[2] == 0 else faces.filter(func(f): return f["rise"] == c[2])
		pool = pool.filter(func(f): return _clear_view(m.world, f))
		if pool.is_empty():
			print("MCLIP %s: no edge" % c[0])
			continue
		await _clip(m, pool[pool.size() / 2], String(c[1]), dir.path_join(String(c[0])), String(c[0]))
	print("MCLIP DONE")
	main.get_tree().quit()

## No tall grass within 4 tiles of the approach: the Hunter stays in sight.
func _clear_view(w: World, f: Dictionary) -> bool:
	var a: Vector2i = f["a"]
	for z in range(a.y - 4, a.y + 5):
		for x in range(a.x - 4, a.x + 5):
			if w.inb(x, z) and w.bush.has(w.idx(x, z)):
				return false
	return true

## One approach, the camera following, a frame every STEPS_PER_FRAME steps.
func _clip(m: Match, f: Dictionary, mode: String, out: String, label: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var h: Hunter = chk.h
	var d: Vector2i = f["d"]
	var dv := Vector2(d)
	var a: Vector2i = f["a"]
	var face := Vector2(a.x + 0.5, a.y + 0.5) + dv * 0.5
	var top := float(f["la"] + f["rise"]) * World.LEVEL
	if not chk._setup(f, mode, face, dv, top):
		print("MCLIP %s: can't stand at the start" % label)
		return
	for i in 20:
		await _frame(m)          # the camera settles on the start
	var jumped := mode == "abyss"
	var dashed := mode != "jump_dash"
	var vin := 0.0
	var vlip := 0.0
	var topped := false
	var n := 0
	var t := 0.0
	while t < CLIP_S:
		for s in STEPS_PER_FRAME:
			h.inp["move"] = dv
			h.inp["aim"] = Vector3(face.x + dv.x * 4.0, top + 0.9, face.y + dv.y * 4.0)     # a frame reads the mouse
			h.inp["jump"] = false
			h.inp["dash"] = false
			var to_face := (face - Vector2(h.pos.x, h.pos.z)).dot(dv)
			if not jumped and to_face < (2.6 if mode == "jump_dash" else 1.2):
				h.inp["jump"] = true
				jumped = true
			elif jumped and not dashed and h.air_t > 0.08 and not h.grounded:
				h.inp["dash"] = true
				dashed = true
			var hv := Vector2(h.vel.x, h.vel.z).length()
			m.step(Match.DT)
			t += Match.DT
			if vin == 0.0 and (to_face < h.r + 0.35 or not h.lfloat.is_empty()):
				vin = hv
			if not topped and vin > 0.0 and h.pos.y >= top - 0.15 and (Vector2(h.pos.x, h.pos.z) - face).dot(dv) > 0.3:
				topped = true
				vlip = Vector2(h.vel.x, h.vel.z).length()
		await _frame(m)
		m.get_viewport().get_texture().get_image().save_png(out.path_join("f%03d.png" % n))
		n += 1
	print("MCLIP %s %s in %.1f lip %.1f (%d frames)" % [label, "topped" if topped else "missed", vin, vlip, n])

## Draws one frame without stepping the match: the camera and the models catch up to where things are now.
func _frame(m: Match) -> void:
	var span := STEPS_PER_FRAME * Match.DT
	if m.cam and m.player:
		Input.warp_mouse(m.cam.unproject_position(m.player.pos))     # the camera leans toward the pointer
	m.hitstop = 0.0
	m.slowmo = 0.0
	m.acc = Match.DT * 0.999 - DashPace.frame_dt(m, span)
	m._process(span)
	await main.get_tree().process_frame
