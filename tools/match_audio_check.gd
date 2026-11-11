extends RefCounted
## --match-audio-check, owner item 103: no sound a match started outlives it. A short match with a
## Boki rescue channelling (its revive_hum loop) plus a deathbox revive hum and the looping hum also
## fired through the one-shot pool (the old bug); the match ends mid-channel (extracted), the game goes
## back to the farm, and after the fades nothing the match started is still playing (Sfx.match_voices).
## Also: a held loop stops on its own once its owner stops asking (the owner frozen or freed mid-channel).
## Shops (ShopSfx): coming within reach of a vendor rings its bell once, not again on a quick step out
## and back (ShopSfx.NEAR_GAP); opening, closing (use key or walking off), a buy (by price band) and a
## refused buy each play exactly one shop sound and nothing else from the shop.

var main: Node
var fails := 0
var n := 0
const SETTLE := 4.0            # s: longer than the slowest match fade (the score's stems, 1.2s)
## Every sound a shop action could start: its own family, plus the ones the shop or its buttons used before.
const SHOP_HEARD := ["shop_near", "shop_open", "shop_close", "shop_buy_s", "shop_buy_m", "shop_buy_l",
	"shop_broke", "bond", "whoosh", "click"]

func ok(cond: bool, what: String) -> void:
	n += 1
	print("MATCHAUDIO %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.d["music"] = Save.d.get("music", [])
	Game.goto("match", {"autoplay": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"demo_kin": "cindle"})
	for i in 6:
		await main.get_tree().process_frame
	var m: Match = main.current
	m.set_process(false)
	var P: Hunter = m.player
	var k: Kin = P.kin
	ok(k != null, "setup: the player has a Boki")
	if k == null:
		main.get_tree().quit(1)
		return
	_shops(m, P)
	var key := "rescue%d" % k.get_instance_id()
	# the Boki goes down beside you and you run into it: the rescue's hum starts and follows the carry
	k.pos = P.pos + Vector3(0.6, 0, 0)
	k.state = "active"
	k.fly = {}
	k.go_down()
	_step(m, 0.4)
	ok(k.rescue_on and Sfx.loop_on(key), "a rescue under way has its hum (rescue_on %s)" % k.rescue_on)
	# the owner stops ticking mid-channel (frozen, or its node gone): the held loop stops by itself
	await main.get_tree().create_timer(0.5).timeout
	ok(not Sfx.loop_on(key), "a held loop nobody asks for any more stops within %d ms" % Sfx.HOLD_MS)
	_step(m, 0.2)
	ok(k.rescue_on and Sfx.loop_on(key), "...and comes back while the rescue goes on")
	# the old leak: a looping file through the one-shot pool plays once now
	Sfx.play("revive_hum", P.pos)
	var once := Sfx.players.filter(func(p): return p.playing and Sfx.loops_forever(p.stream))
	ok(once.is_empty(), "a one-shot of a looping file does not loop (%d looping pool voices)" % once.size())
	Sfx.loop_start("boxhum_check", "revive_hum", P.pos)       # (as a deathbox revive does, keyed)
	ok(Sfx.match_voices() >= 2, "setup: the match has several voices going (%d)" % Sfx.match_voices())
	# extract mid-channel and go home
	m.result = {"extracted": true, "why": "extract"}
	m._finish()
	for i in 6:
		await main.get_tree().process_frame
	if not _on_farm():
		Game.goto("home")
		for i in 6:
			await main.get_tree().process_frame
	ok(_on_farm(), "back on the farm (%s)" % main.current)
	ok(not Sfx.loop_on(key) and not Sfx.loop_on("boxhum_check"), "no keyed match loop is left")
	await main.get_tree().create_timer(SETTLE).timeout
	ok(Sfx.match_voices() == 0, "after the fades nothing the match started is playing (%d)" % Sfx.match_voices())
	print("MATCHAUDIO DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _shops(m: Match, P: Hunter) -> void:
	ok(ShopSfx.buy_sound(10) == "shop_buy_s" and ShopSfx.buy_sound(60) == "shop_buy_m"
		and ShopSfx.buy_sound(200) == "shop_buy_l", "shops: the buy sound follows the price band")
	if Shops.list(m).is_empty():
		ok(false, "shops: the match has a vendor")
		return
	var v: Dictionary = Shops.list(m)[0]
	var at: Vector3 = v["pos"] + Vector3(1.0, 0, 0)
	var away: Vector3 = v["pos"] + Vector3(15.0, 0, 0)
	_walk(m, P, away)
	_quiet()
	_walk(m, P, at)
	_walk(m, P, at)
	ok(_heard() == {"shop_near": 1}, "shops: coming within reach rings the bell once %s" % _heard())
	_quiet()
	_walk(m, P, away)
	_walk(m, P, at)
	ok(_heard().is_empty(), "shops: a step out and straight back doesn't ring again %s" % _heard())
	m.time += ShopSfx.NEAR_GAP
	_walk(m, P, away)
	_walk(m, P, at)
	ok(_heard() == {"shop_near": 1}, "shops: ...it rings again %.0f s later %s" % [ShopSfx.NEAR_GAP, _heard()])
	_quiet()
	Shops.use(m, P, Shops.prompt(m, P))
	var pc = m.get_meta("shops")["panel"]
	ok(pc != null and _heard() == {"shop_open": 1}, "shops: opening the panel plays one sound %s" % _heard())
	P.gems = 1000
	var i := _row_where(v, P, "")
	var paid := ShopStock.price(P, v["rows"][i])
	_quiet()
	_buy_button(pc, i).pressed.emit()
	var band := ShopSfx.buy_sound(paid)
	ok(P.gems == 1000 - paid and _heard() == {band: 1}, "shops: a %d gem buy plays %s once %s" % [paid, band, _heard()])
	P.gems = 0
	ShopPanel.refresh(m, pc, v)
	var b := _buy_button(pc, _row_where(v, P, ShopStock.BROKE))
	ok(not b.disabled, "shops: a buy you can't afford can still be clicked")
	_quiet()
	b.pressed.emit()
	ok(P.gems == 0 and _heard() == {"shop_broke": 1}, "shops: ...and plays one dull tick %s" % _heard())
	_quiet()
	Shops.use(m, P, Shops.prompt(m, P))
	ok(_heard() == {"shop_close": 1}, "shops: the use key closes it with one sound %s" % _heard())
	Shops.use(m, P, Shops.prompt(m, P))
	_quiet()
	_walk(m, P, away)
	_walk(m, P, away)
	ok(_heard() == {"shop_close": 1}, "shops: walking off closes it with one sound %s" % _heard())

## The player stands at `to` for a step of the shops (Shops.update: the bell and the walk-off close),
## the ears with them as the camera would put them.
func _walk(m: Match, P: Hunter, to: Vector3) -> void:
	P.pos = to
	Sfx.listener = to
	Shops.update(m, Match.DT)

## Silences the pool and forgets Sfx's repeat gaps, so the next action's sounds are counted on their own.
func _quiet() -> void:
	for p in Sfx.players:
		p.stop()
	Sfx.last_played.clear()
	Sfx.recent.clear()

## How many pool voices are playing each SHOP_HEARD sound.
func _heard() -> Dictionary:
	var out := {}
	for sname in SHOP_HEARD:
		if not Sfx.ensure(sname):
			continue
		var takes: Array = [Sfx.streams[sname]]
		if Sfx.streams[sname] is Array:
			takes = Sfx.streams[sname]
		for p in Sfx.players:
			if p.playing and takes.has(p.stream):
				out[sname] = int(out.get(sname, 0)) + 1
	return out

## The first row of the vendor whose refusal reason for P is `why` ("" for one P can buy).
func _row_where(v: Dictionary, P: Hunter, why: String) -> int:
	for i in (v["rows"] as Array).size():
		if Shops.why_not(P, v["rows"][i]) == why:
			return i
	return 0

## Row i's Buy button in the panel as drawn now (rows are redrawn, so the freed ones are skipped).
func _buy_button(pc: Node, i: int) -> Button:
	var live := pc.find_children("*", "Button", true, false).filter(func(c): return not c.is_queued_for_deletion())
	return live[i]

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT

func _on_farm() -> bool:
	var sc: Script = main.current.get_script() if is_instance_valid(main.current) else null
	return sc != null and sc.resource_path.ends_with("home/home.gd")
