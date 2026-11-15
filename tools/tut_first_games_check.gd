extends RefCounted
## --tut-first-games-check: the garden games' first round (scripts/home/first_round.gd). On a base-mode
## garden with three rested Boki, for Stump Shove, Seek and Spark Volley:
##   1. the first start of the game on a save is the practice round: its line names the interact and
##      menu keys through Settings.key_cap, and the save's tutorial flag is set at once (once per save)
##   2. the first press (Shove, Volley) or practice_s (Seek) ends it: no gems, no energy, no memory
##   3. the next start is the real game; Esc skips a fresh practice round; tips off, or a Boki that
##      already remembers the game, never get one
## Never touches the real save.

const SETTLE_FRAMES := 600

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FIRSTGAMES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Settings.v["tips"] = true
	var d := Save.fresh()
	for i in 3:
		var k := Save.new_kin(["zapple", "cindle", "zapple"][i], ["Pip", "Ash", "Bo"][i])
		k["level"] = 5
		Care.ensure(k)
		k["needs"]["energy"] = 90.0
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "first_race": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	FarmUnlocks.rules()["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	for k in home.kins:
		k.erase("indoors")
	ok(home.hshove != null and home.hseek != null and home.hvolley != null, "the base has all three games")
	if home.hshove != null:
		_timed(home, home.hshove, BaseShove.FIRST, "shove")
	if home.hvolley != null:
		_timed(home, home.hvolley, BaseVolley.FIRST, "volley")
	if home.hseek != null:
		_seek(home, home.hseek)
	_gates()
	print("FIRSTGAMES DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e

func _snap() -> Array:
	var out: Array = [int(Save.d.get("gems", 0))]
	for rec in Save.d["roster"]:
		out.append([float(rec["needs"]["energy"]), rec.get("memory", []).size()])
	return out

func _keys_named(text: String) -> bool:
	return text.contains(Settings.key_cap("interact")) and text.contains(Settings.key_cap("menu"))

func _free(home) -> void:
	for k in home.kins:
		k["busy"] = false

## Stump Shove and Spark Volley: a timing-bar game that the practice ends at the first press.
func _timed(home, game, flag: String, what: String) -> void:
	_free(home)
	Save.d["tutorial"].erase(flag)
	var before := _snap()
	game.use()
	ok(game.run != null and game.practice, "%s: the first start is the practice round" % what)
	ok(Save.d["tutorial"].get(flag, false), "%s: offered once per save (%s set)" % [what, flag])
	var text: String = game.bar.lbl.text if game.bar != null else ""
	ok(_keys_named(text) and text.begins_with("Practice"), "%s: one line names the keys (%s)" % [what, text])
	game.bar.m = game.bar.zone
	var t := 0.0
	while game.run != null and not game.run.call("can_" + ("shove" if what == "shove" else "call")) and t < 20.0:
		game.tick(0.1)          # (a volley waits for the seed to come to your Boki)
		t += 0.1
	if game.run != null:
		game.bar.m = game.bar.zone
		game.input(_key("interact"))
	ok(game.run == null and not game.practice, "%s: the first press ends it (%.1f s)" % [what, t])
	ok(_snap() == before and not is_instance_valid(game.card), "%s: no gems, energy or memory, no result card" % what)
	_free(home)
	game.use()
	ok(game.run != null and not game.practice, "%s: the next start is the real game" % what)
	game._end(false)
	_free(home)
	Save.d["tutorial"].erase(flag)
	game.use()
	var skipped: bool = game.input(_key("menu")) and game.run == null and _snap() == before
	ok(skipped, "%s: Esc skips the practice, no cost" % what)
	ok(Save.d["tutorial"].get(flag, false), "%s: a skipped practice does not come back" % what)
	_free(home)

func _seek(home, sk) -> void:
	_free(home)
	Save.d["tutorial"].erase(BaseSeek.FIRST)
	var before := _snap()
	sk.use()
	ok(sk.state == BaseSeek.S.CARRY and sk.practice, "seek: the first start is the practice hunt")
	ok(Save.d["tutorial"].get(BaseSeek.FIRST, false), "seek: offered once per save")
	home.ppos = home.kins[0]["pos"] + Vector3(7, 0, 0)
	sk.use()
	ok(sk.state == BaseSeek.S.HUNT and sk.practice, "seek: hidden, the practice hunt runs")
	var t := 0.0
	var cap := float(BaseSeek.rules()["practice_s"])
	while sk.state == BaseSeek.S.HUNT and t < cap + 5.0:
		sk.tick(0.1)
		t += 0.1
	var short: bool = sk.state == BaseSeek.S.IDLE and t <= cap + 0.2 and not sk.practice
	ok(short, "seek: short, it ends by %.0f s (%.1f s)" % [cap, t])
	ok(_snap() == before and not is_instance_valid(sk.card), "seek: no gems, energy or memory, no result card")
	_free(home)
	sk.use()
	ok(sk.state == BaseSeek.S.CARRY and not sk.practice, "seek: the next start is the real hunt")
	sk.input(_key("menu"))
	ok(sk.state == BaseSeek.S.IDLE, "seek: Esc puts the scent back")
	_free(home)

func _gates() -> void:
	var flags := ["first_shove", "first_seek", "first_volley"]
	for f in flags:
		Save.d["tutorial"].erase(f)
	ok(FirstRound.due("first_shove", "shove"), "gates: a fresh save is due")
	Settings.v["tips"] = false
	ok(not FirstRound.due("first_shove", "shove"), "gates: tips off, no practice round")
	Settings.v["tips"] = true
	Save.remember(Save.d["roster"][0], "volley", "beat Ash 5 to 3 at Spark Volley")
	ok(not FirstRound.due("first_volley", "volley") and FirstRound.due("first_seek", "seek"),
			"gates: a Boki that remembers the game skips its practice (old saves)")
	ok(FirstRound.line("x").count(Settings.key_cap("interact")) == 1, "gates: the line names the key once")
