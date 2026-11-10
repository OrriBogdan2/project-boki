extends RefCounted
## --belt-hint-check: the one-time hints for belt items (MatchHints.belt_picked and _belt_hint,
## UtilityBelt.hint_line, content/rules/hints.json belt_line). The first ground pickup of an item shows
## one line with its slot's key cap and the first sentence of its desc; the tonic and armor kit teach on
## low health and on an armor break instead; a chest key and later pickups say nothing; a second
## expedition on the same save (after a save round-trip) shows none of them.

const MOMENT_S := 3.0         # s of play a moment gets to show its hint (the poll and the lane)
const LINE_MAX := 80          # characters: one short toast line

var bad := 0
var main: Node
var m: Match
var p: Hunter
var tag := ""            # "first" or "second" expedition on the save

func ok(cond: bool, what: String) -> void:
	print("BLH %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	for id in FirstTimeHint.ids("match") + FirstTimeHint.ids("event"):
		FirstTimeHint.mark(String(id))      # only the belt hints are under test
	_expedition(true)
	Save.d = JSON.parse_string(JSON.stringify(Save.d))
	_expedition(false)
	if m:
		m.queue_free()
	print("BLH DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _expedition(first: bool) -> void:
	var want := 1 if first else 0
	tag = "first" if first else "second"
	_start()
	# a ground pickup: one line, the item's own key and effect
	var got := _moment(func(): UtilityBelt.pickup(p, "stim"))
	_count(got, want, "a stim pickup")
	if first and got.size() == 1:
		var key := _key("stim")
		var has_both: bool = got[0].contains(key + ":") and got[0].contains("Move 35% faster for 6s")
		ok(has_both, "stim line has key %s and effect: %s" % [key, got[0]])
		ok(got[0].contains("Swift draught") and not got[0].contains("{"), "stim line has its name and no placeholder")
		ok(got[0].length() <= LINE_MAX, "stim line is short (%d chars)" % got[0].length())
	# another item is its own hint
	_count(_moment(func(): UtilityBelt.pickup(p, "smoke")), want, "a smoke pickup")
	# the same item again, a chest key, a tonic and an armor kit: no pickup line
	UtilityBelt.take(p, "smoke", 9)      # frees the slot for the key
	got = _moment(func():
		UtilityBelt.pickup(p, "stim")
		UtilityBelt.pickup(p, "chest_key")
		UtilityBelt.pickup(p, "tonic")
		UtilityBelt.pickup(p, "armor_kit"))
	ok(UtilityBelt.count(p, "chest_key") > 0, "%s: the chest key went on the belt" % tag)
	_count(got, 0, "a second stim, a chest key, a tonic and an armor kit")
	# low health: the tonic's line with its key; armor break: the armor kit's
	got = _moment(func(): pass, func():
		p.hp = p.max_hp * 0.2      # the step heals the player at once, so the hint is ticked on its own
		m.hints.tick(Match.DT))
	_count(got, want, "low health")
	if first and got.size() == 1:
		var has_both: bool = got[0].contains(_key("tonic") + ":") and got[0].contains("heal 40% of your health")
		ok(has_both, "tonic line has its key and effect: %s" % got[0])
	p.hp = p.max_hp
	p.armor = 30.0
	m.step(Match.DT)
	got = _moment(func(): p.armor = 0.0)
	_count(got, want, "an armor break")
	if first and got.size() == 1:
		var has_both: bool = got[0].contains(_key("armor_kit") + ":") and got[0].contains("Repairs your armor to full")
		ok(has_both, "kit line has its key and effect: %s" % got[0])
	if first:
		var four := ["stim", "smoke", "tonic", "armor_kit"]
		ok(four.all(func(id): return FirstTimeHint.seen("belt." + id)), "the four are marked seen in the save")
		ok(not FirstTimeHint.seen("belt.chest_key"), "a chest key has no belt hint of its own")

func _key(id: String) -> String:
	return Settings.key_cap(UtilityBelt.KEYS[UtilityBelt.slot_of(p, id)])

func _count(got: Array, want: int, what: String) -> void:
	ok(got.size() == want, "%s: %s shows %d line(s), want %d (got %s)" % [tag, what, got.size(), want, str(got)])

func _start() -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 1, "tier": 0, "length": 1500.0, "seed": 7, "demo_kin": "cindle", "no_drop": true})
	m.set_process(false)
	p = m.player
	for mb in m.mobs:
		mb.queue_free()      # no fight to hold the hints back
	m.mobs.clear()
	for id in ["tonic", "armor_kit"]:
		if UtilityBelt.slot_of(p, id) < 0:
			UtilityBelt.grant(p, id)
	_moment(func(): pass)      # lets the match's own opening line pass

## Runs `start` once, then MOMENT_S of play (`each` instead of the step); returns the hint
## lines that appeared on the lane.
func _moment(start: Callable, each := Callable()) -> Array:
	m.hud.msgs.clear()
	start.call()
	var shown: Array = []
	var prev: Array = []
	for i in int(MOMENT_S / Match.DT):
		if each.is_valid():
			each.call()
		else:
			m.step(Match.DT)
		var lines: Array = m.hud.msgs.texts()
		for l in lines:
			if not l in prev and not String(l).begins_with("+"):
				shown.append(l)
		prev = lines
	return shown
