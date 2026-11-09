class_name LairsBots
extends RefCounted
## Bot choices around lairs for Lairs.

var ls: Lairs
var m: Match

func _init(l: Lairs) -> void:
	ls = l
	m = l.m

## Bots work the dial too: as the needle enters a lit arc they either catch it (more often the better
## they are, less often as the locks get faster) or press a beat too late.
func _bot_dial(L: Dictionary, h: Hunter, dt: float) -> void:
	if float(L["jam"]) > 0.0 or float(L["grace"]) > 0.0:
		L["bot_ti"] = -1
		return
	var ti := ls.target_under(L)
	var skill := float(h.ai.get("skill", 0.5))
	if ti >= 0 and ti != int(L["bot_ti"]):
		L["bot_ti"] = ti
		L["bot_roll"] = randf() < clampf(0.6 + skill * 0.38 - int(L["lock"]) * 0.07, 0.3, 0.96)
		L["bot_wait"] = randf_range(0.0, float(L["targets"][ti]["w"]) / ls.speed_of(L) * 0.7)
	if ti >= 0 and L["bot_roll"]:
		L["bot_wait"] = float(L["bot_wait"]) - dt
		if float(L["bot_wait"]) <= 0.0:
			ls.press(L, h)
			L["bot_ti"] = -1
	elif ti < 0 and int(L["bot_ti"]) >= 0:
		var missed := not bool(L["bot_roll"])
		L["bot_ti"] = -1
		if missed:
			L["jam"] = 0.0
			ls.press(L, h)       # too late: the needle has already left the arc

# ------------------------------------------------------------------ bots
## Where a bot wants to go for the lairs: a dropped egg first, then (for the bolder ones) a lair.
func bot_goal(h: Hunter, leaving: bool) -> Array:
	var a := h.ai
	var sl := ls.lock.sealed_lair(h)
	if not sl.is_empty():
		if sl.get("victory", false):
			return _bot_exit(sl, h)
		return [sl["c"], "lair_fight"]      # sealed in: there's only the boss
	# riding the escape updraft out: steer for where it throws you
	for L in ls.list:
		if (L.get("flown", []) as Array).has(h) and not h.grounded and h.auto_glide:
			return [L["up_land"], "lair_escape"]
	for L in ls.list:
		var wp = L.get("egg_wp")
		if wp != null and m.wpicks.has(wp) and h.flat_dist(wp["pos"]) < 50.0:
			if not a.has("egg_" + String(L["id"])): a["egg_" + String(L["id"])] = randf() < 0.45 + 0.5 * float(a.get("skill", 0.5))
			if a["egg_" + String(L["id"])]:
				return [wp["pos"], "lair_egg"]
	var cg := _bot_camp(h, leaving)
	if not cg.is_empty():
		return cg
	if leaving or m.time < 25.0 or h.hp < h.max_hp * 0.55:
		return []
	if not a.has("boss_hunt"):
		# a bot on its own (no squadmate left) waits for level 8 before it thinks about a boss: alone
		# at level 2-6 they cracked a lair, got sealed in with it and were wiped (5 of 9 seeded simtests)
		if h.lvl < 8 and not m.hunters.any(func(o): return o != h and o.team == h.team and not o.out):
			return []
		# stronger bots go after bosses more often
		a["boss_hunt"] = randf() < 0.12 + 0.45 * float(a.get("skill", 0.5))
	if not a["boss_hunt"]:
		return []
	var best := {}; var bd := 110.0
	for L in ls.list:
		if L["state"] in ["cleared", "dormant"] or L.get("locked", false): continue
		# a sealed gate bots can't work (runes, wards) isn't a goal: try the next lair instead of giving up
		if L["state"] == "sealed" and not (L["entry"] as Array).has("dial"): continue
		# (the lair we picked last time reaches a little further: at the edge of the range a bot
		# walking about flipped between it and a roam goal every think, turning round each time)
		var d := h.flat_dist(L["c"]) - (15.0 if a.get("lair_pick", "") == String(L["id"]) else 0.0)
		if d < bd: bd = d; best = L
	if best.is_empty():
		a.erase("lair_pick")
		return []
	a["lair_pick"] = String(best["id"])
	if best["state"] == "sealed":
		if not (best["entry"] as Array).has("dial"):
			return []
		var u = best["user"]
		if u != null and not is_same(u, h):
			return [best["dial"] + Vector3(best["out"].x, 0, best["out"].y) * 3.0, "roam"]
		return [best["dial"], "lair_dial"]
	return [best["c"], "lair_fight"]

## A bot sealed in after the kill: the egg if it's still lying here, then out. With rivals waiting at
## the gate (and the updraft blowing) it rides the updraft out the back; otherwise it pulls the lever.
func _bot_exit(L: Dictionary, h: Hunter) -> Array:
	var a := h.ai
	var wp = L.get("egg_wp")
	if wp != null and m.wpicks.has(wp) and ls.inside(L, wp["pos"], 0.0) and ls.lock.victory_left(L) > 3.0:
		var key := "egg_" + String(L["id"])
		if not a.has(key): a[key] = randf() < 0.45 + 0.5 * float(a.get("skill", 0.5))
		if a[key]:
			return [wp["pos"], "lair_egg"]
	var way := "updraft" if L.get("up_on", false) and campers(L, h.team) > 0 else "lever"
	a["lair_exit"] = way
	if way == "updraft":
		return [L["up"], "lair_updraft"]
	return [L["lever"], "lair_lever"]

## Rivals of this team standing outside a lair's gate (waiting for whoever comes out).
func campers(L: Dictionary, team: int) -> int:
	var n := 0
	for o in m.hunters:
		if o.team == team or o.out or o.extracted or o.downed or o.riding or o.dropping:
			continue
		if not ls.inside(L, o.pos, 0.5) and o.flat_dist(L["gate_c"]) < 18.0:
			n += 1
	return n

## A fight we heard about: some squads go and camp its gate for whoever comes out, more often the
## stronger they are (more of them up, healthier, better bots), never when they're leaving.
func _bot_camp(h: Hunter, leaving: bool) -> Array:
	if leaving:
		return []
	for L in ls.list:
		if not ls.lock.alerted(L, h) or String(L["state"]) == "dormant":
			continue
		if (L.get("sealed_in", []) as Array).any(func(x): return is_instance_valid(x) and x.team == h.team):
			continue      # (our own squad is in there)
		var key := "camp_" + String(L["id"])
		if not h.ai.has(key):
			h.ai[key] = randf() < camp_odds(h)
		if h.ai[key]:
			return [camp_spot(L, h), "lair_camp"]
	return []

## How likely a bot is to go and camp a lair fight it heard: its skill, how many of its squad are up,
## and how healthy they are.
func camp_odds(h: Hunter) -> float:
	var mates: Array = m.hunters.filter(func(x): return x.team == h.team and not x.out and not x.extracted)
	var up: Array = mates.filter(func(x): return not x.downed)
	if up.is_empty():
		return 0.0
	var hpk := 0.0
	for x in up: hpk += x.hp / maxf(1.0, x.max_hp)
	hpk /= float(up.size())
	if up.size() == 1 and hpk < 0.5:
		return 0.0
	return clampf(0.1 + 0.3 * float(h.ai.get("skill", 0.5)) + 0.15 * float(mini(up.size(), 4) - 1) + 0.3 * (hpk - 0.5), 0.0, 0.85)

## Where a camper waits: a few steps out from the gate, off to one side of the path.
func camp_spot(L: Dictionary, h: Hunter) -> Vector3:
	var out: Vector2 = L["out"]
	var sd := 1.0 if (hash(h.nid) % 2) == 0 else -1.0
	for k in [Vector2(3.5, 2.5), Vector2(4.5, 1.2), Vector2(3.0, 3.5), Vector2(2.5, 0.0)]:
		var p: Vector3 = L["dial"] + Vector3(out.x, 0, out.y) * k.x + Vector3(-out.y, 0, out.x) * k.y * sd
		if not m.world.is_void(p.x, p.z) and not m.world.is_block(p.x, p.z) and not ls.inside(L, p, 1.0):
			return Vector3(p.x, m.world.ground_at(p.x, p.z), p.z)
	return L["dial"]

## Bots that reach a dropped egg pick it up (into the pack, dropping their least valuable thing if full).
func bot_pickups() -> void:
	for L in ls.list:
		var wp = L.get("egg_wp")
		if wp == null or not m.wpicks.has(wp):
			continue
		for h in m.hunters:
			if h.ctrl != "bot" or h.out or h.downed or h.remote or h.dropping:
				continue
			if h.flat_dist(wp["pos"]) < 1.3 and absf(h.pos.y - float(wp["pos"].y)) < 1.2:
				var it := Pack.ground_item(wp)
				if not Pack.room(h):
					var li := Pack.lowest(h)
					if li >= 0:
						Pack.spawn_item(m, h.pack[li], Pack._near(h))
						h.pack.remove_at(li)
				Pack._off_ground(m, wp)
				h.pack.append(it)
				h.ai["leave"] = true
				m.sfx("pickup", h.pos, 0.0, 0.8)
				break
