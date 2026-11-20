extends RefCounted
## --hurtbox-shots --shots-dir=<dir>: three Hunters (the smallest, a medium, a big one) side on with their
## hurtbox drawn over them: a red cylinder of radius hit_r + Match.HIT_SLACK up to hit_h, a yellow disc at
## the top of the shot band, a blue ring for the body's collision radius. Writes <dir>/hurtbox.png
## (run under xvfb with a renderer).

const DT := 1.0 / 60.0
const PICK := ["tender", "gunslinger", "dredge"]
const GAP := 2.2       # m between neighbours
const DISC := 0.02     # m, thickness of the flat markers
const BAND_PAD := 0.9  # m over the head the shot band reaches (Match.shot_band)

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for b in m.breaks: b["dead"] = true
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	var home := _flat_spot(m.world)
	var row: Array = []
	for i in PICK.size():
		var a: String = PICK[i]
		var at := home + Vector3((float(i) - 1.0) * GAP, 0, 0)
		var h := m.make_hunter("S%d" % i, i + 1, Arch.weight(a), Arch.bare_title(a), "idle", {}, at, {"arch": a})
		h.face = PI
		row.append(h)
		_overlay(h)
	m.player.teleport(home + Vector3(0, 0, 30))
	if m.hud: m.hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 30.0
	main.add_child(cam)
	cam.make_current()
	cam.look_at_from_position(home + Vector3(0, 1.5, 12.0), home + Vector3(0, 1.3, 0), Vector3.UP)
	for k in 20:
		m.step(DT)
		for h in row:
			h.teleport(h.pos)
			h.vel = Vector3.ZERO
		for h in m.hunters: h.render(DT, 1.0)
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("hurtbox.png"))
	var names := []
	for h in row: names.append("%s r %.3f h %.2f" % [Arch.bare_title(h.arch), h.hit_radius(), Arch.hit_h(h.arch)])
	print("HURTBOXSHOTS ", ", ".join(names), " ", dir)
	main.get_tree().quit(0)

## Red cylinder (hurtbox), yellow disc (top of the shot band) and blue ring (body collision) on the hunter.
func _overlay(h: Hunter) -> void:
	var hr := h.hit_radius()
	var ht := Arch.hit_h(h.arch)
	_add(h, _cyl(hr, ht), Color(1, 0.15, 0.1, 0.28), ht * 0.5)
	_add(h, _cyl(hr, DISC), Color(1, 0.9, 0.1, 0.45), ht + BAND_PAD)
	_add(h, _cyl(h.hull_r(), DISC), Color(0.2, 0.5, 1, 0.8), 0.03)

func _cyl(r: float, ht: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = ht
	c.radial_segments = 48
	return c

func _add(h: Hunter, mesh: Mesh, col: Color, y: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Vector3(0, y, 0)
	h.add_child(mi)

func _flat_spot(W: World) -> Vector3:
	for z in range(8, W.h - 8, 3):
		for x in range(14, W.w - 24, 3):
			if _flat(W, x, z):
				return Vector3(x + 0.5, int(W.level[W.idx(x, z)]) * World.LEVEL, z + 0.5)
	return Vector3.ZERO

func _flat(W: World, x: int, z: int) -> bool:
	var lv: int = int(W.level[W.idx(x, z)])
	for dz in range(-3, 8):
		for dx in range(-9, 10):
			var i: int = W.idx(x + dx, z + dz)
			var odd: bool = W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i) or W.bush.has(i)
			if W.kind[i] != World.T_GROUND or int(W.level[i]) != lv or odd:
				return false
	return true
