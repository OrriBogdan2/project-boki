extends RefCounted
## --hawk-sense-shots: review screenshots of Lace's Hawk Sense (HawkSense) in a live match (xvfb with a
## renderer), into --shots-dir=<dir>. A rival stands just behind a boulder (the map's rock mesh, solid in the
## map data), seen from Lace's camera 5 m to the south: at full health they are hidden; under the health line
## they are revealed and their outline in Lace's colour shows through the rock. Each as the full frame and a
## 3x crop round the rock. Never touches the save.

const BACK := 5               # tiles south of the rock Lace stands (the camera looks north over her)
const ROCK_SIZE := 1.6         # the boulder's scale (the map's run 0.8 to 2.2)
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
	var rock := _rock_near(P.pos)
	print("HAWKSHOTS rock at %s" % rock)
	P.teleport(rock + Vector3(0, 0, BACK))
	P.vel = Vector3.ZERO
	P.inp["aim"] = rock + Vector3(0, 0.9, 0)
	for label in ["healthy", "injured"]:
		var img := await _frame(foe, rock + Vector3(0, 0, -1.0), 1.0 if label == "healthy" else 0.4)
		var sensed := (P.ak as ArcherKit).sense.senses(foe)
		print("HAWKSHOTS %s: sensed %s, drawn %s, hidden by sight %s" % [label, sensed, foe.visible, foe.unseen])
		img.save_png(dir.path_join("hawk_%s.png" % label))
		var c := Vector2i(m.cam.unproject_position(rock + Vector3(0, 0.8, -1.0)) * Vector2(img.get_size())
			/ main.get_viewport().get_visible_rect().size)
		var crop := img.get_region(Rect2i(c - CROP / 2, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		crop.resize(CROP.x * 3, CROP.y * 3, Image.INTERPOLATE_LANCZOS)
		crop.save_png(dir.path_join("hawk_%s_zoom.png" % label))
	main.get_tree().quit(0)

## Puts a boulder on open ground north of `at` and returns its foot, with room on the same level a step behind
## it and BACK tiles in front.
func _rock_near(at: Vector3) -> Vector3:
	var W: World = m.world
	for dx in [0, 2, -2, 4, -4, 6, -6]:
		var foot := Vector3(floorf(at.x) + dx + 0.5, at.y, floorf(at.z) - BACK + 0.5)
		if range(-1, BACK + 1).all(func(dz): return _open(foot + Vector3(0, 0, dz))):
			var i := W.idx(int(foot.x), int(foot.z))
			var wk: PackedByteArray = W.kind
			wk[i] = World.T_BLOCK
			W.kind = wk
			var rock := Flora.node("rock", W.style_at(i), 0, ROCK_SIZE)
			rock.position = foot
			W.add_child(rock)
			return foot
	return at + Vector3(0, 0, -BACK)

func _open(p: Vector3) -> bool:
	var i := m.world.idx(int(p.x), int(p.z))
	return m.world.kind[i] == World.T_GROUND and absf(m.world.ground_at(p.x, p.z) - p.y) < 0.3

## About a second of live frames with `foe` held at `spot` and `hp_k` of their health (a bot walks off and
## fights back), then the frame as an image.
func _frame(foe: Hunter, spot: Vector3, hp_k: float) -> Image:
	for i in 60:
		foe.ctrl = "idle"
		foe.teleport(spot)
		foe.face = 0.0
		foe.hp = foe.max_hp * hp_k
		await main.get_tree().process_frame
	return main.get_viewport().get_texture().get_image()
