extends RefCounted
## --fusion-event-sheet --shots-dir=<dir> [--only=a,b] (needs a renderer: jobq submit --needs gpu): one Boki of each
## Fusion look (each type's fallback form, plus the forms with a kit) fuses and then releases at the match camera,
## on grass and on dark ground. <dir>/fe_<look>_<ground>.png is a strip per look: top row the enter (R pressed),
## bottom row the release and its afterglow, cropped round the hunter. Scores: docs/FUSION_EVENT.md.

var slow := 0.3                            # Engine.time_scale while capturing (--slow=0.1 on a software renderer)
const CROP := 440                          # px: the square cut round the hunter
const ENTER_AT := [0.04, 0.25, 0.46, 0.6, 1.0]       # s after R (the form is live at 0.7)
const RELEASE_AT := [0.1, 0.5, 1.5, 3.2, 5.0]        # s after the release (afterglow lasts 3, the rest 6)
const DARK := Color("14121a")

var main: Node
var m: Match

## One species per look: the first of each type with no form file, and one for each kit form.
func _looks() -> Dictionary:
	var out := {}
	for id in Data.KIN:
		var ms := KinLib.merge_of(String(id))
		if ms == null:
			continue
		var key := String(Data.KIN[id].get("type", "none"))
		if not Content.merge_form(ms.id).is_empty():
			key = "form_" + ms.id
		if not out.has(key):
			out[key] = String(id)
	return out

func run(main_node: Node) -> void:
	main = main_node
	var dir := ""
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--slow="): slow = float(String(a).substr(7))
		if String(a).begins_with("--only="): only = String(a).substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var looks := _looks()
	var keys: Array = looks.keys()
	keys.sort()
	for key in keys:
		if only.size() > 0 and not (key in only):
			continue
		await _one(String(key), String(looks[key]), dir)
	print("SHEET done %s" % dir)
	main.get_tree().quit(0)

func _one(key: String, species: String, dir: String) -> void:
	if m != null:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"demo_kin": species, "weapon": "rifle", "cls": "medium"})
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	if m.hud: m.hud.visible = false
	m.player.ctrl = "idle"
	m.player.inp["aim"] = m.player.pos + Vector3(0, 0.9, 6)
	print("SHEET %s species %s" % [key, species])
	for ground in ["grass", "dark"]:
		var floor_disc: MeshInstance3D = null
		if ground == "dark":
			floor_disc = _dark_floor(m.player.pos)
		var enter := await _enter(ENTER_AT)
		var released := await _release(RELEASE_AT)
		_strip(dir.path_join("fe_%s_%s.png" % [key, ground]), enter, released)
		if floor_disc != null:
			floor_disc.queue_free()
		await _settle()

func _dark_floor(at: Vector3) -> MeshInstance3D:
	var d := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 16.0
	cyl.bottom_radius = 16.0
	cyl.height = 0.02
	d.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DARK
	mat.roughness = 1.0
	d.material_override = mat
	m.add_child(d)
	d.global_position = at + Vector3(0, 0.04, 0)
	return d

## R with the Boki on the shoulder; grabs a crop at each time.
func _enter(times: Array) -> Array:
	var P := m.player
	P.kin.stow()
	P.merge_cd = 0.0
	P.ult = 1.0
	P.slot_lv["ult"] = 1
	m.cam.snap(P.pos)
	await _frames(3)
	var pressed := KinMerge.press(P)
	if not pressed:
		push_error("fusion sheet: R did not fuse (plan %s)" % KinMerge.plan(P))
	Engine.time_scale = slow
	return await _grab(times)

## Fires the form's ultimate (the release) once live; grabs crops through the afterglow.
func _release(times: Array) -> Array:
	var P := m.player
	Engine.time_scale = 4.0
	while KinMerge.active(P) and String(P.merge_st.get("phase", "")) != "live":
		await main.get_tree().process_frame
	Engine.time_scale = slow
	KinMerge.end(P, "ult")
	return await _grab(times)

## Waits the game time of each entry (relative to now) and grabs a crop.
func _grab(times: Array) -> Array:
	var shots := []
	var t := 0.0
	var i := 0
	while i < times.size():
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
		if t >= float(times[i]):
			shots.append(_crop())
			i += 1
	return shots

func _crop() -> Image:
	var img: Image = main.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var p := m.cam.unproject_position(m.player.pos + Vector3(0, 1.0, 0))
	var x := clampi(int(p.x) - CROP / 2, 0, maxi(0, img.get_width() - CROP))
	var y := clampi(int(p.y) - CROP / 2, 0, maxi(0, img.get_height() - CROP))
	return img.get_region(Rect2i(x, y, CROP, CROP))

func _strip(path: String, top: Array, bottom: Array) -> void:
	var out := Image.create(CROP * ENTER_AT.size(), CROP * 2, false, Image.FORMAT_RGBA8)
	for i in top.size():
		out.blit_rect(top[i], Rect2i(0, 0, CROP, CROP), Vector2i(i * CROP, 0))
	for i in bottom.size():
		out.blit_rect(bottom[i], Rect2i(0, 0, CROP, CROP), Vector2i(i * CROP, CROP))
	out.save_png(path)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## Back to the Boki on the shoulder, the rest and the afterglow cleared, before the next ground.
func _settle() -> void:
	Engine.time_scale = 1.0
	var P := m.player
	P.merge_cd = 0.0
	P.set_meta("afterglow_t", 0.0)
	P.kin.stow()
	await _frames(3)
