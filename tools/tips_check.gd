extends RefCounted
## --tips-check: the context tips (TipPick, content/rules/tips.json). Checks: the table (about 30 one-line
## tips, unique ids, known triggers each with tips, keys only through {action}); a session that never
## summoned gets the summon tip, and each trigger picks its own tip first; a seen tip is not repeated
## next time and the pool runs through before anything repeats; a rebound key shows in the text; Blight
## tips drop when the Blight is off; and in a real match the counts (summon, wisp stolen, Blight knock)
## raise the triggers the tips read; and the crouch hint (CrouchHint: one banner line near the first idle
## camp, once per save, never beside an alerted camp, steadier aim as it says). Never touches the save.

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("TIPSCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _fresh() -> void:
	Save.d = Save.fresh()
	TipPick.last = []


func _id_of(text: String) -> String:
	for t in TipPick.rules()["tips"]:
		if TipPick.render(String(t["text"])) == text:
			return String(t["id"])
	return ""


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	_table()
	_picking()
	_match_counts()
	_crouch_hint()
	print("TIPSCHECK DONE, failures: %d" % bad)
	main.get_tree().quit()


func _table() -> void:
	var r := TipPick.rules()
	var tips: Array = r["tips"]
	var ids := {}
	var used_triggers := {}
	var tidy := true
	for t in tips:
		ids[t["id"]] = true
		var text := String(t["text"])
		if t.has("when"):
			used_triggers[t["when"]] = true
			tidy = tidy and (r["triggers"] as Dictionary).has(t["when"])
		tidy = tidy and text.length() <= 190 and not text.contains("\n")
		tidy = tidy and not TipPick.render(text).contains("{")
		for tok in RegEx.create_from_string("\\{(\\w+)\\}").search_all(text):
			tidy = tidy and InputMap.has_action(tok.get_string(1))
	var hints: Dictionary = r["hints"]
	var hints_tidy := not hints.is_empty()
	for h in hints.values():
		hints_tidy = hints_tidy and String(h).length() <= 60 and not String(h).contains("\n")
	ok(hints_tidy, "the hints are short one-liners (%d)" % hints.size())
	var lines := tips.size() + hints.size()
	ok(lines >= 28 and lines <= 34, "about 30 lines of text with the hints (%d)" % lines)
	ok(ids.size() == tips.size(), "every tip has its own id")
	ok(tidy, "one line each, a known trigger, keys only as {action} of a real action")
	var n_trig := (r["triggers"] as Dictionary).size()
	ok(used_triggers.size() == n_trig, "every trigger has tips (%d)" % n_trig)


func _picking() -> void:
	_fresh()
	var trap := TipPick.triggers({"summons": 0, "glide_t": 30.0}, {"k1": 3}, "", 200.0)
	ok(trap == ["no_summon"], "a session that never summoned raises only the summon trigger %s" % [trap])
	var first := TipPick.pick(trap)
	ok(_id_of(first).begins_with("summon_"), "and gets a summon tip: %s" % first)
	var second := TipPick.pick(trap)
	ok(second != first and _id_of(second).begins_with("summon_"), "a seen tip is not repeated: the next one differs")
	ok(TipPick.triggers({"summons": 0}, {}, "", 30.0).is_empty(), "a run shorter than min_time_s blames nothing")
	var base := {"summons": 1, "glide_t": 60.0}
	var checks := {
		"abyss": TipPick.triggers(base, {"k1": 1}, "abyss", 120.0),
		"blight": TipPick.triggers(base.merged({"blight_downs": 1}, true), {"k1": 1}, "", 120.0),
		"wisp_stolen": TipPick.triggers(base.merged({"wisp_stolen": 1}, true), {"k1": 1}, "", 120.0),
		"no_e": TipPick.triggers(base, {}, "", 120.0),
		"few_glide": TipPick.triggers(base.merged({"glide_t": 1.0}, true), {"k1": 1}, "", 120.0)
	}
	for k in checks:
		_fresh()
		var got := _id_of(TipPick.pick(checks[k]))
		var want := ""
		for t in TipPick.rules()["tips"]:
			if t.get("when", "") == k:
				want = String(t["id"])
				break
		ok(checks[k] == [k] and got == want, "%s: raised alone, picks %s (%s)" % [k, want, got])
	_fresh()
	var n := (TipPick.rules()["tips"] as Array).size()
	var got_ids := {}
	for i in n:
		got_ids[_id_of(TipPick.pick([]))] = true
	ok(got_ids.size() == n and not got_ids.has(""), "each once before a repeat (%d/%d)" % [got_ids.size(), n])
	ok(TipPick.pick([]) != "", "and once all are seen the list starts over")
	_fresh()
	ok(not TipPick.pick([], false).contains("Blight"), "no Blight tips when the Blight is off")
	_fresh()
	var old := InputMap.action_get_events("signature").duplicate()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	InputMap.action_erase_events("signature")
	InputMap.action_add_event("signature", ev)
	var e_tip := TipPick.pick(["no_e"])
	InputMap.action_erase_events("signature")
	for o in old:
		InputMap.action_add_event("signature", o)
	ok(e_tip.begins_with("J "), "a rebound key reads from Settings.key_cap: '%s'" % e_tip)


func _match_counts() -> void:
	_fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 7, "no_drop": true, "length": 1e9})
	m.set_process(false)
	var p: Hunter = m.player
	var k: Kin = m.give_kin(p, Save.new_kin("zapple"))
	k._launch(p.pos + Vector3(4, 0, 0))
	ok(int(p.stats.get("summons", 0)) == 1, "sending the Boki out counts a summon")
	m.kin_stolen(p, {"name": "Test"})
	ok(int(p.stats.get("wisp_stolen", 0)) == 1, "a stolen Boki counts")
	var b := m.blight.spawn("bl_skitter", p.pos + Vector3(2.5, 0, 0), 1.0)
	m.knock(p, b, {})
	ok(int(p.stats.get("blight_downs", 0)) == 1, "a Blight knock counts")
	var trap := TipPick.triggers(p.stats, p.used, "", 200.0)
	ok(
		trap.has("blight") and trap.has("wisp_stolen") and not trap.has("no_summon"),
		"and the triggers follow: %s" % [trap]
	)
	var down_tip := TipPick.for_downed(p, 200.0, true)
	ok(_id_of(down_tip).begins_with("blight_"), "the downed screen picks the Blight tip: %s" % down_tip)
	ok(TipPick.for_downed(p, 200.0, true) == down_tip, "and keeps it while you stay down")
	var r := {"stats": p.stats, "used": p.used, "why": "abyss", "time": 200.0}
	TipPick.note_run(r)
	ok(TipPick.last.has("abyss") and TipPick.for_loading(true) != "", "the loading screen reads the last run")
	m.queue_free()


## The crouch hint: which tip it says, when it fires, that it fires once, and that its claim holds.
func _crouch_hint() -> void:
	_fresh()
	var said := TipPick.text(CrouchHint.TIP)
	ok(said.begins_with(Settings.key_cap("crouch") + " "), "the crouch tip carries the crouch key: '%s'" % said)
	var old := {"matches": 5, "tutorial": {}}
	CrouchHint.migrate(old)
	var fresh := {"matches": 0, "tutorial": {}}
	CrouchHint.migrate(fresh)
	ok(
		old["tutorial"].get("crouch_hint", false) and not fresh["tutorial"].has("crouch_hint"),
		"an old save has had it; a new one has not"
	)
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 7, "no_drop": true, "length": 1e9})
	m.set_process(false)
	var p: Hunter = m.player
	var camp: Mob = m.spawn_mob("skitter", p.pos + Vector3(300, 0, 300))
	var hint := m.crouch_hint
	ok(hint != null, "a new save's real match has the hint")
	for mb: Mob in m.mobs:
		if mb != camp:
			mb.aggro(p, "check")  # only the camp under test counts as quiet
	p.pos = camp.pos + Vector3(CrouchHint.NEAR + 30.0, 0, 0)
	hint.tick(0.6)
	ok(hint.line == "", "far from every camp: no line")
	camp.aggro(p, "check")
	p.pos = camp.pos + Vector3(8, 0, 0)
	hint.tick(0.6)
	ok(hint.line == "" and not Save.d["tutorial"].get("crouch_hint", false), "an alerted camp: no line, nothing spent")
	camp._go(Mob.S.CHASE, "check")  # (NOTICE has no way to IDLE)
	camp.calm("check")
	hint.tick(0.6)
	ok(
		hint.line == said and Save.d["tutorial"].get("crouch_hint", false),
		"near a quiet camp: the line shows and the flag is set"
	)
	hint.tick(CrouchHint.LIFE + 0.1)
	ok(m.crouch_hint == null, "it goes after its time and does not come back")
	ok(CrouchHint.for_match(m, {}) == null, "the next match has none")
	Save.d = Save.fresh()
	var again := CrouchHint.for_match(m, {})
	p.crouch = true
	again.tick(0.6)
	ok(again.line == "" and Save.d["tutorial"].get("crouch_hint", false), "already crouching: spent without a line")
	p.crouch = false
	for i in 40:
		p.inp["crouch"] = true
		p.grounded = true
		p.sim(Match.DT)
	var steady := p.bloom
	for i in 40:
		p.inp["crouch"] = false
		p.inp["move"] = Vector2(0, -1)
		p.grounded = true
		p.sim(Match.DT)
	ok(
		not p.crouch and steady < 0.0 and p.bloom > steady,
		"its claim: crouched aim is steadier (bloom %.2f, %.2f moving)" % [steady, p.bloom]
	)
	m.queue_free()
