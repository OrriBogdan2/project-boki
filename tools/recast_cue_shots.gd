extends RefCounted
## --recast-cue-shots --shots-dir=<dir>: the "<KEY> AGAIN" cue (scripts/ui/recast_cue.gd) in a live match HUD for three
## Hunters: Thief (E), Cinder (X), Albert (the hammer, LMB). One bottom-left HUD crop each.
## Needs a renderer (jobq --needs gpu).

const SHOTS := [
	["thief", "thief_e", "Shadow Knife stuck: E AGAIN on the E slot"],
	["ashwick", "ashwick_x", "Flue Flight: X AGAIN, ring shrinking with the flight"],
	["bulwark", "bulwark_lmb", "Hammer out: LMB AGAIN on a tile over the RMB slot"],
]
const CROP := Rect2i(0, 520, 760, 200)      # px of the viewport round the ability bar

var main: Node
var dir := "/tmp/recast_cue_shots"

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	for s in SHOTS:
		await _shot(String(s[0]), String(s[1]))
	print("RECASTSHOTS %d in %s" % [SHOTS.size(), dir])
	main.get_tree().quit(0)

func _shot(arch: String, file: String) -> void:
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	o.merge(Match.arena_opts(arch), true)
	var m := Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P.lvl = 6
	P.slot_lv["ult"] = 1
	var K: ArchKit = P.ak
	P.inp["aim"] = P.pos + Vector3(8, 0.9, 0)
	P.inp["aim_y"] = P.pos.y
	match arch:
		"thief": K.use_e()
		"ashwick":
			K.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)
		"bulwark":
			P.inp["fire"] = true
			for i in 6: m.step(1.0 / 60.0)
			P.inp["fire"] = false
	for i in 40:
		m.step(1.0 / 60.0)
		P.inp["aim"] = P.pos + Vector3(8, 0.9, 0)
		await main.get_tree().process_frame
	print("RECASTSHOTS %s left %.2f slot %s text '%s'" % [arch, K.recast_left(), K.recast_slot(), RecastCue.shown])
	var img := main.get_viewport().get_texture().get_image()
	var rg := CROP.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rg).save_png(dir.path_join(file + ".png"))
	img.save_png(dir.path_join(file + "_full.png"))
	m.queue_free()
	await main.get_tree().process_frame
