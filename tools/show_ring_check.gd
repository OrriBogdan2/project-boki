extends RefCounted
## --show-ring-check: the Show Ring (scripts/home/show_ring.gd, GARDEN_MODERN.md 4.2 game 3).
##   1. Look: a fully raised Boki (joy, clean, full lean, two part levels, an aura, a ribbon) scores 10;
##      a plain one scores exactly its joy and clean share
##   2. Trick: the trick follows the best stat; the score is the presses' points plus the stat's share
##   3. Bond: perfect calls give 10; with misses, more trust and loyalty give more; calls grade by timing
##   4. Judges: three tastes a week from the list, the same every time; a fitting Boki gets the bonus;
##      retired mentors sit on the bench first
##   5. A run: the same Boki and presses score the same twice, the run lasts about 2 minutes, its
##      score matches the static one, and the prizes are paid once
##   6. result look: three marks in turn, gone by 1.5 s, then a ribbon in the placing's colour that stays
##      until the Boki leaves the ring
##   7. on the base: no stage with base_mode off; with it on, a show runs to a result card
## Never touches the real save.

const DT := 1.0 / 30.0           # s per step
const LONG_LOW := 95.0           # s: a show with every press made runs at least this long
const LONG_HIGH := 135.0         # s: and at most this long
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("SHOW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_look()
	_trick()
	_bond()
	_judges()
	_run_once()
	_placing()
	await _on_base()
	print("SHOW DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(kname: String, joy: float, clean: float, trust: float, loyalty: float) -> Dictionary:
	var k := Save.new_kin("zapple", kname)
	Care.ensure(k)
	k["needs"]["joy"] = joy
	k["needs"]["clean"] = clean
	k["needs"]["energy"] = 90.0
	k["trust"] = trust
	k["traits"]["loyalty"] = loyalty
	k["muts"] = []
	k["lean"] = {}
	return k

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001

func _look() -> void:
	var full := _kin("Full", 100.0, 100.0, 50.0, 0.5)
	full["lean"] = {"grass": Evo.LEAN_FULL}
	full["muts"] = [{"id": "crest", "lv": 2, "aff": "grass"}]
	full["aura"] = "glowmoss_sprig"
	full["ribbons"] = {"dash": {"n": 1, "week": 3}}
	ok(_near(ShowRing.sum(ShowRing.look(full)), 10.0), "look: fully raised scores 10")
	var plain := _kin("Plain", 50.0, 25.0, 50.0, 0.5)
	ok(_near(ShowRing.sum(ShowRing.look(plain)), 1.0 + 0.5), "look: plain scores its joy and clean share only")
	plain["lean"] = {"water": Evo.LEAN_FULL * 0.5}
	ok(_near(ShowRing.look(plain)["lean"], 1.0), "look: half a lean is half the lean points")

func _trick() -> void:
	var k := _kin("Trick", 70.0, 70.0, 50.0, 0.5)
	k["stats"] = {"power": 5, "guard": 5, "speed": 30, "focus": 10}
	ok(ShowRing.best_stat(k) == "speed", "trick: picked by the best stat")
	ok(ShowRing.trick_of(k)["name"] == "Whirl Hop", "trick: the speed trick")
	var pts := ShowRing.trick(k, ["great", "good", "miss"])
	ok(_near(pts, 3.0 + 2.0 + 0.0 + 30 * 0.02), "trick: presses plus the stat share (%.2f)" % pts)
	k["stats"]["speed"] = 90
	ok(_near(ShowRing.trick(k, ["great", "great", "great"]), 10.0), "trick: three greats and a strong stat give 10")

func _bond() -> void:
	var shy := _kin("Shy", 70.0, 70.0, 0.0, 0.1)
	var close := _kin("Close", 70.0, 70.0, 90.0, 0.9)
	ok(_near(ShowRing.bond(shy, ["great", "great", "great"]), 10.0), "bond: perfect calls give 10")
	var misses := ["miss", "miss", "miss"]
	var shy_pts := ShowRing.bond(shy, misses)
	var close_pts := ShowRing.bond(close, misses)
	ok(close_pts > shy_pts, "bond: trust and loyalty shrink the pull (%.2f > %.2f)" % [close_pts, shy_pts])
	ok(ShowRing.bond(shy, ["good", "good", "good"]) > shy_pts, "bond: calling helps")
	ok(ShowRing.call_grade(0.1) == "great" and ShowRing.call_grade(-0.5) == "good"
			and ShowRing.call_grade(1.0) == "miss", "bond: calls grade by how close to the lure")

func _judges() -> void:
	var a := ShowRing.tastes(7)
	ok(a.size() == 3 and a == ShowRing.tastes(7), "judges: three tastes a week, the same each time")
	ok(a != ShowRing.tastes(8), "judges: next week's tastes differ")
	var all: Array = ShowRing.rules()["tastes"]
	var week := all.find(all.filter(func(t): return t["kind"] == "lean" and t["id"] == "grass")[0]) / 3
	var k := _kin("Green", 70.0, 70.0, 50.0, 0.5)
	var before := float(ShowRing.score(k, ["miss", "miss", "miss"], ["miss", "miss", "miss"], week)["total"])
	k["lean"] = {"grass": Evo.LEAN_FULL}
	var s := ShowRing.score(k, ["miss", "miss", "miss"], ["miss", "miss", "miss"], week)
	ok(s["fits"].has(true), "judges: a full Grass lean fits the Grass taste")
	ok(_near(float(s["total"]) - before, 2.0 + 1.0), "judges: the lean adds its look points and the taste bonus")
	var elder := _kin("Elder", 70.0, 70.0, 50.0, 0.5)
	elder["mentor"] = {}
	var bench := ShowRing.judges([k, elder])
	ok(bench.size() == 3 and bench[0] == "Elder", "judges: a retired mentor sits on the bench first")

## A run with scripted presses: the trick at its start, each call right on its lure.
func _show(a: Dictionary, b: Dictionary) -> ShowRing.Run:
	var r := ShowRing.Run.new([a, b], 0, 4)
	while not r.over():
		if r.can_trick() and r.t > 2.0 * (r.grades.size() + 1):
			r.press_trick(["great", "good", "great"][r.grades.size()])
		if r.phase == ShowRing.Run.Phase.BOND:
			for i in r.calls.size():
				if r.calls[i] == "" and r.t >= r.lure_t(i):
					r.call_out()
		r.step(DT)
	return r

func _run_once() -> void:
	var a := _kin("Pip", 90.0, 80.0, 60.0, 0.7)
	var b := _kin("Ash", 60.0, 50.0, 30.0, 0.4)
	a["stats"]["focus"] = 25
	b["stats"]["power"] = 20
	var r1 := _show(a, b)
	var r2 := _show(a, b)
	ok(r1.scores() == r2.scores() and r1.winner() == r2.winner(), "run: the same Boki and presses score the same")
	ok(r1.total_t >= LONG_LOW and r1.total_t <= LONG_HIGH, "run: about 2 minutes (%.1f s)" % r1.total_t)
	ok(r1.grades == ["great", "good", "great"] and r1.calls == ["great", "great", "great"], "run: presses recorded")
	var want := ShowRing.score(a, r1.grades, r1.calls, 4)
	ok(_near(r1.scores()[0]["total"], want["total"]), "run: the run's score is the static score")
	Save.d["gems"] = 0
	var res := ShowRing.settle(r1)
	var gems := int(Save.d["gems"])
	var bag := JSON.stringify(Save.d.get("items", {})) + JSON.stringify(Save.d["crops"])
	ok(not res.is_empty() and gems > 0, "settle: pays gems (%d)" % gems)
	ok(res["backed_won"] == (r1.winner() == 0), "settle: backing follows the winner")
	var again := ShowRing.settle(r1)
	var bag_after := JSON.stringify(Save.d.get("items", {})) + JSON.stringify(Save.d["crops"])
	ok(again.is_empty() and int(Save.d["gems"]) == gems and bag_after == bag, "settle: prizes paid once")

func _placing() -> void:
	var at: Dictionary = ShowRing.rules()["ribbon_at"]
	var M: Dictionary = ShowRing.rules()["marks"]
	ok(ShowRing.placing(true, 0.0) == "gold", "ribbon: the win is gold")
	ok(ShowRing.placing(false, float(at["silver"])) == "silver", "ribbon: a close second is silver")
	ok(ShowRing.placing(false, float(at["bronze"])) == "bronze", "ribbon: a lower second is bronze")
	ok(ShowRing.placing(false, 0.0) == "part", "ribbon: the rest took part")
	var cols := {}
	for id in M["colors"]:
		cols[M["colors"][id]] = true
	ok(cols.size() == 4, "ribbon: four colours, one per placing")
	ok(2.0 * float(M["gap_s"]) + float(M["life_s"]) <= 1.5, "marks: all gone within 1.5 s")
	var n := Node3D.new()
	main.add_child(n)
	var full := {"look": 10.0, "trick": 5.0, "bond": 0.0}
	var m := ShowMarks.new({"node": n}, Vector3.ZERO, full, "gold")
	ok(m.marks == [int(M["pips"]), roundi(M["pips"] * 0.5), 0], "marks: pips follow each round's points %s" % [m.marks])
	m.t = 0.9
	m._process(0.0)
	ok(not m.is_queued_for_deletion(), "ribbon: stays while the Boki is in the ring")
	n.position = Vector3(ShowMarks.LEAVE_M + 0.5, 0, 0)
	m._process(0.1)
	ok(m.is_queued_for_deletion(), "ribbon: gone once the Boki leaves the ring")
	n.queue_free()
	m.free()

func _on_base() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 3:
		var k := _kin(["Pip", "Ash", "Bo"][i], 70.0, 70.0, 50.0, 0.5)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var off = await main._hb_home()
	ok(off.hshow == null, "off: no stage on the farm")
	off.queue_free()
	await main.get_tree().process_frame
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	ok(home.hshow != null, "on: the base has the Show Ring")
	if home.hshow != null:
		var sr: ShowRing = home.hshow
		var at := Vector2(sr.stage.position.x, sr.stage.position.z)
		ok(sr.find(at) == {"kind": "show"}, "on: the stage offers a show")
		ok(sr.board.text.count("\n") == 3, "on: the board posts three judges' tastes")
		for k in home.kins:
			k.erase("indoors")
		sr.use()
		ok(sr.run != null and sr.pair.size() == 2, "on: a show starts with two Boki")
		var t := 0.0
		var beats := {}
		while sr.run != null and t < LONG_HIGH + 30.0:
			sr.tick(0.1)
			t += 0.1
			if sr.run != null:
				var n := sr.pair[sr.run.backed]["node"] as Node3D
				beats[String(n.get_meta("kact", "")) + "@" + str(sr.run.phase)] = true
		ok(beats.has("strut@" + str(ShowRing.Run.Phase.BOND)), "on: it struts on the walk-in")
		ok(beats.has("pose@" + str(ShowRing.Run.Phase.JUDGE)), "on: it holds a pose when the judges look")
		ok(not beats.has("pose@" + str(ShowRing.Run.Phase.LOOK)), "on: no pose before the judges' round")
		ok(sr.run == null and is_instance_valid(sr.card), "on: the show ends with a result card (%.1f s)" % t)
		var shown: bool = is_instance_valid(sr.marks) and sr.marks.get_parent() == home.root_ui
		ok(shown, "on: the result shows its marks and ribbon")
		var clips: Array = []
		for k in home.kins:
			clips.append(String((k["node"] as Node3D).get_meta("kact", "")))
		ok("hop" in clips and "bow" in clips, "on: the placing is read with a hop and a bow (%s)" % str(clips))
		for i in int(ceil(float(ShowRing.rules()["card_s"]) * 10.0)) + 2:
			sr.tick(0.1)
		ok(sr.acts.is_empty() and home.kins.all(func(k): return not (k["node"] as Node3D).has_meta("kact")),
				"on: and nobody keeps a show clip")
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
