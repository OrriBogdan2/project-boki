class_name ThiefKit
extends ArchKit
## Thief (light), kits2: a duelist built on a Shiv-style baseline (SUPERVIVE; mechanics only, the
## names, numbers, art and sounds are ours). docs/ARCHETYPES.md "Kit loops".
##
## - Passive, Marks: weapon hits on the same target you hit last stack Marks on them (gold diamonds
##   over their head; +6% damage from you each, up to 3); a hit from behind adds one more. A knock
##   heals you (an assist less) and resets Vault.
## - Dash, Vault: a quick flip and a burst of speed; your next weapon hit is Primed (+damage, 2 Marks,
##   Shred). Landing it resets Vault: shoot, flip, shoot, flip. A Primed hit into 3 Marks Cashes In
##   (the payoff: T4, pay_cashin, the Marks spent).
## - RMB, Bola: grounds the first foe it wraps (no dash, jump or glide); with a second foe close by
##   the cords catch both and stun them.
## - E, Shadow Knife: a dagger that sticks (slows); recast, or wait, to Shadow Step to it.
## - R, Jackpot: after a fuse you can shoot through, a knife at every foe nearby (the rim hits harder
##   and blights); Marks refresh and you get two quick Vaults that cost no charge.

var ambush_t := 0.0            # the next hit counts as from behind (after a Shadow Step)
var primed_t := 0.0            # Vault primed the next weapon hit
var haste_t := 0.0             # Vault's burst of speed
var quick := 0                 # Jackpot's free quick Vaults
var quick_t := 0.0
var chain_tgt: Ent = null      # the target of our last weapon hit (consecutive hits stack Marks)
var chain_at := -9.0
var mark_gap := {}             # target id -> time of its last Mark from us (one per 0.3s)
var pips := {}                 # target instance id -> {node, t: Ent}: the Mark pips over their head
var knife := {}                # the stuck Shadow Knife: {target, pos, node}
var glint: Node3D = null       # the Primed tell: a gold glint at the weapon hand
var cash_ins := 0              # (tests, demo)
var primed_hits := 0
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
	var c := mini(int(res_def().get("max", 3)), had + n)
	mk[h.nid] = [c, float(res_def().get("dur", 5.0))]
	t.set_meta("marks", mk)
	t.set_meta("marks_t", now)
	_pip_pop(t, c)
	if c >= 3 and had < 3:
		m.sfx("pickup", t.pos, -2.0, 1.9)       # the victim hears a coin jingle
		m.sfx("unlock", t.pos, -6.0, 1.7)
		m.fx.word(t.pos + Vector3(0, 2.5, 0), "MARKED", res_col(), true)
		m.fx.ring(t.pos, 1.3, res_col(), 0.3)
		net_ring(t.pos, 1.3, res_col())
		if primed_t > 0.0 or h.dashes >= 1.0 or quick > 0:
			armed_fx("", "dash")                  # a Vault now Cashes In: the dash slot pings

func clear_marks(t: Ent) -> void:
	var mk: Dictionary = t.get_meta("marks", {})
	mk.erase(h.nid)
	t.set_meta("marks", mk)

## Every Mark we have on anyone back to its full time (Jackpot).
func refresh_marks() -> void:
	for f in m.foes_of(h.team):
		var mk: Dictionary = f.get_meta("marks", {}) if f.has_meta("marks") else {}
		if mk.has(h.nid) and int(mk[h.nid][0]) > 0:
			mk[h.nid][1] = float(res_def().get("dur", 5.0))
			_pip_pop(f, int(mk[h.nid][0]))

# ---- Marks you can read from across the fight: gold diamonds orbiting over the target's head that
# light up one by one, and a big spinning coin at 3 (everyone sees them, the victim included) ----
func _pip_node(t: Ent) -> Dictionary:
	var key := t.get_instance_id()
	if pips.has(key) and is_instance_valid(pips[key]["node"]):
		return pips[key]
	var n := Node3D.new()
	n.top_level = true
	var gold := res_col()
	var ds: Array = []
	for i in 3:
		var d := MeshInstance3D.new()
		d.mesh = Models.box(0.3, 0.3, 0.3)
		d.material_override = Models.glow_mat(Color(gold, 0.95))
		d.rotation = Vector3(0.0, 0.0, PI * 0.25)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(d)
		ds.append(d)
	var coin := MeshInstance3D.new()
	coin.mesh = Models.cyl(0.48, 0.48, 0.09, 20)
	coin.material_override = Models.glow_mat(Color(gold.lightened(0.2), 1.0))
	coin.rotation.x = 0.45          # nearly flat: from the top-down camera it reads as a big gold disc
	coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coin.visible = false
	n.add_child(coin)
	m.add_child(n)
	pips[key] = {"node": n, "t": t, "d": ds, "coin": coin, "pop": 0.0}
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
		var a: float = m.time * 2.2
		var ds: Array = p["d"]
		for i in 3:
			var d: MeshInstance3D = ds[i]
			var ang := a + TAU * i / 3.0
			d.position = Vector3(cos(ang) * 0.6, 0.0, sin(ang) * 0.6)
			var lit := i < c
			d.scale = Vector3.ONE * ((1.0 + float(p["pop"]) * 0.8) if lit else 0.55)
			d.material_override.set_shader_parameter("color", Color(res_col(), 1.0) if lit else Color(1, 1, 1, 0.22))
			d.visible = c < 3
		var coin: MeshInstance3D = p["coin"]
		coin.visible = c >= 3
		if coin.visible:
			coin.rotation = Vector3(0.45 * sin(m.time * 6.0), m.time * 6.0, 0.45 * cos(m.time * 6.0))
			coin.scale = Vector3.ONE * (1.0 + 0.15 * sin(m.time * 9.0) + float(p["pop"]) * 0.6)

## Highest mark count on any foe (the resource readout).
func best_marks() -> int:
	var b := 0
	for f in m.foes_of(h.team):
		b = maxi(b, marks_on(f))
	return b

func res_frac() -> float:
	return float(best_marks()) / 3.0

func res_text() -> String:
	return "%d/3" % best_marks()

## The payoff is armed: Primed, with a target at 3 Marks.
func full_ready() -> bool:
	return primed_t > 0.0 and best_marks() >= 3

func dash_payoff_ready() -> bool:
	return best_marks() >= 3 and (primed_t > 0.0 or h.dashes >= 1.0 or quick > 0)

func ready_label() -> String:
	if full_ready(): return "CASH IN READY"
	if primed_t > 0.0: return "PRIMED  ·  next hit"
	return ""

## The payoff lives on the dash now: the right click's slot never shows the gold dot.
func slot_info(slot: String) -> Dictionary:
	var out := super.slot_info(slot)
	if slot in ["sec", "utility"]: out["full"] = false
	return out

func _tick(dt: float) -> void:
	ambush_t = maxf(0.0, ambush_t - dt)
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
		var k := 1.0 + 0.25 * sin(m.time * 14.0) + (0.5 if full_ready() else 0.0)
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
		if best_marks() >= 3: armed_fx("CASH IN READY", "dash")
		else: net_ring(h.pos, 0.9, res_col())

## Enemy cue: a smoke afterimage of the Thief where it flipped from.
func _afterimage() -> void:
	m.fx.ghost(h.position, h.face, Color("6a6480"), float(h.cdat["scale"]))
	m.fx.burst(h.pos + Vector3(0, 0.8, 0), Color("8a84a0"), 8, 1.5, 0.3, -1.0)

# ------------------------------------------------------------------ passive hooks
func outgoing(t: Ent, dmg: float, _o: Dictionary) -> float:
	return dmg * (1.0 + float(res_def().get("per_mark", 0.06)) * float(marks_on(t)))

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or t.dead:
		return
	var src := String(o.get("src", ""))
	var tags: Array = o.get("tags", [])
	if src != "shot" or String(o.get("ab", "")) != "" or tags.has("primed") or tags.has("cash_in"):
		return          # only your weapon's hits stack and spend
	var rd := res_def()
	var n := 0
	if chain_tgt == t and m.time - chain_at < float(rd.get("chain_t", 2.5)):
		n = 1           # the same target again: a Mark
	var back := ambush_t > 0.0 or ArchKit.behind(t, h, float(rd.get("rear_deg", 120.0)))
	if back:
		n += int(rd.get("behind", 1))
		if ambush_t > 0.0:
			ambush_t = 0.0
			m.fx.word(t.pos + Vector3(0, 2.0, 0), "AMBUSH", res_col(), false)
	chain_tgt = t
	chain_at = m.time
	if primed_t > 0.0:
		_primed_hit(t, back)
		return
	add_mark(t, n)

## The Primed hit: +damage, 2 Marks and Shred; into 3 Marks it Cashes In. Landing it resets Vault.
func _primed_hit(t: Ent, back: bool) -> void:
	var dd := dash_def()
	primed_t = 0.0
	primed_hits += 1
	var dir := Vector2(t.pos.x - h.pos.x, t.pos.z - h.pos.z).normalized()
	if marks_on(t) >= 3:
		_cash_in(t, dir)
	else:
		t.hurt(float(dd["prime_dmg"]) * power("dash"), h, {"src": "abil", "ab": "dodge", "tags": ["dodge", "primed"], "crit": true, "melee": true, "kb": dir * 3.0})
		if is_instance_valid(t) and not t.dead:
			add_mark(t, int(dd["prime_marks"]) + (1 if rank("dash") >= 3 else 0) + (int(res_def().get("behind", 1)) if back else 0), true)
			KitStatus.apply(t, "vul", float(dd["shred_t"]), float(dd["shred"]))
		m.fx.word(t.pos + Vector3(0, 2.3, 0), "PRIMED", res_col(), false)
		m.fx.flash(t.pos + Vector3(0, 1.0, 0), res_col().lightened(0.3), 0.7, 0.06)
		m.sfx("crit", t.pos, -3.0, 1.35)
		Feel.shake(m, "t2", h, t.pos, t)
		if h.is_local(): Oomph.punch_dir(m, dir, 0.18)
	# the loop: landing it gives Vault straight back
	h.dashes = h.max_dashes()
	h._ab_feedback("dash", "ready")

## Cash In: the three Marks pay out in one big gold hit (the payoff: T4 hitstop and shake, a coin
## burst, pay_cashin), plus the Shred.
func _cash_in(f: Ent, dir: Vector2) -> void:
	var rd := res_def()
	var bonus := (float(dash_def()["prime_dmg"]) + float(rd.get("cash_dmg", 22.0))) * power("dash")
	clear_marks(f)
	cash_ins += 1
	f.hurt(bonus, h, {"src": "abil", "ab": "dodge", "tags": ["dodge", "cash_in"], "payoff": true, "crit": true, "melee": true, "kb": dir * 6.0, "stun": float(rd.get("cash_stun", 0.3)), "dr": true})
	if is_instance_valid(f) and not f.dead:
		KitStatus.apply(f, "vul", float(dash_def()["shred_t"]), float(dash_def()["shred"]))
	var gold := res_col()
	payoff_fx(f.pos, "CASH IN", gold, "pay_cashin", dir, f)
	m.fx.burst(f.pos + Vector3(0, 1.4, 0), gold.lightened(0.3), 30, 6.0, 0.9, 14.0, 1.0)      # the coins spill
	m.sfx("pickup", f.pos, -4.0, 1.3)
	CombatBus.ability_used.emit(h, "cash_in", "dodge")

## A rival we hit was knocked: a heal (less for an assist) and Vault back.
func on_knock(t: Hunter, mine: bool) -> void:
	var rd := res_def()
	var amt := h.max_hp * float(rd.get("heal_knock", 0.12) if mine else rd.get("heal_assist", 0.08))
	h.heal(amt)
	h.dashes = h.max_dashes()
	m.fx.word(h.pos + Vector3(0, 2.5, 0), "TAKEN" if mine else "ASSIST", res_col(), false)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("7fe08a"), 14, 2.5, 0.5, -2.0)
	if is_instance_valid(t): clear_marks(t)

# ------------------------------------------------------------------ RMB: Bola
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var bd: Dictionary = rmb_def()["bola"]
	var gnd := float(bd["ground"]) + (0.5 if rank("sec") >= 3 else 0.0)
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(bd["speed"]), "range": float(bd["range"]), "size": 0.3},
		"effects": [{"type": "damage", "amount": float(bd["dmg"])}, {"type": "slow", "duration": gnd, "strength": float(bd["slow"])}]})
	var done := {}
	run(stg, cx("rmb", "bola", aim(), {"on_foe": func(f: Ent, _c: Dictionary):
		if done.has("first") or not is_instance_valid(f): return
		done["first"] = true
		_wrap(f, gnd)}))
	Feel.cast_sound(m, "projectile", "control", h.pos, h)
	m.sfx("ab_whirr", h.pos, -5.0, 1.7)
	net_bolt(h.pos + Vector3(0, 1.0, 0), h.pos + Vector3(h.aim_dir().x, 0, h.aim_dir().y) * float(bd["range"]) + Vector3(0, 1.0, 0), col_of(rmb_def()))

## The Bola wraps a foe: Grounded and a Mark; a second foe within 3m is caught too, both stunned.
func _wrap(f: Ent, gnd: float) -> void:
	var bd: Dictionary = rmb_def()["bola"]
	var col := col_of(rmb_def())
	KitStatus.apply(f, "gnd", gnd)
	add_mark(f, 1, true)
	m.sfx("ab_tether", f.pos, -3.0, 1.4)
	var other: Ent = null
	var best := float(bd["pair_r"])
	for o in m.foes_of(h.team):
		if o != f and o.hittable() and o.flat_dist(f) < best and absf(o.pos.y - f.pos.y) < 1.6:
			best = o.flat_dist(f); other = o
	if other == null:
		return
	bola_pairs += 1
	KitStatus.apply(other, "gnd", gnd)
	for t in [f, other]:
		if is_instance_valid(t) and not t.dead:
			t.hurt(float(bd["pair_dmg"]) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "bola"], "stun": float(bd["pair_stun"]), "dr": true})
			add_mark(t, 1, true)
	m.fx.bolt(f.pos + Vector3(0, 0.6, 0), other.pos + Vector3(0, 0.6, 0), col)
	m.fx.bolt(f.pos + Vector3(0, 1.0, 0), other.pos + Vector3(0, 1.0, 0), col.lightened(0.3))
	var mid := (f.pos + other.pos) * 0.5
	m.fx.word(mid + Vector3(0, 2.6, 0), "TANGLED", col, true)
	m.fx.ring(mid, 1.6, col, 0.3)
	m.sfx("ab_stun", mid, -2.0, 1.1)
	Feel.shake(m, "t3", h, mid, f)
	net_bolt(f.pos + Vector3(0, 0.8, 0), other.pos + Vector3(0, 0.8, 0), col)

# ------------------------------------------------------------------ E: Shadow Knife
func in_e() -> bool:
	return not knife.is_empty()

func e_recastable() -> bool:
	return not knife.is_empty()

func cast_e() -> bool:
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
	return true

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
	e_t = float(ed["time"]) + (0.6 if rank("kin") >= 3 else 0.0)
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
	ambush_t = maxf(ambush_t, float(e_def().get("ambush", 1.2)))
	last_e = "shadow_step"

## Shadow Step: appear behind the foe (the Ambush window opens).
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

# ------------------------------------------------------------------ R: Jackpot
func _jackpot_targets() -> Array:
	return foes_in(h.pos, float(r_def()["reach"])).filter(func(f): return sees(f) and not (f is Kin))

func r_can_cast() -> bool:
	return not _jackpot_targets().is_empty()

func r_no_target_text() -> String: return "No one within 8.5m to rob"

## The fuse doesn't plant you or stop your weapon: keep shooting through it.
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
	var tg := _jackpot_targets()
	if tg.is_empty():
		return false
	var gold := res_col()
	for f in tg:
		var dist: float = h.flat_dist(f)
		var rim := dist > float(rd["inner"])
		var from := h.pos + Vector3(0, 1.0, 0)
		m.fx.bolt(from, f.pos + Vector3(0, 1.0, 0), Color(gold, 0.9) if rim else Color(Color("c8f0ff"), 0.9))
		net_bolt(from, f.pos + Vector3(0, 1.0, 0), gold)
		m.later(dist / 45.0, func(): _jackpot_hit(f, rim))
	quick = int(rd["quick"]) + (1 if rank("ult") >= 2 else 0)
	quick_t = float(rd["quick_t"])
	r_t = quick_t
	refresh_marks()
	m.fx.word(h.pos + Vector3(0, 2.9, 0), "JACKPOT", gold, true)
	m.fx.ring(h.pos, float(rd["reach"]), gold, 0.4)
	m.fx.ring(h.pos, float(rd["inner"]), Color(1, 1, 1, 0.7), 0.3)
	for i in 12:
		var a := TAU * i / 12.0
		m.fx.burst(h.pos + Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6), gold, 3, 9.0, 0.3, 0.0, 0.7, Vector3(cos(a), 0.05, sin(a)), 8.0)
	m.sfx("ab_throw", h.pos, -1.0, 1.3)
	m.sfx("pickup", h.pos, -4.0, 1.1)
	return true

func _jackpot_hit(f: Ent, rim: bool) -> void:
	if not is_instance_valid(f) or f.dead or not is_instance_valid(h):
		return
	var rd := r_def()
	var stg := stage("r", {"delivery": {"type": "burst", "origin": "here", "radius": 0.0}, "effects": [{"type": "damage", "amount": float(rd["dmg"]) * r_k()}]})
	var c := cx("r", "jackpot", f.pos, {"at": f.pos})
	KinExec.apply_foe(stg.effects, f, c, f.pos, stg)
	KinExec.apply_friends(stg.effects, c, h.pos, 1.0)
	jackpot_hits += 1
	if is_instance_valid(f) and not f.dead:
		if rim:
			f.hurt(float(rd["rim_dmg"]) * r_k() * m.dmg_mult(h), h, {"src": "abil", "ab": "ult", "tags": ["ult", "jackpot_rim"], "crit": true})
			KitStatus.apply(f, "blt", float(rd["blight"]))
			m.fx.word(f.pos + Vector3(0, 2.2, 0), "BLIGHTED", Color("b0e070"), false)
		add_mark(f, 1, true)
	m.sfx("slash_hit", f.pos, -4.0, 1.3)
	m.fx.burst(f.pos + Vector3(0, 1.0, 0), res_col(), 10, 3.5, 0.3)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	# the dagger is stuck in them: step behind them
	if not knife.is_empty() and knife.get("target") != null and randf() < 0.6:
		h.inp["sig"] = true
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and los and dist < float(r_def()["reach"]) - 0.5 and (tgt is Hunter or randf() < 0.3) and randf() < 0.45:
		h.inp["ult"] = true
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and knife.is_empty() and los and dist > 3.5 and dist < float(e_def()["range"]) - 1.0 and randf() < 0.35:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < float(rmb_def()["bola"]["range"]) - 1.0:
		var pair := false
		for o in m.foes_of(h.team):
			if o != tgt and o.hittable() and o.flat_dist(tgt) < float(rmb_def()["bola"]["pair_r"]): pair = true
		if pair or randf() < 0.35:
			h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
			h.inp["sec"] = true
	# Vault to Prime the next hit when it will land (and always to Cash In); flip across them
	var reach := 2.8 if h.wid == "twin_blades" else 6.5
	if int(h.slot_lv["dash"]) > 0 and primed_t <= 0.0 and (h.dashes >= 1.0 or quick > 0) and los and dist < reach + 1.5 and (marks_on(tgt) >= 2 or randf() < 0.3):
		var side := h.dir_to(tgt).rotated(PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
		if h.wid == "twin_blades" and dist > 2.0: side = (h.dir_to(tgt) + side * 0.5).normalized()
		h.ai["dash_dir"] = side
		h.inp["move"] = side
		h.inp["dash"] = true
