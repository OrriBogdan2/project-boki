class_name BreahSpine
extends RefCounted
## Tarek's ultimate on X, Basalt Spine (HeroUlt): a ridge of rocks laid in a shallow arc round him. Tap X for
## a ridge centred at the cursor, across his aim, bowing away from him (its ends curve back toward him by
## `bend` degrees in all); hold X and drag the cursor to swing it round that centre, let go to cast. Everyone
## then sees a 0.2s line of cobalt cracks (HeroVfx), and the rocks erupt from the centre outward over 0.4s, slowing
## whoever stands beside them and shoving anyone on the line aside. They are ordinary rocks of his, one rock
## deep (block foes and their shots, stand on them, punch them into foes). Over the abyss the rocks are
## ground for as long as they stand (Ent.over_void reads StoneStand): the ridge is a walkway, and when the
## rocks crumble whoever stands on them falls. Bond: a hunter slowed by the rise, or hit by one of its
## rocks while the bond window is open, counts as a land (HeroUlt.landed).

const PREVIEW_COL := Color("d8ecff")
const PUSH_PAD := 0.15                  # m past the rock's half thickness a body on the line is moved to

var k: DolmKit
var phase := ""                         # "" | "aim" (X held) | "tell" (the cracks) | "up" (rising, standing)
var phase_t := 0.0
var center := Vector3.ZERO
var press_aim := Vector3.ZERO           # the cursor at the press (the centre may sit short of it, clamped)
var axis := Vector2.RIGHT               # along the ridge
var bow := Vector2.ZERO                 # unit normal its middle bulges toward (away from him), fixed at the cast
var spots: Array = []                   # [{at: Vector3, dir: Vector2 (the ridge there), delay: float, done: bool}]
var cast_n := 0
var erupt_at := -99.0
var rock_dmg_taken := {}                # target instance id -> damage this cast's rocks dealt it
# counters for the checks
var casts := 0
var rocks_raised := 0
var slowed := 0
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
		AimKit.span(h, "x", _span_p({"chevrons": 6, "col": PREVIEW_COL}))
	if not _held() or phase_t >= float(xd()["aim_max"]):
		_erupt()

## Is X still down? Main's X path sends only the press, so the local player's key is read here; tests and
## scripted demos hold it through inp["x_down"]. Bots never hold (a tap).
func _held() -> bool:
	if bool(k.h.inp.get("x_down", false)):
		return true
	return k.h.is_local() and Input.is_action_pressed("hunter_ult")

## Release: the cracks show for everyone, the rocks are scheduled centre-out.
func _erupt() -> void:
	var h := k.h
	AimKit.hide(h, "x")
	cast_n += 1
	casts += 1
	rock_dmg_taken = {}
	phase = "tell"
	phase_t = 0.0
	spots = _plan()
	k.play("breah_spine")
	k.vfx("spine", center, axis)
	for s in spots:
		k.vfx("spine_lane", s["at"], s["dir"])

## The ridge's line as an AimKit.span: the data's length and bend, bowing away from him.
func _span_p(extra: Dictionary) -> Dictionary:
	var side := _bow() if phase == "aim" else bow
	extra.merge({"at": center, "dir": axis, "len": float(xd()["len"]), "bend": _bend(), "bow": side})
	return extra

func _bend() -> float: return deg_to_rad(float(xd()["bend"]))

## The unit normal of the ridge on the side away from him (toward the aim), the way its middle bulges.
func _bow() -> Vector2:
	var n := Vector2(-axis.y, axis.x)
	var away := Vector2(center.x - k.h.pos.x, center.z - k.h.pos.z)
	if absf(away.dot(n)) < 0.05:
		away = k.h.aim_dir()
	return n if away.dot(n) >= 0.0 else -n

## The rock spots along the arc (the ridge's middle at the centre), nearest the centre first, each with its
## rise delay and the ridge's direction there. A spot over the abyss sits at the ridge's height; a spot on
## ground a different level from it is left out.
func _plan() -> Array:
	var n := int(xd()["rocks"])
	var len_ := float(xd()["len"])
	var half := len_ * 0.5
	var bend := _bend()
	bow = _bow()
	var base := _base_y()
	var out: Array = []
	for i in n:
		var off := lerpf(-half, half, float(i) / float(n - 1))
		var p2 := AimShapes.bent(Vector2(center.x, center.z), axis, bow, bend, len_, off)
		var g: float = k.m.world.ground_at(p2.x, p2.y)
		if g > World.VOID + 1.0 and absf(g - base) > 0.9:
			continue
		out.append({
			"at": Vector3(p2.x, g if g > World.VOID + 1.0 else base, p2.y),
			"dir": AimShapes.bent_tangent(axis, bow, bend, len_, off),
			"delay": float(xd()["rise"]) * absf(off) / half, "done": false,
		})
	out.sort_custom(func(a, b): return float(a["delay"]) < float(b["delay"]))
	return out

## The height of the ridge: the ground under its centre, else (over the abyss) where he last stood.
func _base_y() -> float:
	var g: float = k.m.world.ground_at(center.x, center.z)
	return g if g > World.VOID + 1.0 else k.h.last_gy

func _tick_tell(dt: float) -> void:
	phase_t += dt
	if phase_t >= float(xd()["tell"]):
		phase = "up"
		phase_t = 0.0
		erupt_at = k.m.time

func _tick_up(dt: float) -> void:
	phase_t += dt
	for s in spots:
		if not bool(s["done"]) and phase_t >= float(s["delay"]):
			s["done"] = true
			_raise(s["at"], s["dir"])
	if phase_t >= float(xd()["rise"]) + float(xd()["time"]):
		phase = ""

func _raise(p: Vector3, along: Vector2) -> void:
	var m := k.m
	if not (m.world.is_void(p.x, p.z) or HeroZones.fits(m, p, p.y, false)):
		return
	var across := Vector2(along.y, -along.x)
	_shove_off_line(p, along, across)
	var rid := "%s.x%d.%d" % [k.rid_owner(), cast_n, rocks_raised]
	var rd := k.rock_def()
	var w := HeroZones.rock(m, k.h, p, across, rid, float(rd["len"]), float(xd()["time"]), float(rd["hp"]))
	w["ult"] = cast_n
	rocks_raised += 1
	if first_rise_t < 0.0:
		first_rise_t = m.time
	last_rise_t = m.time
	k.vfx("spine_rise", p, along)
	for f in k.foes_in(p, float(xd()["slow_r"])):
		var o := {"src": "abil", "ab": "x", "slow": float(xd()["slow_t"]), "slow_k": float(xd()["slow_k"])}
		f.hurt(float(xd()["rise_dmg"]) * k.power("x"), k.h, o)
		if f is Hunter:
			slowed += 1
			HeroUlt.landed(k, f)

## A rock never rises inside a body: whoever stands on the line is moved to the side they were on.
func _shove_off_line(p: Vector3, along: Vector2, across: Vector2) -> void:
	var half_len := float(k.rock_def()["len"]) * 0.5
	for e in k.m.hunters:
		if e.dead or absf(e.pos.y - p.y) > 1.5:
			continue
		var to := Vector2(e.pos.x - p.x, e.pos.z - p.z)
		var side_off := to.dot(across)
		var clear: float = HeroZones.ROCK_TH + e.r + PUSH_PAD
		if absf(to.dot(along)) > half_len + e.r or absf(side_off) >= clear:
			continue
		var sgn := 1.0 if side_off >= 0.0 else -1.0
		var dest: Vector3 = e.pos + Vector3(across.x, 0, across.y) * (clear - absf(side_off)) * sgn
		k.m.displace.teleport(e, dest)
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
