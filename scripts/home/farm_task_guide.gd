class_name FarmTaskGuide
extends RefCounted
## A Boki's first job, made hard to miss (the farm's one-time "task" hint, FarmHints, says to click it): until
## any Boki is pinned to a job, a pulsing outline and arrow on the page's job dropdown, a confirmation on
## picking one, and, during the farm tutorial, a Care page that points at the one next thing: Done, not Feed.
## WorkView/Home call in here.

const GOLD := Color("f2c84a")
const PULSE := "TutPulse"
const PICKED_SAY_S := 6.0      # s the "Off to work!" bubble stays up, long enough to close the page and see it

static var _drop: OptionButton = null     # the pulsing job dropdown on the open Boki page (until a first job)

## Is the Boki's page open with the dropdown on it?
static func page_up() -> bool:
	return is_instance_valid(_drop) and _drop.is_inside_tree()

## Has any Boki been pinned to a job yet?
static func any_job() -> bool:
	return (Save.d["roster"] as Array).any(func(r): return Work.pin(r) != "")

## The page's dropdown goes in: until a first job is picked, outline it.
static func mark_dropdown(opt: OptionButton, _rec: Dictionary) -> void:
	if any_job() or not HomeLayout.fs(Save.d):
		return
	_drop = opt
	pulse(opt, "▶")

## A job was picked on the page: the task hint is done with; on a first job the Boki is thanked and the page
## says what's next.
static func picked(h: Node, rec: Dictionary, job: String) -> void:
	var was := page_up()
	_drop = null
	FarmTutorial.event("task")
	if was:
		var nm := String(rec.get("name", "your Boki"))
		var on_it := "%s is on %s now!" % [nm, Work.name_of(job)]
		h._toast("Great, %s Press Done to carry on." % on_it)
		_say_off(h, rec)

## The Boki answers in the world, so closing the page shows it heading off (or waiting for work).
static func _say_off(h: Node, rec: Dictionary) -> void:
	var k: Dictionary = h._kin_entry(rec)
	if k.is_empty() or h.hw == null:
		return
	var going: bool = h.hw.pick(k)
	h._say(k, String(FarmTutorial.rules()["picked_say"]["go" if going else "wait"]), PICKED_SAY_S)

## The Care page's main button. While the tutorial still has the trough to set up, Feed is an ordinary button
## (feeding by hand is not the step) and the page's one filled, ringed button is Done once a job is set.
static func care_footer(v: VBoxContainer, feed: Callable, close: Callable) -> void:
	if not FarmTutorial.active() or FarmTutorial.did("feed"):
		UI.footer_primary(v, "Feed", feed, 110, "seed")
		return
	UI.footer(v).add_child(UI.button("Feed", feed, 0, "seed"))
	if any_job():
		pulse(UI.footer_primary(v, "Done", close, 110))

## A gold outline that breathes round a control, with an arrow beside it if given.
static func pulse(c: Control, arrow := "") -> void:
	var box := Control.new()
	box.name = PULSE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ring := ReferenceRect.new()
	ring.border_color = GOLD
	ring.border_width = 3.0
	ring.editor_only = false
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, -3)
	box.add_child(ring)
	if arrow != "":
		var arr := Label.new()
		arr.text = arrow
		arr.add_theme_font_size_override("font_size", 24)
		arr.add_theme_color_override("font_color", GOLD)
		arr.position = Vector2(-26, 0)
		box.add_child(arr)
	box.tree_entered.connect(func():      # the control is usually not on screen yet when this is called
		var tw := box.create_tween().set_loops()
		tw.tween_property(box, "modulate:a", 0.35, 0.5)
		tw.tween_property(box, "modulate:a", 1.0, 0.5))
	c.add_child(box)
