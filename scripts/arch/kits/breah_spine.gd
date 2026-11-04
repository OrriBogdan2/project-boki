class_name BreahSpine
extends RefCounted
## Tarek's ultimate on X, Basalt Spine (HeroUlt): a long ridge of rocks across the fight. Tap X for a ridge
## centred at the cursor, across her aim; hold X and drag the cursor to swing it round that centre, let go
## to cast. Everyone then sees a 0.2s line of molten cracks, and the rocks erupt from the centre outward
## over 0.4s, slowing whoever stands beside them and shoving anyone on the line aside. They are ordinary
## rocks of hers, one rock deep (block foes and their shots, stand on them, punch them into foes). Only
## solid ground takes a rock: the line is clipped where it crosses the abyss (no walkway), and a line with
## no ground under it is refused with a small "no ground" cue, unspent. Bond: a hunter slowed by the rise,
## or hit by one of its rocks while the bond window is open, counts as a land (HeroUlt.landed).

const CRACK_COL := Color("ff4a1f")
const PREVIEW_COL := Color("f4ead8")
const PUSH_PAD := 0.15                  # m past the rock's half thickness a body on the line is moved to
const CRACK_LW := 0.16                  # m: the cracks are a heavy line, wider than an aim reticle
const PUFF_GAP := 0.02                  # s between fire puffs walking along the cracks

var k: DolmKit
var phase := ""                         # "" | "aim" (X held) | "tell" (the cracks) | "up" (rising, standing)
var phase_t := 0.0
var center := Vector3.ZERO
var press_aim := Vector3.ZERO           # the cursor at the press (the centre may sit short of it, clamped)
var axis := Vector2.RIGHT               # along the ridge
var spots: Array = []                   # [{at: Vector3, delay: float, done: bool}], solid ground only
var cast_n := 0
var erupt_at := -99.0
var rock_dmg_taken := {}                # target instance id -> damage this cast's rocks dealt it
# counters for the checks
var casts := 0
var rocks_raised := 0
var slowed := 0
var refused := 0
var shoved := 0
var first_rise_t := -1.0
var last_rise_t := -1.0

func _init(kit: DolmKit) -> void:
	k = kit

func xd() -> Dictionary: return k.x_def()

func running() -> bool: return phase != ""

func aiming() -> bool: return phase == "aim"

## X pressed: fix the centre at the cursor (clamped) and start aiming. The cast happens on release.
func start() -> bool:
	if running():
		return false
	center = AimMode.point(k.h, float(xd()["range"]))
	press_aim = k.aim()
	axis = _across_aim()
	phase = "aim"
	phase_t = 0.0
	k.play("breah_spine_aim")
	return true

## A Boki merge (or a stun or knock) ends the aim before anything was cast: the ult is not spent.
func drop() -> void:
	if phase == "aim":
		phase = ""
		k.cd["x"] = 0.0
		AimKit.hide(k.h, "x")

func tick(dt: float) -> void:
	match phase:
		"aim":
			_tick_aim(dt)
		"tell":
			_tick_tell(dt)
		"up":
			_tick_up(dt)

func _across_aim() -> Vector2:
	var to := Vector2(center.x - k.h.pos.x, center.z - k.h.pos.z)
	var dir := to.normalized() if to.length() > 0.2 else k.h.aim_dir()
	return Vector2(-dir.y, dir.x)

## While X is held the ridge pivots on its centre toward the cursor once the cursor has moved
## `drag_min` from where it was pressed; a tap keeps it across the aim.
func _tick_aim(dt: float) -> void:
	phase_t += dt
	var h := k.h
	if h.downed or h.stun_t > 0.0:
		drop()
		return
	var cur := k.aim()
	var moved := Vector2(cur.x - press_aim.x, cur.z - press_aim.z).length()
	var drag := Vector2(cur.x - center.x, cur.z - center.z)
	if moved >= float(xd()["drag_min"]) and drag.length() > 0.1:
		axis = drag.normalized()
	if h.is_local():
		AimKit.span(h, "x", {"at": center, "dir": axis, "len": float(xd()["len"]), "chevrons": 6, "col": PREVIEW_COL})
	if not _held() or phase_t >= float(xd()["aim_max"]):
		_erupt()

## Is X still down? Main's X path sends only the press, so the local player's key is read here; tests and
## scripted demos hold it through inp["x_down"]. Bots never hold (a tap).
func _held() -> bool:
	if bool(k.h.inp.get("x_down", false)):
		return true
	return k.h.is_local() and Input.is_action_pressed("hunter_ult")

## Release: the cracks show for everyone, the rocks are scheduled centre-out. With no ground anywhere on
## the line the cast is refused and the ult stays ready.
func _erupt() -> void:
	var h := k.h
	AimKit.hide(h, "x")
	var plan := _plan()
	if plan.is_empty():
		_refuse()
		return
	cast_n += 1
	casts += 1
	rock_dmg_taken = {}
	phase = "tell"
	phase_t = 0.0
	spots = plan
	k.play("breah_spine")
	k.m.sfx("br_spine", center, -1.0, 1.0)
	for s in spots:
		var p: Vector3 = s["at"]
		k.m.fx.burst(p + Vector3(0, 0.2, 0), Color("ff7a2a"), 5, 3.0, 0.3, 4.0, 0.9)
		k.m.fx.spark(p, Vector3.UP, Color("ffb347"), 3, 3.0, 30.0, 0.2, 2.0, 0.8)
	k.net_ring(center, 1.2, CRACK_COL)

## The whole line is over the abyss: a puff of grit where it would have been and a small "no ground" note.
func _refuse() -> void:
	refused += 1
	phase = ""
	k.cd["x"] = 0.0
	k.anim_id = ""
	k.m.fx.burst(center + Vector3(0, 0.3, 0), Color(0.55, 0.45, 0.35, 0.8), 8, 2.0, 0.35, -1.0, 0.8)
	if k.h.is_local() and k.m.hud:
		k.m.hud.toast_small("No ground for the ridge", k.col_of(xd()))

## The rock spots along the ridge on solid ground (the rock's middle and both ends), nearest the centre
## first, each with its rise delay.
func _plan() -> Array:
	var n := int(xd()["rocks"])
	var half := float(xd()["len"]) * 0.5
	var reach := float(k.rock_def()["len"]) * 0.5
	var along := Vector3(axis.x, 0, axis.y)
	var out: Array = []
	for i in n:
		var off := lerpf(-half, half, float(i) / float(n - 1))
		var p := AimMode.ground(k.m, center + along * off)
		if not (_solid(p) and _solid(p - along * reach) and _solid(p + along * reach)):
			continue
		out.append({"at": p, "delay": float(xd()["rise"]) * absf(off) / half, "done": false})
	out.sort_custom(func(a, b): return float(a["delay"]) < float(b["delay"]))
	return out

func _solid(p: Vector3) -> bool:
	return not k.m.world.is_void(p.x, p.z) and k.m.world.ground_at(p.x, p.z) > World.VOID + 1.0

func _tick_tell(dt: float) -> void:
	phase_t += dt
	var tell := float(xd()["tell"])
	AimKit.span(k.h, "x_cracks", {
		"at": center, "dir": axis, "len": float(xd()["len"]), "chevrons": 0, "col": CRACK_COL, "all": true,
		"lw": CRACK_LW, "alpha": 1.3,
	})
	var puff: Dictionary = spots[int(phase_t / PUFF_GAP) % spots.size()]
	k.m.fx.burst((puff["at"] as Vector3) + Vector3(0, 0.2, 0), Color("ff5a1f"), 6, 3.5, 0.35, 4.0, 1.2)
	if phase_t >= tell:
		AimKit.hide(k.h, "x_cracks")
		phase = "up"
		phase_t = 0.0
		erupt_at = k.m.time

func _tick_up(dt: float) -> void:
	phase_t += dt
	for s in spots:
		if not bool(s["done"]) and phase_t >= float(s["delay"]):
			s["done"] = true
			_raise(s["at"])
	if phase_t >= float(xd()["rise"]) + float(xd()["time"]):
		phase = ""

func _raise(p: Vector3) -> void:
	var m := k.m
	if not HeroZones.fits(m, p, center.y, false):
		return
	var across := Vector2(axis.y, -axis.x)
	_shove_off_line(p, across)
	var rid := "%s.x%d.%d" % [k.rid_owner(), cast_n, rocks_raised]
	var rd := k.rock_def()
	var w := HeroZones.rock(m, k.h, p, across, rid, float(rd["len"]), float(xd()["time"]), float(rd["hp"]))
	w["ult"] = cast_n
	rocks_raised += 1
	if first_rise_t < 0.0:
		first_rise_t = m.time
	last_rise_t = m.time
	m.fx.burst(p + Vector3(0, 0.5, 0), Color("ff6a1f"), 10, 5.0, 0.35, 6.0, 1.1)
	m.fx.flash(p + Vector3(0, 0.4, 0), Color("ffc070"), 0.8, 0.07)
	for f in k.foes_in(p, float(xd()["slow_r"])):
		var o := {"src": "abil", "ab": "x", "slow": float(xd()["slow_t"]), "slow_k": float(xd()["slow_k"])}
		f.hurt(float(xd()["rise_dmg"]) * k.power("x"), k.h, o)
		if f is Hunter:
			slowed += 1
			HeroUlt.landed(k, f)

## A rock never rises inside a body: whoever stands on the line is moved to the side they were on.
func _shove_off_line(p: Vector3, across: Vector2) -> void:
	var half_len := float(k.rock_def()["len"]) * 0.5
	for e in k.m.hunters:
		if e.dead or absf(e.pos.y - p.y) > 1.5:
			continue
		var to := Vector2(e.pos.x - p.x, e.pos.z - p.z)
		var side_off := to.dot(across)
		var clear: float = HeroZones.ROCK_TH + e.r + PUSH_PAD
		if absf(to.dot(axis)) > half_len + e.r or absf(side_off) >= clear:
			continue
		var sgn := 1.0 if side_off >= 0.0 else -1.0
		var dest: Vector3 = e.pos + Vector3(across.x, 0, across.y) * (clear - absf(side_off)) * sgn
		HeroZones.move_body(k.m, e, dest)
		shoved += 1

## Is this rock one of the ult's, inside the window where its hits still fill the bond?
func bond_open(w_cast: int) -> bool:
	return w_cast == cast_n and k.m.time - erupt_at <= float(xd()["bond_t"])

## Rocks of one cast deal at most `rock_cap` to any one hunter, Shred included (the burst cap with a merge
## after it). Returns the damage to pass to the hit, before the target's Shred.
func capped(target: Ent, dmg: float) -> float:
	if not (target is Hunter):
		return dmg
	var key := target.get_instance_id()
	var shred_k := 1.0 + (minf(target.vuln_k, KinRules.VULN_MAX) if target.vuln_t > 0.0 else 0.0)
	var taken := float(rock_dmg_taken.get(key, 0.0))
	var allowed := maxf(0.0, float(xd()["rock_cap"]) - taken)
	var out := minf(dmg * shred_k, allowed)
	rock_dmg_taken[key] = taken + out
	return out / shred_k
