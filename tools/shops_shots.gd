extends RefCounted
## Screenshots for --shops-check --shots-dir=<dir>: a vendor in the world, the shop panel, a
## purchase, and the full map with its legend. Run under xvfb with a renderer.

var main: Node
var m: Match
var dir := ""

func take(main_node: Node, out: String) -> void:
	main = main_node
	dir = out
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": 11, "no_drop": true})
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var p: Hunter = m.player
	var v: Dictionary = Shops.list(m)[0]
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	p.teleport(v["pos"] + Vector3(0, 0, 2.2))
	p.gems = 240
	p.armor = 12.0
	await _frames(30)
	await _shot("vendor_in_world")
	Shops.use(m, p, Shops.prompt(m, p))
	await _frames(20)
	await _shot("shop_panel")
	ShopPanel.buy_row(m, m.get_meta("shops")["panel"], v, 0)
	await _frames(8)
	await _shot("purchase")
	Shops.close(m)
	m.hud.full_map.open()
	await _frames(20)
	await _shot("full_map_legend")

func _frames(count: int) -> void:
	for i in count:
		m.step(1.0 / 60.0)
		m.cam.snap(m.player.pos)
		await main.get_tree().process_frame

func _shot(stem: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("shops_%s.png" % stem))
