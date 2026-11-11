extends RefCounted
## --loot-full-shots --shots-dir=<dir> [--size=WxH]: screenshots of looting with a full backpack (run under xvfb with a
## renderer). 1: a deathbox beside the hold window (your backpack, the clicked thing held in red, Swap and
## Drop). 2: the same box right after a swap. 3: a ground item's swap window with the red full outline.
## 4: a deathbox with gear (rarity names, better/worse arrows). <dir>/captions.txt gets "file: caption" per file.

var main: Node
var m: Match
var dir := "/tmp/loot_full_shots"
var captions: Array = []

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			main.get_tree().root.size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	var p: Hunter = m.player
	var q: Hunter = m.hunters.filter(func(x): return x != p)[0]
	p.pack_cap = 3
	p.pack = [Loot.valuable("kin_idol"), Loot.valuable("sky_pearl"), Loot.valuable("crown_shard")]
	var things: Array = [Loot.valuable("old_coin"), Loot.valuable("old_coin")]
	var bx: Dictionary = load("res://tools/loot_full_check.gd").make_box(q, p.pos + Vector3(1.0, 0, 0), things)
	bx["gems"] = 14
	m.boxes.append(bx)
	m.hud.open_loot(bx)
	await _frames(4)
	var row: Dictionary = Life.box_items(m, p, bx).filter(func(r): return r["key"] == "pack")[0]
	LootFull.click(m, p, bx, row)
	m.hud.open_hold(row)
	await _frames(6)
	await _shot("hold_window", "Deathbox with a full backpack: the box (things that do not fit outlined red), "
		+ "your backpack beside it, the clicked old coin held in red, Swap and Drop on each of yours")
	LootFull.swap_held(m, p, bx, int(row["i"]), 0)
	m.hud.close_loot()
	m.hud.open_loot(bx)
	await _frames(6)
	await _shot("after_swap", "After swapping: your Boki Idol is now in the box, the old coin in your backpack")
	m.hud.close_loot()
	m.spawn_val(Loot.valuable("old_coin"), p.pos + Vector3(0.6, 0, 0))
	m.hud.open_swap(m.wpicks[m.wpicks.size() - 1])
	await _frames(8)
	await _shot("ground_full", "A ground item with a full backpack: the incoming item outlined red above your things")
	p.pack_cap = 8
	p.gear[Gear.slot_on(p, "windstep_boots")] = {"id": "windstep_boots", "rar": 1}
	var gb: Dictionary = load("res://tools/loot_full_check.gd").make_box(q, p.pos, [Loot.valuable("sky_pearl")])
	gb["gems"] = 40
	gb["gear"] = [{"id": "windstep_boots", "rar": 4}, {"id": "windstep_boots", "rar": 0}]
	m.boxes.append(gb)
	m.hud.open_loot(gb)
	await _frames(8)
	await _shot("box_compare", "Deathbox with gear: names in rarity colour, slot and effect on one line, "
		+ "a green better or red worse arrow against what you wear (tip shows it), Take best key from Settings")
	m.hud.close_loot()
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for c in captions:
		f.store_line(c)
	f.close()
	print("LOOTFULLSHOTS %d in %s" % [captions.size(), dir])
	main.get_tree().quit(0)

func _frames(k: int) -> void:
	for i in k:
		await main.get_tree().process_frame

func _shot(file: String, caption: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	captions.append("%s.png: %s" % [file, caption])
