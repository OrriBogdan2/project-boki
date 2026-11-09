class_name PingInput
extends RefCounted
## The ping key (middle mouse by default, rebindable): marks a spot for your squad through Match.squad_ping,
## which shows it in the world, on the minimap and the full map, as an edge arrow off screen, and sends it
## to your squad over the net. A tap pings where the cursor is ("go here"): an enemy under it gives an
## "enemy" ping, loot a "loot" ping, anything else the ground there. A hold opens a four-way wheel (KINDS)
## that pings the spot you held on. With the full map open a press pings the map point. Riding in or
## dropping, it pings the ground under the cursor: where you mean to land.

const LIFE_S := 6.0                  # s a ping stays up
const PLAN_LIFE_S := 45.0            # s, during the drop planning, when pings are landing picks
const MAX_PER_PLAYER := 2            # pings one hunter keeps up; a third retires the oldest
const BOT_GOAL_S := 30.0              # s a bot keeps heading for a ping it answered
const HOLD_S := 0.3                  # s held before the wheel opens
const PICK_PX := 40.0                # px on screen: how near the cursor an enemy or loot counts as pointed at
const ENEMY_COL := Color("ff4a3d")   # an enemy ping, whoever placed it
## Kind -> the one word its marker shows (a plain spot shows who placed it).
const WORDS := {"enemy": "Enemy", "loot": "Loot", "help": "Need help", "careful": "Careful"}
## What each wheel wedge tells your squad, as its small line.
const HINTS := {"enemy": "a foe is here", "loot": "something to grab", "help": "come to me", "careful": "danger here"}
## The wheel, in KinWheel's segment form: up, right, down, left.
const KINDS := [
	{"id": "enemy", "label": "Enemy here", "dir": Vector2(0, -1)},
	{"id": "loot", "label": "Loot here", "dir": Vector2(1, 0)},
	{"id": "help", "label": "Need help", "dir": Vector2(0, 1)},
	{"id": "careful", "label": "Careful", "dir": Vector2(-1, 0)},
]

## Per frame from Match._gather_input: the ping key. Pressed on the full map it pings the map point at once;
## in the world a tap on release pings under the cursor and a hold opens the wheel (letting go picks).
static func poll(m: Match, map_up: bool) -> void:
	var h := m.player
	if h == null or m.paused:
		return
	if map_up:
		h.inp.erase("ping_t")
		if Input.is_action_just_pressed("ping"):
			place_map(m, m.hud.c.get_local_mouse_position())
		return
	var mouse := m.get_viewport().get_mouse_position()
	if Input.is_action_just_pressed("ping"):
		h.inp["ping_t"] = 0.0
	if not h.inp.has("ping_t"):
		return
	if Input.is_action_pressed("ping"):
		_hold(h, mouse, m.get_process_delta_time())
		return
	var wheel: Dictionary = h.inp.get("ping_wheel", {})
	h.inp.erase("ping_t")
	h.inp.erase("ping_wheel")
	if wheel.is_empty():
		place_world(m, mouse)
	elif int(wheel["sel"]) >= 0:
		place_world(m, wheel["o"], String(KINDS[int(wheel["sel"])]["id"]))

## Is the ping wheel up for `h`?
static func wheel_open(h: Hunter) -> bool:
	return h.inp.has("ping_wheel")

static func _hold(h: Hunter, mouse: Vector2, dt: float) -> void:
	var t := float(h.inp["ping_t"]) + dt
	h.inp["ping_t"] = t
	if t >= HOLD_S and not h.riding and not h.inp.has("ping_wheel"):
		h.inp["ping_wheel"] = {"o": mouse, "sel": -1}
	if h.inp.has("ping_wheel"):
		var wheel: Dictionary = h.inp["ping_wheel"]
		wheel["sel"] = KinWheel.pick(mouse - (wheel["o"] as Vector2), KINDS)
		wheel["t"] = t - HOLD_S
		h.inp["fire"] = false        # a flick is not a shot

## A ping on the full map at `at` (HUD coordinates); nothing if `at` is off the map.
static func place_map(m: Match, at: Vector2) -> void:
	var fm: FullMap = m.hud.full_map
	if fm.rect.has_point(at):
		fm.ping_at(fm.to_world(at))

## A ping at screen point `sp` in the world. With a `kind` (the wheel's pick) it marks the ground there;
## without, an enemy or loot under `sp` gives its own kind, else a plain spot. Returns the kind placed.
static func place_world(m: Match, sp: Vector2, kind := "") -> String:
	var h := m.player
	if h == null or h.out or h.extracted:
		return ""
	if kind != "":
		m.squad_ping(h, _ground_at(m, sp), false, kind)
		return kind
	if not (h.riding or h.dropping):
		var foe := _enemy_at(m, sp)
		if foe:
			m.squad_ping(h, foe.pos, false, "enemy")
			return "enemy"
		var loot := _loot_at(m, sp)
		if loot != Vector3.INF:
			m.squad_ping(h, loot, false, "loot")
			return "loot"
	m.squad_ping(h, _ground_at(m, sp))
	return "spot"

## How long a ping placed now lasts.
static func life(m: Match) -> float:
	return PLAN_LIFE_S if m.skydrop and m.skydrop.planning else LIFE_S

## Retires `h`'s oldest pings until there is room for one more.
static func make_room(m: Match, h: Hunter) -> void:
	var mine: Array = m.pings.filter(func(pg): return pg.get("by") == h)
	while mine.size() >= MAX_PER_PLAYER:
		m.pings.erase(mine.pop_front())

## The bots of `h`'s squad head for a "go here" ping their squad leader places.
static func call_bots(m: Match, h: Hunter, p: Vector3, kind: String) -> void:
	if kind != "" or m.skydrop == null or not m.skydrop.is_lead(h):
		return
	for b in m.hunters:
		if b != h and b.team == h.team and b.ctrl == "bot" and not b.remote and not b.out:
			b.ai["ping_goal"] = {"pos": p, "until": m.time + BOT_GOAL_S, "by": h}

## A ping's colour: red on an enemy, else the pinger's squad colour.
static func color(m: Match, h: Hunter, kind: String) -> Color:
	return ENEMY_COL if kind == "enemy" else m.mate_col(h)

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
		if not bool(c["open"]):
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
