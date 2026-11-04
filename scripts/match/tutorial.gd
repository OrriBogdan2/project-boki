class_name Tutorial
extends RefCounted
## The first-match tutorial's newer steps (crouch, watching your Boki, picking gear up) and the headless
## test driver. The step table and the shared steps live in Match (TUT, _update_tutorial).

const CROUCH_T := 1.5      # s of crouching that completes the crouch step
const KIN_WATCH_T := 12.0  # s to wait for your Boki to use its ability before moving on

const BEAM_R := 0.9       # m, radius of the destination pillar
const BEAM_H := 60.0      # m, its height

static var last_step := -1

## Whether a step of these kinds is finished. dt: this frame's time.
static func done(m: Match, id: String, dt: float) -> bool:
	match id:
		"crouch":
			m.tut_t += dt if m.player.crouch else 0.0
			return m.tut_t >= CROUCH_T
		"kin1":
			m.tut_t += dt
			var k: Kin = m.player.kin
			var cast: bool = k != null and k.st_skills > int(m.tut_used0.get("kin_sk", 0))
			return k == null or k.state == "downed" or cast or m.tut_t >= KIN_WATCH_T
		"pickup": return ground_item(m).is_empty()
	return false

## A step starts: reset its timer and set up what it needs.
static func enter(m: Match, id: String) -> void:
	m.tut_t = 0.0
	if m.player.kin:
		m.tut_used0["kin_sk"] = m.player.kin.st_skills
	if id == "pickup":
		var at := m._tut_spot(2.5, 0.6)
		if at != Vector3.INF:
			m.spawn_gear("vest", 1, at, "", false)
			m.wpicks[-1]["tut"] = true
			m.ping(at, Color("dfe8f2"))

## A tall pillar of light over the step's destination, so it can be seen from the air and across gaps.
static func beam(m: Match) -> void:
	var n: MeshInstance3D = m.get_meta("tut_beam") if m.has_meta("tut_beam") else null
	if n == null:
		n = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = BEAM_R
		cyl.bottom_radius = BEAM_R
		cyl.height = BEAM_H
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.56, 0.89, 0.78, 0.3)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		cyl.material = mat
		n.mesh = cyl
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.add_child(n)
		m.set_meta("tut_beam", n)
	n.visible = m.tut_target != Vector3.INF
	if n.visible:
		n.position = m.tut_target + Vector3(0, BEAM_H * 0.5, 0)

## The gear on the ground that the pickup step is about ({} when it is gone).
static func ground_item(m: Match) -> Dictionary:
	for wp in m.wpicks:
		if wp.get("tut", false):
			return wp
	return {}

## Test driver: plays the tutorial by itself so the whole flow can be checked headless.
static func drive(m: Match) -> void:
	if m.tut_step != last_step:
		var live := m.mobs.filter(func(x): return not x.dead).size()
		print("TUT step ", m.tut_step, " ", m.tut_id(), " t=", snapped(m.time, 0.1), " mobs=", live)
		last_step = m.tut_step
	var p := m.player
	p.inp["move"] = Vector2.ZERO
	p.inp["fire"] = false
	p.inp["glide"] = false
	p.inp["interact"] = false
	p.inp["crouch"] = false
	var goto := func(at: Vector3):
		var d := Vector2(at.x - p.pos.x, at.z - p.pos.z)
		p.inp["move"] = d.normalized() if d.length() > 0.5 else Vector2.ZERO
	var near_mob := func() -> Ent:
		var best: Ent = null
		var bd := 1e9
		for mb in m.mobs:
			if not mb.dead and p.flat_dist(mb) < bd:
				bd = p.flat_dist(mb)
				best = mb
		return best
	match m.tut_id():
		"move": p.inp["move"] = Vector2(1, 0) if int(m.time) % 4 < 2 else Vector2(-1, 0)
		"dash": p.inp["dash"] = true
		"glide":
			if p.grounded and not m.tut_flag: p.inp["jump"] = true
			p.inp["glide"] = true
		"exdash":
			if p.grounded and not m.tut_flag: p.inp["jump"] = true
			elif not p.grounded and not m.tut_flag and p.vel.y < 0.0: p.inp["dash"] = true
		"utility":
			p.inp["sec"] = true
		"crouch": p.inp["crouch"] = true
		"shoot", "kin1", "throw":
			var best: Ent = near_mob.call()
			if best:
				p.inp["aim"] = best.pos + Vector3(0, 0.9, 0)
				if p.flat_dist(best) > 3.0: goto.call(best.pos)
				if m.tut_id() == "shoot": p.inp["fire"] = true
				elif p.kin and p.kin.state == "shoulder": p.kin.throw_to(best.pos)     # (kin1 then just watches)
		"pickup":
			var wp := ground_item(m)
			if not wp.is_empty():
				goto.call(wp["pos"])
				p.inp["interact"] = int(m.time * 30.0) % 2 == 0     # (a tap per item: one press, one pickup)
		"chest":
			for c in m.chests:
				if not c["open"] and c.get("tut", false):
					goto.call(c["pos"])
					p.inp["interact"] = true
					break
		"goexit", "uplink", "defend", "extract":
			var o := m._tut_outpost()
			if o.is_empty():
				return
			var c: Vector3 = o["pos"]
			match m.tut_id():
				"goexit":
					# go there the way a bot would: over the bridges, or jump and glide across a gap
					var mv := m.bot_brain._path_dir(m, p, c)
					if p.ai.has("cross"):
						var L: Dictionary = p.ai["cross"]
						var land: Vector3 = L["land"]
						var tol := Vector2(land.x - p.pos.x, land.z - p.pos.z)
						if p.grounded and m.world.island_of(p.pos.x, p.pos.z) == int(L["to"]):
							p.ai.erase("cross")
						elif not p.grounded:
							mv = tol.normalized()
							p.inp["glide"] = tol.length() > 1.6 or m.world.is_void(p.pos.x, p.pos.z)
						elif p.flat_dist(L["take"]) < 1.3:
							mv = tol.normalized()
							p.inp["jump"] = true
					p.inp["move"] = mv
					p.inp["aim"] = p.pos + Vector3(mv.x, 0.9, mv.y) * 3.0
				"uplink":
					goto.call(c)
					p.inp["interact"] = p.flat_dist(c) < 1.4
				"defend":
					goto.call(c + Vector3(1.2, 0, 1.2))
					var best: Ent = near_mob.call()
					if best and p.flat_dist(best) < 8.0:
						p.inp["aim"] = best.pos + Vector3(0, 0.9, 0)
						p.inp["fire"] = true
				"extract":
					goto.call(c)
