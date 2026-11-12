extends RefCounted
## --look-locker-check: making yourself in the LookLocker (scripts/ui/look_locker.gd). The four tabs with their
## icons; each tab's camera shot (Hollow closes in on the head, Glider pulls back); hovering a choice tries it on
## the model without keeping it; picking one keeps it, pops the model and flashes the turntable; the hood row
## only on a cut with a hood; the dais, satchel and lantern are the Meshy pieces; glider tiles in their rarity
## colours, a locked one never equips; the wheel zooms within its limits and a drag turns the turntable; Looks
## good saves the look and takes the locker down.
## --look-tour --shots-dir=<dir>: the same screen toured for the media (every frame a JPG in <dir>/frames, run
## it on a GPU worker with --fixed-fps 30). Never writes the save.

const TOUR_FRAMES := 450          # 15 s at 30 fps

var bad := 0
var main: Node
var hx: Node
var locker: LookLocker

func ok(cond: bool, what: String) -> void:
	print("LOOK_LOCKER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node, mode: String) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["tutorial"]["intro"] = true
	Save.d["look"] = Unmasked.default_look()
	hx = load("res://scripts/ui/hatch.gd").new()
	hx.edit_only = true
	main.add_child(hx)
	await _frames(3)
	locker = hx.locker
	if mode == "tour":
		await _tour()
		return
	ok(locker != null and hx.stage == "create", "Change your look opens the locker")
	await _tabs()
	await _try_and_pick()
	_hood()
	_props()
	await _gliders()
	await _zoom_and_turn()
	hx._looks_good()
	await _frames(2)
	ok(hx.locker == null and int(Save.d["look"]["shroud"]) == 3 and String(Save.d["look"]["glider"]) == "sunset",
		"Looks good saves the picks (shroud 3, the Sunset Kite) and closes the locker")
	print("LOOK_LOCKER_CHECK %s" % ("FAILED %d" % bad if bad > 0 else "PASSED"))
	main.get_tree().quit(1 if bad > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _opts(prefix: String) -> Array:
	return hx.root_ui.find_children("*", "", true, false).filter(func(c):
		return c.has_meta("look_opt") and String(c.get_meta("look_opt")).begins_with(prefix))

func _opt(id: String) -> Control:
	var all := _opts(id)
	return all[0] if all.size() > 0 else null

func _tabs() -> void:
	var tabs: Array = hx.root_ui.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("tab"))
	ok(tabs.map(func(b): return String(b.get_meta("tab"))) == LookLocker.TABS, "four tabs: %s" % str(LookLocker.TABS))
	ok(tabs.all(func(b): return b.has_meta("glyph") and b.custom_minimum_size.y >= 48), "big tabs, each with its icon")
	ok(_opts("gender:").size() == 2 and _opts("height:").size() == 3, "Body shows sex and height as tiles")
	await _frames(60)
	var head := locker.model.global_position + Vector3(0, 1.5, 0)
	var body_d: float = locker._cam.global_position.distance_to(head)
	locker.show_tab("Hollow")
	await _frames(90)
	var hollow_d: float = locker._cam.global_position.distance_to(head)
	ok(hollow_d < body_d * 0.7, "Hollow closes in on the head (%.2f m from %.2f m)" % [hollow_d, body_d])
	ok(_opts("glow:").size() == Unmasked.GLOWS.size() and _opt("glow:0") is Button, "the glow colours as swatches")
	locker.show_tab("Glider")
	await _frames(90)
	ok(locker._cam.global_position.distance_to(head) > body_d, "Glider pulls back to show the canopy")
	ok(locker.model.position.y > LookLocker.TOP and locker.model.get_node("Rig/Torso/Glider").visible,
		"under the open glider you hang over the turntable")
	locker.show_tab("Shroud")
	await _frames(2)

func _try_and_pick() -> void:
	var tile := _opt("shroud:3")
	tile.mouse_entered.emit()
	await _frames(4)
	var tried := locker.look.duplicate(true)
	tried["shroud"] = 3
	ok(locker._shown == tried.hash() and int(locker.look["shroud"]) == 0,
		"hovering Long Coat tries it on, not keeping it")
	tile.mouse_exited.emit()
	await _frames(4)
	ok(locker._shown == locker.look.hash(), "leaving the tile puts your own shroud back")
	var radial: int = hx.fx.radial
	locker.pick("shroud", 3)
	await _frames(3)
	ok(int(locker.look["shroud"]) == 3 and locker.model.scale.x > 1.0, "picking it keeps it and the model pops")
	ok(hx.fx.radial >= radial + 2, "the turntable flashes a ring and a burst")
	ok(_opt("shroud:3").get_theme_stylebox("panel") != _opt("shroud:0").get_theme_stylebox("panel"), "the pick is lit")

func _hood() -> void:
	locker.pick("shroud", 1)
	ok(_opts("hood:").is_empty(), "a cut without a hood shows no hood row")
	locker.pick("shroud", 3)
	locker.pick("shroud", 0)
	ok(_opts("hood:").size() == 2, "a hooded cut shows it")
	locker.pick("shroud", 3)
	ok(_opts("accent:").size() == Unmasked.COLOURS.size() + 1 and _opt("accent:-1") != null,
		"trim colour: Match, then the colours")

## The Meshy pieces (scripts/match/look_props.gd): the dais under the turntable, the satchel and the lantern worn.
## A worn piece is found by its node name (Models.bake_part_y gives every toon part a copy of its mesh): the same
## vertices, painted in vertex colours, on the body's own leather (no material of its own).
func _props() -> void:
	var dais := LookProps.mesh("dais")
	ok(locker._turn.get_children().any(func(c): return c is MeshInstance3D and c.mesh == dais),
		"the turntable is the carved dais (art/look/dais.glb)")
	for a in [[2, "satchel"], [4, "lantern"]]:
		locker.pick("accessory", a[0])
		var prop := LookProps.mesh(String(a[1]))
		var worn := locker.model.find_child(LookProps.NODE, true, false) as MeshInstance3D
		var leather := locker.model.find_children("*", "MeshInstance3D", true, false).filter(
			func(m): return m != worn and m.material_override == (worn.material_override if worn else null))
		ok(worn != null and worn.mesh.surface_get_array_len(0) == prop.surface_get_array_len(0)
			and prop.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR and not leather.is_empty(),
			"the %s is worn as its vertex-painted Meshy piece, on a material the body already wears" % a[1])
	locker.pick("accessory", 0)

func _gliders() -> void:
	ok(Gliders.rarity("classic") == 0 and Gliders.rarity("sunset") == 1 and Gliders.rarity("moth") == 2
		and Gliders.rarity("ember") == 3 and Gliders.rarity("storm") == 3 and Gliders.rarity("paper_crane") == 4,
		"glider rarity from how it is got (free, price, earned, a mastery gift)")
	locker.show_tab("Glider")
	await _frames(2)
	ok(_opts("glider:").size() == Gliders.LIST.size(), "every glider has a tile")
	var ember := _opt("glider:ember")
	ok(ember.tooltip_text.contains("gems"), "a glider you don't own says how to get it")
	ember.mouse_entered.emit()
	await _frames(4)
	ok(String(locker.model.get_node("Rig/Torso/Glider").get_meta("skin")) == "ember",
		"hovering one you don't own shows it on you")
	ember.mouse_exited.emit()
	locker.pick("glider", "ember")
	ok(Gliders.equipped() == "classic" and String(locker.look.get("glider", "classic")) == "classic",
		"a locked glider never equips")
	Save.d["gliders"] = ["sunset"]
	locker.pick("glider", "sunset")
	ok(Gliders.equipped() == "sunset" and String(locker.look["glider"]) == "sunset",
		"an owned one glides on at a click")

func _zoom_and_turn() -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	for i in 30:
		locker._unhandled_input(wheel)
	ok(is_equal_approx(locker._zoom, LookLocker.ZOOM_MIN), "the wheel zooms in down to its limit (%.2f)" % locker._zoom)
	var yaw: float = locker._turn.rotation.y
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	locker._unhandled_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(80, 0)
	locker._unhandled_input(drag)
	press.pressed = false
	locker._unhandled_input(press)
	ok(absf(locker._turn.rotation.y - yaw) > 0.5, "a drag turns the turntable")

# ---- the media tour: [frame, what happens]
func _tour() -> void:
	var dir := "shots/look_after"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if dir.is_relative_path():
		dir = ProjectSettings.globalize_path("res://").path_join(dir)
	DirAccess.make_dir_recursive_absolute(dir.path_join("frames"))
	if main.fade != null:
		main.fade.reveal(0.05)
	Save.d["gliders"] = ["sunset", "moth"]
	var steps := {30: ["try", "gender:0"], 50: ["pick", "gender", 0], 70: ["try", "height:2"], 85: ["untry"],
		100: ["tab", "Hollow"], 130: ["try", "glow:2"], 145: ["try", "glow:3"], 160: ["pick", "glow", 3],
		180: ["pick", "hollow", 2], 205: ["tab", "Shroud"], 225: ["try", "shroud:4"], 238: ["try", "shroud:8"],
		250: ["pick", "shroud", 1], 260: ["pick", "colour", 5], 270: ["pick", "accessory", 2],
		305: ["pick", "accessory", 4], 340: ["yaw", 0.0], 341: ["tab", "Glider"], 352: ["try", "glider:ember"],
		364: ["try", "glider:moth"], 376: ["pick", "glider", "moth"], 390: ["tab", "Body"], 400: ["zoom", 6]}
	for f in TOUR_FRAMES:
		if steps.has(f):
			_tour_step(steps[f])
		if f >= 272 and f < 296:
			locker._turn.rotation.y += 0.05          # the satchel's side (-x) round to the camera
		if f >= 307 and f < 331:
			locker._turn.rotation.y -= 0.1           # and on round to the lantern's (+x)
		if f >= 410 and f < 445:
			locker._turn.rotation.y += 0.09          # a drag round to the back and on
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_jpg(dir.path_join("frames/%05d.jpg" % f), 0.9)
	print("LOOK_TOUR done %d frames in %s" % [TOUR_FRAMES, dir])
	main.get_tree().quit(0)

func _tour_step(step: Array) -> void:
	match String(step[0]):
		"tab": locker.show_tab(String(step[1]))
		"try": _opt(String(step[1])).mouse_entered.emit()
		"untry": locker._untry()
		"yaw": locker.set_yaw(float(step[1]))
		"pick": locker.pick(String(step[1]), step[2])
		"zoom": locker._zoom = clampf(1.0 - 0.08 * int(step[1]), LookLocker.ZOOM_MIN, LookLocker.ZOOM_MAX)
