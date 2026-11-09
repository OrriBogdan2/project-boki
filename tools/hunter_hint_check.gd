extends RefCounted
## --hunter-hint-check: the first-time Hunter hints (HunterHints; content/archetypes/<id>.json "hint").
##   1. the data: all 12 Hunters have 5 hints (primary, right click, E, dash, ultimate), each one short
##      line in our words that names its slot's key, with a two-step move told in both steps
##   2. the keys are the player's own: rebinding E changes the E hints
##   3. each shows once per Hunter (flags independent between Hunters, kept in the save)
##   4. when each is due: the fighting slots in order once a foe is close, the ultimate at level 6
##   5. the v12 -> v13 migration: a Hunter the save already played gets none of its hints

const LINE_MAX := 64        # characters, with the keys filled in: one toast line
const KEY_OF := {"lmb": "fire", "rmb": "secondary", "e": "signature", "dash": "dash", "x": "hunter_ult"}
const TWO_STEP := ["again", "then", "drag"]

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("HHC %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_data()
	_keys()
	_once()
	_due()
	_migrate()
	print("HHC DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _fresh() -> Dictionary:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	return d

func _data() -> void:
	Save.d = _fresh()
	var missing: Array = []
	var long: Array = []
	var no_key: Array = []
	var no_two_step: Array = []
	for arch in Arch.ids():
		var two := false
		for slot in HunterHints.SLOTS:
			var hid := HunterHints.id(arch, slot)
			var line := FirstTimeHint.text(hid)
			if HunterHints.raw(hid) == "":
				missing.append(hid)
			if line.length() > LINE_MAX or line.contains("{"):
				long.append(hid)
			if not line.contains(Settings.key_cap(String(KEY_OF[slot]))):
				no_key.append(hid)
			two = two or TWO_STEP.any(func(w): return line.contains(w))
		if not two:
			no_two_step.append(arch)
	ok(Arch.ids().size() == 12, "12 Hunters (%d)" % Arch.ids().size())
	ok(missing.is_empty(), "every Hunter has all 5 hints (missing %s)" % str(missing))
	ok(long.is_empty(), "each fits one toast, keys filled in (%s)" % str(long))
	ok(no_key.is_empty(), "each names its slot's key (%s)" % str(no_key))
	ok(no_two_step.is_empty(), "each Hunter's two-step move is told in both steps (%s)" % str(no_two_step))
	ok(FirstTimeHint.text("archer.lmb") == "Hold %s to draw, release on the flash" % Settings.key_cap("fire"),
			"the Archer's first line: '%s'" % FirstTimeHint.text("archer.lmb"))
	ok(FirstTimeHint.text("archer.nope") == "" and FirstTimeHint.text("nobody.lmb") == "",
			"an unknown Hunter or slot has no line")

func _keys() -> void:
	var old := InputMap.action_get_events("signature")
	InputMap.action_erase_events("signature")
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	InputMap.action_add_event("signature", q)
	ok(FirstTimeHint.text("thief.e").contains("Q") and not FirstTimeHint.text("thief.e").contains("{"),
			"rebind E to Q: '%s'" % FirstTimeHint.text("thief.e"))
	InputMap.action_erase_events("signature")
	for e in old:
		InputMap.action_add_event("signature", e)

func _once() -> void:
	Save.d = _fresh()
	var shown: Array = []
	var toast := func(line: String): shown.append(line)
	for arch in Arch.ids():
		for slot in HunterHints.SLOTS:
			FirstTimeHint.show(HunterHints.id(arch, slot), toast)
	ok(shown.size() == 60, "12 Hunters x 5 hints show once each (%d toasts)" % shown.size())
	for arch in Arch.ids():
		for slot in HunterHints.SLOTS:
			FirstTimeHint.show(HunterHints.id(arch, slot), toast)
	ok(shown.size() == 60, "the second time, nothing")
	Save.d = JSON.parse_string(JSON.stringify(_fresh()))
	shown.clear()
	FirstTimeHint.show("archer.lmb", toast)
	Save.d = JSON.parse_string(JSON.stringify(Save.d))
	ok(FirstTimeHint.seen("archer.lmb") and not FirstTimeHint.seen("archer.rmb")
			and not FirstTimeHint.seen("thief.lmb"),
			"seen is kept in the save, per Hunter and per slot")

func _due() -> void:
	Save.d = _fresh()
	var order: Array = []
	for i in 6:
		var hid := HunterHints.due("mage", 1, true)
		order.append(hid)
		FirstTimeHint.mark(hid)
	ok(order.slice(0, 4) == ["mage.lmb", "mage.rmb", "mage.e", "mage.dash"] and order[4] == "" and order[5] == "",
			"a foe close: lmb, rmb, e, dash in order, the ultimate not before level 6 (%s)" % str(order))
	ok(HunterHints.due("mage", Hunter.ULT_AT[0], false) == "mage.x", "level 6: the ultimate's hint")
	Save.d = _fresh()
	ok(HunterHints.due("mage", 1, false) == "" and HunterHints.due("", 9, true) == ""
			and HunterHints.due("zzz", 9, true) == "",
			"no foe near, or no Hunter kit: nothing")

func _migrate() -> void:
	var old := _fresh()
	old["v"] = 12
	old["classes"]["hunters"] = {"archer": {"expeditions": 2}, "thief": {}}
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION, "a v12 save upgrades")
	Save.d = old
	ok(HunterHints.SLOTS.all(func(s): return FirstTimeHint.seen(HunterHints.id("archer", String(s)))),
			"a Hunter it played: no hints")
	ok(not FirstTimeHint.seen("thief.lmb") and not FirstTimeHint.seen("mage.x"),
			"a Hunter it never played: all its hints")
	var bare := _fresh()
	bare["v"] = 12
	bare.erase("classes")
	ok(Save.migrate(bare), "a save with no Hunter record still upgrades")
