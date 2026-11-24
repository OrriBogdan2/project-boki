extends RefCounted
## --shake-check: your own actions never shake your camera, and the little shake
## that is left comes only from big things happening to you.
##   1. all 12 hunters cast LMB / RMB / E / X / Q, dash, air dash, land from a height, all with a dummy in front to
##      hit: the caster's camera gets zero shake (Cam.shake_total never moves);
##   2. a boss slam on top of you shakes at most Shake.MAX_SECS (0.15 s), at the Screen shake slider's scale;
##   3. the slider at 0 means no shake at all, and the default is 30%;
##   3b. your own Fuse and your Boki's landing strike and blast don't shake your camera (a wild Boki's blast does);
##   4. a scripted 60 s fight (a hunter casting its whole kit at a bot) stays under FIGHT_BUDGET seconds of shake;
##   5. the table (content/rules/shake.json): every row's source and power, the hit tiers read it, every Shake call
##      in scripts/ names a class (never a number) from a file the row lists, the 0 rows (self, dash, landings,
##      knocks, slams that don't explode) have no caller, and each row fires at its power, max_secs, linear falloff.
## Reuses the dash-flow check's training match and slot presses. Never touches the save.

const FIGHT_BUDGET := 1.0       # s of shake allowed in the 60 s fight (with no boss in it, none is expected)
const FIGHT_SECS := 60
const SLOTS := ["lmb", "rmb", "e", "x", "q"]
const SOURCES := ["owner", "decision", "?"]  # shake.json src: an owner rule, the brief's decision, no reference number
## The only callers of the power door (Shake.incoming_big): Feel's hit tiers, and Shake.big itself.
const POWER_DOOR_OK := ["res://scripts/arch/feel.gd", "res://scripts/match/shake.gd"]

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
	await _own_boki(main)
	await _boss_slam(main)
	await _fight(main)
	_rows()
	_callers()
	await _fires(main)
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

## Your own Fuse and your Boki's landing strike and blast: big moments, but yours, so your camera stays still. The
## same blast from a wild Boki (no owner) still shakes it, so a still camera is the cause's doing. Each reads the
## strength left on the camera (Cam.shake_amp): a shake inside the team-fight gap starts no seconds but raises it.
func _own_boki(main: Node) -> void:
	var m: Match = flow._match(main, Arch.ORDER[0])
	var h: Hunter = flow.hunter
	var rec := Save.new_kin("cindle")
	rec["trust"] = 95.0
	var k: Kin = h.kin if h.kin else m.give_kin(h, rec)
	_steps(m, 30)
	k.teleport(h.pos + Vector3(2, 0, 0))
	_still(m)
	KinStrike.land(k, {})
	_steps(m, 30)
	ok(m.cam.shake_amp <= 0.0, "your Boki's landing strike shakes you at %.3f" % m.cam.shake_amp)
	# a wild Boki is a Boki with no owner (Shake reads the cause's owner_h, so the cast must come from one)
	var wild: Kin = m.spawn_wild(Save.new_kin("cindle"), h.pos + Vector3(4, 0, 0))
	for owner_h in [h, null]:
		_still(m)
		var by: Kin = k if owner_h else wild
		var cx := KinExec.make_cx(m, by, by, owner_h, h.pos + Vector3(6, 0, 0), 1.0, "q", "boulder_heave")
		KinExec.cast(KinLib.ability("boulder_heave"), cx)
		_steps(m, 90)
		if owner_h:
			ok(m.cam.shake_amp <= 0.0, "your Boki's Boulder Heave blast shakes you at %.3f" % m.cam.shake_amp)
		else:
			ok(m.cam.shake_amp > 0.0, "a wild Boki's Boulder Heave blast shakes you (%.3f)" % m.cam.shake_amp)
	_still(m)
	h.ult = 1.0
	h.slot_lv["ult"] = 1
	var fused := KinMerge.press(h)
	_steps(m, 120)
	ok(fused and not h.merge_st.is_empty(), "the Fuse went off (merge %s)" % str(not h.merge_st.is_empty()))
	ok(m.cam.shake_amp <= 0.0, "your own Fuse shakes you at %.3f" % m.cam.shake_amp)
	m.queue_free()
	await main.get_tree().process_frame

## Ends a running shake and its strength.
func _still(m: Match) -> void:
	m.cam.shake_left = 0.0
	m.cam.shake_amp = 0.0

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
	ok(secs > 0.0 and secs <= Shake.door("max_secs") + 0.001, "a boss slam on you shakes %.3f s" % secs)
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


## 5a. Each row: a known source, a 0-1 power; an owner or decision row is 0 with no caller; the tiers read theirs.
func _rows() -> void:
	var rows: Dictionary = Shake.rules["classes"]
	for cls in rows:
		var row: Dictionary = rows[cls]
		var pw := Shake.power(cls)
		var sane := String(row["src"]) in SOURCES and pw >= 0.0 and pw <= 1.0
		ok(sane, "row %s: power %.2f, src %s" % [cls, pw, row["src"]])
		if String(row["src"]) != "?":
			ok(pw == 0.0 and (row["at"] as Array).is_empty(), "row %s (%s): 0 and no caller" % [cls, row["src"]])
	for w in ImpactWeight.TIERS:
		var reads := rows.has(w + "_hit") and ImpactWeight.shake(w) == Shake.power(w + "_hit")
		ok(reads, "the %s tier reads %s_hit" % [w, w])
	for cls in ["self", "dash", "hard_land", "landing_strike", "knock", "area_slam", "light_hit", "solid_hit"]:
		ok(rows.has(cls) and Shake.power(cls) == 0.0, "%s shakes no one" % cls)
	ok(Shake.door("max_secs") <= 0.15 and String(Shake.rules["door"]["falloff"]) == "linear", "door: <= 0.15 s, linear")


## 5b. Every Shake call in scripts/: Shake.big names table classes from a file its row lists (and every listed file
## calls it); the power door is only Feel's; nothing else rumbles the camera.
func _callers() -> void:
	var rows: Dictionary = Shake.rules["classes"]
	var calls := {}  # class -> {file: true}
	var big_rx := RegEx.create_from_string("Shake\\.big\\(([^\\n]*)")
	var name_rx := RegEx.create_from_string('"(\\w+)"(?!\\])')  # a quoted name, not a key (l_v["c"])
	var door_rx := RegEx.create_from_string("Shake\\.incoming_big\\(|cam\\.rumble\\(")
	var files: Array = []
	_gd_files("res://scripts", files)
	var strays := []
	for f in files:
		var src := FileAccess.get_file_as_string(f)
		for hit in big_rx.search_all(src):
			var names := name_rx.search_all(hit.get_string(1))
			if names.is_empty():
				strays.append("%s: %s" % [f, hit.get_string(0)])
			for n in names:
				var cls := n.get_string(1)
				if not rows.has(cls) or not (rows[cls]["at"] as Array).has(f.trim_prefix("res://")):
					strays.append("%s: %s" % [f, cls])
				calls.get_or_add(cls, {})[f.trim_prefix("res://")] = true
		if door_rx.search(src) != null and not POWER_DOOR_OK.has(f) and f != "res://scripts/match/cam.gd":
			strays.append("%s: a direct shake" % f)
	ok(strays.is_empty(), "every Shake call names a table class from a listed file, strays: %s" % [strays])
	var unused := []
	for cls in rows:
		for at in rows[cls]["at"]:
			if not (calls.get(cls, {}) as Dictionary).has(at):
				unused.append("%s @ %s" % [cls, at])
	ok(unused.is_empty(), "every row's listed caller calls it, stale: %s" % [unused])


func _gd_files(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(d), out)


## 5c. Each row fired on top of you at full slider: power x max_amp, max_secs long; half as strong at half the
## radius; nothing past it. Prints the table's TABLE rows (docs/MOVEMENT_FEEL.d/1123-shake-table.md).
func _fires(main: Node) -> void:
	var m: Match = flow._match(main, Arch.ORDER[0])
	var h: Hunter = flow.hunter
	Settings.v["screen_shake"] = 1.0
	var rad := Shake.door("radius_m")
	var rows: Dictionary = Shake.rules["classes"]
	for cls in rows:
		var stage := 2 if rows[cls].has("step") else 0
		var want := Shake.power(cls, stage) * Shake.door("max_amp")
		_still(m)
		m.time += ImpactWeight.cap("shake_gap_s") + 0.1  # past the team-fight gap: this one starts its own shake
		var amp := Shake.big(m, h.pos, cls, null, stage)
		var secs := m.cam.shake_left
		var half := Shake.big(m, h.pos + Vector3(rad * 0.5, 0, 0), cls, null, stage)
		var past := Shake.big(m, h.pos + Vector3(rad + 1.0, 0, 0), cls, null, stage)
		var fired := is_equal_approx(amp, want) and past == 0.0 and (want <= 0.0 or is_equal_approx(half, want * 0.5))
		fired = fired and (secs == Shake.door("max_secs") if want > 0.0 else secs == 0.0)
		var at_half := "%.3f at %.0f m, %.3f past it" % [half, rad * 0.5, past]
		ok(fired, "%s fires %.3f (want %.3f), %.2f s, %s" % [cls, amp, want, secs, at_half])
		print(
			(
				"SHAKE TABLE %s power %.2f amp %.4f (at 30%%: %.4f) secs %.2f falloff linear 0-%.0f m src %s"
				% [cls, Shake.power(cls, stage), amp, amp * 0.3, secs, rad, rows[cls]["src"]]
			)
		)
	_still(m)
	m.queue_free()
	await main.get_tree().process_frame
