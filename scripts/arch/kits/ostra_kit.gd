class_name OstraKit
extends ArchKit
## Ostra (medium): Swell, Tether Lantern (a Settled orb after a pause), Lantern Trade, Shard Snap,
## Brimseed, and Nightwell on X (ostra_well.gd). docs/heroes/ostra.md. The loop: hits (ten times as much on
## hunters) fill Swell; Swollen, the seed grows bigger and quicker, Trade lands sooner and Snap hits harder.
## Snap to stun at range, drop the seed on the stunned foe, let it grow, pop it; Trade puts you or the foe
## (and everyone else in its circle) in it.
##
## A thin aim line runs to the cursor the whole time she is out (her reticle); the Snap's wind-up turns
## it into two rails the width of the shard bundle, and holding Shift shows the Trade's two ends.
## The seed is a ground zone placed through HeroZones (legal ground, short of walls, never in the
## abyss) and synced over Net as ["zone", "seed" | "pop", ...]. Looks: KitLooks (pooled).

const PAY := "COLLAPSE"
const TEAL := Color("7fe0d0")
const VOID_COL := Color("b06bff")
const PINK := Color("ff4fd8")

var swollen_t := 0.0
var last_shot_t := -99.0
var shot_seen := 0
var primed := false
var base_wpn: Dictionary = {}
var prime_until := -9.0
var seed: Dictionary = {}      # {pos, t, grow, rmax, sid, vis, burn, col}
var sid_n := 0
var swap: Dictionary = {}      # in flight: {t, T, land, from (where she hovers until it lands)}
var swap_aim := -1.0           # Shift held to aim the Trade (-1: not aiming)
var snap: Dictionary = {}      # the Snap's wind-up: {t, k}
var well: OstraWell            # X: Nightwell
# counters for the checks
var swells := 0
var settled_shots := 0
var swaps := 0
var swapped_foes := 0
var swapped_allies := 0
var swapped_boki := 0
var snaps := 0
var pops := 0
var collapses := 0
var seed_denied := 0
var early_pops := 0            # recasts refused inside the 0.3s minimum
var denied_swaps := 0
var swap_peak := 0.0           # how high the last Trade's lantern flew above its start (checks)

func is_swollen() -> bool: return swollen_t > 0.0

func _setup() -> void:
	well = OstraWell.new(self)

# ------------------------------------------------------------------ X: Nightwell (OstraWell)
func cast_ult() -> bool: return HeroUlt.press(self, well.start)
func has_ult() -> bool: return true
func ult_running() -> bool: return well.running()

func res_text() -> String: return "SWOLLEN" if is_swollen() else "%d" % int(res)
func ready_label() -> String: return "SWOLLEN" if is_swollen() else ""
func e_recastable() -> bool: return not seed.is_empty()

func _hand(up := 1.15) -> Vector3:
	var d := h.aim_dir()
	return h.pos + Vector3(d.x * 0.45 + d.y * 0.25, up, d.y * 0.45 - d.x * 0.25)

# ------------------------------------------------------------------ passive
func add_swell(v: float) -> void:
	if is_swollen() or v <= 0.0:
		return
	res = minf(res_max(), res + v)
	touch_res(float(res_def()["wait"]))
	if res >= res_max():
		swollen_t = float(res_def()["swollen_t"])
		swells += 1
		armed_fx("SWOLLEN", "")
		play("ostra_empower")
		m.fx.ring(h.pos + Vector3(0, 0.05, 0), 2.2, Color("4a1068"), 0.45)      # the vortex disc under her
		m.fx.ring(h.pos + Vector3(0, 0.05, 0), 1.2, PINK, 0.3)
		m.fx.flash(h.pos + Vector3(0, 1.0, 0), PINK, 1.6, 0.1)
		m.sfx("os_empower", h.pos, -2.0, 1.0)

func on_deal(t: Ent, dmg: float, _o: Dictionary) -> void:
	if t == null or t.team == h.team:
		return
	var rd := res_def()
	add_swell(dmg * float(rd["per_dmg"]) * (float(rd["hunter_k"]) if t is Hunter else 1.0))

func on_knock(_t: Hunter, mine: bool) -> void:
	if mine and not h.downed:
		h.heal(h.max_hp * 0.2)
		m.fx.word(h.pos + Vector3(0, 2.2, 0), "+20%", TEAL, false)

func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	# a Settled orb slows what it hits
	if m.time < prime_until and String(
		o.get("src", "")
	) == "shot" and not o.has("ab") and t != null and t.team != h.team:
		prime_until = -9.0
		o["slow"] = float(lmb_def()["prime_slow_t"])
		o["slow_k"] = float(lmb_def()["prime_slow"])
	return dmg

## She hovers in place while the Trade is in flight; the Snap's wind-up slows her.
func move_k() -> float:
	if not swap.is_empty():
		return 0.0
	return 1.0 - float(rmb_def()["snap"]["cast_slow"]) if not snap.is_empty() else 1.0

# ------------------------------------------------------------------ per step
func _tick(dt: float) -> void:
	if is_swollen():
		swollen_t = maxf(0.0, swollen_t - dt)
		res = res_max() * swollen_t / float(res_def()["swollen_t"])
		if swollen_t <= 0.0: res = 0.0
		KitLooks.of(m).hold_on("os_aura", "aura", h, h.pos)
	elif res_wait <= 0.0:
		add_res(-float(res_def()["drain"]) * dt)
	tell = "full" if is_swollen() else ("half" if res > 30.0 else "")
	net_pulse(dt, is_swollen())
	_tick_weapon()
	if not snap.is_empty():
		_tick_snap(dt)
	if swap_aim >= 0.0:
		_tick_swap_aim(dt)
	if not swap.is_empty():
		_tick_swap(dt)
	if not seed.is_empty():
		_tick_seed(dt)
	well.tick(dt)
	_reticle()

## Her reticle: the thin line to the cursor, all the time; the Snap's two rails while it winds up or
## while RMB is held.
func _reticle() -> void:
	if not h.is_local() or h.downed or h.out:
		return
	var sn: Dictionary = rmb_def()["snap"]
	if not snap.is_empty() or (bool(h.inp.get("sec_hold", false)) and rmb_ready()):
		AimKit.hide(h, "aim")
		AimKit.lane(
			h, "snap", {"len": float(sn["range"]), "width": float(sn["width"]), "rails": true, "col": Color("f2eaff")}
		)
	else:
		AimKit.line(h, "aim", {"col": Color("f2eaff"), "alpha": 0.8})

## The Settled orb: after a pause the next shot is harder and faster, a long bright bolt that slows.
func _tick_weapon() -> void:
	if h.wid != "tether_lantern":
		return
	if h.shot_n != shot_seen:
		shot_seen = h.shot_n
		last_shot_t = m.time
		var hot := primed
		KitLooks.of(m).skin_last(h, "orb_hot" if hot else "orb")
		play("ostra_orb_hot" if hot else "ostra_orb")
		if hot: m.sfx("os_orb_hot", h.pos, -4.0, 1.0)      # (the plain orb's sound is the weapon's own)
		if primed:
			primed = false
			settled_shots += 1
			prime_until = m.time + 1.2
			if not base_wpn.is_empty(): h.wpn = base_wpn
			m.fx.ring(h.pos, 1.0, Color("6f7cff"), 0.2)
			m.fx.burst(_hand(), Color(0.45, 0.5, 1.0, 0.9), 8, 3.0, 0.2, 0.0, 1.0)
	if primed and not h.downed:
		KitLooks.of(m).hold_on("os_charge", "mote", h, _hand(), 1.1, Color("6f7cff"))
	if not primed and m.time - last_shot_t >= float(lmb_def()["idle"]) and not h.downed:
		primed = true
		base_wpn = h.wpn
		var w := h.wpn.duplicate()
		w["dmg"] = float(w["dmg"]) * (1.0 + float(lmb_def()["prime_dmg"]))
		w["speed"] = float(w["speed"]) * float(lmb_def()["prime_speed"])
		w["color"] = Color("8f9cff")
		h.wpn = w
		m.sfx("os_prime", h.pos, -12.0, 1.0)

# ------------------------------------------------------------------ dash: Lantern Trade
func swap_time() -> float:
	var dd := dash_def()
	return float(dd["time_swollen"]) if is_swollen() else float(dd["time"])

## Shift: hold to see both ends (where you are, where the lantern lands at the cursor), let go to lob.
## A tap lobs at once. It never travels by itself, so a press in the air or with no charge never sends
## her off in some other direction: it waits for the next charge.
func on_dash(_use_ex: bool) -> bool:
	if not swap.is_empty() or swap_aim >= 0.0:
		return true
	if h.dashes < 1.0:
		denied_swaps += 1
		h._ab_feedback("dash", "deny")
		return true
	swap_aim = 0.0
	play("ostra_swap_aim")
	return true

func _tick_swap_aim(dt: float) -> void:
	swap_aim += dt
	var dd := dash_def()
	if (held("dash") and swap_aim < float(dd["aim_max"])) and not h.downed and h.stun_t <= 0.0:
		var spot := swap_spot()
		AimKit.swap(h, "swap", {"b": spot if spot != Vector3.INF else h.pos, "r": float(dd["radius"]), "col": TEAL})
		return
	swap_aim = -1.0
	if h.downed or h.stun_t > 0.0:
		return
	_swap_cast()

func _swap_cast() -> void:
	var dd := dash_def()
	var land := swap_spot()
	if land == Vector3.INF:
		h._ab_feedback("dash", "deny")
		return
	if not spend_dash(false):
		return
	swap = {"t": swap_time(), "T": swap_time(), "land": land, "from": h.pos, "over_void": h.over_void()}
	swap_peak = 0.0
	play("ostra_swap")
	m.fx.ring(h.pos, float(dd["radius"]), TEAL, 0.35)
	m.fx.ring(land, float(dd["radius"]), VOID_COL, 0.35)
	m.sfx("os_swap_lob", h.pos, -3.0, 1.0)
	net_bolt(h.pos + Vector3(0, 1.2, 0), land + Vector3(0, 0.6, 0), Color("b8f5ea"))
	CombatBus.ability_used.emit(h, String(dd.get("id", "swap")), "dodge")

## Where the lantern lands: walked out from her toward the cursor (short of walls and the abyss edge). Cast
## while hovering over the abyss, the walk can't start, so it lands on the first solid ground back from
## the cursor. Vector3.INF: nowhere.
func swap_spot() -> Vector3:
	var reach := float(dash_def()["reach"])
	var pw := HeroZones.walk(m, h.pos, aim(), reach)
	if pw["ok"]:
		return pw["pos"]
	if not h.over_void():
		return Vector3.INF
	var dir: Vector2 = pw["dir"]
	var want := minf(Vector2(aim().x - h.pos.x, aim().z - h.pos.z).length(), reach)
	while want > 0.5:
		var p := h.pos + Vector3(dir.x, 0, dir.y) * want
		p.y = m.world.ground_at(p.x, p.z)
		if p.y > World.VOID + 1.0 and HeroZones.fits(m, p, p.y, false):
			return p
		want -= HeroZones.STEP
	return Vector3.INF

func _tick_swap(dt: float) -> void:
	var dd := dash_def()
	swap["t"] = float(swap["t"]) - dt
	var land: Vector3 = swap["land"]
	var from: Vector3 = swap["from"]
	_hover_at(from)
	var u := 1.0 - clampf(float(swap["t"]) / float(swap["T"]), 0.0, 1.0)
	# a high lob: up well above the field, then down onto the spot
	var lift := sin(u * PI) * float(dd["lob"])
	swap_peak = maxf(swap_peak, lift)
	var p := from.lerp(land, u) + Vector3(0, 1.2 + lift, 0)
	KitLooks.of(m).hold_on("os_star", "star", h, p, 1.0)
	m.fx.burst(p, Color(0.5, 0.3, 1.0, 0.75), 1, 0.8, 0.35, 0.0, 1.1)
	var r := float(dd["radius"])
	AimKit.swap(h, "swap_fly", {"a": from, "b": land, "r": r, "fill": u, "all": true, "col": TEAL, "col2": VOID_COL})
	KitLooks.of(m).sigil("os_sigil_from", h, AimMode.ground(m, from), r, u, TEAL)
	KitLooks.of(m).sigil("os_sigil_to", h, land, r, u, VOID_COL)
	if h.downed or h.out or h.stun_t > 0.0:
		_swap_end(false)
		return
	if float(swap["t"]) <= 0.0:
		_swap_end(true)

## While the lantern flies she floats where she cast it, at that height, even over the abyss.
func _hover_at(at: Vector3) -> void:
	h.vel = Vector3.ZERO
	if not h.grounded:
		h.pos.y = at.y

## Her after-image on any dash (a merge's dodge): a streak of violet motes off the hem, not the shared pill.
## Her own hand tell (the charge mote) replaces the shared white charge orb.
func charge_orb() -> bool:
	return false

func dash_afterimage() -> bool:
	m.fx.burst(h.pos + Vector3(0, 0.6, 0), Color(0.55, 0.3, 0.95, 0.75), 3, 0.8, 0.4, -0.5, 1.2)
	return true

## A Boki merge ends the Trade in flight (nobody moves), its aim, the Snap's wind-up and the Settled
## orb's prime.
func _drop_holds() -> void:
	swap_aim = -1.0
	snap = {}
	if not swap.is_empty():
		_swap_end(false)
	if primed:
		primed = false
		if not base_wpn.is_empty(): h.wpn = base_wpn
	last_shot_t = m.time
	prime_until = -9.0

func _swap_end(go: bool) -> void:
	var dd := dash_def()
	var land: Vector3 = swap.get("land", h.pos)
	var from: Vector3 = swap.get("from", h.pos)
	var from_void := bool(swap.get("over_void", false))
	swap = {}
	AimKit.hide(h, "swap_fly")
	for key in ["os_star", "os_sigil_from", "os_sigil_to"]:
		KitLooks.of(m).release(key)
	if not go:
		return
	swaps += 1
	m.fx.ring(from, 1.4, TEAL, 0.3)
	m.fx.burst(from + Vector3(0, 1.0, 0), Color(0.5, 0.88, 0.82, 0.85), 16, 4.0, 0.4, -2.0, 1.1)
	_trade_bodies(land, from, float(dd["radius"]))
	_arrive(land, from, from_void)
	if rank("dash") >= 3:
		# allies who were by her side when she left share in it: a shield
		for o2 in m.hunters:
			if o2 != h and o2.team == h.team and not o2.downed and (
				o2.flat_dist(from) < float(dd["ally_r"]) or o2.flat_dist(h) < float(dd["ally_r"])
			):
				o2.shield = maxf(o2.shield, float(dd["ally_shield"]))
				o2.shield_t = 3.0

## Everyone in the landing circle (foes, allies, Boki off the shoulder) goes to where she was, each keeping
## its place in the circle; foes are slowed. Bodies another game owns are moved there over Net.
func _trade_bodies(land: Vector3, from: Vector3, r: float) -> void:
	var dd := dash_def()
	for body in trade_bodies(land, r):
		var off := Vector3(body.pos.x - land.x, 0, body.pos.z - land.z)
		var to := from + off
		var g: float = m.world.ground_at(to.x, to.z)
		if g <= World.VOID + 1.0 or absf(g - from.y) > 1.5:
			to = from
		else:
			to.y = maxf(g, from.y)
		HeroZones.move_body(m, body, to)
		if body.team != h.team:
			swapped_foes += 1
			KitStatus.apply(body, "dsr", float(dd["slow_t"]), float(dd["slow"]))
			m.fx.word(body.pos + Vector3(0, 2.3, 0), "SLOWED", Color("b8a8ff"), false)
		elif body is Kin:
			swapped_boki += 1
		else:
			swapped_allies += 1

## What a Trade landing at `land` would send back: foes, allies and Boki (not riding a shoulder) in the circle.
func trade_bodies(land: Vector3, r: float) -> Array:
	var out: Array = foes_in(land, r)
	for o in m.hunters:
		if o != h and o.team == h.team and not o.downed and not o.dead and o.flat_dist(land) < r + o.r:
			out.append(o)
	for k in m.kins:
		var kin := k as Kin
		var off_shoulder: bool = kin.state in ["active", "flying", "returning"]
		if kin.team == h.team and off_shoulder and not kin.dead and kin.flat_dist(land) < r + kin.r:
			out.append(kin)
	return out

## She appears at the landing spot: at her height over the ground (over the abyss: the height she hovered
## at, if that is higher), with an implosion and her appear pose.
func _arrive(land: Vector3, from: Vector3, from_void: bool) -> void:
	var dd := dash_def()
	var gy: float = m.world.ground_at(land.x, land.z)
	var dy := clampf(from.y - h.ground(), 0.0, float(dd["keep_h"])) if not from_void else 0.0
	var arrive_y := maxf(gy + dy, from.y) if from_void else gy + dy
	h.teleport(Vector3(land.x, arrive_y, land.z))
	h.vel.y = 0.0
	if arrive_y - gy > 0.05: h.grounded = false
	play("ostra_arrive")
	KitLooks.of(m).implode(land, VOID_COL)
	m.fx.ring(land, 1.6, VOID_COL, 0.3)
	m.fx.ring(land, 0.8, TEAL, 0.25)
	m.fx.flash(land + Vector3(0, 1.0, 0), Color("b06bff"), 0.9, 0.08)
	m.sfx("os_swap", land, -2.0, 1.0)
	net_ring(land, 1.6, TEAL)

# ------------------------------------------------------------------ RMB: Shard Snap
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not snap.is_empty():
		return
	if not spend_rmb(): return
	# a 0.2s wind-up: a black orb with a bright rim gathers at her hand, she slows while casting
	snap = {"t": float(rmb_def()["snap"]["wind"])}
	play("ostra_snap_wind")
	m.sfx("os_snap_wind", h.pos, -5.0, 1.0)

func _tick_snap(dt: float) -> void:
	snap["t"] = float(snap["t"]) - dt
	KitLooks.of(m).hold_on("os_snaporb", "dark", h, _hand(), 1.2)
	if h.downed or h.stun_t > 0.0:
		snap = {}
		return
	if float(snap["t"]) <= 0.0:
		snap = {}
		_snap_release()

func _snap_release() -> void:
	var sn: Dictionary = rmb_def()["snap"]
	snaps += 1
	KitLooks.of(m).release("os_snaporb")
	play("ostra_snap")
	var k := power("sec") * (1.0 + float(sn["swollen_k"]) if is_swollen() else 1.0)
	var dir := h.aim_dir()
	var start := Vector3(h.pos.x + dir.x * 0.6, h.pos.y + 0.95 * float(h.cdat["scale"]), h.pos.z + dir.y * 0.6)
	var spd := float(sn["speed"])
	var rng := AimMode.dist(h, float(sn["range"]), AimMode.MAX)
	m.spawn_shot(
		h, start, dir * spd, float(sn["dmg"]) * k, rng / spd, float(sn["size"]), VOID_COL,
		{"kb": 1.0, "tracer": 0.2, "src": "abil", "ab": "rmb", "kx": func(s, at, e, _why): _snap_hit(s, at, e)}
	)
	KitLooks.of(m).skin(m.shots[-1], "spear")
	m.sfx("os_snap", h.pos, -2.0, 1.0)
	m.fx.flash(start, Color("b06bff"), 0.7, 0.07)
	m.fx.burst(start, Color(0.45, 0.15, 0.7, 0.9), 10, 4.0, 0.25, 0.0, 1.1, Vector3(dir.x, 0, dir.y), 40.0)
	AimKit.hide(h, "snap")

## The bundle stuns the first foe it hits, from 0.8s up to 1.8s the further it flew. The stun reads on
## anyone (the training dummy too): stars over the head for as long as it lasts.
func _snap_hit(s: Dictionary, at: Vector3, e: Ent) -> void:
	m.fx.burst(at, Color(0.45, 0.15, 0.7, 0.9), 14, 5.0, 0.3, 0.0, 1.2)
	m.fx.flash(at, PINK, 0.7, 0.08)
	if e == null:
		return
	var sn: Dictionary = rmb_def()["snap"]
	var st: Vector3 = s["start"]
	var kd := clampf(Vector2(at.x - st.x, at.z - st.z).length() / float(sn["range"]), 0.0, 1.0)
	var stun := lerpf(float(sn["stun"][0]), float(sn["stun"][1]), kd)
	s["x"]["stun"] = stun
	s["x"]["dr"] = true
	KitLooks.of(m).crown(e, stun)
	m.fx.word(e.pos + Vector3(0, 2.3, 0), "STUNNED", Color("fff27a"), false)
	m.sfx("os_snap_hit", at, -2.0, 1.0)

# ------------------------------------------------------------------ E: Brimseed
func cast_e() -> bool:
	var ed := e_def()
	var pw := HeroZones.walk(m, h.pos, aim(), float(ed["reach"]))
	var p: Vector3 = pw["pos"]
	if not pw["ok"] or not HeroZones.fits(m, p, h.pos.y, false):
		seed_denied += 1
		if h.is_local() and m.hud: m.hud.toast_small("No ground to plant on", col_of(ed))
		return false
	sid_n += 1
	var sid := "%s.s%d" % [h.nid if h.nid != "" else str(h.get_instance_id()), sid_n]
	var grow := float(ed["grow"]) * (float(ed["grow_swollen_k"]) if is_swollen() else 1.0)
	var rmax := float(ed["rmax_swollen"]) if is_swollen() else float(ed["rmax"])
	var vis := HeroZones.seed_visual(m, sid, p, rmax, grow, TEAL)
	seed = {
		"pos": p, "t": 0.0, "grow": grow, "rmax": rmax, "sid": sid, "vis": vis, "burn": 0.0, "from": _hand(),
		"col": null
	}
	e_t = grow + float(ed["linger"])
	play("ostra_seed")
	m.sfx("os_seed", p, -3.0, 1.0)
	if (m.net_on or HeroZones.capture) and not h.remote:
		HeroZones.tx(
			m, ["zone", "seed", h.nid, sid, m._r(p.x), m._r(p.y), m._r(p.z), snappedf(rmax, 0.1), snappedf(grow, 0.1)]
		)
	return true

func seed_radius() -> float:
	if seed.is_empty(): return 0.0
	return float(seed["rmax"]) * clampf(float(seed["t"]) / float(seed["grow"]), 0.08, 1.0)

func seed_k() -> float:
	return clampf(float(seed["t"]) / float(seed["grow"]), 0.0, 1.0) if not seed.is_empty() else 0.0

func _tick_seed(dt: float) -> void:
	var ed := e_def()
	seed["t"] = float(seed["t"]) + dt
	var p: Vector3 = seed["pos"]
	# the cast: a small orb drops from her hand onto the spot
	var drop := float(ed["drop"])
	if float(seed["t"]) < drop:
		var u := float(seed["t"]) / drop
		var from: Vector3 = seed["from"]
		KitLooks.of(m).hold_on("os_drop", "mote", h, from.lerp(p + Vector3(0, 0.3, 0), u * u), 1.0, VOID_COL)
	AimKit.circle(
		h, "seed",
		{
			"at": p, "r": seed_radius(), "fill": seed_k(), "all": true, "col": TEAL, "col2": VOID_COL,
			"dashed": seed_k() < 1.0
		}
	)
	if seed_k() >= float(ed["tell_k"]) and seed.get("col") == null:
		seed["col"] = KitLooks.of(m).column(p, 30.0)
		m.sfx("os_full", p, -6.0, 1.0)
	if rank("kin") >= 3:
		seed["burn"] = float(seed["burn"]) - dt
		if float(seed["burn"]) <= 0.0:
			seed["burn"] = 0.5
			for f in foes_in(seed["pos"], seed_radius()):
				f.hurt(2.5 * power("kin"), h, {"src": "abil", "ab": "e"})
	if h.downed:
		_pop(false)

func _e_end() -> void:
	if not seed.is_empty():
		_pop(true)

## E again pops it, from 0.3s after the plant (a press before that is eaten, so a double tap can't
## waste the seed).
func e_recast() -> bool:
	if seed.is_empty():
		return false
	if float(seed["t"]) < float(e_def()["min_recast"]):
		early_pops += 1
		return true
	_pop(true)
	e_t = 0.0
	return true

func _pop(hit: bool) -> void:
	var ed := e_def()
	var p: Vector3 = seed["pos"]
	var k := seed_k()
	var rad := seed_radius()
	var sid := String(seed["sid"])
	var vis = seed.get("vis")
	if is_instance_valid(vis): vis.queue_free()
	var colm = seed.get("col")
	if colm != null and is_instance_valid(colm): KitLooks.of(m).end_column(colm)
	seed = {}
	e_t = 0.0
	AimKit.hide(h, "seed")
	HeroZones.seed_pop(m, sid, TEAL)
	if (m.net_on or HeroZones.capture) and not h.remote:
		HeroZones.tx(m, ["zone", "pop", sid])
	if not hit:
		return
	pops += 1
	play("ostra_pop")
	var mult := 1.0 + (float(ed["dmg_max_k"]) - 0.5) * k
	var dmg := float(ed["dmg"]) * mult * power("kin")
	# an implosion: the rim snaps inward to a bright point, then dark shards fly out
	for i in 3:
		var rr := rad * (1.0 - 0.3 * i)
		m.later(0.04 * i, func(): m.fx.ring(p, rr, VOID_COL if i < 2 else Color("f2eaff"), 0.12))
	m.fx.burst(p + Vector3(0, 0.8, 0), VOID_COL, int(14 + 22 * k), -5.0, 0.35, 0.0, 1.2)
	m.later(
		0.12,
		func(): m.fx.spark(
			p + Vector3(0, 0.6, 0), Vector3.UP, Color("2a0a3a"), int(10 + 12 * k), 8.0, 90.0, 0.4, 8.0, 1.2
		)
	)
	m.fx.flash(p + Vector3(0, 0.8, 0), Color("f2eaff"), 1.0 + k, 0.1)
	m.sfx("os_pop", p, -2.0, 1.0)
	Feel.shake(m, "t3" if k > 0.6 else "t2", h, p)
	net_ring(p, rad, TEAL)
	var caught_hunter: Ent = null
	for f in foes_in(p, rad):
		f.hurt(dmg, h, {"src": "abil", "ab": "e", "payoff": k >= 0.99 and f is Hunter})
		KitStatus.apply(f, "gnd", float(ed["ground"]))
		if f is Hunter: caught_hunter = f
	if caught_hunter != null and k >= 0.99:
		collapses += 1
		payoff_fx(caught_hunter.pos, PAY, TEAL, "pay_collapse", h.dir_to(caught_hunter), caught_hunter)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if HeroUlt.ready(self) and dist < 9.0 and los and randf() < 0.1:
		h.inp["aim"] = tgt.pos
		HunterKeys.ult_pressed(h)
		return
	if not seed.is_empty():
		var inside := Vector2(
			tgt.pos.x - float(seed["pos"].x), tgt.pos.z - float(seed["pos"].z)
		).length() < seed_radius()
		if inside or float(seed["t"]) > float(seed["grow"]) * 0.9:
			h.inp["sig"] = true
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < 8.0 and los and randf() < 0.3:
		h.inp["aim"] = tgt.pos
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 11.0 and randf() < 0.5:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		return
	if int(
		h.slot_lv["dash"]
	) > 0 and h.dashes >= 1.0 and swap.is_empty() and dist > 6.0 and dist < 11.0 and los and randf() < 0.15:
		h.inp["aim"] = tgt.pos
		h.inp["dash"] = true
