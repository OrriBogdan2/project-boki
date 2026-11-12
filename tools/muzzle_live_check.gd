extends RefCounted
## --muzzle-live-check: every Hunter's shots leave the drawn weapon. Each of the 13 Hunters, in a real match with
## its model dressed and drawn at the match camera's size, presses LMB, RMB, E, R and X; the round each press spawns
## starts within MAX_OFF (on screen: off the camera's ray through it) of that slot's weapon point (Muzzle) as the
## arm stands a few frames later. One MUZZLE line per press, a table to paste. A press that spawns no round
## (a dash, a melee swing, a field) is n/a, a round ring (a nova) leaves the body, not the weapon.
## --only=<archetype> runs one. Never touches the save.

const DT := 1.0 / 60.0
const MAX_OFF := 0.15         # m: how far a round may start from its weapon point
const WAIT := 2               # frames after the round spawns, for the arm to stand
const RING := 0.4             # m: rounds of one press starting this far apart are a ring, not a muzzle
const ARCHS := ["archer", "ashwick", "bulwark", "dolm", "dredge", "gil", "gunslinger", "juggernaut", "mage", "ostra",
	"rimewright", "tender", "thief"]
const SLOTS := ["lmb", "rmb", "e", "r", "x"]

var bad := 0
var first: Dictionary = {}      # the first round of the press

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

func _collect(m: Match, P: Hunter, sid0: int, group: Array) -> void:
	for s in m.shots:
		if s["by"] == P and int(s["sid"]) > sid0 and not (s["x"] as Dictionary).get("melee", false):
			group.append(Muzzle.drawn(s, s["start"]))
			first = s

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
	first = {}
	_collect(m, P, sid0, group)      # (a round that spawns on the press may hit and be gone after one step)
	var seen := 0 if not group.is_empty() else -1
	for f in 120:
		if f == 1:
			P.inp["fire"] = false
			P.inp["sec"] = false
		if f == (40 if held else 1):
			P.inp["sec_hold"] = false
		_frame(m, P)
		if seen < 0:
			_collect(m, P, sid0, group)
			if not group.is_empty():
				seen = f
		elif f == seen + WAIT:
			break
	for k in ["fire", "sec", "sec_hold"]:
		P.inp[k] = false
	if slot == "lmb" and not first.is_empty():
		_look_eases(P, first)
		_copy_leaves(m, P, first)
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

## Only the look moves to the muzzle: the round keeps its start (aim, reach, hits); its look eases onto its line.
func _look_eases(P: Hunter, s: Dictionary) -> void:
	if not s.has("vis"):
		return
	var start_at: Vector3 = s["start"]
	var far := start_at + Vector3(Muzzle.BLEND_M, 0, 0)
	ok(Muzzle.drawn(s, far) == far and Muzzle.drawn(s, start_at) == start_at + (s["vis"] as Vector3),
		"%s: the look is at the muzzle at the start and on the round's line %.0f m on" % [P.arch, Muzzle.BLEND_M])

## The other player's game (decision 0061): the copy the "s" event makes of the round gets its look's offset
## from the shooter's weapon there too.
func _copy_leaves(m: Match, P: Hunter, s: Dictionary) -> void:
	if not s.has("vis"):
		return
	var at: Vector3 = s["start"]
	var v: Vector2 = s["vel"]
	m._net_ev(["s", at.x, at.y, at.z, v.x, v.y, 0.1, 0.2, "ffffff", 0.0, P.team, 0, P.nid, "lmb"], "")
	var vis: Variant = m.shots[-1].get("vis")
	var want := Muzzle.offset(P, "lmb", at)
	ok(vis != null and want != Vector3.ZERO and (vis as Vector3).distance_to(want) < 0.01,
		"%s: the other player's copy of the round leaves the same weapon point" % P.arch)

func run(main: Node) -> void:
	Save.no_write = true
	var A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--only="):
			only = String(a).substr(7)
	for arch in ARCHS:
		if only != "" and only != arch:
			continue
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
			if got["n"] == 0:      # (some casts want a foe in the lane)
				r[2].teleport(r[4] + Vector3(6.0, 0, 0))
				A.aim_at(P, r[2].pos)
				got = _press(m, P, slot, slot == "rmb")
				r[2].teleport(r[4] + Vector3(0, 0, 9.0))
				A.aim_at(P, aim)
			var off: float = got["off"]
			var what := "%.3f m" % off
			if got["n"] == 0 or off < 0.0:
				what = "n/a (no round)" if got["n"] == 0 else "ring"
			print("MUZZLE %s %s %d rounds: %s  [%s]" % [arch, slot, got["n"], what, P.ak.anim_id])
			worst = maxf(worst, off)
			A.step(m, 1.0)
			A.aim_at(P, aim)
		ok(worst < MAX_OFF, "%s: every round leaves its weapon point (worst %.3f m)" % [arch, worst])
		m.queue_free()
	print("MUZZLE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
