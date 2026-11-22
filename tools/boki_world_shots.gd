extends "res://tools/vv_shots.gd"
## --boki-world-shots --shots-dir=<dir> [--species=a,b,c] [--tag=name]: a real expedition match (tier 0, the
## default map, two teams) with a wild Boki of each listed species placed beside the hero at match zoom. Writes
## <dir>/world_<species>.png (crop round the Boki), <dir>/world_sheet.png (all of them) and <dir>/world_report.txt:
## the model each Boki really loaded (BokiRig present, its .glb path) and how many wild Boki of each species the
## match's own spawn plan placed. Needs a renderer (jobq submit --needs gpu).

const CROP_PX := Vector2i(380, 300)
const ZOOM := 1.6
const COLS := 4

var species: Array = [
	"casquebill", "duskapi", "glaciyak", "heatherhorn", "kilnbadger", "moonloris", "velvorm", "tuatrune"
]


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--species="):
			species = Array(arg.substr(10).split(","))
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var rep := PackedStringArray()
	var natural := {}
	for k in m.kins:
		natural[k.species] = int(natural.get(k.species, 0)) + 1
	rep.append("wild Boki at match start: %d, species: %s" % [m.kins.size(), JSON.stringify(natural)])
	var crops: Array[Image] = []
	for sp in species:
		var rec := Save.new_kin(String(sp), "", m.kin_seed("world_shot"))
		var k: Kin = m.spawn_wild(rec, P.pos + Vector3(3.5, 0, 0))
		await _go(0.6)
		var rig := k.find_child("BokiRig", true, false)
		rep.append(
			"%s: rigged=%s glb=%s" % [sp, rig != null, BokiRig.PATH % [sp, sp] if rig != null else "primitive body"]
		)
		var img := main.get_viewport().get_texture().get_image()
		var c := _crop(img, k.position + Vector3(0, 0.45, 0), CROP_PX, ZOOM)
		c.save_png(dir.path_join("world_%s.png" % sp))
		crops.append(c)
		m.kins.erase(k)
		k.queue_free()
	if not crops.is_empty():
		var w := crops[0].get_width()
		var h := crops[0].get_height()
		var rows := (crops.size() + COLS - 1) / COLS
		var sheet := Image.create(w * mini(COLS, crops.size()), h * rows, false, Image.FORMAT_RGB8)
		for i in crops.size():
			var at := Vector2i((i % COLS) * w, (i / COLS) * h)
			sheet.blit_rect(crops[i], Rect2i(Vector2i.ZERO, crops[i].get_size()), at)
		sheet.save_png(dir.path_join("world_sheet.png"))
	var f := FileAccess.open(dir.path_join("world_report.txt"), FileAccess.WRITE)
	f.store_string("\n".join(rep) + "\n")
	f.close()
	print("BOKIWORLD ", "\n".join(rep))
	main.get_tree().quit(0)


func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	home = P.pos
