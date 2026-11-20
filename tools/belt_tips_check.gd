extends RefCounted
## --belt-tips-check: the one-time belt item tips (BeltTips, shown by Match._tips through _tip). The
## first ground pickup of an item gives one line with its slot's key cap and the first sentence of its
## desc; the tonic and armor kit come on low health and an armor break instead; a chest key and a
## second pickup say nothing; a second expedition on the same save (after a save round-trip) shows none.

const LINE_MAX := 80  # characters: one short tip line

var bad := 0
var main: Node
var m: Match
var p: Hunter
var tag := ""  # "first" or "second" expedition on the save


func ok(cond: bool, what: String) -> void:
	print("BELT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	for key in ["move", "ability", "ult", "throw", "skill", "catch", "exit_uplink", "down"]:
		Save.d["tutorial"][key] = true  # only the belt tips are under test
	_expedition(true)
	Save.d = JSON.parse_string(JSON.stringify(Save.d))
	_expedition(false)
	m.queue_free()
	print("BELT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _expedition(first: bool) -> void:
	var want := 1 if first else 0
	tag = "first" if first else "second"
	_start()
	var got := _moment(func(): UtilityBelt.pickup(p, "stim"))
	_count(got, want, "a stim pickup")
	if first and got.size() == 1:
		ok(got[0].contains(_key("stim") + ": Move 35% faster for 6s"), "stim line has its key and effect: " + got[0])
		ok(got[0].begins_with("Swift draught on") and got[0].length() <= LINE_MAX, "stim line has its name, is short")
	_count(_moment(func(): UtilityBelt.pickup(p, "smoke")), want, "a smoke pickup")
	UtilityBelt.take(p, "smoke", 9)  # frees the slot for the key
	got = _moment(
		func():
			UtilityBelt.pickup(p, "stim")
			UtilityBelt.pickup(p, "chest_key")
			UtilityBelt.pickup(p, "tonic")
			UtilityBelt.pickup(p, "armor_kit")
	)
	ok(UtilityBelt.count(p, "chest_key") > 0, "%s: the chest key went on the belt" % tag)
	_count(got, 0, "a second stim, a chest key, a tonic and an armor kit")
	p.armor = 30.0
	_moment(func(): pass)
	got = _moment(func(): p.armor = 0.0)
	_count(got, want, "an armor break")
	if first and got.size() == 1:
		ok(got[0].contains(_key("armor_kit") + ": Repairs your armor to full"), "kit line: " + got[0])
	got = _moment(func(): p.hp = p.max_hp * 0.2)
	_count(got, want, "low health")
	if first and got.size() == 1:
		ok(got[0].contains(_key("tonic") + ": Drink for a second to heal"), "tonic line: " + got[0])
	if first:
		var four := ["stim", "smoke", "tonic", "armor_kit"]
		ok(four.all(func(id): return Save.d["tutorial"].get("belt_" + id, false)), "the four are marked in the save")
		ok(not Save.d["tutorial"].has("belt_chest_key"), "a chest key has no belt tip")


func _key(id: String) -> String:
	return Settings.key_cap(UtilityBelt.KEYS[UtilityBelt.slot_of(p, id)])


func _count(got: Array, want: int, what: String) -> void:
	ok(got.size() == want, "%s: %s shows %d line(s), want %d (got %s)" % [tag, what, got.size(), want, str(got)])


func _start() -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1e9, "seed": 7, "no_drop": true})
	m.set_process(false)
	p = m.player
	for id in ["tonic", "armor_kit"]:
		if UtilityBelt.slot_of(p, id) < 0:
			UtilityBelt.grant(p, id)
	m._tip_t = 2.0  # past the tips' opening second


## Runs `start`, then the tips a few times; returns the new tip lines on the message lane.
func _moment(start: Callable) -> Array:
	m.hud.msgs.clear()
	start.call()
	for i in 4:
		m._tips()
	return Array(m.hud.msgs.texts()).filter(func(l): return not String(l).begins_with("+"))
