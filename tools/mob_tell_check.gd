extends RefCounted
## --mob-tell-check: every monster attack can be dodged by watching its tell (docs/MOB_TELLS.md).
## For skitter, spitter, brute, warden, bomber and sentinel: the ground tell the player sees is read back
## from the telegraph nodes themselves and compared with where the attack really lands, found by
## running the attack against a stand-in just inside (95%) and just outside (105%) of the tell's edges;
## the fill reaches 1.0 on the hit frame (and the full tell stays up a moment); the body glow brightens
## to its peak on that frame; the tell wears the rival tint; and an instant blow leaves time to step out.
## The glimmerkin never attacks and must show no tell.
## With --shots-dir=<dir>: one strip per monster at wind-up 25 / 60 / 100 % (mob_tell_<kind>.png).

var main: Node
var ak = null
var m: Match
var T: Hunter
var home := Vector3.ZERO
var fails := 0
var n := 0
const DT := 1.0 / 60.0
const MOBS := ["skitter", "spitter", "brute", "warden", "bomber", "sentinel"]
const NEAR := 0.95          # probe just inside an edge
const FAR := 1.05           # probe just outside it
const WALK := 4.4           # m/s, a hunter on foot (Data.CLASSES)

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("MOBTELL %-62s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	var r: Array = ak.setup("gunslinger", 12.0, "", false)
	m = r[0]
	T = r[2]
	home = r[4]
	var P: Hunter = r[1]
	P.teleport(home + Vector3(-6, 0, 9))        # off every lane
	for k in MOBS:
		_mob(k)
	_glimmer()
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): shots = String(a).substr(12)
	if shots != "":
		m.queue_free()
		await main.get_tree().process_frame
		await load("res://tools/mob_tell_shots.gd").new().take(main, shots)
	print("MOBTELL DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## A fresh monster winding up at the origin of the strip, aimed east at the stand-in, which then goes to `at`.
func _wind(kind: String, at: Vector3) -> Mob:
	for old in m.mobs: old.queue_free()
	m.mobs.clear()
	ak.fresh(T)
	var mb := m.spawn_mob(kind, home + Vector3(2, 0, 0))
	mb.teleport(home + Vector3(2, 0, 0))
	T.teleport(mb.pos + Vector3(3, 0, 0))
	T.vel = Vector3.ZERO
	mb.tgt = T
	mb._begin_attack()
	T.teleport(at)
	T.vel = Vector3.ZERO
	mb.tgt = null                       # the aim stays east: the test moves the stand-in, not the mob
	return mb

## What the player sees: the lanes and circles on the ground, read back off the telegraph nodes.
func _seen(mb: Mob) -> Array:
	var out: Array = []
	for mi in mb.tele:
		var node := mi as MeshInstance3D
		var sz: Vector2 = (node.mesh as PlaneMesh).size
		var yaw := node.rotation.y
		if node.has_meta("len"):
			var d := Vector2(-sin(yaw), -cos(yaw))
			var c := node.global_position
			var from := c - Vector3(d.x, 0, d.y) * sz.y * 0.5
			out.append({"lane": true, "dir": d, "len": sz.y, "width": sz.x, "from": from})
		else:
			out.append({"lane": false, "at": node.global_position, "r": sz.x * 0.5})
	return out

## Run the attack to its end with the stand-in at `at`; did it hurt?
func _hurts(kind: String, at: Vector3) -> bool:
	var mb := _wind(kind, at)
	var secs := float(mb.md["windup"]) + 1.6
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
	return ak.dmg(T) > 0.0

func _probes(sh: Dictionary) -> Array:
	## [point, should it hit?, label]
	var out: Array = []
	if sh["lane"]:
		var d: Vector2 = sh["dir"]
		var nv := Vector2(-d.y, d.x)
		var s: Vector3 = sh["from"]
		var L: float = sh["len"]
		var hw: float = sh["width"] * 0.5
		for sd in [-1.0, 1.0]:
			for f in [[NEAR, true], [FAR, false]]:
				var q: Vector2 = Vector2(s.x, s.z) + d * L * 0.9 + nv * hw * f[0] * sd
				out.append([Vector3(q.x, s.y, q.y), f[1], "side"])
		for f in [[NEAR, true], [FAR, false]]:
			var q2: Vector2 = Vector2(s.x, s.z) + d * L * f[0]
			out.append([Vector3(q2.x, s.y, q2.y), f[1], "end"])
	else:
		var c: Vector3 = sh["at"]
		for a in [0.0, 2.1, 4.2]:
			for f in [[NEAR, true], [FAR, false]]:
				out.append([c + Vector3(cos(a), 0, sin(a)) * float(sh["r"]) * f[0], f[1], "edge"])
	return out

func _mob(kind: String) -> void:
	var mb := _wind(kind, home + Vector3(2, 0, 9))
	var windup := float(mb.md["windup"])
	m.step(DT)
	var seen := _seen(mb)
	var want := MobTell.shapes(mb, mb.atk_pad).size()
	var made := seen.size() == want and want > 0
	ok("%s: one ground tell per shape of its attack" % kind, made, "%d of %d" % [seen.size(), want])
	var base: Color = MobTell.TELL_COL[mb.md["attack"]]
	var col := Color.BLACK
	if not mb.tele.is_empty():
		col = (mb.tele[0] as MeshInstance3D).material_override.get_shader_parameter("color")
	var tinted := Color(col, 1.0).is_equal_approx(Feel.hostile(base))
	ok("%s: the tell wears the rival tint" % kind, tinted and _gap(col, Feel.RIM_ENEMY) < _gap(base, Feel.RIM_ENEMY))
	# 1) the tell's shape against where the attack really lands
	var bad := 0
	var probes := 0
	for sh in seen:
		for pr in _probes(sh):
			probes += 1
			if _hurts(kind, pr[0]) != pr[1]:
				bad += 1
				var rel: Vector3 = pr[0] - home
				var verdict := "hit" if pr[1] else "miss"
				print("MOBTELL   %s %s probe at %.2f,%.2f expected %s" % [kind, pr[2], rel.x, rel.z, verdict])
	var what := "%s: the tell equals the hit shape within 5%% (%d probes)" % [kind, probes]
	ok(what, bad == 0 and probes > 0, "%d wrong" % bad)
	# 2) the fill and the glow end on the hit frame
	mb = _wind(kind, home + Vector3(2, 0, 9))
	var fills: Array = []
	var glows: Array = []
	var struck := false
	var kept := true
	m.step(DT)                            # (the tell is made on the first step of the wind-up)
	for i in int(windup / DT) + 8:
		var nodes := mb.tele.duplicate()      # (a bomber clears its own on the hit frame)
		m.step(DT)
		mb.render(DT, 1.0)
		fills.append(float((nodes[0] as MeshInstance3D).material_override.get_shader_parameter("progress")))
		glows.append(_glow(mb))
		if mb.st != "windup" or mb.dead:
			struck = true
			kept = not mb.tele.is_empty() or mb.dead
			break
	var f_last: float = fills.back() if not fills.is_empty() else -1.0
	var f_prev: float = fills[fills.size() - 2] if fills.size() > 1 else -1.0
	var lands := struck and f_last >= 0.999 and f_prev >= 1.0 - 3.0 * DT / windup
	lands = lands and (fills.size() < 3 or fills[fills.size() - 3] < 0.999)
	ok("%s: the fill reaches 1 on the hit frame, not before" % kind, lands, "%.3f -> %.3f" % [f_prev, f_last])
	ok("%s: the tell stays up on the hit frame" % kind, kept)
	var rising := true
	for i in range(1, glows.size() - 1):
		if glows[i] < glows[i - 1]: rising = false
	var peak: float = glows[glows.size() - 2] if glows.size() > 1 else -1.0
	var bright: bool = rising and glows.size() > 3 and glows[0] < 0.1 and peak >= MobTell.GLOW_MAX * 0.9
	ok("%s: the body glow brightens to its peak on the hit frame" % kind, bright, "%.2f -> %.2f" % [glows[0], peak])
	# 3) an instant blow can be stepped out of while its shape is fixed (the aim locks for the last 40% of a lunge)
	if mb.md["attack"] in ["lunge", "slam", "fuse"]:
		var locked := windup * (0.4 if mb.md["attack"] == "lunge" else 1.0)
		var out_m := 0.0
		for sh in seen:
			out_m = maxf(out_m, sh["width"] * 0.5 if sh["lane"] else float(sh["r"]))
		var info := "%.2f m in %.2f s, needs %.2f" % [locked * WALK, locked, out_m]
		ok("%s: a hunter on foot steps out before it lands" % kind, locked * WALK >= out_m, info)

func _gap(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _glow(mb: Mob) -> float:
	return float(mb.mats[0].get_shader_parameter("flash")) if not mb.mats.is_empty() else -1.0

func _glimmer() -> void:
	var mb := m.spawn_mob("glimmer", home + Vector3(2, 0, 0))
	var quiet: bool = mb.md["attack"] == "none" and MobTell.shapes(mb, 0.4).is_empty()
	ok("glimmer: never attacks, so it has no tell to show", quiet and not MobTell.TELL_COL.has("none"))
