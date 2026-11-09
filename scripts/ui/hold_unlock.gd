class_name HoldUnlock
extends VBoxContainer
## Hold to unlock a Hunter (docs/decisions/0005). Press and hold the button (mouse, or Enter / Space
## while it has focus): a bar slides out under it and fills over hold_s (content/rules/class_unlock.json)
## while the viewer's Hunter powers up (HunterViewer.power) with a rising hum. Let go early and it
## cancels: the bar drains and slides back, nothing changes. At full the Hunter unlocks
## (ClassUnlock.unlock), the viewer bursts and `done` fires (the caller plays the reveal).
##
##   var hu := HoldUnlock.make(id, viewer)
##   hu.done.connect(func(id): ...)

signal done(id: String)
signal cancelled(id: String)

const BAR_W := 300.0          # px, the bar at full slide
const SLIDE_S := 0.18         # s for the bar to slide out (and back)
const DRAIN_S := 0.25         # s for a cancelled bar to drain

var id := ""
var viewer: HunterViewer
var btn: Button
var track: Control
var holding := false
var k := 0.0                  # 0..1 filled
var slide := 0.0              # 0..1 how far the bar is out
var finished := false
var _hum_at := 0.0

static func make(hunter_id: String, v: HunterViewer) -> HoldUnlock:
	var h := HoldUnlock.new()
	h.id = hunter_id
	h.viewer = v
	return h

static func hold_s() -> float:
	return maxf(0.2, float(ClassUnlock.rules().get("hold_s", 1.6)))

func _ready() -> void:
	set_meta("hold_unlock", id)
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	btn = UiWidgets.primary("Hold to unlock %s" % Arch.name_of(id, true), func(): pass, 300)
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.button_down.connect(press)
	btn.button_up.connect(release)
	btn.gui_input.connect(func(ev):
		if ev.is_action_pressed("ui_accept") and not ev.is_echo(): press()
		elif ev.is_action_released("ui_accept"): release())
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(btn)
	track = Control.new()
	track.custom_minimum_size = Vector2(BAR_W, 12)
	track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.draw.connect(_draw_bar)
	add_child(track)

func press() -> void:
	if finished or holding:
		return
	holding = true
	Sfx.play("whoosh", null, -14.0, 0.0, 0.7)

## Letting go: before full, the hold is cancelled.
func release() -> void:
	if not holding:
		return
	holding = false
	if not finished and k < 1.0:
		cancelled.emit(id)

func _process(dt: float) -> void:
	tick(minf(dt, 0.1))

## One step of the hold (also driven straight by the unlock check).
func tick(dt: float) -> void:
	if finished:
		slide = maxf(0.0, slide - dt / SLIDE_S)
		track.queue_redraw()
		return
	if holding:
		slide = minf(1.0, slide + dt / SLIDE_S)
		k = minf(1.0, k + dt / hold_s())
		_hum_at -= dt
		if _hum_at <= 0.0:
			# a rising hum: higher pitched as it fills
			Sfx.play("ui_charge", null, -12.0, 0.0, 0.8 + 0.8 * k)
			_hum_at = 0.22
		if k >= 1.0:
			_complete()
	else:
		k = maxf(0.0, k - dt / DRAIN_S)
		if k <= 0.0: slide = maxf(0.0, slide - dt / SLIDE_S)
	if viewer: viewer.power(k)
	track.queue_redraw()

func _complete() -> void:
	holding = false
	if not ClassUnlock.unlock(id):
		k = 0.0
		return
	finished = true
	Save.save_game()
	Sfx.play("unlock", null, -3.0, 0.0, 1.0)
	if viewer: viewer.burst()
	btn.disabled = true
	btn.text = "%s unlocked" % Arch.name_of(id)
	done.emit(id)

func _draw_bar() -> void:
	if slide <= 0.0:
		return
	var col := Arch.color(id)
	var e := 1.0 - pow(1.0 - slide, 3.0)        # out-cubic slide
	var w := BAR_W * e
	var x0 := (BAR_W - w) * 0.5
	var r := Rect2(Vector2(x0, 0), Vector2(w, track.size.y))
	track.draw_style_box(UI.frame(Color(0, 0, 0, 0.55), 6, Color(col, 0.6), 1, 0, 0), r)
	if k > 0.0:
		var fr := Rect2(r.position + Vector2(2, 2), Vector2(maxf(0.0, (w - 4.0) * k), r.size.y - 4.0))
		track.draw_style_box(UI.frame(col.lerp(Color.WHITE, 0.25 * k), 4, Color(0, 0, 0, 0), 0), fr)
		if k >= 1.0:
			track.draw_style_box(UI.frame(Color(1, 1, 1, 0.6), 4, Color(0, 0, 0, 0), 0), fr)
