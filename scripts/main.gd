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
	return not (_has_arg("--shot=") or _has_arg("--rolling-shot=") or _has_arg("--autoplay") or _has_arg("--simtest"))

func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args() or "--version" in OS.get_cmdline_user_args():
		add_child(DedicatedServer.new())      # one matchmade match, no local player; --version alone (scripts/core/dedicated_server.gd)
		return
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
	if "--perch-check" in args:
		# tooling: for each perch, start on the island next to its updraft chain, jump, glide into the
		# short column, then the tall one, then onto the perch. Reports who made it and how high.
		var pm := Match.new()
		add_child(pm)
		pm.start({"teams": 2, "squad": 1, "tier": 0, "seed": 31, "no_drop": true, "length": 1e9, "autoplay": true})
		pm.set_process(false)
		for mb in pm.mobs: mb.queue_free()
		pm.mobs.clear()
		var ph: Hunter = pm.hunters[0]
		for o in pm.hunters:
			o.ctrl = "idle"
			if o != ph: o.teleport(pm.world.spawns[-1])
		ph.ctrl = "local"
		var chains := {"spire": [Vector2(127, 93), Vector2(130, 89)], "emberspire": [Vector2(72, 100), Vector2(78, 92)], "eye": [Vector2(124, 124), Vector2(130, 128)], "needle": [Vector2(146, 48), Vector2(139, 43)]}
		var ok := 0
		for pid in chains:
			var pi := -1
			for ii in pm.world.islands.size():
				if String(pm.world.islands[ii].get("id", "")) == pid: pi = ii
			var steps: Array = chains[pid]
			var u1: Vector2 = steps[0]
			# the nearest ground to the first column that isn't a perch
			var start := Vector3.INF; var bd := 1e9
			for z in range(int(u1.y) - 10, int(u1.y) + 11):
				for x in range(int(u1.x) - 10, int(u1.x) + 11):
					if not pm.world.inb(x, z) or pm.world.kind[pm.world.idx(x, z)] != World.T_GROUND: continue
					var isl := pm.world.island_of(x, z)
					if pm.world.islands[isl].get("perch", false): continue
					var d := Vector2(x + 0.5, z + 0.5).distance_to(u1)
					if d < bd: bd = d; start = Vector3(x + 0.5, pm.world.ground_at(x + 0.5, z + 0.5), z + 0.5)
			ph.teleport(start); ph.vel = Vector3.ZERO; ph.grounded = true; ph.glide_fuel = 1.0; ph.pad = {}
			var goal := pm.world._poi(pi)
			var stage := 0; var t := 0.0; var top_y := 0.0; var made := false
			while t < 14.0:
				var tgt: Vector2 = steps[stage] if stage < steps.size() else Vector2(goal.x, goal.z)
				var to := tgt - Vector2(ph.pos.x, ph.pos.z)
				ph.inp["move"] = to.normalized() if to.length() > 0.4 else Vector2.ZERO
				ph.inp["jump"] = t < 0.1 or (ph.grounded and pm.world.island_of(ph.pos.x, ph.pos.z) != pi)
				ph.inp["glide"] = t > 0.25
				pm.step(Match.DT); t += Match.DT
				top_y = maxf(top_y, ph.pos.y)
				var up: Dictionary = pm.world.updraft_at(ph.pos)
				if stage < steps.size() and not up.is_empty() and ph.pos.y > float(up["top"]) - 0.6:
					stage += 1
				if ph.grounded and pm.world.island_of(ph.pos.x, ph.pos.z) == pi:
					made = true; break
				if ph.out: break
			if made: ok += 1
			print("PERCH %s: %s in %.1fs, highest %.1fm (perch top %.1fm)" % [pid, "made it" if made else "FAILED", t, top_y, goal.y])
			ph.out = false; ph.hp = ph.max_hp
		print("PERCHCHECK done, %d of %d reached" % [ok, chains.size()])
		get_tree().quit()
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
	if "--revive-check" in args:
		var rvc = load("res://tools/revive_check.gd").new()      # bot squadmates pick you up first
		set_meta("revive_check", rvc)
		rvc.run(self)
		return
	if "--weapon-clip-check" in args:
		var wcc = load("res://tools/weapon_clip_check.gd").new()      # no held weapon ever dips into the ground
		set_meta("weapon_clip_check", wcc)
		wcc.run(self)
		return
	if "--farm-start-check" in args:
		set_meta("farm_start_check", load("res://tools/farm_start_check.gd").new()); get_meta("farm_start_check").run(self); return      # a new farm: empty island, placing, chopping, stations, old saves (kept in meta: the check awaits, so it must stay referenced)
	if "--work-check" in args:
		var wkc = load("res://tools/work_check.gd").new()      # kin at work: jobs, stations, priorities, shimmer odds
		set_meta("work_check", wkc)
		wkc.run(self)
		return
	if "--polish-check" in args:
		load("res://tools/polish_check.gd").new().run(self)      # polish pass: drop families, stair flights, chest look, see-through
		return
	if "--boki-system-check" in args:
		load("res://tools/boki_system_check.gd").new().run(self)      # Boki commands (throw, recall, hold/follow, C), the downed Boki, the Merge
		return
	if "--merge-form-check" in args:
		load("res://tools/merge_form_check.gd").new().run(self)      # merge forms: transformation, kit swap, ultimates, shell, no tiers, net, bots
		return
	if "--boki-follow-check" in args:
		load("res://tools/boki_follow_check.gd").new().run(self)      # the Boki follows you: leash, glide hops, Sic / Call back, the wheel, mounts
		return
	if "--capture-check" in args:
		load("res://tools/capture_check.gd").new().run(self)      # capture by scan, the box, the Field Book, the net events
		return
	if "--teammate-check" in args:
		load("res://tools/teammate_check.gd").new().run(self)      # Boki as teammates: following, callouts, caring, the tutorial guide
		return
	if "--unique-check" in args:
		load("res://tools/unique_check.gd").new().run(self)      # every kin its own: rolls, inheritance, ids, migration, size
		return
	if "--iv-check" in args:
		load("res://tools/iv_check.gd").new().run(self)      # kin IVs: rolls, backfill, breeding, Rare Eggs, caps
		return
	if "--incubator-check" in args:
		var icc = load("res://tools/incubator_check.gd").new()      # Rare Eggs on the Incubator by the Nook
		set_meta("incubator_check", icc)
		icc.run(self)
		return
	if "--economy-check" in args:
		_economy_check()
		return
	if "--gear-check" in args:
		load("res://tools/gear_check.gd").new().run(self)      # signature weapons, gear, tunings, drop tables, save migration
		return
	if "--lair-lock-check" in args:
		load("res://tools/lair_lock_check.gd").new().run(self)      # boss loot and the egg's own spot; locked in 20 s after the kill
		return
	if "--level-hud-check" in args:
		load("res://tools/level_hud_check.gd").new().run(self)      # the portrait's level and XP ring, the level-up flash and sound, R locked to 6
		return
	if "--pack-ui-check" in args:
		var puc = load("res://tools/pack_ui_check.gd").new()      # the backpack windows take real mouse clicks
		set_meta("pack_ui_check", puc)
		puc.run(self)
		return
	if "--life-check" in args:
		_life_check()
		return
	if "--swim-check" in args:
		set_meta("swim_check", load("res://tools/swim_check.gd").new())     # wading and swimming in the farm's pond
		get_meta("swim_check").run(self)
		return
	if "--hero-check" in args:
		set_meta("hero_check", load("res://tools/hero_check.gd").new())     # change hero on the farm
		get_meta("hero_check").run(self)
		return
	if "--keybind-check" in args:
		set_meta("keybind_check", load("res://tools/keybind_check.gd").new())     # two keys per action, the ult on R and X, clashes
		get_meta("keybind_check").run(self)
		return
	if "--mantle-check" in args:
		load("res://tools/mantle_check.gd").new().run(self)    # ledges you mean to climb, you climb; the rest never grab you
		return
	if "--glide-reach" in args:
		load("res://tools/glide_reach.gd").new().run(self)    # how far a glide carries over open void (sizes map gaps)
		return
	if "--abyss-check" in args:
		set_meta("abyss_check", load("res://tools/abyss_check.gd").new())
		get_meta("abyss_check").run(self)
		return
	if "--move-feel-check" in args:
		load("res://tools/move_feel_check.gd").new().run(self)    # movement, jump, glide, drop and camera timings vs docs/MOVEMENT_FEEL.md
		return
	if "--wallhug-check" in args:
		load("res://tools/wallhug_check.gd").new().run(self)    # pressed against an island side from the abyss: caught, not sunk
		return
	if "--obstacle-check" in args:
		load("res://tools/obstacle_slide_check.gd").new().run(self)    # walking past and around trees and rocks: no sticking, no pull
		return
	if "--airheal-check" in args:
		load("res://tools/airheal_check.gd").new().run(self)    # heals and abilities in the air, drinking is a risk
	if "--train-check" in args:
		load("res://tools/train_check.gd").new().run(self)      # riding the sky train, and being hit by it
		return
	if "--balloon-check" in args:
		load("res://tools/balloon_check.gd").new().run(self)      # the hit marker is the hitbox
		return
	if Array(args).any(func(a): return String(a).begins_with("--weapon-check")):
		_weapon_check()
		return
	if "--base-check" in args:
		_base_check()
		return
	if "--duel-check" in args:
		_duel_check()
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
	if "--ability-check" in args:
		_ability_check()
		return
	if "--grammar-runtime-check" in args:
		_grammar_runtime_check()
		return
	if "--hold-check" in args:
		_hold_check()
		return
	if "--record-check" in args:
		_record_check()
		return
	if "--blight-check" in args:
		load("res://tools/blight_check.gd").new().run(self)      # the Blight: spawns, scaling, noise, early weakness
		return
	if "--raid-check" in args:
		load("res://tools/raid_check.gd").new().run(self)        # raid conditions, sight, the armor kit key
		return
	if "--rolling-check" in args:
		var rck = load("res://tools/rolling_check.gd").new()     # rolling sessions: waves, cut-off, level floor, catch-up XP, bounties, the end
		set_meta("rolling_check", rck)      # (held, so nothing it waits on loses it)
		rck.run(self)
		return
	if "--rolling-sim" in args:
		var rsim = load("res://tools/rolling_sim.gd").new()      # a whole 30-minute rolling session, headless, with bots
		set_meta("rolling_sim", rsim)       # (held: it yields frames so freed nodes really go, and must outlive its awaits)
		rsim.run(self, opts)
		return
	if "--bot-sanity-check" in args:
		_bot_sanity()
		return
	if "--simtest" in args:
		_simtest(opts)
		return
	if "--extract-check" in args:
		_extract_check()
		return
	if "--truce-check" in args:
		_truce_check()
		return
	if "--boss-check" in args:
		_boss_check()
	if "--boss-ttk" in args:
		_boss_ttk()
		return
	if "--drop-check" in args:
		_drop_check()
		return
	if "--home-build-check" in args:
		_home_build_check()
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
	if "--hitch-check" in args or _has_arg("--load-check"):
		# a seeded expedition through the drop and landing; fails on a stalled frame (tools/hitch_check.gd);
		# --load-check stops at the reveal and judges the loading screen
		add_child(load("res://tools/hitch_check.gd").new())
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
	elif "--match" in args or opts.has("raid_demo") or opts.has("blight_demo") or opts.get("rolling", false):
		show_screen("match", opts)
	elif "--duel" in args:
		show_screen("match", Match.duel_opts())
	elif Record.arena_pick != "":
		_open_arena(Record.arena_pick)
	elif "--arena" in args:
		_open_arena("")
	elif "--training" in args:
		show_screen("match", Match.arena_opts(Arch.of_save()).merged({"perk_demo": "--perk-demo" in args}, true))      # (the Training Area)
	elif "--tutorial" in args:
		show_screen("match", {"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "tut_test": "--tut-test" in args})
	elif args.is_empty() or "--title" in args:
		show_screen("title", {})
	elif Save.d["roster"].is_empty():
		show_screen("hatch", {})
	else:
		show_screen("home", {})

## --arena=<archetype> (with --record for filming): straight into the arena with that archetype
## picked. The arena provides `static func arena_opts(pick: String) -> Dictionary` on Match; until it
## does, this opens the training area instead and says so.
func _open_arena(pick: String) -> void:
	Save.d["tutorial"]["home"] = true
	var ms: Script = load("res://scripts/match/match.gd")
	if ms.get_script_method_list().any(func(md): return String(md["name"]) == "arena_opts"):
		show_screen("match", ms.call("arena_opts", pick))
		return
	push_warning("--arena=%s: no arena in this build (Match.arena_opts); opening the training area" % pick)
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
				Sfx.prefetch(["music_hollow" if tier_i >= 2 else "music_match", "amb_match"])
				Match.prefetch([Match.HUD_SCRIPT])
				ld = load("res://scripts/ui/loading.gd").new()
				ld.setup(opts)
				add_child(ld)
				_ld = ld
				# nothing in 3D shows behind the loading screen while the match builds: drawing the
				# half-built world every frame only slows the build (see Match.warm_up for the drawing)
				get_viewport().disable_3d = true
				await ld.shown
				ld.want = 0.04
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
					ld.want = maxf(ld.want, 0.04 + 0.66 * f)
					ld.set_stage(stage))
				get_viewport().disable_3d = false
				if not is_instance_valid(m) or not m.is_inside_tree():
					ld.queue_free()
					return
				if not opts.has("net"): m.set_process(false)
				ld.set_stage("graphics")
				await m.warm_up(func(f: float): ld.want = maxf(ld.want, 0.7 + 0.28 * f))
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
		"online":
			var scr_o = load("res://scripts/ui/online.gd").new()      # matchmade play (scripts/core/online_session.gd)
			scr_o.setup(opts)
			current = _layer(scr_o)
		"lobby":
			var L = load("res://scripts/ui/lobby.gd")
			var scr = L.new()
			scr.setup(opts)
			current = _layer(scr)
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

## Headless check: a whole match with the player on autopilot, stepped as fast as possible.
## Test: the down / death / revive rules, step by step, with idle hunters placed by hand.
## Headless: drops a hunter (and a wisp) just off island edges, holds toward the cliff, and checks
## every mantle: it happens, it ends on top, and the body never sinks into the cliff on the way.
func _life_check() -> void:
	var m := Match.new()
	add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	var mine: Array = m.hunters.filter(func(x): return x.team == 0)
	var foe: Hunter = m.hunters.filter(func(x): return x.team != 0)[0]
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var A: Hunter = mine[0]; var B: Hunter = mine[1]; var C: Hunter = mine[2]
	var home: Vector3 = A.pos
	# the test steps up to 8m in every direction, so start from open ground (spawns can be small landings)
	for k in 2000:
		var g := m.world.random_ground()
		var roomy := true
		for dx in range(-10, 11, 2):
			for dz in range(-6, 7, 2):
				if m.world.is_void(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - m.world.ground_at(g.x, g.z)) > 0.3: roomy = false
		if roomy:
			home = g; break
	var far := home + Vector3(0, 0, 0)
	var spot := func(h: Hunter, at: Vector3): h.teleport(at); h.vel = Vector3.ZERO
	var run := func(sec: float):
		var t := 0.0
		while t < sec:
			m.step(Match.DT); t += Match.DT
	# park everyone else far apart
	for h in m.hunters:
		if h.team != 0 and h != foe: spot.call(h, m.world.random_ground())
	var away := m.world.random_ground()
	for k in 200:
		if away.distance_to(home) > 40.0: break
		away = m.world.random_ground()
	spot.call(foe, away)
	# 1. ally revive
	spot.call(B, home + Vector3(2, 0, 0)); spot.call(C, home + Vector3(2, 0, 0.5)); spot.call(A, home)
	m.knock(B, foe, {})
	var t0 := m.time
	while B.downed and m.time - t0 < 10.0: run.call(Match.DT)
	print("LCHECK ally revive: back=%s after %.1fs hp %.0f%%" % [not B.downed, m.time - t0, B.hp / B.max_hp * 100.0])
	# 2. bleed out alone (with the kin knocked out, so it can't pull them up)
	for kk in [B.kin, B.kin2]:
		if kk: kk.dead = true
	spot.call(C, home + Vector3(-8, 0, 0)); spot.call(A, home + Vector3(-8, 0, 1))
	B.gems = 20
	m.knock(B, foe, {})
	t0 = m.time
	print("LCHECK  knocked: downed=%s hp=%s" % [B.downed, B.down_hp])
	while not B.out and m.time - t0 < 30.0:
		run.call(Match.DT)
		if int((m.time - t0) * 60.0) % 120 == 0: print("LCHECK   t=%.1f downed=%s down_hp=%.1f revive=%.2f out=%s" % [m.time - t0, B.downed, B.down_hp, B.revive, B.out])
	var bx := Life.box_of(m, B)
	print("LCHECK bleed: dead=%s after %.1fs box=%s gems in box=%d" % [B.out, m.time - t0, not bx.is_empty(), int(bx.get("gems", -1))])
	# 3. box revive: --box-revive-check (tools/box_revive_check.gd) times the channel; here it just brings B back
	Life.box_revive(m, bx, C)
	print("LCHECK box revive: back=%s hp %.0f%% gems %d" % [not B.out, B.hp / B.max_hp * 100.0, B.gems])
	# 4. stomp drain
	for kk in [B.kin, B.kin2]:
		if kk: kk.dead = true
	spot.call(C, home + Vector3(-8, 0, 0))
	spot.call(foe, B.pos)
	m.knock(B, foe, {})
	t0 = m.time
	run.call(Match.DT); run.call(Match.DT)
	var pinned: bool = B.get_meta("stomped", false)
	var stood: bool = foe.get_meta("standing_on", null) == B
	while not B.out and m.time - t0 < 30.0: run.call(Match.DT)
	print("LCHECK stomp: dead=%s after %.1fs (expect ~%.1fs at %.1fx) pinned=%s stomper flagged=%s slow=%.2f" % [B.out, m.time - t0, Life.R["bleed_out"] / Life.R["stomp_mult"], Life.R["stomp_mult"], pinned, stood, Life.R["stomp_slow"]])
	spot.call(foe, m.world.random_ground())
	# 5. beacon
	var bc: Dictionary = m.beacons[0]
	spot.call(C, bc["pos"])
	t0 = m.time
	while B.out and m.time - t0 < 12.0: run.call(Match.DT)
	print("LCHECK beacon: back=%s after %.1fs hp %.0f%% sick %.1fs used=%s" % [not B.out, m.time - t0, B.hp / B.max_hp * 100.0, B.sick_t, bc["used"]])
	# 6. execute
	for kk in [B.kin, B.kin2]:
		if kk: kk.dead = true
	spot.call(C, home + Vector3(-8, 0, 0)); spot.call(B, home + Vector3(6, 0, 0))
	m.knock(B, foe, {})
	spot.call(foe, B.pos + Vector3(0.5, 0, 0)); foe.inp["interact"] = true
	t0 = m.time
	while not B.out and m.time - t0 < 10.0:
		foe.inp["interact"] = true
		run.call(Match.DT)
	print("LCHECK execute: dead=%s after %.1fs (stomp drains too)" % [B.out, m.time - t0])
	# 6b. a committed stomp can't be cancelled by its owner, but a knockback breaks it
	var W2: Hunter = C
	for kk in [W2.kin, W2.kin2]:
		if kk: kk.dead = true
	spot.call(W2, home + Vector3(2, 0, 3))
	m.knock(W2, foe, {})
	spot.call(foe, W2.pos + Vector3(0.5, 0, 0))
	t0 = m.time
	while foe.stomp.is_empty() and m.time - t0 < 2.0:
		foe.inp["interact"] = true
		run.call(Match.DT)
	var committed := not foe.stomp.is_empty()
	for i in 30:
		foe.inp["interact"] = false      # letting go does nothing once committed
		foe.inp["move"] = Vector2(1, 0)
		run.call(Match.DT)
	var still := not foe.stomp.is_empty()
	foe.kb_t = m.time
	run.call(Match.DT)
	print("LCHECK stomp lock: committed=%s still after letting go=%s broken by knock=%s wisp alive=%s" % [committed, still, foe.stomp.is_empty(), not W2.out])
	print("LCHECK beacons=%d boxes=%d" % [m.beacons.size(), m.boxes.size()])
	# 7. Hollow rules: the Boki on you drops dazed beside the box and guards it; an enemy looting the box takes none of it
	m.tier = 2
	m.T = Data.TIERS[2]
	var rec := Save.new_kin("zapple")
	A.kin = null; A.kin2 = null
	m.give_kin(A, rec)
	spot.call(A, home); spot.call(B, home + Vector3(-8, 0, 0)); spot.call(C, home + Vector3(-8, 0, 1))
	m.eliminate(A, foe, "knocked out")
	var ab := Life.box_of(m, A)
	print("LCHECK hollow: kin guarding=%s" % KinLoss.guarding(A.kin))
	spot.call(foe, ab["pos"])
	t0 = m.time
	while not ab["empty"] and m.time - t0 < 4.0:
		foe.inp["interact"] = true
		run.call(Match.DT)
	print("LCHECK hollow loot: foe caught=%d guard still dazed=%s" % [foe.caught.size(), KinLoss.guarding(A.kin)])
	# 8. Meadow: kin stay safe (hidden) on death and come back on revive
	m.tier = 0
	m.T = Data.TIERS[0]
	spot.call(foe, m.world.random_ground())
	var B2: Hunter = B
	B2.kin = null; B2.kin2 = null
	m.give_kin(B2, Save.new_kin("zapple"))
	spot.call(B2, home + Vector3(-6, 0, 0))
	m.eliminate(B2, foe, "knocked out")
	print("LCHECK meadow: kin state=%s lost=%d" % [B2.kin.state, m.player_lost.size()])
	# 9. the deathbox loot window: a box with a rare glove and some gems; take one by hand, smart loot the rest
	var lb: Dictionary = {}
	for b0 in m.boxes:
		if not b0.get("empty", true):
			lb = b0
	if not lb.is_empty():
		var gid: String = String(Gear.ALL.keys()[0]) if not Gear.ALL.is_empty() else ""
		if gid != "": (lb["gear"] as Array).append({"id": gid, "rar": 3})
		lb["gems"] = int(lb.get("gems", 0)) + 15
		var looter: Hunter = C
		looter.gear = Gear.empty_slots(); looter.refresh_gear()
		var its: Array = Life.box_items(m, looter, lb)
		var g0 := looter.gems
		var first: Dictionary = its[0]
		Life.take_item(m, looter, lb, first)
		var got := Life.smart_loot(m, looter, lb)
		print("LCHECK loot window: items=%d took first=%s smart=%d gems +%d gear=%s left=%d empty=%s" % [its.size(), first["name"], got, looter.gems - g0, str(looter.gear), Life.box_items(m, looter, lb).size(), lb["empty"]])
	get_tree().quit()

## Headless check for loot and kin keeping: a full backpack asks to swap, smart loot takes the best
## first, extracting fills the armory, feeders feed hungry kin (also while you're away), starving
## runs its course to a grave, and the Soul Shrine brings a kin back changed. Never touches the save.
func _economy_check() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var bad := [0]
	var ok := func(cond: bool, what: String) -> void:
		print("ECON %s %s" % ["ok  " if cond else "FAIL", what])
		if not cond: bad[0] += 1
	var m := Match.new()
	add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var P: Hunter = m.player
	var Q: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var at := P.pos + Vector3(0.6, 0, 0)
	# 1. a full backpack asks what to drop
	P.pack_cap = 2
	P.pack = [Loot.valuable("old_coin"), Loot.gear("vest", 1)]
	m.spawn_val(Loot.valuable("kin_idol"), at)
	var wp: Dictionary = m.wpicks[m.wpicks.size() - 1]
	Pack.take_ground(m, P, wp)
	ok.call(m.hud.swap_open() and P.pack.size() == 2 and m.wpicks.has(wp), "full backpack opens the swap window (pack %d/%d)" % [P.pack.size(), P.pack_cap])
	Pack.swap(m, P, 0, wp)      # you pick the coin to leave behind
	var ids: Array = P.pack.map(func(it): return String(it.get("id", it.get("wid", ""))))
	ok.call(ids.has("kin_idol") and not ids.has("old_coin") and m.wpicks.any(func(w): return String(w.get("val", "")) == "old_coin"), "swap drops the coin on the ground and packs the idol: %s" % str(ids))
	m.hud.close_swap()
	# better armor on the ground goes on, and the old piece goes in the pack
	P.pack_cap = 4
	P.gear[2] = {"id": "vest", "rar": 1}
	m.spawn_gear("bastion_plate", 3, at, "", false)
	Pack.take_ground(m, P, m.wpicks[m.wpicks.size() - 1])
	ok.call(String(P.gear[2]["id"]) == "bastion_plate" and P.pack.any(func(it): return String(it.get("id", "")) == "vest"), "better armor goes on, the old piece into the pack: %s" % str(P.gear[2]))
	P.welem = "fire"
	var ex := {}
	Loot.rider(P, ex, 10.0)
	ok.call(float(ex.get("burn", 0.0)) >= 5.0, "fire rider burns (%s)" % str(ex))
	P.welem = "storm"; P.el_n = 3
	var ex2 := {}
	Loot.rider(P, ex2, 10.0)
	ok.call(ex2.has("fx_hit"), "storm rider arcs on the 4th attack")
	P.welem = "fire"
	# 2. smart loot: gear on you first, then the pack, best first, never worse for better
	var gid: String = Gear.ALL.keys()[0]
	var b := {"owner": Q, "team": Q.team, "pos": P.pos, "gems": 10, "seeds": {"tidebloom": 2}, "caught": [], "belt": [], "soul_until": 0.0,
		"prog": {}, "node": null, "empty": false, "gear": [{"id": gid, "rar": 4}, {"id": "gale_mantle", "rar": 4}],
		"pack": [Loot.valuable("old_coin"), Loot.valuable("crown_shard"), Loot.gear("vest", 1), Loot.gear("windstep_boots", 2), Loot.valuable("sky_pearl")]}
	P.pack = [Loot.valuable("kin_idol")]
	P.pack_cap = 3
	P.gear = Gear.empty_slots(); P.refresh_gear()
	var g0 := P.gems
	var got := Life.smart_loot(m, P, b)
	var pv: Array = P.pack.map(func(it): return Loot.value(it))
	var left: Array = Pack._box_things(b).map(func(c): return Loot.value(c["it"]))
	var minp: int = pv.min() if not pv.is_empty() else 0
	var maxl: int = left.max() if not left.is_empty() else 0
	print("ECON  smart loot took %d: weapon=%s gear=%s pack=%s values=%s left in box=%s" % [got, P.wpn["name"], str(P.gear), str(P.pack.map(func(it): return Loot.name_of(it))), str(pv), str(left)])
	ok.call(String(P.gear[2].get("id", "")) == "gale_mantle" and not (P.gear[Gear.slot_of(gid)] as Dictionary).is_empty(), "smart loot: the best gear goes on (armor %s)" % str(P.gear[2]))
	ok.call(P.pack.size() == 3 and minp >= maxl, "smart loot: pack holds the most valuable (min %d >= best left %d)" % [minp, maxl])
	ok.call(P.gems == g0 + 10 and int(P.seeds.get("tidebloom", 0)) >= 2, "smart loot: gems and seeds taken too")
	# 3. extracting brings it all home to the armory; the loadout goes out and comes back
	Save.d["roster"] = [Save.new_kin("cindle", "Pip")]
	Save.d["active"] = Save.d["roster"][0]["uid"]
	var haul := Pack.haul(P)
	# armor salvages on arrival
	var n_arm := haul.filter(func(it): return String(it["t"]) != "val" and not Equal.salvages(it)).size()
	var out := Game.apply_result({"extracted": true, "haul": haul, "tier": 0, "gems": 5, "kin_runs": []})
	ok.call(Econ.armory().size() == n_arm and int(Save.d["valuables"].get("crown_shard", 0)) == 1, "extract: %d pieces of gear in the armory, treasure in the vault %s" % [Econ.armory().size(), str(Save.d["valuables"])])
	ok.call((out.get("haul", []) as Array).size() == haul.size(), "results list what came home (%d)" % (out.get("haul", []) as Array).size())
	ok.call(int((out.get("mats", {}) as Dictionary).get("wood", 0)) > 0 and Work.mat("wood") > 0, "extract: the haul also gives farm materials %s" % str(out.get("mats", {})))
	var best_w: Dictionary = Econ.armory().filter(func(it): return Equal.may_bring(it, 2))[0]
	Econ.set_loadout(Econ.gear_slot(best_w), String(best_w["uid"]))
	var kit := Equal.take_loadout(2)
	ok.call(kit.size() == 1 and Econ.find(String(best_w["uid"])).is_empty() and (Save.d["raid_out"] as Array).size() == 1, "loadout leaves the armory for the expedition")
	Game.apply_result({"extracted": true, "haul": kit, "tier": 0, "kin_runs": []})
	ok.call(not Econ.find(String(best_w["uid"])).is_empty() and not Econ.loadout(Econ.gear_slot(best_w)).is_empty(), "extracting brings the loadout gear back, still picked")
	Equal.take_loadout(2)
	Game.apply_result({"extracted": false, "why": "knocked out", "lost_items": [best_w], "tier": 0, "kin_runs": []})
	ok.call(Econ.find(String(best_w["uid"])).is_empty() and Econ.loadout(Econ.gear_slot(best_w)).is_empty(), "dying loses the loadout gear")
	# armor salvages on arrival now; make sure two pieces are left
	if Econ.armory().size() < 2: Save.d["armory"].append(Loot.gear("skylark_boots", 2))
	var sold := Econ.sell(String(Econ.armory()[0]["uid"]))
	var scrap := Econ.salvage(String(Econ.armory()[0]["uid"]))
	ok.call(sold > 0 and scrap > 0, "sell (%d gems) and salvage (%d scrap)" % [sold, scrap])
	m.queue_free()
	# 4. feeders: a hungry kin eats, and a filled feeder keeps kin fed while you're away
	var rec: Dictionary = Save.d["roster"][0]
	Care.ensure(rec)
	rec["likes"]["hates"] = "puffcorn"
	rec["needs"]["food"] = 20.0
	var f: Dictionary = Econ.feeders()[0]
	f["food"] = ["kibble", "kibble", "kibble"]
	var res := Econ.serve(f, rec)
	ok.call(not res.is_empty() and Care.need(rec, "food") > 45.0 and Econ.fill(f) == 2, "feeder feeds a hungry kin: food %d, %d meals left" % [int(Care.need(rec, "food")), Econ.fill(f)])
	var now := Time.get_unix_time_from_system()
	f["kind"] = "hopper"; f["food"] = []; f["auto"] = true
	Save.d["items"]["kibble"] = 14
	rec["needs"]["food"] = 70.0; rec["needs_t"] = now - 3.0 * 86400.0; rec.erase("starve")
	var ev := Econ.catch_up_all()
	ok.call(ev.is_empty() and Care.starve_h(rec) == 0.0 and Care.need(rec, "food") > 0.0, "3 days away with an auto hopper and kibble: fed (food %d, %d kibble left)" % [int(Care.need(rec, "food")), Econ.pantry("kibble")])
	# 5. starving, with nothing to eat: the timeline
	Save.d["feeders"] = []
	Save.d["items"]["kibble"] = 0
	var line: Array = []
	var died_at := -1.0
	for days in [0.5, 1.0, 2.0, 3.0, 4.0, 5.0]:
		var r2: Dictionary = rec.duplicate(true)
		r2["uid"] = "starve%d" % int(days * 10)
		r2["needs"] = {"food": 70.0, "energy": 80.0, "joy": 70.0, "clean": 75.0}
		r2.erase("starve")
		r2["needs_t"] = now - days * 86400.0
		Save.d["roster"] = [r2]
		var ev2 := Econ.catch_up_all()
		var st := Care.starve_stage(r2) if not ev2.any(func(e): return e["kind"] == "died") else "dead"
		if st == "dead" and died_at < 0.0: died_at = days
		line.append("%.1fd: %s (food %d, %.0fh starving, trust %d)" % [days, st if st != "" else "fine", int(Care.need(r2, "food")), Care.starve_h(r2), int(r2["trust"])])
	print("ECON  starving timeline: " + "  |  ".join(line))
	ok.call(died_at >= 3.0 and died_at <= 5.0, "unfed with no feeder, a kin dies after several days (day %.1f)" % died_at)
	ok.call(Econ.graves().size() >= 1 and String(Econ.graves()[0]["cause"]) == "starved" and String(Econ.graves()[0]["name"]) == "Pip", "a grave with its name (%d graves, %d memories)" % [Econ.graves().size(), (Econ.graves()[0]["mem"] as Array).size() if Econ.graves().size() > 0 else 0])
	# 6. the Soul Shrine brings one back, changed
	var g: Dictionary = Econ.graves()[Econ.graves().size() - 1]
	ok.call(Econ.keep_soul(g) != "", "no shrine yet: can't keep a soul")
	Save.d["buildings"].append("shrine")
	Save.d["valuables"]["soul_ember"] = 1
	Save.d["gems"] = 500
	ok.call(Econ.keep_soul(g) == "" and g["soul"], "soul kept in the shrine")
	var before: Dictionary = (g["rec"] as Dictionary).duplicate(true)
	before["level"] = 6
	g["rec"]["level"] = 6; g["level"] = 6
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var back := Econ.revive(g, rng)
	var tdiff := 0.0
	for t in before["traits"]: tdiff += absf(float(before["traits"][t]) - float(back["traits"].get(t, 0.0)))
	print("ECON  revived %s %s: level %d -> %d, trust %d -> %d, traits moved %.2f, memories %d -> %d, ghost=%s, likes %s -> %s" % [back["name"], back["title"], int(before["level"]), int(back["level"]), int(before["trust"]), int(back["trust"]), tdiff, (before["memory"] as Array).size(), (back["memory"] as Array).size(), back.get("ghost", false), str(before.get("likes", {}).get("food", "")), str(back["likes"]["food"])])
	ok.call(not back.is_empty() and back["ghost"] and String(back["title"]) != "" and int(back["level"]) == 4 and tdiff > 0.05 and Save.d["roster"].has(back) and not Econ.graves().has(g) and Econ.embers() == 0, "revived kin comes back changed")
	# an old save (from before the armory and feeders) loads and gets them filled in
	var old := Save.fresh()
	for k in ["armory", "raid_out", "loadout", "valuables", "feeders", "graves", "arm_lvl", "scrap", "feeder_inv",
			"feeder_given"]:
		old.erase(k)
	var orec := Save.new_kin("zapple", "Oldie")
	orec.erase("starve")
	old["roster"] = [orec]
	Save.d = old
	Econ.ensure()
	Care.catch_up(orec)
	ok.call(Econ.armory().is_empty() and Econ.feeders().size() == 1 and Econ.graves().is_empty()
			and Econ.pack_cap() == Equal.base_pack() and Care.starve_stage(orec) == ""
			and Equal.take_loadout(0).is_empty(),
			"an old save loads: a first trough, empty armory, %d-slot backpack" % Econ.pack_cap())
	print("ECON DONE failures: %d" % bad[0])
	get_tree().quit()

## Test: every weapon against a standing target at a couple of ranges, tapping and (for swords)
## charging, and prints the damage per second it actually lands.
func _weapon_check() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weapon-check="): only = a.substr(15)
	for ad in Arch.ids():
		var wid := Arch.signature(String(ad))
		if only != "" and wid != only:
			continue
		var cls := Arch.weight(String(ad))
		var wd: Dictionary = Data.weapon_stats(wid)
		var modes: Array = ["tap", "charge"] if wd.has("charge_time") else ["hold"]
		for mode in modes:
			for dist in ([1.6] if wd.get("melee", false) else ([1.5, 3.0] if wd.has("pellets") else [3.0, float(wd["range"]) * 0.8])):
				var m := Match.new()
				add_child(m)
				m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "weapon": wid, "cls": cls, "arch": ad})
				m.set_process(false)
				var P: Hunter = m.player
				var T: Hunter = null
				var home := Vector3.ZERO
				# find flat open ground for both
				for tries in 400:
					# the training island first; long sightlines may need the open ground elsewhere
					var at: Vector3 = m.world.random_ground(m.world.island_of(P.pos.x, P.pos.z)) if tries < 200 else m.world.random_ground()
					var to := at + Vector3(dist, 0, 0)
					var ok := true
					for k in 9:
						var q := at.lerp(to, k / 8.0)
						if m.world.is_block(q.x, q.z) or absf(m.world.ground_at(q.x, q.z) - at.y) > 0.01: ok = false
					if ok:
						home = at
						P.teleport(at)
						T = m.make_hunter("T", 5, "medium", "Target", "idle", {}, to)
						break
				if T == null:
					print("WCHECK %s: no spot" % wid); m.queue_free(); continue
				T.max_hp = 100000.0; T.hp = T.max_hp; T.armor = 0.0; T.max_armor = 0.0
				for mb in m.mobs: mb.queue_free()
				m.mobs.clear()
				var t := 0.0
				var dur := 6.0
				while t < dur:
					T.teleport(P.pos + Vector3(dist, 0, 0)); T.vel = Vector3.ZERO
					P.inp["aim"] = T.pos + Vector3(0, 0.9, 0); P.inp["aim_y"] = T.pos.y
					if mode == "tap": P.inp["fire"] = int(t / 0.05) % 2 == 0
					elif mode == "charge":
						# hold until the charge is full, then let go for a moment
						if P.inp["fire"] and P.charge_k() >= 1.0: P.inp["fire"] = false; P.set_meta("rel", 0.5)
						elif not P.inp["fire"]:
							P.set_meta("rel", float(P.get_meta("rel", 0.0)) - Match.DT)
							if float(P.get_meta("rel", 0.0)) <= 0.0:
								P.inp["fire"] = true
								P.teleport(home); P.vel = Vector3.ZERO     # lunges carry you off the test strip
					else: P.inp["fire"] = true
					m.mobs.clear()
					m.step(Match.DT)
					t += Match.DT
				var dealt := T.max_hp - T.hp
				print("WCHECK %-12s %-6s dist %4.1f  dps %6.1f  (%d in %ds)" % [wid, mode, dist, dealt / dur, int(dealt), int(dur)])
				m.queue_free()
				await get_tree().process_frame
	get_tree().quit()

## Headless check for the ability verbs: each one fired at a dummy rival, asserting what it should
## do (a hook drags them in, a wall stops a shot, a mirror sends it back, a slam throws them up...).
var _ac_fail := 0
func _ac(name: String, ok: bool, info := "") -> void:
	print("ACHECK %-26s %s  %s" % [name, "PASS" if ok else "FAIL", info])
	if not ok: _ac_fail += 1

func _ac_setup(dist: float, extra_t := false) -> Array:
	var m := Match.new()
	add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "weapon": "rifle", "cls": "medium"})
	m.set_process(false)
	var P: Hunter = m.player
	P.set_arch("")         # these are the old weapon RMBs and class dodges (the verbs stay; archetypes: --archetype-check)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	# a flat, open strip of ground for the test: the training map is small and busy, so the logical
	# tiles around the spawn are levelled (headless, nothing is drawn)
	var W = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-3, 4):
		for dx in range(-6, int(dist) + 7):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	var home := Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.hp = P.max_hp
	var T: Hunter = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(dist, 0, 0))
	T.max_hp = 10000.0; T.hp = T.max_hp; T.armor = 0.0; T.max_armor = 0.0
	var T2: Hunter = null
	if extra_t:
		T2 = m.make_hunter("T2", 5, "medium", "Target2", "idle", {}, home + Vector3(dist + 2.0, 0, 0))
		T2.max_hp = 10000.0; T2.hp = T2.max_hp; T2.armor = 0.0; T2.max_armor = 0.0
	for i in 5: m.step(Match.DT)
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0); P.inp["aim_y"] = T.pos.y
	if OS.get_cmdline_user_args().has("--ac-debug"):
		print("  setup home=%s P=%s T=%s gP=%.2f gT=%.2f Tgr=%s Pgr=%s" % [home, P.pos, T.pos, m.world.ground_at(P.pos.x, P.pos.z), m.world.ground_at(T.pos.x, T.pos.z), T.grounded, P.grounded])
	return [m, P, T, T2]

func _ac_run(m: Match, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(Match.DT); t += Match.DT

func _ac_glove(P: Hunter, gid: String, rar := 1) -> void:
	P.gear[0] = {"id": gid, "rar": rar}
	P.gear_cd[0] = 0.0
	P.m.use_gear(P, 0)

func _ability_check() -> void:
	var r: Array
	var m: Match; var P: Hunter; var T: Hunter
	# 1. Hook glove drags the target in
	r = _ac_setup(7.0); m = r[0]; P = r[1]; T = r[2]
	var d0 := P.flat_dist(T)
	_ac_glove(P, "grapple")
	_ac_run(m, 1.0)
	_ac("hook pulls target", P.flat_dist(T) < 3.0, "dist %.1f -> %.1f" % [d0, P.flat_dist(T)])
	m.queue_free(); await get_tree().process_frame
	# 2. Barrier wall stops an enemy shot
	r = _ac_setup(7.0); m = r[0]; P = r[1]; T = r[2]
	P.inp["aim"] = P.pos + Vector3(2.5, 0.9, 0)
	_ac_glove(P, "barrier")
	var whp: float = m.verbs.walls[0]["hp"] if not m.verbs.walls.is_empty() else -1.0
	var php := P.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 20.0, 0.5, 0.15, Color.RED, {})
	_ac_run(m, 0.5)
	var whp2: float = m.verbs.walls[0]["hp"] if not m.verbs.walls.is_empty() else -1.0
	_ac("wall blocks a shot", P.hp >= php and whp2 < whp and whp > 0.0, "wall hp %.0f -> %.0f, player hp %.0f -> %.0f" % [whp, whp2, php, P.hp])
	# a barrier stops bodies too: walk the target into it
	var tx0 := T.pos.x
	_ac_run(m, 1.2, func(): T.inp["move"] = Vector2(-1, 0))
	_ac("wall blocks movement", T.pos.x > P.pos.x + 2.4, "target x %.1f (wall at %.1f)" % [T.pos.x - P.pos.x, 2.5])
	m.queue_free(); await get_tree().process_frame
	# 3. Mirror glove reflects a shot back at the shooter
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	_ac_glove(P, "bubble")
	php = P.hp
	var thp := T.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 20.0, 0.6, 0.15, Color.RED, {})
	_ac_run(m, 0.6)
	_ac("reflect returns a shot", P.hp >= php and T.hp < thp, "shooter took %.0f, player took %.0f" % [thp - T.hp, php - P.hp])
	m.queue_free(); await get_tree().process_frame
	# 4. Riposte (frontal) parries a melee swing and stuns the swinger
	r = _ac_setup(1.4); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("riposte"))
	P.runner.use("utility", {})
	m.spawn_shot(T, T.pos + Vector3(-0.3, 0.95, 0), Vector2(-40, 0), 10.0, 0.08, 0.3, Color.RED, {"melee": true})
	_ac_run(m, 0.15)
	_ac("riposte parries melee", T.stun_t > 0.3, "attacker stun %.2f" % T.stun_t)
	m.queue_free(); await get_tree().process_frame
	# 5. Earthshatter: leap, knock up; an airborne target is spiked
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("earthshatter"))
	P.runner.use("utility", {})
	var acc := {"top": 0.0, "hits": 0, "last": 0.0}
	var g := T.pos.y
	_ac_run(m, 1.0, func(): acc["top"] = maxf(acc["top"], T.pos.y - g))
	_ac("slam knocks up", acc["top"] > 0.5 and T.hp < T.max_hp, "rose %.2fm, took %.0f" % [acc["top"], T.max_hp - T.hp])
	m.queue_free(); await get_tree().process_frame
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("earthshatter"))
	P.runner.use("utility", {})
	_ac_run(m, 0.42)
	T.vel.y = 7.0; T.grounded = false
	_ac_run(m, 0.3)
	_ac("slam spikes airborne", T.stun_t > 0.4, "stun %.2f, took %.0f" % [T.stun_t, T.max_hp - T.hp])
	m.queue_free(); await get_tree().process_frame
	# 6. Leash Bolt: tether snaps when stretched
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("leash_bolt"))
	P.runner.use("utility", {})
	_ac_run(m, 0.4)
	var tethered := not m.verbs.tethers.is_empty()
	thp = T.hp
	T.teleport(P.pos + Vector3(8.0, 0, 0))
	_ac_run(m, 0.2)
	_ac("tether snaps", tethered and T.hp < thp - 15.0 and T.stun_t > 0.5, "tethered=%s snap dmg %.0f stun %.2f" % [tethered, thp - T.hp, T.stun_t])
	m.queue_free(); await get_tree().process_frame
	# 7. Tripwire Mine roots whoever steps on it
	r = _ac_setup(4.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("tripwire_mine"))
	P.inp["aim"] = T.pos + Vector3(-2.0, 0, 0)      # clear of the target's hitbox (item 46 sizes)
	P.runner.use("utility", {})
	_ac_run(m, 1.0)
	var before_root := T.root_t
	_ac_run(m, 1.0, func(): T.inp["move"] = Vector2(-1, 0))
	_ac("trap roots on step", before_root <= 0.0 and (T.root_t > 0.0 or T.hp < T.max_hp) and m.verbs.traps.is_empty(), "root %.2f, took %.0f" % [T.root_t, T.max_hp - T.hp])
	m.queue_free(); await get_tree().process_frame
	# 8. Moon Swap (kin E, performed from the shoulder): trade places
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	var pa := P.pos; var ta := T.pos
	KinExec.cast(KinLib.ability("moon_swap"), KinExec.make_cx(m, P, null, P, T.pos, 1.0, "k1", "moon_swap"))
	_ac_run(m, 0.5)
	_ac("swap trades places", P.flat_dist(ta) < 1.2 and T.flat_dist(pa) < 1.2, "player at %.1f from target's spot" % P.flat_dist(ta))
	m.queue_free(); await get_tree().process_frame
	# 9. Fissure glove: the line throws the target up
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	_ac_glove(P, "quake")
	acc["top"] = 0.0; g = T.pos.y
	_ac_run(m, 1.0, func(): acc["top"] = maxf(acc["top"], T.pos.y - g))
	_ac("fissure knocks up", acc["top"] > 0.4 and T.hp < T.max_hp, "rose %.2f" % acc["top"])
	m.queue_free(); await get_tree().process_frame
	# 10. Vortex glove: drags the target to the centre
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	var ctr := T.pos + Vector3(2.0, 0, 0)
	P.inp["aim"] = ctr
	_ac_glove(P, "shock")
	var dc0 := T.flat_dist(ctr)
	_ac_run(m, 1.0)
	_ac("vortex pulls in", T.flat_dist(ctr) < dc0 - 0.6, "to centre %.1f -> %.1f" % [dc0, T.flat_dist(ctr)])
	m.queue_free(); await get_tree().process_frame
	# 11. Razor Disc: out and back, hitting twice
	r = _ac_setup(4.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("razor_disc"))
	P.runner.use("utility", {})
	acc["hits"] = 0; acc["last"] = T.hp
	_ac_run(m, 1.6, func():
		if T.hp < float(acc["last"]) - 0.5: acc["hits"] = int(acc["hits"]) + 1
		acc["last"] = T.hp)
	_ac("boomerang hits twice", int(acc["hits"]) >= 2, "%d hits" % acc["hits"])
	m.queue_free(); await get_tree().process_frame
	# 12. Rail Charge: a full charge pierces two in a line
	r = _ac_setup(5.0, true); m = r[0]; P = r[1]; T = r[2]
	var T2: Hunter = r[3]
	P.runner.set_slot("utility", Content.ability("rail_charge"))
	P.runner.use("utility", {"charge": 1.0})
	_ac_run(m, 0.4)
	_ac("rail pierces", T.hp < T.max_hp - 20.0 and T2.hp < T2.max_hp - 20.0, "%.0f and %.0f" % [T.max_hp - T.hp, T2.max_hp - T2.hp])
	# and the player's held charge path: press, hold 1s, let go
	P.runner.reset()
	T.hp = T.max_hp
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.inp["sec"] = true; P.inp["sec_hold"] = true
	_ac_run(m, 1.0, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	_ac_run(m, 0.3)
	_ac("rail hold-to-charge", T.hp < T.max_hp - 25.0, "took %.0f" % (T.max_hp - T.hp))
	# the same hold as an archetype (Sparkle's Coilshot): the shared wind-up fills, ticks full, punches out
	P.reclass("light", "mage"); P.unlock_all()
	_ac_run(m, 0.3)      # (the swap to a Light body settles on the ground first)
	T.hp = T.max_hp
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.ak.cd["rmb"] = 0.0; P.ak.ch_rmb = 1.0
	P.inp["sec_hold"] = true; P.ak.press_rmb()
	var hk_mid := [-1.0]
	_ac_run(m, 1.3, func():
		P.inp["sec_hold"] = true
		if hk_mid[0] < 0.0 and P.ak.rmb_t > 0.6: hk_mid[0] = P.ak.charge_k())
	P.inp["sec_hold"] = false
	_ac_run(m, 0.3)
	_ac("archetype hold wind-up", hk_mid[0] > 0.2 and P.ak.charge_fulls >= 1 and P.ak.charge_last > 0.9 and T.hp < T.max_hp - 10.0, "mid %.2f fulls %d took %.0f" % [hk_mid[0], P.ak.charge_fulls, T.max_hp - T.hp])
	m.queue_free(); await get_tree().process_frame
	# 13. Breach: throws the target back and you the other way
	r = _ac_setup(2.5); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("breach"))
	var p0 := P.pos; var t0 := T.pos
	P.runner.use("utility", {})
	var pv := P.vel
	_ac_run(m, 0.5)
	print("   breach vel after cast ", pv)
	_ac("breach knocks both apart", T.pos.x - t0.x > 1.5 and p0.x - P.pos.x > 1.0, "target +%.1f, you -%.1f" % [T.pos.x - t0.x, p0.x - P.pos.x])
	m.queue_free(); await get_tree().process_frame
	# 14. Bulwark: a shield that follows you and stops shots
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("bulwark"))
	P.runner.use("utility", {})
	php = P.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 20.0, 0.5, 0.15, Color.RED, {})
	_ac_run(m, 0.4)
	_ac("bulwark blocks", P.hp >= php and not m.verbs.walls.is_empty(), "")
	m.queue_free(); await get_tree().process_frame
	# 15. Shadow Step: knife, then you're behind them
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	P.runner.set_slot("utility", Content.ability("shadow_step"))
	P.runner.use("utility", {})
	_ac_run(m, 0.4)
	_ac("shadow step lands behind", P.pos.x > T.pos.x and P.flat_dist(T) < 1.8 and P.crit_t > 0.0, "x %.1f vs %.1f, target took %.0f" % [P.pos.x, T.pos.x, T.max_hp - T.hp])
	m.queue_free(); await get_tree().process_frame
	# 16. Ice Bridge: over the abyss
	r = _ac_setup(4.0); m = r[0]; P = r[1]; T = r[2]
	var edge := Vector3.INF; var ed := Vector2.ZERO
	for i in 4000:
		var q: Vector3 = m.world.random_ground()
		for dd in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var q2 := q + Vector3(dd.x, 0, dd.y) * 1.2
			if m.world.is_void(q2.x, q2.z) and not m.world.is_block(q.x, q.z):
				edge = q; ed = dd; break
		if edge != Vector3.INF: break
	P.teleport(edge); P.inp["aim"] = edge + Vector3(ed.x, 0, ed.y) * 8.0
	_ac_glove(P, "frost")
	var ground_ok: bool = not m.world.is_void(edge.x + ed.x * 3.0, edge.z + ed.y * 3.0)
	_ac("ice bridge makes ground", not m.verbs.terrain.is_empty() and ground_ok, "%d tiles" % (m.verbs.terrain[0]["tiles"].size() if not m.verbs.terrain.is_empty() else 0))
	_ac_run(m, 7.5)
	_ac("ice bridge melts", m.verbs.terrain.is_empty() and m.world.is_void(edge.x + ed.x * 3.0, edge.z + ed.y * 3.0), "")
	m.queue_free(); await get_tree().process_frame
	# 17. Prism Wall (kin E) reflects shots back
	r = _ac_setup(7.0); m = r[0]; P = r[1]; T = r[2]
	P.inp["aim"] = P.pos + Vector3(2.5, 0, 0)
	KinExec.cast(KinLib.ability("prism_wall"), KinExec.make_cx(m, P, null, P, P.pos + Vector3(2.5, 0, 0), 1.0, "k1", "prism_wall"))
	thp = T.hp; php = P.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 20.0, 0.6, 0.15, Color.RED, {})
	_ac_run(m, 0.6)
	_ac("prism wall reflects", T.hp < thp and P.hp >= php, "shooter took %.0f" % (thp - T.hp))
	m.queue_free(); await get_tree().process_frame
	# 18. Stinger Hook (kin E): yanks to the caster and blights
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	KinExec.cast(KinLib.ability("stinger_hook"), KinExec.make_cx(m, P, null, P, T.pos, 1.0, "k1", "stinger_hook"))
	_ac_run(m, 0.8)
	_ac("stinger hook yanks + blights", P.flat_dist(T) < 3.0 and T.blight_t > 0.0, "dist %.1f blight %.1f" % [P.flat_dist(T), T.blight_t])
	m.queue_free(); await get_tree().process_frame
	# 19. Gravity Slam (kin E) pulls in and lifts
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	var gk: Kin = P.kin
	if gk:
		gk.teleport(P.pos + Vector3(1, 0, 0)); gk.state = "active"
		var land := T.pos + Vector3(1.5, 0, 0)
		KinExec.cast(KinLib.ability("slam"), KinExec.make_cx(m, gk, gk, P, land, 1.0, "k1", "slam"))
		acc["top"] = 0.0; g = T.pos.y
		var dl := T.flat_dist(land)
		var mind := {"d": dl, "v": 0.0}
		var to_c := Vector2(land.x - T.pos.x, land.z - T.pos.z).normalized()
		_ac_run(m, 1.0, func():
			acc["top"] = maxf(acc["top"], T.pos.y - g)
			mind["v"] = maxf(float(mind["v"]), Vector2(T.vel.x, T.vel.z).dot(to_c))
			mind["d"] = minf(mind["d"], T.flat_dist(land)))
		# (the kin itself lands in the crater, so the pull ends against its body)
		_ac("gravity slam pulls + lifts", acc["top"] > 0.4 and float(mind["v"]) > 3.0, "rose %.2f, pulled at %.1fm/s toward the crater (kin %s)" % [acc["top"], mind["v"], gk.state])
	m.queue_free(); await get_tree().process_frame
	# 20. Dashes: class verbs (no kin changes a dash: --boki-dash-check). Each starts grounded at the same spot, 3m short of the target.
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	var home2 := P.pos
	var ready := func(cls: String, at: Vector3, mv: Vector2) -> void:
		P.teleport(at); P.vel = Vector3.ZERO
		T.teleport(home2 + Vector3(6.0, 0, 0)); T.vel = Vector3.ZERO
		T.burn_t = 0.0; T.blight_t = 0.0; T.slow_t = 0.0; T.stun_t = 0.0; T.root_t = 0.0; T.knock_t = 0.0
		P.cls = cls; P.dodge_def = Content.class_dodge(cls)
		P.kin = null
		_ac_run(m, 0.3)
		P.dashes = P.max_dashes(); P.ex_cd = 0.0; P.roll_t = 0.0
		P.inp["move"] = mv
	# Light: phase step, a shot fired through you mid-step does nothing
	ready.call("light", home2, Vector2(1, 0))
	var php2 := P.hp
	P.do_dash()
	m.spawn_shot(T, P.pos + Vector3(1.0, 0.95, 0), Vector2(-30, 0), 20.0, 0.3, 0.15, Color.RED, {})
	_ac_run(m, 0.25)
	_ac("light phase: shots pass", P.phase_t >= 0.0 and P.hp >= php2, "hp %.0f -> %.0f" % [php2, P.hp])
	# Medium: the roll reloads
	ready.call("medium", home2, Vector2(1, 0))
	P.ammo = 0
	P.do_dash()
	_ac("medium roll reloads", P.ammo > 0, "ammo %d" % P.ammo)
	# Heavy: the charge bowls the target back
	ready.call("heavy", T.pos + Vector3(-2.2, 0, 0), Vector2(1, 0))
	var tx := T.pos.x
	P.do_dash()
	_ac_run(m, 0.5)
	_ac("heavy charge knocks back", T.pos.x - tx > 1.0 and T.hp < T.max_hp, "target pushed %.1f, took %.0f" % [T.pos.x - tx, T.max_hp - T.hp])
	m.queue_free(); await get_tree().process_frame
	# 21. Every ability and active glove runs without errors (watch the log for SCRIPT ERROR)
	r = _ac_setup(5.0); m = r[0]; P = r[1]; T = r[2]
	var n := 0
	for id in Content.ids("abilities"):
		var ad := Content.ability(id)
		P.teleport(T.pos + Vector3(-5, 0, 0)); P.vel = Vector3.ZERO
		P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
		Effects.run(ad.effects, P, {"slot": "utility", "ability": id, "charge": 0.7})
		_ac_run(m, 0.8)
		n += 1
	for gid in Gear.ALL:
		if Gear.active(gid):
			P.teleport(T.pos + Vector3(-5, 0, 0)); P.vel = Vector3.ZERO
			P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
			for rar in [1, 4]:
				_ac_glove(P, gid, rar)
				_ac_run(m, 0.6)
			n += 1
	for kid in KinLib.lib()["abilities"]:
		P.teleport(T.pos + Vector3(-5, 0, 0)); P.vel = Vector3.ZERO
		KinExec.cast(KinLib.ability(kid), KinExec.make_cx(m, P, null, P, T.pos, 1.0, "k1", kid))
		_ac_run(m, 0.8)
		n += 1
	_ac("all abilities run", true, "%d ran" % n)
	m.queue_free(); await get_tree().process_frame
	# 22. Ranks: a rank-3 slot makes the same verb stronger and recharge faster; a glove never ranks (Gloves)
	r = _ac_setup(7.0); m = r[0]; P = r[1]; T = r[2]
	P.inp["aim"] = P.pos + Vector3(2.5, 0.9, 0)
	_ac_glove(P, "barrier")
	var hp1: float = m.verbs.walls[-1]["hp"] if not m.verbs.walls.is_empty() else 0.0
	var cd1: float = P.gear_cd[0]
	P.skill_pts = 5      # spent on the hero's own abilities (the level stays, so level growth stays out of it)
	P._bot_spend()
	_ac_glove(P, "barrier")
	var hp3: float = m.verbs.walls[-1]["hp"] if not m.verbs.walls.is_empty() else 0.0
	_ac("a glove is as strong after spending skill points (no ranks)", absf(hp3 - hp1) < 0.01
			and absf(float(P.gear_cd[0]) - cd1) < 0.01 and not P.slot_lv.has("gear"),
			"wall hp %.0f -> %.0f, cooldown %.1f -> %.1f" % [hp1, hp3, cd1, float(P.gear_cd[0])])
	P.runner.set_slot("utility", Content.ability("leash_bolt"))
	P.slot_lv["sec"] = 3
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.runner.use("utility", {"level": P.ability_level("sec")})
	_ac("rank 3 RMB cooldown", P.runner.cd_left("utility") < Content.ability("leash_bolt").cooldown * 0.85, "%.1fs" % P.runner.cd_left("utility"))
	m.queue_free(); await get_tree().process_frame
	print("ACHECK DONE, failures: ", _ac_fail)
	get_tree().quit()

# ------------------------------------------------------------------ kin grammar runtime check
## Headless check of the kin grammar's runtime (docs/KIN_GRAMMAR.md, Phase 2): each kin's abilities
## run from their parts, diminishing returns and stun immunity, no self-trigger, the caps, carry
## modes, the merge's unlock, timer and cooldown, and owner bonuses. Prints GRT PASS/FAIL lines.
var _grt_fail := 0
func _grt(name: String, ok: bool, info := "") -> void:
	if has_meta("grt_T") and is_instance_valid(get_meta("grt_T")) and OS.get_cmdline_user_args().has("--grt-debug"): print("   T at %s" % str((get_meta("grt_T") as Hunter).pos))
	print("GRT %-34s %s  %s" % [name, "PASS" if ok else "FAIL", info])
	if not ok: _grt_fail += 1

## Gives the test player a fresh kin of this species, settled on its shoulder.
func _grt_kin(m: Match, P: Hunter, sp: String, rec_extra := {}) -> Kin:
	if P.kin:
		var o: Kin = P.kin
		KinMerge.end(P, "test")
		o.dead = true
		m.kins.erase(o)
		o.queue_free()
		P.kin = null
	var rec := Save.new_kin(sp)
	rec["trust"] = 95.0
	for kk in rec_extra: rec[kk] = rec_extra[kk]
	var k := m.give_kin(P, rec)
	k.stow()
	k.settle = 1.0
	k.brain.think_t = 1e9        # the test casts by hand; its own AI stays quiet (tested on its own below)
	P.merge_cd = 0.0
	for i in 3: m.step(Match.DT)
	return k

## Puts the kin out on the field beside its hunter.
func _grt_out(k: Kin, at: Vector3) -> void:
	k.runner.reset()
	k.target = null
	k.teleport(at)
	k.state = "active"
	k.fly = {}
	k.settle = 0.0
	k.grounded = true

func _grt_reset(T: Hunter) -> void:
	T.hp = T.max_hp
	T.burn_t = 0.0; T.blight_t = 0.0; T.slow_t = 0.0; T.stun_t = 0.0; T.root_t = 0.0; T.knock_t = 0.0
	T.dr = {}; T.cc_immune_t = 0.0; T.dr_stun = false; T.vuln_t = 0.0; T.vel = Vector3.ZERO

## A test-only ability from a dictionary (parsed by the checker like any file).
func _grt_spec(d: Dictionary) -> AbilitySpec:
	var rep := GrammarReport.new()
	var a := AbilitySpec.parse(d, rep)
	if not rep.ok():
		print("GRT spec errors: ", rep.errors)
	return a

func _grammar_runtime_check() -> void:
	var r: Array
	var m: Match; var P: Hunter; var T: Hunter
	var acc := {}
	r = _ac_setup(6.0); m = r[0]; P = r[1]; T = r[2]
	set_meta("grt_T", T)
	var home := P.pos
	# ---- 1. each of the six kin: its E and its auto active, run from their parts
	var k := _grt_kin(m, P, "cindle")
	_grt_out(k, home + Vector3(1.0, 0, 0))
	var d0 := k.flat_dist(T)
	_grt("cindle E Stinger Hook cast", k.use_ability("k1", T.pos), "")
	_ac_run(m, 0.8)
	_grt("cindle E hook yanks + poisons", k.flat_dist(T) < d0 - 2.0 and T.blight_t > 0.0 and T.burn_t > 0.0, "dist %.1f -> %.1f, blight %.1f burn %.1f" % [d0, k.flat_dist(T), T.blight_t, T.burn_t])
	_grt_reset(T); T.teleport(home + Vector3(6, 0, 0))
	_grt_out(k, home + Vector3(1.0, 0, 0))
	var dash_ok := k.use_ability("k2", T.pos)
	_ac_run(m, 0.6)
	_grt("cindle auto Stinger Dash", dash_ok and T.hp < T.max_hp and T.burn_t > 0.0, "took %.0f burn %.1f" % [T.max_hp - T.hp, T.burn_t])
	_grt_reset(T); T.teleport(home + Vector3(6, 0, 0))
	k = _grt_kin(m, P, "pebbit")
	_grt_out(k, home + Vector3(1.0, 0, 0))
	acc["top"] = 0.0
	var g0 := T.pos.y
	k.use_ability("k1", T.pos + Vector3(-1.0, 0, 0))
	_ac_run(m, 1.2, func(): acc["top"] = maxf(float(acc["top"]), T.pos.y - g0))
	_grt("pebbit E Gravity Slam", T.hp < T.max_hp and float(acc["top"]) > 0.3, "took %.0f, rose %.2f" % [T.max_hp - T.hp, acc["top"]])
	k.stow()
	var nw := m.verbs.walls.size()
	k.use_ability("k2", P.pos)
	_grt("pebbit auto Mass Guard wall", m.verbs.walls.size() == nw + 1 and bool(m.verbs.walls[-1]["follow"]), "%d walls" % m.verbs.walls.size())
	_ac_run(m, 3.5)
	_grt_reset(T)
	k = _grt_kin(m, P, "puddlet")
	_grt_out(k, home + Vector3(0.5, 0, 1.0))
	k.use_ability("k1", home + Vector3(2.5, 0, 0))
	var thp := T.hp; var php := P.hp
	m.spawn_shot(T, T.pos + Vector3(-0.6, 0.95, 0), Vector2(-30, 0), 20.0, 0.6, 0.15, Color.RED, {})
	_ac_run(m, 0.6)
	_grt("puddlet E Prism Wall reflects", T.hp < thp and P.hp >= php, "shooter took %.0f" % (thp - T.hp))
	k.stow()
	P.shield = 0.0
	var nm := m.verbs.mirrors.size()
	k.use_ability("k2", P.pos)
	_grt("puddlet auto Refraction", P.shield >= 19.0 and m.verbs.mirrors.size() > nm, "shield %.0f, mirrors %d" % [P.shield, m.verbs.mirrors.size()])
	_ac_run(m, 5.0)
	_grt_reset(T)
	k = _grt_kin(m, P, "burrlet")
	_grt_out(k, home + Vector3(1.0, 0, 0))
	var ntr := m.verbs.traps.size()
	var nf := m.fields.list.size()
	k.use_ability("k1", T.pos + Vector3(-3.5, 0, 0))
	_grt("burrlet E Puffcap Mines: 3 traps", m.verbs.traps.size() - ntr == 3, "%d" % (m.verbs.traps.size() - ntr))
	_ac_run(m, 0.8)
	acc["root"] = 0.0
	_ac_run(m, 1.6, func():
		T.inp["move"] = Vector2(-1, 0)
		acc["root"] = maxf(float(acc["root"]), T.root_t))
	T.inp["move"] = Vector2.ZERO
	_grt("burrlet E mine roots + spore cloud", float(acc["root"]) > 0.5 and m.fields.list.size() > nf, "root %.2f, took %.0f" % [acc["root"], T.max_hp - T.hp])
	_ac_run(m, 3.5)
	_grt_reset(T); T.teleport(home + Vector3(6, 0, 0))
	_grt_out(k, home + Vector3(2.0, 0, 0))
	nf = m.fields.list.size()
	k.use_ability("k2", T.pos)
	_ac_run(m, 1.0)
	_grt("burrlet auto Spore Patch zone", m.fields.list.size() > nf and T.slow_t > 0.0 and T.hp < T.max_hp, "slow %.2f took %.0f" % [T.slow_t, T.max_hp - T.hp])
	_ac_run(m, 3.5)
	_grt_reset(T)
	k = _grt_kin(m, P, "zapple")
	_grt_out(k, home + Vector3(1.0, 0, 0))
	k.use_ability("k1", T.pos)
	_ac_run(m, 0.05)
	_grt("zapple E Echo Chain stuns", T.stun_t > 0.2 and T.hp < T.max_hp, "stun %.2f took %.0f" % [T.stun_t, T.max_hp - T.hp])
	_ac_run(m, 1.5)
	_grt_reset(T)
	k.stow()
	P.crit_t = 0.0
	k.use_ability("k2", P.pos)
	_grt("zapple auto Echolocate", T.reveal_t > 0.0 and P.crit_t > 0.0, "reveal %.1f crit %.1f" % [T.reveal_t, P.crit_t])
	_grt_reset(T)
	k = _grt_kin(m, P, "wisplet")
	var pa := P.pos; var ta := T.pos
	k.use_ability("k1", T.pos)
	_ac_run(m, 0.6)
	_grt("wisplet E Moon Swap trades places", P.flat_dist(ta) < 1.2 and T.flat_dist(pa) < 1.2, "player %.1f from target's spot" % P.flat_dist(ta))
	P.teleport(home); T.teleport(home + Vector3(6, 0, 0)); _grt_reset(T)
	_ac_run(m, 0.2)
	k.use_ability("k2", P.pos)
	_grt("wisplet auto Moonlift lifts you", P.vel.y > 8.0, "vel.y %.1f" % P.vel.y)
	_ac_run(m, 2.0)
	P.teleport(home); P.vel = Vector3.ZERO
	# the rare kin run too
	var rare_ok := true
	for sp in ["cairnback", "hivara", "zephyrak"]:
		k = _grt_kin(m, P, sp)
		_grt_out(k, home + Vector3(1.0, 0, 0))
		var a1 := k.use_ability("k1", T.pos)
		_ac_run(m, 1.0)
		_grt_out(k, home + Vector3(1.0, 0, 0))
		var a2 := k.use_ability("k2", T.pos if sp != "cairnback" else P.pos)
		_ac_run(m, 1.0)
		rare_ok = rare_ok and a1 and a2
		acc[sp] = "%s E %s auto %s, took %.0f" % [sp, a1, a2, T.max_hp - T.hp]
		_grt_reset(T)
	_grt("rare Boki abilities cast", rare_ok, "%s; %s; %s" % [acc["cairnback"], acc["hivara"], acc["zephyrak"]])
	P.teleport(home); T.teleport(home + Vector3(6, 0, 0)); _ac_run(m, 3.5); _grt_reset(T)
	# (a zephyrak gust can leave the dummy flying: put it back on its mark, at rest)
	T.teleport(home + Vector3(6, 0, 0)); T.vel = Vector3.ZERO; T.knock_t = 0.0; T.grounded = true; _ac_run(m, 0.2)
	# ---- 2. diminishing returns and stun immunity
	T.hurt(0.1, P, {"stun": 1.0, "dr": true})
	var s1 := T.stun_t
	_ac_run(m, 1.1)
	var imm := T.cc_immune_t
	T.hurt(0.1, P, {"stun": 1.0, "dr": true})
	var s2 := T.stun_t
	_ac_run(m, 1.0)
	T.hurt(0.1, P, {"stun": 1.0, "dr": true})
	var s3 := T.stun_t
	_grt("DR: full stun, then immunity", s1 > 0.95 and imm > 0.5 and s2 <= 0.0, "stun %.2f, immune %.2f, stun during immunity %.2f" % [s1, imm, s2])
	_grt("DR: next stun is shorter", s3 > 0.5 and s3 < 0.7, "%.2f" % s3)
	_ac_run(m, 1.6)
	T.hurt(0.1, P, {"root": 1.0, "dr": true})
	var r1 := T.root_t
	_ac_run(m, 1.1)
	T.hurt(0.1, P, {"root": 1.0, "dr": true})
	var r2 := T.root_t
	_grt("DR: repeated root gets shorter", r1 > 0.95 and r2 > 0.5 and r2 < 0.7, "%.2f then %.2f" % [r1, r2])
	_grt_reset(T)
	T.hurt(0.1, P, {"slow": 1.0, "dr": true})
	var sl1 := T.slow_t
	T.hurt(0.1, P, {"slow": 1.0, "dr": true})
	var sl1b := T.slow_t
	_ac_run(m, 1.1)
	T.hurt(0.1, P, {"slow": 1.0, "dr": true})
	var sl2 := T.slow_t
	_grt("DR: slow refresh free, new slow weaker", sl1 > 0.95 and sl1b > 0.95 and sl2 > 0.7 and sl2 < 0.8, "%.2f, refresh %.2f, then %.2f" % [sl1, sl1b, sl2])
	_grt_reset(T)
	# a zone that tries to stun every 0.25s can't keep anyone locked down
	k = _grt_kin(m, P, "burrlet")
	var zs := _grt_spec({"grammar": 1, "id": "grt_stun_zone", "name": "Test Zone", "trigger": {"type": "on_cast"},
		"stages": [{"delivery": {"type": "zone", "origin": "aim", "radius": 2.5, "duration": 4, "every": 0.25}, "effects": [{"type": "stun", "duration": 1.0}]}]})
	KinExec.cast(zs, KinExec.make_cx(m, P, k, P, T.pos, 1.0, "k1", zs.id))
	acc["st"] = 0.0
	_ac_run(m, 4.0, func(): if T.stun_t > 0.0: acc["st"] = float(acc["st"]) + Match.DT)
	_grt("DR: a stunning zone can't lock", float(acc["st"]) < 2.2, "stunned %.2fs of 4s" % acc["st"])
	_grt_reset(T)
	# ---- 3. no ability triggers itself
	var trig := _grt_spec({"grammar": 1, "id": "grt_on_hit", "name": "Test Trigger", "trigger": {"type": "on_hit", "every": 1}, "cue": {"type": "foe_in_range"},
		"stages": [{"delivery": {"type": "burst", "origin": "aim", "radius": 1.5}, "effects": [{"type": "damage", "amount": 5}]}]})
	k.runner.set_slot("k2", trig)
	_grt_out(k, home + Vector3(5.0, 0, 0))
	k.melee_n = 1
	var self_fire := k.fire_trigger("on_hit", {"at": T.pos, "chain": ["grt_on_hit"]})
	var real_fire := k.fire_trigger("on_hit", {"at": T.pos, "chain": []})
	k.stow()       # (so it doesn't swing at the target itself)
	var mel0 := k.melee_n
	_ac_run(m, 0.3)
	_grt("no self-trigger", not self_fire and real_fire and k.melee_n == mel0, "own hit fired=%s, melee hit fired=%s, its hits counted as melee %d" % [self_fire, real_fire, k.melee_n - mel0])
	_grt_reset(T)
	# ---- 4. caps
	m.verbs.add_mirror(P, {"time": 1.0, "radius": 1.6, "dmg_k": 3.0})
	m.verbs.add_mirror(T, {"time": 1.0, "radius": 1.6, "dmg_k": 3.0})
	var kmax := 0.0
	for mr in m.verbs.mirrors: kmax = maxf(kmax, float(mr["k"]))
	php = P.hp; thp = T.hp
	m.spawn_shot(T, T.pos + Vector3(-0.8, 0.95, 0), Vector2(-30, 0), 20.0, 0.6, 0.15, Color.RED, {})
	_ac_run(m, 0.8)
	_grt("reflect power capped at 1.5", kmax <= KinRules.REFLECT_MAX + 0.001, "%.2f" % kmax)
	_grt("a reflected shot isn't reflected again", P.hp >= php and T.hp < thp and T.hp > thp - 31.0, "shooter took %.0f, you took %.0f" % [thp - T.hp, php - P.hp])
	_ac_run(m, 0.5); _grt_reset(T)
	KinRules.mark(T, "vulnerable", 3.0, 0.6)
	var vh := T.hp
	T.hurt(100.0, null, {})
	_grt("vulnerable capped at +35%", is_equal_approx(T.vuln_k, 0.35) and absf((vh - T.hp) - 135.0) < 1.0, "k %.2f, 100 dmg -> %.0f" % [T.vuln_k, vh - T.hp])
	_grt_reset(T)
	var hook := KinLib.ability("stinger_hook")
	var big := KinLib.effective(hook, "k1", KinLib.kin("cindle"), {"level": 1}, 1, {"stage": 0, "scale": {"range": 9.0}})
	var rng0 := float(hook.stages[0].delivery.params["range"])
	var rng1 := float(big.stages[0].delivery.params["range"])
	_grt("merge scale clamped (x1.3 max)", rng1 <= rng0 * 1.3 + 0.01 and rng1 > rng0, "range %.1f -> %.1f" % [rng0, rng1])
	var hard := _grt_spec({"grammar": 1, "id": "grt_hard", "name": "Hard", "trigger": {"type": "on_cast"},
		"stages": [{"delivery": {"type": "burst", "radius": 2}, "effects": [{"type": "stun", "duration": 1.5}]}]})
	var hard3 := KinLib.effective(hard, "k1", null, {}, 3)
	_grt("ranks stay inside bounds", float(hard3.stages[0].effects[0].params["duration"]) <= 1.5, "stun %.2f at rank 3" % float(hard3.stages[0].effects[0].params["duration"]))
	var evo := KinLib.effective(hook, "k1", KinLib.kin("cindle"), {"level": 8, "forms": ["fierce", "fierce"]})
	_grt("evolution sidegrade applies", float(evo.stages[0].delivery.params["range"]) > rng0 and float(evo.stages[0].effects[4].params["duration"]) < 0.3,
		"range %.1f, stun %.2f" % [float(evo.stages[0].delivery.params["range"]), float(evo.stages[0].effects[4].params["duration"])])
	var pts := KinLib.points(KinLib.kin("cindle"), {"level": 8, "forms": ["fierce", "fierce"]})
	var tot := 0
	for kk in pts: tot += int(pts[kk])
	_grt("evolution stat shift is budget-neutral", tot == KinParts.STAT_BUDGET and int(pts["kin_damage"]) == 4, "%s" % pts)
	var many: Array = []
	for i in 20: many.append(T)
	var hc := {"n": 0}
	var cxh := KinExec.make_cx(m, P, null, P, T.pos, 0.0, "k1", "grt"); cxh["hits"] = hc
	KinExec._hit([], null, many, cxh, T.pos, 1.0)
	_grt("one delivery touches at most 12", int(hc["n"]) == KinParts.MAX_HITS, "%d" % int(hc["n"]))
	_grt("level growth capped by tier", is_equal_approx(KinRules.level_growth(30, 0), 0.15) and is_equal_approx(KinRules.level_growth(30, 2), 0.35), "")
	# ---- 5. slot locks and auto-cast
	k = _grt_kin(m, P, "cindle")
	P.slot_lv["kin"] = 0
	_grt_out(k, home + Vector3(1.0, 0, 0))
	var locked := not k.use_ability("k1", T.pos) and not k.use_ability("k2", T.pos)
	P.slot_lv["kin"] = 1
	_grt("locked Boki slot never casts", locked, "")
	k.target = T
	k.runner.reset()
	var used := {"k1": 0, "k2": 0}
	for i in 60:
		k.brain.think_t = 0.0
		var c1 := k.runner.charges("k1"); var c2 := k.runner.charges("k2")
		k.brain.think_abilities(0.1)
		if k.runner.charges("k1") < c1: used["k1"] += 1
		if k.runner.charges("k2") < c2: used["k2"] += 1
		k.runner.reset()
		_grt_out(k, home + Vector3(1.0, 0, 0)); k.target = T
	_grt("your out Boki casts both its abilities itself", int(used["k1"]) > 0 and int(used["k2"]) > 0, "ability %d, auto %d" % [used["k1"], used["k2"]])
	_ac_run(m, 1.0); _grt_reset(T)
	# ---- 6. carry modes
	k = _grt_kin(m, P, "pebbit")
	P.teleport(home); _ac_run(m, 0.1)
	var kb := P.vel.x
	P.impulse(Vector2(8, 0))
	var kbv := P.vel.x - kb
	_grt("mount: rider, -15% damage, half knockback", P.mounted() and is_equal_approx(P.owner_stat("damage_reduction"), 0.15) and k.ride_height() > 0.2, "kb %.1f, ride %.2f" % [kbv, k.ride_height()])
	P.vel = Vector3.ZERO
	P.gliding = true
	P._refresh_kin_stats()
	_grt("mount curls up while you glide", not P.mounted() and P.owner_stat("damage_reduction") == 0.0, "")
	P.gliding = false
	P._refresh_kin_stats()
	var dashes0 := P.max_dashes()
	k = _grt_kin(m, P, "wisplet")
	P._refresh_kin_stats()
	_grt("perch extends your glide, never your dashes", P.gear_stat("heat") >= 0.19 and P.max_dashes() == dashes0, "glide +%.2f, dodges %.0f" % [P.gear_stat("heat"), P.max_dashes()])
	k.throw_cd = 0.0
	k.throw_to(T.pos)
	if k.hesitate_t > 0.0: k._launch(T.pos)
	var dive_y := k.pos.y - P.pos.y
	var dive: bool = k.fly.get("dive", false)
	_ac_run(m, 0.6)
	_grt("perch: its throw is a dive", dive and dive_y > 2.5 and T.stun_t > 0.0, "starts %.1fm up, target stun %.2f" % [dive_y, T.stun_t])
	_ac_run(m, 1.0); _grt_reset(T)
	k = _grt_kin(m, P, "cindle")
	P.teleport(home); P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	_ac_run(m, 0.1)
	P._emit_shot()
	_ac_run(m, 0.5)
	_grt("shoulder: shots poison (carry rider)", T.burn_t > 0.0, "burn %.1f" % T.burn_t)
	_grt_reset(T)
	# ---- 7. owner bonuses
	var base_hp := float(Data.CLASSES[P.cls]["hp"])
	_grt("owner bonus: Vespyx +8 hp, +3% speed", is_equal_approx(P.max_hp, base_hp + 8.0) and absf(P.kin_pt("owner_move_speed") - 0.03) < 0.001, "max hp %.0f (class %.0f)" % [P.max_hp, base_hp])
	k = _grt_kin(m, P, "puddlet")
	_grt("owner bonus: Prismander shield + regen", is_equal_approx(P.kin_shield, 16.0) and absf(P.kin_pt("owner_regen") - 0.75) < 0.01 and is_equal_approx(P.max_hp, base_hp), "shield %.0f regen %.2f" % [P.kin_shield, P.kin_pt("owner_regen")])
	var hp0 := P.hp
	P.hurt(10.0, T, {})
	_grt("owner shield soaks the hit", P.hp >= hp0 - 0.05 and P.kin_shield < 16.0, "hp %.0f -> %.0f, shield %.0f" % [hp0, P.hp, P.kin_shield])
	# ---- 8. the merge: unlocks at level 6 with a free full meter, runs out, then a cooldown
	k = _grt_kin(m, P, "cindle")
	P.slot_lv["ult"] = 0; P.ult = 0.0; P.merge_free = true; P.skill_pts = 1; P.lvl = 5
	var early := P.level_slot("ult")
	P.lvl = 6
	var unl := P.level_slot("ult")
	_grt("merge unlocks at level 6, meter full", not early and unl and P.ult >= 1.0, "lvl5 %s, lvl6 %s, meter %.2f" % [early, unl, P.ult])
	var ok_cast := KinMerge.cast(P)
	var dur := float(P.merge_st.get("T", 0.0))
	var ms := KinMerge.def_for(k)
	_grt("merge casts: fused, timed, passives on", ok_cast and k.state == "fused" and is_equal_approx(dur, ms.duration) and P.owner_stat("damage") > 0.19,
		"%.1fs, damage +%.2f" % [dur, P.owner_stat("damage")])
	_ac_run(m, dur + float(MergeForm.data()["xform_s"]) + 0.3)       # (the transformation comes first, then the timer; no tiers: the length is fixed)
	_grt("merge ends on its timer, then cooldown", not KinMerge.active(P) and P.merge_cd > 0.0 and k.state == "shoulder" and not KinMerge.can_cast(P), "cd %.1f" % P.merge_cd)
	P.ult = 1.0
	var blocked := not KinMerge.can_cast(P)
	_ac_run(m, KinParts.MERGE_SPENT_TIME + 0.1)
	_grt("merge again after the cooldown", blocked and KinMerge.can_cast(P), "")
	KinMerge.cast(P)
	KinCommand.tap(P)
	_ac_run(m, 0.05)
	_grt("throwing ends the merge (throw still works)", not KinMerge.active(P) and k.state in ["flying", "active"], "Boki %s" % k.state)
	_ac_run(m, 1.0)
	k = _grt_kin(m, P, "cairnback")        # (a mount without a form of its own yet: the stat merge grows it giant; Gravadillo has the Heavy Star form)
	P.teleport(home); T.teleport(home + Vector3(2.0, 0, 0)); _grt_reset(T)
	P.ult = 1.0; P.merge_cd = 0.0
	KinMerge.cast(P)
	_grt("mount merge: giant under you", KinMerge.active(P) and not k.giant.is_empty() and k.state == "shoulder" and P.owner_stat("knockback_resist") > 0.49, "knockback resist %.2f" % P.owner_stat("knockback_resist"))
	_ac_run(m, 0.2)
	var ph := T.hp
	_ac_run(m, 2.4, func(): T.teleport(home + Vector3(2.0, 0, 0)); T.vel = Vector3.ZERO)
	_grt("merge pulses stomp around you", T.hp < ph, "took %.0f" % (ph - T.hp))
	KinMerge.end(P, "test")
	# IVs ride on top of the budget: final hp/damage/speed and the merge meter's fill (sizes are
	# normalized here, since two random Boki differ in size and size nudges hp and speed too)
	var was_norm := Unique.normalize
	Unique.normalize = true
	var lo := _grt_kin(m, P, "cindle", {"ivs": {"hp": 0, "atk": 0, "spd": 0, "work": 0, "bond": 0}})
	var lo_st := [lo.max_hp, lo.dmg, lo.speed]
	P.ult = 0.0; Bond.add(P, 0.1)
	var lo_b := P.ult
	var hi := _grt_kin(m, P, "cindle", {"ivs": {"hp": 31, "atk": 31, "spd": 31, "work": 31, "bond": 31}})
	P.ult = 0.0; Bond.add(P, 0.1)
	var hi_b := P.ult
	_grt("IVs: +10% hp/dmg, +5% speed at 31", absf(hi.max_hp / lo_st[0] - 1.1) < 0.005 and absf(hi.dmg / lo_st[1] - 1.1) < 0.005 and absf(hi.speed / lo_st[2] - 1.05) < 0.005,
		"hp %.0f/%.0f dmg %.1f/%.1f speed %.2f/%.2f" % [hi.max_hp, lo_st[0], hi.dmg, lo_st[1], hi.speed, lo_st[2]])
	Unique.normalize = was_norm
	_grt("IVs: Bond fills the merge meter 10% faster", absf(hi_b / lo_b - 1.1) < 0.005, "%.3f vs %.3f" % [hi_b, lo_b])
	m.queue_free(); await get_tree().process_frame
	print("GRT DONE, failures: ", _grt_fail)
	get_tree().quit(1 if _grt_fail > 0 else 0)

## Headless check for basing to a teammate (B): a clean channel arrives weakened; a hit interrupts.
func _base_check() -> void:
	var m := Match.new()
	add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "no_drop": true, "seed": 77, "autoplay": true, "big": false})
	m.set_process(false)
	var p: Hunter = m.player
	p.ctrl = "local"
	var mate := m.base_target(p)
	if mate == null:
		print("BCHECK FAIL no teammate"); get_tree().quit(); return
	mate.ctrl = "idle"   # the check measures the recall landing beside the mate, not where a wandering mate strolls off to during the 3 s channel
	for i in 30: m.step(Match.DT)
	p.inp["move"] = Vector2.ZERO
	p.start_base(mate)
	var t := 0.0
	while t < 3.3:
		p.inp["move"] = Vector2.ZERO
		m.step(Match.DT); t += Match.DT
	var near := p.flat_dist(mate) < 2.5
	print("BCHECK clean: arrived=%s weak=%.1f cd=%.0f dmg_mult=%.2f" % [near, p.weak_t, p.base_cd, m.dmg_mult(p)])
	p.base_cd = 0.0
	p.start_base(mate)
	for i in 30: m.step(Match.DT)
	p.hurt(5.0, null, {"src": "test"})
	print("BCHECK interrupt: channel=%.2f cancelled=%s" % [p.base_t, p.base_t <= 0.0])
	print("BCHECK ", "PASS" if near and p.base_t <= 0.0 else "FAIL")
	get_tree().quit()

## Headless smoke test for the duel room: your autopilot against the sparring bot for a few
## minutes, changing the bot's class, behaviour, glove and difficulty along the way.
func _duel_check() -> void:
	var o := Match.duel_opts()
	o["autoplay"] = true
	var m := Match.new()
	add_child(m)
	m.start(o)
	m.set_process(false)
	var ok := true
	if m.duel == null or m.duel.bot == null:
		print("DUEL FAIL no bot"); get_tree().quit(); return
	print("DUEL START player=%s bot=%s dist=%.1f" % [m.player.pos.snapped(Vector3(0.1, 0.1, 0.1)), m.duel.bot.pos.snapped(Vector3(0.1, 0.1, 0.1)), m.player.flat_dist(m.duel.bot)])
	var plan := {20.0: ["mode", 1], 40.0: ["mode", 1], 60.0: ["mode", 1], 80.0: ["cls", 1], 100.0: ["glove", 1], 120.0: ["diff", 1], 140.0: ["weapon", 1]}
	var done := {}
	while m.time < 170.0:
		m.step(Match.DT)
		for t in plan:
			if m.time >= float(t) and not done.has(t):
				done[t] = true
				m.duel.cycle(String(plan[t][0]), int(plan[t][1]))
				print("DUEL t=%d %s -> %s / %s / %s / %s / %s" % [m.time, plan[t][0], m.duel.pick_text("cls"), m.duel.pick_text("weapon"), m.duel.pick_text("glove"), m.duel.pick_text("diff"), m.duel.pick_text("mode")])
		if m.duel.bot == null or not is_instance_valid(m.duel.bot):
			print("DUEL FAIL bot lost at ", m.time); ok = false; break
		if m.over:
			print("DUEL FAIL match ended at ", m.time); ok = false; break
	var st: Dictionary = m.duel.stats
	print("DUEL STATS ", st, " rounds=", m.duel.round_n, " bots=", m.hunters.size())
	if int(st["shots"]) <= 0 or float(st["dealt"]) <= 0.0:
		print("DUEL FAIL nothing landed"); ok = false
	print("DUEL CHECK ", "PASS" if ok else "FAIL")
	get_tree().quit()

## Headless check of every way out: call a skiff (monster waves come, a rival can board too, it
## leaves with whoever's on deck), open a rift hatch with a key (and lose a key to a deathbox, then
## loot it back), and charge an uplink (a rival in the yard stalls it, it completes, the lift opens).
func _extract_check() -> void:
	var ok := true
	var fresh := func(sq: int) -> Match:
		var mm := Match.new()
		add_child(mm)
		mm.start({"teams": 2, "squad": sq, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
		mm.set_process(false)
		for h in mm.hunters:
			h.ctrl = "idle"; h.inp["move"] = Vector2.ZERO
			h.max_hp = 5000.0; h.hp = 5000.0
		for mb in mm.mobs: mb.queue_free()
		mm.mobs.clear()
		return mm
	var run := func(mm: Match, sec: float, every := Callable()):
		var t := 0.0
		while t < sec and not mm.over:
			if every.is_valid(): every.call()
			mm.step(Match.DT); t += Match.DT
	# keeps the test quiet: wave monsters cleared, and the idle hunters held where they were put
	# (biome hazards like gusts would otherwise shove them around)
	var calm := func(mm: Match):
		for mb in mm.mobs:
			if not mb.dead: mb.dead = true; mb.visible = false
		for h in mm.hunters:
			if h.has_meta("pin") and not h.extracted and not h.out:
				h.teleport(h.get_meta("pin")); h.vel = Vector3.ZERO
	var done := func(mm: Match):
		mm.over = true       # the end-of-match timer must not take us to the results screen
		mm.queue_free()
	# ---- 1. the skiff
	var m: Match = fresh.call(2)
	var P: Hunter = m.player
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var R: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	var docks := m.exits.of_kind("dock")
	print("EXCHECK exits: %d docks, %d hatches, %d outposts" % [docks.size(), m.exits.of_kind("hatch").size(), m.exits.of_kind("outpost").size()])
	if docks.is_empty() or m.exits.of_kind("hatch").is_empty() or m.exits.of_kind("outpost").is_empty():
		print("EXCHECK FAIL a kind of exit is missing"); ok = false
	var d: Dictionary = docks[0]
	m.time = float(d["open_at"]) + 1.0
	P.teleport(d["pos"] + Vector3(0.3, 0, 0.3))
	var t0 := m.time
	var pings_before := m.pings.size()
	run.call(m, 2.5, func(): P.inp["interact"] = true)
	P.inp["interact"] = false
	var flare: bool = (d["node"] as Node3D).get_node("Beacon/Flare").visible
	print("EXCHECK skiff: state=%s after holding %.1fs, arrives in %.0fs; loud: map pings +%d, flare=%s" % [d["state"], m.time - t0, float(d["t"]), m.pings.size() - pings_before, flare])
	if d["state"] != "called" or m.pings.size() <= pings_before or not flare: ok = false; print("EXCHECK FAIL skiff not called (or not loud)")
	# the waves come in: hold everyone where they are (a brute could knock the idle test hunters
	# off the landing) but leave the monsters be, to count them
	P.set_meta("pin", P.pos); mate.set_meta("pin", mate.pos); R.set_meta("pin", R.pos)
	run.call(m, 30.0, func():
		for h in [P, mate, R]:
			if not h.out: h.teleport(h.get_meta("pin")); h.vel = Vector3.ZERO; h.hp = h.max_hp)
	var waves := m.mobs.filter(func(x): return not x.dead and int(x.get_meta("exit", -1)) == int(d["i"])).size()
	print("EXCHECK skiff: waves=%d monsters alive from them=%d t left=%.0f" % [int(d["waves"]), waves, float(d["t"])])
	if int(d["waves"]) < 2 or waves <= 0: ok = false; print("EXCHECK FAIL no monster waves")
	# the player and a rival step on the deck; the teammate stays on the pier's foot (not aboard)
	for mb in m.mobs: mb.dead = true; mb.visible = false
	P.teleport(d["berth"]); R.teleport(d["berth"] + Vector3(0.8, 0, 0.4))
	mate.teleport(d["pos"])
	for h in [P, R, mate]: h.set_meta("pin", h.pos)
	while d["state"] == "called" and m.time - t0 < 80.0: run.call(m, Match.DT, calm.bind(m))
	print("EXCHECK skiff: state=%s (boarding %.0fs) player %.1fm from the berth (y %.2f vs %.2f) downed=%s out=%s" % [d["state"], float(d["t"]), P.flat_dist(d["berth"]), P.pos.y, d["berth"].y, P.downed, P.out])
	run.call(m, 1.0, calm.bind(m))
	print("EXCHECK skiff: aboard=%s" % str((d["aboard"] as Array).map(func(x): return x.pname)))
	while d["state"] == "boarding" and m.time - t0 < 100.0: run.call(m, Match.DT, calm.bind(m))
	print("EXCHECK skiff: left. player extracted=%s how=%s where=%s  rival extracted=%s  mate (on the pier) extracted=%s" % [P.extracted, m.result.get("how", ""), m.result.get("where", ""), R.extracted, mate.extracted])
	if not P.extracted or m.result.get("how", "") != "skiff" or not R.extracted or mate.extracted: ok = false; print("EXCHECK FAIL skiff boarding")
	done.call(m)
	await get_tree().process_frame
	# ---- 2. the rift hatch: a key press turns it (the key is spent), it opens 10s later, three drop through
	m = fresh.call(3)
	P = m.player
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	mate = mates[0]
	var rivals: Array = m.hunters.filter(func(x): return x.team != P.team)
	R = rivals[0]
	var hx: Dictionary = m.exits.of_kind("hatch")[0]
	var hp: Vector3 = hx["pos"]
	var press := func(h: Hunter, sec: float):
		run.call(m, sec, func(): h.inp["interact"] = true)
		h.inp["interact"] = false
		run.call(m, Match.DT)
	R.rift_keys = 0
	R.teleport(hp + Vector3(0.6, 0, 0.6))
	press.call(R, 0.5)
	print("EXCHECK hatch: without a key: state=%s rival extracted=%s" % [hx["state"], R.extracted])
	if hx["state"] != "sealed" or R.extracted: ok = false; print("EXCHECK FAIL hatch opened without a key")
	R.teleport(m.world.random_ground())
	# a key in a deathbox: the teammate dies carrying one, the player loots it
	mate.rift_keys = 1
	mate.lives = 1
	# its box lands clear of the hatch: a revive prompt there would beat the hatch's
	mate.teleport(m.world.free_spot_near(hp + Vector3(6.0, 0, 0), [], 0.5, 0.4, 6.0))
	m.eliminate(mate, R, "knocked out", true)
	var bx := Life.box_of(m, mate)
	print("EXCHECK hatch: teammate died with a key: their keys=%d box keys=%d" % [mate.rift_keys, int(bx.get("keys", -1))])
	if mate.rift_keys != 0 or int(bx.get("keys", 0)) != 1: ok = false; print("EXCHECK FAIL key not in the box")
	P.rift_keys = 0
	var got_key := false
	for it in Life.box_items(m, P, bx):
		if it["key"] == "keys": Life.take_item(m, P, bx, it); got_key = true
	print("EXCHECK hatch: looted the box: player keys=%d" % P.rift_keys)
	if not got_key or P.rift_keys != 1: ok = false; print("EXCHECK FAIL couldn't loot the key")
	var pings0 := m.pings.size()
	# the prompt: with a key, "F: Unlock with Rift Key"
	P.teleport(hp + Vector3(0.7, 0, 0.5))
	var pr := m.exits.interact_for(P)
	print("EXCHECK hatch: prompt with a key: %s" % pr.get("label", ""))
	if String(pr.get("act", "")) != "open" or not String(pr.get("label", "")).contains("Unlock with Rift Key"): ok = false; print("EXCHECK FAIL hatch key prompt")
	t0 = m.time
	press.call(P, 0.3)
	print("EXCHECK hatch: key pressed: state=%s keys left=%d opens in %.1fs player extracted=%s new map pings=%d" % [hx["state"], P.rift_keys, float(hx["t"]), P.extracted, m.pings.size() - pings0])
	if hx["state"] != "unlocking" or P.rift_keys != 0 or P.extracted or m.pings.size() != pings0: ok = false; print("EXCHECK FAIL hatch key press")
	# no way in before the 10 s are up: pressing, or standing right on it
	P.teleport(hp + Vector3(0.2, 0, 0.1))
	run.call(m, 4.0, func(): P.inp["interact"] = true)
	P.inp["interact"] = false
	var st: Dictionary = m.exits.status_for(P)
	print("EXCHECK hatch: 4s on: state=%s %.1fs left, player extracted=%s, HUD: %s" % [hx["state"], float(hx["t"]), P.extracted, st.get("text", "")])
	if P.extracted or hx["state"] != "unlocking" or not String(st.get("text", "")).contains("opening"): ok = false; print("EXCHECK FAIL hatch entered before it opened")
	P.teleport(hp + Vector3(1.4, 0, 0.0))
	while hx["state"] == "unlocking" and m.time - t0 < 15.0: run.call(m, Match.DT)
	print("EXCHECK hatch: opened after %.1fs, %d uses" % [m.time - t0, int(hx.get("uses", 0))])
	if hx["state"] != "open" or absf(m.time - t0 - 10.0) > 0.6 or int(hx.get("uses", 0)) != 3: ok = false; print("EXCHECK FAIL hatch didn't open after 10s with 3 uses")
	# three drop through: the player by pressing, a rival and his teammate by walking in
	P.teleport(hp + Vector3(1.0, 0, 0.0))      # (back at the hatch: something may have nudged you while it opened)
	press.call(P, 0.2)
	var u1 := int(hx["uses"])
	var R2: Hunter = rivals[1]
	R.teleport(hp + Vector3(0.3, 0, 0.2)); run.call(m, 0.2)
	R2.teleport(hp + Vector3(-0.2, 0, 0.3)); run.call(m, 0.2)
	var R3: Hunter = rivals[2]
	R3.teleport(hp + Vector3(0.2, 0, -0.3)); run.call(m, 0.4)
	print("EXCHECK hatch: player in=%s (uses then %d), rival in=%s, rival 2 in=%s, 4th in=%s, state=%s how=%s" % [P.extracted, u1, R.extracted, R2.extracted, R3.extracted, hx["state"], m.result.get("how", "")])
	if not P.extracted or u1 != 2 or m.result.get("how", "") != "hatch" or not R.extracted or not R2.extracted or R3.extracted or hx["state"] != "sealed": ok = false; print("EXCHECK FAIL hatch: three drop through, then it seals")
	done.call(m)
	await get_tree().process_frame
	# ---- 2b. a bot with a key: walks up, turns it, waits it out, and its squad drops through
	m = fresh.call(2)
	hx = m.exits.of_kind("hatch")[0]
	hp = hx["pos"]
	var B: Hunter = m.hunters.filter(func(x): return x != m.player)[0]
	var BM: Hunter = m.hunters.filter(func(x): return x.team == B.team and x != B)[0]
	for h in m.hunters:
		if h.team != B.team: h.teleport(m.world.spawns[0] if hp.distance_to(m.world.spawns[0]) > 40.0 else m.world.spawns[-1])
	for h in [B, BM]:
		h.ctrl = "bot"; h.ai["leave"] = true
		h.teleport(m.world.free_spot_near(hp + Vector3(4.0, 0, 3.0), [hp], 2.0, 0.5, 6.0))
	B.rift_keys = 1; BM.rift_keys = 0
	m.time = m.length - 160.0       # late: everyone's heading home
	t0 = m.time
	var opened_at := -1.0
	while not (B.extracted and BM.extracted) and m.time - t0 < 60.0:
		run.call(m, Match.DT, calm.bind(m))
		if opened_at < 0.0 and hx["state"] == "unlocking": opened_at = m.time - t0
	print("EXCHECK hatch bots: key turned at %.1fs, bot out=%s, its teammate out=%s, keys left=%d, after %.1fs" % [opened_at, B.extracted, BM.extracted, B.rift_keys, m.time - t0])
	if opened_at < 0.0 or not B.extracted or not BM.extracted or B.rift_keys != 0: ok = false; print("EXCHECK FAIL bots and the hatch")
	done.call(m)
	await get_tree().process_frame
	# ---- 3. the uplink
	m = fresh.call(2)
	P = m.player
	R = m.hunters.filter(func(x): return x.team != P.team)[0]
	var o: Dictionary = m.exits.of_kind("outpost")[0]
	m.time = float(o["open_at"]) + 1.0
	P.teleport(o["pos"] + Vector3(0.6, 0, 0.6))
	run.call(m, 2.0, func(): P.inp["interact"] = true)
	P.inp["interact"] = false
	P.set_meta("pin", o["pos"] + Vector3(0.6, 0, 0.6))
	print("EXCHECK uplink: state=%s team=%d" % [o["state"], int(o["team"])])
	if o["state"] != "charging": ok = false; print("EXCHECK FAIL uplink didn't start")
	run.call(m, 8.0, calm.bind(m))
	var p1 := float(o["prog"])
	R.teleport(o["pos"] + Vector3(-1.6, 0, 1.0))
	R.set_meta("pin", R.pos)
	run.call(m, 1.0, calm.bind(m))
	var pa := float(o["prog"])
	run.call(m, 3.0, calm.bind(m))
	var pb := float(o["prog"])
	print("EXCHECK uplink: %d%% after 8s; rival in the yard: contested=%s %d%% -> %d%% over 3s (paused)" % [int(p1 * 100), o["contested"], int(pa * 100), int(pb * 100)])
	if p1 <= 0.1 or not o["contested"] or absf(pb - pa) > 0.001: ok = false; print("EXCHECK FAIL contest")
	R.remove_meta("pin")
	R.teleport(m.world.random_ground())
	t0 = m.time
	while o["state"] == "charging" and m.time - t0 < 60.0:
		run.call(m, 0.5, calm.bind(m))
	print("EXCHECK uplink: state=%s after %.0fs more, waves=%d prog=%.2f contested=%s player in yard=%s (%.1fm) downed=%s" % [o["state"], m.time - t0, int(o["waves"]), float(o["prog"]), o["contested"], m.exits.in_yard(o, P), P.flat_dist(o["pos"]), P.downed])
	for h in m.hunters: print("   ", h.pname, " team ", h.team, " ", h.flat_dist(o["pos"]), " in yard ", m.exits.in_yard(o, h))
	if o["state"] != "open" or int(o["waves"]) < 2: ok = false; print("EXCHECK FAIL uplink never completed (or no waves)")
	P.remove_meta("pin")
	P.teleport(o["pos"] + Vector3(0.4, 0, 0.3))
	run.call(m, 0.3)
	print("EXCHECK uplink: player extracted=%s how=%s where=%s" % [P.extracted, m.result.get("how", ""), m.result.get("where", "")])
	if not P.extracted or m.result.get("how", "") != "uplink": ok = false; print("EXCHECK FAIL lift")
	done.call(m)
	await get_tree().process_frame
	# ---- 3b. one of the squad charges the uplink; more of you in the yard charge it faster (and a
	# rival still stalls it however many of you there are). Squadmate bots come and hold the yard.
	m = fresh.call(3)
	P = m.player
	var crew: Array = m.hunters.filter(func(x): return x.team == P.team)
	R = m.hunters.filter(func(x): return x.team != P.team)[0]
	o = m.exits.of_kind("outpost")[0]
	m.time = float(o["open_at"]) + 1.0
	for i in crew.size():
		var h: Hunter = crew[i]
		h.teleport(m.world.random_ground()); h.set_meta("pin", h.pos)
	P.teleport(o["pos"] + Vector3(0.6, 0, 0.6)); P.set_meta("pin", P.pos)
	run.call(m, 2.0, func(): P.inp["interact"] = true)
	P.inp["interact"] = false
	var rates: Array = []
	for n in [1, 2, 3]:
		for i in n:
			var h: Hunter = crew[i]
			var at: Vector3 = o["pos"] + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.2
			h.teleport(at); h.set_meta("pin", at)
		run.call(m, 0.2, calm.bind(m))
		var q0 := float(o["prog"])
		run.call(m, 2.0, calm.bind(m))
		rates.append((float(o["prog"]) - q0) / 2.0 * m.exits.uplink_time(o))
	var crew_ok: bool = absf(float(rates[0]) - 1.0) < 0.05 and absf(float(rates[1]) - 1.5) < 0.05 and absf(float(rates[2]) - 1.8) < 0.05
	print("EXCHECK uplink crew: charge rate x%.2f with one, x%.2f with two, x%.2f with three in the yard (crew %d)" % [rates[0], rates[1], rates[2], int(o.get("crew", 0))])
	if not crew_ok: ok = false; print("EXCHECK FAIL uplink crew rates")
	R.teleport(o["pos"] + Vector3(-1.6, 0, 1.0)); R.set_meta("pin", R.pos)
	run.call(m, 0.2, calm.bind(m))
	var qc0 := float(o["prog"])
	run.call(m, 2.0, calm.bind(m))
	print("EXCHECK uplink crew: three of you and one rival in the yard: contested=%s %d%% -> %d%%" % [o["contested"], int(qc0 * 100), int(float(o["prog"]) * 100)])
	if not o["contested"] or absf(float(o["prog"]) - qc0) > 0.001: ok = false; print("EXCHECK FAIL contest with a crew")
	R.remove_meta("pin"); R.teleport(m.world.random_ground())
	# a squadmate bot elsewhere goes to hold the yard, at its own spot
	var YB: Hunter = crew[2]
	YB.remove_meta("pin"); YB.teleport(m.world.random_ground()); YB.ctrl = "bot"
	var bgx: Array = m.exits.bot_goal(YB, false)
	print("EXCHECK uplink crew: a squadmate bot heads for %s (%s, %.1fm from the mast)" % [str(bgx.slice(1)), str(bgx[0]) if not bgx.is_empty() else "-", (bgx[0] as Vector3).distance_to(o["pos"]) if not bgx.is_empty() else -1.0])
	if bgx.is_empty() or String(bgx[1]) != "yard" or not m.exits.in_yard(o, crew[0]) or (bgx[0] as Vector3).distance_to(o["pos"]) > Exits.OUTPOST_R - 0.5: ok = false; print("EXCHECK FAIL bot yard")
	# ... and it walks there and holds it (the uplink charging the while)
	for h in m.hunters:
		if h != YB: h.remove_meta("pin"); h.teleport(m.world.random_ground()); h.set_meta("pin", h.pos)
	YB.teleport(o["pos"] + Vector3(9.0, 0, 0) if not m.world.is_void(o["pos"].x + 9.0, o["pos"].z) else o["pos"] + Vector3(0, 0, 9.0))
	var yb_in := 0.0
	var tyb := 0.0
	seed(2024)      # the bot's random choices should not depend on how many rolls the map and loot took
	while tyb < 16.0:
		run.call(m, 0.25, calm.bind(m)); tyb += 0.25
		if m.exits.in_yard(o, YB): yb_in += 0.25
	print("EXCHECK uplink crew: the bot held the yard %.1fs of the last 16s (%.1fm from the mast)" % [yb_in, YB.flat_dist(o["pos"])])
	if yb_in < 8.0 or not m.exits.in_yard(o, YB): ok = false; print("EXCHECK FAIL bot didn't hold the yard")
	YB.ctrl = "idle"; YB.inp["move"] = Vector2.ZERO
	# ---- 3c. nobody in the yard: the charge drains (shown on the HUD and over the yard); at nothing
	# the uplink flickers, shuts off, and after a cooldown can be started again
	# (everyone else idle and well clear of the yard: a squadmate or rival anywhere near it would keep
	# it from draining)
	for h in m.hunters:
		if h == P: continue
		h.ctrl = "idle"; h.inp["move"] = Vector2.ZERO
		var far := m.world.random_ground()
		for k in 200:
			if far.distance_to(o["pos"]) > 25.0: break
			far = m.world.random_ground()
		h.remove_meta("pin"); h.teleport(far); h.set_meta("pin", far)
	P.remove_meta("pin"); P.teleport(o["pos"] + Vector3(6.0, 0, 0) if not m.world.is_void(o["pos"].x + 6.0, o["pos"].z) else o["pos"] + Vector3(0, 0, 6.0)); P.set_meta("pin", P.pos)
	o["prog"] = 0.5
	run.call(m, 0.2, calm.bind(m))
	var d0 := float(o["prog"])
	run.call(m, 3.0, calm.bind(m))
	var d1 := float(o["prog"])
	var ust: Dictionary = m.exits.status_for(P)
	var drain_rate := (d0 - d1) / 3.0 * Exits.UPLINK_DECAY_T
	print("EXCHECK uplink decay: nobody in the yard: %d%% -> %d%% in 3s (x%.2f of a full drain in %ds); '%s'" % [int(d0 * 100), int(d1 * 100), drain_rate, int(Exits.UPLINK_DECAY_T), String(ust.get("text", ""))])
	if not o.get("draining", false) or absf(drain_rate - 1.0) > 0.05 or not String(ust.get("text", "")).contains("draining"): ok = false; print("EXCHECK FAIL uplink decay")
	# back in the yard it charges again
	P.teleport(o["pos"] + Vector3(0.6, 0, 0.6)); P.set_meta("pin", P.pos)
	run.call(m, 1.0, calm.bind(m))
	var d2 := float(o["prog"])
	if o.get("draining", false) or d2 <= d1: ok = false; print("EXCHECK FAIL back in the yard it didn't charge")
	# out again until it runs dry
	P.teleport(o["pos"] + Vector3(6.0, 0, 0) if not m.world.is_void(o["pos"].x + 6.0, o["pos"].z) else o["pos"] + Vector3(0, 0, 6.0)); P.set_meta("pin", P.pos)
	var seen_fizz := false
	var tf := 0.0
	while tf < Exits.UPLINK_DECAY_T + Exits.FIZZLE_T + 2.0 and String(o["state"]) != "spent":
		run.call(m, 0.25, calm.bind(m)); tf += 0.25
		if String(o["state"]) == "fizzling": seen_fizz = true
	print("EXCHECK uplink decay: ran dry after %.1fs: flickered %s, now %s (team %d, prog %.2f, crew %d, contested %s, draining %s, match over %s)" % [tf, seen_fizz, o["state"], int(o["team"]), float(o["prog"]), int(o.get("crew", 0)), o.get("contested", false), o.get("draining", false), m.over])
	if not seen_fizz or String(o["state"]) != "spent" or int(o["team"]) != -1: ok = false; print("EXCHECK FAIL uplink fizzle")
	run.call(m, Exits.FIZZLE_CD + 0.5, calm.bind(m))
	print("EXCHECK uplink decay: after the cooldown it's %s, startable %s" % [o["state"], m.exits.startable(o)])
	if String(o["state"]) != "idle" or not m.exits.startable(o): ok = false; print("EXCHECK FAIL uplink not startable again")
	done.call(m)
	await get_tree().process_frame
	# ---- 4. docks close late, one stays open
	m = fresh.call(2)
	var closing := m.exits.of_kind("dock").filter(func(x): return float(x["close_at"]) < 1e8).size()
	m.time = m.length - 25.0
	run.call(m, 0.5)
	var still := m.exits.of_kind("dock").filter(func(x): return x["state"] != "closed")
	print("EXCHECK docks: %d close during the match, %d still open near the end; a call now takes %.0fs" % [closing, still.size(), m.exits.call_time()])
	if still.size() != 1 or m.exits.call_time() > 10.0: ok = false; print("EXCHECK FAIL closing")
	done.call(m)
	print("EXCHECK ", "PASS" if ok else "FAIL")
	get_tree().quit()

## Headless check of truces: a weak bot squad offers one to a strong squad (by its own weighing),
## the strong squad answers; with a truce in place neither targets the other; an attack breaks it,
## is announced and marks the betrayer; truce partners share an uplink's yard without contesting it.
func _truce_check() -> void:
	var ok := true
	var m := Match.new()
	add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.time = 120.0
	var A: Array = m.hunters.filter(func(x): return x.team == 0)
	var B: Array = m.hunters.filter(func(x): return x.team == 1)
	# open flat ground for the stand-off
	var home: Vector3 = A[0].pos
	for k in 3000:
		var g := m.world.random_ground()
		var roomy := true
		for dx in range(-8, 9, 2):
			for dz in range(-4, 5, 2):
				if m.world.is_void(g.x + dx, g.z + dz) or m.world.is_block(g.x + dx, g.z + dz) or absf(m.world.ground_at(g.x + dx, g.z + dz) - g.y) > 0.3: roomy = false
		if roomy:
			home = g; break
	var spots := {}
	for i in A.size(): spots[A[i]] = home + Vector3(-3.5, 0, -1.0 + 2.0 * i)
	for i in B.size(): spots[B[i]] = home + Vector3(3.5, 0, -1.0 + 2.0 * i)
	for h in m.hunters:
		h.ctrl = "bot"
		h.teleport(spots[h])
	# squad A is hurt and bare; squad B is fresh with good armor
	for h in A:
		h.hp = h.max_hp * 0.2; h.armor = 0.0
	for h in B:
		h.armor_tier = 3; h.armor = h.max_armor
	var hold := func():
		for h in m.hunters:
			if not h.out and not h.extracted:
				h.teleport(spots[h]); h.vel = Vector3.ZERO; h.inv_t = 5.0
				if h.downed: m.revive_hunter(h, null)
				if h.team == 0: h.hp = minf(h.hp, h.max_hp * 0.2); h.armor = 0.0; h.tonics = 0     # squad A stays hurt
	var run := func(sec: float):
		var t := 0.0
		while t < sec:
			hold.call(); m.step(Match.DT); t += Match.DT
	var cross := func() -> int:
		var n := 0
		for h in m.hunters:
			var tg = h.ai.get("tgt")
			if tg is Hunter and (tg as Hunter).team != h.team: n += 1
		return n
	var T: Truce = m.truce
	print("TCHECK strength A=%.1f B=%.1f  peace score A->B=%.2f  B would accept from A=%.2f  A would accept from B=%.2f" % [T.strength(0), T.strength(1), T._peace_score(0, 1, {1: 7.0}), T.would_accept(1, 0), T.would_accept(0, 1)])
	if T.would_accept(1, 0) >= T.would_accept(0, 1): ok = false; print("TCHECK FAIL the stronger squad should be less keen")
	run.call(2.0)
	var before: int = cross.call()
	print("TCHECK before any truce: %d hunters targeting the other squad" % before)
	if before == 0: ok = false; print("TCHECK FAIL they never squared up")
	# the weak squad should raise the flag by itself within a while
	var t0 := m.time
	while not T.events.any(func(e): return String(e).begins_with("offer 0->1")) and m.time - t0 < 40.0:
		run.call(0.25)
	var offered: bool = T.events.any(func(e): return String(e).begins_with("offer 0->1"))
	print("TCHECK weak squad offered a truce: %s after %.1fs" % [offered, m.time - t0])
	if not offered: ok = false; print("TCHECK FAIL no offer")
	run.call(3.5)
	var answered := "accepted" if T.allied(0, 1) else ("faked" if T.events.has("fake 1") else ("refused" if T.events.any(func(e): return String(e).begins_with("refused")) else "no answer"))
	print("TCHECK strong squad answered: %s  (events %s)" % [answered, str(T.events)])
	if answered == "no answer": ok = false; print("TCHECK FAIL no answer")
	if not T.allied(0, 1):
		print("TCHECK (making the truce by hand for the rest of the check)")
		T.make(0, 1)
	for h in m.hunters: h.ai.erase("betray_at"); h.ai.erase("betray")
	run.call(3.0)
	var during: int = cross.call()
	print("TCHECK during the truce: %d hunters targeting the other squad" % during)
	if during != 0: ok = false; print("TCHECK FAIL truce partners still targeted")
	# an attack breaks it
	var traitor: Hunter = B[0]; var victim: Hunter = A[0]
	victim.inv_t = 0.0
	victim.hurt(20.0, traitor, {"src": "shot"})
	var announced: bool = m.feed_all.any(func(f): return String(f).contains("broke the truce"))
	run.call(0.6)
	var hits_back: int = A.filter(func(x): return x.ai.get("tgt") == traitor).size()
	print("TCHECK attack: truce holds=%s announced=%s betrayer marked=%s revealed %.0fs, victims targeting the betrayer=%d" % [T.allied(0, 1), announced, T.is_marked(traitor), traitor.reveal_t, hits_back])
	if T.allied(0, 1) or not announced or not T.is_marked(traitor) or hits_back == 0: ok = false; print("TCHECK FAIL breaking")
	# sharing an uplink
	T.marked.clear()
	T.make(0, 1)
	var o: Dictionary = m.exits.of_kind("outpost")[0]
	m.time = maxf(m.time, float(o["open_at"]) + 1.0)
	m.exits.act(o, "start", A[0])
	spots[A[0]] = o["pos"] + Vector3(1.0, 0, 0.8)
	spots[B[0]] = o["pos"] + Vector3(-1.2, 0, -0.9)
	spots[A[1]] = o["pos"] + Vector3(30, 0, 30); spots[B[1]] = o["pos"] + Vector3(30, 0, 30)
	for h in [A[1], B[1]]: spots[h] = m.world.free_spot_near(spots[h], [], 1.0, 0.5, 20.0)
	var p0 := float(o["prog"])
	run.call(3.0)
	var p1 := float(o["prog"])
	print("TCHECK uplink with a truce partner in the yard: contested=%s %d%% -> %d%%" % [o["contested"], int(p0 * 100), int(p1 * 100)])
	if o["contested"] or p1 <= p0: ok = false; print("TCHECK FAIL partner contested the uplink")
	T.end("0:1", "")
	run.call(1.0)
	var p2 := float(o["prog"])
	run.call(2.0)
	print("TCHECK without the truce: contested=%s %d%% -> %d%%" % [o["contested"], int(p2 * 100), int(float(o["prog"]) * 100)])
	if not o["contested"]: ok = false; print("TCHECK FAIL rival didn't contest")
	# the other way round: now squad B is the beaten one, and an offer to it (as a player would
	# make from the emote wheel) gets accepted by its own weighing
	T.marked.clear(); T._cool.clear()
	spots[A[0]] = home + Vector3(-3.5, 0, -1.0); spots[A[1]] = home + Vector3(-3.5, 0, 1.0)
	spots[B[0]] = home + Vector3(3.5, 0, -1.0); spots[B[1]] = home + Vector3(3.5, 0, 1.0)
	for h in A: h.hp = h.max_hp; h.armor = h.max_armor; h.armor_tier = 3; h.tonics = 3
	for h in B: h.hp = h.max_hp * 0.15; h.armor = 0.0; h.armor_tier = 0; h.tonics = 0; h.ai.erase("betray")
	m.player.team = 0
	var hold2 := func():
		for h in m.hunters:
			h.teleport(spots[h]); h.vel = Vector3.ZERO; h.inv_t = 5.0
			if h.team == 1: h.hp = minf(h.hp, h.max_hp * 0.15); h.armor = 0.0
	var tt := 0.0
	while tt < 1.0: hold2.call(); m.step(Match.DT); tt += Match.DT
	print("TCHECK reversed: B would accept from A=%.2f" % T.would_accept(1, 0))
	# acceptance is a weighed roll (95% here), so like a player the offer is made again after a refusal
	tt = 0.0
	for _try in 3:
		T._cool.clear()
		T.emote(A[0], "truce")
		var offer_t := tt
		while tt - offer_t < 3.5 and not T.allied(0, 1): hold2.call(); m.step(Match.DT); tt += Match.DT
		if T.allied(0, 1): break
	print("TCHECK reversed: the beaten squad accepted=%s after %.1fs (events %s)" % [T.allied(0, 1), tt, str(T.events.slice(-3))])
	if not T.allied(0, 1) and not T.events.has("fake 1"): ok = false; print("TCHECK FAIL beaten squad refused")
	m.over = true
	print("TCHECK ", "PASS" if ok else "FAIL")
	get_tree().quit()

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
## Hold animations: a hold keeps its pose while it's refreshed and lets go cleanly when it stops;
## every kind rides the snapshot flags (bits 11 and 15-18) and decodes back to itself.
func _hold_check() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var bad := 0
	var m := Match.new()
	add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	for i in 5: await get_tree().process_frame
	var h: Hunter = m.player
	for k in Hunter.HOLD_KINDS:
		h.set_hold(String(k))
		var f: int = m._flags(h)
		var back := ((f >> 15) & 15) - 1
		if f & 2048 == 0 or back < 0 or String(Hunter.HOLD_KINDS[back]) != String(k):
			bad += 1; print("HOLDCHECK FAIL flags for %s: %d" % [k, f])
	# (the flags never reach the bits other state uses)
	h.hold_until = 0.0
	if m._flags(h) & (2048 | (15 << 15)) != 0: bad += 1; print("HOLDCHECK FAIL flags set with no hold")
	var t := 0.0
	var peak := 0.0
	while t < 0.8:
		h.set_hold("chest")
		m.step(Match.DT); t += Match.DT
		await get_tree().process_frame
		if h.anim: peak = maxf(peak, h.anim.act_k)
	var held_kind: String = h.anim.act_kind if h.anim else ""
	t = 0.0
	while t < 1.0:
		m.step(Match.DT); t += Match.DT
		await get_tree().process_frame
	var after: float = h.anim.act_k if h.anim else 0.0
	print("HOLDCHECK chest hold: pose %.2f while held (%s), %.2f a second after letting go, holding '%s'" % [peak, held_kind, after, h.holding()])
	if h.anim and (peak < 0.6 or held_kind != "chest" or after > 0.1): bad += 1; print("HOLDCHECK FAIL pose")
	if h.holding() != "": bad += 1; print("HOLDCHECK FAIL the hold didn't lapse")
	print("HOLDCHECK done, failures: %d" % bad)
	get_tree().quit(1 if bad > 0 else 0)

## Recording mode: F10 cycles off / clean / no HUD, Shift+F10 goes straight to no HUD; the debug and
## hint nodes hide in clean mode, the HUDs in no-HUD mode, the fps counter goes, tips stop, the camera
## softens and orbits only with the HUD hidden; turning it off puts everything back as it was.
func _record_check() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var bad := [0]
	var ok := func(cond: bool, what: String) -> void:
		print("RECCHECK %s %s" % ["ok  " if cond else "FAIL", what])
		if not cond: bad[0] += 1
	var press := func(shift: bool) -> void:
		var e := InputEventKey.new()
		e.physical_keycode = KEY_F10; e.keycode = KEY_F10; e.pressed = true; e.shift_pressed = shift
		Overlay._input(e)
	Settings.set_v("show_fps", true, false)
	var m := Match.new()
	add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	for i in 5: await get_tree().process_frame
	var dbg := Label.new(); dbg.text = "debug"; add_child(dbg); Record.hide_in_clean(dbg)
	var hint_hidden := Label.new(); hint_hidden.visible = false; add_child(hint_hidden); Record.hide_in_clean(hint_hidden)
	await get_tree().process_frame
	ok.call(Record.level == 0 and dbg.visible and m.hud.visible and Overlay.fps_lbl.visible, "off: debug label, HUD and fps shown")
	var cam_off: Array = Record.cam_rates()
	press.call(false)
	await get_tree().process_frame
	await get_tree().process_frame
	ok.call(Record.level == 1, "F10: clean (level %d)" % Record.level)
	ok.call(not dbg.visible and m.hud.visible and not Overlay.fps_lbl.visible, "clean: debug label and fps hidden, the HUD stays")
	ok.call(float(Record.cam_rates()[0]) < float(cam_off[0]) and float(Record.cam_rates()[4]) < 1.0, "clean: the camera follows softer, less shake")
	m.hud.tip("a tip"); m._tip_t = 99.0
	var tips_before: int = m.hud.msgs.count()
	m._tips()
	ok.call(m.hud.msgs.count() == tips_before, "clean: no new tips queued")
	press.call(false)
	await get_tree().process_frame
	ok.call(Record.level == 2 and not m.hud.visible, "F10 again: no HUD (level %d, hud visible %s)" % [Record.level, m.hud.visible])
	var y0 := Record.orbit_yaw
	var e9 := InputEventKey.new(); e9.physical_keycode = KEY_F9; e9.keycode = KEY_F9; e9.pressed = true
	Overlay._input(e9)
	for i in 10: await get_tree().process_frame
	ok.call(Record.orbit and absf(Record.orbit_yaw - y0) > 0.0001, "F9: the camera orbits (%.3f rad)" % Record.orbit_yaw)
	press.call(false)
	for i in 3: await get_tree().process_frame
	ok.call(Record.level == 0 and dbg.visible and not hint_hidden.visible and m.hud.visible and Overlay.fps_lbl.visible and not Record.orbit, "F10 a third time: off, all back as it was (a hidden one stays hidden)")
	press.call(true)
	await get_tree().process_frame
	ok.call(Record.level == 2 and not m.hud.visible and not dbg.visible, "Shift+F10: straight to no HUD")
	press.call(true)
	await get_tree().process_frame
	ok.call(Record.level == 1 and m.hud.visible, "Shift+F10 again: back to the clean HUD")
	Record.set_level(0)
	await get_tree().process_frame
	ok.call(InputMap.has_action("record") and Settings.ACTIONS.any(func(a): return a[0] == "record"), "F10 is a rebindable action (%s)" % Settings.key_cap("record"))
	# Settings > Demo: clear weather, no Blight, bots hold off fresh landers longer (offline matches)
	var o0 := Settings.demo_opts({})
	ok.call(not o0.has("raid") and not o0.has("blight") and not o0.has("fresh_t") and RaidLook.rolls({"big": true}), "demo settings at their defaults change nothing")
	Settings.set_v("demo_weather", "clear", false); Settings.set_v("demo_blight", false, false); Settings.set_v("demo_fresh", "long", false)
	var o1 := Settings.demo_opts({"teams": 10})
	ok.call(RaidLook.pick(o1, 12345) == "clear" and not BlightDir.enabled(o1) and float(o1.get("fresh_t", 0.0)) == Settings.DEMO_FRESH_T, "demo settings: clear weather, no Blight, %ds for fresh landers" % int(Settings.DEMO_FRESH_T))
	var seen := {}
	for sd in 40: seen[RaidLook.pick(Settings.demo_opts({}), sd + 1)] = true
	ok.call(seen.keys() == ["clear"], "always clear over 40 seeds (%s)" % ", ".join(seen.keys()))
	Settings.set_v("demo_weather", "random", false); Settings.set_v("demo_blight", true, false); Settings.set_v("demo_fresh", "normal", false)
	print("RECCHECK done, failures: %d" % bad[0])
	get_tree().quit(1 if bad[0] > 0 else 0)

## Bots shouldn't look broken: over a few seeded matches, every bot is watched for spinning (its
## facing swinging back and forth), jump and dash spam, and hanging in the air (which shows its hit ring
## under it: blue on an ally). Any 5 s window over the limits is flagged, with what the bot was doing.
func _bot_sanity() -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var seeds := [3, 5, 9]
	var dur := 150.0
	var verbose := "--sanity-verbose" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sanity-seeds="): seeds = Array(a.substr(15).split(",")).map(func(x): return int(x))
		if a.begins_with("--sanity-t="): dur = float(a.substr(11))
	const WIN := 5.0
	const MAX_TURN := 9.0 * PI      # facing travel in a window (a full fight's strafing is ~3 pi)
	const MAX_FLIPS := 14           # big reversals of facing in a window
	const MAX_JUMPS := 6
	const MAX_DASHES := 6
	const MAX_RING := 0.6           # share of a window spent in the air over land, ring showing
	var bad := 0
	var worst := {}
	for sd in seeds:
		var m := Match.new()
		add_child(m)
		m.start({"teams": 3, "squad": 3, "tier": 0, "seed": sd, "autoplay": true})
		m.set_process(false)
		var st := {}
		for h in m.hunters:
			st[h.nid] = {"face": h.face, "dface": 0.0, "turn": 0.0, "flips": 0, "jumps": 0, "dashes": 0, "ring": 0.0, "t": 0.0, "vy": 0.0, "roll": 0.0, "air": 0.0}
		var flagged := 0
		var watch := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--sanity-watch="): watch = a.substr(15)
		while m.time < dur and not m.over:
			m.step(Match.DT)
			if watch != "":
				var wn := watch.split("@")
				var w0 := float(wn[1]) if wn.size() > 1 else 0.0
				if m.time > w0 and m.time < w0 + 6.0 and int(m.time * 60.0) % 6 == 0:
					for h in m.hunters:
						if h.pname == wn[0]:
							var c: Dictionary = h.ai.get("cross", {})
							print("WATCH t=%.2f pos=%s vel=%s face=%.2f aim=%s move=%s gr=%s goal=%s kind=%s cross=%s go=%s wp=%s stuck=%.2f detour=%.2f" % [m.time, str(h.pos.snapped(Vector3(0.01,0.01,0.01))), str(h.vel.snapped(Vector3(0.1,0.1,0.1))), h.face, str((h.inp["aim"] as Vector3).snapped(Vector3(0.1,0.1,0.1))), str(h.inp["move"]), h.grounded, str(h.ai.get("goal")), str(h.ai.get("goal_kind")), ("%d>%d take %s land %s" % [c["from"], c["to"], str(c["take"]), str(c["land"])]) if not c.is_empty() else "-", str(h.ai.get("cross_go")), str((h.ai.get("wp", {}) as Dictionary).get("path", []).slice(0, 2)), float(h.ai.get("stuck", 0)), float(h.ai.get("detour_t", 0.0))])
			for h in m.hunters:
				if h.out or h.extracted or h.riding or h.dropping or h.downed:
					continue
				var s: Dictionary = st[h.nid]
				var df := wrapf(h.face - float(s["face"]), -PI, PI)
				s["turn"] = float(s["turn"]) + absf(df)
				if absf(df) > 0.08 and signf(df) != signf(float(s["dface"])) and absf(float(s["dface"])) > 0.08:
					s["flips"] = int(s["flips"]) + 1
				if absf(df) > 0.02: s["dface"] = df
				s["face"] = h.face
				if h.vel.y - float(s["vy"]) > 6.0 and h.pad.is_empty() and h.vel.y > 5.0:
					s["jumps"] = int(s["jumps"]) + 1
				s["vy"] = h.vel.y
				if h.roll_t > float(s["roll"]) + 0.05:
					s["dashes"] = int(s["dashes"]) + 1
				s["roll"] = h.roll_t
				# (a ledge rise is a climb up a wall, not hanging in the air: it doesn't count)
				if h.hit_marker() == "ring" and not h.gliding and h.lfloat.is_empty():
					s["ring"] = float(s["ring"]) + Match.DT
				s["t"] = float(s["t"]) + Match.DT
				if float(s["t"]) >= WIN:
					var why: Array = []
					if float(s["turn"]) > MAX_TURN: why.append("spin %.0f rad" % float(s["turn"]))
					if int(s["flips"]) > MAX_FLIPS: why.append("%d facing flips" % int(s["flips"]))
					if int(s["jumps"]) > MAX_JUMPS: why.append("%d jumps" % int(s["jumps"]))
					if int(s["dashes"]) > MAX_DASHES: why.append("%d dashes" % int(s["dashes"]))
					if float(s["ring"]) > MAX_RING * WIN: why.append("ring up %.1fs" % float(s["ring"]))
					for k in ["turn", "flips", "jumps", "dashes", "ring"]:
						var v := float(s[k])
						if v > float(worst.get(k, 0.0)): worst[k] = v
					if not why.is_empty() or verbose:
						if not why.is_empty(): flagged += 1
						var a: Dictionary = h.ai
						print("SANITY %s seed %d t=%.0f %s (%s): %s | goal=%s tgt=%s cross=%s gl=%s gr=%s pos=%s turn=%.1f flips=%d jumps=%d dashes=%d ring=%.1f" % ["FLAG" if not why.is_empty() else "    ", sd, m.time, h.pname, h.ctrl, ", ".join(why),
							str(a.get("goal_kind", "")), str(a.get("tgt")).get_slice(":", 0), str(a.has("cross")), h.gliding, h.grounded, str(h.pos.snapped(Vector3(0.1, 0.1, 0.1))),
							float(s["turn"]), int(s["flips"]), int(s["jumps"]), int(s["dashes"]), float(s["ring"])])
					s["turn"] = 0.0; s["flips"] = 0; s["jumps"] = 0; s["dashes"] = 0; s["ring"] = 0.0; s["t"] = 0.0
		print("SANITY seed %d: %d flagged windows over %.0fs" % [sd, flagged, m.time])
		bad += flagged
		m.queue_free()
		await get_tree().process_frame
	print("SANITY worst window: turn %.1f rad, flips %d, jumps %d, dashes %d, ring %.1fs" % [float(worst.get("turn", 0)), int(worst.get("flips", 0)), int(worst.get("jumps", 0)), int(worst.get("dashes", 0)), float(worst.get("ring", 0))])
	print("SANITY done, failures: %d" % bad)
	get_tree().quit(1 if bad > 0 else 0)

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

## The drop: the planning phase, map pings, the squad following its leader in formation, passing the
## lead, separating, and the randomised spawns (different between seeds, rare kin only where rolled).
func _drop_check() -> void:
	var ok := true
	var m := Match.new()
	add_child(m)
	m.start({"teams": 3, "squad": 3, "tier": 0, "seed": 4101})
	m.set_process(false)
	var P: Hunter = m.player
	var D: DropSquad = m.skydrop
	var mates: Array = m.hunters.filter(func(x): return x.team == P.team and x != P)
	print("DCHECK planning=%s plan_t=%.1f riding=%s leader=%s map open=%s" % [D.planning, D.plan_t, P.riding, D.leader(P.team).pname, m.hud.map_open()])
	if not D.planning or absf(D.plan_t - DropSquad.PLAN_T) > 0.01 or not P.riding or D.leader(P.team) != P or not m.hud.map_open():
		ok = false; print("DCHECK FAIL planning phase did not start right")
	# a ping placed on the map (the same path a click takes)
	var target: Vector3 = m.world.spawns[0]
	var sp: SpawnPlan = m.spawn_plan
	if sp and not sp.active_of("vault").is_empty(): target = sp.active_of("vault")[0]["pos"]
	m.hud.full_map.ping_at(target)
	var mine := m.my_ping()
	print("DCHECK map ping at %s -> %s (squad pings %d)" % [str(target.snapped(Vector3(0.1, 0.1, 0.1))), str(mine.get("pos", Vector3.INF)), m.pings.filter(func(q): return q.has("by")).size()])
	if mine.is_empty() or Vector2(mine["pos"].x - target.x, mine["pos"].z - target.z).length() > 0.6: ok = false; print("DCHECK FAIL map ping")
	var steps := 0
	var t0 := m.time
	while D.planning and steps < 2000:
		m.step(Match.DT); steps += 1
	var bot_pings := m.pings.filter(func(q): return q.has("by") and (q["by"] as Hunter).ctrl == "bot").size()
	var acks := m.truce.shown.filter(func(e): return e["id"] == "omw").size() if m.truce else 0
	print("DCHECK planning lasted %.2fs, match clock %.2f -> %.2f, bot pings %d, bot replies %d, events %s" % [steps * Match.DT, t0, m.time, bot_pings, acks, str(D.events)])
	if absf(steps * Match.DT - DropSquad.PLAN_T) > 0.1 or m.time != t0: ok = false; print("DCHECK FAIL planning length / clock")
	if bot_pings < 1: ok = false; print("DCHECK FAIL bots never pinged")
	# a follower can't jump by themselves while the leader is aboard
	var f0: Hunter = mates[0]
	m.ship_jump(f0)
	if not f0.riding: ok = false; print("DCHECK FAIL a follower jumped without the leader")
	# ride to the middle of the map, then the leader jumps
	var mid := Vector3(m.world.w * 0.5, 0, m.world.h * 0.5)
	while Vector2(m.ship_pos().x - mid.x, m.ship_pos().z - mid.z).length() > 26.0 and m.time < 60.0 and P.riding:
		m.step(Match.DT)
	m.ship_jump(P)
	var fol := mates.filter(func(x): return x.drop_follow == P)
	print("DCHECK leader jumped at t=%.1f: %d of %d squadmates jumped with them (%s)" % [m.time, fol.size(), mates.size(), str(mates.map(func(x): return [x.pname, x.riding, x.dropping]))])
	if fol.size() != mates.size(): ok = false; print("DCHECK FAIL the squad didn't jump together")
	var sep_plan: Array = fol.map(func(x): return snappedf(float(x.ai.get("sep_h", -1.0)), 0.1))
	for f in fol: f.ai["sep_h"] = -1.0       # (bots that break off low down: checked below, not here)
	# the leader steers; the squad follows in its slots
	var worst := 0.0; var t := 0.0
	# (the turn is relative to the ship's heading, so every map and ship route tests the same turn:
	# veer 17 degrees right of the flight line, then swing a further 85 degrees right)
	var sdir := Vector2((m.ship["dir"] as Vector3).x, (m.ship["dir"] as Vector3).z).normalized() if m.ship.has("dir") else Vector2(1, 0)
	while t < 1.3 and P.dropping:
		P.inp["move"] = sdir.rotated(0.29) if t < 0.7 else sdir.rotated(1.77)
		m.step(Match.DT); t += Match.DT
		if t > 0.5:
			for f in fol:
				if f.drop_follow == P:
					worst = maxf(worst, D.target_of(f).distance_to(Vector2(f.pos.x, f.pos.z)))
	var spread: Array = fol.map(func(x): return snappedf(Vector2(x.pos.x - P.pos.x, x.pos.z - P.pos.z).length(), 0.1))
	var dy: Array = fol.map(func(x): return snappedf(x.pos.y - P.pos.y, 0.1))
	print("DCHECK formation: worst slot error %.2fm, distance to leader %s, height difference %s (bots planning to break off at %s m)" % [worst, str(spread), str(dy), str(sep_plan)])
	if worst > 1.6 or fol.any(func(x): return x.drop_follow != P): ok = false; print("DCHECK FAIL formation")
	# pass the lead: the next squadmate leads, you follow them
	var passed := D.pass_lead(P)
	var L2: Hunter = D.leader(P.team)
	t = 0.0
	while t < 0.8 and P.dropping:
		m.step(Match.DT); t += Match.DT
	var err2 := D.target_of(P).distance_to(Vector2(P.pos.x, P.pos.z)) if P.drop_follow else 99.0
	print("DCHECK pass lead=%s: leader now %s, you follow %s (slot error %.2fm), others follow %s" % [passed, L2.pname, P.drop_follow.pname if P.drop_follow else "nobody", err2, str(fol.map(func(x): return x.drop_follow.pname if x.drop_follow else "-"))])
	if not passed or L2 == P or P.drop_follow != L2 or err2 > 2.5 or fol.any(func(x): return x != L2 and x.drop_follow != L2): ok = false; print("DCHECK FAIL pass lead")
	# separate: you steer yourself again
	var sep := D.separate(P)
	var v0 := Vector2(P.vel.x, P.vel.z)
	var want := -Vector2(L2.vel.x, L2.vel.z).normalized() if Vector2(L2.vel.x, L2.vel.z).length() > 0.5 else Vector2(-1, 0)
	var alt0 := m.player_altitude()
	t = 0.0
	while t < 0.7 and P.dropping:
		P.inp["move"] = want
		m.step(Match.DT); t += Match.DT
	var v1 := Vector2(P.vel.x, P.vel.z)
	print("DCHECK separate=%s at %.1fm up: solo=%s follow=%s, velocity %s -> %s (steering %s)" % [sep, alt0, P.drop_solo, P.drop_follow, str(v0.snapped(Vector2(0.1, 0.1))), str(v1.snapped(Vector2(0.1, 0.1))), str(want.snapped(Vector2(0.01, 0.01)))])
	if not sep or P.drop_follow != null or not P.drop_solo or v1.normalized().dot(want) < 0.7: ok = false; print("DCHECK FAIL separate")
	# everyone lands
	t = 0.0
	while t < 20.0 and m.hunters.any(func(x): return x.dropping or x.riding):
		m.step(Match.DT); t += Match.DT
	print("DCHECK landed after %.1fs more; squad on ground %s" % [t, str(m.hunters.filter(func(x): return x.team == P.team).map(func(x): return [x.pname, x.grounded, x.pos.snapped(Vector3(1, 1, 1))]))])
	if m.hunters.any(func(x): return x.dropping or x.riding): ok = false; print("DCHECK FAIL someone never landed")
	# on the ground: a ping from you sends your squad's bots there, and one answers
	var bot: Hunter = mates[1] if mates.size() > 1 else mates[0]
	# the drop above is steered by script: if it ended off an island (stuck under a rim), put the
	# ground half of the test on solid ground so it tests pings and scouting, not the glide line
	var base_spot := m.world.free_spot_near(m.world.spawns[0], [], 1.0, 0.5, 8.0)
	for x in [P, bot]:
		# (a scripted glide that ends over the abyss loses that hunter: bring them back first, so the
		# rest tests pings and scouting with everyone alive, not whatever a revive beacon does later)
		if x.out or x.downed:
			Life.bring_back(m, x, base_spot + (Vector3(2.0, 0, 0) if x == bot else Vector3.ZERO), 1.0, false)
		if m.world.is_void(x.pos.x, x.pos.z) or x.pos.y < m.world.ground_at(x.pos.x, x.pos.z) - 1.0:
			x.teleport(base_spot + (Vector3(2.0, 0, 0) if x == bot else Vector3.ZERO))
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for o in m.hunters:
		if o.team != P.team:
			o.ctrl = "idle"; o.teleport(m.world.spawns[-1] + Vector3(0, 0, 0))     # (no fights in the way)
	var ev0 := D.events.size()
	var spot := bot.pos
	for k in 40:
		var q := m.world.free_spot_near(bot.pos + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)), [], 1.0, 0.5, 6.0)
		if m.world.island_of(q.x, q.z) == m.world.island_of(bot.pos.x, bot.pos.z) and bot.flat_dist(q) > 6.0 and bot.flat_dist(q) < 9.0 and m.world.los(bot.pos, q, bot.pos.y + 1.0):
			spot = q; break      # (6-9 m: an unseeded roll, so a far spot made the 6 s walk a coin flip)
	spot.y = m.world.ground_at(spot.x, spot.z)
	m.squad_ping(P, spot)
	var d0 := bot.flat_dist(spot)
	var went := false
	var closest := d0
	t = 0.0
	while t < 6.0:
		m.step(Match.DT); t += Match.DT
		# any squad bot: one busy with its downed Boki or a beacon leaves it to the other
		if mates.any(func(x): return String(x.ai.get("goal_kind", "")) == "ping"): went = true
		closest = minf(closest, mates.map(func(x): return x.flat_dist(spot)).min())
	var replies: Array = D.events.slice(ev0).filter(func(e): return String(e).begins_with("reply"))
	print("DCHECK ground ping: %s headed there=%s, %.1fm -> got within %.1fm; replies %s (from %s to %s)" % [bot.pname, went, d0, closest, str(replies), str(bot.pos.snapped(Vector3(0.1, 0.1, 0.1))), str(spot.snapped(Vector3(0.1, 0.1, 0.1)))])
	if not went or closest > 4.0 or not replies.any(func(r): return String(r).ends_with("omw")): ok = false; print("DCHECK FAIL squad bots ignore pings")
	m.unping(P)
	if not m.my_ping().is_empty() or bot.ai.has("ping_goal"): ok = false; print("DCHECK FAIL right click didn't take the ping down")
	# the spawns: the same candidates every match, a different live subset per seed
	var layout := World.load_layout(World.layout_for_tier(0))
	var subsets := {}
	for sd in [4101, 4102, 4103]:
		var plan := SpawnPlan.new(m)
		plan.build(layout)
		plan.roll(sd)
		subsets[sd] = plan.active_ids()
	print("DCHECK candidates %s; live by seed: %s" % [str(sp.shown_cats().map(func(cc): return "%s %d/%d" % [cc, sp.active_of(cc).size(), sp.of(cc).size()])), str(subsets)])
	if subsets[4101] != sp.active_ids(): ok = false; print("DCHECK FAIL the same seed rolled differently")
	if subsets[4101] == subsets[4102] and subsets[4102] == subsets[4103]: ok = false; print("DCHECK FAIL seeds roll the same spawns")
	# a generated map (no authored list): candidates come from its islands, the same for the same map
	var gm := Match.new()
	gm.world = World.new()
	gm.world.generate(9, World.BIG_SIZE, World.BIG_ISLANDS)
	var g1 := SpawnPlan.new(gm); g1.build({})
	var g2 := SpawnPlan.new(gm); g2.build({})
	var gpos: Array = g1.cands.map(func(cc): return cc["pos"])
	var counts: Array = g1.shown_cats().map(func(cc): return "%s %d" % [cc, g1.count_of(cc)])
	print("DCHECK generated map candidates: %s (same both times=%s)" % [str(counts), gpos == g2.cands.map(func(cc): return cc["pos"])])
	if g1.count_of("rare_kin") < 3 or g1.count_of("vault") < 2 or g1.count_of("cache") < 4 or gpos != g2.cands.map(func(cc): return cc["pos"]): ok = false; print("DCHECK FAIL generated map candidates")
	gm.world.free(); gm.free()
	# rare kin only at the live rare-kin points, one at each
	var rare: Array = m.kins.filter(func(k): return k.has_meta("rare"))
	var live: Array = sp.active_of("rare_kin")
	var stray := 0
	for k in rare:
		var near := false
		for cnd in live:
			if Vector2(k.home.x - cnd["pos"].x, k.home.z - cnd["pos"].z).length() < 3.0: near = true
		if not near: stray += 1
	var at_dead := 0
	for cnd in sp.of("rare_kin"):
		if cnd["active"]: continue
		for k in rare:
			if Vector2(k.home.x - cnd["pos"].x, k.home.z - cnd["pos"].z).length() < 3.0: at_dead += 1
	print("DCHECK rare kin: %d spawned for %d live points (%d strays, %d at points not rolled)" % [rare.size(), live.size(), stray, at_dead])
	if rare.size() != live.size() or stray > 0 or at_dead > 0: ok = false; print("DCHECK FAIL rare kin spawns")
	# scouting: walk the player to an unrolled candidate and its state turns from "?" to empty
	var hidden: Array = sp.cands.filter(func(cc): return not sp.cats[cc["cat"]].get("announce", false) and not cc["active"])
	if not hidden.is_empty():
		var hc: Dictionary = hidden[0]
		var before := sp.state_for(hc, P.team)
		if P.out or P.downed: Life.bring_back(m, P, hc["pos"], 1.0, false)      # (walking off an island is allowed now: the player may have gone over the edge during the checks above; same bring-back as the ground half)
		P.teleport(hc["pos"] + Vector3(1.5, 0, 0))
		for i in 30: m.step(Match.DT)
		print("DCHECK scouting %s: %s -> %s" % [hc["id"], before, sp.state_for(hc, P.team)])
		if before != "unknown" or sp.state_for(hc, P.team) != "empty": ok = false; print("DCHECK FAIL scouting")
	m.over = true
	print("DCHECK ", "PASS" if ok else "FAIL")
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


## Headless check for build mode at home: the island is bigger, things place, turn, move and go into
## storage, bad spots are refused (overlaps, the void, cutting off a door), the layout survives a save
## and reload, an old save without a layout migrates, kin walk round a fence, and expanding adds land.
func _home_build_check() -> void:
	Save.no_write = true
	var bad := [0]
	var ok := func(cond: bool, what: String) -> void:
		print("HOMEBUILD %s %s" % ["ok  " if cond else "FAIL", what])
		if not cond: bad[0] += 1
	var t0 := HomeLayout.main_tiles(0)
	var t1 := HomeLayout.main_tiles(1)
	ok.call(t0 >= 900, "the main island has %d open tiles (the old one had about 480)" % t0)
	ok.call(t1 > t0 + 100, "one expansion step grows it to %d tiles (+%d)" % [t1, t1 - t0])
	# a save with a few kin and buildings
	Save.d = Save.fresh()
	var pk := Save.new_kin("zapple", "Pip"); Save.d["roster"].append(pk); Save.d["active"] = pk["uid"]
	for sp in ["cindle", "puddlet"]: Save.d["roster"].append(Save.new_kin(sp))
	Save.d["tutorial"]["home"] = true; Save.d["tutorial"]["day1_done"] = true
	Save.d["gems"] = 5000; Save.d["scrap"] = 100
	Save.d["buildings"].append_array(["workshop", "board", "ransom"])
	Econ.ensure()
	var home = await _hb_home()
	var hb: HomeBuild = home.hb
	ok.call(hb != null and (HomeLayout.of(Save.d)["deco"] as Array).size() == HomeLayout.STOCK.size(), "a new save's layout starts with the farm's lamps and flower beds as decorations")
	hb.toggle()
	ok.call(hb.active and is_instance_valid(hb.bar), "build mode opens with its catalog bar")
	var spot := func(item: Dictionary, sz := Vector2i(1, 1)) -> Vector2i:
		for z in range(34, 46):
			for x in range(52, 62):
				var cs := HomeLayout.cells_of([x, z, x + sz.x - 1, z + sz.y - 1])
				if hb.fits(item, cs): return Vector2i(x, z)
		return Vector2i(-1, -1)
	var put := func(cs: Array) -> bool:
		hb.cells = cs; hb._check_cells()
		return hb.place_held()
	# place
	var g0 := int(Save.d["gems"])
	var n0 := (HomeLayout.of(Save.d)["deco"] as Array).size()
	hb.take("lantern")
	var lt: Vector2i = spot.call(hb.held)
	ok.call(lt.x >= 0 and put.call([lt]), "a lantern goes down on open meadow at %s" % str(lt))
	ok.call((HomeLayout.of(Save.d)["deco"] as Array).size() == n0 + 1 and int(Save.d["gems"]) == g0 - 15, "it's in the layout and cost 15 gems")
	# refused spots
	hb.take("kin_statue")
	ok.call(not put.call([lt]), "nothing goes on top of the lantern (%s)" % hb.why)
	ok.call(not put.call([Vector2i(1, 1)]), "nothing goes in the sky (%s)" % hb.why)
	ok.call(not put.call([Vector2i(38, 26)]), "nothing goes on the house (%s)" % hb.why)
	# turn
	hb.take("bench")
	hb.rotate_held()
	var bt: Vector2i = spot.call(hb.held, Vector2i(1, 2))
	ok.call(bt.x >= 0 and put.call(HomeLayout.cells_of([bt.x, bt.y, bt.x, bt.y + 1])), "a bench turned a quarter fits a 1x2 footprint")
	var last: Dictionary = (HomeLayout.of(Save.d)["deco"] as Array)[-1]
	ok.call(String(last["id"]) == "bench" and int(last["r"]) == 1 and Vector2i(HomeLayout.size_of("bench", 1)) == Vector2i(1, 2), "the bench is saved turned (r=%d)" % int(last["r"]))
	ok.call(home.world.is_block(bt.x + 0.5, bt.y + 1.5), "the bench blocks walking")
	hb._drop_held()
	# move a building
	var old_rc := HomeLayout.rect_of("workshop", Save.d)
	hb.take_building("workshop")
	hb.rotate_held()
	var ws: Vector2i = spot.call(hb.held, HomeLayout.turned(HomeLayout.base_size("workshop"), int(hb.held["r"])))
	var nrc := HomeLayout.rect_at("workshop", ws.x, ws.y, int(hb.held["r"]))
	ok.call(ws.x >= 0 and put.call(HomeLayout.cells_of(nrc)), "the Workshop picks up, turns and drops at %s" % str(ws))
	ok.call(HomeLayout.rect_of("workshop", Save.d) == nrc and home.world.is_block(nrc[0] + 0.5, nrc[1] + 0.5) and not home.world.is_block(old_rc[0] + 0.5, old_rc[1] + 0.5), "its footprint moved in the world (old lot open again)")
	ok.call(home.lots["workshop"]["door"].distance_to(HomeLayout.door_at("workshop", ws.x, ws.y, 1)) < 0.01 and int(HomeLayout.place_of("workshop", Save.d)["r"]) == 1, "its door turned with it")
	# a ring of fence round its door would shut it in
	var door: Vector3 = home.lots["workshop"]["door"]
	var ring: Array = []
	for z in range(int(door.z) - 2, int(door.z) + 3):
		for x in range(int(door.x) - 2, int(door.x) + 3):
			if absi(x - int(door.x)) == 2 or absi(z - int(door.z)) == 2: ring.append(Vector2i(x, z))
	ok.call(not hb.keeps_paths([], ring), "a fence ring round the Workshop door is refused: it would cut the door off")
	# store and undo
	hb.pick_up_at(lt)
	ok.call(hb.held.get("id", "") == "lantern" and int(hb.held.get("from", -1)) > 0, "clicking the lantern picks it up")
	hb.store_held()
	var lay: Dictionary = HomeLayout.of(Save.d)
	ok.call(int(lay["inv"].get("lantern", 0)) == 1 and not lay["deco"].any(func(e): return String(e["id"]) == "lantern"), "X puts it in storage")
	hb.undo_last()
	lay = HomeLayout.of(Save.d)
	ok.call(lay["deco"].any(func(e): return String(e["id"]) == "lantern") and int(lay["inv"].get("lantern", 0)) == 0, "undo brings it back")
	# paint a path and a pond
	hb.take("path_stone")
	var pt: Vector2i = spot.call({"kind": "deco", "id": "flowers", "from": -1})
	hb.drag = {"from": pt, "tiles": {pt: true, pt + Vector2i(1, 0): true}, "last": pt}
	hb.cells = (hb.drag["tiles"] as Dictionary).keys(); hb._check_cells()
	ok.call(hb.place_held() and String(lay["paths"].get(HomeLayout.key(pt.x, pt.y), "")) == "path_stone" and home.world.paint.has(home.world.idx(pt.x, pt.y)), "a stone path paints two tiles")
	hb.take("water")
	var wt: Vector2i = spot.call({"kind": "deco", "id": "bush", "from": -1})
	hb.drag = {"from": wt, "tiles": {wt: true}, "last": wt}
	hb.cells = [wt]; hb._check_cells()
	ok.call(hb.place_held() and home.water.depth(wt.x + 0.5, wt.y + 0.5) > 0 and not home.world.is_block(wt.x + 0.5, wt.y + 0.5), "a pond tile goes down (water you can wade into, but nothing can be built on it)")
	# kin walk round a fence
	var fx := 56; var fz := 41
	var line: Array = []
	for z in range(fz - 4, fz + 5): line.append(Vector2i(fx, z))
	hb.take("fence")
	hb.drag = {"from": line[0], "tiles": {}, "last": line[0]}
	hb.cells = line; hb._check_cells()
	var placed := hb.place_held()
	hb._drop_held()
	ok.call(placed and home.world.is_block(fx + 0.5, fz + 0.5), "a 9-tile fence line goes down (%s)" % hb.why)
	var kd: Dictionary = home.kins[0]
	for o in home.kins:
		if o != kd: o["busy"] = true
	kd.erase("indoors"); (kd["node"] as Node3D).visible = true
	kd["pos"] = Vector3(fx - 2.5, 0, fz + 0.5); kd["goal"] = Vector3(fx + 3.5, 0, fz + 0.5); kd["t"] = 999.0
	for nk in Care.NEEDS: kd["rec"]["needs"][nk] = 100.0
	var through := false; var reached := false
	for i in 500:
		kd["t"] = 999.0; kd["goal"] = Vector3(fx + 3.5, 0, fz + 0.5)
		home._move_kin(0.05)
		var kp: Vector3 = kd["pos"]
		if int(floor(kp.x)) == fx and absi(int(floor(kp.z)) - fz) <= 4: through = true
		if Vector2(kp.x - fx - 3.5, kp.z - fz - 0.5).length() < 0.6: reached = true; break
	ok.call(reached and not through, "a kin walks round the fence to the far side (reached=%s through=%s)" % [reached, through])
	for o in home.kins: o["busy"] = false
	# buying a feeder goes straight into placing it, and it waits in storage until it's down
	Save.d["feeder_inv"]["basket"] = 1
	home.hecon.start_carry("basket")
	ok.call(hb.active and hb.held.get("kind", "") == "feeder", "buying a feeder opens build mode holding it")
	var nf0 := Econ.feeders().size()
	var fpt := Vector2i(-1, -1)
	for z in range(36, 46):
		for x in range(50, 62):
			if fpt.x < 0 and hb.feeder_fits(Vector2i(x, z), ""): fpt = Vector2i(x, z)
	hb.cells = [fpt]; hb._check_cells()
	ok.call(fpt.x >= 0 and hb.place_held() and Econ.feeders().size() == nf0 + 1 and int(Save.d["feeder_inv"].get("basket", 0)) == 0, "it sets down on a green spot (%s) and leaves storage" % str(fpt))
	hb.pick_up_at(fpt)
	ok.call(hb.held.get("kind", "") == "feeder" and String(hb.held.get("from", "")) != "", "a feeder that's out can be picked up again")
	hb._drop_held()
	# save and reload
	var ws_at: Vector3 = home.lots["workshop"]["at"]
	var deco_n := (HomeLayout.of(Save.d)["deco"] as Array).size()
	var js := JSON.stringify(Save.d)
	home.queue_free()
	await get_tree().process_frame
	Save.d = JSON.parse_string(js)
	var home2 = await _hb_home()
	ok.call(home2.lots["workshop"]["at"].distance_to(ws_at) < 0.01 and (HomeLayout.of(Save.d)["deco"] as Array).size() == deco_n and home2.hb.nodes.size() > 0 and home2.world.is_block(fx + 0.5, fz + 0.5), "after a save and reload the Workshop, %d decorations and the fence are where they were" % deco_n)
	ok.call(home2.water.depth(wt.x + 0.5, wt.y + 0.5) > 0 and home2.world.paint.has(home2.world.idx(pt.x, pt.y)), "the pond tile and the path come back too")
	# expanding
	var gl := int(HomeLayout.of(Save.d)["grow"])
	ok.call(home2.hb.expand() and int(HomeLayout.of(Save.d)["grow"]) == gl + 1, "Expand pays and grows the island a step (now %d)" % (gl + 1))
	home2.queue_free()
	await get_tree().process_frame
	var home3 = await _hb_home()
	var n3 := 0
	for i in home3.world.kind.size():
		if home3.world.island[i] == 0 and home3.world.kind[i] != World.T_VOID: n3 += 1
	ok.call(n3 > t0 + 100, "the grown island has %d tiles of land" % n3)
	home3.queue_free()
	await get_tree().process_frame
	# an old save: no layout, the greenhouse on the Orchard Isle, and a feeder on the old orchard
	var od := Save.fresh()
	var ok2 := Save.new_kin("puddlet", "Drip"); od["roster"].append(ok2); od["active"] = ok2["uid"]
	od["tutorial"] = {"home": true, "day1_done": true}
	od["buildings"] = ["workshop", "greenhouse", "board", "ransom"]
	od["bridges"] = ["orchard"]
	od["feeders"] = [{"id": "f1", "kind": "trough", "x": 61.0, "z": 39.5, "food": [], "auto": true}, {"id": "f2", "kind": "trough", "x": 40.4, "z": 29.4, "food": [], "auto": true}]
	od["feeder_given"] = true
	od.erase("layout")
	Save.d = JSON.parse_string(JSON.stringify(od))
	Econ.ensure()
	var home4 = await _hb_home()
	var f1: Dictionary = Econ.feeders()[0]
	ok.call(typeof(Save.d.get("layout")) == TYPE_DICTIONARY and (Save.d["layout"]["deco"] as Array).size() == HomeLayout.STOCK.size(), "an old save gets a layout (the farm's lamps and flower beds)")
	ok.call(home4.world.island_id(home4.lots["greenhouse"]["at"].x, home4.lots["greenhouse"]["at"].z) == "orchard" and home4.world.is_block(home4.lots["greenhouse"]["at"].x, home4.lots["greenhouse"]["at"].z), "its greenhouse stands on the (moved) Orchard Isle")
	ok.call(not home4.world.is_void(float(f1["x"]), float(f1["z"])), "a feeder left out where there's no land now is moved to open ground (%.1f, %.1f)" % [float(f1["x"]), float(f1["z"])])
	ok.call(home4.lots["workshop"]["at"].distance_to(HomeLayout.rect_center(Data.BUILDINGS["workshop"]["rect"])) < 0.01, "its Workshop stays on its old lot")
	# moving at home: dash, glide, falling off
	var mv: Node = home4
	mv.ppos = Vector3(38.0, 0, 34.5); mv.py = 0.0; mv.pvy = 0.0
	var x0: float = mv.ppos.x
	mv.dash_charges = 2.0
	mv.start_dash(Vector2(1, 0), 23.0, 0.15)
	for i in 6: mv._move_player(0.05)
	ok.call(mv.ppos.x - x0 > 2.0, "a dash at home carries you %.1fm" % (mv.ppos.x - x0))
	mv.py = 1.2; mv.pvy = 0.0; mv.gliding = true
	var y0: float = mv.py
	Input.action_press("jump")
	mv._move_player(0.5)
	Input.action_release("jump")
	ok.call(mv.gliding and y0 - mv.py < 1.5 and y0 - mv.py > 0.3, "gliding sinks slowly (%.2fm in half a second)" % (y0 - mv.py))
	mv.gliding = false
	var safe: Vector3 = mv.safe_at
	mv.ppos = Vector3(2.0, 0, 2.0); mv.py = -0.5; mv.pvy = -5.0
	# (no glider: the jump pressed above still reads as pressed in a headless run, which opens one, and
	# an open glider now lifts you back to the lip over the abyss instead of sinking. A panel open
	# means no keys)
	mv.panel_open = "test"
	for i in 60:
		mv.gliding = false
		mv._move_player(0.05)
	mv.panel_open = ""
	ok.call(mv.ppos.distance_to(safe) < 0.01 and mv.py >= -0.01, "falling off the island puts you back where you last stood")
	Save.d["classes"] = ClassUnlock.legacy()      # an old save: every Hunter open (the locks: --hunter-unlock-check)
	# dashing at home: the match's charges and recharge for each class, then the long dash
	var cls0 := String(Save.d.get("cls", "medium"))
	mv.ppos = Vector3(38.0, 0, 34.5); mv.py = mv._ground_h(38.0, 34.5); mv.pvy = 0.0; mv.gliding = false
	for ck in ["light", "medium", "heavy"]:
		Save.d["cls"] = ck
		var dg: Dictionary = mv._dodge()
		var want := int(Content.class_dodge(ck).charges) if Content.class_dodge(ck) else int(Data.CLASSES[ck]["dashes"])
		mv.ppos = Vector3(38.0, 0, 34.5); mv.py = mv._ground_h(38.0, 34.5); mv.pvy = 0.0; mv.dash_t = 0.0; mv.ex_cd = 0.0
		mv.dash_charges = 9.0; mv._move_player(0.0001)     # topped up to the class's count
		var shorts := 0
		var longs := 0
		for k in want + 2:
			mv.dash_t = 0.0; mv.ppos = Vector3(38.0, 0, 34.5); mv.py = mv._ground_h(38.0, 34.5); mv.pvy = 0.0
			var had: float = mv.dash_charges
			if mv.try_dash(Vector2(1, 0), false):
				if had >= 1.0: shorts += 1
				else: longs += 1
		var regen := float(dg["cd"])
		mv.dash_t = 0.0
		var waited := 0.0
		while mv.dash_charges < 1.0 and waited < 40.0:
			mv.ppos = Vector3(38.0, 0, 34.5); mv.py = mv._ground_h(38.0, 34.5); mv.pvy = 0.0; mv.dash_t = 0.0
			mv._move_player(0.05); waited += 0.05
		mv.dash_t = 0.0
		var again: bool = mv.try_dash(Vector2(1, 0), false)
		ok.call(shorts == want and longs == 1 and absf(waited - regen) < 0.2 and again and absf(float(dg["ex_cd"]) - float(Data.CLASSES[ck]["ex_cd"])) < 0.01,
			"%s dashes at home as in a match: %d short (%d), then the long one (%d), %.1fs to recharge (dodge cooldown %.1fs), then again (%s)" % [ck, shorts, want, longs, waited, regen, again])
	Save.d["cls"] = cls0
	mv.dash_t = 0.0
	home4.queue_free()
	await get_tree().process_frame
	# procedural homes: two seeds, two different islands, both usable; the first look round
	var sigs: Array = []
	for sd in [1234567, 7654321]:
		Save.d = Save.fresh()
		var nk := Save.new_kin("zapple", "Pip"); Save.d["roster"].append(nk); Save.d["active"] = nk["uid"]
		Save.d["tutorial"] = {"home": true, "day1_done": true}
		Save.d["layout"] = HomeLayout.fresh()
		Save.d["layout"]["seed"] = sd; Save.d["layout"]["made"] = false
		HomeLayout.ensure(Save.d)
		Econ.ensure()
		var hp = await _hb_home()
		var vr: Dictionary = hp.hb.validate()
		ok.call(vr["ok"], "seed %d: %d open tiles, all %d reachable, %d places missed, %d wild tiles" % [sd, vr["open"], vr["reached"], (vr["missing"] as Array).size(), hp.hb.wild_t.size()])
		var sg := ""
		for i in hp.world.kind.size(): sg += str(hp.world.kind[i])
		sigs.append(sg)
		ok.call(hp.hb.needs_making(), "a new home asks where things go first")
		var sug: Dictionary = hp.hb.make if not hp.hb.make.is_empty() else hp.hb.suggest()
		hp.hb.use_suggested()
		var ws2: Dictionary = HomeLayout.place_of("workshop", Save.d)
		ok.call(not hp.hb.needs_making() and not (sug.get("workshop", []) as Array).is_empty() and int(ws2["x"]) == int(sug["workshop"][0]["x"]) and hp.hb.validate()["ok"], "Use suggested layout puts the Workshop lot at %s and the feeder by the pot, still all reachable (%s)" % [str(ws2), str(hp.hb.validate())])
		hp.queue_free()
		await get_tree().process_frame
	ok.call(sigs[0] != sigs[1], "the two seeds made different islands")
	print("HOMEBUILD done, failures: %d" % bad[0])
	get_tree().quit(1 if bad[0] > 0 else 0)

func _hb_home():
	var H = load("res://scripts/home/home.gd")
	var hm = H.new()
	add_child(hm)
	current = hm
	await get_tree().process_frame
	await get_tree().process_frame
	return hm
