extends RefCounted
## --glide-bank-check: the glider rolls into its turns and the dive pitches the body nose-down, on every Hunter's
## rig (HunterAnim._air_tilt). Each Hunter (Arch.ORDER) in a live training match glides high up with a Boki riding
## on it: straight, a hard turn left (the keys held STEER degrees ahead of the heading: full steer), straight, a hard
## turn right, straight, then the dive (crouch held). Asserts that the roll leans into the turn (+ left), eases (no
## frame moves it more than JUMP_DEG), never passes GLIDE_BANK and reaches MIN_DEG in a hard turn, and settles level
## after it; that the dive pitches the whole body at least DIVE_MIN_DEG nose-down; that the .glb's whole body (its
## root bone, clips or not) turns with the rig; and that the rider keeps its seat on the torso you see through it all
## and leans with the body. Angles are taken in the Hunter's own frame (the camera's lean toward you left out).
## Prints "BANK ok|FAIL ..." and "BANK DONE, failures: N".

const HEIGHT := 60.0       # m above the ground: room for the dive
const STEER := 30.0        # degrees the keys sit ahead of the heading in a hard turn
const MIN_DEG := 20.0      # a hard turn banks at least this much (GLIDE_BANK is 25)
const JUMP_DEG := 3.5      # the most the bank may move in one 60 Hz step
const LEVEL_DEG := 1.0     # the bank left once a turn has been over for a phase
const DIVE_MIN_DEG := 45.0
const FOLLOW_DEG := 5.0    # the .glb's root may turn this far off the rig's tilt (a clip's own sway: Lace, Sparkle ~3)
const SEAT_M := 0.03       # m: how far the rider may move on the torso you see from where it sat in the straight glide
const LEAN_DEG := 2.0      # the rider's lean may differ from the rig's by this much
## s: the phases, each to the next one's start
const PHASES := [["fall", 0.0], ["hold", 0.3], ["left", 1.0], ["level", 2.0], ["right", 2.8], ["level2", 3.8],
	["dive", 4.6], ["end", 5.4]]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BANK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for arch in Arch.ORDER:
		await _hunter(main, String(arch))
	print("BANK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _phase(t: float) -> String:
	var at := "fall"
	for p in PHASES:
		if t >= float(p[1]):
			at = String(p[0])
	return at

func _hunter(main: Node, arch: String) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch)})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var h: Hunter = m.player
	h.set_arch(arch)
	for other in m.hunters:
		if other != h:
			other.ctrl = "idle"
			other.teleport(h.pos + Vector3(60, 0, 60))
	for i in 20:
		m.step(Match.DT)
	h.teleport(h.pos + Vector3(0, HEIGHT, 0))
	var sync := h.model.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync:
		sync.set_process(false)
	var k := h.kin as Kin
	if k == null:
		var rec := Save.new_kin("puddlet")
		rec["trust"] = 95.0
		k = m.give_kin(h, rec)
	var r := {"most": 0.0, "jump": 0.0, "follow": 0.0, "seat": 0.0, "lean": 0.0, "rode": 0, "level": 99.0}
	var hold := {}
	var heading := Vector2(1, 0)
	var was := 0.0
	var step := 0
	var t := 0.0
	while t < float(PHASES[-1][1]):
		var ph := _phase(t)
		if Vector2(h.vel.x, h.vel.z).length() > 1.0:
			heading = Vector2(h.vel.x, h.vel.z).normalized()
		var steer := 0.0       # (a Vector2 of x, z turns right for a positive angle)
		if ph == "left": steer = -STEER
		elif ph == "right": steer = STEER
		h.inp["move"] = heading.rotated(deg_to_rad(steer))
		h.inp["aim"] = h.pos + Vector3(heading.x, 0, heading.y) * 8.0 + Vector3(0, 0.9, 0)
		h.inp["glide"] = ph != "fall"
		h.inp["glide_btn"] = ph != "fall"
		h.inp["crouch"] = ph == "dive"
		if k and ph == "fall":
			k.stow()
		m.step(Match.DT)
		h.render(Match.DT, 1.0)
		if sync:
			sync._process(Match.DT)
		if k:
			k.render(Match.DT, 1.0)
		var bank := rad_to_deg(h.anim.glide_bank)
		r["most"] = maxf(r["most"], absf(bank))
		r["jump"] = maxf(r["jump"], absf(bank - was))
		was = bank
		var now := _pose(h, k)
		if ph == "hold":
			hold = now
		elif ph in ["left", "right", "dive"] and not hold.is_empty():
			_compare(r, ph, bank, now, hold)
		elif ph == "level" and _phase(t + Match.DT) != ph:
			r["level"] = absf(bank)
		step += 1
		t = step * Match.DT
	_report(arch, h, r)
	m.queue_free()
	await main.get_tree().process_frame

## One frame of a turn or the dive against the straight glide: the phase's last frame is kept (the held state), and
## the worst of the .glb root's drift off the rig and of the rider's over all of them.
func _compare(r: Dictionary, ph: String, bank: float, now: Dictionary, hold: Dictionary) -> void:
	var ax := "pitch" if ph == "dive" else "roll"
	var d := func(nm: String) -> float: return float(now[nm + "_" + ax]) - float(hold[nm + "_" + ax])
	var rig: float = d.call("rig")
	r[ph] = {"bank": bank, "rig": rig, "root": d.call("root"), "line": d.call("line")}
	r["follow"] = maxf(r["follow"], absf(d.call("root") - rig))
	if now.has("seat") and hold.has("seat"):
		r["rode"] += 1
		r["seat"] = maxf(r["seat"], ((now["seat"] as Vector3) - (hold["seat"] as Vector3)).length())
		r["lean"] = maxf(r["lean"], absf(d.call("rider") - rig))

func _report(arch: String, h: Hunter, r: Dictionary) -> void:
	var left: Dictionary = r.get("left", {"bank": 0.0})
	var right: Dictionary = r.get("right", {"bank": 0.0})
	var dive: Dictionary = r.get("dive", {"root": 0.0, "line": 0.0, "rig": 0.0})
	var cap := rad_to_deg(HunterAnim.GLIDE_BANK)
	ok(float(left["bank"]) >= MIN_DEG and float(right["bank"]) <= -MIN_DEG,
		"%s: a hard turn banks into it, left %+.1f deg, right %+.1f (at least %.0f)" % [arch, left["bank"],
		right["bank"], MIN_DEG])
	ok(float(r["most"]) <= cap + 0.01 and float(r["jump"]) <= JUMP_DEG,
		"%s: the bank stays within %.0f deg (%.1f) and eases (at most %.1f deg a step, limit %.1f)" % [arch, cap,
		r["most"], r["jump"], JUMP_DEG])
	ok(float(r["level"]) <= LEVEL_DEG, "%s: level again after the turn (%.2f deg)" % [arch, r["level"]])
	ok(float(dive["root"]) >= DIVE_MIN_DEG, "%s: the dive pitches the whole body you see nose-down %.0f deg (rig %.0f,"
		% [arch, dive["root"], dive["rig"]] + " hips to head %.0f)" % dive["line"])
	ok(float(r["follow"]) <= FOLLOW_DEG, "%s: the whole body you see turns with the rig (off by %.1f deg at most)"
		% [arch, r["follow"]])
	ok(int(r["rode"]) > 0 and float(r["seat"]) <= SEAT_M and float(r["lean"]) <= LEAN_DEG,
		"%s: the Boki riding on it keeps its seat (%d frames, moved %.3f m on the torso you see) and leans with it"
		% [arch, r["rode"], r["seat"]] + " (%.1f deg off)" % r["lean"])

## The tilts, in degrees off upright in the Hunter's own frame (the model's, the camera's lean left out): roll toward
## the left of the way it flies (+), pitch toward the way it faces (+ nose-down). "rig": the Rig node; "root": the
## .glb's root bone (what it carries the model's up to); "line": the body you see, hips to head; "rider": a Boki
## riding on it, with "seat" where it sits in the frame of the torso you see (the .glb's hips bone, else the rig's).
func _pose(h: Hunter, k: Kin) -> Dictionary:
	var inv := h.model.global_transform.affine_inverse()
	var fwd := Vector2(-sin(h.face), -cos(h.face))
	var hv := Vector2(h.vel.x, h.vel.z)
	var way := Vector3(hv.dot(Vector2(-fwd.y, fwd.x)), 0.0, -hv.dot(fwd)).normalized()
	var left := Vector3(way.z, 0.0, -way.x)
	var out := {}
	var rig := inv.basis * (h.model.get_node("Rig") as Node3D).global_basis.y
	_tilts(out, "rig", rig, left)
	var glb := h.model.get_node_or_null("Warden")
	var sk := WardenGlb.skeleton(glb) if glb else null
	var pts := []
	var torso := (h.model.get_node("Rig/Torso") as Node3D).global_transform     # the body's frame, world
	if sk:
		for b in ["hips", "head"]:
			pts.append(inv * (sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, b)).origin))
		var bi := WardenSkeleton.find(sk, "root")
		var to_m := (inv.basis * sk.global_basis).orthonormalized()
		var rest := sk.get_bone_global_rest(bi).basis.orthonormalized()
		var turn := sk.get_bone_global_pose(bi).basis.orthonormalized() * rest.inverse()
		_tilts(out, "root", to_m * turn * to_m.inverse() * Vector3.UP, left)
		torso = sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "hips"))
	else:
		pts = [inv * torso.origin, inv * (h.model.get_node("Rig/Torso/HeadPivot") as Node3D).global_position]
		_tilts(out, "root", rig, left)
	_tilts(out, "line", (pts[1] as Vector3) - (pts[0] as Vector3), left)
	if k and k.state == "shoulder" and not k.beside:
		_tilts(out, "rider", Basis(Vector3.UP, h.face).inverse() * k.model.global_basis.y, left)
		var frame := inv * torso       # (model space: a body "bulk" scales the model on x and z only)
		frame.basis = frame.basis.orthonormalized()       # (and a bone's frame carries the look's scale)
		out["seat"] = frame.affine_inverse() * (inv * k.global_position) * absf(h.model.scale.y)
	return out

static func _tilts(out: Dictionary, nm: String, up: Vector3, left: Vector3) -> void:
	out[nm + "_roll"] = rad_to_deg(atan2(up.dot(left), up.y))
	out[nm + "_pitch"] = rad_to_deg(atan2(-up.z, up.y))
