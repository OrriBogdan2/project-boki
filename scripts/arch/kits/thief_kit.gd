class_name ThiefKit
extends ArchKit
## Thief (light), kits2: a port of SUPERVIVE's Shiv, ability by ability (supervive.wiki.gg), scaled to
## our health and TTK; only the names, art, sounds and on-screen text are ours. docs/ARCHETYPES.md.
##
## - Passive, Marks (Malice & Resolve): every weapon hit stacks a Mark on the target (gold diamonds over
##   their head, up to 5): each makes your weapon hits on them stronger. A knock or an assist heals you.
## - Dash, Vault (Quickflip): a short flip and a burst of speed; the next weapon hit is Primed (+damage,
##   2 Marks, Shred) and landing it resets Vault (the payoff: T4, pay_cashin, VAULT RESET).
## - RMB, Bola (Chain Bolas): grounds the first foe it wraps and flies on; a second foe caught and both
##   are stunned with bonus damage.
## - E, Shadow Knife (Farstep Dagger): a dagger that sticks to a foe (slows) or a surface; recast to step
##   to it, or you step there when it runs out.
## - R, Jackpot (Fusillade): after a fuse, 2s of knives at everyone near (5 each), harder with
##   anti-heal at the rim, each one refreshing every Mark; two quick weaker Vaults; you keep firing.

var primed_t := 0.0            # Vault primed the next weapon hit
var haste_t := 0.0             # Vault's burst of speed (ends on the Primed hit)
var quick := 0                 # Jackpot's free quick Vaults
var quick_t := 0.0
var mark_gap := {}             # target id -> time of its last Mark from us (one per 0.3s)
var pips := {}                 # target instance id -> {node, t: Ent}: the Mark pips over their head
var knife := {}                # the stuck Shadow Knife: {target, pos, node}
var bola2 := {}                # the Bola flying on after its first foe: {pos, dir, left, first, node}
var fus := {}                  # the running Jackpot: {t, next, n}
var glint: Node3D = null       # the Primed tell: a gold glint at the weapon hand
var primed_hits := 0           # (tests, demo)
var bola_pairs := 0
var jackpot_hits := 0

func _setup() -> void:
	res = 0.0

# ---- Marks live on the targets: meta "marks" {thief nid: [count, time left]} ----
func marks_on(t: Ent) -> int:
	if t == null or not is_instance_valid(t):
		return 0
	var mk: Dictionary = t.get_meta("marks", {})
	var e: Array = mk.get(h.nid, [0, 0.0])
	return int(e[0]) if float(e[1]) > 0.0 else 0

func add_mark(t: Ent, n := 1, force := false) -> void:
	if t == null or not is_instance_valid(t) or t.dead or t.team == h.team or n <= 0:
		return
	var now: float = m.time
	if not force and now - float(mark_gap.get(t.get_instance_id(), -9.0)) < float(res_def().get("gap", 0.3)):
		return
	mark_gap[t.get_instance_id()] = now
	var mk: Dictionary = t.get_meta("marks", {})
	var e: Array = mk.get(h.nid, [0, 0.0])
	var had := int(e[0]) if float(e[1]) > 0.0 else 0
	var c := mini(mark_max(), had + n)
	mk[h.nid] = [c, float(res_def().get("dur", 4.0))]
	t.set_meta("marks", mk)
	t.set_meta("marks_t", now)
	_pip_pop(t, c)
	if c >= mark_max() and had < mark_max():
		m.sfx("pickup", t.pos, -2.0, 1.9)       # the victim hears a coin jingle at full Marks
		m.sfx("unlock", t.pos, -6.0, 1.7)
		m.fx.word(t.pos + Vector3(0, 2.5, 0), "MARKED", res_col(), true)
		m.fx.ring(t.pos, 1.3, res_col(), 0.3)
		net_ring(t.pos, 1.3, res_col())

func clear_marks(t: Ent) -> void:
	var mk: Dictionary = t.get_meta("marks", {})
	mk.erase(h.nid)
	t.set_meta("marks", mk)

func mark_max() -> int:
	return int(res_def().get("max", 5))

## Sets a target's Marks outright (the Bola pooling two foes' Marks at rank 3).
func set_marks(t: Ent, n: int) -> void:
	if t == null or not is_instance_valid(t) or t.dead:
		return
	var mk: Dictionary = t.get_meta("marks", {})
	mk[h.nid] = [mini(mark_max(), n), float(res_def().get("dur", 4.0))]
	t.set_meta("marks", mk)
	_pip_pop(t, n)

## Every Mark we have on anyone back to its full time (Jackpot).
func refresh_marks() -> void:
	for f in m.foes_of(h.team):
		var mk: Dictionary = f.get_meta("marks", {}) if f.has_meta("marks") else {}
		if mk.has(h.nid) and int(mk[h.nid][0]) > 0:
			mk[h.nid][1] = float(res_def().get("dur", 4.0))
			_pip_pop(f, int(mk[h.nid][0]))

# ---- Marks you can read from across the fight: gold diamonds orbiting over the target's head, one per
# Mark (five at most), spinning faster as they stack (everyone sees them, the victim included) ----
func _pip_node(t: Ent) -> Dictionary:
	var key := t.get_instance_id()
	if pips.has(key) and is_instance_valid(pips[key]["node"]):
		return pips[key]
	var n := Node3D.new()
	n.top_level = true
	var gold := res_col()
	var ds: Array = []
	for i in mark_max():
		var d := MeshInstance3D.new()
		d.mesh = Models.box(0.28, 0.28, 0.28)
		d.material_override = Models.glow_mat(Color(gold, 0.95))
		d.rotation = Vector3(0.0, 0.0, PI * 0.25)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(d)
		ds.append(d)
	m.add_child(n)
	pips[key] = {"node": n, "t": t, "d": ds, "pop": 0.0}
	return pips[key]

func _pip_pop(t: Ent, _c: int) -> void:
	var p := _pip_node(t)
	p["pop"] = 1.0

func _tick_pips(dt: float) -> void:
	for key in pips.keys():
		var p: Dictionary = pips[key]
		var t: Ent = p["t"]
		var n: Node3D = p["node"]
		var c := marks_on(t) if is_instance_valid(t) and not t.dead else 0
		if c <= 0 or not is_instance_valid(n):
			if is_instance_valid(n): n.queue_free()
			pips.erase(key)
			continue
		var top := 2.7 if t is Hunter else 1.9
		n.global_position = t.position + Vector3(0, top, 0)
		p["pop"] = maxf(0.0, float(p["pop"]) - dt * 4.0)
		var a: float = m.time * (1.6 + 0.6 * c)
		var ds: Array = p["d"]
		for i in ds.size():
			var d: MeshInstance3D = ds[i]
			var ang := a + TAU * i / float(ds.size())
			d.position = Vector3(cos(ang) * 0.68, 0.0, sin(ang) * 0.68)
			var lit := i < c
			d.scale = Vector3.ONE * ((1.0 + float(p["pop"]) * 0.8 + (0.15 * sin(m.time * 9.0) if c >= ds.size() else 0.0)) if lit else 0.5)
			d.material_override.set_shader_parameter("color", Color(res_col(), 1.0) if lit else Color(1, 1, 1, 0.22))

## Highest mark count on any foe (the resource readout).
func best_marks() -> int:
	var b := 0
	for f in m.foes_of(h.team):
		b = maxi(b, marks_on(f))
	return b

func res_frac() -> float:
	return float(best_marks()) / float(mark_max())

func res_text() -> String:
	return "%d/%d" % [best_marks(), mark_max()]

## The payoff is armed: the next weapon hit is Primed.
func full_ready() -> bool:
	return primed_t > 0.0

func dash_payoff_ready() -> bool:
	return primed_t > 0.0

func ready_label() -> String:
	return "PRIMED  ·  land it to reset Vault" if primed_t > 0.0 else ""

## The payoff lives on the dash: the right click's slot never shows the gold dot.
func slot_info(slot: String) -> Dictionary:
	var out := super.slot_info(slot)
	if slot in ["sec", "utility"]: out["full"] = false
	return out

func _tick(dt: float) -> void:
	haste_t = maxf(0.0, haste_t - dt)
	if primed_t > 0.0:
		primed_t -= dt
		if primed_t <= 0.0:
			primed_t = 0.0
			m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color(res_col(), 0.6), 6, 1.5, 0.3, -1.0, 0.7)
	if quick_t > 0.0:
		quick_t -= dt
		if quick_t <= 0.0: quick = 0
	_tick_pips(dt)
	# marks fade on every target we've touched
	for f in m.foes_of(h.team):
		var mk: Dictionary = f.get_meta("marks", {}) if f.has_meta("marks") else {}
		if mk.has(h.nid):
			var e: Array = mk[h.nid]
			e[1] = float(e[1]) - dt
			if float(e[1]) <= 0.0: mk.erase(h.nid)
	_tick_knife()
	if not bola2.is_empty(): _tick_bola2(dt)
	if not fus.is_empty(): _tick_fus(dt)
	_tick_glint()
	_tick_jackpot_tele()
	net_pulse(dt, full_ready())

## The Primed tell: a gold glint and a light at the weapon hand (everyone sees it).
func _tick_glint() -> void:
	if glint == null or not is_instance_valid(glint):
		glint = own_node()
		var ball := MeshInstance3D.new()
		ball.mesh = Models.sphere(0.16, 10)
		ball.material_override = Models.glow_mat(Color(res_col().lightened(0.3), 1.0))
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glint.add_child(ball)
		var lt := OmniLight3D.new()
		lt.light_color = res_col()
		lt.omni_range = 2.6
		lt.light_energy = 1.8
		glint.add_child(lt)
	glint.visible = primed_t > 0.0 and tells_visible()
	if glint.visible:
		var d := h.aim_dir()
		glint.global_position = h.position + Vector3(d.x * 0.55, 1.0 * float(h.cdat.get("scale", 1.0)), d.y * 0.55)
		var k := 1.3 + 0.3 * sin(m.time * 14.0)
		glint.scale = Vector3.ONE * k
		if randf() < 0.3: m.fx.burst(glint.global_position, res_col(), 1, 0.8, 0.25, -1.0, 0.6)

func move_k() -> float:
	return 1.0 + (float(dash_def().get("haste", 0.3)) if haste_t > 0.0 else 0.0)

# ------------------------------------------------------------------ dash: Vault
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if quick > 0 and quick_t > 0.0:
		# Jackpot's quick Vaults: shorter, free
		quick -= 1
		travel(float(dd["quick_dist"]), float(dd["quick_time"]), {"invuln": 0.08, "phase": 0.2, "trail": "ghost"})
		_vaulted(true)
		return true
	if not spend_dash(use_ex):
		return true
	if use_ex:
		travel(float(h.cdat.get("ex_dist", 5.0)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1, "trail": "ghost"}, true)
	else:
		travel(float(dd["dist"]), float(dd["time"]), {"invuln": float(dd["invuln"]), "phase": 0.3, "trail": "ghost"})
	_vaulted(false)
	return true

## After a Vault: the flip's afterimages, the speed, and the next weapon hit Primed.
func _vaulted(quick_one: bool) -> void:
	var dd := dash_def()
	play(flip_for(h.roll_dir, "thf_vault"))
	_afterimage()
	var t := float(dd["quick_time"] if quick_one else dd["time"])
	m.later(t * 0.5, func(): if is_instance_valid(h): _afterimage())
	haste_t = float(dd["haste_t"])
	var was := primed_t > 0.0
	primed_t = float(dd["primed_t"])
	m.sfx("swipe", h.pos, -5.0, 2.1)
	m.later(t, func():
		if not is_instance_valid(h): return
		m.fx.ring(h.pos, 0.9, res_col(), 0.2)
		m.sfx("click", h.pos, -6.0 if h.is_local() else -10.0, 2.2))      # the blade turned in the hand: Primed
	if not was:
		armed_fx("", "dash")                     # Primed: the ready ping, a ring everyone sees

## Enemy cue: a smoke afterimage of the Thief where it flipped from.
func _afterimage() -> void:
	m.fx.ghost(h.position, h.face, Color("6a6480"), float(h.cdat["scale"]))
	m.fx.burst(h.pos + Vector3(0, 0.8, 0), Color("8a84a0"), 8, 1.5, 0.3, -1.0)

# ------------------------------------------------------------------ passive hooks
## Marks make your weapon hits (and the Primed hit) on that target stronger.
func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	var weapon := String(o.get("src", "")) == "shot" and String(o.get("ab", "")) == ""
	if not weapon and not (o.get("tags", []) as Array).has("primed"):
		return dmg
	return dmg * (1.0 + float(res_def().get("per_mark", 0.08)) * float(marks_on(t)))

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or t.dead:
		return
	if String(o.get("src", "")) != "shot" or String(o.get("ab", "")) != "":
		return          # only your weapon's hits stack (and spend the Prime)
	if primed_t > 0.0:
		_primed_hit(t)
		return
	add_mark(t, 1)

## The Primed hit: +damage, 2 Marks and Shred, the speed boost ends, and landing it resets Vault (the
## payoff: T4 hitstop and shake, pay_cashin, VAULT RESET).
func _primed_hit(t: Ent) -> void:
	var dd := dash_def()
	primed_t = 0.0
	haste_t = 0.0
	primed_hits += 1
	play("thf_primed")
	var dir := Vector2(t.pos.x - h.pos.x, t.pos.z - h.pos.z).normalized()
	t.hurt(float(dd["prime_dmg"]) * power("dash") * (1.2 if rank("dash") >= 3 else 1.0), h, {"src": "abil", "ab": "dodge", "tags": ["dodge", "primed"], "crit": true, "melee": true, "kb": dir * 3.0, "payoff": true})
	if is_instance_valid(t) and not t.dead:
		add_mark(t, int(dd["prime_marks"]), true)
		KitStatus.apply(t, "vul", float(dd["shred_t"]), float(dd["shred"]))
	payoff_fx(t.pos, "VAULT RESET", res_col(), "pay_cashin", dir, t)
	# the loop: landing it gives Vault straight back
	h.dashes = h.max_dashes()
	h._ab_feedback("dash", "ready")

## A rival we hit was knocked (or we assisted): a heal.
func on_knock(t: Hunter, mine: bool) -> void:
	var rd := res_def()
	var amt := h.max_hp * float(rd.get("heal_knock", 0.15) if mine else rd.get("heal_assist", 0.25))
	h.heal(amt)
	m.fx.word(h.pos + Vector3(0, 2.5, 0), "TAKEN" if mine else "ASSIST", res_col(), false)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("7fe08a"), 14, 2.5, 0.5, -2.0)
	if is_instance_valid(t): clear_marks(t)

# ------------------------------------------------------------------ RMB: Bola
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var bd: Dictionary = rmb_def()["bola"]
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(bd["speed"]), "range": float(bd["range"]), "size": 0.3},
		"effects": [{"type": "damage", "amount": float(bd["dmg"])}, {"type": "slow", "duration": _ground_t(), "strength": float(bd["slow"])}]})
	var done := {}
	play("thf_bola")
	m.sfx("ab_whirr", h.pos, -5.0, 1.7)
	m.later(0.14, func():
		if not is_instance_valid(h) or busy(): return
		run(stg, cx("rmb", "bola", aim(), {"on_foe": func(f: Ent, _c: Dictionary):
			if done.has("first") or not is_instance_valid(f): return
			done["first"] = true
			_wrap(f)}))
		Feel.cast_sound(m, "projectile", "control", h.pos, h))
	net_bolt(h.pos + Vector3(0, 1.0, 0), h.pos + Vector3(h.aim_dir().x, 0, h.aim_dir().y) * float(bd["range"]) + Vector3(0, 1.0, 0), col_of(rmb_def()))

func _ground_t() -> float:
	return float(rmb_def()["bola"]["ground"])

## The Bola wraps its first foe: Grounded and a Mark, then it flies on past them.
func _wrap(f: Ent) -> void:
	var bd: Dictionary = rmb_def()["bola"]
	KitStatus.apply(f, "gnd", _ground_t())
	add_mark(f, 1, true)
	m.sfx("ab_tether", f.pos, -3.0, 1.4)
	var dir := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z).normalized()
	if dir.length() < 0.1: dir = h.aim_dir()
	var n := own_node()
	var ball := MeshInstance3D.new()
	ball.mesh = Models.sphere(0.18, 8)
	ball.material_override = Models.glow_mat(Color(col_of(rmb_def()), 1.0))
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ball)
	var left := float(bd["after"]) + (float(bd["after_r3"]) if rank("sec") >= 3 else 0.0)
	bola2 = {"pos": f.pos + Vector3(0, 0.9, 0), "dir": dir, "left": left, "first": f, "node": n}
	n.global_position = bola2["pos"]

## The Bola flying on: the next foe it touches is caught too (TANGLED).
func _tick_bola2(dt: float) -> void:
	var bd: Dictionary = rmb_def()["bola"]
	var step := float(bd["speed"]) * dt
	var p: Vector3 = bola2["pos"]
	var dir: Vector2 = bola2["dir"]
	var q := p + Vector3(dir.x, 0, dir.y) * step
	var n: Node3D = bola2["node"]
	if m.world.is_block(q.x, q.z) or float(bola2["left"]) <= 0.0:
		_end_bola2()
		return
	bola2["pos"] = q
	bola2["left"] = float(bola2["left"]) - step
	if is_instance_valid(n): n.global_position = q
	var first = bola2["first"]
	for o in m.foes_of(h.team):
		if o != first and o.hittable() and Vector2(o.pos.x - q.x, o.pos.z - q.z).length() < o.r + 0.5 and absf(o.pos.y + 0.9 - q.y) < 1.6:
			_tangle(first, o)
			_end_bola2()
			return

func _end_bola2() -> void:
	var n: Node3D = bola2.get("node")
	if n and is_instance_valid(n):
		self_nodes.erase(n)
		n.queue_free()
	bola2 = {}

## Two foes in one Bola: both Grounded, stunned and hurt; at rank 3 they pool their Marks.
func _tangle(f, other: Ent) -> void:
	var bd: Dictionary = rmb_def()["bola"]
	var col := col_of(rmb_def())
	bola_pairs += 1
	KitStatus.apply(other, "gnd", _ground_t())
	var both: Array = [other]
	if f != null and is_instance_valid(f) and not (f as Ent).dead: both.append(f)
	for t in both:
		t.hurt(float(bd["pair_dmg"]) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "bola"], "stun": float(bd["pair_stun"]), "dr": true})
	add_mark(other, 1, true)
	if rank("sec") >= 3 and both.size() == 2:
		var pool := marks_on(both[0]) + marks_on(both[1])
		for t in both: set_marks(t, pool)
	var a: Vector3 = other.pos if both.size() < 2 else (both[1] as Ent).pos
	m.fx.bolt(a + Vector3(0, 0.6, 0), other.pos + Vector3(0, 0.6, 0), col)
	m.fx.bolt(a + Vector3(0, 1.0, 0), other.pos + Vector3(0, 1.0, 0), col.lightened(0.3))
	var mid := (a + other.pos) * 0.5
	m.fx.word(mid + Vector3(0, 2.6, 0), "TANGLED", col, true)
	m.fx.ring(mid, 1.6, col, 0.3)
	m.sfx("ab_stun", mid, -2.0, 1.1)
	Feel.shake(m, "t3", h, mid, other)
	net_bolt(a + Vector3(0, 0.8, 0), other.pos + Vector3(0, 0.8, 0), col)

# ------------------------------------------------------------------ E: Shadow Knife
func in_e() -> bool:
	return not knife.is_empty()

func e_recastable() -> bool:
	return not knife.is_empty()

func cast_e() -> bool:
	play("thf_knife")
	m.later(0.12, func():               # cocked by the ear, then thrown on the key pose
		if not is_instance_valid(h) or busy(): return
		_throw_knife())
	return true

func _throw_knife() -> void:
	var ed := e_def()
	var stg := stage("e", {"delivery": {"type": "projectile", "speed": float(ed["speed"]), "range": float(ed["range"]), "size": 0.2},
		"effects": [{"type": "damage", "amount": float(ed["dmg"])}, {"type": "slow", "duration": float(ed["slow_t"]), "strength": float(ed["slow"])}]})
	run(stg, cx("e", "shadow_knife", aim(), {
		"on_foe": func(f: Ent, _c: Dictionary):
			if knife.is_empty() and is_instance_valid(f) and not f.dead:
				add_mark(f, 1, true)
				_stick(f, f.pos),
		"on_shot_end": func(at: Vector3, _why: String, e: Ent):
			if knife.is_empty() and e == null: _stick(null, ground(at))}))
	Feel.cast_sound(m, "projectile", "damage", h.pos, h)
	m.sfx("ab_throw", h.pos, -4.0, 1.6)

func _stick(f: Ent, at: Vector3) -> void:
	var ed := e_def()
	var n := own_node()
	var blade := MeshInstance3D.new()
	blade.mesh = Models.box(0.12, 0.12, 0.9)
	blade.material_override = Models.glow_mat(Color(col_of(ed), 1.0))
	blade.rotation = Vector3(-0.6, 0.0, 0.0)
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(blade)
	var lt := OmniLight3D.new()
	lt.light_color = col_of(ed)
	lt.omni_range = 2.6
	lt.light_energy = 2.2
	n.add_child(lt)
	var hilt := MeshInstance3D.new()
	hilt.mesh = Models.cyl(0.36, 0.36, 0.04, 20)
	hilt.material_override = Models.glow_mat(Color(col_of(ed), 0.55))
	hilt.position.y = -0.2
	hilt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(hilt)              # a bright ring round it: where you'll step to
	knife = {"target": f, "pos": at, "node": n}
	e_t = float(ed["time"])
	if rank("kin") >= 3:
		cd["e"] = float(cd["e"]) * (1.0 - float(ed["refund_foe"] if f else ed["refund_wall"]))
	if f and rank("dash") >= 3:
		h.dashes = h.max_dashes()           # Vault rank 3: a knife in a foe resets it
		h._ab_feedback("dash", "ready")
	n.global_position = at + Vector3(0, 2.15 if f else 0.3, 0)
	m.fx.ring(at, 0.8, col_of(ed), 0.25)
	m.sfx("ab_plant", at, -6.0, 1.8)
	net_ring(at, 0.8, col_of(ed))

func _tick_knife() -> void:
	if knife.is_empty():
		return
	var n: Node3D = knife["node"]
	var f = knife["target"]
	if f != null and (not is_instance_valid(f) or (f as Ent).dead):
		knife["target"] = null
		f = null
	if f != null:
		knife["pos"] = (f as Ent).pos
	if is_instance_valid(n):
		n.global_position = (knife["pos"] as Vector3) + Vector3(0, 2.15 if f != null else 0.3, 0)
		n.rotation.y = m.time * 3.0
		n.visible = true

func e_recast() -> bool:
	if knife.is_empty():
		return false
	_step_to_knife()
	return true

## It fell out: you step to it anyway.
func _e_end() -> void:
	if not knife.is_empty():
		_step_to_knife()

func _step_to_knife() -> void:
	var k := knife
	knife = {}
	e_t = 0.0
	var n: Node3D = k.get("node")
	if n and is_instance_valid(n):
		self_nodes.erase(n)
		n.queue_free()
	if busy():
		return
	var f = k.get("target")
	play("thf_arrive")
	if f != null and is_instance_valid(f) and not (f as Ent).dead:
		_shadow_step(f)
	else:
		var at: Vector3 = k["pos"]
		if m.world.is_void(at.x, at.z) or m.world.is_block(at.x, at.z):
			return
		var from := h.pos
		m.fx.ghost(h.position, h.face, Color("6a6480"), float(h.cdat["scale"]))
		h.teleport(ground(at))
		h.vel = Vector3.ZERO
		h.gliding = false
		m.fx.bolt(from + Vector3(0, 0.9, 0), h.pos + Vector3(0, 0.9, 0), Color(0.8, 0.95, 1.0, 0.6))
		m.fx.burst(h.pos + Vector3(0, 0.9, 0), Color("c8f0ff"), 14, 3.0, 0.3)
		m.sfx("cloak", h.pos, -3.0, 1.6)
	last_e = "shadow_step"

## Step to the knife in a foe: you appear right at them, on their far side.
func _shadow_step(tgt: Ent) -> void:
	var back := Vector2(sin(tgt.face), cos(tgt.face))      # behind = opposite their facing
	var at := tgt.pos + Vector3(back.x, 0, back.y) * (tgt.r + h.r + 0.35)
	if m.world.is_void(at.x, at.z) or m.world.is_block(at.x, at.z):
		var away := Vector2(tgt.pos.x - h.pos.x, tgt.pos.z - h.pos.z).normalized()
		at = tgt.pos + Vector3(away.x, 0, away.y) * (tgt.r + h.r + 0.35)
	at = ground(at)
	var from := h.pos
	m.fx.ghost(h.position, h.face, Color("6a6480"), float(h.cdat["scale"]))
	h.teleport(at)
	h.vel = Vector3.ZERO
	h.gliding = false
	var dv := Vector2(tgt.pos.x - at.x, tgt.pos.z - at.z)
	if dv.length() > 0.05: h.face = atan2(-dv.x, -dv.y)
	m.fx.burst(at + Vector3(0, 0.9, 0), Color("c8f0ff"), 14, 3.0, 0.3)
	m.fx.bolt(from + Vector3(0, 0.9, 0), at + Vector3(0, 0.9, 0), Color(0.8, 0.95, 1.0, 0.6))
	m.sfx("cloak", at, -3.0, 1.6)
	m.sfx("swipe", at, -4.0, 1.9)
	m.fx.ring(at, 1.0, Color("c8f0ff"), 0.22)
	net_bolt(from + Vector3(0, 0.9, 0), at + Vector3(0, 0.9, 0), Color("c8f0ff"))
	if h.is_local():
		Oomph.punch_dir(m, Vector2(at.x - from.x, at.z - from.z), 0.25)
		if m.cam: m.cam.punch(0.03)

# ------------------------------------------------------------------ R: Jackpot (Fusillade)
func _jackpot_targets() -> Array:
	return foes_in(h.pos, float(r_def()["reach"])).filter(func(f): return sees(f) and not (f is Kin))

func r_can_cast() -> bool:
	return not _jackpot_targets().is_empty()

func r_no_target_text() -> String: return "No one within 8.5m to rob"

## The fuse: crouched, gathering the knives.
func _fuse_start(bond: bool) -> void:
	super._fuse_start(bond)
	play("thf_volley_wind")

## The fuse and the volleys don't plant you or stop your weapon: keep shooting through them.
func can_shoot() -> bool:
	return fire_ok()

func pace() -> float:
	return move_k() * (0.75 if fusing() else 1.0)

## While the fuse runs, everyone sees the two rings: the knife reach and the rim.
func _tick_jackpot_tele() -> void:
	if fusing() and not st.has("jp_tele"):
		var rd := r_def()
		st["jp_tele"] = true
		tele_circle(h.pos, float(rd["reach"]), res_col(), fuse_time())
		tele_circle(h.pos, float(rd["inner"]), Color(res_col(), 0.6), fuse_time())
		net_ring(h.pos, float(rd["reach"]), res_col())
	elif not fusing():
		st.erase("jp_tele")

func cast_r() -> bool:
	var rd := r_def()
	if _jackpot_targets().is_empty():
		return false
	var dur := float(rd["time"])
	fus = {"t": dur, "next": 0.0, "n": int(rd["shots"])}
	play("thf_volley")
	quick = int(rd["quick"])
	quick_t = dur + 0.4
	r_t = dur
	m.fx.word(h.pos + Vector3(0, 2.9, 0), "JACKPOT", res_col(), true)
	m.fx.ring(h.pos, float(rd["reach"]), res_col(), 0.4)
	m.fx.ring(h.pos, float(rd["inner"]), Color(1, 1, 1, 0.7), 0.3)
	m.sfx("pickup", h.pos, -4.0, 1.1)
	return true

## One volley every 0.4s: a knife at every foe in reach and sight (they're picked again each time).
func _tick_fus(dt: float) -> void:
	fus["t"] = float(fus["t"]) - dt
	fus["next"] = float(fus["next"]) - dt
	if float(fus["next"]) <= 0.0 and int(fus["n"]) > 0:
		var rd := r_def()
		fus["n"] = int(fus["n"]) - 1
		fus["next"] = float(rd["time"]) / float(rd["shots"])
		var gold := res_col()
		for f in _jackpot_targets():
			var dist: float = h.flat_dist(f)
			var rim := dist > float(rd["inner"])
			var from := h.pos + Vector3(0, 1.0, 0)
			m.fx.bolt(from, f.pos + Vector3(0, 1.0, 0), Color(gold, 0.9) if rim else Color(Color("c8f0ff"), 0.9))
			net_bolt(from, f.pos + Vector3(0, 1.0, 0), gold)
			m.later(dist / 45.0, func(): _jackpot_hit(f, rim))
		m.sfx("ab_throw", h.pos, -5.0, 1.5)
		for i in 8:
			var a: float = TAU * i / 8.0 + m.time
			m.fx.burst(h.pos + Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6), gold, 2, 8.0, 0.25, 0.0, 0.6, Vector3(cos(a), 0.05, sin(a)), 8.0)
	if float(fus["t"]) <= 0.0:
		fus = {}

func _jackpot_hit(f: Ent, rim: bool) -> void:
	if not is_instance_valid(f) or f.dead or not is_instance_valid(h):
		return
	var rd := r_def()
	var stg := stage("r", {"delivery": {"type": "burst", "origin": "here", "radius": 0.0}, "effects": [{"type": "damage", "amount": float(rd["dmg"]) * r_k()}]})
	var c := cx("r", "jackpot", f.pos, {"at": f.pos})
	KinExec.apply_foe(stg.effects, f, c, f.pos, stg)
	jackpot_hits += 1
	refresh_marks()            # every knife refreshes all your Marks
	if is_instance_valid(f) and not f.dead and rim:
		f.hurt(float(rd["rim_dmg"]) * r_k() * m.dmg_mult(h), h, {"src": "abil", "ab": "ult", "tags": ["ult", "jackpot_rim"], "crit": true})
		if f.blight_t <= 0.0: m.fx.word(f.pos + Vector3(0, 2.2, 0), "BLIGHTED", Color("b0e070"), false)
		KitStatus.apply(f, "blt", float(rd["blight"]))
	m.sfx("slash_hit", f.pos, -6.0, 1.3)
	m.fx.burst(f.pos + Vector3(0, 1.0, 0), res_col(), 6, 3.0, 0.25)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	# the dagger is stuck in them: step to them
	if not knife.is_empty() and knife.get("target") != null and randf() < 0.6:
		h.inp["sig"] = true
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and los and dist < float(r_def()["reach"]) - 0.5 and (tgt is Hunter or randf() < 0.3) and randf() < 0.45:
		h.inp["ult"] = true
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and knife.is_empty() and los and dist > 1.5 and dist < float(e_def()["range"]) - 1.0 and randf() < 0.35:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < float(rmb_def()["bola"]["range"]) - 1.0:
		# best when someone stands behind them along the throw (the Bola flies on and catches both)
		var pair := false
		var dv := h.dir_to(tgt)
		for o in m.foes_of(h.team):
			if o != tgt and o.hittable() and tgt.flat_dist(o) < float(rmb_def()["bola"]["after"]) and dv.dot(tgt.dir_to(o)) > 0.8: pair = true
		if pair or tgt is Hunter or randf() < 0.35:
			h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
			h.inp["sec"] = true
	# Vault to Prime the next hit when it will land; flip across them
	var reach := 2.8 if h.wid == "twin_blades" else 6.5
	if int(h.slot_lv["dash"]) > 0 and primed_t <= 0.0 and (h.dashes >= 1.0 or quick > 0) and los and dist < reach + 1.5 and randf() < 0.35:
		var side := h.dir_to(tgt).rotated(PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
		if h.wid == "twin_blades" and dist > 2.0: side = (h.dir_to(tgt) + side * 0.5).normalized()
		h.ai["dash_dir"] = side
		h.inp["move"] = side
		h.inp["dash"] = true
