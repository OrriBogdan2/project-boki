class_name PingInput
extends RefCounted
## The ping key (middle mouse by default, or Alt+click): marks a spot for your squad through Match.squad_ping, which
## shows it in the world, on the minimap and the full map, as an edge arrow off screen, and sends it to
## the bots and over the net. With the full map open it pings the map point. Otherwise it reads what the
## cursor is on: an enemy hunter gives an "enemy" ping, loot (a pickup, a deathbox, a chest or a crate) a
## "loot" ping, anything else the ground there. Riding in or dropping, it pings the ground under the
## cursor: where you mean to land. An enemy ping follows its hunter for ENEMY_T; each player keeps CAP
## pings (see docs/decisions/0094-world-ping-follow.md).

const PICK_PX := 40.0                # px on screen: how near the cursor an enemy or loot counts as pointed at
const LOOT_COL := Color("ffc94a")    # loot or a box
const ENEMY_T := 4.0                 # s an enemy ping follows its hunter, then it is gone
const CAP := 2                       # pings per player: one more drops their oldest
## Kind -> the one word its marker shows (a plain spot shows who placed it).
const WORDS := {"enemy": "Enemy", "loot": "Loot"}

## Per frame from Match._gather_input: on the ping key or Alt+click, places a ping where the cursor is.
## While Alt is held the left click pings instead of shooting.
static func poll(m: Match, map_up: bool) -> void:
	var alt := Input.is_key_pressed(KEY_ALT)
	if alt:
		m.player.inp["fire"] = false
	var pressed := Input.is_action_just_pressed("ping") or (alt and Input.is_action_just_pressed("fire"))
	if m.paused or not pressed:
		return
	if map_up:
		place_map(m, m.hud.c.get_local_mouse_position())
	else:
		place_world(m, m.get_viewport().get_mouse_position())

## A ping on the full map at `at` (HUD coordinates); nothing if `at` is off the map.
static func place_map(m: Match, at: Vector2) -> void:
	var fm: FullMap = m.hud.full_map
	if fm.rect.has_point(at):
		fm.ping_at(fm.to_world(at))

## A ping at screen point `sp` in the world: on an enemy, on loot, or on the ground. Returns its kind.
static func place_world(m: Match, sp: Vector2) -> String:
	var h := m.player
	if h == null or h.out or h.extracted:
		return ""
	if not (h.riding or h.dropping):
		var foe := _enemy_at(m, sp)
		if foe:
			m.squad_ping(h, foe.pos, false, "enemy", foe)
			return "enemy"
		var loot := _loot_at(m, sp)
		if loot != Vector3.INF:
			m.squad_ping(h, loot, false, "loot")
			return "loot"
	m.squad_ping(h, _ground_at(m, sp))
	return "spot"

## A ping's colour: the foe colour on an enemy, gold on loot, else the pinger's squad colour.
static func color(m: Match, h: Hunter, kind: String) -> Color:
	if kind == "enemy":
		return SideColor.foe()
	return LOOT_COL if kind == "loot" else m.mate_col(h)

## How long a ping of `kind` lasts.
static func life(kind: String) -> float:
	return ENEMY_T if kind == "enemy" else Match.SQUAD_PING_T

## Before `h` places a ping: drops their oldest ones so the new one keeps them at CAP.
static func make_room(m: Match, h: Hunter) -> void:
	var theirs: Array = m.pings.filter(func(pg): return pg.get("by") == h)
	for i in theirs.size() - CAP + 1:
		m.pings.erase(theirs[i])

## Per frame from Match: ages every ping, moves enemy pings onto their hunter while it is in sight,
## drops the expired.
static func tick(m: Match, dt: float) -> void:
	for pg in m.pings.duplicate():
		pg["t"] += dt
		var foe = pg.get("foe")
		if foe is Hunter and is_instance_valid(foe) and not (foe as Hunter).out and not (foe as Hunter).unseen:
			pg["pos"] = (foe as Hunter).pos
		if pg["t"] > float(pg.get("life", 4.0)):
			m.pings.erase(pg)

## The word over a squad ping in the world, as seen by `me`.
static func label(pg: Dictionary, me: Hunter) -> String:
	var kind := String(pg.get("kind", ""))
	if WORDS.has(kind):
		return WORDS[kind]
	var by: Hunter = pg["by"] if is_instance_valid(pg["by"]) else null
	if by == me:
		return "Your ping"
	return by.pname if by else "Ping"

## The visible enemy hunter nearest `sp` on screen, within PICK_PX.
static func _enemy_at(m: Match, sp: Vector2) -> Hunter:
	var best: Hunter = null
	var bd := PICK_PX
	for x in m.hunters:
		if x.team == m.player.team or x.out or x.extracted or x.riding or x.unseen or not x.visible:
			continue
		var d := _screen_dist(m, x.pos + Vector3(0, 0.9, 0), sp)
		if d < bd:
			bd = d
			best = x
	return best

## The loot nearest `sp` on screen within PICK_PX (its world spot), or Vector3.INF.
static func _loot_at(m: Match, sp: Vector2) -> Vector3:
	var spots: Array = []
	for w in m.wpicks:
		spots.append(w["pos"])
	for b in m.boxes:
		if not bool(b.get("empty", false)) and b.get("node") != null:
			spots.append(b["pos"])
	for c in m.chests:
		if not bool(c["open"]) and (c["node"] as Node3D).visible:      # (hidden on the drop: KeyChest.show_all)
			spots.append(c["pos"])
	for br in m.breaks:
		if not bool(br["dead"]):
			spots.append(br["pos"])
	var best := Vector3.INF
	var bd := PICK_PX
	for at in spots:
		var d := _screen_dist(m, at + Vector3(0, 0.5, 0), sp)
		if d < bd:
			bd = d
			best = at
	return best

static func _screen_dist(m: Match, at: Vector3, sp: Vector2) -> float:
	if m.cam.is_position_behind(at):
		return INF
	return m.cam.unproject_position(at).distance_to(sp)

## The ground under screen point `sp`: the camera ray met with the terrain (two refinements, as
## Match._mouse_aim does), or the player's spot when the ray runs flat.
static func _ground_at(m: Match, sp: Vector2) -> Vector3:
	var o := m.cam.project_ray_origin(sp)
	var d := m.cam.project_ray_normal(sp)
	if absf(d.y) < 0.0001:
		return m.player.pos
	var y := 0.0 if m.player.dropping or m.player.riding else m.player.pos.y
	var p := o + d * ((y - o.y) / d.y)
	for _i in 2:
		var g := m.world.ground_at(p.x, p.z)
		if g <= World.VOID + 1.0:
			break
		p = o + d * ((g - o.y) / d.y)
	return p
