class_name HungerGate
extends VBoxContainer
## The "Too hungry to go" panel body: how many more meals the partner needs, a bar with the line it has to
## cross, and a Feed button right there. It re-reads the Boki every poll_s (tuning.json "hunger_gate"), so a
## feeder or a meal moves the bar and the moment the line is crossed the panel offers Go, with no closing and reopening.

const BAR_H_PX := 20.0          # px, the fed bar's height
const BAR_BACK := Color(0.09, 0.085, 0.12)
const LINE_W_PX := 3.0          # px, the minimum line
const FULL_AT := 92.0           # food, above this a Boki turns a meal down (Care.feed)

var home: Node
var go: Callable                # called by the Go button once the partner can come
var back: Callable
var _key := ""
var _clock := 0.0

## Whole meals still needed before `rec` stops being too weak to come (0 when it already can).
static func meals_needed(rec: Dictionary) -> int:
	var over := Care.starve_h(rec) - Care.STARVE["refuse"]
	return 0 if over < 0.0 else int(floor(over / Care.MEAL_H)) + 1

## How fed it is, 0..1 (a Boki that has starved the whole of STARVE["dead"] hours is at 0).
static func fed_level(rec: Dictionary) -> float:
	return clampf(1.0 - Care.starve_h(rec) / Care.STARVE["dead"], 0.0, 1.0)

## Where the minimum line sits on that bar, 0..1.
static func line_level() -> float:
	return 1.0 - Care.STARVE["refuse"] / Care.STARVE["dead"]

## The food to put down: its favourite if known, then kibble, the crops, a bun. "" when the pantry has none.
static func pick_food(rec: Dictionary) -> String:
	var known: Array = rec.get("known", [])
	var likes: Dictionary = rec.get("likes", {})
	var order: Array = []
	if known.has("food"): order.append(String(likes.get("food", "")))
	order.append("kibble")
	order.append_array(Data.CROPS.keys())
	order.append("sweetbun")
	for f in order:
		if known.has("hates") and f == String(likes.get("hates", "")):
			continue
		if Econ.pantry(f) > 0:
			return f
	return ""

func _init(home_node: Node, go_cb: Callable, back_cb: Callable) -> void:
	home = home_node
	go = go_cb
	back = back_cb
	add_theme_constant_override("separation", 10)

func _ready() -> void:
	_rebuild()

func _process(dt: float) -> void:
	_clock += dt
	if _clock >= float(Tuning.of("hunger_gate")["poll_s"]):
		_clock = 0.0
		if _state_key() != _key:
			_rebuild()

func _state_key() -> String:
	var rec := Save.active_kin()
	if rec.is_empty():
		return ""
	var starve_tenths := int(Care.starve_h(rec) * 10.0)
	var full := int(Care.need(rec, "food") >= FULL_AT)
	return "%s|%d|%s|%d|%d" % [rec["uid"], meals_needed(rec), pick_food(rec), starve_tenths, full]

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
		remove_child(c)
	_key = _state_key()
	var rec := Save.active_kin()
	if rec.is_empty():
		add_child(UI.button("Back", back, 140))
		return
	var need := meals_needed(rec)
	var nm := String(rec["name"])
	var head := "%s is fed enough to come." % nm
	if need > 0:
		head = "%s needs %d more meal%s." % [nm, need, "" if need == 1 else "s"]
	add_child(UI.label(head, 17, UI.GOOD if need == 0 else UI.INK, UI.big))
	add_child(_Bar.new(fed_level(rec), line_level(), need == 0))
	add_child(UI.para("It can come once the bar passes the line." if need > 0 else "Ready when you are.", UI.T_SMALL))
	var row := UI.hbox(10)
	var main_b: Button = null           # what Enter presses
	if need == 0:
		main_b = UI.primary("Go", go, 160)
		row.add_child(main_b)
	else:
		var f := pick_food(rec)
		var full := Care.need(rec, "food") >= FULL_AT
		if f == "":
			add_child(UI.para("Nothing to feed it. Harvest crops, or buy kibble at the stall.", UI.T_SMALL, UI.BAD))
		elif full:
			add_child(UI.para("It is full right now. Try again in a little while.", UI.T_SMALL, UI.BAD))
		var feed_b := UI.primary("Feed %s" % Care.food_name(f) if f != "" else "Feed", _feed, 220)
		feed_b.disabled = f == "" or full
		row.add_child(feed_b)
		main_b = feed_b
	var back_b := UI.button("Back", back, 140)
	row.add_child(back_b)
	add_child(row)
	var shell: Control = (get_parent() as Control).get_meta("shell", null) if get_parent() != null else null
	if shell != null:
		# Enter never sits on a dead button
		shell.set_meta("primary", main_b if main_b != null and not main_b.disabled else back_b)

## One meal from the pantry, straight onto the starve clock (the same rules as feeding it at home).
func _feed() -> void:
	var rec := Save.active_kin()
	var f := pick_food(rec)
	if rec.is_empty() or f == "":
		return
	var res := Care.feed(rec, f)
	if res["ok"]:
		if Data.CROPS.has(f): Save.d["crops"][f] = int(Save.d["crops"][f]) - 1
		else: Save.d["items"][f] = int(Save.d["items"][f]) - 1
		for af in Evo.AFF:
			if Data.CROPS.has(f) and Evo.AFF[af]["food"] == f: Evo.add(rec, af, 6.0)
		if res.get("hungry", false): Save.remember(rec, "fed", "was fed when it was hungry", 2.0)
		Sfx.play("kin_happy", null, -8.0)
		Save.save_game()
	_rebuild()

## The fed bar: full up on the right, the minimum line where "too weak" ends.
class _Bar extends Control:
	var level := 0.0
	var line := 0.0
	var ok := false
	func _init(l: float, ln: float, enough: bool) -> void:
		level = l
		line = ln
		ok = enough
		custom_minimum_size = Vector2(0.0, BAR_H_PX + 8.0)
	func _draw() -> void:
		var r := Rect2(0.0, 4.0, size.x, BAR_H_PX)
		draw_rect(r, BAR_BACK)
		draw_rect(Rect2(r.position, Vector2(r.size.x * level, r.size.y)), UI.GOOD if ok else UI.ACCENT)
		var x := r.size.x * line
		draw_rect(Rect2(x - LINE_W_PX * 0.5, 0.0, LINE_W_PX, BAR_H_PX + 8.0), UI.INK)
