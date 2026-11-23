extends RefCounted
## --hunter-hint-check: the first-time Hunter hints (HunterHints; content/archetypes/<id>.json "hint").
##   1. the data: every Hunter has four hints (primary, right click, E, dash), each one short line that names its
##      slot's key, with the player's own keys filled in
##   2. the keys are the player's own: rebinding E changes the E hint
##   3. in a match: nothing with no foe close; then the four in order, one at a time, GAP_S apart, each once
##   4. a save round trip keeps them seen, and another Hunter's hints are independent
##   5. the v20 -> v21 migration: a Hunter the save already played gets none of its hints

const LINE_MAX := 64  # characters, keys filled in: one toast line
const KEY_OF := {"lmb": "fire", "rmb": "secondary", "e": "signature", "dash": "dash"}

var bad := 0
var m: Match
var main: Node


func ok(cond: bool, what: String) -> void:
	print("HHC %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	Settings.set_v("tips", true, false)
	_data()
	_keys()
	_match()
	_migrate()
	print("HHC DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _line(arch: String, slot: String) -> String:
	return Settings.fill_keys(String((Arch.def(arch).get("hint", {}) as Dictionary).get(slot, "")))


func _data() -> void:
	var missing: Array = []
	var long: Array = []
	var no_key: Array = []
	for arch in Arch.ORDER:
		for slot in HunterHints.SLOTS:
			var line := _line(arch, slot)
			if line == "":
				missing.append("%s.%s" % [arch, slot])
			if line.length() > LINE_MAX or line.contains("{"):
				long.append("%s.%s" % [arch, slot])
			if not line.contains(Settings.key_cap(String(KEY_OF[slot]))):
				no_key.append("%s.%s" % [arch, slot])
	ok(Arch.ORDER.size() == 13, "13 Hunters (%d)" % Arch.ORDER.size())
	ok(missing.is_empty(), "every Hunter has all four hints (missing %s)" % str(missing))
	ok(long.is_empty(), "each fits one toast, keys filled in (%s)" % str(long))
	ok(no_key.is_empty(), "each names its slot's key (%s)" % str(no_key))


func _keys() -> void:
	var old := InputMap.action_get_events("signature")
	InputMap.action_erase_events("signature")
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	InputMap.action_add_event("signature", q)
	var line := _line("thief", "e")
	ok(line.contains("Q") and not line.contains("{"), "rebind E to Q: '%s'" % line)
	InputMap.action_erase_events("signature")
	for e in old:
		InputMap.action_add_event("signature", e)


func _match() -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var p := m.player
	p.arch = "mage"
	var far := p.pos + Vector3(HunterHints.FOE_M * 3.0, 0, 0)
	for mb in m.mobs:
		mb.pos = far
	var rivals := m.hunters.filter(func(h): return h.team != p.team)
	for h in rivals:
		h.pos = far
	m.time = 100.0
	ok(m.hunter_hints.next(m).is_empty(), "no foe close: nothing")
	m.spawn_mob("skitter", p.pos + Vector3(3, 0, 0))
	var order: Array = []
	for i in 6:
		var tip := m.hunter_hints.next(m)
		order.append(String(tip[0]) if tip else "")
		if tip:
			ok(tip[1] == _line("mage", HunterHints.SLOTS[i]), "line %d is the Mage's: '%s'" % [i, tip[1]])
			Save.d["tutorial"][tip[0]] = true
		var again := m.hunter_hints.next(m)
		ok(again.is_empty(), "no second line within GAP_S")
		m.time += HunterHints.GAP_S
	var want := ["hh_mage_lmb", "hh_mage_rmb", "hh_mage_e", "hh_mage_dash", "", ""]
	ok(order == want, "in order, once each: %s" % str(order))
	p.arch = "thief"
	m.time += HunterHints.GAP_S
	ok(m.hunter_hints.next(m)[0] == "hh_thief_lmb", "another Hunter's hints are its own")
	m.queue_free()


func _migrate() -> void:
	var old := Save.fresh()
	old["v"] = 20
	old["classes"]["hunters"] = {"archer": {"matches": 2}, "thief": {}}
	var path := "user://hunter_hint_check_old.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.d = Save.fresh()
	Save.load_from(path)
	DirAccess.remove_absolute(path)
	var seen := Save.d["tutorial"] as Dictionary
	ok(int(Save.d["v"]) == Save.VERSION, "a v20 save upgrades")
	var archer_seen := HunterHints.SLOTS.all(func(s): return seen.get(HunterHints.key("archer", s), false))
	ok(archer_seen, "a Hunter it played: no hints")
	ok(not seen.has("hh_thief_lmb") and not seen.has("hh_mage_lmb"), "a Hunter it never played: all its hints")
	var bare := Save.fresh()
	bare["v"] = 20
	bare.erase("classes")
	ok(Save.migrate(bare), "a save with no Hunter record still upgrades")
