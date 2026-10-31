extends Node3D
## Match props side by side under the match's sky and light: chests (the vault one open), the
## breakables, a camp's supplies, a deathbox, the shrine, nest, portal, jump pad and pickups.
## Run with -- --prop-gallery (or open tests/prop_gallery.tscn and press F6); --prop-close frames
## the loot props up close, --prop-sets the set pieces (dock, skiff, hatch, uplink, lair gate, dial).
## Use with --shot / --frames. --art1 shows the first art pass's props.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var T: Dictionary = Data.TIERS[0]
	var env := WorldEnvironment.new()
	var sky: Color = T["sky"]; var amb: Color = T["ambient"]; var cl: Array = T["clouds"]
	env.environment = Look.environment({"top": sky.darkened(0.2), "mid": sky.lerp(amb, 0.35), "horizon": (cl[1] as Color).lerp(T["sun"], 0.5).lightened(0.15),
		"below": cl[0], "ambient": amb, "ambient_energy": 0.5, "fog": (cl[1] as Color).lightened(0.12).lerp(Color("4a5aa8"), 0.35), "sun_col": T["sun"]})
	add_child(env)
	var sun := Look.lights(self, T["sun"], 1.0, Vector3(-55, -35, 0), 60.0)
	sun.shadow_opacity = 0.8
	RenderingServer.global_shader_parameter_set("vis_on", 0.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(60, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("6f9a52"); gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	var items: Array
	var gap := 2.0
	var cam_at := Vector3(0, 6.5, 9.5)
	if "--prop-sets" in args:
		var gate := BossModels.gate(3.0, Color("ffd36a")); Flora.paint_set_piece(gate)
		var dial := BossModels.dial_stone(Color("ffd36a")); Flora.paint_set_piece(dial)
		items = [ExitModels.dock(Vector3(2.6, 0, 2.2)), ExitModels.skiff(), ExitModels.hatch(), ExitModels.uplink(), gate, dial, Models.shrine()]
		gap = 5.4
		cam_at = Vector3(0, 17.0, 27.0)
	else:
		var rng := RandomNumberGenerator.new(); rng.seed = 3
		items = [Models.chest(0), Models.chest(1), Models.chest(2), Models.breakable("crate"), Models.breakable("barrel"), Models.breakable("pot"), Models.deathbox(Color("6ad8ff"))]
		if Flora.v2():
			items.append(PropSculpt.camp(rng))
		if not "--prop-close" in args:
			items.append_array([Models.shrine(), Models.nest(), Models.portal(Color("8fe3c8")), Models.jump_pad(Color("ffd25a")), Models.gem(), Models.tonic()])
			gap = 2.6
			cam_at = Vector3(0, 9.0, 15.0)
	var t0 := Time.get_ticks_usec()
	for i in items.size():
		var n: Node3D = items[i]
		n.position = Vector3((i - (items.size() - 1) * 0.5) * gap, 0, 0)
		add_child(n)
	print("PROPS built and added in %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	if not "--prop-sets" in args:
		(items[2].get_node("Body/Lid") as Node3D).rotation.x = 1.9
		(items[0].get_node("Body/Lid") as Node3D).rotation.x = 0.6
	var cam := Camera3D.new()
	cam.position = cam_at
	cam.fov = 40
	add_child(cam)
	cam.look_at(Vector3(0, 0.5, 0))
	cam.make_current()
