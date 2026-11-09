extends RefCounted
## --status-shots --shots-dir=<dir>: the status looks (scripts/combat/status_looks.gd) at the match camera, for
## scoring "which status, and on whom" (run under xvfb with a renderer). A Hunter carries one status with a clean
## Hunter 1.8 m beside it; each status gets a row of 5 crops 0.2 s apart (the ref sheets' 5 fps). One sheet per
## ground: status_grass.png (the map's own), status_light.png (a pale floor), status_dark.png (a dark one).
## <dir>/captions.txt lists the rows.

const DT := 1.0 / 60.0
const ROWS := ["none", "stun", "daze", "root", "gnd", "slow", "chill", "burn", "static", "antiheal", "sick"]
const GROUNDS := {"grass": null, "light": Color("d8cfb0"), "dark": Color("2b2824")}
const FRAMES := 5
const FRAME_S := 0.2           # s between crops
const CROP := 220              # px square, round the Hunter at 1280x720
const LEAD_S := 0.4            # s the status runs before the first crop

var m: Match
var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	for k in m.kins:
		k.dead = true
		k.visible = false
	if m.hud: m.hud.visible = false
	var P: Hunter = m.player
	var base := P.pos
	var F: Hunter = m.hunters[1]
	var N: Hunter = m.hunters[2]
	for h: Hunter in m.hunters:
		h.ctrl = "idle"
		if h != F and h != N: h.teleport(base + Vector3(-30, 0, 30))
	F.teleport(base)
	N.teleport(base + Vector3(1.8, 0, 0))
	Sfx.listener = base
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	floor_mi.mesh = plane
	floor_mi.position = base + Vector3(0, 0.03, 0)
	m.add_child(floor_mi)
	var lines: Array = []
	for g: String in GROUNDS:
		floor_mi.visible = GROUNDS[g] != null
		if floor_mi.visible:
			floor_mi.material_override = DJFx.solid(GROUNDS[g])
		var sheet := Image.create(CROP * FRAMES, CROP * ROWS.size(), false, Image.FORMAT_RGB8)
		for r in ROWS.size():
			var row := await _row(F, String(ROWS[r]), base)
			for c in FRAMES:
				sheet.blit_rect(row[c], Rect2i(0, 0, CROP, CROP), Vector2i(c * CROP, r * CROP))
		sheet.save_png(dir.path_join("status_%s.png" % g))
		lines.append("status_%s.png: rows top to bottom %s; the left Hunter carries it, the right one is clean"
			% [g, ", ".join(ROWS)])
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	print("STATUSSHOTS ", dir)
	main.get_tree().quit(0)

## One status on F for LEAD_S, then FRAMES crops FRAME_S apart.
func _row(F: Hunter, st: String, base: Vector3) -> Array:
	var out: Array = []
	var t := 0.0
	var next := LEAD_S
	while out.size() < FRAMES:
		_hold(F, st)
		m.step(DT)
		for h in m.hunters: h.render(DT, 1.0)
		m.cam.snap(base + Vector3(0.9, 0, 0))
		await main.get_tree().process_frame
		t += DT
		if t >= next:
			out.append(_crop(F.pos + Vector3(0.9, 1.0, 0)))
			next += FRAME_S
	_hold(F, "")
	m.step(DT)
	return out

## Keeps `st` on F the way the game does ("" takes every status off).
func _hold(F: Hunter, st: String) -> void:
	F.stun_t = 9.0 if st == "stun" else 0.0
	F.root_t = 9.0 if st == "root" else 0.0
	F.slow_t = 9.0 if st == "slow" else 0.0
	F.burn_t = 9.0 if st == "burn" else 0.0
	F.burn_dps = 0.0
	F.blight_t = 9.0 if st == "antiheal" else 0.0
	F.sick_t = 9.0 if st == "sick" else 0.0
	F.hp = F.max_hp
	F.set_meta("gnd_until", m.time + 9.0 if st == "gnd" else 0.0)
	F.set_meta("rat_until", m.time + 9.0 if st == "daze" else 0.0)
	if st in ["chill", "static"]:
		StatusLooks.of(m).keep(F, st)

func _crop(at: Vector3) -> Image:
	var img := main.get_viewport().get_texture().get_image()
	var vp := main.get_viewport()
	var c := vp.get_camera_3d().unproject_position(at) * Vector2(img.get_size()) / vp.get_visible_rect().size
	var box := Rect2i(Vector2i(c) - Vector2i(CROP / 2, CROP / 2), Vector2i(CROP, CROP))
	var out := Image.create(CROP, CROP, false, Image.FORMAT_RGB8)
	img.convert(Image.FORMAT_RGB8)
	out.blit_rect(img, box, Vector2i.ZERO)
	return out
