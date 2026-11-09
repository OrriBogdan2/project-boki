extends Node3D
## Every kin species side by side, glowing as they do when they're out in a fight. Open
## tests/kin_gallery.tscn and press F6 to look at them (or to check a new kin you added in content/kin),
## or start the game with -- --kin-gallery (how GPU jobs run it).
## --kin-wisps: the Model Room's Boki wisps (BokiWispLook), each bouncing in front of its Boki, for the
## WISP_ROOM species; add --kin-shiny for their shiny colours. Use with --shot / --frames.

## The starters, the mystery egg's Ermink, and six more with a spread of ears, horns, crests and tails.
const WISP_ROOM := ["cindle", "puddlet", "burrlet", "ermink", "zapple", "wisplet", "pebbit", "kestrike",
	"kindlewren", "heatherhorn"]
const WISP_SHOW_SCALE := 1.8   # the wisps shown bigger than in a match so their outlines read from the camera
const WISP_AHEAD := Vector3(0, 0.75, 0.95)   # m from its Boki: in front of it, about at its head

var _wisps: Array = []
var _clock := 0.0

func _ready() -> void:
	_stage()
	var args := OS.get_cmdline_user_args()
	var ids: Array = Data.KIN.keys()
	var show_wisps := "--kin-wisps" in args
	if show_wisps:
		ids = WISP_ROOM.filter(func(id): return Data.KIN.has(id))
		var missing := WISP_ROOM.filter(func(id): return not ids.has(id))
		print("KIN GALLERY wisps of %d, not in this build: %s" % [ids.size(), str(missing)])
	for a in args:
		if a.begins_with("--kin-only="):
			ids = Array(a.substr(11).split(","))
	var close := "--kin-close" in args
	var rec := {"level": 6, "shimmer": "--kin-shiny" in args}
	var yaw := 0.0
	for a in args:
		if a.begins_with("--kin-yaw="):
			yaw = float(a.substr(10))
	for i in ids.size():
		var k := Models.kin(String(ids[i]), rec)
		k.position = Vector3((i - (ids.size() - 1) * 0.5) * 1.6, 0, 0)
		k.rotation.y = PI + 0.35 + yaw
		k.scale = Vector3.ONE * 1.3
		add_child(k)
		var shell: MeshInstance3D = k.get_node_or_null("Body/Shell")
		if shell and not close:
			shell.visible = true
			(shell.material_override as ShaderMaterial).set_shader_parameter("strength", 0.6)
		var pt: CPUParticles3D = k.get_node_or_null("Aura")
		if pt:
			pt.emitting = true
		var ring := MeshInstance3D.new()
		ring.mesh = Models.flat_quad(1.4)
		ring.material_override = Models.ring_mat(Color(Data.TEAM_COLORS[0], 0.85), 0.16)
		ring.position = k.position + Vector3(0, 0.03, 0)
		add_child(ring)
		var l := Label3D.new()
		l.text = String(Data.KIN[ids[i]]["name"])
		l.font_size = 48
		l.pixel_size = 0.005
		l.position = k.position + Vector3(0, 1.45, 0)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(l)
		if show_wisps:
			_add_wisp(String(ids[i]), rec, k)
	_camera(close, ids.size() if show_wisps else 0)
	set_process(show_wisps)

## Started from Main by --kin-gallery (CheckRegistry): stands in for the title screen.
func run(main: Node) -> void:
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.add_child(self)

func _process(dt: float) -> void:
	_clock += dt
	for w in _wisps:
		BokiWispLook.pose(w, _clock)

func _stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1b2030")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b9c4e6")
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 12)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("5f8d45"), false)
	add_child(ground)

func _add_wisp(species: String, rec: Dictionary, kin: Node3D) -> void:
	var w := BokiWispLook.build(species, rec)
	w.position = kin.position + WISP_AHEAD
	w.rotation.y = kin.rotation.y
	w.scale = Vector3.ONE * WISP_SHOW_SCALE
	add_child(w)
	_wisps.append(w)

## The gallery camera; with a row of wisps it stands back far enough to frame them all.
func _camera(close: bool, wisp_row: int) -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 4.2, 6.5)
	cam.rotation = Vector3(-0.55, 0, 0)
	cam.fov = 50
	if close:
		cam.position = Vector3(0, 1.6, 4.4)
		cam.rotation = Vector3(-0.22, 0, 0)
		cam.fov = 62
	elif wisp_row > 0:
		cam.position = Vector3(0, 3.2, 1.6 + wisp_row * 0.85)
		cam.rotation = Vector3(-0.3, 0, 0)
	add_child(cam)
	cam.make_current()
