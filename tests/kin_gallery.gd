extends Node3D
## Every kin species side by side, glowing as they do when they're out in a fight. Open
## tests/kin_gallery.tscn and press F6 to look at them (or to check a new kin you added in content/kin),
## or start the game with -- --kin-gallery (how GPU jobs run it).
## --kin-wisps: the Model Room's Boki wisps (BokiWispLook), each bouncing over its Boki, for the
## WISP_ROOM species; add --kin-shiny for their shiny colours. Use with --shot / --frames.
## --kin-pop: the Model Room's ten wisps; each wisp bursts into its Boki and folds back, on a loop (BokiWispPop).
## --kin-pop-strip[=back]: one species (--kin-only=<id>) frozen at STRIP_STEPS moments of the burst (or fold).

## The starters, the mystery egg's Ermink, and six more with a spread of ears, horns, crests and tails.
const WISP_ROOM := ["cindle", "puddlet", "burrlet", "ermink", "zapple", "wisplet", "pebbit", "kestrike",
	"kindlewren", "heatherhorn"]
const WISP_SHOW_SCALE := 2.4   # the wisps shown bigger than in a match so their outlines read from the camera
const WISP_ABOVE := 2.2        # m; each wisp floats over its Boki's name
const POP_LOOP := 3.0          # s per loop: wisp, burst at 1 s, Boki, fold at 2 s
const STRIP_STEPS := 6         # frames across one burst or fold

var _wisps: Array = []
var _pops: Array = []
var _clock := 0.0

func _ready() -> void:
	_stage()
	var args := OS.get_cmdline_user_args()
	var ids: Array = Data.KIN.keys()
	var strip := ""
	for a in args:
		if a.begins_with("--kin-pop-strip"):
			strip = a.substr(16) if a.length() > 16 else "burst"
	var show_pop := "--kin-pop" in args or strip != ""
	var show_wisps := "--kin-wisps" in args or show_pop
	if show_wisps:
		ids = WISP_ROOM.filter(func(id): return Data.KIN.has(id))
		var missing := WISP_ROOM.filter(func(id): return not ids.has(id))
		print("KIN GALLERY wisps of %d, not in this build: %s" % [ids.size(), str(missing)])
	for a in args:
		if a.begins_with("--kin-only="):
			ids = Array(a.substr(11).split(","))
	if strip != "":
		ids = ids.slice(0, 1)
		ids.resize(STRIP_STEPS)
		ids.fill(ids[0])
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
		if shell and not close and not show_wisps:      # round glows would muddle round = Hunter, critter = Boki
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
		if show_pop:
			k.visible = false
			_add_pop(String(ids[i]), rec, k, strip, float(i) / (STRIP_STEPS - 1))
		elif show_wisps:
			_add_wisp(String(ids[i]), rec, k)
	_camera(close, ids.size() if show_wisps else 0)
	set_process(show_wisps and strip == "")

## Started from Main by --kin-gallery (CheckRegistry): stands in for the title screen.
func run(main: Node) -> void:
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.add_child(self)

func _process(dt: float) -> void:
	_clock += dt
	for w in _wisps:
		BokiWispLook.pose(w, _clock)
	var at := fposmod(_clock, POP_LOOP)
	for p in _pops:
		var pop: BokiWispPop = p
		if not pop.out and at >= 1.0 and at < 2.0:
			pop.play(true)
		elif pop.out and at >= 2.0:
			pop.play(false)

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
	w.position = kin.position + Vector3(0, WISP_ABOVE, 0)
	w.rotation.y = kin.rotation.y
	w.scale = Vector3.ONE * WISP_SHOW_SCALE
	add_child(w)
	_wisps.append(w)

## The wisp and its Boki as one BokiWispPop over the Boki's spot. strip "" loops it; otherwise it is frozen
## at `along` (0..1) of a "burst" or "back" (fold).
func _add_pop(species: String, rec: Dictionary, kin: Node3D, strip: String, along: float) -> void:
	var pop := BokiWispPop.new(species, rec)
	pop.position = kin.position + Vector3(0, WISP_ABOVE, 0)
	pop.rotation.y = kin.rotation.y
	pop.stand = Vector3(0, -WISP_ABOVE, 0)
	pop.wisp_k = WISP_SHOW_SCALE
	pop.form_k = kin.scale.x
	add_child(pop)
	if strip == "":
		_pops.append(pop)
	else:
		pop.pose(along, strip == "burst")

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
		cam.position = Vector3(0, 2.0, 1.6 + wisp_row * 0.85)
		cam.rotation = Vector3(-0.07, 0, 0)
	add_child(cam)
	cam.make_current()
