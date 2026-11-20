class_name TutorialCamps
extends RefCounted
## The tutorial's run levels (Tutorial owns one as `camps`). The hunter lands at level 1 with one point and
## every ability locked, as in a real run. XP comes only from the camps the tutorial sets up: each camp is
## worth the XP to its "to" level (content/rules/tutorial.json "camps"), paid out kill by kill so the level
## ring fills as they fall, and nothing else pays XP here (Hunter.gain_xp asks xp_ok). A beat that uses an
## ability unlocks it itself (unlock); a point may go anywhere but the Fusion (Hunter.can_level asks lets_level).

const UNLOCK_LVL := {"sec": 1, "dash": 2, "kin": 3}     # the level each beat's ability opens at
## m to a row camp's first monster: past an idle monster's notice (Mob, 7.5 m), so the line holds
const ROW_FROM := 10.0
const ROW_STEP := 1.6     # m between a row camp's monsters, one behind the other
const TELEGRAPH_T := 3.0  # s the first camp's marker counts down on the world and the minimap before it appears

var tu: Tutorial
var granting := false        # the tutorial is paying XP right now (any other XP is ignored)
var ledger: Array = []       # this camp's monsters: {mb, to, paid}
var count := 0               # how many the latest camp had
var told := false            # the first camp has been telegraphed (CampMark); later ones come at once
var coming: Dictionary = {}  # the telegraphed camp: {sid, kinds, spots, at: marker spot, left: s to go}

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

## Hunter._gate's toast for a locked key.
static func locked_text(_h: Hunter) -> String:
	return "Locked  ·  earn a skill point to unlock it"

## The camps a hunter's levels answer to: the tutorial's, for its own player only (null otherwise).
static func of(h: Hunter) -> TutorialCamps:
	var mt := h.m as Match
	if mt == null or mt.tut == null or h != mt.player:
		return null
	return mt.tut.camps

## The slot a point may go in: any but the Fusion, which never opens in the tutorial.
func may_level(slot: String) -> bool:
	return slot != "ult"

## A beat's ability opens: its level, and a point for it (one more level when a key press spent the last).
func unlock(slot: String) -> void:
	var p := tu.m.player
	if int(p.slot_lv[slot]) > 0:
		return
	reach(int(UNLOCK_LVL[slot]))
	if p.skill_pts <= 0:
		reach(p.lvl + 1)
	p.level_slot(slot)

## Pays XP as the tutorial's own: the level-up pop, the chime and the point all come from Hunter.gain_xp.
func grant(x: float) -> void:
	granting = true
	tu.m.player.gain_xp(x)
	granting = false

## Tops the hunter up to a level (a beat's unlock must always have its point, even if a camp fell off the world).
func reach(lvl: int) -> void:
	var p := tu.m.player
	if p.lvl < lvl:
		grant(float(Hunter.XP_TO[lvl - 1]) - p.xp + 0.01)

## Brings in a step's camp near the player (only if none of it is left).
func spawn(sid: String) -> void:
	var c: Dictionary = Content.rules("tutorial")["camps"].get(sid, {})
	var kinds: Array = c.get("foes", [])
	if alive() > 0:
		return
	ledger.clear()
	count = 0
	if told:
		add(sid, kinds)
		return
	told = true
	count = kinds.size()
	var spots := _plan(sid, kinds)
	var at := Vector3.ZERO
	for q in spots:
		at += q / float(maxi(spots.size(), 1))
	coming = {"sid": sid, "kinds": kinds, "spots": spots, "at": at, "left": TELEGRAPH_T}

## Adds monsters to a step's camp as it stands (a second wave): placed and paid as the step's camp is.
func add(sid: String, kinds: Array) -> void:
	count += kinds.size()
	_place(sid, kinds, _plan(sid, kinds))

## Where each of a camp's monsters stands (Vector3.INF where the island has no room).
func _plan(sid: String, kinds: Array) -> Array:
	var c: Dictionary = Content.rules("tutorial")["camps"].get(sid, {})
	var ang := randf() * TAU
	var spots: Array = []
	var line: Array = row(kinds.size(), ang) if c.get("row", false) else []
	for i in kinds.size():
		var at := Vector3.INF
		if c.get("held", false):
			at = tu.foe_spot(sid, i)       # (fixed posts in the open, clear of every cliff: they never wander off)
		elif c.get("row", false):
			# (one behind the other, to line up)
			at = line[i] if i < line.size() else tu.spot(ROW_FROM + i * ROW_STEP, ang)
		elif c.get("far", false):
			at = tu.spot(8.5 - i * 3.0, ang + i * 0.7)
		else:
			at = tu.spot(6.0 + (i % 3) * 1.2, ang + i * 1.3)
		spots.append(at)
	return spots

func _place(sid: String, kinds: Array, spots: Array) -> void:
	var c: Dictionary = Content.rules("tutorial")["camps"].get(sid, {})
	var camp_hp: float = Content.rules("tutorial")["mob"]["camp_hp"]
	for i in kinds.size():
		if spots[i] != Vector3.INF:
			var mb := tu.m.spawn_mob(kinds[i], spots[i])
			tu.tank(mb, float(c.get("hp", camp_hp)))
			mb.held = bool(c.get("held", false))
			ledger.append({"mb": mb, "to": int(c.get("to", 0)), "paid": false})

## A row camp's spots, one behind the other on ONE line out from the player: the first direction (from `ang`, the
## way Tutorial.spot turns) where the whole row stands on the player's island clear of edges, at full distance
## or, failing that, pulled in. Empty if no line fits (each monster then finds its own spot). Placing them one by
## one let a monster near an edge fall back to a shorter distance, so the row bunched up and the spawn push
## shoved one onto the next island.
func row(n: int, ang: float) -> Array:
	var w := tu.m.world
	var p := tu.m.player
	var isl := w.island_of(p.pos.x, p.pos.z)
	for i in 24:
		var a := ang + i * 0.52
		for d0 in [ROW_FROM, ROW_FROM * 0.7, ROW_FROM * 0.5]:
			var out: Array = []
			for j in n:
				var x: float = p.pos.x + cos(a) * (d0 + j * ROW_STEP)
				var z: float = p.pos.z + sin(a) * (d0 + j * ROW_STEP)
				if w.island_of(x, z) != isl or w.is_block(x, z) or w.edge_dist(int(x), int(z), 2) < 2:
					break
				out.append(Vector3(floor(x) + 0.5, w.ground_at(x, z), floor(z) + 0.5))
			if out.size() == n:
				return out
	return []

## The send is in: the camp's held monsters wake (the Boki and they go at each other).
func release() -> void:
	for e: Dictionary in ledger:
		if is_instance_valid(e["mb"]):
			(e["mb"] as Mob).held = false

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
## A retry: the camp goes without a kill (no XP) and the ledger starts again, so the camp brought back pays
## only what is left to its level.
func clear() -> void:
	coming = {}
	for e: Dictionary in ledger:
		if is_instance_valid(e["mb"]) and not (e["mb"] as Mob).dead:
			(e["mb"] as Mob).vanish()
	ledger.clear()
	count = 0

## Each kill pays its share of what is left to the camp's level; the last one tips it over.
func update(dt: float) -> void:
	if not coming.is_empty():
		coming["left"] = float(coming["left"]) - dt
		if float(coming["left"]) <= 0.0:
			var c := coming
			coming = {}
			_place(String(c["sid"]), c["kinds"], c["spots"])
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
	if not coming.is_empty():
		return (coming["kinds"] as Array).size()      # (a camp on its way counts: no step ends or re-spawns on it)
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
