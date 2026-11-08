extends Node3D
## The home island: walk around the farm, tend crops, cook, shop, spend time with your kin,
## and step through the portal to start an expedition.

const SPEED := 5.0

var world: World
## Under the ink wipe the farm builds in slices (see _ready): true until it's whole; Main holds the
## reveal until then.
var building := false
var cam: CamRig
var fx: Fx
var ui: CanvasLayer
var root_ui: Control
var panel_host: Control
var topbar: Label
var top_chips: HBoxContainer
var prompt_box: PanelContainer
var prompt_lbl: Label
var hint: Label
var player: Node3D
var ppos := Vector3.ZERO
var pvel := Vector3.ZERO
var spawn := ""             # set when coming back out of a building: start at its door
var py := 0.0               # height of a jump
var farm_t := 0.0
var pvy := 0.0
const JUMP_V := Hunter.JUMP_V
const GRAV := Hunter.H_GRAV
var pface := 0.0
var walk_ph := 0.0
var house_node: Node3D
var rack_node: Node3D
var rack_pick := ""
var whistle_cd := 0.0
var talk_cd := 0.0          # kin take turns talking: one ambient line at a time
var whistle_player: AudioStreamPlayer
var kins: Array = []           # {rec, node, pos, vel, goal, t, emote, emote_t, hop}
var spots := {}                # name -> Vector3
var plots: Array = []          # nodes, index matches Save plots
var interact := {}
var panel_open := ""
var chat_log: Array = []       # [{role, content}]
var chat_kin: Dictionary = {}
var chat_input: LineEdit
var chat_busy := false
var emote_labels: Array = []
var pet_done := {}

var lots := {}                 # building id -> {node, built}
var visit: Dictionary = {}     # when visiting someone: their island snapshot (see Social.publish_profile)
var visit_id := ""
var petted := {}
var hecon: HomeEcon = null       # the armory, feeders, starving, graveyard and Soul Shrine (home_econ.gd)
var water := HomeWater.new(self)      # the ponds you wade and swim in (home_water.gd)
var hb: HomeBuild = null         # build mode and the island's layout (home_build.gd, home_layout.gd)
var hob: FarmHob = null            # Hob the builder: talks, blueprints, the second Relic, a hammer (farm_hob.gd)
var guide: FarmGuide = null        # the Goals card and the farm tutorial on screen (farm_guide.gd)
var hw: HomeWork = null            # kin at work: jobs, stations and the Job Board (home_work.gd, Work)
var hinc: HomeIncubator = null     # the Incubator by the Nesting Nook, where Rare Eggs hatch (home_incubator.gd, Incubator)
var hmk: HomeMarket = null         # the market stall's panel (home_market.gd)
var hbm: HomeBlackMarket = null    # Old Pell's Black Market (home_black_market.gd)
## A farm-start island (HomeLayout.fs): the house, crop patches, pot, stall, Nook, Burrow, training
## post and graveyard are things you place in build mode, so where they are comes from the layout
## (_sync_fixtures); one you haven't placed is FAR away (nothing finds it, nothing walks to it).
var fs := false
const FAR := Vector3(-400, 0, -400)
var house_r := 0                   # which way the house faces (quarter turns)
var grave_c := Vector3(50.0, 0, 32.0)
var grave_r := 0
var burrow_r := 0
var _fx_sig := ""
var away_work: Array = []          # lines: what assigned Boki made while you were away
var tw := ToolWork.new()           # your tool swing: axe, pickaxe, hammer (tool_work.gd)
var hg: HomeGather = null           # chopping wild trees and mining boulders with your tools (home_gather.gd)

## The island being shown: yours, or the one you're visiting.
func _d() -> Dictionary:
	return visit if not visit.is_empty() else Save.d

func _has_b(b: String) -> bool:
	return _d().get("buildings", []).has(b)

func _has_br(k: String) -> bool:
	return _d().get("bridges", []).has(k)
var bridges := {}              # isle id -> {tiles, node, built, label}
var gh_plots: Array = []
var building_now := false
# ---- day, night and weather
const DAY_LEN := 300.0          # seconds for a full day at home
var env_res: Environment
var sun_l: DirectionalLight3D
var p_anim: HunterAnim = null
var crouch_on := false          # crouching (the match's crouch key and its tap-to-toggle setting)
var p_crouch_k := 0.0           # the crouched pose, eased in and out
const CROUCH_SPEED := 0.55      # walking speed crouched (the same as in a match)
var lamps: Array = []           # OmniLight3D
var day_t := 0.3                # 0..1, 0.25 is morning, 0.5 noon, 0.75 dusk
var rain: CPUParticles3D
var raining := false
var rain_k := 0.0
var weather_t := 40.0

func _ready() -> void:
	if Game.modding(): Game.apply_mod()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_ambience("home")
	Sfx.new_track.connect(_on_new_track)
	var dbg := OS.get_cmdline_user_args()
	for a in dbg:
		if a.begins_with("--home-weapon="):
			# test: wear a given weapon at home (as the archetype whose signature it is)
			var wk := a.substr(14)
			for ak0 in Arch.archetypes_of(wk):
				Save.d["cls"] = Arch.weight(String(ak0)); Save.d["arch"] = ak0
			Save.d["weapon"] = wk
			Save.d.erase("loadout")
			Save.no_write = true
			# and nobody starving, so no popup covers the view
			for rec in Save.d["roster"]:
				Care.ensure(rec)
				rec["starve"] = 0.0; rec["needs"]["food"] = 100.0; rec["needs_t"] = Time.get_unix_time_from_system()
	if "--evo-test" in dbg:
		var ek := Save.active_kin()
		ek["level"] = 7
		ek["forms"] = []; ek["muts"] = []
		Evo.simulate(ek, RandomNumberGenerator.new())
		ek["level"] = 8
		Game._evolve(ek, {})
		Save.d["tutorial"]["home"] = true
	# (the Challenge House is no longer given: Hob draws it up after the first expedition and you build it, FarmBuilder)
	# so does Old Pell's Black Market
	if visit.is_empty() and not Save.d.get("buildings", []).has("ransom"):
		Save.d["buildings"].append("ransom")
	# in real play the farm builds under the ink wipe in slices (no 3D drawn meanwhile), so the wipe's
	# spinner keeps turning and the window never hangs; tools and checks (no wipe) build it in one go
	building = Game.main != null and Game.main.fade != null and Game.main.fade.covered and is_inside_tree()
	if building:
		set_process(false)
		set_process_unhandled_input(false)
		get_viewport().disable_3d = true
		PerfLog.frame_drawn()
	hecon = HomeEcon.new(self)
	hmk = HomeMarket.new(self, _spawn_kin)
	hbm = HomeBlackMarket.new(self)
	if visit.is_empty():
		HomeLayout.ensure(Save.d)     # first: a brand new farm-start island keeps its first trough in storage
		Econ.ensure()
		KinBox.ensure()        # the Kin Burrow; an old crowded farm gets its overflow boxed once
		_econ_tests(dbg)
	if "--home-all" in dbg:
		Save.d["bridges"] = Data.ISLES.keys()
		Save.d["buildings"] = Data.BUILDINGS.keys()
	_build_env()
	world = World.new(); add_child(world)
	var lay := HomeLayout.ensure(_d())
	await _slice()
	fs = HomeLayout.fs(_d())
	HomeLayout.make_world(world, int(lay["grow"]), int(lay.get("seed", 0)), float(lay.get("sk", 1.0)) if fs else 0.0)
	await _slice()
	hb = HomeBuild.new(self)
	hg = HomeGather.new(self)
	hw = HomeWork.new(self)
	if visit.is_empty():
		hob = FarmHob.new(self)
		guide = FarmGuide.new(self)
	if visit.is_empty(): Work.ensure()
	var path_col := Color("9c7a52")
	spots["portal"] = Vector3(38.0, 0, 39.0)
	if fs:
		# a farm-start island: just the portal, its rack and the ferry; you put everything else down
		for nm in ["house", "pot", "stall"]: spots[nm] = FAR
		NEST_AT = FAR; INCUB_AT = FAR; YARD_AT = FAR; YARD_KIN = FAR; BURROW_AT = FAR; POND_EDGE = FAR; grave_c = FAR
		world.paint_path(Vector2i(37, 36), Vector2i(37, 38), path_col)
	_classic_layout(path_col)
	spots["rack"] = Vector3(34.5, 0, 40.5)      # the glider rack, beside the portal
	world.set_block_rect(34, 40, 34, 40)
	_ready_rest()

## The classic island's fixed farm: the house up north, a path from its door down to the portal,
## branches to the market, the farm and the bridges; the pot, the stall, the farm's soil and the pond.
func _classic_layout(path_col: Color) -> void:
	if fs:
		return
	spots["house"] = Vector3(38.0, 0, 26.5)
	world.set_block_rect(36, 25, 40, 27)
	world.paint_path(Vector2i(37, 28), Vector2i(37, 38), path_col)
	world.paint_path(Vector2i(39, 31), Vector2i(42, 31), path_col, false)
	world.paint_path(Vector2i(24, 30), Vector2i(36, 30), path_col, false)
	world.paint_path(Vector2i(39, 38), Vector2i(50, 38), path_col, false)
	world.paint_path(Vector2i(44, 21), Vector2i(44, 28), path_col, false)
	world.paint_path(Vector2i(28, 31), Vector2i(28, 34), path_col, false)
	# out to the newer bridges: the Orchard Isle (north-east), Pine Hollow (north-west), Blossom Grove (south-west)
	world.paint_path(Vector2i(48, 28), Vector2i(61, 28), path_col, false)
	world.paint_path(Vector2i(29, 25), Vector2i(29, 29), path_col, false)
	world.paint_path(Vector2i(34, 42), Vector2i(34, 46), path_col, false)
	spots["stall"] = Vector3(30.5, 0, 33.0)
	world.set_block_rect(29, 32, 31, 33)
	spots["pot"] = Vector3(42.5, 0, 27.5)
	world.set_block_rect(42, 27, 42, 27)
	for z in range(30, 38):
		for x in range(43, 48):
			world.paint_tile(x, z, Color("6b4a33"))
	# the pond: water you can wade into and swim in (HomeWater), nothing grows in it
	for z in range(36, 39):
		for x in range(32, 35):
			world.no_deco[world.idx(x, z)] = true

# ------------------------------------------------------------------ a farm-start island's fixtures
func _fx1(fx: String) -> Dictionary:
	var a := HomeLayout.fixtures(_d(), fx)
	return a[0] if not a.is_empty() else {}

static func _turn(v: Vector3, r: int) -> Vector3:
	return v.rotated(Vector3.UP, r * PI * 0.5)

## Where the placed fixtures put the house, pot, stall, Nook, Incubator, Burrow, training post and
## graveyard (FAR for any not placed). Data only: _sync_fixtures moves the nodes too.
func _fixture_spots() -> void:
	if not fs:
		return
	var e := _fx1("house")
	spots["house"] = HomeLayout.deco_center(e) if not e.is_empty() else FAR
	house_r = int(e.get("r", 0)) if not e.is_empty() else 0
	e = _fx1("pot")
	spots["pot"] = HomeLayout.deco_center(e) if not e.is_empty() else FAR
	e = _fx1("stall")
	spots["stall"] = HomeLayout.deco_center(e) if not e.is_empty() else FAR
	e = _fx1("nook")
	if e.is_empty():
		NEST_AT = FAR; INCUB_AT = FAR
	else:
		var c := HomeLayout.deco_center(e); var r := int(e.get("r", 0))
		NEST_AT = c + _turn(Vector3(0.9, 0, 0), r)
		INCUB_AT = c + _turn(Vector3(-1.15, 0, 0.1), r)
	e = _fx1("burrow")
	BURROW_AT = HomeLayout.deco_center(e) if not e.is_empty() else FAR
	burrow_r = int(e.get("r", 0)) if not e.is_empty() else 0
	e = _fx1("yard")
	if e.is_empty():
		YARD_AT = FAR; YARD_KIN = FAR
	else:
		var c2 := HomeLayout.deco_center(e); var r2 := int(e.get("r", 0))
		YARD_AT = c2 + _turn(Vector3(0.3, 0, -0.2), r2)
		YARD_KIN = YARD_AT + _turn(Vector3(-0.3, 0, 0.2), r2)
	e = _fx1("graves")
	grave_c = HomeLayout.deco_center(e) if not e.is_empty() else FAR
	grave_r = int(e.get("r", 0)) if not e.is_empty() else 0
	# the pond's edge, for kin that like to sit by the water: the first wild pond tile
	POND_EDGE = FAR
	if hb:
		for k in HomeLayout.of(_d()).get("water", {}):
			var t := HomeLayout.unkey(k)
			POND_EDGE = Vector3(t.x + 0.5, 0, t.y + 1.6)
			break

## After the layout changed: fixture spots, and the nodes that follow them (plots on the crop
## patches, the Incubator, the graveyard's gate and graves, the house and the Burrow's models).
func _sync_fixtures() -> void:
	if not fs:
		return
	_fixture_spots()
	var e := _fx1("house")
	house_node = (hb.nodes.get(int(e["u"])) as Node3D) if hb and not e.is_empty() else null
	if hob: hob.sync()
	e = _fx1("burrow")
	var bn: Node3D = (hb.nodes.get(int(e["u"])) as Node3D) if hb and not e.is_empty() else null
	burrow_node = bn.get_node_or_null("Burrow") as Node3D if is_instance_valid(bn) else null
	e = _fx1("yard")
	var yn: Node3D = (hb.nodes.get(int(e["u"])) as Node3D) if hb and not e.is_empty() else null
	yard = yn.get_child(0) as Node3D if is_instance_valid(yn) and yn.get_child_count() > 0 else null
	if hinc and hinc.node:
		hinc.node.position = INCUB_AT
		hinc.node.rotation.y = int(_fx1("nook").get("r", 0)) * PI * 0.5
		hinc.node.visible = INCUB_AT.x > -100.0
		if hinc.label:
			hinc.label.position = INCUB_AT + Vector3(0, 2.4, -0.4)
			hinc.label.visible = hinc.node.visible
		hinc.refresh()
	if hecon and visit.is_empty():
		hecon.move_graveyard()
	if is_instance_valid(nest): nest.position = NEST_AT
	var cap: int = int(Save.d["plot_cap"]) if visit.is_empty() else (_d()["plots"] as Array).size()
	if str(_plot_spots(cap)) != _fx_sig:
		_build_plots()

## A farm-start island after your first expedition: Old Pell sets up the Black Market and the
## Challenge House goes up, each on open ground near the portal (move them wherever you like).
## Returns true if any went up.
func _fs_arrivals() -> bool:
	if int(Save.d.get("matches", 0)) < 1:
		return false
	var any := false
	var put: Array = []
	var w: World = world
	for b in ["board", "ransom"]:
		if HomeLayout.placed(b, _d()) or not _has_b(b):
			continue
		var item := {"kind": "b", "id": b, "r": 0, "from": 0}
		var best := Vector2i(-1, -1); var bd := 1e9
		for z in range(20, 50):
			for x in range(20, 64):
				var dd := Vector2(x - HomeLayout.LANDING.x, z - HomeLayout.LANDING.z).length()
				if dd < 5.0 or dd > 16.0 or dd >= bd: continue
				if not w.inb(x, z) or w.island[w.idx(x, z)] != 0: continue
				if hb.fits(item, HomeLayout.cells_of(HomeLayout.rect_at(b, x, z, 0))): best = Vector2i(x, z); bd = dd
		if best.x >= 0:
			HomeLayout.of(_d())["b"][b] = {"x": best.x, "z": best.y, "r": 0}
			hb._apply_blockers()
			hb._reach_cache.clear()
			any = true
			put.append(Data.BUILDINGS[b]["name"])
	if any:
		var them := "them" if put.size() > 1 else "it"
		HomeBuild.pending_toast = "Old Pell set up the %s near the portal (move %s in build mode)" % [" and the ".join(put), them]
	return any

## The rest of setting the island up (after the classic farm's fixed parts, or none on a farm-start island).
func _ready_rest() -> void:
	var dbg := OS.get_cmdline_user_args()
	_fixture_spots()
	# a few trees around the rim of every island, kept away from paths, lots and bridges
	world.add_trees_on_rim(54)
	var keep_clear: Array = [[36, 34, 40, 44], [42, 28, 50, 40], [41, 20, 47, 26], [22, 28, 28, 32], [46, 26, 62, 30], [27, 23, 31, 30], [32, 41, 36, 47]]
	for b in Data.BUILDINGS:
		var rc: Array = HomeLayout.rect_of(b, _d())
		keep_clear.append([rc[0] - 1, rc[1] - 1, rc[2] + 1, rc[3] + 2])
	keep_clear.append([BURROW_RECT[0] - 1, BURROW_RECT[1] - 1, BURROW_RECT[2] + 1, BURROW_RECT[3] + 2])
	for k in Data.ISLES:
		var rc: Array = HomeLayout.isle_bridge(world, k)["rect"]
		keep_clear.append([rc[0] - 2, rc[1] - 2, rc[2] + 2, rc[3] + 2])
	for rc in keep_clear:
		for z in range(rc[1], rc[3] + 1):
			for x in range(rc[0], rc[2] + 1):
				if world.inb(x, z) and world.kind[world.idx(x, z)] == World.T_BLOCK and not world.no_deco.has(world.idx(x, z)):
					world.kind[world.idx(x, z)] = World.T_GROUND
	# bridges: work out which tiles they cover before any are opened
	for k in Data.ISLES:
		bridges[k] = {"tiles": world.bridge_tiles(HomeLayout.isle_bridge(world, k)["rect"]), "built": _has_br(k)}
		if bridges[k]["built"]:
			world.open_bridge(bridges[k]["tiles"])
	if visit.is_empty():
		HomeLayout.rescue_feeders(world)
	# the layout's buildings, decorations, paths, ponds and colour theme
	hb.prepare_world()
	if fs and visit.is_empty(): HomeStall.ensure(self)       # every save has a market stall
	if fs and visit.is_empty() and _fs_arrivals():
		hb._apply_blockers()
	if visit.is_empty() and not fs:
		world.set_block_rect(BURROW_RECT[0], BURROW_RECT[1], BURROW_RECT[2], BURROW_RECT[3])
	if "--print-home" in OS.get_cmdline_user_args():
		for z in range(0, world.h):
			var line := "%2d " % z
			for x in range(0, world.w):
				var i := world.idx(x, z)
				line += "." if world.kind[i] == World.T_VOID else ("#" if world.kind[i] == World.T_BLOCK else ("o" if world.paint.has(i) else "g"))
			print(line)
		get_tree().quit()
	await _slice()
	if building: world.stage_cb = func(_l: String) -> void: pass
	await world.build_meshes()
	world.stage_cb = Callable()
	fx = Fx.new(); add_child(fx)
	cam = CamRig.new(); add_child(cam)
	cam.zoom_to = HOME_ZOOM; cam.zoom = HOME_ZOOM; cam.lead = 0.2
	_apply_cam_settings()
	if "--home-wide" in OS.get_cmdline_user_args():
		cam.zoom_to = 2.6; cam.zoom = 2.6     # test: the whole farm in one shot
	if not fs:
		var house := Models.house(); house.position = spots["house"]; add_child(house)
		house_node = house
		var pot := Models.cauldron(); pot.position = spots["pot"]; add_child(pot)
		var stall := StallModels.build(Stalls.level()); stall.position = spots["stall"]; stall.rotation.y = PI * 0.5; add_child(stall)
	var portal := Models.portal(UI.TEAL); portal.position = spots["portal"]; add_child(portal)
	if visit.is_empty():
		rack_node = _glider_rack()
		rack_node.position = spots["rack"]
		add_child(rack_node)
	portal.get_node("Disc").visible = true
	(portal.get_node("Beam") as CPUParticles3D).emitting = true
	if not fs:
		var pond := Models.pond(1.9, 1.5); pond.position = Vector3(33.5, 0, 37.5); add_child(pond)
		(pond.get_child(0) as MeshInstance3D).material_override = HomeBuild.water_mat()      # animated water
		for fp in [[Vector3(45.4, 0, 29.4), 0.0, 5.0], [Vector3(45.4, 0, 37.6), 0.0, 5.0], [Vector3(47.8, 0, 33.5), PI / 2, 8.0], [Vector3(42.4, 0, 35.6), PI / 2, 4.0]]:
			var f := Models.fence(fp[2]); f.position = fp[0]; f.rotation.y = fp[1]; add_child(f)
	# (the farm's lamps and flower beds are decorations now: see HomeLayout.STOCK)
	spots["ferry"] = Vector3(42.2, 0, 40.6)
	var fpost := Models.ferry_post(); fpost.position = spots["ferry"]; fpost.rotation.y = -0.4; add_child(fpost)
	var sign_post := Models.signpost(["Expeditions"]); sign_post.position = Vector3(39.8, 0, 38.2); sign_post.rotation.y = -0.3; add_child(sign_post)
	var roster: Array = _farm_kin() if not fs else []
	for i in mini(roster.size(), 6):
		var bed := Models.kin_bed(Data.KIN[roster[i]["species"]]["color"])
		bed.position = Vector3(33.4 + (i % 3) * 1.1, 0, 27.6 + (i / 3) * 1.1)
		add_child(bed)
	await _slice()
	_build_lots()
	if visit.is_empty() and not fs:
		_build_burrow()
	await _slice()
	_build_bridges()
	_build_plots()
	await _slice()
	player = Models.hunter(Data.class_of_save(), Data.TEAM_COLORS[0], _weapon(), "", Unmasked.worn(), Arch.of_save())
	add_child(player)
	ppos = Vector3(38.0, 0, 34.5) if not fs else HomeLayout.LANDING
	if spawn == "house":
		ppos = _house_door() + HomeLayout.facing(house_r) * 0.5
	elif lots.has(spawn):
		ppos = lots[spawn]["door"]
	player.position = ppos
	cam.snap(ppos)
	if "--expedition-test" in dbg:
		get_tree().create_timer(0.5).timeout.connect(_open_expedition)
	if "--home-crouch-test" in dbg:
		# test: walk right crouched for a second, then standing: crouched is slower, and posed low
		# (--crouch-still: stay crouched and still, for a screenshot)
		set_meta("crouch_test", true)
		if not "--crouch-still" in dbg:
			get_tree().create_timer(0.6).timeout.connect(func():
				Input.action_press("right")
				var x0 := ppos.x
				get_tree().create_timer(1.0).timeout.connect(func():
					var v_crouch := ppos.x - x0
					var ck := p_crouch_k
					remove_meta("crouch_test")
					var x1 := ppos.x
					get_tree().create_timer(1.0).timeout.connect(func():
						Input.action_release("right")
						print("HOMECROUCH crouched %.2f m/s (pose %.2f), standing %.2f m/s, pose now %.2f" % [v_crouch, ck, ppos.x - x1, p_crouch_k]))))
	if "--expedition-scroll-test" in dbg:
		# test: open the expedition panel, scroll down, press a match-mode tab (which rebuilds the
		# panel): it should stay where it was scrolled (--no-keep-scroll shows the old jump to the top)
		get_tree().create_timer(0.5).timeout.connect(func():
			_open_expedition()
			get_tree().create_timer(0.6).timeout.connect(func():
				var sc := _panel_scroll()
				if sc == null: print("SCROLLTEST no scroll"); return
				sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
				get_tree().create_timer(0.3).timeout.connect(func():
					var before := sc.scroll_vertical
					if "--no-keep-scroll" in dbg: set_meta("no_keep_scroll", true)
					exp_mode = "duo" if exp_mode != "duo" else "trio"
					_open_expedition()
					get_tree().create_timer(0.5).timeout.connect(func():
						var sc2 := _panel_scroll()
						print("SCROLLTEST before=%d after=%d max=%d" % [before, sc2.scroll_vertical if sc2 else -1, int(sc2.get_v_scroll_bar().max_value) if sc2 else -1])))))
	for a in dbg:
		if a.begins_with("--rack-test"):
			# test: open the glider rack (optionally on a skin: --rack-test=ember)
			var pick := a.substr(12) if a.length() > 12 else ""
			get_tree().create_timer(0.5).timeout.connect(func():
				if pick != "": rack_pick = pick
				_open_rack())
	if "--crowd-test" in dbg:
		# test: pile every kin onto one spot next to you, then watch them sort themselves out
		get_tree().create_timer(0.3).timeout.connect(func():
			for k in kins:
				k.erase("indoors"); (k["node"] as Node3D).visible = true
				k["pos"] = ppos + Vector3(1.0, 0, 0.5); (k["node"] as Node3D).position = k["pos"]
				k["hi_cd"] = 0.0
			var t := 0.0
			var tick := func(): pass
			for step in [1.0, 3.0, 6.0]:
				get_tree().create_timer(step).timeout.connect(func():
					var md := 99.0; var talking := 0
					for i in kins.size():
						if float(kins[i].get("say_t", 0.0)) > 0.0: talking += 1
						for j in range(i + 1, kins.size()):
							md = minf(md, Vector2(kins[i]["pos"].x - kins[j]["pos"].x, kins[i]["pos"].z - kins[j]["pos"].z).length())
					print("CROWD t=%.0f kin=%d min_gap=%.2f talking=%d" % [step, kins.size(), md, talking])))
	if "--whistle-test" in dbg:
		# test: every kin but one is indoors, then you whistle
		get_tree().create_timer(0.3).timeout.connect(func():
			for j in kins.size():
				if j == 0: continue
				kins[j]["indoors"] = 999.0
				(kins[j]["node"] as Node3D).visible = false
			get_tree().create_timer(0.6).timeout.connect(_whistle))
	for a in dbg:
		if a.begins_with("--home-zoom="):
			cam.zoom_to = float(a.substr(12)); cam.zoom = cam.zoom_to
		if a.begins_with("--home-at="):
			# test: start standing here (x,z)
			var hp := a.substr(10).split(",")
			ppos = Vector3(float(hp[0]), 0, float(hp[1])); py = _ground_h(ppos.x, ppos.z)
			player.position = ppos + Vector3(0, py, 0); cam.snap(ppos)
		if a == "--home-act=run":
			# test: run to the right (for animation shots)
			get_tree().create_timer(1.0).timeout.connect(func(): Input.action_press("right"))
		if a.begins_with("--home-build="):
			var bk := a.substr(13)
			Save.d["bridges"].append(bk)
			get_tree().create_timer(0.3).timeout.connect(func(): _build_bridge_now(bk))
		if a.begins_with("--home-construct="):
			var cb := a.substr(17)
			Save.d["buildings"].append(cb)
			get_tree().create_timer(0.3).timeout.connect(func(): _construct(cb))
		if a.begins_with("--kin-needs="):
			var nv := a.substr(12).split(",")
			var nk := Save.active_kin()
			Care.ensure(nk)
			for i in mini(4, nv.size()): nk["needs"][Care.NEEDS[i]] = float(nv[i])
			nk["needs_t"] = Time.get_unix_time_from_system()
			get_tree().create_timer(0.3).timeout.connect(func():
				var ke := _kin_entry(nk)
				if not ke.is_empty():
					ke["pos"] = ppos + Vector3(1.2, 0, -0.4); (ke["node"] as Node3D).position = ke["pos"]; ke["hold_t"] = 30.0)
		if a == "--care-test":
			# test: feed, brush, bath, nap and dress in a row
			Save.d["items"]["kibble"] = 2; Save.d["crops"]["sunroot"] = 1
			Save.d["accs"] = ["scarf"]
			var ck := Save.active_kin()
			get_tree().create_timer(0.6).timeout.connect(func(): _care_feed(ck, "kibble"))
			get_tree().create_timer(4.0).timeout.connect(func(): _care_feed(ck, "sunroot"))
			get_tree().create_timer(7.5).timeout.connect(func(): _care_brush(ck))
			get_tree().create_timer(10.5).timeout.connect(func(): _set_acc(ck, "scarf"))
			get_tree().create_timer(11.5).timeout.connect(func(): _care_bath(ck))
			get_tree().create_timer(19.0).timeout.connect(func(): _care_nap(ck); print("CARETEST ", ck["needs"], " known ", ck["known"], " items ", Save.d["items"]))
			get_tree().create_timer(22.0).timeout.connect(func(): print("CARETEST2 nap ", _kin_entry(ck).get("nap_t", 0), " acc ", ck.get("acc", "")); get_tree().quit())
		if a == "--hatch-nest":
			# test: two kin with an egg ready; stand by the nest and hatch it
			var ka := Save.active_kin()
			var kb := Save.new_kin("puddlet", "Drip")
			kb["level"] = 6; kb["trust"] = 60.0
			Save.d["roster"].append(kb)
			Save.d["egg"] = {"a": ka["uid"], "b": kb["uid"], "m": 0, "t": 0.0}
			_spawn_kin()
			_refresh_nest()
			ppos = NEST_AT + Vector3(0, 0, 2.0)
			get_tree().create_timer(1.0).timeout.connect(_hatch_nest_egg)
		if a.begins_with("--drill="):
			var dstat := a.substr(8)
			get_tree().create_timer(0.4).timeout.connect(func(): _start_drill(Save.active_kin(), dstat))
		if a in ["--build-demo", "--decor-demo", "--overview-demo"]:
			Save.no_write = true
			var which: String = a
			get_tree().create_timer(0.05).timeout.connect(func(): _build_demo(which))
		if a == "--home-night": day_t = 0.97
		if a == "--home-noon": day_t = 0.5
		if a == "--home-rain":
			raining = true; rain_k = 1.0; rain.emitting = true; weather_t = 999.0
		if a == "--farm-test":
			# test: a farm in every state, with a farmhand on duty
			Save.d["plot_cap"] = 8
			_build_plots()
			var ks: Array = Data.CROPS.keys()
			for i in 8:
				Save.d["plots"][i] = {"crop": ks[i % ks.size()], "stage": i % 3, "care": 0, "wt": (Time.get_unix_time_from_system() - 85.0) if i % 2 == 0 else 0.0}
				_refresh_plot("plots", i)
			Save.active_kin()["farmhand"] = true
		if a == "--ransom-test":
			# test: go down on an expedition with two kin; one is left unclaimed, a rival takes the other,
			# and a rival wants back a kin you took from them
			while Save.d["roster"].size() < 4:
				Save.d["roster"].append(Save.new_kin(Data.common_kin()[Save.d["roster"].size() % Data.common_kin().size()]))
			var ka: Dictionary = Save.d["roster"][1]
			var kb: Dictionary = Save.d["roster"][2]
			var kc: Dictionary = Save.d["roster"][3]
			kc["lost_from"] = "Moss"
			Save.d["gems"] = maxi(int(Save.d["gems"]), 400)
			var res := Game.apply_result({"extracted": false, "why": "knocked out", "tier": 1, "rivals": ["Vexa", "Moss", "Tarn"],
				"kin_runs": [{"uid": ka["uid"], "events": [], "trust": ka["trust"], "stats": {}}, {"uid": kb["uid"], "events": [], "trust": kb["trust"], "stats": {}}],
				"lost_kin": [{"uid": ka["uid"], "fate": "ransom", "holder": ""}, {"uid": kb["uid"], "fate": "rival", "holder": "Vexa"}]})
			print("RANSOM lost_news=%d news=%s lost=%d offers=%d" % [res["lost_news"].size(), str(res["ransom_news"]), Save.d["lost_kin"].size(), Save.d["offers"].size()])
			if Save.d["offers"].is_empty():
				Save.d["offers"].append({"uid": kc["uid"], "from": "Moss", "gems": 90, "m": 0})
		if a.begins_with("--ui-tour="):
			UiTour.run(self, a.substr(10))
		if a.begins_with("--open="):
			var which := a.substr(7)
			get_tree().create_timer(0.2).timeout.connect(func():
				if which == "loadout": _open_loadout()
				elif which == "expedition": _open_expedition()
				elif which == "kitcard": _open_kit_card()
				elif which == "kin" or which.begins_with("kin:"):
					if which.begins_with("kin:"): kin_tab = which.substr(4)      # --open=kin:About opens that tab
					_open_kin(Save.active_kin())
				elif which == "burrow" or which == "kinbox": _open_burrow()
				elif which == "shop": hmk.open()
				elif hmk.open_named(which): pass      # a market tab: "exchange[:item]", "shelter", "auctions"...
				elif which == "challenges": _open_challenges()
				elif which.begins_with("ransom") or which.begins_with("blackmarket"):
					hbm.open(which.get_slice(":", 1) if ":" in which else "")
				elif which == "kitchen": _open_kitchen()
				elif which == "plot": _open_plot("plots", 0)
				elif which == "chat":
					var ak := Save.active_kin()
					var ke := _kin_entry(ak)
					if not ke.is_empty(): ppos = ke["pos"] + Vector3(1.5, 0, 1.0); cam.snap(ppos)
					_open_chat(ak)
					chat_input.text = "hi, how are you?"
					_send_chat()
				elif which == "fetch":
					var ke := _kin_entry(Save.active_kin())
					if not ke.is_empty(): ppos = ke["pos"] + Vector3(1.5, 0, 1.0); cam.snap(ppos); _play_with_kin(ke))
		if a.begins_with("--work-") and a in ["--work-demo", "--work-board", "--work-board=Kin", "--work-card", "--work-box", "--work-hover", "--work-close", "--work-build"] or a == "--shiny-lineup":
			Save.no_write = true
			var wd: String = a
			get_tree().create_timer(0.3).timeout.connect(func(): hw.demo(wd))
		if a.begins_with("--farm-demo"):
			Save.no_write = true
			var fw := a.substr(12) if a.length() > 12 else "empty"
			get_tree().create_timer(0.6).timeout.connect(func(): hg.demo(fw))
		if a.begins_with("--kinbox-demo"):
			# test: a full farm and three pages in the Kin Burrow, then the box, a mutation lineup or a details card
			KinBoxView.demo_roster()
			var kw := a.substr(14) if a.length() > 14 else "box"
			get_tree().create_timer(0.4).timeout.connect(func(): KinBoxView.demo_show(self, kw))
		if a.begins_with("--nest-demo"):
			# test: a full roster, then the Nesting Nook (=grid, =kin, =rare, =pair), a kin card's IVs (=card)
			# or the Kin Burrow's side panel (=box). Never written to the save.
			KinBoxView.demo_roster()
			var nw := a.substr(12) if a.length() > 12 else "grid"
			get_tree().create_timer(0.4).timeout.connect(func(): _nest_demo(nw))
		if a.begins_with("--home-at="):
			var xy := a.substr(10).split(",")
			ppos = Vector3(float(xy[0]), 0, float(xy[1])); player.position = ppos; cam.snap(ppos)
	await _slice()
	_spawn_kin()
	await _slice()
	_setup_care()
	if visit.is_empty():
		hecon.build()
	await _slice()
	hb.build_visuals()
	_sync_fixtures()
	await _slice()
	hb.assign_beds()
	if "--kin-lineup" in dbg:
		var lr := RandomNumberGenerator.new(); lr.seed = 11
		var sps: Array = Data.common_kin()
		for i in 12:
			var rr := Save.new_kin(sps[i % sps.size()])
			rr["level"] = [1, 4, 8, 12, 16, 22][i / 2]
			Evo.simulate(rr, lr)
			var kn := Models.kin(rr["species"], rr)
			kn.position = Vector3(33.5 + (i % 6) * 1.7, 0, 32.5 + (i / 6) * 1.8)
			kn.rotation.y = PI * 0.1
			kn.scale *= 1.3
			add_child(kn)
	await _slice()
	_build_ui()
	_refresh_top()
	if guide: guide.build_ui()
	if building:
		building = false
		set_process(true)
		set_process_unhandled_input(true)
		get_viewport().disable_3d = false
	if visit.is_empty() and int(Save.d.get("box_notice", 0)) > 0:
		# an old save, first time home since the Kin Burrow: say where everyone went
		var nb := int(Save.d["box_notice"])
		Save.d.erase("box_notice")
		Save.save_game()
		_show_when_free(["The farm has room for %d Boki out at once now. Your partner, your first Boki and your closest ones stayed out; the other %d curled up in the new Boki Burrow, south of the market stall by the pond." % [KinBox.farm_cap(), nb],
			"Boki in the burrow sleep: they don't get hungry and don't need looking after. Swap them out whenever you like, or expand the cottages for more room."])
	if visit.is_empty():
		hecon.show_away()
		ClassReveal.maybe_show(self)     # a Hunter unlock that became ready: a toast (ClassUnlock)
	if not visit.is_empty():
		pass
	elif hb.needs_making():
		hb.open_make_home()
	elif not Save.d["tutorial"].get("home", false):
		_open_welcome()
	else:
		_play_evolutions()
	if visit.is_empty() and Social.available():
		Social.publish_profile(true)
		Social.collect_gifts(func(lines: Array):
			if lines.size() > 0 and is_inside_tree():
				_show_when_free(lines))
		Social.collect_payouts(func(total: int):
			if total > 0 and is_inside_tree():
				_toast("The market paid you %d gems" % total)
				_refresh_top())
	# a kin with lines written by Claude keeps them fresh
	var ak := Save.active_kin()
	if visit.is_empty() and Bridge.ai_ok and not ak.is_empty() and int(ak.get("matches", 0)) % 3 == 0:
		Bridge.refresh_lines(ak)

## While building under the ink wipe: lets a frame draw once the build has had the CPU for a while.
func _slice() -> void:
	if building and is_inside_tree() and PerfLog.slice_due():
		PerfLog.wait_begin()
		await get_tree().process_frame
		PerfLog.wait_end()

func _rect_center(rc: Array) -> Vector3:
	return Vector3((rc[0] + rc[2] + 1) * 0.5, 0, (rc[1] + rc[3] + 1) * 0.5)

func _isle_open(isle: String) -> bool:
	return isle == "main" or _has_br(isle)

# ---- buildings and building sites
func _build_lots() -> void:
	for b in Data.BUILDINGS:
		var bd: Dictionary = Data.BUILDINGS[b]
		var pl := HomeLayout.place_of(b, _d())
		var rc: Array = HomeLayout.rect_of(b, _d())
		var at := _rect_center(rc)
		var holder := Node3D.new(); holder.position = at; holder.rotation.y = int(pl["r"]) * PI * 0.5; add_child(holder)
		var built := _has_b(b)
		var n: Node3D
		if built:
			n = Models.building(b)
		else:
			var sz := HomeLayout.base_size(b)
			var lcost := FarmBuilder.lot_cost(b)
			n = Models.lot(sz.x, sz.y, bd["name"], FarmSites.cost_text(lcost) if not lcost.is_empty() else "%d gems" % int(bd["cost"]))
		holder.add_child(n)
		lots[b] = {"node": holder, "built": built, "at": at, "door": HomeLayout.door_at(b, int(pl["x"]), int(pl["z"]), int(pl["r"]))}
		if not HomeLayout.placed(b, _d()):
			# a farm-start lot you haven't marked out yet (build mode, Buildings)
			holder.visible = false
			lots[b]["at"] = FAR; lots[b]["door"] = FAR

func _build_bridges() -> void:
	for k in Data.ISLES:
		var isd: Dictionary = Data.ISLES[k]
		var br: Dictionary = bridges[k]
		var node := Node3D.new(); add_child(node)
		br["node"] = node
		var sgp: Vector2 = HomeLayout.isle_bridge(world, k)["sign"]
		var sg := Models.signpost([isd["name"]]); sg.position = Vector3(sgp.x, 0, sgp.y); add_child(sg)
		br["sign"] = sg
		if br["built"]:
			_lay_planks(k, false)
		else:
			_bridge_stub(k)
		var lbl := Label3D.new()
		lbl.font = UI.big; lbl.font_size = 64; lbl.pixel_size = 0.012; lbl.outline_size = 16
		lbl.outline_modulate = Color(UI.NIGHT, 0.9)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.text = "%s\n%d gems to bridge" % [isd["name"], int(isd["cost"])]
		lbl.modulate = UI.GOLD
		lbl.position = Vector3(isd["c"].x, 3.2, isd["c"].y)
		lbl.visible = not br["built"]
		add_child(lbl)
		br["label"] = lbl

func _bridge_axis(k: String) -> Dictionary:
	var rc: Array = HomeLayout.isle_bridge(world, k)["rect"]
	var horiz: bool = rc[2] - rc[0] > rc[3] - rc[1]
	return {"horiz": horiz, "width": (rc[3] - rc[1] + 1.0) if horiz else (rc[2] - rc[0] + 1.0),
		"mid": (rc[1] + rc[3] + 1) * 0.5 if horiz else (rc[0] + rc[2] + 1) * 0.5}

## Plank positions along the bridge, ordered from the home island outward.
func _plank_spots(k: String) -> Array:
	var ax := _bridge_axis(k)
	var along := {}
	for t in bridges[k]["tiles"]:
		along[t.x if ax["horiz"] else t.y] = true
	var out: Array = []
	for a in along.keys():
		for half in [0.25, 0.75]:
			var u: float = a + half
			out.append(Vector3(u, -0.07, ax["mid"]) if ax["horiz"] else Vector3(ax["mid"], -0.07, u))
	var mc := Vector3(38, 0, 32)
	out.sort_custom(func(p, q): return Vector2(p.x - mc.x, p.z - mc.z).length() < Vector2(q.x - mc.x, q.z - mc.z).length())
	return out

func _bridge_stub(k: String) -> void:
	var spots_l := _plank_spots(k)
	if spots_l.is_empty():
		return
	var node: Node3D = bridges[k]["node"]
	var ax := _bridge_axis(k)
	var p0: Vector3 = spots_l[0]
	var side := Vector3(0, 0, 1) if ax["horiz"] else Vector3(1, 0, 0)
	for sgn in [-1.0, 1.0]:
		var post := Models.part(node, Models.box(0.16, 1.2, 0.16), Models.toon(Color("7a5a3c")), p0 + side * sgn * (ax["width"] * 0.5) + Vector3(0, 0.6, 0))
		post.name = "Post"
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	# two loose planks side by side (stacked in the same spot they flickered through each other)
	var along := Vector3(1, 0, 0) if ax["horiz"] else Vector3(0, 0, 1)
	var outward := signf((spots_l[spots_l.size() - 1] as Vector3 - p0).dot(along)) if spots_l.size() > 1 else 1.0
	for i in 2:
		var pl := Models.plank(rng, ax["width"] - 0.02)
		pl.position = p0 + along * outward * (i * 0.5) + Vector3(0, 0.07 - i * 0.012, 0)
		if ax["horiz"]: pl.rotation.y += PI / 2
		node.add_child(pl)

func _lay_planks(k: String, animate: bool) -> void:
	var node: Node3D = bridges[k]["node"]
	for c in node.get_children():
		c.queue_free()
	var ax := _bridge_axis(k)
	var rng := RandomNumberGenerator.new(); rng.seed = k.hash()
	var sp := _plank_spots(k)
	var side := Vector3(0, 0, 1) if ax["horiz"] else Vector3(1, 0, 0)
	var rope := Models.toon(Color("e8d8b0"), false)
	var post_m := Models.toon(Color("7a5a3c"))
	for i in sp.size():
		var p: Vector3 = sp[i]
		var pl := Models.plank(rng, ax["width"] - 0.02)
		pl.position = p + Vector3(0, 0.03, 0)
		if ax["horiz"]: pl.rotation.y += PI / 2
		node.add_child(pl)
		var extra: Array = [pl]
		if i % 4 == 0 or i == sp.size() - 1:
			for sgn in [-1.0, 1.0]:
				extra.append(Models.part(node, Models.box(0.12, 0.9, 0.12), post_m, p + side * sgn * (ax["width"] * 0.5 + 0.05) + Vector3(0, 0.4, 0)))
		if i < sp.size() - 1:
			var q: Vector3 = sp[i + 1]
			for sgn in [-1.0, 1.0]:
				var a: Vector3 = p + side * sgn * (ax["width"] * 0.5 + 0.05) + Vector3(0, 0.75, 0)
				var b: Vector3 = q + side * sgn * (ax["width"] * 0.5 + 0.05) + Vector3(0, 0.75, 0)
				var r := Models.part(node, Models.box(0.04, 0.04, a.distance_to(b) + 0.02), rope, (a + b) * 0.5)
				r.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
				extra.append(r)
		if animate:
			for e in extra:
				var tgt: Vector3 = e.position
				e.position = tgt + Vector3(0, -2.5, 0)
				e.scale = Vector3.ONE * 0.2
				var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_interval(i * 0.06)
				tw.tween_property(e, "position", tgt, 0.3)
				tw.parallel().tween_property(e, "scale", Vector3.ONE, 0.3)
			if i % 3 == 0:
				get_tree().create_timer(i * 0.06 + 0.25).timeout.connect(func():
					Sfx.play("build", null, -6.0, 0.12)
					fx.dust(p, 6))

func _build_env() -> void:
	var env := WorldEnvironment.new()
	var e := Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"), "below": Color("3a3a6a"),
		"ambient": Color("c4cbe6"), "ambient_energy": 0.5, "fog": Color("8a96c8"), "fog_height": -4.0, "stars": 0.0})
	Look.cozy(e)
	env.environment = e
	add_child(env)
	env_res = e
	var sun := Look.lights(self, Color("ffe9cf"), 0.95, Vector3(-50, -30, 0), 45.0)
	sun_l = sun
	# you always arrive in the morning; the day runs on from there
	day_t = 0.3
	rain = CPUParticles3D.new()
	rain.amount = 260; rain.lifetime = 0.9; rain.emitting = false
	var dm := BoxMesh.new(); dm.size = Vector3(0.025, 0.4, 0.025)
	var rm := StandardMaterial3D.new(); rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.75, 0.82, 1.0, 0.45); rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = rm
	rain.mesh = dm
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(16, 0.5, 12)
	rain.direction = Vector3(0.15, -1, 0); rain.spread = 3.0
	rain.gravity = Vector3(0, -30, 0)
	rain.initial_velocity_min = 14.0; rain.initial_velocity_max = 18.0
	add_child(rain)

func _build_plots() -> void:
	for n in plots:
		n.queue_free()
	plots.clear()
	for n in gh_plots:
		n.queue_free()
	gh_plots.clear()
	var cap: int = int(Save.d["plot_cap"]) if visit.is_empty() else (_d()["plots"] as Array).size()
	while _d()["plots"].size() < cap:
		_d()["plots"].append({"crop": "", "stage": 0})
	var where := _plot_spots(cap)
	_fx_sig = str(where)
	for i in where.size():
		var p := Models.plot()
		p.position = where[i]
		add_child(p)
		plots.append(p)
		_refresh_plot("plots", i)
	if _has_b("greenhouse") and _d().get("gh_plots", []).size() >= 4:
		var oc: Vector2 = Data.ISLES["orchard"]["c"]
		for i in 4:
			var p := Models.plot()
			p.position = Vector3(oc.x - 3.3 + i * 2.2, 0, oc.y + 3.0)
			add_child(p)
			gh_plots.append(p)
			_refresh_plot("gh_plots", i)

## Where each plot is: the classic farm's two columns, or on a farm-start island four to each crop
## patch you've put down (plots without a patch yet aren't out).
func _plot_spots(cap: int) -> Array:
	var out: Array = []
	if not fs:
		for i in cap: out.append(Vector3(44.2 + (i % 2) * 2.2, 0, 30.8 + (i / 2) * 2.0))
		return out
	for e in HomeLayout.fixtures(_d(), "farm"):
		var c := HomeLayout.deco_center(e)
		for j in 4:
			if out.size() >= cap: break
			out.append(c + Vector3(-1.1 + (j % 2) * 2.2, 0, -1.0 + (j / 2) * 2.0).rotated(Vector3.UP, int(e.get("r", 0)) * PI * 0.5))
	return out

func _plot_node(arr: String, i: int) -> Node3D:
	return plots[i] if arr == "plots" else gh_plots[i]

func _refresh_plot(arr: String, i: int) -> void:
	var p: Node3D = _plot_node(arr, i)
	var holder: Node3D = p.get_node("Crop")
	for ch in holder.get_children():
		ch.queue_free()
	var d: Dictionary = _d()[arr][i]
	(p.get_node("Wet") as Node3D).visible = d["crop"] != "" and float(d.get("wt", 0.0)) > 0.0
	if d["crop"] != "":
		var cd: Dictionary = Data.CROPS[d["crop"]]
		holder.add_child(Models.crop(int(d["stage"]), int(cd["grow"]), cd["color"]))

func _spawn_kin() -> void:
	for k in kins:
		k["node"].queue_free()
	kins.clear()
	KinIndoors.inside.clear()
	var open_isles: Array = [0]
	for i in world.islands.size():
		if i > 0 and _isle_open(world.islands[i]["id"]):
			open_isles.append(i)
	var ri := 0
	var farm_kin := _farm_kin()          # kin asleep in the Kin Burrow stay there
	for rec in farm_kin:
		var n := Models.kin(rec["species"], rec)
		add_child(n)
		var isl: int = 0 if rec["uid"] == _d().get("active", "") else open_isles[ri % open_isles.size()]
		ri += 1
		# somewhere open, not wedged against a building and not on top of another kin
		var taken: Array = kins.map(func(o): return o["pos"])
		taken.append(ppos)
		var at := world.free_spot_near(world.random_ground(isl), taken, 1.3)
		n.position = at
		var lbl := Label3D.new()
		lbl.font = UI.big; lbl.font_size = 48; lbl.pixel_size = 0.013; lbl.outline_size = 14
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.no_depth_test = true
		lbl.position.y = 1.25; lbl.visible = false
		n.add_child(lbl)
		var kd := {"rec": rec, "node": n, "pos": at, "vel": Vector3.ZERO, "goal": Vector3.INF, "t": randf() * 3.0, "emote": lbl, "emote_t": 0.0, "hop": randf() * 6.0, "pers": _personality(rec)}
		var ri2: int = farm_kin.find(rec)
		if isl == 0 and ri2 >= 0 and ri2 < 6:
			kd["bed"] = Vector3(32.9 + (ri2 % 3) * 1.6, 0, 27.2 + (ri2 / 3) * 1.6)
		kins.append(kd)
	if hb and hb.astar: hb.assign_beds()

# ------------------------------------------------------------------ loop
## Sun, sky, lamps and the occasional rain shower.
var _music_t := 0.0
var music_hold := 0.0
## The music follows where you're standing: each island has its own theme, home changes at night.
func _update_music(d: float) -> void:
	_music_t -= d
	music_hold -= d
	if _music_t > 0.0 or music_hold > 0.0:
		return
	_music_t = 0.5
	var isle := world.island_id(ppos.x, ppos.z)
	var night := sin((day_t - 0.25) * TAU) < -0.15
	var want := "home_night" if night else "home_day"
	if isle in ["orchard", "meadow", "summit"]:
		want = isle
	if Sfx.music_lock != "":
		want = Sfx.music_lock
	Sfx.play_music(want, 2.5)

func _on_new_track(name: String) -> void:
	if not is_inside_tree() or root_ui == null:
		return
	pass     # tracks join the music list in the house quietly; no popup every time a new one plays

func _update_sky(d: float) -> void:
	_update_music(d)
	day_t = fmod(day_t + d / DAY_LEN, 1.0)
	var sun_h := sin((day_t - 0.25) * TAU)            # 1 at noon, -1 at midnight
	var light := clampf(sun_h * 1.6 + 0.6, 0.0, 1.0)   # how much daylight (night is short and moonlit)
	var dusk := clampf(1.0 - absf(sun_h) * 3.0, 0.0, 1.0)
	weather_t -= d
	if weather_t <= 0.0:
		raining = not raining and randf() < 0.45
		weather_t = randf_range(50.0, 110.0) if raining else randf_range(70.0, 160.0)
		rain.emitting = raining
		Sfx.play_ambience("rain" if raining else "home")
	rain_k = move_toward(rain_k, 1.0 if raining else 0.0, d * 0.3)
	rain.position = Vector3(ppos.x, 12.0, ppos.z)
	# home is the warm place: a honey-coloured sun, a long golden hour, and lamps glowing amber
	# against a soft blue night (the expedition is the cold, moody one)
	var day_col := Color("ffe2b4").lerp(Color("ff9058"), dusk * 0.85)
	sun_l.light_color = day_col.lerp(Color("8fa6e0"), 1.0 - light)
	sun_l.light_energy = lerpf(0.4, 1.0, light) * (1.0 - rain_k * 0.35)
	sun_l.rotation_degrees = Vector3(lerpf(-28.0, -62.0, maxf(sun_h, 0.0)), -30.0 + day_t * 80.0, 0)
	env_res.ambient_light_color = Color("e6d4c4").lerp(Color("8090c8"), 1.0 - light).lerp(Color("ffc39a"), dusk * 0.45)
	env_res.fog_light_color = Color("c8a890").lerp(Color("4a5590"), 1.0 - light).lerp(Color("ff9e78"), dusk * 0.5)
	env_res.ambient_light_energy = lerpf(0.36, 0.45, light) * (1.0 - rain_k * 0.2)
	env_res.adjustment_enabled = true
	env_res.adjustment_brightness = lerpf(0.92, 1.0, light) * (1.0 - rain_k * 0.08)
	env_res.adjustment_saturation = lerpf(0.95, 1.14, light) * (1.0 - rain_k * 0.15) * (1.65 if Look.full_renderer() else 1.0)
	Look.night(env_res, (1.0 - light) * 0.75)
	var lamp_on := clampf(1.2 - light * 1.6, 0.0, 1.0)
	for l in lamps:
		l.light_color = Color("ffc37a")
		l.light_energy = 0.3 + lamp_on * 2.6
		l.omni_range = 4.0 + lamp_on * 4.0

func _process(delta: float) -> void:
	var d := minf(delta, 0.05)
	farm_t -= delta
	if farm_t <= 0.0:
		farm_t = 1.0
		_farm_tick()
	_update_sky(d)
	_update_hover()
	_hub_room_t -= delta
	if _hub_room_t <= 0.0:
		_hub_room_t = 0.2
		_keep_off_hub(root_ui.get_node_or_null("Hints") if root_ui else null)
	_move_player(d)
	_move_kin(d)
	if guide: guide.tick(d)
	_care_tick(d)
	if hecon: hecon.tick(d)
	_update_bubbles(d)
	_train_process(d)
	if hb: hb.tick(d)
	if hg: hg.tick(d)
	if hw: hw.tick(d)
	if hinc: hinc.tick(d)
	_apply_cam_settings()
	var focus := Vector3(ppos.x, minf(py, 0.0), ppos.z)
	cam.follow(hob.chat.frame(focus) if hob else focus, d, panel_open == "" and train.is_empty())
	_see_through()
	_abyss_tint(d)
	_find_interact()
	if hb and hb.active:
		return
	if panel_open == "" and not building_now and not Overlay.is_open() and not chat_open and train.is_empty() and not interact.is_empty():
		if Input.is_action_just_pressed("interact"):
			_use(interact)
		elif interact["kind"] == "kin" and visit.is_empty():
			if Input.is_action_just_pressed("play"): _play_with_kin(interact["k"])
			elif Input.is_action_just_pressed("talk"): _open_chat(interact["k"]["rec"])
			elif Input.is_action_just_pressed("details"): _open_kin(interact["k"]["rec"])

# ---- moving at home: walk, jump, dash (Shift, your class's dodge) and glide (hold Space in the air).
# py is your feet's height (terraces are 0.8 each). Off the edge you can glide over to another isle;
# drop into the sky and the wind sets you back down where you last stood.
var gliding := false
var glide_hold := 0.0
var dash_t := 0.0
var dash_v := Vector2.ZERO
var dash_charges := 2.0
var ex_cd := 0.0               # the long dash (Shift in the air, or with the short ones spent), as in a match
var dash_slot: HomeDashSlot = null  # the dash slot on screen, the match bar's own (DashSlot)
var safe_at := Vector3(38.0, 0, 34.5)
var glider_node: MeshInstance3D = null
const HOME_ZOOM := 1.2         # the camera on arriving home: midway between close (0.8) and the widest the wheel goes (1.6)
const MANTLE := 1.5            # ledges this far above your feet pop you up when you jump at them
const MANTLE_ABYSS := 3.5   # falling past an island's side, you catch its edge from this far below (pinned: the expedition reach grew to 4.5 in movefeel)
const FALL_RESPAWN := -40.0    # (a backstop: the abyss takes you a few metres under the island, World.abyss_floor)
## (movefeel) The Settings camera at home too, so you can try it here: the style's angle and lens and
## your follow mode. The farm keeps its own wider framing (the same ground across as the old home
## camera, whatever the style, so every zoom and panel shot here still frames the same).
const HOME_ACROSS_REF := "classic"   # the style the home's zooms were framed with
func _apply_cam_settings() -> void:
	cam.apply_settings()
	cam.dist_mul = CamRig.style_across(HOME_ACROSS_REF) / CamRig.style_across(cam.style_id)
	if player and is_instance_valid(player):
		# (a hero swap's pop rides on the base scale of 1, so it can't get stuck stretched)
		player.scale = player.get_meta("pop", Vector3.ONE) as Vector3

## Trees between the camera and you (or your active Boki) thin out, as in a match (SeeThrough).
func _see_through() -> void:
	if player == null or not is_instance_valid(player) or not player.visible:
		SeeThrough.off()
		return
	var b = null
	var act := String(_d().get("active", ""))
	for k in kins:
		var n = k.get("node")
		if String(k["rec"].get("uid", "")) == act and n is Node3D and is_instance_valid(n) and (n as Node3D).visible and (n as Node3D).is_inside_tree():
			b = (n as Node3D).global_position
	SeeThrough.update(cam, player.global_position, b)

func _exit_tree() -> void:
	SeeThrough.off()

## Boki on the farm are drawn bigger than in a match: the farm's camera sits much further back than the
## expedition's (HOME_ACROSS_REF framing at HOME_ZOOM), and at match size a Boki was a speck beside
## your hunter there. Presentation only (the farm has no hitboxes; a match's Boki keep their size).
const FARM_BOKI_SCALE := 1.7

var climb := {}                # (unused since the ledge float; kept for anything that clears it)
## Floating up a ledge, as in a match (Hunter._ledge_float): {lip, n (into the wall), t, at, g0}.
## You keep steering the whole way; steering away, a dash or the glider lets go.
var lfl := {}
var _mv := Vector2.ZERO

## Your class's dodge with the match's numbers: its charges and recharge (Hunter.max_dashes and
## dash_regen at rank 1), and the class's long dash (ex_dist, ex_time, ex_cd; Hunter.EX_DASH_CD).
## The key hints sit centred at the bottom, and on a 1280-wide window
## they ran under the hub's buttons (Settings covered the start of each): slide one right of the hub
## when it would overlap, centred in the room that's left.
var _hub_room_t := 0.0
func _keep_off_hub(c) -> void:
	if not (c is Control) or not is_instance_valid(c) or hub == null or not is_instance_valid(hub) or not hub.is_visible_in_tree():
		return
	var cc := c as Control
	var hr := hub.get_global_rect()
	var cr := cc.get_global_rect()
	var vw := get_viewport().get_visible_rect().size.x
	var room_l := hr.end.x + 12.0
	var centred := (vw - cr.size.x) * 0.5
	var want := centred if centred >= room_l else room_l + maxf(0.0, (vw - room_l - cr.size.x) * 0.5)
	if absf(cr.position.x - want) > 1.0 and cr.end.y > hr.position.y - 4.0:
		cc.global_position.x = want

func _dodge() -> Dictionary:
	var ck := Data.class_of_save()
	var dd := Content.class_dodge(ck)
	var cdat: Dictionary = Data.CLASSES.get(ck, {})
	var out := {"charges": float(cdat.get("dashes", 2)), "cd": Hunter.DASH_REGEN, "speed": Hunter.DASH_SPEED, "time": Hunter.DASH_TIME,
		"ex_cd": float(cdat.get("ex_cd", Hunter.EX_DASH_CD)), "ex_time": float(cdat.get("ex_time", Hunter.DASH_TIME * 1.45)), "ex_dist": float(cdat.get("ex_dist", 5.0))}
	if dd:
		out["charges"] = dd.charges; out["cd"] = dd.cooldown
		for e in dd.effects:
			if typeof(e) == TYPE_DICTIONARY and String(e.get("type", "")) == "dash":
				out["speed"] = float(e.get("speed", out["speed"])); out["time"] = float(e.get("time", out["time"]))
				break
	return out

func dashing() -> bool:
	return dash_t > 0.0

## Shift, by the match's rules (Hunter.do_dash): the short dash while you have a charge and are on
## the ground; in the air or with the charges spent, the long dash if it's off cooldown.
func try_dash(mv: Vector2, air: bool) -> bool:
	var dg := _dodge()
	var dir := mv if mv.length() > 0.1 else Vector2(-sin(pface), -cos(pface))
	if not air and dash_charges >= 1.0:
		dash_charges -= 1.0
		start_dash(dir, float(dg["speed"]), float(dg["time"]))
		return true
	if ex_cd > 0.0:
		return false
	ex_cd = float(dg["ex_cd"])
	var et := float(dg["ex_time"])
	start_dash(dir, float(dg["ex_dist"]) / maxf(0.01, et), et)
	pvy = maxf(pvy, 0.0)
	return true

func start_dash(dir: Vector2, speed: float, time: float) -> void:
	if dir.length() < 0.1:
		dir = Vector2(-sin(pface), -cos(pface))
	dash_v = dir.normalized() * speed
	dash_t = time
	gliding = false
	Sfx.play("whoosh", null, -6.0, 0.1, 1.2)
	if fx: fx.dust(ppos, 6)

## The ground under a point: its terrace height, or World.VOID over the sky.
func _ground_h(x: float, z: float) -> float:
	return world.ground_at(x, z)

func _move_player(d: float) -> void:
	if not climb.is_empty():
		_climb_step(d)
		return
	var mv := Vector2.ZERO
	var can_act := panel_open == "" and not Overlay.is_open() and not chat_open and train.is_empty()
	if can_act:
		mv = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))
		if mv.length() > 1.0: mv = mv.normalized()
	var dg := _dodge()
	dash_charges = minf(float(dg["charges"]), dash_charges + d / maxf(0.1, float(dg["cd"])))
	ex_cd = maxf(0.0, ex_cd - d)
	var gh := _ground_h(ppos.x, ppos.z)
	var air := py > gh + 0.001 or pvy > 0.0
	# crouch: held by default, or tapped to toggle (Settings crouch_toggle), as in a match
	if Settings.get_v("crouch_toggle"):
		if can_act and Input.is_action_just_pressed("crouch"):
			crouch_on = not crouch_on
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"):
			crouch_on = false
	else:
		crouch_on = can_act and Input.is_action_pressed("crouch")
	if has_meta("crouch_test"): crouch_on = true
	var wdep := water.depth(ppos.x, ppos.z) if py < 0.4 else 0
	water.step(wdep, d, mv, air)
	var crouching := crouch_on and not air and dash_t <= 0.0 and not gliding and wdep == 0
	p_crouch_k = move_toward(p_crouch_k, 1.0 if crouching else 0.0, d * 8.0)
	if can_act and Input.is_action_just_pressed("dash") and dash_t <= 0.0 and not water.swimming:
		if not try_dash(mv, air) and dash_slot:
			dash_slot.deny()
	_mv = mv
	var hv := Vector2(pvel.x, pvel.z)
	if dash_t > 0.0:
		dash_t -= d
		hv = dash_v
		if dash_t <= 0.0: hv = HunterMove.dash_exit(dash_v, SPEED)
	else:
		var spd := Hunter.GLIDE_SPEED * 1.15 if gliding else SPEED * (CROUCH_SPEED if crouching else 1.0) * water.speed_mul(wdep, air)
		hv += (mv * spd - hv) * (1.0 - exp(-(14.0 if not air else (4.0 if gliding else 6.0)) * d))
	# the island's edge doesn't hold you: walk off it and you fall (glide back, or the abyss returns you)
	var guard := false
	var p0 := ppos
	var nx := ppos.x + hv.x * d
	var ox := world.occupy(nx, ppos.z, 0.38, py, guard)
	if ox == 0.0: ppos.x = nx
	elif not _mantle(nx, ppos.z, ox, air): hv.x = 0.0
	var nz := ppos.z + hv.y * d
	var oz := world.occupy(ppos.x, nz, 0.38, py, guard)
	if oz == 0.0: ppos.z = nz
	elif not _mantle(ppos.x, nz, oz, air): hv.y = 0.0
	pvel = Vector3(hv.x, 0, hv.y)
	# caught on a corner: slip around it. Boxed in on every side: step out to open ground.
	if not air and mv.length() > 0.3 and Vector2(ppos.x - p0.x, ppos.z - p0.z).length() < SPEED * d * 0.3:
		var dn := mv.normalized()
		var slid := false
		for side in [Vector2(-dn.y, dn.x), Vector2(dn.y, -dn.x)]:
			var t: Vector2 = Vector2(ppos.x, ppos.z) + (side * 0.8 + dn * 0.4) * SPEED * d
			if world.occupy(t.x, t.y, 0.38, py, true) == 0.0:
				ppos.x = t.x; ppos.z = t.y; slid = true
				break
		var boxed := not slid
		if boxed:
			for i in 8:
				var a2 := TAU * i / 8.0
				if world.occupy(ppos.x + cos(a2) * 0.2, ppos.z + sin(a2) * 0.2, 0.38, py, true) == 0.0:
					boxed = false; break
		wedge_t = wedge_t + d if boxed else 0.0
		if wedge_t > 0.8:
			wedge_t = 0.0
			unstick()
	gh = _ground_h(ppos.x, ppos.z)
	air = py > gh + 0.001 or pvy > 0.0
	# jump; in the air, a second press (or holding Space, or the glide key) opens the glider
	var jump_now := can_act and Input.is_action_just_pressed("jump")
	if jump_now and not air:
		pvy = water.breach(JUMP_V) if water.swimming else JUMP_V      # from deep water: a kick up and out
		air = true
		glide_hold = 0.0
		Sfx.play("jump", null, -12.0)
	elif air and can_act:
		var holding := Input.is_action_pressed("jump") or Input.is_action_pressed("glide")
		glide_hold = glide_hold + d if holding else 0.0
		if not gliding and dash_t <= 0.0 and ((jump_now and lfl.is_empty()) or Input.is_action_just_pressed("glide") or (lfl.is_empty() and holding and glide_hold > Hunter.GLIDE_ENGAGE and pvy < 2.0)):
			gliding = true
			Sfx.play("whoosh", null, -10.0, 0.1, 0.8)
		elif gliding and not holding:
			gliding = false
	if air:
		if not lfl.is_empty() and _ledge_float(d, mv):
			pass
		elif gliding and gh <= World.VOID + 1.0 and py < _abyss_lip() - 0.5:
			# below an island's lip over the abyss the glider pulls you up, harder the deeper you are
			# (the match's lift: Hunter.abyss_lift_vy). The farm never had it: you only sank
			pvy = Hunter.abyss_lift_vy(pvy, _abyss_lip() - py, d)
		elif gliding and pvy <= 0.0:
			pvy = move_toward(pvy, -Hunter.GLIDE_SINK, Hunter.GLIDE_CATCH * d)
		else:
			pvy = maxf(pvy - GRAV * d, -HunterMove.fall_max)
		py += pvy * d
		if gh > World.VOID + 1.0 and py <= gh:
			lfl = {}
			if py < gh - 0.6:
				Sfx.play("land", null, -8.0)     # caught the edge from below and climbed up
			py = gh
			pvy = 0.0
			gliding = false
			Sfx.step(null, -16.0)
		elif py < FALL_RESPAWN or (gh <= World.VOID + 1.0 and py < world.abyss_floor(ppos.x, ppos.z) - Hunter.ABYSS_EXTRA - (Hunter.ABYSS_GLIDE_ROOM if gliding else 0.0)):
			_respawn_safe()
	else:
		py = gh
		pvy = 0.0
		gliding = false
		if gh > World.VOID + 1.0 and world.kind[world.idx(int(floor(ppos.x)), int(floor(ppos.z)))] == World.T_GROUND:
			safe_at = ppos
	_glider_look()
	player.position = ppos + Vector3(0, py - water.drop_y(), 0)
	# face the mouse; with the mouse outside the window, face where you're walking
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var aim_ok := panel_open == "" and Rect2(Vector2.ZERO, vp.get_visible_rect().size).has_point(mp)
	var want := pface
	if aim_ok:
		var aim := cam.mouse_on_plane(0.9)
		var ad := Vector2(aim.x - ppos.x, aim.z - ppos.z)
		if ad.length() > 0.4: want = atan2(-ad.x, -ad.y)
	elif hv.length() > 0.3:
		want = atan2(-hv.x, -hv.y)
	if tw.active(): want = tw.face_from(ppos)      # working: face the target
	pface = lerp_angle(pface, want, minf(1.0, d * 14.0))
	player.basis = cam.char_basis(pface, player.scale)     # leaned toward the camera, as in a match
	player.basis = water.tilt(player.basis, hv.length())      # swimming: tipped into a stroke
	if p_anim == null or p_anim.model != player:
		p_anim = HunterAnim.new(player)
	var ps := {"vel": Vector3(hv.x, pvy if air else 0.0, hv.y), "face": pface, "grounded": not air, "gliding": gliding or water.k > 0.5, "rolling": dash_t > 0.0, "dash_dir": dash_v, "crouch": p_crouch_k}
	ps.merge(tw.anim_state())      # the Empty carries no class weapon at home; a tool only while working
	if air and not gliding and gh > World.VOID + 1.0:
		ps["air_h"] = clampf(py - gh, 0.0, 30.0)
	p_anim.update(d, ps)
	if dash_slot == null and ui:
		dash_slot = HomeDashSlot.new()
		dash_slot.home = self
		ui.add_child(dash_slot)
		ui.move_child(dash_slot, 0)
	if p_anim.stepped:
		Sfx.step(null, -20.0)

func _move_kin(d: float) -> void:
	whistle_cd = maxf(0.0, whistle_cd - d)
	talk_cd = maxf(0.0, talk_cd - d)
	_separate_kin(d)
	for k in kins:
		if k.get("busy", false):
			continue
		if k.has("indoors"):
			# inside the house: out of sight until it fancies coming out (or hears you whistle)
			if KinIndoors.step(k, d, ppos, _house_door(), KinIndoors.has_house(spots)) and not k.has("exiting"):
				_kin_exit_house(k, false)
			continue
		if k.has("leap"):
			_leap_step(k, d)
			continue
		k["t"] -= d
		if k.has("called_t"):
			# you whistled: drop everything and come to you
			k["called_t"] = float(k["called_t"]) - d
			var slot: Vector3 = k.get("call_slot", Vector3.ZERO)
			k["goal"] = ppos + slot
			k.erase("chase"); k.erase("task"); k.erase("going_in")
			var to_me := Vector2(ppos.x + slot.x - k["pos"].x, ppos.z + slot.z - k["pos"].z).length()
			if world.island_of(k["pos"].x, k["pos"].z) != world.island_of(ppos.x, ppos.z) and world.island_of(ppos.x, ppos.z) >= 0:
				_start_leap(k, ppos + slot)
				continue
			if to_me < 0.6 or float(k["called_t"]) <= 0.0:
				var arrived := to_me < 0.6
				k.erase("called_t"); k.erase("call_slot")
				if arrived:
					k["hold_t"] = 1.4; k["joy_t"] = 0.9; k["t"] = randf_range(2.5, 4.0)
					_emote(k, "♥" if float(k["rec"]["trust"]) > 55.0 else "♪")
					Sfx.play("kin_happy", k["pos"], -10.0, 0.15, Unique.voice(k["rec"]))
		var pos: Vector3 = k["pos"]
		var rec: Dictionary = k["rec"]
		var trust := float(rec["trust"])
		if k.get("nap_go", false):
			k["nap_go_t"] = float(k.get("nap_go_t", 15.0)) - d
			if float(k["nap_go_t"]) <= 0.0: k.erase("nap_go"); k.erase("nap_go_t")
			elif k.has("bed"): k["goal"] = k["bed"]
		var locked: bool = float(k.get("nap_t", 0.0)) > 0.0 or k.has("bath") or k.get("nap_go", false)
		if locked:
			k.erase("chase"); k.erase("task")
		var here := world.island_of(pos.x, pos.z)
		# playing tag: chase a friend, then it's their turn
		var other = k.get("chase", null)
		if other != null:
			k["chase_t"] = float(k.get("chase_t", 0.0)) - d
			k["goal"] = other["pos"]
			if Vector2(other["pos"].x - pos.x, other["pos"].z - pos.z).length() < 0.7 or k["chase_t"] <= 0.0:
				k.erase("chase")
				k["t"] = randf_range(1.5, 3.0)
				if k["chase_t"] > 0.0:
					_emote(k, "♪"); _emote(other, "!")
					Sfx.play("kin_happy", other["pos"], -14.0, 0.15, 1.2 * Unique.voice(other["rec"]))
					if not other.get("busy", false) and randf() < 0.7:
						other["chase"] = k; other["chase_t"] = 4.0
				k["goal"] = world.random_ground(maxi(here, 0))
		# work: watering (the old farmhand job), sowing, harvesting, the stations... (HomeWork)
		if hw: hw.step(k, d)
		var pers: Dictionary = k.get("pers", {})
		if k["t"] <= 0.0 and not locked and not k.has("chase") and not k.has("job") and not k.has("fetch"):
			k["t"] = randf_range(2.0, 5.0) * float(pers.get("rest", 1.0))
			var night := sin((day_t - 0.25) * TAU) < -0.2
			var friends: Array = kins.filter(func(o): return o != k and not o.get("busy", false) and not o.has("job") and world.island_of(o["pos"].x, o["pos"].z) == here)
			k.erase("stare")
			if rec.has("recall") and world.island_of(ppos.x, ppos.z) == here:
				# back from an expedition with something to tell you: it comes over (see below)
				k["goal"] = _seat(k, ppos, 1.3)
				k["t"] = 1.5
			elif _care_goal(k):
				pass
			elif hw and hw.pick(k):
				pass      # off to a job it's suited to
			elif night and randf() < 0.6:
				if here == world.island_of(spots["house"].x, spots["house"].z) and randf() < 0.45:
					# some sleep indoors
					k["going_in"] = true
					k["goal"] = _house_door()
				elif not KinIndoors.has_house(spots) and randf() < 0.5:
					KinIndoors.nap_outside(k)      # no house: it curls up where it is
				else:
					# at night they head for bed and doze
					k["goal"] = k.get("bed", world.random_ground(maxi(here, 0)))
				if randf() < 0.5: _emote(k, "z")
			elif not night and randf() < 0.05:
				# a short nap now and then: inside if there is a house, otherwise curled up outside
				if here == world.island_of(spots["house"].x, spots["house"].z):
					k["going_in"] = true
					k["goal"] = _house_door()
				elif not KinIndoors.has_house(spots):
					KinIndoors.nap_outside(k)
			elif friends.size() > 0 and randf() < float(pers.get("social", 0.22)):
				var f: Dictionary = friends[randi() % friends.size()]
				k["chase"] = f; k["chase_t"] = 4.0
				_emote(k, "★")
			elif randf() < float(pers.get("cling", 0.25)) + trust / 300.0 and world.island_of(ppos.x, ppos.z) == here:
				# kin that trust you like to be near you, each in its own spot around you
				k["goal"] = _seat(k, ppos, 1.5)
			elif randf() < 0.75 - float(pers.get("roam", 0.5)) * 0.5 and _haunt(k, here) != Vector3.INF:
				# everyone has a favourite corner of the farm they drift back to
				k["goal"] = _haunt(k, here) + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6))
			else:
				k["goal"] = world.random_ground(maxi(here, 0))
			if randf() < 0.3 * float(pers.get("chatty", 1.0)):
				_emote(k, "♥" if trust > 65.0 else ("?" if trust < 30.0 else "★"))
		if k.has("fetch"):
			_fetch_step(k, d)
		_care_step(k, d)
		var hold := float(k.get("hold_t", 0.0))
		if hold > 0.0:
			# being petted or talked to: it stays put and looks at you
			k["hold_t"] = hold - d
			k["goal"] = pos
		var wish := Vector2.ZERO
		var goal: Vector3 = k["goal"]
		if goal != Vector3.INF:
			# round fences, buildings and ponds on the tile grid when the way isn't clear (HomeBuild.steer)
			var aim: Vector3 = hb.steer(k, pos, goal) if hb else goal
			var to := Vector2(aim.x - pos.x, aim.z - pos.z)
			if Vector2(goal.x - pos.x, goal.z - pos.z).length() > 0.4 and to.length() > 0.01:
				wish = to.normalized() * (4.4 if (k.has("fetch") or k.has("called_t")) else (3.6 if k.has("chase") else 2.4)) * _care_speed(rec) * float(pers.get("speed", 1.0))
		var hv := Vector2(k["vel"].x, k["vel"].z)
		hv += (wish - hv) * (1.0 - exp(-8.0 * d))
		var nx := pos.x + hv.x * d
		if world.occupy(nx, pos.z, 0.3, 0.0, true) == 0.0: pos.x = nx
		var nz := pos.z + hv.y * d
		if world.occupy(pos.x, nz, 0.3, 0.0, true) == 0.0: pos.z = nz
		k["vel"] = Vector3(hv.x, 0, hv.y)
		k["pos"] = pos
		var n: Node3D = k["node"]
		n.position = pos
		water.paddle(k, pos, n, d)
		if k.get("going_in", false) and Vector2(pos.x - _house_door().x, pos.z - _house_door().z).length() < 0.6:
			k.erase("going_in")
			var night_now := sin((day_t - 0.25) * TAU) < -0.2
			KinIndoors.enter(k, night_now)
			n.visible = false
			Sfx.play("thump", pos, -16.0, 0.1, 1.3)
			continue
		var face := atan2(-hv.x, -hv.y) if hv.length() > 0.2 else atan2(-(ppos.x - pos.x), -(ppos.z - pos.z))
		n.rotation.y = lerp_angle(n.rotation.y, face, minf(1.0, d * 8.0))
		k["hop"] += d * (float(pers.get("hop_f", 9.0)) if hv.length() > 0.3 else 2.5)
		var joy := float(k.get("joy_t", 0.0))
		if joy > 0.0:
			# a happy little bounce
			k["joy_t"] = joy - d
			k["hop"] += d * 10.0
		n.get_node("Body").position.y = absf(sin(k["hop"])) * (0.26 if joy > 0.0 else (float(pers.get("hop_a", 0.14)) if hv.length() > 0.3 else 0.03))
		_quirk(k, n, hv.length() > 0.3, d)
		if hw: hw.pose(k, n, d)
		n.set_meta("happy", joy > 0.0)
		n.set_meta("kstate", "sleep" if float(k.get("nap_t", 0.0)) > 0.0 else "")
		if k.has("say"):
			k["say_t"] = float(k.get("say_t", 0.0)) - d
			(k["say"] as Label3D).visible = k["say_t"] > 0.0
		n.scale = Vector3.ONE * (1.05 if rec["uid"] == _d().get("active", "") else 0.9) * float(n.get_meta("evo_scale", 1.0)) * FARM_BOKI_SCALE
		if k["emote_t"] > 0.0:
			k["emote_t"] -= d
			var lbl: Label3D = k["emote"]
			lbl.visible = k["emote_t"] > 0.0
			lbl.position.y = 1.15 + (1.6 - k["emote_t"]) * 0.2

## Jumping at a ledge a little above you pops you up onto it (and from below, an island's rim).
## (x, z) is where you were moving to; `top` is the height of the ledge your body bumped into.
## You land on top of the ledge, just past its lip; the move is done here (ppos set) when it works.
func _mantle(x: float, z: float, top: float, air: bool) -> bool:
	if not air or top <= 0.0:
		return false
	var reach := MANTLE_ABYSS if py < -0.2 else MANTLE
	if top - py > reach:
		return false
	# touching an island's rim with your side, from below: there's no ground under (x, z)
	var side := not world.is_block(x, z) and _ground_h(x, z) <= World.VOID + 1.0
	if world.is_sheer(int(floor(x)), int(floor(z))) and py < top - 0.6:
		return false      # a smooth sheer rim has nothing to hold: you slide down it
	# the spot on top: step on from where you were heading until the ground there is the ledge
	var dv := Vector2(x - ppos.x, z - ppos.z)
	if dv.length() < 0.0001:
		return false
	dv = dv.normalized()
	var to := Vector3.INF
	for k in 17:
		var q := Vector2(x, z) + dv * (0.1 * k)
		var g := _ground_h(q.x, q.y)
		if world.is_block(q.x, q.y) or g <= World.VOID + 1.0 or g < top - 0.05 or g - py > reach:
			continue
		if world.occupy(q.x, q.y, 0.38, g, false) != 0.0:
			continue
		to = Vector3(q.x, g, q.y)
		break
	if to == Vector3.INF:
		return false
	# (ledge float) only when your keys push into it; no snap, no fixed climb: you float up the
	# face and keep steering (see _ledge_float)
	var n := Vector2(signf(x - ppos.x), 0.0) if absf(x - ppos.x) > absf(z - ppos.z) else Vector2(0.0, signf(z - ppos.z))
	if _mv.length() < 0.3 or _mv.normalized().dot(n) < Hunter.LRISE_PUSH or not lfl.is_empty():
		return false
	lfl = {"lip": to.y, "n": n, "t": 0.0, "at": Vector2(ppos.x, ppos.z), "g0": Input.is_action_pressed("jump") or Input.is_action_pressed("glide")}
	gliding = false
	dash_t = 0.0
	if to.y - py > 0.6 or side:
		Sfx.play("grab", null, -8.0, 0.1, 1.2)
		if fx: fx.burst(ppos + Vector3(0, py + 0.6, 0), Color("cfeaff"), 6, 2.0, 0.3, 0.0)
	return false

## One step of rising up a ledge (the match's Hunter._ledge_rise): sets pvy while it lasts and
## returns true; false once it's over (moved off the face, dashed, glided, or timed out). A jump
## near the top (Hunter.LRISE_WINDOW) flings you higher and faster toward your keys.
func _ledge_float(d: float, mv: Vector2) -> bool:
	lfl["t"] = float(lfl["t"]) + d
	var n: Vector2 = lfl["n"]
	var glide_now := Input.is_action_pressed("glide")
	var off := (Vector2(ppos.x, ppos.z) - (lfl["at"] as Vector2)).dot(-n) > Hunter.LRISE_OFF
	if off or gliding or dash_t > 0.0 or float(lfl["t"]) > 1.2 or Vector2(ppos.x, ppos.z).distance_to(lfl["at"]) > 2.0 			or (glide_now and Input.is_action_just_pressed("glide")):
		lfl = {}
		return false
	var left: float = float(lfl["lip"]) + 0.12 - py
	var dir: Vector2 = mv.normalized() if mv.length() > 0.3 else n
	if Input.is_action_just_pressed("jump") and panel_open == "":
		# the fling: strong in the window near the top, weaker before it
		var timed := left <= Hunter.LRISE_WINDOW
		lfl = {}
		var hv := Vector2(pvel.x, pvel.z)
		var spd := Hunter.FLING_SPEED if timed else SPEED
		if hv.dot(dir) < spd: hv += dir * (spd - hv.dot(dir))
		pvel = Vector3(hv.x, 0, hv.y)
		pvy = sqrt(2.0 * GRAV * (maxf(0.0, left) + (Hunter.FLING_HEIGHT if timed else Hunter.FLING_EARLY_HEIGHT)))
		glide_hold = 0.0
		Sfx.play("whoosh" if timed else "jump", null, -8.0, 0.1, 1.3)
		return true
	if left <= 0.0:
		lfl = {}
		pvy = Hunter.LRISE_POP
		if mv.length() > 0.3:
			var hv := Vector2(pvel.x, pvel.z)
			if hv.dot(dir) < SPEED * 0.9: hv += dir * (SPEED * 0.9 - hv.dot(dir))
			if mv.normalized().dot(n) > 0.15 and hv.dot(n) < SPEED * 0.6: hv += n * (SPEED * 0.6 - hv.dot(n))
			pvel = Vector3(hv.x, 0, hv.y)
	else:
		pvy = clampf(left * 14.0, Hunter.LRISE_MIN, Hunter.LRISE_SPEED)
	return true

## The pull-up over a rim (the match's mantle): straight up the face, then forward over the lip.
func _climb_step(d: float) -> void:
	climb["t"] = float(climb["t"]) + d
	var k := clampf(float(climb["t"]) / float(climb["dur"]), 0.0, 1.0)
	var a: Vector3 = climb["from"]; var b: Vector3 = climb["to"]
	var sp: float = climb["split"]; var lip: float = climb["lip"]
	var p: Vector3
	if k < sp:
		var u := k / maxf(0.001, sp)
		p = Vector3(a.x, lerpf(a.y, lip, 1.0 - (1.0 - u) * (1.0 - u)), a.z)
	else:
		var u2 := (k - sp) / maxf(0.001, 1.0 - sp)
		var e2 := u2 * u2 * (3.0 - 2.0 * u2)
		p = Vector3(lerpf(a.x, b.x, e2), lerpf(lip, b.y, e2) + 0.22 * sin(u2 * PI), lerpf(a.z, b.z, e2))
	ppos = Vector3(p.x, 0, p.z)
	py = p.y
	pvel = Vector3.ZERO
	player.position = ppos + Vector3(0, py, 0)
	if p_anim == null or p_anim.model != player:
		p_anim = HunterAnim.new(player)
	p_anim.update(d, {"vel": Vector3.ZERO, "face": pface, "grounded": false, "gliding": false, "mantle": k, "fired": 99.0})
	if k >= 1.0:
		climb = {}
		py = b.y
		pvy = 0.0
		Sfx.play("land", null, -12.0)
		if fx: fx.dust(ppos, 3)

## Under island level over the abyss the view goes magenta, as in a match (AbyssFx), deeper toward
## the point of no return.
const ABYSS_FX := preload("res://scripts/match/abyss_fx.gd")
var abyss_fx: CanvasLayer = null
var abyss_k := 0.0
func _abyss_tint(d: float) -> void:
	var want := 0.0
	if world.is_void(ppos.x, ppos.z) and climb.is_empty() and pvy <= ABYSS_FX.RISE_OFF:     # (rising back up: no tint)
		var top := _abyss_lip() - 0.5
		var kill: float = world.abyss_floor(ppos.x, ppos.z) - Hunter.ABYSS_EXTRA - (Hunter.ABYSS_GLIDE_ROOM if gliding else 0.0)
		want = ABYSS_FX.danger_depth(top - py, top - kill)
	abyss_k = lerpf(abyss_k, want, 1.0 - exp(-(12.0 if want > abyss_k else 9.0) * d))     # in fast, out over a few frames
	if abyss_fx == null and abyss_k > 0.004:
		abyss_fx = ABYSS_FX.new()
		add_child(abyss_fx)
	if abyss_fx:
		abyss_fx.show_danger(abyss_k, 0.0)

## The island lip you're under over the abyss: the lowest ground close by (World.abyss_ref), else
## where you last stood.
func _abyss_lip() -> float:
	var a: float = world.abyss_ref(ppos.x, ppos.z)
	if a > World.VOID + 1.0:
		return a
	var s: float = _ground_h(safe_at.x, safe_at.z)
	return s if s > World.VOID + 1.0 else 0.0

## Dropped into the sky: the wind carries you back to where you last stood. No harm done.
func _respawn_safe() -> void:
	climb = {}
	lfl = {}
	ppos = safe_at
	py = _ground_h(ppos.x, ppos.z)
	if py <= World.VOID + 1.0: py = 0.0
	pvy = 0.0; pvel = Vector3.ZERO; gliding = false; dash_t = 0.0
	player.position = ppos + Vector3(0, py, 0)
	cam.snap(ppos)
	if fx: fx.burst(ppos + Vector3(0, 0.8, 0), Color("cfe8ff"), 16, 3.0, 0.5)
	Sfx.play("whoosh", null, -4.0, 0.1, 0.7)
	_toast("The wind caught you")

## The glider over your head while you glide (your equipped skin).
func _glider_look() -> void:
	if glider_node == null or not is_instance_valid(glider_node):
		glider_node = MeshInstance3D.new()
		glider_node.mesh = Gliders.mesh(Gliders.equipped(), Data.TEAM_COLORS[0], UI.ACCENT)
		glider_node.material_override = Models.vtoon_outlined()
		glider_node.position = Vector3(0, 2.0, 0.05); glider_node.scale = Vector3.ONE * 0.8
		glider_node.visible = false
		player.add_child(glider_node)
	glider_node.visible = gliding

# ---- the glider rack: skins for your glider, each with its own trail and sounds
func _glider_rack() -> Node3D:
	var n := Node3D.new()
	var wood := Models.toon(Color("8a6242")); var dark := Models.toon(Color("4e3424"))
	for sx in [-1.0, 1.0]:
		Models.part(n, Models.cyl(0.06, 0.07, 1.9, 8), wood, Vector3(0.75 * sx, 0.95, 0))
	Models.part(n, Models.cyl(0.05, 0.05, 1.7, 8), dark, Vector3(0, 1.85, 0), Vector3.ONE, Vector3(0, 0, PI / 2))
	var can := MeshInstance3D.new(); can.name = "Canopy"
	can.mesh = Gliders.mesh(Gliders.equipped(), Data.TEAM_COLORS[0], UI.ACCENT)
	can.material_override = Models.vtoon_outlined()
	can.position = Vector3(0, 1.75, 0); can.scale = Vector3.ONE * 0.75; can.rotation = Vector3(-0.35, 0, 0)
	n.add_child(can)
	var sign := Label3D.new(); sign.text = "Gliders"
	sign.font = UI.big; sign.font_size = 40; sign.pixel_size = 0.012; sign.outline_size = 10
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED; sign.position = Vector3(0, 2.35, 0)
	n.add_child(sign)
	return n

func _open_rack() -> void:
	if rack_pick == "": rack_pick = Gliders.equipped()
	var v := _new_panel("Glider skins", 700, true)
	UI.subtitle(v, "What you glide on. Pick one to try it; owned skins equip in a click.")
	UI.head_extra(v).add_child(UI.chip("gem", str(int(Save.d["gems"])), UI.GOLD, "Your gems"))
	# a preview of the picked skin, open and turning, trail and all
	var svc := SubViewportContainer.new(); svc.stretch = true; svc.custom_minimum_size = Vector2(620, 150)
	var vp := SubViewport.new(); vp.own_world_3d = true; vp.transparent_bg = true; vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	var w3 := Node3D.new(); vp.add_child(w3)
	Look.lights(w3, Color("fff1dc"), 1.0)
	var holder := Node3D.new(); w3.add_child(holder)
	var can := MeshInstance3D.new()
	can.mesh = Gliders.mesh(rack_pick, Data.TEAM_COLORS[0], UI.ACCENT)
	can.material_override = Models.vtoon_outlined()
	holder.add_child(can)
	var tr := Gliders.trail(rack_pick, Data.TEAM_COLORS[0], UI.ACCENT)
	if tr: tr.position = Vector3(0, -0.05, 0.3); tr.local_coords = true; tr.direction = Vector3(0, -0.2, 1); holder.add_child(tr)
	var pc := Camera3D.new(); pc.fov = 42
	pc.transform = Transform3D(Basis(), Vector3(0, 2.35, 2.05)).looking_at(Vector3(0, -0.15, 0.05), Vector3.UP)
	w3.add_child(pc)
	holder.set_meta("spin", true)
	svc.set_process(true)
	var spin := func(): if is_instance_valid(holder): holder.rotation.y = sin(Time.get_ticks_msec() / 1400.0) * 0.6
	svc.draw.connect(spin)
	var ticker := Timer.new(); ticker.wait_time = 0.033; ticker.autostart = true; svc.add_child(ticker)
	ticker.timeout.connect(func(): spin.call(); svc.queue_redraw())
	var well := UI.card(Color(0, 0, 0, 0.22), 0, 14)
	well.add_child(svc)
	v.add_child(well)
	var g := Gliders.get_skin(rack_pick)
	var info := UI.hbox(12)
	var it := UI.vbox(2); it.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nrow := UI.hbox(8)
	nrow.add_child(UI.title(String(g["name"]), 24))
	if Gliders.equipped() == rack_pick: nrow.add_child(UI.tag("Equipped", UI.GOOD))
	elif Gliders.owned(rack_pick): nrow.add_child(UI.tag("Owned", UI.TEAL))
	it.add_child(nrow)
	it.add_child(UI.para(String(g["desc"]), UI.T_SMALL, UI.MUTED))
	info.add_child(it)
	v.add_child(info)
	v.add_child(UI.section("All gliders"))
	var grid := GridContainer.new(); grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	for sk in Gliders.LIST:
		var sid: String = sk["id"]
		var owned := Gliders.owned(sid)
		var tc := UI.tile_card(sid == rack_pick, func(): rack_pick = sid; _rack_sound(sid); _open_rack(), 8)
		tc.custom_minimum_size = Vector2(150, 0)
		var tv := UI.vbox(1); tc.add_child(tv)
		var nl := UI.label(String(sk["name"]), UI.T_BODY, UI.INK if owned else UI.MUTED, UI.semi)
		nl.clip_text = true
		tv.add_child(nl)
		var st := "Equipped" if Gliders.equipped() == sid else ("Owned" if owned else ("Earned" if sk.has("unlock") else "%d gems" % int(sk["cost"])))
		tv.add_child(UI.label(st, 12, UI.GOOD if Gliders.equipped() == sid else (UI.MUTED if owned else (UI.FAINT if sk.has("unlock") else UI.GOLD))))
		if not owned:
			tc.tooltip_text = ("%d gems" % int(sk["cost"])) if not sk.has("unlock") else "Earned, not bought"
		grid.add_child(tc)
	v.add_child(grid)
	# footer: hear it, and the one thing you can do with the picked skin
	UI.footer_left(v).add_child(UI.ghost("Hear it", func(): _rack_sound(rack_pick), 0, "wave"))
	var own := Gliders.owned(rack_pick)
	if own:
		if Gliders.equipped() == rack_pick:
			var eq := UI.label("You're gliding on this one", UI.T_SMALL, UI.GOOD, UI.semi); eq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			UI.footer(v).add_child(eq)
		else:
			UI.footer_primary(v, "Equip", func(): _rack_equip(rack_pick), 140, "check")
	elif g.has("unlock"):
		var lk := UI.label(Gliders.how(rack_pick), UI.T_SMALL, UI.ACCENT_HI)
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UI.footer(v).add_child(lk)
	else:
		var cost := int(g["cost"])
		var buy := UI.footer_primary(v, "Buy  ·  %d" % cost, func(): _rack_buy(rack_pick), 170, "gem")
		buy.disabled = int(Save.d["gems"]) < cost
		if buy.disabled: buy.tooltip_text = "You need %d more gems" % (cost - int(Save.d["gems"]))

func _rack_sound(id: String) -> void:
	var ap := AudioStreamPlayer.new()
	ap.stream = Gliders.sound(id, "open")
	ap.bus = "SFX"
	ap.volume_db = -3.0
	add_child(ap)
	ap.play()
	ap.finished.connect(ap.queue_free)

func _rack_buy(id: String) -> void:
	var cost := int(Gliders.get_skin(id).get("cost", 0))
	if int(Save.d["gems"]) < cost:
		return
	Save.d["gems"] = int(Save.d["gems"]) - cost
	if not Save.d.has("gliders"): Save.d["gliders"] = []
	Save.d["gliders"].append(id)
	Sfx.play("unlock")
	_toast("%s unlocked!" % Gliders.get_skin(id)["name"])
	_rack_equip(id)

func _rack_equip(id: String) -> void:
	Gliders.equip(id)
	Save.save_game()
	_rack_sound(id)
	if is_instance_valid(rack_node):
		var can := rack_node.get_node_or_null("Canopy") as MeshInstance3D
		if can: can.mesh = Gliders.mesh(id, Data.TEAM_COLORS[0], UI.ACCENT)
	_refresh_top()
	_open_rack()

# ---- the whistle: press H at home and your kin come running, even from inside the house
func _house_door() -> Vector3:
	if fs and (not spots.has("house") or spots["house"].x < -100.0):
		return HomeLayout.LANDING      # no house yet: the way in is the landing by the portal
	return spots["house"] + HomeLayout.facing(house_r) * 2.1

func _whistle() -> void:
	if whistle_cd > 0.0:
		return
	whistle_cd = 1.6
	_whistle_sound()
	_whistle_ring()
	var my_isle := world.island_of(ppos.x, ppos.z)
	var n := kins.size()
	var inside: Array = []
	var i := 0
	for k in kins:
		var slot := Vector3(cos(TAU * i / maxf(1.0, n) + 0.4), 0, sin(TAU * i / maxf(1.0, n) + 0.4)) * (1.3 + 0.15 * n)
		i += 1
		if k.get("busy", false) or k.has("fetch") or k.has("bath"):
			continue
		var rec: Dictionary = k["rec"]
		# a kin that doesn't trust you might just pretend it didn't hear
		if float(rec["trust"]) < 22.0 and randf() < 0.7:
			if not k.has("indoors"):
				get_tree().create_timer(0.4).timeout.connect(func(): if is_instance_valid(k["node"]): _emote(k, "…"))
			continue
		k["call_slot"] = slot
		if k.has("indoors"):
			inside.append(k)
			continue
		var dist := Vector2(k["pos"].x - ppos.x, k["pos"].z - ppos.z).length()
		get_tree().create_timer(0.12 + dist * 0.015 + randf() * 0.15).timeout.connect(func():
			if not is_instance_valid(k["node"]) or not kins.has(k): return
			k["nap_t"] = 0.0
			k.erase("nap_go"); k.erase("nap_go_t"); k.erase("going_in")
			k["called_t"] = 7.0
			_emote(k, "!")
			Sfx.play("kin_alert", k["pos"], -12.0, 0.15, Unique.voice(k["rec"]))
			if world.island_of(k["pos"].x, k["pos"].z) != my_isle and my_isle >= 0:
				_start_leap(k, ppos + slot))
	if not inside.is_empty():
		_house_alert(inside)

## The whistle itself: a soft, breathy two-note whistle (made in code by Synth.whistle).
func _whistle_sound() -> void:
	if whistle_player == null:
		whistle_player = AudioStreamPlayer.new()
		whistle_player.bus = "SFX"
		add_child(whistle_player)
		whistle_player.stream = Synth.whistle()
	whistle_player.pitch_scale = randf_range(0.97, 1.03)
	whistle_player.volume_db = -4.0
	whistle_player.play()

## A soft ring spreading out from you, and a little note over your head.
func _whistle_ring() -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.92; tm.outer_radius = 1.0; tm.rings = 32; tm.ring_segments = 4
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.92, 0.6, 0.7)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = ppos + Vector3(0, 0.15, 0)
	ring.scale = Vector3(0.4, 1.0, 0.4)
	add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(9.0, 1.0, 9.0), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(ring.queue_free)
	var note := Label3D.new()
	note.text = "♪"
	note.font = UI.big; note.font_size = 64; note.pixel_size = 0.012; note.outline_size = 14
	note.modulate = Color("ffe08a")
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED; note.no_depth_test = true
	note.position = ppos + Vector3(0.35, 2.1, 0)
	add_child(note)
	var nt := note.create_tween().set_parallel(true)
	nt.tween_property(note, "position:y", note.position.y + 0.8, 0.9)
	nt.tween_property(note, "modulate:a", 0.0, 0.9).set_delay(0.3)
	nt.chain().tween_callback(note.queue_free)

## Kin inside the house heard you: a "!" pops over the roof, the house rattles with little feet,
## then they tumble out of the door one after another and run over.
func _house_alert(inside: Array) -> void:
	var at: Vector3 = spots["house"] if spots["house"].x > -100.0 else _house_door()      # no house yet: the landing
	var names: Array = inside.map(func(k): return String(k["rec"]["name"]))
	var bub := Label3D.new()
	bub.text = "!"
	bub.font = UI.big; bub.font_size = 64; bub.pixel_size = 0.012; bub.outline_size = 14
	bub.modulate = UI.GOLD; bub.outline_modulate = Color(0.12, 0.06, 0.1)
	bub.billboard = BaseMaterial3D.BILLBOARD_ENABLED; bub.no_depth_test = true
	bub.position = at + Vector3(0, 3.4, 0)
	bub.scale = Vector3.ONE * 0.1
	add_child(bub)
	var who := Label3D.new()
	who.text = ("%s heard you!" % names[0]) if names.size() == 1 else ("%s and %s heard you!" % [", ".join(names.slice(0, names.size() - 1)), names[-1]])
	who.font = UI.big; who.font_size = 40; who.pixel_size = 0.012; who.outline_size = 12
	who.modulate = UI.INK
	who.billboard = BaseMaterial3D.BILLBOARD_ENABLED; who.no_depth_test = true
	who.position = at + Vector3(0, 2.7, 0)
	who.modulate.a = 0.0
	add_child(who)
	var tw := bub.create_tween()
	tw.tween_property(bub, "scale", Vector3.ONE * 1.25, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bub, "scale", Vector3.ONE, 0.12)
	tw.tween_property(bub, "position:y", bub.position.y + 0.25, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bub, "position:y", bub.position.y, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(1.2)
	tw.tween_property(bub, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bub.queue_free)
	var wt := who.create_tween()
	wt.tween_property(who, "modulate:a", 1.0, 0.2)
	wt.tween_interval(2.0)
	wt.tween_property(who, "modulate:a", 0.0, 0.3)
	wt.tween_callback(who.queue_free)
	Sfx.play("kin_alert", at, -6.0, 0.1, 1.15)
	# the house might be off screen: say it on the HUD as well
	_toast(who.text.replace("heard you!", "heard you from the house and are on their way") if names.size() > 1 else who.text.replace("heard you!", "heard you from the house and is on its way"))
	# the house rattles: little feet scurrying for the door
	if is_instance_valid(house_node):
		var base := house_node.scale
		var ht := house_node.create_tween()
		for j in 4:
			ht.tween_property(house_node, "scale", base * Vector3(1.025, 0.97, 1.025), 0.07)
			ht.tween_property(house_node, "scale", base, 0.09)
			ht.tween_interval(0.08)
	for j in 5:
		get_tree().create_timer(0.15 + j * 0.16).timeout.connect(func(): Sfx.play("step%d" % (j % 3), at, -8.0, 0.2, 1.5))
	for j in inside.size():
		var k: Dictionary = inside[j]
		k["exiting"] = true
		get_tree().create_timer(0.95 + j * 0.35).timeout.connect(func():
			if kins.has(k): _kin_exit_house(k, true))

## Out of the front door (with a little pop), and on to wherever it was going.
func _kin_exit_house(k: Dictionary, called: bool) -> void:
	k.erase("indoors"); k.erase("exiting")
	KinIndoors.left(k)
	var door := _house_door() + Vector3(randf_range(-0.4, 0.4), 0, 0.2)
	k["pos"] = door
	k["vel"] = Vector3(0, 0, 2.5)
	var n: Node3D = k["node"]
	n.position = door
	n.visible = true
	var s0 := n.scale
	n.scale = s0 * 0.3
	n.create_tween().tween_property(n, "scale", s0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("pickup", door, -12.0, 0.1, 1.3)
	if called:
		k["called_t"] = 7.0
		_emote(k, "!")
	else:
		k["goal"] = door + Vector3(randf_range(-3, 3), 0, randf_range(2, 4))
		k["t"] = randf_range(1.0, 3.0)

## Too far to walk (another island): a big happy bound through the air to you.
func _start_leap(k: Dictionary, to: Vector3) -> void:
	var from: Vector3 = k["pos"]
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	k["leap"] = {"a": from, "b": to, "t": 0.0, "dur": clampf(dist / 10.0, 0.6, 1.6), "h": 1.6 + dist * 0.12}
	_emote(k, "!")
	Sfx.play("jump", from, -10.0, 0.1, 1.3)

func _leap_step(k: Dictionary, d: float) -> void:
	var L: Dictionary = k["leap"]
	L["t"] = float(L["t"]) + d
	var f := clampf(float(L["t"]) / float(L["dur"]), 0.0, 1.0)
	var p: Vector3 = (L["a"] as Vector3).lerp(L["b"], f)
	p.y = sin(PI * f) * float(L["h"])
	var n: Node3D = k["node"]
	n.position = p
	var dir: Vector3 = (L["b"] as Vector3) - (L["a"] as Vector3)
	n.rotation.y = lerp_angle(n.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, d * 10.0))
	if f >= 1.0:
		k.erase("leap")
		k["pos"] = Vector3(p.x, 0, p.z)
		n.position = k["pos"]
		k["vel"] = Vector3.ZERO
		Sfx.play("land", k["pos"], -10.0, 0.1, 1.3)

func _emote(k: Dictionary, s: String, force := false) -> void:
	if not force and float(k.get("say_t", 0.0)) > 0.0:
		return
	if not force:
		# one little symbol per huddle, so a group doesn't sprout a cloud of icons
		for o in kins:
			if o != k and float(o.get("emote_t", 0.0)) > 0.4 and Vector2(o["pos"].x - k["pos"].x, o["pos"].z - k["pos"].z).length() < 3.0:
				return
	var lbl: Label3D = k["emote"]
	lbl.text = s
	lbl.modulate = Color("ff8fb0") if s == "♥" else UI.INK
	k["emote_t"] = 1.6

func _find_interact() -> void:
	var best := {}; var bd := 1.9
	var p2 := Vector2(ppos.x, ppos.z)
	for i in plots.size():
		var d := p2.distance_to(Vector2(plots[i].position.x, plots[i].position.z))
		if d < bd: bd = d; best = {"kind": "plot", "arr": "plots", "i": i}
	for i in gh_plots.size():
		var d := p2.distance_to(Vector2(gh_plots[i].position.x, gh_plots[i].position.z))
		if d < bd: bd = d; best = {"kind": "plot", "arr": "gh_plots", "i": i}
	if hob:
		var near_hob := hob.find(p2)
		if not near_hob.is_empty():
			bd = 0.5
			best = near_hob
	for nm in ["pot", "stall", "portal", "house", "ferry", "rack"]:
		if not spots.has(nm) or (nm == "rack" and not visit.is_empty()): continue
		var sp: Vector3 = spots[nm]
		if sp.x < -100.0: continue      # a farm-start fixture not put down yet
		var reach := 2.6 if nm in ["house", "portal"] else 1.9
		if nm == "house": sp = _house_door() - HomeLayout.facing(house_r) * 0.1
		var d := p2.distance_to(Vector2(sp.x, sp.z))
		if d < reach and d < bd + 0.6: bd = d; best = {"kind": nm}
	for b in lots:
		var l: Dictionary = lots[b]
		var dp: Vector3 = l["door"] if l["built"] else l["at"]
		var d := p2.distance_to(Vector2(dp.x, dp.z))
		if d < (1.8 if l["built"] else 2.4) and d < bd + 0.4: bd = d; best = {"kind": "lot", "b": b}
	for k in bridges:
		if bridges[k]["built"]:
			continue
		var sg: Vector2 = HomeLayout.isle_bridge(world, k)["sign"]
		var d := p2.distance_to(sg)
		if d < 2.4 and d < bd + 0.4: bd = d; best = {"kind": "bridge", "isle": k}
	for k in kins:
		if k.has("indoors"): continue
		var d := p2.distance_to(Vector2(k["pos"].x, k["pos"].z))
		if d < bd: bd = d; best = {"kind": "kin", "k": k}
	if visit.is_empty() and is_instance_valid(burrow_node):
		var bdoor := BURROW_AT + _turn(Vector3(0, 0, 1.55), burrow_r)
		var bdd := p2.distance_to(Vector2(bdoor.x, bdoor.z))
		if bdd < 1.7 and bdd < bd + 0.4: bd = bdd; best = {"kind": "burrow"}
	if p2.distance_to(Vector2(NEST_AT.x, NEST_AT.z)) < 1.8 and visit.is_empty():
		best = {"kind": "egg"} if is_instance_valid(nest) else {"kind": "nook"}
	if hinc and p2.distance_to(Vector2(INCUB_AT.x, INCUB_AT.z)) < 1.6 and visit.is_empty():
		best = {"kind": "incubator"}
	if p2.distance_to(Vector2(YARD_AT.x, YARD_AT.z)) < 1.6 and best.is_empty():
		best = {"kind": "yard"}
	if hecon:
		var hb: Dictionary = hecon.find(p2, bd if not best.is_empty() else 9.0)
		if not hb.is_empty(): best = hb
	if hg and visit.is_empty() and (best.is_empty() or bd > 1.2):
		# a wild tree or boulder in reach: chop or mine it (with the right tool)
		var wt := hg.find(p2)
		if not wt.is_empty() and (best.is_empty() or float(wt["d"]) < bd): bd = float(wt["d"]); best = wt
	if hw and visit.is_empty():
		# work stations: any of them opens the Job Board
		for s in HomeLayout.stations(_d()):
			var sc := HomeLayout.deco_center(s["e"])
			var sd := p2.distance_to(Vector2(sc.x, sc.z))
			if sd < 1.7 and (best.is_empty() or sd < bd): bd = sd; best = {"kind": "station", "id": s["id"], "e": s["e"]}
	interact = best
	if panel_open != "" or best.is_empty() or building_now or chat_open or not train.is_empty() or (hb and hb.active):
		prompt_box.visible = false
		return
	prompt_box.visible = true
	var pairs: Array = []
	if best["kind"] == "kin" and visit.is_empty():
		pairs = [[Settings.key_cap("interact"), KinWants.line(best["k"]["rec"], POND_EDGE.x > -100.0)], [Settings.key_cap("play"), "Play fetch"], [Settings.key_cap("talk"), "Talk"], [Settings.key_cap("details"), "Details"]]
	else:
		pairs = [[Settings.key_cap("interact"), _label_for(best)]]
	# the prompt is keycaps and words, rebuilt only when what it says changes
	var sig := str(pairs)
	if String(prompt_box.get_meta("sig", "")) != sig:
		prompt_box.set_meta("sig", sig)
		prompt_lbl.visible = false
		var old_row := prompt_box.get_node_or_null("Keys")
		if old_row: old_row.free()
		var row := UI.key_hints(pairs, 14, UI.INK)
		row.name = "Keys"
		row.add_theme_constant_override("separation", 22)
		for one in row.get_children():
			var l: Label = one.get_child(one.get_child_count() - 1)
			l.add_theme_font_override("font", UI.big)
			l.add_theme_font_size_override("font_size", 18)
			l.add_theme_color_override("font_color", UI.GOLD if one.get_index() == 0 else UI.INK)
		prompt_box.add_child(row)
		prompt_box.reset_size()
		prompt_box.modulate.a = 0.0
		create_tween().tween_property(prompt_box, "modulate:a", 1.0, 0.12)
	prompt_box.reset_size()
	var vp := get_viewport().get_visible_rect().size
	var py_at := vp.y - 110.0
	prompt_box.position = Vector2((vp.x - prompt_box.size.x) * 0.5, py_at)
	_keep_off_hub(prompt_box)

## Point at a kin to see who it is, how it's doing and what you can do with it.
var hover_k: Dictionary = {}
var hover_box: PanelContainer
var hover_lbl: RichTextLabel
func _update_hover() -> void:
	if hover_box == null:
		hover_box = UI.glass(10, 12)
		hover_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hover_lbl = RichTextLabel.new()
		hover_lbl.bbcode_enabled = true; hover_lbl.fit_content = true; hover_lbl.scroll_active = false
		hover_lbl.custom_minimum_size = Vector2(300, 0)
		hover_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hover_lbl.add_theme_font_size_override("normal_font_size", 14)
		hover_lbl.add_theme_font_size_override("bold_font_size", 19)
		hover_lbl.add_theme_font_override("bold_font", UI.big)
		hover_box.add_child(hover_lbl)
		root_ui.add_child(hover_box)
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var best: Dictionary = {}; var bd := 52.0
	if panel_open == "" and not chat_open and not building_now and not Overlay.is_open() and not (hb and hb.active):
		for k in kins:
			if k.has("indoors"): continue
			var np: Vector3 = (k["node"] as Node3D).global_position + Vector3(0, 0.45, 0)
			if cam.is_position_behind(np): continue
			var d := cam.unproject_position(np).distance_to(mp)
			if d < bd: bd = d; best = k
	hover_k = best
	hover_box.visible = not best.is_empty()
	if best.is_empty():
		return
	var rec: Dictionary = best["rec"]
	var sp: Dictionary = Data.KIN[rec["species"]]
	var col: Color = Shiny.body(rec)
	var needs: Dictionary = rec.get("needs", {})
	var nl: Array = []
	for n in Care.NEEDS:
		var v := float(needs.get(n, 100.0))
		nl.append("%s %s" % [n.capitalize(), "[color=#ff8a7a]%d%%[/color]" % int(v) if v < 35.0 else "%d%%" % int(v)])
	var b: Array = Care.bond(rec)
	var t := "[b][color=#%s]%s[/color][/b]\n" % [col.to_html(false), rec["name"]]
	t += "[color=#9aa3b8]Lv %d %s  ·  %s  ·  %s bond[/color]\n" % [int(rec["level"]), Evo.form_name(rec), String(sp["type"]).capitalize(), b[1]]
	if Mutations.special(rec):
		t += "[color=#fff0a0]%s[/color]\n" % ", ".join(Mutations.tags(rec))
	t += "  ·  ".join(nl) + "\n"
	if hw and visit.is_empty():
		var jt := hw.job_text(best)
		var wl: Array = Work.list(rec).map(func(it): return "[color=#%s]%s %d[/color]" % [Work.col_of(String(it[0])).lerp(UI.INK, 0.3).to_html(false), Work.name_of(String(it[0])), int(it[1])])
		t += "[color=#9aa3b8]Work:[/color] %s\n" % "  ".join(wl)
		if jt != "": t += "[color=#ffd36a]%s[/color]\n" % jt
		if rec.get("overworked", false): t += "[color=#ff9a8a]Overworked: it needs a proper rest[/color]\n"
	if visit.is_empty():
		t += "[color=#ffd36a]Click[/color] details    [color=#ffd36a]%s[/color] pet    [color=#ffd36a]%s[/color] fetch    [color=#ffd36a]%s[/color] talk" % [Settings.key_cap("interact"), Settings.key_cap("play"), Settings.key_cap("talk")]
		if rec["uid"] == Save.d.get("active", ""):
			t += "\n[color=#8fe0a0]Your partner: comes on expeditions with you.[/color]"
	hover_lbl.text = t
	hover_box.reset_size()
	var vs := vp.get_visible_rect().size
	var pos := mp + Vector2(20, 16)
	if pos.x + hover_box.size.x > vs.x - 8: pos.x = mp.x - hover_box.size.x - 20
	if pos.y + hover_box.size.y > vs.y - 8: pos.y = mp.y - hover_box.size.y - 16
	hover_box.position = pos

func _label_for(it: Dictionary) -> String:
	if not visit.is_empty():
		match it["kind"]:
			"kin": return ("Pet %s" % it["k"]["rec"]["name"]) if not petted.has(it["k"]["rec"]["uid"]) else "%s is happy you came" % it["k"]["rec"]["name"]
			"house": return "Leave a gift"
			"portal", "ferry": return "Go home"
			"plot": return "%s's crops" % visit.get("name", "Their")
		return "Look around"
	match it["kind"]:
		"ferry": return "Take the ferry"
		"plot":
			var d: Dictionary = Save.d[it["arr"]][it["i"]]
			if d["crop"] == "": return "Plant something"
			var cd: Dictionary = Data.CROPS[d["crop"]]
			if int(d["stage"]) >= int(cd["grow"]): return "Harvest the %s" % cd["name"]
			if it["arr"] == "plots" and FarmWater.plot_near(Save.d, it["i"]):
				return "%s: the water nearby tends it (%s)" % [cd["name"], _grow_left(it["arr"], d)]
			if float(d.get("wt", 0.0)) <= 0.0: return "Water the %s" % cd["name"]
			if int(d.get("wet", 2)) < 2: return "Water the %s (the rain only soaked it)" % cd["name"]
			return "%s: watered, growing (%s)" % [cd["name"], _grow_left(it["arr"], d)]
		"pot": return "Cook"
		"rack": return "Glider skins"
		"stall": return "Shop"
		"portal": return "Start an expedition"
		"house": return "Go inside"
		"lot":
			var bd: Dictionary = Data.BUILDINGS[it["b"]]
			if lots[it["b"]]["built"]: return _building_verb(it["b"])
			return "Build a %s" % bd["name"]
		"bridge": return "Build a bridge to %s" % Data.ISLES[it["isle"]]["name"]
		"kin":
			var rec: Dictionary = it["k"]["rec"]
			return "Spend time with %s" % rec["name"]
		"egg": return ("Help the %s hatch!" if _egg_ready() else "Warm the %s") % _egg_label()
		"yard": return "Train your partner"
		"nook": return "Pair two Boki for an egg"
		"incubator": return hinc.prompt()
		"burrow": return "Open the Boki Burrow (%d asleep inside)" % KinBox.boxed().size()
		"hob", "site": return hob.label(it)
		"feeder", "grave", "graveyard", "place": return hecon.label(it)
		"station": return "Job Board" if it["id"] == "job_board" else "%s: assign a Boki" % HomeLayout.CATALOG[it["id"]]["name"]
		"wild": return hg.label(it)
	return ""

func _use(it: Dictionary) -> void:
	Sfx.play("click")
	if not visit.is_empty():
		_use_visiting(it)
		return
	match it["kind"]:
		"ferry": _open_ferry()
		"plot": _open_plot(it["arr"], it["i"])
		"lot": _open_lot(it["b"])
		"bridge": _open_bridge(it["isle"])
		"pot": _open_kitchen()
		"rack": _open_rack()
		"stall": hmk.open()
		"portal": _open_expedition()
		"house": Game.goto("interior", {"room": "house"})
		"kin": _kin_act(it["k"])
		"egg":
			if _egg_ready():
				_hatch_nest_egg()
			else:
				fx.burst(NEST_AT + Vector3(0, 0.5, 0), Color("ffd28a"), 8, 1.4)
				_toast("It hatches after your next expedition")
		"yard":
			var ak := Save.active_kin()
			if not ak.is_empty(): _open_train(ak)
		"nook": _open_nook()
		"incubator":
			if Incubator.any_ready(): _hatch_incubator(String(hinc.nearest_ready(ppos).get("id", "")))
			else: nook_tab = "Incubator"; _open_nook()
		"burrow": _open_burrow()
		"hob", "site": hob.use(it)
		"feeder", "grave", "graveyard", "place": hecon.use(it)
		"station":
			if it["id"] == "job_board" or not hw: open_job_board()
			else: hw.open_station(it["e"])
		"wild": hg.use(it)

## The Job Board: job priorities, who's doing what, pinning kin (scripts/ui/work_view.gd).
func open_job_board(tab := "") -> void:
	if tab != "": WorkView.tab = tab
	if hw: hw.scan()
	WorkView.open(self)

func _unhandled_input(event: InputEvent) -> void:
	if hb and hb.active and panel_open == "" and not Overlay.is_open():
		if hb.input(event):
			get_viewport().set_input_as_handled()
			return
	elif hb and event.is_action_pressed("build") and hb.can_build():
		hb.toggle()
		get_viewport().set_input_as_handled()
		return
	if not train.is_empty():
		if event.is_action_pressed("interact") or event.is_action_pressed("jump") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			_train_hit()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("menu"):
			# walk away from the drill
			var tk: Dictionary = train["k"]
			tk["busy"] = false
			train = {}
			if is_instance_valid(train_bar): train_bar.queue_free()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and panel_open == "":
		# click a kin to see its details
		if event.button_index == MOUSE_BUTTON_LEFT and not hover_k.is_empty() and visit.is_empty() and not building_now and not chat_open:
			_open_kin(hover_k["rec"])
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: cam.zoom_to = clampf(cam.zoom_to - 0.08, 0.55, 1.6)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: cam.zoom_to = clampf(cam.zoom_to + 0.08, 0.55, 1.6)
	if panel_open == HomeClasses.TITLE and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_K and has_meta("hero_hover"):
		HomeHero.kit(self, String(get_meta("hero_hover")))      # K on the Hunters screen: its full kit card
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("hero") and visit.is_empty() and not chat_open and not Overlay.is_open() and not building_now and (panel_open == "" or panel_open == HomeClasses.TITLE):
		if panel_open == HomeClasses.TITLE: _close_panel()
		else: HomeHero.open(self)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("whistle") and panel_open == "" and not chat_open and visit.is_empty() and train.is_empty() and not Overlay.is_open():
		_whistle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu") and hecon and not hecon.carry.is_empty():
		hecon.cancel_carry()
		get_viewport().set_input_as_handled()
		return
	if panel_open != "" and not Overlay.is_open() and event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER) and not (get_viewport().gui_get_focus_owner() is LineEdit):
		if UI.press_primary(panel_host):
			get_viewport().set_input_as_handled()
			return
	if not Overlay.is_open() and _hub_key(event):
		get_viewport().set_input_as_handled()
		return
	if panel_open != "" and not Overlay.is_open() and event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"):
		_close_panel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu") and not Overlay.is_open():
		if chat_open:
			_close_chat()
		elif panel_open != "":
			_close_panel()
		else:
			Overlay.open_pause("home")

# ------------------------------------------------------------------ ui
func _build_ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root_ui)
	# top left: your partner and what you have, as quiet chips on glass
	var top := UI.glass(6, 14)
	top.position = Vector2(16, 14)
	var th := UI.hbox(10); top.add_child(th)
	top_chips = UI.hbox(6)
	th.add_child(top_chips)
	topbar = UI.label("", 15, UI.INK)
	topbar.autowrap_mode = TextServer.AUTOWRAP_OFF
	topbar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topbar.visible = false
	th.add_child(topbar)
	root_ui.add_child(top)
	# what F (and the kin keys) do with whatever is in front of you
	prompt_box = UI.glass(10, 16)
	prompt_lbl = UI.label("", 18, UI.GOLD, UI.big)
	prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt_box.add_child(prompt_lbl)
	root_ui.add_child(prompt_box)
	# bottom centre: the few keys you need to get about
	var hint_box := UI.glass(6, 12)
	hint_box.modulate.a = 0.85
	var keys := UI.key_hints([["W A S D", "walk"], ["Space", "jump"], [Settings.key_cap("interact"), "use"], [Settings.key_cap("whistle"), "whistle"], [Settings.key_cap("build"), "build"], ["Esc", "menu"]], 12, Color(1, 1, 1, 0.78))
	hint_box.add_child(keys)
	hint = UI.label("", 14, UI.INK)     # kept for code that still sets hint text; the key row replaces it
	hint.visible = false
	keys.add_child(hint)
	root_ui.add_child(hint_box)
	hint_box.name = "Hints"
	Record.hide_in_clean(hint_box)      # recording mode: no key hints
	Record.hide_in_cinema(ui)           # ... and with the HUD hidden, none of this
	hint_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	hint_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if visit.is_empty():
		_build_hub()
	# menus open over a blurred, dimmed farm
	panel_dim = UI.backdrop()
	panel_dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and panel_open != "":
			_close_panel())
	root_ui.add_child(panel_dim)
	panel_host = CenterContainer.new()
	panel_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(panel_host)

# ---- the hub: one bar of the places you go most, each a click or a number key away
var panel_dim: ColorRect = null
var hub: Control = null
var hub_btns := {}            # id -> Button

## The hub's entries, in order: [id, label, icon, open]. Other systems can add to this before the
## UI is built, or replace an entry's Callable (Build mode and the Kin Box hook in here).
func hub_items() -> Array:
	var open_kin := func():
		if has_method("open_kin_box"): call("open_kin_box")
		elif not Save.active_kin().is_empty(): _open_kin(Save.active_kin())
	var items: Array = []
	items.append(["expedition", "Expedition", "portal", _open_expedition])
	items.append(["kin", "Boki", "paw", open_kin])
	items.append(["bag", "Bag", "bag", func(): Overlay.open_inventory()])
	items.append(["shop", "Market", "shop", func(): hmk.open()])
	if has_method("open_build"):
		items.append(["build", "Build", "hammer", func(): call("open_build")])
	items.append(["settings", "Settings", "gear", func(): Overlay.ctx = "home"; Overlay.open_settings()])
	items.append(["hero", "Relics", "swap", func(): HomeHero.open(self)])
	return items

func _build_hub() -> void:
	hub = HubBar.build(hub_items(), _hub_go, hub_btns)
	root_ui.add_child(hub)
	hub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	hub.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _hub_go(cb: Callable, id: String) -> void:
	if chat_open: _close_chat()
	if Overlay.is_open(): Overlay.close()
	if panel_open != "" and String(get_meta("hub_open", "")) == id:
		_close_panel()
		return
	cb.call()
	set_meta("hub_open", id)

## Number keys open the hub entries (pressing the same one again closes it).
func _hub_key(event: InputEvent) -> bool:
	if hub == null or not visit.is_empty() or not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if building_now or not train.is_empty() or chat_open:
		return false
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return false
	var k := (event as InputEventKey).physical_keycode
	var i := k - KEY_1
	var items := hub_items()
	if i < 0 or i >= items.size() or k > KEY_9:
		return false
	_hub_go(items[i][3], String(items[i][0]))
	return true

var build_btn: Button = null
## Build mode hides the walking hints and the Build button while its own bar is up.
func set_build_ui(on: bool) -> void:
	var hb_box := root_ui.get_node_or_null("Hints")
	if hb_box: hb_box.visible = not on
	if is_instance_valid(build_btn): build_btn.visible = not on
	var hub_bar = get("hub")         # the menus branch's bottom-left hub bar, when it's merged
	if hub_bar is CanvasItem: (hub_bar as CanvasItem).visible = not on

## Opens build mode (for a Build entry in the home's hub bar).
func open_build() -> void:
	if hb and not hb.active:
		hb.toggle()

func _refresh_top() -> void:
	if not visit.is_empty():
		topbar.text = "Visiting %s's island   ·   Pet their Boki, leave a gift at the house   ·   The portal takes you home" % String(visit.get("name", "a friend")).substr(0, 16)
		topbar.visible = true
		return
	topbar.visible = false
	var crops := 0
	for k in Save.d["crops"]: crops += int(Save.d["crops"][k])
	var ak := Save.active_kin()
	var treat: String = Save.d.get("treat", "")
	for ch in top_chips.get_children():
		ch.queue_free()
	if not ak.is_empty():
		var kc: Color = Data.KIN.get(String(ak.get("species", "")), {}).get("color", UI.ACCENT)
		top_chips.add_child(_top_chip("paw", String(ak.get("name", "")), kc, "Your partner: the Boki that comes on expeditions with you"))
	top_chips.add_child(_top_chip("gem", str(int(Save.d["gems"])), UI.GOLD, "Gems: spend them on buildings, seeds and treats"))
	top_chips.add_child(_top_chip("tonic", str(int(Save.d["items"].get("tonic", 0))), Color("ff8a9a"), "Tonics: drink one (1) on an expedition to heal"))
	top_chips.add_child(_top_chip("seed", str(crops), UI.GOOD, "Crops you've harvested"))
	if fs or Work.mat("wood") > 0 or Work.mat("stone") > 0:
		top_chips.add_child(_top_chip("dash", FarmSites.mats_text(), Color("d8b07a"), "Building materials: wood and stone from the wild (an axe and a pickaxe from the market) or a Lumber Camp and a Quarry, fibre from harvests and clearing the wild, Ember Coals from a Kiln. They pay for buildings and upgrades."))
	if treat != "":
		top_chips.add_child(_top_chip("heart", "Treat: " + _treat_name(treat), Color("ffb0d0"), "A treat is ready to give to a Boki"))

## One number on the top bar: an icon, the value, and a tooltip saying what it is.
func _top_chip(icon: String, txt: String, col: Color, tip := "") -> Control:
	return UI.chip(icon, txt, col, tip, 14)

func _treat_name(t: String) -> String:
	for k in Data.CROPS:
		if Data.CROPS[k]["use"] == t: return Data.CROPS[k]["name"]
	return t

func _new_panel(title_txt: String, width := 520.0, scroll := false) -> VBoxContainer:
	var prev := panel_open
	# the same panel rebuilt (a button on it changed something, as the expedition loadout's do):
	# keep it scrolled where it was instead of jumping back to the top
	var keep_scroll := -1
	if prev == title_txt:
		var old_sc := _panel_scroll()
		if old_sc: keep_scroll = old_sc.scroll_vertical
	_close_panel()
	var pb := UI.scroll_panel(title_txt, width, _close_panel, "Close", scroll)
	var p: PanelContainer = pb[0]
	var v: VBoxContainer = pb[1]
	panel_host.add_child(p)
	panel_open = title_txt
	# the blur and the panel go over everything else on the screen (the day-one list, toasts)
	root_ui.move_child(panel_dim, -1)
	root_ui.move_child(panel_host, -1)
	UI.show_backdrop(panel_dim, true)
	if hub: hub.visible = false
	if prev != title_txt:
		UI.pop_in(p)
		Sfx.play("whoosh", null, -10.0)
	if keep_scroll > 0 and not has_meta("no_keep_scroll"):
		_restore_scroll(p, keep_scroll, 4)
	return v

## The scroll of the open panel (the newest one in the host), or null.
func _panel_scroll() -> ScrollContainer:
	var kids := panel_host.get_children().filter(func(ch): return not ch.is_queued_for_deletion())
	if kids.is_empty():
		return null
	var found := (kids[-1] as Node).find_children("*", "ScrollContainer", true, false)
	return found[0] as ScrollContainer if not found.is_empty() else null

## Put a rebuilt panel back where it was scrolled to, once its content has been laid out (the panel
## sizes its scroll a frame or two after it's built, so this tries for a few frames).
func _restore_scroll(p: Control, val: int, tries: int) -> void:
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	var found := p.find_children("*", "ScrollContainer", true, false)
	if found.is_empty():
		return
	var sc: ScrollContainer = found[0]
	sc.scroll_vertical = val
	if tries <= 0:
		return
	# next frame, try again (the panel sizes its scroll a frame or two late, and a late resize can
	# clamp it back toward the top). By id: the panel may be gone by then.
	var pid := p.get_instance_id()
	get_tree().process_frame.connect(func():
		var pp := instance_from_id(pid) as Control
		if pp: _restore_scroll(pp, val, tries - 1), CONNECT_ONE_SHOT)

func _close_panel() -> void:
	var was := panel_open
	for ch in panel_host.get_children():
		ch.queue_free()
	panel_open = ""
	chat_input = null
	set_meta("hub_open", "")
	if panel_dim and not was.is_empty(): UI.show_backdrop(panel_dim, false)
	if hub: hub.visible = true
	_refresh_top()
	_refresh_burrow()
	if was.ends_with(" evolved") or was.ends_with(" is changing") or was == "Welcome home":
		_play_evolutions.call_deferred()

func _open_welcome() -> void:
	# shown once: marked seen as soon as it opens, however it's closed
	Save.d["tutorial"]["home"] = true
	Save.save_game()
	var kn: String = Save.active_kin().get("name", "your Boki")
	var v := _new_panel("Welcome home", 580)
	UI.subtitle(v, "This island is yours, and %s lives here with you." % kn)
	v.add_child(UI.para("Hob will show you around. Out in the wild, what you find is only yours once you make it back.", UI.T_BODY, UI.MUTED))
	var b := UI.footer_primary(v, "Let's go", func():
		Save.d["tutorial"]["home"] = true
		Save.save_game()
		_close_panel(), 160)
	b.grab_focus.call_deferred()

# ---- farm
## How long until the next stage, for a watered plant.
func _grow_left(arr: String, d: Dictionary) -> String:
	var need := Data.WATER_TIME * (0.5 if arr == "gh_plots" else 1.0)
	var left := int(ceil(need - (Time.get_unix_time_from_system() - float(d.get("wt", 0.0)))))
	return "%ds" % maxi(1, left)

## Watered plants grow while you're home; rain and a farmhand kin water for you.
func _farm_tick() -> void:
	if not visit.is_empty():
		return
	var now := Time.get_unix_time_from_system()
	for arr in ["plots", "gh_plots"]:
		var nodes: Array = plots if arr == "plots" else gh_plots
		for i in mini(nodes.size(), Save.d[arr].size()):
			var d: Dictionary = Save.d[arr][i]
			if d["crop"] == "":
				continue
			var cd: Dictionary = Data.CROPS[d["crop"]]
			if int(d["stage"]) >= int(cd["grow"]):
				continue
			var wt := float(d.get("wt", 0.0))
			var by_water: bool = arr == "plots" and FarmWater.plot_near(Save.d, i)
			if (wt <= 0.0 or (by_water and int(d.get("wet", 2)) < 2)) and (raining or by_water):
				_water(arr, i, "stream" if by_water else "rain")
				continue
			if wt > 0.0 and now - wt >= FarmCropGuide.stage_time(Data.WATER_TIME * (0.5 if arr == "gh_plots" else 1.0)):
				d["stage"] = int(d["stage"]) + 1
				# rain only makes it wet; watering it yourself (or a farmhand kin) is what counts as tending
				if int(d.get("wet", 2)) >= 2:
					d["care"] = int(d.get("care", 0)) + 1
				d["wt"] = 0.0
				d["wet"] = 0
				var pn: Node3D = nodes[i]
				fx.burst(pn.position + Vector3(0, 0.5, 0), Color("8fd16a"), 8, 1.6)
				_refresh_plot(arr, i)
				if int(d["stage"]) >= int(cd["grow"]):
					_toast("%s is ready to harvest" % cd["name"])
				Save.save_game()

## The first planted, unwatered plant the farmhand can reach.
func _dry_plot() -> Array:
	for arr in ["plots", "gh_plots"]:
		var nodes: Array = plots if arr == "plots" else gh_plots
		for i in mini(nodes.size(), Save.d[arr].size()):
			var d: Dictionary = Save.d[arr][i]
			var by_water: bool = arr == "plots" and FarmWater.plot_near(Save.d, i)
			var dry: bool = float(d.get("wt", 0.0)) <= 0.0 or int(d.get("wet", 2)) < 2
			if d["crop"] != "" and dry and int(d["stage"]) < int(Data.CROPS[d["crop"]]["grow"]) and not by_water:
				if arr == "plots" or _isle_open("orchard"):
					return [arr, i]
	return []

## Watering. who: "you" (by hand), "kin" (a farmhand) or "rain". Rain makes a plant wet so it
## grows; by hand (or a farmhand) it's also tended, which is what earns the bigger harvest. A plant
## the rain already soaked can still be watered by hand to tend it, without restarting its growth.
func _water(arr: String, i: int, who = "you") -> void:
	if typeof(who) == TYPE_BOOL: who = "you" if who else "rain"
	var d: Dictionary = Save.d[arr][i]
	var already := float(d.get("wt", 0.0)) > 0.0
	if not already:
		d["wt"] = Time.get_unix_time_from_system()
	d["wet"] = 1 if who == "rain" else 2
	var pn: Node3D = _plot_node(arr, i)
	if who == "you":
		Sfx.play("plant", null, -6.0, 0.1, 1.4)
		fx.burst(pn.position + Vector3(0, 0.8, 0), Color("7ac8ff"), 14, 2.0)
		if already:
			fx.burst(pn.position + Vector3(0, 0.9, 0), Color("bfefff"), 10, 2.4)
			_toast("Tended: a bigger harvest")
	_refresh_plot(arr, i)
	Save.save_game()

func _open_plot(arr: String, i: int) -> void:
	var d: Dictionary = Save.d[arr][i]
	var pn: Node3D = _plot_node(arr, i)
	if d["crop"] != "":
		var cd: Dictionary = Data.CROPS[d["crop"]]
		var grow := int(cd["grow"])
		if int(d["stage"]) >= grow:
			_harvest(arr, i, "you")
			return
		if float(d.get("wt", 0.0)) <= 0.0 or int(d.get("wet", 2)) < 2:
			_water(arr, i)
			return
		var v := _new_panel(cd["name"], 440)
		if arr == "plots" and FarmWater.plot_near(Save.d, i):
			v.add_child(UI.label("This patch is by the water, so it waters itself.", 14, UI.GOOD))
		v.add_child(UI.label("Watered. It grows a stage in %s while you're home, or after your next expedition." % _grow_left(arr, d), 16))
		v.add_child(UI.label("Stage %d of %d. Tended %d time%s: %s" % [int(d["stage"]), grow, int(d.get("care", 0)), "" if int(d.get("care", 0)) == 1 else "s",
			"water it every stage for a bigger harvest, and maybe a seed back." if int(d.get("care", 0)) < grow else "it'll be a big harvest."], 14, UI.MUTED))
		v.add_child(UI.label(cd["desc"], 14, UI.MUTED))
		return
	var v := _new_panel("Plant a seed", 480)
	var any := false
	for s in Data.CROPS:
		var n := int(Save.d["seeds"].get(s, 0))
		if n <= 0: continue
		any = true
		var rc := UI.card(UI.CARD, 10, 12)
		var row := UI.hbox(12); rc.add_child(row)
		row.add_child(UI.IconDot.new("seed", Data.CROPS[s]["color"], 22.0))
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label("%s  ×%d" % [Data.CROPS[s]["name"], n], UI.T_BODY, UI.INK, UI.semi))
		info.add_child(UI.para("%d stages. %s" % [Data.CROPS[s]["grow"], Data.CROPS[s]["desc"]], 12, UI.MUTED))
		row.add_child(info)
		var sk: String = s
		row.add_child(UI.button("Plant", func():
			Save.d["seeds"][sk] = int(Save.d["seeds"][sk]) - 1
			d["crop"] = sk; d["stage"] = 0; d["care"] = 0; d["wt"] = 0.0
			Sfx.play("plant")
			fx.dust(pn.position, 10)
			_refresh_plot(arr, i)
			Save.save_game()
			_close_panel(), 0, "plus"))
		v.add_child(rc)
	if not any:
		v.add_child(UI.empty_state("seed", "No seeds", "Find them in chests and from monsters on expeditions, or buy some at the stall."))
	UI.subtitle(v, "Water it (%s) and it grows a stage every %d seconds while you're home." % [Settings.key_cap("interact"), int(Data.WATER_TIME)])

## Picking a ripe crop (by hand, or a Forage kin). A tended plant gives more, and a fully tended
## common one sometimes gives a seed back. Returns how many it gave.
func _harvest(arr: String, i: int, who := "you") -> int:
	var d: Dictionary = Save.d[arr][i]
	if d["crop"] == "":
		return 0
	var cd: Dictionary = Data.CROPS[d["crop"]]
	var grow := int(cd["grow"])
	if int(d["stage"]) < grow:
		return 0
	var pn: Node3D = _plot_node(arr, i)
	var care := int(d.get("care", 0))
	var n := 2 + (1 if care * 2 >= grow else 0)
	Save.d["crops"][d["crop"]] = int(Save.d["crops"].get(d["crop"], 0)) + n
	Progress.add("harvested", n)
	FarmSites.on_harvest(n)
	var extra := ""
	# a fully tended common crop sometimes drops a seed (rare ones never do)
	if care >= grow and float(cd.get("weight", 1.0)) >= 1.0 and randf() < 0.5:
		Save.add_seed(d["crop"], 1)
		extra = " and a seed"
	fx.burst(pn.position + Vector3(0, 0.6, 0), cd["color"], 18 + n * 4, 3.0)
	Sfx.play("harvest", null if who == "you" else pn.position, 0.0 if who == "you" else -8.0)
	if who == "you":
		_toast("%d %s%s%s" % [n, cd["name"], "" if n == 1 else "s", extra])
	d["crop"] = ""; d["stage"] = 0; d["care"] = 0; d["wt"] = 0.0; d["wet"] = 0
	d.erase("tend")
	_refresh_plot(arr, i)
	Save.save_game()
	_refresh_top()
	return n

func _open_kitchen() -> void:
	var v := _new_panel("Cooking pot", 560)
	UI.subtitle(v, "Crops become tonics for the match, or a treat for your partner.")
	var any := false
	for s in Data.CROPS:
		var n := int(Save.d["crops"].get(s, 0))
		if n <= 0: continue
		any = true
		var cd: Dictionary = Data.CROPS[s]
		var rc := UI.card(UI.CARD, 10, 12)
		var row := UI.hbox(12); rc.add_child(row)
		row.add_child(UI.IconDot.new("seed", cd["color"], 22.0))
		var info := UI.vbox(2); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label("%s  ×%d" % [cd["name"], n], UI.T_BODY, UI.INK, UI.semi))
		info.add_child(UI.para(cd["desc"], 12, UI.MUTED))
		row.add_child(info)
		var sk: String = s
		var label_txt: String = {"tonic": "Brew 2 tonics", "snack": "Feed a snack", "levelup": "Feed it"}.get(cd["use"], "Make the treat")
		row.add_child(UI.button(label_txt, func():
			var ak := Save.active_kin()
			if (cd["use"] == "snack" or cd["use"] == "levelup") and ak.is_empty():
				_toast("You need a partner Boki for that")
				return
			Save.d["crops"][sk] = int(Save.d["crops"][sk]) - 1
			match String(cd["use"]):
				"tonic": Save.add_item("tonic", 2)
				"snack":
					Save.remember(ak, "fed", "got a %s snack from you" % cd["name"], 4.0)
					_toast("%s loved the snack" % ak["name"])
				"levelup":
					var today := int(Time.get_unix_time_from_system() / 86400.0)
					if int(ak.get("starfruit_day", -1)) == today:
						Save.d["crops"][sk] = int(Save.d["crops"][sk]) + 1
						_toast("%s is still full from the last one. Try again tomorrow" % ak["name"])
						return
					ak["starfruit_day"] = today
					ak["level"] = int(ak["level"]) + 1
					var out := {}
					Game._evolve(ak, out)
					Save.remember(ak, "fed", "ate a Starfruit and grew stronger", 2.0)
					_toast("%s is now level %d" % [ak["name"], int(ak["level"])])
					_play_evolutions()
				_: Save.d["treat"] = cd["use"]
			Sfx.play("heal")
			fx.burst(spots["pot"] + Vector3(0, 1.0, 0), cd["color"], 20, 3.0)
			Save.save_game()
			_open_kitchen(), 0, "tonic" if cd["use"] == "tonic" else "heart"))
		v.add_child(rc)
	if not any:
		v.add_child(UI.empty_state("seed", "Nothing to cook yet", "Harvest crops from your plots first."))
	if Save.d.get("treat", "") != "":
		UI.head_extra(v).add_child(UI.chip("heart", "Treat: " + _treat_name(Save.d["treat"]), Color("ffb0d0"), "Ready for the next match"))

## The Challenge House: goals with rewards. Finished ones are claimed here for gems, and some open
## up new goods at the market.
var chal_page := 0
func _open_challenges() -> void:
	var v := _new_panel("Challenge House", 800)
	var ready := Progress.ready_to_claim()
	var donec: int = Save.d.get("challenges", []).size()
	UI.subtitle(v, "Goals with rewards. Finished ones are claimed here, and some open new goods at the market.")
	UI.head_extra(v).add_child(UI.chip("check", "%d/%d" % [donec, Progress.CHALLENGES.size()], UI.GOOD, "Challenges done"))
	if ready.size() > 0:
		UI.head_extra(v).add_child(UI.tag("%d to claim" % ready.size(), UI.GOLD))
	# ready first, then in progress, then finished
	var list: Array = Progress.CHALLENGES.duplicate()
	list.sort_custom(func(a, b):
		var ra := 0 if ready.has(a) else (2 if Progress.done(a[0]) else 1)
		var rb := 0 if ready.has(b) else (2 if Progress.done(b[0]) else 1)
		return ra < rb)
	# every goal on one page: three columns of compact rows, ready ones first
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 8)
	for c in list:
		grid.add_child(_challenge_card(c, ready.has(c)))
	v.add_child(grid)

## One goal as a compact row: its name, a progress bar with the count, and its reward (or Claim).
## What it asks and what it unlocks show on hover.
func _challenge_card(c: Array, ready: bool) -> Control:
	var donec := Progress.done(c[0])
	var card := UI.card(UI.CARD if not donec else Color(0.1, 0.14, 0.12, 0.9), 9, 10)
	card.custom_minimum_size = Vector2(240, 0)
	var ul: Array = Progress.unlocks_of(c[0]).map(func(k): return Progress.item_name(k))
	card.tooltip_text = String(c[2]) + (("\nUnlocks " + ", ".join(ul)) if ul.size() > 0 else "")
	var hr := UI.hbox(10); card.add_child(hr)
	var lv := UI.vbox(4); lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(String(c[1]), UI.T_BODY, UI.INK if not donec else UI.MUTED, UI.semi)
	nm.clip_text = true
	lv.add_child(nm)
	var pr := UI.hbox(8)
	var cur := mini(Progress.stat(c[3]), int(c[4]))
	var bar := ProgressBar.new(); bar.max_value = float(c[4]); bar.value = float(cur); bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if donec:
		bar.add_theme_stylebox_override("fill", UI.frame(UI.GOOD, 5, Color(0, 0, 0, 0), 0, 0.0, 0.0, 0.25))
	pr.add_child(bar)
	pr.add_child(UI.label("%d / %d" % [cur, int(c[4])], 12, UI.MUTED))
	if ul.size() > 0: pr.add_child(UI.IconDot.new("lock" if not donec else "check", UI.FAINT, 12.0))
	lv.add_child(pr)
	hr.add_child(lv)
	if ready:
		var cb := UI.primary("Claim +%d" % int(c[5]), func():
			var g := Progress.claim(c[0])
			if g > 0:
				Sfx.play("unlock")
				_toast("%s done!  +%d gems" % [c[1], g])
				_refresh_top()
			_open_challenges(), 0)
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(cb)
	elif donec:
		hr.add_child(UI.tag("Done", UI.GOOD))
	else:
		hr.add_child(UI.chip("gem", "+%d" % int(c[5]), UI.GOLD, "Reward", 13))
	return card

# ---- kin
# ---- kin: petting, playing and talking happen out in the world; only the details card is a menu
func _kin_entry(rec: Dictionary) -> Dictionary:
	for k in kins:
		if k["rec"] == rec: return k
	return {}

func _face(at: Vector3) -> void:
	pface = atan2(-(at.x - ppos.x), -(at.z - ppos.z))
	player.rotation.y = pface

## The interact key on a Boki: do something about what it wants, otherwise pet it.
func _kin_act(k: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	match KinWants.action(rec, POND_EDGE.x > -100.0):
		"feed": _care_feed(rec, KinWants.best_food(rec))
		"nap": _care_nap(rec)
		"bath": _care_bath(rec)
		"brush": _care_brush(rec)
		_: _pet_kin(k)

func _pet_kin(k: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	if float(k.get("nap_t", 0.0)) > 0.0:
		# a gentle pat wakes it up
		k["nap_t"] = 0.01
	var loves_pet: bool = rec["likes"]["play"] == "pet"
	var now_s := Time.get_ticks_msec() / 1000.0
	if now_s >= float(k.get("pet_ok", 0.0)):
		k["pet_ok"] = now_s + 20.0
		Care.change(rec, "joy", 12.0 if loves_pet else 5.0)
	if loves_pet and Care.discover(rec, "play"): _toast("%s loves scratches" % rec["name"])
	k["hold_t"] = 1.0
	k["joy_t"] = 0.9
	_face(k["pos"])
	_emote(k, "♥", true)
	fx.burst(k["pos"] + Vector3(0, 0.9, 0), Color("ff8fb0"), 12, 1.8)
	Sfx.play("kin_happy", null, -4.0, 0.12, Unique.voice(rec))
	if pet_done.get(rec["uid"], -1) != int(Save.d["matches"]):
		pet_done[rec["uid"]] = int(Save.d["matches"])
		Save.remember(rec, "petted", "got a long scratch behind the ears", 1.5)
		Save.save_game()
		_say(k, BokiLines.say(rec, "petted"))

## Fetch: you toss a ball toward the cursor, the kin runs it down and brings it back.
func _play_with_kin(k: Dictionary) -> void:
	if k.has("fetch"):
		return
	var aim := cam.mouse_on_plane(0.0)
	var dir := Vector2(aim.x - ppos.x, aim.z - ppos.z)
	if dir.length() < 1.0: dir = Vector2(sin(pface), cos(pface)) * -1.0
	var to := ppos + Vector3(dir.normalized().x, 0, dir.normalized().y) * clampf(dir.length(), 3.0, 7.0)
	for _i in 8:
		if not world.is_void(to.x, to.z) and not world.is_block(to.x, to.z): break
		to = ppos + (to - ppos) * 0.75
	if world.is_void(to.x, to.z) or world.is_block(to.x, to.z):
		to = ppos + Vector3(1.5, 0, 0)
	var ball := MeshInstance3D.new()
	ball.mesh = Models.sphere(0.16, 12)
	ball.material_override = Models.toon(Color("ff6a5a"))
	add_child(ball)
	ball.position = ppos + Vector3(0, 1.2, 0)
	_face(to)
	k["fetch"] = {"ball": ball, "from": ball.position, "to": to, "t": 0.0, "phase": "fly", "life": 14.0}
	k.erase("chase"); k.erase("task")
	_emote(k, "!")
	Sfx.play("throw", null, -8.0)

func _fetch_step(k: Dictionary, d: float) -> void:
	var f: Dictionary = k["fetch"]
	var ball: MeshInstance3D = f["ball"]
	f["life"] -= d
	var pos: Vector3 = k["pos"]
	match String(f["phase"]):
		"fly":
			f["t"] += d
			var q := clampf(f["t"] / 0.7, 0.0, 1.0)
			var a: Vector3 = f["from"]; var b: Vector3 = f["to"] + Vector3(0, 0.16, 0)
			ball.position = a.lerp(b, q) + Vector3(0, 2.2 * q * (1.0 - q), 0)
			k["goal"] = f["to"]
			if q >= 1.0: f["phase"] = "ground"
		"ground":
			k["goal"] = f["to"]
			if Vector2(pos.x - f["to"].x, pos.z - f["to"].z).length() < 0.55:
				f["phase"] = "carry"
				Sfx.play("pickup", null, -14.0)
		"carry":
			ball.position = pos + Vector3(0, 0.75, 0)
			k["goal"] = ppos
			if Vector2(pos.x - ppos.x, pos.z - ppos.z).length() < 1.3:
				f["life"] = -1.0
				_emote(k, "★")
				k["joy_t"] = 0.8
				Sfx.play("kin_happy", null, -6.0)
				var rec: Dictionary = k["rec"]
				var loves_fetch: bool = rec["likes"]["play"] == "fetch"
				Care.change(rec, "joy", 24.0 if loves_fetch else 14.0)
				Care.change(rec, "energy", -6.0)
				Care.change(rec, "clean", -4.0)
				if loves_fetch and Care.discover(rec, "play"): _toast("%s loves playing fetch" % rec["name"])
				if int(rec.get("played", -1)) != int(Save.d["matches"]):
					rec["played"] = int(Save.d["matches"])
					Save.remember(rec, "played", "played fetch with you on the farm", 1.5)
					Save.save_game()
	if f["life"] <= 0.0:
		ball.queue_free()
		k.erase("fetch")
		k["t"] = randf_range(1.5, 3.0)

## A speech bubble over a kin's head.
## secs: how long it stays up (0: the usual BokiLines.bubble_s); an empty line says nothing.
func _say(k: Dictionary, text: String, secs := 0.0, direct := true) -> void:
	if text == "":
		return
	if secs <= 0.0:
		secs = BokiLines.bubble_s()
	if not direct:
		# chatter waits its turn: nobody else talking nearby, and a breath since the last line
		if talk_cd > 0.0 or _talking_near(k, 7.0):
			return
		talk_cd = randf_range(3.0, 5.0)
	else:
		# something you did with this kin: its answer wins, the others go quiet around it
		for o in kins:
			if o != k and o.has("say") and Vector2(o["pos"].x - k["pos"].x, o["pos"].z - k["pos"].z).length() < 5.0:
				o["say_t"] = 0.0
				(o["say"] as Label3D).visible = false
		talk_cd = maxf(talk_cd, 2.0)
	if not k.has("say"):
		var l := Label3D.new()
		l.font = UI.body; l.font_size = 34; l.pixel_size = BokiSpeech.FARM_PIXEL * BokiSpeech.SCALE; l.outline_size = 14
		l.outline_modulate = Color(UI.NIGHT, 0.95)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.width = 520
		l.position = Vector3(0, 1.75, 0)
		(k["node"] as Node3D).add_child(l)
		k["say"] = l
	(k["say"] as Label3D).text = text
	k["say_t"] = secs
	(k["say"] as Label3D).visible = true

## What a kin does in a match: its abilities, its merge, then how it rides with you. compact: one
## line each (the card's Training tab); otherwise the full rules (the "Full details" sub-page).
func _kin_match_rows(rec: Dictionary, c2: Control, compact: bool) -> void:
	var sp: Dictionary = Data.KIN[rec["species"]]
	var abl: Array = sp.get("abilities", [])
	var kspec := KinLib.kin(String(rec["species"]))
	var ab_row := func(key: String, nm: String, desc: String, c: Color) -> void:
		var r := UI.hbox(10)
		var kc := UI.keycap(key, 12); kc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		r.add_child(kc)
		var tv := UI.vbox(1); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UI.label(nm, UI.T_BODY, c, UI.semi))
		tv.add_child(UI.para(desc, 12, UI.MUTED))
		r.add_child(tv)
		c2.add_child(r)
	if compact:
		c2.add_child(BokiMoves.new(String(rec["species"]), rec))      # tiles with tips (item 82)
	# read from its parts (the kin grammar): what it does, coloured by effect category
	for ai in (0 if compact else abl.size()):
		var ad := KinLib.ability(String(abl[ai]))
		if ad == null: continue
		var eff := KinLib.effective(ad, "k1" if ai == 0 else "k2", kspec, rec)
		ab_row.call(Settings.key_cap("signature") if ai == 0 else "auto", ad.display_name, (KinText.ability(eff) if ai == 0 else KinText.when(ad) + ": " + KinText.ability(eff)), KinText.color(ad).lerp(UI.INK, 0.3))
	var ud := KinLib.merge(String(sp.get("ultimate", "")))
	if ud and not compact:
		ab_row.call(Settings.key_caps("ultimate"), "Fusion: " + ud.display_name, " ".join(KinText.merge(ud, kspec != null and kspec.carry_style == "mount")), Color("ffd84a").lerp(UI.INK, 0.3))
	if kspec == null:
		return
	var lines: Array = [[KinText.carry(kspec), KinRules.cat_color("sustain").lerp(UI.INK, 0.35)]]
	var ob := KinText.owner_bonus(KinLib.owner_bonus(kspec, rec))
	if ob != "": lines.append(["Owner bonus while it's your Boki: " + ob, Color("ffd84a").lerp(UI.INK, 0.35)])
	for ln in lines:
		if compact:
			var l := UI.label(String(ln[0]), 12, ln[1])
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.tooltip_text = String(ln[0])
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			c2.add_child(l)
		else:
			c2.add_child(UI.para(String(ln[0]), 12, ln[1]))

## A sub-page of the card: everything the kin does in a match, in full. Back returns to the card.
func _open_kin_match(rec: Dictionary) -> void:
	var v := _new_panel("%s in a match" % String(rec["name"]), 820)
	UI.hold(v, KIN_CARD_H + 58.0)
	UI.title_icon(v, UI.sex_icon(rec, 22.0))
	_kin_match_rows(rec, v, false)
	UI.footer(v).add_child(UI.button("Back to %s" % String(rec["name"]), func(): _open_kin(rec), 0, "back"))

## The card's body height on every tab (fits a 720p window), so switching tabs or Boki never
## resizes it.
const KIN_CARD_H := 400.0

## The details card: everything about one kin, laid out to fit on screen without scrolling.
var kin_tab := "Care"

## A kin's card: who it is up top, then Care (bond, needs, likes), Training (stats and what it does
## in a match) and Growth (where it's heading) as tabs, with the care actions in the footer.
func _open_kin(rec: Dictionary) -> void:
	var sp: Dictionary = Data.KIN[rec["species"]]
	Evo.ensure(rec)
	Care.ensure(rec)
	var col: Color = Shiny.body(rec)
	var partner: bool = rec["uid"] == Save.d.get("active", "")
	var rare_pre := Mutations.prefix(rec)
	var kpre := ("shimmering " if rec.get("shimmer", false) else "") + ((rare_pre + " ") if rare_pre != "" else "")
	var v := _new_panel(("%s the %s%s" % [rec["name"], kpre, Evo.form_name(rec)]) if kpre != "" else Data.kin_title(String(rec["name"]), Evo.form_name(rec)), 820)
	UI.hold(v, KIN_CARD_H)
	UI.title_icon(v, UI.sex_icon(rec, 22.0))
	UI.subtitle(v, "Level %d  ·  %s Boki  ·  %s  ·  %s nature" % [int(rec["level"]), String(sp["type"]).capitalize(), Care.stage_name(rec), Care.nature(rec)])
	var hx := UI.head_extra(v)
	hx.add_child(VoidPortrait.of(rec, get_tree(), 84.0))
	if partner: hx.add_child(UI.tag("Partner", UI.ACCENT))
	elif Match.TWO_KIN and rec["uid"] == Save.d.get("active2", ""): hx.add_child(UI.tag("Second", UI.TEAL))
	if rec.get("farmhand", false): hx.add_child(UI.tag("Farmhand", UI.GOOD))
	if KinBox.is_boxed(rec): hx.add_child(UI.tag("In the Boki Burrow", Color("cdb8ff")))
	for mid in Mutations.of(rec):
		var mt := UI.tag(Mutations.name_of(mid), UI.MUTED)      # plain: rarity shows on the Boki itself
		mt.tooltip_text = Mutations.perk_text(mid)
		hx.add_child(mt)
	UI.shell_tabs(v, ["Care", "Training", "Growth", "About"], kin_tab, func(t): kin_tab = t; _open_kin(rec))
	var row := func(parent: Control, label_txt: String, frac: float, c: Color, right := "", lw := 92.0) -> void:
		var r := UI.hbox(10)
		var l := UI.label(label_txt, UI.T_SMALL, UI.MUTED); l.custom_minimum_size.x = lw
		r.add_child(l)
		var bb := UI.bar(frac, c, 150, 8); bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(bb)
		var rl := UI.label(right, 12, UI.MUTED, UI.semi); rl.custom_minimum_size.x = 64
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(rl)
		parent.add_child(r)
	var cols := UI.hbox(UI.GAP_BIG + 10)
	v.add_child(cols)
	var c1 := UI.vbox(8); c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c2 := UI.vbox(8); c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(c1); cols.add_child(c2)
	match kin_tab:
		"About":
			# what makes it itself, and where it came from (AboutView: Unique and Save.register)
			c1.add_child(UI.section("Who it is"))
			AboutView.looks(rec, c1)
			c2.add_child(UI.section("Where it's from"))
			AboutView.history(rec, c2)
		"Care":
			var bd: Array = Care.bond(rec)
			var nb: Array = Care.next_bond(rec)
			c1.add_child(UI.section("Bond  ·  %s" % bd[1], col.lerp(UI.INK, 0.35)))
			var lo := float(bd[0]); var hi := float(nb[0]) if nb.size() > 0 else 100.0
			row.call(c1, "Trust", clampf((float(rec["trust"]) - lo) / maxf(1.0, hi - lo), 0.0, 1.0), Color("ffb3c6"), ("next: %s" % nb[1]) if nb.size() > 0 else "max")
			c1.add_child(UI.para(String(bd[2]), 12, UI.MUTED))
			c1.add_child(UI.spacer(4))
			var starving := Care.starve_stage(rec) != ""
			c1.add_child(UI.section(Care.condition_name(rec), Color("ff9a7a") if starving else UI.PINK))
			if starving:
				c1.add_child(UI.para(String(Care.STARVE_INFO[Care.starve_stage(rec)][1]), 12, Color("ffb0a0")))
			for n in Care.NEEDS:
				row.call(c1, Care.NEED_INFO[n]["name"], Care.need(rec, n) / 100.0, Care.NEED_INFO[n]["col"], str(int(Care.need(rec, n))))
			c2.add_child(UI.section("Likes"))
			var known: Array = rec["known"]
			var lk: Dictionary = rec["likes"]
			c2.add_child(UI.kv("Loves", Care.food_name(lk["food"]) if known.has("food") else "???", UI.INK if known.has("food") else UI.FAINT))
			c2.add_child(UI.kv("Won't eat", Care.food_name(lk["hates"]) if known.has("hates") else "???", UI.INK if known.has("hates") else UI.FAINT))
			c2.add_child(UI.kv("Favourite game", Care.PLAY_NAMES[lk["play"]] if known.has("play") else "???", UI.INK if known.has("play") else UI.FAINT))
			c2.add_child(UI.para("Feed it, play with it and talk to it to find out more.", 12, UI.FAINT))
			c2.add_child(UI.spacer(2))
			WorkView.card_section(self, rec, c2, func(): _open_kin(rec))
			var mem: Array = rec.get("memory", [])
			if mem.size() > 0:
				c2.add_child(UI.spacer(4))
				c2.add_child(UI.section("Remembers"))
				for i in range(maxi(0, mem.size() - 1), mem.size()):
					var t := String(mem[i]["text"])
					c2.add_child(UI.para("\u201c%s\u201d" % (t.substr(0, 1).to_upper() + t.substr(1)), 13, UI.INK.darkened(0.1)))
			if String(rec.get("title", "")) != "":
				c2.add_child(UI.para("%s %s  ·  came back from the Soul Shrine" % [rec["name"], rec["title"]], 12, Color("bff8ec")))
		"Training":
			c1.add_child(UI.section("Stats  ·  cap %d" % Care.stat_cap(rec)))
			for st in Care.STATS:
				row.call(c1, Care.STATS[st]["name"], float(rec["stats"][st]) / float(Care.stat_cap(rec)), Care.STATS[st]["col"], str(int(rec["stats"][st])))
			c1.add_child(UI.para("Train at the yard to raise them. Higher bonds raise the cap.", 12, UI.FAINT))
			c2.add_child(UI.section("In a match"))
			_kin_match_rows(rec, c2, true)
			var more := UI.ghost("Full details", func(): _open_kin_match(rec), 0, "info")
			more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			c2.add_child(more)
		"Growth":
			var lead := Evo.leading(rec)
			var lv := int(rec["level"])
			var next_form := (lv / 4 + 1) * 4
			var next_mut := lv + ((2 - lv % 4) + 4) % 4
			if next_mut == lv: next_mut += 4
			c1.add_child(UI.section("Growing toward"))
			c1.add_child(UI.label(String(Evo.AFF[lead]["name"]), UI.T_HEAD, Evo.AFF[lead]["tint"], UI.big))
			c1.add_child(UI.label("New form at level %d  ·  mutation at %d" % [next_form, next_mut], UI.T_SMALL, UI.MUTED))
			c1.add_child(UI.para("What you feed it and how you raise it decides which way it grows.", 12, UI.FAINT))
			var tot := 0.0
			for af in Evo.AFF: tot += maxf(0.0, float(rec["aff"][af]))
			c2.add_child(UI.section("Affinities"))
			for af in Evo.AFF:
				row.call(c2, Evo.AFF[af]["name"], float(rec["aff"][af]) / maxf(tot, 1.0), Evo.AFF[af]["tint"], "%d%%" % int(round(100.0 * maxf(0.0, float(rec["aff"][af])) / maxf(tot, 1.0))))
			c2.add_child(UI.spacer(4))
			IvView.block(rec, c2)        # what it was born with (Care.IVS), under how it's growing
			if rec.has("parents"):
				c1.add_child(UI.spacer(4))
				c1.add_child(UI.kv("Parents", "%s and %s" % [rec["parents"][0], rec["parents"][1]]))
	# looking after it: the care actions as one row, Feed first
	var ft := UI.footer(v)
	var fl := UI.hbox(4)
	v.add_child(UI.spacer(2))
	var roles := UI.hbox(6)
	roles.add_child(UI.label("Role", UI.T_SMALL, UI.FAINT))
	roles.add_child(fl)
	v.add_child(roles)
	ft.add_child(UI.button("Brush", func(): _care_brush(rec), 0, "heart"))
	ft.add_child(UI.button("Bath", func(): _care_bath(rec), 0, "wave"))
	ft.add_child(UI.button("Nap", func(): _care_nap(rec), 0, "clock"))
	if kin_tab == "Training":
		ft.add_child(UI.button("Dress", func(): _open_wear(rec), 0, "paw"))
		var tb := UI.footer_primary(v, "Train", func(): _open_train(rec), 110, "dash")
		tb.name = "Train"
	elif kin_tab == "Growth":
		var why := _can_pair(rec)
		ft.add_child(UI.button("Dress", func(): _open_wear(rec), 0, "paw"))
		var pb := UI.footer_primary(v, "Pair", func(): _open_pair(rec), 110, "egg")
		pb.disabled = why != ""
		pb.tooltip_text = why
	else:
		ft.add_child(UI.button("Dress", func(): _open_wear(rec), 0, "paw"))
		UI.footer_primary(v, "Feed", func(): _open_feed(rec), 110, "seed")
	# roles: quiet links on the left
	if not partner:
		fl.add_child(UI.ghost("Make partner", func():
			var swapped := KinBox.bring_out(rec)      # partners live on the farm
			if Save.d.get("active2", "") == rec["uid"]: Save.d["active2"] = Save.d.get("active", "")
			Save.d["active"] = rec["uid"]
			Save.save_game()
			if not swapped.is_empty(): _toast("%s went to the Boki Burrow to make room" % swapped["name"])
			_spawn_kin(); _refresh_burrow()
			_open_kin(rec)))
		if Match.TWO_KIN and rec["uid"] != Save.d.get("active2", ""):     # (one Boki per run now: no second)
			fl.add_child(UI.ghost("Bring as second", func():
				Save.d["active2"] = rec["uid"]
				Save.save_game()
				_toast("%s joins your next expedition (%s swaps)" % [rec["name"], Settings.key_cap("swap_kin")])
				_open_kin(rec)))
	# the Kin Burrow: put it to sleep there, or wake it and bring it out
	if KinBox.is_boxed(rec):
		fl.add_child(UI.ghost("Send to farm", func():
			var bwhy := KinBox.to_farm(rec)
			if bwhy != "": _toast(bwhy); return
			Save.save_game(); _spawn_kin(); _refresh_burrow()
			_toast("%s is out on the farm" % rec["name"])
			_open_kin(rec)))
	elif KinBox.pinned(rec) == "":
		fl.add_child(UI.ghost("Put in Boki Burrow", func():
			var bwhy := KinBox.to_box(rec)
			if bwhy != "": _toast(bwhy); return
			Save.save_game(); _spawn_kin(); _refresh_burrow()
			_toast("%s curled up in the Boki Burrow (%s)" % [rec["name"], KinBox.page_name(KinBox.page_of(rec))])
			_open_kin(rec)))
	fl.add_child(UI.ghost("Boki Burrow", func(): KinBoxView.sel = String(rec["uid"]); KinBoxView.page = KinBox.page_of(rec) if KinBox.is_boxed(rec) else KinBoxView.page; _open_burrow()))
	if rec.get("farmhand", false):
		fl.add_child(UI.ghost("Stop farming", func():
			rec.erase("farmhand")
			Save.save_game()
			_open_kin(rec)))
	elif not KinBox.is_boxed(rec):
		fl.add_child(UI.ghost("Make farmhand", func():
			for r2 in Save.d["roster"]: r2.erase("farmhand")
			rec["farmhand"] = true
			Save.remember(rec, "farm", "was put in charge of watering the farm", 1.0)
			Save.save_game()
			_toast("%s will water your plants" % rec["name"])
			_open_kin(rec)))

# ---- talking: speech bubbles over the kin and a slim bar to type in
var chat_open := false
var chat_bar: Control = null
var chat_hist: Label = null

func _open_chat(rec: Dictionary) -> void:
	_close_panel()
	_close_chat()
	chat_kin = rec
	chat_open = true
	if chat_log.size() == 0 or chat_log[0].get("uid", "") != rec["uid"]:
		chat_log = [{"uid": rec["uid"]}]
	var k := _kin_entry(rec)
	if not k.is_empty():
		k["hold_t"] = 9999.0
		_face(k["pos"])
		if chat_log.size() == 1:
			_say(k, _greeting(rec))
	var bar := UI.card(Color(UI.NIGHT, 0.92), 12, 14)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -64; bar.offset_bottom = -64
	bar.custom_minimum_size.x = minf(640.0, get_viewport().get_visible_rect().size.x - 32.0)
	var col := UI.vbox(8)
	bar.add_child(col)
	chat_hist = UI.label("", 13, UI.MUTED)
	chat_hist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(chat_hist)
	var row := UI.hbox(8)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Say something to %s" % rec["name"]
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.max_length = 200
	chat_input.text_submitted.connect(func(_t): _send_chat())
	row.add_child(chat_input)
	row.add_child(UI.button("Say", _send_chat))
	row.add_child(UI.button("Done", _close_chat))
	col.add_child(row)
	root_ui.add_child(bar)
	chat_bar = bar
	_chat_bubble("", "")
	chat_input.grab_focus()

func _close_chat() -> void:
	if is_instance_valid(chat_bar):
		chat_bar.queue_free()
	chat_bar = null
	chat_input = null
	chat_hist = null
	if chat_open:
		var k := _kin_entry(chat_kin)
		if not k.is_empty(): k["hold_t"] = 0.6
	chat_open = false

## What it says when you walk up or start talking: cold if it doesn't trust you, else what it wants.
func _greeting(rec: Dictionary) -> String:
	var w := Care.want(rec)
	if float(rec["trust"]) < 30.0:
		return BokiLines.say(rec, "greet_cold")
	return BokiLines.say(rec, "want_" + w if w != "" else "greet")

## Keeps the last few lines of the conversation in the bar.
func _chat_bubble(_role: String, _text: String) -> void:
	if not is_instance_valid(chat_hist):
		return
	var lines: Array = []
	var turns: Array = chat_log.slice(1)
	for t in turns.slice(maxi(0, turns.size() - 4)):
		lines.append(("You: " if t["role"] == "user" else "%s: " % chat_kin.get("name", "Boki")) + String(t["content"]))
	chat_hist.text = "\n".join(lines) if lines.size() > 0 else "Type below and press Enter. %s answers above its head." % chat_kin.get("name", "Your Boki")

func _send_chat() -> void:
	if chat_input == null or chat_busy:
		return
	var txt := chat_input.text.strip_edges()
	if txt == "":
		return
	chat_input.text = ""
	chat_log.append({"role": "user", "content": txt})
	_chat_bubble("user", txt)
	var rec := chat_kin
	var k := _kin_entry(rec)
	chat_busy = true
	var dots := create_tween().set_loops()
	for i in 4:
		var n := i
		dots.tween_callback(func(): if not k.is_empty(): _say(k, ".".repeat(n + 1), 1.0))
		dots.tween_interval(0.35)
	var t0 := Time.get_ticks_msec() / 1000.0
	var msgs := []
	var brief := Bridge.kin_brief(rec) + "\n\nYou are chatting with your hunter at home on the farm. Stay in character and respond to what they actually said. " + \
		("Answer in one to three short sentences, plain text, no emoji, no stage directions. " if Care.speech(rec) >= 3 else "Follow the rule above about how you can talk. Keep it short. ") + \
		"If they apologise or are kind, you can warm up a little. If they ask you to do something in a match, you can agree or set conditions based on your trust."
	var turns: Array = chat_log.slice(1)
	turns = turns.slice(maxi(0, turns.size() - 10))
	for i in turns.size():
		var tmsg: Dictionary = turns[i]
		var content: String = tmsg["content"]
		if i == 0 and tmsg["role"] == "user":
			content = brief + "\n\nYour hunter says: " + content
		msgs.append({"role": tmsg["role"], "content": content})
	if msgs.size() > 0 and msgs[0]["role"] != "user":
		msgs.push_front({"role": "user", "content": brief + "\n\n(The hunter walks up to you.)"})
	Bridge.ask(msgs, func(reply: String):
		var offline := reply.strip_edges() == ""
		if offline:
			reply = KinSpeak.reply(rec, txt)
		# a kin takes a moment to answer: at least 2 seconds, longer for longer replies
		var want := clampf(2.0 + reply.length() * 0.03, 2.0, 6.0)
		var wait := want - (Time.get_ticks_msec() / 1000.0 - t0)
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		dots.kill()
		if not is_inside_tree():
			return
		chat_busy = false
		chat_log.append({"role": "assistant", "content": reply})
		if not k.is_empty():
			_say(k, reply, clampf(3.0 + reply.length() * 0.06, 4.0, 10.0))
		if chat_kin.get("uid", "") == rec["uid"]:
			_chat_bubble("assistant", reply)
		var loves_chat: bool = rec["likes"]["play"] == "chat"
		Care.change(rec, "joy", 6.0 if loves_chat else 2.0)
		if loves_chat and Care.discover(rec, "play"): _toast("%s loves chatting with you" % rec["name"])
		# talking builds a little trust, once per match
		if int(rec.get("talked", -1)) != int(Save.d["matches"]):
			rec["talked"] = int(Save.d["matches"])
			Save.remember(rec, "talked", "had a chat with you at home", 2.0)
			Save.save_game()
			if Bridge.ai_ok and rec["uid"] == Save.d.get("active", "") and not rec.has("lines"):
				Bridge.refresh_lines(rec), "default")

# ---- expedition
var exp_cls := ""
var exp_mode := "solo"
var exp_tier := 0
var exp_seed := 0          # the next expedition's seed, rolled when the panel opens: its raid condition shows as a forecast

func _weapon() -> String:
	return Arch.weapon_for(Arch.of_save(), Data.class_of_save(), String(Save.d.get("weapon", "")))

func _open_expedition() -> void:
	FarmTutorial.event("portal")
	var v := _new_panel("Expedition", 940, true)
	UI.subtitle(v, "Pick your kit and where to drop. Everything here is saved as you change it.")
	var cols := UI.hbox(UI.GAP_BIG + 8)
	v.add_child(cols)
	# left: who you are (your Hunter, its weapon, your Boki); locked Hunters are greyed (HunterPickRow)
	var left := UI.vbox(10); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var cur_a := HunterPickRow.add(self, left)
	# your abilities before a run: the kit card's compact row (click for the full card)
	left.add_child(KitCard.strip(cur_a, _open_kit_card))
	left.add_child(UI.spacer(2))
	left.add_child(UI.section("Signature weapon"))
	var wd: Dictionary = Data.weapon_stats(Arch.signature(cur_a))
	var wb := UI.choice(String(wd["name"]), true, func(): pass, 200, Arch.signature(cur_a))
	wb.tooltip_text = (String(wd.get("desc", "")) + "\n" if wd.has("desc") else "") + "The one weapon you carry. It grows during a run: level-ups, chests and tunings upgrade it."
	left.add_child(wb)
	var ak := Save.active_kin()
	if not ak.is_empty():
		left.add_child(UI.spacer(2))
		left.add_child(UI.section("Boki you bring"))
		left.add_child(_kin_pick_row("Partner", ak, "active"))
		if Match.TWO_KIN and Save.d["roster"].size() > 1:
			left.add_child(_kin_pick_row("Second", Save.second_kin(), "active2"))
		if float(ak["trust"]) < 30.0:
			left.add_child(UI.para("%s doesn't trust you much yet and may refuse risky throws." % ak["name"], UI.T_SMALL, UI.BAD))
	if Save.d.get("treat", "") != "":
		left.add_child(UI.chip("heart", "Treat: " + _treat_name(Save.d["treat"]), Color("ffb0d0")))
	hecon.loadout_rows(left, _open_expedition)
	# right: where you're going and how
	var right := UI.vbox(10); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UI.section("Where"))
	var ex := int(Save.d.get("extracts", 0))
	if exp_tier >= Data.TIERS.size() or ex < int(Data.TIERS[exp_tier]["unlock"]): exp_tier = 0
	for i in Data.TIERS.size():
		var td: Dictionary = Data.TIERS[i]
		var locked := ex < int(td["unlock"])
		var ti := i
		var tc := UI.tile_card(exp_tier == i and not locked, (func(): exp_tier = ti; _open_expedition()) if not locked else Callable(), 12, UI.BAD if KinLoss.at_risk(i) else UI.ACCENT)
		var th := UI.hbox(12); tc.add_child(th)
		var tv := UI.vbox(2); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		th.add_child(tv)
		var nrow := UI.hbox(8)
		nrow.add_child(UI.label(String(td["name"]), UI.T_HEAD, UI.INK if not locked else UI.MUTED, UI.big))
		if KinLoss.at_risk(i): nrow.add_child(UI.tag("Boki at risk", UI.BAD))
		tv.add_child(nrow)
		if locked:
			var need := int(td["unlock"]) - ex
			tv.add_child(UI.label("Make it out %d more time%s to open" % [need, "" if need == 1 else "s"], UI.T_SMALL, UI.FAINT))
			th.add_child(UI.IconDot.new("lock", UI.FAINT, 18.0))
			tc.modulate.a = 0.7
			tc.focus_mode = Control.FOCUS_NONE
			tc.mouse_default_cursor_shape = Control.CURSOR_ARROW
		elif exp_tier == i:
			tv.add_child(UI.para(String(td["desc"]), UI.T_SMALL, Color("ffb3a8") if KinLoss.at_risk(i) else UI.MUTED))
		right.add_child(tc)
	right.add_child(UI.spacer(2))
	right.add_child(UI.section("Match"))
	var mode_names := {"solo": "Solo", "duo": "Duos", "trio": "Trios"}
	var mode_keys := {"Solo": "solo", "Duos": "duo", "Trios": "trio"}
	var mtabs := UI.tabs(["Solo", "Duos", "Trios"], mode_names[exp_mode], func(nm): exp_mode = mode_keys[nm]; _open_expedition(), {}, 96)
	for tb in mtabs.get_child(0).get_children():
		tb.tooltip_text = {"solo": "20 hunters, every one for themselves", "duo": "10 squads of two", "trio": "7 squads of three"}[mode_keys[String(tb.get_meta("tab"))]]
	right.add_child(mtabs)
	right.add_child(UI.label({"solo": "20 hunters, every one for themselves", "duo": "10 squads of two", "trio": "7 squads of three"}[exp_mode], UI.T_SMALL, UI.MUTED))
	# the session: today's fixed match, or a rolling 30-minute session you join part-way through
	# (scripts/match/rolling.gd; the fixed match stays the default until the owner switches it)
	var rolling_on: bool = Save.d.get("exp_rolling", false)
	var stabs := UI.tabs(["Fixed match", "Rolling session"], "Rolling session" if rolling_on else "Fixed match", func(nm): Save.d["exp_rolling"] = nm == "Rolling session"; _open_expedition(), {}, 150)
	for tb in stabs.get_child(0).get_children():
		tb.tooltip_text = "Everyone drops together; the islands fall after about 10 minutes" if String(tb.get_meta("tab")) == "Fixed match" else "A 30-minute session already under way: you drop in with the next wave, wherever it's at"
	right.add_child(stabs)
	right.add_child(UI.label("30 minutes, waves every 2-3 minutes; late arrivals start at a higher level" if rolling_on else "Everyone drops together; about 10 minutes", UI.T_SMALL, UI.MUTED))
	# the raid condition this drop will have (rolled with the match's seed: RaidLook)
	if exp_seed == 0: exp_seed = randi() | 1
	var rc := RaidLook.pick(Settings.demo_opts({}), exp_seed)
	right.add_child(UI.spacer(2))
	right.add_child(UI.section("Conditions"))
	right.add_child(UI.chip("clock", String(RaidLook.NAMES.get(rc, rc)), RaidLook.COLORS.get(rc, UI.INK), String(RaidLook.BLURBS.get(rc, ""))))
	right.add_child(UI.para(String(RaidLook.BLURBS.get(rc, "")), 12, UI.MUTED))
	if not ak.is_empty():
		right.add_child(UI.para("Go down for good and the Boki you bring are left behind (the Black Market holds the unclaimed ones).", 12, UI.FAINT))
	# the way out: practice on the left, go on the right
	var fl := UI.footer_left(v)
	fl.add_child(UI.ghost("Arena", func(): Save.save_game(); Game.start_match(Match.arena_opts(Arch.of_save())), 0, "knock"))
	fl.add_child(UI.ghost("Training area", _start_training, 0, "jump"))
	fl.add_child(UI.ghost("Duel room", _start_duel, 0, "knock"))
	if Net.available():
		fl.add_child(UI.ghost("Play online", func(): Game.goto("lobby", {"cls": Data.class_of_save(), "tier": exp_tier}), 0, "bond"))
	var start_b := UI.footer_primary(v, "Start expedition", _confirm_start, 250, "portal")
	start_b.grab_focus.call_deferred()

## The full kit card for your archetype and Boki (KitCard), over the expedition panel.
func _open_kit_card() -> void:
	var v := _new_panel("Your kit", KitCard.SIZE.x + 40, true)
	var ak := Save.active_kin()
	var card := KitCard.make(Arch.of_save(), String(ak.get("species", "")))
	v.add_child(card)
	UI.footer_left(v).add_child(UI.ghost("Back to the expedition", _open_expedition, 0))

## The old separate loadout page now lives inside the expedition panel.
func _open_loadout() -> void:
	_open_expedition()

## One row of the expedition loadout: which kin, with ‹ › to change it.
func _kin_pick_row(label_t: String, rec: Dictionary, key: String) -> Control:
	var card := UI.card(UI.CARD, 10, 10)
	var row := UI.hbox(10); card.add_child(row)
	var roster: Array = Save.d["roster"]
	var other := str(Save.d.get("active2" if key == "active" else "active", ""))
	var choices: Array = roster.filter(func(r): return r["uid"] != other)
	var cur := str(Save.d.get(key, ""))
	var cycle := func(dir: int) -> void:
		var ids: Array = choices.map(func(r): return r["uid"])
		if key == "active2": ids.append("none")
		var i := ids.find(cur)
		Save.d[key] = ids[(i + dir + ids.size()) % ids.size()] if ids.size() > 0 else cur
		Save.save_game()
		_open_expedition()
	var prev_b := UI.icon_button("back", func(): cycle.call(-1), "Previous Boki", 12.0)
	prev_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(prev_b)
	if not rec.is_empty():
		var ksp: Dictionary = Data.KIN[rec["species"]]
		var kcol: Color = Color(ksp["color"]).lerp(Color.WHITE, 0.25)
		var dot := UI.badge("paw", kcol, 36.0)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
	var info := UI.vbox(1); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if rec.is_empty():
		info.add_child(UI.label("%s: none" % label_t, 16, UI.MUTED, UI.big))
		info.add_child(UI.label("Bring only your partner. Nothing else at risk.", 12, UI.MUTED))
	else:
		var sp: Dictionary = Data.KIN[rec["species"]]
		var nl := UI.label(Data.kin_title(String(rec["name"]), String(sp["name"])), 17, UI.INK, UI.big)
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.clip_text = true
		info.add_child(nl)
		var sl := UI.label("%s  ·  level %d  ·  trust %d%s" % [label_t, int(rec.get("level", 1)), int(rec["trust"]), "  ·  asleep in the Boki Burrow: comes out to go with you" if KinBox.is_boxed(rec) else ""], 12, Color("cdb8ff") if KinBox.is_boxed(rec) else UI.MUTED)
		sl.autowrap_mode = TextServer.AUTOWRAP_OFF
		info.add_child(sl)
		var names: Array = []
		for aid in sp.get("abilities", []):
			var ad := KinLib.ability(String(aid))
			if ad: names.append(ad.display_name)
		var ud := KinLib.merge(String(sp.get("ultimate", "")))
		var keys := "auto" if key == "active" else ("swap in with %s" % Settings.key_cap("swap_kin"))
		var al := UI.label("%s  ·  %s  ·  bond: %s" % [keys, ", ".join(names), ud.display_name if ud else "-"], 12, UI.MUTED)
		al.autowrap_mode = TextServer.AUTOWRAP_OFF
		al.clip_text = true
		al.tooltip_text = al.text
		al.mouse_filter = Control.MOUSE_FILTER_PASS
		info.add_child(al)
	row.add_child(info)
	var next_b := UI.icon_button("next", func(): cycle.call(1), "Next Boki", 12.0)
	next_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(next_b)
	return card

## A safe island to learn every button: nothing can hurt you and nothing you do there counts.
func _start_training() -> void:
	Save.d["cls"] = Data.class_of_save()
	Save.save_game()
	Game.start_match({"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242})

## The duel room: you against one sparring bot you set up yourself.
func _start_duel() -> void:
	Save.d["cls"] = Data.class_of_save()
	Save.save_game()
	Game.start_match(Match.duel_opts())

## Before a run where kin can be lost, say so plainly and make the player confirm.
func _confirm_start() -> void:
	var weak := hecon.refuse_reason()
	if weak != "":
		var wv := _new_panel("Too hungry to go", 560)
		var wl := UI.label(weak, 15, UI.INK); wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wv.add_child(wl)
		var wr := UI.hbox(10)
		wr.add_child(UI.primary("Feed it", func(): _open_feed(Save.active_kin()), 160))
		wr.add_child(UI.button("Back", _open_expedition, 140))
		wv.add_child(wr)
		return
	var td: Dictionary = Data.TIERS[exp_tier]
	if not KinLoss.at_risk(exp_tier):
		_start_match()
		return
	var v := _new_panel("Your Boki can be lost", 640)
	var names: Array = []
	for rec in Save.d.get("roster", []):
		if rec.get("uid", "") in [Save.d.get("active", ""), Save.d.get("active2", "")]:
			names.append(String(rec.get("name", "your Boki")))
	var who := " and ".join(names) if not names.is_empty() else "the Boki you bring"
	var lines := ["In %s, if you die, %s drops dazed beside your deathbox and guards it. Get revived and run into it to pick it up. A rival can scan it and take it." % [td["name"], who]]
	lines.append("If a rival takes your Boki you feel its pull: an arrow points at them and their spot pings on your map. Knock them out and it drops, and you can pick it up. If they get out with it, or nobody picks it up, it ends up at the Black Market.")
	for ln in lines:
		var l := UI.label(ln, 15, UI.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var row := UI.hbox(10)
	row.add_child(UI.primary("I understand, go", _start_match, 220))
	row.add_child(UI.button("Back", _open_expedition, 140))
	v.add_child(row)

func _start_match() -> void:
	# kin picked from the Kin Burrow come out to go with you
	for kk in [Save.active_kin(), Save.second_kin() if Match.TWO_KIN else {}]:
		if not (kk as Dictionary).is_empty() and KinBox.is_boxed(kk): KinBox.bring_out(kk)
	Save.d["cls"] = Data.class_of_save()
	Save.save_game()
	# about 20 hunters a match, whatever the squad size (your squadmates are bots)
	var o := {"teams": Data.MATCH_PLAYERS, "squad": 1}
	match exp_mode:
		"duo": o = {"teams": Data.MATCH_PLAYERS / 2, "squad": 2}
		"trio": o = {"teams": int(ceil(Data.MATCH_PLAYERS / 3.0)), "squad": 3}
	o["total"] = Data.MATCH_PLAYERS
	if Save.d.get("exp_rolling", false):
		o["rolling"] = true      # the session sizes its own waves (Rolling.plan)
	o["tier"] = exp_tier
	o["kit_items"] = Equal.take_loadout(exp_tier)      # gloves and boots from the armory ride with you (capped by tier)
	o["belt_items"] = Equal.take_belt(exp_tier)         # and the utility you picked
	o["backpack"] = Backpacks.take_home(exp_tier)       # and your backpack
	if exp_seed != 0: o["seed"] = exp_seed  # the conditions the panel showed
	exp_seed = 0
	Save.save_game()
	Game.start_match(o)

# ---- evolution
## Kin that grew during the last expedition change in front of you when you get home.
func _play_evolutions() -> void:
	if building_now or panel_open != "":
		return
	var k: Dictionary = {}
	for kk in kins:
		if kk["rec"].get("pending_evo", []).size() > 0 and not kk.has("indoors"):
			k = kk; break
	if k.is_empty():
		return
	building_now = true
	var rec: Dictionary = k["rec"]
	var evs: Array = rec["pending_evo"]
	rec["pending_evo"] = []
	Save.save_game()
	var n: Node3D = k["node"]
	# bring it next to you
	var at := ppos + Vector3(1.6, 0, 0.6)
	if world.is_void(at.x, at.z) or world.is_block(at.x, at.z):
		at = ppos + Vector3(0, 0, 1.4)
	k["pos"] = at
	k["goal"] = Vector3.INF
	k["busy"] = true
	n.position = at
	cam.zoom_to = 0.55
	var big := false
	for e in evs:
		if e["kind"] == "form": big = true
	var tint: Color = Evo.AFF[evs[evs.size() - 1]["aff"]]["tint"]
	Sfx.play("skill")
	music_hold = 25.0
	Sfx.play_music("lullaby", 1.0)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(n, "rotation:y", n.rotation.y + TAU * (3.0 if big else 1.0), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for i in 6:
		get_tree().create_timer(0.4 + i * 0.22).timeout.connect(func(): fx.burst(at + Vector3(0, 0.5, 0), tint, 6, 2.0, 0.4, -2.0))
	tw.tween_callback(func():
		# swap in the grown model
		if not is_instance_valid(n):
			building_now = false
			return
		var nn := Models.kin(rec["species"], rec)
		nn.position = at
		nn.rotation = n.rotation
		var lbl: Label3D = k["emote"]
		n.remove_child(lbl)
		nn.add_child(lbl)
		if k.has("say") and is_instance_valid(k["say"]):
			n.remove_child(k["say"]); nn.add_child(k["say"])
		k.erase("bubble")
		add_child(nn)
		n.queue_free()
		k["node"] = nn
		k["busy"] = false
		k["t"] = 3.0
		fx.burst(at + Vector3(0, 0.5, 0), tint, 36, 5.0, 0.8, 4.0, 1.3)
		fx.ring(at, 3.0, Color(tint, 0.9), 0.5)
		Sfx.play("unlock")
		Sfx.play("kin_happy")
		_emote(k, "★")
		building_now = false
		cam.zoom_to = HOME_ZOOM
		var v := _new_panel(("%s evolved" if big else "%s is changing") % rec["name"], 520)
		for e in evs:
			v.add_child(UI.label(String(e.get("text", Evo.describe(e, rec))), 16, Evo.AFF[e["aff"]]["tint"]))
		v.add_child(UI.label("How you raise it decides what it grows into next. Feed it, fight beside it, look after it.", 14, UI.MUTED)))

# ---- buildings and bridges
func _building_verb(b: String) -> String:
	match b:
		"hall": return "Look at your trophies"
		"cottage", "cottage2": return "Peek into the %s" % Data.BUILDINGS[b]["name"]
		"armory": return "Open the armory  ·  %d stored" % Econ.armory().size()
		"shrine": return "Visit the Soul Shrine"
	return "Visit the %s" % Data.BUILDINGS[b]["name"]

func _open_lot(b: String) -> void:
	var bd: Dictionary = Data.BUILDINGS[b]
	if lots[b]["built"]:
		if b == "hall":
			_open_hall()
			return
		if b == "board":
			_open_challenges()
			return
		if b == "ransom":
			hbm.open()
			return
		if b == "armory":
			hecon.open_armory()
			return
		if b == "shrine":
			hecon.open_shrine()
			return
		var v := _new_panel(bd["name"], 480)
		v.add_child(UI.label(bd["desc"], 16))
		if b in ["cottage", "cottage2"]:
			_close_panel()
			Game.goto("interior", {"room": b})
			return
		if false:
			var resting: Array = []
			for rec in Save.d["roster"]:
				if rec["uid"] != Save.d.get("active", ""): resting.append(rec["name"])
			v.add_child(UI.label(("Resting here: " + ", ".join(resting)) if resting.size() > 0 else "Nobody's resting here right now. Boki who aren't your partner sleep here.", 15, UI.MUTED))
		return
	if b == "shrine":
		hecon.open_shrine_lot()
		return
	var v := _new_panel("Build a %s" % bd["name"], 500)
	v.add_child(UI.label(bd["desc"], 16))
	var lc := FarmBuilder.lot_cost(b)       # a farm under the building pass pays some lots in wood and stone
	var cost := int(bd["cost"])
	var can := FarmSites.can_pay(lc) if not lc.is_empty() else int(Save.d["gems"]) >= cost
	var cost_line := "Costs %d gems. You have %d." % [cost, int(Save.d["gems"])]
	if not lc.is_empty():
		cost_line = "Costs %s. You have %s." % [FarmSites.cost_text(lc), FarmSites.mats_text()]
	v.add_child(UI.label(cost_line, 15, UI.GOLD if can else UI.BAD))
	var btn := UI.button("Build it", func():
		if Save.has_building(b) or not (FarmSites.can_pay(lc) if not lc.is_empty() else int(Save.d["gems"]) >= cost): return
		if lc.is_empty(): Save.d["gems"] = int(Save.d["gems"]) - cost
		else: FarmSites.pay(lc)
		Save.d["buildings"].append(b)
		Save.save_game()
		_close_panel()
		_construct(b), 200)
	btn.disabled = not can
	v.add_child(btn)

var wedge_t := 0.0

## Moves you (and any kin) to the nearest open ground if something has boxed you in.
func unstick() -> void:
	var p2 := world.free_spot_near(ppos, [], 1.0, 0.5)
	if p2.distance_to(ppos) > 0.05:
		ppos = Vector3(p2.x, ppos.y, p2.z)
		if player: player.position = ppos
	for k in kins:
		var kp: Vector3 = k["pos"]
		if not world._fits(kp.x, kp.z, 0.35) or not world.roomy(int(floor(kp.x)), int(floor(kp.z))):
			var np := world.free_spot_near(kp, [ppos], 1.2, 0.4)
			k["pos"] = np
			k["goal"] = Vector3.INF
			(k["node"] as Node3D).position = np

## Builds a building on its lot: the site packs away and the building pops up with dust and hammering.
func _construct(b: String) -> void:
	building_now = true
	var l: Dictionary = lots[b]
	var holder: Node3D = l["node"]
	l["built"] = true
	hb.apply(false)      # its footprint blocks now; steps you and any kin out of it
	l["built"] = false
	for c in holder.get_children():
		var tw0 := create_tween()
		tw0.tween_property(c, "scale", Vector3(1, 0.01, 1), 0.25)
		tw0.tween_callback(c.queue_free)
	var n := Models.building(b)
	holder.add_child(n)
	var body: Node3D = n.get_node("Body")
	body.scale = Vector3(0.6, 0.0, 0.6)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(body, "scale", Vector3(1.0, 0.45, 1.0), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body, "scale", Vector3(1.0, 0.8, 1.0), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body, "scale", Vector3(1.0, 1.0, 1.0), 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for i in 5:
		get_tree().create_timer(0.3 + i * 0.24).timeout.connect(func():
			Sfx.play("build", null, -3.0, 0.15)
			fx.dust(l["at"] + Vector3(randf_range(-1.4, 1.4), 0, randf_range(-1.0, 1.0)), 10))
	get_tree().create_timer(1.55).timeout.connect(func():
		Sfx.play("unlock")
		fx.burst(l["at"] + Vector3(0, 2.6, 0), UI.GOLD, 26, 6.0, 0.8, 8.0, 1.2)
		fx.ring(l["at"], 4.0, Color(UI.GOLD, 0.9), 0.5)
		l["built"] = true
		building_now = false
		if b == "greenhouse": _build_plots()
		_toast("%s built" % Data.BUILDINGS[b]["name"]))
	cam.zoom_to = 0.95

func _open_bridge(k: String) -> void:
	var isd: Dictionary = Data.ISLES[k]
	var v := _new_panel("Bridge to %s" % isd["name"], 520)
	v.add_child(UI.label(isd["desc"], 16))
	var ex := int(Save.d.get("extracts", 0))
	var cost := int(isd["cost"])
	var need := 0 if Game.modding() else int(isd["need"])
	if ex < need:
		v.add_child(UI.label("Make it out of %d more expedition%s to get the materials." % [need - ex, "" if need - ex == 1 else "s"], 15, UI.BAD))
		return
	v.add_child(UI.label("Costs %d gems. You have %d." % [cost, int(Save.d["gems"])], 15, UI.GOLD if int(Save.d["gems"]) >= cost else UI.BAD))
	var btn := UI.button("Build the bridge", func():
		if int(Save.d["gems"]) < cost or Save.has_bridge(k): return
		Save.d["gems"] = int(Save.d["gems"]) - cost
		Save.d["bridges"].append(k)
		Save.save_game()
		_close_panel()
		_build_bridge_now(k), 220)
	btn.disabled = int(Save.d["gems"]) < cost
	v.add_child(btn)

func _build_bridge_now(k: String) -> void:
	building_now = true
	var br: Dictionary = bridges[k]
	br["built"] = true
	_lay_planks(k, true)
	var n: int = _plank_spots(k).size()
	cam.zoom_to = 1.15
	get_tree().create_timer(n * 0.06 + 0.4).timeout.connect(func():
		world.open_bridge(br["tiles"])
		Sfx.play("unlock")
		var far: Vector3 = _plank_spots(k)[n - 1]
		fx.burst(far + Vector3(0, 1.0, 0), UI.GOLD, 24, 5.0, 0.8)
		var lbl: Label3D = br["label"]
		var tw := create_tween()
		tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
		tw.tween_callback(func(): lbl.visible = false)
		building_now = false
		_spawn_kin()
		_toast("%s is open" % Data.ISLES[k]["name"]))

func _toast(txt: String) -> void:
	UI.toast(root_ui, txt, UI.GOLD, 100.0 + (52.0 if guide and guide.hint_visible() else 0.0))

func _open_hall() -> void:
	var v := _new_panel("Trophy Hall", 560)
	var st: Dictionary = Save.d.get("stats", {})
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30); grid.add_theme_constant_override("v_separation", 6)
	for row in [["Expeditions", int(Save.d["matches"])], ["Made it out", int(Save.d.get("extracts", 0))],
			["Hunters knocked out", int(st.get("knocks", 0))], ["Best match, kills", int(st.get("best_kills", 0))],
			["Most gems carried home", int(st.get("best_gems", 0))], ["Boki brought home", int(st.get("caught", 0))]]:
		grid.add_child(UI.label(row[0], 16, UI.MUTED))
		grid.add_child(UI.label(str(row[1]), 18, UI.GOLD, UI.big))
	v.add_child(grid)
	v.add_child(UI.section("Your Boki"))
	var kr := HFlowContainer.new()
	kr.add_theme_constant_override("h_separation", 8)
	for rec in Save.d["roster"]:
		var sp: Dictionary = Data.KIN[rec["species"]]
		var c := UI.card(UI.CARD, 6, 10)
		c.add_child(UI.label("%s · %s · lv %d" % [rec["name"], sp["name"], int(rec["level"])], 14, sp["color"]))
		kr.add_child(c)
	v.add_child(kr)

# ---- class and loadout
func _refresh_player_model() -> void:
	var at := player.position
	var rot := player.rotation
	player.queue_free()
	var w := _weapon()
	player = Models.hunter(Data.class_of_save(), Data.TEAM_COLORS[0], w, "", Unmasked.worn(), Arch.of_save())
	player.position = at; player.rotation = rot
	add_child(player)

# ---- music list
func _open_music() -> void:
	var v := _new_panel("Music", 560)
	var have: Array = Save.d.get("music", [])
	v.add_child(UI.label("%d of %d tracks found. Pick one to play it here, or let the music follow where you are." % [have.size(), Data.MUSIC.size()], 14, UI.MUTED))
	for id in Data.MUSIC:
		var md: Dictionary = Data.MUSIC[id]
		var row := UI.hbox(10)
		var got: bool = have.has(id)
		var nl := UI.label(String(md["name"]) if got else "???", 16, UI.INK if got else UI.MUTED)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		if got:
			var tid: String = id
			var playing: bool = Sfx.music_name == id
			var b := UI.button("Playing" if playing else "Play", func():
				Sfx.music_lock = tid
				Sfx.play_music(tid, 1.0)
				_open_music(), 120)
			b.disabled = playing
			row.add_child(b)
		else:
			var hl := UI.label(String(md["hint"]), 13, UI.MUTED)
			hl.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(hl)
		v.add_child(row)
	if Sfx.music_lock != "":
		v.add_child(UI.button("Let the music follow where I am", func():
			Sfx.music_lock = ""
			Sfx.music_name = ""
			_music_t = 0.0
			_open_music(), 320))

# ---- visiting and the ferry
func _use_visiting(it: Dictionary) -> void:
	var owner_name := String(visit.get("name", "Their owner")).substr(0, 16)
	match it["kind"]:
		"kin":
			var rec: Dictionary = it["k"]["rec"]
			if petted.has(rec["uid"]):
				_emote(it["k"], "♥")
				return
			petted[rec["uid"]] = true
			Social.send_gift(visit_id, "pet", String(rec["uid"]))
			_emote(it["k"], "♥")
			Sfx.play("kin_happy")
			_toast("%s will remember your visit" % rec["name"])
		"house":
			_open_gift_panel(owner_name)
		"portal", "ferry":
			Game.goto("home")
		_:
			_toast("This belongs to %s" % owner_name)

func _open_gift_panel(owner_name: String) -> void:
	var v := _new_panel("Leave a gift for %s" % owner_name, 520)
	v.add_child(UI.primary("Go inside %s's house" % owner_name, func(): Game.goto("interior", {"room": "house", "visit": visit, "visit_id": visit_id}), 300))
	v.add_child(UI.label("They'll find it next time they're home.", 14, UI.MUTED))
	var any := false
	for kind in ["seed", "crop"]:
		var store: Dictionary = Save.d["seeds"] if kind == "seed" else Save.d["crops"]
		for key in store:
			if int(store[key]) <= 0 or not Data.CROPS.has(key):
				continue
			any = true
			var row := UI.hbox(10)
			var l := UI.label("%s%s  ×%d" % [Data.CROPS[key]["name"], " seed" if kind == "seed" else "", int(store[key])], 15, Data.CROPS[key]["color"])
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var kk: String = key
			var kd: String = kind
			row.add_child(UI.button("Give one", func():
				var st: Dictionary = Save.d["seeds"] if kd == "seed" else Save.d["crops"]
				if int(st.get(kk, 0)) <= 0:
					return
				st[kk] = int(st[kk]) - 1
				Save.save_game()
				_close_panel()
				Social.send_gift(visit_id, kd, kk, func(okk: bool):
					if okk:
						Sfx.play("pickup")
						if is_inside_tree(): _toast("Gift left for %s" % owner_name)
					else:
						st[kk] = int(st.get(kk, 0)) + 1      # it didn't arrive, so it's still yours
						Save.save_game()
						if is_inside_tree(): _toast("The gift couldn't be left. Try again in a moment.")), 140))
			v.add_child(row)
	if not any:
		v.add_child(UI.label("You have nothing to give yet. Seeds and crops make good gifts.", 15))

## The "while you were away" note waits until nothing else is on screen.
func _show_when_free(lines: Array, title := "While you were away") -> void:
	if not is_inside_tree():
		return
	if panel_open != "" or building_now or not Save.d["tutorial"].get("home", false):
		get_tree().create_timer(1.0).timeout.connect(_show_when_free.bind(lines, title))
		return
	var v := _new_panel(title, 520)
	for l in lines: v.add_child(UI.label(HomeNotices.bullet(String(l)), 15))
	_refresh_top()

func _open_ferry() -> void:
	var v := _new_panel("Ferry", 520)
	if not Social.available():
		v.add_child(UI.label("The ferry will connect you with other players: the town, guilds and friends' islands. It isn't running yet. Check back in a later update.", 15))
		return
	v.add_child(UI.label("Where to?", 14, UI.MUTED))
	v.add_child(UI.button("The town: market, notice board and guilds", func(): Game.goto("town", {"mode": "hub"}), 440))
	if not Social.guild.is_empty():
		var gname := String(Social.guild.get("name", "your guild"))
		var gid := Social.my_guild_id()
		v.add_child(UI.button("Your guild isle: %s" % gname, func(): Game.goto("town", {"mode": "guild", "gid": gid}), 440))
	v.add_child(UI.label("Visit a friend's island", 14, UI.MUTED))
	var list := UI.vbox(6)
	v.add_child(list)
	list.add_child(UI.label("Looking for islands...", 14, UI.MUTED))
	Social.list_islands(func(rows: Array):
		if not is_instance_valid(list):
			return
		for c in list.get_children():
			c.queue_free()
		if rows.is_empty():
			list.add_child(UI.label("Nobody else has an island here yet. Share the game with a friend to visit each other.", 14, UI.MUTED))
		for r in rows.slice(0, 12):
			var d: Dictionary = r["d"]
			var row := UI.hbox(10)
			var l := UI.label("%s  ·  %d Boki  ·  %d buildings" % [d["name"], d["roster"].size(), d["buildings"].size()], 15)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var rid: String = r["id"]
			row.add_child(UI.button("Visit", func(): Game.goto("home", {"visit": d, "visit_id": rid}), 100))
			list.add_child(row))


# ---- house
func _open_house() -> void:
	var v := _new_panel("Your house", 620)
	v.add_child(UI.label("Your Boki. The one you bring on expeditions is your partner.", 15, UI.MUTED))
	for rec in Save.d["roster"]:
		var row := UI.card(UI.CARD, 10, 10)
		var h := UI.hbox(12); row.add_child(h)
		var sp: Dictionary = Data.KIN[rec["species"]]
		var dot := ColorRect.new(); dot.color = sp["color"]; dot.custom_minimum_size = Vector2(14, 14)
		h.add_child(dot)
		var info := UI.label("%s  ·  level %d  ·  trust %d" % [Data.kin_title(String(rec["name"]), Evo.form_name(rec)), int(rec["level"]), int(rec["trust"])], 15)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var r: Dictionary = rec
		if rec["uid"] == Save.d.get("active", ""):
			h.add_child(UI.label("Partner", 14, UI.GOLD))
		else:
			h.add_child(UI.button("Make partner", func():
				Save.d["active"] = r["uid"]
				Save.save_game()
				_open_house()))
		h.add_child(UI.button("Visit", func(): _open_kin(r)))
		v.add_child(row)
	var hb := UI.hbox(8)
	hb.add_child(UI.button("Music", _open_music, 160))
	hb.add_child(UI.button("Settings", _open_settings, 160))
	v.add_child(hb)

# ---- settings
func _open_settings() -> void:
	_close_panel()
	Overlay.ctx = "home"
	Overlay.open_settings()

# ------------------------------------------------------------------ raising: needs, care, training, eggs
# (where these stand on a classic island; a farm-start island moves them with its placed fixtures)
var YARD_AT := Vector3(40.9, 0, 32.7)
var YARD_KIN := Vector3(40.6, 0, 32.9)
var NEST_AT := Vector3(34.4, 0, 33.7)    # the Nesting Nook, between the market stall and the pond
var INCUB_AT := NEST_AT + Vector3(-2.45, 0, 0.45)    # the Incubator, beside the Nook: Rare Eggs hatch here
## The Kin Burrow, where the kin who aren't out on the farm sleep (KinBox, KinBoxView)
var BURROW_AT := Vector3(30.6, 0, 38.8)    # south of the market stall, between the cottage lot and the pond
const BURROW_RECT := [29, 38, 31, 39]
var burrow_node: Node3D = null
var kinbox_view: KinBoxView = null

## The kin out on the island being shown (yours: not the ones asleep in the Kin Burrow).
func _farm_kin() -> Array:
	return (_d()["roster"] as Array) if not visit.is_empty() else KinBox.farm()

func _build_burrow() -> void:
	burrow_node = KinBurrow.model(KinBox.boxed().size())
	burrow_node.position = BURROW_AT
	burrow_node.scale = Vector3.ONE * 0.8
	add_child(burrow_node)
	var bl := Label3D.new()
	bl.text = "Boki Burrow"; bl.font = UI.big; bl.font_size = 40; bl.pixel_size = 0.008; bl.outline_size = 10
	bl.modulate = Color("d9c8ff"); bl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bl.position = BURROW_AT + Vector3(0, 1.85, 0.3)
	add_child(bl)

func _refresh_burrow() -> void:
	KinBurrow.set_sleepers(burrow_node, KinBox.boxed().size())

## The Kin Box (Kin Burrow) screen, for menus and shortcuts (the hub bar's Kin button).
func open_kin_box() -> void:
	if visit.is_empty(): _open_burrow()

## The Kin Burrow screen: the farm, the box pages and the kin you picked.
func _open_burrow() -> void:
	kinbox_view = KinBoxView.open(self)
	_refresh_burrow()
var POND_EDGE := Vector3(35.7, 0, 37.4)
var care_acc := 0.0
var care_save := 0.0
var yard: Node3D = null
var nest: Node3D = null
var train := {}                 # the training session in progress
var train_bar: Control = null
var train_lbl: Label = null
var train_draw: Control = null

## Builds the yard and the nest, and catches every kin up on the time you were away.
func _setup_care() -> void:
	if not fs:
		yard = Models.training_yard()
		yard.position = YARD_AT
		add_child(yard)
		# the Nesting Nook: where two close kin leave an egg
		var nook := Models.nesting_nook()
		nook.position = NEST_AT
		add_child(nook)
		var nl := Label3D.new()
		nl.text = "Nesting Nook"; nl.font = UI.big; nl.font_size = 40; nl.pixel_size = 0.008; nl.outline_size = 10
		nl.modulate = Color("ffc0d0"); nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nl.position = NEST_AT + Vector3(0, 2.95, -0.7)
		add_child(nl)
	if visit.is_empty():
		hinc = HomeIncubator.new(self)
		hinc.build()
	if not visit.is_empty():
		return
	# the time you were away: needs drift, kin eat from the feeders, and hungry ones may starve
	hecon.away = Econ.catch_up_all()
	# nobody is left with no Boki: a stray turns up (Lifeline; the toast is in home_notices.gd)
	var floor_ev := Lifeline.check()
	if hecon.away.any(func(e): return e["kind"] == "died") or not floor_ev.is_empty():
		_spawn_kin()
	HomeNotices.toast_stray(self, floor_ev)
	HomeNotices.show_migration(self)       # the one-time list of what the equal-footing save update converted
	# what Boki assigned to stations made while you were away (Work.catch_up)
	away_work = Work.catch_up()
	if not away_work.is_empty():
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(self) and is_inside_tree():
				_show_when_free(away_work)
				_refresh_top())
	Care.dex_sync()
	_refresh_nest()

func _refresh_nest() -> void:
	if is_instance_valid(nest):
		nest.queue_free()
	nest = null
	if visit.is_empty():
		Incubator.ensure()
		if Incubator.migrate():
			# an older save's Rare Egg was sitting in the breeding nest: it moves to the Incubator
			Save.save_game()
			if hinc: hinc.refresh()
			_toast("The Rare Egg moved to the Incubator beside the Nook")
		elif Incubator.settle() > 0:
			Save.save_game()
			if hinc: hinc.refresh()
	var egg: Dictionary = Save.d.get("egg", {})
	if egg.is_empty() or not visit.is_empty():
		return
	var col: Color = Data.KIN[_egg_species()]["color"] if _egg_species() != "" else Color("f2e6cf")
	if egg.get("rare", false):
		# a boss's egg: gold, glowing, with the rare kin's colour in its spots
		nest = Models.nest_egg(Color("ffd36a"), Data.KIN[_egg_species()].get("glow", col) if _egg_species() != "" else col)
		var sp2 := CPUParticles3D.new()
		sp2.amount = 16; sp2.lifetime = 1.6; sp2.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp2.emission_sphere_radius = 0.35
		sp2.direction = Vector3.UP; sp2.spread = 25.0; sp2.initial_velocity_min = 0.3; sp2.initial_velocity_max = 0.8; sp2.gravity = Vector3.ZERO
		sp2.scale_amount_min = 0.04; sp2.scale_amount_max = 0.08; sp2.mesh = Models.sphere(0.5, 4)
		sp2.material_override = Models.glow_mat(Color(1.0, 0.88, 0.45, 0.9)); sp2.position.y = 0.4
		nest.add_child(sp2)
	else:
		nest = Models.nest_egg(col, Color("fff6c0"))
	nest.position = NEST_AT
	add_child(nest)

## The species in the nest egg ("" if none). Older saves didn't store it: fall back to parent A.
func _egg_species() -> String:
	var egg: Dictionary = Save.d.get("egg", {})
	if egg.is_empty():
		return ""
	var sp := String(egg.get("sp", ""))
	if sp == "" or not Data.KIN.has(sp):
		var a := Save.kin(String(egg.get("a", "")))
		sp = String(a.get("species", ""))
	return sp if Data.KIN.has(sp) else ""

func _egg_label() -> String:
	var sp := _egg_species()
	var rare: bool = Save.d.get("egg", {}).get("rare", false)
	return ("Rare " if rare else "") + (Data.egg_name(sp) if sp != "" else "egg")

func _egg_ready() -> bool:
	var egg: Dictionary = Save.d.get("egg", {})
	if egg.is_empty():
		return false
	return int(Save.d["matches"]) >= int(egg.get("m", 0)) or Time.get_unix_time_from_system() >= float(egg.get("t", 0.0))

## Needs drift every second; kin asleep in bed (or napping) get their energy back.
func _care_tick(d: float) -> void:
	if not visit.is_empty():
		return
	care_acc += d
	care_save += d
	if care_acc >= 1.0:
		var night := sin((day_t - 0.25) * TAU) < -0.2
		for k in kins:
			var rec: Dictionary = k["rec"]
			var in_bed: bool = k.has("bed") and Vector2(k["pos"].x - k["bed"].x, k["pos"].z - k["bed"].z).length() < 0.6
			Care.tick(rec, care_acc, float(k.get("nap_t", 0.0)) > 0.0 or (night and in_bed) or k.has("indoors"))
		care_acc = 0.0
	if care_save > 20.0:
		care_save = 0.0
		Save.save_game()
	# a little life: an egg wobbles when it's close, dusty kin shed a little dust
	if is_instance_valid(nest) and _egg_ready():
		var sh: Node3D = nest.get_node("Shell")
		sh.rotation.z = sin(Time.get_ticks_msec() / 90.0) * 0.12 * (1.0 if fmod(Time.get_ticks_msec() / 1000.0, 3.0) < 0.6 else 0.0)

## The thought bubble over each kin that wants something (KinWants), and the sleeping badge by the door.
func _update_bubbles(d: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	KinWants.update(self, d, now)
	FarmChatter.tick(self, d)
	KinIndoors.badge(self, _house_door(), KinIndoors.names(kins), ppos)
	for k in kins:
		var rec: Dictionary = k["rec"]
		# dusty kin shed a little dust as they go
		if visit.is_empty() and Care.need(rec, "clean") < 22.0 and randf() < d * 0.4:
			fx.dust(k["pos"], 3)
		# saying hello when you walk up to it
		k["hi_cd"] = float(k.get("hi_cd", 0.0)) - d
		# the big moment of its last expedition: it brings it up when you're close
		if rec.has("recall") and visit.is_empty() and panel_open == "" and not chat_open and not k.get("busy", false) \
				and float(k.get("nap_t", 0.0)) <= 0.0 and Vector2(ppos.x - k["pos"].x, ppos.z - k["pos"].z).length() < 3.2:
			var rl := BokiLines.say(rec, "back_" + String(rec["recall"].get("kind", "")))
			rec.erase("recall")
			k["hi_cd"] = 25.0
			if rl != "":
				_say(k, rl)
				_emote(k, "♥" if float(rec["trust"]) > 55.0 else "!")
				Sfx.play("kin_happy", k["pos"], -8.0, 0.15, Unique.voice(rec))
				Save.save_game()
		if visit.is_empty() and float(k["hi_cd"]) <= 0.0 and panel_open == "" and not chat_open and train.is_empty() and not k.get("busy", false):
			if Vector2(ppos.x - k["pos"].x, ppos.z - k["pos"].z).length() < 2.0:
				k["hi_cd"] = randf_range(18.0, 30.0)
				if randf() < 0.5 and float(k.get("nap_t", 0.0)) <= 0.0:
					_say(k, _greeting(rec), 0.0, false)

## Gentle routines driven by how it's feeling. Returns true if it chose where to go.
func _care_goal(k: Dictionary) -> bool:
	var rec: Dictionary = k["rec"]
	if not visit.is_empty():
		return false
	if Care.need(rec, "energy") < 22.0 and k.has("bed"):
		k["goal"] = k["bed"]
		k["nap_go"] = true
		return true
	if hecon and hecon.feed_goal(k):
		return true      # off to a feeder
	if Care.need(rec, "food") < 30.0 and randf() < 0.4 and spots["pot"].x > -100.0:
		k["goal"] = _seat(k, spots["pot"], 1.4)
		k["stare"] = spots["pot"]
		return true
	if Care.need(rec, "joy") < 30.0 and randf() < 0.6 and world.island_of(ppos.x, ppos.z) == world.island_of(k["pos"].x, k["pos"].z):
		k["goal"] = _seat(k, ppos, 1.4)
		return true
	return false

## Per-frame care states: napping, bathing, staring at the pot.
func _care_step(k: Dictionary, d: float) -> void:
	if hecon and hecon.feed_step(k, d):
		return
	var rec: Dictionary = k["rec"]
	var pos: Vector3 = k["pos"]
	if float(k.get("nap_t", 0.0)) > 0.0:
		k["nap_t"] = float(k["nap_t"]) - d
		k["goal"] = pos
		k["z_t"] = float(k.get("z_t", 0.0)) - d
		if float(k["z_t"]) <= 0.0:
			k["z_t"] = 2.2
			_emote(k, "z")
		k["slept"] = float(k.get("slept", 0.0)) + d
		if float(k["nap_t"]) <= 0.0:
			Care.change(rec, "energy", 40.0 * clampf(float(k["slept"]) / 30.0, 0.0, 1.0))
			k["slept"] = 0.0
			Care.change(rec, "joy", 4.0)
			k["t"] = 1.0
			_emote(k, "!")
		return
	if k.get("nap_go", false) and k.has("bed") and Vector2(pos.x - k["bed"].x, pos.z - k["bed"].z).length() < 0.5:
		k.erase("nap_go"); k.erase("nap_go_t")
		k["slept"] = 0.0
		k["nap_t"] = 30.0
		k["z_t"] = 0.5
	if k.has("stare") and Vector2(pos.x - k["goal"].x, pos.z - k["goal"].z).length() < 0.5:
		var at: Vector3 = k["stare"]
		k.erase("stare")
		k["hold_t"] = 3.0
		_emote(k, "?")
		(k["node"] as Node3D).rotation.y = atan2(-(at.x - pos.x), -(at.z - pos.z))
	if k.has("bath"):
		var b: Dictionary = k["bath"]
		if b["phase"] == "go":
			k["goal"] = POND_EDGE
			b["t"] = float(b["t"]) + d
			if Vector2(pos.x - POND_EDGE.x, pos.z - POND_EDGE.z).length() < 0.6 or float(b["t"]) > 10.0:
				b["phase"] = "splash"; b["t"] = 3.0
				Sfx.play("plant", POND_EDGE, -4.0, 0.1, 1.4)
		else:
			k["goal"] = pos
			b["t"] = float(b["t"]) - d
			k["hop"] = float(k["hop"]) + d * 14.0
			if randf() < d * 6.0:
				fx.burst(pos + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3)), Color("8fd0ff"), 6, 2.2, 0.4)
			if float(b["t"]) <= 0.0:
				k.erase("bath")
				_finish_bath(k)

## Speed multiplier for a tired kin.
func _care_speed(rec: Dictionary) -> float:
	return (0.7 if Care.need(rec, "energy") < 25.0 else 1.0) * (0.7 if Care.starve_h(rec) >= Care.STARVE["weak"] else 1.0)

# ---- care actions, from the kin's card; they play out in the world, not in a menu
func _care_start(k: Dictionary) -> bool:
	if k.is_empty():
		return false
	_close_panel()
	k.erase("chase"); k.erase("task"); k.erase("stare"); k.erase("nap_go"); k.erase("eat")
	k["nap_t"] = 0.0
	return true

func _care_feed(rec: Dictionary, f: String) -> void:
	var k := _kin_entry(rec)
	if not _care_start(k):
		return
	var have := int(Save.d["crops"].get(f, 0)) if Data.CROPS.has(f) else int(Save.d["items"].get(f, 0))
	if have <= 0:
		return
	# it comes over to you and you put the food down in front of it
	var at := ppos + Vector3(sin(pface) * -1.0, 0, cos(pface) * -1.0)
	if world.is_void(at.x, at.z) or world.is_block(at.x, at.z): at = ppos + Vector3(0.9, 0, 0.4)
	k["pos"] = at
	(k["node"] as Node3D).position = at
	k["hold_t"] = 3.2
	_face(at)
	var food := MeshInstance3D.new()
	food.mesh = Models.sphere(0.11, 10)
	food.material_override = Models.toon(Care.food_col(f))
	var fp := at + Vector3((ppos.x - at.x) * 0.35, 0.12, (ppos.z - at.z) * 0.35)
	food.position = fp
	add_child(food)
	(k["node"] as Node3D).rotation.y = atan2(-(fp.x - at.x), -(fp.z - at.z))
	var res := Care.feed(rec, f)
	if res["ok"]:
		# taken out of the pantry now, so two quick feeds can't both use the last one
		if Data.CROPS.has(f): Save.d["crops"][f] = int(Save.d["crops"][f]) - 1
		else: Save.d["items"][f] = int(Save.d["items"][f]) - 1
	var body: Node3D = (k["node"] as Node3D).get_node("Body")
	var tw := create_tween()
	if res["ok"]:
		for i in 3:
			tw.tween_property(body, "scale", Vector3(1.12, 0.86, 1.12), 0.14)
			tw.tween_property(body, "scale", Vector3.ONE, 0.14)
			tw.tween_callback(func(): fx.burst(fp, Care.food_col(f), 4, 1.2, 0.3); Sfx.play("pickup", fp, -16.0, 0.1, 1.4))
		tw.tween_callback(func(): food.queue_free())
	else:
		# a sniff, then a firm no
		tw.tween_interval(0.4)
		var n: Node3D = k["node"]
		var r0 := n.rotation.y
		for i in 3:
			tw.tween_property(n, "rotation:y", r0 + 0.5, 0.08)
			tw.tween_property(n, "rotation:y", r0 - 0.5, 0.08)
		tw.tween_property(n, "rotation:y", r0, 0.08)
		tw.tween_interval(0.6)
		tw.tween_callback(func(): food.queue_free())
	tw.tween_callback(func(): _after_feed(k, f, res))

func _after_feed(k: Dictionary, f: String, res: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	var nm: String = rec["name"]
	if res["hate"]:
		_say(k, BokiLines.say(rec, "fed_no"))
		if res["new"]: _toast("You found out %s won't eat %s" % [nm, Care.food_name(f)])
		return
	if res["full"] and not res["ok"]:
		_say(k, BokiLines.say(rec, "full"))
		return
	if Data.CROPS.has(f):
		for af in Evo.AFF:
			if Evo.AFF[af]["food"] == f: Evo.add(rec, af, 6.0)
	if res["love"]:
		k["joy_t"] = 1.2
		_emote(k, "♥")
		fx.burst(k["pos"] + Vector3(0, 0.9, 0), Color("ff8fb0"), 16, 2.2)
		Sfx.play("kin_happy", null, -2.0, 0.1)
		_say(k, BokiLines.say(rec, "fed_fav"))
		if res["new"]: _toast("%s loves %s!" % [nm, Care.food_name(f)])
	else:
		_emote(k, "♪")
		Sfx.play("kin_happy", null, -8.0)
		_say(k, BokiLines.say(rec, "fed"))
	if res.get("hungry", false):
		Save.remember(rec, "fed", "was fed when it was hungry", 2.0)
	elif int(rec.get("fed_m", -1)) != int(Save.d["matches"]):
		rec["fed_m"] = int(Save.d["matches"])
		Save.remember(rec, "fed", "was fed %s by you" % Care.food_name(f).to_lower(), 1.0)
	Save.save_game()
	_refresh_top()

func _care_brush(rec: Dictionary) -> void:
	var k := _kin_entry(rec)
	if not _care_start(k):
		return
	if Vector2(ppos.x - k["pos"].x, ppos.z - k["pos"].z).length() > 1.4:
		k["pos"] = ppos + Vector3(0.9, 0, 0.3)
		(k["node"] as Node3D).position = k["pos"]
	k["hold_t"] = 2.2
	_face(k["pos"])
	var tw := create_tween()
	for i in 5:
		tw.tween_callback(func(): fx.burst(k["pos"] + Vector3(randf_range(-0.2, 0.2), 0.5, randf_range(-0.2, 0.2)), Color("fff6c0"), 5, 1.4, 0.35); Sfx.play("click", null, -18.0, 0.1, 1.6))
		tw.tween_interval(0.32)
	tw.tween_callback(func():
		var clean_before := Care.need(rec, "clean")
		Care.change(rec, "clean", 32.0)
		var loves: bool = rec["likes"]["play"] == "brush"
		Care.change(rec, "joy", 18.0 if loves else 6.0)
		k["joy_t"] = 0.8
		_emote(k, "♥" if loves else "★")
		_say(k, BokiLines.say(rec, "brushed"))
		if loves and Care.discover(rec, "play"): _toast("%s loves being brushed" % rec["name"])
		if clean_before < 30.0: Save.remember(rec, "brushed", "got brushed clean when it was a mess", 1.5)
		Save.save_game())

func _care_bath(rec: Dictionary) -> void:
	var k := _kin_entry(rec)
	if not _care_start(k):
		return
	k["bath"] = {"phase": "go", "t": 0.0}
	_emote(k, "!")

func _finish_bath(k: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	Care.change(rec, "clean", 100.0)
	Care.change(rec, "energy", -4.0)
	var loves: bool = rec["likes"]["play"] == "bath"
	var grumpy: bool = not loves and float(rec["traits"].get("curiosity", 0.5)) < 0.45
	Care.change(rec, "joy", 16.0 if loves else (-5.0 if grumpy else 4.0))
	fx.burst(k["pos"] + Vector3(0, 0.6, 0), Color("8fd0ff"), 18, 3.0, 0.5)
	if loves:
		_emote(k, "♥")
		_say(k, BokiLines.say(rec, "bath_fav"))
		if Care.discover(rec, "play"): _toast("%s loves baths" % rec["name"])
	elif grumpy:
		_emote(k, "!")
		_say(k, BokiLines.say(rec, "bath_grump"))
	else:
		_emote(k, "★")
	k["t"] = 1.5
	Save.save_game()

func _care_nap(rec: Dictionary) -> void:
	var k := _kin_entry(rec)
	if not _care_start(k):
		return
	if k.has("bed"):
		k["goal"] = k["bed"]
		k["nap_go"] = true
		k["nap_go_t"] = 15.0
	else:
		k["nap_t"] = 30.0
		k["slept"] = 0.0
	_say(k, BokiLines.say(rec, "nap"))

# ---- training: a timing game at the yard; three rounds, each a little faster
func _start_drill(rec: Dictionary, stat: String) -> void:
	var k := _kin_entry(rec)
	if k.is_empty():
		return
	if Care.need(rec, "energy") < 20.0 or Care.need(rec, "food") < 12.0:
		_close_panel()
		var why := "energy" if Care.need(rec, "energy") < 20.0 else "food"
		_say(k, BokiLines.say(rec, "want_" + why))
		_toast("%s is too %s to train. %s first" % [rec["name"], "tired" if why == "energy" else "hungry", "Let it nap" if why == "energy" else "Feed it"])
		return
	if int(rec["stats"][stat]) >= Care.stat_cap(rec):
		_toast("%s can't train %s any further until it levels up" % [rec["name"], Care.STATS[stat]["name"]])
		return
	if not _care_start(k):
		return
	k["busy"] = true
	k["pos"] = YARD_KIN
	var n: Node3D = k["node"]
	n.position = YARD_KIN
	var dummy := yard.get_node("Dummy") as Node3D
	var dpos := dummy.global_position
	n.rotation.y = atan2(-(dpos.x - YARD_KIN.x), -(dpos.z - YARD_KIN.z))
	ppos = YARD_KIN + Vector3(-0.6, 0, 1.4)
	player.position = ppos
	_face(YARD_KIN)
	train = {"k": k, "stat": stat, "round": 0, "results": [], "m": 0.0, "dir": 1.0, "speed": 0.85, "zone": randf_range(0.3, 0.7), "wait": 0.0}
	_build_train_bar()
	Sfx.play("whoosh", null, -8.0)

func _build_train_bar() -> void:
	if is_instance_valid(train_bar): train_bar.queue_free()
	var bar := UI.card(Color(UI.NIGHT, 0.92), 12, 14)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_top = -64; bar.offset_bottom = -64
	bar.custom_minimum_size.x = minf(560.0, get_viewport().get_visible_rect().size.x - 32.0)
	var col := UI.vbox(8); bar.add_child(col)
	train_lbl = UI.label("", 15)
	col.add_child(train_lbl)
	train_draw = Control.new()
	train_draw.custom_minimum_size = Vector2(0, 26)
	train_draw.draw.connect(_draw_train)
	col.add_child(train_draw)
	col.add_child(UI.label("Press %s (or click) when the marker is in the gold" % Settings.key_cap("interact"), 12, UI.MUTED))
	root_ui.add_child(bar)
	train_bar = bar
	_train_label()

func _train_label() -> void:
	if not is_instance_valid(train_lbl) or train.is_empty():
		return
	var st: Dictionary = Care.STATS[train["stat"]]
	var res: Array = train["results"]
	var marks := ""
	for r in res: marks += {"great": "  ★", "good": "  ●", "miss": "  ✕"}[r]
	train_lbl.text = "%s  ·  round %d of 3%s" % [st["drill"], mini(int(train["round"]) + 1, 3), marks]
	train_lbl.add_theme_color_override("font_color", st["col"])

func _draw_train() -> void:
	if train.is_empty() or not is_instance_valid(train_draw):
		return
	var w := train_draw.size.x
	var h := train_draw.size.y
	train_draw.draw_rect(Rect2(0, h * 0.3, w, h * 0.4), Color(1, 1, 1, 0.1))
	var z: float = train["zone"]
	train_draw.draw_rect(Rect2(w * (z - 0.16), h * 0.3, w * 0.32, h * 0.4), Color(UI.ACCENT, 0.45))
	train_draw.draw_rect(Rect2(w * (z - 0.06), h * 0.2, w * 0.12, h * 0.6), UI.GOLD)
	var mx := w * float(train["m"])
	train_draw.draw_rect(Rect2(mx - 3, 0, 6, h), UI.INK)

func _train_process(d: float) -> void:
	if train.is_empty():
		return
	if float(train["wait"]) > 0.0:
		train["wait"] = float(train["wait"]) - d
		if float(train["wait"]) <= 0.0 and int(train["round"]) >= 3:
			_finish_training()
		return
	var m := float(train["m"]) + float(train["dir"]) * float(train["speed"]) * d
	if m > 1.0: m = 2.0 - m; train["dir"] = -1.0
	if m < 0.0: m = -m; train["dir"] = 1.0
	train["m"] = m
	if is_instance_valid(train_draw): train_draw.queue_redraw()

func _train_hit() -> void:
	if train.is_empty() or float(train["wait"]) > 0.0:
		return
	var off := absf(float(train["m"]) - float(train["zone"]))
	var r := "great" if off < 0.06 else ("good" if off < 0.16 else "miss")
	train["results"].append(r)
	train["round"] = int(train["round"]) + 1
	train["wait"] = 1.1
	train["speed"] = float(train["speed"]) * 1.35
	train["zone"] = randf_range(0.2, 0.8)
	_train_anim(train["k"], String(train["stat"]), r)
	_train_label()

## What the kin does each round.
func _train_anim(k: Dictionary, stat: String, r: String) -> void:
	var n: Node3D = k["node"]
	var body: Node3D = n.get_node("Body")
	var dummy := yard.get_node("Dummy") as Node3D
	var tw := create_tween()
	var col: Color = Care.STATS[stat]["col"]
	match stat:
		"power":
			var to := YARD_KIN.lerp(dummy.global_position, 0.55)
			tw.tween_property(n, "position", to, 0.12)
			tw.tween_callback(func():
				if r != "miss":
					fx.burst(dummy.global_position + Vector3(0, 1.0, 0), Color("e2c47a"), 12 if r == "great" else 6, 3.0, 0.4)
					Sfx.play("kinhit", dummy.global_position, -6.0)
					var dt := create_tween()
					dt.tween_property(dummy, "rotation:z", 0.35 if r == "great" else 0.18, 0.08)
					dt.tween_property(dummy, "rotation:z", 0.0, 0.3)
				else:
					Sfx.play("whoosh", null, -10.0))
			tw.tween_property(n, "position", YARD_KIN, 0.2)
		"guard":
			tw.tween_property(body, "scale", Vector3(1.2, 0.72, 1.2), 0.12)
			tw.tween_callback(func(): if r != "miss": fx.ring(YARD_KIN, 1.2, col, 0.3); Sfx.play("shield", null, -10.0))
			tw.tween_interval(0.3)
			tw.tween_property(body, "scale", Vector3.ONE, 0.15)
		"speed":
			var hoop := yard.global_position + Vector3(-1.4, 0, 0.2)
			tw.tween_property(n, "position", hoop, 0.18 if r != "miss" else 0.35)
			tw.tween_callback(func(): if r != "miss": fx.burst(hoop + Vector3(0, 0.4, 0), col, 8, 2.5, 0.3))
			tw.tween_property(n, "position", YARD_KIN, 0.18 if r != "miss" else 0.35)
		"focus":
			tw.tween_property(n, "rotation:y", n.rotation.y + TAU, 0.6)
			tw.tween_callback(func(): if r != "miss": fx.burst(YARD_KIN + Vector3(0, 0.5, 0), col, 14 if r == "great" else 7, 1.6, 0.6, -3.0))
	_emote(k, {"great": "★", "good": "♪", "miss": "?"}[r])

func _finish_training() -> void:
	var k: Dictionary = train["k"]
	var rec: Dictionary = k["rec"]
	var stat: String = train["stat"]
	var pts := 0
	for r in train["results"]:
		pts += {"great": 3, "good": 2, "miss": 0}[r]
		if r != "miss" and Save.has_building("dojo"): pts += 1
	var mult := 1.0
	if Care.need(rec, "joy") >= 60.0: mult *= 1.25
	if Care.need(rec, "energy") < 35.0: mult *= 0.7
	var gained := Care.add_stat(rec, stat, int(round(pts * mult)))
	Care.change(rec, "energy", -18.0)
	Care.change(rec, "food", -6.0)
	Care.change(rec, "joy", 4.0 if (train["results"] as Array).has("great") else -2.0)
	var aff: String = {"power": "fierce", "guard": "steadfast", "speed": "swift", "focus": "curious"}[stat]
	Evo.add(rec, aff, 2.0)
	if int(rec.get("trained_m", -1)) != int(Save.d["matches"]):
		rec["trained_m"] = int(Save.d["matches"])
		Save.remember(rec, "trained", "trained %s with you at the yard" % String(Care.STATS[stat]["name"]).to_lower(), 1.0)
	Save.save_game()
	_toast("+%d %s  (%d of %d)" % [gained, Care.STATS[stat]["name"], int(rec["stats"][stat]), Care.stat_cap(rec)] if gained > 0 else "No gain this time. Try again after a rest")
	_say(k, BokiLines.say(rec, "trained" if gained > 0 else "train_miss"))
	k["busy"] = false
	k["t"] = 1.5
	train = {}
	if is_instance_valid(train_bar): train_bar.queue_free()
	train_bar = null

# ---- eggs: two kin who are close leave an egg in the nest; you hatch and name it
func _can_pair(rec: Dictionary) -> String:
	if not Save.d.get("egg", {}).is_empty(): return "There's already an egg in the nest"
	if int(rec["level"]) < 5: return "Needs to be level 5"
	if float(rec["trust"]) < 50.0: return "Needs a Close bond (trust 50)"
	if int(rec.get("bred_m", -99)) > int(Save.d["matches"]) - 3: return "Needs a few more expeditions' rest"
	if KinBox.full(): return "Your farm and the Boki Burrow are full"
	if not Save.d.get("egg", {}).is_empty(): return "There's already an egg in the nest"
	return ""

## The Nesting Nook: every kin as a picture, ready ones first. Click one to see its IVs (what it was
## born with); pick two who are ready and they leave an egg in the nest. With two picked, the side
## panel lays their IVs side by side with what an egg could take from them.
var nook_pick: Array = []
var nook_view := ""          # the kin whose IVs the side panel shows ("" = the pair, or the intro)
var nook_scroll := 0.0
var nook_tab := "Pairs"      # Pairs (breeding) or Incubator (Rare Eggs)
const NOOK_COLS := 4
const NOOK_TILE := Vector2(128, 0)
const NOOK_H := 404.0        # the Nook's body height (fits a 720p window)
const NOOK_SIDE_W := 372.0   # the side panel's width, fixed so picking a Boki never widens the window

## A short word for why a kin can't pair yet ("" if it can), for the tiles.
func _pair_short(why: String) -> String:
	if why == "": return ""
	if why.contains("level"): return "Lv 5 needed"
	if why.contains("bond"): return "Not close yet"
	if why.contains("rest"): return "Resting"
	if why.contains("egg"): return "Egg in nest"
	if why.contains("full"): return "No room"
	return why

func _open_nook() -> void:
	var egg_in: bool = not Save.d.get("egg", {}).is_empty()
	var v := _new_panel("Nesting Nook", 1010)
	UI.hold(v, NOOK_H)           # the same size whichever tab, Boki or pair is showing
	Incubator.ensure()
	UI.shell_tabs(v, ["Pairs", "Incubator"], nook_tab, func(t): nook_tab = t; _open_nook(), {"Incubator": Incubator.count()} if Incubator.count() > 0 else {})
	if nook_tab == "Incubator":
		IncubatorView.build(self, v, _open_nook, _hatch_incubator)
		return
	nook_pick = nook_pick.filter(func(u): return not Save.kin(String(u)).is_empty() and _can_pair(Save.kin(String(u))) == "")
	if nook_view != "" and Save.kin(nook_view).is_empty(): nook_view = ""
	var roster: Array = (Save.d["roster"] as Array).duplicate()
	var ready_n := roster.filter(func(o): return _can_pair(o) == "").size()
	UI.subtitle(v, ("There's a %s in the nest. It hatches after your next expedition, or in about ten minutes at home." % _egg_label()) if egg_in
		else "Pick two Boki who are close. They leave an egg that mixes their personalities and takes some of their IVs.")
	UI.head_extra(v).add_child(UI.chip("egg", "%d ready" % ready_n, UI.GOOD if ready_n >= 2 else UI.MUTED, "Boki who can pair now: level 5, a Close bond, rested"))
	# picked first, then the ready ones, then the rest; higher levels first
	var rank := func(o) -> int: return 0 if nook_pick.has(o["uid"]) else (1 if _can_pair(o) == "" else 2)
	roster.sort_custom(func(x, y):
		var rx: int = rank.call(x); var ry: int = rank.call(y)
		if rx != ry: return rx < ry
		return int(x["level"]) > int(y["level"]))
	var cols := UI.hbox(16)
	v.add_child(cols)
	# the kin, as pictures
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(NOOK_COLS * (NOOK_TILE.x + 8) + 14, NOOK_H - 4)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = NOOK_COLS
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	cols.add_child(sc)
	for o in roster:
		grid.add_child(_nook_tile(o, egg_in))
	sc.scroll_vertical = int(nook_scroll)
	sc.get_v_scroll_bar().value_changed.connect(func(x): nook_scroll = x)
	(func(): if is_instance_valid(sc): sc.scroll_vertical = int(nook_scroll)).call_deferred()
	# the side: one kin's IVs, the pair, or what this is
	var dc := UI.card(UI.CARD, 14, 14)
	dc.custom_minimum_size = Vector2(NOOK_SIDE_W, NOOK_H - 4)
	dc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# a pair's IVs side by side can run long: only that side panel scrolls, the window never changes
	var dsc := ScrollContainer.new()
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER     # (DISABLED would pass its content's width up and widen the window)
	dsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dc.add_child(dsc)
	var dv := UI.vbox(8)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dsc.add_child(dv)
	cols.add_child(dc)
	var viewing := Save.kin(nook_view)
	if not viewing.is_empty():
		_nook_detail(viewing, dv, egg_in)
	elif nook_pick.size() == 2:
		_nook_pair(Save.kin(String(nook_pick[0])), Save.kin(String(nook_pick[1])), dv)
	else:
		_nook_intro(dv, egg_in)
	UI.footer_left(v).add_child(UI.label("Click a Boki to see its IVs", UI.T_SMALL, UI.FAINT))
	if not egg_in:
		var pr := UI.footer_primary(v, "Pair them" if nook_pick.size() < 2 else "Pair %s and %s" % [Save.kin(String(nook_pick[0]))["name"], Save.kin(String(nook_pick[1]))["name"]], func():
			if nook_pick.size() < 2: return
			var a := Save.kin(String(nook_pick[0])); var b := Save.kin(String(nook_pick[1]))
			nook_pick = []; nook_view = ""
			_make_egg(a, b), 200, "egg")
		pr.disabled = nook_pick.size() < 2
		pr.tooltip_text = "" if nook_pick.size() == 2 else "Pick %d more" % (2 - nook_pick.size())

## One kin in the Nook: its picture, name, kind and level, rare marks, whether it's ready, its IVs.
func _nook_tile(o: Dictionary, egg_in: bool) -> Control:
	var uid := String(o["uid"])
	var why := _can_pair(o)
	var picked: bool = nook_pick.has(uid)
	var viewed := uid == nook_view
	var t := UI.tile_card(picked or viewed, func(): nook_view = uid; _open_nook(), 8, UI.ACCENT if picked else UI.TEAL)
	t.custom_minimum_size = NOOK_TILE
	var tv := UI.vbox(2)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(tv)
	# the picture, with its level, rare marks and pick number over it
	var pic_box := Control.new()
	pic_box.custom_minimum_size = Vector2(NOOK_TILE.x - 16, 74)
	pic_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := KinPortrait.view(o, get_tree(), 74.0)
	pic.position = Vector2((NOOK_TILE.x - 16 - 74) * 0.5, 0)
	pic.size = Vector2(74, 74)
	if why != "" and not picked: pic.modulate = Color(1, 1, 1, 0.55)
	pic_box.add_child(pic)
	var lv := UI.label("Lv %d" % int(o.get("level", 1)), 11, UI.INK, UI.semi)
	lv.add_theme_constant_override("outline_size", 4)
	lv.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lv.position = Vector2(0, -2)
	pic_box.add_child(lv)
	if picked:
		var n := UI.tag(str(nook_pick.find(uid) + 1), UI.ACCENT)
		n.position = Vector2(0, 52)
		pic_box.add_child(n)
	tv.add_child(pic_box)
	var nm := UI.name_with_sex(o, String(o["name"]), UI.T_SMALL, UI.INK if why == "" or picked else UI.MUTED, UI.semi, 11.0)
	nm.alignment = BoxContainer.ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(nm)
	var spl := UI.label(Evo.form_name(o), 11, UI.MUTED)
	spl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spl.clip_text = true
	tv.add_child(spl)
	var st := UI.hbox(6)
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picked: st.add_child(UI.tag("Picked", UI.ACCENT))
	elif why == "": st.add_child(UI.tag("Ready", UI.GOOD))
	else: st.add_child(UI.tag(_pair_short(why), UI.MUTED))
	var mi := IvView.mini(o, 14.0, false)
	mi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(mi)
	tv.add_child(st)
	var tags := Mutations.tags(o)
	t.tooltip_text = "%s the %s%s  ·  Lv %d\n%s\nIVs %d/155 (%s)" % [o["name"], (" ".join(tags) + " ") if not tags.is_empty() else "", Evo.form_name(o), int(o.get("level", 1)),
		"Ready to pair" if why == "" else why, Care.iv_total(o), Care.iv_grade(o)[0]]
	return t

## The side panel for one kin: who it is, then its IVs as a chart, rows and the judge's word.
func _nook_detail(rec: Dictionary, dv: VBoxContainer, egg_in: bool) -> void:
	var uid := String(rec["uid"])
	var sp: Dictionary = Data.KIN[rec["species"]]
	var col: Color = Shiny.body(rec)
	var top := UI.hbox(12)
	top.add_child(KinPortrait.view(rec, get_tree(), 72.0))
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nrow := UI.hbox(8)
	nrow.add_child(UI.title(String(rec["name"]), UI.T_HEAD + 3, col.lerp(UI.INK, 0.35)))
	nrow.add_child(UI.sex_icon(rec, 16.0))
	tv.add_child(nrow)
	tv.add_child(UI.label("Level %d %s  ·  %s Boki" % [int(rec["level"]), Evo.form_name(rec), String(sp["type"]).capitalize()], UI.T_SMALL, UI.INK))
	var why := _can_pair(rec)
	tv.add_child(UI.label("Ready to pair" if why == "" else why, 12, UI.GOOD if why == "" else UI.MUTED))
	var mk := UI.hbox(4)
	if rec.get("shimmer", false): mk.add_child(UI.tag("Shimmering", UI.MUTED))
	for mid in Mutations.of(rec):
		var mt := UI.tag(Mutations.name_of(mid), UI.MUTED)
		mt.tooltip_text = Mutations.perk_text(mid)
		mt.mouse_filter = Control.MOUSE_FILTER_PASS
		mk.add_child(mt)
	if rec.get("rare", false): mk.add_child(UI.tag("Rare Egg", UI.MUTED))
	if mk.get_child_count() > 0: tv.add_child(mk)
	top.add_child(tv)
	dv.add_child(top)
	AboutView.block(rec, dv, true)      # its size, coat, eyes, habit and where it came from
	dv.add_child(IvView.heading())
	IvView.first_view_line(dv)
	var mid := UI.hbox(10)
	mid.add_child(IvView.radar(rec, 168.0, col.lerp(UI.ACCENT, 0.35)))
	var wv := UI.vbox(8)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.add_child(IvView.grade_line(rec))
	wv.add_child(IvView.word_list(rec))
	mid.add_child(wv)
	dv.add_child(mid)
	var jv := UI.vbox(2)
	jv.add_child(UI.para(Care.iv_judge(rec), 13, UI.INK))
	var from: Dictionary = rec.get("iv_from", {})
	if rec.has("parents") and not from.is_empty():
		var bits: Array = []
		for side in [0, 1]:
			var ks: Array = Care.IV_KEYS.filter(func(k): return from.has(k) and int(from[k]) == side)
			if not ks.is_empty():
				bits.append("%s from %s" % [", ".join(ks.map(func(k): return String(Care.IVS[k]["name"]))), rec["parents"][side]])
		jv.add_child(UI.para("; ".join(bits) + ".", 12, UI.MUTED))
	elif rec.get("rare", false):
		jv.add_child(UI.para("From a Rare Egg: three of its IVs are 26 or better.", 12, UI.MUTED))
	dv.add_child(jv)
	var br := UI.hbox(8)
	if not egg_in:
		if nook_pick.has(uid):
			br.add_child(UI.button("Unpick", func(): nook_pick.erase(uid); _open_nook(), 0, "close"))
		elif why == "":
			var pk := UI.button("Pick for an egg", func():
				if nook_pick.size() >= 2: nook_pick.pop_front()
				nook_pick.append(uid)
				if nook_pick.size() == 2: nook_view = ""     # show the pair
				_open_nook(), 0, "egg")
			br.add_child(pk)
	if nook_pick.size() == 2 and not nook_pick.has(uid):
		br.add_child(UI.ghost("Back to the pair", func(): nook_view = ""; _open_nook()))
	elif nook_pick.size() == 2:
		br.add_child(UI.ghost("Compare the pair", func(): nook_view = ""; _open_nook()))
	br.add_child(UI.fill())
	br.add_child(UI.ghost("Details", func(): _open_kin(rec)))
	dv.add_child(br)

## The side panel with two picked: both, their IVs side by side, what an egg could take.
func _nook_pair(a: Dictionary, b: Dictionary, dv: VBoxContainer) -> void:
	var top := UI.hbox(10)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 2:
		var r: Dictionary = a if i == 0 else b
		var pv := UI.vbox(0)
		var pic := KinPortrait.view(r, get_tree(), 64.0)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pv.add_child(pic)
		var l := UI.label("Lv %d %s" % [int(r["level"]), Evo.form_name(r)], 11, UI.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(l)
		top.add_child(pv)
		if i == 0:
			var h := Icons.Glyph.new("heart", Color("ff8fb0"), 22.0)
			h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			top.add_child(h)
	dv.add_child(top)
	dv.add_child(IvView.heading())
	dv.add_child(IvView.compare(a, b, 100.0))
	dv.add_child(IvView.pass_on(a, b))
	var sp_line := UI.para("The egg will be a %s or a %s, with a blend of their personalities." % [Data.KIN[a["species"]]["name"], Data.KIN[b["species"]]["name"]] if a["species"] != b["species"] else "The egg will be a %s, with a blend of their personalities." % Data.KIN[a["species"]]["name"], 12, UI.MUTED)
	dv.add_child(sp_line)
	var br := UI.hbox(8)
	br.add_child(UI.ghost("Clear picks", func(): nook_pick = []; _open_nook()))
	dv.add_child(br)

## The side panel before you've picked: what the Nook is for, and what IVs are.
func _nook_intro(dv: VBoxContainer, egg_in: bool) -> void:
	dv.add_child(UI.section("How it works"))
	if egg_in:
		dv.add_child(UI.para("The nest is taken until this egg hatches. You can still look through your Boki's IVs.", UI.T_SMALL, UI.INK))
	else:
		dv.add_child(UI.para("Pick two Boki who are ready: level 5, a Close bond, and rested from their last egg. The egg hatches after your next expedition, or in about ten minutes at home.", UI.T_SMALL, UI.INK))
	dv.add_child(UI.spacer(4))
	dv.add_child(IvView.heading())
	dv.add_child(UI.para(Care.IV_EXPLAIN, UI.T_SMALL, UI.MUTED))
	dv.add_child(UI.para("An egg takes 3 of its 5 IVs from its parents (each from one of them at random) and rolls the other 2 fresh. Rare Eggs from boss lairs always have 3 high ones.", UI.T_SMALL, UI.MUTED))
	if nook_pick.size() == 1:
		var r := Save.kin(String(nook_pick[0]))
		dv.add_child(UI.spacer(4))
		dv.add_child(UI.label("%s is picked. Pick one more." % r["name"], UI.T_SMALL, UI.ACCENT_HI))
	elif not egg_in:
		dv.add_child(UI.spacer(4))
		dv.add_child(UI.label("Click a Boki to see its IVs, then pick two.", UI.T_SMALL, UI.ACCENT_HI))

func _make_egg(rec: Dictionary, ok: Dictionary) -> void:
	# which parent it takes after is settled now, so the egg can wear that element's name and colour
	var esp: String = rec["species"] if randf() < 0.5 else ok["species"]
	Save.d["egg"] = {"a": rec["uid"], "b": ok["uid"], "sp": esp, "m": int(Save.d["matches"]) + 1, "t": Time.get_unix_time_from_system() + 600.0}
	rec["bred_m"] = int(Save.d["matches"]); ok["bred_m"] = int(Save.d["matches"])
	Save.remember(rec, "egg", "had an egg with %s" % ok["name"], 2.0)
	Save.remember(ok, "egg", "had an egg with %s" % rec["name"], 2.0)
	Save.save_game()
	_close_panel()
	_refresh_nest()
	fx.burst(NEST_AT + Vector3(0, 0.6, 0), Color("ff8fb0"), 24, 3.0)
	Sfx.play("unlock")
	_toast("A %s appeared in the Nesting Nook" % Data.egg_name(esp))

## Tooling for --nest-demo: a bred kin and a Rare Egg kin join the demo roster, then a view opens.
func _nest_demo(which: String) -> void:
	Save.no_write = true
	_close_panel()
	for r in Save.d["roster"]:
		Care.ensure(r); r.erase("starve")
		for n in Care.NEEDS: r["needs"][n] = 90.0
	Save.d["egg"] = {}
	Save.d["tutorial"].erase("ivs_seen")
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var ready: Array = []
	for r in Save.d["roster"]:
		if _can_pair(r) == "" and not r.get("starter", false): ready.append(r)
	ready.sort_custom(func(x, y): return Care.iv_total(x) > Care.iv_total(y))
	var pa: Dictionary = ready[0]
	var pb: Dictionary = {}
	for r in ready:
		if r["species"] != pa["species"]: pb = r; break
	var kid := Care.breed(pa, pb, rng)
	kid["name"] = "Sprig"; kid["level"] = 6; kid["trust"] = 62.0
	Save.d["roster"].append(kid); KinBox.route_new(kid)
	var rare := Care.hatch_rare({"sp": "cairnback" if Data.KIN.has("cairnback") else String(Data.common_kin()[0]), "boss": ""}, rng)
	rare["name"] = "Tor"
	Save.d["roster"].append(rare); KinBox.route_new(rare)
	Save.register_all()      # numbers, origin and first trainer for the made-up kin
	nook_pick = []; nook_view = ""; nook_scroll = 0.0; nook_tab = "Pairs"
	if which.begins_with("incub"):
		# five Rare Eggs in the cradles (warming, one ready), two waiting on the shelf, an Ember kin at the brazier
		Save.d["incubator"] = {}; Save.d["rare_eggs"] = []
		Incubator.ensure()
		var bosses: Array = Data.MOBS.keys().filter(func(b): return Data.MOBS[b].has("egg"))
		for i in 7:
			var bk: String = bosses[i % bosses.size()] if not bosses.is_empty() else ""
			Incubator.add(String(Data.MOBS[bk]["egg"]) if bk != "" else String(Data.common_kin()[0]), bk)
		var heats := [1.0, 0.7, 0.5, 0.3, 0.1]
		for e in Incubator.eggs(): e["heat"] = Incubator.HEAT_NEED * float(heats[int(e["slot"]) % heats.size()])
		Save.d["incubator"]["coal"] = 120.0
		Save.d["items"]["coals"] = 2
		if hinc:
			for e in Incubator.ready_eggs(): hinc.ready_ids[String(e["id"])] = true
			hinc.refresh()
		var ember: Dictionary = {}
		for k in kins:
			if Work.level(k["rec"], "ember") > 0: ember = k; break
		if not ember.is_empty() and hw:
			for n in Care.NEEDS: ember["rec"]["needs"][n] = 100.0
			ember["pos"] = hinc.warm_spot(); (ember["node"] as Node3D).position = ember["pos"]
			hw.scan()
			for j in hw.jobs:
				if String(j["kind"]) == "warm": hw.take(ember, j)
		ppos = INCUB_AT + Vector3(1.9, 0, 1.3) if which != "incub-wide" else INCUB_AT + Vector3(1.6, 0, 2.6); player.position = ppos; cam.snap(ppos)
		cam.zoom_to = 1.1 if which == "incub-wide" else 0.42; cam.zoom = cam.zoom_to
		if which == "incub-panel":
			nook_tab = "Incubator"
			get_tree().create_timer(1.2).timeout.connect(_open_nook)
		return
	match which:
		"kin": nook_view = String(kid["uid"]); _open_nook()
		"rare": nook_view = String(rare["uid"]); _open_nook()
		"pair": nook_pick = [String(pa["uid"]), String(pb["uid"])]; _open_nook()
		"card": kin_tab = "Growth"; _open_kin(kid)
		"card-care": kin_tab = "Care"; _open_kin(kid)
		"card-train": kin_tab = "Training"; _open_kin(kid)
		"card-about": kin_tab = "About"; _open_kin(kid)
		"box": KinBoxView.sel = String(kid["uid"]); KinBoxView.page = KinBox.page_of(kid) if KinBox.is_boxed(kid) else 0; _open_burrow()
		_: _open_nook()

## From a kin's card: the Nesting Nook with this kin already picked.
func _open_pair(rec: Dictionary) -> void:
	nook_tab = "Pairs"
	nook_pick = [String(rec["uid"])] if _can_pair(rec) == "" else []
	nook_view = String(rec["uid"])
	nook_scroll = 0.0
	_open_nook()

func _hatch_nest_egg() -> void:
	var egg: Dictionary = Save.d.get("egg", {})
	var rare: bool = egg.get("rare", false)
	var a := Save.kin(String(egg.get("a", "")))
	var b := Save.kin(String(egg.get("b", "")))
	if not rare and (a.is_empty() or b.is_empty()):
		Save.d["egg"] = {}
		_refresh_nest()
		return
	var rng := RandomNumberGenerator.new(); rng.randomize()
	var baby := Care.hatch_rare(egg, rng) if rare else Care.breed(a, b, rng, _egg_species())
	Save.d["egg"] = {}
	_hatch_play(baby, rare, String(egg.get("boss", "")), NEST_AT, nest.get_node("Shell") if is_instance_valid(nest) else null)

## A ready Rare Egg in the Incubator hatches (Incubator.hatch: a rare kin with three high IVs), in
## its own cradle. id: which egg ("" for the first one ready).
func _hatch_incubator(id := "") -> void:
	if not Incubator.any_ready():
		return
	_close_panel()
	var e: Dictionary = Incubator.find(id) if id != "" else {}
	if e.is_empty() or not Incubator.egg_ready(e): e = Incubator.ready_eggs()[0]
	var boss := String(e.get("boss", ""))
	var at: Vector3 = hinc.slot_pos(int(e.get("slot", 0))) if hinc else INCUB_AT
	var shell: Node3D = hinc.egg_nodes.get(String(e["id"]), null) if hinc else null
	var rng := RandomNumberGenerator.new(); rng.randomize()
	var baby := Incubator.hatch(rng, String(e["id"]))
	if baby.is_empty():
		return
	_hatch_play(baby, true, boss, at, shell)

## A new kin out of an egg: into the roster, then the hatch in stages, the reveal and naming.
func _hatch_play(baby: Dictionary, rare: bool, boss: String, at: Vector3, hide: Node3D) -> void:
	# it's yours from the moment it hatches; the naming card only renames it
	baby["name"] = Data.default_kin_name(String(baby["species"]))
	if rare:
		Save.remember(baby, "born", "hatched from a Rare Egg you carried home from %s" % String(Data.MOBS.get(boss, {}).get("name", "a boss's lair")), 2.0)
		Progress.add("rare_hatched")
	else:
		Save.remember(baby, "born", "hatched in the nest on your farm", 0.0)
	Progress.add("hatched")
	Save.d["roster"].append(baby)
	Save.register(baby)           # its serial, you as its trainer, and "hatched" in the log
	KinBox.route_new(baby)        # a repeat of a kind already on the farm goes to the Kin Burrow (unless it's rare)
	Care.dex_got(baby)
	Save.save_game()
	building_now = true
	# the egg hatches in stages: wiggles, cracks, a peek, then the kin pops out
	var shell_c: Color = Color("ffd36a") if rare else Color(Data.KIN[baby["species"]]["color"]).lightened(0.15)
	if is_instance_valid(hide):
		hide.visible = false
	var eh := EggHatch.new(baby["species"], fx, 0.26, 0.36, 1.0, baby)
	eh.shell_col = shell_c
	eh.spot_col = Color("fff6c0")
	eh.position = at
	eh.scale = Vector3.ONE * 1.2
	add_child(eh)
	eh.start()
	var zoom0: float = cam.zoom_to
	cam.zoom_to = 0.5
	eh.done.connect(func():
		var land: Vector3 = eh.kin_node.global_position if is_instance_valid(eh.kin_node) else Vector3(at.x, 0, at.z) + Vector3(0.8, 0, 0.6)
		land.y = 0.0
		if is_instance_valid(eh.kin_node): eh.kin_node.queue_free()
		eh.queue_free()
		_refresh_nest()
		if hinc: hinc.refresh()
		building_now = false
		cam.zoom_to = zoom0
		_spawn_kin()
		var ke := _kin_entry(baby)
		if not ke.is_empty():
			ke["pos"] = Vector3(land.x, ke["pos"].y, land.z)
			(ke["node"] as Node3D).position = ke["pos"]
		# a closer look (its card, and turning it round), then naming
		var rv := KinReveal.new(baby["species"], baby)
		add_child(rv)
		panel_open = "reveal"; building_now = true      # hold the hunter still while you turn it round
		rv.proceed.connect(func():
			panel_open = ""; building_now = false
			_name_baby(baby)))

func _name_baby(baby: Dictionary) -> void:
	var sp: Dictionary = Data.KIN[baby["species"]]
	var v := _new_panel("It hatched!", 520)
	v.add_child(UI.label("\"%s\"" % KinSpeak.babble(baby["species"], "happy"), 24, Shiny.body(baby)))
	var rare_pre := Mutations.prefix(baby)
	if baby.get("rare", false) or not baby.has("parents"):
		v.add_child(UI.label("A rare %s%s%s, hatched from the egg %s guarded. %s nature." % ["shimmering " if baby.get("shimmer", false) else "", (rare_pre + " ") if rare_pre != "" else "", sp["name"], String(Data.MOBS.get(String(baby.get("from_boss", "")), {}).get("name", "a boss")), Care.nature(baby)], 15))
	else:
		v.add_child(UI.label("A %s%s%s, child of %s and %s. %s nature." % ["shimmering " if baby.get("shimmer", false) else "", (rare_pre + " ") if rare_pre != "" else "", sp["name"], baby["parents"][0], baby["parents"][1], Care.nature(baby)], 15))
	for mid in Mutations.of(baby):
		var mr := UI.hbox(8)
		var mtl := UI.label("%s: %s" % [Mutations.name_of(mid), Mutations.perk_text(mid)], 14, UI.INK)
		mtl.autowrap_mode = TextServer.AUTOWRAP_OFF
		mr.add_child(mtl)
		v.add_child(mr)
	if KinBox.is_boxed(baby):
		var bl := UI.label("Sent to the Boki Burrow (%s): you already have a %s out on the farm. Swap it out any time." % [KinBox.page_name(KinBox.page_of(baby)), sp["name"]] if KinBox.dup_on_farm(baby) else "Sent to the Boki Burrow (%s): the farm is full." % KinBox.page_name(KinBox.page_of(baby)), 14, Color("cdb8ff"))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(bl)
	var row := UI.hbox(8)
	var ne := LineEdit.new(); ne.text = String(baby["name"]); ne.max_length = 14; ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ne)
	v.add_child(row)
	var picks := UI.hbox(6)
	var pool: Array = Data.KIN_NAMES.duplicate(); pool.shuffle()
	for nm in pool.slice(0, 4):
		var n2: String = nm
		picks.add_child(UI.button(n2, func(): ne.text = n2))
	v.add_child(picks)
	ne.text = String(baby["name"])
	v.add_child(UI.primary("Welcome home", func():
		var was_name := String(baby["name"])
		baby["name"] = ne.text.strip_edges() if ne.text.strip_edges() != "" else String(baby["name"])
		if String(baby["name"]) != was_name: Save.log_event("renamed", baby, {"from": was_name})
		Save.save_game()
		_close_panel()
		var old := _kin_entry(baby)
		var spot: Vector3 = old["pos"] if not old.is_empty() else NEST_AT + Vector3(0.8, 0, 0.6)
		_spawn_kin()
		var ke := _kin_entry(baby)
		if not ke.is_empty():
			ke["pos"] = spot
			(ke["node"] as Node3D).position = ke["pos"]
			_say(ke, BokiLines.say(baby, "hatched")), 220))

# ---- what it wears
func _open_wear(rec: Dictionary) -> void:
	var v := _new_panel("Dress %s" % rec["name"], 520)
	var owned: Array = Save.d.get("accs", [])
	if owned.is_empty():
		v.add_child(UI.label("You don't own anything for Boki to wear yet. The market stall sells bells, bows, hats and more.", 15))
		return
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var cur: String = rec.get("acc", "")
	grid.add_child(UI.choice("Nothing", cur == "", func(): _set_acc(rec, ""), 220))
	for a in owned:
		var ak: String = a
		var worn_by := ""
		for o in Save.d["roster"]:
			if o != rec and String(o.get("acc", "")) == ak: worn_by = o["name"]
		grid.add_child(UI.choice(Data.ACCS[ak]["name"] + ("  (on %s)" % worn_by if worn_by != "" else ""), cur == ak, func(): _set_acc(rec, ak), 220))
	var dyes := HomeTrade.dye_row(rec, func(): _set_acc(rec, String(rec.get("acc", ""))))
	if dyes: v.add_child(dyes)

func _set_acc(rec: Dictionary, a: String) -> void:
	for o in Save.d["roster"]:
		if o != rec and a != "" and String(o.get("acc", "")) == a:
			o["acc"] = ""
	rec["acc"] = a
	Save.save_game()
	_close_panel()
	_spawn_kin()
	var ke := _kin_entry(rec)
	if not ke.is_empty():
		ke["pos"] = ppos + Vector3(1.0, 0, 0.4)
		(ke["node"] as Node3D).position = ke["pos"]
		ke["joy_t"] = 0.8
		_emote(ke, "★")
		if a != "": Care.change(rec, "joy", 5.0)

func _open_feed(rec: Dictionary) -> void:
	var v := _new_panel("Feed %s" % rec["name"], 560)
	var known: Array = rec["known"]
	var any := false
	var row_for := func(f: String, n: int, desc: String) -> void:
		any = true
		var row := UI.hbox(10)
		var info := UI.vbox(2); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tag := ""
		if known.has("food") and rec["likes"]["food"] == f: tag = "  ♥ loves it"
		elif known.has("hates") and rec["likes"]["hates"] == f: tag = "  ✕ won't eat it"
		info.add_child(UI.label("%s  ×%d%s" % [Care.food_name(f), n, tag], 16, Care.food_col(f)))
		info.add_child(UI.label(desc, 12, UI.MUTED))
		row.add_child(info)
		row.add_child(UI.button("Feed", func(): _care_feed(rec, f), 100))
		v.add_child(row)
	for f in Care.FOODS:
		var n := int(Save.d["items"].get(f, 0))
		if n > 0: row_for.call(f, n, Care.FOODS[f]["desc"])
	for f in Data.CROPS:
		var n := int(Save.d["crops"].get(f, 0))
		if n > 0:
			var aff := ""
			for af in Evo.AFF:
				if Evo.AFF[af]["food"] == f: aff = "Grows it %s. " % String(Evo.AFF[af]["name"]).to_lower()
			row_for.call(f, n, aff + "Fills it up.")
	if not any:
		v.add_child(UI.label("Nothing to feed it. Harvest crops, or buy kibble and buns at the market stall.", 15))

func _open_train(rec: Dictionary) -> void:
	var v := _new_panel("Train %s" % rec["name"], 560)
	v.add_child(UI.label("A short drill at the yard. Time your presses: gold is great, orange is good. Costs some energy and food; a happy Boki learns faster.", 14, UI.MUTED))
	for s in Care.STATS:
		var st: Dictionary = Care.STATS[s]
		var row := UI.hbox(10)
		var info := UI.vbox(2); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label("%s  ·  %d of %d" % [st["name"], int(rec["stats"][s]), Care.stat_cap(rec)], 16, st["col"]))
		info.add_child(UI.label("%s. %s." % [st["drill"], st["desc"]], 12, UI.MUTED))
		row.add_child(info)
		var sk: String = s
		var b := UI.button("Train", func(): _start_drill(rec, sk), 100)
		b.disabled = int(rec["stats"][s]) >= Care.stat_cap(rec)
		row.add_child(b)
		v.add_child(row)
	v.add_child(UI.label("Energy %d  ·  Full %d" % [int(Care.need(rec, "energy")), int(Care.need(rec, "food"))], 13, UI.MUTED))

# ---- kin as individuals: personal space, turns to talk, and a personality in how they move

## How this kin carries itself, from its traits and kind: pace, bounce, how social or clingy it
## is, how far it roams, how long it lingers, how chatty it is, and a little habit of its own.
func _personality(rec: Dictionary) -> Dictionary:
	var tr: Dictionary = rec.get("traits", {})
	var brave := float(tr.get("bravery", 0.5)); var hot := float(tr.get("temper", 0.5))
	var cur := float(tr.get("curiosity", 0.5)); var loyal := float(tr.get("loyalty", 0.5))
	var h := absi(String(rec.get("uid", rec.get("name", ""))).hash())
	var typ := String(Data.KIN.get(rec.get("species", ""), {}).get("type", ""))
	# [hop rate, hop height, pace]: heavy kinds plod, light ones skip
	var gait: Array = {"gravity": [5.5, 0.06, 0.82], "spore": [7.0, 0.11, 0.9], "lunar": [4.5, 0.2, 0.95],
		"prism": [11.0, 0.09, 1.12], "venom": [9.5, 0.05, 1.06], "echo": [8.0, 0.16, 1.0]}.get(typ, [9.0, 0.14, 1.0])
	var quirks := ["spin", "sniff", "hop", "sit", "look", "wiggle"]
	return {
		"speed": float(gait[2]) * lerpf(0.86, 1.18, (brave + hot) * 0.5) * (0.94 + float(h % 13) * 0.01),
		"hop_f": float(gait[0]) * (0.9 + float(h % 7) * 0.035),
		"hop_a": float(gait[1]),
		"social": lerpf(0.06, 0.4, cur * 0.6 + (1.0 - loyal) * 0.4),
		"cling": lerpf(0.08, 0.5, loyal),
		"roam": cur,
		"rest": lerpf(1.6, 0.7, hot * 0.5 + cur * 0.5),
		"chatty": lerpf(0.35, 1.3, hot * 0.5 + cur * 0.5),
		"haunt": h % 7,
		"quirk": quirks[(h / 7) % quirks.size()],
	}

## A spot in a ring around a place, different for every kin, so a crowd fans out instead of piling up.
func _seat(k: Dictionary, center: Vector3, r := 1.4) -> Vector3:
	var i := maxi(0, kins.find(k))
	var a := float(i) * 2.39996 + float(absi(String(k["rec"]["uid"]).hash()) % 100) * 0.013
	var rr := r + float(i / 6) * 0.9
	var p := center + Vector3(cos(a) * rr, 0, sin(a) * rr)
	if world.is_void(p.x, p.z) or world.occupy(p.x, p.z, 0.3, 0.0, true) != 0.0:
		return world.free_spot_near(p, kins.map(func(o): return o["pos"]), 1.0)
	return p

## The kin's favourite corner on this island, or INF if it isn't here.
func _haunt(k: Dictionary, here: int) -> Vector3:
	var picks := [spots.get("pot", Vector3.INF), POND_EDGE, spots.get("house", Vector3.INF) + Vector3(0, 0, 3.0), YARD_AT,
		NEST_AT + Vector3(1.5, 0, 1.0), spots.get("rack", Vector3.INF) + Vector3(1.2, 0, 0.8), spots.get("stall", Vector3.INF) + Vector3(0, 0, 2.0)]
	var p: Vector3 = picks[int(k.get("pers", {}).get("haunt", 0)) % picks.size()]
	if p == Vector3.INF or world.island_of(p.x, p.z) != here:
		return Vector3.INF
	return p

func _talking_near(k: Dictionary, r: float) -> bool:
	for o in kins:
		if o != k and float(o.get("say_t", 0.0)) > 0.0 and Vector2(o["pos"].x - k["pos"].x, o["pos"].z - k["pos"].z).length() < r:
			return true
	return false

func _kin_r(k: Dictionary) -> float:
	var n: Node3D = k["node"]
	return 0.42 * n.scale.x

## Personal space: kin push gently apart (and step around you) instead of stacking in one spot.
## A kin that's being petted, napping or busy holds its ground and the others make room.
func _separate_kin(d: float) -> void:
	var act: Array = kins.filter(func(o): return not o.has("indoors") and not o.has("leap") and (o["node"] as Node3D).visible and not o.get("busy", false))
	var fixed := func(o: Dictionary) -> bool: return float(o.get("hold_t", 0.0)) > 0.0 or float(o.get("nap_t", 0.0)) > 0.0 or o.has("bath")
	var p2 := Vector2(ppos.x, ppos.z)
	for i in act.size():
		var a: Dictionary = act[i]
		if fixed.call(a): continue
		var ap := Vector2(a["pos"].x, a["pos"].z)
		var push := Vector2.ZERO
		for j in act.size():
			if j == i: continue
			var b: Dictionary = act[j]
			var diff := ap - Vector2(b["pos"].x, b["pos"].z)
			var need := _kin_r(a) + _kin_r(b)
			var dl := diff.length()
			if dl < need:
				if dl < 0.001: diff = Vector2.from_angle(float(i) * 2.4); dl = 0.001
				push += diff / dl * (need - dl) * (1.0 if fixed.call(b) else 0.5)
		var dp := ap - p2
		var need_p := _kin_r(a) + 0.38
		if dp.length() < need_p and not a.has("fetch"):
			if dp.length() < 0.001: dp = Vector2.from_angle(float(i) * 2.4)
			push += dp.normalized() * (need_p - dp.length())
		if push == Vector2.ZERO: continue
		push = push.limit_length(3.5 * d + 0.02)
		var pos: Vector3 = a["pos"]
		if world.occupy(pos.x + push.x, pos.z, 0.3, 0.0, true) == 0.0 and not world.is_void(pos.x + push.x, pos.z): pos.x += push.x
		if world.occupy(pos.x, pos.z + push.y, 0.3, 0.0, true) == 0.0 and not world.is_void(pos.x, pos.z + push.y): pos.z += push.y
		a["pos"] = pos
		(a["node"] as Node3D).position = pos

## Each kin's little habit when it stops: a spin, a sniff at the ground, a happy hop, sitting down,
## looking around, or a wiggle. Rare and staggered, so it reads as character, not a dance routine.
func _quirk(k: Dictionary, n: Node3D, moving: bool, d: float) -> void:
	var body := n.get_node_or_null("Body") as Node3D
	if body == null: return
	k["qt"] = float(k.get("qt", randf_range(4.0, 12.0))) - d
	var q := float(k.get("q_on", 0.0))
	if moving or float(k.get("hold_t", 0.0)) > 0.0 or float(k.get("nap_t", 0.0)) > 0.0 or k.has("bath") or k.has("fetch"):
		# interrupted: only undo our own pose, so feeding and training animations keep theirs
		if q > 0.0:
			k["q_on"] = 0.0
			body.rotation = Vector3.ZERO; body.scale = Vector3.ONE
		k["qt"] = maxf(float(k["qt"]), 3.0)
		return
	if q <= 0.0 and float(k["qt"]) <= 0.0:
		k["qt"] = randf_range(7.0, 16.0) * float(k.get("pers", {}).get("rest", 1.0))
		k["q_on"] = 1.2
		q = 1.2
	if q <= 0.0:
		return
	q -= d
	k["q_on"] = q
	var t := 1.0 - clampf(q / 1.2, 0.0, 1.0)      # 0 -> 1 over the habit
	var e := sin(t * PI)
	match String(k.get("pers", {}).get("quirk", "look")):
		"spin": body.rotation.y = t * TAU
		"sniff": body.rotation.x = e * 0.35; body.position.y = -e * 0.04
		"hop": body.position.y = absf(sin(t * TAU * 1.5)) * 0.22
		"sit": body.scale = Vector3(1.0 + e * 0.12, 1.0 - e * 0.16, 1.0 + e * 0.12)
		"look": body.rotation.y = sin(t * TAU) * 0.7
		"wiggle": body.rotation.z = sin(t * TAU * 3.0) * 0.18 * e
	if q <= 0.0:
		body.rotation = Vector3.ZERO; body.scale = Vector3.ONE

# ------------------------------------------------------------------ build mode screenshots
## --build-demo: build mode open with a bench's ghost by the farm; --decor-demo: an island decorated
## through the layout.
func _build_demo(which: String) -> void:
	Save.no_write = true
	Save.d["gems"] = maxi(int(Save.d["gems"]), 9999); Save.d["scrap"] = 99
	var lay := HomeLayout.of(Save.d)
	if which == "--decor-demo" or which == "--build-demo":
		var add := func(id: String, x: int, z: int, r := 0, c := ""):
			var e := {"u": HomeLayout._next_uid(lay), "id": id, "x": x, "z": z, "r": r}
			if c != "": e["c"] = c
			lay["deco"].append(e)
		for x in range(50, 61): add.call("picket", x, 40)
		for z in range(41, 46):
			add.call("picket", 50, z); add.call("picket", 60, z)
		for x in range(52, 59): lay["paths"][HomeLayout.key(x, 43)] = "path_stone"
		for k in [[53, 41], [57, 41], [53, 44]]: add.call("flowers", k[0], k[1])
		add.call("fountain", 54, 41)
		add.call("bench", 56, 44, 0)
		add.call("lantern", 51, 42); add.call("lantern", 59, 42)
		add.call("banner", 51, 44, 0, "5ab0f0"); add.call("banner", 59, 44, 0, "e0607e")
		for k in [[55, 33], [56, 34], [57, 33], [54, 33], [55, 34], [56, 33]]: lay["water"][HomeLayout.key(k[0], k[1])] = 1
		add.call("blossom_tree", 52, 31); add.call("pine", 60, 31); add.call("tree", 58, 36); add.call("bush", 53, 36)
		add.call("rug", 47, 41, 0, "f2c84a"); add.call("kin_bed", 52, 38, 0, "8fd16a")
		add.call("kin_statue", 61, 36)
		for z in range(30, 36): add.call("hedge", 63, z)
		if which == "--decor-demo": lay["theme"] = "blossom"
		hb.apply(true)
	if which == "--build-demo":
		get_tree().create_timer(0.4).timeout.connect(func():
			ppos = Vector3(52.0, 0, 37.0); player.position = ppos; cam.snap(ppos)
			hb.toggle()
			hb.cat = "Furniture"
			hb.take("bench")
			hb.debug_m = Vector2(54.5, 37.6)
			hb._build_bar())
	if which == "--overview-demo" or which == "--decor-demo":
		get_tree().create_timer(0.2).timeout.connect(func():
			ppos = Vector3(46.0, 0, 37.0) if which == "--overview-demo" else Vector3(55.0, 0, 39.0)
			player.position = ppos
			cam.zoom_to = 3.3 if which == "--overview-demo" else 1.5; cam.zoom = cam.zoom_to; cam.snap(ppos))

# ------------------------------------------------------------------ test hooks for the economy
## --armory-test, --feeder-test, --grave-test, --shrine-test: set up a save and open the thing,
## for screenshots (nothing is written to the real save).
func _econ_tests(dbg) -> void:
	var any := false
	for a in dbg:
		if String(a) in ["--armory-test", "--feeder-test", "--grave-test", "--shrine-test", "--starve-test"]: any = true
	if not any:
		return
	Save.no_write = true
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	Save.d["gems"] = maxi(int(Save.d["gems"]), 900)
	Save.d["extracts"] = maxi(int(Save.d.get("extracts", 0)), 6)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	if "--armory-test" in dbg:
		if not Save.d["buildings"].has("armory"): Save.d["buildings"].append("armory")
		EqualMigrate.demo()      # an old armory, after the equal-footing migration
		var gl: Array = (Save.d["armory"] as Array).filter(func(it): return Equal.may_bring(it, 2))
		if not gl.is_empty(): Save.d["loadout"] = {"gear0": gl[0]["uid"]}
		HomeNotices.show_migration(self)
		get_tree().create_timer(0.4).timeout.connect(func():
			hecon.arm_pick = String(Save.d["armory"][0]["uid"])
			hecon.arm_tab = "Backpacks" if "--armory-backpacks" in dbg else hecon.arm_tab
			hecon.open_armory())
	if "--feeder-test" in dbg or "--starve-test" in dbg:
		# a clean roster of six, so nothing else from the machine's save (an evolution, a nap) gets in the way
		Save.d["roster"] = [Save.new_kin("zapple", "Pip")]
		Save.d["active"] = Save.d["roster"][0]["uid"]
		while Save.d["roster"].size() < 6:
			Save.d["roster"].append(Save.new_kin(Data.common_kin()[Save.d["roster"].size() % Data.common_kin().size()]))
		Save.d["items"]["kibble"] = 12
		Save.d["crops"]["tidebloom"] = 4
		Save.d["feeders"] = [{"id": "f1", "kind": "trough", "x": Econ.FEEDER_START.x, "z": Econ.FEEDER_START.z, "food": ["kibble", "kibble", "tidebloom", "kibble", "kibble", "kibble"], "auto": true}]
		Save.d["feeder_given"] = true
		for rec in Save.d["roster"]:
			Care.ensure(rec)
			rec["needs"]["food"] = 18.0 if "--feeder-test" in dbg else 0.0
			rec["needs_t"] = Time.get_unix_time_from_system()
			rec["likes"]["hates"] = "puffcorn"
		if "--starve-test" in dbg:
			# one kin a day and a half without food, another a whole day: warnings on the way in
			Save.d["roster"][0]["starve"] = 20.0 * 3600.0
			Save.d["roster"][1]["starve"] = 7.0 * 3600.0
		if "--feeder-test" in dbg:
			get_tree().create_timer(0.3).timeout.connect(func():
				ppos = Econ.FEEDER_START + Vector3(0.5, 0, 3.2); player.position = ppos; cam.snap(ppos)
				for i in kins.size():
					var k: Dictionary = kins[i]
					k.erase("indoors"); (k["node"] as Node3D).visible = true
					k["pos"] = Econ.FEEDER_START + Vector3(cos(i * 1.1) * 3.4, 0, sin(i * 1.1) * 2.6 + 0.4)
					k["pos"] = world.free_spot_near(k["pos"], [], 0.6)
					(k["node"] as Node3D).position = k["pos"]
					k["t"] = 0.0
					hecon.feed_goal(k)
				if "--feeder-open" in dbg:
					Save.d["feeder_inv"] = {"basket": 1}
					hecon.open_feeder(Econ.feeders()[0]))
			for step in [3.0, 8.0, 14.0, 22.0]:
				get_tree().create_timer(step).timeout.connect(func():
					var md := 99.0; var eating := 0; var waiting := 0
					for i in kins.size():
						if kins[i].has("eat"):
							if String(kins[i]["eat"]["phase"]) == "eat": eating += 1
							elif int(kins[i]["eat"]["seat"]) < 0: waiting += 1
						for j in range(i + 1, kins.size()):
							md = minf(md, Vector2(kins[i]["pos"].x - kins[j]["pos"].x, kins[i]["pos"].z - kins[j]["pos"].z).length())
					var fed := (Save.d["roster"] as Array).filter(func(r): return Care.need(r, "food") > 30.0).size()
					print("FEEDER t=%.0f kin=%d eating=%d waiting=%d fed=%d fill=%d min_gap=%.2f" % [step, kins.size(), eating, waiting, fed, Econ.fill(Econ.feeders()[0]), md]))
	if "--grave-test" in dbg or "--shrine-test" in dbg:
		while Save.d["roster"].size() < 3:
			Save.d["roster"].append(Save.new_kin(Data.common_kin()[Save.d["roster"].size() % Data.common_kin().size()]))
		Save.d["graves"] = []
		for i in 4:
			var rec := Save.new_kin(Data.common_kin()[(i + 2) % Data.common_kin().size()], ["Biscuit", "Wren", "Clove", "Sorrel"][i])
			rec["level"] = 3 + i * 2
			Save.remember(rec, "caught", "was scanned by you out in the islands and brought home")
			Save.remember(rec, "extracted", "made it out of the islands with you")
			Save.remember(rec, "fed", "was fed emberberry by you")
			Save.remember(rec, "love", "loved playing fetch with you")
			Save.d["roster"].append(rec)
			var g := Econ.kin_dies(rec, "starved")
			g["t"] = Time.get_unix_time_from_system() - 86400.0 * (i + 1)
			g["soul"] = i < 2 and "--shrine-test" in dbg
		if "--shrine-test" in dbg and not Save.d["buildings"].has("shrine"):
			Save.d["buildings"].append("shrine")
		Save.d["valuables"] = {"soul_ember": 2}
		get_tree().create_timer(0.3).timeout.connect(func():
			if not Array(dbg).any(func(a): return String(a).begins_with("--home-at=")):
				ppos = Vector3(49.6, 0, 37.6) if "--shrine-test" in dbg else Vector3(49.7, 0, 35.6)
				player.position = ppos; cam.snap(ppos)
			if "--shrine-open" in dbg: hecon.open_shrine()
			elif "--grave-open" in dbg: hecon.open_grave(Econ.graves()[Econ.graves().size() - 1]))
