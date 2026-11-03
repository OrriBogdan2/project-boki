class_name BotKeys
extends RefCounted
## What a bot does about chest keys (called from Bot's goal picking): with no key, fight for one
## (a carrier's glint, or a key lying on the ground); with a key, go and open a chest. A bot never
## walks to a locked chest it cannot open, and never chases a Shrubling it cannot see.

const SEE_CARRIER := 34.0      # m: a key carrier in this range is worth walking to
const SEE_KEY := 30.0          # m: a dropped key
const CHEST_WITH_KEY := 45.0   # m: how far a bot with a key will walk to a chest
const CLIMB := 2.5             # m: a carrier this far above the bot is out of reach (it hops at the lip)

static func chest_open_for(h: Hunter, c: Dictionary) -> bool:
	return not c["open"] and (bool(c.get("free", false)) or h.chest_keys > 0)

## How far this bot will look for a chest: far with a key in hand, otherwise not at all.
static func chest_range(h: Hunter) -> float:
	return CHEST_WITH_KEY if h.chest_keys > 0 else 0.0

static func _chests_left(m: Match) -> int:
	var n := 0
	for c in m.chests:
		if not c["open"] and not c.get("free", false): n += 1
	return n

## [goal, kind] for a bot that wants a key, or [] (it has enough for the chests that are left, or a full stack).
static func goal(m: Match, h: Hunter, cur: Vector3) -> Array:
	if h.chest_keys >= _chests_left(m) or not KeyChest.has_room(h):
		return []
	var best := Vector3.INF
	var bd := SEE_KEY
	var kind := "loot"
	for p in m.pickups:
		if String(p["kind"]) != "ckey" or m.world.is_void(p["pos"].x, p["pos"].z):
			continue
		if m.lairs and m.lairs.walled_off(h, p["pos"]):
			continue
		var d := h.flat_dist(p["pos"])
		if d < bd:
			bd = d
			best = p["pos"]
	for mb in m.mobs:
		if mb.dead or not KeyCarry.carries(mb) or (mb is Shrubling and (mb as Shrubling).ss == "disguised"):
			continue
		if m.lairs and m.lairs.walled_off(h, mb.pos):
			continue
		if mb.pos.y - h.pos.y > CLIMB:
			continue
		var d2 := h.flat_dist(mb) - (4.0 if mb.pos.distance_to(cur) < 3.0 else 0.0)
		if d2 < minf(bd, SEE_CARRIER):
			bd = d2
			best = mb.pos
			kind = "keyhunt"
	return [best, kind] if best != Vector3.INF else []
