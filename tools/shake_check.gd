extends RefCounted
## --shake-check: your own actions never shake your camera, and the little shake
## that is left comes only from big things happening to you.
##   1. all 12 hunters cast LMB / RMB / E / X / Q, dash, air dash, land from a height, all with a dummy in front to
##      hit: the caster's camera gets zero shake (Cam.shake_total never moves);
##   2. a boss slam on top of you shakes at most Shake.MAX_SECS (0.15 s), at the Screen shake slider's scale;
##   3. the slider at 0 means no shake at all, and the default is 30%;
##   4. a scripted 60 s fight (a hunter casting its whole kit at a bot) stays under FIGHT_BUDGET seconds of shake.
## Reuses the dash-flow check's training match and slot presses. Never touches the save.

const FIGHT_BUDGET := 1.0       # s of shake allowed in the 60 s fight (with no boss in it, none is expected)
const FIGHT_SECS := 60
const SLOTS := ["lmb", "rmb", "e", "x", "q"]

var bad := 0
var casts := 0
var flow := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	print("SHAKE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(func(who, _a, _s): if who == flow.hunter: casts += 1)
	Settings.v["screen_shake"] = 1.0           # the strongest the slider goes: any self-shake would show
	ok(is_equal_approx(float(Settings.DEFAULTS["screen_shake"]), 0.3), "the Screen shake slider defaults to 30%")
	for hero in Arch.ORDER:
		var m: Match = flow._match(main, hero)
		_self_shake(m, hero)
		m.queue_free()
		await main.get_tree().process_frame
	await _boss_slam(main)
	await _fight(main)
	print("SHAKE DONE, failures: %d" % bad)
	main.get_tree().quit()

func _steps(m: Match, n: int) -> void:
	for i in n:
		m.step(Match.DT)

## A dummy to hit: a bot standing still 5 m north of the hunter.
func _dummy(m: Match) -> void:
	var h: Hunter = flow.hunter
	for o in m.hunters:
		if o != h:
			o.ctrl = "idle"
			o.teleport(h.pos + Vector3(0, 0, -5))
			o.hp = o.max_hp

func _shake_of(m: Match) -> float:
	return m.cam.shake_total + m.cam.shake_left

func _self_shake(m: Match, hero: String) -> void:
	var h: Hunter = flow.hunter
	var worst := 0.0
	var did := []
	casts = 0
	for slot in SLOTS + ["dash", "air dash", "landing"]:
		flow._ready_up(m)
		_dummy(m)
		var before := _shake_of(m)
		match slot:
			"dash":
				h.inp["move"] = Vector2(0, -1)
				h.inp["dash"] = true
			"air dash":
				flow._lift()
				h.inp["move"] = Vector2(0, -1)
				h.inp["dash"] = true
			"landing":
				h.pos += Vector3(0, 12, 0)
				h.grounded = false
			_:
				flow._press(slot)
		for i in 150:
			m.step(Match.DT)
			h.inp["fire"] = false
			h.inp["dash"] = false
			if slot == "lmb" and i < 20:
				h.inp["fire"] = true         # a held LMB hits the dummy a few times
		var got := _shake_of(m) - before
		worst = maxf(worst, got)
		did.append(slot)
	ok(worst <= 0.0, "%s: %s put %.3f s of shake on the caster's camera" % [hero, ", ".join(did), worst])
	ok(absf(m.cam.shake_amp) <= 0.0, "%s: no shake left running" % hero)
	ok(casts >= 3, "%s: the script really cast (%d abilities went off)" % [hero, casts])

## A boss slam (Boss.blast, the same call the slam attack makes) on top of the player, then at the slider's ends.
func _boss_slam(main: Node) -> void:
	var m: Match = flow._match(main, Arch.ORDER[0])
	var h: Hunter = flow.hunter
	var boss := Boss.new()
	boss.m = m
	boss.md = {"windup": 1.0, "slam_r": 3.0, "dmg": 0.0}
	boss.pos = h.pos + Vector3(0, 0, -3)
	Settings.v["screen_shake"] = 0.3
	var t0 := _shake_of(m)
	boss.blast(h.pos, 3.0, 0.0)
	_steps(m, 60)
	var secs := _shake_of(m) - t0
	ok(secs > 0.0 and secs <= Shake.MAX_SECS + 0.001, "a boss slam on you shakes %.3f s" % secs)
	var amp_30 := Shake.incoming_big(m, h.pos, 1.0)
	Settings.v["screen_shake"] = 0.6
	var amp_60 := Shake.incoming_big(m, h.pos, 1.0)
	var scaled := amp_60 > amp_30 and is_equal_approx(amp_60, amp_30 * 2.0)
	ok(scaled, "the slider scales it: 30%% %.3f, 60%% %.3f" % [amp_30, amp_60])
	ok(Shake.incoming_big(m, h.pos + Vector3(40, 0, 0), 1.0) == 0.0, "a slam 40 m away is not felt")
	ok(Shake.incoming_big(m, h.pos, 1.0, h) == 0.0, "a slam you caused yourself is not felt")
	_steps(m, 30)
	Settings.v["screen_shake"] = 0.0
	var z0 := _shake_of(m)
	boss.blast(h.pos, 3.0, 0.0)
	Shake.incoming_big(m, h.pos, 1.0)
	_steps(m, 60)
	ok(_shake_of(m) == z0, "slider at 0: a slam on you shakes nothing")
	m.queue_free()
	await main.get_tree().process_frame

## 60 s of a hunter casting its kit at a bot; three kit shapes (all 12 would be slow).
func _fight(main: Node) -> void:
	Settings.v["screen_shake"] = 1.0
	var total := 0.0
	for hero in ["bulwark", "dolm", "mage"]:
		var m: Match = flow._match(main, hero)
		var h: Hunter = flow.hunter
		flow._ready_up(m)
		for o in m.hunters:
			if o != h:
				o.ctrl = "bot"
				o.teleport(h.pos + Vector3(0, 0, -6))
		var t0 := _shake_of(m)
		for sec in FIGHT_SECS:
			var foe: Hunter = null
			for o in m.hunters:
				if o != h and not o.downed:
					foe = o
			if foe != null:
				h.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
				h.inp["move"] = Vector2(sin(sec * 0.7), cos(sec * 0.5))
			h.hp = h.max_hp
			flow._press(SLOTS[sec % SLOTS.size()])
			if sec % 7 == 3:
				h.inp["dash"] = true
			for i in 60:
				m.step(Match.DT)
				h.inp["fire"] = false
				h.inp["dash"] = false
		var secs := _shake_of(m) - t0
		total = maxf(total, secs)
		m.queue_free()
		await main.get_tree().process_frame
	ok(total <= FIGHT_BUDGET, "a scripted %d s fight shakes %.3f s (budget %.1f s)" % [FIGHT_SECS, total, FIGHT_BUDGET])
