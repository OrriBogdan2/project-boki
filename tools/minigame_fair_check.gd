extends RefCounted
## --minigame-fair-check: every Boki-vs-Boki minigame in content/rules/minigames.json (The Dash, Stump Shove,
## Seek, Spark Volley) played RUNS times headless with seeded Boki, no press from you, and a win-rate table:
##   1. matched pair (same trained stat on both): side 0 wins 40 to 60%, so neither seat is favoured
##   2. a clearly raised Boki (+10 and +20 points of the stat the game reads) against an unraised one wins
##      clearly more than 50%, and +20 wins more than +10 (raising matters, nothing is a certainty: under 98%)
##   3. the seat does not matter when the raised Boki sits on side 1 (its win share is within 12 points)
## Prints "FAIR <game> ..." rows. Never touches the real save.

const RUNS := 200
const DT := 1.0 / 30.0
const SEAT_TOL := 0.12  # the raised Boki's win share may differ by this between seats
const STAT := {"race": ["speed"], "shove": ["power"], "seek": ["focus"], "volley": ["speed", "focus"]}

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("FAIR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	for game in ["race", "shove", "seek", "volley"]:
		_game(game)
	print("FAIR DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _kin(game: String, points: int, species := "zapple") -> Dictionary:
	var k := Save.new_kin(species, "K")
	k["level"] = 5
	Care.ensure(k)
	for s in STAT[game]:
		k["stats"][s] = points
	k["traits"]["curiosity"] = 0.5
	k["needs"]["joy"] = 60.0
	k["needs"]["energy"] = 90.0
	k["trust"] = 50.0
	return k


## One played game; returns the winning side (0 or 1).
func _play(game: String, a: Dictionary, b: Dictionary, seed_v: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	match game:
		"race":
			var r := BaseRace.Run.new([a, b], 0, rng)
			while not r.over():
				r.step(DT)
			return int(r.order()[0])
		"shove":
			var r := BaseShove.Run.new([a, b], 0, rng)
			while not r.over():
				r.step(DT)
			return r.winner()
		"seek":
			var at := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(6.0, 14.0)
			var h := BaseSeek.Hunt.new([a, b], [Vector2.ZERO, Vector2.ZERO], at, false, rng)
			while not h.over():
				h.step(DT)
			return h.winner()
		_:
			var r := BaseVolley.Run.new([a, b], 0, rng)
			while not r.over():
				r.step(DT)
			return r.winner()


## Share of RUNS won by the pts_hi Boki sitting on side hi_seat.
func _share(game: String, hi: int, lo: int, hi_seat: int) -> float:
	var wins := 0
	for n in RUNS:
		var hi_k := _kin(game, hi)
		var lo_k := _kin(game, lo)
		var pair: Array = [hi_k, lo_k] if hi_seat == 0 else [lo_k, hi_k]
		if _play(game, pair[0], pair[1], 1000 + n) == hi_seat:
			wins += 1
	return float(wins) / RUNS


func _game(game: String) -> void:
	var matched := _share(game, 10, 10, 0)
	var p10 := _share(game, 10, 0, 0)
	var p20 := _share(game, 20, 0, 0)
	var p20_seat1 := _share(game, 20, 0, 1)
	var row := "FAIR TABLE %-6s matched(side0)=%3.0f%%  +10 raised=%3.0f%%  +20 raised=%3.0f%%"
	row += "  +20 raised on side1=%3.0f%%  (%d runs each)"
	print(row % [game, matched * 100, p10 * 100, p20 * 100, p20_seat1 * 100, RUNS])
	ok(matched >= 0.40 and matched <= 0.60, "%s: matched pair, side 0 wins %.0f%% (40 to 60)" % [game, matched * 100])
	ok(p10 > 0.55, "%s: +10 raised points win clearly more than half (%.0f%%)" % [game, p10 * 100])
	ok(
		p20 > p10 and p20 < 0.98,
		"%s: +20 wins more than +10, not a certainty (%.0f%% > %.0f%%, under 98)" % [game, p20 * 100, p10 * 100]
	)
	ok(
		absf(p20 - p20_seat1) <= SEAT_TOL,
		(
			"%s: the raised Boki's seat moves its share under %.0f points (%+.0f)"
			% [game, SEAT_TOL * 100, (p20_seat1 - p20) * 100]
		)
	)
