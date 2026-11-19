extends RefCounted
## --fusion-off-check: Fusion (X) is off by default (docs/decisions/0101). Prints PASS/FAIL lines.
##   1. the flag: content/rules/merge_forms.json ships `fusion_enabled` false
##   2. off: X, the bot's merge call, the Boki's leap and a full bond meter start nothing; the meter never fills;
##      no hunter in a bot match merges; the Boki-ability tip, loading tips, words, cards, controls and the
##      keybind list (X stays reserved in the input map) say nothing about it; the tutorial never has Fusion steps
##   3. on: the same calls start a Fusion, and the same screens show it again

var bad := 0
var main: Node
var m: Match


func ok(cond: bool, what: String) -> void:
	print("FUSIONOFF %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func _flag(on: bool) -> void:
	Content.rules("merge_forms")["fusion_enabled"] = on


func _match(opts: Dictionary) -> Match:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	var o := {"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
			"demo_kin": "pebbit", "weapon": "rifle", "cls": "medium"}
	o.merge(opts, true)
	m.start(o)
	m.set_process(false)
	return m


func _run_for(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT


## A match whose player is ready to fuse: Boki on the shoulder, a full meter, the slot open.
func _ready_player() -> Hunter:
	_match({})
	var p := m.player
	p.kin.stow()
	p.slot_lv["ult"] = 1
	p.ult = 1.0
	return p


func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var shipped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/merge_forms.json"))
	ok(shipped.has("fusion_enabled") and shipped["fusion_enabled"] == false, "the rules ship fusion_enabled = false")
	_flag(false)
	_off()
	_flag(true)
	_on()
	_flag(false)
	print("FUSIONOFF DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


# ------------------------------------------------------------------ 2. off
func _off() -> void:
	var p := _ready_player()
	ok(not KinMerge.ready(p) and KinMerge.plan(p) == "" and not KinMerge.can_cast(p), "off: a full meter is not ready")
	ok(not KinMerge.press(p) and not KinMerge.cast(p) and not KinMerge.surge(p),
			"off: press, cast and surge start nothing")
	p.inp["ult"] = true
	_run_for(0.5)
	ok(p.merge_st.is_empty() and KinMerge.deny_text(p) == "", "off: the X input does nothing and says nothing")
	var rival: Hunter = m.hunters.filter(func(h): return h.team != p.team)[0]
	BotKin.merge(p, rival, 3.0)
	ok(not bool(p.inp["ult"]) or p.merge_st.is_empty(), "off: the bot's merge call starts nothing")
	p.inp["ult"] = false
	p.ult = 0.0
	ok(KinBond.add(p, 0.5, "ult_hit") == 0.0 and KinBond.add(p, 0.5, KinBond.FIGHT) == 0.0 and p.ult == 0.0,
			"off: the bond meter does not fill (hits or fighting)")
	p.skill_pts = 3
	p.lvl = 9
	ok(not p.can_level("ult"), "off: no skill point can go into the Fusion slot")
	ok(InputMap.has_action("ultimate") and not Settings.slots("ultimate").is_empty(), "off: X stays reserved")
	_off_match()
	_off_text()
	_off_tutorial()


## A bot match (4 hunters, every meter held full): nobody fuses, nothing is counted.
func _off_match() -> void:
	_match({"training": false, "teams": 4, "squad": 1, "length": 600.0, "no_drop": true})
	var seen := 0
	for i in int(20.0 / Match.DT):
		for h in m.hunters:
			if h.kin != null:
				h.slot_lv["ult"] = 1
				h.ult = 1.0
		m.step(Match.DT)
		seen += m.hunters.filter(func(h): return not h.merge_st.is_empty()).size()
	ok(seen == 0 and int(m.kstat["ult"]) == 0, "off: 20s of a bot match with full meters, nobody fused (%d)" % seen)


func _off_text() -> void:
	ok(not TipText.ability(true).contains("fuse") and not TipText.ability(false).contains("bond"),
			"off: the Boki tip is silent")
	var tips_seen := {}
	for i in 60:
		Save.d["tutorial"]["tips_seen"] = []
		tips_seen[TipPick.pick(["no_summon"])] = true
	ok(not tips_seen.keys().any(func(t): return String(t).contains("fuses you")),
			"off: no loading tip about the bond fuse")
	Save.d["matches"] = 20
	ok(not WordsView.visible().any(func(w): return w["term"] == "Fusion"), "off: the Words page has no Fusion")
	ok(not KitCard.card_slots("bulwark").has("r") and not HunterViewer.slots_for("bulwark").has("r"),
			"off: the kit card has no Fusion row")
	ok(not ClassCard.kit_tip("bulwark").contains("Fusion"), "off: the class tooltip has no Fusion")
	ok(not _controls_text().contains("ultimate"), "off: the controls card has no Fusion row")
	ok(not _has_action_row("ultimate"), "off: the keybind list has no Fusion row")


func _off_tutorial() -> void:
	var tu := _tutorial()
	ok(not tu.applies("pick_ult") and not tu.applies("ult") and tu.applies("pick_kin"),
			"off: the tutorial skips its Fusion steps")
	ok(TutorialCamps.of(m.player) != null and not TutorialCamps.of(m.player).may_level("ult"),
			"off: no tutorial point goes to Fusion")


# ------------------------------------------------------------------ 3. on
func _on() -> void:
	var p := _ready_player()
	ok(KinMerge.ready(p) and KinMerge.plan(p) == "merge", "on: a full meter is ready")
	ok(KinMerge.press(p), "on: X starts the Fusion")
	_run_for(0.9)
	ok(not p.merge_st.is_empty() and String(p.merge_st["phase"]) == "live", "on: ...and the form goes live")
	p = _ready_player()
	var rival: Hunter = m.hunters.filter(func(h): return h.team != p.team)[0]
	BotKin.merge(p, rival, 3.0)
	ok(bool(p.inp["ult"]), "on: a bot calls the Fusion on a near rival")
	p.ult = 0.0
	ok(KinBond.add(p, 0.5, KinBond.FIGHT) == 0.5, "on: the meter fills")
	p.skill_pts = 3
	p.lvl = 9
	ok(p.can_level("ult"), "on: a skill point can go into the Fusion slot")
	Save.d["matches"] = 20
	ok(TipText.ability(true).contains("fuses") and WordsView.visible().any(func(w): return w["term"] == "Fusion"),
			"on: tip and word are back")
	ok(KitCard.card_slots("bulwark").has("r") and ClassCard.kit_tip("bulwark").contains("Fusion"), "on: cards show it")
	ok(_controls_text().contains("ultimate") and _has_action_row("ultimate"), "on: controls and keybinds list it")
	var tu := _tutorial()
	ok(not tu.applies("pick_ult") and not tu.applies("ult"), "on: the tutorial still skips Fusion (11-18)")
	var tut_tips := {}
	for i in 60:
		Save.d["tutorial"]["tips_seen"] = []
		tut_tips[TipPick.pick(["no_summon"], true, false)] = true
	ok(not tut_tips.keys().any(func(t): return String(t).contains("fuses you")),
			"on: no loading/downed tip in the tutorials mentions the fuse")


# ------------------------------------------------------------------ helpers
func _tutorial() -> Tutorial:
	Save.d = Save.fresh()
	var k := Save.new_kin("cindle", "Ash")
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true}
	_match({"tutorial": true, "training": false, "teams": 1, "length": 1500.0, "demo_kin": "cindle"})
	return m.tut


## The key actions the Controls card rows carry (meta "actions"), joined.
func _controls_text() -> String:
	var v := VBoxContainer.new()
	main.add_child(v)
	ControlsCard.fill(v, "bulwark")
	var acts: Array = []
	_collect(v, acts)
	v.queue_free()
	return " ".join(acts)


func _collect(n: Node, out: Array) -> void:
	if n.has_meta("actions"):
		out.append_array(n.get_meta("actions"))
	for c in n.get_children():
		_collect(c, out)


func _has_action_row(action: String) -> bool:
	var ov = load("res://scripts/ui/overlay.gd").new()
	var v := VBoxContainer.new()
	main.add_child(v)
	ov._tab_controls(v)
	var what := String(Settings.ACTIONS.filter(func(a): return a[0] == action)[0][1])
	var found := _has_label(v, what)
	v.queue_free()
	ov.free()
	return found


func _has_label(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text == text:
		return true
	for c in n.get_children():
		if _has_label(c, text):
			return true
	return false
