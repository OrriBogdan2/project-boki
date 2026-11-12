extends RefCounted
## --boss-tell-check: every lair boss attack gives a fair tell. Each move (content/rules/boss_moves.json)
## keeps its tell at or above the floor in every enrage and phase, shows a ground ring the moment it
## starts, never hits a full-HP Hunter for more than they have, and a dash started at 70% of the tell
## (from the middle of the shape, the worst spot) is out of the hit when it lands. Also checks the old
## bug where each slam made the next tell shorter. Prints BOSSTELL ok/FAIL and the table.

const HUNTER_CLASS := "medium"      # the 145-HP Hunter the shares are quoted for
const DASH_AT := 0.7                # the dash starts this share of the way through the tell
const SHOT_R := 0.36                # m: the radius of a boss spit shot (boss.gd _atk_spit)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOSSTELL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## The metres a dash started at DASH_AT of a tell has put between a hunter and the middle by the hit.
func _escape_m(tell: float, dash_m: float, dash_s: float, run_mps: float) -> float:
	var left := tell * (1.0 - DASH_AT)
	return dash_m * minf(1.0, left / dash_s) + run_mps * maxf(0.0, left - dash_s)

## The metres from the middle to clear the hit, for the hunter's own radius.
func _need_m(mv: Dictionary, hunter_r: float) -> float:
	match String(mv["shape"]):
		"circle": return float(mv["radius_m"]) + hunter_r
		"shots": return float(mv["width_m"]) * 0.5 + SHOT_R + hunter_r
	return float(mv["width_m"]) * 0.5 + hunter_r

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var cls: Dictionary = Data.CLASSES[HUNTER_CLASS]
	var hp := float(cls["hp"])
	var feel_file := FileAccess.get_file_as_string("res://content/rules/dash_feel.json")
	var feel: Dictionary = JSON.parse_string(feel_file)["default"]
	var dash_m: float = Hunter.DASH_SPEED * Hunter.DASH_TIME * float(feel["dist"])
	var dash_s: float = Hunter.DASH_TIME * float(feel["time"])
	var run_mps := float(cls["speed"])
	var hunter_r := float(cls["hit_r"])
	var rules := BossMoves.rules()
	var floor_s := float(rules["min_tell_s"])
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var dummy: Hunter = m.player
	var max_k := 1.0 + (float(Data.TIERS[Data.TIERS.size() - 1]["mob"]) - 1.0) * 0.6
	for id in Data.BOSSES:
		var L: Dictionary = m.lairs.list.filter(func(x): return x["boss"] == id)[0]
		m.lairs.activate(L)
		var b: Boss = L["boss_mob"]
		b.dormant = false
		b.tgt = dummy
		dummy.teleport(Vector3(b.pos.x + 2.5, b.pos.y, b.pos.z))
		for move_id in rules["moves"][id]:
			var mv := BossMoves.move(id, move_id)
			if mv.has("tell_s"):
				_tell_checks(id, move_id, mv, floor_s)
			if float(mv["dmg"]) > 0.0 and mv.has("tell_s") and mv["shape"] != "ring" and not mv.has("puddle_dmg"):
				var ring := BossMoves.ring_s(id, move_id)
				var got := _escape_m(ring, dash_m, dash_s, run_mps)
				var need := _need_m(mv, hunter_r)
				var msg := "%s %s: a dash at 70%% of its %.2fs tell goes %.2f m, the hit reaches %.2f m"
				ok(got >= need or ring * (1.0 - DASH_AT) <= 0.14, msg % [id, move_id, ring, got, need])
			_live_checks(b, id, move_id, mv, hp, max_k)
		_no_compounding(b, id)
	var roar_s := float(rules["phase_roar"]["tell_s"])
	ok(roar_s >= floor_s, "the phase roar's shove has a %.1fs ground ring" % roar_s)
	print("BOSSTELL DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _tell_checks(id: String, move_id: String, mv: Dictionary, floor_s: float) -> void:
	var low := BossMoves.tell(id, move_id, true, 2)
	var msg := "%s %s: the shortest tell (enraged, last phase) is %.2fs, floor %.2fs"
	ok(low >= floor_s - 0.001, msg % [id, move_id, low, floor_s])
	var calm := BossMoves.tell(id, move_id, false, 0)
	ok(is_equal_approx(calm, float(mv["tell_s"])), "%s %s: the calm tell is the content's %.2fs" % [id, move_id, calm])

func _live_checks(b: Boss, id: String, move_id: String, mv: Dictionary, hp: float, max_k: float) -> void:
	var dmg_k := b.dmg_mult
	b.dmg_mult = max_k
	b.enraged = true
	b.phase = 2
	var worst := b.dmg(float(mv["dmg"]))
	b.dmg_mult = dmg_k
	b.enraged = false
	b.phase = 0
	var msg := "%s %s: the worst hit (top tier, enraged, last phase) is %.0f, %.0f%% of a %.0f-HP Hunter, base %.0f%%"
	ok(worst < hp, msg % [id, move_id, worst, worst / hp * 100.0, hp, float(mv["dmg"]) / hp * 100.0])
	if not mv.has("tell_s"):
		return
	b.atk = ""
	b.call("_atk_" + move_id)
	for s in b.steps:
		if float(s["t"]) <= 0.6:
			(s["f"] as Callable).call()
	var ring_s := 0.0
	for t in b.teles:
		ring_s = maxf(ring_s, float(t["dur"]))
	var up := not b.teles.is_empty() and ring_s >= float(mv["tell_s"]) - 0.001
	ok(up, "%s %s: its ground ring is up from the start for %.2fs" % [id, move_id, ring_s])
	b._clear_attack()

## The old bug: a quickening move read the tell the last one left behind, so each was shorter.
func _no_compounding(b: Boss, id: String) -> void:
	b.enraged = true
	b.phase = 1
	for move_id in BossMoves.rules()["moves"][id]:
		if not BossMoves.move(id, move_id).get("quickens", false):
			continue
		var first := 0.0
		for i in 4:
			b.call("_atk_" + move_id)
			if i == 0: first = float(b.md["windup"])
			b._clear_attack()
		var same := is_equal_approx(float(b.md["windup"]), first)
		ok(same, "%s %s: four in a row keep the same %.2fs tell" % [id, move_id, first])
	b.enraged = false
	b.phase = 0
