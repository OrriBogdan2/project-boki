extends "res://tools/vv_shots.gd"
## --recast-marker-shots --shots-dir=<dir>: the recast world marker (scripts/ui/recast_marker.gd) in a live
## Arena match, once per kit: Tenzo's Rock Hop skid, Neve's sliding Rink Wall, Sparkle hanging in Kitefall and
## Cinder in Flue Flight. A full frame and a close-up each (needs a renderer: GPU).

const HEROES := ["dolm", "rimewright", "mage", "ashwick"]
const FAR := 14.0               # m to the target: past every reach, so the cursor is the limit

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	for id in HEROES:
		who = id
		hero_name = id
		await _setup()
		await _reset(FAR)
		P.lvl = 6
		await Callable(self, "_" + id).call()
		m.queue_free()
		await main.get_tree().process_frame
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(String(l).get_slice("|", 1) + ": " + String(l).get_slice("|", 2))
	f.close()
	print("RMSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _mark(file: String, caption: String, at: float) -> Array:
	return [[at, "full", file, caption]]

func _dolm() -> void:
	var press := func(t: float):
		if t < DT:
			P.ak.on_dash(false)
	var caption := "Tenzo: the skid between hops, a Shift marker on the next landing spot"
	await _go(0.7, press, _mark("hop", caption, 0.5))

func _rimewright() -> void:
	var press := func(t: float): P.inp["sig"] = t < 0.05
	var caption := "Neve: the Rink Wall slides toward the cursor, an E marker on it to freeze it"
	await _go(0.8, press, _mark("wall", caption, 0.5))

func _mage() -> void:
	P.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	await _go(1.8, Callable(), _mark("kitefall", "Sparkle: hanging in Kitefall, a marker on the crash point", 1.1))

func _ashwick() -> void:
	P.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	var caption := "Cinder: Flue Flight, a marker on the ground under her for an early landing"
	await _go(1.0, Callable(), _mark("flight", caption, 0.6))
