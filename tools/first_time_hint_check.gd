extends RefCounted
## --first-time-hint-check: the one-time hints that took over the cut tutorial steps (FirstTimeHint,
## content/rules/hints.json; decision 0023).
##   1. the data: every hint has a "when" note and one short line in our words, the keys filled in
##   2. shown once: show() toasts it the first time and never again; mark() (doing the thing first) means
##      it never shows; the flags live in the save, so a reload keeps them
##   3. the v11 -> v12 migration: a save past the old tutorials gets none of their hints, one mid-farm-
##      tutorial keeps the farm ones
##   4. when the farm ones are due (FarmHints.due): out of seeds, holding a crop

const LINE_MAX := 60        # characters: a hint is one short toast line

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FTH %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_data()
	_once()
	_migrate()
	_farm_due()
	print("FTH DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _fresh() -> Dictionary:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	return d

func _data() -> void:
	Save.d = _fresh()
	var when: Dictionary = FirstTimeHint.rules().get("when", {})
	var all: Array = FirstTimeHint.ids("match") + FirstTimeHint.ids("farm")
	var nm := FirstTimeHint.ids("match").size()
	var nf := FirstTimeHint.ids("farm").size()
	ok(nm >= 8 and nf >= 5, "the cut steps are hints: %d match, %d farm" % [nm, nf])
	ok(all.all(func(id): return when.has(id)), "every hint says when it shows")
	var long := all.filter(func(id): return FirstTimeHint.text(String(id)).length() > LINE_MAX)
	ok(long.is_empty(), "every line fits one toast (%s)" % str(long))
	var raw := all.filter(func(id): return FirstTimeHint.text(String(id)).contains("{"))
	ok(raw.is_empty(), "every placeholder is filled (%s)" % str(raw))
	var key := FirstTimeHint.text("key")
	ok(key.contains(Settings.key_cap("interact")), "keys are the player's own: '%s'" % key)
	ok(FirstTimeHint.text("orders").contains("Pip"), "the Boki is named: '%s'" % FirstTimeHint.text("orders"))
	ok(FirstTimeHint.text("nope") == "", "an unknown id has no line")

func _once() -> void:
	Save.d = _fresh()
	var shown: Array = []
	var toast := func(line: String): shown.append(line)
	ok(not FirstTimeHint.seen("rank") and FirstTimeHint.show("rank", toast) and shown.size() == 1,
			"the first time it matters, it shows")
	ok(not FirstTimeHint.show("rank", toast) and shown.size() == 1, "the second time, nothing")
	FirstTimeHint.mark("crouch")
	ok(not FirstTimeHint.show("crouch", toast) and shown.size() == 1, "doing the thing first means it never shows")
	ok(not FirstTimeHint.show("nope", toast) and not FirstTimeHint.seen("nope"), "an unknown id shows nothing")
	var js := JSON.stringify(Save.d)
	Save.d = JSON.parse_string(js)
	ok(FirstTimeHint.seen("rank") and FirstTimeHint.seen("crouch") and not FirstTimeHint.seen("pickup"),
			"they are kept in the save")

func _migrate() -> void:
	var old := _fresh()
	old["v"] = 11
	old["tutorial"] = {"hatched": true, "match": true, "ft": {"done": true}}
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION, "a v11 save upgrades")
	Save.d = old
	var all: Array = FirstTimeHint.ids("match") + FirstTimeHint.ids("farm")
	ok(all.all(func(id): return FirstTimeHint.seen(String(id))),
			"past both old tutorials: no hints for what they taught")
	var mid := _fresh()
	mid["v"] = 11
	mid["tutorial"] = {"hatched": true, "match": true, "ft": {"done": false, "did": {"chop": true}}}
	Save.migrate(mid)
	Save.d = mid
	ok(FirstTimeHint.seen("rank") and not FirstTimeHint.seen("hammer") and not FirstTimeHint.seen("sell"),
			"mid farm tutorial: the match hints are settled, the farm ones still to come")

func _farm_due() -> void:
	Save.d = _fresh()
	var fh := FarmHints.new(null)
	for s in Save.d["seeds"]:
		Save.d["seeds"][s] = 0
	ok(fh.due("buy"), "out of seeds: the Market hint is due")
	Save.d["seeds"]["tidebloom"] = 2
	ok(not fh.due("buy"), "with seeds: not")
	Save.d["crops"]["tidebloom"] = 1
	ok(fh.due("sell"), "holding a crop: the selling hint is due")
