extends RefCounted
## --glider-canopy-shots --shots-dir=<dir>: the canopy's heat as other players see it (GliderHeat), in a live match
## under xvfb with a renderer. One Hunter glides across open ground at the match camera's closest zoom:
##   canopy_cool      no heat: the skin's own colours (reference)
##   canopy_warm      60% heat: the cloth warms toward ember
##   canopy_overheat  overheated on level air: full ember and a thin smoke trail
##   canopy_burning   overheated over the abyss, lifting at half strength: the cloth flickers
## <dir>/captions.txt gets "file: caption" per file.

const DT := 1.0 / 60.0

var main: Node
var m: Match
var P: Hunter
var dir := ""
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	await _state("canopy_cool", 1.0, false, "Cool glider (reference): the skin's own colours")
	await _state("canopy_warm", 0.4, false, "60% heat: the canopy warms toward ember")
	await _state("canopy_overheat", 0.0, false, "Overheated on level air: full ember and a thin smoke trail behind")
	await _state("canopy_burning", 0.0, true, "Overheated over the abyss, lifting at half strength: the cloth flickers")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("CANOPYSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	P = m.player
	m.opts["god"] = true
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		if h != P:
			h.ctrl = "idle"
			h.teleport(m.world.random_ground() + Vector3(0, 60, 0))
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)

## Glides P sideways (east, so a trail lies across the screen; the camera looks north) with the heat pinned for
## 1.5 s, then takes the shot.
func _state(file: String, fuel: float, lip: bool, caption: String) -> void:
	P.teleport(m.world.random_ground() + Vector3(0, 14, 0))
	P.grounded = false
	P.gliding = true
	P.vel = Vector3(9.0, 0, 0)
	for i in 90:
		P.inp["glide"] = true
		P.inp["move"] = Vector2(1, 0)
		P.glide_fuel = fuel
		m.step(DT)
		P.glide_fuel = fuel
		P.below_lip = lip
		m.cam.zoom = 0.5
		m.cam.snap(P.pos + Vector3(1.0, 1.0, -2.0))
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file + ".png"))
	lines.append("%s.png: %s" % [file, caption])
