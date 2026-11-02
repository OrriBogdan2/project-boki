class_name DredgeKit
extends ArchKit
## Dredge (heavy). Gameplay follows the "initiator who reels you in" brief (docs/heroes/dredge.md);
## names, art, sounds and text are ours.
##
## - Passive, Salvage: knocks and assists stack (+2.5% health each, 10 at most); being downed costs
##   one. Hits on a hunter's back deal 50% more. A knock heals.
## - LMB: the shotgun (the weapon's own firing). At dash rank 3 pellet hits trim the barge recharge.
## - RMB, Grapnel: a rope-hook that stops at the first foe or wall, then reels the foe in (walls block
##   the reel, the abyss is not special-cased: a body dragged over it falls). They land Grounded.
##   While reeling only the barge works.
## - E, Anchor Drop: a short wind-up, then a stunning, slamming cone; in the air it also drives you
##   down (not over the abyss); rank 3 adds height damage. Just after it the barge turns badly.
## - Dash, Barge: a shoulder dash that shoves.

var pull := {}                  # the reel: {t (the foe), left, rope (node)}
var flying := false             # the hook is in the air
var wind := 0.0                 # the Anchor's wind-up left
var lock_until := -9.0          # the barge can't turn much until then (just after the Anchor)
var grapples := 0               # (tests) foes reeled in
var anchors := 0
var backstabs := 0
var snags := 0                  # reels ended by a wall
var arrivals := 0
var stacks_lost := 0
var _down_seen := false
var _stab_at := -9.0

func _setup() -> void:
	st["base_hp"] = h.max_hp

func res_text() -> String: return "%d" % int(res)
func res_frac() -> float: return clampf(res / res_max(), 0.0, 1.0)
func ready_label() -> String: return "SALVAGE" if res >= res_max() else ""
func rd() -> Dictionary: return res_def()

# ------------------------------------------------------------------ passive: Salvage
func add_stack(n: int) -> void:
	var before := res
	res = clampf(res + n, 0.0, res_max())
	if res == before:
		return
	_apply_hp()
	if n > 0:
		m.fx.word(h.pos + Vector3(0, 2.6, 0), "SALVAGE %d" % int(res), res_col(), res >= res_max())
		m.fx.ring(h.pos, 1.5, res_col(), 0.3)
		m.sfx("pay_salvage", h.pos, -4.0, 1.0)
		net_ring(h.pos, 1.5, res_col())

func _apply_hp() -> void:
	var want := float(st.get("base_hp", h.max_hp)) * (1.0 + float(rd()["per_stack"]) * res)
	var delta := want - h.max_hp
	h.max_hp = want
	if delta > 0.0: h.hp += delta
	else: h.hp = minf(h.hp, h.max_hp)

func on_knock(t: Hunter, mine: bool) -> void:
	add_stack(1)
	if mine and is_instance_valid(t):
		h.heal(h.max_hp * float(rd()["heal_knock"]))
		m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("7fe08a"), 14, 2.5, 0.5, -2.0)

func outgoing(t: Ent, dmg: float, _o: Dictionary) -> float:
	if t is Hunter and ArchKit.behind(t, h):
		if m.time - _stab_at > 1.2:
			_stab_at = m.time
			backstabs += 1
			m.fx.word(t.pos + Vector3(0, 2.2, 0), "BEHIND", res_col(), false)
		return dmg * (1.0 + float(rd()["back_k"]))
	return dmg

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or String(o.get("src", "")) != "shot":
		return
	if rank("dash") >= 3 and h.dashes < h.max_dashes():
		h.dashes = minf(h.max_dashes(), h.dashes + float(dash_def()["cut"]) / maxf(0.5, h.dash_regen()))

func can_shoot() -> bool:
	return fire_ok() and fuse.is_empty() and pull.is_empty()

func move_k() -> float:
	return 0.7 if wind > 0.0 else 1.0

# ------------------------------------------------------------------ tick
func _tick(dt: float) -> void:
	if h.downed and not _down_seen:
		_down_seen = true
		if res > 0.0:
			stacks_lost += 1
			add_stack(-1)
	elif not h.downed:
		_down_seen = false
	tell = "full" if res >= res_max() else ("half" if res >= 5.0 else "")
	self_pips(int(res_max()), int(res), res >= res_max(), dt)
	if wind > 0.0:
		wind -= dt
		if h.stun_t > 0.0 or h.downed:
			wind = 0.0
		elif wind <= 0.0:
			wind = 0.0
			_anchor()
	if not pull.is_empty(): _tick_pull(dt)
	net_pulse(dt, res >= res_max(), 1.8)

# ------------------------------------------------------------------ RMB: Grapnel
func fire_rmb(c: Dictionary) -> void:
	c["variant"] = "tap"
	last_variant = "tap"
	if flying or not pull.is_empty() or wind > 0.0:
		h._ab_feedback("sec", "deny")
		return
	if not spend_rmb():
		return
	var rdf := rmb_def()
	flying = true
	play("dr_throw")
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(rdf["speed"]), "range": float(rdf["range"]), "size": 0.24, "rope": true},
		"effects": [{"type": "damage", "amount": float(rdf["dmg"])}]})
	run(stg, cx("rmb", "grapnel", aim(), {
		"on_foe": func(f: Ent, _c: Dictionary):
			if pull.is_empty() and is_instance_valid(f) and not f.dead: _grab(f),
		"on_shot_end": func(at: Vector3, why: String, e: Ent):
			flying = false
			if e == null and pull.is_empty():
				m.fx.word(at + Vector3(0, 1.2, 0), "SNAGGED" if why == "wall" else "MISS", Color("c0b0a0"), false)}))
	m.sfx("dr_haul", h.pos, -3.0, 1.0)

func _grab(f: Ent) -> void:
	flying = false
	var rdf := rmb_def()
	if f.mass() >= 6.0:
		m.fx.word(f.pos + Vector3(0, 2.4, 0), "TOO HEAVY", Color("c0b0a0"), false)
		return
	grapples += 1
	if rank("sec") >= 3:
		cd["rmb"] = float(cd["rmb"]) * (1.0 - float(rdf["refund"]))
	var n := own_node()
	var link := MeshInstance3D.new()
	link.mesh = Models.box(0.08, 0.08, 1.0)
	link.material_override = Models.glow_mat(Color(col_of(rdf), 0.95))
	link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(link)
	pull = {"t": f, "left": float(rdf["pull_max"]), "node": n}
	m.fx.word(f.pos + Vector3(0, 2.4, 0), "HOOKED", col_of(rdf), true)
	m.sfx("grab", f.pos, -1.0, 0.9)
	play("dr_reel")
	if f.remote:
		_end_pull(true)           # their body belongs to another game: the hit and Grounded still land

func _tick_pull(dt: float) -> void:
	var f = pull["t"]
	if not is_instance_valid(f) or (f as Ent).dead or ((f is Hunter) and (f as Hunter).downed) or h.stun_t > 0.0 or h.downed:
		_end_pull(false)
		return
	var fe := f as Ent
	pull["left"] = float(pull["left"]) - dt
	var rdf := rmb_def()
	var to := Vector2(h.pos.x - fe.pos.x, h.pos.z - fe.pos.z)
	var dist := to.length()
	var gap := float(rdf["gap"])
	var node: Node3D = pull["node"]
	if is_instance_valid(node):
		var a := h.pos + Vector3(0, 1.1, 0); var b := fe.pos + Vector3(0, 0.9, 0)
		node.global_position = (a + b) * 0.5
		if a.distance_to(b) > 0.2: node.look_at(b, Vector3.UP)
		(node.get_child(0) as MeshInstance3D).scale = Vector3(1.0, 1.0, maxf(0.1, a.distance_to(b)))
	if dist <= gap + 0.05:
		_end_pull(true)
		return
	if float(pull["left"]) <= 0.0:
		_end_pull(false)
		return
	fe.stun_t = maxf(fe.stun_t, 0.2)        # carried: they can't act or walk off the rope
	var left := minf(float(rdf["pull_speed"]) * dt, dist - gap)
	var dir := to / dist
	var moved := 0.0
	while moved < left - 0.001:
		var s := minf(0.2, left - moved)
		var nx := fe.pos.x + dir.x * s; var nz := fe.pos.z + dir.y * s
		var bx: float = m.world.occupy(nx, fe.pos.z, fe.r, fe.pos.y, false)
		var bz: float = m.world.occupy(fe.pos.x, nz, fe.r, fe.pos.y, false)
		if bx == 0.0: fe.pos.x = nx
		if bz == 0.0: fe.pos.z = nz
		if bx != 0.0 and bz != 0.0:
			break
		moved += s
	if moved < left - 0.001 and moved < 0.001:
		snags += 1
		m.fx.word(fe.pos + Vector3(0, 2.2, 0), "WALLED", Color("c0b0a0"), false)
		_end_pull(false)

func _end_pull(arrived: bool) -> void:
	var f = pull.get("t")
	var n: Node3D = pull.get("node")
	if n and is_instance_valid(n):
		self_nodes.erase(n)
		n.queue_free()
	pull = {}
	play("dr_pullend")
	if arrived and is_instance_valid(f) and not (f as Ent).dead:
		arrivals += 1
		var rdf := rmb_def()
		KitStatus.apply(f, "gnd", float(rdf["ground_t"]))
		(f as Ent).vel.x = 0.0; (f as Ent).vel.z = 0.0
		payoff_fx((f as Ent).pos, "HAULED", col_of(rdf), "pay_salvage", h.aim_dir(), f)

# ------------------------------------------------------------------ E: Anchor Drop
func cast_e() -> bool:
	if wind > 0.0 or not pull.is_empty():
		return false
	wind = float(e_def()["windup"])
	play("dr_anchor")
	m.fx.word(h.pos + Vector3(0, 2.9, 0), "!", col_of(e_def()), true)
	m.sfx("charge", h.pos, -5.0, 0.7)
	return true

func use_e() -> void:
	if not pull.is_empty():
		h._ab_feedback("k1", "deny")          # only the barge works while reeling
		return
	super.use_e()

func _anchor() -> void:
	var ed := e_def()
	var dd := h.aim_dir()
	anchors += 1
	var height := 0.0
	var gy: float = m.world.ground_at(h.pos.x, h.pos.z)
	var over_void := gy <= World.VOID + 1.0
	if not h.grounded and not over_void:
		height = clampf(h.pos.y - gy, 0.0, 12.0)
	var air_k := 1.0 + (float(ed["air_max"]) * clampf(height / float(ed["air_h"]), 0.0, 1.0) if rank("kin") >= 3 else 0.0)
	var amt := float(ed["dmg"]) * air_k
	var stun := float(ed["stun"]) + 0.1 * float(maxi(0, rank("kin") - 1))
	var stg := stage("e", {"delivery": {"type": "cone", "radius": float(ed["radius"]), "angle": float(ed["angle"])},
		"effects": [{"type": "damage", "amount": amt}, {"type": "stun", "duration": stun}]})
	run(stg, cx("e", "anchor_drop", aim(), {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if not is_instance_valid(f) or f.dead: return
		f.vel.y = minf(f.vel.y, -16.0)
		KitStatus.apply(f, "gnd", float(ed["gnd_t"]))
		Feel.hitstop(m, h, f, 30.0, {"melee": true, "heavy": true})
		m.fx.word(f.pos + Vector3(0, 2.3, 0), "ANCHORED", col_of(ed), false)}))
	m.fx.cone(h.pos + Vector3(0, 0.1, 0), dd, float(ed["radius"]), col_of(ed))
	m.fx.ring(h.pos + Vector3(dd.x, 0, dd.y) * 1.8, 1.2, col_of(ed), 0.25)
	m.fx.dust(h.pos + Vector3(dd.x, 0, dd.y) * 1.8, 14)
	m.sfx("dr_anchor", h.pos, -1.0, 1.0)
	Feel.shake(m, "t3", h, h.pos)
	if h.is_local(): Oomph.punch_dir(m, dd, 0.25)
	if not h.grounded and not over_void:
		h.gliding = false
		h.vel.y = -float(ed["dive"])          # driven down after it (never over the abyss)
	st["dive_vy"] = h.vel.y               # (tests) what the Anchor left your fall speed at
	lock_until = m.time + float(dash_def()["lock_t"])
	net_ring(h.pos, float(ed["radius"]), col_of(ed))

# ------------------------------------------------------------------ dash: Barge
func on_dash(use_ex: bool) -> bool:
	if wind > 0.0:
		return true
	var dd := dash_def()
	var dir := h.aim_dir()
	if m.time < lock_until:
		# just after the Anchor the barge can't turn far from where you face
		var fwd := Vector2(-sin(h.face), -cos(h.face))
		var lim := deg_to_rad(float(dd["lock_deg"]))
		var ang := fwd.angle_to(dir)
		if absf(ang) > lim:
			dir = fwd.rotated(clampf(ang, -lim, lim))
	if use_ex and not h.grounded:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.2)), float(h.cdat.get("ex_time", 0.21)), {"invuln": 0.08, "trail": "dust", "dir": dir}, true)
		play("dr_barge")
		return true
	if not spend_dash(false):
		return true
	var pk := power("dash") / maxf(0.01, m.dmg_mult(h))
	travel(float(dd["dist"]), float(dd["time"]), {"invuln": 0.06, "shove": true, "shove_kb": float(dd["hit_kb"]), "shove_dmg": float(dd["hit_dmg"]) * pk, "trail": "dust", "dir": dir})
	st["last_dash"] = "barge"
	play("dr_barge")
	h.glide_cd = maxf(h.glide_cd, float(dd["time"]) + 0.35)
	m.sfx("ab_whirr", h.pos, -4.0, 0.6)
	return true

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null or not pull.is_empty() or wind > 0.0:
		return
	var tf := tgt as Ent
	# the Anchor on a foe that has just landed Grounded, or any foe up close
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < float(e_def()["radius"]) - 0.4 and los:
		h.inp["aim"] = tgt.pos; h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and not flying and los and dist > 4.5 and dist < float(rmb_def()["range"]) - 1.0 and (tf.mass() < 6.0):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0); h.inp["sec"] = true; return
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and dist > 3.0 and dist < 6.0 and randf() < 0.2:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
