extends RefCounted
## --tips-check: the context tips (TipPick, content/rules/tips.json). Checks: the table (about 30 one-line
## tips, unique ids, known triggers each with tips, keys only through {action}); a session that never
## summoned gets the summon tip, and each trigger picks its own tip first; a seen tip is not repeated
## next time and the pool runs through before anything repeats; a rebound key shows in the text; Blight
## tips drop when the Blight is off; and in a real match the counts (summon, wisp stolen, Blight knock)
## raise the triggers the tips read. Never touches the save.

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
	await _match_counts()
	print("TIPSCHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

func _table() -> void:
	var R := TipPick.rules()
	var tips: Array = R["tips"]
	var ids := {}
	var used_triggers := {}
	var tidy := true
	for t in tips:
		ids[t["id"]] = true
		var text := String(t["text"])
		if t.has("when"):
			used_triggers[t["when"]] = true
			tidy = tidy and (R["triggers"] as Dictionary).has(t["when"])
		tidy = tidy and text.length() <= 190 and not text.contains("\n")
		tidy = tidy and not TipPick.render(text).contains("{")
		for tok in RegEx.create_from_string("\\{(\\w+)\\}").search_all(text):
			tidy = tidy and InputMap.has_action(tok.get_string(1))
	ok(tips.size() >= 28 and tips.size() <= 34, "about 30 tips (%d)" % tips.size())
	ok(ids.size() == tips.size(), "every tip has its own id")
	ok(tidy, "one line each, a known trigger, keys only as {action} of a real action")
	var n_trig := (R["triggers"] as Dictionary).size()
	ok(used_triggers.size() == n_trig, "every trigger has tips (%d)" % n_trig)

func _picking() -> void:
	_fresh()
	var tr := TipPick.triggers({"summons": 0, "glide_t": 30.0}, {"k1": 3}, "", 200.0)
	ok(tr == ["no_summon"], "a session that never summoned raises only the summon trigger %s" % [tr])
	var first := TipPick.pick(tr)
	ok(_id_of(first).begins_with("summon_"), "and gets a summon tip: %s" % first)
	var second := TipPick.pick(tr)
	ok(second != first and _id_of(second).begins_with("summon_"), "a seen tip is not repeated: the next one differs")
	ok(TipPick.triggers({"summons": 0}, {}, "", 30.0).is_empty(), "a run shorter than min_time_s blames nothing")
	var base := {"summons": 1, "glide_t": 60.0}
	var checks := {"abyss": TipPick.triggers(base, {"k1": 1}, "abyss", 120.0),
		"blight": TipPick.triggers(base.merged({"blight_downs": 1}, true), {"k1": 1}, "", 120.0),
		"wisp_stolen": TipPick.triggers(base.merged({"wisp_stolen": 1}, true), {"k1": 1}, "", 120.0),
		"no_e": TipPick.triggers(base, {}, "", 120.0),
		"few_glide": TipPick.triggers(base.merged({"glide_t": 1.0}, true), {"k1": 1}, "", 120.0)}
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
	await m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 7, "no_drop": true, "length": 1e9})
	m.set_process(false)
	var P: Hunter = m.player
	var k: Kin = m.give_kin(P, Save.new_kin("zapple"))
	k._launch(P.pos + Vector3(4, 0, 0))
	ok(int(P.stats.get("summons", 0)) == 1, "sending the Boki out counts a summon")
	m.kin_stolen(P, {"name": "Test"})
	ok(int(P.stats.get("wisp_stolen", 0)) == 1, "a stolen Boki counts")
	var b := m.blight.spawn("bl_skitter", P.pos + Vector3(2.5, 0, 0), 1.0)
	m.knock(P, b, {})
	ok(int(P.stats.get("blight_downs", 0)) == 1, "a Blight knock counts")
	var tr := TipPick.triggers(P.stats, P.used, "", 200.0)
	ok(tr.has("blight") and tr.has("wisp_stolen") and not tr.has("no_summon"), "and the triggers follow: %s" % [tr])
	var down_tip := TipPick.for_downed(P, 200.0, true)
	ok(_id_of(down_tip).begins_with("blight_"), "the downed screen picks the Blight tip: %s" % down_tip)
	ok(TipPick.for_downed(P, 200.0, true) == down_tip, "and keeps it while you stay down")
	var r := {"stats": P.stats, "used": P.used, "why": "abyss", "time": 200.0}
	TipPick.note_run(r)
	ok(TipPick.last.has("abyss") and TipPick.for_loading(true) != "", "the loading screen reads the last run")
	m.queue_free()
