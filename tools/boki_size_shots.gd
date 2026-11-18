extends "res://tools/vv_shots.gd"
## --boki-size-shots --shots-dir=<dir> [--species=a,b,c] [--no-fit]: each listed Boki, an average-sized one, stands
## next to Vex on the arena's flat ground at the match camera. Writes <dir>/size_<species>.png: a crop round the pair,
## the same scale for every Boki. --no-fit draws them at the rig frame's own size (the data's "fit" left out).
## Needs a renderer (jobq submit --needs gpu).

const CROP_PX := Vector2i(200, 160)
const ZOOM := 2.5
const GAP := 0.8            # m between Vex and the Boki, along x
const LEVEL := 20           # past the hatchling shrink (level < 4) and any form scale

var species: Array = ["velvorm", "duskapi"]
var no_fit := false


func run(main_node: Node) -> void:
	main = main_node
	who = "gunslinger"
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--species="):
			species = Array(arg.substr(10).split(","))
		if arg == "--no-fit":
			no_fit = true
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	for sp in species:
		if no_fit:
			Unique.base_size(String(sp))["fit"] = 1.0
		var rec := Save.new_kin(String(sp), "", 1)
		rec["level"] = LEVEL
		var dna := Unique.roll(1)
		dna["size"] = 0.0
		rec["dna"] = dna
		var k: Kin = m.spawn_wild(rec, P.pos + Vector3(GAP, 0, 0))
		await _go(0.6)
		var img := main.get_viewport().get_texture().get_image()
		var mid := (P.pos + k.global_position) * 0.5 + Vector3(0, 0.9, 0)
		_crop(img, mid, CROP_PX, ZOOM).save_png(dir.path_join("size_%s.png" % sp))
		m.kins.erase(k)
		k.queue_free()
	print("BOKISIZE %d shots in %s" % [species.size(), dir])
	main.get_tree().quit(0)

