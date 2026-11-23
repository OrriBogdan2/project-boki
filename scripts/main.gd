extends Node
## Holds whichever screen is showing: home, a match, or the results.

var current: Node = null
var fade: ScreenFade

## Real play gets ink-wipe transitions between screens. Tooling that screenshots by frame count,
## headless checks and autoplay skip them so their timing stays exact (--show-fade forces them on).
func _fades_on() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if _has_arg("--show-fade"):
		return true
	return not (_has_arg("--shot=") or _has_arg("--art-view=") or _has_arg("--rolling-shot=")
			or _has_arg("--autoplay") or _has_arg("--simtest"))

func _ready() -> void:
	if "--relay" in OS.get_cmdline_user_args():
		# dedicated relay server for desktop online play (scripts/server/relay.gd): no screens, no audio
		var relay := RelayServer.new()
		relay.name = "Relay"
		add_child(relay)
		if relay.start(OS.get_cmdline_user_args()) != OK:
			get_tree().quit(1)
		return
	Game.main = self
	fade = ScreenFade.new()
	add_child(fade)
	if _fades_on():
		fade.boot()     # carry on from the boot splash: covered, logo showing, until the first screen is up
	var args := OS.get_cmdline_user_args()
	var opts := {}
	var demo := Demo.name_in(args)      # recording presets: made-up save, overlays hidden (docs/DEMO_PRESETS.md)
	if demo != "": Demo.setup(demo)
	for a in args:
		if a.begins_with("--overlay="):
			# test: open one of the overlay menus a moment after the screen appears
			var which := a.substr(10).split(":")
			get_tree().create_timer(0.6).timeout.connect(func(): Overlay.shot_demo(which))
		if a.begins_with("--seed="): opts["seed"] = int(a.substr(7))
		if a == "--god" and AdminGate.unlocked(): opts["god"] = true
		if a.begins_with("--cam-style="): Settings.set_v("cam_style", a.substr(12), false)    # tooling: a camera style for one run (camcal)
		if a == "--autoplay": opts["autoplay"] = true
		if a == "--rolling": opts["rolling"] = true      # a rolling 30-minute session (scripts/match/rolling.gd)
		if a.begins_with("--heart-raid="): opts.merge(HeartRaid.from_arg(a.substr(13)), true)    # N[:hard], --match
		if a.begins_with("--join-wave="): opts["rolling"] = true; opts["join_wave"] = int(a.substr(12))
		if a.begins_with("--join-at="): opts["rolling"] = true; opts["join_at"] = float(a.substr(10))
		if a.begins_with("--rolling-pop="): opts["rolling_pop"] = a.substr(14)     # what the 24-40 hunters count: at_once (default) or total (Rolling.POP_MODE)
		if a.begins_with("--rolling-demo="): opts["rolling"] = true; opts["rolling_demo"] = a.substr(15); opts["plan_t"] = 0.4; opts["raid"] = "clear"    # screenshots (Rolling.demo)
		if a == "--record": Record.set_level(1)            # start in recording mode (F10 cycles it)
		if a.begins_with("--record="): Record.set_level(int(a.substr(9)))    # --record=2: with the HUD hidden
		if a.begins_with("--arena="): Record.arena_pick = a.substr(8)    # straight into the arena, this archetype picked
		if a == "--glide-demo": opts["glide_demo"] = true
		if a == "--ledge-demo": opts["ledge_demo"] = true
		if a.begins_with("--abyss-demo="): opts["abyss_demo"] = a.substr(13); opts["no_drop"] = true
		if a.begins_with("--mates-revive="): opts["mates_revive"] = float(a.substr(15))
		if a == "--mates-demo": opts["mates_demo"] = true; opts["no_drop"] = true; opts["god"] = true; opts["squad"] = 4; opts["teams"] = 2
		if a == "--life-demo": opts["life_demo"] = true; opts["no_drop"] = true; opts["squad"] = 3; opts["teams"] = 3
		if a == "--boxrev-demo": opts["life_demo"] = true; opts["boxrev_demo"] = true; opts["no_drop"] = true; opts["squad"] = 3; opts["teams"] = 3
		if a.begins_with("--length="): opts["length"] = float(a.substr(9))
		if a == "--no-drop": opts["no_drop"] = true
		if a.begins_with("--map="): opts["map"] = a.substr(6)            # an expedition on another authored map (e.g. skyreach)
		if a.begins_with("--at="): opts["at_xz"] = a.substr(5)          # tooling: start standing at x,z (map screenshots)
		if a.begins_with("--zoom="): opts["zoom_hold"] = float(a.substr(7))   # tooling: hold the camera zoom
		if a.begins_with("--lost-demo"): opts["lost_demo"] = a.substr(12) if a.length() > 12 else "rival"; opts["no_drop"] = true    # a Boki left behind (hud labels)
		if a == "--train-demo": opts["train_demo"] = true; opts["no_drop"] = true
		if a.begins_with("--train-demo="): opts["train_demo"] = a.substr(13); opts["no_drop"] = true
		if a.begins_with("--aim-demo="): opts["aim_demo"] = a.substr(11); opts["no_drop"] = true
		if a.begins_with("--balloon-demo="): opts["balloon_demo"] = a.substr(15); opts["no_drop"] = true; opts["god"] = true; opts["squad"] = 2; opts["teams"] = 2
		if a == "--loot-demo": opts["loot_demo"] = true
		if a == "--pack-demo": opts["pack_demo"] = true; opts["no_drop"] = true
		if a == "--gear-demo": opts["gear_demo"] = true; opts["no_drop"] = true
		if a == "--bag-demo": opts["bag_demo"] = true; opts["no_drop"] = true
		if a == "--stomp-demo": opts["stomp_demo"] = true
		if a == "--ring-demo": opts["ring_demo"] = true; opts["no_drop"] = true
		if a == "--wall-demo": opts["wall_demo"] = true; opts["no_drop"] = true
		if a == "--cone-demo": opts["cone_demo"] = true
		if a == "--rival-demo": opts["rival_demo"] = true; opts["no_drop"] = true
		if a == "--crouch-demo": opts["cone_demo"] = true; opts["crouch_demo"] = true
		if a == "--wall-behind": opts["wall_behind"] = true; opts["no_drop"] = true
		if a == "--meteor-test": opts["meteor_test"] = true; opts["no_drop"] = true
		if a == "--break-demo": opts["break_demo"] = true; opts["no_drop"] = true
		if a == "--chest-demo": opts["chest_demo"] = true; opts["no_drop"] = true     # a chest next to breakables (screenshots)
		if a == "--watch-heart": opts["watch_heart"] = true
		if a.begins_with("--class="): Save.d["cls"] = a.substr(8); Save.d["weapon"] = ""
		if a.begins_with("--weapon="):
			Save.d["weapon"] = a.substr(9)
			for ak0 in Arch.archetypes_of(a.substr(9)):
				Save.d["cls"] = Arch.weight(String(ak0)); Save.d["arch"] = ak0      # (a weapon is some archetype's signature)
		if a == "--ability-demo": opts["ability_demo"] = true
		if a.begins_with("--arch-demo="):
			# screenshots: an archetype mid-ability (scripts/arch/arch_demo.gd)
			var ad := a.substr(12).split(":")
			opts["arch_demo"] = a.substr(12); opts["no_drop"] = true; opts["training"] = true; opts["unlocked"] = true
			opts["arch"] = ad[0]; opts["cls"] = Arch.weight(ad[0]); opts["weapon"] = Arch.signature(ad[0])
			if ad.size() > 2: opts["weapon"] = ad[2]
		if a.begins_with("--boki-demo="):
			# screenshots: the Boki commands and the Merge (scripts/match/boki_demo.gd), --boki-demo=throw|recall|downed|merge[:species]
			var bd := a.substr(12).split(":")
			opts["boki_demo"] = a.substr(12); opts["arch_demo"] = "gunslinger:rmb"; opts["no_drop"] = true; opts["training"] = true; opts["unlocked"] = true
			opts["arch"] = "gunslinger"; opts["cls"] = Arch.weight("gunslinger"); opts["weapon"] = Arch.signature("gunslinger")
			if bd.size() > 1: opts["demo_kin"] = bd[1]
		if a == "--normalize-size": Unique.normalize = true      # kin size changes no stats or hitboxes (Unique)
		if a == "--fresh": Save.d = Save.fresh()
		if a in ["--work-demo", "--work-board", "--work-board=Kin", "--work-card", "--work-box", "--work-hover", "--work-close", "--work-build", "--shiny-lineup"]:
			Save.no_write = true; Save.d = HomeWork.demo_save()     # a made-up farm at work (screenshots)
		if a.begins_with("--farm-demo"):
			# screenshots: a new farm-start island (--farm-demo=empty|ghost|chop|station|panel, --farm-seed=N)
			var fseed := 7
			for a2 in args:
				if String(a2).begins_with("--farm-seed="): fseed = int(String(a2).substr(12))
			Save.no_write = true
			Save.d = HomeGather.demo_save(a.substr(12) if a.length() > 12 else "empty", fseed)
		if a == "--base-demo":      # a made-up base to show (GARDEN.md 9.8), never the real save
			Save.no_write = true
			Save.d = BaseDemo.save()
		if a.begins_with("--test-kin="):
			# test: a save with one kin "species:level:trust", ready to play at home
			var tk := a.substr(11).split(":")
			if Save.d["roster"].is_empty():
				var nk := Save.new_kin(tk[0], "Pip")
				nk["level"] = int(tk[1]) if tk.size() > 1 else 1
				nk["trust"] = float(tk[2]) if tk.size() > 2 else 50.0
				Save.d["roster"].append(nk); Save.d["active"] = nk["uid"]
			Save.d["tutorial"]["home"] = true
			Save.d["tutorial"]["day1_done"] = true
		if a == "--skip-tutorial": Save.d["tutorial"]["home"] = true
		if a.begins_with("--teams="): opts["teams"] = int(a.substr(8))
		if a.begins_with("--tier="): opts["tier"] = int(a.substr(7))
		if a.begins_with("--squad="): opts["squad"] = int(a.substr(8))
		if a.begins_with("--bot-diff="): opts["bot_diff"] = a.substr(11)
		if a == "--perk-demo": opts["perk_demo"] = true
		if a.begins_with("--exit-demo="): opts["exit_demo"] = a.substr(12); opts["no_drop"] = true
		if a == "--heart-demo" or a.begins_with("--heart-demo="):
			opts["heart_demo"] = a.substr(13) if a.length() > 13 else "ready"
			opts["no_drop"] = true
			opts["heart"] = true
		if a == "--truce-demo": opts["truce_demo"] = true; opts["no_drop"] = true
		if a.begins_with("--teammate-demo="): opts["teammate_demo"] = a.substr(16); opts["no_drop"] = true
		if a.begins_with("--demo-kin="): opts["demo_kin"] = a.substr(11)      # test: bring this species (level/trust via --demo-kin-lv=)
		if a.begins_with("--demo-kin-lv="): opts["demo_kin_lv"] = a.substr(14)
		if a == "--no-tips": Settings.set_v("tips", false, false)     # test: no kit panel or tip banners (screenshots)
		if a.begins_with("--set-kin=") and not Save.d["roster"].is_empty():
			# test: your first Boki's level and trust, "level:trust" (how well it talks)
			var sk := a.substr(10).split(":")
			Save.d["roster"][0]["level"] = int(sk[0])
			if sk.size() > 1: Save.d["roster"][0]["trust"] = float(sk[1])
		if a == "--recall-demo" and not Save.d["roster"].is_empty():
			# test: your partner just got back from an expedition with something to tell you
			Save.d["roster"][0]["recall"] = {"kind": "carried_out", "text": "was carried out of the Ember Quarry by you", "place": "the Ember Quarry", "boss": "", "m": 1}
		if a.begins_with("--lair-demo="): opts["lair_demo"] = a.substr(12); opts["no_drop"] = true
		if a.begins_with("--lair-boss="): opts["demo_boss"] = a.substr(12)
		if a.begins_with("--hudref-demo="): opts.merge(HudRefDemo.opts(a), true)
		if a == "--plate-demo": opts["plate_demo"] = true; opts["no_drop"] = true; opts["teams"] = 3; opts["squad"] = 3
		if a == "--hold-demo": opts["hold_demo"] = true; opts["no_drop"] = true; opts["teams"] = 4; opts["squad"] = 3
		if a == "--no-plan": opts["no_plan"] = true
		if a.begins_with("--see-demo"): opts["see_demo"] = a.substr(11) if a.begins_with("--see-demo=") else "bloom"; opts["no_drop"] = true     # your hunter just behind a big tree
		if a.begins_with("--plan-t="): opts["plan_t"] = float(a.substr(9))
		if a == "--map-demo": opts["map_demo"] = "plan"          # the planning map, with pings
		if a == "--map-mid-demo": opts["map_demo"] = "mid"; opts["no_drop"] = true    # the map mid-match, some spawns scouted
		if a == "--drop-demo": opts["drop_demo"] = "lead"; opts["plan_t"] = 0.6        # the squad gliding in formation behind you
		if a == "--drop-follow-demo": opts["drop_demo"] = "follow"; opts["plan_t"] = 0.6   # ... behind a squadmate
		if a.begins_with("--raid-demo="): opts["raid"] = a.substr(12); opts["raid_demo"] = true; opts["no_drop"] = true    # a raid condition's look (RaidLook)
		if a == "--blight-demo": opts["blight_demo"] = "all"; opts["no_drop"] = true      # a Warden's light and a Skitter pack (BlightDir.demo)
		if a.begins_with("--blight-demo="): opts["blight_demo"] = a.substr(14); opts["no_drop"] = true
	if "--grammar-vocab" in args:
		print(KinGrammar.vocab_markdown())
		get_tree().quit()
		return
	if "--meshtime" in args:
		# test: how long the big map takes to build its meshes, and how many draws it makes
		var w := World.new()
		add_child(w)
		w.generate(5, World.BIG_SIZE, World.BIG_ISLANDS)
		var t0 := Time.get_ticks_msec()
		w.build_meshes()
		var t1 := Time.get_ticks_msec()
		var n := 0; var mm := 0; var inst := 0
		var stack: Array = [w]
		while not stack.is_empty():
			var c: Node = stack.pop_back()
			if c is MeshInstance3D: n += 1 + (1 if (c as MeshInstance3D).material_override and (c as MeshInstance3D).material_override.next_pass else 0)
			if c is MultiMeshInstance3D: mm += 1; inst += (c as MultiMeshInstance3D).multimesh.instance_count
			for ch in c.get_children(): stack.append(ch)
		print("MESHTIME ms=%d mesh_draws=%d multimeshes=%d instances=%d" % [t1 - t0, n, mm, inst])
		get_tree().quit()
		return
	if "--gentime" in args:
		for sz in [[64, 7], [128, 16], [World.BIG_SIZE, World.BIG_ISLANDS]]:
			var t0 := Time.get_ticks_msec()
			var w := World.new()
			w.generate(int(OS.get_environment("GSEED")) if OS.get_environment("GSEED") != "" else 5, sz[0], sz[1])
			var t1 := Time.get_ticks_msec()
			print("GEN ", sz, " ms=", t1 - t0, " islands=", w.islands.size(), " pads=", w.pads.size(), " portals=", w.portal_spots.size(), " spawns=", w.spawns.size())
			w.free()
		get_tree().quit()
		return
	for a in args:
		if a.begins_with("--biome-shot="):
			# tooling: stand next to a region's point of interest, for screenshots of its look
			var want := a.substr(13)
			var sm := Match.new()
			add_child(sm)
			current = sm
			sm.start({"teams": 2, "squad": 1, "tier": 1, "seed": 9, "no_drop": true, "length": 1e9})
			for ii in sm.world.islands.size():
				if String(sm.world.islands[ii].get("id", "")) == want:
					var poi: Vector3 = sm.world._poi(ii)
					var at := sm.world.free_spot_near(poi + Vector3(3.0, 0, 4.5), [], 1.0, 0.5)
					sm.player.teleport(Vector3(at.x, sm.world.ground_at(at.x, at.z), at.z))
					sm.cam.snap(sm.player.pos)
			for o in sm.hunters:
				if o != sm.player:
					o.teleport(sm.world.spawns[-1]); o.ctrl = "idle"
			return
	if "--arch-lineup" in args or "--showcase" in args or "--arch-matrix" in args or "--arch-heads" in args:
		add_child(load("res://tests/arch_gallery.gd").new())
		return
	if "--hair-gallery" in args or "--class-lineup" in args:
		add_child(load("res://tests/hair_gallery.gd").new())
		return
	if "--art-stats" in args:
		load("res://tests/art_stats.gd").stats()
		get_tree().quit()
		return
	if "--pack-gallery" in args:
		add_child(load("res://tests/pack_gallery.gd").new())
		return
	if "--prop-gallery" in args:
		add_child(load("res://tests/prop_gallery.gd").new())
		return
	if "--mob-gallery" in args:
		add_child(load("res://tests/mob_gallery.gd").new())
		return
	if "--flora-gallery" in args:
		add_child(load("res://tests/flora_gallery.gd").new())
		return
	if Array(args).any(func(a): return String(a).begins_with("--art-view=")):
		add_child(load("res://tests/art_view.gd").new())
		return
	if "--map-overview" in args:
		add_child(load("res://tests/map_overview.gd").new())
		return
	if "--mapcheck-authored" in args:
		load("res://tools/mapcheck.gd").new().run_authored(World.layout_for_tier(0), range(1, 21))
		get_tree().quit()
		return
	if "--mapcheck" in args:
		var MC = load("res://tools/mapcheck.gd")
		if not "--big" in args: MC.new().run(range(1, 201))
		MC.new().run(range(1, 41), World.BIG_SIZE, World.BIG_ISLANDS)
		get_tree().quit()
		return
	if "--speak-test" in args:
		load("res://tools/speaktest.gd").new().run()
		get_tree().quit()
		return
	if CheckRegistry.run(self, args):      # registered checks (tools/check_registry.gd)
		return
	if "--glide-reach" in args:
		load("res://tools/glide_reach.gd").new().run(self)    # how far a glide carries over open void (sizes map gaps)
		return
	if "--simtest" in args:
		_simtest(opts)
		return
	if "--boss-ttk" in args:
		_boss_ttk()
		return
	for a in args:
		if a.begins_with("--map-bake="):
			# tooling: bake the painted map of an authored layout (no world meshes) and save it as a PNG
			var bw := World.new()
			var tier_i := 0
			for a2 in args:
				if a2.begins_with("--tier="): tier_i = int(a2.substr(7))
			bw.biome = Data.TIERS[tier_i]["biome"].duplicate()
			bw.clouds = Data.TIERS[tier_i]["clouds"]
			bw.generate_authored(World.load_layout(World.layout_for_tier(tier_i)), 9)
			bw._assign_regions()
			var outp := a.substr(11)
			var t0 := Time.get_ticks_msec()
			MapPaint.request(self, bw, func(t: Texture2D):
				t.get_image().save_png(outp)
				print("MAPBAKE %s in %d ms" % [outp, Time.get_ticks_msec() - t0])
				get_tree().quit())
			return
	if _has_arg("--loop-tour"):
		# demo QA: the core loop end to end through the real screens, a screenshot per step (tools/loop_tour.gd)
		var lt: GDScript = load("res://tools/loop_tour.gd")
		if lt == null or not lt.can_instantiate():
			print("TOUR DONE the tour script failed to load")
			get_tree().quit(1)
			return
		add_child(lt.new())
		return
	if OS.has_feature("web"):
		_expose_test_hooks()
		var hash := str(JavaScriptBridge.eval("location.hash", true))
		_soc_test = hash.contains("soctest")
		if _soc_test:
			# test-only: a ready-made player so the shared features can be driven from a script
			Save.d["tutorial"]["home"] = true
			if Save.d["roster"].is_empty():
				var k := Save.new_kin("zapple")
				Save.d["roster"].append(k)
				Save.d["active"] = k["uid"]
			show_screen("home", {})
			return
		if hash.contains("online"):
			Save.d["tutorial"]["home"] = true
			show_screen("lobby", {})
			return
	# a test scene (tests/combat_sandbox.tscn) can ask for a screen directly
	if has_meta("start"):
		var st: Dictionary = get_meta("start")
		show_screen(String(st["screen"]), st.get("opts", {}))
		return
	if "--sandbox" in args:
		var so := {"training": true, "sandbox": true, "sandbox_demo": "--sandbox-demo" in args, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "weapon": "rifle"}
		for a in args:
			if a.begins_with("--weapon="): so["weapon"] = a.substr(9)
			if a.begins_with("--aim-demo="): so["aim_demo"] = a.substr(11); so["sandbox_demo"] = false
			if a.begins_with("--glove="): so["glove"] = a.substr(8)
			if a.begins_with("--class="): so["cls"] = a.substr(8)
			if a.begins_with("--carry-demo="):
				# test: bring this species and just walk with it (mount, perch or shoulder); --merge-demo merges
				so["demo_kin"] = a.substr(13)
				so["sandbox_demo"] = false
				so["carry_demo"] = true
			if a == "--merge-demo": so["merge_demo"] = true
			if a == "--rival-demo": so["rival_demo"] = true
			if a.begins_with("--rival-kin="): so["rival_kin"] = a.substr(12)
			if a == "--glide-demo": so["glide_demo"] = true
			if a == "--dashglide-demo": so["dashglide_demo"] = true
			if a == "--dashpip-demo": so["dashpip_demo"] = true     # test: spend every dash, then watch the strip refill
			if a.begins_with("--kin-demo="):
				# test: bring this species (and the next one) and run its whole kit on the dummies
				so["demo_kin"] = a.substr(11)
				so["sandbox_demo"] = false
				so["kin_demo"] = true
		show_screen("match", so)
		return
	if "--results-test" in args:
		show_screen("results", {"extracted": true, "gems": 42, "seeds": {"sunroot": 1}, "caught": [Save.new_kin("zapple")], "knocks": 3, "damage": 512, "taken": 388, "kills": 1, "downs": 1, "deaths": 0, "revives": 2, "armor_tier": 3, "time": 201.0, "kin_events": [{"kind": "refused", "text": "refused to jump into a fight that looked too dangerous", "trust": -1.0}], "kin_trust": 57.0, "tonics": 1})
		return
	for a in args:
		if a.begins_with("--reveal-test"):
			# test: the hatch reveal on its own (--reveal-test=<species>)
			var spr := a.substr(14) if a.length() > 14 else "cindle"
			var holder := Node3D.new(); add_child(holder); current = holder
			var rv := KinReveal.new(spr, Save.new_kin(spr, "", 4242))     # a new Boki, as a real hatch passes
			holder.add_child(rv)
			rv.proceed.connect(func(): print("REVEAL proceed"))
			return
	if "--lobby-test" in args:
		show_screen("lobby", {})
		return
	var town_arg := ""
	for a in args:
		if a.begins_with("--town="): town_arg = a.substr(7)
	if "--crowd-test" in args and Save.d["roster"].size() < 6:
		# test: a crowd of kin, to check they keep apart and take turns talking
		for sp in ["zapple", "cindle", "puddlet", "zapple", "cindle", "puddlet"]:
			var ck := Save.new_kin(sp)
			ck["trust"] = 75.0
			Save.d["roster"].append(ck)
		Save.d["active"] = Save.d["roster"][0]["uid"]
		Save.d["tutorial"]["home"] = true
	if "--whistle-test" in args and Save.d["roster"].size() < 3:
		# test: a few kin, so some can be indoors when you whistle
		for sp in ["zapple", "cindle", "puddlet"]:
			var wk := Save.new_kin(sp)
			wk["trust"] = 70.0
			Save.d["roster"].append(wk)
		Save.d["active"] = Save.d["roster"][0]["uid"]
		Save.d["tutorial"]["home"] = true
	if "--test-roster" in args and Save.d["roster"].is_empty():
		# test: a ready-made kin so home and the house rooms have someone to pet
		var tk := Save.new_kin("zapple", "Pip")
		Save.d["roster"].append(tk)
		Save.d["active"] = tk["uid"]
		Save.d["tutorial"]["home"] = true
	var room_arg := ""
	for a in args:
		if a.begins_with("--interior="): room_arg = a.substr(11)
	if room_arg != "":
		show_screen("interior", {"room": room_arg})
		if "--interior-pet" in args:
			# test: pet a kin indoors and show that it counted
			get_tree().create_timer(0.5).timeout.connect(func():
				current._pet_kin(current.kins[0])
				print("PET gems=", Save.d["gems"]))
		if "--decorate" in args:
			get_tree().create_timer(0.5).timeout.connect(func():
				current.dec.toggle()
				current.dec.take("plant"))
	elif demo != "":
		Demo.open(self, demo, args)
	elif town_arg != "":
		show_screen("town", {"mode": town_arg, "gid": "test"})
	elif "--visit-test" in args:
		show_screen("home", {"visit": Social.clean_island(Social.profile_doc()), "visit_id": "test"})    # test: visiting an island
	elif "--prologue" in args:
		show_screen("prologue", {"then": "title"})    # test: the opening story
	elif "--creator" in args:
		show_screen("hatch", {"create": true})    # test: the hunter creator
	elif "--demo-match" in args:
		# the title screen's Demo match (tooling: screenshots of it); other match flags still apply
		var dm := Match.demo_opts()
		dm.merge(opts, true)
		show_screen("match", dm)
	elif "--match" in args or opts.has("raid_demo") or opts.has("blight_demo") or opts.has("heart_demo") \
			or opts.get("rolling", false):
		show_screen("match", opts)
	elif "--duel" in args:
		show_screen("match", Match.duel_opts())
	elif Record.arena_pick != "":
		_open_arena(Record.arena_pick)
	elif "--arena" in args:
		_open_arena("")
	elif "--training" in args:
		show_screen("match", {"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": "--no-drop" in args, "perk_demo": "--perk-demo" in args})
	elif "--duo-tutorial" in args:
		show_screen("match", DuoTutorial.opts("", "--duo-test" in args))
	elif "--tutorial" in args or "--tut-test" in args:
		show_screen("match", {"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "tut_test": "--tut-test" in args})
	elif args.is_empty() or "--title" in args:
		show_screen("title", {})
	elif Save.d["roster"].is_empty():
		show_screen("hatch", {})
	else:
		show_screen("home", {})

## --arena=<archetype> (with --record for filming): straight into the arena with that archetype
## picked. The arena provides `static func arena_opts(pick: String) -> Dictionary` on Match; until it
## does, this opens the Training Grounds instead and says so.
func _open_arena(pick: String) -> void:
	Save.d["tutorial"]["home"] = true
	var ms: Script = load("res://scripts/match/match.gd")
	if ms.get_script_method_list().any(func(md): return String(md["name"]) == "arena_opts"):
		show_screen("match", ms.call("arena_opts", pick))
		return
	push_warning("--arena=%s: no arena in this build (Match.arena_opts); opening the Training Grounds" % pick)
	show_screen("match", {"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})

## Menu screens sit on their own layer so they fill the window.
func _layer(scr: Control) -> CanvasLayer:
	var cl := CanvasLayer.new()
	add_child(cl)
	cl.add_child(scr)
	cl.set_meta("screen", scr)
	return cl

func screen_node() -> Node:
	if current is CanvasLayer and current.has_meta("screen"):
		return current.get_meta("screen")
	return current

func _has_arg(prefix: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix): return true
	return false

var _gen := 0

var _ld: Node = null       # the loading screen of a match still on its way
const HOME_SCRIPT := "res://scripts/home/home.gd"

func show_screen(screen: String, opts: Dictionary) -> void:
	_gen += 1
	var gen := _gen
	# a match left while it was still loading: its loading screen goes, and 3D draws again
	get_viewport().disable_3d = false
	if is_instance_valid(_ld) and not _ld.is_queued_for_deletion() and not _ld.get("leaving"):
		_ld.queue_free()
	_ld = null
	var fx := _fades_on()
	if fx and current:
		await fade.cover()
		if gen != _gen:
			return
	if screen == "match": MeshCache.sweep()     # one-off meshes the last two matches never asked for go
	if current:
		current.queue_free()
		current = null
	await get_tree().process_frame
	if gen != _gen:
		return    # another screen was asked for while this one was still on its way
	if fx:
		# the next screen builds this frame (often a heavy one); reveal once it has actually drawn
		fade.reveal_after(3, 0.55, func() -> bool: return gen == _gen and is_instance_valid(current) and current.get("building") == true)
	match screen:
		"match":
			# Settings > Demo (clear weather, no Blight, ...) on offline matches; online ones play the host's rules
			if not opts.has("net"): Settings.demo_opts(opts)
			# the seed is fixed here, so the loading screen can show the raid condition it rolls
			if not opts.has("seed"): opts["seed"] = randi()
			# a loading screen covers building the world; tests that screenshot by frame count skip it
			var ld = null
			if (not opts.get("autoplay", false) or opts.get("probe", false)) and (not _has_arg("--shot=") or _has_arg("--show-loading")):
				var tier_i := clampi(int(opts.get("tier", 0)), 0, Data.TIERS.size() - 1)
				Sfx.prefetch(["music_" + MusicDir.opening(tier_i), "amb_match"])
				Match.prefetch([Match.HUD_SCRIPT])
				WardenGlb.fetch_all()
				ld = load("res://scripts/ui/loading.gd").new()
				opts["squad_intro"] = true      # a real start: the squad on the skyship deck first (SquadIntro)
				ld.setup(opts)
				add_child(ld)
				_ld = ld
				# nothing in 3D shows behind the loading screen while the match builds: drawing the
				# half-built world every frame only slows the build (see Match.warm_up for the drawing)
				get_viewport().disable_3d = true
				await ld.shown
				ld.advance(0.04)
				if gen != _gen:
					get_viewport().disable_3d = false
					ld.queue_free()
					return
			var m := Match.new()
			m.name = "Match"
			add_child(m)
			current = m
			if ld:
				# build in short slices so the loading screen keeps moving, then draw everything once
				# behind it, a batch a frame, so no shader compiles mid-drop (see Match.warm_up)
				await m.start_staged(opts, func(f: float, stage: String):
					ld.advance(0.04 + 0.66 * f)
					ld.set_stage(stage))
				get_viewport().disable_3d = false
				if not is_instance_valid(m) or not m.is_inside_tree():
					ld.queue_free()
					return
				if not opts.has("net"): m.set_process(false)
				ld.set_stage("graphics")
				await m.warm_up(func(f: float): ld.advance(0.7 + 0.28 * f))
				ld.set_stage("ready")
				# hold the match still while the bar finishes, except online where everyone runs together
				await ld.finish()
				if is_instance_valid(m) and m.is_inside_tree(): m.set_process(true)
			else:
				m.start(opts)
		"results":
			var R = load("res://scripts/ui/results.gd")
			var scr = R.new()
			current = _layer(scr)
			scr.show_result(opts)
			Match.prefetch([HOME_SCRIPT])     # where you're most likely going next
		"lobby":
			var L = load("res://scripts/ui/lobby.gd")
			var scr = L.new()
			scr.setup(opts)
			current = _layer(scr)
		"party":
			var Pt = PartyView.new()
			Pt.setup(opts)
			current = _layer(Pt)
		"prematch":
			var Pv = load("res://scripts/ui/prematch_view.gd")
			var pscr = Pv.new()
			pscr.setup(opts)
			current = _layer(pscr)
		"title":
			var Tt = load("res://scripts/ui/title.gd")
			current = Tt.new()
			add_child(current)
			Match.prefetch([HOME_SCRIPT])     # compiled on a worker thread while the title shows
		"prologue":
			var Pr = load("res://scripts/ui/prologue.gd")
			current = Pr.new()
			current.set("then_go", String(opts.get("then", "hatch")))
			add_child(current)
		"hatch":
			var Hx = load("res://scripts/ui/hatch.gd")
			current = Hx.new()
			current.set("edit_only", bool(opts.get("create", false)))
			add_child(current)
		"home":
			var H = Match.take_prefetched(HOME_SCRIPT)
			current = H.new()
			current.set("visit", opts.get("visit", {}))
			current.set("visit_id", String(opts.get("visit_id", "")))
			current.set("spawn", String(opts.get("spawn", "")))
			current.set("zone", GardenZones.landing(opts))
			current.set("play_hub", bool(opts.get("play_hub", false)))
			add_child(current)
		"interior":
			var In = load("res://scripts/home/interior.gd")
			current = In.new()
			current.set("room", String(opts.get("room", "house")))
			current.set("visit", opts.get("visit", {}))
			current.set("visit_id", String(opts.get("visit_id", "")))
			add_child(current)
		"town":
			var Tw = load("res://scripts/social/town.gd")
			current = Tw.new()
			current.set("mode", String(opts.get("mode", "hub")))
			current.set("gid", String(opts.get("gid", "")))
			add_child(current)

# ------------------------------------------------------------------ kin grammar runtime check
## Balance probe for the 90 s seal: a squad of three bots (skill 0.6) walks into each boss's lair and
## fights it for real; prints how long the kill takes (or that the seal would have failed).
func _boss_ttk() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var tiers := [0]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ttk-tier="): tiers = [int(a.substr(11))]
	for tier in tiers:
		for boss in ["colossus", "serpent", "brood"]:
			for sd in [11, 12, 13]:
				var m := Match.new()
				add_child(m)
				m.start({"teams": 2, "squad": 3, "tier": tier, "length": 1e9, "seed": sd, "no_drop": true, "autoplay": true})
				m.set_process(false)
				var L: Dictionary = {}
				for x in m.lairs.list:
					if String(x["boss"]) == boss: L = x
				if L.is_empty():
					m.queue_free(); continue
				m.lairs.activate(L)
				for g in L["guards"]: if is_instance_valid(g): g.dead = true; g.visible = false
				m.lairs.open(L, null, "dial")
				var P: Hunter = m.player
				var squad: Array = m.hunters.filter(func(x): return x.team == P.team)
				for h in m.hunters:
					if h.team != P.team:
						h.ctrl = "idle"
						h.teleport(m.world.spawns[0] if not m.world.spawns.is_empty() else h.pos)
				var outv := Vector3(L["out"].x, 0, L["out"].y)
				var side := Vector3(-L["out"].y, 0, L["out"].x)
				for i in squad.size():
					var h: Hunter = squad[i]
					h.ai["skill"] = 0.6
					var at: Vector3 = L["c"] + outv * (float(L["half"]) - 2.0) + side * (i - 1) * 1.5
					h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
				var b: Boss = L["boss_mob"]
				var t0 := m.time
				var downs := 0
				var was := {}
				while m.time - t0 < 100.0 and not b.dead:
					m.step(Match.DT)
					for h in squad:
						if h.downed and not was.get(h.nid, false): downs += 1
						was[h.nid] = h.downed
				var woke := float(L.get("lock_at", t0))
				print("TTK tier %d %-9s seed %d: %s at %.1fs after the seal (hp %d/%d left, %d downs, state %s)" % [tier, boss, sd, "KILLED" if b.dead else "ALIVE", m.time - woke, int(b.hp), int(b.max_hp), downs, L["state"]])
				m.queue_free()
				await get_tree().process_frame
	get_tree().quit()

func _simtest(opts: Dictionary) -> void:
	opts["autoplay"] = true
	var m := Match.new()
	add_child(m)
	m.start(opts)
	m.set_process(false)
	var t0 := Time.get_ticks_msec()
	var log_t := 0.0
	var kill_at := -1.0
	var until := 1e9
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kill-at="): kill_at = float(a.substr(10))
		if a.begins_with("--sim-until="): until = float(a.substr(12))
	print("SIMTEST seed ", m.seed_val, " raid ", m.raid, " blight ", m.blight != null)
	while not m.over and m.time < m.length + 5.0 and m.time < until:
		m.step(Match.DT)
		if kill_at > 0.0 and m.time >= kill_at and m.player and not m.player.out:
			# test: the player goes down for good here, to check what happens to the kin they brought
			var near: Hunter = null
			for o in m.hunters:
				if o != m.player and not o.out and (near == null or o.flat_dist(m.player) < near.flat_dist(m.player)): near = o
			m.player.lives = 1
			m.eliminate(m.player, near, "knocked out", true)
			kill_at = -1.0
		if m.result.get("ending", false) and m.time > 0.0:
			m._finish_now = true
		log_t += Match.DT
		if log_t >= 30.0:
			log_t = 0.0
			var alive := m.hunters.filter(func(x): return not x.out and not x.extracted).size()
			var down := m.hunters.filter(func(x): return x.downed).size()
			var P: Hunter = m.player
			print("  island=", m.world.island_of(P.pos.x, P.pos.z), " pads=", m.world.pads.map(func(pd): return "%d>%d@(%d,%d)" % [pd["from"], pd["to"], pd["pos"].x, pd["pos"].z]))
			var TG = P.ai.get("tgt")
			if TG: print("  DBG tgt=%s pos=%s hp=%s dead=%s drop=%s vel=%s grap=%s ride=%s cross=%s blockhere=%s ground=%s" % [TG.get_class() + ":" + str(TG.get_script().resource_path.get_file()), TG.pos.snapped(Vector3(0.1,0.1,0.1)), TG.hp, TG.dead, P.dropping, P.vel.snapped(Vector3(0.1,0.1,0.1)), P.grap.size(), P.riding, P.ai.has("cross"), m.world.is_block(P.pos.x, P.pos.z), m.world.ground_at(P.pos.x, P.pos.z)])
			print("  player pos=%s goal=%s kind=%s tgt=%s move=%s grounded=%s" % [P.pos.snapped(Vector3(0.1,0.1,0.1)), str(P.ai.get("goal")), P.ai.get("goal_kind"), str(P.ai.get("tgt")), str(P.inp["move"]), P.grounded])
			if "--stuck-debug" in OS.get_cmdline_user_args():
				var W: World = m.world
				var tiles := []
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var ti := W.idx(int(P.pos.x) + dx, int(P.pos.z) + dz)
						tiles.append("%d/%d%s" % [W.kind[ti], W.level[ti], "w" if W.walls.has(ti) else ""])
				print("  STUCK? vel=%s pad=%s grap=%d stun=%.1f root=%.1f base=%.1f drop=%s ride=%s glide=%s roll=%.2f cross=%s tiles=%s hist=%s" % [P.vel.snapped(Vector3(0.1,0.1,0.1)), str(P.pad.keys()), P.grap.size(), P.stun_t, P.root_t, P.base_t, P.dropping, P.riding, P.gliding, P.roll_t, str(P.ai.get("cross", {}).get("take", "")), str(tiles), str(P.get_meta("hist", []).slice(-3))])
			print("t=%d alive=%d down=%d mobs=%d shots=%d pickups=%d feed=%s" % [m.time, alive, down, m.mobs.filter(func(x): return not x.dead).size(), m.shots.size(), m.pickups.size(), str(m.feed.map(func(f): return f["text"]))])
		if m.result.get("ending", false):
			break
	for line in m.feed_all:
		print("   | ", line)
	# per-weapon totals, to spot a weapon that never lands or lands far too much
	var wsum := {}
	for h in m.hunters:
		var e: Array = wsum.get(h.wid, [0, 0.0, 0])
		e[0] += 1; e[1] += h.dmg_done; e[2] += h.knocks
		wsum[h.wid] = e
	for k in wsum:
		print("WPN %s n=%d dmg=%d knocks=%d" % [k, wsum[k][0], int(wsum[k][1]), wsum[k][2]])
	if m.player:
		var isl := m.world.island_of(m.player.pos.x, m.player.pos.z)
		print("player island ", isl, " pads out: ", m.world.pads.filter(func(pd): return pd["from"] == isl).map(func(pd): return [pd["pos"], pd["to"], pd["land"]]))
	var nb := 0
	for b in m.breaks: nb += int(b["dead"])
	var wr: Array = []
	for h in m.hunters: wr.append(h.gear.filter(func(g): return not g.is_empty()).size())
	print("SIMSTAT breaks %d/%d pickups left %d gear worn %s staggers %d rings %d pads %d" % [nb, m.breaks.size(), m.wpicks.size(), str(wr), m.stag_n, m.ring_n, m.world.pads.size()])
	print("SIMTEST done in %dms, sim time %d, result %s" % [Time.get_ticks_msec() - t0, m.time, str(m.result)])
	print("SIMKIN %s lost=%s" % [str(m.kstat), str(m._resolve_lost().map(func(L): return [L["fate"], L["holder"]]))])
	if m.blight:
		# the Blight: how many it brought out, and what it did (knocks / eliminations / damage on hunters)
		print("SIMBLIGHT spawned %d alive %d wardens %d shrieks %d knocks %d outs %d dmg %d" % [m.blight.spawned, m.blight.alive().size(), m.blight.wardens.size(), m.blight.shrieks, int(m.kstat.get("bl_knock", 0)), int(m.kstat.get("bl_out", 0)), int(m.kstat.get("bl_dmg", 0.0))])
	for h in m.hunters:
		print("  %s team %d %s %s knocks %d kills %d dmg %d gems %d %s" % [h.pname, h.team, h.cls, h.arch, h.knocks, h.kills, h.dmg_done, h.gems, "OUT" if h.out else ("EXTRACTED" if h.extracted else "alive")])
	get_tree().quit()

# ------------------------------------------------------------------ browser test hooks
var _cmd_cb = null

## window.kinGameCmd("ready" | "start" | "state" | "move:x,z" | "fire:x,z" | "god") for automated browser tests.
## Results land in window.kinGameOut as JSON.
var _soc_test := false      # the shared-feature test hooks only answer on a #soctest page

func _expose_test_hooks() -> void:
	_cmd_cb = JavaScriptBridge.create_callback(func(a): _cmd(str(a[0])))
	JavaScriptBridge.get_interface("window").kinGameCmd = _cmd_cb

func _cmd(c: String) -> void:
	var out := {}
	var current = screen_node()
	if (c.begins_with("goto:") or c.begins_with("soc:")) and _soc_test:
		_social_cmd(c, current)
		return
	if current and current.has_method("_toggle_ready") and c == "ready":
		current._toggle_ready()
	elif current and current.has_method("_start") and c == "start":
		current._start()
	elif current is Match:
		var m: Match = current
		if c == "state":
			out = {"time": m.time, "mid": m.get_instance_id(), "host": m.is_host, "me": Net.me, "hunters": m.hunters.map(func(h): return [h.nid, h.pname, h.team, snappedf(h.hp, 0.1), h.remote, h.downed, h.out, h.pos.snapped(Vector3(0.1, 0.1, 0.1)), h.dropping, h.cls]),
				"mobs": m.mobs.filter(func(x): return not x.dead).size(), "kills": m.player.kills if m.player else 0, "knocks": m.player.knocks if m.player else 0,
				"feed": m.feed.map(func(f): return f["text"]), "pickups": m.pickups.size(), "gems": m.player.gems if m.player else 0}
		elif c.begins_with("tp:") and m.player:
			var nid := c.substr(3)
			var t: Ent = m.ents_by_id.get(nid, null)
			if t:
				# stand a few tiles away on solid ground at the same height
				for off in [Vector3(2.5, 0, 0), Vector3(-2.5, 0, 0), Vector3(0, 0, 2.5), Vector3(0, 0, -2.5), Vector3(1.8, 0, 1.8), Vector3(-1.8, 0, -1.8)]:
					var q: Vector3 = t.pos + off
					if absf(m.world.ground_at(q.x, q.z) - t.pos.y) < 0.1 and not m.world.is_block(q.x, q.z):
						m.player.teleport(q)
						break
		elif c.begins_with("shoot:") and m.player:
			var t: Ent = m.ents_by_id.get(c.substr(6), null)
			if t:
				m.player.inp["aim"] = t.pos + Vector3(0, 0.9, 0)
				m.player.fire_cd = 0.0
				m.player.fire()
		elif c == "god" and m.player:
			m.player.max_hp = 9999; m.player.hp = 9999
	elif current and current.has_method("_open_chat"):
		if c.begins_with("chat:"):
			var rec: Dictionary = Save.active_kin()
			current._open_chat(rec)
			current.chat_input.text = c.substr(5)
			current._send_chat()
		elif c == "chatlog":
			out = {"log": current.chat_log.slice(1), "lines": Save.active_kin().get("lines", {}), "ai_ok": Bridge.ai_ok}
	elif current and current.has_method("show_result"):
		out = {"screen": "results"}
	JavaScriptBridge.eval("window.kinGameOut = " + JSON.stringify(out) + ";", true)

## Test hooks for the shared features. Answers land in window.kinSocOut (they're mostly async).
func _soc_reply(v) -> void:
	JavaScriptBridge.eval("window.kinSocOut = " + JSON.stringify(v) + ";", true)

func _social_cmd(c: String, current) -> void:
	var p := c.split(":")
	match p[0] + ":" + p[1]:
		"goto:town": Game.goto("town", {"mode": p[2], "gid": p[3] if p.size() > 3 else ""})
		"goto:home": Game.goto("home")
		"goto:visit":
			Social.get_doc("profiles/" + p[2], func(d: Dictionary): Game.goto("home", {"visit": Social.clean_island(d), "visit_id": p[2]}))
		"soc:state":
			var st := {"me": Social.me, "mode": Social.mode, "ok": Social.ok, "guild": Social.guild, "progress": Social.guild_progress,
				"perks": Save.d.get("guild_perks", []), "gems": Save.d["gems"], "seeds": Save.d["seeds"], "crops": Save.d["crops"],
				"listings": Save.d.get("listings", {}), "screen": str(current.get_script().resource_path) if current and current.get_script() else ""}
			if current and "others" in current: st["others"] = (current.others as Dictionary).size()
			if current and "members" in current: st["members"] = (current.members as Array).size()
			if current and "project_nodes" in current: st["projects"] = (current.project_nodes as Dictionary).keys()
			if current and "visit" in current: st["visiting"] = String((current.visit as Dictionary).get("name", ""))
			_soc_reply(st)
		"soc:name": Save.d["name"] = p[2]; _soc_reply(true)
		"soc:give":
			Save.d["gems"] = int(Save.d["gems"]) + int(p[2])
			if p.size() > 3: Save.add_seed(p[3], 3)
			_soc_reply(true)
		"soc:publish": Social.publish_profile(true); _soc_reply(true)
		"soc:create": Social.create_guild(p[2], "We test things", "", func(okk): _soc_reply(okk))
		"soc:join": Social.join_guild(p[2], func(okk): _soc_reply(okk))
		"soc:leave": Social.leave_guild(func(): _soc_reply(true))
		"soc:guilds": Social.list_guilds(func(rows): _soc_reply(rows))
		"soc:contrib": Social.contribute(p[2], int(p[3]), func(okk): _soc_reply(okk))
		"soc:sell": Social.sell(p[2], p[3], int(p[4]), func(okk): _soc_reply(okk))
		"soc:market": Social.list_market(func(rows): _soc_reply(rows))
		"soc:buy": Social.buy(p[2], func(what): _soc_reply(what))
		"soc:unlist": Social.unlist(p[2], func(okk): _soc_reply(okk))
		"soc:notice": Social.post_notice(p[2], func(okk): _soc_reply(okk))
		"soc:notices": Social.list_notices(func(rows): _soc_reply(rows))
		"soc:gift": Social.send_gift(p[2], p[3], p[4], func(okk): _soc_reply(okk))
		"soc:collect":
			Social.collect_gifts(func(lines):
				Social.collect_payouts(func(total): _soc_reply({"lines": lines, "paid": total})))
		"soc:islands": Social.list_islands(func(rows): _soc_reply(rows.map(func(r): return r["id"])))
		"soc:refresh": Social.refresh_guild(func(): _soc_reply(Social.guild))
		"soc:open":
			if current and current.has_method("_use"):
				current._use({"kind": p[2], "data": p[3] if p.size() > 3 else null, "label": ""})
			_soc_reply(true)
		"soc:walk":
			if current and "ppos" in current:
				current.ppos = Vector3(float(p[2]), 0, float(p[3]))
			_soc_reply(true)

func _hb_home():      # the farm for the checks that build one (tools/*_check.gd call main._hb_home())
	var H = load("res://scripts/home/home.gd")
	var hm = H.new()
	add_child(hm)
	current = hm
	await get_tree().process_frame
	await get_tree().process_frame
	while hm.building:      # a farm built under a still-covered fade comes in slices: wait for all of it
		await get_tree().process_frame
	return hm
