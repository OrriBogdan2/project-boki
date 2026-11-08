class_name ThiefKit
extends ArchKit
## Sable (light, id "thief"): a port of SUPERVIVE's Shiv, matched to the footage (briefs/hero-ref/dancer.md),
## scaled to our health and TTK; only the names, art, sounds and on-screen text are ours. docs/heroes/thief.md.
##
## - LMB, Arc Bolts: a spinning bolt from alternating hands every 0.45s that flies to the cursor (clamped
##   to 8.5m) and fizzles there; a thin aim line ends at the cursor, gold while the next bolt is empowered.
## - Passive, Marks: every bolt that hits stacks a Mark on the target (gold diamonds over their head, up
##   to 8 shown, no cap): each makes your bolts on them stronger. A knock or an assist heals you.
## - X, Encore (ThiefUlt, level 6): a ring grows round her, then for 2s blades fly at every foe inside it,
##   harder from the outer band, refreshing every Mark; the Vault comes back. The Boki Merge has its own key.
## - Dash, Vault: a short cartwheel (a longer one from a jump); the next bolt is empowered (3.5x, 2 Marks,
##   Shred), shown by a gold glint in the throwing hand that flares as she lands, and landing it gives the
##   Vault back with no cap (the payoff: T4, pay_cashin, RESET at her hand); a chain runs a routine of flips and
##   keeps fast Shift presses (ThiefChain). No ring or burst on the dash itself.
##   What other presses do during the cartwheel: content/dash_flow/thief.json (DashFlow).
## - RMB, Bola: a 0.4s wind-up with the lane showing, then a kit-run Bola that grounds the first foe and
##   slows it (the owner's call, on top of the source's Ground) and flies on (bouncing once off a wall); a second
##   foe caught and both are stunned with bonus damage.
## - E, Shadow Knife: a dagger to the cursor that sticks in the first foe (slows) or lands; recast to blink
##   to it through a chain of afterimages, or you step there when it runs out.

const HAND_OFF := 0.28         # m: a bolt leaves this far to the side, alternating hands
const BOLT_GOLD := Color("ffc04a")
const BOLT_CORE := Color("fff2c0")
const FIZZLE := Color("6a48ff")    # a bolt running out at the cursor: a blue-violet puff
const EMP_BLUE := Color("4ab8ff")  # the empowered shot's chakram
const GLINT_EDGE := Color("2a1450")    # the dark violet edge round the hand glint
const GHOST := Color("7af0ff")     # the blink's afterimages
const KNOCK_STAR := Color("ff2a48")
const EMP_LINE := Color("ffc23a")      # the aim line while the next bolt is empowered
const AIM_LILAC := Color("d8c8ff")     # ... and otherwise
const BOLT_TAIL := Color("ff8a2a")     # the bolt's short orange flame tail
const KNIFE_VIOLET := Color("b07aff")  # the dagger's arrival circle
const BOLA_HOT := Color("ffb02a")      # the Bola's lane front and inner binding ring
const BOLA_CORD := Color("b06aff")     # its violet lightning cord
const EMP_RANGE_K := 1.12          # the empowered bolt flies 12% further (the source: 850 -> 950 units)
## The ground Cartwheel's speed over its run (time share, speed as a share of its average): a quick burst
## that peaks near 0.15s and runs down into the hasted run by the landing (the sheet's measured curve).
const VAULT_CURVE := [[0.0, 0.4], [0.3, 1.9], [1.0, 0.55]]
const VAULT_MEAN := 1.2025         # the mean of VAULT_CURVE, so the distance stays the data's
const TRAIL_EVERY := 0.035         # s between two of her after-images on a dash
const GLINT_POP_S := 0.22          # s the glint's flare takes to settle as the empowered bolt forms
const GLINT_NET_EVERY := 1.1       # s between two glint pings online viewers get while it's empowered
const CARTWHEELS := ["thf_vault_r", "thf_vault_l", "thf_vault_f", "thf_vault_b", "thf_vault_twist", "thf_exdash"]

var primed_t := 0.0            # Vault empowered the next bolt
var haste_t := 0.0             # Vault's burst of speed (ends on the empowered hit)
var mark_gap := {}             # target id -> time of its last Mark from us
var pips := {}                 # target instance id -> {node, t: Ent}: the Mark pips over their head
var knife := {}                # the stuck Shadow Knife: {target, pos, dir}
var bola_cast := {}            # the Bola winding up, lane showing: {t}
var bola := {}                 # the Bola in flight: {pos, dir, left, first, bounces, stg}
var encore: ThiefUlt           # X, the ultimate
var chain: ThiefChain          # the Vault loop: its routine of flips, the Shift presses it keeps
var wrapped := {}              # foe instance id -> [foe, time left]: the binding rings on the Grounded
var glint: Node3D = null       # the empowered tell: a gold glint at the weapon hand
var glint_pop := 0.0           # 1 as the empowered bolt forms (the landing), easing back to 0
var glint_net_t := 0.0
var hand := 0                  # 0: the next bolt leaves the right hand, 1: the left
var primed_on: Ent = null      # the empowered bolt just reached this foe (its end sets it; outgoing, on_deal read it)
var bolt_buf := 0.0            # s a click that couldn't fire yet is kept (lmb_override)
var _fire_was := false
var primed_hits := 0           # (tests, demo)
var bola_pairs := 0
var bola_bounces := 0
var bola_breaks := 0
var bolts := 0                 # bolts thrown
var fizzles := 0               # bolts that ran out at the cursor
var last_bolt_end := Vector3.ZERO
var last_bolt_emp := false
var blinks := 0
var vault := {}                # the Cartwheel running: {t, dur, speed, air}
var trail_t := 0.0
var landing_due := false       # an air cartwheel is over; she lands in a crouch when she touches down

func _setup() -> void:
	res = 0.0
	encore = ThiefUlt.new(self)
	chain = ThiefChain.new(self)

func fx() -> DJFx:
	return DJFx.of(m)

## A Boki merge starting drops the Bola's wind-up and a running Encore (nothing fires, nothing is left
## for after the merge). Hold fields: bola_cast, encore.st.
func _drop_holds() -> void:
	bola_cast = {}
	encore.drop()

# ------------------------------------------------------------------ X: Encore (ThiefUlt)
## X (main's HunterKeys gate: level 6; HeroUlt.press: its own cooldown in cd["x"], the cast id).
func cast_ult() -> bool:
	return HeroUlt.press(self, _start_encore)

func has_ult() -> bool:
	return true

func _start_encore() -> bool:
	encore.start()
	return true

func ult_running() -> bool:
	return encore.running()

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
	var c := had + n
	mk[h.nid] = [c, float(res_def().get("dur", 4.0))]
	t.set_meta("marks", mk)
	t.set_meta("marks_t", now)
	_pip_pop(t, c)
	_on_marks(t, had, c)

## Filling the diamonds over the target chimes. Marks have no cap, so they keep climbing past it.
func _on_marks(t: Ent, had: int, c: int) -> void:
	if had < pip_count() and c >= pip_count():
		m.sfx("unlock", t.pos, -6.0, 1.7)

func clear_marks(t: Ent) -> void:
	var mk: Dictionary = t.get_meta("marks", {})
	mk.erase(h.nid)
	t.set_meta("marks", mk)

## How many diamonds the readout draws; the Marks themselves are uncapped.
func pip_count() -> int:
	return int(res_def().get("max", 8))

## Sets a target's Marks outright (the Bola pooling two foes' Marks at rank 3).
func set_marks(t: Ent, n: int) -> void:
	if t == null or not is_instance_valid(t) or t.dead:
		return
	var mk: Dictionary = t.get_meta("marks", {})
	var e: Array = mk.get(h.nid, [0, 0.0])
	var had := int(e[0]) if float(e[1]) > 0.0 else 0
	mk[h.nid] = [n, float(res_def().get("dur", 4.0))]
	t.set_meta("marks", mk)
	_pip_pop(t, n)
	_on_marks(t, had, n)

## Every Mark we have on anyone back to its full time (each Encore blade).
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
	for i in pip_count():
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
			var wob: float = 0.15 * sin(m.time * 9.0) if c >= ds.size() else 0.0
			d.scale = Vector3.ONE * ((1.0 + float(p["pop"]) * 0.8 + wob) if lit else 0.45)
			d.material_override.set_shader_parameter("color", Color(res_col(), 1.0) if lit else Color(1, 1, 1, 0.2))

## Highest mark count on any foe (the resource readout).
func best_marks() -> int:
	var b := 0
	for f in m.foes_of(h.team):
		b = maxi(b, marks_on(f))
	return b

func res_frac() -> float:
	return clampf(float(best_marks()) / float(pip_count()), 0.0, 1.0)

func res_text() -> String:
	return "%d" % best_marks()

## The payoff lives on the dash (the dash slot's gold dot): the next bolt is empowered. It isn't the shared
## "resource full" tell, which would ring her feet and spray sparks round her on every Cartwheel.
func dash_payoff_ready() -> bool:
	return primed_t > 0.0

func ready_label() -> String:
	return "EMPOWERED  ·  land it to reset Vault" if primed_t > 0.0 else ""

func _tick(dt: float) -> void:
	haste_t = maxf(0.0, haste_t - dt)
	if primed_t > 0.0:
		primed_t -= dt
		if primed_t <= 0.0:
			primed_t = 0.0
			fx().puff(hand_pos(hand == 0), FIZZLE, 0.3, 0.2)       # unused, it fades from the hand
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
	encore.tick(dt)
	_tick_vault(dt)
	chain.tick(dt)
	_tick_landing()
	_tick_trail(dt)
	_tick_wrapped(dt)
	_tick_knife()
	_tick_glint(dt)
	_tick_aim_line()
	_net_glint(dt)

## The aim line (your screen only): thin and pale lilac to the cursor, clamped to the bolt's range, with an
## arrow tick; a thick, solid gold line with a soft gold glow while the next bolt is empowered.
func _tick_aim_line() -> void:
	if not h.is_local() or h.wid != "arc_bolts" or busy() or KinMerge.active(h):
		AimKit.hide(h, "aim_glow")
		return
	var to := AimMode.point(h, float(h.wpn.get("range", 12.0)) * (EMP_RANGE_K if primed_t > 0.0 else 1.0))
	if primed_t > 0.0:
		AimKit.line(h, "aim", {"to": to, "col": EMP_LINE, "alpha": 1.6, "lw": 0.13})
		AimKit.line(h, "aim_glow", {"to": to, "col": EMP_LINE, "alpha": 0.35, "lw": 0.34, "arrow": false})
	else:
		AimKit.hide(h, "aim_glow")
		AimKit.line(h, "aim", {"to": to, "col": AIM_LILAC, "alpha": 0.6})

func own_aim_line() -> bool:
	return h.wid == "arc_bolts"

## The empowered tell (everyone sees it): a tight gold glint in the hand the next bolt leaves from, a hot core
## and a turning four-point star, flaring as the bolt forms on the landing. No light (it pooled into a pale disc
## on the ground) and nothing on the ground.
func _tick_glint(dt: float) -> void:
	if glint == null or not is_instance_valid(glint):
		glint = own_node()
		for layer in [[GLINT_EDGE, 0.22, -0.01], [EMP_LINE, 0.17, 0.0]]:      # a dark edge so it reads on grass
			var star := _glint_part(DJFx.star_mesh(4, 0.14), layer[0])
			star.scale = Vector3.ONE * float(layer[1])
			star.position.y = float(layer[2])
			glint.add_child(star)
		glint.add_child(_glint_part(Models.sphere(0.045, 8), BOLT_CORE))
	glint.visible = primed_t > 0.0 and tells_visible()
	glint_pop = maxf(0.0, glint_pop - dt / GLINT_POP_S)
	if glint.visible:
		glint.global_position = hand_pos(hand == 0)
		glint.rotation.y = m.time * 5.0
		glint.scale = Vector3.ONE * (1.0 + 0.12 * sin(m.time * 14.0) + 0.5 * glint_pop * glint_pop)

func _glint_part(mesh: Mesh, col: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = DJFx.solid(col)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part

## Online viewers get the glint as a small ping at her hand while the next bolt is empowered.
func _net_glint(dt: float) -> void:
	glint_net_t -= dt
	if primed_t <= 0.0 or glint_net_t > 0.0:
		return
	glint_net_t = GLINT_NET_EVERY
	net_ring(hand_pos(hand == 0), 0.25, EMP_LINE)

func move_k() -> float:
	return 1.0 + (vault_haste() if haste_t > 0.0 else 0.0)

## Vault's speed boost; the last rank makes it half again as big.
func vault_haste() -> float:
	var boost := float(dash_def().get("haste", 0.3))
	return boost * (float(dash_def().get("haste_r3", 1.5)) if rank("dash") >= 3 else 1.0)

## The empowered bonus's rank growth: +20% at rank 2 and again at rank 3.
func prime_rank_k() -> float:
	return 1.0 + float(dash_def().get("prime_rank", 0.2)) * float(clampi(rank("dash") - 1, 0, 2))

## The empowered bolt as a multiple of a plain one: a bolt plus the bonus (the source's +214 on its 160 bolt).
func empowered_k() -> float:
	return 1.0 + float(dash_def()["prime_bonus"]) * prime_rank_k()

# ------------------------------------------------------------------ LMB: Arc Bolts
## Held, a bolt goes every 0.45s. A click that comes while the last bolt is still cooling (mid-cartwheel too) is
## kept for one bolt's interval and goes the moment it can, so a tap after a Vault is never lost.
func lmb_override(held: bool, dt: float) -> bool:
	if h.wid != "arc_bolts":
		return false
	if KinMerge.active(h):
		return true
	if held and not _fire_was:
		bolt_buf = float(h.wpn.get("rate", 0.45))
	else:
		bolt_buf = maxf(0.0, bolt_buf - dt)
	_fire_was = held
	if (held or bolt_buf > 0.0) and h.fire_cd <= 0.0 and h.can_fire():
		bolt_buf = 0.0
		_bolt()
	return true

## One bolt: from the hand whose turn it is, to the cursor point (clamped to range); an empowered one
## when Vault primed it.
func _bolt() -> void:
	var emp := primed_t > 0.0
	var n0: int = m.shots.size()
	h.shot_aim = AimMode.CURSOR
	h.fire()
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
	sd["pos"] = start
	sd["prev"] = start
	sd["start"] = start
	if v.length() > 0.05: sd["vel"] = v.normalized() * spd
	sd["life"] = dist / spd
	sd["life0"] = sd["life"]
	var x: Dictionary = sd["x"]
	x["kx"] = func(s: Dictionary, at: Vector3, e: Ent, why: String) -> void: _bolt_end(s, at, e, why, emp)
	# the throw: the torso unwinds into it and winds toward the other hand for the next bolt (KMovesDJ
	# thf_lmb_r / thf_lmb_l) while the swing whips that hand's blade out (HunterAnim.SWINGS "arc_bolts"); the
	# empowered one is both blades driven out together (thf_primed)
	var throw := "thf_lmb_r" if hand == 1 else "thf_lmb_l"
	play("thf_primed" if emp else throw)
	h.swing_n += 1
	h.combo_i = 1 if hand == 1 else 2
	var muzzle := start + Vector3(d.x, 0, d.y) * 0.1
	if emp:
		primed_t = 0.0
		haste_t = 0.0
		chain.bolt_thrown(float(sd["life"]))
		sd["dmg"] = float(sd["dmg"]) * empowered_k()
		sd["r"] = 0.3
		x["kb"] = 3.0
		fx().ride(sd, "chakram_big", Color("ffd84a"), EMP_BLUE, 2.6, 0.55)
		fx().star(muzzle, EMP_BLUE, 0.9, 0.16)
		m.sfx("thief_flintlock_crack", h.pos, -1.0 if h.is_local() else -5.0, 1.0)
	else:
		fx().ride(sd, "chakram", BOLT_TAIL, BOLT_GOLD, 0.9, 0.3)
		fx().star(muzzle, BOLT_GOLD, 0.6, 0.1, BOLT_CORE)        # the gold muzzle star at the throwing hand
	last_bolt_emp = emp

## Where a bolt ends: a starburst on a hit, a blue-violet puff at the cursor, sparks on a wall.
func _bolt_end(s: Dictionary, at: Vector3, e: Ent, why: String, emp: bool) -> void:
	s["dj_end"] = true
	last_bolt_end = at
	primed_on = e if emp else null
	if emp: chain.bolt_ended()
	if e != null:
		fx().star(at, BOLT_GOLD if not emp else Color("ffe070"),
				1.5 if emp else 0.7,
				0.24 if emp else 0.14)
		if emp: m.fx.spark(at, Vector3.UP, EMP_BLUE, 14, 11.0, 70.0)
	elif why == "expire":
		fizzles += 1
		fx().puff(at, FIZZLE, 0.75 if not emp else 1.1, 0.34, Color("c8b8ff"))
		m.sfx("dj_fizzle", at, -10.0 if h.is_local() else -14.0, 1.0)
	else:
		m.fx.spark(at, Vector3.UP, BOLT_GOLD, 6, 6.0, 80.0)

# ------------------------------------------------------------------ dash: Vault
## The Cartwheel: a Vault charge on the ground; in the air (or out of charges) the long dash, flipped her way.
## From a jump it carries its speed to the landing (the sheet's ~8m over ~0.95s).
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if chain.hold_for_bolt(use_ex) or not spend_dash(use_ex):
		return true
	var air := use_ex or not h.grounded
	if use_ex:
		h.ex_next = false            # her own distance and time, not the class's long dash
		travel(float(dd["air_dist"]), float(dd["air_time"]), {"invuln": 0.1})
		h.dash_is_ex = true
		h.vel.y = maxf(h.vel.y, 0.0)
	else:
		var dist := float(dd["air_dist"] if air else dd["dist"])
		travel(dist, float(dd["air_time"] if air else dd["time"]), {"invuln": float(dd["invuln"]), "phase": 0.3})
	vault = {"t": 0.0, "dur": h.roll_t, "speed": h.roll_speed, "air": air}
	_vaulted(air, _empowers(use_ex))
	return true

## Whether this cartwheel empowers the next bolt: its dash -> LMB row says so (the source's Quickflip does on
## the ground and from a jump); the long dash on the ground, with the charges spent, doesn't.
func _empowers(use_ex: bool) -> bool:
	if use_ex and h.grounded:
		return false
	return String(DashFlow.row_of(id, "lmb", not h.grounded)["variant"]) == "empowered"

## The Cartwheel's speed curve on the ground; from the air it holds its speed and ends where she lands.
func _tick_vault(dt: float) -> void:
	if vault.is_empty():
		return
	vault["t"] = float(vault["t"]) + dt
	var u := float(vault["t"]) / maxf(0.01, float(vault["dur"]))
	if u >= 1.0 or h.roll_t <= 0.0:
		_vault_over()
		return
	if bool(vault["air"]):
		if h.grounded and float(vault["t"]) > 0.12:
			h.roll_t = 0.0
		return
	h.roll_speed = float(vault["speed"]) * _curve(VAULT_CURVE, u) / VAULT_MEAN

## The air cartwheel holds its carried pose until she touches down (the dash can run out first), then lands in
## a low crouch.
func _vault_over() -> void:
	landing_due = bool(vault["air"])
	vault = {}

func _tick_landing() -> void:
	if not landing_due or not h.grounded:
		return
	landing_due = false
	if anim_id == "thf_exdash":
		play("thf_land")

static func _curve(pts: Array, u: float) -> float:
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if u <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (u - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])))
	return float(pts[-1][1])

## A move another press starts mid-cartwheel (a bolt, the Bola, the dagger) waits out the flip: the ability
## goes off, the cartwheel isn't cut short.
func play(move: String) -> void:
	if not vault.is_empty() and anim_id in CARTWHEELS and move not in CARTWHEELS:
		return
	if encore.running() and move in ThiefUlt.DANCED_OVER:
		return
	super.play(move)

## Her own after-images on every dash: cyan streaks and a spinning cyan star where her hands were (not the
## shared team-colour pill).
func own_dash_trail() -> bool:
	return true

func _tick_trail(dt: float) -> void:
	if h.roll_t <= 0.0 or not tells_visible():
		return
	trail_t -= dt
	if trail_t > 0.0:
		return
	trail_t = TRAIL_EVERY
	var dir := h.roll_dir if h.roll_dir.length() > 0.1 else h.aim_dir()
	fx().streak(h.pos + Vector3(0, 0.7, 0), dir, 1.3, 0.5, GHOST, Color("e0fbff"), 0.3)
	fx().star(h.pos + Vector3(0, 1.0, 0), GHOST, 0.5, 0.22, Color("c9a0ff"))

## After a Vault: the flip (the routine's, ThiefChain; from a jump the air one), the white arc its hands and feet
## trace, the speed and, by its row, the next bolt empowered: the glint forms in the throwing hand and flares as
## she lands.
func _vaulted(air: bool, empower: bool) -> void:
	var dd := dash_def()
	var dir := h.roll_dir if h.roll_dir.length() > 0.1 else h.aim_dir()
	play("thf_exdash" if air else chain.next_flip(dir))
	var t := float(dd["time"])
	_swoosh(dir)
	m.later(t * 0.5, func(): if is_instance_valid(h): _swoosh(dir))
	m.sfx("thief_dash", h.pos, -3.0 if h.is_local() else -7.0, 1.0)
	if not empower:
		return
	haste_t = float(dd["haste_t"])
	var was := primed_t > 0.0
	primed_t = float(dd["primed_t"])
	m.later(t, func():
		if not is_instance_valid(h) or primed_t <= 0.0: return
		glint_pop = 1.0                          # the bolt formed in the hand: empowered
		net_ring(hand_pos(hand == 0), 0.25, EMP_LINE)
		m.sfx("thief_cock", h.pos, -6.0 if h.is_local() else -10.0, 1.0))
	if not was:
		m.sfx("ab_ready", h.pos, -4.0 if h.is_local() else -7.0, 1.0)
		if h.is_local(): h._ab_feedback("dash", "ready")

func _swoosh(dir: Vector2) -> void:
	fx().crescent(h.pos + Vector3(0, 0.85, 0), dir, 300.0, 1.05, GHOST, AIM_LILAC, 0.3,
			PI * 0.5)

# ------------------------------------------------------------------ passive hooks
## Marks make your bolts on that target stronger: +10% of a bolt each, a flat add like the source's +16 a stack,
## so on the empowered bolt they add to its plain-bolt part, not to the bonus.
func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	var weapon := String(o.get("src", "")) == "shot" and String(o.get("ab", "")) == ""
	if not weapon:
		return dmg
	var bolt := dmg / empowered_k() if t == primed_on else dmg
	return dmg + bolt * float(res_def().get("per_mark", 0.1)) * float(marks_on(t))

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or t.dead:
		return
	if String(o.get("src", "")) != "shot" or String(o.get("ab", "")) != "":
		return          # only your weapon's hits stack
	if primed_on != null and primed_on == t:
		primed_on = null
		_primed_hit(t)
		return
	add_mark(t, 1)

## The empowered bolt landed: two Marks (the owner's faster stacking), and the Vault comes back on the spot, from a
## jump too (its damage was on the bolt itself). Weight without a blast: a blue blade flash on them and the reset
## snap on her.
func _primed_hit(t: Ent) -> void:
	primed_hits += 1
	add_mark(t, int(dash_def()["prime_marks"]), true)
	h.dashes = h.max_dashes()
	h.ex_cd = 0.0
	chain.on_reset()
	DashReset.cue(h)
	_reset_fx(t)
	m.later(0.06, func(): if is_instance_valid(h): play("thf_reset"))

## The empowered hit and the reset, in her colours: a blue-white star and an upright blade arc on the target (the
## source's red-white flash with its blue chakram), a white four-point glint with RESET at her throwing hand,
## its own sound (no self-shake: item 50).
func _reset_fx(t: Ent) -> void:
	var at := t.pos + Vector3(0, 1.0, 0)
	var dir := Vector2(t.pos.x - h.pos.x, t.pos.z - h.pos.z)
	fx().star(at, EMP_BLUE, 2.2, 0.2, Color.WHITE)
	fx().crescent(at, dir, 160.0, 1.2, EMP_BLUE, Color.WHITE, 0.2, PI * 0.5)
	m.fx.flash(at, Color("e8f6ff"), 1.0, 0.08)
	var at_hand := hand_pos(hand == 1)
	fx().star(at_hand, Color.WHITE, 1.4, 0.28, GHOST)
	m.fx.word(at_hand + Vector3(0, 0.7, 0), "RESET", GHOST, false)
	m.sfx("pay_cashin", at, -2.0, 1.0)
	net_bolt(at, at + Vector3(0, 1.4, 0), EMP_BLUE)
	CombatBus.ability_used.emit(h, id + "_payoff", "secondary")

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
	var who: String = "TAKEN" if mine else "ASSIST"
	m.fx.word(h.pos + Vector3(0, 2.6, 0), "+%d" % int(round(got)) if got >= 1.0 else who, Color("7fe08a"), true)
	m.sfx("dj_heal", h.pos, -4.0, 1.0)

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
	# a strip with chevrons in the Bola's violet (the source's is white); the gold fill front runs to the throw
	AimKit.lane(h, "rmb",
			{"len": lane_len(), "width": float(bd["lane_w"]), "chevrons": 4, "tip": true, "fill": k,
					"col": BOLA_CORD, "col2": BOLA_HOT, "alpha": 1.6})
	_whirl_bola()
	if float(bola_cast["t"]) <= 0.0:
		bola_cast = {}
		AimKit.hide(h, "rmb")
		fx().unplace("bolaw%d" % h.get_instance_id())
		_throw_bola()

## The two weights whirling round the raised hand through the wind-up (everyone sees them).
func _whirl_bola() -> void:
	# over her head, where the raised hand circles (from above the hand itself hides under the hood)
	var top := h.pos + Vector3(0, 2.0 * float(h.cdat.get("scale", 1.0)), 0)
	var at := hand_pos(true).lerp(top, 0.6)
	var spin: float = m.time * 24.0
	fx().place("bolaw%d" % h.get_instance_id(), "bola", at, Vector2(cos(spin), sin(spin)), col_of(rmb_def()),
			BOLA_CORD, 0.0, 0.0)

func _throw_bola() -> void:
	var bd: Dictionary = rmb_def()["bola"]
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(bd["speed"]),
			"range": float(bd["range"]), "size": 0.3},
		"effects": [{"type": "damage", "amount": float(bd["dmg"])},
				{"type": "slow", "duration": float(bd["ground"]), "strength": float(bd["slow"])}]})
	var dv := h.aim_dir()
	bola = {"pos": h.pos + Vector3(dv.x * 0.5, 1.0, dv.y * 0.5), "dir": dv, "left": float(bd["range"]), "first": null,
			"bounces": int(bd["bounces"]), "stg": stg}
	m.sfx("dj_bola_throw", h.pos, -3.0, 1.0)
	Feel.cast_sound(m, "projectile", "control", h.pos, h)
	# the yellow flash of the throw
	fx().star(h.pos + Vector3(dv.x * 0.6, 1.2, dv.y * 0.6), col_of(rmb_def()), 0.8, 0.12)
	net_bolt(h.pos + Vector3(0, 1.0, 0), h.pos + Vector3(dv.x, 0, dv.y) * lane_len() + Vector3(0, 1.0, 0),
			col_of(rmb_def()))

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
					m.brk.hit(b, h)
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
	fx().place("bola%d" % h.get_instance_id(), "bola", p, dir * spd, col_of(rmb_def()), BOLA_CORD, 1.0, 0.25)

func _walled(q: Vector3) -> bool:
	return m.world.is_block(q.x, q.z) or m.world.ground_at(q.x, q.z) > q.y - 0.4

func _end_bola(at: Vector3) -> void:
	bola = {}
	fx().unplace("bola%d" % h.get_instance_id())
	m.fx.burst(at, col_of(rmb_def()), 5, 2.0, 0.25, 6.0, 0.6)

## The Bola wraps its first foe: its stage (damage), Grounded and slowed, a Mark, the binding rings.
func _wrap(f: Ent) -> void:
	var stg: StageSpec = bola["stg"]
	KinExec.apply_foe(stg.effects, f, cx("rmb", "bola", f.pos, {"at": f.pos}), f.pos, stg)
	if not is_instance_valid(f) or f.dead: return
	KitStatus.apply(f, "gnd", _ground_t())
	add_mark(f, 1, true)
	wrapped[f.get_instance_id()] = [f, _ground_t()]
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
		AimKit.circle(h, "gnd%d" % key,
				{"at": e.pos, "r": r, "col": BOLA_HOT, "all": true, "lw": 0.1, "alpha": 1.4})
		AimKit.circle(h, "gnd2%d" % key,
				{"at": e.pos, "r": r * 0.7, "col": BOLA_HOT, "all": true, "dashed": true})

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
		t.hurt(float(bd["pair_dmg"]) * power("sec"), h,
				{"src": "abil", "ab": "utility", "tags": ["utility", "bola"], "stun": float(bd["pair_stun"]),
						"dr": true})
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
	m.sfx("thief_bola_stun", mid, -2.0, 1.0)
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
		"effects": [{"type": "damage", "amount": float(ed["dmg"])},
				{"type": "slow", "duration": float(ed["slow_t"]), "strength": float(ed["slow"])}]})
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
	if f and rank("kin") >= 3:
		h.dashes = h.max_dashes()           # Shadow Knife rank 3: a knife in a foe gives the Vault back
		DashReset.cue(h)
	fx().star(at + Vector3(0, 1.0 if f else 0.3, 0), Color("ffcf5a"), 0.8, 0.2)
	m.sfx("thief_knife_stick", at, -6.0, 1.0)
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
		fx().place("knife%d" % h.get_instance_id(), "dagger", at + Vector3(0, 1.2 if f != null else 0.35, 0), dv * 0.01,
				col_of(e_def()), Color("ffcf5a"), 0.2, 0.2)
	AimKit.circle(h, "knife", {"at": at, "r": 1.6, "col": KNIFE_VIOLET, "ticks": true, "alpha": 1.0})

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
	if in_dash():
		h.roll_t = 0.0                  # the blink ends a cartwheel: she arrives standing
		vault = {}
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
	net_bolt(from + Vector3(0, 0.9, 0), to + Vector3(0, 0.9, 0), GHOST)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	# Encore once a foe is well inside the ring's reach (it rides with her, so she can chase them)
	if HeroUlt.ready(self) and los and dist < float(x_def()["reach"]) * 0.7:
		HunterKeys.ult_pressed(h)
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
