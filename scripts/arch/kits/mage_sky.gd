class_name MageSky
extends RefCounted
## Sparkle's Skycall (E) and what it does to her charge orbs. docs/heroes/mage.md has the numbers.
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

## The tap default: from Sparkle out through the circle, from where she stands right now.
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
	kit.vfx("e_place", at, null, {"r": float(ed["radius"])})
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
			drag.merge({"col": MageKit.GLOW, "col2": MageKit.GLOW})
			AimKit.lane(kit.h, "e_drag", drag)
		var k := 1.0 - float(s["t"]) / float(ed["delay"]) if counting else 0.0
		# a copper ticked rim with a chevron on it pointing the drag
		var rim := {"at": at, "r": r, "ticks": true, "pointer": s["dir"], "all": true}
		rim.merge({"col": MageKit.COPPER, "col2": MageKit.DEEP_GOLD, "fill": k})
		AimKit.circle(kit.h, "e%d" % i, rim)
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
	kit.vfx("e_count", at, null, {"r": r})          # the storm gathers over the circle (other games see it too)
	AimKit.hide(kit.h, "e_drag")
	kit.m.sfx("vv_sky_count", at, -4.0)

## The committed drag as a clear arrow inside the circle for the whole countdown.
func _arrow(i: int, s: Dictionary, r: float) -> void:
	var dir: Vector2 = s["dir"]
	var at: Vector3 = s["at"]
	var from := at - Vector3(dir.x, 0, dir.y) * r * ARROW_LEN * 0.5
	var arrow := {"from": from, "dir": dir, "len": r * ARROW_LEN, "width": 0.5, "tip": true}
	arrow.merge({"col": MageKit.GLOW, "col2": Color.WHITE})
	AimKit.lane(kit.h, "e_arrow%d" % i, arrow)

func _strike(s: Dictionary) -> void:
	var ed := kit.e_def()
	var at: Vector3 = s["at"]
	var dir: Vector2 = s["dir"]
	kit.last_strike = {"at": at, "dir": dir}
	AimKit.hide(kit.h, "e_arrow0")
	AimKit.hide(kit.h, "e_arrow1")
	kit.vfx("e_strike", at, dir, {"r": float(ed["radius"])})
	kit.m.sfx("vv_sky_strike", at, 0.0)
	kit.play("mage_e_snap")
	var delivery := {"type": "burst", "origin": "here", "radius": float(ed["radius"])}
	var stg := kit.stage("e", {"delivery": delivery, "effects": [{"type": "damage", "amount": float(ed["dmg"])}]})
	kit.run_own(stg, kit.cx("e", "skycall", at, {"at": at, "dir": dir}))
	for f in kit.foes_in(at, float(ed["radius"])):
		kit.add_spark(f, int(ed.get("stacks", 1)))
		# every body inside is moved along the one committed vector, pinned there for a moment
		var slide := {"mode": "slide", "dir": [dir.x, dir.y], "dur": float(ed["slide_t"])}
		slide["dist"] = float(ed["slide_dist"])
		kit.m.displace.tow(f, null, slide)
		if f is Hunter:
			KitStatus.apply(f, "gnd", float(ed["grounded"]))
		kit.fx().shackle(f, MageKit.PINK, MageKit.GLOW, float(ed["grounded"]))
	for mt in kit.motes.duplicate():
		if (mt["pos"] as Vector3).distance_to(at) < float(ed["radius"]) + 0.6:
			_fling_orb(mt, dir, ed)

## A charge orb the lightning catches (a rival's becomes hers): dragged toward Sparkle and within reach, it flies
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
	kit.fx().arc(from + lift, dest + lift, MageKit.PINK, MageKit.GLOW, 0.6, 0.25)
