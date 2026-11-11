extends RefCounted
## --hawk-sense-shots: review screenshots of Lace's Hawk Sense (HawkSense) in a live match (xvfb with a
## renderer), into --shots-dir=<dir>. A rival stands just behind one of the map's rocks, seen from Lace's camera
## 6 m to the south: at full health they are hidden; under the health line they are revealed and their outline
## in Lace's colour shows through the rock. Each as the full frame and a 3x crop round the rock. Never touches
## the save.

const BACK := 6               # tiles south of the rock Lace stands (the camera looks north over her)
const CROP := Vector2i(220, 160)   # px round the rock, scaled 3x

var main: Node
var m: Match
var dir := "user://shots"

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Settings.set_v("tips", false)      # (the kit card would cover the view)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true, "arch": "archer",
		"cls": Arch.weight("archer"), "weapon": Arch.signature("archer")})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	m.cam.lead = 0.0
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P := m.player
	var foe: Hunter = m.hunters.filter(func(o): return o.team != P.team)[0]
	foe.ctrl = "idle"
	var rock := _rock_near(P.pos)
	print("HAWKSHOTS rock at %s" % rock)
	P.teleport(rock + Vector3(0, 0, BACK))
	foe.teleport(rock + Vector3(0, 0, -1.0))
	foe.face = 0.0
	P.inp["aim"] = rock + Vector3(0, 0.9, 0)
	for label in ["healthy", "injured"]:
		foe.hp = foe.max_hp * (1.0 if label == "healthy" else 0.4)
		var img := await _frame()
		var sensed := (P.ak as ArcherKit).sense.senses(foe)
		print("HAWKSHOTS %s: sensed %s, drawn %s, hidden by sight %s" % [label, sensed, foe.visible, foe.unseen])
		img.save_png(dir.path_join("hawk_%s.png" % label))
		var c := Vector2i(m.cam.unproject_position(rock + Vector3(0, 0.8, 0)) * Vector2(img.get_size())
			/ main.get_viewport().get_visible_rect().size)
		var crop := img.get_region(Rect2i(c - CROP / 2, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		crop.resize(CROP.x * 3, CROP.y * 3, Image.INTERPOLATE_LANCZOS)
		crop.save_png(dir.path_join("hawk_%s_zoom.png" % label))
	main.get_tree().quit(0)

## The foot of the map's nearest rock with open ground on the same level a step north (where the rival hides)
## and BACK tiles south (where Lace stands).
func _rock_near(at: Vector3) -> Vector3:
	var W: World = m.world
	var best := at
	var best_d := INF
	for z in range(1, W.h - BACK - 1):
		for x in W.w:
			var i := W.idx(x, z)
			var foot := Vector3(x + 0.5, W.level[i] * World.LEVEL, z + 0.5)
			if W.kind[i] != World.T_BLOCK or W.props.has(i) or W.walls.has(i) or foot in W.tree_spots:
				continue
			if not (_open(foot + Vector3(0, 0, -1)) and _open(foot + Vector3(0, 0, BACK))):
				continue
			if foot.distance_to(at) < best_d:
				best = foot
				best_d = foot.distance_to(at)
	return best

func _open(p: Vector3) -> bool:
	var i := m.world.idx(int(p.x), int(p.z))
	return m.world.kind[i] == World.T_GROUND and absf(m.world.ground_at(p.x, p.z) - p.y) < 0.3

## About a second of live frames, then the frame as an image.
func _frame() -> Image:
	for i in 60:
		await main.get_tree().process_frame
	return main.get_viewport().get_texture().get_image()
