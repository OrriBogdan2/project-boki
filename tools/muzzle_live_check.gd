extends RefCounted
## --muzzle-live-check: every Hunter's shots leave the drawn weapon. Each of the 13 Hunters, in a real match with
## its model dressed and drawn at the match camera's size, presses LMB, RMB, E, R and X; the round each press spawns
## starts within MAX_OFF (on screen: off the camera's ray through it) of that slot's weapon point on the model (Muzzle) as the
## arm stands a few frames later. One MUZZLE line per press, a table to paste. A press that spawns no round
## (a dash, a melee swing, a field) is n/a, a round ring (a nova) leaves the body, not the weapon.
## Never touches the save.

const DT := 1.0 / 60.0
const MAX_OFF := 0.15         # m: how far a round may start from its weapon point
const WAIT := 6               # frames after the round spawns, for the arm to stand
const RING := 0.4             # m: rounds of one press starting this far apart are a ring, not a muzzle
const ARCHS := ["archer", "ashwick", "bulwark", "dolm", "dredge", "gil", "gunslinger", "juggernaut", "mage", "ostra",
	"rimewright", "tender", "thief"]
const SLOTS := ["lmb", "rmb", "e", "r", "x"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MUZZLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, h: Hunter) -> void:
	m.step(DT)
	h.render(DT, 1.0)
	var sync: Node = h.model.get_node_or_null("Warden/Sync") if h.model else null
	if sync:
		sync.set_process(false)
		sync.call("_process", DT)

## Presses `slot` and returns {"n": rounds, "off": m} for the first round(s) it spawns, off -1 when none or a ring.
func _press(m: Match, P: Hunter, slot: String, held: bool) -> Dictionary:
	var sid0: int = m.shot_n
	P.fire_cd = 0.0
	P.ammo = int(P.wpn.get("mag", 12))
	for k in P.ak.cd:
		P.ak.cd[k] = 0.0
	match slot:
		"lmb": P.inp["fire"] = true
		"rmb": P.inp["sec"] = true
		"e": P.ak.use_e()
		"r": P.ak.use_r()
		"x": HunterKeys.ult_pressed(P)
	P.inp["sec_hold"] = held
	var group: Array = []
	var seen := -1
	for f in 120:
		if f == 1:
			P.inp["fire"] = false
			P.inp["sec"] = false
		if f == (40 if held else 1):
			P.inp["sec_hold"] = false
		_frame(m, P)
		if seen < 0:
			for s in m.shots:
				if s["by"] == P and int(s["sid"]) > sid0 and not (s["x"] as Dictionary).get("melee", false):
					group.append(s["start"])
			if not group.is_empty():
				seen = f
		elif f == seen + WAIT:
			break
	for k in ["fire", "sec", "sec_hold"]:
		P.inp[k] = false
	if group.is_empty():
		return {"n": 0, "off": -1.0}
	var mid := Vector3.ZERO
	for g in group:
		mid += g / group.size()
	for g in group:
		if Vector2(g.x - mid.x, g.z - mid.z).length() > RING:
			return {"n": group.size(), "off": -1.0}
	var worst := 0.0
	for g in group:
		var best := 99.0
		for p in Muzzle.points(P, slot):
			best = minf(best, Muzzle.off_screen(P, g, p))
		worst = maxf(worst, best)
	return {"n": group.size(), "off": worst}

func run(main: Node) -> void:
	Save.no_write = true
	var A = load("res://tools/archetype_check.gd").new()
	A.main = main
	for arch in ARCHS:
		var r: Array = A.setup(arch, 11.0, "", true)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var aim: Vector3 = r[4] + Vector3(11.0, 0, 0)
		r[2].teleport(r[4] + Vector3(0, 0, 9.0))      # (off the lane: a round that hits dies before it is seen)
		for f in 20:
			_frame(m, P)
		var worst := 0.0
		A.aim_at(P, aim)
		for slot in SLOTS:
			var got := _press(m, P, slot, false)
			if slot == "rmb" and got["n"] == 0:
				got = _press(m, P, slot, true)
			var off: float = got["off"]
			var what := "n/a (no round)" if got["n"] == 0 else ("ring" if off < 0.0 else "%.3f m" % off)
			print("MUZZLE %s %s %d rounds: %s  [%s]" % [arch, slot, got["n"], what, P.ak.anim_id])
			worst = maxf(worst, off)
			A.step(m, 1.0)
			A.aim_at(P, aim)
		ok(worst < MAX_OFF, "%s: every round leaves its weapon point (worst %.3f m)" % [arch, worst])
		m.queue_free()
	print("MUZZLE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
