extends RefCounted
## --kite-check: Kite Tow (scripts/home/base_kite.gd, briefs/design/GARDEN_MODERN.md 4.2 game 7).
##   1. seeded laps finish: a steering bot flies SEEDS laps, each ends with all twelve rings passed, and the
##      same seed flies the same rings to the same time
##   2. the course is flyable: at Guard 25 the bot (steering, flapping, taking vents) goes through every
##      ring at Speed 0 and at Speed 60
##   3. Speed shortens the time: on one seed, Speed 40 lands sooner than Speed 0, at lap / pace
##   4. a missed ring adds a second: a lap with no steering misses rings and its time is the clean lap's
##      plus miss_s for each
##   5. a settled lap: energy down, joy up, gems paid, more for a clean lap
##   7. flaps by Guard: 3, plus 1 per 25 Guard (base_kite.json); a flap climbs and the tow line brings the
##      kite back; no flaps left, no flap; six high rings, never the first
##   8. vents refund: passing over a vent with a flap spent gives it back, passing wide or with every flap
##      left does not; at Guard 0 the vents are what lets the bot clear more high rings
##   9. the cup rival comes from data: its stats are yours times each round's min_ratio (garden_prizes.json),
##      and its time is lap / its pace plus rival_misses seconds
##  10. a won lap pays the kite prize table (Zipseed, Windfloss), the first win of the day and garden XP
##      (garden_xp.json, triple on the first win); three wins run Sprout, Bloom, Crown to the Cup Ribbon;
##      a loss pays play XP and starts the cup over
##   6. on the base: no kite stand on a meadow island; on a ridge island a flight runs to a result card
## Never touches the real save.

const SEEDS := 8
const DT := 1.0 / 30.0           # s per step
const MAX_S := 300.0             # s: a lap still flying after this is stuck
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("KITE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_seeded()
	_speed()
	_misses()
	_settle()
	_flaps()
	_vents()
	_rival()
	_cup()
	await _on_base("meadow")
	await _on_base("ridge")
	await _on_zone()
	print("KITE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(speed: int, guard := 25) -> Dictionary:
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	Care.ensure(k)
	k["stats"]["speed"] = speed
	k["stats"]["guard"] = guard
	k["needs"]["energy"] = 90.0
	k["needs"]["joy"] = 50.0
	return k

## A lap on seed sd. steer: true steers and flaps for the next ring like a player would (and for a vent
## first when vents), false holds still.
func _lap(sd: int, speed: int, steer: bool, guard := 25, vents := true) -> BaseKite.Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var r := BaseKite.Run.new(_kin(speed, guard), rng)
	var R := BaseKite.rules()
	var peak_s := float(R["flap_v"]) / float(R["lift_g"])      # s from a flap to its top
	while not r.over() and r.t < MAX_S:
		var aim := 0.0
		if steer and r.next < r.rings.size():
			var to := float(r.rings[r.next])
			var v := _next_vent(r)
			var want_v := vents and r.flaps < r.flaps_max and not v.is_empty()
			if want_v and float(v["s"]) < r.ring_at(r.next):
				to = float(v["off"])
			aim = clampf((to - r.off) * 3.0, -1.0, 1.0)
			var ahead := (r.ring_at(r.next) - r.s) / r.speed
			var low := r.lift < float(R["high_lift"]) * 0.5 and r.climb <= 0.0
			if r.high[r.next] and low and ahead <= peak_s:
				r.flap()
		r.step(DT, aim)
	return r

func _next_vent(r: BaseKite.Run) -> Dictionary:
	for v in r.vents:
		if not v["used"]:
			return v
	return {}

func _seeded() -> void:
	var finished := 0
	for sd in SEEDS:
		var r := _lap(1000 + sd, 20, true)
		if r.over() and r.next == r.rings.size() and r.hits + r.misses == 12:
			finished += 1
	ok(finished == SEEDS, "seeded laps finish with all twelve rings passed: %d of %d" % [finished, SEEDS])
	var a := _lap(77, 20, true)
	var b := _lap(77, 20, true)
	ok(a.rings == b.rings and is_equal_approx(a.time(), b.time()),
			"one seed flies the same rings to the same time (%.2f s, %.2f s)" % [a.time(), b.time()])
	var c := _lap(78, 20, true)
	ok(a.rings != c.rings, "another seed lays other rings")

func _speed() -> void:
	for sp in [0, 60]:
		var clean := 0
		for sd in SEEDS:
			if _lap(2000 + sd, sp, true).misses == 0:
				clean += 1
		ok(clean == SEEDS, "Speed %d: the bot goes through every ring on %d of %d seeds" % [sp, clean, SEEDS])
	var slow := _lap(5, 0, true)
	var fast := _lap(5, 40, true)
	ok(fast.time() < slow.time(), "Speed 40 lands sooner than Speed 0: %.2f s < %.2f s" % [fast.time(), slow.time()])
	var lap := TAU * float(BaseKite.rules()["loop_r"])
	var pace := BaseKite.pace(_kin(0))
	ok(is_equal_approx(slow.t, lap / pace),
			"a lap flies lap / pace: %.2f s for %.1f m at %.2f m/s" % [slow.t, lap, pace])

func _misses() -> void:
	var clean := _lap(9, 20, true)
	var still := _lap(9, 20, false)
	var each := float(BaseKite.rules()["miss_s"])
	ok(clean.misses == 0 and still.misses > 0,
			"no steering misses rings: %d of 12 (steered: %d)" % [still.misses, clean.misses])
	ok(is_equal_approx(still.time(), clean.time() + still.misses * each),
			"each miss adds %.0f s: %.2f s vs clean %.2f s with %d misses"
			% [each, still.time(), clean.time(), still.misses])

func _settle() -> void:
	var R := BaseKite.rules()
	for steer in [true, false]:
		var rec := _kin(20)
		Save.d["gems"] = 0
		var res := BaseKite.settle(_lap(11, 20, steer), rec, BaseKite.rival(rec))
		var gems := int(R["gems_clean"]) if steer else int(R["gems"])
		ok(Care.need(rec, "energy") < 90.0 and Care.need(rec, "joy") > 50.0 and int(Save.d["gems"]) == gems
				and res["gems"] == gems, "settled %s lap: energy %.0f, joy %.0f, +%d gems"
				% ["clean" if steer else "missed", Care.need(rec, "energy"), Care.need(rec, "joy"), res["gems"]])

func _flaps() -> void:
	var R := BaseKite.rules()
	var want := {0: 3, 24: 3, 25: 4, 60: 5, 100: 7}
	var got := {}
	for g in want:
		got[g] = BaseKite.flaps(_kin(0, g))
	ok(got == want and int(R["flaps"]) == 3 and int(R["guard_per_flap"]) == 25,
			"flaps by Guard (3, +1 per 25): %s" % str(got))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var r := BaseKite.Run.new(_kin(0, 50), rng)
	ok(r.flaps == 5, "a Guard 50 lap starts with 5 flaps: %d" % r.flaps)
	var top := 0.0
	r.flap()
	for i in 90:
		r.step(DT, 0.0)
		top = maxf(top, r.lift)
	ok(r.flaps == 4 and top > float(R["high_lift"]) and r.lift == 0.0,
			"a flap climbs %.2f m (high rings %.2f m up) and the tow line brings it back to 0" % [top, R["high_lift"]])
	while r.flaps > 0:
		r.flap()
	ok(not r.flap(), "no flaps left: Space does nothing")
	var highs := 0
	var first_high := false
	for sd in SEEDS:
		var c := _lap(3000 + sd, 0, false)
		highs += c.high.count(true)
		first_high = first_high or c.high[0]
	ok(highs == SEEDS * int(R["high"]) and not first_high,
			"%d high rings a lap, never the first (%d over %d seeds)" % [R["high"], highs, SEEDS])

func _vents() -> void:
	var R := BaseKite.rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var r := BaseKite.Run.new(_kin(0, 0), rng)
	ok(r.vents.size() == int(R["vents"]), "%d vents on the loop" % r.vents.size())
	var v: Dictionary = r.vents[0]
	r.s = float(v["s"]) - 0.01
	r.off = float(v["off"])
	r.step(DT, 0.0)
	ok(r.flaps == 3 and r.refunds == 0, "over a vent with every flap left: nothing (%d)" % r.flaps)
	var w: Dictionary = r.vents[1]
	r.flap()
	r.s = float(w["s"]) - 0.01
	r.off = float(w["off"])
	r.step(DT, 0.0)
	ok(r.flaps == 3 and r.refunds == 1, "over a vent with a flap spent: it comes back (%d)" % r.flaps)
	var wide := BaseKite.Run.new(_kin(0, 0), rng)
	var u: Dictionary = wide.vents[0]
	wide.flap()
	wide.s = float(u["s"]) - 0.01
	wide.off = float(u["off"]) + float(R["vent_r"]) + 0.3
	wide.step(DT, 0.0)
	ok(wide.flaps == 2 and wide.refunds == 0, "passing wide of a vent: no flap back (%d)" % wide.flaps)
	var with_v := 0
	var without := 0
	var refunds := 0
	for sd in SEEDS:
		var a := _lap(4000 + sd, 20, true, 0, true)
		var b := _lap(4000 + sd, 20, true, 0, false)
		with_v += a.hits
		without += b.hits
		refunds += a.refunds
	ok(refunds == SEEDS * int(R["vents"]) and with_v > without,
			"Guard 0: taking the vents gives %d flaps back and %d rings vs %d without" % [refunds, with_v, without])

func _rival() -> void:
	var R := BaseKite.rules()
	var rounds: Array = GardenPrizes.rules()["cup"]["rounds"]
	var rec := _kin(37, 13)
	rec["stats"]["power"] = 9
	Save.d["cups"] = {}
	var good := 0
	for i in rounds.size():
		Save.d["cups"] = {"kite": {String(rec["uid"]): i}}
		var foe := BaseKite.rival(rec)
		var ratio := float(rounds[i]["min_ratio"])
		var sp := int(foe["stats"]["speed"]) == ceili(37.0 * ratio)
		var match_data := sp and int(foe["stats"]["guard"]) == ceili(13.0 * ratio)
		var strong := float(GardenPrizes.strength(foe)) >= ratio * float(GardenPrizes.strength(rec))
		if match_data and strong and foe["uid"] != rec["uid"]:
			good += 1
	ok(good == rounds.size(), "the rival is your stats x min_ratio for each of %d cup rounds" % rounds.size())
	var lap := TAU * float(R["loop_r"])
	var foe := BaseKite.rival(rec)
	var par := lap / BaseKite.pace(foe) + float(R["rival_misses"]) * float(R["miss_s"])
	ok(is_equal_approx(BaseKite.rival_time(foe, lap), par),
			"the rival's time: lap / its pace + %d misses (%.1f s)" % [R["rival_misses"], par])
	Save.d["cups"] = {}

## Laps settled at a fixed time against the rival rival() picks: prizes, first win, XP, the cup.
func _cup() -> void:
	var XP := GardenXp.rules()
	var now := 1000.0 * 86400.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var table: Array = GardenPrizes.game("kite")["table"]
	var ids := table.map(func(e): return e["id"])
	ok(ids == ["zipseed", "windfloss"] and GardenItems.item_name("windfloss") == "Windfloss",
			"the kite prize table is Zipseed and Windfloss: %s" % str(ids))
	Save.d = Save.fresh()
	Save.d["items"] = {}
	var rec := _kin(30, 25)
	var steps: Array = []
	var xps: Array = []
	var first := false
	for i in 3:
		var res := BaseKite.settle(_lap(6, 30, true), rec, BaseKite.rival(rec), now + i, rng)
		steps.append(res["prize"]["round"])
		xps.append(res["xp"])
		first = first or (i == 0 and res["prize"]["first"])
	var win := int(XP["game_win"])
	ok(steps == ["Sprout", "Bloom", "Crown"] and GardenPrizes.ribbon_count(rec, "kite") == 1,
			"three won laps: %s and the Kite Tow Cup Ribbon" % str(steps))
	ok(first and xps == [win * int(XP["first_win_mult"]), win, win],
			"XP: first win of the day x%d, then %d a win: %s" % [XP["first_win_mult"], win, str(xps)])
	var bag: Dictionary = Save.d["items"]
	ok(int(bag.get("zipseed", 0)) >= 1 and int(bag.get("galeribbon", 0)) == 1,
			"prizes banked: first-win Zipseed and the Galeribbon cup prize %s" % str(bag))
	var next_week := now + 8.0 * 86400.0
	GardenPrizes.settle("kite", rec, BaseKite.rival(rec), true, next_week, rng)
	var lost := BaseKite.settle(_lap(6, 30, false), rec, BaseKite.rival(rec), next_week + 1.0, rng)
	ok(not lost["won"] and lost["xp"] == int(XP["game"]) and lost["prize"]["reset"],
			"a lost lap: %d play XP and the cup starts over" % lost["xp"])
	Save.d = Save.fresh()

## Three Boki on a stock farm (a Training post) whose island has the given theme.
func _on_base(theme: String) -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 3:
		var k := _kin(10)
		k["name"] = ["Pip", "Ash", "Bo"][i]
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	d["layout"]["theme"] = theme
	Save.d = d
	HomeLayout.ensure(Save.d)
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	var kt: BaseKite = home.hkite
	if theme != "ridge":
		ok(kt != null and kt.stand == null, "%s: no kite stand off the ridge" % theme)
	else:
		ok(kt != null and is_instance_valid(kt.stand), "ridge: the kite stand is up")
		if kt != null and is_instance_valid(kt.stand):
			var at := Vector2(kt.stand.position.x, kt.stand.position.z)
			ok(kt.find(at) == {"kind": "kite"}, "ridge: the stand offers a flight")
			for k in home.kins:
				k.erase("indoors")
			kt.use()
			ok(kt.flying() and kt.hoops.size() == 12 and kt.flier["rec"] == Save.active_kin(),
					"ridge: your partner takes off with twelve rings up")
			var t := 0.0
			while kt.flying() and t < MAX_S:
				kt.tick(0.1)
				t += 0.1
			ok(not kt.flying() and is_instance_valid(kt.card) and kt.hoops.is_empty(),
					"ridge: the lap lands on a result card (%.1f s)" % t)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame

## Kitewind Ridge as a zone (ZoneLayout builds it from garden_zones.json): its Training post carries the stand.
func _on_zone() -> void:
	Content.rules("farm_build")["base_mode"] = true
	var d := Save.fresh()
	d["roster"].append(_kin(10))
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	d["zones"]["ridge"] = {"open": true}
	Save.d = d
	HomeLayout.ensure(d)
	Game.goto("home", {"zone": "ridge"})
	var home = null
	var t := 0.0
	while t < 30.0 and home == null:
		await main.get_tree().process_frame
		t += main.get_process_delta_time()
		var cur = Game.main.current
		if is_instance_valid(cur) and cur.get("hkite") != null and cur.get("root_ui") != null \
				and not Game.main.fade.covered:
			home = cur
	var kt: BaseKite = home.hkite if home != null else null
	ok(kt != null and is_instance_valid(kt.stand), "ridge zone: the kite stand is up")
	if kt != null and is_instance_valid(kt.stand):
		var at := Vector2(kt.stand.position.x, kt.stand.position.z)
		ok(kt.find(at) == {"kind": "kite"}, "ridge zone: the stand offers a flight")
		for k in home.kins:
			k.erase("indoors")
			k["busy"] = false
		kt.use()
		var ft := 0.0
		while kt.flying() and ft < MAX_S:
			kt.tick(0.1)
			ft += 0.1
		ok(not kt.flying() and is_instance_valid(kt.card), "ridge zone: the lap lands on a result card (%.1f s)" % ft)
	Content.rules("farm_build")["base_mode"] = false
