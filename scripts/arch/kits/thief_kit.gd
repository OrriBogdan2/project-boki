class_name ThiefKit
extends ArchKit
## Dancer (light, id "thief"): a port of SUPERVIVE's Shiv, matched to the footage (briefs/hero-ref/dancer.md),
## scaled to our health and TTK; only the names, art, sounds and on-screen text are ours. docs/heroes/thief.md.
##
## - LMB, Arc Bolts: a spinning bolt from alternating hands every 0.45s that flies to the cursor (clamped
##   to 12m) and fizzles there; a thin aim line ends at the cursor, gold while the next bolt is empowered.
## - Passive, Marks: every bolt that hits stacks a Mark on the target (gold diamonds over their head, up
##   to 8): each makes your bolts on them stronger. A knock or an assist heals you.
## - Jackpot (a Mark trigger, not a key; kits2-nor's fold of the source R): the fifth Mark opens a cyan
##   ring round you; for 1.2s a blade flies at each foe in it, harder at the rim, refreshing every Mark,
##   and the Vault comes back. No R: that key is the Boki Merge.
## - Dash, Vault: a short cartwheel; the next bolt is empowered (3.5x, 2 Marks, Shred) and landing it
##   gives the Vault back (the payoff: T4, pay_cashin, VAULT RESET).
## - RMB, Bola: a 0.4s wind-up with the lane showing, then a kit-run Bola that grounds the first foe and
##   flies on (bouncing once off a wall); a second foe caught and both are stunned with bonus damage.
## - E, Shadow Knife: a dagger to the cursor that sticks in the first foe (slows) or lands; recast to blink
##   to it through a chain of afterimages, or you step there when it runs out.

const HAND_OFF := 0.28         # m: a bolt leaves this far to the side, alternating hands
const BOLT_GOLD := Color("ffc04a")
const BOLT_CORE := Color("fff2c0")
const FIZZLE := Color("8a7aff")    # a bolt running out at the cursor: a blue-violet puff
const EMP_BLUE := Color("4ab8ff")  # the empowered shot's chakram
const GHOST := Color("7af0ff")     # the blink's afterimages
const KNOCK_STAR := Color("ff2a48")
const EMP_RANGE_K := 1.12          # the empowered bolt flies 12% further (the source: 850 -> 950 units)

var primed_t := 0.0            # Vault empowered the next bolt
var haste_t := 0.0             # Vault's burst of speed (ends on the empowered hit)
var mark_gap := {}             # target id -> time of its last Mark from us
var pips := {}                 # target instance id -> {node, t: Ent}: the Mark pips over their head
var knife := {}                # the stuck Shadow Knife: {target, pos, dir}
var bola_cast := {}            # the Bola winding up, lane showing: {t}
var bola := {}                 # the Bola in flight: {pos, dir, left, first, bounces, stg}
var jp := {}                   # Jackpot running: {t, next, n}
var jp_cd := 0.0               # Jackpot is resting (seconds)
var wrapped := {}              # foe instance id -> [foe, time left]: the binding rings on the Grounded
var glint: Node3D = null       # the empowered tell: a gold glint at the weapon hand
var hand := 0                  # 0: the next bolt leaves the right hand, 1: the left
var _primed_on: Ent = null     # the empowered bolt just reached this foe (its end sets it, on_deal reads it)
var primed_hits := 0           # (tests, demo)
var bola_pairs := 0
var bola_bounces := 0
var bola_breaks := 0
var jackpot_hits := 0          # blades landed
var jackpots := 0              # bursts opened
var bolts := 0                 # bolts thrown
var fizzles := 0               # bolts that ran out at the cursor
var last_bolt_end := Vector3.ZERO
var last_bolt_emp := false
var blinks := 0

func _setup() -> void:
	res = 0.0

func fx() -> DJFx:
	return DJFx.of(m)

## A Boki merge starting drops the Bola's wind-up and a running Jackpot (nothing fires, nothing is left
## for after the merge). Hold fields: bola_cast, jp.
func _drop_holds() -> void:
	bola_cast = {}
	jp = {}

# ---- Marks live on the targets: meta "marks" {dancer nid: [count, time left]} ----
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
	if not force and now - float(mark_gap.get(t.get_instance_id(), -9.0)) < float(res_def().get("gap", 0.0)):
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
	_on_marks(t, had, c)

## Crossing the Jackpot count (5) opens Jackpot; reaching the cap (8) chimes.
func _on_marks(t: Ent, had: int, c: int) -> void:
	var at := int(jackpot_def().get("at", 5))
	if had < at and c >= at:
		m.sfx("pickup", t.pos, -2.0, 1.9)       # the victim hears a coin jingle at the Jackpot count
		m.fx.word(t.pos + Vector3(0, 2.5, 0), "MARKED", res_col(), true)
		fx().star(t.pos + Vector3(0, 1.2, 0), res_col(), 1.0, 0.3)
		net_ring(t.pos, 1.3, res_col())
		_jackpot(t)
	if had < mark_max() and c >= mark_max():
		m.sfx("unlock", t.pos, -6.0, 1.7)

func clear_marks(t: Ent) -> void:
	var mk: Dictionary = t.get_meta("marks", {})
	mk.erase(h.nid)
	t.set_meta("marks", mk)

func mark_max() -> int:
	return int(res_def().get("max", 8))

## Sets a target's Marks outright (the Bola pooling two foes' Marks at rank 3).
func set_marks(t: Ent, n: int) -> void:
	if t == null or not is_instance_valid(t) or t.dead:
		return
	var mk: Dictionary = t.get_meta("marks", {})
	var e: Array = mk.get(h.nid, [0, 0.0])
	var had := int(e[0]) if float(e[1]) > 0.0 else 0
	mk[h.nid] = [mini(mark_max(), n), float(res_def().get("dur", 4.0))]
	t.set_meta("marks", mk)
	_pip_pop(t, n)
	_on_marks(t, had, mini(mark_max(), n))

## Every Mark we have on anyone back to its full time (each Jackpot blade).
func refresh_marks() -> void:
	for f in m.foes_of(h.team):
		var mk: Dictionary = f.get_meta("marks", {}) if f.has_meta("marks") else {}
		if mk.has(h.nid) and int(mk[h.nid][0]) > 0:
			mk[h.nid][1] = float(res_def().get("dur", 4.0))
			_pip_pop(f, int(mk[h.nid][0]))

# ---- Marks you can read from across the fight: gold diamonds orbiting over the target's head, one per
# Mark, spinning faster as they stack (everyone sees them, the victim included). Made once per target.
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
		d.mesh = Models.box(0.24, 0.24, 0.24)
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
		var n = p["node"]
		var tv = p["t"]     # untyped first: a freed target can't be assigned to a typed var
		var t: Ent = tv if is_instance_valid(tv) else null
		var c := marks_on(t) if t != null and not t.dead else 0
		if c <= 0 or not is_instance_valid(n):
			if is_instance_valid(n): n.queue_free()
			pips.erase(key)
			continue
		var top := 2.7 if t is Hunter else 1.9
		n.global_position = t.position + Vector3(0, top, 0)
		p["pop"] = maxf(0.0, float(p["pop"]) - dt * 4.0)
		var a: float = m.time * (1.6 + 0.4 * c)
		var ds: Array = p["d"]
		for i in ds.size():
			var d: MeshInstance3D = ds[i]
			var ang := a + TAU * i / float(ds.size())
			d.position = Vector3(cos(ang) * 0.78, 0.0, sin(ang) * 0.78)
			var lit := i < c
			d.scale = Vector3.ONE * ((1.0 + float(p["pop"]) * 0.8 + (0.15 * sin(m.time * 9.0) if c >= ds.size() else 0.0)) if lit else 0.45)
			d.material_override.set_shader_parameter("color", Color(res_col(), 1.0) if lit else Color(1, 1, 1, 0.2))

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

## The payoff is armed: the next bolt is empowered.
func full_ready() -> bool:
	return primed_t > 0.0

func dash_payoff_ready() -> bool:
	return primed_t > 0.0

func ready_label() -> String:
	return "EMPOWERED  ·  land it to reset Vault" if primed_t > 0.0 else ""

## The payoff lives on the dash: the right click's slot never shows the gold dot.
func slot_info(slot: String) -> Dictionary:
	var out := super.slot_info(slot)
	if slot in ["sec", "utility"]: out["full"] = false
	return out

func _tick(dt: float) -> void:
	haste_t = maxf(0.0, haste_t - dt)
	jp_cd = maxf(0.0, jp_cd - dt)
	if primed_t > 0.0:
		primed_t -= dt
		if primed_t <= 0.0:
			primed_t = 0.0
			m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color(res_col(), 0.6), 6, 1.5, 0.3, -1.0, 0.7)
	_tick_pips(dt)
	# marks fade on every target we've touched
	for f in m.foes_of(h.team):
		var mk: Dictionary = f.get_meta("marks", {}) if f.has_meta("marks") else {}
		if mk.has(h.nid):
			var e: Array = mk[h.nid]
			e[1] = float(e[1]) - dt
			if float(e[1]) <= 0.0: mk.erase(h.nid)
	if not bola_cast.is_empty(): _tick_bola_cast(dt)
	if not bola.is_empty(): _tick_bola(dt)
	if not jp.is_empty(): _tick_jackpot(dt)
	_tick_wrapped(dt)
	_tick_knife()
	_tick_glint()
	_tick_aim_line()
	net_pulse(dt, full_ready())

## The aim line (your screen only): thin and white to the cursor, clamped to the bolt's range, with an
## arrow tick; gold and brighter while the next bolt is empowered.
func _tick_aim_line() -> void:
	if not h.is_local() or h.wid != "arc_bolts" or busy() or KinMerge.active(h):
		return
	var to := AimMode.point(h, float(h.wpn.get("range", 12.0)) * (EMP_RANGE_K if primed_t > 0.0 else 1.0))
	if primed_t > 0.0:
		AimKit.line(h, "aim", {"to": to, "col": Color("ffd25a"), "hot": 0.6, "alpha": 1.3, "lw": 0.06})
	else:
		AimKit.line(h, "aim", {"to": to, "col": Color(1, 1, 1), "alpha": 0.55})

## The empowered tell: a gold glint and a light at the weapon hand (everyone sees it).
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

# ------------------------------------------------------------------ LMB: Arc Bolts
func lmb_override(held: bool, _dt: float) -> bool:
	if h.wid != "arc_bolts":
		return false
	if KinMerge.active(h):
		return true
	if held and h.fire_cd <= 0.0 and h.can_fire():
		_bolt()
	return true

## One bolt: from the hand whose turn it is, to the cursor point (clamped to range); an empowered one
## when Vault primed it.
func _bolt() -> void:
	var emp := primed_t > 0.0
	var n0: int = m.shots.size()
	h.shot_aim = AimMode.CURSOR
	h.fire()
	h.ammo = int(h.wpn.get("mag", 99))        # no magazine: a bolt every 0.45s for as long as you hold it
	if m.shots.size() <= n0:
		return
	var sd: Dictionary = m.shots[-1]
	if sd["by"] != h:
		return
	bolts += 1
	hand = 1 - hand
	var d := h.aim_dir()
	var right := Vector2(-d.y, d.x)
	var off := right * HAND_OFF * (1.0 if hand == 1 else -1.0)
	var start: Vector3 = (sd["pos"] as Vector3) + Vector3(off.x, 0, off.y)
	var rng := float(h.wpn.get("range", 12.0)) * (EMP_RANGE_K if emp else 1.0)
	var to := AimMode.point(h, rng)
	var v := Vector2(to.x - start.x, to.z - start.z)
	var spd := (sd["vel"] as Vector2).length()
	var dist := clampf(v.length(), AimMode.MIN_D, rng)
	sd["pos"] = start; sd["prev"] = start; sd["start"] = start
	if v.length() > 0.05: sd["vel"] = v.normalized() * spd
	sd["life"] = dist / spd; sd["life0"] = sd["life"]
	var x: Dictionary = sd["x"]
	x["kx"] = func(s: Dictionary, at: Vector3, e: Ent, why: String) -> void: _bolt_end(s, at, e, why, emp)
	# the throw: the firing arm whips forward, the torso turns into it (KMovesDJ thf_lmb_r / thf_lmb_l)
	play("thf_lmb_r" if hand == 1 else "thf_lmb_l")
	h.swing_n += 1
	h.combo_i = 1 if hand == 1 else 2
	var muzzle := start + Vector3(d.x, 0, d.y) * 0.1
	if emp:
		var dd := dash_def()
		primed_t = 0.0
		haste_t = 0.0
		sd["dmg"] = float(sd["dmg"]) * float(dd.get("prime_k", 3.5)) * (1.2 if rank("dash") >= 3 else 1.0)
		sd["r"] = 0.3
		x["kb"] = 3.0
		fx().ride(sd, "chakram_big", Color("ffd84a"), EMP_BLUE, 2.6, 0.55)
		fx().star(muzzle, EMP_BLUE, 0.9, 0.16)
		m.sfx("dj_bolt_emp", h.pos, -1.0 if h.is_local() else -5.0, 1.0)
		play("thf_primed")
		if h.is_local() and m.cam: m.cam.add_trauma(0.12)
	else:
		fx().ride(sd, "chakram", BOLT_GOLD, BOLT_CORE, 1.1, 0.28)
		fx().star(muzzle, BOLT_GOLD, 0.35, 0.08)
	last_bolt_emp = emp

## Where a bolt ends: a starburst on a hit, a blue-violet puff at the cursor, sparks on a wall.
func _bolt_end(s: Dictionary, at: Vector3, e: Ent, why: String, emp: bool) -> void:
	s["dj_end"] = true
	last_bolt_end = at
	if e != null:
		if emp: _primed_on = e
		fx().star(at, BOLT_GOLD if not emp else Color("ffe070"), 1.5 if emp else 0.7, 0.24 if emp else 0.14)
		if emp: m.fx.spark(at, Vector3.UP, EMP_BLUE, 14, 11.0, 70.0)
	elif why == "expire":
		fizzles += 1
		fx().puff(at, FIZZLE, 0.5 if not emp else 0.9, 0.3, Color("d8d0ff"))
		m.sfx("dj_fizzle", at, -10.0 if h.is_local() else -14.0, 1.0)
	else:
		m.fx.spark(at, Vector3.UP, BOLT_GOLD, 6, 6.0, 80.0)

# ------------------------------------------------------------------ dash: Vault
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if not spend_dash(use_ex):
		return true
	if use_ex:
		# the shared long dash, her way: a flick into a forward tumble with a violet streak
		travel(float(h.cdat.get("ex_dist", 5.0)), float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1}, true)
		play("thf_exdash")
		for i in 3:
			m.later(0.05 * i, func(): if is_instance_valid(h): m.fx.spark(h.pos + Vector3(0, 0.9, 0), Vector3(-h.roll_dir.x, 0.1, -h.roll_dir.y), Arch.color(id), 8, 8.0, 25.0, 0.22, 0.0, 1.2))
		m.later(float(h.cdat.get("ex_time", 0.2)), func(): if is_instance_valid(h): m.fx.ring(h.pos, 0.8, Arch.color(id), 0.18))
		return true
	else:
		travel(float(dd["dist"]), float(dd["time"]), {"invuln": float(dd["invuln"]), "phase": 0.3})
	_vaulted()
	return true

## After a Vault: the cartwheel (a side flip in the plane of travel, whichever way you go), the white
## arc its hands and feet trace, the speed, and the next bolt empowered.
func _vaulted() -> void:
	var dd := dash_def()
	var dir := h.roll_dir if h.roll_dir.length() > 0.1 else h.aim_dir()
	var right := Vector2(cos(h.face), -sin(h.face))
	play("thf_vault_r" if dir.dot(right) >= 0.0 else "thf_vault_l")
	var t := float(dd["time"])
	_swoosh(dir)
	m.later(t * 0.5, func(): if is_instance_valid(h): _swoosh(dir))
	haste_t = float(dd["haste_t"])
	var was := primed_t > 0.0
	primed_t = float(dd["primed_t"])
	m.sfx("dj_cartwheel", h.pos, -3.0 if h.is_local() else -7.0, 1.0)
	m.later(t, func():
		if not is_instance_valid(h): return
		m.fx.ring(h.pos, 0.9, Color(1, 1, 1, 0.8), 0.2)      # the white halo as she lands
		m.sfx("click", h.pos, -6.0 if h.is_local() else -10.0, 2.2))      # the bolt formed in the hand: empowered
	if not was:
		armed_fx("", "dash")                     # empowered: the ready ping, a ring everyone sees

func _swoosh(dir: Vector2) -> void:
	fx().crescent(h.pos + Vector3(0, 0.85, 0), dir, 300.0, 0.95, Color(1, 1, 1, 0.9), Color(0.82, 0.86, 1.0, 0.7), 0.28, PI * 0.5)

# ------------------------------------------------------------------ passive hooks
## Marks make your bolts (the empowered one too) on that target stronger.
func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	var weapon := String(o.get("src", "")) == "shot" and String(o.get("ab", "")) == ""
	if not weapon:
		return dmg
	return dmg * (1.0 + float(res_def().get("per_mark", 0.12)) * float(marks_on(t)))

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or t.dead:
		return
	if String(o.get("src", "")) != "shot" or String(o.get("ab", "")) != "":
		return          # only your weapon's hits stack
	if _primed_on != null and _primed_on == t:
		_primed_on = null
		_primed_hit(t)
		return
	add_mark(t, 1)

## The empowered bolt landed: 2 Marks and Shred, and the Vault comes back (the payoff: T4 hitstop and
## shake, pay_cashin, VAULT RESET). Its 3.5x damage was on the bolt itself.
func _primed_hit(t: Ent) -> void:
	var dd := dash_def()
	primed_hits += 1
	var dir := Vector2(t.pos.x - h.pos.x, t.pos.z - h.pos.z).normalized()
	add_mark(t, int(dd["prime_marks"]), true)
	if is_instance_valid(t) and not t.dead:
		KitStatus.apply(t, "vul", float(dd["shred_t"]), float(dd["shred"]))
	payoff_fx(t.pos, "VAULT RESET", res_col(), "pay_cashin", dir, t)
	m.later(0.1, func(): if is_instance_valid(h) and anim_id != "thf_vault_r" and anim_id != "thf_vault_l": play("thf_reset"))
	h.dashes = h.max_dashes()
	DashReset.cue(h)

## A rival we hit was knocked (or we assisted): a heal, a crimson star on them, a green pillar on us.
func on_knock(t: Hunter, mine: bool) -> void:
	var rd := res_def()
	var hp0 := h.hp
	h.heal(h.max_hp * float(rd.get("heal_knock", 0.15) if mine else rd.get("heal_assist", 0.25)))
	var got := h.hp - hp0
	if is_instance_valid(t):
		fx().star(t.pos + Vector3(0, 1.2, 0), KNOCK_STAR, 3.0 if mine else 2.0, 0.55, Color(1, 0.9, 0.9))
		clear_marks(t)
	fx().pillar(h.pos, Color("5ae07a"), 3.4, 0.6, 0.7)
	play("thf_flourish")
	m.fx.word(h.pos + Vector3(0, 2.6, 0), "+%d" % int(round(got)) if got >= 1.0 else ("TAKEN" if mine else "ASSIST"), Color("7fe08a"), true)
	m.sfx("dj_heal", h.pos, -4.0, 1.0)

# ------------------------------------------------------------------ Jackpot (the fifth Mark)
func jackpot_def() -> Dictionary:
	return d.get("jackpot", {})

## Five Marks on a foe: the ring opens, then blades at everyone inside it for 1.2s; the Vault is back.
## It rests 10s so a long fight can't chain it. The payoff: T4, pay_cashin.
func _jackpot(t: Ent) -> void:
	var jd := jackpot_def()
	if jp_cd > 0.0 or not jp.is_empty() or t is Kin or h.downed or Hex.active(h) or KinMerge.active(h):
		return
	jp_cd = float(jd["cd"])
	jackpots += 1
	jp = {"t": 0.0, "next": float(jd["grow"]), "n": int(jd["shots"])}
	play("thf_volley")
	m.fx.word(h.pos + Vector3(0, 2.9, 0), "JACKPOT", col_of(jd), true)
	m.sfx("dj_jackpot", h.pos, -2.0, 1.0)
	net_ring(h.pos, float(jd["reach"]), col_of(jd))
	h.dashes = h.max_dashes()
	DashReset.cue(h)

func _jackpot_targets() -> Array:
	return foes_in(h.pos, float(jackpot_def()["reach"])).filter(func(f): return sees(f) and not (f is Kin) and f.hittable())

func _tick_jackpot(dt: float) -> void:
	var jd := jackpot_def()
	jp["t"] = float(jp["t"]) + dt
	var gk := clampf(float(jp["t"]) / float(jd["grow"]), 0.0, 1.0)
	# the ring grows out from her, then rides with her (everyone sees it)
	AimKit.circle(h, "jackpot", {"self": true, "r": float(jd["reach"]) * (0.25 + 0.75 * gk), "col": col_of(jd), "all": true, "ticks": true, "fill": 0.25 * gk})
	AimKit.circle(h, "jackpot_rim", {"self": true, "r": float(jd["inner"]) * gk, "col": Color(col_of(jd), 0.6), "all": true, "dashed": true, "alpha": 0.6})
	if float(jp["t"]) >= float(jp["next"]) and int(jp["n"]) > 0:
		jp["n"] = int(jp["n"]) - 1
		jp["next"] = float(jp["next"]) + float(jd["time"]) / float(jd["shots"])
		var hit := false
		for f in _jackpot_targets():
			_jackpot_blade(f)
			hit = true
		if hit: m.sfx("dj_blade", h.pos, -6.0, randf_range(0.95, 1.1))
	if int(jp["n"]) <= 0 and float(jp["t"]) >= float(jp["next"]):
		jp = {}
		AimKit.hide(h, "jackpot"); AimKit.hide(h, "jackpot_rim")

## One blade from her hand at a foe in the ring: a cosmetic shot flies, the hit lands on arrival.
func _jackpot_blade(f: Ent) -> void:
	var jd := jackpot_def()
	var from := h.pos + Vector3(0, 1.0, 0)
	var to := f.pos + Vector3(0, 1.0, 0)
	var dv := Vector2(to.x - from.x, to.z - from.z)
	var dist := dv.length()
	var spd := 30.0
	var n0: int = m.shots.size()
	m.spawn_shot(h, from, dv.normalized() * spd, 0.0, dist / spd, 0.08, col_of(jd), {"cos": true})
	if m.shots.size() > n0:
		fx().ride(m.shots[-1], "blade", col_of(jd), Color("ff5a6a"), 0.9, 0.22)
	var rim := dist > float(jd["inner"])
	m.later(dist / spd, func(): _jackpot_hit(f, rim))

func _jackpot_hit(f: Ent, rim: bool) -> void:
	if not is_instance_valid(h) or not is_instance_valid(f) or f.dead or not f.hittable():
		return
	var jd := jackpot_def()
	var dmg := float(jd["dmg"]) + (float(jd["rim_dmg"]) if rim else 0.0)
	f.hurt(dmg * power("passive"), h, {"src": "abil", "ab": "mark", "tags": ["jackpot"], "crit": rim})
	if rim and is_instance_valid(f) and not f.dead:
		KitStatus.apply(f, "blt", float(jd.get("rim_blight", 4.0)))      # the rim also cuts healing (the source's outer ring)
	jackpot_hits += 1
	refresh_marks()
	fx().star(f.pos + Vector3(0, 1.0, 0), col_of(jd) if not rim else Color("ff5a6a"), 0.9 if rim else 0.6, 0.18)

# ------------------------------------------------------------------ RMB: Bola
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not bola_cast.is_empty() or not spend_rmb(): return
	var bd: Dictionary = rmb_def()["bola"]
	bola_cast = {"t": float(bd["cast"])}
	play("thf_bola")                  # the whirl overhead through the wind-up, the sling at the end
	m.sfx("dj_bola_whirl", h.pos, -4.0 if h.is_local() else -8.0, 1.0)

func lane_len() -> float:
	var bd: Dictionary = rmb_def()["bola"]
	return float(bd["range"]) + float(bd["after"]) + (float(bd["after_r3"]) if rank("sec") >= 3 else 0.0)

## The wind-up: the lane (about 1 bh wide, 6 bh long) shows toward the cursor and follows your aim.
func _tick_bola_cast(dt: float) -> void:
	var bd: Dictionary = rmb_def()["bola"]
	if busy():
		bola_cast = {}
		return
	bola_cast["t"] = float(bola_cast["t"]) - dt
	var k := 1.0 - clampf(float(bola_cast["t"]) / float(bd["cast"]), 0.0, 1.0)
	# the source's lane is a translucent white strip with chevrons; the fill front runs gold toward the throw
	AimKit.lane(h, "rmb", {"len": lane_len(), "width": float(bd["lane_w"]), "chevrons": 4, "tip": true, "fill": k, "col": Color(1, 1, 1), "col2": col_of(rmb_def()), "alpha": 1.35})
	if float(bola_cast["t"]) <= 0.0:
		bola_cast = {}
		AimKit.hide(h, "rmb")
		_throw_bola()

func _throw_bola() -> void:
	var bd: Dictionary = rmb_def()["bola"]
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(bd["speed"]), "range": float(bd["range"]), "size": 0.3},
		"effects": [{"type": "damage", "amount": float(bd["dmg"])}, {"type": "slow", "duration": _ground_t(), "strength": float(bd["slow"])}]})
	var dv := h.aim_dir()
	bola = {"pos": h.pos + Vector3(dv.x * 0.5, 1.0, dv.y * 0.5), "dir": dv, "left": float(bd["range"]), "first": null, "bounces": int(bd["bounces"]), "stg": stg}
	m.sfx("dj_bola_throw", h.pos, -3.0, 1.0)
	Feel.cast_sound(m, "projectile", "control", h.pos, h)
	fx().star(h.pos + Vector3(dv.x * 0.6, 1.2, dv.y * 0.6), col_of(rmb_def()), 0.8, 0.12)      # the yellow flash of the throw
	net_bolt(h.pos + Vector3(0, 1.0, 0), h.pos + Vector3(dv.x, 0, dv.y) * lane_len() + Vector3(0, 1.0, 0), col_of(rmb_def()))

func _ground_t() -> float:
	return float(rmb_def()["bola"]["ground"])

## The Bola in flight (it's ours, not a stage shot, so it can fly on through its first foe and bounce
## once off a wall): it grounds the first foe it wraps, flies on, and tangles the second.
func _tick_bola(dt: float) -> void:
	var bd: Dictionary = rmb_def()["bola"]
	var spd := float(bd["speed"])
	var p: Vector3 = bola["pos"]
	var dir: Vector2 = bola["dir"]
	var steps := maxi(1, int(ceil(spd * dt / 0.25)))
	var step := spd * dt / float(steps)
	for i in steps:
		var q := p + Vector3(dir.x, 0, dir.y) * step
		if _walled(q):
			if int(bola["bounces"]) > 0:
				# off the wall: flip whichever way took it in, keep what's left of its flight
				if _walled(Vector3(q.x, q.y, p.z)): dir.x = -dir.x
				else: dir.y = -dir.y
				bola["bounces"] = int(bola["bounces"]) - 1
				bola_bounces += 1
				m.fx.spark(p, Vector3.UP, col_of(rmb_def()), 8, 6.0, 70.0)
				m.sfx("click", p, -5.0, 1.4)
				continue
			_end_bola(p)
			return
		p = q
		bola["left"] = float(bola["left"]) - step
		var first = bola["first"]
		if first == null and not bola.get("broke", false):
			# a crate or barrel counts as the first catch: the Bola breaks on it and flies on
			for b in m.breaks:
				if not b["dead"] and Vector2(b["pos"].x - p.x, b["pos"].z - p.z).length() < 0.7:
					m.hit_break(b, float(bd["dmg"]) * 3.0, h)
					bola["broke"] = true
					bola["left"] = float(bd["after"]) + (float(bd["after_r3"]) if rank("sec") >= 3 else 0.0)
					bola_breaks += 1
					break
		for o in m.foes_of(h.team):
			if o == first or not o.hittable(): continue
			if Vector2(o.pos.x - p.x, o.pos.z - p.z).length() < o.r + 0.45 and absf(o.pos.y + 0.9 - p.y) < 1.6:
				if first == null:
					_wrap(o)
					bola["first"] = o
					bola["left"] = float(bd["after"]) + (float(bd["after_r3"]) if rank("sec") >= 3 else 0.0)
					first = o
				else:
					_tangle(first, o)
					_end_bola(p)
					return
		if float(bola["left"]) <= 0.0:
			_end_bola(p)
			return
	bola["pos"] = p
	bola["dir"] = dir
	fx().place("bola%d" % h.get_instance_id(), "bola", p, dir * spd, col_of(rmb_def()), Color("c9a0ff"), 1.0, 0.25)

func _walled(q: Vector3) -> bool:
	return m.world.is_block(q.x, q.z) or m.world.ground_at(q.x, q.z) > q.y - 0.4

func _end_bola(at: Vector3) -> void:
	bola = {}
	fx().unplace("bola%d" % h.get_instance_id())
	m.fx.burst(at, col_of(rmb_def()), 5, 2.0, 0.25, 6.0, 0.6)

## The Bola wraps its first foe: its stage (damage, slow), Grounded and a Mark, the binding rings.
func _wrap(f: Ent) -> void:
	var stg: StageSpec = bola["stg"]
	KinExec.apply_foe(stg.effects, f, cx("rmb", "bola", f.pos, {"at": f.pos}), f.pos, stg)
	if not is_instance_valid(f) or f.dead: return
	KitStatus.apply(f, "gnd", _ground_t())
	add_mark(f, 1, true)
	wrapped[f.get_instance_id()] = [f, _ground_t()]
	m.fx.word(f.pos + Vector3(0, 2.4, 0), "GROUNDED", col_of(rmb_def()), false)
	m.sfx("dj_bola_wrap", f.pos, -3.0, 1.0)

## Yellow rings bind the Grounded (everyone sees them), two of them winding round their legs.
func _tick_wrapped(dt: float) -> void:
	for key in wrapped.keys():
		var w: Array = wrapped[key]
		w[1] = float(w[1]) - dt
		var f = w[0]
		if float(w[1]) <= 0.0 or not is_instance_valid(f) or (f as Ent).dead:
			wrapped.erase(key)
			continue
		var e := f as Ent
		var r := e.r + 0.35 + 0.08 * sin(m.time * 10.0)
		AimKit.circle(h, "gnd%d" % key, {"at": e.pos, "r": r, "col": col_of(rmb_def()), "all": true, "hot": 0.4, "lw": 0.09})
		AimKit.circle(h, "gnd2%d" % key, {"at": e.pos, "r": r * 0.7, "col": Color("fff0a0"), "all": true, "dashed": true})

## Two foes in one Bola: both Grounded, stunned and hurt; at rank 3 they pool their Marks.
func _tangle(f, other: Ent) -> void:
	var bd: Dictionary = rmb_def()["bola"]
	var col := col_of(rmb_def())
	bola_pairs += 1
	KitStatus.apply(other, "gnd", _ground_t())
	wrapped[other.get_instance_id()] = [other, _ground_t()]
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
	for t in both: fx().star((t as Ent).pos + Vector3(0, 1.4, 0), Color("ff9be8"), 1.2, 0.3)
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
	m.later(0.12, func():               # spun into a side-arm throw, released on the key pose
		if not is_instance_valid(h) or busy(): return
		_throw_knife())
	return true

func _throw_knife() -> void:
	var ed := e_def()
	var rng := AimMode.dist(h, float(ed["range"]))     # to the cursor, 14m at most
	var stg := stage("e", {"delivery": {"type": "projectile", "speed": float(ed["speed"]), "range": rng, "size": 0.2},
		"effects": [{"type": "damage", "amount": float(ed["dmg"])}, {"type": "slow", "duration": float(ed["slow_t"]), "strength": float(ed["slow"])}]})
	var land := ground(AimMode.point(h, float(ed["range"])))     # with nothing on the way it lies where you aimed
	var n0: int = m.shots.size()
	run(stg, cx("e", "shadow_knife", aim(), {
		"on_foe": func(f: Ent, _c: Dictionary):
			if knife.is_empty() and is_instance_valid(f) and not f.dead:
				add_mark(f, 1, true)
				_stick(f, f.pos),
		"on_shot_end": func(at: Vector3, _why: String, e: Ent):
			if knife.is_empty() and e == null: _stick(null, ground(at) if _why == "wall" else land)}))
	if m.shots.size() > n0 and m.shots[-1]["by"] == h:
		fx().ride(m.shots[-1], "dagger", col_of(ed), Color("ffcf5a"), 1.6, 0.26)
	fx().star(h.pos + Vector3(h.aim_dir().x * 0.6, 1.1, h.aim_dir().y * 0.6), Color("ffcf5a"), 0.7, 0.1)
	m.sfx("dj_knife_throw", h.pos, -3.0, 1.0)

func _stick(f: Ent, at: Vector3) -> void:
	var ed := e_def()
	knife = {"target": f, "pos": at, "dir": h.aim_dir()}
	e_t = float(ed["time"])
	if rank("kin") >= 3:
		cd["e"] = float(cd["e"]) * (1.0 - float(ed["refund_foe"] if f else ed["refund_wall"]))
	if f and rank("dash") >= 3:
		h.dashes = h.max_dashes()           # Vault rank 3: a knife in a foe resets it
		DashReset.cue(h)
	fx().star(at + Vector3(0, 1.0 if f else 0.3, 0), Color("ffcf5a"), 0.8, 0.2)
	m.sfx("ab_plant", at, -6.0, 1.8)
	net_ring(at, 0.8, col_of(ed))

## The stuck dagger (a pooled look, everyone sees it) and, on your screen, the white arrival circle.
func _tick_knife() -> void:
	if knife.is_empty():
		return
	var f = knife["target"]
	if f != null and (not is_instance_valid(f) or (f as Ent).dead):
		knife["target"] = null
		f = null
	if f != null:
		knife["pos"] = (f as Ent).pos
	var at: Vector3 = knife["pos"]
	var dv: Vector2 = knife["dir"]
	if tells_visible() or f != null:
		fx().place("knife%d" % h.get_instance_id(), "dagger", at + Vector3(0, 1.2 if f != null else 0.35, 0), dv * 0.01, col_of(e_def()), Color("ffcf5a"), 0.2, 0.2)
	AimKit.circle(h, "knife", {"at": at, "r": 1.6, "col": Color(1, 1, 1), "ticks": true, "alpha": 0.8})

func e_recast() -> bool:
	if knife.is_empty():
		return false
	_step_to_knife()
	return true

## It ran out: you step to it anyway.
func _e_end() -> void:
	if not knife.is_empty():
		_step_to_knife()

func _step_to_knife() -> void:
	var k := knife
	knife = {}
	e_t = 0.0
	fx().unplace("knife%d" % h.get_instance_id())
	AimKit.hide(h, "knife")
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
		_blink(ground(at))
	last_e = "shadow_step"

## Step to the knife in a foe: you appear right at them, on their far side.
func _shadow_step(tgt: Ent) -> void:
	var back := Vector2(sin(tgt.face), cos(tgt.face))      # behind = opposite their facing
	var at := tgt.pos + Vector3(back.x, 0, back.y) * (tgt.r + h.r + 0.35)
	if m.world.is_void(at.x, at.z) or m.world.is_block(at.x, at.z):
		var away := Vector2(tgt.pos.x - h.pos.x, tgt.pos.z - h.pos.z).normalized()
		at = tgt.pos + Vector3(away.x, 0, away.y) * (tgt.r + h.r + 0.35)
	_blink(ground(at))
	var dv := Vector2(tgt.pos.x - h.pos.x, tgt.pos.z - h.pos.z)
	if dv.length() > 0.05: h.face = atan2(-dv.x, -dv.y)
	m.sfx("swipe", h.pos, -4.0, 1.9)

## The blink: a near-instant jump with a chain of cyan afterimages from where she was to where she lands.
func _blink(to: Vector3) -> void:
	var from := h.pos
	var yaw := atan2(-(to.x - from.x), -(to.z - from.z))
	fx().ghosts(from, to, int(e_def().get("ghosts", 5)), yaw, GHOST, float(h.cdat.get("scale", 1.0)))
	h.teleport(to)
	h.vel = Vector3.ZERO
	h.gliding = false
	blinks += 1
	fx().puff(to + Vector3(0, 0.9, 0), GHOST, 1.2, 0.3)
	m.sfx("dj_blink", to, -3.0, 1.0)
	m.fx.ring(to, 1.0, GHOST, 0.22)
	net_bolt(from + Vector3(0, 0.9, 0), to + Vector3(0, 0.9, 0), GHOST)
	if h.is_local():
		Oomph.punch_dir(m, Vector2(to.x - from.x, to.z - from.z), 0.25)
		if m.cam: m.cam.punch(0.03)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	# the dagger is stuck in them: step to them
	if not knife.is_empty() and knife.get("target") != null and randf() < 0.6:
		h.inp["sig"] = true
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and knife.is_empty() and los and dist > 1.5 and dist < float(e_def()["range"]) - 1.0 and randf() < 0.35:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and bola_cast.is_empty() and los and dist < lane_len() - 1.0:
		# best when someone stands behind them along the throw (the Bola flies on and catches both)
		var pair := false
		var dv := h.dir_to(tgt)
		for o in m.foes_of(h.team):
			if o != tgt and o.hittable() and tgt.flat_dist(o) < float(rmb_def()["bola"]["after"]) and dv.dot(tgt.dir_to(o)) > 0.8: pair = true
		if pair or tgt is Hunter or randf() < 0.35:
			h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
			h.inp["sec"] = true
	if not bola_cast.is_empty():
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
	# Vault to empower the next bolt when it will land; cartwheel sideways across their aim
	if int(h.slot_lv["dash"]) > 0 and primed_t <= 0.0 and h.dashes >= 1.0 and los and dist < float(h.wpn.get("range", 12.0)) - 1.0 and randf() < 0.3:
		var side := h.dir_to(tgt).rotated(PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
		h.ai["dash_dir"] = side
		h.inp["move"] = side
		h.inp["dash"] = true
