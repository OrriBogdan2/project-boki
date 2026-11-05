class_name FarmTaskGuide
extends RefCounted
## The farm tutorial's "give your Boki a job" step, made hard to miss: a pulsing outline and arrow on the
## Kin button (until the Boki's page is open) and on the page's job dropdown, the best job named in the
## hint, and a confirmation on picking one. FarmTutorial/FarmGuide/WorkView call in here.

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
	_job = WorkView.job_label(String(jobs[0][0])) if not jobs.is_empty() else "Whatever it's best at"
	pulse(opt, "▶")

## What the hint line fills in: {boki}, {job}.
static func fill(txt: String) -> String:
	var rec := Save.active_kin()
	var nm := _boki if _boki != "" else String(rec.get("name", "your Boki"))
	return txt.replace("{boki}", nm).replace("{job}", _job)

## A job was picked on the page: the step completes and the Boki is thanked.
static func picked(h: Node, rec: Dictionary, job: String) -> void:
	var was := FarmTutorial.active() and FarmTutorial.current() == "task"
	FarmTutorial.event("task")
	if was and h.has_method("_toast"):
		h._toast("Great, %s is on %s now!" % [String(rec.get("name", "your Boki")), Work.name_of(job)])

## A gold outline that breathes round a control, with an arrow beside it.
static func pulse(c: Control, arrow: String) -> void:
	unpulse(c)
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
	var arr := Label.new()
	arr.text = arrow
	arr.add_theme_font_size_override("font_size", 24)
	arr.add_theme_color_override("font_color", GOLD)
	arr.position = Vector2(-26, 0)
	box.add_child(arr)
	c.add_child(box)
	if box.is_inside_tree():
		var tw := box.create_tween().set_loops()
		tw.tween_property(box, "modulate:a", 0.35, 0.5)
		tw.tween_property(box, "modulate:a", 1.0, 0.5)

static func unpulse(c: Control) -> void:
	var old := c.get_node_or_null(PULSE)
	if old:
		old.queue_free()

## The bottom bar's Boki button: pulsing while the step wants you to open the page, quiet otherwise.
static func hub_hint(h: Node, want: bool) -> void:
	var b: Control = h.hub_btns.get("kin")
	if b == null or not is_instance_valid(b):
		return
	var has := b.get_node_or_null(PULSE) != null
	if want and not has:
		pulse(b, "▼")
		(b.get_node(PULSE).get_child(1) as Label).position = Vector2(20, -34)
	elif has and not want:
		unpulse(b)
