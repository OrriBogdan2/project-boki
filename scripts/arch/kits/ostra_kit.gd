class_name OstraKit
extends ArchKit
## Motley (medium): Swell, Tether Lantern (the wait between shots charges the next orb), Lantern Trade, Shard Snap,
## Brimseed, and Nightwell on X (ostra_well.gd). docs/heroes/ostra.md. The loop: hits (ten times as much on
## hunters) fill Swell; Swollen, the seed grows bigger and quicker, Trade lands sooner and Snap hits harder.
## Snap to stun at range, drop the seed on the stunned foe, let it grow, pop it; Trade puts you or the foe
## (and everyone else in its circle) in it.
##
## A thin aim line runs to the cursor the whole time he is out (his reticle); the Snap's wind-up turns
## it into two rails the width of the shard bundle, and holding Shift shows the Trade's two ends.
## The seed is a ground zone placed through HeroZones (legal ground, short of walls, never in the
## abyss) and synced over Net as ["zone", "seed" | "pop", ...]. Looks: KitLooks (pooled).

const PAY := "COLLAPSE"
static var TEAL := HeroVfx.col("ostra", "tide")
static var VOID_COL := HeroVfx.col("ostra", "hot")
static var PINK := HeroVfx.col("ostra", "swell")
# the signature: Snap, Brimseed and Nightwell (content/vfx/ostra.json)
static var SEA := HeroVfx.col("ostra", "main")
static var DEEP := HeroVfx.col("ostra", "deep")              # their deep teal: the seed's and the dome's filling accent
const GROUND_HAZARDS := ["hazard", "lava", "spore", "toxic", "molten"]
# the orb's shot colour at full charge (what other games draw)
static var ORB_FULL_COL := HeroVfx.col("ostra", "orb")
static var GLOW_COL := HeroVfx.col("ostra", "glow")          # the charge glow at his hand, starting...
static var GLOW_FULL_COL := HeroVfx.col("ostra", "hot")     # ...and at full charge
static var WHITE := HeroVfx.col("ostra", "white")
const GLOW_SIZE := Vector2(0.4, 1.25)      # the glow's scale (a mote is 0.4m wide at 1), starting and at full

var swollen_t := 0.0
var last_shot_t := -99.0
var shot_seen := 0
var charge := 0.0              # 0..1: the next orb's build-up since the last shot; orb_wpn carries it
var base_wpn: Dictionary = {}  # the weapon as loaded, the plain orb
var orb_wpn: Dictionary = {}   # his live weapon: a copy of base_wpn with the charge written in
var last_orb_c := 0.0          # (checks) the charge and hit radius of the last orb fired
var last_orb_r := 0.0
var seed: Dictionary = {}      # {pos, t, grow, rmax, sid, vis, burn, col}
var sid_n := 0
var swap: Dictionary = {}      # in flight: {t, T, land, cast, from (where he is now), hold (CastHold)}
var swap_aim := -1.0           # Shift held to aim the Trade (-1: not aiming)
var snap: Dictionary = {}      # the Snap's wind-up: {t, T}
var snap_rec := 0.0            # s of recovery left after a release (still slowed)
var well: OstraWell            # X: Nightwell
# counters for the checks
var swells := 0
var settled_shots := 0
var full_chimes := 0
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
var hazards_dodged := 0        # ground-hazard hits his float turned away
var boost_t := 0.0             # Snap rank 3: the speed burst left
var boost_k := 0.0
var swap_peak := 0.0           # how high the last Trade's lantern flew above its start (checks)

func is_swollen() -> bool: return swollen_t > 0.0

func _setup() -> void:
	well = OstraWell.new(self)

# ------------------------------------------------------------------ X: Nightwell (OstraWell)
func cast_ult() -> bool: return HeroUlt.press(self, well.start)
func has_ult() -> bool: return true
func ult_running() -> bool: return well.running()

## Nightwell holds him in the cast pose: no walking, jumping, dashing, other abilities or attacks, no turning.
func cast_locked() -> bool: return well.locked
func aim_lock() -> Vector2: return well.aim_lock
func busy() -> bool: return super.busy() or well.locked
func can_shoot() -> bool: return not well.locked and super.can_shoot()

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
		m.fx.ring(h.pos + Vector3(0, 0.05, 0), 2.2, HeroVfx.col("ostra", "deep"), 0.45)      # the vortex disc under him
		m.fx.ring(h.pos + Vector3(0, 0.05, 0), 1.2, PINK, 0.3)
		m.fx.flash(h.pos + Vector3(0, 1.0, 0), PINK, 1.6, 0.1)
		m.sfx("os_empower", h.pos, -2.0, 1.0)

func on_deal(t: Ent, dmg: float, _o: Dictionary) -> void:
	if t == null or t.team == h.team:
		return
	var rd := res_def()
	add_swell(dmg * float(rd["per_dmg"]) * (float(rd["hunter_k"]) if t is Hunter else 1.0))

## He floats: the ground hazards (lava vents and their pools, spore pods, puddles, the pit's pull) never
## touch him. A sky strike (the lightning rod) still does.
func incoming(_by: Ent, dmg: float, o: Dictionary) -> Array:
	if not o.get("sky", false) and (o.get("tags", []) as Array).any(func(t): return t in GROUND_HAZARDS):
		hazards_dodged += 1
		return [0.0, o]
	return [dmg, o]

func hovering() -> bool:
	return not swap.is_empty()

## He drifts slowly (dash.fly_slow of run speed) while the Trade is in flight; the Snap's wind-up slows him.
func move_k() -> float:
	if well.locked:
		return 0.0
	if not swap.is_empty():
		return (swap["hold"] as CastHold).slow_k
	var casting := not snap.is_empty() or snap_rec > 0.0
	var k := 1.0 - float(rmb_def()["snap"]["cast_slow"]) if casting else 1.0
	return k * (1.0 + boost_k if boost_t > 0.0 else 1.0)

## Snap rank 3: a burst of speed on the cast, a bigger one when it hits (the later one replaces it).
func _boost(k: float) -> void:
	if rank("sec") < 3: return
	var b: Dictionary = rmb_def()["snap"]["boost"]
	boost_k = k
	boost_t = float(b["t"])

# ------------------------------------------------------------------ per step
func _tick(dt: float) -> void:
	boost_t = maxf(0.0, boost_t - dt)
	snap_rec = maxf(0.0, snap_rec - dt)
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

## His reticle: the thin line to the cursor, all the time; the Snap's two rails while it winds up or
## while RMB is held.
func _reticle() -> void:
	if not h.is_local() or h.downed or h.out:
		return
	var sn: Dictionary = rmb_def()["snap"]
	if not snap.is_empty() or (bool(h.inp.get("sec_hold", false)) and rmb_ready()):
		AimKit.hide(h, "aim")
		AimKit.lane(
			h, "snap", {"len": float(sn["range"]), "width": float(sn["width"]), "rails": true, "col": WHITE}
		)
	else:
		AimKit.line(h, "aim", {"col": WHITE, "alpha": 0.8})

## The wait between shots charges the next orb: its damage, speed, size and colour follow the charge, and a
## full one also slows. Written into his live weapon (only when the charge moves), so bots and Net get it too.
func _tick_weapon() -> void:
	if h.wid != "tether_lantern":
		return
	if h.shot_n != shot_seen:
		shot_seen = h.shot_n
		_orb_fired()
	_set_charge(wait_charge())
	if charge > 0.0 and not h.downed and snap.is_empty():
		var col := GLOW_COL.lerp(GLOW_FULL_COL, charge)
		# (on his actual hand, where the 3D model holds its orb: at a fixed point in front of him the match
		# camera drew it as a disc at his feet)
		KitLooks.of(m).hold_on("os_charge", "mote", h, hand_pos(true), lerpf(GLOW_SIZE.x, GLOW_SIZE.y, charge), col)

## The next orb's charge from the time since the last shot: 0 until lmb.charge_from (the fire rate, so held
## fire stays plain orbs), then a straight build to 1 at lmb.idle.
func wait_charge() -> float:
	var ld := lmb_def()
	var from := float(ld["charge_from"])
	return clampf((m.time - last_shot_t - from) / (float(ld["idle"]) - from), 0.0, 1.0)

func _set_charge(k: float) -> void:
	var fresh := not is_same(h.wpn, orb_wpn)      # first step, or a weapon upgrade replaced it
	if fresh:
		base_wpn = h.wpn
		orb_wpn = base_wpn.duplicate()
		h.wpn = orb_wpn
	elif k == charge:
		return
	var ld := lmb_def()
	var shot_x: Dictionary = (base_wpn["shot_x"] as Dictionary).duplicate()
	if k >= 1.0:
		shot_x["slow"] = float(ld["prime_slow_t"])
		shot_x["slow_k"] = float(ld["prime_slow"])
		if charge < 1.0 and not h.downed:
			full_chimes += 1
			m.sfx("os_prime", h.pos, -12.0, 1.0)      # the soft chime at full
			m.fx.flash(hand_pos(true), GLOW_FULL_COL, 0.45, 0.08)
	orb_wpn["shot_x"] = shot_x
	orb_wpn["dmg"] = float(base_wpn["dmg"]) * (1.0 + float(ld["prime_dmg"]) * k)
	orb_wpn["speed"] = float(base_wpn["speed"]) * lerpf(1.0, float(ld["prime_speed"]), k)
	orb_wpn["size"] = float(base_wpn["size"]) * orb_size_k(k)
	orb_wpn["color"] = Color(base_wpn["color"]).lerp(ORB_FULL_COL, k)
	charge = k

## The orb's size at charge k, as a share of the plain orb's.
func orb_size_k(k: float) -> float:
	return 1.0 + float(lmb_def()["size_k"]) * k

## The orb just left at the charge it was fired with; a full one has its own flick, sound and flash.
func _orb_fired() -> void:
	last_shot_t = m.time
	last_orb_c = charge
	last_orb_r = float(h.wpn["size"])
	KitLooks.of(m).release("os_charge")
	KitLooks.of(m).skin_orb(h, charge, orb_size_k(charge))
	var full := charge >= 1.0
	play("ostra_orb_hot" if full else "ostra_orb")
	if full:
		settled_shots += 1
		m.sfx("os_orb_hot", h.pos, -4.0, 1.0)      # (the plain orb's sound is the weapon's own)
		m.fx.burst(_hand(), Color(HeroVfx.col("ostra", "hot"), 0.9), 8, 3.0, 0.2, 0.0, 1.0)

## A seed now waits for its recast, so a kit swapped out (practice, the Arena) takes its seed with it.
func teardown() -> void:
	if not seed.is_empty():
		_pop(false)
	if is_same(h.wpn, orb_wpn):
		h.wpn = base_wpn
	super.teardown()

# ------------------------------------------------------------------ dash: Lantern Trade
func swap_time() -> float:
	var dd := dash_def()
	return float(dd["time_swollen"]) if is_swollen() else float(dd["time"])

## His dash, as DashFlow sees it: the Trade's flight (content/dash_flow/ostra.json routes presses made during it).
func in_dash() -> bool:
	return super.in_dash() or not swap.is_empty()

## s left in his dash: the Trade's flight, else the shared dash's.
func dash_left() -> float:
	return float(swap["t"]) if not swap.is_empty() else super.dash_left()

## Shift: hold to see both ends (where you are, where the lantern lands at the cursor), let go to lob.
## A tap lobs at once. It never travels by itself, so a press in the air or with no charge never sends
## him off in some other direction: it waits for the next charge.
func on_dash(_use_ex: bool) -> bool:
	if well.locked:
		well.press_dash()
		return true
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
		AimKit.swap(h, "swap", {"b": spot, "r": float(dd["radius"]), "col": TEAL})
		return
	swap_aim = -1.0
	if h.downed or h.stun_t > 0.0:
		return
	_swap_cast()

func _swap_cast() -> void:
	var dd := dash_def()
	var land := swap_spot()
	if not spend_dash(false):
		return
	swap = {
		"t": swap_time(), "T": swap_time(), "land": land, "cast": h.pos, "from": h.pos,
		"hold": CastHold.hover_slow(h, float(dd["fly_slow"])),
	}
	swap_peak = 0.0
	play(swap_move())
	m.fx.ring(h.pos, float(dd["radius"]), TEAL, 0.35)
	m.fx.ring(land, float(dd["radius"]), VOID_COL, 0.35)
	m.sfx("os_swap_lob", h.pos, -3.0, 1.0)
	net_bolt(h.pos + Vector3(0, 1.2, 0), land + Vector3(0, 0.6, 0), HeroVfx.col("ostra", "hot"))
	CombatBus.ability_used.emit(h, String(dd.get("id", "swap")), "dodge")

## His dash moves: the underhand lob from the ground, the overhead sling and streaming drift in the air.
func swap_move() -> String:
	return "ostra_swap" if h.grounded else "ostra_swap_air"

## Where the lantern lands: the cursor if it is within reach, else the point at full reach along the cursor
## direction. No ground, wall or abyss check limits it; over the abyss it keeps his current height.
func swap_spot() -> Vector3:
	var reach := float(dash_def()["reach"])
	var a := aim()
	var dv := Vector2(a.x - h.pos.x, a.z - h.pos.z)
	if dv.length() > reach:
		dv = dv.normalized() * reach
	var p := Vector3(h.pos.x + dv.x, h.pos.y, h.pos.z + dv.y)
	var g: float = m.world.ground_at(p.x, p.z)
	if g > World.VOID + 1.0:
		p.y = g
	return p

func _tick_swap(dt: float) -> void:
	var dd := dash_def()
	swap["t"] = float(swap["t"]) - dt
	var land: Vector3 = swap["land"]
	var cast_at: Vector3 = swap["cast"]
	var from: Vector3 = (swap["hold"] as CastHold).tick(m.world)
	swap["from"] = from
	var u := 1.0 - clampf(float(swap["t"]) / float(swap["T"]), 0.0, 1.0)
	# a high lob: up well above the field, then down onto the spot
	var lift := sin(u * PI) * float(dd["lob"])
	swap_peak = maxf(swap_peak, lift)
	var p := cast_at.lerp(land, u) + Vector3(0, 1.2 + lift, 0)
	KitLooks.of(m).hold_on("os_star", "star", h, p, 1.0)
	m.fx.burst(p, Color(HeroVfx.col("ostra", "main"), 0.75), 1, 0.8, 0.35, 0.0, 1.1)
	var r := float(dd["radius"])
	AimKit.swap(h, "swap_fly", {"a": from, "b": land, "r": r, "fill": u, "all": true, "col": TEAL, "col2": VOID_COL})
	KitLooks.of(m).sigil("os_sigil_from", h, AimMode.ground(m, from), r, u, TEAL)
	KitLooks.of(m).sigil("os_sigil_to", h, land, r, u, VOID_COL)
	if h.downed or h.out or h.stun_t > 0.0:
		_swap_end(false)
		return
	if float(swap["t"]) <= 0.0:
		_swap_end(true)

## His after-image on any dash (a merge's dodge): a streak of teal motes off the hem, not the shared pill.
## His own hand tell (the charge mote) replaces the shared white charge orb.
func charge_orb() -> bool:
	return false

func dash_afterimage() -> bool:
	m.fx.burst(h.pos + Vector3(0, 0.6, 0), Color(HeroVfx.col("ostra", "main"), 0.75), 3, 0.8, 0.4, -0.5, 1.2)
	return true

## A Boki merge ends the Trade in flight (nobody is sent), its aim, the Snap's wind-up and the Settled
## orb's prime.
func _drop_holds() -> void:
	well.unlock(false)
	swap_aim = -1.0
	snap = {}
	snap_rec = 0.0
	if not swap.is_empty():
		_swap_end(false)
	last_shot_t = m.time
	if is_same(h.wpn, orb_wpn):
		_set_charge(0.0)

func _swap_end(go: bool) -> void:
	var dd := dash_def()
	var land: Vector3 = swap.get("land", h.pos)
	var from: Vector3 = swap.get("from", h.pos)
	var from_void := h.over_void()
	swap = {}
	AimKit.hide(h, "swap_fly")
	for key in ["os_star", "os_sigil_from", "os_sigil_to"]:
		KitLooks.of(m).release(key)
	if not go:
		return
	swaps += 1
	_fold_in(from, TEAL)
	_trade_bodies(land, from, float(dd["radius"]))
	_arrive(land, from, from_void)
	if rank("dash") >= 3:
		# allies who were by his side when he left share in it: a shield
		for o2 in m.hunters:
			if o2 != h and o2.team == h.team and not o2.downed and (
				o2.flat_dist(from) < float(dd["ally_r"]) or o2.flat_dist(h) < float(dd["ally_r"])
			):
				o2.shield = maxf(o2.shield, float(dd["ally_shield"]))
				o2.shield_t = 3.0

## Everyone in the landing circle (foes, allies, Boki off the shoulder) goes to where he was, each keeping
## its place in the circle. Bodies another game owns are moved there over Net.
func _trade_bodies(land: Vector3, from: Vector3, r: float) -> void:
	for body in trade_bodies(land, r):
		var off := Vector3(body.pos.x - land.x, 0, body.pos.z - land.z)
		var to := from + off
		var g: float = m.world.ground_at(to.x, to.z)
		if g <= World.VOID + 1.0 or absf(g - from.y) > 1.5:
			to = from
		else:
			to.y = maxf(g, from.y)
		m.displace.teleport(body, to)
		if body.team != h.team:
			swapped_foes += 1
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

## He appears at the landing spot: at his height over the ground (over the abyss: the height he hovered
## at, if that is higher; landing over the abyss also keeps it), with an implosion and his appear pose.
func _arrive(land: Vector3, from: Vector3, from_void: bool) -> void:
	var dd := dash_def()
	var gy: float = m.world.ground_at(land.x, land.z)
	var dy := clampf(from.y - h.ground(), 0.0, float(dd["keep_h"])) if not from_void else 0.0
	var arrive_y := maxf(gy + dy, from.y) if from_void or gy <= World.VOID + 1.0 else gy + dy
	h.teleport(Vector3(land.x, arrive_y, land.z))
	h.vel.y = 0.0
	if arrive_y - gy > 0.05: h.grounded = false
	play("ostra_arrive")
	_fold_in(land, VOID_COL)
	m.fx.flash(land + Vector3(0, 1.0, 0), HeroVfx.col("ostra", "hot"), 0.9, 0.08)
	m.sfx("os_swap", land, -2.0, 1.0)
	net_ring(land, 1.6, TEAL)

## Both ends of a Trade fold in on themselves (motes drawn inward, no ring or blast: the dash rule).
func _fold_in(at: Vector3, col: Color) -> void:
	m.fx.burst(at + Vector3(0, 1.0, 0), Color(col, 0.9), 20, -6.0, 0.3, 0.0, 1.3)
	m.fx.burst(at + Vector3(0, 1.0, 0), Color(HeroVfx.col("ostra", "void"), 0.9), 8, -3.0, 0.25, 0.0, 1.8)

# ------------------------------------------------------------------ RMB: Shard Snap
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not snap.is_empty():
		return
	if not spend_rmb(): return
	# the wind-up: a black orb with a bright rim gathers and swells at his hand, he slows while casting
	var wind := float(rmb_def()["snap"]["wind"])
	snap = {"t": wind, "T": wind}
	play("ostra_snap_wind")
	m.sfx("os_snap_wind", h.pos, -5.0, 1.0)
	vfx("snap_wind", _hand())

func _tick_snap(dt: float) -> void:
	snap["t"] = float(snap["t"]) - dt
	var grown := 1.0 - clampf(float(snap["t"]) / float(snap["T"]), 0.0, 1.0)
	KitLooks.of(m).hold_on("os_snaporb", "dark", h, _hand(), lerpf(0.5, 1.3, grown))
	if h.downed or h.stun_t > 0.0:
		snap = {}
		return
	if float(snap["t"]) <= 0.0:
		snap = {}
		_snap_release()

func _snap_release() -> void:
	var sn: Dictionary = rmb_def()["snap"]
	snaps += 1
	snap_rec = float(sn["recover"])
	KitLooks.of(m).release("os_snaporb")
	play("ostra_snap")
	var k := power("sec") * (1.0 + float(sn["swollen_k"]) if is_swollen() else 1.0)
	var dir := h.aim_dir()
	var start := Vector3(h.pos.x + dir.x * 0.6, h.pos.y + 0.95 * float(h.cdat["scale"]), h.pos.z + dir.y * 0.6)
	var spd := float(sn["speed"])
	var rng := AimMode.dist(h, float(sn["range"]), AimMode.MAX)
	m.spawn_shot(
		h, start, dir * spd, float(sn["dmg"]) * k, rng / spd, float(sn["size"]), SEA,
		{"kb": 1.0, "tracer": 0.2, "src": "abil", "ab": "rmb", "kx": func(s, at, e, _why): _snap_hit(s, at, e)}
	)
	HeroVfx.of(m).trail(h, "snap_trail", KitLooks.of(m).skin(m.shots[-1], "spear"))
	m.sfx("os_snap", h.pos, -2.0, 1.0)
	_boost(float(sn["boost"]["cast"]))
	vfx("snap", start, dir)
	AimKit.hide(h, "snap")

## The bundle stuns the first foe it hits, from 0.8s up to 1.8s the further it flew. The stun reads on
## anyone (the training dummy too): stars over the head for as long as it lasts.
func _snap_hit(s: Dictionary, at: Vector3, e: Ent) -> void:
	vfx("snap_hit", AimMode.ground(m, at))
	if e == null:
		return
	var sn: Dictionary = rmb_def()["snap"]
	var st: Vector3 = s["start"]
	var kd := clampf(Vector2(at.x - st.x, at.z - st.z).length() / float(sn["range"]), 0.0, 1.0)
	var stun := lerpf(float(sn["stun"][0]), float(sn["stun"][1]), kd)
	s["x"]["stun"] = stun
	s["x"]["dr"] = true
	_boost(float(sn["boost"]["hit"]))
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
	var vis := HeroZones.seed_visual(m, sid, p, rmax, grow, SEA)
	seed = {
		"pos": p, "t": 0.0, "grow": grow, "rmax": rmax, "sid": sid, "vis": vis, "burn": 0.0, "from": _hand(),
		"col": null
	}
	e_t = grow + float(ed["hold_full"])
	play("ostra_seed")
	m.sfx("os_seed", p, -3.0, 1.0)
	m.later(float(ed["drop"]), func(): vfx("seed_plant", p))
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
	# the cast: a small orb drops from his hand onto the spot
	var drop := float(ed["drop"])
	if float(seed["t"]) < drop:
		var u := float(seed["t"]) / drop
		var from: Vector3 = seed["from"]
		KitLooks.of(m).hold_on("os_drop", "mote", h, from.lerp(p + Vector3(0, 0.3, 0), u * u), 1.0, SEA)
	AimKit.circle(
		h, "seed",
		{
			"at": p, "r": seed_radius(), "fill": seed_k(), "all": true, "col": SEA, "col2": DEEP,
			"dashed": seed_k() < 1.0
		}
	)
	if seed_k() >= float(ed["tell_k"]) and seed.get("col") == null:
		seed["col"] = KitLooks.of(m).column(p, 30.0)
		m.sfx("ostra_music_box", p, -6.0, 1.0)      # the crank's tune: the box is about to pop
	if rank("kin") >= 3:
		seed["burn"] = float(seed["burn"]) - dt
		if float(seed["burn"]) <= 0.0:
			seed["burn"] = float(ed["burn_every"])
			for f in foes_in(seed["pos"], seed_radius()):
				f.hurt(float(ed["burn"]) * float(ed["burn_every"]) * power("kin"), h, {"src": "abil", "ab": "e"})
	if h.downed:
		_pop(false)

## The source detonates only on the recast: a seed left at full size this long (e.hold_full) fizzles out
## with no damage, so it can't be parked forever.
func _e_end() -> void:
	if not seed.is_empty():
		_pop(false)

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
	HeroZones.seed_pop(m, sid, SEA)
	if (m.net_on or HeroZones.capture) and not h.remote:
		HeroZones.tx(m, ["zone", "pop", sid])
	if not hit:
		return
	pops += 1
	play("ostra_pop")
	var mult := 1.0 + (float(ed["dmg_max_k"]) - 1.0) * k
	var dmg := float(ed["dmg"]) * mult * power("kin")
	# an implosion: the void swallows the rim to a point, then teal shards and dark debris fly out
	vfx("seed_pop", p, null, {"r": rad, "k": k})
	m.sfx("os_pop", p, -2.0, 1.0)
	m.sfx("ostra_spring_boing", p, -3.0, 1.0)     # the jack springs out
	var caught_hunter: Ent = null
	for f in foes_in(p, rad):
		f.hurt(dmg, h, {"src": "abil", "ab": "e", "payoff": k >= 0.99 and f is Hunter})
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
