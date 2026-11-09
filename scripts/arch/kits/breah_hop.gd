class_name BreahHop
extends RefCounted
## Tarek's ground dash, Rock Hop (docs/heroes/dolm.md): a rock bursts up under him and he springs
## off it toward the cursor, up to `hops` times. Fast, low arcs; a fresh low rock rises to meet his feet at each
## landing, laid along the hop like a rail, and he skids along it. A press inside `window` of the last take-off
## sends the next hop toward the cursor as it is then; no press and the skid ends in the landing. Each landing but
## the last nudges; the last crashes and its rock rolls on (the kit's identity, all of the dash's damage).
##
## A hop's spot is the cursor clamped to reach, pulled back toward him until a body fits. Over the abyss a hop lands
## on a rock raised at his height, but only if ground lies ahead within the reach of the hops left: he crosses a
## gap, never runs out into open abyss (nothing past the map's edge is ground, so that is out of reach too).
## The charge is spent at the press and recharges from the chain's end. Rocks are "hop" rocks: real ones that stop
## foes and carry allies, not counted among his Stone Row, never launched, gone in `hop_rock_t`.

const CROUCH := 0.06           # s: the first rock bursts up and he crouches on it
const RISE_LEAD := 0.06        # s before touchdown: the landing rock comes up to meet him
const RAIL_BACK := 0.3         # m: the rock's centre lies this far ahead of the landing, so the skid stays on it
const FOOT_KEY := "br_foot"

var k: DolmKit
var h: Hunter
var m: Node
var st := {}                   # {n, phase: crouch|air|skid|roll, t, T, from, spot, dir, left, press, start}
var dash_was := false
var rock_n := 0
# counters for the checks
var hops := 0                  # hops taken, every chain
var chain_hops := 0            # hops in the last chain
var chain_dist := 0.0          # m, the last chain from its press to its end
var shoves := 0                # foes a landing nudged
var spots: Array = []          # the last chain's touchdowns

func _init(kit: DolmKit) -> void:
	k = kit
	h = kit.h
	m = kit.m

func dd() -> Dictionary: return k.dash_def()

## In the chain, as DashFlow sees it (the rock rolling on after is not).
func chaining() -> bool:
	return not st.is_empty() and String(st["phase"]) != "roll"

## s to the chain's end if nobody presses again.
func left() -> float:
	var skid := 0.0 if int(st["n"]) >= int(dd()["hops"]) else float(dd()["window"]) - float(st["T"])
	match String(st["phase"]):
		"crouch": return CROUCH - float(st["t"]) + float(st["T"]) + skid
		"air": return maxf(0.0, float(st["T"]) - float(st["t"])) + skid
		"skid": return maxf(0.0, float(st["left"]))
	return 0.0

func drop() -> void:
	st = {}
	AimKit.hide(h, "leap")
	KitLooks.of(m).release(FOOT_KEY)

## A re-press: the next hop, as soon as he is on a rock.
func press() -> void:
	if int(st["n"]) < int(dd()["hops"]):
		st["press"] = true

func start() -> void:
	if not st.is_empty():
		_roll_on()         # the last chain's rock was still to come
	spots = []
	st = {
		"n": 0, "phase": "crouch", "t": 0.0, "T": _flight(), "from": h.pos, "start": h.pos, "press": false, "left": 0.0
	}
	dash_was = true
	_aim_hop()
	k.play("breah_hop")
	if not h.grounded:
		return
	m.fx.dust(h.pos, 10)
	m.sfx("br_rise", h.pos, -4.0, 1.2)
	_raise(h.pos, st["dir"])
	CombatBus.ability_used.emit(h, String(dd().get("id", "dash")), "dodge")

func _flight() -> float:
	return float(dd()["time"]) * float(k.dash_feel()["time"])

func _reach() -> float:
	return float(dd()["dist"]) * float(k.dash_feel()["dist"]) * (float(dd()["speed_k"]) if k.rank("dash") >= 3 else 1.0)

## Picks the next hop from the cursor as it is now. False: nowhere to land.
func _aim_hop() -> bool:
	var dir := h.aim_dir()
	var spot := spot_for(dir, int(dd()["hops"]) - int(st["n"]) - 1)
	st["dir"] = dir
	st["spot"] = spot
	if spot.is_empty():
		return false
	var at: Vector3 = spot["at"]
	AimKit.circle(
		h, "leap",
		{"at": at, "r": float(dd()["land_r"]), "fill": 0.0, "all": true, "col": Color("ff5a2a"), "dur": st["T"] + 0.4}
	)
	return true

## Where a hop along dir lands, `after` hops still to come: {at (rock base or ground), rock (a rock can rise),
## feet (his height on landing)}, or {} when nothing in reach will do.
func spot_for(dir: Vector2, after: int) -> Dictionary:
	var far := _reach()
	var to_aim := Vector2(k.aim().x - h.pos.x, k.aim().z - h.pos.z).length()
	var want := clampf(to_aim, float(dd()["min"]), far)
	var top := float(dd()["hop_top"])
	while want > 0.3:
		var p := h.pos + Vector3(dir.x, 0, dir.y) * want
		var g: float = m.world.ground_at(p.x, p.z)
		if not _clear(dir, want):
			pass
		elif g <= World.VOID + 1.0:
			if _ground_ahead(p, dir, far * after + 0.5):
				return {"at": Vector3(p.x, h.pos.y - top, p.z), "rock": true, "feet": h.pos.y}
		elif g - h.pos.y < 2.5 and _lands(p, g):
			var fit: bool = HeroZones.fits(m, Vector3(p.x, g, p.z), g, true, h)
			return {"at": Vector3(p.x, g, p.z), "rock": fit, "feet": g + (top if fit else 0.0)}
		want -= 0.25
	return {}

## A body fits at p on ground g (his own rocks count as he would walk them).
func _lands(p: Vector3, g: float) -> bool:
	var asking := StoneStand.mover
	StoneStand.mover = h
	var fits: bool = m.world.occupy(p.x, p.z, h.r, maxf(g, h.pos.y), false) == 0.0
	StoneStand.mover = asking
	return fits

## Nothing solid on the first `want` metres of the line: a hop is low, it doesn't go over walls or trees (a terrace
## is fine: it is measured from the terrain's own top). His own rocks count as he would walk them.
func _clear(dir: Vector2, want: float) -> bool:
	var asking := StoneStand.mover
	StoneStand.mover = h
	var clear := true
	var d := 0.25
	while clear and d < want:
		var q := h.pos + Vector3(dir.x, 0, dir.y) * d
		var y := maxf(h.pos.y, m.world.ground_at(q.x, q.z))
		clear = m.world.occupy(q.x, q.z, 0.05, y, false) == 0.0
		d += 0.25
	StoneStand.mover = asking
	return clear

## Solid ground on the line from p, within `reach` metres and not out of a hop's rise?
func _ground_ahead(p: Vector3, dir: Vector2, reach: float) -> bool:
	var d := 0.5
	while d <= reach:
		var q := p + Vector3(dir.x, 0, dir.y) * d
		var g: float = m.world.ground_at(q.x, q.z)
		if g > World.VOID + 1.0:
			return g - h.pos.y < 2.5
		d += 0.5
	return false

## A low rock with its length along the hop.
func _raise(at: Vector3, dir: Vector2) -> Dictionary:
	rock_n += 1
	var d := dd()
	var mid := at + Vector3(dir.x, 0, dir.y) * RAIL_BACK
	var w: Dictionary = HeroZones.rock(
		m, h, mid, Vector2(dir.y, -dir.x), "%s.h%d" % [k.rid_owner(), rock_n], float(k.rock_def()["len"]),
		float(d["hop_rock_t"]), float(d["hop_rock_hp"]), true, float(d["hop_top"])
	)
	w["hop"] = true
	return w

func tick(dt: float) -> void:
	if st.is_empty():
		return
	var phase := String(st["phase"])
	st["t"] = float(st["t"]) + dt
	if phase == "roll":
		if float(st["t"]) >= float(dd()["rock_lag"]):
			_roll_on()
		return
	if h.downed or h.gliding:
		drop()
		return
	_hold_charge(dt)
	var down := k.held("dash")
	if down and not dash_was:
		press()
	dash_was = down
	if phase == "skid" and h.ctrl == "bot":
		press()            # bots ride the whole chain
	if h.grounded or phase != "crouch":
		_foot()
	match phase:
		"crouch":
			if float(st["t"]) >= CROUCH:
				_aim_hop()         # he stands on the rock now: the hop is measured from there
				_kick()
		"air":
			_tick_air(dt)
		"skid":
			_tick_skid(dt)

## The recharge waits for the chain's end (the shared step adds this back).
func _hold_charge(dt: float) -> void:
	if h.dashes < h.max_dashes():
		h.dashes -= dt / h.dash_regen()

## The slab under his feet: his board through the whole chain.
func _foot() -> void:
	var n: Node3D = KitLooks.of(m).hold_on(FOOT_KEY, "footrock", h, h.pos + Vector3(0, 0.04, 0))
	var dir: Vector2 = st["dir"]
	n.rotation.y = atan2(dir.x, dir.y)

func _kick() -> void:
	var spot: Dictionary = st["spot"]
	if spot.is_empty():
		_crash()
		return
	var d := dd()
	st["n"] = int(st["n"]) + 1
	st["from"] = h.pos
	st["phase"] = "air"
	st["t"] = 0.0
	st["press"] = false
	st["rock_up"] = not bool(spot["rock"])
	hops += 1
	chain_hops = int(st["n"])
	h.roll_t = 0.0
	var at: Vector3 = spot["at"]
	var T := float(st["T"])
	var feet := Vector3(at.x, float(spot["feet"]), at.z)
	h.launch_to(feet, T)
	if not h.pad.is_empty():
		h.pad["ledge"] = true          # up onto a ledge: a sure arc, and a press in it must not break it
	else:
		var pull := _pull()
		h.vel.y += 0.5 * pull * T      # a heavy hop: a low, fast arc, same landing time
	if int(st["n"]) == 1:
		h.inv_t = maxf(h.inv_t, float(d["invuln"]))
	h.dash_at = m.time
	k.play("breah_hop")
	m.fx.dust(h.pos, 6)
	m.sfx("br_leap", h.pos, -3.0, 1.0)
	Feel.dash_sound(m, k.id, h.pos, h)

## Rock Hop falls at its own leap_grav: the pull on top of gravity.
func _pull() -> float:
	return maxf(0.0, float(dd().get("leap_grav", Hunter.H_GRAV)) - Hunter.H_GRAV)

func _tick_air(dt: float) -> void:
	var t := float(st["t"])
	var T := float(st["T"])
	AimKit.circle(
		h, "leap",
		{
			"at": st["spot"]["at"], "r": float(dd()["land_r"]), "fill": clampf(t / T, 0.0, 1.0), "all": true,
			"col": Color("ff5a2a")
		}
	)
	if not h.grounded and h.pad.is_empty():
		h.vel.y -= _pull() * dt
	if not bool(st["rock_up"]) and t >= T - RISE_LEAD:
		st["rock_up"] = true
		var at: Vector3 = st["spot"]["at"]
		if m.world.is_void(at.x, at.z) or HeroZones.fits(m, at, at.y, true, h):      # never into a body
			m.sfx("br_rise", at, -6.0, 1.3)
			_raise(at, st["dir"])
	if t > 0.08 and h.grounded:
		_touchdown()
	elif t > T + 0.5:
		_crash()

func _touchdown() -> void:
	var d := dd()
	spots.append(h.pos)
	if int(st["n"]) >= int(d["hops"]) or k.dive:
		_crash()
		return
	_nudge()
	st["phase"] = "skid"
	st["left"] = maxf(float(d["window"]) - float(st["t"]), float(d["skid_min"]))
	st["t"] = 0.0
	k.play("breah_skate")
	m.fx.dust(h.pos, 8)
	m.sfx("br_slam", h.pos, -11.0, 1.5)
	var dir: Vector2 = st["dir"]
	h.vel.x = 0.0
	h.vel.z = 0.0
	var run := _skid_room(dir)
	k._lunge(run, float(d["skid_t"]) * run / float(d["skid"]), dir)

## How far the skid can run: on ground it stops short of an edge, so a chain never slides him off one.
func _skid_room(dir: Vector2) -> float:
	var run := float(dd()["skid"])
	if m.world.is_void(h.pos.x, h.pos.z):
		return run
	while run > 0.0:
		var q := h.pos + Vector3(dir.x, 0, dir.y) * (run + h.r)
		if not m.world.is_void(q.x, q.z):
			return run
		run -= 0.05
	return 0.0

func _tick_skid(dt: float) -> void:
	st["left"] = float(st["left"]) - dt
	if bool(st["press"]) and float(st["t"]) >= float(dd()["skid_min"]) and int(st["n"]) < int(dd()["hops"]):
		if _aim_hop():
			_kick()
		else:
			_crash()
		return
	if float(st["left"]) <= 0.0:
		_crash()

## A landing's nudge: a small shove, no damage.
func _nudge() -> void:
	var d := dd()
	for f in k.foes_in(h.pos, float(d["land_r"])):
		var away := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z)
		away = away.normalized() if away.length() > 0.05 else h.aim_dir()
		m.displace.knock(f, away * float(d["shove_kb"]), 0.0)
		shoves += 1

## The chain's end: today's crash, then its rock rolls on. The recharge runs from here.
func _crash() -> void:
	var d := dd()
	var at := h.pos
	var r := float(d["land_r"])
	var start_at: Vector3 = st["start"]
	chain_dist = Vector2(at.x - start_at.x, at.z - start_at.z).length()
	k.leap_lands += 1
	k.play("breah_leap_land")
	m.fx.dust(at, 14)      # the hit area showed all through the flight: no ring or blast here
	m.sfx("br_slam", at, -5.0, 1.15)
	for f in k.foes_in(at, r):
		k.leap_hits += 1
		var away := Vector2(f.pos.x - at.x, f.pos.z - at.z)
		away = away.normalized() if away.length() > 0.05 else h.aim_dir()
		f.hurt(
			float(d["land_dmg"]) * k.power("dash"), h,
			{"src": "abil", "ab": "dash", "kb": away * float(d["kb"]), "lift": 2.0, "heavy": true}
		)
	KitLooks.of(m).release(FOOT_KEY)
	AimKit.hide(h, "leap")
	st = {"phase": "roll", "t": 0.0, "at": at, "dir": st["dir"]}

func _roll_on() -> void:
	var at: Vector3 = st.get("at", h.pos)
	var dir: Vector2 = st.get("dir", h.aim_dir())
	st = {}
	AimKit.hide(h, "leap")
	_landslide(at, dir)

## The rock comes down just ahead of where he landed and rolls on (the chain's second hit).
func _landslide(at: Vector3, dir: Vector2) -> void:
	var d := dd()
	k.landslides += 1
	var from := at + Vector3(dir.x * 0.9, 0.85, dir.y * 0.9)
	m.fx.burst(from, Color("a8805a"), 14, 5.0, 0.4, 6.0, 1.2, Vector3(dir.x, 0.3, dir.y), 50.0)
	m.fx.dust(from, 8)
	k._fire_rock(from, dir, float(d["dmg"]) * k.power("dash"), "dash", "dashrock", float(d["rock_range"]))
	m.sfx("br_roll", from, -3.0, 1.0)
