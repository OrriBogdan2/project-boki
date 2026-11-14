extends RefCounted
## --feed-check: a hungry Boki, kibble bought at the market, the Feed panel lists it, feeding works
## and the "too weak to go" gate lifts. Fresh save, and a save with a trough built.
## Also the hand-feed verb (BaseHandFeed, base_mode): a trusting Boki eats from your hand in 3 s and the snack is
## used once, a shy one needs two tries, a full one sniffs and leaves, the prompt says what to hold.
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
	await _hand_cases()
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
	if k["likes"]["hates"] == "kibble":
		k["likes"]["hates"] = k["likes"]["food"]     # likes come from the random uid; a kibble-hater refuses
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
	await main.get_tree().process_frame      # the previous panel is only queue_freed: let it go first
	var btns := _feed_buttons(home.panel_host)
	ok(btns.size() == 1 and not _says_nothing(home.panel_host), "%s: the panel offers the kibble" % tag)
	ok(home.hecon.refuse_reason() != "", "%s: too weak to go while starving" % tag)
	var food0 := Care.need(k, "food")
	if btns.size() == 1: (btns[0] as Button).pressed.emit()
	var food1 := Care.need(k, "food")
	ok(Econ.pantry("kibble") == 1 and food1 > food0, "%s: feeding eats a kibble, food %d -> %d" % [tag, food0, food1])
	ok(home.hecon.refuse_reason() == "", "%s: it can go on an expedition again" % tag)
	home.queue_free()

const HAND_DT := 0.25      # s per farm step
const SNACK := "sapjelly"      # a snack of snacks.json: it gives joy and leans (kibble gives neither)
const HAND_WITHIN := 3.0   # s a trusting Boki takes to eat from your hand

## Runs the farm for `secs` simulated seconds.
func _run(home, secs: float) -> void:
	var t := 0.0
	while t < secs:
		home._move_kin(HAND_DT)
		t += HAND_DT

func _lean(k: Dictionary) -> float:
	var sum := 0.0
	for v in k.get("lean", {}).values():
		sum += float(v)
	return sum

func _hand_cases() -> void:
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	for who in ["trusting", "shy", "full"]:
		Save.d = Save.fresh()
		var k := Save.new_kin("zapple", "Pip")
		Care.ensure(k)
		k["likes"]["hates"] = "frostdrop"
		k["likes"]["food"] = "pebblenut"
		k["starter"] = true
		k["trust"] = 5.0 if who == "shy" else 60.0
		k["needs"]["food"] = 98.0 if who == "full" else 40.0
		k["needs"]["joy"] = 50.0
		Save.d["roster"].append(k)
		Save.d["active"] = k["uid"]
		Save.d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
		HomeLayout.ensure(Save.d)
		for f in Care.FOODS:      # a fresh save starts with kibble now: Q must land on the snack first
			Save.d["items"].erase(f)
		Save.d["items"][SNACK] = 2
		var home = await main._hb_home()
		home.day_t = 0.4
		home.ppos = home.world.random_ground(0)
		var e: Dictionary = home.kins[0]
		e["pos"] = home.world.free_spot_near(home.ppos + Vector3(3, 0, 0), [], 0.8)
		(e["node"] as Node3D).position = e["pos"]
		e["goal"] = e["pos"]
		await main.get_tree().process_frame
		var hand: BaseHandFeed = home.life.hand
		var fsm: Fsm = home.life.machine(e)
		fsm.go(BaseLife.S.ROAM, "check")
		ok(BaseHandFeed.hint() == "Hold %s to feed" % Settings.key_cap("interact"), "prompt text names the use key")
		ok(not hand.offer(e), "%s: no snack selected, the hold does not feed" % who)
		hand.cycle()
		ok(hand.snack == SNACK and hand.pairs([]).size() == 1, "%s: Q selects the snack and the prompt shows it" % who)
		var joy0 := Care.need(k, "joy")
		var food0 := Care.need(k, "food")
		var trust0 := float(k["trust"])
		var lean0 := _lean(k)
		ok(hand.offer(e) and fsm.is_in(BaseLife.S.APPROACH), "%s: the held use key sends it to your hand" % who)
		var ate_at := -1.0
		var t := 0.0
		while t < 6.0:
			_run(home, HAND_DT)
			t += HAND_DT
			if ate_at < 0.0 and Econ.pantry(SNACK) < 2 and fsm.is_in(BaseLife.S.DONE):
				ate_at = t
		match who:
			"trusting":
				ok(ate_at > 0.0 and ate_at <= HAND_WITHIN,
					"trusting: ate from the hand in %.2f s (limit %.0f)" % [ate_at, HAND_WITHIN])
				ok(Econ.pantry(SNACK) == 1, "trusting: the snack was used once (%d left)" % Econ.pantry(SNACK))
				ok(Care.need(k, "food") > food0 and Care.need(k, "joy") > joy0,
					"trusting: food %.0f -> %.0f, joy %.0f -> %.0f"
					% [food0, Care.need(k, "food"), joy0, Care.need(k, "joy")])
				ok(float(k["trust"]) > trust0, "trusting: trust went up")
				ok(_lean(k) > lean0, "trusting: the snack's own lean built (%.1f -> %.1f)" % [lean0, _lean(k)])
				ok(fsm.is_in(BaseLife.S.ROAM) and not e.has("hand"), "trusting: back to its day, the hand is empty")
			"shy":
				ok(Econ.pantry(SNACK) == 2 and float(k["trust"]) == trust0, "shy: the first try is a hesitant look")
				ok(not fsm.is_in(BaseLife.S.EAT) and e.has("hand_shy"), "shy: it remembers being asked")
				hand.offer(e)
				_run(home, 6.0)
				ok(Econ.pantry(SNACK) == 1 and float(k["trust"]) > trust0,
					"shy: the second try, it ate and trusts more")
			"full":
				ok(Econ.pantry(SNACK) == 2 and is_equal_approx(Care.need(k, "food"), food0),
					"full: sniffed, snack kept")
				ok(fsm.is_in(BaseLife.S.ROAM), "full: it left")
		ok(fsm.refused == 0, "%s: no machine refusal (%d)" % [who, fsm.refused])
		home.queue_free()
		await main.get_tree().process_frame
	rules["base_mode"] = false
