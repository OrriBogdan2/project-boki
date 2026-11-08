class_name MageSky
extends RefCounted
## Ryzz's Skycall (E) and what it does to her charge orbs. docs/heroes/mage.md has the numbers.
##
## Press drops the circle at the cursor; while E is held the drag follows the cursor from the circle; the
## release commits ONE vector (the drag, or the away-from-her default when it is tiny) and every foe and orb
## inside is moved along exactly that vector 0.8 s later. Nothing re-reads the cursor or her position after
## the commit.

const MIN_DRAG := 0.8        # m of cursor drag below which the tap default is used
const TOWARD_COS := 0.64     # a drag within about 50 degrees of "to Sparkle" counts as pulling toward her
const ARROW_LEN := 1.3       # of the circle radius: the committed arrow inside the circle

var kit: MageKit

func _init(owner_kit: MageKit) -> void:
	kit = owner_kit

## The tap default: from Ryzz out through the circle, from where she stands right now.
func default_dir(at: Vector3) -> Vector2:
	var away := Vector2(at.x - kit.h.pos.x, at.z - kit.h.pos.z)
	return away.normalized() if away.length() > 0.1 else kit.h.aim_dir()

## The drag vector for the cursor as it is now (the preview, and the commit when E is let go).
func drag_dir(at: Vector3) -> Vector2:
	var cursor: Vector3 = kit.h.inp.get("aim", at)
	var drag := Vector2(cursor.x - at.x, cursor.z - at.z)
	return drag.normalized() if drag.length() >= MIN_DRAG else default_dir(at)

func cast() -> bool:
	var ed := kit.e_def()
	var at := AimMode.point(kit.h, float(ed["reach"]))
	kit.strikes.append({"at": at, "t": float(ed["drag_max"]), "dir": default_dir(at), "phase": "flick"})
	kit.fx().star(at + Vector3(0, 0.3, 0), MageKit.TEAL, MageKit.GOLD, 0.8, 0.12)
	kit.fx().disc(at, float(ed["radius"]), MageKit.VIOLET, MageKit.GOLD, 0.2, MageKit.COPPER)
	kit.m.sfx("vv_sky_place", at, -3.0)
	kit.play("mage_e")
	return true

## Skycall is held to drag (the data: "HOLD AND DRAG before release to aim"): the key read here for the local
## player, inp["e_down"] for tests and scripted demos. Bots never hold (a tap: the default drag).
func _held() -> bool:
	if bool(kit.h.inp.get("e_down", false)):
		return true
	return kit.h.is_local() and Input.is_action_pressed("signature")

func tick(dt: float) -> void:
	var ed := kit.e_def()
	var r := float(ed["radius"])
	for i in kit.strikes.size():
		var s: Dictionary = kit.strikes[i]
		var at: Vector3 = s["at"]
		var counting := String(s["phase"]) == "count"
		if counting:
			_arrow(i, s, r)
		else:
			s["dir"] = drag_dir(at)
			var drag := {"from": at, "dir": s["dir"], "len": 4.0, "width": 0.55, "tip": true}
			drag.merge({"col": MageKit.GOLD, "col2": MageKit.GOLD})
			AimKit.lane(kit.h, "e_drag", drag)
		var k := 1.0 - float(s["t"]) / float(ed["delay"]) if counting else 0.0
		# a copper ticked rim with the gold chevron on it pointing the drag (the dark disc is VVFx's)
		var rim := {"at": at, "r": r, "ticks": true, "pointer": s["dir"], "all": true}
		rim.merge({"col": MageKit.COPPER, "col2": MageKit.DEEP_GOLD, "fill": k})
		AimKit.circle(kit.h, "e%d" % i, rim)
		_chevron(at, s["dir"] as Vector2, r)
	for s in kit.strikes.duplicate():
		s["t"] = float(s["t"]) - dt
		var dragging := String(s["phase"]) == "flick"
		if float(s["t"]) > 0.0 and (not dragging or _held()):
			continue
		if dragging:
			_commit(s, ed, r)
		else:
			kit.strikes.erase(s)
			_strike(s)

## E let go (or the hold ran out): the vector is fixed here for good.
func _commit(s: Dictionary, ed: Dictionary, r: float) -> void:
	var at: Vector3 = s["at"]
	s["dir"] = drag_dir(at)
	s["phase"] = "count"
	s["t"] = float(ed["delay"])
	kit.fx().disc(at, r, MageKit.VIOLET, MageKit.GOLD, float(ed["delay"]) + 0.1, MageKit.COPPER)
	kit.fx().pillar(at, Color(MageKit.GOLD, 0.45), MageKit.GOLD.lightened(0.6), 8.0, r * 0.95, float(ed["delay"]))
	AimKit.hide(kit.h, "e_drag")
	kit.m.sfx("vv_sky_count", at, -4.0)
	kit.net_ring(at, r, kit.col_of(ed))

## The committed drag as a clear arrow inside the circle for the whole countdown.
func _arrow(i: int, s: Dictionary, r: float) -> void:
	var dir: Vector2 = s["dir"]
	var at: Vector3 = s["at"]
	var from := at - Vector3(dir.x, 0, dir.y) * r * ARROW_LEN * 0.5
	var arrow := {"from": from, "dir": dir, "len": r * ARROW_LEN, "width": 0.5, "tip": true}
	arrow.merge({"col": MageKit.GOLD, "col2": Color.WHITE})
	AimKit.lane(kit.h, "e_arrow%d" % i, arrow)

## The gold rim chevron pointing the drag: two short gold strokes, redrawn every step.
func _chevron(at: Vector3, d: Vector2, r: float) -> void:
	var tip := at + Vector3(d.x, 0, d.y) * (r + 0.55) + Vector3(0, 0.15, 0)
	for side in [-1.0, 1.0]:
		var wing := d.rotated(side * 2.4)
		var start := tip + Vector3(wing.x, 0, wing.y) * 0.55
		kit.fx().smear(start, tip, MageKit.GOLD, MageKit.GOLD.lightened(0.4), 0.2, 0.05)

func _strike(s: Dictionary) -> void:
	var ed := kit.e_def()
	var at: Vector3 = s["at"]
	var dir: Vector2 = s["dir"]
	kit.last_strike = {"at": at, "dir": dir}
	AimKit.hide(kit.h, "e_arrow0")
	AimKit.hide(kit.h, "e_arrow1")
	_strike_fx(at, float(ed["radius"]))
	var delivery := {"type": "burst", "origin": "here", "radius": float(ed["radius"])}
	var stg := kit.stage("e", {"delivery": delivery, "effects": [{"type": "damage", "amount": float(ed["dmg"])}]})
	kit.run(stg, kit.cx("e", "skycall", at, {"at": at, "dir": dir}))
	for f in kit.foes_in(at, float(ed["radius"])):
		kit.add_spark(f, int(ed.get("stacks", 1)))
		# every body inside is moved along the one committed vector, pinned there for a moment
		var slide := {"mode": "slide", "dir": [dir.x, dir.y], "dur": float(ed["slide_t"])}
		slide["dist"] = float(ed["slide_dist"])
		kit.m.displace.tow(f, null, slide)
		if f is Hunter:
			KitStatus.apply(f, "gnd", float(ed["grounded"]))
		kit.fx().shackle(f, MageKit.TEAL, MageKit.GOLD, float(ed["grounded"]))
	for mt in kit.motes.duplicate():
		if (mt["pos"] as Vector3).distance_to(at) < float(ed["radius"]) + 0.6:
			_fling_orb(mt, dir, ed)

func _strike_fx(at: Vector3, r: float) -> void:
	var fx := kit.fx()
	for i in 3:
		var sky := at + Vector3(0, 9.0, 0) + kit._jitter(0.6, 0.0, 0.0)
		fx.arc(sky, at + kit._jitter(0.4, 0.1, 0.1), MageKit.TEAL, MageKit.GOLD, 1.0 - 0.25 * i, 0.22)
	kit.net_bolt(at + Vector3(0, 9.0, 0), at, MageKit.TEAL)
	fx.ring(at, r, MageKit.GOLD, MageKit.TEAL, 0.35)          # the hit area, at its true size
	fx.disc(at, r * 0.9, Color("1a1420"), MageKit.GOLD, 0.45, MageKit.COPPER)
	kit.m.fx.burst(at + Vector3(0, 0.5, 0), MageKit.GOLD, 22, 6.0, 0.45, 6.0, 1.2)
	kit.m.fx.flash(at + Vector3(0, 1.0, 0), MageKit.GOLD, 1.8, 0.12)
	kit.m.sfx("vv_sky_strike", at, 0.0)
	kit.play("mage_e_snap")

## A charge orb the lightning catches (a rival's becomes hers): dragged toward Ryzz and within reach, it flies
## all the way to her and resets her Wirerun on arrival; any other drag flings it a shorter way.
func _fling_orb(mt: Dictionary, dir: Vector2, ed: Dictionary) -> void:
	var from: Vector3 = mt["pos"]
	var to_her := Vector2(kit.h.pos.x - from.x, kit.h.pos.z - from.z)
	var homing := to_her.length() <= float(ed["pull_reach"]) and dir.dot(to_her.normalized()) >= TOWARD_COS
	var land := from + Vector3(dir.x, 0, dir.y) * float(ed["fling_dist"])
	mt["owner"] = kit.h
	mt["t"] = float(kit.rmb_def()["coil"]["mote_life"])
	var dest := kit.ground(kit.h.pos) if homing else kit.ground(land)
	mt["fly"] = {"from": from, "to": dest, "t": 0.0, "home": homing}
	var lift := Vector3(0, 0.55, 0)
	kit.fx().arc(from + lift, dest + lift, MageKit.TEAL, MageKit.GOLD, 0.6, 0.25)
