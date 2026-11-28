class_name BaseGreet
extends RefCounted
## A Boki notices you coming back (GARDEN.md section 4, base_mode only): a roaming Boki that has had you far off
## for away_s and sees you come within near_m looks at you; a Boki that likes you enough (bond rank Close or
## higher) runs over and follows you for a few steps, then goes back to its day. Whether it notices at all is
## weighted by its bond rank and how clingy it is (home.gd _personality). BaseLife owns the Greet state and calls
## watch() for each roaming Boki; no UI, no reward. Your partner uses the same state to trail you for good
## (trail(), the follow half with no end): 2 to 4 m behind, stopping when you stop, sitting when you idle, waiting
## at the Waystone. Tuning: content/rules/base_life.json "notice" and "trail".


static func rules() -> Dictionary:
	return Content.rules("base_life")["notice"]


static func trail_rules() -> Dictionary:
	return Content.rules("base_life")["trail"]


## From BaseLife.choose: your partner goes to trail you. False for any other Boki or when it cannot now.
static func trail(life: BaseLife, k: Dictionary) -> bool:
	if not GardenZones.is_partner(k["rec"]) or not life.machine(k).go(BaseLife.S.GREET, "trails"):
		return false
	k["life_greet"] = {"runs": true, "reached": 0.0, "trail": true}
	return true


## 10 Hz, from BaseLife._tick for a roaming Boki: counts the time you were far and starts the greeting on your return.
static func watch(life: BaseLife, k: Dictionary, dt: float) -> void:
	var r := rules()
	var h = life.h
	var gap := Vector2(h.ppos.x - k["pos"].x, h.ppos.z - k["pos"].z).length()
	if gap > float(r["far_m"]):
		k["notice_away"] = float(k.get("notice_away", 0.0)) + dt
		return
	if gap > float(r["near_m"]) or float(k.get("notice_away", 0.0)) < float(r["away_s"]):
		return
	k["notice_away"] = 0.0
	if h.world.island_of(h.ppos.x, h.ppos.z) != h.world.island_of(k["pos"].x, k["pos"].z):
		return
	var rank := Care.bond_index(k["rec"])
	var cling := float(k.get("pers", {}).get("cling", 0.0))
	if randf() >= float(r["chance"]) + float(r["rank_chance"]) * rank + float(r["cling_chance"]) * cling:
		return
	var runs := rank >= int(r["run_rank"])
	if life.machine(k).go(BaseLife.S.GREET, "runs over" if runs else "looks"):
		k["life_greet"] = {"runs": runs, "reached": -1.0}
		h._emote(k, "!" if runs else "?", true)


## The Greet state, 10 Hz: a look is a pause facing you (an idle Boki faces you, home.gd _move_kin); a run goes at
## RUN_SPEED to a spot beside you, hops, and keeps following at the walk until follow_s is up.
static func tick(life: BaseLife, k: Dictionary, m: Fsm) -> void:
	var r := rules()
	var g: Dictionary = k["life_greet"]
	if g.has("trail"):
		_trail_tick(life, k, m)
		return
	if not g["runs"]:
		k["goal"] = k["pos"]
		if m.since >= float(r["look_s"]):
			m.go(BaseLife.S.ROAM, "looked")
		return
	var h = life.h
	var slot: Vector3 = h._seat(k, h.ppos, float(r["slot_m"]))
	k["goal"] = slot
	if float(g["reached"]) < 0.0:
		k["led"] = BokiRig.RUN_SPEED
		if Vector2(slot.x - k["pos"].x, slot.z - k["pos"].z).length() < float(r["reach_m"]):
			g["reached"] = m.since
			k.erase("led")
			k["joy_t"] = 0.9
			h._emote(k, "♥", true)
	var followed := float(g["reached"]) >= 0.0 and m.since - float(g["reached"]) >= float(r["follow_s"])
	if followed or m.since >= float(r["give_up_s"]):
		m.go(BaseLife.S.ROAM, "greeted")


## Leaving the state (BaseLife.machine on_exit): it keeps no mark of the greeting.
static func end(k: Dictionary) -> void:
	k.erase("life_greet")
	k.erase("led")


## The trailing partner, 10 Hz: the band round you, your speed, a sit when you idle (see "trail_doc").
static func _trail_tick(life: BaseLife, k: Dictionary, m: Fsm) -> void:
	var r := trail_rules()
	var h = life.h
	var pos: Vector3 = k["pos"]
	var to := Vector2(pos.x - h.ppos.x, pos.z - h.ppos.z)
	var speed := Vector2(h.pvel.x, h.pvel.z).length()
	var moving := speed > float(r["moving_mps"])
	var goal := pos
	if m.since >= float(r["check_s"]):
		m.go(BaseLife.S.ROAM, "needs")
		return
	if (h.hway != null and h.hway.hopping != "") or h.world.island_of(h.ppos.x, h.ppos.z) < 0:
		pass  # the Waystone is lit for the hop, or you are over the void: wait where it stands
	elif _lost(h, pos, to, r):
		h._start_leap(k, h.world.free_spot_near(h.ppos + _away(h, to) * float(r["settle_m"]), [], 1.0))
	elif to.length() > float(r["max_m"]):
		goal = h.ppos + _away(h, to) * float(r["settle_m"])
	elif moving and to.length() < float(r["min_m"]):
		goal = h.ppos + Vector3(sin(h.pface), 0, cos(h.pface)) * float(r["settle_m"])
	if goal != pos:
		goal = _clear_of_pad(h, _open(h, goal), r)  # only a new aim is moved: a Boki standing still is left alone
	var idle := not moving and goal == pos and float(k.get("hold_t", 0.0)) <= 0.0
	var still := float(k.get("trail_still", 0.0)) + BaseLife.STEP if idle else 0.0
	k["trail_still"] = still  # kept over the needs check: a sitting partner does not stand up for it
	KinHabit.sit(k, still >= float(r["sit_s"]))
	k["goal"] = goal
	if goal == pos:
		k.erase("led")
	else:
		var hurry := maxf(0.0, to.length() - float(r["max_m"]))  # 1 m/s more for each m past the band
		k["led"] = clampf(speed * 1.1 + hurry, float(r["walk_mps"]), float(r["run_mps"]))


## On another island or past the leash: it leaps to you.
static func _lost(h, pos: Vector3, to: Vector2, r: Dictionary) -> bool:
	var apart: bool = h.world.island_of(pos.x, pos.z) != h.world.island_of(h.ppos.x, h.ppos.z)
	return apart or to.length() > float(r["leash_m"])


## Unit step from you towards the partner, or straight behind you when it sits on you.
static func _away(h, to: Vector2) -> Vector3:
	var dir := to.normalized() if to.length() > 0.2 else Vector2(sin(h.pface), cos(h.pface))
	return Vector3(dir.x, 0, dir.y)


## `p` itself if a Boki may stand there (ground, no building, toy or water), else the nearest open spot.
static func _open(h, p: Vector3) -> Vector3:
	if h.world.is_void(p.x, p.z) or h.world.occupy(p.x, p.z, 0.3, 0.0, true) != 0.0:
		return h.world.free_spot_near(p, [], 1.0)
	return p


## Never aim inside the ring round the Waystone or return pad: pushed out to its edge, on the side it is on.
static func _clear_of_pad(h, p: Vector3, r: Dictionary) -> Vector3:
	if h.hway == null or h.hway.node == null:
		return p
	var at: Vector3 = h.hway.node.position
	var off := Vector2(p.x - at.x, p.z - at.z)
	var ring := float(r["pad_m"])
	if off.length() >= ring:
		return p
	var dir := off.normalized() if off.length() > 0.05 else Vector2(0, 1)
	return _open(h, Vector3(at.x + dir.x * ring, p.y, at.z + dir.y * ring))
