extends RefCounted
## Thrown-prop hand-off, run inside the hero combo checks (Albert's hammer, Grimble's hook, Kael's Warchain, Sable's
## dagger, Neve's spear): sampled after every step of a real throw, the prop leaves the hand on the throw frame (the
## kit's key time, not before or after), the hand and the air never both show it, the hand is never empty with
## nothing flying for more than a step, and it snaps back on the step it stops flying. Each hero is one trace of
## rows [t, in_hand, in_air]: in_hand is the model's own prop (the kit's out-of-hand flag), in_air the copies the kit
## draws in the world.

const DT := 1.0 / 60.0
const KEY_TOL := 0.06            # s either side of the throw key (about three frames at 60 fps)
const GAP_STEPS := 1             # steps the hand may be empty with nothing flying (the kit's flag follows its tick)

var A
var ok: Callable

func _init(ak, ok_fn: Callable) -> void:
	A = ak
	ok = ok_fn

func run(who: String) -> void:
	match who:
		"bulwark": await _albert()
		"dredge": await _grimble()
		"juggernaut": await _kael()
		"thief": await _sable()
		"rimewright": await _neve()

## Steps the match `secs` and samples [t, in_hand, in_air] after each step; `each` runs before it (inputs).
func trace(m: Match, secs: float, sample: Callable, each := Callable()) -> Array:
	var rows: Array = []
	var t := 0.0
	while t < secs:
		if each.is_valid():
			each.call(t)
		m.step(DT)
		t += DT
		var s: Array = sample.call()
		rows.append([t, s[0], s[1]])
	return rows

## The asserts on one trace. key: the throw key's time in the move's clip, skip: how far into the clip the kit starts it
## (ArchKit.play), so the prop must leave within KEY_TOL of key - skip after the press. back: it returns to the hand.
func judge(who: String, rows: Array, key: float, skip: float, back: bool) -> void:
	var out := -1.0
	var air := -1.0
	var back_t := -1.0
	var copies := 0
	var gap := 0
	var worst_gap := 0
	for r in rows:
		var hand := bool(r[1])
		var n := int(r[2])
		copies = maxi(copies, int(hand) + n)
		gap = gap + 1 if not hand and n == 0 else 0
		worst_gap = maxi(worst_gap, gap)
		if out < 0.0 and not hand:
			out = float(r[0])
		if air < 0.0 and n > 0:
			air = float(r[0])
		if back_t < 0.0 and out >= 0.0 and hand:
			back_t = float(r[0])
	ok.call("%s: the prop leaves the hand on the throw key (%.2f s of its clip)" % [who, key],
			out >= 0.0 and absf(out + skip - key) <= KEY_TOL, "left at %.3f s of the clip" % (out + skip))
	ok.call("%s: never two copies (hand and air)" % who, copies <= 1, "most at once: %d" % copies)
	ok.call("%s: the hand empties as the prop appears in the air" % who,
			out >= 0.0 and air >= 0.0 and absf(out - air) <= DT * 1.5, "hand %.3f, air %.3f" % [out, air])
	ok.call("%s: never an empty hand with nothing flying" % who, worst_gap <= GAP_STEPS, "%d steps" % worst_gap)
	if back:
		var last: Array = rows[rows.size() - 1]
		ok.call("%s: it snaps back to the hand and the air copy goes in the same step" % who,
				back_t > out and int(last[2]) == 0 and bool(last[1]), "back at %.3f s" % back_t)

func _shots_by(m: Match, h: Hunter) -> int:
	return m.shots.filter(func(s): return s["by"] == h).size()

func _albert() -> void:
	var r: Array = A.setup("bulwark", 9.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: BulwarkKit = P.ak
	A.aim_at(P, r[4] + Vector3(0, 0, -6.0))
	var pose: Array = []           # [move, its age] on each step (the catch pose check below)
	var rows := trace(m, 1.3,
			func():
				pose.append([K.anim_id, m.time - K.anim_at])
				return [not bool(P.model.get_meta(WardenClips.WEAPON_OUT, false)), int(K.fx.hammer.visible)],
			func(t): P.inp["fire"] = t < 0.03 or (t > 0.6 and t < 0.65))
	judge("Albert hammer", rows, 0.14, 0.0, true)
	var at := -1
	for i in range(1, rows.size()):
		if bool(rows[i][1]) and not bool(rows[i - 1][1]):
			at = i
	var cp: Array = pose[at] if at >= 0 else ["", -1.0]
	ok.call("Albert hammer: the catch step plays bul_recall at its catch key (%.2f s)" % BulwarkKit.RECALL_CATCH,
			cp[0] == "bul_recall" and absf(float(cp[1]) - BulwarkKit.RECALL_CATCH) <= DT * 1.5,
			"%s at %.3f s" % [cp[0], float(cp[1])])
	m.queue_free()

func _grimble() -> void:
	var r: Array = A.setup("dredge", 9.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: DredgeKit = P.ak
	A.aim_at(P, r[4] + Vector3(0, 0, -8.0))
	P.inp["sec_hold"] = false
	P.ak.press_rmb()
	var rows := trace(m, 1.0,
			func(): return [not bool(P.model.get_meta(WardenGlb.CHAIN_OUT, false)),
					int(not K.hook_sd.is_empty() or K.snap_t > 0.0 or not K.pull.is_empty())])
	judge("Grimble hook", rows, 0.14, DredgeKit.THROW_SKIP, true)
	m.queue_free()

func _kael() -> void:
	var r: Array = A.setup("juggernaut", 9.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: JuggernautKit = P.ak
	A.aim_at(P, r[4] + Vector3(0, 0, -8.0))
	K.use_e()
	var rows := trace(m, 0.8,
			func(): return [not bool(P.model.get_meta(WardenGlb.CHAIN_OUT, false)),
					_shots_by(m, P) if K.warchain.state == "throwing" else int(K.warchain.state != "ready")])
	judge("Kael Warchain", rows, 0.16, JuggernautChain.THROW_SKIP, true)
	m.queue_free()

func _sable() -> void:
	var r: Array = A.setup("thief", 9.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: ThiefKit = P.ak
	A.aim_at(P, r[4] + Vector3(0, 0, -8.0))
	K.use_e()
	var rows := trace(m, 0.6,
			func():
				var n := _shots_by(m, P) + int(not K.knife.is_empty())
				return [n == 0, n])
	judge("Sable dagger", rows, 0.12, 0.0, false)
	m.queue_free()

func _neve() -> void:
	var r: Array = A.setup("rimewright", 9.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: RimewrightKit = P.ak
	A.aim_at(P, r[4] + Vector3(0, 0, -8.0))
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	A.step(m, 0.35, func(): P.inp["sec_hold"] = true)       # the spear is formed between her palms
	var rows := trace(m, 0.3,
			func(): return [K.lk().showing("spear_prop") or K.throw_t >= 0.0, _shots_by(m, P)],
			func(_t): P.inp["sec_hold"] = false)
	judge("Neve spear", rows, 0.1, 0.0, false)
	m.queue_free()
