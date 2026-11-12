class_name TutorialCamps
extends RefCounted
## The tutorial's run levels (Tutorial owns one as `camps`). The hunter lands at level 1 with one point and
## every ability locked, as in a real run. XP comes only from the camps the tutorial sets up: each camp is
## worth the XP to its "to" level (content/rules/tutorial.json "camps"), paid out kill by kill so the level
## ring fills as they fall, and nothing else pays XP here (Hunter.gain_xp asks xp_ok). Points go only where
## the next pick step says (Hunter.can_level asks lets_level), until the ranks step opens them all.

const PICK_LVL := {"sec": 1, "dash": 2, "kin": 3, "ult": 6}     # the level each pick step is at

var tu: Tutorial
var granting := false        # the tutorial is paying XP right now (any other XP is ignored)
var ledger: Array = []       # this camp's monsters: {mb, to, paid}
var count := 0               # how many the latest camp had

func _init(t: Tutorial) -> void:
	tu = t

## Hunter.gain_xp: in the tutorial the local hunter's XP comes only from the camps.
static func xp_ok(h: Hunter) -> bool:
	var c := of(h)
	return c == null or c.granting

## Hunter.can_level: in the tutorial a point goes only into the slot the next pick step unlocks.
static func lets_level(h: Hunter, slot: String) -> bool:
	var c := of(h)
	return c == null or c.may_level(slot)

## Hunter._gate's toast for a locked key: in the tutorial, a point on hand is for the step's own pick.
static func locked_text(h: Hunter) -> String:
	var c := of(h)
	if c == null or h.skill_pts <= 0:
		return "Locked  ·  earn a skill point to unlock it"
	return "Not that one yet  ·  %s takes this point" % Settings.key_cap(String(Tutorial.KEYS.get(c.tu.id(), "")))

## The camps a hunter's levels answer to: the tutorial's, for its own player only (null otherwise).
static func of(h: Hunter) -> TutorialCamps:
	var mt := h.m as Match
	if mt == null or mt.tut == null or h != mt.player:
		return null
	return mt.tut.camps

## The slot a point may go in now: the next pick step's, or any from the ranks step on.
func may_level(slot: String) -> bool:
	var all: Array = Tutorial.steps()
	for i in range(maxi(tu.step, 0), all.size()):
		var sid := String(all[i][0])
		if sid == "ranks":
			return true
		if sid.begins_with("pick_"):
			return slot == sid.substr(5)
	return true

## The slot a pick step unlocks ("" for any other step).
static func pick_slot(sid: String) -> String:
	return sid.substr(5) if sid.begins_with("pick_") else ""

## Pays XP as the tutorial's own: the level-up pop, the chime and the point all come from Hunter.gain_xp.
func grant(x: float) -> void:
	granting = true
	tu.m.player.gain_xp(x)
	granting = false

## Tops the hunter up to a level (a pick step must always have its point, even if a camp fell off the world).
func reach(lvl: int) -> void:
	var p := tu.m.player
	if p.lvl < lvl:
		grant(float(Hunter.XP_TO[lvl - 1]) - p.xp + 0.01)

## Brings in a step's camp near the player (only if none of it is left).
func spawn(sid: String) -> void:
	var c: Dictionary = Content.rules("tutorial")["camps"].get(sid, {})
	var kinds: Array = c.get("foes", [])
	if kinds.is_empty():
		kinds = Content.rules("tutorial")["fight_foes"].get(tu.m.player.arch, ["skitter", "spitter", "skitter"])
	if alive() > 0:
		return
	ledger.clear()
	count = kinds.size()
	var ang := randf() * TAU
	for i in kinds.size():
		var at := Vector3.INF
		if c.get("row", false):
			at = tu.spot(8.0 + i * 1.6, ang)       # (one behind the other, to line up)
		elif c.get("far", false):
			at = tu.spot(8.5 - i * 3.0, ang + i * 0.7)
		else:
			at = tu.spot(6.0 + (i % 3) * 1.2, ang + i * 1.3)
		if at != Vector3.INF:
			var mb := tu.m.spawn_mob(kinds[i], at)
			tu.tank(mb, c.has("to"))
			ledger.append({"mb": mb, "to": int(c.get("to", 0)), "paid": false})

## A monster that fell or was knocked off the player's island is out of every kit's reach: it goes, and if that
## empties the camp a new one comes.
func _cull_strays() -> void:
	var p := tu.m.player
	if not p.grounded:
		return
	var isl := tu.m.world.island_of(p.pos.x, p.pos.z)
	var culled := false
	for e: Dictionary in ledger:
		var mb: Mob = e["mb"]
		if is_instance_valid(mb) and not mb.dead and tu.m.world.island_of(mb.pos.x, mb.pos.z) != isl:
			mb.dead = true
			mb.visible = false
			culled = true
	if culled and alive() == 0:
		spawn(tu.id())

## Each kill pays its share of what is left to the camp's level; the last one tips it over.
func update() -> void:
	_cull_strays()
	for e: Dictionary in ledger:
		if e["paid"] or (is_instance_valid(e["mb"]) and not (e["mb"] as Mob).dead):
			continue
		e["paid"] = true
		var to := int(e["to"])
		var p := tu.m.player
		if to <= 1 or p.lvl >= to:
			continue
		var left := ledger.filter(func(x): return not x["paid"]).size()
		var owed := float(Hunter.XP_TO[to - 1]) - p.xp
		grant(owed / float(left + 1) + (0.01 if left == 0 else 0.0))

func alive() -> int:
	return ledger.filter(func(e): return is_instance_valid(e["mb"]) and not (e["mb"] as Mob).dead).size()

func killed() -> int:
	return count - alive()

## The camp's monster nearest the player of a kind ("" any), or null.
func nearest(kind := "") -> Mob:
	var best: Mob = null
	for e: Dictionary in ledger:
		if not is_instance_valid(e["mb"]):
			continue
		var mb: Mob = e["mb"]
		if mb.dead or (kind != "" and mb.mkind != kind):
			continue
		if best == null or tu.m.player.flat_dist(mb) < tu.m.player.flat_dist(best):
			best = mb
	return best
