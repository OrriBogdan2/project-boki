extends RefCounted
## --first-shop-hint-check: the first-shop hint (Shops.first_hint through Match._tip, key "shop").
##   1. not in the first HINT_AFTER_LAND s after landing, even at a vendor; not away from a vendor
##   2. at a vendor after that: the line shows once, with the use key's cap, and never again that match
##   3. skipped (walked off without shopping): no line at the next vendor, nor in the next match
##   4. after a rebind of the use key, the line names the new key
## Prints FSHOP PASS/FAIL lines and FSHOP DONE.

const LINE_START := "A shop: spend gems"

var main: Node
var bad := 0

func ok(cond: bool, what: String, info := "") -> void:
	print("FSHOP %s %s  %s" % ["PASS" if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Settings.set_v("tips", true, false)
	Save.d = Save.fresh()
	var m: Match = await _build(11)
	_timing(m)
	_once_and_skip(m)
	m.queue_free()
	var m2: Match = await _build(12)
	_at_vendor(m2, 0)
	ok(_tick(m2) == 0, "skipped: a new match on the same save says nothing at a vendor")
	m2.queue_free()
	await _rebind()
	print("FSHOP DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _build(seed_i: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "seed": seed_i, "no_drop": true})
	m.set_process(false)
	return m

## Stands the player at vendor `i` (or far from every vendor for -1) and works out the use prompt.
func _at_vendor(m: Match, i: int) -> void:
	var v: Dictionary = Shops.list(m)[maxi(i, 0)]
	m.player.pos = v["pos"] if i >= 0 else v["pos"] + Vector3(40, 0, 0)
	m._update_interact(0.0)

## One hint pass with an empty lane; returns how many first-shop lines it put up.
func _tick(m: Match) -> int:
	m.hud.msgs.clear()
	m._tip_t = 20.0
	m._tips()
	var lines: Array = m.hud.msgs.texts() + m.hud.msgs._waiting.map(func(e): return String(e["text"]))
	return lines.filter(func(t): return String(t).begins_with(LINE_START)).size()

func _line(m: Match) -> String:
	for e in m.hud.msgs._shown + m.hud.msgs._waiting:
		if String(e["text"]).begins_with(LINE_START):
			return String(e["text"])
	return ""

func _timing(m: Match) -> void:
	ok(Shops.list(m).size() >= 2, "the map has two vendors or more", str(Shops.list(m).size()))
	m.time = 100.0
	m.player.set_meta("landed_t", m.time - (Shops.HINT_AFTER_LAND - 1.0))
	_at_vendor(m, 0)
	var kind := String(m.interact.get("kind", ""))
	ok(kind == "shop", "at the vendor the use prompt is the shop", kind)
	ok(_tick(m) == 0, "%d s after landing at a vendor: no line yet" % int(Shops.HINT_AFTER_LAND - 1.0))
	ok(not Save.d["tutorial"].has("shop"), "held back, so not marked seen")
	m.player.set_meta("landed_t", m.time - Shops.HINT_AFTER_LAND - 1.0)
	_at_vendor(m, -1)
	ok(_tick(m) == 0, "past the wait but no vendor in reach: no line")

func _once_and_skip(m: Match) -> void:
	_at_vendor(m, 0)
	ok(_tick(m) == 1, "past the wait at a vendor: the line shows")
	var want := "A shop: spend gems on tools for this run. Press %s." % Settings.key_cap("interact")
	ok(_line(m) == want, "the line reads with the use key's cap", _line(m))
	var again := 0
	for f in 5:
		again += _tick(m)
	ok(again == 0, "still at the vendor: never again", str(again))
	ok(bool(Save.d["tutorial"].get("shop", false)), "marked seen in the save")
	_at_vendor(m, -1)
	_tick(m)
	_at_vendor(m, 1)
	ok(_tick(m) == 0, "skipped (walked off without shopping): no line at the next vendor")

## (the rebind is written to this run's own XDG settings, so nothing to put back)
func _rebind() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_G
	Settings.rebind("interact", ev)
	Save.d = Save.fresh()
	var m: Match = await _build(11)
	m.time = 100.0
	m.player.set_meta("landed_t", 0.0)
	_at_vendor(m, 0)
	_tick(m)
	var line := _line(m)
	ok(Settings.key_cap("interact") != "F" and line.ends_with("Press %s." % Settings.key_cap("interact")),
		"after a rebind the line names the new key", line)
	ok(line.find("Press F.") < 0, "and not the old one")
	m.queue_free()
