extends "res://tools/hit_shape_check.gd"
## --hit-shape-fine [--fine-hero=<arch>] (docs/KIT_PARITY.md, "Hit shapes in game"): the --hit-shape-check
## method with ONE dummy moved around instead of a grid, so a reach, a lane and an arc come out to about
## 0.1 m / 3 degrees instead of 0.5 m / 10. Per input: a radial scan along the aim line (near and far
## distance of a dummy's CENTRE that still takes damage), a lateral scan at the middle radius (the lane's
## full width in centres) and an angular scan at that radius (arc of centres, only for a lane wider than
## 1.2 m). A foe is hit when its centre is that close to the shape, so the shape's own edge is up to the
## foe's hit circle (0.48 m) nearer, and a bullet adds its radius. Prints HFROW lines (archetype, input,
## hold, side, near, far, width, arc). A row's 4th number is a side offset in metres the
## radial scan runs along (a cone's flank), 0 on the aim line; a 5th, true, marks an area move
## (--hit-shape-shots puts a foe on the aim line for it).

const HEROES := {
	"gunslinger": [
		["lmb", 0.4, 0.7], ["rmb", 0.0, 1.8], ["rmb", 0.0, 1.8, 1.5], ["e", 0.0, 1.4],
		["x", 0.0, 2.3, 0.0, true]],
	"juggernaut": [
		["lmb", 0.0, 0.9, 0.0, true], ["lmb_hold", 1.15, 1.5], ["rmb", 0.0, 1.0, 0.0, true],
		["rmb_hold", 0.9, 1.5], ["e", 0.0, 1.0], ["x", 0.0, 1.6, 0.0, true]],
	"archer": [
		["lmb_hold", 0.75, 1.2], ["lmb_hold", 1.3, 1.6], ["rmb_hold", 1.2, 1.7],
		["e", 0.0, 1.6, 0.0, true], ["x_fire", 0.9, 1.8]],
	"ashwick": [
		["lmb_hold", 0.5, 0.8, 0.0, true], ["rmb", 0.0, 1.8], ["e", 0.0, 1.0, 0.0, true],
		["x", 0.0, 2.6, 0.0, true]],
}
const SCAN := 1.0                # m between the first radial probes
const FAR := 22.0                # m, last radial probe
const MIN_LANE := 1.2            # m: a lane narrower than this (a shot, a beam) has no arc to read

var lone := Vector3.ZERO
var arch := ""
var kind := ""
var hold := 0.0
var secs := 0.0
var side := 0.0

func _slot(i: int) -> Vector3:
	return lone if i == 0 else home + Vector3(-6.0, 0.0, 6.0)

## True when a dummy standing `p` (x ahead, z aside, metres from the hero) loses health.
func _hit(p: Vector2) -> bool:
	for mb in m.mobs: mb.queue_free()      # (a monster respawned on the aim line would stop a bullet)
	m.mobs.clear()
	lone = home + Vector3(p.x, 0.0, p.y)
	return _probe(arch, kind, hold, secs).has(0)

## The edge between a probe that hit (`a`) and one that missed (`b`), by halving four times.
func _edge(a: Vector2, b: Vector2) -> Vector2:
	for i in 4:
		var mid := (a + b) * 0.5
		if _hit(mid): a = mid
		else: b = mid
	return a

func _measure_fine() -> Dictionary:
	var hits: Array = []
	var d := 0.5
	while d <= FAR:
		if _hit(Vector2(d, side)): hits.append(d)
		d += SCAN
	var out := {"near": 0.0, "far": 0.0, "width": 0.0, "arc": 0.0, "n": hits.size()}
	if hits.is_empty(): return out
	var near: float = hits[0]
	var far: float = hits[hits.size() - 1]
	if near > 0.5: near = _edge(Vector2(near, side), Vector2(near - SCAN, side)).x
	far = _edge(Vector2(far, side), Vector2(far + SCAN, side)).x
	out["near"] = near
	out["far"] = far
	if side != 0.0: return out
	var mid := snappedf((near + far) * 0.5, 0.25)
	var z := 0.0
	while z < 5.0 and _hit(Vector2(mid, z + 0.5)): z += 0.5
	if z < 5.0: z = _edge(Vector2(mid, z), Vector2(mid, z + 0.5)).y
	out["width"] = 2.0 * z
	if out["width"] >= MIN_LANE:
		var ang := 0.0
		while ang < 180.0 and _hit(Vector2.from_angle(deg_to_rad(ang + 10.0)) * mid): ang += 10.0
		if ang < 180.0:
			var hi := ang + 10.0
			for i in 4:
				var half := (ang + hi) * 0.5
				if _hit(Vector2.from_angle(deg_to_rad(half)) * mid): ang = half
				else: hi = half
		out["arc"] = 2.0 * ang
	return out

func _close(what: String, got: float, want: float, tol: float) -> void:
	ok(absf(got - want) <= tol, "%s %s: game %.2f, content %.2f (+-%.2f)" % [arch, what, got, want, tol])

## The shapes whose content number names the shape itself, against the game: an area takes a foe in when its
## body circle (radius r, 0.40 m; bullets and swing rays use r + Match.HIT_SLACK) touches it, so r comes off
## every edge.
func _vs_content(meas: Dictionary) -> void:
	var rd: float = dummies[0].r
	var mid: float = (float(meas["far"]) + float(meas["near"])) * 0.5
	match [arch, kind, side]:
		["gunslinger", "e", 0.0]:
			_close("E range", float(meas["far"]) - rd, float(P.ak.e_def()["range"]), 0.15)
			_close("E half width", float(meas["width"]) * 0.5 - rd, float(P.ak.e_def()["width"]), 0.15)
		["gunslinger", "x", 0.0]:
			_close("R disc centre", mid, minf(float(P.ak.x_def()["range"]), 20.0), 0.15)
			var span: float = float(meas["far"]) - float(meas["near"])
			_close("R disc radius", span * 0.5 - rd, float(P.ak.x_def()["radius"]), 0.15)
		["juggernaut", "rmb", 0.0]:
			var sl: Dictionary = P.ak.rmb_def()["slam"]
			_close("RMB slam reach", float(meas["far"]) - rd, float(sl["radius"]), 0.15)
			_close("RMB slam angle", float(meas["arc"]), float(sl["angle"]), 6.0)
		["juggernaut", "x", 0.0]:
			_close("R strip length", float(meas["far"]) - rd, float(P.ak.x_def()["len"]), 0.15)
			_close("R strip half width", float(meas["width"]) * 0.5 - rd, float(P.ak.x_def()["width"]) * 0.5, 0.15)
		["archer", "e", 0.0]:
			_close("E wall radius", mid, float(P.ak.e_def()["reach"]), 0.15)
			_close("E wall arc", float(meas["arc"]), float(P.ak.e_def()["deg"]), 8.0)
		["ashwick", "e", 0.0]:
			_close("E ring radius", float(meas["far"]) - rd, float(P.ak.e_def()["radius"]), 0.15)

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	n_dummies = 4
	step_dt = 1.0 / 60.0      # the game's own step: a 74 m/s bullet moves 1.2 m a step, not 3.7
	await _spawn(main)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--fine-hero="): only = String(a).substr(12)
	for a in HEROES:
		if only != "" and a != only: continue
		arch = a
		for row in HEROES[a]:
			kind = row[0]
			hold = row[1]
			secs = row[2]
			side = row[3] if row.size() > 3 else 0.0
			var meas := _measure_fine()
			print("HFROW|%s|%s|%.2f|%.1f|%.1f|%.1f|%.1f|%.0f" % [a, kind, hold, side, meas["near"], meas["far"],
					meas["width"], meas["arc"]])
			ok(int(meas["n"]) > 0, "%s %s hurt the dummy somewhere on the aim line" % [a, kind])
			_vs_content(meas)
	HeroVfx.of(m).ribbons.clear()
	print("HIT SHAPE FINE DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
