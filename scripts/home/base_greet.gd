class_name BaseGreet
extends RefCounted
## A Boki notices you coming back (GARDEN.md section 4, base_mode only): a roaming Boki that has had you far off
## for away_s and sees you come within near_m looks at you; a Boki that likes you enough (bond rank Close or
## higher) runs over and follows you for a few steps, then goes back to its day. Whether it notices at all is
## weighted by its bond rank and how clingy it is (home.gd _personality). BaseLife owns the Greet state and calls
## watch() for each roaming Boki; no UI, no reward. Tuning: content/rules/base_life.json "notice".


static func rules() -> Dictionary:
	return Content.rules("base_life")["notice"]


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
