class_name RideView
extends RefCounted
## The skyship ride as a map screen (docs/decisions/0178-ride-map-view.md). From the plan until your rocket
## launches, the drop map is the whole view: the 3D world behind it is not drawn (from the ship's height it was
## ~16k objects and ~1.3k draws for a picture the dark map covers), the match and the ship run as always. The
## launch closes the map and the 3D view comes back on the rocket (DropRocket, Cam.skydive). Closing the map
## with its key brings the 3D ride view back, as before.


## True while the player waits on the skyship for the plan or the launch.
static func aboard(m: Match) -> bool:
	var p := m.player
	return p != null and p.riding and p.rocket == null and not p.out


## What the drop prompt's title says: the plan, the leader's name, or the launch key.
static func title(m: Match) -> String:
	var dr := m.skydrop
	if dr.planning:
		return "Plan your drop"
	if dr.waits(m.player):
		return "%s leads the drop" % dr.leader(m.player.team).pname
	return "Press %s to launch" % Settings.key_cap("jump")


## The map's header while the ship is under way (the plan has its own).
static func header(hud, sz: Vector2) -> void:
	var m: Match = hud.m
	var left := maxf(0.0, float(m.ship.get("ride", 0.0)) - m.time)
	var sub := "Click to ping where you land  ·  %s closes the map  ·  everyone left aboard drops in %ds"
	hud._ctext(Vector2(sz.x * 0.5, 40), title(m).to_upper(), 30, hud.GOLD, hud.big)
	hud._ctext(Vector2(sz.x * 0.5, 64), sub % [Settings.key_cap("map"), ceili(left)], 15, hud.INK)


## Each frame (Hud._process): the drop map stays up while you wait aboard and steps aside at the launch; the 3D
## view is off while it covers the screen. Not before the loading screen's warm-up has drawn everything once.
static func tick(m: Match, map: FullMap) -> void:
	var waiting := aboard(m)
	if map.is_open and map.auto and not waiting:
		map.close()
	var off: bool = m.warmed and map.is_open and waiting and not (m.intro != null and m.intro.running())
	var vp := m.get_viewport()
	if vp.disable_3d != off:
		vp.disable_3d = off
