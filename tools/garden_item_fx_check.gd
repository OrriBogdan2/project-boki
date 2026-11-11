extends RefCounted
## --garden-item-fx-check: the moment on a Boki given a shaping item (GardenItemFx, GARDEN_MODERN.md 1.2-1.3),
## through the feed menu's own wiring (Home._after_feed):
##   1. Sunsap: one tick rising in gold; a stat bite plays nothing here and rises as its StatGlint icon instead
##   2. Keepstone: the path meter (one slot per token) with the new pip sliding into the first free slot in
##      Steadfast's tint, then the charm
##   3. Bramble Honey: the lean ring ends half full in Grass's colour; Rinse Melon drains a lean ring to empty
##   4. Stayleaf: the leaf and the lock; a second Stayleaf (can't be given) plays nothing
##   5. the pool: thirty gives make no node, every bit is hidden after GardenItemFx.LIFE and it stops processing
## --garden-item-fx-shots --shots-dir=<dir>: five Boki in a row each given one item at once (Sunsap, Keepstone,
## Bramble Honey, Rinse Melon, Stayleaf), three frames and item_fx_strip.png (them side by side). Never touches
## the real save.

const GIVE := ["sunsap", "keepstone", "bramble_honey", "rinse_melon", "stayleaf"]

var bad := 0
var main: Node
var home

func ok(cond: bool, what: String) -> void:
	print("ITEMFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node, mode: String = "check") -> void:
	main = m
	Save.no_write = true
	Save.d = _new_save()
	FarmTutorial.skip()
	home = await main._hb_home()
	for i in 600:
		if home.player != null and home.item_fx != null and home.kins.size() == GIVE.size():
			break
		await main.get_tree().process_frame
	home.day_t = 0.5
	for k in home.kins:
		k["busy"] = true      # (held by the check: no wandering off, napping or going indoors)
	await _frames(2)
	if mode == "shots":
		await _shots()
		return
	var fx: GardenItemFx = home.item_fx
	var k: Dictionary = home.kins[0]
	var rec: Dictionary = k["rec"]
	# 1. Sunsap, and a stat bite
	ok(_give(k, "sunsap") and fx.live.size() == 1 and fx.live[0]["c1"] == GardenItemFx.XP_GOLD,
		"Sunsap: one tick, in gold")
	var y0 := (fx.live[0]["mi"] as Node3D).global_position.y
	await _wait(0.5)
	ok((fx.live[0]["mi"] as Node3D).global_position.y > y0 + 0.3, "and it rises")
	await _settle(fx)
	while not home.stat_glint.glints.is_empty():
		await _frames(1)
	ok(not _give(k, "thumpnut") and fx.live.is_empty(), "Thumpnut: nothing from GardenItemFx ...")
	await _frames(2)
	var g: Array = home.stat_glint.glints
	ok(g.size() == 1 and g[0]["stats"] == ["power"], "... it rises as the Power glint (StatGlint)")
	# 2. Keepstone
	await _settle(fx)
	var slots := int(GardenItems.rules()["max_tokens"])
	var tint: Color = Evo.AFF["steadfast"]["tint"]
	ok(_give(k, "keepstone") and fx.live.size() == slots + 1, "Keepstone: %d meter slots and a charm" % slots)
	var pip: Dictionary = fx.live[0]
	ok(pip["c1"] == tint and pip["a"] != pip["b"], "the new pip is Steadfast's tint and slides")
	ok(fx.live[slots]["s0"] == Vector3.ZERO and fx.live[slots]["c1"] == tint, "the charm pops on, same tint")
	await _settle(fx)
	_give(k, "galeribbon")
	ok(fx.live[0]["c1"] == tint and fx.live[1]["c1"] == Evo.AFF["swift"]["tint"] and fx.live[1]["a"] != fx.live[1]["b"],
		"a second token: the Keepstone stays in slot 1, the Galeribbon slides into slot 2")
	# 3. the lean ring
	await _settle(fx)
	var grass: Color = Lean.face("grass")["tint"]
	rec["lean"] = {}
	ok(_give(k, "bramble_honey") and fx.live.size() == GardenItemFx.RING_SEGS, "Bramble Honey: the lean ring")
	ok(_count(fx, "c0", grass) == 0 and _count(fx, "c1", grass) == GardenItemFx.RING_SEGS / 2,
		"it fills from empty to half, in Grass's colour")
	await _settle(fx)
	ok(_give(k, "rinse_melon") and _count(fx, "c0", grass) == GardenItemFx.RING_SEGS / 2
		and _count(fx, "c1", GardenItemFx.DIM) == GardenItemFx.RING_SEGS, "Rinse Melon: the half ring drains to empty")
	await _wait(0.1)
	ok(fx.live.size() == GardenItemFx.RING_SEGS and is_instance_valid(fx.live[0]["k"]["node"]),
		"it keeps playing on the redrawn model")
	# 4. Stayleaf
	await _settle(fx)
	ok(_give(k, "stayleaf") and fx.live.size() == 2, "Stayleaf: the leaf and the lock")
	await _settle(fx)
	ok(not _give(k, "stayleaf") and fx.live.is_empty(), "a second Stayleaf can't be given: nothing plays")
	# 5. the pool
	await _settle(fx)
	var nodes := fx.get_child_count()
	for i in 30:
		var to: Dictionary = home.kins[i % home.kins.size()]
		to["rec"]["lean"] = {}
		_give(to, "bramble_honey")
	ok(fx.get_child_count() == nodes and nodes == GardenItemFx.POOL and fx.live.size() <= GardenItemFx.POOL,
		"thirty gives: still the %d pooled bits, no new node" % GardenItemFx.POOL)
	await _wait(GardenItemFx.LIFE + 0.1)
	var shown := fx.get_children().filter(func(n): return (n as Node3D).visible)
	ok(fx.live.is_empty() and shown.is_empty() and not fx.is_processing(), "after the moment: all hidden, idle")
	print("ITEMFX DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Gives one item the way the feed menu does (Care.feed, then Home._after_feed); true if a moment started.
func _give(k: Dictionary, id: String) -> bool:
	var res := Care.feed(k["rec"], id)
	home._after_feed(k, id, res)
	return res["ok"] and not home.item_fx.live.is_empty() and home.item_fx.is_processing()

func _count(fx: GardenItemFx, key: String, col: Color) -> int:
	return fx.live.filter(func(b): return b[key] == col).size()

func _new_save() -> Dictionary:
	var d := Save.fresh()
	for i in GIVE.size():
		var k := Save.new_kin(["zapple", "puddlet", "cindle", "burrlet", "zapple"][i], "B%d" % i)
		k["level"] = 5
		Care.ensure(k)
		for n in ["food", "energy", "clean", "joy"]: k["needs"][n] = 80.0
		d["roster"].append(k)
	d["roster"][3]["lean"] = {"fire": 8.0, "water": 6.0}      # (the one rinsed in the shots)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	HomeLayout.ensure(d)
	d["tutorial"]["home"] = true      # (after the island is made: no Welcome home panel over the shots)
	return d

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _wait(s: float) -> void:
	await main.get_tree().create_timer(s).timeout

## Until the moment has run out.
func _settle(fx: GardenItemFx) -> void:
	for i in 600:
		if fx.live.is_empty():
			return
		await main.get_tree().process_frame

# ------------------------------------------------------------------ shots
func _shots() -> void:
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots-dir="): dir = arg.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	if main.fade:
		main.fade.reveal(0.05)
	var at: Vector3 = home.YARD_KIN
	for i in home.kins.size():
		var k: Dictionary = home.kins[i]
		k["pos"] = at + Vector3(1.6 * (i - 2), 0, 0)
		k["goal"] = k["pos"]
		k["t"] = 30.0
		(k["node"] as Node3D).position = k["pos"]
		(k["node"] as Node3D).rotation.y = 0.0
	home.ppos = at + Vector3(0, 0, 4.0)      # (the player behind the camera, out of the way)
	home.player.position = home.ppos
	home.cam.zoom_to = 0.6
	home.cam.zoom = 0.6
	home.cam.snap(at)
	await _wait(0.8)
	for i in GIVE.size():
		Save.d["items"][GIVE[i]] = 1
		var res: Dictionary = GardenItems.use(home.kins[i]["rec"], GIVE[i], "grass")
		home._after_feed(home.kins[i], GIVE[i], res)
	var frames: Array = []
	for gap in [0.15, 0.25, 0.35]:      # s: frames at 0.15, 0.4 and 0.75 into the moment
		await _wait(gap)
		await RenderingServer.frame_post_draw
		var img: Image = main.get_viewport().get_texture().get_image()
		var file := dir.path_join("item_fx_%d.png" % (frames.size() + 1))
		img.save_png(file)
		print("ITEMFX SHOT %s live=%d" % [file, home.item_fx.live.size()])
		frames.append(img)
	var w: int = frames[0].get_width() / 2
	var h: int = frames[0].get_height() / 2
	var strip := Image.create(w * frames.size(), h, false, frames[0].get_format())
	for i in frames.size():
		var f: Image = frames[i]
		f.resize(w, h, Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(f, Rect2i(0, 0, w, h), Vector2i(w * i, 0))
	strip.save_png(dir.path_join("item_fx_strip.png"))
	print("ITEMFX STRIP %s" % dir.path_join("item_fx_strip.png"))
	main.get_tree().quit(0)
