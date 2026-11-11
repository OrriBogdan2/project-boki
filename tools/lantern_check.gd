extends RefCounted
## --lantern-check: Lantern Match (scripts/home/lantern_match.gd, GARDEN_MODERN.md 4.2 game 6).
##   1. the board: 12 caps, 6 pairs, the same seed deals the same ring, each pair flashes then all go dark
##   2. picks: none while it flashes, a mismatch shows then goes dark, a match stays lit, a cleared solo
##      ring deals a fresh one
##   3. Focus and curiosity shorten the sniff; seeded solo runs: a Focus Boki points more often per second
##      and a player who only follows its points finds more pairs
##   4. versus: seeded runs, a Focus rival remembers and wins more; a match keeps the turn
##   5. a settled game: prizes from the lantern table, a solo win never moves the cup, a versus win does
##   6. the state machine refuses moves its table lacks
##   7. on the base: no ring with base_mode off; with it on, the ring opens a panel, solo plays to a card
## Never touches the real save.

const RUNS := 40                 # seeded games per comparison
const DT := 1.0 / 30.0           # s per step
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("LANTERN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_board()
	_picks()
	_sniffs()
	_versus()
	_settle()
	_machine()
	await _on_base()
	print("LANTERN DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(kname: String, focus: int, curiosity := 0.5) -> Dictionary:
	var k := Save.new_kin("zapple", kname)
	k["level"] = 5
	Care.ensure(k)
	k["stats"]["focus"] = focus
	k["traits"]["curiosity"] = curiosity
	k["needs"]["joy"] = 50.0
	k["needs"]["energy"] = 90.0
	return k

func _rng(seed_: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	return r

func _board() -> void:
	var b := LanternMatch.Board.new(_kin("A", 0), {}, _rng(7))
	var counts := {}
	for c in b.caps:
		counts[c] = int(counts.get(c, 0)) + 1
	ok(b.caps.size() == 12 and counts.size() == 6 and counts.values().all(func(n): return n == 2), "12 caps, 6 pairs")
	ok(LanternMatch.Board.new(_kin("A", 0), {}, _rng(7)).caps == b.caps, "the same seed deals the same ring")
	ok(LanternMatch.Board.new(_kin("A", 0), {}, _rng(8)).caps != b.caps, "another seed deals another ring")
	var flashed := {}
	while b.flash_t > 0.0:
		var lit := range(12).filter(func(i): return b.lit(i))
		if not lit.is_empty() and not flashed.has(b.caps[lit[0]]):
			ok(lit.size() == 2 and b.caps[lit[0]] == b.caps[lit[1]], "a flash lights one pair")
			flashed[b.caps[lit[0]]] = true
		b.step(DT)
	ok(flashed.size() == 6, "every pair flashed")
	ok(range(12).all(func(i): return not b.lit(i)), "after the flash every cap is dark")

func _picks() -> void:
	var b := LanternMatch.Board.new(_kin("A", 0), {}, _rng(3))
	ok(not b.pick(0), "no pick while the board flashes")
	_past_flash(b)
	var a := 0
	var miss: int = range(1, 12).filter(func(i): return b.caps[i] != b.caps[a])[0]
	ok(b.pick(a) and b.pick(miss), "two caps open")
	ok(not b.pick(b.partner(a)), "no third cap while two are lit")
	_play_to(b, b.t + float(LanternMatch.rules()["reveal_s"]) + 0.1)
	ok(not b.lit(a) and not b.lit(miss), "a mismatch goes dark")
	ok(b.pick(a) and b.pick(b.partner(a)) and b.matched[a] and b.pairs[0] == 1, "a match stays lit and scores")
	ok(not b.pick(a), "a matched cap cannot be opened")
	for c in 12:
		if not b.matched[c]:
			b.pick(c)
			b.pick(b.partner(c))
	var fresh: bool = b.pairs[0] == 6 and not b.matched.has(true) and b.flash_t > 0.0
	ok(fresh, "a cleared solo ring deals a fresh one that flashes")

func _past_flash(b: LanternMatch.Board) -> void:
	while b.flash_t > 0.0:
		b.step(DT)

func _play_to(b: LanternMatch.Board, t: float) -> void:
	while b.t < t:
		b.step(DT)

## Plays a board to its end as a player who remembers nothing: on your turn open an unmatched cap, then the
## Boki's point if it has one (waiting a second for it), else another cap.
func _play(b: LanternMatch.Board, dice: RandomNumberGenerator) -> void:
	var wait := 0.0
	while not b.over():
		b.step(DT)
		wait -= DT
		if b.over() or b.turn != 0 or b.flash_t > 0.0 or b.shut_t > 0.0 or wait > 0.0:
			continue
		var can := range(12).filter(func(i): return b.can_open(i))
		var pick: int = b.hint if b.open.size() == 1 and b.hint >= 0 else can[dice.randi_range(0, can.size() - 1)]
		b.pick(pick)
		wait = 1.0 if b.open.size() == 1 and b.hint < 0 else 0.3

## A seeded solo game: [won, points per second of play, pairs found].
func _solo(rec: Dictionary, seed_: int) -> Array:
	var b := LanternMatch.Board.new(rec, {}, _rng(seed_))
	_play(b, _rng(seed_ + 500))
	return [b.won(), float(b.hints) / maxf(b.t, 1.0), b.pairs[0]]

func _sniffs() -> void:
	var plain := _kin("Plain", 0)
	var sharp := _kin("Sharp", 50)
	var curious := _kin("Curious", 0, 1.0)
	var twice := is_equal_approx(LanternMatch.sniff_every(sharp) * 2.0, LanternMatch.sniff_every(plain))
	ok(twice, "50 Focus sniffs twice as often")
	ok(LanternMatch.sniff_every(curious) < LanternMatch.sniff_every(plain), "a curious Boki sniffs more often")
	var rate := [0.0, 0.0]
	var wins := [0, 0]
	var found := [0, 0]
	for n in RUNS:
		for i in 2:
			var r := _solo([plain, sharp][i], 100 + n)
			wins[i] += 1 if r[0] else 0
			rate[i] += r[1] / RUNS
			found[i] += r[2]
	ok(rate[1] > rate[0] * 1.5, "Focus points more often: %.3f vs %.3f points/s" % [rate[1], rate[0]])
	ok(found[1] > found[0] and wins[1] >= wins[0], "following a Focus Boki finds more: %d vs %d pairs, %d vs %d wins"
			% [found[1], found[0], wins[1], wins[0]])

## A seeded versus game against foe, you a player who missed the flash but remembers every cap opened
## since: the rival's pairs minus yours.
func _vs(foe: Dictionary, seed_: int) -> int:
	var b := LanternMatch.Board.new(_kin("You", 0), foe, _rng(seed_))
	var dice := _rng(seed_ + 900)
	var known := {}                  # cap -> pair, every cap opened in play
	while not b.over():
		b.step(DT)
		for i in b.open:
			known[i] = b.caps[i]
		if b.over() or b.turn != 0 or b.flash_t > 0.0 or b.shut_t > 0.0:
			continue
		var can := range(12).filter(func(i): return b.can_open(i))
		var sure := can.filter(func(i): return known.has(i) and known.has(b.partner(i)) \
				and (b.open.is_empty() or b.open.has(b.partner(i))))
		var fresh := can.filter(func(i): return not known.has(i))
		var from: Array = fresh if not fresh.is_empty() else can
		if not sure.is_empty():
			from = sure
		b.pick(from[dice.randi_range(0, from.size() - 1)])
	return b.pairs[1] - b.pairs[0]

func _versus() -> void:
	var lead := [0, 0]
	for n in RUNS:
		lead[0] += _vs(_kin("Dull", 0), 300 + n)
		lead[1] += _vs(_kin("Keen", 60), 300 + n)
	ok(lead[1] > lead[0], "a Focus rival leads by more pairs: %d vs %d over %d games" % [lead[1], lead[0], RUNS])
	var b := LanternMatch.Board.new(_kin("You", 0), _kin("Foe", 0), _rng(5))
	_past_flash(b)
	var miss: int = range(1, 12).filter(func(i): return b.caps[i] != b.caps[0])[0]
	b.pick(0)
	b.pick(miss)
	_play_to(b, b.t + float(LanternMatch.rules()["reveal_s"]) + 0.1)
	ok(b.turn == 1 and not b.pick(1), "a miss passes the turn; you cannot open on the rival's turn")
	b = LanternMatch.Board.new(_kin("You", 0), _kin("Foe", 0), _rng(6))
	_past_flash(b)
	ok(b.pick(0) and b.pick(b.partner(0)) and b.turn == 0 and b.pairs == [1, 0], "a match keeps the turn")

## A finished board: you hold `mine` pairs, the rival `theirs`, the clock run out.
func _done(me: Dictionary, foe: Dictionary, mine: int, theirs: int) -> LanternMatch.Board:
	var b := LanternMatch.Board.new(me, foe, _rng(1))
	b.pairs = [mine, theirs]
	b.t = float(LanternMatch.rules()["time_s"])
	return b

func _settle() -> void:
	var table: Array = GardenPrizes.game("lantern")["table"]
	var ids := table.map(func(e): return e["id"])
	ok(ids.has("peekbox") and ids.has("hush_truffle") and ids.has("glowmoss_sprig"),
			"the lantern table holds Peekbox, Glowmoss Sprig and Hush Truffle")
	for e in table:
		var id := String(e["id"])
		var known: bool = Data.CROPS.has(id) if e["kind"] == "snack" else GardenItems.item_name(id) != id
		ok(known, "table entry %s exists" % e["id"])
	var me := _kin("Me", 20)
	var gems := int(Save.d["gems"])
	var res := LanternMatch.settle(_done(me, {}, int(LanternMatch.rules()["solo_goal"]), 0))
	var two: bool = res["prize"]["items"].size() == 2 and res["prize"]["first"]
	ok(res["won"] and two, "a solo win: a roll and the first-win item")
	ok(res["prize"]["round"] == "" and GardenPrizes.stage(me, "lantern") == 0, "a solo win never moves the cup")
	ok(int(Save.d["gems"]) == gems + int(LanternMatch.rules()["gems"]), "gems paid")
	var joy := Care.need(me, "joy")
	res = LanternMatch.settle(_done(me, _kin("Strong", 40), 4, 2))
	ok(res["won"] and res["prize"]["round"] == "Sprout", "a versus win over a stronger Boki takes the Sprout round")
	var lost := LanternMatch.settle(_done(me, _kin("Strong", 40), 2, 4))
	ok(not lost["won"] and Care.need(me, "joy") < joy + float(LanternMatch.rules()["win_joy"]), "a loss sulks")
	ok(lost["prize"]["reset"] and GardenPrizes.stage(me, "lantern") == 0, "a loss starts the cup over")
	var draw := LanternMatch.settle(_done(me, _kin("Even", 20), 3, 3))
	ok(draw["draw"] and not draw["won"], "3 all is a draw, not a win")

func _machine() -> void:
	var lm := LanternMatch.new(null)
	var stay: bool = not lm.go(LanternMatch.S.RESULT) and lm.state == LanternMatch.S.IDLE
	ok(stay and lm.refused == 1, "IDLE -> RESULT refused")
	ok(lm.go(LanternMatch.S.PLAY) and not lm.go(LanternMatch.S.PLAY) and lm.refused == 2, "PLAY -> PLAY refused")

func _on_base() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 2:
		var k := _kin(["Pip", "Ash"][i], 10)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var off = await main._hb_home()
	ok(off.hlantern == null, "off: no glowcap ring on the farm")
	off.queue_free()
	await main.get_tree().process_frame
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	ok(home.hlantern != null, "on: the base has Lantern Match")
	if home.hlantern != null:
		var lm: LanternMatch = home.hlantern
		var at := Vector2(lm.ring.position.x, lm.ring.position.z)
		ok(lm.find(at) == {"kind": "lantern"} and lm.find(at + Vector2(30, 0)).is_empty(), "on: the ring offers a game")
		for k in home.kins:
			k.erase("indoors")
		lm.use()
		ok(home.panel_open == LanternMatch.PANEL and lm.state == LanternMatch.S.IDLE, "on: the ring opens its panel")
		lm._start(home.hrace.entrants().slice(0, 1))
		ok(lm.state == LanternMatch.S.PLAY and lm.buttons.size() == 12, "on: solo starts with 12 caps on the panel")
		var t := 0.0
		while lm.state == LanternMatch.S.PLAY and t < float(LanternMatch.rules()["time_s"]) + 10.0:
			lm.tick(0.1)
			t += 0.1
		var carded: bool = lm.state == LanternMatch.S.RESULT and is_instance_valid(lm.card)
		ok(carded, "on: the clock runs out to a card (%.1f s)" % t)
		lm.tick(float(LanternMatch.rules()["card_s"]) + 1.0)
		ok(lm.state == LanternMatch.S.IDLE, "on: the card goes and the ring is ready again")
		lm.use()
		lm._start(home.hrace.entrants().slice(0, 1))
		home._close_panel()
		lm.tick(0.1)
		ok(lm.state == LanternMatch.S.IDLE and home.hrace.entrants().size() == 2, "on: closing the panel calls it off")
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
