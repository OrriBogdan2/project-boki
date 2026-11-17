extends RefCounted
## --pet-react-check: a pat answers by personality (scripts/home/pet_react.gd, content/rules/pet_react.json).
## One Boki of each kind on a stub screen: playful rolls and wants a game, shy flinches then leans in on a
## second pat, proud allows one pat and walks off, sleepy purrs and naps. Each shows its mood icon and pays
## joy and trust, spamming pays no more than the daily cap, the next farm day pays again, a visit pays nothing.

class StubFx extends RefCounted:
	func burst(_at: Vector3, _col: Color, _n: int, _speed: float) -> void:
		pass

class Stub extends RefCounted:
	var ppos := Vector3.ZERO
	var verbs := HomeVerbs.new()
	var fx := StubFx.new()
	var toasts := 0
	func _toast(_txt: String) -> void:
		toasts += 1

const TRAITS := {
	"playful": {"bravery": 0.5, "temper": 0.3, "curiosity": 0.8},
	"shy": {"bravery": 0.1, "temper": 0.3, "curiosity": 0.8},
	"proud": {"bravery": 0.5, "temper": 0.9, "curiosity": 0.8},
	"sleepy": {"bravery": 0.5, "temper": 0.3, "curiosity": 0.1},
}
const ICONS := {"playful": "♪", "proud": "★", "sleepy": "z"}

var bad := 0
var scene: Node

func ok(cond: bool, what: String) -> void:
	print("PETREACT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _boki(kd: String) -> Dictionary:
	var rec := Save.new_kin("cindle", kd)
	rec["traits"] = (TRAITS[kd] as Dictionary).duplicate()
	rec["likes"]["play"] = "fetch"
	Care.ensure(rec)
	rec["needs"]["joy"] = 10.0
	rec["trust"] = 10.0
	var n := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	n.add_child(body)
	scene.add_child(n)
	return {"rec": rec, "node": n, "pos": Vector3(3, 0, 0), "goal": Vector3.INF, "t": 0.0}

func _pat(s: Stub, k: Dictionary) -> Dictionary:
	return PetReact.pet(s, k)

func _icon(k: Dictionary) -> String:
	var lbl := (k["node"] as Node3D).get_node_or_null("PetIcon") as Label3D
	return lbl.text if lbl else ""

func _joy(k: Dictionary) -> float:
	return Care.need(k["rec"], "joy")

func _next_day(rec: Dictionary) -> void:
	var day := float(Content.rules("care")["care_day_s"])
	for kind in rec["care_day"]:
		rec["care_day"][kind] = float(rec["care_day"][kind]) - day - 1.0
	rec["care_t"] = {}

func _spam(s: Stub, kd: String) -> void:
	var k := _boki(kd)
	var cap := int(PetReact.rules()["kinds"][kd]["cap"])
	var paid := 0
	for _i in 12:
		k["pet_at"] = Time.get_ticks_msec() / 1000.0      # a shy one is always on its second pat
		if _pat(s, k)["paid"]: paid += 1
	ok(paid <= cap, "%s: 12 pats in a row pay %d time(s), the daily cap is %d" % [kd, paid, cap])
	var trust := float(k["rec"]["trust"])
	var joy := _joy(k)
	var again := bool(_pat(s, k)["paid"])
	ok(not again and float(k["rec"]["trust"]) == trust and _joy(k) == joy, "%s: past the cap a pat adds nothing" % kd)
	_next_day(k["rec"])
	ok(_pat(s, k)["paid"], "%s: the next farm day pays again" % kd)

func _pose(k: Dictionary) -> String:
	return String((k["node"] as Node3D).get_meta("pose", ""))

func _trust(k: Dictionary) -> float:
	return float(k["rec"]["trust"]) - 10.0

func run(m: Node) -> void:
	Save.no_write = true
	scene = m
	var s := Stub.new()
	var rules := PetReact.rules()
	for kd in TRAITS:
		ok(PetReact.kind(_boki(kd)["rec"]) == kd, "traits of a %s Boki read as %s" % [kd, kd])
	# playful: rolls over, icon, joy and trust
	var k := _boki("playful")
	var r := _pat(s, k)
	var body := (k["node"] as Node3D).get_node("Body") as Node3D
	await m.get_tree().create_timer(0.35).timeout
	ok(r["paid"] and _icon(k) == "♪", "playful: a pat shows its icon")
	ok(absf(body.rotation.z) > 0.1, "playful: it rolls over (rot %.2f)" % body.rotation.z)
	ok(_joy(k) > 10.0 and float(k["joy_t"]) > 1.0, "playful: joy %.0f and a happy wiggle" % _joy(k))
	var play_trust := _trust(k)
	ok(play_trust >= float(Content.rules("garden_trust")["pet"]), "playful: trust %.1f" % play_trust)
	# shy: flinch, then lean in
	k = _boki("shy")
	r = _pat(s, k)
	ok(not r["paid"] and _pose(k) == "flinch" and _icon(k) == "!", "shy: the first pat is a flinch")
	ok(_joy(k) == 10.0 and _trust(k) == 0.0, "shy: the flinch pays nothing yet")
	r = _pat(s, k)
	ok(r["paid"] and _pose(k) == "comfort" and _icon(k) == "♥", "shy: the second pat is a lean in")
	ok(_joy(k) > 10.0 and _trust(k) > play_trust, "shy: it pays more trust (%.2f vs %.2f)" % [_trust(k), play_trust])
	k["pet_at"] = -1.0e9
	ok(not _pat(s, k)["paid"] and _pose(k) == "flinch", "shy: left alone a while, it flinches again")
	# proud: one pat, then it walks off
	k = _boki("proud")
	r = _pat(s, k)
	ok(r["paid"] and _icon(k) == "★" and _joy(k) > 10.0, "proud: its one pat pays and shows its icon")
	await m.get_tree().create_timer(float(rules["kinds"]["proud"]["hold_s"]) + 0.3).timeout
	var goal: Vector3 = k["goal"]
	var away := 3.0 + float(rules["away_m"]) * 0.9
	ok(goal != Vector3.INF and goal.x > away, "proud: it walks off away from you (goal x %.1f)" % goal.x)
	var joy := _joy(k)
	ok(not _pat(s, k)["paid"] and _joy(k) == joy, "proud: a second pat pays nothing")
	# sleepy: purr and nap
	k = _boki("sleepy")
	r = _pat(s, k)
	ok(r["paid"] and _icon(k) == "z", "sleepy: it purrs")
	var nap := float(rules["kinds"]["sleepy"]["nap_s"])
	ok(is_equal_approx(float(k["nap_t"]), nap), "sleepy: it drops into a short nap")
	# a visit: the beat plays, nothing is paid
	k = _boki("playful")
	r = PetReact.pet(s, k, false)
	ok(not r["paid"] and _joy(k) == 10.0 and _icon(k) == "♪", "a visit: the beat plays, no joy, no trust")
	for kd in TRAITS:
		_spam(s, kd)
	print("PETREACT DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
