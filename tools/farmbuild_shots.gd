extends RefCounted
## --farmbuild-shots=<dir>: screenshots of the farm building pass (run with a real renderer, e.g. xvfb-run with
## --rendering-driver opengl3): build mode with locked entries, a valid and an invalid placement preview, Boki
## building a site, the finished building, and a tier 3 upgrade. Never touches the real save.

var main: Node
var dir := ""
var hm = null             # the Home screen being shot

func _shot(name: String, caption: String) -> void:
	for i in 3: await main.get_tree().process_frame
	if main.fade: main.fade.reveal(0.05)      # the boot splash still covers a screen made straight from a tool
	await main.get_tree().create_timer(0.25).timeout
	if hm:
		hm._close_panel()      # the welcome card
		if hm.guide and hm.guide.tracker: hm.guide.tracker.visible = false
		await main.get_tree().process_frame
		hm.set_process(false)      # (the hover card and the prompt come back every frame otherwise)
		if hm.hover_box: hm.hover_box.visible = false
		hm.prompt_box.visible = false
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	if hm: hm.set_process(true)
	img.save_png("%s/%s.png" % [dir, name])
	print("FBSHOT %s|%s" % [name, caption])

func _put(hb: HomeBuild, cs: Array) -> bool:
	hb.cells = cs; hb._check_cells()
	return hb.place_held()

func _spot(hb: HomeBuild, p: Vector3) -> Array:
	var id := String(hb.held["id"])
	var sz := HomeLayout.size_of(id, int(hb.held["r"]))
	for rad in 22:
		for k in 48:
			var a := float(k) / 48.0 * TAU
			var x := int(round(p.x + cos(a) * rad - sz.x * 0.5)); var z := int(round(p.z + sin(a) * rad - sz.y * 0.5))
			var cs := HomeLayout.cells_of([x, z, x + sz.x - 1, z + sz.y - 1])
			if hb.fits(hb.held, cs): return cs
	return []

## The home builds itself over a few frames when drawing for real: wait until its UI exists.
func _ready_home(home) -> void:
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null: break
		await main.get_tree().process_frame

func _look(home, target: Vector3, zoom: float) -> void:
	var p := target + Vector3(3.2, 0, 2.6)      # you stand a little way off so the building is in clear view
	home.ppos = p
	home.player.position = p
	home.cam.zoom_to = zoom
	home.cam.zoom = zoom
	home.cam.snap(p)

func _sim(home, secs: float) -> void:
	for i in int(secs / 0.05):
		for k in home.kins:
			for n in Care.NEEDS: k["rec"]["needs"][n] = maxf(float(k["rec"]["needs"][n]), 70.0)
		home.day_t = 0.5
		home._move_kin(0.05)
		home.hw.tick(0.05)
		if i % 100 == 0: await main.get_tree().process_frame

## Runs the farm until a Boki is hammering at a site that already has some swings in (for the mid-build shots).
func _until_working(home, e: Dictionary, min_got: int) -> void:
	for i in 120:
		await _sim(home, 1.0)
		if not FarmSites.has_site(e): return
		var working := false
		for k in home.kins:
			if k.has("job") and String(k["job"].get("kind", "")) == "build" and String(k["job"].get("phase", "")) == "work": working = true
		if working and int(e["site"]["got"]) >= min_got: return

func run(m: Node, out_dir: String) -> void:
	main = m
	dir = out_dir
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip"); k["starter"] = true
	d["roster"].append(k); d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	Save.d["gems"] = 500
	Save.d["stats"] = {"extracts": 1, "bosses": 0, "caught": 0, "harvested": 40, "hatched": 1, "fb_built": 0}      # farm level 2
	Save.d["extracts"] = 1
	Save.d["mats"] = {"wood": 40, "stone": 30, "fibre": 20}
	Save.d["items"]["coals"] = 4
	var home = await main._hb_home()
	await _ready_home(home)
	var hb: HomeBuild = home.hb
	home._close_panel()
	hb.toggle()
	var land := HomeLayout.LANDING
	hb.take("house")
	var hc := _spot(hb, land + Vector3(0, 0, -8))
	_put(hb, hc)
	hb.take("crop_patch")
	_put(hb, _spot(hb, home.spots["house"] + Vector3(7, 0, 2)))
	hb.take("cook_pot")
	_put(hb, _spot(hb, home.spots["house"] + Vector3(4, 0, 3)))
	hb.toggle()
	var rk := Save.new_kin("pebbit", "Rocky"); rk["level"] = 5
	var ash := Save.new_kin("cindle", "Ash"); ash["level"] = 5
	for r in [rk, ash]:
		Care.ensure(r)
		for nd in Care.NEEDS: r["needs"][nd] = 100.0
		Save.d["roster"].append(r)
	home.queue_free()
	await main.get_tree().process_frame
	home = await main._hb_home()
	await _ready_home(home)
	hb = home.hb
	home._close_panel()
	hm = home
	if main.fade: main.fade.reveal(0.05)
	await main.get_tree().create_timer(1.0).timeout
	var L := HomeLayout.of(Save.d)
	var hp: Vector3 = home.spots["house"]
	# 1. build mode: the Work tab, locked entries with their requirement
	_look(home, hp + Vector3(-1, 0, 3), 1.1)
	hb.toggle()
	home.cam.zoom_to = 1.1; home.cam.zoom = 1.1
	hb.cat = "Work"; hb._build_bar()
	hb.debug_m = Vector2(hp.x - 5.0, hp.z + 6.0)
	await _shot("01_build_mode", "Build mode, Work tab: the Lumber Camp and Quarry are open at farm level 2, the rest show what unlocks them; prices are material icons")
	# 2. a valid preview
	hb.take("lumber_camp")
	var cc := _spot(hb, hp + Vector3(-5, 0, 4))
	home.cam.zoom_to = 0.8; home.cam.zoom = 0.8
	hb.debug_m = Vector2(cc[0].x + 1.0, cc[0].y + 0.5)
	hb.tick(0.05)
	await _shot("02_preview_valid", "Placement preview, valid: green footprint outline, snapping grid, Lumber Camp ghost")
	# 3. an invalid preview (on the house)
	hb.debug_m = Vector2(hp.x - 1.0, hp.z)
	hb.tick(0.05)
	await _shot("03_preview_invalid", "Placement preview, invalid: red outline and the reason floats over it")
	# 4. place it, Boki build it
	hb.debug_m = Vector2(cc[0].x + 1.0, cc[0].y + 0.5)
	hb.tick(0.05)
	hb.place_held()
	hb.toggle()
	home.hw.scan_t = 0.0
	home.hw.scan()
	_look(home, HomeLayout.deco_center(HomeLayout.of(Save.d)["deco"][-1]), 0.6)
	var camp: Dictionary = {}
	for e in L["deco"]:
		if String(e["id"]) == "lumber_camp": camp = e
	await _until_working(home, camp, 1)
	await _shot("04_boki_building", "A Boki building the Lumber Camp site: scaffolding, rising walls and a progress bar")
	var mid := int(camp["site"]["got"]) if camp.has("site") else -1
	print("FBSHOT  site got %d of %d" % [mid, int(camp["site"]["need"]) if camp.has("site") else 0])
	# 5. finished
	await _sim(home, 160.0)
	await _shot("05_finished_build", "The finished Lumber Camp, tier 1, working")
	# 6. upgraded to tier 3 next to a second tier 1 camp
	Save.d["stats"]["harvested"] = 400; Save.d["stats"]["bosses"] = 1; Save.d["stats"]["extracts"] = 6
	Save.d["mats"] = {"wood": 60, "stone": 60, "fibre": 40}; Save.d["items"]["coals"] = 8
	hb.toggle()
	hb.cat = "Upgrades"; hb._build_bar()
	await _shot("06_upgrades_tab", "Build mode, Upgrades tab: tier costs as icons")
	hb.upgrade(int(camp["u"]))
	hb.toggle()
	home.hw.scan_t = 0.0
	home.hw.scan()
	_look(home, HomeLayout.deco_center(camp), 0.55)
	await _until_working(home, camp, 1)
	await _shot("07_upgrade_in_progress", "Upgrading: scaffolding goes up round the working camp with its bar")
	await _sim(home, 200.0)
	hb.toggle()
	hb.upgrade(int(camp["u"]))      # tier 3
	hb.toggle()
	home.hw.scan_t = 0.0
	home.hw.scan()
	await _sim(home, 260.0)
	hb.toggle()
	_look(home, HomeLayout.deco_center(camp) + Vector3(1.8, 0, 0), 0.5)
	hb.take("quarry")
	var qc := _spot(hb, HomeLayout.deco_center(camp) + Vector3(3.5, 0, 0))
	_put(hb, qc)
	hb.toggle()
	await _sim(home, 200.0)
	_look(home, HomeLayout.deco_center(camp) + Vector3(0.6, 0, 0), 0.62)
	await _shot("08_tier3_beside_tier1", "A tier 3 Lumber Camp (gold plinth, tall pennant, corner lanterns) beside a plain tier 1 Quarry")
	print("FBSHOT DONE")
	main.get_tree().quit()
