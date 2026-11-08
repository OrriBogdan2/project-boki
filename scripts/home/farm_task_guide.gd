class_name FarmTaskGuide
extends RefCounted
## The farm tutorial's "give your Boki a job" step, made hard to miss: a pulsing outline and arrow on the
## page's job dropdown (the Boki button on the bar is FarmSpotlight's), the best job named in the hint, a
## confirmation on picking one, and a Boki page that points at the one next thing: Done, not Feed.
## FarmTutorial/FarmGuide/WorkView/Home call in here.

const GOLD := Color("f2c84a")
const PULSE := "TutPulse"

static var _drop: OptionButton = null     # the job dropdown on the open Boki page (while this step is up)
static var _job := ""                     # the best job for that Boki, in words
static var _boki := ""                    # and its name

## Is the Boki's page open with the dropdown on it?
static func page_up() -> bool:
	return is_instance_valid(_drop) and _drop.is_inside_tree()

## The page's dropdown goes in while the step is up: outline it and name the best job.
static func mark_dropdown(opt: OptionButton, rec: Dictionary) -> void:
	if not FarmTutorial.active() or FarmTutorial.current() != "task":
		return
	_drop = opt
	_boki = String(rec.get("name", "your Boki"))
	var jobs := Work.list(rec)
	_job = WorkView.job_label(String(jobs[0][0])) if not jobs.is_empty() else "the first one on the list"
	pulse(opt, "▶")

## What the hint line fills in: {boki}, {job}.
static func fill(txt: String) -> String:
	var rec := Save.active_kin()
	var nm := _boki if _boki != "" else String(rec.get("name", "your Boki"))
	return txt.replace("{boki}", nm).replace("{job}", _job)

## A job was picked on the page: the step completes, the Boki is thanked, and the page says what's next.
static func picked(h: Node, rec: Dictionary, job: String) -> void:
	var was := FarmTutorial.active() and FarmTutorial.current() == "task"
	FarmTutorial.event("task")
	if was and h.has_method("_toast"):
		var nm := String(rec.get("name", "your Boki"))
		var on_it := "%s is on %s now!" % [nm, Work.name_of(job)]
		h._toast("Great, %s Press Done to carry on." % on_it)

## The Care page's main button. While the tutorial still has the trough to set up, Feed is an ordinary button
## (feeding by hand is not the step) and the page's one filled, ringed button is Done once a job is set.
static func care_footer(v: VBoxContainer, feed: Callable, close: Callable) -> void:
	if not FarmTutorial.active() or FarmTutorial.did("feed"):
		UI.footer_primary(v, "Feed", feed, 110, "seed")
		return
	UI.footer(v).add_child(UI.button("Feed", feed, 0, "seed"))
	if FarmTutorial.did("task"):
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
