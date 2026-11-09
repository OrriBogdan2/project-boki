class_name StationGoals
extends RefCounted
## One plain goal line over each Training Area station (content/rules/station_goals.json), with a tick when you
## have done it once. Nothing blocks you: a goal is only a hint and a tick. Progress is saved per save
## (Save.d["tutorial"]["goals"]), and the Esc menu's "Hide goals" hides the lines (also saved).

const RULES_PATH := "res://content/rules/station_goals.json"
const FLOOR_EPS := 0.15                        # m above the ground that still counts as standing on it
const COL_TODO := Color("ffe9b8")
const COL_DONE := Color("8fe0a0")
static var rules: Dictionary = _load()

var a: Arena
var rows: Array = []                           # {g: the goal's data, label: Label3D, n: hits so far, done: bool}
var _slams := 0                                # the player's wall-slam count last tick

static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	assert(parsed is Dictionary, "%s did not parse" % RULES_PATH)
	return parsed

## The save's part: {"done": {goal id: true}, "hidden": bool}.
static func state() -> Dictionary:
	if typeof(Save.d.get("tutorial")) != TYPE_DICTIONARY:
		Save.d["tutorial"] = {}
	var t: Dictionary = Save.d["tutorial"]
	if typeof(t.get("goals")) != TYPE_DICTIONARY:
		t["goals"] = {"done": {}, "hidden": false}
	return t["goals"]

static func is_done(id: String) -> bool:
	return bool(state()["done"].get(id, false))

static func hidden() -> bool:
	return bool(state().get("hidden", false))

## Entering the duel room counts as its goal (the Training Area is gone by then; the save keeps it).
static func mark_duel() -> void:
	state()["done"]["duel"] = true

func _init(arena: Arena) -> void:
	a = arena
	_slams = int(a.m.player.stats.get("slams", 0))
	for g in rules["goals"]:
		var at: Vector3 = a.m.duel_pad if not g.has("at") else a._arena_point(Vector3(g["at"][0], 0, g["at"][1]))
		var lb := Label3D.new()
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.fixed_size = true
		lb.pixel_size = 0.0009
		lb.font_size = 24
		lb.outline_size = 10
		lb.font = UI.big
		lb.position = at + Vector3(0, float(g["lift"]), 0) if at != Vector3.INF else Vector3.ZERO
		lb.visible = not hidden() and at != Vector3.INF      # (no duel pad: nothing to point at)
		a.m.add_child(lb)
		var row := {"g": g, "label": lb, "n": 0, "done": is_done(String(g["id"]))}
		rows.append(row)
		_show(row)

func done_count() -> int:
	return rows.filter(func(r): return r["done"]).size()

func set_hidden(on: bool) -> void:
	state()["hidden"] = on
	for r in rows:
		(r["label"] as Label3D).visible = not on

## Only the unfinished goals are looked at, a few comparisons each.
func tick() -> void:
	var P: Hunter = a.m.player
	var slams := int(P.stats.get("slams", 0))
	var slammed := slams > _slams
	_slams = slams
	for r in rows:
		if not r["done"] and _passed(r, P, slammed):
			_pass(r)

func hit(dummy: String) -> void:
	for r in rows:
		var g: Dictionary = r["g"]
		if not r["done"] and g["kind"] == "hits" and String(g["who"]).to_upper() == dummy:
			r["n"] += 1
			if r["n"] >= int(g["need"]):
				_pass(r)
			else:
				_show(r)

func _passed(r: Dictionary, P: Hunter, slammed: bool) -> bool:
	var g: Dictionary = r["g"]
	match String(g["kind"]):
		"mode":
			return (a.dummies[0]["mv"] as DummyMove).mode == String(g["mode"])
		"slam":
			return slammed and P.flat_dist(a._arena_point(Vector3(g["at"][0], 0, g["at"][1]))) < float(g["r"])
		"stand":
			return _in_rect(P, g["rect"]) and P.pos.y - a.m.world.ground_at(P.pos.x, P.pos.z) < FLOOR_EPS
		"dash":
			return P.roll_t > 0.0 and _in_rect(P, g["rect"])
		"train":
			return a.m.train.has(String(g["step"]))
	return false

func _in_rect(P: Hunter, rc: Array) -> bool:
	return P.pos.x >= float(rc[0]) and P.pos.x <= float(rc[2]) and P.pos.z >= float(rc[1]) and P.pos.z <= float(rc[3])

func _pass(r: Dictionary) -> void:
	r["done"] = true
	state()["done"][String(r["g"]["id"])] = true
	_show(r)
	Sfx.play("unlock", null, -8.0)
	if a.m.hud:
		a.m.hud.toast("Goal done: %s" % _text(r["g"]), COL_DONE)
	Save.save_game()

func _show(r: Dictionary) -> void:
	var g: Dictionary = r["g"]
	var lb: Label3D = r["label"]
	var need := int(g.get("need", 1))
	var count := "   %d/%d" % [r["n"], need] if need > 1 and r["n"] > 0 and not r["done"] else ""
	lb.text = "%s %s%s" % ["[x]" if r["done"] else "[ ]", _text(g), count]
	lb.modulate = COL_DONE if r["done"] else COL_TODO

func _text(g: Dictionary) -> String:
	return String(g["text"]).format({"throw": Settings.key_cap("throw"), "interact": Settings.key_cap("interact"),
		"jump": Settings.key_cap("jump")})
