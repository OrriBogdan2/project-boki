class_name BulwarkKit
extends ArchKit
## Bulwark (heavy): the squad's shield. docs/ARCHETYPES.md §6.6 and "Kit loops" (kits4: rebuilt on an
## Oath-style shield-tank baseline; mechanics only, names and numbers our own).
##
## - LMB (Tower Shield & Mace): tap throws the mace (it passes through foes, lies where it lands and
##   shows foes near it to your team; tap again to call it back, hitting on the way); hold charges a
##   Crushing Blow (full at 1.25s, knockback) whose wind-down carries you forward (jump into a glide).
## - RMB: hold to raise the shield (its own HP, regenerates); tap, or let go after a hold, to Bash.
## - Dash: Whirl, a spinning dash that knocks foes aside; dashing while the shield is up is a Shield
##   Charge (invulnerable for its length, a heavier knock).
## - Passive, Guard: damage the shield blocks becomes Guard; at 50 a Bash is a Shield Slam (stun).
##   Payoff, Crushed: a Bash, Shield Charge or full Crushing Blow that knocks a foe into a wall or
##   another foe stuns them and heals you (T4, pay_slam).
## - E, Mending Ground: a healing burst after 1s, at the lying mace (or your aim); it also mends the shield.
## - R, Fissure: a crack runs forward (walls stop it) and stuns, then the ground erupts in slowing
##   pulses; +1 pulse per 50 Guard (spends it).

var wall: Dictionary = {}      # the raised shield (a following verbs wall)
var shield_hp := 160.0
var down_t := 0.0              # seconds since it was lowered (regen after 2s)
var lock_t := 0.0              # broken: locked out
var front_t := 0.0             # the Shield Charge's front guard
var mend := {}                 # Mending Ground waiting to burst: {pos, t}
var fissure := {}              # the running Fissure
var mace := {}                 # the thrown mace: {} in hand, else {st: fly|ground|back, pos, dir, d, hit, node, t}
var lmb_t := -1.0              # how long the attack key has been held with the mace in hand (-1: not)
var lmb_was := false
var bot_smash_t := 0.0
var knock_until := 0.0         # a knock that can Crush is landing (bash, charge, full blow) until this time
var crushed_at := {}           # foe id -> last Crush (one per 0.6s each)
var crushes := 0               # Crushes landed (tests, demo)
var crest: Node3D = null       # the gold crest light while a Shield Slam is armed

func _setup() -> void:
	shield_hp = shield_max()

func shield_max() -> float:
	return float(rmb_def()["shield"]["hp"]) + (60.0 if rank("sec") >= 3 else 0.0)

func full_ready() -> bool:
	return res >= float(res_def().get("slam", 50.0))

func res_text() -> String:
	return "SLAM" if full_ready() else "%d" % int(res)

func ready_label() -> String:
	return "SHIELD SLAM READY" if full_ready() else ""

func add_guard(v: float) -> void:
	var was := res
	add_res(v)
	touch_res()
	for step in [33.0, 66.0, 100.0]:
		if was < step and res >= step:
			m.fx.ring(h.pos, 1.0 + step / 100.0, res_col(), 0.25)      # the shield runes light in steps
	if was < float(res_def().get("slam", 50.0)) and full_ready():
		armed_fx("SLAM READY", "sec")

func on_block(dmg: float, _by) -> void:
	add_guard(dmg * float(res_def().get("per_hp", 0.5)))

func _tick(dt: float) -> void:
	if res_wait <= 0.0:
		add_res(-float(res_def().get("decay", 5.0)) * dt)
	lock_t = maxf(0.0, lock_t - dt)
	front_t = maxf(0.0, front_t - dt)
	var sd: Dictionary = rmb_def()["shield"]
	if not wall.is_empty():
		if not m.verbs.walls.has(wall):
			# broken: locked out for 3s
			wall = {}
			shield_hp = 0.0
			lock_t = float(sd["lock"])
			down_t = 0.0
			m.fx.word(h.pos + Vector3(0, 2.2, 0), "SHIELD BROKEN", Feel.cat_color("damage"), false)
			m.sfx("knock", h.pos, -3.0, 1.4)
		else:
			shield_hp = float(wall["hp"])
			wall["t"] = 99.0
			if h.gliding:
				h.glide_fuel = maxf(0.0, h.glide_fuel - dt / h.glide_max * (float(rmb_def()["surf_heat"]) - 1.0))
			# armed: the shield itself burns gold
			var nd: Node3D = wall.get("node")
			if nd and is_instance_valid(nd):
				var body := nd.get_node_or_null("Body") as MeshInstance3D
				if body: body.material_override.set_shader_parameter("color", Color(res_col() if full_ready() else col_of(rmb_def()), 0.5 if full_ready() else 0.38))
	else:
		down_t += dt
		if down_t >= float(sd["wait"]) and lock_t <= 0.0:
			shield_hp = minf(shield_max(), shield_hp + float(sd["regen"]) * dt)
	_tick_mace(dt)
	if not mend.is_empty():
		mend["t"] = float(mend["t"]) - dt
		if float(mend["t"]) <= 0.0: _mend_burst()
	if not fissure.is_empty():
		_tick_fissure(dt)
	# Guard: three rune pips over the helm (33 / 66 / 100), a gold crest light when a Slam is armed
	self_pips(3, int(res / 33.0 + 0.01), full_ready(), dt)
	_tick_crest()
	net_pulse(dt, full_ready())

func _tick_crest() -> void:
	if crest == null or not is_instance_valid(crest):
		crest = own_node()
		var lt := OmniLight3D.new()
		lt.light_color = res_col()
		lt.omni_range = 3.2
		lt.light_energy = 2.0
		crest.add_child(lt)
	crest.visible = full_ready() and tells_visible()
	if crest.visible:
		crest.global_position = h.position + Vector3(0, 2.3 * float(h.cdat.get("scale", 1.0)), 0)

func move_k() -> float:
	var k := 1.0
	if not wall.is_empty() and h.grounded:
		k *= float(rmb_def()["shield"]["slow"])
	if lmb_t > 0.2:
		k *= 0.55          # winding up the Crushing Blow
	return k

## Behind the raised shield you can't swing or throw.
func fire_ok() -> bool:
	return wall.is_empty()

## The Shield Charge's front guard: hits from the front 140° are blocked (and become Guard).
func incoming(by: Ent, dmg: float, o: Dictionary) -> Array:
	if front_t > 0.0 and by != null and is_instance_valid(by):
		var to := Vector2(by.pos.x - h.pos.x, by.pos.z - h.pos.z)
		var fwd := Vector2(-sin(h.face), -cos(h.face))
		if to.length() > 0.1 and fwd.dot(to.normalized()) > cos(deg_to_rad(70.0)):
			on_block(dmg, by)
			m.fx.flash(h.pos + Vector3(to.normalized().x * 0.6, 1.0, to.normalized().y * 0.6), res_col(), 0.4, 0.05)
			o = o.duplicate(); o.erase("kb"); o.erase("lift")
			return [0.0, o]
	return [dmg, o]

## A Shield Charge counts as being in the fight up front (the dash's own "during E" stand-in).
func in_e() -> bool:
	return not mend.is_empty()

# ------------------------------------------------------------------ Crushed (the payoff)
## A knock that drives a foe into terrain, or into another foe, Crushes it: a stun, a heal for you.
func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or t.dead or m.time > knock_until:
		return
	if String(o.get("src", "")) == "burn" or (o.get("tags", []) as Array).has("crushed"):
		return
	_try_crush(t, Vector2(t.pos.x - h.pos.x, t.pos.z - h.pos.z).normalized())

func _foe_behind(t: Ent, dir: Vector2, reach: float) -> Ent:
	for f in m.foes_of(h.team):
		if f == t or not f.hittable(): continue
		var to := Vector2(f.pos.x - t.pos.x, f.pos.z - t.pos.z)
		if to.length() < reach + f.r and to.length() > 0.05 and to.normalized().dot(dir) > 0.5 and absf(f.pos.y - t.pos.y) < 1.4:
			return f
	return null

func _try_crush(t: Ent, dir: Vector2) -> void:
	if dir.length() < 0.1:
		dir = h.aim_dir()
	if m.time - float(crushed_at.get(t.get_instance_id(), -9.0)) < 0.6:
		return
	var other := _foe_behind(t, dir, 1.6)
	if other == null and not terrain_behind(t, dir, float(res_def().get("crush_reach", 1.5))):
		return
	crushed_at[t.get_instance_id()] = m.time
	var rd := res_def()
	var tgt := t
	m.later(0.02, func():
		if not is_instance_valid(h) or not is_instance_valid(tgt) or tgt.dead: return
		crushes += 1
		tgt.hurt(float(rd.get("crush_dmg", 8.0)) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "crushed"], "payoff": true, "stun": float(rd.get("crush_stun", 0.8)), "dr": true})
		if other and is_instance_valid(other) and not other.dead:
			crushed_at[other.get_instance_id()] = m.time
			other.hurt(float(rd.get("crush_dmg", 8.0)) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "crushed"], "stun": float(rd.get("crush_stun", 0.8)) * 0.6, "dr": true})
		h.heal(float(rd.get("crush_heal", 14.0)))
		payoff_fx(tgt.pos, "CRUSHED", res_col(), "pay_slam", dir, tgt)
		m.fx.dust(tgt.pos, 14))

# ------------------------------------------------------------------ LMB: the mace (throw / Crushing Blow)
func _wk() -> float:
	return float(Data.RARITY[clampi(h.wrar, 0, Data.RARITY.size() - 1)]["dmg"]) * m.dmg_mult(h)

func lmb_override(held: bool, dt: float) -> bool:
	if h.wid != "tower_shield":
		return false
	var pressed := held and not lmb_was
	lmb_was = held
	if not h.can_fire() or h.fire_cd > 0.0:
		if lmb_t >= 0.0 and not h.can_fire():
			lmb_t = -1.0; h.mel_hold = 0.0
		return true
	var md := lmb_def()
	if not mace.is_empty():
		# the mace is out: a press calls it back
		if pressed and String(mace["st"]) != "back":
			_recall()
		return true
	var local := h.ctrl == "local"
	if pressed and not local:
		# a bot: throw from range, wind up a Crushing Blow up close
		var tg := _bot_target()
		if tg == null or h.flat_dist(tg) > 3.4:
			_throw()
			return true
		lmb_t = 0.0
		bot_smash_t = randf_range(0.5, 1.35)
		return true
	if not local:
		if lmb_t >= 0.0:
			lmb_t += dt
			h.mel_hold = lmb_t
			if lmb_t >= bot_smash_t: _smash()
		return true
	if held:
		lmb_t = maxf(lmb_t, 0.0) + dt
		h.mel_hold = lmb_t
		if lmb_t >= float(md["full"]) + 0.4:
			_smash()           # held well past full: it goes off by itself
	elif lmb_t >= 0.0:
		if lmb_t < float(md["tap"]): _throw()
		else: _smash()
	return true

func lmb_def() -> Dictionary:
	return d.get("lmb", {})

func _bot_target() -> Ent:
	var best: Ent = null; var bd := 12.0
	for f in m.foes_of(h.team):
		if f.hittable() and h.flat_dist(f) < bd: bd = h.flat_dist(f); best = f
	return best

## Charge 0..1 of the Crushing Blow being held.
func smash_k() -> float:
	var md := lmb_def()
	return clampf((lmb_t - float(md["tap"])) / maxf(0.05, float(md["full"]) - float(md["tap"])), 0.0, 1.0)

func _smash() -> void:
	var md := lmb_def()
	var k := smash_k()
	lmb_t = -1.0
	h.mel_hold = 0.0
	var full := k >= 0.99
	var dmg := lerpf(float(md["smash_dmg"][0]), float(md["smash_dmg"][1]), k) * _wk()
	var kb := lerpf(float(md["smash_kb"][0]), float(md["smash_kb"][1]), k)
	h.fire_cd = float(md["smash_rate"])
	if full: knock_until = m.time + 0.25
	h._strike(dmg / m.dmg_mult(h), float(md["smash_reach"]), float(md["smash_arc"]), kb, {"heavy": true, "charged": true, "stun": float(md["smash_stun"]) if full else 0.0})
	# the wind-down carries you forward (jump out of it into a glide)
	var dv := h.aim_dir()
	if h.grounded:
		h.vel.x += dv.x * lerpf(3.0, 8.0, k); h.vel.z += dv.y * lerpf(3.0, 8.0, k)
	m.fx.dust(h.pos + Vector3(dv.x, 0, dv.y) * 1.6, 8 + int(10 * k))
	Feel.shake(m, "t3" if full else "t2", h, h.pos)
	if h.is_local(): Oomph.punch_dir(m, dv, 0.15 + 0.25 * k)
	if full:
		m.fx.ring(h.pos + Vector3(dv.x, 0, dv.y) * 1.6, 2.2, res_col(), 0.3)
		m.sfx("ab_slam", h.pos, -2.0, 0.9)
		net_ring(h.pos + Vector3(dv.x, 0, dv.y) * 1.6, 2.2, res_col())

func _throw() -> void:
	var md := lmb_def()
	lmb_t = -1.0
	h.mel_hold = 0.0
	h.fire_cd = float(md["throw_rate"])
	var n := own_node()
	var head := MeshInstance3D.new()
	head.mesh = Models.sphere(0.24, 10)
	head.material_override = Models.toon(Color("b8c4d8"))
	n.add_child(head)
	var haft := MeshInstance3D.new()
	haft.mesh = Models.box(0.08, 0.08, 0.8)
	haft.material_override = Models.toon(Color("6a5040"))
	haft.position = Vector3(0, 0, 0.35)
	n.add_child(haft)
	var at := h.pos + Vector3(0, 1.0, 0)
	n.global_position = at
	mace = {"st": "fly", "pos": at, "dir": h.aim_dir(), "d": 0.0, "hit": {}, "node": n, "t": 0.0}
	h.swing_t = 0.18; h.swing_n += 1
	m.sfx("ab_throw", h.pos, -2.0, 0.7)
	Oomph.on_fire(h, true)
	net_bolt(at, at + Vector3(mace["dir"].x, 0, mace["dir"].y) * float(md["throw_range"]), Color("d8e8ff"))

func _recall() -> void:
	mace["st"] = "back"
	mace["hit"] = {}
	m.sfx("ab_whirr", mace["pos"], -4.0, 0.8)

func _mace_hit(f: Ent, dmg: float, dir: Vector2) -> void:
	f.hurt(dmg * _wk(), h, {"src": "abil", "ab": "primary", "tags": ["primary", "mace"], "kb": dir * 3.0, "melee": true})

func _tick_mace(dt: float) -> void:
	if mace.is_empty():
		return
	var md := lmb_def()
	var n: Node3D = mace["node"]
	if not is_instance_valid(n) or h.downed or h.out:
		if is_instance_valid(n): n.queue_free()
		mace = {}
		return
	var p: Vector3 = mace["pos"]
	match String(mace["st"]):
		"fly":
			var dir: Vector2 = mace["dir"]
			var step := float(md["throw_speed"]) * dt
			var q := p + Vector3(dir.x, 0, dir.y) * step
			mace["d"] = float(mace["d"]) + step
			var g: float = m.world.ground_at(q.x, q.z)
			var blocked: bool = m.world.is_block(q.x, q.z) or g > p.y - 0.2
			if not blocked: p = q
			for f in foes_in(p, 0.9, 1.8):
				if not (mace["hit"] as Dictionary).has(f.get_instance_id()):
					mace["hit"][f.get_instance_id()] = true
					_mace_hit(f, float(md["throw_dmg"]), dir)
			n.rotation = Vector3(m.time * 18.0, atan2(dir.x, dir.y), 0.0)
			if blocked or float(mace["d"]) >= float(md["throw_range"]):
				var gy: float = m.world.ground_at(p.x, p.z)
				if gy <= World.VOID + 1.0:
					mace["st"] = "back"; mace["hit"] = {}       # over the abyss: it comes straight back
				else:
					p = Vector3(p.x, gy + 0.15, p.z)
					mace["st"] = "ground"; mace["t"] = 0.0
					n.rotation = Vector3(PI * 0.5, randf() * TAU, 0.0)
					m.fx.dust(p, 8)
					m.sfx("thump", p, -4.0, 0.8)
					net_ring(p, 1.2, Color("d8e8ff"))
		"ground":
			mace["t"] = float(mace["t"]) + dt
			# it shows foes near it to your team (vision where it lies)
			for f in foes_in(p, float(md["vision_r"]), 3.0):
				if "reveal_t" in f: f.set("reveal_t", maxf(float(f.get("reveal_t")), 0.4))
			if int(m.time * 2.0) != int((m.time - dt) * 2.0): m.fx.ring(p, float(md["vision_r"]), Color(Color("d8e8ff"), 0.35), 0.4)
			if Vector2(h.pos.x - p.x, h.pos.z - p.z).length() < 1.2 and absf(h.pos.y - p.y) < 1.5:
				_catch()
				return
			if float(mace["t"]) >= float(md["lie_t"]):
				_recall()
		"back":
			var to := h.pos + Vector3(0, 1.0, 0) - p
			var step := float(md["recall_speed"]) * dt
			var dir2 := Vector2(to.x, to.z).normalized()
			if to.length() <= step + 0.6:
				_catch()
				return
			p += to.normalized() * step
			for f in foes_in(p, 0.9, 1.8):
				if not (mace["hit"] as Dictionary).has(f.get_instance_id()):
					mace["hit"][f.get_instance_id()] = true
					_mace_hit(f, float(md["recall_dmg"]), dir2)
			n.rotation = Vector3(m.time * 18.0, atan2(dir2.x, dir2.y), 0.0)
	mace["pos"] = p
	n.global_position = p

func _catch() -> void:
	var n: Node3D = mace.get("node")
	if is_instance_valid(n): n.queue_free()
	self_nodes.erase(n)
	mace = {}
	m.sfx("catch", h.pos, -6.0, 0.9)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("d8e8ff"), 8, 2.5, 0.25)

# ------------------------------------------------------------------ RMB: Shield (hold to block, release or tap to Bash)
## The shield is a block, not a charge (the Crushing Blow on LMB is the Bulwark's charge).
func rmb_charge_full() -> float:
	return 0.0

## In the air the press doesn't fire at once: holding it there is Shield Surf.
func press_rmb() -> void:
	if busy():
		h._ab_feedback("sec", "deny")
		return
	if rmb_down:
		return
	rmb_down = true
	rmb_t = 0.0
	rmb_ctx = {"air": not h.grounded or h.gliding, "e": in_e(), "r": r_t > 0.0, "full": full_ready()}
	lmb_t = -1.0; h.mel_hold = 0.0

func rmb_hold_tick(t: float) -> void:
	if t >= float(rmb_def()["hold"]) and wall.is_empty() and lock_t <= 0.0 and shield_hp > 5.0:
		_raise()

func _raise() -> void:
	var sd: Dictionary = rmb_def()["shield"]
	var d := h.aim_dir()
	wall = m.verbs.add_wall(h, h.pos + Vector3(d.x, 0, d.y) * 1.0, d, {"length": float(sd["len"]), "hp": shield_hp, "time": 99.0, "follow": true, "dist": 0.95, "block": "enemy", "color": rmb_def().get("col", "#9ad8ff")}, 1.0)
	h.mel_hold = 0.0
	last_variant = "air" if rmb_ctx.get("air", false) else "hold"

func _lower() -> void:
	if wall.is_empty():
		return
	shield_hp = float(wall["hp"])
	if m.verbs.walls.has(wall):
		m.verbs.walls.erase(wall)
		if is_instance_valid(wall["node"]): (wall["node"] as Node3D).queue_free()
	wall = {}
	down_t = 0.0

func fire_rmb(c: Dictionary) -> void:
	var was_up := not wall.is_empty()
	_lower()
	if c.get("air", false) and was_up:
		return                    # a Shield Surf just ends
	if not rmb_ready():
		if not was_up: h._ab_feedback("sec", "deny")
		return
	# a tap, or letting go after a block: the Bash (a Shield Slam with 50 Guard)
	c = c.duplicate()
	c["full"] = full_ready()
	last_variant = "full" if c["full"] else ("hold" if was_up else String(c["variant"]))
	if not spend_rmb(): return
	var bd: Dictionary = rmb_def()["bash"]
	var slam: bool = c["full"]
	var go := func():
		if not is_instance_valid(h) or h.downed: return
		var effs: Array = [{"type": "damage", "amount": float(rmb_def()["slam"]["dmg"]) if slam else float(bd["dmg"])}, {"type": "push", "strength": float(rmb_def()["slam"]["push"]) if slam else float(bd["push"]), "from": "caster"}]
		if slam: effs.append({"type": "stun", "duration": float(rmb_def()["slam"]["stun"])})
		knock_until = m.time + 0.2
		var stg := stage("rmb", {"delivery": {"type": "cone", "radius": float(bd["radius"]), "angle": float(bd["angle"])}, "effects": effs})
		run(stg, cx("rmb", "shield_slam" if slam else "bash", aim(), {"no_floor": true, "hit_extra": {"heavy": true}}))
		var dv := h.aim_dir()
		m.fx.cone(h.pos + Vector3(0, 0.1, 0), dv, float(bd["radius"]), res_col() if slam else col_of(rmb_def()))
		m.fx.flash(h.pos + Vector3(dv.x * 0.9, 1.0, dv.y * 0.9), res_col() if slam else Color("d8e8ff"), 0.9, 0.06)
		m.sfx("shield", h.pos, -1.0, 0.6 if slam else 0.75)
		m.sfx("ab_shield_hit", h.pos, -4.0, 0.8)
		Feel.shake(m, "t3" if slam else "t2", h, h.pos)
		if h.is_local(): Oomph.punch_dir(m, dv, 0.3 if slam else 0.18)
		if h.grounded:
			h.vel.x += dv.x * 4.0; h.vel.z += dv.y * 4.0         # you step into it
	if slam:
		# Shield Slam spends 50 Guard; a 0.3s shield flare is the tell
		res -= float(res_def().get("slam", 50.0))
		m.fx.flash(h.pos + Vector3(h.aim_dir().x * 0.8, 1.0, h.aim_dir().y * 0.8), res_col(), 0.9, float(rmb_def()["slam"]["tell"]))
		tele_lane(h.pos, h.aim_dir(), float(bd["radius"]), 2.0, Feel.cat_color("control"), float(rmb_def()["slam"]["tell"]))
		net_ring(h.pos, 1.6, res_col())
		m.later(float(rmb_def()["slam"]["tell"]), go)
	else:
		go.call()

func fire_ok_rmb() -> bool:
	return lock_t <= 0.0

# ------------------------------------------------------------------ dash: Whirl / Shield Charge
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if not wall.is_empty() and h.grounded:
		# Shield Charge: behind the raised shield, invulnerable for its length, a heavier knock
		if not spend_dash(false): return true
		var dist := float(dd["charge"]) + (1.0 if rank("dash") >= 3 else 0.0)
		var t := dist / float(dd["charge_speed"])
		travel(dist, t, {"invuln": t + 0.08, "shove": true, "shove_kb": float(dd["charge_kb"]), "shove_dmg": float(dd["charge_dmg"]), "trail": "dust", "dir": h.aim_dir()})
		front_t = t + 0.15
		knock_until = m.time + t + 0.1
		st["last_dash"] = "charge"
		m.fx.word(h.pos + Vector3(0, 2.3, 0), "SHIELD CHARGE", col_of(dd), false)
		m.sfx("shield", h.pos, 0.0, 0.55)
		return true
	if not spend_dash(use_ex):
		return true
	var dist2 := (float(dd["whirl"]) if not use_ex else float(h.cdat.get("ex_dist", 4.2))) + (1.0 if rank("dash") >= 3 else 0.0)
	var t2 := dist2 / float(dd["whirl_speed"])
	travel(dist2, t2, {"invuln": 0.1, "shove": true, "shove_kb": float(dd["whirl_kb"]), "shove_dmg": float(dd["whirl_dmg"]), "trail": "dust"}, use_ex)
	st["last_dash"] = "whirl"
	# the spin: two full slashes around you along the way
	for i in 3:
		m.later(t2 * float(i) / 3.0, func():
			if is_instance_valid(h): m.fx.slash(h.pos + Vector3(0, 0.9, 0), m.time * 9.0, TAU, 1.6, col_of(dd), i == 2))
	m.sfx("ab_whirr", h.pos, -3.0, 1.2)
	return true

# ------------------------------------------------------------------ E: Mending Ground
func cast_e() -> bool:
	var ed := e_def()
	var at := aim_at(float(ed["reach"]))
	if not mace.is_empty() and String(mace["st"]) == "ground":
		at = ground(mace["pos"])          # it grows where the mace lies
	var r := float(ed["radius"]) + (0.5 if rank("kin") >= 3 else 0.0)
	mend = {"pos": at, "t": float(ed["delay"]), "r": r}
	e_t = float(ed["delay"])
	tele_circle(at, r, Feel.cat_color("sustain"), float(ed["delay"]))
	m.fx.burst(at + Vector3(0, 0.4, 0), Feel.cat_color("sustain"), 16, 2.0, 0.6, -2.0, 1.1)
	m.sfx("plant", at, -2.0, 0.9)
	net_ring(at, r, Feel.cat_color("sustain"))
	return true

func _mend_burst() -> void:
	var ed := e_def()
	var at: Vector3 = mend["pos"]
	var r: float = mend["r"]
	mend = {}
	var heal := float(ed["heal"]) + (10.0 if rank("kin") >= 3 else 0.0)
	for o in m.hunters:
		if o.team == h.team and not o.out and not o.downed and Vector2(o.pos.x - at.x, o.pos.z - at.z).length() < r:
			o.heal(heal * (1.0 + 0.15 * float(rank("kin") - 1)))
			m.fx.burst(o.pos + Vector3(0, 1.0, 0), Feel.cat_color("sustain"), 12, 2.5, 0.5, -3.0)
			if o == h:
				shield_hp = minf(shield_max(), shield_hp + float(ed["shield"]))
				if not wall.is_empty() and m.verbs.walls.has(wall): wall["hp"] = minf(float(wall.get("max_hp", shield_max())), float(wall["hp"]) + float(ed["shield"]))
	# the kin's typing rides the burst (a cleanse, a shield, a slow on foes...)
	var stg := stage("e", {"delivery": {"type": "burst", "origin": "aim", "radius": r}, "effects": [{"type": "slow", "duration": 1.0, "strength": float(ed["slow"])}]})
	run(stg, cx("e", "mending_ground", at, {"no_floor": true}))
	m.fx.ring(at, r, Feel.cat_color("sustain"), 0.45)
	m.fx.burst(at + Vector3(0, 0.5, 0), Feel.cat_color("sustain"), 30, 5.0, 0.7, -2.0, 1.4)
	m.sfx("heal", at, 0.0, 0.9)
	net_ring(at, r, Feel.cat_color("sustain"))

# ------------------------------------------------------------------ R: Fissure
## Where the crack runs: along the aim up to its reach, stopped by walls, rocks and rises.
func _fissure_end(dir: Vector2, reach: float) -> float:
	var k := 0.5
	var y0 := h.pos.y
	while k <= reach:
		var q := h.pos + Vector3(dir.x, 0, dir.y) * k
		var g: float = m.world.ground_at(q.x, q.z)
		if m.world.is_block(q.x, q.z) or g > y0 + 0.8 or g <= World.VOID + 1.0:
			return maxf(1.0, k - 0.3)
		k += 0.25
	return reach

func cast_r() -> bool:
	var rd := r_def()
	var dir := h.aim_dir()
	var reach := float(rd["reach"]) + (3.0 if rank("ult") >= 2 else 0.0)
	var length := _fissure_end(dir, reach)
	var pulses := int(rd["pulses"]) + int(floor(res / 50.0))
	res = 0.0          # all Guard goes into the cascade: +1 pulse per 50
	fissure = {"from": h.pos, "dir": dir, "len": length, "front": 0.0, "hit": {}, "wait": 0.0, "erupt": false, "left": pulses, "pt": 0.0}
	r_t = length / float(rd["crack_speed"]) + float(rd["erupt_after"]) + float(rd["every"]) * pulses + 0.2
	tele_lane(h.pos, dir, length, float(rd["width"]), col_of(rd), length / float(rd["crack_speed"]) + float(rd["erupt_after"]))
	m.sfx("ab_slam", h.pos, 0.0, 0.6)
	net_bolt(h.pos + Vector3(0, 0.2, 0), h.pos + Vector3(dir.x, 0, dir.y) * length + Vector3(0, 0.2, 0), col_of(rd))
	return true

## A rock spur that bursts up out of the crack and sinks back (everyone sees the eruption).
func _pillar(at: Vector3, tall: float) -> void:
	var n := MeshInstance3D.new()
	n.mesh = Models.box(0.55, tall, 0.55)
	n.material_override = Models.toon(Color("b08a62"))
	m.add_child(n)
	n.global_position = at + Vector3(0, -tall * 0.5, 0)
	n.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
	var glow := MeshInstance3D.new()
	glow.mesh = Models.box(0.62, 0.12, 0.62)
	glow.material_override = Models.glow_mat(Color(col_of(r_def()), 0.9))
	glow.position = Vector3(0, tall * 0.5, 0)
	n.add_child(glow)
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", at + Vector3(0, tall * 0.45, 0), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.18)
	tw.tween_property(n, "global_position", at + Vector3(0, -tall * 0.55, 0), 0.25)
	tw.tween_callback(n.queue_free)

func _near_line(f: Ent, a: Vector3, b: Vector3, w: float) -> bool:
	var fp := Vector2(f.pos.x, f.pos.z)
	var cp := Geometry2D.get_closest_point_to_segment(fp, Vector2(a.x, a.z), Vector2(b.x, b.z))
	return fp.distance_to(cp) < w * 0.5 + f.r and absf(f.pos.y - a.y) < 2.0

func _tick_fissure(dt: float) -> void:
	var rd := r_def()
	var from: Vector3 = fissure["from"]
	var dir: Vector2 = fissure["dir"]
	var length: float = fissure["len"]
	if not bool(fissure["erupt"]):
		# the crack runs: everyone it passes under is stunned
		var f0 := float(fissure["front"])
		var f1 := minf(length, f0 + float(rd["crack_speed"]) * dt)
		fissure["front"] = f1
		var a := from + Vector3(dir.x, 0, dir.y) * f0
		var b := from + Vector3(dir.x, 0, dir.y) * f1
		m.fx.dust(b, 6)
		m.fx.burst(b + Vector3(0, 0.2, 0), col_of(rd), 8, 4.0, 0.35, 4.0, 1.2)
		m.fx.bolt(a + Vector3(0, 0.08, 0), b + Vector3(0, 0.08, 0), col_of(rd).darkened(0.2))     # the crack itself
		for f in m.foes_of(h.team):
			if f.hittable() and not (fissure["hit"] as Dictionary).has(f.get_instance_id()) and _near_line(f, from, b, float(rd["width"])):
				fissure["hit"][f.get_instance_id()] = true
				f.hurt(float(rd["crack_dmg"]) * r_k(), h, {"src": "abil", "ab": "ult", "tags": ["ult", "fissure"], "stun": float(rd["stun"]), "dr": true, "heavy": true})
				m.fx.word(f.pos + Vector3(0, 2.2, 0), "CRACKED", col_of(rd), false)
		if f1 >= length:
			fissure["erupt"] = true
			fissure["wait"] = float(rd["erupt_after"])
			Feel.shake(m, "t3", h, b)
		return
	if float(fissure["wait"]) > 0.0:
		fissure["wait"] = float(fissure["wait"]) - dt
		return
	fissure["pt"] = float(fissure["pt"]) - dt
	if float(fissure["pt"]) > 0.0:
		return
	fissure["pt"] = float(rd["every"])
	fissure["left"] = int(fissure["left"]) - 1
	# an eruption pulse along the whole line: damage and a slow (the kin's typing rides it)
	var stg := stage("r", {"delivery": {"type": "burst", "origin": "here", "radius": 0.0}, "effects": [{"type": "damage", "amount": float(rd["pulse_dmg"]) * r_k()}, {"type": "slow", "duration": 1.0, "strength": float(rd["slow"])}]})
	var end := from + Vector3(dir.x, 0, dir.y) * length
	for f in m.foes_of(h.team):
		if f.hittable() and _near_line(f, from, end, float(rd["width"]) + 0.4):
			KinExec.apply_foe(stg.effects, f, cx("r", "fissure", f.pos, {"at": f.pos}), f.pos, stg)
	var k := 0.8
	while k < length:
		var q := from + Vector3(dir.x, 0, dir.y) * k
		m.fx.burst(q + Vector3(0, 0.3, 0), col_of(rd), 9, 7.0, 0.5, 9.0, 1.5, Vector3.UP, 20.0)
		_pillar(ground(q), 0.9 + randf() * 0.7)
		m.fx.dust(q, 3)
		k += 1.2
	m.fx.dust(from + Vector3(dir.x, 0, dir.y) * length * 0.5, 10)
	m.sfx("boom", from + Vector3(dir.x, 0, dir.y) * length * 0.5, -6.0, 0.7)
	Feel.shake(m, "t2", h, from + Vector3(dir.x, 0, dir.y) * length * 0.5)
	net_bolt(from + Vector3(0, 0.6, 0), end + Vector3(0, 0.6, 0), col_of(rd))
	if int(fissure["left"]) <= 0:
		fissure = {}

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and los and dist < 11.0 and randf() < 0.4:
		h.inp["aim"] = tgt.pos; h.inp["ult"] = true; return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and (h.hp < h.max_hp * 0.65 or shield_hp < shield_max() * 0.4) and randf() < 0.5:
		h.inp["aim"] = h.pos; h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0:
		var shot_at: bool = m.time - h.hurt_at < 0.6 and dist > 3.0
		if shot_at and lock_t <= 0.0 and shield_hp > 30.0:
			# raise the shield toward whoever is shooting
			h.inp["aim"] = tgt.pos
			if not rmb_down: h.inp["sec"] = true
			bot_hold["rmb"] = 1.0
		elif dist < 2.6 and rmb_ready():
			h.inp["aim"] = tgt.pos; h.inp["sec"] = true
	# close in: a Shield Charge from behind the shield, else a Whirl
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and dist < 4.5 and dist > 1.5 and randf() < 0.3:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
