class_name Camps
extends RefCounted
## Monster camps (content/rules/camps.json, docs/decisions/0048-camps-and-xp.md). Spawns a camp on
## each of the map's camp spots, sized by its layout kind (one size up in the hot zone). Each camp
## keeps a state: LIVE, then CLEARED when its last monster dies, RETURNING when it comes back once,
## one size up, then SPENT. The last kill drops the camp's one reward bundle where that monster fell
## and toasts the killer's squad. Its monsters pay XP on their own kills (XpRules) and roll no drops
## of their own. The host (or the offline game) runs camps; other games see the monsters and the toast.
## A clear gives back part of the summon cooldown (KinSummon.refund) of each clearing squadmate the camp
## paid XP, by size ("refund" in the rules); each game refunds the Hunters it owns, from the "campclr" event.
##
## Public API:
##   Camps.list() -> Array            {id, pos, size, state, back_t, region} per camp
##   Camps.nearest_live(pos, r) -> Dictionary   the nearest camp with monsters up within r m ({} if none)
##   Camps.region_xp(region) -> float  the XP still alive in a region's camps
##   Camps.safe_for(pos, ahead) -> bool   the Blight will not have this spot ahead seconds from now
##   signal cleared(id, squad)

signal cleared(id: int, squad: int)

enum State { LIVE, CLEARED, RETURNING, SPENT }

static var _rules: Dictionary = {}

var m: Match
# per camp: {id, pos, island, size (index in sizes), state, mobs, back_t, region, paid {team: xp},
# paid_h {hunter nid: true} (everyone its kills paid XP, for the summon refund)}
var camps: Array = []
var comebacks := 0           # (tests and the rolling sim)
var _tick_t := 0.0

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/camps.json"))
		_rules = d if d is Dictionary else {}
	return _rules

static func size_def(i: int) -> Dictionary:
	return rules()["sizes"][i]

## Whether a monster belongs to a camp (it then rolls no drops of its own).
static func is_camp(mb: Mob) -> bool:
	return mb.has_meta("camp")

func _init(match_node: Match) -> void:
	m = match_node

## One camp on every camp spot (Match setup). Only the host spawns monsters.
func spawn_all() -> void:
	if m.net_on and not m.is_host:
		return
	var sizes: Array = rules()["sizes"]
	for spot in m.world.camp_spots:
		await m._slice()
		var si := 0
		for i in sizes.size():
			if sizes[i]["id"] == rules()["kind_size"].get(String(spot.get("kind", "normal")), "camp"): si = i
		var region := m.biomes.hot.region_at(spot["pos"]) if m.biomes else -1
		if m.biomes and region >= 0 and region == m.biomes.hot.hot:
			si = mini(si + 1, sizes.size() - 1)       # the hot zone's camps are one size up
		var c := {"id": camps.size(), "pos": spot["pos"], "island": spot.get("island", -1), "size": si,
			"state": State.LIVE, "mobs": [], "back_t": -1.0, "region": region, "paid": {}}
		camps.append(c)
		_populate(c)

func _populate(c: Dictionary) -> void:
	var sd := size_def(int(c["size"]))
	var p: Vector3 = c["pos"]
	var big := String(sd.get("big", ""))
	var comp: Array = m.biomes.camp_comp_n(p, int(sd["n"]), big) if m.biomes else []
	if comp.is_empty():
		comp = [big] if big != "" else []
		while comp.size() < int(sd["n"]):
			comp.append(String((rules()["small"] as Array)[m.rng.randi_range(0, rules()["small"].size() - 1)]))
	var spread := float(rules()["spread"])
	c["mobs"] = []
	c["paid"] = {}
	c["paid_h"] = {}
	for kk in comp:
		var q := p
		for _t in 20:
			var cand := p + Vector3(m.rng.randf_range(-spread, spread), 0, m.rng.randf_range(-spread, spread))
			if not m.world.is_void(cand.x, cand.z) and not m.world.is_block(cand.x, cand.z):
				q = Vector3(cand.x, m.world.ground_at(cand.x, cand.z), cand.z)
				break
		var mb := m.spawn_mob(String(kk), q)
		var chief: bool = sd.has("big_rar") and kk == big and not c["mobs"].any(func(o): return o.has_meta("chief"))
		mb.set_meta("camp", int(c["id"]))
		if chief: mb.set_meta("chief", true)
		if m.biomes: m.biomes.dress(mb, int(sd.get("big_rar", 0)) if chief else 0)
		c["mobs"].append(mb)

## A monster died (Match.on_mob_dead, host): its camp's last one clears the camp.
func on_mob_dead(mb: Mob, credit: Ent, xp: float) -> void:
	if not is_camp(mb) or int(mb.get_meta("camp")) >= camps.size():
		return
	var c: Dictionary = camps[int(mb.get_meta("camp"))]
	var team: int = credit.team if credit is Hunter else -1
	c["paid"][team] = float(c["paid"].get(team, 0.0)) + xp
	if xp > 0.0:
		for o: Hunter in XpRules.squad_in_range(m, credit):
			c["paid_h"][o.nid] = true
	if c["mobs"].all(func(o): return not is_instance_valid(o) or o.dead):
		_clear(c, mb, credit as Hunter if credit is Hunter else null, team)

func _clear(c: Dictionary, last: Mob, by: Hunter, team: int) -> void:
	var first: bool = c["state"] == State.LIVE
	c["state"] = State.CLEARED if first else State.SPENT
	c["back_t"] = m.time + float(rules()["back_s"]) if first else -1.0
	var p := last.pos if not m.world.is_void(last.pos.x, last.pos.z) else (c["pos"] as Vector3)
	_bundle(size_def(int(c["size"])), p, by)
	var xp := int(c["paid"].get(team, 0.0))
	var paid_h: Array = c["paid_h"].keys()
	show_clear(m, team, int(c["size"]), xp)
	refund_summons(m, team, int(c["size"]), paid_h)
	if m.net_on: m.net_event(["campclr", team, int(c["size"]), xp, paid_h])
	cleared.emit(int(c["id"]), team)

## The camp's one reward, in one spot: armor, maybe a perk orb, maybe a gear piece.
func _bundle(sd: Dictionary, p: Vector3, by: Hunter) -> void:
	m.drop("armor", p + Vector3(0, 0.6, 0), int(sd["armor"]))
	if m.rng.randf() < float(sd["orb"]):
		PerkOrbs.drop(m, "camp", p, 1, by)
	if sd.has("gear"):
		var bonus := (m.biomes.rarity_bonus_at(p) if m.biomes else 0) + int(sd["gear"])
		var g := GearDrops.roll_gear(m.rng, bonus)
		m.spawn_gear(String(g["id"]), int(g["rar"]), p + Vector3(0.8, 0, 0.4))

## The clear toast, for the clearing squad only (here, or from the "campclr" event).
static func show_clear(mt: Match, team: int, size_i: int, xp: int) -> void:
	if mt.hud and mt.player and mt.player.team == team:
		mt.hud.toast("%s cleared  +%d XP" % [String(size_def(size_i)["name"]), xp], Color("ffd27a"))

## The clear's summon refund: each of this game's own Hunters on the clearing squad whose nid is in paid_h
## gets the size's share of their Boki's remaining summon cooldown back (the Boki box ring jumps).
static func refund_summons(mt: Match, team: int, size_i: int, paid_h: Array) -> void:
	var frac := float(size_def(size_i).get("refund", 0.0))
	for h: Hunter in mt.hunters:
		if h.team == team and not h.remote and h.nid in paid_h and h.kin and h.kin.summon and h.kin.owner_h == h:
			h.kin.summon.refund(frac)

## The "campclr" event from the host: the toast, and the refund for the Hunters this game owns.
static func on_clear_event(mt: Match, x: Array) -> void:
	show_clear(mt, int(x[1]), int(x[2]), int(x[3]))
	if x.size() > 4: refund_summons(mt, int(x[1]), int(x[2]), x[4])

func tick(dt: float) -> void:
	_tick_t -= dt
	if _tick_t > 0.0 or (m.net_on and not m.is_host):
		return
	_tick_t = 1.0
	for c in camps:
		if c["state"] != State.CLEARED or m.time < float(c["back_t"]):
			continue
		if m.time > float(rules()["back_until_s"]):
			c["state"] = State.SPENT
		elif _may_return(c):
			c["size"] = mini(int(c["size"]) + 1, rules()["sizes"].size() - 1)
			c["state"] = State.RETURNING
			_populate(c)
			comebacks += 1

func _may_return(c: Dictionary) -> bool:
	var p: Vector3 = c["pos"]
	for h in m.hunters:
		if not h.out and not h.extracted and h.flat_dist(p) < float(rules()["back_clear_r"]):
			return false
	var n := int(size_def(mini(int(c["size"]) + 1, rules()["sizes"].size() - 1))["n"])
	return safe_for(p, float(rules()["back_safe_s"])) and alive() + n <= int(rules()["max_mobs"])

## The Blight will not cover p `ahead` seconds from now. This base has no closing ring yet: the
## islands fall together at the match's end. The Blight zone redesign replaces only this function.
func safe_for(_p: Vector3, ahead: float) -> bool:
	return m.time + ahead < m.length

## Camp monsters alive now.
func alive() -> int:
	var n := 0
	for c in camps:
		for mb in c["mobs"]:
			if is_instance_valid(mb) and not mb.dead: n += 1
	return n

func list() -> Array:
	return camps.map(func(c): return {"id": c["id"], "pos": c["pos"], "size": size_def(int(c["size"]))["id"],
		"state": c["state"], "back_t": c["back_t"], "region": c["region"]})

func nearest_live(p: Vector3, r: float) -> Dictionary:
	var best := {}
	var bd := r
	for c in camps:
		if c["state"] in [State.LIVE, State.RETURNING] and Vector2(p.x - c["pos"].x, p.z - c["pos"].z).length() <= bd:
			bd = Vector2(p.x - c["pos"].x, p.z - c["pos"].z).length()
			best = c
	return best

func region_xp(region: int) -> float:
	var xp := 0.0
	for c in camps:
		if c["region"] != region:
			continue
		for mb in c["mobs"]:
			if is_instance_valid(mb) and not mb.dead: xp += XpRules.kill_xp(mb)
	return xp

## A rolling session's late start (Rolling.after_setup): about frac of the camps were cleared some
## time ago, so some come back soon after you land. Returns how many.
func picked_over(frac: float, rng: RandomNumberGenerator) -> int:
	var n := 0
	for c in camps:
		if rng.randf() >= frac:
			continue
		for mb in c["mobs"]:
			if is_instance_valid(mb) and not mb.dead:
				mb.hp = 0.0
				mb.dead = true
				mb.visible = false
		c["state"] = State.CLEARED
		c["back_t"] = m.time + rng.randf_range(0.0, float(rules()["back_s"]))
		n += 1
	return n
