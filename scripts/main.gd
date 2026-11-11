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
	# tooling never touches the real save file: checks, screenshots and --no-save runs play on a copy
	if "--no-save" in args or "--archetype-check" in args or "--kit-combo-check" in args or "--mage-combo-check" in args or "--gunslinger-combo-check" in args or "--zone-check" in args or "--dolm-combo-check" in args or "--ostra-combo-check" in args or "--hero-combo-check" in args or "--archer-combo-check" in args or "--bulwark-combo-check" in args or "--arena-check" in args or "--dredge-combo-check" in args or "--ashwick-combo-check" in args or Array(args).any(func(x): return String(x).begins_with("--shot=") or String(x).begins_with("--arena-shot=") or String(x).begins_with("--rolling-shot=")):
		Save.no_write = true
	var opts := {}
	var demo := Demo.name_in(args)      # recording presets: made-up save, overlays hidden (docs/DEMO_PRESETS.md)
	if demo != "": Demo.setup(demo)
	for a in args:
		if a.begins_with("--overlay="):
			# test: open one of the overlay menus a moment after the screen appears
			var which := a.substr(10).split(":")
			get_tree().create_timer(0.6).timeout.connect(func(): Overlay.shot_demo(which))
		if a.begins_with("--seed="): opts["seed"] = int(a.substr(7))
		if a == "--god": opts["god"] = true
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
	if "--check" in args:
		var CheckT = load("res://tools/check.gd")
		var bad := 0
		for f in CheckT.new()._scan("res://scripts"):
			var sc = load(f)
			if sc == null or not sc.can_instantiate():
				print("FAIL ", f); bad += 1
		print("CHECK DONE, failures: ", bad)
		get_tree().quit()
		return
	if Array(args).any(func(a): return String(a).begins_with("--grammar-check")):
		# tooling: parse every kin grammar file (docs/KIN_GRAMMAR.md) and print structural errors;
		# --grammar-check=<root> checks another folder (e.g. res://tests/grammar_fixtures/broken)
		var groot := "res://content"
		for a in args:
			if a.begins_with("--grammar-check="): groot = a.substr(16)
		var gbad := KinGrammar.check(groot)
		get_tree().quit(1 if gbad > 0 else 0)
		return
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
	if "--biome-check" in args:
		# tooling: an expedition on the authored map; what each biome spawned, then a minute of play
		var bm := Match.new()
		add_child(bm)
		bm.start({"teams": 4, "squad": 1, "tier": int(opts.get("tier", 1)), "seed": int(opts.get("seed", 9)), "no_drop": true, "autoplay": true})
		bm.set_process(false)
		var by := {}
		var rar := [0, 0, 0, 0]; var nm := 0
		for mb in bm.mobs:
			var b := bm.world.biome_at(mb.pos.x, mb.pos.z)
			if not by.has(b): by[b] = []
			by[b].append(String(mb.md["name"]))
			rar[int(mb.get_meta("rarity", 0))] += 1
			if not (mb.get_meta("muts", []) as Array).is_empty(): nm += 1
		for b in by:
			print("BIOME %s: %d mobs, e.g. %s" % [b, by[b].size(), ", ".join((by[b] as Array).slice(0, 6))])
		var hk := {}
		for hz in bm.biomes.hazards: hk[hz["kind"]] = int(hk.get(hz["kind"], 0)) + 1
		print("BIOME rarity common/uncommon/rare/elite %s, mutated %d of %d; hazards %s" % [str(rar), nm, bm.mobs.size(), str(hk)])
		for i in int(60.0 / Match.DT):
			bm.step(Match.DT)
		print("BIOME sim ok, time %.0f, mobs left %d, fields %d" % [bm.time, bm.mobs.filter(func(x): return not x.dead).size(), bm.fields.list.size()])
		get_tree().quit()
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
	if "--hair-check" in args:
		var hb: int = load("res://tests/hair_gallery.gd").check()
		print("HAIR CHECK DONE, failures: ", hb)
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
	if "--kinbox-check" in args:
		var kbc = load("res://tools/kinbox_check.gd").new()      # the farm cap, the Kin Burrow and rare mutations
		set_meta("kinbox_check", kbc)      # kept alive while it waits on frames
		kbc.run(self)
		return
	if CheckRegistry.run(self, args):      # registered checks (tools/check_registry.gd)
		return
	if "--glide-reach" in args:
		load("res://tools/glide_reach.gd").new().run(self)    # how far a glide carries over open void (sizes map gaps)
		return
	if "--arena-check" in args:
		var arc = load("res://tools/arena_check.gd").new()      # the Arena, training's practice tools, the kit card
		set_meta("arena_check", arc)        # (kept alive across its awaits)
		arc.run(self)
		return
	if "--archetype-check" in args or "--kit-combo-check" in args or "--mage-combo-check" in args or "--gunslinger-combo-check" in args:
		var akc = load("res://tools/archetype_check.gd").new()      # every archetype kit, controls, locks, infusion, feel
		set_meta("archetype_check", akc)
		akc.run(self)
		return
	if "--simtest" in args:
		_simtest(opts)
		return
	if "--boss-check" in args:
		_boss_check()
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
	if "--perf-probe" in args:
		# tooling: a scripted expedition with per-phase frame costs and hitches (tests/perf_probe.gd)
		add_child(load("res://tests/perf_probe.gd").new())
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
	elif "--feel-lab" in args:
		get_tree().change_scene_to_file.call_deferred("res://tests/feel_test.tscn")    # the Supervive feel playground
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
## Headless check for boss lairs: every map has them; the dial opens a gate when every arc is hit and
## a miss resets the lock, chimes and calls guards; runes and ward stones open theirs; the ward keeps
## people out until then; each boss wakes, changes phase at 66% and 33%, enrages, and drops a Rare Egg;
## the egg takes a backpack slot (a full pack asks to swap), stays in your deathbox, comes home on
## extract onto the Incubator by the Nook and hatches a rare kin. Bots can work a dial too.
func _boss_check() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var bad := [0]
	var ok := func(cond: bool, what: String) -> void:
		print("BOSS %s %s" % ["ok  " if cond else "FAIL", what])
		if not cond: bad[0] += 1
	# 0. every map has lairs: the authored one, and generated maps of each size an expedition can use
	for sd in [3, 8, 13]:
		var gw := World.new()
		gw.generate(sd, World.BIG_SIZE, World.BIG_ISLANDS)
		ok.call(gw.lair_defs.size() >= 1, "generated big map seed %d has %d lair(s): %s" % [sd, gw.lair_defs.size(), str(gw.lair_defs.map(func(D): return D["boss"]))])
		gw.free()
	var gw2 := World.new()
	gw2.generate(5, 128, 16)
	ok.call(gw2.lair_defs.size() >= 1, "generated mid map has %d lair(s)" % gw2.lair_defs.size())
	gw2.free()
	var m := Match.new()
	add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var P: Hunter = m.player
	# boss loot is picked from the killer's class weapons (lairs.gd); with an archetype only its family
	# can be held, so this check plays the classic class kit (see docs/ARCHETYPES.md, gaps)
	P.set_arch("")
	var C: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var Q: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	for h in m.hunters:
		h.ctrl = "idle" if h != P else "local"
		h.inp["move"] = Vector2.ZERO
	var LS: Array = m.lairs.list
	ok.call(LS.size() == 3 and LS.map(func(L): return L["boss"]).has("colossus") and LS.map(func(L): return L["boss"]).has("serpent") and LS.map(func(L): return L["boss"]).has("brood"),
		"Skyreach has 3 lairs: %s" % str(LS.map(func(L): return "%s (%s)" % [L["name"], L["boss"]])))
	# SpawnPlan rolls which lairs are live (the rest lie dormant, rusted shut); the full map announces them
	var live: int = LS.filter(func(L): return L["active"]).size()
	var marks: int = m.spawn_plan.active_of("boss").size() if m.spawn_plan else -1
	ok.call(live >= 2 and live <= 3 and marks == live and LS.filter(func(L): return not L["active"]).all(func(L): return L["state"] == "dormant" and L["boss_mob"] == null),
		"Skyreach rolled %d of 3 lairs live (%d boss markers on the full map), the rest dormant" % [live, marks])
	for L in LS: m.lairs.activate(L)
	var by_boss := {}
	for L in LS: by_boss[L["boss"]] = L
	var sealed_ok := true
	for L in LS:
		for q in L["gate_tiles"]:
			if m.world.kind[m.world.idx(q.x, q.y)] != World.T_BLOCK: sealed_ok = false
		if L["boss_mob"] == null or not (L["boss_mob"] as Boss).dormant or L["state"] != "sealed": sealed_ok = false
	ok.call(sealed_ok, "every gate starts sealed, each boss asleep inside")
	var god := func():
		for h in [P, C]:
			h.hp = h.max_hp; h.armor = h.max_armor
			if h.downed: m.revive_hunter(h, h)
	var run := func(sec: float, each := Callable()):
		var t := 0.0
		while t < sec:
			if each.is_valid(): each.call()
			god.call()
			m.step(Match.DT); t += Match.DT
	var spot := func(h: Hunter, at: Vector3): h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z)); h.vel = Vector3.ZERO
	var park := func(h: Hunter):
		var at: Vector3 = m.world.spawns[0] if not m.world.spawns.is_empty() else m.world.random_ground()
		spot.call(h, at)
		# (a parked hunter just stands there: clear the monsters round it, or they shove it about until
		# one knock sends it over the island's edge and out of the match)
		for mb in m.mobs:
			if not (mb is Boss) and not mb.dead and mb.flat_dist(at) < 18.0:
				print("BOSS  park: cleared a %s %.1fm from the parking spot" % [mb.mkind, mb.flat_dist(at)])
				mb.dead = true; mb.visible = false
	# 1. the ward keeps you out while it's sealed
	var F: Dictionary = by_boss["colossus"]
	spot.call(P, F["c"] + Vector3(2, 0, 2))
	run.call(0.1)
	ok.call(not m.lairs.inside(F, P.pos, 0.0), "the seal throws you out of a sealed lair (now %.1fm from its middle)" % P.flat_dist(F["c"]))
	# 2. the dial: press on every lit arc, through all four locks
	spot.call(P, F["dial"])
	for g in F["guards"]: if is_instance_valid(g): g.dead = true
	var prev := [false]
	var press_right := func():
		var fire := false
		if not m.lairs.puzzle_of(P).is_empty() and float(F["jam"]) <= 0.0 and float(F["grace"]) <= 0.0:
			var nxt := float(F["needle"]) + float(F["dir"]) * m.lairs.speed_of(F) * Match.DT
			for t in F["targets"]:
				if not t["hit"] and absf(wrapf(nxt - float(t["a"]), -PI, PI)) <= float(t["w"]) * 0.5 - 0.03: fire = true
		elif m.lairs.puzzle_of(P).is_empty():
			fire = true      # the first press starts the dial
		P.inp["interact"] = fire and not prev[0]
		prev[0] = P.inp["interact"]
	var t0 := m.time
	while F["state"] == "sealed" and m.time - t0 < 60.0:
		press_right.call()
		god.call()
		m.step(Match.DT)
	P.inp["interact"] = false
	ok.call(F["state"] == "open" and int(F["fails"]) == 0 and int(F["lock"]) == 4, "dial: %d locks opened in %.1fs with no misses, gate %s" % [int(F["lock"]), m.time - t0, F["state"]])
	var gate_open := true
	for q in F["gate_tiles"]:
		if m.world.kind[m.world.idx(q.x, q.y)] != World.T_GROUND: gate_open = false
	ok.call(gate_open, "the gate's tiles are open ground now")
	# 3. a miss: hit one arc, then press off the arcs. The lock resets, the chime pings, guards come.
	var E: Dictionary = by_boss["serpent"]
	Q.ctrl = "local"
	spot.call(Q, E["dial"])
	spot.call(P, E["dial"] + Vector3(E["out"].x, 0, E["out"].y) * 6.0)
	# the gate's guards go for whoever works the dial: a bomber's blast or a spitter's hit could knock Q
	# off the lectern (the dial stops) or down, depending only on how the frames fall. Keep Q on it and
	# standing: this part tests the dial's miss, not surviving the guards
	var pin := func():
		Q.hp = Q.max_hp; Q.armor = Q.max_armor
		if Q.downed: m.revive_hunter(Q, Q)
		if Q.flat_dist(E["dial"]) > 0.25: spot.call(Q, E["dial"])
	Q.inp["interact"] = true; run.call(Match.DT, pin); Q.inp["interact"] = false; run.call(0.4, pin)
	var hit_one := false
	var tq := m.time
	while not hit_one and m.time - tq < 8.0:
		var nxt := float(E["needle"]) + float(E["dir"]) * m.lairs.speed_of(E) * Match.DT
		var on := false
		for t in E["targets"]:
			if absf(wrapf(nxt - float(t["a"]), -PI, PI)) <= float(t["w"]) * 0.5 - 0.03: on = true
		Q.inp["interact"] = on and not Q.inp["interact"]
		run.call(Match.DT, pin)
		hit_one = (E["targets"] as Array).any(func(t): return t["hit"])
	Q.inp["interact"] = false; run.call(Match.DT, pin)
	var guards0: int = m.lairs._guards_alive(E)
	var pings0 := m.pings.size()
	var feed0 := m.feed_all.size()
	while m.lairs.target_under(E) >= 0:
		run.call(Match.DT, pin)
	Q.inp["interact"] = true; run.call(Match.DT, pin); Q.inp["interact"] = false
	var any_hit: bool = (E["targets"] as Array).any(func(t): return t["hit"])
	ok.call(hit_one and int(E["fails"]) == 1 and not any_hit and int(E["lock"]) == 0 and float(E["jam"]) > 0.0, "miss: the lock resets (fails %d, arcs lit again, jammed %.1fs)" % [int(E["fails"]), float(E["jam"])])
	ok.call(m.lairs._guards_alive(E) > guards0 and m.pings.size() > pings0 and m.feed_all.slice(feed0).any(func(f): return String(f).contains("chime")) and Q.reveal_t > 2.0,
		"miss: chime pings nearby players, reveals the presser, guards %d -> %d" % [guards0, m.lairs._guards_alive(E)])
	Q.ctrl = "idle"
	park.call(Q)
	run.call(0.5)
	# 4. runes open the Eyrie, wards open the Thornhive
	for rn in E["runes"]:
		spot.call(P, rn["pos"] + Vector3(0.6, 0, 0))
		P.inp["interact"] = true
		run.call(Match.DT * 2)
		var tr := m.time
		while not rn["lit"] and m.time - tr < 4.0:
			# (the guards each rune calls are fought for real in a match; here they'd only shove the test hunter off)
			for g in E["guards"]: if is_instance_valid(g): g.dead = true
			P.inp["interact"] = true
			run.call(Match.DT)
	P.inp["interact"] = false
	ok.call(E["runes"].size() == 3 and E["state"] == "open", "runes: %d pylons lit, the Eyrie is %s" % [E["runes"].filter(func(r): return r["lit"]).size(), E["state"]])
	var H: Dictionary = by_boss["brood"]
	var wards: Array = H["wards"]
	for wd in wards:
		spot.call(P, wd.pos + Vector3(1.2, 0, 0))
		wd.hurt(30.0, P, {"src": "shot"})
		run.call(0.2)
		wd.hurt(9999.0, P, {"src": "shot"})
		run.call(0.1)
	ok.call(wards.size() == 3 and H["state"] == "open" and m.lairs._guards_alive(H) > 0, "wards: %d broken (guards came out: %d), the Thornhive is %s" % [wards.filter(func(x): return x.dead).size(), m.lairs._guards_alive(H), H["state"]])
	# 4b. sealed in like a raid: free to come and go before the fight; step in and the gate shuts
	# behind you until the boss dies, you all go down, or the seal times out
	for g in F["guards"]: if is_instance_valid(g) and not g.dead: g.dead = true; g.visible = false
	park.call(C); park.call(Q)
	var outv := Vector2(F["out"].x, F["out"].y)
	var walk := func(h: Hunter, dir: Vector2, sec: float, until := Callable()) -> void:
		var t := 0.0
		while t < sec:
			h.inp["move"] = dir
			m.step(Match.DT); t += Match.DT
			if until.is_valid() and until.call(): break
		h.inp["move"] = Vector2.ZERO
		m.step(Match.DT)
	var gate_shut := func(L: Dictionary) -> bool:
		return (L["gate_tiles"] as Array).all(func(q): return m.world.kind[m.world.idx(q.x, q.y)] == World.T_BLOCK)
	var gate_free := func(L: Dictionary) -> bool:
		return (L["gate_tiles"] as Array).all(func(q): return m.world.kind[m.world.idx(q.x, q.y)] == World.T_GROUND)
	var fb: Boss = F["boss_mob"]
	# before the fight: walk up into the gateway and back out again, the boss sleeping
	spot.call(P, F["dial"])
	walk.call(P, -outv, 6.0, func(): return m.lairs.inside(F, P.pos, 0.3))
	var in_gateway: bool = m.lairs.inside(F, P.pos, 0.3) and F["state"] == "open"
	walk.call(P, outv, 1.5)      # (1.5 s: 3 s walked off the island edge, which is allowed now)
	ok.call(in_gateway and F["state"] == "open" and fb.dormant and not F.get("locked", false) and not m.lairs.inside(F, P.pos, 0.5) and gate_free.call(F),
		"before the fight: into the gateway and back out, the boss still asleep (%.1fm out)" % P.flat_dist(F["c"]))
	# step in: it wakes and the gate seals behind you, the ward lit
	walk.call(P, -outv, 6.0, func(): return F["state"] == "awake")
	walk.call(P, -outv, 0.4)
	ok.call(F["state"] == "awake" and F.get("locked", false) and (F["sealed_in"] as Array).has(P) and gate_shut.call(F) and m.lairs.sealed_lair(P) == F,
		"walk in: %s wakes and the gate seals behind you (locked %s, gate shut %s)" % [fb.md["name"], F.get("locked", false), gate_shut.call(F)])
	ok.call(Lairs.LOCK_T == 90.0 and m.lairs.lock_left(F) > 88.5 and m.lairs.lock_left(F) <= 90.0 and float(fb.md["enrage"]) < Lairs.LOCK_T,
		"the seal holds for at most %ds (%s left on the clock); %s enrages at %ds, inside it" % [int(Lairs.LOCK_T), Lairs.clock(m.lairs.lock_left(F)), fb.md["name"], int(fb.md["enrage"])])
	var dome: Node3D = F["nodes"]["dome"]
	run.call(0.6)
	ok.call(dome.visible and float(F["gate_k"]) < 0.05 and ((F["nodes"]["gate"] as Node3D).get_node("Bars") as Node3D).visible, "the bars are back down and the ward glows over the walls")
	# no way out while it's sealed: walking, or being flung over the wall
	walk.call(P, outv, 4.0)
	var walked_in := m.lairs.inside(F, P.pos, 0.0)
	P.pos = F["c"] + Vector3(outv.x, 0, outv.y) * (float(F["half"]) + 1.5); P.prev = P.pos
	run.call(0.1)
	ok.call(walked_in and m.lairs.inside(F, P.pos, 0.0) and F.get("locked", false), "sealed: walking at the gate or being flung over the wall keeps you inside")
	# nobody crashes in
	spot.call(Q, F["dial"])
	Q.ctrl = "local"
	walk.call(Q, -outv, 4.0)
	ok.call(not m.lairs.inside(F, Q.pos, 0.25), "sealed: a rival can't get in (%.1fm from the middle)" % Q.flat_dist(F["c"]))
	Q.ctrl = "idle"; park.call(Q)
	# bots: sealed in, they fight; outside, a sealed lair isn't a goal
	var bg: Array = m.lairs.bot_goal(P, true)
	Q.ai["boss_hunt"] = true
	var qg: Array = m.lairs.bot_goal(Q, false)
	ok.call(not bg.is_empty() and String(bg[1]) == "lair_fight" and (qg.is_empty() or (qg[0] as Vector3).distance_to(F["c"]) > 1.0),
		"bots: sealed in they fight it (%s); a sealed lair isn't a goal from outside (%s)" % [str(bg.slice(1)), str(qg.slice(1))])
	# everyone inside goes down: the seal breaks and the boss heals and goes back to sleep
	fb.hurt(fb.max_hp * 0.2, P, {"src": "shot"})
	var hp_hurt := fb.hp
	P.lives = 3
	m.knock(P, null, {})
	m.step(Match.DT); m.step(Match.DT)
	ok.call(P.downed and hp_hurt < fb.max_hp and not F.get("locked", false) and F["state"] == "open" and fb.dormant and fb.hp >= fb.max_hp and gate_free.call(F),
		"wiped: the seal breaks, %s heals (%d -> %d) and sleeps" % [fb.md["name"], int(hp_hurt), int(fb.hp)])
	m.revive_hunter(P, P)
	god.call()
	# the seal times out: it drops and the boss resets
	spot.call(P, F["c"] + Vector3(outv.x, 0, outv.y) * 2.0)
	var tl := m.time
	while not F.get("locked", false) and m.time - tl < 10.0: run.call(Match.DT)      # (it lets you be a moment after a reset)
	var relocked: bool = F.get("locked", false)
	fb.hurt(fb.max_hp * 0.1, P, {"src": "shot"})
	F["lock_at"] = m.time - Lairs.LOCK_T + 0.2
	run.call(0.5)
	ok.call(relocked and not F.get("locked", false) and fb.dormant and fb.hp >= fb.max_hp and F["state"] == "open", "the seal times out after %ds: it drops and the boss resets" % int(Lairs.LOCK_T))
	# unsealed: the way out through the gate is clear
	spot.call(P, F["c"])
	run.call(0.1)
	if F.get("locked", false):
		F["lock_at"] = m.time - Lairs.LOCK_T; run.call(0.2)
	walk.call(P, outv, 6.0, func(): return not m.lairs.inside(F, P.pos, 1.5))
	ok.call(not m.lairs.inside(F, P.pos, 1.0) and not F.get("locked", false), "unsealed: you walk out through the gate (%.1fm from the middle)" % P.flat_dist(F["c"]))
	run.call(13.0)      # (the boss settles back to sleep with nobody inside)
	# 5. each boss: wakes when you walk in, phases at 66% and 33%, attacks, enrages, drops its egg
	var egg_items: Array = []
	for h in [P, C]:      # (a kin's own attacks and abilities would move the scripted hp thresholds; its species is random)
		for k in [h.kin, h.kin2]:
			if k != null:
				k.dead = true
				k.visible = false
	for L in [F, E, H]:
		for g in L["guards"]: if is_instance_valid(g) and not g.dead: g.dead = true; g.visible = false
		var b: Boss = L["boss_mob"]
		spot.call(P, L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0)
		spot.call(C, L["c"] + Vector3(-L["out"].y, 0, L["out"].x) * 3.0)
		run.call(0.3)
		ok.call(L["state"] == "awake" and not b.dormant and L.get("locked", false) and (L["sealed_in"] as Array).has(P) and (L["sealed_in"] as Array).has(C), "%s wakes when you walk in and seals you both in" % b.md["name"])
		var atks := {}
		var track := func(): if b.atk != "": atks[b.atk] = true
		run.call(6.0, track)
		if b.buried: b._clear_attack()      # (a burrowed Brood Mother can't be hit: bring her up for the scripted hits)
		b.stagger_t = 0.0; b.stag_open = 0.0     # (nor staggered: a kin's ability can stagger it, and a staggered boss takes 2.5x)
		b.hurt(b.max_hp * 0.36, P, {"src": "shot"})
		run.call(0.1, track)
		var p1 := b.phase
		var hp_a := b.hp
		if b.buried: b._clear_attack()
		b.stagger_t = 0.0; b.stag_open = 0.0
		b.hurt(100.0, P, {"src": "shot"})
		var invul_ok := hp_a - b.hp < 30.0
		run.call(8.0, track)
		if b.buried: b._clear_attack()
		b.stagger_t = 0.0; b.stag_open = 0.0
		b.hurt(b.max_hp * 0.4, P, {"src": "shot"})
		run.call(0.1, track)
		var p2 := b.phase
		run.call(8.0, track)
		b.awake_t = float(b.md["enrage"]) - 0.05
		run.call(0.2, track)
		var enr := b.enraged
		ok.call(p1 == 1 and p2 == 2 and invul_ok and enr, "%s: phase 2 at 66%%, phase 3 at 33%% (shrugs off hits while it roars), enraged after %ds" % [b.md["name"], int(b.md["enrage"])])
		if not (p1 == 1 and p2 == 2 and invul_ok and enr):
			print("BOSS  (phases %d %d, invul %s, enraged %s, hp %d/%d, dead %s, damage by team %s, feed %s)" % [p1, p2, invul_ok, enr, int(b.hp), int(b.max_hp), b.dead, str(b.damage_by), str(m.feed_all.slice(-8))])
		ok.call(atks.size() >= 3, "%s used %d attacks: %s" % [b.md["name"], atks.size(), str(atks.keys())])
		var w0 := m.wpicks.size(); var brands0 := P.perks.filter(func(k): return String(k).begins_with("brand_")).size()      # (a Brand dropped where you stand is taken on the spot)
		spot.call(P, L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0)     # (a shove may have sent you out of the lair)
		P.lvl = 1; P.xp = 0.0
		var xp0 := P.xp
		b.hp = 1.0
		if b.buried: b._clear_attack()
		b.hurt(5.0, P, {"src": "shot"})
		run.call(0.2)
		var ew = L.get("egg_wp")
		var egg_shown: bool = m.lairs.egg_pings.size() > 0
		var egg_ok: bool = ew != null and m.wpicks.has(ew) and Loot.is_rare_egg(Pack.ground_item(ew)) and Data.is_rare(String(Pack.ground_item(ew)["sp"]))
		var strong: bool = m.wpicks.slice(w0).any(func(wp): return wp.has("gear") and int(wp["rar"]) >= 3)
		var kill_t := m.time - 0.2
		for a in L["adds"]: if is_instance_valid(a) and not a.dead: a.dead = true; a.visible = false     # (the brood scatters; here it'd only shove the test hunters about)
		var lvn: Node3D = L["nodes"]["lever"]
		var vent: Node3D = L["nodes"]["vent"]
		ok.call(L.get("locked", false) and L.get("victory", false) and gate_shut.call(L) and L.get("up_on", false) and (lvn.get_node("Lit") as Node3D).visible and (vent.get_node("Air") as Node3D).visible
			and m.lairs.victory_left(L) > Lairs.VICTORY_T - 0.5 and m.lairs.sealed_lair(P) == L,
			"%s falls: the gate stays shut (opens in %s), the lever lit, the updraft blowing" % [b.md["name"], Lairs.clock(m.lairs.victory_left(L))])
		var pile_now: Array = m.wpicks.slice(w0)      # the drop as it landed (walking about can pick some of it up)
		# no walking out yet
		spot.call(P, L["c"] + Vector3(L["out"].x, 0, L["out"].y) * (float(L["half"]) - 2.0))
		walk.call(P, Vector2(L["out"].x, L["out"].y), 1.2)
		ok.call(m.lairs.inside(L, P.pos, 0.0) and gate_shut.call(L), "after the kill: walking at the shut gate keeps you in")
		spot.call(P, L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0)
		# a small pile, all of it good, and the egg on its own spot a few steps away
		var pile: Array = pile_now.filter(func(wp): return not wp.get("egg", false))
		var usable: bool = pile.any(func(wp): return wp.has("gear") and int(wp["rar"]) >= 3) and (pile.any(func(wp): return wp.has("tune")) or P.perks.filter(func(k): return String(k).begins_with("brand_")).size() > brands0)
		var good: bool = pile.all(func(wp): return int(wp["rar"]) >= 3 if not wp.has("val") else Loot.value(Pack.ground_item(wp)) >= 40)
		var apart := 99.0
		if ew != null:
			for wp in pile: apart = minf(apart, Vector2(wp["pos"].x - ew["pos"].x, wp["pos"].z - ew["pos"].z).length())
		ok.call(pile.size() <= 4 and usable and good and apart >= 2.0 and m.lairs.inside(L, ew["pos"], 0.0),
			"%s's loot: %d things, all good (%s), an Epic+ piece of gear and a Brand upgrade, the egg %.1fm from the pile" % [b.md["name"], pile.size(), str(pile.map(func(wp): return String(wp["gear"]) + " " + str(wp["rar"]) if wp.has("gear") else (String(wp["tune"]) if wp.has("tune") else Loot.name_of(Pack.ground_item(wp))))), apart])
		var outL := Vector3(L["out"].x, 0, L["out"].y)
		var vic: bool = L.get("victory", false)
		if L == F:
			# the lever: a press away from it does nothing; at it, the gate opens (pressed well clear of the loot
			# and the egg: beside them it would pick them up, and where they land follows the fight)
			var clear := func(q: Vector3) -> float:
				return m.wpicks.reduce(func(d, wp): return minf(d, q.distance_to(wp["pos"])), 99.0)
			var spots: Array = [-3.0, 0.0, 3.0].map(func(d): return L["c"] + outL * d)
			spots.sort_custom(func(a, c): return clear.call(a) > clear.call(c))
			spot.call(P, spots[0])
			P.inp["interact"] = true; run.call(Match.DT); P.inp["interact"] = false; run.call(Match.DT)
			var held: bool = L.get("locked", false)
			spot.call(P, L["lever"] - outL * 0.8)
			var it: Dictionary = m.lairs.interact_for(P)
			run.call(0.1)
			P.inp["interact"] = true; run.call(Match.DT); P.inp["interact"] = false; run.call(0.3)
			ok.call(vic and held and String(it.get("what", "")) == "lever" and String(it.get("label", "")) == "%s: Open the gate" % Settings.key_cap("interact")
				and not L.get("locked", false) and gate_free.call(L) and not L.get("up_on", false) and String(L.get("opened_by_lever", "")) == P.pname,
				"the lever: '%s'; pulled %.1fs after the kill, the gate opens and the updraft dies down" % [it.get("label", "?"), m.time - kill_t])
		elif L == E:
			# the updraft: anyone who wasn't sealed in gets no lift from it
			var up: Vector3 = L["up"]
			Q.ctrl = "local"
			Q.teleport(up + Vector3(0, 6.0, 0)); Q.vel = Vector3.ZERO; Q.grounded = false
			var qy0 := Q.pos.y
			var qy := qy0
			var tq2 := 0.0
			while tq2 < 0.5:
				m.step(Match.DT); tq2 += Match.DT; god.call()
				qy = maxf(qy, Q.pos.y)
			var refused: bool = not (L["flown"] as Array).has(Q) and qy <= qy0 + 0.05 and not Q.auto_glide
			spot.call(Q, up)
			run.call(0.2)
			# (a person walks off an island's edge now, so an outsider shoved off the lair may fall out of the match: that counts as shoved out)
			refused = refused and not (L["flown"] as Array).has(Q) and Q.pos.y < float(L["c"].y) + 1.0 and (Q.out or not m.lairs.inside(L, Q.pos, 0.0))
			ok.call(refused, "the updraft refuses outsiders: no lift over it (%.2fm), shoved off and out (%.1fm from the middle)" % [qy - qy0, Q.flat_dist(L["c"])])
			if Q.out or Q.downed: Life.bring_back(m, Q, m.world.spawns[0] if not m.world.spawns.is_empty() else m.world.random_ground(), 1.0, false)
			Q.ctrl = "idle"; park.call(Q)
			# a hunter who fought rides it: up over the wall and away from the back, the gate still shut
			spot.call(P, up)
			var top := P.pos.y
			var shut_when_out := false
			var tf := 0.0
			while tf < 12.0:
				m.step(Match.DT); tf += Match.DT; god.call()
				top = maxf(top, P.pos.y)
				if not m.lairs.inside(L, P.pos, 0.3) and not shut_when_out: shut_when_out = gate_shut.call(L) and L.get("locked", false)
				if P.grounded and not m.lairs.inside(L, P.pos, 0.5): break
			var rel: Vector3 = P.pos - L["c"]
			var back: float = -rel.dot(outL)
			ok.call((L["flown"] as Array).has(P) and top > float(L["c"].y) + 6.0 and not m.lairs.inside(L, P.pos, 0.5) and shut_when_out and P.grounded and rel.dot(outL) < float(L["half"]) * 0.5 and not P.out and m.lairs.sealed_lair(P).is_empty(),
				"the updraft: lifts you %.1fm over the floor, over the wall and away (%.1fm behind the lair's middle, landed %s) while the gate stays shut" % [top - float(L["c"].y), back, P.grounded])
			# nobody pulls the lever: it opens by itself after VICTORY_T
			var ta := m.time
			while L.get("locked", false) and m.time - ta < Lairs.VICTORY_T + 2.0: run.call(Match.DT)
			ok.call(not L.get("locked", false) and gate_free.call(L) and not L.get("up_on", false) and absf(m.time - kill_t - Lairs.VICTORY_T) < 0.25 and String(L.get("opened_by_lever", "?")) == "",
				"nobody at the lever: the gate opens by itself %.1fs after the kill, the updraft dies down" % (m.time - kill_t))
		else:
			# a bot sealed in after the kill: the lever with nobody outside, the updraft with rivals at the gate
			C.ai["egg_" + String(L["id"])] = false      # (this bot leaves the egg to you)
			var g0: Array = m.lairs.bot_goal(C, false)
			spot.call(Q, m.lairs.camp_spot(L, Q))
			var g1: Array = m.lairs.bot_goal(C, false)
			ok.call(not g0.is_empty() and String(g0[1]) == "lair_lever" and not g1.is_empty() and String(g1[1]) == "lair_updraft" and m.lairs.campers(L, C.team) >= 1,
				"bots after the kill: no one at the gate, pull the lever (%s); rivals camping it, the updraft (%s)" % [str(g0.slice(1)), str(g1.slice(1))])
			# and it does: walks into the updraft and glides out over the wall
			L["victory_at"] = m.time      # (a fresh clock: this part is about the bot, not the timer)
			C.ctrl = "bot"
			var tb2 := 0.0
			while tb2 < 16.0 and (m.lairs.inside(L, C.pos, 0.5) or not C.grounded):
				m.step(Match.DT); tb2 += Match.DT; god.call()
				Q.hp = Q.max_hp
			ok.call((L["flown"] as Array).has(C) and not m.lairs.inside(L, C.pos, 0.5) and not C.out and L.get("locked", false),
				"a bot rides the updraft out with rivals at the gate (%.1fs, %.1fm from the gate, the gate still shut)" % [tb2, C.flat_dist(L["gate_c"])])
			C.ctrl = "idle"; C.inp["move"] = Vector2.ZERO
			Q.ctrl = "idle"; park.call(Q)
			spot.call(P, L["lever"] - outL * 0.8)
			run.call(0.1)
			P.inp["interact"] = true; run.call(Match.DT); P.inp["interact"] = false; run.call(0.3)
			park.call(C)
		# the way out is clear
		if m.lairs.inside(L, P.pos, 0.0): spot.call(P, L["c"] + outL * 3.0)
		var tw := 0.0
		while m.lairs.inside(L, P.pos, 1.0) and tw < 8.0:
			P.inp["move"] = Vector2(L["out"].x, L["out"].y) if absf(P.pos.x - L["gate_c"].x) + absf(P.pos.z - L["gate_c"].z) < 2.0 or m.lairs.inside(L, P.pos, -2.0) == false else Vector2(L["gate_c"].x - P.pos.x, L["gate_c"].z - P.pos.z).normalized()
			god.call(); m.step(Match.DT); tw += Match.DT
		P.inp["move"] = Vector2.ZERO
		ok.call(not m.lairs.inside(L, P.pos, 1.0), "after the kill you walk out through the gate (%.1fs)" % tw)
		ok.call(L["state"] == "cleared" and egg_ok and strong and P.xp > xp0 + 100.0 and egg_shown,
			"%s falls: a Rare %s on the ground (on everyone's map), an Epic+ weapon, +%d XP" % [b.md["name"], Data.egg_name(String(Pack.ground_item(ew)["sp"])) if ew != null else "?", int(P.xp - xp0)])
		if ew != null: egg_items.append(ew)
	# 6. the egg takes a pack slot: a full pack asks what to leave
	var ew0: Dictionary = egg_items[0]
	spot.call(P, ew0["pos"])
	P.pack_cap = 2
	P.pack = [Loot.valuable("old_coin"), Loot.valuable("sky_pearl")]
	Pack.take_ground(m, P, ew0)
	ok.call(m.hud.swap_open() and m.wpicks.has(ew0), "full pack: the egg opens the swap window")
	Pack.swap(m, P, 0, ew0)
	m.hud.close_swap()
	var egg_it: Dictionary = P.pack.filter(func(it): return Loot.is_rare_egg(it))[0] if P.pack.any(func(it): return Loot.is_rare_egg(it)) else {}
	ok.call(not egg_it.is_empty() and P.pack.size() == 2, "the Rare Egg is in the pack (%s)" % str(P.pack.map(func(it): return Loot.name_of(it))))
	run.call(0.2)
	ok.call(m.lairs.egg_pings.any(func(e): return e.get("follow") == P), "picking it up shows the carrier to everyone for a few seconds")
	# 7. die with it: it's in your deathbox; a teammate smart-loots it
	P.lives = 1
	m.eliminate(P, Q, "knocked out")
	var bx := Life.box_of(m, P)
	var in_box: bool = not bx.is_empty() and (bx.get("pack", []) as Array).any(func(it): return Loot.is_rare_egg(it))
	ok.call(in_box, "dead: the egg is in your deathbox")
	spot.call(C, bx["pos"])
	C.pack = [Loot.valuable("old_coin"), Loot.valuable("kin_idol"), Loot.valuable("sky_pearl")]
	C.pack_cap = 3
	Life.smart_loot(m, C, bx)
	ok.call(C.pack.any(func(it): return Loot.is_rare_egg(it)), "smart loot takes the egg first, even from a full pack")
	# 8. extract: the egg goes to the Incubator (not the breeding nest), it hatches a rare kin
	Save.d["roster"] = [Save.new_kin("cindle", "Pip")]
	Save.d["active"] = Save.d["roster"][0]["uid"]
	Save.d["incubator"] = {}; Save.d["rare_eggs"] = []; Save.d["egg"] = {}
	var out := Game.apply_result({"extracted": true, "haul": Pack.haul(C), "tier": 0, "gems": 0, "kin_runs": []})
	var q: Array = [Incubator.eggs()[0]] if not Incubator.eggs().is_empty() else []
	ok.call(q.size() == 1 and Data.is_rare(String(q[0]["sp"])) and (out.get("haul", []) as Array).any(func(it): return Loot.is_rare_egg(it)),
		"extract: a %s goes to the Incubator %s" % [Data.egg_name(String(q[0]["sp"])) if not q.is_empty() else "?", str(q)])
	ok.call(not Incubator.eggs().is_empty() and Save.d.get("egg", {}).is_empty() and Save.d.get("rare_eggs", []).is_empty(), "home: it goes straight into the Incubator's cradle (the breeding nest stays free)")
	var rr := RandomNumberGenerator.new(); rr.seed = 3
	var inc_egg: Dictionary = Incubator.eggs()[0].duplicate()
	var baby := Care.hatch_rare(inc_egg, rr)
	ok.call(Data.is_rare(String(baby["species"])) and baby.get("rare", false) and String(baby["species"]) == String(Data.MOBS[String(inc_egg["boss"])]["egg"]),
		"hatch: a rare %s (%s)" % [Data.KIN[baby["species"]]["name"], baby["species"]])
	# 9. rare kin never turn up wild, on rivals or as a starter
	var any_rare := false
	for i in 60:
		if Data.is_rare(String(m.bot_kin_record()["species"])): any_rare = true
	var rares: Array = Data.KIN.keys().filter(func(k): return Data.is_rare(k))
	ok.call(not any_rare and Data.common_kin().size() + rares.size() == Data.KIN.size() and rares.size() >= 2,
		"rare species (%s) only come from eggs" % str(rares))
	m.queue_free()
	# 10. a bot can work a dial
	var m2 := Match.new()
	add_child(m2)
	m2.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4, "no_drop": true, "autoplay": true})
	m2.set_process(false)
	var B: Hunter = m2.hunters[1]
	for h in m2.hunters:
		if h != B: h.ctrl = "idle"; h.teleport(m2.world.spawns[0])
	var L2: Dictionary = m2.lairs.list[0]
	m2.lairs.activate(L2)
	# the only lair it can go for: bots don't plan lairs in a match's first 25 s and roam instead,
	# then take the nearest live one, so with the other rolled-live lairs about, where that roam ended
	# (which drifts with the RNG stream the earlier sections leave) decided which gate it worked
	for x in m2.lairs.list:
		if x != L2 and x["state"] == "sealed":
			x["state"] = "dormant"; m2.lairs._tint_dormant(x, true)
	# ... and it has to find its way back across the islands: every route a bot takes lands on the
	# island it leads to (a bridge route that landed on the island it left looped the bot round it)
	var W2 := m2.world
	var bad_links: Array = W2.links.filter(func(lk): return W2.island_of(lk["land"].x, lk["land"].z) != int(lk["to"]))
	ok.call(bad_links.is_empty(), "every glide, wind and bridge route lands on the island it leads to (%d of %d don't: %s)" % [bad_links.size(), W2.links.size(), str(bad_links.slice(0, 3).map(func(lk): return "%d>%d land %s" % [lk["from"], lk["to"], str(lk["land"])]))])
	for g in L2["guards"]: g.dead = true
	B.ai["skill"] = 0.9
	B.ai["boss_hunt"] = true
	B.teleport(L2["dial"] + Vector3(L2["out"].x, 0, L2["out"].y) * 4.0)
	var tb := m2.time
	if "--boss-only-dial" in OS.get_cmdline_user_args(): print("  dial bot: %s %s %s" % [B.cls, B.arch, B.wid])
	# a dial test, not a loot test: no chests or ground loot to wander off to first
	for c in m2.chests: c["open"] = true
	m2.pickups.clear()
	while L2["state"] == "sealed" and m2.time - tb < 150.0:
		if "--boss-only-dial" in OS.get_cmdline_user_args() and int(m2.time * 60.0) % 300 == 0:
			print("  t=%.0f pos=%s dial=%.1f goal=%s kind=%s tgt=%s user=%s inter=%s" % [m2.time - tb, B.pos.snapped(Vector3(0.1,0.1,0.1)), B.flat_dist(L2["dial"]), str(B.ai.get("goal")), B.ai.get("goal_kind"), str(B.ai.get("tgt")), str(L2["user"]), B.inp.get("interact")])
		B.hp = B.max_hp
		for g in L2["guards"]: if is_instance_valid(g): g.dead = true
		m2.step(Match.DT)
	ok.call(L2["state"] != "sealed", "a bot walked up and opened %s in %.0fs (%d misses)" % [L2["name"], m2.time - tb, int(L2["fails"])])
	m2.queue_free()
	# 10b. the fight is loud: everyone outside within ALERT_R hears it start (a roar, a ping with the
	# boss's icon, a shaft of light over the lair, the seal's clock over the gate) and its boss fall;
	# bots that hear it may camp the gate, the stronger squads more often; bots sealed in get out by
	# the lever, or by the updraft when rivals wait at the gate
	var m4 := Match.new()
	add_child(m4)
	m4.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m4.set_process(false)
	var P4: Hunter = m4.player
	for h in m4.hunters:
		h.ctrl = "idle" if h != P4 else "local"
		h.inp["move"] = Vector2.ZERO
	var A: Dictionary = m4.lairs.list.filter(func(x): return x["boss"] == "colossus")[0]
	m4.lairs.activate(A)
	for g in A["guards"]: if is_instance_valid(g): g.dead = true; g.visible = false
	m4.lairs.open(A, null, "dial")
	var spot4 := func(h: Hunter, at: Vector3): h.teleport(Vector3(at.x, m4.world.ground_at(at.x, at.z), at.z)); h.vel = Vector3.ZERO
	var run4 := func(sec: float):
		var t := 0.0
		while t < sec:
			for h in m4.hunters:
				if not h.out: h.hp = h.max_hp
			m4.step(Match.DT); t += Match.DT
	var teams4 := {}
	for h in m4.hunters:
		if h.team != P4.team: teams4[h.team] = teams4.get(h.team, []) + [h]
	var tk: Array = teams4.keys()
	var R1: Hunter = teams4[tk[0]][0]; var R2: Hunter = teams4[tk[0]][1]
	var S1: Hunter = teams4[tk[1]][0]; var S2: Hunter = teams4[tk[1]][1]
	var C4: Hunter = m4.hunters.filter(func(x): return x.team == P4.team and x != P4)[0]
	var outA := Vector3(A["out"].x, 0, A["out"].y)
	var sideA := Vector3(-A["out"].y, 0, A["out"].x)
	# where everyone is when it starts: you and your mate by the gate, one rival a way off, one far away
	spot4.call(P4, A["dial"] + outA * 4.0)
	spot4.call(C4, A["dial"] + outA * 4.0 + sideA * 2.0)
	var mid_at := Vector3.INF; var far_at := Vector3.INF
	for i in 500:
		var gp: Vector3 = m4.world.random_ground()
		if m4.lairs.lair_of(gp, 2.0).size() > 0: continue
		var gd := Vector2(gp.x - A["c"].x, gp.z - A["c"].z).length()
		if gd > 50.0 and gd < 120.0 and mid_at == Vector3.INF: mid_at = gp
		if far_at == Vector3.INF or gd > Vector2(far_at.x - A["c"].x, far_at.z - A["c"].z).length(): far_at = gp
	spot4.call(S1, mid_at)
	spot4.call(S2, far_at)
	var far_real := S2.flat_dist(A["c"])
	if far_real <= Lairs.ALERT_R:
		S2.pos = A["c"] + (S2.pos - A["c"]).normalized() * (Lairs.ALERT_R + 10.0); S2.prev = S2.pos     # (the map isn't that big: put it out of earshot for the moment)
	var pings4 := m4.pings.size()
	var feed4 := m4.feed_all.size()
	# a rival squad walks in and the fight starts
	spot4.call(R1, A["c"] + outA * 1.5 + sideA * 1.5)
	spot4.call(R2, A["c"] + outA * 1.5 - sideA * 1.5)
	var tl4 := 0.0
	while not A.get("locked", false) and tl4 < 1.0:
		m4.step(Match.DT); tl4 += Match.DT
	var s2_far := S2.flat_dist(A["c"])
	spot4.call(S2, far_at)
	var heard_f: Array = m4.lairs.alert_log.filter(func(e): return e["lair"] == A["id"] and e["kind"] == "fight").map(func(e): return e["nid"])
	var lbl4: Label3D = A["nodes"]["label"]
	var beam4: Node3D = A["nodes"]["beam"]
	ok.call(A.get("locked", false) and (A["sealed_in"] as Array).has(R1) and (A["sealed_in"] as Array).has(R2) and not (A["sealed_in"] as Array).has(P4),
		"a rival squad walks into %s: sealed in with %s, you outside" % [A["name"], A["boss_mob"].md["name"]])
	ok.call(heard_f.has(P4.nid) and heard_f.has(C4.nid) and heard_f.has(S1.nid) and not heard_f.has(S2.nid) and not heard_f.has(R1.nid),
		"the fight is heard by everyone outside within %dm (you, your mate, a rival %.0fm off) but not %.0fm away, nor by those inside" % [int(Lairs.ALERT_R), S1.flat_dist(A["c"]), s2_far])
	var pinged: bool = m4.pings.slice(pings4).any(func(pg): return Vector2(pg["pos"].x - A["c"].x, pg["pos"].z - A["c"].z).length() < 1.0)
	var fed: bool = m4.feed_all.slice(feed4).any(func(f): return String(f).contains("fight at %s" % A["name"]))
	ok.call(pinged and fed and m4.lairs.alerted(A, P4) and beam4.visible and lbl4.text.contains("FIGHT") and lbl4.text.contains(Lairs.clock(m4.lairs.lock_left(A))),
		"outside: a ping on the lair (boss icon on the map), '%s', the beam over the lair, the seal's clock over the gate ('%s')" % [String(A.get("alert_text", "")), lbl4.text.replace("\n", " / ")])
	# bots outside that heard it: camp it, the stronger squads more often, never when leaving
	S1.ctrl = "bot"
	var odds_full: float = m4.lairs.camp_odds(S1)
	S1.hp = S1.max_hp * 0.3; S2.hp = S2.max_hp * 0.3
	var odds_hurt: float = m4.lairs.camp_odds(S1)
	S1.hp = S1.max_hp; S2.hp = S2.max_hp
	S1.ai["camp_" + String(A["id"])] = true
	var cg: Array = m4.lairs.bot_goal(S1, false)
	var cg_leave: Array = m4.lairs.bot_goal(S1, true)
	S2.ai["camp_" + String(A["id"])] = true
	var cg_deaf: Array = m4.lairs.bot_goal(S2, false)
	ok.call(odds_full > odds_hurt and not cg.is_empty() and String(cg[1]) == "lair_camp" and not m4.lairs.inside(A, cg[0], 0.5) and (cg[0] as Vector3).distance_to(A["gate_c"]) < 9.0
		and (cg_leave.is_empty() or String(cg_leave[1]) != "lair_camp") and (cg_deaf.is_empty() or String(cg_deaf[1]) != "lair_camp"),
		"bots that heard it may camp the gate (odds %.2f with the squad up, %.2f hurt; %s); not when leaving, nor if they never heard it" % [odds_full, odds_hurt, str(cg.slice(1))])
	S1.ctrl = "idle"
	spot4.call(S1, cg[0])
	# the boss falls: a different cry, the ping turns to "fallen", the gate's clock over the gate
	var feed4b := m4.feed_all.size()
	var bA: Boss = A["boss_mob"]
	bA.hurt(bA.max_hp * 3.0, R1, {"src": "shot"})
	run4.call(0.1)
	for a in A["adds"]: if is_instance_valid(a) and not a.dead: a.dead = true; a.visible = false
	var heard_v: Array = m4.lairs.alert_log.filter(func(e): return e["lair"] == A["id"] and e["kind"] == "fallen").map(func(e): return e["nid"])
	ok.call(A.get("victory", false) and heard_v.has(P4.nid) and heard_v.has(S1.nid) and String(A.get("alert", "")) == "fallen" and m4.feed_all.slice(feed4b).any(func(f): return String(f).contains("has fallen"))
		and lbl4.text.contains("has fallen") and lbl4.text.contains("gate opens") and beam4.visible,
		"the boss falls: everyone near hears it ('%s'), the clock over the gate: '%s'" % [String(A.get("alert_text", "")), lbl4.text.replace("\n", " / ")])
	# sealed-in bots: S1 waits at the gate, so R1 takes the updraft; with nobody there R2 takes the lever
	spot4.call(P4, A["dial"] + outA * 30.0 if not m4.world.is_void((A["dial"] + outA * 30.0).x, (A["dial"] + outA * 30.0).z) else far_at)
	spot4.call(C4, P4.pos + sideA * 1.5)
	R1.ai["egg_" + String(A["id"])] = false; R2.ai["egg_" + String(A["id"])] = false     # (straight out: the egg is another test)
	var gR1: Array = m4.lairs.bot_goal(R1, false)
	R1.ctrl = "bot"
	var tr1 := 0.0
	while tr1 < 11.0 and (m4.lairs.inside(A, R1.pos, 0.5) or not R1.grounded):
		run4.call(Match.DT); tr1 += Match.DT
	var r1_out: bool = (A["flown"] as Array).has(R1) and not m4.lairs.inside(A, R1.pos, 0.5) and A.get("locked", false)
	R1.ctrl = "idle"; R1.inp["move"] = Vector2.ZERO
	spot4.call(S1, far_at)
	A["victory_at"] = m4.time       # (a fresh clock for R2)
	var gR2: Array = m4.lairs.bot_goal(R2, false)
	R2.ctrl = "bot"
	var tr2 := 0.0
	while tr2 < 10.0 and A.get("locked", false):
		run4.call(Match.DT); tr2 += Match.DT
	ok.call(String(gR1[1]) == "lair_updraft" and r1_out and String(gR2[1]) == "lair_lever" and not A.get("locked", false) and String(A.get("opened_by_lever", "")) == R2.pname,
		"bots sealed in: with a rival camping the gate one rides the updraft out (%.1fs); with nobody there the other pulls the lever (%.1fs)" % [tr1, tr2])
	m4.queue_free()
	# 11. a generated map rolls at least one live lair too
	var m3 := Match.new()
	add_child(m3)
	m3.start({"teams": 2, "squad": 1, "tier": 1, "length": 1e9, "seed": 8, "no_drop": true, "procedural": true, "autoplay": true})
	m3.set_process(false)
	var live3: int = m3.lairs.list.filter(func(L): return L["active"]).size()
	ok.call(m3.lairs.list.size() >= 1 and live3 >= 1, "a generated map: %d lair(s), %d live (%s)" % [m3.lairs.list.size(), live3, str(m3.lairs.list.map(func(L): return L["boss"]))])
	print("BOSSCHECK done, failures: %d" % bad[0])
	get_tree().quit(1 if bad[0] > 0 else 0)
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
		"soc:create": Social.create_guild(p[2], "We test things", func(okk): _soc_reply(okk))
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

