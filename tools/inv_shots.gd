extends RefCounted
## --inv-shots --shots-dir=<dir>: the in-match inventory at whatever resolution the window has (run
## under xvfb with a renderer, --resolution WxH). inv_pack: the backpack window with a full loadout;
## inv_loot: a deathbox with gear beside it; inv_tip: the compare tooltip on a hovered backpack piece
## (only when the loadout window offers hover_demo). Files carry the viewport height in their name.

var main: Node
var captions: Array = []
var dir := "/tmp/inv_shots"

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	var p: Hunter = m.player
	var q: Hunter = m.hunters.filter(func(x): return x != p)[0]
	dress(p)
	m.hud.toggle_pack()
	await _frames(8)
	var tag := "%dp" % int(main.get_viewport().get_visible_rect().size.y)
	await _shot("inv_pack_" + tag, "Backpack window with a full loadout")
	var lp = m.hud.pack_panel
	if lp.has_method("hover_demo"):
		lp.call("hover_demo", "pack", 0)
		await _frames(8)
		await _shot("inv_tip_" + tag, "Compare tooltip on a backpack piece: only the changed numbers")
	m.hud.toggle_pack()
	var bx: Dictionary = load("res://tools/loot_full_check.gd").make_box(q, p.pos + Vector3(1.0, 0, 0), [])
	bx["gear"] = [{"id": "vest", "rar": 3}, {"id": "skylark_boots", "rar": 2}]
	bx["pack"] = [Loot.valuable("old_coin")]
	bx["gems"] = 14
	m.boxes.append(bx)
	m.hud.open_loot(bx)
	await _frames(10)
	await _shot("inv_loot_" + tag, "A deathbox with your loadout beside it")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for c in captions:
		f.store_line(c)
	f.close()
	print("INVSHOTS %d in %s" % [captions.size(), dir])
	main.get_tree().quit(0)

## A hunter in a full loadout: two gloves, armor, boots, belt items, a few perks and a half-full pack.
static func dress(p: Hunter) -> void:
	p.gear = [{"id": "power_core", "rar": 2}, {"id": "frost", "rar": 1}, {"id": "quilted_coat", "rar": 1},
		{"id": "boots", "rar": 1}]
	p.perks = ["keen", "keen", "toughskin", "fleet"]
	UtilityBelt.grant(p, "medkit", 2)
	UtilityBelt.grant(p, "smoke", 1)
	p.refresh_gear()
	p.pack_cap = 6
	p.pack = [Loot.gear("vest", 3), Loot.gear("blink", 2), Loot.gear("windstep_boots", 1), Loot.valuable("kin_idol"),
		Loot.valuable("sky_pearl")]

func _frames(k: int) -> void:
	for i in k:
		await main.get_tree().process_frame

func _shot(file: String, caption: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	captions.append("%s.png: %s" % [file, caption])
