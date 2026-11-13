extends RefCounted
## --kin-wisp-form-check: a downed Hunter's Boki ride with them as wisps (KinWispForm). In a 2v2 with a
## bot teammate (the bot's Boki goes through the same code as yours):
##   1. knocked with its Boki out fighting a few metres off: the Boki zips back, rides as a wisp round
##      them (Boki model hidden, a Boki wisp drawn), is not hittable and attacks nothing
##   2. knocked with its Boki far away: it blinks straight to them
##   3. a teammate stands on the Wisp: back up, the Boki pops back onto the shoulder with its old order
##   4. nobody near: the Boki wisp pulls its Hunter up after its wait, and the bleed-out pauses meanwhile
##   5. a Boki that is down itself when its Hunter goes down stays down where it fell
##   6. an enemy on the Wisp (the stomp): no pull, and when they're finished the Boki leaves the wisp
##      form by the death rules (KinLoss)
##   7. the Hunter Wisp itself: the rack's picker lists every skin and wears one; you, your
##      bot teammate and a rival knocked swap the hero for a Wisp (bots the same code); your saved skin is
##      on yours only; its outline and plume are the
##      viewer's relation colour, read from three viewers (you, the teammate, the rival); the plate sits on
##      the Wisp and says JUMP TO REVIVE to a teammate close by only; you jump onto the teammate's Wisp and
##      that brings them back
## Never touches the save.

const DT := 1.0 / 60.0

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("KINWISP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P: Hunter = m.player
	var bot: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var foe: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h.kin == null:
			m.give_kin(h, m.bot_kin_record())
	var spot := m.world.random_ground()
	_put(bot, spot)
	_put(P, spot + Vector3(25, 0, 0))
	_put(foe, spot + Vector3(-25, 0, 0))
	for h in m.hunters:
		if h.team != P.team:
			_put(h, spot + Vector3(-25, 0, 3))
	var k: Kin = bot.kin
	k.trust = 50.0
	_run(0.2)
	# ---------------------------------------------------------------- 1. out fighting nearby
	_out(k, bot.pos + Vector3(4.0, 0, 3.0))
	k.target = foe
	m.knock(bot, foe, {})
	bot.down_hp = 1e6
	_run(DT)
	ok(k.state == KinWispForm.STATE, "knocked: the Boki leaves the fight for the wisp form (%s)" % k.state)
	ok(not k.hittable() and k.target == null, "a Boki wisp can't be hit and has no target")
	_put(foe, bot.pos + Vector3(1.2, 0, 0))
	var foe_hp := foe.hp
	_run(KinWispForm.ZIP_S + 0.2)
	var gap := k.flat_dist(bot)
	ok(absf(gap - KinWispForm.ORBIT_R) < 0.05, "it zipped back and circles its Hunter (%.2f m)" % gap)
	ok(foe.hp >= foe_hp, "it does not attack the rival standing on its Hunter")
	_put(foe, spot + Vector3(-25, 0, 0))
	k.render(DT, 1.0)
	var wisp := k.get_node_or_null("BokiWisp")
	ok(wisp != null and not k.model.visible, "drawn as its Boki wisp, the Boki model hidden")
	# ---------------------------------------------------------------- 3. a teammate revives
	_put(P, bot.pos)
	var t := _until(func(): return not bot.downed, 6.0)
	_put(P, spot + Vector3(25, 0, 0))
	ok(not bot.downed and t < 6.0, "the teammate on the Wisp brings them back (%.1fs)" % t)
	_run(DT)
	k.render(DT, 1.0)
	ok(k.state == "shoulder" and k.cmd == "follow",
		"revived: the Boki is back on the shoulder with its order (%s, %s)" % [k.state, k.cmd])
	ok(k.model.visible and k.get_node_or_null("BokiWisp") == null, "the Boki model is back, the wisp gone")
	# ---------------------------------------------------------------- 2. far away
	_out(k, bot.pos + Vector3(30.0, 0, 0))
	m.knock(bot, foe, {})
	_run(DT)
	ok(absf(k.flat_dist(bot) - KinWispForm.ORBIT_R) < 0.05, "a Boki 30 m off blinks straight to its Hunter")
	# ---------------------------------------------------------------- 4. the Boki wisp pulls them up
	var hp0 := bot.down_hp
	t = _until(func(): return not bot.downed, Life.R["kin_revive_time"] + 5.0)
	ok(not bot.downed, "nobody near: the Boki wisp pulls its Hunter up (%.1fs)" % t)
	ok(hp0 - bot.down_hp < Data.MATCH["down_hp"] * 0.3, "the bleed-out paused while it pulled")
	_run(DT)
	ok(k.state == "shoulder", "and it is back on the shoulder")
	# ---------------------------------------------------------------- 5. a Boki down itself
	var k2: Kin = P.kin
	_put(foe, spot + Vector3(-25, 0, 0))
	_out(k2, P.pos + Vector3(4.0, 0, 0))
	k2.go_down()
	m.knock(P, foe, {})
	_run(0.5)
	ok(k2.state == "downed", "a Boki down itself stays down where it fell (%s)" % k2.state)
	m.revive_hunter(P, null)
	_put(foe, spot + Vector3(-25, 0, 0))
	await _hunter_wisp(P, bot, foe)
	# ---------------------------------------------------------------- 6. stomped and finished
	_out(k, bot.pos + Vector3(3.0, 0, 0))
	m.knock(bot, foe, {})
	_put(foe, bot.pos)
	_run(2.0)
	ok(bot.downed and bot.revive <= 0.0, "an enemy on the Wisp stops the Boki's pull (%.2f)" % bot.revive)
	t = _until(func(): return bot.out, 20.0)
	ok(bot.out, "stomped out: the Hunter is dead (%.1fs)" % t)
	_run(DT)
	ok(k.state != KinWispForm.STATE, "dead: the death rules take the Boki (%s)" % k.state)
	print("KINWISP CHECK %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	main.get_tree().quit(1 if bad > 0 else 0)

func _put(h: Ent, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO

## Sets the Boki down on foot, out of the shoulder, at `at`.
func _out(k: Kin, at: Vector3) -> void:
	k.state = "active"
	k.cmd = "follow"
	_put(k, at)

func _run(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

## Steps until `cond` holds (at most `limit` s); the seconds it took.
func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit and not cond.call():
		m.step(DT)
		t += DT
	return t

## 7. The Hunter Wisp: form, skin, colour by relation for three viewers, the prompt, a jump revive.
func _hunter_wisp(P: Hunter, bot: Hunter, foe: Hunter) -> void:
	var panel := VBoxContainer.new()
	WispPicker.add_to(panel, func(): pass)
	var tiles := panel.get_child(1).get_child_count()
	var every: bool = tiles == (WispLook.rules()["looks"] as Dictionary).size() and tiles >= 3
	ok(every, "the rack's picker lists every Wisp skin (%d)" % tiles)
	panel.free()
	WispPicker._wear("glitch", func(): pass)
	var spot := bot.pos
	_put(P, spot + Vector3(0, 0, 3.0))
	_put(foe, spot + Vector3(3.0, 0, 0))
	for h in [P, bot, foe]:
		m.knock(h, null, {})
		h.down_hp = 1e6
		h.reveal_t = 30.0          # seen however the headless camera faces
	_show(0.4)
	for h in [P, bot, foe]:
		var swapped: bool = HunterWisp.mode_of(h) == HunterWisp.ON and not h.model.visible
		ok(swapped, "%s knocked: the hero is gone, a Wisp sits in their place" % h.pname)
	var styles := []
	for h in [P, bot, foe]:
		styles.append(_mat(h, "mat").get_shader_parameter("style"))
	ok(styles == [1, 0, 0], "your saved skin (glitch) is on your Wisp only, the bots wear the default %s" % [styles])
	for viewer in [P, bot, foe]:
		m.player = viewer
		_show(DT)
		var cols := []
		for h in [P, bot, foe]:
			cols.append(_mat(h, "plume").get_shader_parameter("col"))
		var want := []
		for h in [P, bot, foe]:
			want.append(SideColor.of_team(viewer.team, h.team, h == viewer))
		var rim_ok: bool = _mat(foe, "mat").get_shader_parameter("rim_col") == want[2]
		ok(cols == want and rim_ok,
			"seen by %s: plumes and outlines are you/ally/rival by relation %s" % [viewer.pname, cols])
	m.player = P
	m.revive_hunter(P, null)
	_put(P, spot + Vector3(0, 0, 3.0))
	m.cam.snap(P.pos)
	for i in 20:
		_show(DT)
		await main.get_tree().process_frame
	var shown: Dictionary = m.hud.plates.shown
	var mate_word := String(shown.get(bot.nid, {}).get("word", ""))
	var foe_word := String(shown.get(foe.nid, {}).get("word", ""))
	ok(mate_word == HudPlate.PROMPT, "a teammate near your Wisp sees '%s'" % mate_word)
	ok(foe_word != HudPlate.PROMPT and foe_word != "", "a rival's Wisp shows its plate but no prompt ('%s')" % foe_word)
	ok(not DownedMarks.cued(foe, bot), "...and a rival never gets the prompt")
	ok(HudPlate.plate_offset(bot) == HudPlate.WISP_OFFSET, "the plate sits on the Wisp")
	# jump onto the teammate's Wisp: the revive runs while you are in the air over it
	_put(P, bot.pos)
	P.do_jump()
	var air_revive := 0.0
	var t := 0.0
	while t < 0.4:
		_show(DT)
		t += DT
		if not P.grounded:
			air_revive = bot.revive
	ok(air_revive > 0.0, "jumping onto the Wisp starts the revive mid-air (%.2f)" % air_revive)
	t = _until(func(): return not bot.downed, 6.0)
	ok(not bot.downed, "...and standing over it brings them back (%.1fs more)" % t)
	m.revive_hunter(foe, null)
	WispLook.equip("default")
	_show(0.5)
	_put(P, spot + Vector3(25, 0, 0))
	_put(foe, spot + Vector3(-25, 0, 0))

## The Wisp's body ("mat") or plume ("plume") material on a downed hunter.
func _mat(h: Hunter, key: String) -> ShaderMaterial:
	return HunterWisp.node_of(h).get_meta(key)

## Steps and draws the hunters (their Wisps live in render).
func _show(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		for h in m.hunters:
			h.render(DT, 1.0)
