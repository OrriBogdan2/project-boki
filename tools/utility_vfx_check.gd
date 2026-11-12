extends RefCounted
## --utility-vfx-check: every belt item id has a look that says what it does (UtilityVfx,
## content/vfx/belt/utility.json).
## Data: each id has an entry naming its area, what it does and when it ends, and a "<id>" moment; every moment
## belongs to an item, every layer is a HeroVfx look in the shared caps (2.2 s, 4 m flare, 4.5 m swirl), holds are
## particles only, colours are hex or "side". Play: in one quiet match each item is used for real (a rival in reach,
## a lock beside the user, a downed squadmate, the pad stepped on, the seed stood in...) and every moment its entry
## has plays; the ground looks that last (fuse, edge, portals, spikes, anomaly, ward ring, bag, flag) are up while
## it works and gone once it ends; the marks a body wears go when the effect does; "side" reads you / rival.
## Prints UVFX FAIL lines and "UVFX DONE, N items, failures: M". Never touches the save file.

const MAX_LIFE := 2.2          # s (as --hero-vfx-check)
const MAX_FLARE := 4.0         # m across
const MAX_SWIRL := 4.5         # m radius of a ring or vortex
const RUN_MAX := 130.0         # s an item may take to end (the Bounty Banner runs 120 s)
const SPACE := 18.0            # m between two items' spots
const MOMENTS := ["", "_hit", "_hold", "_end"]
const LOOKS := {               # the ground looks that last, by item
	"skyfall_charge": ["SkyfallFuse"], "blight_flask": ["BlightEdge"], "twin_gate": ["GatePortal", "GateLink"],
	"warp_seed": ["WarpAnomaly"], "thorn_wall": ["ThornSpikes"], "lookout_lantern": ["WardRing"],
	"toss_satchel": ["SatchelBag"], "bounty_banner": ["BountyFlag"],
}

var bad := 0
var main: Node
var m: Match
var P: Hunter
var cast_at := Vector3.ZERO   # where P used the item: its field is the one nearest this
var rival: Hunter
var mate: Hunter
var used: Array[Vector3] = []

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("UVFX FAIL ", what)
		bad += 1

func run(host: Node) -> void:
	main = host
	Save.no_write = true
	Save.d = Save.fresh()
	_data()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 2, "length": 1e9, "seed": 9001, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		if h != P and h.team == P.team:
			mate = h
		elif h.team != P.team and rival == null:
			rival = h
	_park()
	var V := HeroVfx.of(m)
	ok(V._pal(P, "side", "") == SideColor.YOU and V._pal(rival, "side", "") == SideColor.FOE,
			"\"side\" is your colour on you and the rival colour on a rival")
	for id in UtilityBelt.ids():
		await _item(String(id))
	print("UVFX DONE, %d items, failures: %d" % [UtilityBelt.ids().size(), bad])
	host.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ data
func _data() -> void:
	var d := HeroVfx.data(UtilityVfx.FILE)
	var moves: Dictionary = d.get("moves", {})
	var items: Dictionary = d.get("items", {})
	for id in UtilityBelt.ids():
		var e: Dictionary = items.get(id, {})
		for k in ["area", "does", "ends"]:
			ok(String(e.get(k, "")).length() > 8, "%s says its %s" % [id, k])
		ok(moves.has(id), "%s has a moment when it is used" % id)
	for k in items:
		ok(UtilityBelt.is_item(String(k)), "entry %s is a belt item" % k)
	for mv: String in moves:
		var item := ""
		for id in UtilityBelt.ids():
			for suffix in MOMENTS:
				if mv == String(id) + suffix:
					item = id
		ok(item != "", "moment %s belongs to an item (<id>, _hit, _hold, _end)" % mv)
		for layer: Dictionary in moves[mv].get("fx", []):
			_layer(mv, layer)

func _layer(mv: String, layer: Dictionary) -> void:
	var p := String(layer.get("p", ""))
	ok(HeroVfx.MODES.has(p) or HeroVfx.LOOKS.has(p), "%s: %s is a HeroVfx look" % [mv, p])
	ok(not mv.ends_with("_hold") or HeroVfx.LOOKS.has(p), "%s: a hold is particles only (%s)" % [mv, p])
	ok(float(layer.get("life", 0.0)) <= MAX_LIFE, "%s: %s lasts at most %.1f s" % [mv, p, MAX_LIFE])
	var across := float(layer.get("size", 0.0))
	ok(not (p == "flare" and across > MAX_FLARE) and not (p in ["ring", "vortex"] and across > MAX_SWIRL),
			"%s: %s stays in the size caps" % [mv, p])
	for k in ["c", "c2", "c3"]:      # (no palette here: each colour is spelled out)
		ok(layer.get(k) == "side" or Color.html_is_valid(String(layer.get(k, ""))), "%s: %s %s" % [mv, k, layer.get(k)])

# ------------------------------------------------------------------ play
## Everyone else stands far off, out of every item's reach.
func _park() -> void:
	for h in [rival, mate]:
		h.teleport(_ground() + Vector3.ZERO)
		h.out = false
		h.downed = false
	for h in m.hunters:
		if h != P and h != rival and h != mate:
			h.teleport(P.pos + Vector3(300.0, 0, 0))

## Open ground away from every earlier item's spot, with room to aim 6 m along +x.
func _ground() -> Vector3:
	var at: Vector3 = m.world.random_ground()
	for t in 200:
		var clear := used.all(func(u: Vector3) -> bool: return u.distance_to(at) > SPACE)
		var room := not m.world.is_void(at.x + 6.0, at.z) and absf(m.world.ground_at(at.x + 6.0, at.z) - at.y) < 0.4
		for dx in [1.0, 2.0, 4.0]:
			room = room and not m.world.is_block(at.x + dx, at.z)
		if clear and room:
			break
		at = m.world.random_ground()
	used.append(at)
	return at

func _looks(id: String) -> Array:
	var names: Array = LOOKS.get(id, [])
	return main.get_tree().get_nodes_in_group(UtilityLook.GROUP).filter(
			func(n): return is_instance_valid(n) and not n.is_queued_for_deletion() and String(n.name) in names)

func _wanted(id: String) -> Array:
	var moves: Dictionary = HeroVfx.data(UtilityVfx.FILE)["moves"]
	return MOMENTS.map(func(s): return id + s).filter(func(mv): return moves.has(mv))

func _item(id: String) -> void:
	var V := HeroVfx.of(m)
	V.plays.clear()
	P.out = false
	P.downed = false
	P.hp = P.max_hp * 0.5
	P.armor = 0.0
	P.gems = 0
	P.teleport(_ground())
	P.vel = Vector3.ZERO
	P.inp["aim"] = P.pos + Vector3(6.0, 0, 0)
	m.remove_meta("banner_%d" % P.team)
	_before(id)
	UtilityBelt.clear(P)
	UtilityBelt.grant(P, id, 1)
	cast_at = P.pos
	ok(UtilityBelt.use_id(P, id), id + " is used")
	await _steps(0.1)
	for nm: String in LOOKS.get(id, []):
		ok(_looks(id).any(func(n): return String(n.name) == nm), "%s: its %s is up" % [id, nm])
	var wanted := _wanted(id)
	var worn := false
	var t := 0.0
	while t < RUN_MAX:
		_during(id, t)
		worn = worn or not UtilityVfx.wearers(m, id).is_empty()
		var all_played := wanted.all(func(mv): return int(V.plays.get(mv, 0)) > 0)
		if all_played and _looks(id).is_empty() and UtilityVfx.wearers(m, id).is_empty():
			break
		await _steps(0.25)
		t += 0.25
	var missing := wanted.filter(func(mv): return int(V.plays.get(mv, 0)) == 0)
	ok(missing.is_empty(), "%s: every moment plays %s" % [id, missing])
	ok(not wanted.has(id + "_hold") or worn, "%s: a body wears its look while it works" % id)
	ok(UtilityVfx.wearers(m, id).is_empty(), "%s: the worn look ends with it" % id)
	ok(_looks(id).is_empty(), "%s: its ground look is gone once it ends (%.1f s)" % [id, t])
	m.fields.clear()
	_park()

## What the item needs to have someone to act on.
func _before(id: String) -> void:
	match id:
		"scanner", "hawk_whistle", "lookout_lantern":
			rival.teleport(P.pos + Vector3(-5.0, 0, 0))
		"pilfer_pouch":
			rival.teleport(P.inp["aim"])
			rival.gems = 100
		"revive_ember":
			mate.teleport(P.pos + Vector3(0, 0, 3.0))
			mate.downed = true
		"chest_key":
			var locks: Array = BeltKeys._locks(m, id)
			ok(not locks.is_empty(), id + ": the match has a lock to open")
			if not locks.is_empty():
				var at: Vector3 = locks[0]["pos"]
				P.teleport(at + Vector3(0.6, 0, 0))
				used.append(at)

## Steps into what the item made, once it is ready.
func _during(id: String, t: float) -> void:
	match id:
		"jump_pad", "gust_fan":
			if t >= 2.5 and t < 3.0 and not m.gpads.is_empty():
				P.teleport(m.gpads.back()["pos"])
				P.grounded = true
		"warp_seed", "toss_satchel":
			if t < 0.3 and not m.fields.list.is_empty():
				P.teleport(_own_field()["at"])

func _steps(secs: float) -> void:
	for i in int(round(secs / Match.DT)):
		Sfx.listener = P.pos
		P.inv_t = 1.0      # nothing on the map hurts the user: a drink ends only by finishing
		m.step(Match.DT)
	await main.get_tree().process_frame

## The item's own field: the one nearest where it was used (a field from anything else may be newer).
func _own_field() -> Dictionary:
	var best: Dictionary = m.fields.list[0]
	for z: Dictionary in m.fields.list:
		if cast_at.distance_to(z["at"]) < cast_at.distance_to(best["at"]):
			best = z
	return best
