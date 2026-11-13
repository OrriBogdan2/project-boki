extends RefCounted
## --tool-raise-shots --shots-dir=<dir>: Albert (the tallest Hunter) and Kael (the shortest) with the axe and the
## pickaxe at the top of the swing, as the farm camera sees them (the Settings default: 66 degrees down, the
## body leaned back 20), turned 0, 45, 90 and 180 degrees from facing away. One sheet, raise.png: a row per
## Hunter and tool, a column per turn. It also prints, per picture, how much of the tool's head and of its haft
## the camera sees (TOOL-RAISE): the tool drawn flat in one colour, with the Hunter in the way and alone.
## Needs a renderer.

const HEROES := ["bulwark", "juggernaut"]      # Albert, Kael
const TURNS := [0.0, 45.0, 90.0, 180.0]       # degrees from facing away from the camera
const CELL := Vector2i(480, 560)              # px per picture
const AIM_Y := 1.9                            # m: where the camera looks, between Kael's chest and Albert's
const PITCH := 66.0                           # degrees down: the Settings default camera
const FOV := 14.0                             # a tight lens from 23 m, so the figure fills a cell
const ALONE_LAYER := 1 << 19                  # the tool alone is drawn on this layer
const HEAD_COL := Color(1, 0, 1)              # the tool's head, flat
const HAFT_COL := Color(0, 1, 1)              # the tool's haft, flat
const SETTLE := 90                            # frames the pose is held, the arms ease into it

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	main.get_window().size = Vector2i(CELL.x, CELL.y)
	main.get_viewport().size = Vector2i(CELL.x, CELL.y)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
		await main.get_tree().create_timer(1.5).timeout
	var holder := _stage(main)
	var cam := holder.get_node("Cam") as Camera3D
	var sheet := Image.create(CELL.x * TURNS.size(), CELL.y * HEROES.size() * 2, false, Image.FORMAT_RGBA8)
	var row := 0
	for id in HEROES:
		for tool in ["axe", "pickaxe"]:
			for col in TURNS.size():
				var img := await _cell(main, holder, cam, id, tool, TURNS[col])
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(col * CELL.x, row * CELL.y))
			row += 1
	sheet.save_png(dir.path_join("raise.png"))
	print("TOOL-RAISE-SHOTS done ", dir)
	main.get_tree().quit()

## One Hunter, new, with the tool at the top of the swing and turned `turn` degrees: the picture; prints the share seen.
func _cell(main: Node, holder: Node3D, cam: Camera3D, id: String, tool: String, turn: float) -> Image:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	var turner := Node3D.new()      # leans the Hunter back and turns it, as the game's body is (CamRig.char_basis)
	holder.add_child(turner)
	turner.add_child(model)
	turner.basis = Basis(Vector3.RIGHT, -CamRig.CHAR_LEAN) * Basis(Vector3.UP, deg_to_rad(turn))
	var anim := HunterAnim.new(model)
	var state := {"vel": Vector3.ZERO, "face": deg_to_rad(turn), "grounded": true, "holster": true, "tool": tool,
			"act": HunterTool.act_of(tool), "tool_t": HunterTool.WIND * HunterTool.period(tool)}
	for i in SETTLE:
		anim.update(1.0 / 60.0, state)
	var paint := _flat(model.get_node("Rig/Torso/Tool"))
	await main.get_tree().process_frame
	var alone := await _count(main, cam, true)
	var seen := await _count(main, cam, false)
	print("TOOL-RAISE %s %s turn %3d: head seen %3d%% haft seen %3d%%" % [id, tool, turn,
			_share(seen[0], alone[0]), _share(seen[1], alone[1])])
	_restore(paint)
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	turner.free()
	return img

func _share(seen: int, total: int) -> int:
	return mini(100, roundi(100.0 * seen / maxi(total, 1)))      # (edge blur can count a few pixels twice)

## Draws the tool flat (head and haft in their colours, on the alone layer too); returns what to put back.
func _flat(tool: Node3D) -> Array:
	var put_back: Array = []
	var first := true
	for part in tool.get_children():
		var mi := part as MeshInstance3D
		put_back.append([mi, mi.material_override, mi.layers])
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = HAFT_COL if first else HEAD_COL
		mi.material_override = mat
		mi.layers |= ALONE_LAYER
		first = false
	return put_back

func _restore(put_back: Array) -> void:
	for row in put_back:
		row[0].material_override = row[1]
		row[0].layers = row[2]

## [head pixels, haft pixels] on screen: with `alone` only the tool is drawn, else the whole scene.
func _count(main: Node, cam: Camera3D, alone: bool) -> Array:
	cam.cull_mask = ALONE_LAYER if alone else 0xFFFFF
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var head := 0
	var haft := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.6 and c.b > 0.6 and c.g < 0.35:
				head += 1
			elif c.g > 0.6 and c.b > 0.6 and c.r < 0.35:
				haft += 1
	return [head, haft]

## A plain ground and the farm camera's angle, aimed at the Hunter's chest.
func _stage(main: Node) -> Node3D:
	var holder := Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"),
			"horizon": Color("ffd2a8"), "stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	var cam := Camera3D.new()
	holder.add_child(cam)
	cam.fov = FOV
	cam.position = Vector3(0, 23.0 * sin(deg_to_rad(PITCH)), 23.0 * cos(deg_to_rad(PITCH))) + Vector3(0, AIM_Y, 0)
	cam.look_at(Vector3(0, AIM_Y, 0))
	cam.name = "Cam"
	cam.make_current()
	return holder
