class_name WispStation
extends RefCounted
## The Training Area's wisp station (content/rules/wisp_station.json): a dummy Hunter that stays downed, so it
## shows its round Hunter Wisp (slow, low, never taken), with two critter Boki wisps (quick, shoulder height) that
## pop off it every few seconds. Hold interact on a critter wisp to grab it; it then circles you. Skip counts the
## same as a grab. StationGoals reads done() for its goal line and tick.

const RULES_PATH := "res://content/rules/wisp_station.json"
const POP_ARC := 0.9          # m: how high a wisp rises on its way off the Hunter Wisp
const ORBIT_RATE := 1.8       # rad/s: a grabbed wisp circling you
const SKIP_LIFT := 2.6        # m over the ground: the Skip line, just under the goal line (lift 3.2)
const HOLD_GROW := 0.5        # extra scale a wisp swells to as the hold fills
static var rules: Dictionary = _load()

var m: Match
var dummy: Hunter
var wisps: Array[Node3D] = []
var carried: Array[bool] = []
var hold := 0.0               # s the player has held interact on a wisp
var skipped := false
var skip_label: Label3D = null
var _rest: Array[Vector3] = []
var _pop_t := 0.0             # s since the last pop started
var _origin := Vector3.ZERO   # the Hunter Wisp's middle: where a pop starts

static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	assert(parsed is Dictionary, "%s did not parse" % RULES_PATH)
	return parsed

func _init(match_node: Match, team: int, at: Vector3) -> void:
	m = match_node
	dummy = m.make_hunter(m.next_id("wisp"), team, "light", "Wisp dummy", "idle", {}, at, {"arch": "none"})
	dummy.downed = true
	dummy.hp = 0.0
	dummy.lives = 99
	dummy.down_hp = float(rules["down_hp"])
	_origin = at + Vector3(0, 0.4, 0)
	var species: Array = rules["species"]
	for i in species.size():
		var w := BokiWispLook.build(String(species[i]))
		m.add_child(w)
		wisps.append(w)
		carried.append(false)
		var a := PI * (0.5 + float(i) * 2.0 / species.size())
		_rest.append(shoulder_ring(at, float(rules["apart_m"]), a))
	skip_label = Label3D.new()
	skip_label.text = "Skip: %s" % OS.get_keycode_string(KEY_Z)
	skip_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	skip_label.no_depth_test = true
	skip_label.fixed_size = true
	skip_label.pixel_size = 0.0009
	skip_label.font_size = 22
	skip_label.outline_size = 10
	skip_label.font = UI.big
	skip_label.modulate = Color("c9c2b0")
	skip_label.position = at + Vector3(0, SKIP_LIFT, 0)
	m.add_child(skip_label)
	reset()

## True once a critter wisp has been grabbed or the station was skipped.
func done() -> bool:
	return skipped or carried.has(true)

## A point on a circle of radius r around `base`, at angle a, at a Boki wisp's shoulder height.
static func shoulder_ring(base: Vector3, r: float, a: float) -> Vector3:
	return base + Vector3(cos(a) * r, float(rules["shoulder_m"]), sin(a) * r)

func skip() -> void:
	skipped = true

## Back to rest: grabbed wisps return to the dummy and pop off it again.
func reset() -> void:
	carried.fill(false)
	hold = 0.0
	_pop()
	_pose(0.0)

## Every frame: keeps the dummy downed, pops the wisps, runs the grab and the skip label.
func tick(dt: float, goal_shown: bool) -> void:
	dummy.down_hp = float(rules["down_hp"])
	skip_label.visible = goal_shown and not done()
	_pop_t += dt
	if _pop_t >= float(rules["repeat_s"]):
		_pop()
	_pose(clampf(_pop_t / float(rules["pop_s"]), 0.0, 1.0))
	_grab(dt)

func _pop() -> void:
	_pop_t = 0.0
	m.fx.burst(_origin, Color("ffe9b8"), 10, 3.0, 0.4)

## Wisps hop on the spot (BokiWispLook.pose); a carried one circles the player, a popping one flies off the Hunter Wisp.
func _pose(pop_k: float) -> void:
	for i in wisps.size():
		var w := wisps[i]
		BokiWispLook.pose(w, m.time)
		if carried[i]:
			var a := m.time * ORBIT_RATE + PI * float(i)
			w.position = shoulder_ring(m.player.pos, float(rules["orbit_m"]), a)
		else:
			w.position = _origin.lerp(_rest[i], pop_k) + Vector3(0, POP_ARC * 4.0 * pop_k * (1.0 - pop_k), 0)
		w.scale = Vector3.ONE

## Holding interact within reach of a loose critter wisp fills the hold; full, it is yours. The round Wisp is no target.
func _grab(dt: float) -> void:
	var P := m.player
	var near := -1
	for i in wisps.size():
		var gap := wisps[i].position.distance_to(P.pos + Vector3(0, 1.0, 0))
		if not carried[i] and not P.downed and gap < float(rules["reach_m"]):
			near = i
	if near >= 0 and P.inp.get("interact", false):
		hold += dt
	else:
		hold = maxf(0.0, hold - dt * 2.0)
	if near >= 0:
		wisps[near].scale = Vector3.ONE * (1.0 + HOLD_GROW * hold / float(rules["hold_s"]))
	if near >= 0 and hold >= float(rules["hold_s"]):
		carried[near] = true
		hold = 0.0
		var col := SideColor.of(m, P)
		m.fx.ring(wisps[near].position, 1.6, col, 0.4)
		m.fx.burst(wisps[near].position, col, 14, 3.5, 0.5)
		m.sfx("revive", null, -6.0)
