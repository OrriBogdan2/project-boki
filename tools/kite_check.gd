extends RefCounted
## --kite-check: Kite Tow part 1 (scripts/home/base_kite.gd, briefs/design/GARDEN_MODERN.md 4.2 game 7).
##   1. seeded laps finish: a steering bot flies SEEDS laps, each ends with all twelve rings passed, and the
##      same seed flies the same rings to the same time
##   2. the course is flyable: the bot goes through every ring at Speed 0 and at Speed 60
##   3. Speed shortens the time: on one seed, Speed 40 lands sooner than Speed 0, at lap / pace
##   4. a missed ring adds a second: a lap with no steering misses rings and its time is the clean lap's
##      plus miss_s for each
##   5. a settled lap: energy down, joy up, gems paid, more for a clean lap
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
	await _on_base("meadow")
	await _on_base("ridge")
	await _on_zone()
	print("KITE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(speed: int) -> Dictionary:
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	Care.ensure(k)
	k["stats"]["speed"] = speed
	k["needs"]["energy"] = 90.0
	k["needs"]["joy"] = 50.0
	return k

## A lap on seed sd. steer: true steers for the next ring like a player would, false holds still.
func _lap(sd: int, speed: int, steer: bool) -> BaseKite.Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var r := BaseKite.Run.new(_kin(speed), rng)
	while not r.over() and r.t < MAX_S:
		var aim := 0.0
		if steer and r.next < r.rings.size():
			var gap := float(r.rings[r.next]) - r.off
			aim = clampf(gap * 3.0, -1.0, 1.0)
		r.step(DT, aim)
	return r

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
		var res := BaseKite.settle(_lap(11, 20, steer), rec)
		var gems := int(R["gems_clean"]) if steer else int(R["gems"])
		ok(Care.need(rec, "energy") < 90.0 and Care.need(rec, "joy") > 50.0 and int(Save.d["gems"]) == gems
				and res["gems"] == gems, "settled %s lap: energy %.0f, joy %.0f, +%d gems"
				% ["clean" if steer else "missed", Care.need(rec, "energy"), Care.need(rec, "joy"), res["gems"]])

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
