class_name LessonHall
extends RefCounted
## The Lessons hall (content/rules/lessons.json): a building where you leave a Boki for a timed lesson (song, dance
## or drawing). The Boki walks off the farm for the lesson's length, then comes out of the door with a stat point
## or two and a new habit that KinHabit plays now and then. The lesson is on the Boki's record (rec["lesson"] =
## {id, t}, t in unix seconds), so it finishes by the clock even with the game closed; what it learned is
## rec["habits"]. Your partner stays with you. Reached from HomeEcon (find, label, use, tick).

const ID := "lesson_hall"
const CHECK_S := 1.0  # s between looks at who has finished

var h  # the Home screen
var _look_t := 0.0


func _init(home) -> void:
	h = home


static func rules() -> Dictionary:
	return Content.rules("lessons")


static func lesson(id: String) -> Dictionary:
	return rules()["lessons"][id]


static func ids() -> Array:
	return (rules()["lessons"] as Dictionary).keys()


## The placed hall's deco entry, or {}.
static func entry(d: Dictionary) -> Dictionary:
	for e in HomeLayout.of(d).get("deco", []):
		if String(e.get("id", "")) == ID:
			return e
	return {}


## Is this Boki off the farm in a lesson?
static func in_class(rec: Dictionary) -> bool:
	return rec.has("lesson")


## Boki in class now.
static func students(d: Dictionary) -> Array:
	return (d.get("roster", []) as Array).filter(func(r): return r.has("lesson"))


static func left_s(rec: Dictionary, now: float) -> float:
	var l: Dictionary = rec["lesson"]
	return float(lesson(String(l["id"]))["secs"]) - (now - float(l["t"]))


## Why `rec` cannot take lesson `id` now ("" if it can).
static func why_not(d: Dictionary, rec: Dictionary, id: String) -> String:
	var nm := String(rec["name"])
	var l := lesson(id)
	if entry(d).is_empty():
		return "Build the Lessons hall first"
	if rec.has("lesson"):
		return "%s is already in class" % nm
	if students(d).size() >= int(rules()["max_students"]):
		return "The hall is full: %d Boki are in class" % students(d).size()
	if GardenZones.is_partner(rec) or String(d.get("active2", "")) == String(rec["uid"]):
		return "%s is with you: a partner stays out of class" % nm
	if KinBox.is_boxed(rec):
		return "%s is asleep in the Burrow" % nm
	if StatBudget.room(rec, String(l["stat"])) <= 0 and (rec.get("habits", []) as Array).has(String(l["habit"])):
		return "%s has nothing left to learn from %s" % [nm, String(l["name"]).to_lower()]
	if int(d["gems"]) < int(l["gems"]):
		return "%s costs %d gems" % [l["name"], int(l["gems"])]
	return ""


## Sends `rec` to class: pays the fee and starts the clock. False (nothing changes) when it cannot go.
static func enrol(d: Dictionary, rec: Dictionary, id: String, now: float) -> bool:
	if why_not(d, rec, id) != "":
		return false
	d["gems"] = int(d["gems"]) - int(lesson(id)["gems"])
	rec["lesson"] = {"id": id, "t": now}
	return true


## Students whose lesson has run its length.
static func finished(d: Dictionary, now: float) -> Array:
	return students(d).filter(func(r): return left_s(r, now) <= 0.0)


## The lesson ends: the stat points, the habit and a memory. Returns the line to show.
static func graduate(rec: Dictionary) -> String:
	var l := lesson(String(rec["lesson"]["id"]))
	rec.erase("lesson")
	Care.ensure(rec)
	var got := Care.add_stat(rec, String(l["stat"]), int(l["gain"]))
	var habits: Array = rec.get("habits", [])
	var habit := String(l["habit"])
	var fresh := not habits.has(habit)
	if fresh:
		habits.append(habit)
	rec["habits"] = habits
	var stat_name := String(Care.STATS[l["stat"]]["name"])
	var line := "%s finished %s class" % [rec["name"], String(l["name"]).to_lower()]
	line += ": +%d %s" % [got, stat_name] if got > 0 else ", and %s is already at its best" % stat_name
	if fresh:
		line += ", and it %s now" % l["habit_text"]
	Save.remember(rec, "lesson", line + ".", float(rules()["trust"]))
	return line


## A little open hall: a stage under a roof, with a ball for each lesson's colour on the back wall.
static func model(_e: Dictionary) -> Node3D:
	var n := Node3D.new()
	var wood := Models.toon(Color("a8794a"))
	var roof := Models.toon(Color("c75d4b"))
	Models.part(n, Models.box(2.9, 0.12, 1.9), Models.toon(Color("d9c08a"), false), Vector3(0, 0.06, 0))
	Models.part(n, Models.box(2.9, 1.5, 0.12), wood, Vector3(0, 0.87, -0.9))
	for sx in [-1.35, 1.35]:
		Models.part(n, Models.box(0.14, 1.7, 0.14), wood, Vector3(sx, 0.97, 0.85))
	Models.part(n, Models.box(3.2, 0.1, 2.3), roof, Vector3(0, 1.85, -0.05), Vector3.ONE, Vector3(0.12, 0, 0))
	var i := 0
	for id in ids():
		var tint := Models.toon(Color(String(lesson(id)["colour"])))
		Models.part(n, Models.sphere(0.2, 10), tint, Vector3(-0.8 + i * 0.8, 1.15, -0.78))
		i += 1
	return n


## The spot just outside the hall's door, where a finished Boki comes out.
static func door(e: Dictionary) -> Vector3:
	var sz := HomeLayout.size_of(ID, int(e.get("r", 0)))
	var out := HomeLayout.facing(int(e.get("r", 0)))
	return HomeLayout.deco_center(e) + out * (maxf(sz.x, sz.y) * 0.5 + 0.6)


## The walk-up spot: E at the hall while you stand within reach of it.
func find(p2: Vector2) -> Dictionary:
	var e := entry(Save.d)
	if e.is_empty():
		return {}
	var c := HomeLayout.deco_center(e)
	var sz := HomeLayout.size_of(ID, int(e.get("r", 0)))
	var reach := float(rules()["reach"])
	var near := absf(p2.x - c.x) <= sz.x * 0.5 + reach and absf(p2.y - c.z) <= sz.y * 0.5 + reach
	return {"kind": "place", "hall": e} if near else {}


func label() -> String:
	var n := students(Save.d).size()
	return "Lessons hall  ·  %d in class" % n if n > 0 else "Lessons hall"


## Looks about once a second for finished lessons.
func tick(d: float) -> void:
	_look_t -= d
	if _look_t > 0.0 or not h.visit.is_empty():
		return
	_look_t = CHECK_S
	for rec in finished(Save.d, Time.get_unix_time_from_system()):
		var line := graduate(rec)
		_walk_out(rec)
		h._toast(line)
		Save.save_game()


## Back on the farm at the hall's door, if the hall is in the zone you are in and the Boki lives here.
func _walk_out(rec: Dictionary) -> void:
	var e := entry(Save.d)
	if e.is_empty() or not GardenZones.walks_in(rec, GardenZones.current()):
		return
	var at := door(e)
	var k: Dictionary = h.add_kin(rec, h.world.island_of(at.x, at.z))
	k["pos"] = at
	(k["node"] as Node3D).position = at
	h.fx.burst(at + Vector3(0, 0.8, 0), Color(String(lesson("song")["colour"])), 12, 1.6, 0.5)


## Leaves the farm for class: the Boki's body goes, its record stays on the roster.
func _send(rec: Dictionary, id: String) -> void:
	if not enrol(Save.d, rec, id, Time.get_unix_time_from_system()):
		return
	var k: Dictionary = h._kin_entry(rec)
	if not k.is_empty():
		var n: Node3D = k["node"]
		h.fx.burst(n.position + Vector3(0, 0.6, 0), Color(String(lesson(id)["colour"])), 14, 2.0, 0.6)
		n.queue_free()
		h.kins.erase(k)
	Save.save_game()
	h._toast(
		(
			"%s is off to %s class: back in %d min"
			% [rec["name"], String(lesson(id)["name"]).to_lower(), ceili(float(lesson(id)["secs"]) / 60.0)]
		)
	)
	use()


## The hall's panel: who is in class, and a row per Boki that can go with a button per lesson.
func use() -> void:
	var v: VBoxContainer = h._new_panel("Lessons hall", 600)
	UI.subtitle(v, "Leave a Boki for a lesson. It comes back with a new habit.")
	var now := Time.get_unix_time_from_system()
	for rec in students(Save.d):
		var l := lesson(String(rec["lesson"]["id"]))
		var mins := ceili(maxf(0.0, left_s(rec, now)) / 60.0)
		v.add_child(
			UI.label("%s: %s class, %d min left" % [rec["name"], String(l["name"]).to_lower(), mins], UI.T_BODY, UI.INK)
		)
	v.add_child(UI.section("Send a Boki"))
	var shown := 0
	for rec in KinBox.farm():
		if rec.has("lesson") or GardenZones.is_partner(rec) or shown >= 6:
			continue
		shown += 1
		var row := UI.hbox(8)
		var name_lbl := UI.label(
			String(rec["name"]), UI.T_BODY, Data.KIN.get(String(rec["species"]), {}).get("color", UI.INK)
		)
		name_lbl.custom_minimum_size = Vector2(130, 0)
		row.add_child(name_lbl)
		for id in ids():
			var l := lesson(id)
			var r: Dictionary = rec
			var b := UI.button("%s  %dg" % [l["name"], int(l["gems"])], func(): _send(r, id), 130)
			b.tooltip_text = "%s\n%s" % [l["desc"], why_not(Save.d, r, id)]
			b.disabled = why_not(Save.d, r, id) != ""
			row.add_child(b)
		v.add_child(row)
	if shown == 0:
		v.add_child(UI.label("Every Boki here is in class or stays with you.", UI.T_BODY, UI.MUTED))
