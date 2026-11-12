extends RefCounted
## --tumble-check: Tumble (scripts/home/base_tumble.gd, briefs/design/GARDEN_MODERN.md 4.2 game 1).
##   1. the rules: Rush beats Dodge beats Brace beats Rush, one step or two on a 20+ lead, a clash moves the
##      lower push half a step, the 10% type edge and the 10% follow bonus, an untouched pick goes with the want
##   2. the read: the higher Focus sees the honest tell about 7 in 10, the other about 5 in 10
##   3. 200 seeded bouts with a simulated player (reads the tell, follows its Boki, or picks at random):
##      60 to 75 s on average; 30 more points of Power, Guard, Speed or Focus each end bouts further forward
##      (the push is what stats size, and a mean position is far less noisy than a win share) and win no fewer
##   4. no dominant move: always Rush, always Brace and always Dodge win within a few points of each other's
##      share of exchanges (about 900 each, so the test is not noise) and none wins most bouts
##   5. a settled bout: joy, trust (plus what following earned) and memories for your Boki, a visitor untouched
##   6. on the base: a ring by the stump; one rested Boki refuses, two start a bout that ends in a card
## Never touches the real save.

const BOUTS := 200
const SEED := 20261110
const DT := 1.0 / 30.0           # s per step
const LEN_LOW := 60.0            # s, the shortest average bout
const LEN_HIGH := 75.0           # s, the longest average bout
const BOOST := 30                # stat points added for the "every stat matters" test
const STAT_PUSH := 0.25          # steps further forward those points must end a bout, on average
const MOVE_SPREAD := 0.08        # most the fixed-move strategies' exchange win shares may differ by
const MOVE_MAX := 0.6            # no fixed move may win more than this share
const TELL_ROLLS := 4000         # tells sampled for the honesty test
const TELL_SLACK := 0.03         # how far the sampled honesty may sit from the rule
const PICK_S := [0.8, 2.8]       # s the simulated player takes to pick, after the tell
const PRESS_S := [0.4, 2.0]      # s it takes to press, after the charge starts
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TUMBLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_rules()
	_tells()
	_bouts()
	_moves()
	_settle()
	await _on_base()
	print("TUMBLE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String, stats: Array) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	for i in 4:
		k["stats"][["power", "guard", "speed", "focus"][i]] = int(stats[i])
	k["needs"]["joy"] = 50.0
	k["needs"]["energy"] = 90.0
	k["trust"] = 50.0
	return k

func _by_theme() -> Dictionary:
	var out := {}
	for id in Data.KIN:
		out[String(Data.KIN[id].get("theme", ""))] = id
	return out

## One exchange with fixed moves and presses on a fresh run; returns the run after it resolved.
func _exchange(a: Dictionary, b: Dictionary, mine: String, theirs: String, want := "") -> BaseTumble.Run:
	var r := BaseTumble.Run.new([a, b], RandomNumberGenerator.new())
	r.R = r.R.duplicate(true)
	r.R["rival_press"] = {"great": 0.0, "good": 0.0}
	r.step(float(r.R["intro_s"]) + DT)
	r.want = want if want != "" else BaseTumble.counter(mine)
	r.plan = theirs
	r.choose(mine)
	r.step(float(r.R["tell_s"]))
	r.press("miss")
	r.step(float(r.R["impact_s"]))
	return r

func _rules() -> void:
	var th := _by_theme()
	var a := _kin(th["stone"], "A", [10, 10, 10, 10])
	var b := _kin(th["stone"], "B", [10, 10, 10, 10])
	var cycle := ["rush", "dodge", "brace"]
	var fine := true
	for i in 3:
		fine = fine and _exchange(a, b, cycle[i], cycle[(i + 1) % 3]).last["winner"] == 0
		fine = fine and _exchange(a, b, cycle[(i + 1) % 3], cycle[i]).last["winner"] == 1
	ok(fine, "Rush beats Dodge, Dodge beats Brace, Brace beats Rush, both ways round")
	var r := _exchange(a, b, "rush", "dodge")
	ok(r.pos == 1.0 and r.state == "push", "a win on a level stat pushes one step (%.1f)" % r.pos)
	a["stats"]["power"] = 30
	r = _exchange(a, b, "rush", "dodge")
	ok(r.pos == 2.0, "a win with 20 more Power pushes two steps (%.1f)" % r.pos)
	r = _exchange(a, b, "rush", "rush")
	ok(r.pos == 0.5 and r.last["winner"] == 0, "a Rush clash moves the lower Power half a step (%.1f)" % r.pos)
	a["stats"]["power"] = 10
	r = _exchange(a, b, "brace", "brace")
	ok(r.pos == 0.0 and r.last["winner"] == -1, "a clash on a dead level moves no one")
	var c := _kin(th["ember"], "C", [10, 10, 10, 10])
	var d := _kin(th["frost"], "D", [10, 10, 10, 10])
	r = _exchange(c, d, "rush", "dodge")
	var p := r.push(0, "power", "miss") / (float(r.R["base"]) + 10.0)
	ok(absf(p - 1.1) < 0.001, "the type edge is 10%% of push (x%.3f)" % p)
	r = _exchange(a, b, "rush", "dodge", "rush")
	var f := r.push(0, "power", "miss") / (float(r.R["base"]) + 10.0)
	ok(absf(f - 1.1) < 0.001 and r.follows == 1, "following the want is 10%% more push (x%.3f)" % f)
	var idle := BaseTumble.Run.new([a, b], RandomNumberGenerator.new())
	var limit := float(idle.R["intro_s"]) + float(idle.R["tell_s"]) + float(idle.R["pick_s"]) + DT * 2.0
	var tt := 0.0
	while idle.state != "resolve" and tt < limit:
		idle.step(DT)
		tt += DT
	ok(idle.state == "resolve" and idle.pick == idle.want, "no pick in 3 s goes with what your Boki wants")

func _tells() -> void:
	var sharp := _kin("zapple", "S", [10, 10, 10, 60])
	var dull := _kin("zapple", "D", [10, 10, 10, 20])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var r := BaseTumble.Run.new([sharp, dull], rng)
	var share := [0.0, 0.0]
	for viewer in 2:
		var right := 0
		for n in TELL_ROLLS:
			if r.shown("rush", viewer) == "rush":
				right += 1
		share[viewer] = float(right) / TELL_ROLLS
	var h: Array = r.R["honest"]
	ok(absf(share[0] - float(h[0])) < TELL_SLACK and absf(share[1] - float(h[1])) < TELL_SLACK,
			"the higher Focus sees the honest tell %.0f%%, the other %.0f%%" % [share[0] * 100.0, share[1] * 100.0])

## Plays a whole bout. style: "mixed" (the simulated player), or a move to always pick.
func _bout(a: Dictionary, b: Dictionary, s: int, style: String) -> BaseTumble.Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var me := RandomNumberGenerator.new()
	me.seed = s + 1
	var r := BaseTumble.Run.new([a, b], rng)
	var wait := 0.0
	var at := ""
	while not r.over():
		if r.state != at:
			at = r.state
			wait = me.randf_range(PICK_S[0], PICK_S[1]) if at == "pick" else me.randf_range(PRESS_S[0], PRESS_S[1])
		wait -= DT
		if r.state == "pick" and wait <= 0.0:
			r.choose(_style_pick(r, style, me))
		elif r.state == "resolve" and wait <= 0.0 and r.grade == "":
			r.press(_grade(me.randf()))
		r.step(DT)
	return r

## The simulated press: a quarter great, nearly half good, the rest missed.
func _grade(roll: float) -> String:
	if roll < 0.25:
		return "great"
	return "good" if roll < 0.7 else "miss"

func _style_pick(r: BaseTumble.Run, style: String, me: RandomNumberGenerator) -> String:
	if style != "mixed":
		return style
	var roll := me.randf()
	if roll < 0.6:
		return BaseTumble.counter(r.tell)
	if roll < 0.85:
		return r.want
	return ["rush", "brace", "dodge"][me.randi() % 3]

## The seeded field: random species and stats on both sides.
func _field() -> Array:
	var kinds: Array = Data.common_kin()
	var out: Array = []
	seed(SEED)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for n in BOUTS:
		var pair: Array = []
		for side in 2:
			var st: Array = []
			for i in 4:
				st.append(rng.randi_range(0, 60))
			pair.append(_kin(kinds[rng.randi() % kinds.size()], "AB"[side], st))
		out.append(pair)
	return out

func _share(field: Array, style: String, boost := "") -> Dictionary:
	var wins := 0
	var secs := 0.0
	var ex: Array = [0, 0]
	var pos := 0.0
	for n in field.size():
		var a: Dictionary = field[n][0].duplicate(true)
		if boost != "":
			a["stats"][boost] = int(a["stats"][boost]) + BOOST
		var r := _bout(a, field[n][1], SEED + n * 7, style)
		secs += r.t
		pos += r.pos
		ex[0] += r.wins[0]
		ex[1] += r.wins[1]
		if r.winner() == 0:
			wins += 1
	return {"share": float(wins) / field.size(), "secs": secs / field.size(), "ex": float(ex[0]) / (ex[0] + ex[1]),
			"pos": pos / field.size()}

func _bouts() -> void:
	var field := _field()
	var base := _share(field, "mixed")
	ok(base["secs"] >= LEN_LOW and base["secs"] <= LEN_HIGH, "%d bouts last %.1f s on average (needs %d to %d)"
			% [BOUTS, base["secs"], LEN_LOW, LEN_HIGH])
	for s in ["power", "guard", "speed", "focus"]:
		var up := _share(field, "mixed", s)
		var gain := float(up["pos"]) - float(base["pos"])
		ok(gain >= STAT_PUSH and up["share"] >= base["share"],
				"+%d %s ends %.2f steps further forward (needs %.2f), wins %.0f%% of bouts (from %.0f%%)"
				% [BOOST, s, gain, STAT_PUSH, up["share"] * 100.0, base["share"] * 100.0])

func _moves() -> void:
	var field := _field()
	var ex: Array = []
	var bouts: Array = []
	for m in ["rush", "brace", "dodge"]:
		var res := _share(field, m)
		ex.append(float(res["ex"]))
		bouts.append(float(res["share"]))
	var spread: float = ex.max() - ex.min()
	var what := "no dominant move: always Rush, Brace, Dodge win %.0f, %.0f, %.0f%% of exchanges (spread under %.0f)"
	what += " and %.0f, %.0f, %.0f%% of bouts (none over %.0f)"
	ok(spread <= MOVE_SPREAD and bouts.max() <= MOVE_MAX, what % [ex[0] * 100.0, ex[1] * 100.0, ex[2] * 100.0,
			MOVE_SPREAD * 100.0, bouts[0] * 100.0, bouts[1] * 100.0, bouts[2] * 100.0, MOVE_MAX * 100.0])

func _settle() -> void:
	Save.d = Save.fresh()
	var a := _kin("zapple", "Pip", [10, 10, 10, 10])
	var b := _kin("cindle", "Ash", [10, 10, 10, 10])
	var r := BaseTumble.Run.new([a, b], RandomNumberGenerator.new())
	r.pos = 3.0
	r.follows = 2
	var gems := int(Save.d["gems"])
	var res := BaseTumble.settle(r)
	var want_trust := 50.0 + float(r.R["win_trust"]) + 2.0 * float(r.R["follow_trust"])
	ok(res["win"] == a and absf(float(a["trust"]) - want_trust) < 0.001,
			"settle: the winner gains trust, plus following")
	ok(float(a["needs"]["joy"]) > 50.0 and float(b["needs"]["joy"]) < 50.0, "settle: the winner beams, the loser sulks")
	ok(String(a["memory"][-1]["text"]).contains("Ash") and String(b["memory"][-1]["text"]).contains("Pip"),
			"settle: both remember it")
	ok(int(Save.d["gems"]) > gems and res["backed_won"], "settle: gems for your win")
	var v := _kin("cindle", "Visitor", [10, 10, 10, 10])
	var before := v.duplicate(true)
	r = BaseTumble.Run.new([a, v], RandomNumberGenerator.new())
	r.visitor = true
	r.pos = -3.0
	BaseTumble.settle(r)
	ok(v == before, "settle: a visitor's record is left alone")

func _on_base() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	var k := _kin("zapple", "Pip", [10, 10, 10, 10])
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["roster"].append(_kin("cindle", "Ash", [10, 10, 10, 10]))
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var off = await main._hb_home()
	ok(off.htumble == null, "off: no Tumble ring on the farm")
	off.queue_free()
	await main.get_tree().process_frame
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	ok(home.htumble != null and is_instance_valid(home.htumble.ring), "on: the base has a Tumble ring")
	if home.htumble != null and is_instance_valid(home.htumble.ring):
		var tb: BaseTumble = home.htumble
		var at := Vector2(tb.ring.position.x, tb.ring.position.z)
		ok(tb.find(at) == {"kind": "tumble"}, "on: the ring offers a Tumble")
		for e in home.kins:
			e.erase("indoors")
		# one rested Boki out: refuses cleanly, no bout, nobody left busy
		var lone: Dictionary = home.kins[1]
		lone["indoors"] = true
		tb.use()
		ok(tb.run == null and tb.pair.is_empty(), "on: one rested Boki refuses (needs two), no bout")
		ok(not home.kins[0].get("busy", false), "on: the refused Tumble leaves your Boki free")
		# no ring built: use() and find() stay quiet instead of touching a nil ring
		var kept: MeshInstance3D = tb.ring
		tb.ring = null
		tb.use()
		ok(tb.run == null and tb.find(at) == {}, "no ring: use() and find() do nothing, no script error")
		tb.ring = kept
		lone.erase("indoors")
		tb.use()
		ok(tb.run != null and not tb.run.visitor and tb.pair.size() == 2, "on: two rested Boki start a bout")
		var t := 0.0
		while tb.run != null and tb.run.state != "resolve" and t < 200.0:
			tb.tick(0.1)
			t += 0.1
		var moves: Dictionary = BaseTumble.rules()["moves"]
		var clips: Array = [String(moves[tb.run.pick]["clip"]), String(moves[tb.run.plan]["clip"])]
		var shown: Array = tb.pair.map(func(k: Dictionary) -> String: return String(k["node"].get_meta("kact", "")))
		ok(shown == clips, "on: in the charge each Boki plays its move's clip %s" % str(shown))
		while tb.run != null and t < 200.0:
			tb.tick(0.1)
			t += 0.1
		await main.get_tree().process_frame
		ok(tb.run == null and is_instance_valid(tb.card), "on: the bout ends in a result card (%.1f s)" % t)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
