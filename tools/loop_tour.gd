extends Node
## Demo QA tooling: plays the core loop end to end in a window, through the real screens and keys,
## and saves a numbered screenshot at each step.
##   --loop-tour[=<archetype>]     (default thief)
##   --tour-out=<dir>              where the PNGs go (default /tmp/tour)
##   --tour-part=front|home|exp|all  which part to play (default all; "home" and "exp" start from a
##                                   made-up save with one hatched Boki, so they can run on their own)
## Prints "TOUR ..." lines: each shot, what was on screen, and anything that went wrong ("TOUR BAD").
## The player can't die (health refilled each frame) and a few slow waits are shortened (the uplink
## comes online at once, levels 2-6 are granted after the first kills): it's a camera tour, not a test
## of balance. Never writes the save.

var out := "/tmp/tour"
var arch := "thief"
var part := "all"
var n := 0
var bad := 0
var god := false
var aim_at = null           # an Ent (or Vector3) the mouse is kept on while a match runs
var hold_keys: Array = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--loop-tour="): arch = a.substr(12)
		if a.begins_with("--tour-out="): out = a.substr(11)
		if a.begins_with("--tour-part="): part = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	process_priority = -10
	_run.call_deferred()

func _run() -> void:
	print("TOUR start arch=%s part=%s" % [arch, part])
	if part in ["all", "front"]:
		await _front()
	if part in ["home", "exp"] and Save.d["roster"].is_empty():
		_fake_save()
	if part in ["all", "home"]:
		await _home()
	if part in ["all", "exp"]:
		await _expedition()
	print("TOUR DONE shots=%d bad=%d" % [n, bad])
	get_tree().quit()

# ------------------------------------------------------------------ helpers
func cur() -> Node:
	return Game.main.screen_node() if Game.main else null

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func frames(k: int) -> void:
	for i in k: await get_tree().process_frame

## Wait until the match clock has moved on s seconds (it runs slower than real time on a slow box).
func mwait(s: float, cap := 0.0) -> void:
	var m = _match()
	if m == null:
		await wait(s); return
	var t0: float = m.time
	var w0 := Time.get_ticks_msec()
	var capms := (cap if cap > 0.0 else s * 6.0 + 5.0) * 1000.0
	while is_instance_valid(m) and m.time - t0 < s and Time.get_ticks_msec() - w0 < capms:
		await get_tree().process_frame

func until(cond: Callable, cap: float, what: String) -> bool:
	var w0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - w0 > cap * 1000.0:
			note_bad("timed out waiting for " + what)
			return false
		await get_tree().process_frame
	return true

func note_bad(s: String) -> void:
	bad += 1
	print("TOUR BAD ", s)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	var p := "%s/%s_%02d_%s.png" % [out, arch, n, label]
	get_viewport().get_texture().get_image().save_png(p)
	print("TOUR shot %02d %-22s %s" % [n, label, _state()])

func _state() -> String:
	var m = _match()
	if m and is_instance_valid(m) and m.player:
		var P: Hunter = m.player
		return "t=%.1f lvl=%d hp=%d/%d pos=(%.0f,%.1f,%.0f) riding=%s drop=%s gr=%s int=%s" % [m.time, P.lvl, P.hp, P.max_hp, P.pos.x, P.pos.y, P.pos.z, P.riding, P.dropping, P.grounded, String(m.interact.get("label", ""))]
	var c := cur()
	return "screen=%s" % (c.get_script().resource_path.get_file() if c and c.get_script() else "?")

func _match():
	var c = Game.main.current if Game.main else null
	return c if c is Match else null

## Presses the first visible button whose text starts with `txt` (anywhere in the tree).
func press(txt: String) -> bool:
	var b := _find_button(get_tree().root, txt)
	if b == null:
		note_bad("no button '%s'" % txt)
		return false
	b.pressed.emit()
	return true

func _find_button(nd: Node, txt: String) -> BaseButton:
	if nd is BaseButton and (nd as Control).is_visible_in_tree() and nd is Button and String((nd as Button).text).begins_with(txt):
		return nd
	for ch in nd.get_children():
		var r := _find_button(ch, txt)
		if r: return r
	return null

func key(action: String, hold := 0.12) -> void:
	Input.action_press(action)
	await frames(2)          # (seen pressed for at least a frame, however slow the frames are)
	await wait(hold)
	Input.action_release(action)
	await frames(2)

func key_event(code: Key) -> void:
	var e := InputEventKey.new(); e.physical_keycode = code; e.keycode = code; e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var e2 := InputEventKey.new(); e2.physical_keycode = code; e2.keycode = code; e2.pressed = false
	Input.parse_input_event(e2)
	await frames(2)

var _feed: Array = []
var _was_match := false
func _process(_d: float) -> void:
	var m = _match()
	if m == null or not is_instance_valid(m) or m.player == null:
		if _was_match and not Game.last_result.is_empty() and String(Game.last_result.get("why", "")) != "extracted":
			print("TOUR the match ended: %s; last feed: %s" % [str(Game.last_result.get("why", "?")), str(_feed.slice(-8))])
		_was_match = false
		return
	_was_match = not m.over
	_feed = m.feed_all
	if god:
		var P: Hunter = m.player
		P.hp = P.max_hp
		if P.downed: m.revive_hunter(P, P)
	if aim_at != null and m.cam:
		var p: Vector3 = aim_at if aim_at is Vector3 else ((aim_at as Node3D).global_position if is_instance_valid(aim_at) else Vector3.INF)
		var c3 := get_viewport().get_camera_3d()
		if p != Vector3.INF and c3 and not c3.is_position_behind(p):
			get_viewport().warp_mouse(c3.unproject_position(p + Vector3(0, 0.6, 0)))

func _fake_save() -> void:
	Save.d["look"] = Models.default_look()
	Save.d["arch"] = arch; Save.d["cls"] = Arch.weight(arch); Save.d["weapon"] = Arch.default_weapon(arch)
	var rec := Save.new_kin("cindle", "Ember")
	rec["trust"] = 55.0; rec["starter"] = true
	Save.d["roster"] = [rec]; Save.d["active"] = rec["uid"]
	for k in ["intro", "prologue", "hatched", "match", "home"]: Save.d["tutorial"][k] = true

# ------------------------------------------------------------------ 1. title to the farm
func _front() -> void:
	Game.goto("title")
	await wait(4.0)
	await shot("title")
	press("New game")
	await wait(4.5)
	await shot("prologue_1")
	for i in 2:
		var pr := cur()
		if pr and pr.has_method("_advance"):
			pr.set("shot_t", 9.0)
			pr._advance()
		await wait(4.0)
		await shot("prologue_%d" % (i + 2))
	var pr2 := cur()
	if pr2 and pr2.has_method("_finish"): pr2._finish()
	await wait(3.5)
	await shot("story")
	var hx := cur()
	if hx == null or not hx.has_method("_next_story"):
		note_bad("not on the hatch screen after the prologue"); return
	for i in 3:
		hx._next_story()
		await wait(0.4)
	await wait(1.5)
	await shot("creator")
	var guard := 0
	while Arch.of_save() != arch and guard < 8:
		hx._step_arch(1); guard += 1
		await wait(0.3)
	await wait(1.2)
	await shot("creator_" + arch)
	press("Looks good")
	await wait(2.0)
	await shot("egg_pick")
	hx._pick(0)
	await wait(0.8)
	await shot("egg_chosen")
	press("Hatch it")
	await wait(1.0)
	for i in 7:
		hx._tap_egg()
		await wait(0.35)
		if i == 3: await shot("egg_tapping")
	await until(func(): return String(hx.stage) in ["reveal", "name"], 60.0, "the egg to hatch")
	await wait(1.2)
	await shot("hatch_reveal")
	await wait(2.5)
	await shot("hatch_reveal2")
	var rv := _find_class(hx, "KinReveal")
	if rv:
		await until(func(): return not is_instance_valid(rv) or bool(rv.get("ready_to_name")), 40.0, "the reveal to finish")
		if is_instance_valid(rv): rv._go()
	await until(func(): return String(hx.stage) == "name", 20.0, "the naming card")
	await wait(1.0)
	await shot("name_boki")
	press("Skip the tutorial")
	await _wait_home()

func _find_class(nd: Node, cname: String) -> Node:
	for ch in nd.get_children():
		if ch.get_script() and String(ch.get_script().get_global_name()) == cname: return ch
		var r := _find_class(ch, cname)
		if r: return r
	return null

func _wait_home() -> void:
	await until(func(): var c := cur(); return c != null and c.get_script() and c.get_script().resource_path.ends_with("home/home.gd") and c.get("player") != null, 120.0, "the farm")
	await wait(3.0)

# ------------------------------------------------------------------ 2. the farm
func _home() -> void:
	var h := cur()
	if h == null or not h.get_script().resource_path.ends_with("home.gd"):
		Game.goto("home")
		await _wait_home()
		h = cur()
	await shot("farm_arrive")
	if String(h.panel_open) != "":
		print("TOUR panel open on arrival: ", h.panel_open)
		if String(h.panel_open) == "Make it home":
			press("Use suggested layout")
			await wait(1.5)
			await shot("farm_made_home")
		if String(h.panel_open) != "":
			h._close_panel()
		await wait(0.6)
	Input.action_press("right"); Input.action_press("down")
	await wait(1.4)
	await shot("farm_walk")
	Input.action_release("right"); Input.action_release("down")
	await wait(0.5)
	if h.kins.is_empty():
		note_bad("no Boki on the farm")
	else:
		var k: Dictionary = h.kins[0]
		h.ppos = k["pos"] + Vector3(1.3, 0, 0.9)
		h.cam.snap(h.ppos)
		await wait(1.0)
		await shot("farm_near_boki")
		h._pet_kin(k)
		await wait(0.7)
		await shot("farm_pet")
		await key_event(KEY_T)       # talk
		await wait(1.2)
		await shot("farm_talk")
		if String(h.panel_open) != "": h._close_panel()
		if h.has_method("_close_chat"): h._close_chat()
		await wait(0.5)
		h._open_kin(k["rec"])
		await wait(1.2)
		await shot("farm_boki_card")
		h._close_panel()
		await wait(0.5)
	h._open_expedition()
	await wait(1.5)
	await shot("loadout")
	var sc = h._panel_scroll()
	if sc:
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
		await wait(0.6)
		await shot("loadout_bottom")
	h._close_panel()
	await wait(0.4)
	# the Training Grounds isle at home
	if h.training:
		h.ppos = HomeTraining.STILL + Vector3(1.6, 0, 0.4)
		h.cam.snap(h.ppos)
		await wait(1.0)
		for i in 4:
			h.training.cds.clear(); h.training.cast("fire")
			await wait(0.3)
		await shot("farm_training_grounds")
	# the training area (a match)
	h._start_training()
	await _wait_match(60.0)
	god = true
	await mwait(2.0)
	await shot("training_area")
	var m = _match()
	if m:
		await _cast_round(m, "training", false)
	god = false
	Game.goto("home")
	await _wait_home()

# ------------------------------------------------------------------ 3. the expedition
func _wait_match(cap: float) -> bool:
	return await until(func(): var m = _match(); return m != null and m.player != null and m.is_processing() and m.hud != null, cap, "the match to start")

func _expedition() -> void:
	var h := cur()
	if h == null or not h.get_script().resource_path.ends_with("home.gd"):
		Game.goto("home")
		await _wait_home()
		h = cur()
	Save.d["arch"] = arch; Save.d["cls"] = Arch.weight(arch); Save.d["weapon"] = Arch.default_weapon(arch)
	h._open_expedition()
	await wait(1.0)
	await shot("exp_loadout")
	press("Start expedition")
	await wait(0.6)
	if _find_button(get_tree().root, "I understand") != null: press("I understand")
	# the loading screen
	for i in 3:
		await wait(1.6)
		await shot("loading_%d" % (i + 1))
	if not await _wait_match(120.0):
		return
	var m = _match()
	god = true
	if m.skydrop and m.skydrop.planning:
		await shot("drop_planning")
		await until(func(): return not m.skydrop.planning, 30.0, "planning to end")
	await mwait(1.0)
	await shot("skyship")
	await mwait(3.0)
	# jump when the ship is over land
	await until(func(): return not m.player.riding or not m.world.is_void(m.ship_pos().x, m.ship_pos().z) and m.time > 4.0, 60.0, "the ship to cross land")
	if m.player.riding:
		await key("jump")
		await mwait(0.3)
		if m.player.riding:
			note_bad("Space didn't jump off the ship (%s)" % ("waits for the leader" if m.skydrop and m.skydrop.waits(m.player) else "?"))
			m.ship_jump(m.player, true)
	await mwait(1.0)
	await shot("drop_high")
	await mwait(3.0)
	await shot("drop_mid")
	await until(func(): return not m.player.dropping and m.player.grounded, 60.0, "landing")
	await mwait(0.6)
	await shot("landed")
	# (direct awaits: resuming these through Callable.call() once crashed Godot 4.6.2 with SIGSEGV)
	await _fight(m)
	if _gone(m): return
	await _level_up(m)
	if _gone(m): return
	await _cast_round(m, "exp", true)
	if _gone(m): return
	await _tame(m)
	if _gone(m): return
	await _lair(m)
	if _gone(m): return
	await _extract(m)

func _gone(m) -> bool:
	if is_instance_valid(m) and not m.over:
		return false
	note_bad("the match ended early (%s)" % str(Game.last_result.get("why", "?")))
	return true

func _nearest_mob(m, maxd := 1e9) -> Mob:
	var best: Mob = null; var bd := maxd
	for mb in m.mobs:
		if mb.dead or mb is Boss or not is_instance_valid(mb): continue
		var d: float = m.player.flat_dist(mb)
		if d < bd: bd = d; best = mb
	return best

func _fight(m) -> void:
	var P: Hunter = m.player
	var mb := _nearest_mob(m)
	if mb == null:
		note_bad("no monsters on the map"); return
	print("TOUR nearest monster %s %.0fm" % [mb.mkind, P.flat_dist(mb)])
	if P.flat_dist(mb) > 9.0:
		var at: Vector3 = m.world.free_spot_near(mb.pos + Vector3(5.0, 0, 3.0), [], 1.0, 0.5, 6.0)
		P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
		m.cam.snap(P.pos)
	var kills := 0
	var w0 := Time.get_ticks_msec()
	while kills < 3 and Time.get_ticks_msec() - w0 < 90000 and is_instance_valid(m) and not m.over:
		mb = _nearest_mob(m, 30.0)
		if mb == null:
			break
		aim_at = mb
		Input.action_press("fire")
		var t0: float = m.time
		while is_instance_valid(m) and not m.over and is_instance_valid(mb) and not mb.dead and m.time - t0 < 12.0:
			var d: float = P.flat_dist(mb)
			Input.action_release("left"); Input.action_release("right"); Input.action_release("up"); Input.action_release("down")
			var reach: float = 2.2 if P.wpn.get("melee", false) else 7.0
			if d > reach:
				# (step up to it rather than walk: held keys walked the hunter off a bridge into the abyss)
				var to: Vector3 = mb.pos + (P.pos - mb.pos).normalized() * (reach * 0.7)
				if not m.world.is_void(to.x, to.z):
					P.teleport(Vector3(to.x, m.world.ground_at(to.x, to.z), to.z))
			await get_tree().process_frame
			if kills == 0 and m.time - t0 > 1.2 and m.time - t0 < 1.3: await shot("fight")
		if is_instance_valid(mb) and mb.dead: kills += 1
	for a in ["fire", "left", "right", "up", "down"]: Input.action_release(a)
	aim_at = null
	if not is_instance_valid(m): return
	print("TOUR fought: %d kills, level %d, xp %.0f" % [kills, P.lvl, P.xp])
	await shot("fight_after")

func _level_up(m) -> void:
	var P: Hunter = m.player
	if P.lvl < 6:
		P.gain_xp(float(Hunter.XP_TO[5]) - P.xp + 1.0)
	await mwait(0.8)
	await shot("level_%d" % P.lvl)
	# spend the points the way a player does: press a locked ability with a point to spare
	for a in ["secondary", "signature", "dash", "kin_ability", "gear1", "ultimate"]:
		await key(a)
		await mwait(0.3)
	print("TOUR slots after spending: %s, points left %d" % [str(P.slot_lv), P.skill_pts])
	await shot("skills_spent")

## E, R, the RMB variants (tap, hold, in the air), dash, the Boki's C and G, each with a shot.
func _cast_round(m, tag: String, wait_cd: bool) -> void:
	var P: Hunter = m.player
	if P.lvl < 6 and tag == "training":
		P.unlock_all()
		P.lvl = 6; P.skill_pts = 1; P.level_slot("ult")
	var mb := _nearest_mob(m, 25.0)
	var tgt = mb if mb else P.pos + Vector3(4, 0, 0)
	aim_at = tgt
	var casts := [["secondary", "rmb_tap", 0.1], ["secondary", "rmb_hold", 1.2], ["signature", "e", 0.12], ["dash", "dash", 0.1],
		["kin_ability", "boki_c", 0.12], ["throw", "boki_g", 0.12], ["ultimate", "r", 0.12]]
	for c in casts:
		if wait_cd:
			await mwait(1.5)
		var a: String = c[0]
		P.ult = 1.0 if a == "ultimate" else P.ult
		Input.action_press(a)
		await frames(2)
		await wait(float(c[2]) * 0.5)
		if float(c[2]) > 0.5: await shot("%s_%s_holding" % [tag, c[1]])
		await wait(float(c[2]) * 0.5)
		Input.action_release(a)
		await mwait(0.25)
		await shot("%s_%s" % [tag, c[1]])
		await mwait(0.6)
	# RMB in the air
	await key("jump", 0.05)
	await mwait(0.2)
	await key("secondary")
	await mwait(0.2)
	await shot("%s_rmb_air" % tag)
	await mwait(1.0)
	if Input.is_action_pressed("throw") == false and P.kin and String(P.kin.get("state")) != "shoulder":
		await key("throw")      # call the Boki back
	aim_at = null
	print("TOUR %s casts done, kstat %s" % [tag, str(m.kstat)])

func _tame(m) -> void:
	var P: Hunter = m.player
	var rec := Save.new_kin("puddlet", "", 77)
	rec["level"] = 3
	var at: Vector3 = m.world.free_spot_near(P.pos + Vector3(2.2, 0, 1.0), [], 0.8, 0.4, 6.0)
	var k = m.spawn_wild(rec, Vector3(at.x, m.world.ground_at(at.x, at.z), at.z), true)
	await mwait(0.8)
	await shot("tame_dazed")
	var w0 := Time.get_ticks_msec()
	var caught := false
	var caught0: int = P.caught.size()
	while Time.get_ticks_msec() - w0 < 30000:
		var near: float = P.flat_dist(k) if is_instance_valid(k) else 0.0
		if near > 1.4:
			var to: Vector3 = k.pos + (P.pos - k.pos).normalized() * 1.0
			P.teleport(Vector3(to.x, m.world.ground_at(to.x, to.z), to.z))
		Input.action_press("interact")
		await mwait(0.6)
		if not caught and Time.get_ticks_msec() - w0 > 600 and Time.get_ticks_msec() - w0 < 2200:
			await shot("tame_holding")
		if not is_instance_valid(k) or k.dead or P.caught.size() > caught0:
			caught = true; break
	Input.action_release("interact")
	print("TOUR tame caught=%s interact='%s'" % [caught, String(m.interact.get("label", ""))])
	if not caught: note_bad("couldn't tame the dazed Boki")
	await mwait(1.0)
	await shot("tame_done")

func _lair(m) -> void:
	var P: Hunter = m.player
	var LS: Array = m.lairs.list.filter(func(L): return L["active"] and L["state"] == "sealed" and (L["entry"] as Array).has("dial"))
	if LS.is_empty():
		LS = m.lairs.list.filter(func(L): return L["state"] == "sealed" and (L["entry"] as Array).has("dial"))
		if not LS.is_empty(): m.lairs.activate(LS[0])
	if LS.is_empty():
		note_bad("no sealed lair with a dial"); return
	var L: Dictionary = LS[0]
	print("TOUR lair %s (%s)" % [L["name"], L["boss"]])
	var dp: Vector3 = L["dial"]
	var at: Vector3 = dp + Vector3(L["out"].x, 0, L["out"].y) * 0.9
	P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	m.cam.snap(P.pos)
	for g in L["guards"]: if is_instance_valid(g): g.dead = true; g.visible = false
	await mwait(1.0)
	await shot("lair_gate")
	# the dial: press as the needle crosses a lit arc
	var w0 := Time.get_ticks_msec()
	var shots_dial := 0
	await key("interact", 0.05)
	while L["state"] == "sealed" and Time.get_ticks_msec() - w0 < 40000:
		var on := false
		if float(L["jam"]) <= 0.0 and float(L["grace"]) <= 0.0:
			var nxt: float = float(L["needle"]) + float(L["dir"]) * float(m.lairs.speed_of(L)) * 0.05
			for t in L["targets"]:
				if not t["hit"] and absf(wrapf(nxt - float(t["a"]), -PI, PI)) <= float(t["w"]) * 0.5 - 0.06: on = true
		if m.lairs.puzzle_of(P).is_empty() and float(L["jam"]) <= 0.0: on = true
		if on:
			await key("interact", 0.02)
			if shots_dial < 2: shots_dial += 1; await shot("lair_dial_%d" % shots_dial)
		else:
			await get_tree().process_frame
	print("TOUR dial: state %s lock %d fails %d" % [L["state"], int(L["lock"]), int(L["fails"])])
	if L["state"] == "sealed":
		note_bad("couldn't open the dial in 40 s (fails %d) - opening it" % int(L["fails"]))
		m.lairs.open(L, P, "dial")
	await mwait(0.8)
	await shot("lair_open")
	# step in: the boss wakes, the seal drops
	var inside: Vector3 = L["c"] + (L["gate_c"] - L["c"]) * 0.45
	P.teleport(Vector3(inside.x, m.world.ground_at(inside.x, inside.z), inside.z))
	m.cam.snap(P.pos)
	await until(func(): return L["state"] != "open", 10.0, "the boss to wake")
	await mwait(1.5)
	await shot("boss_awake")
	var b: Boss = m.lairs.boss_of(L)
	aim_at = b
	Input.action_press("fire")
	await mwait(1.5)
	await key("signature"); await mwait(0.6)
	await shot("boss_fight")
	await key("secondary"); await mwait(1.0)
	P.ult = 1.0
	await key("ultimate"); await mwait(0.5)
	await shot("boss_fight_r")
	await mwait(3.0)
	await shot("boss_fight_2")
	Input.action_release("fire")
	if b and is_instance_valid(b) and not b.dead:
		print("TOUR boss hp %.0f/%.0f after the fight shots - finishing it" % [b.hp, b.max_hp])
		b.hurt(b.hp + b.max_hp, P, {"src": "shot"})
	aim_at = null
	await mwait(1.5)
	await shot("boss_dead")
	await mwait(1.5)
	await shot("boss_loot")
	if not m.perk_offer.is_empty():
		await key_event(KEY_1)       # take the boss's first perk
		await mwait(0.6)
		print("TOUR perk taken, offer open: %s" % (not m.perk_offer.is_empty()))
	var egg: Dictionary = L.get("egg_wp", {})
	if not egg.is_empty():
		var ep: Vector3 = egg["pos"]
		P.teleport(Vector3(ep.x + 0.6, m.world.ground_at(ep.x, ep.z), ep.z))
		await mwait(0.6)
		await shot("rare_egg")
		Input.action_press("interact")
		await mwait(1.5)
		Input.action_release("interact")
		await mwait(0.5)
		print("TOUR rare egg carried: %s (wpicks has it: %s)" % [str(P.pack.map(func(it): return String(it.get("name", it.get("id", "?"))))), m.wpicks.has(egg)])
		await shot("rare_egg_taken")
	print("TOUR victory=%s locked=%s state=%s" % [L.get("victory", false), L.get("locked", false), L["state"]])
	if arch == "juggernaut" and L.get("up_on", false):
		var u: Vector3 = L["up"]
		P.teleport(Vector3(u.x, m.world.ground_at(u.x, u.z), u.z))
		await mwait(0.8)
		await shot("lair_updraft")
		await mwait(2.0)
		await shot("lair_updraft_2")
		await until(func(): return P.grounded and not m.lairs.inside(L, P.pos, 0.0), 20.0, "landing outside the lair")
		await shot("lair_out_updraft")
	elif L.get("victory", false):
		var lv: Vector3 = L["lever"]
		P.teleport(Vector3(lv.x, m.world.ground_at(lv.x, lv.z), lv.z) + Vector3(L["out"].x, 0, L["out"].y) * -0.6)
		await mwait(0.6)
		await shot("lair_lever")
		Input.action_press("interact")
		await mwait(1.2)
		Input.action_release("interact")
		await mwait(0.6)
		await shot("lair_lever_pulled")
		print("TOUR lever: victory=%s locked=%s" % [L.get("victory", false), L.get("locked", false)])

func _extract(m) -> void:
	var P: Hunter = m.player
	var ups: Array = m.exits.of_kind("outpost")
	if ups.is_empty():
		note_bad("no uplinks"); return
	var best: Dictionary = ups[0]
	for x in ups:
		if P.flat_dist(x["pos"]) < P.flat_dist(best["pos"]): best = x
	best["open_at"] = 0.0
	var cp: Vector3 = best["pos"]
	var at: Vector3 = m.world.free_spot_near(cp + Vector3(1.2, 0, 0.6), [], 0.6, 0.4, 3.0)
	P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	m.cam.snap(P.pos)
	await mwait(1.0)
	await shot("uplink")
	Input.action_press("interact")
	await mwait(2.0)
	Input.action_release("interact")
	print("TOUR uplink state %s" % best["state"])
	if best["state"] != "charging": note_bad("the uplink didn't start (%s, '%s')" % [best["state"], String(m.interact.get("label", ""))])
	var i := 0
	var w0 := Time.get_ticks_msec()
	while is_instance_valid(m) and best["state"] in ["charging", "fizzling"] and Time.get_ticks_msec() - w0 < 600000:
		# (rivals parked in the yard contest it and it never charges: send them elsewhere)
		for o in m.hunters:
			if is_instance_valid(o) and o != P and not o.out and o.team != P.team and o.flat_dist(cp) < 12.0:
				o.teleport(m.world.spawns[(m.hunters.find(o) * 3) % m.world.spawns.size()])
		await mwait(8.0)
		i += 1
		if i <= 3: await shot("uplink_charging_%d" % i)
		if P.flat_dist(cp) > 3.0:
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	print("TOUR uplink now %s" % best["state"])
	await shot("uplink_open")
	# step into the light
	await until(func(): return P.extracted or m.over or not is_instance_valid(m), 40.0, "extracting")
	if is_instance_valid(m) and not P.extracted and not m.over:
		P.teleport(Vector3(cp.x, m.world.ground_at(cp.x, cp.z), cp.z))
		await until(func(): return not is_instance_valid(m) or P.extracted or m.over, 30.0, "extracting in the lift")
	await wait(2.0)
	await shot("extracted")
	await until(func(): var c := cur(); return c != null and c.get_script() and c.get_script().resource_path.ends_with("results.gd"), 60.0, "the results")
	god = false
	await wait(2.0)
	await shot("results")
	await wait(2.5)
	await shot("results_2")
	press("Back to the farm")
	await _wait_home()
	await shot("home_after")
	print("TOUR roster now: %s" % str(Save.d["roster"].map(func(r): return "%s (%s)" % [r["name"], r["species"]])))
	var h := cur()
	if h and Save.d["roster"].size() > 1:
		var nk: Dictionary = Save.d["roster"][-1]
		var ke: Dictionary = h._kin_entry(nk)
		if not ke.is_empty():
			h.ppos = ke["pos"] + Vector3(1.3, 0, 0.9); h.cam.snap(h.ppos)
			await wait(1.5)
			await shot("home_new_boki")
		else:
			note_bad("the new Boki %s isn't on the farm" % nk["name"])
	else:
		note_bad("no new Boki in the roster after the run")
