extends RefCounted
## --feed-check: a hungry Boki, kibble bought at the market, the Feed panel lists it, feeding works
## and the "too weak to go" gate lifts. Fresh save, and a save with a trough built.
## Prints FEED ok/FAIL lines and "FEED DONE, failures: N". Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FEED %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	await _case(false)
	await _case(true)
	print("FEED DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _feed_buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button and (n as Button).text == "Feed": out.append(n)
	for c in n.get_children(): out += _feed_buttons(c)
	return out

func _says_nothing(n: Node) -> bool:
	if n is Label and (n as Label).text.begins_with("Nothing to feed"): return true
	for c in n.get_children():
		if _says_nothing(c): return true
	return false

func _case(trough: bool) -> void:
	var tag := "with a trough" if trough else "fresh save"
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Care.ensure(k)
	k["starter"] = true
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true}
	Save.d["gems"] = 500
	HomeLayout.ensure(Save.d)
	if trough: Econ.ensure()
	k["needs"]["food"] = 5.0
	k["starve"] = (Care.STARVE["refuse"] + 0.5) * 3600.0
	var home = await main._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await main.get_tree().process_frame
	Save.d["items"]["kibble"] = 0
	home._open_feed(k)
	ok(_feed_buttons(home.panel_host).is_empty() and _says_nothing(home.panel_host), "%s: no food says so" % tag)
	var ask := Exchange.best("kibble", "sell")
	var r := Exchange.post("buy", "kibble", 2, ask)
	ok(r["ok"] and int(r["filled"]) == 2 and Econ.pantry("kibble") == 2, "%s: bought 2 kibble from the market" % tag)
	home._open_feed(k)
	var btns := _feed_buttons(home.panel_host)
	ok(btns.size() == 1 and not _says_nothing(home.panel_host), "%s: the panel offers the kibble" % tag)
	ok(home.hecon.refuse_reason() != "", "%s: too weak to go while starving" % tag)
	var food0 := Care.need(k, "food")
	if btns.size() == 1: (btns[0] as Button).pressed.emit()
	var food1 := Care.need(k, "food")
	ok(Econ.pantry("kibble") == 1 and food1 > food0, "%s: feeding eats a kibble, food %d -> %d" % [tag, food0, food1])
	ok(home.hecon.refuse_reason() == "", "%s: it can go on an expedition again" % tag)
	home.queue_free()
