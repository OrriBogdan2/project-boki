extends RefCounted
## --build-ui-shots=<dir>: screenshots of the shared build and decorate UI (run with a real renderer, e.g.
## xvfb-run with --rendering-driver opengl3): the farm catalog, the ghost green and red with its reason, the
## piece menu, the rotate animation strip, the empty new house and the Storage tab. Never touches the real save.

var main: Node
var dir := ""
var hm = null            # the home screen being shot, if any

func _settle(frames := 3) -> void:
	for i in frames: await main.get_tree().process_frame

func _prep() -> void:
	await _settle()
	if main.fade: main.fade.reveal(0.05)
	await main.get_tree().create_timer(0.35).timeout
	if hm:
		hm._close_panel()
		if hm.guide and hm.guide.tracker: hm.guide.tracker.visible = false
		if hm.guide and hm.guide.hint_box: hm.guide.hint_box.visible = false
		hm.set_process(false)
		if hm.hover_box: hm.hover_box.visible = false
		hm.prompt_box.visible = false
	await _settle(2)

func _grab() -> Image:
	return main.get_viewport().get_texture().get_image()

func _shot(shot_name: String, caption: String) -> void:
	await _prep()
	_grab().save_png("%s/%s.png" % [dir, shot_name])
	if hm: hm.set_process(true)
	print("BUSHOT %s|%s" % [shot_name, caption])

func _mouse_at(world: Vector3, cam: Camera3D) -> void:
	main.get_viewport().warp_mouse(cam.unproject_position(world))

func _farm_save() -> void:
	var d := Save.fresh()
	var kin := Save.new_kin("zapple", "Pip")
	kin["starter"] = true
	d["roster"].append(kin)
	d["active"] = kin["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	Save.d["gems"] = 900
	Save.d["stats"] = {"extracts": 10, "bosses": 3, "caught": 10, "harvested": 400, "hatched": 6, "fb_built": 0}
	Save.d["extracts"] = 10
	Save.d["matches"] = 1
	Save.d["mats"] = {"wood": 40, "stone": 30, "fibre": 20}

func _spot(hb: HomeBuild, p: Vector3, skip := 0) -> Array:
	var foot := HomeLayout.size_of(String(hb.held["id"]), int(hb.held["r"]))
	var seen := 0
	for rad in 22:
		for k in 48:
			var a := float(k) / 48.0 * TAU
			var x := int(round(p.x + cos(a) * rad - foot.x * 0.5))
			var z := int(round(p.z + sin(a) * rad - foot.y * 0.5))
			var cs := HomeLayout.cells_of([x, z, x + foot.x - 1, z + foot.y - 1])
			if hb.fits(hb.held, cs):
				if seen == skip:
					return cs
				seen += 1
	print("BUSHOT no spot: %s %s held=%s" % [hb.why, p, str(hb.held)])
	return []

func _put(hb: HomeBuild, cs: Array) -> void:
	hb.cells = cs
	hb._check_cells()
	hb.place_held()

func _look(home, target: Vector3, zoom: float) -> void:
	var p := target + Vector3(0, 0, 3.0)
	home.ppos = p
	home.player.position = p
	home.cam.zoom_to = zoom
	home.cam.zoom = zoom
	home.cam.snap(p)

## The ground point under a screen position.
func _ground_at(screen: Vector2) -> Vector3:
	var cam: Camera3D = hm.cam
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	return from + dir * (-from.y / dir.y)

## Ghost, card and menu with the cursor at a screen position near an edge.
func _edges(hb: HomeBuild, rug_e: Dictionary) -> void:
	var vp := main.get_viewport().get_visible_rect().size
	var spots := {"bottom": Vector2(vp.x * 0.45, vp.y - 175.0), "right": Vector2(vp.x - 60.0, vp.y * 0.45)}
	for edge in spots:
		var ground := _ground_at(spots[edge])
		hb.take("rug_long")
		await _settle()
		var cs := _spot(hb, ground)
		var cell := Vector2(cs[0].x + 1.5, cs[0].y + 1.0)
		_hover(hb, cell)
		main.get_viewport().warp_mouse(spots[edge])
		await _shot("10_green_%s_edge" % edge, "Green ghost, cursor at the %s edge: the card flips clear" % edge)
		hb._cancel_held()
		var bc: Vector2i = HomeLayout.deco_cells(rug_e)[0]
		var rug_at := Vector3(bc.x + 1.0, 0, bc.y + 1.0)
		var shift := rug_at - _ground_at(spots[edge])
		var centre := _ground_at(vp * 0.5)
		_look(hm, centre + shift - Vector3(0, 0, 3.0) + Vector3(0, 0, 3.0), 1.0)
		await _settle(4)
		hb.take("rug")
		await _settle()
		_hover(hb, Vector2(rug_at.x, rug_at.z))
		print("BUSHOT rug on screen %s want %s" % [hm.cam.unproject_position(rug_at), spots[edge]])
		await _shot("11_red_%s_edge" % edge, "Blocked ghost on the rug at the %s edge" % edge)
		hb._cancel_held()
		_hover(hb, Vector2(rug_at.x, rug_at.z))
		hb.open_menu("d:%d" % int(rug_e["u"]))
		await _shot("12_menu_%s_edge" % edge, "Piece menu opened on the rug at the %s edge" % edge)
		hb._close_menu()

func _hover(hb: HomeBuild, cell: Vector2) -> void:
	hb.debug_m = cell
	hb.tick(0.05)
	hm.cam.follow(hm.cam.focus, 0.05, false)
	_mouse_at(Vector3(cell.x, 0, cell.y), hm.cam)

func run(m: Node, out_dir: String) -> void:
	main = m
	dir = out_dir
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	await _farm()
	await _house()
	print("BUSHOT DONE")
	main.get_tree().quit()

func _farm() -> void:
	_farm_save()
	var home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null: break
		await main.get_tree().process_frame
	var hb: HomeBuild = home.hb
	FarmBuilder.draw_up()
	home._close_panel()
	hm = home
	hb.toggle()
	var land := HomeLayout.LANDING
	hb.take("house")
	var house_cells := _spot(hb, land + Vector3(0, 0, -8))
	_put(hb, house_cells)
	var hpos := Vector3(house_cells[0].x, 0, house_cells[0].y)
	hb.take("crop_patch")
	_put(hb, _spot(hb, hpos + Vector3(7, 0, 2)))
	hb.take("rug_long")
	_put(hb, _spot(hb, hpos + Vector3(-1, 0, 5)))
	hb.take("lantern")
	_put(hb, _spot(hb, hpos + Vector3(3, 0, 5)))
	hb.toggle()
	home.queue_free()
	await main.get_tree().process_frame
	home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null: break
		await main.get_tree().process_frame
	hb = home.hb
	hm = home
	FarmBuilder.draw_up()
	home._close_panel()
	if main.fade: main.fade.reveal(0.05)
	await main.get_tree().create_timer(3.2).timeout
	home.day_t = 0.5
	var focus: Vector3 = hpos + Vector3(2.0, 0, 5.5)
	_look(home, focus, 1.0)
	# 1. the catalog
	hb.toggle()
	hb.cat = "Furniture"
	hb._build_bar()
	print("BUSHOT tabs: %s" % ", ".join(hb._tabs()))
	hb.debug_m = Vector2(-1000.0, -1000.0)
	hb.tick(0.05)
	await _shot("01_farm_catalog",
		"Build mode on the farm: category tabs, search, big tiles with pictures, prices and owned counts, easing in")
	# 2. a green ghost with the key hints at the cursor
	hb.take("rug_long")
	print("BUSHOT held: %s" % str(hb.held))
	var open_cell := _spot(hb, focus + Vector3(-3, 0, 2))
	var free_mid := Vector2(open_cell[0].x + 1.5, open_cell[0].y + 1.0)
	await _settle()
	_hover(hb, free_mid)
	await _shot("02_ghost_green",
		"The held long rug as a green ghost snapped to the grid with its footprint, and the keys beside the cursor")
	# 3. red, blocked by the bench
	var rug_e: Dictionary = HomeLayout.of(Save.d)["deco"].filter(func(e): return e["id"] == "rug_long")[0]
	var bc: Vector2i = HomeLayout.deco_cells(rug_e)[0]
	hb.take("rug")
	await _settle()
	_hover(hb, Vector2(bc.x + 1.0, bc.y + 1.0))
	await _shot("03_ghost_red_blocked",
		"A rug over the long rug: the ghost turns red, the blocker lights up, the cursor says 'Blocked by: Long rug'")
	hb._cancel_held()
	# 4. the piece menu
	hb.cat = "Furniture"
	_hover(hb, Vector2(bc.x + 1.0, bc.y + 1.0))
	hb.open_menu("d:%d" % int(rug_e["u"]))
	await _shot("04_context_menu", "Clicking a placed rug: Move, Rotate, Store and its colours")
	hb._close_menu()
	await _edges(hb, rug_e)
	# 5. the rotate animation
	hb.take("rug_long")
	await _settle()
	_hover(hb, free_mid)
	await _strip(hb, free_mid)
	hb._cancel_held()
	# 7. storage
	hb.store_placed("d:%d" % int(rug_e["u"]))
	hb.cat = BuildCatalog.STORAGE
	hb._build_bar()
	await _shot("07_storage_tab", "The Storage tab: the stored long rug with its count, ready to put down again")
	hb.toggle()
	home.queue_free()
	hm = null
	await main.get_tree().process_frame

## Five frames of one quarter turn, side by side.
func _strip(hb: HomeBuild, cell: Vector2) -> void:
	await _prep()
	var centre: Vector2 = hm.cam.unproject_position(Vector3(cell.x, 0.4, cell.y))
	var crop := Rect2i(int(centre.x) - 130, int(centre.y) - 120, 380, 240)
	var frames: Array = []
	hb.rotate_held()
	for i in 5:
		hb.tick(0.03 if i > 0 else 0.0)
		await _settle(2)
		frames.append(_grab().get_region(crop))
	var strip := Image.create(crop.size.x * frames.size(), crop.size.y, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		strip.blit_rect(frames[i], Rect2i(Vector2i.ZERO, crop.size), Vector2i(i * crop.size.x, 0))
	strip.save_png("%s/05_rotate_strip.png" % dir)
	hm.set_process(true)
	print("BUSHOT 05_rotate_strip|One quarter turn of the long rug ghost in five frames: it turns smoothly, no pop")

func _house() -> void:
	Save.d = Save.fresh()
	Save.d["gems"] = 900
	var room = load("res://scripts/home/interior.gd").new()
	main.add_child(room)
	await _settle(5)
	var dec: Decorate = room.dec
	dec.toggle()
	await main.get_tree().create_timer(0.5).timeout
	await _shot("06_empty_house_decorate",
		"A new house in decorate mode: empty, with the same catalog bar, the Useful pieces waiting in Storage")
	dec.cat = BuildCatalog.STORAGE
	dec.refresh()
	await _shot("08_house_storage", "The house's Storage tab: the journal and gramophone, free to place")
	dec.cat = "Beds & seats"
	dec.take("bed")
	dec.debug_m = Vector2(5.0, 3.5)
	room.get_viewport().warp_mouse(room.cam.unproject_position(Vector3(5.0, 0, 3.5)))
	dec.tick(0.05)
	await _shot("09_house_ghost", "Placing a bed in the house: green footprint and the keys by the cursor")
	dec.toggle()
	room.queue_free()
	await main.get_tree().process_frame
